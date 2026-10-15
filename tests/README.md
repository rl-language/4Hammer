# Rule validation baseline

The deterministic tests are Rulebook functions compiled into a native library.
CMake discovers their declarations and a small C executable calls one assertion
per CTest process. There is no Python runner, wrapper generation/import, or
Python runtime dependency in this test path.

## CMake / CTest

Use a tests-only configuration to avoid Godot, SDK downloads and web builds:

```bash
source /workspace/4hammer-venv/bin/activate
cmake -S . -B build-tests -DBUILD_GAME=OFF
ctest --test-dir build-tests --output-on-failure -j 4
```

Use CMake/CTest 3.20+ for the commands shown (`--test-dir`); configuration needs
3.19+ for JSON manifest validation. Put compiler/core **0.4.18** on PATH, or set
`-DRLC_TEST_COMPILER=/path/to/rlc`. CMake does not find or launch a Python
interpreter. The activated environment above supplies the compiler and CMake.
Each compilation uses four workers; change this with
`-DRULE_TEST_COMPILER_JOBS=N`. Debug tests are unoptimized. Set
`-DRULE_TEST_OPTIMIZE=ON` only for optimized validation. An explicit linker can
be supplied with `-DRULE_TEST_CLANG=/path/to/clang`. CTest process parallelism
(`ctest -j`) is separate from compiler workers.

`ctest -N --test-dir build-tests` lists **1,191 entries**:1,190 assertions and
one compilation fixture. `ctest --test-dir build-tests -R test_timing_opponent_charge --output-on-failure` selects one case. Labels `baseline`, `discrepancies` and
`expected-failure` allow filtering with `-L`. CTest includes the compilation
fixture for filtered runs. That fixture builds the native runner and suite with
normal CMake dependencies and precondition/bounds checks; unchanged sources
need no recompilation. No separate compilation cache is added. Linkage verifies
that every discovered test symbol exists. Each assertion runs in isolation; a
crash fails its test. A failed fixture blocks its assertions.

The discrepancy manifest is empty. Recorded false discrepancy assertions return
77 and appear as **Skipped / XFAIL**, never semantic passes. Unexpected passes,
false supported assertions, crashes, malformed declarations, manifest mismatches
and build failures fail validation. Promote fixed discrepancies into the
baseline and remove their manifest entries. Empty suites have no fixture.

CTest also works with `BUILD_GAME=ON` (the default), and Make/Ninja support
`cmake --build build-tests --target test`. CMake itself has no `--test` command.
Reconfigure after changing declarations or the manifest; builds also track them
for regeneration. Outputs stay in the chosen build directory. The former
Python test runners have been removed. Python tools below exercise separate
host/ML integrations and source audits; they do not execute this native suite.

The six `test_procedures_*` assertions cover shared resource/reroll, granted
movement and healing/return operations with non-Orks fixtures. Their generated
host contexts and position payload also have a focused Godot check:

```bash
python tools/check_godot_state.py --build-path /path/to/matching/native/bindings \
  --script tests/godot_shared_procedures.gd --timeout 120
```

Generate both native bindings and headers at state/observation40, action26
(next-state41). This is a host integration check, separate from native CTest.

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

The former Python interpreter selection described by earlier validation records has been removed from the native CTest path; configure the compiler using `RLC_TEST_COMPILER` instead.

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


## Fighting (task 14)

Current schemas: state/observation **14**, action **10**. The suite contains **345 supported assertions / 347 CTest entries**, with an empty discrepancy manifest. Prepared builds are `/workspace/4hammer-validation/task14-tests`, `task14-godot` and `task14-fuzzer`. The 34 focused Fight cases also pass the native sanitized driver in `task14-sanitized-fight-tests` with leak detection enabled.

The Godot regression covers closest-target choices, staged Pile In save/restoration, alternating fights and retained-unit Fight on Death. Use an explicit extended timeout for the enlarged harness. Keep both preserved lifetime regressions, fixed replays and mutation campaigns distinct. The 920-action full-game seed contains no selected fights; focused cases and the Godot fixture establish Fight behavior. See [the Fight report](../doc/fighting.md) and ROADMAP.md for final evidence, preserved-grid limits and remaining integration owners.


## Core stratagems and actions (task 15)

Current schemas: state/observation **15**, action **11**. **382 supported assertions / 384 CTest entries** pass with an empty discrepancy manifest. The 37 focused core cases also pass the standalone native sanitized driver in `/workspace/4hammer-validation/task15-sanitized-core-tests` with leak detection enabled. Prepared test/binding builds are `task15-tests` / `task15-godot`; use an explicit extended timeout for the enlarged headless editor harness.

The Godot checks exercise Explosives source/bearer/target controls, post-charge Crushing Impact, Epic Challenge's character and Counteroffensive's constrained selection. Its independent fixtures explicitly reset usage before the older CP-reroll scenario; do not interpret those resets as permitted gameplay. Fixed arrays need the bounded `command_points_for_player` accessor. Sibling persistent action arguments need unique field names for generated C++.

Use `task15-final-fuzzer` for matching instrumented replay/mutation checks. Both preserved lifetime inputs, fixed zero input and the 920-action current-schema full-game replay pass; the fresh campaign completes 58 runs in 64 seconds without artifacts. The full-game seed contains no selected fights/new core card activations; deterministic cases and Godot fixtures establish those rules. Gym checks 20 steps, 20,516 candidates and 9,351,760 finite observations without tensor warnings. See [the core report](../doc/core-stratagems-actions.md) and ROADMAP.md for limits and mandatory transport/mission/data/UI/performance follow-ups.

## Orks configuration (batch 17.B)

Schemas are state/observation **17**, action **13**. The suite has **442 supported assertions / 444 CTest entries**, with an empty discrepancy manifest. Prepared builds are `/workspace/4hammer-validation/task17b-tests`, `task17b-godot`, `task17b-sanitized-tests` and `task17b-fuzzer`. Sixteen focused native assertions include malformed configuration saves, point-free carriers/passengers and shocked/destroyed CP targets; require leak detection as well as address/undefined-behavior checks.

The full headless Godot harness passes, beginning with both players selecting independent packages through actual enum buttons, duplicate rejection and pending selection restoration. Use an explicit extended timeout for the existing large binding suite (`--timeout 1200` for this batch). Matching full-game seed40000 now selects Orks detachments and point-free reserves; regenerate old legal-choice replays after the action/schema change. See ROADMAP.md and [the configuration report](../doc/orks-configuration.md) for final validation and the remaining faction-rule batches.

## Orks keyword predicates (batch17.C1)

Current schemas are state/observation **18**, action **14**. The suite has **465 supported assertions /467 CTest entries**, with an empty discrepancy manifest. Prepared tests are `/workspace/4hammer-validation/task17c1-tests`; the final focused native sanitizer driver in `task17c1-sanitized-tests` passes24 cases with leak detection. Use `task17c1-final-godot` for matching final native/header/C++ bindings.

The complete headless interaction harness passes for the compact layout; a later body-only temporary-ANTI filter fix has dedicated final-binding coverage:

```sh
python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task17c1-final-godot --script tests/godot_keyword_predicates.gd --timeout 120
```

Omitting `--script` runs the full existing interaction harness; use an explicit extended timeout. Replays must match the removed old action payloads and schema14. See [the predicate report](../doc/orks-keyword-predicates.md) and ROADMAP.md for final fuzzer evidence, layout measurements and pending17.C2–C4 mechanics. Predicate completion does not certify any Orks datasheet.

## Model characteristics (batch17.C2a)

Schemas are state/observation **19**, action **14**. The final suite passes **477 supported assertions /479 CTest entries**, with an empty discrepancy manifest. Compilation fixtures allow600 seconds; individual assertions keep30 seconds. Prepared tests are `/workspace/4hammer-validation/task17c2-model-tests`; the final native sanitizer driver is `task17c2-model-sanitized/driver-final`, with12 cases and leak detection.

Matching final native/header/C++ bindings are in `task17c2-model-final-godot`. Run the affected model/query/allocation bridge checks with:

```sh
python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task17c2-model-final-godot --script tests/godot_model_characteristics.gd --timeout 120
```

The existing focused keyword script also passes with this build. The full interaction harness was not rerun for this batch. Use `task17c2-model-final-fuzzer` for preserved inputs and current-schema game replay; the mutation campaign passes51 runs in64 seconds. See [the report](../doc/model-characteristics.md) and ROADMAP.md for provenance and remaining weapon/named selector scope.

## Fixed weapon characteristics (batch17.C2b1)

Schemas are state/observation20, action14. The final suite has **497 assertions /499 CTest entries**, with an empty discrepancy manifest. Reconfigure CMake when adding tests so the new functions register individually; compilation fixtures remain600s and assertions30s. Prepared tests are `/workspace/4hammer-validation/task17c2b1-tests`; the final20-case sanitizer driver is `task17c2b1-sanitized/driver-verified`.

Matching native/header/C++ artifacts are in `task17c2b1-verified-godot`:

```sh
python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task17c2b1-verified-godot --script tests/godot_weapon_characteristics.gd --timeout 120
```

The prior model script also passes against this build. Full rendered/interaction journeys were not rerun. Use `task17c2b1-verified-fuzzer` for preserved inputs/schema20 game and final mutation checks. See [the report](../doc/weapon-characteristics.md) and ROADMAP.md for measured layout, provenance and pending A/D/named-selector scope.

## Attacks and Damage (batch17.C2b2)

Schemas are state/observation21, action14. Final CTest passes509 assertions /511 registered entries with an empty discrepancy manifest. Configure after the complete test list is frozen; do not add declarations while the compilation fixture is running. Prepared tests are `/workspace/4hammer-validation/task17c2b2-tests`, and the12-case native sanitizer driver is `task17c2b2-sanitized/driver-final`, with leak detection enabled.

Matching native/header/C++ artifacts are in `task17c2b2-godot`. Run the weapon and model scripts as above with this path; both pass. The weapon script also checks actual A/D modifier APIs. Full rendered/interaction journeys were not rerun. Use `task17c2b2-fuzzer` for preserved-input, game-replay and mutation checks. See [the A/D report](../doc/weapon-attacks-damage.md) and ROADMAP.md for exact provenance and remaining named/source-dependent modifiers and datasheets.

## Named selectors (batch17.C2c)

Schemas are state/observation22, action14. Final CTest passes534 assertions /536 registered entries with an empty discrepancy manifest. Prepared tests are `/workspace/4hammer-validation/task17c2c-final-tests`; the25-case native sanitized driver is `task17c2c-final-sanitized/driver`, with ASAN/UBSAN and leak detection.

Matching native/header/C++ artifacts are in `task17c2c-final-godot`. The focused `tests/godot_named_identities.gd` and prior weapon script pass against that build; use `--timeout 120`. The new script uses a generic fixture with existing physical profile groups and typed identity bridges, since fixed-array getters are not exposed. Full interaction/rendered journeys were not rerun. Use `task17c2c-final-fuzzer` for final replay/mutation checks. Earlier `task17c2c-*` builds without `final` predate the ranged/melee catalog correction and are superseded. See [the report](../doc/named-selectors.md) and ROADMAP.md for remaining data/source owners.

## Damaged (batch17.C3)

Schemas are state/observation23, action14. Twelve focused regressions cover bearer thresholds, modifier order, live group refresh, retained models, Firing Deck, grouping, saves, real hit batches and Torrent. Final CTest passes546 assertions /548 entries in `task17c3-final-tests`; all12 native cases pass in `task17c3-sanitized/driver-verified` with ASAN/UBSAN/leak detection. Use `task17c3-fuzzer` and the final verified replay/mutation evidence in ROADMAP.md; earlier runs with fixture errors are superseded.

Matching bindings are in `/workspace/4hammer-validation/task17c3-godot`. Run `tests/godot_damaged.gd` or the prior weapon script with `tools/check_godot_state.py --timeout 120`; both pass. Full interaction/rendered journeys were not rerun. The model's threshold is explicit metadata, not an automatic grant to current legacy profiles. See [the report](../doc/damaged.md) for source authority and pending data/ignoring consumers.


## Incoming AP/D (batch17.C4a)

Schemas are state/observation24, action14. Twelve new regressions cover ranged/melee and bearer separation, shared arithmetic/floors/zero lock, AP/InSv/natural one, actual normal saves/damage, Devastating/random D after allocation, non-attack mortals, pre-rounding attack identity, printed mixed allocation groups, restore validation and save round trips. Final CTest passes558 assertions /560 entries in `task17c4a-final-tests`;12 native sanitizer cases and matching focused Godot checks pass. ROADMAP.md records the final878-action completed game,20-step Gym, fixed replay and31-run mutation evidence. Matching bindings are in `task17c4a-godot`; run `tests/godot_incoming_modifiers.gd` with `tools/check_godot_state.py --timeout 120`. Use `task17c4a-fuzzer` and `task17c4a-sanitized/driver` for sanitizer checks.

These are engine fixtures, not installed current Orks profiles. Selective modifier ignoring is17.C4b; source grants and duration/expiry retain their later owners.


## Shared physical weapons/source effects (17.D/E)

The user requested a shared final validation build. Schemas are state/observation25, action15.38 new regressions cover physical capacity/copy/profile permissions, Hazardous, compound A/D/M/demise/re-rolls/codecs, source ownership/mandatory choices/shared limits, all interval durations, live auras, named grants, transfer/compaction, banks/archives, real event hooks and source save validation. ROADMAP.md records final evidence and superseded runs.

Final0.4.17 CTest is `/workspace/4hammer-validation/task17de-compiler17-tests` (598/598 pass). The focused native fixture/driver is `task17de-sanitized`; use the final library/driver named in the roadmap, since earlier0.4.16 capacity fixtures hit a compiler cleanup defect around direct constant loop bounds/Boolean expressions and leaked despite semantic passes. RLC0.4.17 fixes the standalone reproduction; the final fixtures retain ordinary generated cleanup without workarounds. All38 native cases pass both `task17de-sanitized/driver-debug17` (unoptimized) and `driver-optimized17`, with leak detection. Matching native/header/C++ artifacts are `task17de-compiler17-godot`; run `tests/godot_weapons_sources.gd --timeout 120` with the standard binding helper. It exercises13 profile slots, compound inputs, actual source choice methods and production buttons/labels, plus phase expiry. The final `task17de-compiler17-fuzzer` passes preserved/game inputs and41 mutation runs; use ROADMAP.md for exact scope/artifacts. MultipleChoises adds explicit bounded source buttons. Full rendered journeys remain17.Q.

Current unit/ability adapters remain later source-data batches; the framework fixtures are explicit.17.C4b optional modifier subsets remain pending after the user's changed priority.


## Optional WS/BS and hit modifiers (batch17.C4b)

Current CTest is `/workspace/4hammer-validation/task17c4b-tests`:621/621 pass,619 supported assertions and two compilation fixtures. The23 `test_ignore17c4b_*` regressions cover all subsets, per-attack decisions, beneficial ignoring, arithmetic/provenance, natural gates, re-roll order, controller restoration, grouping, borrowed bearer permissions, source expiry/archives and saved continuations. [The report](../doc/modifier-ignoring.md) distinguishes generic core support from current datasheet adapters.

The final unoptimized ASAN/UBSAN/leak driver is `task17c4b-sanitized/driver-final`; all23 cases pass with leak detection. Matching artifacts are `task17c4b-godot`; run `python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task17c4b-godot --script tests/godot_modifier_ignoring.gd --timeout 30`. It checks generated one-Bool payloads and the production Apply/Ignore panel. Existing source/weapon binding checks also pass. Full rendered journeys remain17.Q.

The optimized sanitized `task17c4b-fuzzer` passes preserved lifetime inputs, zero input and the prior completed game; fresh short-seed fuzzing completes43 runs in63s without sanitizer failures or crash artifacts. Legacy roster games do not exercise new optional permissions; focused native/Godot fixtures establish that behavior. Schemas26/16/26 (next27) require matching policies/bindings. Fresh seed40000 completes878 actions, terminal owner-4, with input bytes matching that sanitized replay (`task17c4b-gameplay.log`, `task17c4b-replays`). Next is17.F; Forge World/Legends adapters are excluded.


## Orks army-rule consumers (batch17.F)

Current CTest is `/workspace/4hammer-validation/task17f-tests`:650/650 pass,648 supported assertions and two fixtures. The29 `test_orks17f_*` cases cover current Waaagh/riled/War Cry/Da Boss and the supplied Warlord definition; [the report](../doc/orks-army-rules.md) records source/provenance and current-data boundaries. The final unoptimized ASAN/UBSAN/leak driver is `task17f-sanitized/driver-final`; all29 pass with leak detection.

Matching artifacts are `task17f-godot`; run `python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task17f-godot --script tests/godot_orks_army.gd --timeout 30`. It checks real child methods, production Warlord/timing buttons, offboard click suppression and status/CP. Previous modifier/source checks also pass. The harness frees its owned RLCLib Object and defers quit; a leak warning remains a failure.

The optimized `task17f-fuzzer` passes preserved/zero/completed-game inputs and43 fresh mutation runs in64s without sanitizer failures or crash artifacts.20-step Gym is finite with22,746 candidates and26,128,335 observations; schemas27/17/27 (next28). Full rendered journeys and wrapper performance remain17.Q. Fresh seed40000 completes878 actions, terminal owner-4, with identical bytes to the sanitized replay (`task17f-gameplay.log`, `task17f-replays`). Actual current unit profiles/abilities are not installed by these fixtures. Next17.G covers Orks Leader/Support mechanics; Forge World/Legends stay excluded.


## Attachment mechanics and included Orks lists (batch17.G)

Current CTest is `/workspace/4hammer-validation/task17g-tests`:684/684 pass,682 assertions plus two fixtures. The34 `test_attachment17g_*` cases cover exact roles/permissions, both slot orders, ownership/capacity rejection, provenance, mixed keywords/T, source destruction/return, deferred cleanup, merged model/unit death, Warlord/One Shot saves and Painboss bearer-only arithmetic. [The report](../doc/attachments.md) distinguishes metadata/engine support from actual current profiles and revival/setup. The unoptimized ASAN/UBSAN/leak driver `task17g-sanitized/driver-final` passes all34.

Run the independent inventory cross-check without recompilation:

```sh
python tools/check_orks_attachment_permissions.py --wrapper /workspace/4hammer-validation/task17g-tests/rule-tests/baseline/wrapper.py
python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task17g-godot --script tests/godot_attachments.gd --timeout 45
```

The inventory check validates all67 identities,10 Leader/seven Support cards,41 permission edges and13 excluded cards against the compiled implementation. Matching Godot tests validate the actual child frame, source-first reserve pair, production labels and click suppression. Prior army/Warlord and weapon/source tests pass. The broad `godot_state.gd` now uses explicit attachment metadata for its pending-pair fixture; its documented large-journey timeout is1200s. A45s exploratory run timed out, so no full broad journey is claimed for this batch. The focused pending-root-save subset is recorded in ROADMAP.md.

The optimized sanitized `task17g-fuzzer-final` passes preserved lifetime/zero/fresh-game inputs,45 fresh mutation runs in61s and the new1,000-action seed40000 game. The matching fresh input separately replays in49.260s; no controlled performance comparison is claimed.20-step Gym is finite with22,746 candidates and26,183,041 observations; schemas28/18/28 (next29). Full rendered journeys/wrapper retrieval remain17.Q. Other faction permissions, current Orks profiles/grants and actual revival/setup remain separate owners. Next17.H; exclude Forge World/Legends.


## Current Orks data and loadouts (batch17.H1)

Current CTest is `/workspace/4hammer-validation/task17h1-tests`:709/709 pass,707 assertions plus two fixtures. The25 `test_orks17h1_*` cases cover current profiles, composition/equipment checks, Hunter/conditional combat consumers, shared physical weapons, attachment/saves and explicit oval guards. The unoptimized ASAN/UBSAN/leak driver `task17h1-sanitized/driver-final` passes all25. [The data report](../doc/orks-current-unit-data.md) distinguishes current data from pending special abilities, oval support and roster promotion.

Cross-check compiled statistics against the cached original HTML, without recompilation:

```sh
python tools/check_orks_unit_tables.py --wrapper /workspace/4hammer-validation/task17h1-tests/rule-tests/baseline/wrapper.py --source-dir /workspace/4hammer-validation/orks-audit-2026-10-12/sources
python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task17h1-godot --script tests/godot_orks_unit_data.gd --timeout 45
```

The HTML check passes3 cards/five profiles/13 printed weapon rows, including separate invulnerable-save boxes omitted by text extraction. Semantic/native tests cover FNP, keywords, equipment and target conditions separately. Matching Godot checks pass current constructors/labels/attachments/oval guards/root saves; prior attachment and weapon/source controls also pass. Full broad/rendered journeys remain17.Q.

The optimized sanitized `task17h1-fuzzer` passes preserved lifetime, zero and completed-game inputs and31 fresh mutation runs in66s without sanitizer failures/artifacts.20-step Gym passes22,746 candidates/26,183,041 finite observations. Schemas29/18/29, next30, require matching bindings/policies despite unchanged tensor dimensions. A fresh1,000-action game completes with input bytes matching the sanitized replay; the public roster remains legacy until17.H4. ROADMAP.md records final logs and scope. Next17.H2 implements the special abilities;17.H3 owns oval geometry. Forge World/Legends remain excluded.


## Combined current Orks abilities and circle proxies (17.H2/H3)

Current discovery has738 assertions/740 entries in `/workspace/4hammer-validation/task17h23-tests`. Initial full execution passes739/740; the updated circle-placement fixture incorrectly used an opposing deployment zone. After correcting its anchor, all58 affected entries pass (57 assertions plus compilation). These results cover every registered assertion across the two runs; no full740/740 rerun is claimed. The31 new `test_orks17h23_*` cases cover source windows/limits/targets, actual move/charge hooks, hit/damage/shock consumers, FNP/spill, owner restoration, saves and proxy edges/overlap/rotation/movement. [The report](../doc/orks-current-unit-rules.md) records printed rules and user-approved approximation limits.

The unoptimized ASAN/UBSAN/leak driver `task17h23-sanitized/driver-final` passes all56 current-data/ability cases with leak detection. If sandbox process inspection blocks LeakSanitizer, run the same binary through the permitted outside-sandbox execution flow; do not disable leak detection. Matching pure native/header/C++ bindings are `task17h23-godot`:

```sh
python tools/check_orks_unit_tables.py --wrapper /workspace/4hammer-validation/task17h23-tests/rule-tests/baseline/wrapper.py --source-dir /workspace/4hammer-validation/orks-audit-2026-10-12/sources
python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task17h23-godot --script tests/godot_orks_unit_rules.gd --timeout 45
python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task17h23-godot --script tests/godot_orks_unit_data.gd --timeout 45
```

The HTML check passes3 cards/five profiles/13 weapon rows. New source-choice and prior data/attachment/ignoring/weapon-source Godot controls pass. CTest's Python-linked --pylib native library requires Python symbols and is not a direct substitute for Godot's pure native build; compatible Python wrappers can still be reused for Gym/gameplay without recompiling.

Schemas30/19/30, next31, require matching bindings/policies.20-step Gym passes22,907 candidates/28,980,462 finite observations; coordinate domains are unchanged. Fresh legacy-roster gameplay completes1,000 legal actions and its matching optimized sanitized `task17h23-fuzzer` replay passes, alongside both lifetime inputs/zero input. Fresh mutation completes20 runs in66s without failures/artifacts. Native/Godot fixtures cover actual current abilities; production roster promotion remains17.H4 and broad/rendered/performance validation remains17.Q. Follow the user's combined-task workflow: complete both related edits and fixtures before costly builds, then rerun only checks affected by corrections.


### Current Orks roster and War Horde passive (17.H4/17.I1)

See [the roster/passive guide](../doc/orks-roster-war-horde.md) and ROADMAP.md.
The new17 assertions cover public current-roster/Warlord/formation/save flow and
Get Stuck In ownership, keyword/profile/package gates, duplicate choices, actual
weapon declaration and critical-hit resolution. The new Godot control check is:

```bash
python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task17h4i1-godot --script tests/godot_orks_roster.gd --timeout 180
```

The enlarged production selection/save journey exceeded the initial60-second
budget on this machine; the corrected180-second run passes. Formation choices
alternate after each action, including a successful attachment, rather than
only after each player's finish choice. Never insert an extra finish before
the opponent's immediate attachment decision.

Fresh matching bindings use state/observation31 and action19. Three affected
Godot controls, independent HTML tables and the20-step ML check pass; the latter
retains22,907 candidates and28,980,462 finite observations. Exact rendered/mouse
journeys and the known wrapper-performance work remain17.Q. Read the roadmap
for full/affected CTest,17-case native sanitizer/leak and actual-roster complete
game/fuzzer evidence; do not describe a partial rerun as a second full suite.

### Large debug suites

CTest compiles only suites that contain assertions. An empty known-discrepancy
manifest no longer triggers a second full-engine compilation. Compilation
fixtures use `RULE_TEST_COMPILE_TIMEOUT` (default1200 seconds); override it at
CMake configuration when the native debug build needs longer. Individual
assertions retain their30-second timeout. `RULE_TEST_COMPILER_JOBS=4` keeps the
requested compiler parallelism; `RULE_TEST_OPTIMIZE` remains off for debugging.
Run large native builds separately when concurrent compilers exceed available
memory. A compilation timeout or killed compiler leaves its assertions unrun,
not passed.


### Twelve-unit Orks sweep (17.P1)

There are931 assertions/932 registered entries. ROADMAP records930 initial
full-suite passes plus the corrected59-case native ASAN/UBSAN/leak suite,
including59 individual CTests; do not claim a second full-suite run. The single
initial failure was an incorrect expected absence of Shoota's printed conditional
Lethal Hits. The corrected target query passes against the compiled game and
in the final native suite. No game rule was weakened or test disabled.

Artifacts are `/workspace/4hammer-validation/orks-p1`: `tests` for the full
CTest fixture, `sanitized` for the final unoptimized59-case driver and CTest
registration, `godot` for matching header/C++/debug-native bindings, `fuzzer`
for the optimized fixture-assisted engine and separate semantic/action corpora.
The Godot artifact reuses the Python-linked debug engine with explicit matching
libpython3.12 linkage; sanitizer-library loading is incompatible with Godot's
RTLD_DEEPBIND. Keep native ASAN/UBSAN/leak checks separate; no sanitizer is disabled.

```sh
python tools/check_orks_unit_tables.py --wrapper /workspace/4hammer-validation/orks-p1/tests/rule-tests/baseline/wrapper.py --source-dir /workspace/4hammer-validation/orks-audit-2026-10-12/sources
python tools/check_godot_state.py --build-path /workspace/4hammer-validation/orks-p1/godot --script tests/godot_orks_infantry.gd --timeout 120
```

All15 cards/20 profiles/79 rows are checked from original HTML; the59 semantic
cases cover source-specific behavior. This validates adapters and host APIs;
full public roster selection of these units remains17.Q. Use ROADMAP for the
completed game, fixed replays,265 semantic-seed runs and78 action-mutation runs,
coverage and diagnostic limits. Action/schema33/21 regeneration adds six Bool
candidates and leaves coordinate bounds unchanged.


## Current native Orks adapter validation —17.P2

The Python migration was reverted at the user's request. Tests remain native
Rulebook functions in `baseline.rl`, compiled once per CTest fixture and shown
as individual cases. No new build cache is introduced. Compiler/core0.4.18
support the verified four-worker parallel builds; debug tests remain
unoptimized, with separate optimized sanitizer/fuzzer validation.

Current discovery is995 entries:994 assertions and one nonempty-suite build
fixture, with no discrepancies. All994 final-source assertions pass. The
fourteen-card guide and latest ROADMAP section record the29-card HTML check,
63 native sanitizer cases, Godot controls, frame/ML checks and fuzzer scope.
Keep matching native/header clients for schema34/22/34 (next35). Broader
rendered integration and the known wrapper/runtime performance work remain17.Q.


### Sanitizer source diagnostics without llvm-symbolizer

On the prepared Linux environment, GNU `addr2line` is available even when
`llvm-symbolizer` is not. Use the explicit supported sanitizer configuration:

```bash
ASAN_OPTIONS=detect_leaks=1:allow_addr2line=1:external_symbolizer_path=/usr/bin/addr2line \
  /path/to/rules_fuzzer corpus -max_total_time=60
```

This preserves ASAN/UBSAN/leak instrumentation and supplies source/function
names for failures. The17.Q validation verified it with an isolated intentional
use-after-free probe: the report identifies the probe function and exact source
line. That expected diagnostic-probe failure is not a game regression failure.
Keep actual game inputs and semantic tests separate from such tool checks.

### Public roster and shared bank checks

The79 added17.Q assertions remain native Rulebook functions in `baseline.rl`.
They cover all54 roster adapters and common own-unit rules in battlefield,
reserve and embarked storage. No Python test migration or compilation cache is
introduced. Use the normal CTest fixture to build the native library and C runner. It does
not generate or import a Python wrapper; normal CMake dependencies avoid
recompiling unchanged sources.

New headless scripts are `godot_orks_custom_roster.gd`,
`godot_shared_bank_rules.gd` and `godot_string_ownership.gd`. The bank script
checks the shared mortal payload, actual reserve/passenger contexts, labels and
click suppression. The string probe checks UTF-8/empty values and10,000 native
conversions. The broad script reads the shared hit-dice collector rather than
the retired nested hit frame. Use matching state/observation37 and action24 artifacts; the
earlier host-validation artifacts reused a Python-enabled debug library; the
current native CTest library and runner have no libpython dependency.


### Native CTest runner validation —2026-10-15

All1,184 assertions plus the build fixture pass through the C runner. The fresh
unoptimized-j4 build takes342.76s; the complete CTest run takes354.69s. A filtered
repeat includes the fixture and takes0.16s without recompilation. CMake discovers
all declarations without an interpreter; the fixture produces no Python wrapper.
`ldd` and native undefined-symbol inspection confirm no libpython/Python symbols;
a shared-bank case also passes with an empty environment and no Python on PATH.

Isolated tiny Rulebook fixtures outside the checkout verify PASS, FAIL, crashes,
XFAIL77, XPASS failure, unknown-name rejection, manifest/signature rejection,
build-failure blocking and filtered-fixture inclusion. They intentionally fail
where required to verify the runner's contracts; these are not game test failures.
The three old Python test runners have been removed. Host/ML integration and
source-audit tools remain separate from the pure Rulebook CTest execution path.
