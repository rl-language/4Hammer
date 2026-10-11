"""Seeded gameplay with explicit completion, ownership and legal-action checks.

Write legal-choice ranks as fuzzer inputs and readable traces outside the repo.
Run each source in a separate process: RLC 0.3.3 caches generated modules as sim.
"""

import argparse
import json
import random
import struct
from pathlib import Path
from rlc import compile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("--seed", type=int, default=40000)
    parser.add_argument("--max-actions", type=int, default=5000)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    args.output.mkdir(parents=True, exist_ok=True)
    rng = random.Random(args.seed)
    choices, trace = [], []
    with compile([str(root / args.source)], rlc_includes=[str(root / "src")]) as program:
        state = program.start()
        initial_count = state.num_actions
        for step in range(args.max_actions):
            if state.is_done():
                break
            owner = program.module.get_current_player(state.state)
            if owner not in (-1, 0, 1):
                raise RuntimeError(f"Invalid decision owner {owner} at action {step}")
            actions = state.legal_actions
            if not actions:
                raise RuntimeError(f"Nonterminal state has no legal actions at {step}")
            rank = rng.randrange(len(actions))
            action = actions[rank]
            # Generated payload parsing is part of the replay contract.
            parsed = program.parse_action(str(action))
            if parsed is None or not state.can_apply(parsed):
                raise RuntimeError(f"Action failed textual round trip: {action}")
            choices.append(rank)
            trace.append(f"{step}\t{owner}\t{rank}\t{action}")
            state.step(parsed)
        result = {
            "source": args.source,
            "seed": args.seed,
            "actions": len(choices),
            "enumerated_actions": initial_count,
            "completed": state.is_done(),
            "final_owner": program.module.get_current_player(state.state),
        }
        stem = Path(args.source).stem + f"-seed-{args.seed}"
        (args.output / (stem + ".trace")).write_text("\n".join(trace) + "\n")
        (args.output / (stem + ".bin")).write_bytes(
            b"".join(struct.pack("<q", rank) for rank in choices) + b"\0"
        )
        (args.output / (stem + ".json")).write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result), flush=True)
        if not result["completed"] or result["final_owner"] != -4:
            raise RuntimeError("Scenario did not finish within its action budget")


if __name__ == "__main__":
    main()
