# Rule validation baseline

Activate the repository's compatible environment first:

```bash
source /workspace/4hammer-venv/bin/activate
python tools/run_rule_tests.py
```

The runner executes `rlc-test tests/baseline.rl -i src`, checks actual RUN/OK names and counts, then runs the known-discrepancy assertions in a separate process. It rejects a zero-test success, missing tests, crashes and unexpected passes. Separate processes avoid RLC 0.3.3's generated-module cache reusing a previous `sim` module.

`baseline.rl` tests supported behavior, legality and state transitions. `known_discrepancies.rl` asserts desired behavior that currently fails; its manifest links each failure to a source rule, category and roadmap owner. These failures are reported as XFAIL, never as semantic passes. When fixing one, move its assertion into the passing suite and remove its manifest entry. Do not change the assertion to approve incorrect behavior or broadly skip a failing subsystem.

The tests are a starting suite, not all 156 subsections. Later tasks add their page-linked boundaries, modes and workflow cases. Supply valid populated fixtures: `required_wound_roll` looks up the attacking unit even for a plain weapon; an empty board is not a valid attack state.

## Seeded gameplay and bindings

Run sources in separate processes. These commands check legal choices, decision-owner values, action text round trips and explicit completion; they write readable traces, JSON outcomes and binary legal-choice ranks for the fuzzer outside the checkout.

```bash
python tools/check_gameplay_baseline.py src/full_game.rl \
  --seed 40000 --output /workspace/4hammer-validation/replays
python tools/check_gameplay_baseline.py examples/single_shooting_maximize.rl \
  --seed 40000 --output /workspace/4hammer-validation/replays
python tools/check_gym_baseline.py
```

The gym check exercises JIT/wrappers, legal masks and finite observations for 20 steps. The existing `rlc-random` commands in AGENTS.md remain useful smoke checks, but that CLI has no seed option and applies its action budget across iterations. Use the seeded runner for reproducible completion evidence. Completion alone does not validate combat: the baseline currently reproduces zero evaluation of fixed characteristics, which can let shooting finish without attacks.

## Sanitized fuzzer

The prepared Debian 13 amd64 environment has libLLVM-19, GCC, libc headers and binutils. Clang 19 and its compiler runtime were extracted into writable workspace storage because system package installation is unavailable. Recreate that local toolchain from checksum-pinned packages with:

```bash
python tools/prepare_validation_clang.py
export LD_LIBRARY_PATH="/workspace/4hammer-validation/toolchain/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p /workspace/4hammer-validation/corpus /workspace/4hammer-validation/artifacts
rlc src/full_game.rl -O2 -g --fuzzer --sanitize \
  --emit-precondition-checks --emit-bound-checks \
  --clang=/workspace/4hammer-validation/toolchain/usr/lib/llvm-19/bin/clang \
  -o /workspace/4hammer-validation/rules_fuzzer
```

This matches the repository's fuzzer instrumentation without requiring the Godot CMake build. It does not install a complete general-purpose LLVM development environment. On other machines use an appropriate installed Clang/sanitizer runtime instead.

Seed with completed replay `.bin` files or these initial inputs (each exceeds eight bytes, so the harness actually applies actions):

```bash
python - <<'PY'
from pathlib import Path
import random
import struct
root = Path('/workspace/4hammer-validation/corpus')
root.mkdir(parents=True, exist_ok=True)
inputs = {
    'zero': [0] * 64,
    'one': [1] * 64,
    'seed_40k': [random.Random(i + 40000).randrange(1 << 31) for i in range(128)],
}
for name, choices in inputs.items():
    (root / name).write_bytes(b''.join(struct.pack('<q', value) for value in choices) + b'\0')
PY
/workspace/4hammer-validation/rules_fuzzer \
  /workspace/4hammer-validation/corpus -seed=40000 \
  -max_total_time=60 -max_len=4096 \
  -artifact_prefix=/workspace/4hammer-validation/artifacts/
```

Use `rules_fuzzer path/to/replay.bin -runs=1` for a fixed-input replay. That is distinct from a mutation campaign. Keep the optimized/debug/sanitizer/precondition/bounds flags, preserve failures and add regressions; do not weaken instrumentation to get a pass. A seeded duration-limited run is not guaranteed identical across hardware or an already-grown corpus.

See [the recorded task-2 results](../doc/validation-baseline.md) for actual counts, known defects and practical limits.
