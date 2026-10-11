"""Check JIT compilation, legal masks and finite observations for 20 gym steps."""

import json
from pathlib import Path
import random
import numpy as np
from rlc import compile
from ml.env import SingleRLCEnvironment, exit_on_invalid_env


def main():
    root = Path(__file__).resolve().parents[1]
    np.random.seed(40000)
    rng = random.Random(40000)
    with compile([str(root / "src/full_game.rl")]) as program:
        exit_on_invalid_env(program, forced_one_player=True, needs_score=True)
        env = SingleRLCEnvironment(program)
        completed = 0
        for _ in range(20):
            if env.is_done_underling():
                break
            mask = env.get_action_mask()
            legal = np.flatnonzero(mask == 1)
            if not len(legal):
                raise RuntimeError("Gym environment has no legal action")
            env.step(int(legal[rng.randrange(len(legal))]))
            if not np.isfinite(env.get_state()).all():
                raise RuntimeError("Gym observation contains nonfinite values")
            completed += 1
        if completed != 20:
            raise RuntimeError(f"Expected 20 gym steps, got {completed}")
        print(json.dumps({"gym_steps": completed, "action_count": env.get_action_count(), "observation_size": env.get_state_size(), "seed": 40000}), flush=True)


if __name__ == "__main__":
    main()
