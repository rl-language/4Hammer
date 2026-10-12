# Rule validation baseline

Activate the repository's compatible environment first:

```bash
source /workspace/4hammer-venv/bin/activate
python tools/run_rule_tests.py
```

## CMake / CTest

Use CMake's CTest runner to see each rule test individually. A tests-only configuration avoids Godot, SDK downloads and web builds:

```bash
source /workspace/4hammer-venv/bin/activate
cmake -S . -B build-tests -DBUILD_GAME=OFF
ctest --test-dir build-tests --output-on-failure -j 4
```

For another virtual environment, activate it first; if CMake cached a different interpreter, configure with `-DPython3_EXECUTABLE=/path/to/venv/bin/python`. The commands shown use CMake/CTest 3.20+ (`--test-dir`); project configuration supports CMake 3.12+. The compatible Rulebook/Python environment is required.

`ctest -N --test-dir build-tests` lists the tests. `ctest --test-dir build-tests -R test_timing_opponent_charge --output-on-failure` runs a selected case. Labels `baseline`, `discrepancies` and `expected-failure` allow filtering with `-L`. CTest automatically includes the matching compilation fixture even for a single selected test. Each suite compiles once per invocation with precondition/bounds checks; each assertion runs in its own process. A failed compilation blocks its cases rather than using an old library.

The current discovery lists **283 entries**: 281 supported assertions and 2 compilation fixtures. The discrepancy manifest is empty. Recorded discrepancies, when present, return CTest's skip code and appear as **Skipped / XFAIL**, not semantic passes. Unexpected passes, false supported assertions, crashes, manifest mismatches and compilation failures fail validation. When fixing a discrepancy, promote its assertion into the baseline and remove its manifest entry.

CTest is also available in a normal game configuration (`BUILD_GAME=ON`, the default), and Make/Ninja support `cmake --build build-tests --target test`. CMake itself has no `--test` command. Reconfigure after changing test declarations or the manifest; CMake also tracks these files for regeneration during a build. Generated libraries stay in the chosen build directory. The original Python runner below remains available.

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

The gym check exercises JIT/wrappers, legal masks and finite observations for 20 steps. The existing `rlc-random` commands in AGENTS.md remain useful smoke checks, but that CLI has no seed option and applies its action budget across iterations. Use the seeded runner for reproducible completion evidence. Completion alone does not validate combat semantics. Task 9 fixed fixed-characteristic evaluation; later tasks must still certify complete shooting and fighting workflows.

## Sanitized fuzzer

The prepared Debian 13 amd64 environment has GCC 14, libc headers, binutils and the runtime dependencies. RLC 0.4.14 needs Clang 21.1.8 and matching sanitizer/fuzzer runtimes, extracted into writable workspace storage. Recreate that local toolchain from checksum-pinned LLVM packages with:

```bash
python tools/prepare_validation_clang21.py
export LD_LIBRARY_PATH="/workspace/4hammer-validation/toolchain21/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p /workspace/4hammer-validation/corpus /workspace/4hammer-validation/artifacts
rlc src/full_game.rl -O2 -g --fuzzer --sanitize \
  --emit-precondition-checks --emit-bound-checks \
  --clang=/workspace/4hammer-validation/toolchain21/usr/lib/llvm-21/bin/clang \
  -o /workspace/4hammer-validation/rules_fuzzer-0.4.14
test -x /workspace/4hammer-validation/rules_fuzzer-0.4.14
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
/workspace/4hammer-validation/rules_fuzzer-0.4.14 \
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

## Quad geometry foundations (task 4)

The current runner passes 74 tests, with 8 XFAIL and 0 XPASS. State/observation schemas are 4; action schema remains 2. Observations contain 156,098 values and action enumeration contains 7,469 candidates. Read [the geometry report](../doc/geometry-foundations.md) for exact scope, source citations, successful validation and unsupported geometry. Whole-inch quad model positions and existing Godot coordinate controls are preserved.

Fresh matching Godot libraries are in `/workspace/4hammer-validation/task4-godot`. Run `python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task4-godot` after rebuilding the Rulebook library, generated header and C++ extension together. The headless harness also checks rejected edge placement without state mutation.

The current instrumented executable is `/workspace/4hammer-validation/task4-rules-fuzzer`. Replay `tests/fuzz-regressions/geometry-placement-leak.bin -runs=1` with that executable before the mutation campaign; keep leak detection enabled. Its [README](fuzz-regressions/README.md) describes the original failure. Seeded replay results are in `/workspace/4hammer-validation/task4-replays`. The gameplay runner now preserves the action ranks, trace and state before raising on a nonterminal state with no legal actions.

## Timing foundations (task 5)

The current suite has **97 PASS, 8 XFAIL, 0 XPASS**. Read [the timing report](../doc/timing-foundations.md) and ROADMAP.md for scope and final evidence. State/observation schemas are **5**, action schema **3**; matching new native libraries and headers are required. Full-game enumeration has **9,950** candidates and the gym observation has **163,673** values. Earlier section counts are historical. The Godot harness also checks timing-enum, coherency UnitID/ModelID and source-first Neural Disruption payload shapes; interactive input/rendering remains unrun.

CTest integration validation: the tests-only configuration discovered 107 entries; the full `ctest --output-on-failure -j 4` run finished in 44.54 seconds with **97 supported assertions passing, 8 XFAIL skips, and 2 compilation fixtures passing**. Checked pass/fail and XFAIL/XPASS exit contracts, compiler-failure/stale-output rejection and selected-test fixture inclusion. No game rules or migration task status changed.

Deployment editor regression: `godot_state.gd` loads the actual choice panel and interaction script, presses deployment buttons for both armies, checks the opposite deployment regions and owners, rejects the incorrect battlefield ID, and verifies battlefield clicking is disabled while choosing reserves. The previous choice panel fails this regression; the fixed scripts pass against the matching task-5 native bindings. No rule source, action/state schema or quad coordinates changed in this UI fix.

The deployment harness also presses “Done deploying” for Army 1 and verifies that only Army 2 can subsequently deploy, including retention of Army 2 ownership after placement. It repeats the finish handoff with identical armies. Deployment and finish buttons identify Army 1/2 explicitly, since unit names alone cannot distinguish identical armies and placement alternates decision ownership.

## Command phase and Battle-shock (task 7)

The suite has **120 PASS, 5 XFAIL, 0 XPASS**. CTest registers **127 entries**, including two compilation fixtures and five explicit expected-failure skips. [The task-7 report](../doc/command-battle-shock.md) gives rule scope, page citations and validation evidence. State/observation schemas are **6**; action schema stays **3**. Matching native Godot artifacts are in `/workspace/4hammer-validation/task7-godot`. The headless harness saves/reloads a pending Command recovery roll and checks chance ownership and shock gates.

CMake now prefers the activated Python environment and checks `rlc.program` during configuration. For an existing build cached with the wrong interpreter, reconfigure with `-DPython3_EXECUTABLE=/workspace/4hammer-venv/bin/python`; fresh builds select the activated environment automatically.

## Terrain and objectives (task 8)

The current suite has **144 PASS, 3 XFAIL, 0 XPASS**; CTest exposes **149 entries**, including two compilation fixtures and three explicit expected-failure skips. State/observation schemas are **7**, action schema **3**. Read [the task-8 report](../doc/terrain-objectives.md) and ROADMAP.md for source pages, user-approved visibility approximation and final evidence. Objective aggregation/tie assertions are promoted into the passing suite; the remaining three failures belong to task 9.

Fresh native artifacts are in `/workspace/4hammer-validation/task8-godot`; run `python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task8-godot`. The harness exercises bounded area fields, cover/Hidden, secured-objective snapshots through absence, schema-7 save restoration and actual-shot history, alongside existing selectors/deployment/Command checks. Area rendering and interactive GUI input remain unrun.

The sanitized executable is `/workspace/4hammer-validation/task8-rules-fuzzer`, with seeded inputs in `task8-replays`. Replay both completed inputs and `tests/fuzz-regressions/geometry-placement-leak.bin` with leak detection enabled before mutation fuzzing. The fresh campaign completes 31 runs in 74 seconds without reported sanitizer failures; its external-symbolizer warning limits symbolic diagnostic names, not sanitizer instrumentation. Gym produces 164,014 finite observations and 9,950 action candidates across 20 checked steps. Fixed characteristics still suppress actual combat until task 9.


## Attack declarations and dice (task 9)

The supported suite now contains **171** passing rule tests, with **0 XFAIL and 0 XPASS**. CTest exposes **173 entries**, including two passing compilation fixtures. The three final discrepancy assertions were promoted unchanged. An empty discrepancy manifest is valid; an empty supported suite still fails validation. State/observation schemas are **8**, action schema **4**; earlier counts describe historical task results.

The new cases test pre-roll declarations, target legality, split melee budgets, grouping, per-weapon random A, target replacement, stable source identity, batch rerolls, expenditure, exact Strength thresholds, critical abilities, modifier limits, fixed damage and random-D allocation order. The user-directed assumption that random-A melee weapons do not exist is enforced with an assertion. Read [the task-9 report](../doc/attack-declarations-dice.md) for mandatory downstream limitations.

Build matching native/header/C++ artifacts together in `/workspace/4hammer-validation/task9-godot`, then run `python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task9-godot`. The new harness uses production weapon/group buttons and source/target clicks, checks batch chance ownership and restores a pending attack save. Numeric melee-share buttons are provided but are not interactively exercised by this shooting harness; deterministic Rulebook tests establish share legality.

The fresh instrumented executable is `/workspace/4hammer-validation/task9-fuzzer`; keep leak detection and precondition/bounds checks enabled. Final seeded replay and campaign evidence is in ROADMAP.md. Task 10 must replace the legacy damage bridge before claiming full attack-resolution correctness.

## Task 10 current checks

The supported suite is **202 PASS, 0 XFAIL, 0 XPASS**, with **204 passing CTest entries** including two compilation fixtures. The discrepancy manifest is empty. State/observation schemas are **9**, action schema **5**; earlier evidence in this document is historical. See [the saves/damage/destruction report](../doc/saves-damage-destruction.md) for rule-page ownership, core regressions and deferred attachment/fight/transport/faction scope.

Fresh matching native artifacts are in `/workspace/4hammer-validation/task10-godot`. Run:

```bash
python tools/check_godot_state.py \
  --build-path /workspace/4hammer-validation/task10-godot --timeout 120
```

The expanded headless regression passes labelled save-group buttons, model clicks on the actual defender, all-save batch boundaries, save/reload while awaiting allocation, individual Feel No Pain rolls and archival. Prior deployment, Command, terrain/Hidden, objective and weapon/target controls remain tested. The timeout is explicit because expanded serialized action state exceeds the old 30-second check on this machine; script errors and missing PASS evidence still fail. Interactive rendering and mouse input remain unrun.

The final instrumented executable is `/workspace/4hammer-validation/task10-final-fuzzer`; keep leak/precondition/bounds checks enabled. Replay completed `task10-replays/*.bin` and the original geometry leak input before mutation fuzzing. The fresh campaign completes **25 runs in 78 seconds**, coverage **10,184**, features **23,383**, without reported sanitizer failures or crash artifacts. A slow-unit artifact retains the complete full-game seed; it is a performance diagnostic, not a sanitizer failure. Keep it and the campaign log outside the checkout for later comparison. The 60-second requested campaign duration can be exceeded by a slow individual replay.

Seed 40000 completes full/shooting games in **625/9 actions**. Gym checks **20** legal steps, **12,744** action candidates and **1,595,388** finite observations. The larger bounded destruction work stack materially expands inferred ML layout; saves and policies from previous schemas are incompatible. Actual interactive integration and complete downstream rules remain owned by ROADMAP.md.

## Compiler 0.4.14

The user requested the new compiler with duplicate-variable diagnostics. Use `rl_language==0.4.14` and matching `rl_language_core==0.4.14`. Regenerate native libraries, wrappers and Godot headers together after the upgrade. Earlier version-specific results above describe historical checks.

Task-12 validation under 0.4.14: 276 supported assertions, 278 passing CTest entries, empty discrepancy manifest, fresh native/Godot bindings, and sanitized full-game/shooting replay and mutation checks. The enlarged Godot harness needs `--timeout 300`; consult ROADMAP.md for paths and scope. Replay `deployment-search-lifetime.bin` as well as the original geometry input with leak detection enabled. A shooting `.bin` file requires the fuzzer built from that shooting example, not the full-game root.

Current numeric-storage follow-up: state/observation schemas **12**, action **8**; 281 assertions / 283 CTest entries pass. Paths and terrain corners are stored in whole quads, so fixtures must no longer write micrometre values into those fields. Run the ML check and require no not-tensorable warnings; Hidden<Float> game data is also prohibited by source guidance. See [the report](../doc/bounded-numeric-storage.md) for checked storage limits, offset metadata, exact segment calculations and versioned artifact paths.

## Charges (task 13)

State/observation schemas are **13**, action schema **9**. The current CTest suite has **311 supported assertions and 313 entries**, including two compilation fixtures; the discrepancy manifest remains empty. Thirty new charge cases cover declarations, failed/cancelled attempts, pair re-rolls, post-roll/multiple targets, per-model path lengths and final approach obligations, detours, flight/Hover, Aircraft, Super-heavy Walker exclusions, both Heroic modes/costs and pending-save/malformed-data handling.

Use `/workspace/4hammer-validation/task13-tests` for the prepared tests-only build and `task13-godot` for matching native/header/C++ bindings. The headless Godot harness additionally exercises charger/target/model clicks, two targets and a saved staged charge path. Run it with `--timeout 300`; production Rules.gd and TraceManager.gd remain unchanged. The matching sanitized executable is `task13-fuzzer`; keep leak/precondition/bounds checks enabled and replay both preserved lifetime inputs before mutation fuzzing. See ROADMAP.md and [the charge report](../doc/charges.md) for final results and remaining geometry/Fight/stratagem/data scope.
