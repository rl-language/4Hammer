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

The prepared Debian 13 amd64 environment has GCC 14, libc headers, binutils and the runtime dependencies. RLC 0.4.13 needs Clang 21.1.8 and matching sanitizer/fuzzer runtimes, extracted into writable workspace storage. Recreate that local toolchain from checksum-pinned LLVM packages with:

```bash
python tools/prepare_validation_clang21.py
export LD_LIBRARY_PATH="/workspace/4hammer-validation/toolchain21/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p /workspace/4hammer-validation/corpus /workspace/4hammer-validation/artifacts
rlc src/full_game.rl -O2 -g --fuzzer --sanitize \
  --emit-precondition-checks --emit-bound-checks \
  --clang=/workspace/4hammer-validation/toolchain21/usr/lib/llvm-21/bin/clang \
  -o /workspace/4hammer-validation/rules_fuzzer-0.4.13
test -x /workspace/4hammer-validation/rules_fuzzer-0.4.13
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
/workspace/4hammer-validation/rules_fuzzer-0.4.13 \
  /workspace/4hammer-validation/corpus -seed=40000 \
  -max_total_time=60 -max_len=4096 \
  -artifact_prefix=/workspace/4hammer-validation/artifacts/
```

Use `rules_fuzzer path/to/replay.bin -runs=1` for a fixed-input replay. That is distinct from a mutation campaign. Keep the optimized/debug/sanitizer/precondition/bounds flags, preserve failures and add regressions; do not weaken instrumentation to get a pass. A seeded duration-limited run is not guaranteed identical across hardware or an already-grown corpus.

See [the recorded task-2 results](../doc/validation-baseline.md) for actual counts, known defects and practical limits.

## Current state foundations (task 3)

The current suite has 45 passing tests and 8 remaining discrepancy assertions. See [the state report](../doc/state-foundations.md) and ROADMAP.md for fixed issues and remaining owners. State/observation schemas are 3 and action schema is 2; old policies, saves and ordered action traces are incompatible. Seeded replay JSON records all three versions. Full-game observations now contain 149,836 values and action enumeration contains 7,469 candidates.

`tests/godot_state.gd` exercises the existing source/target, unit and location selector APIs and engine save loading followed by explicit state replacement through regenerated native bindings. Run it with matching fresh `librules.so` and `librlcrules.so`:

```bash
python tools/check_godot_state.py \
  --build-path /workspace/4hammer-validation/godot-build
```

The runner creates an isolated temporary project, uses writable XDG directories and rejects missing PASS evidence, script/load errors, nonzero exits, timeout and ObjectDB leak warnings. The harness frees its test-owned library; production script ownership and automatic load/trace integration are outside this change. It does not exercise interactive mouse input or rendering.

The task-3 build used godot-cpp 4.3 commit `d5cc777a89d899665fb61f1650ef0dc0cf6488c4`, SCons and Godot 4.6.3's dumped extension API. Its reduced SDK build profile enables RefCounted, Node, OS, FileAccess, Image, WorkerThreadPool, XMLParser and EditorPlugin, including their generated dependencies. Regenerate the native library and header together after every source change; stale template instantiations can leave undefined symbols even when the shared extension links.

Native generation used:

```bash
rlc src/full_game.rl --godot -o /workspace/4hammer-validation/godot-build/rules.inc
rlc src/full_game.rl --shared -O2 -g \
  --emit-precondition-checks --emit-bound-checks --abort-symbol rlc_abort \
  -o /workspace/4hammer-validation/godot-build/librlcrules.so
```

Compile `src/gdexample.cpp` and `src/rlc_runtime.c` against that header, godot-cpp's include/generated/include/gdextension directories and its static library. Link `librlcrules.so` and set the extension's runtime search path to `$ORIGIN`. The repository's CMake rules describe the complete SDK/extension build; task 3 used this narrower native path, not the web/repository-wide CMake targets.

For the task-3 completed replay seed (5,169 bytes), use `-max_len=8192` in a mutation campaign rather than the earlier 4096 example. Native fixed-input replay remains a separate check.

Numeric state uses standard bounded Rulebook types for inferred ML domains/encoding. The updated tests cover CP domain/tensor inference, out-of-range save rejection, and sufficient Advance/random-result/damage/starting-strength bounds. See the state report for configured inclusive ranges and standard clamping behavior.

## Compiler 0.4.13 follow-up

Use `rl_language==0.4.13` and matching core package. After correcting the bare `is_character` name to `destroyed.is_character()`, the runner passes 45 tests with 8 XFAIL and 0 XPASS. Two added regressions cover the existing Feeder Tendrils character-casualty/attacker-ability gate; its faction source remains external. The compiler had misleadingly located the bad Boolean operand at the method declaration.

The initial Clang 19 mismatch is resolved by the helper above. Its six pinned LLVM 21 packages were authenticated against the signed repository metadata with fingerprint `6084F3CF814B57C1CF12EFD515CF4D18AF4F7421`; every download is checksum-verified. Same-version x86_64 runtime symlinks adapt Debian's layout to RLC's per-target paths. The installation was repeated successfully. The resulting sanitized fuzzer completes 118 runs in 62 seconds with seed 40000, coverage 6,565 and feature count 18,472, without reported failures or failure artifacts; a fresh three-input corpus drives actions. RLC may exit zero despite linker errors, so inspect diagnostics and require a produced runnable binary. Existing 0.3.3 native/Godot libraries are historical and cannot validate the upgraded compiler.
