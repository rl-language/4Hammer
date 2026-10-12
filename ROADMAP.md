# 11th-edition rules migration roadmap

This roadmap tracks planning and implementation separately. Tasks 1–5 and 7–8 are complete; task 6 is deferred by the user until full unit datasheets are supplied; task 9 is complete; task 10 is complete within the deferred attachment/transport scope and task 11 is complete within the preserved-grid and deferred-data scope; task 12 is complete within the deferred-data and preserved-grid scope; tasks 13–17 remain pending. Task 8 is complete within the user-approved area-only visibility abstraction below. Update task status and record evidence as work is completed; do not mark a task complete merely because it compiles.

User constraint: retain the quad-based game throughout this migration. A change to non-quad coordinates is a separate future task requiring explicit instruction. Base-aware physical measurements do not authorize fractional model positions, new coordinate action domains or changes to Godot's grid interactions.

The migration changes the game's state and action sequence as well as individual rule calculations. The largest changes are declaring attacks before resolving them, allocating damage to save groups, choosing charge targets after rolling, and separating the Fight phase into distinct steps.

Use [the procedural reference](doc/11th-edition-core-rules-procedural.txt) as the specification. Its reproduced source wording takes precedence over its editorial summaries. Page citations below refer to the original core rulebook. Each task must produce page-linked regression tests alongside the eventual implementation.

## Tasks

| # | Status | Task | Scope and acceptance criteria |
| --- | --- | --- | --- |
| 1 | Complete | Create a rule coverage map | Map every source subsection to existing code, required changes, tests, and missing systems. Identify rules requiring external mission, faction or app definitions. Record ambiguities explicitly rather than inventing resolutions. |
| 2 | Complete | Establish the validation baseline | Create a deterministic test entrypoint and capture current scenarios before changing behavior. Prepare Clang for the sanitized fuzzer; it was missing when this plan was written. Separate existing defects from edition changes. |
| 3 | Complete | Update state and identity foundations | Review bounded capacities, persistent unit/model identity, attachment provenance, phase history and once-per-battle state. Prevent removals from redirecting stored targets and prevent bounded values from silently truncating valid game state. Version affected saves, traces and observations. |
| 4 | Complete | Define geometry and movement primitives | Implement the new engagement and coherency distances, individual model movement primitives, placement and path checks (pp. 12–15) within the existing whole-inch quad grid. Preserve BoardPosition action domains and Godot grid interactions; do not introduce fractional model positions or migrate away from quads. Account for base sizes in measurements and document tabletop geometry the grid cannot express. Test distance boundaries. Completion requires regression, binding and fuzzer validation. |
| 5 | Complete | Rebuild timing and decision ownership | Add explicit phase/turn start and end windows, active/opposing controller changes, and correctly classified chance decisions (pp. 8–9, 28–30). Centralize CP spending and stratagem eligibility, including per-player and per-unit restrictions (pp. 54–57). |
| 6 | Deferred | Rework attachments and unit characteristics | Implement Leader/Support attachment rules, combined starting strength, bodyguard toughness, keyword inheritance and ability lifetime (pp. 66–67, 86–88). Test what survives when bodyguards or attached characters die. New faction attachment permissions require supplied data. |
| 7 | Complete | Correct Command phase and Battle-shock | Implement the prescribed order, Leadership selection, at-or-below-half checks, persistent shock and its restrictions (pp. 8–9, 28–30). Test odd starting strengths, single-model units, already-shocked units and successful recovery. |
| 8 | Complete (user-adjusted scope) | Implement terrain, visibility and objective control | Implement terrain areas, category flags, BS cover and Hidden (pp.46–51). Under the user's explicit abstraction, area crossings give partial obscuration and physical visibility is assumed; physical features, exact obscuring/Solid LOS and feature traversal are deferred. Sum eligible OC, apply boundary control/ties/securing and marker range (pp.52–53,88). Keep mission scoring separate. |
| 9 | Complete | Replace the attack declaration and dice pipeline | Declare weapons and targets before resolution, support split attacks, form permitted attack groups, and implement hit/wound/critical rules (pp. 16–23). Test exact Strength/Toughness thresholds and declarations whose targets change during resolution. |
| 10 | Complete | Replace saves, damage and destruction | Implement save groups and their priority, simultaneous save rolls processed in ascending order, armour/invulnerable comparisons, Precision, normal-before-mortal damage, Feel No Pain, Hazardous and destruction timing (pp. 19–24, 78–88). Test mixed characters, wounded models and group changes during a batch. |
| 11 | Complete (preserved-grid scope) | Update movement and deployment systems | Implement Normal, Advance, Remain Stationary, Fall Back, Ordered Retreat and Desperate Escape (pp. 32–33). Add reserve entry/removal, repositioning, Scouts, Deep Strike, surge and flying movement (pp. 68–71, 78–85). Replace the remaining anchor-only deployment/reserve predicates with checks on every base, and provide an independent model-path decision workflow compatible with Godot. Test placement boundaries and round restrictions. |
| 12 | Complete within deferred-data scope | Update Shooting phase and weapon abilities | Implement normal, assault, close-quarters and indirect modes; engaged Monster/Vehicle shooting; and the revised weapon abilities (pp. 34–35, 62–63, 78–85). Maintain a checklist covering every published core ability, including currently absent ones. |
| 13 | Complete within preserved-grid scope | Replace the Charge sequence | Select the charging unit, roll, then select legal targets and perform the constrained movement (pp. 36–37). Support multiple targets and successful-charge Fights First. Test failed charges, prohibited chargers and incidental engagement with unselected enemies. |
| 14 | Complete within preserved-grid scope | Replace the Fight phase workflow | Implement phase-wide Pile In, alternating fights with the correct starting player, changing eligibility/Fights First, and phase-wide consolidation (pp. 38–43, 87). Test Overrun, newly engaged units and legal passing. |
| 15 | Complete within deferred-data/visibility scope | Implement the revised core stratagems and actions | Implement each core stratagem's exact cost, timing, targets and effects (pp. 54–58). Include end-of-opponent-Movement Overwatch and end-of-Charge Heroic Intervention. Implement generic action eligibility without inventing unavailable mission actions. |
| 16 | In progress | Add transport and aircraft systems | Implement capacity, embarkation, disembarkation modes, emergency procedures, passenger/reserve interactions and Aircraft exceptions (pp. 64–65, 74). These are substantial new systems, not adjustments to existing functionality. |
| 17 | Pending | Integrate army data, Godot and full-game validation | Update supplied new-edition datasheets, faction rules and mission configuration. Regenerate bindings and exercise every changed action through Godot, Python and replay. Run deterministic scenarios, completed games and the sanitized fuzzer; turn every discovered failure into a regression case. |

## Dependencies and execution order

### Task 1 — complete: rule coverage inventory

The [rule coverage map](doc/11th-edition-rule-coverage.md) maps all 156 numbered subsections and 31 supplemental entries to inspected code, migration requirements, planned regression cases, task owners and source dependencies. It distinguishes partial behavior, conflicting behavior and missing systems; none is certified as new-edition compliant.

The [source excerpt ledger](doc/11th-edition-source-coverage.tsv) accounts for all 1,114 retained locators across 73 text-bearing pages, including worked examples, sidebars, appendix definitions and FAQs. The [reference inventory](doc/11th-edition-external-references.tsv) records 46 named cross-reference occurrences and distinguishes supplied definitions from missing app entries. Twelve source-uncertainty/dependency gates and a separate existing-defect/infrastructure register are in the coverage map.

Validation: checked numbered-ID completeness/uniqueness, defining pages/locators, full excerpt ownership, supplemental ownership, task/gate references and local code/document links. These are documentation checks; no game tests, GUI checks or fuzzer run were performed for task 1. Its listed semantic regressions were plans for later tasks.

### Task 2 — complete: validation baseline

Added [deterministic tests and usage instructions](tests/README.md), a runner that rejects zero-test success, an individually enumerated expected-failure manifest, seeded gameplay/replay checks, a 20-step gym check, and checksum-pinned local Clang preparation. [The baseline report](doc/validation-baseline.md) records evidence and separates existing defects from edition/source conflicts.

Results: 12 supported tests pass; 12 desired-rule assertions reproduce known failures (0 unexpected passes). Existing smoke checks ran 200 full-game actions and completed three shooting scenarios. Seed 40000 completes a full game in 376 actions and a shooting scenario in 11; both inputs replay successfully through the sanitized native fuzzer. JIT/gym completes 20 steps. The optimized/debug/precondition/bounds/sanitizer fuzzer builds and completes 640 mutation runs in 61 seconds without reported failures.

A newly reproduced existing defect makes fixed characteristics evaluate to zero, so shooting completion does not establish attack resolution. Known defects remain unfixed and semantic coverage remains limited. No Godot GUI, web or repository-wide CMake validation was performed; game sources and action signatures are unchanged. Native artifacts and logs are outside the checkout in `/workspace/4hammer-validation`. At baseline capture, the next step was task 3; its completed results are below.

### Task 3 — complete: state, identity and capacity foundations

Implementation and scope limits are recorded in [the state foundations report](doc/state-foundations.md). Completed:

- [x] Use standard bounded numeric storage for automatic ML-layout inference, with wider configured ranges covering CP, Advance and damage; keep action domains separate and reject collection overflow/oversized text decoding.
- [x] Add persistent unit/model identities, non-reused battlefield slots, destroyed-model archives and empty-slot selector guards.
- [x] Preserve attachment components/original-model provenance and capture combined starting strength after attachment.
- [x] Add turn/phase, setup, movement, attack/action and once-per-battle history carriers; preserve them through copies and saves.
- [x] Version state/actions/observations, reject incompatible/invalid engine saves transactionally and record replay schema metadata.
- [x] Promote CP/Advance and actual-cost/own-player-usage failures into passing regressions; fix expenditure prerequisites exposed by checked CP and Godot native build issues.
- [x] Validate deterministic tests, Python/gym, completed seeded scenarios, regenerated native Godot selectors/save loading and the sanitized fuzzer.

Evidence: 38 tests pass; 8 remaining expected failures and 0 unexpected passes. Seed 40000 completes a full game in 646 actions and shooting in 11; both replay through the final sanitized native fuzzer. Gym completes 20 legal steps with finite observations. Existing random smoke commands execute 200 bounded full-game actions and complete three shooting games (50 total actions). The fuzzer completes 376 runs in 61 seconds without reported failures or failure artifacts. Godot 4.6.3 passes the saved headless selector/state regression; interactive rendering and full combat GUI remain untested. The original task-3 schemas were version 2; the bounded-storage revision below records the current versions and checks.

#### Follow-up — bounded storage for ML inference

Removed the custom unbounded Quantity type at the user’s request. Numeric state now uses standard LinearlyDistributedInt ranges listed in [the state report](doc/state-foundations.md), preserving the tested capacity fixes and automatic ML-layout inference. Standard bounded arithmetic clamps at its configured edges; future supplied data must fit the documented ranges. State/observation schemas are 3; the unchanged action domain remains schema 2. The updated suite passes 43 tests with 8 expected failures and 0 unexpected passes. Gym completes 20 finite-observation steps with unchanged widths (7,469 actions, 149,836 observations); seeded full/shooting games complete in 646/11 actions. Matching regenerated native/Godot bindings pass the headless selector/save check; completed inputs replay successfully through the sanitized fuzzer. A fresh mutation campaign completes 363 runs in 61 seconds (coverage 6,681; feature count 21,781) without reported failures. Stable fixed/dice save tags fix RLC 0.3.3 indented type-name parsing without changing bounded ML storage, with two round-trip regressions.

Production changes to `scripts/Rules.gd` and `scripts/TraceManager.gd` were removed from this branch at the user’s request. Editor schema checks, trace compatibility, automatic load refresh and library ownership remain deferred to task 17; the headless harness checks engine loading and explicit state replacement and owns its cleanup.

State foundations do not complete tasks 4–17: exact geometry, attachment permissions/detachment, timing and usage restrictions, attack/save workflows, revival, One Shot enforcement and action eligibility remain with their owners. The fixed-characteristic defect still suppresses actual attacks and remains a mandatory task-9 fix. Native artifacts/logs remain outside the checkout. At task-3 completion, the next pending task was 4; its completed evidence is below.

#### Follow-up — compiler 0.4.13 and character predicate

- [x] Upgrade the environment to `rl_language`/`rl_language_core` 0.4.13.
- [x] Review every live `is_character` occurrence: one method declaration and one erroneous bare-name use. Invoke `destroyed.is_character()` in `on_model_destroyed`; generated documentation and historical artifact logs are not call sites.
- [x] Add positive and negative regressions for the existing Feeder Tendrils character-casualty/attacker-ability gate; its faction definition remains external. Deterministic result: 45 pass, 8 XFAIL, 0 XPASS.
- [x] Prepare matching Clang 21.1.8 sanitizer/fuzzer runtimes in writable workspace storage. Verify LLVM’s signed repository metadata and pinned package checksums; adapt Debian’s same-version x86_64 runtime paths to RLC’s per-target layout. Save the repeatable helper in `tools/prepare_validation_clang21.py` and the environment installation/startup draft. The optimized/debug/sanitizer/precondition/bounds fuzzer builds and completes 118 runs in 62 seconds with seed 40000, coverage 6,565 and feature count 18,472, without reported failures or failure artifacts. The fresh corpus starts with three action-driving inputs; logs/artifacts are outside the checkout. Check the produced executable as well as diagnostics, because RLC can exit zero after linker errors. No new Godot runtime test has run; task 4–17 status is unchanged.

### Task 4 — complete: geometry and movement primitives within the quad grid

Read [the geometry foundations report](doc/geometry-foundations.md) for source citations, representation, APIs, failure fixes and remaining owners. Completed:

- [x] Preserve whole-inch quad model positions, BoardPosition domains and existing Godot grid scripts; use bounded numeric geometry for inferred ML layout.
- [x] Implement nearest-base measurements, closest model pairs and supplied point-range Within/Wholly Within quantifiers; inclusive 2/5 engagement and local 2/5 plus whole-unit 9/5 coherency.
- [x] Implement transactional individual model-path primitives with cumulative per-model M, free circular-base rotation, friendly/enemy traversal, swept base clearance, complete footprint bounds and final overlap/coherency checks.
- [x] Add grid-aligned solid terrain/support geometry, full-base roof support and separately accumulated ascent/descent; reject invalid geometry saves and off-grid paths.
- [x] Integrate validated formation translation/setup with existing editor actions; remove edge clamping and preserve state on failure/cancellation.
- [x] Fix the roof-contact defect, seeded trapped-move stall and owning-copy leaks discovered during validation; retain deterministic regressions and the sanitizer leak input.
- [x] Validate deterministic rules, Python observations, completed seeded gameplay, freshly generated native Godot selectors/save replacement and sanitized fuzzing/replays.

Evidence: **74 PASS, 8 XFAIL, 0 XPASS**; full game seed 40000 completes in **474 actions**, shooting in **10**, with action round trips and terminal owner −4. Python/gym completes **20 steps**, with **7,469** action candidates and **156,098** observation values. State/observation schemas are **4**, action schema **2**. The rebuilt RLC-0.4.13/Godot extension passes target/unit/location selector, schema, rejected-edge-placement and save-replacement checks; interactive input/rendering is unrun. Clang-21 sanitized native replays of both completed scenarios and the original leak input pass; the fresh three-input mutation campaign completes **32 runs in 61 seconds**, coverage **6,106**, feature count **12,314**, without sanitizer failures or new failure artifacts. The original leak artifact is preserved separately rather than erased.

The user supplied Within/Wholly Within and Closest definitions. D05 remains open for Table Quarter, Setting Up Large Models and unsupported footprint/body data. Task-4 completion establishes primitives within the user-required quad representation; it does not certify exact tabletop geometry or full movement/deployment rules. Task 5 must implement end-turn incoherent removal without destruction triggers. Task 8 owns terrain categories/visibility. Task 11 must fix the recorded anchor-only setup constraints and implement independent model choices, movement modes/reserve timing and keyword exceptions. Tasks 13/14 own charge/fight workflows; task 17 owns supplied army footprints and complete editor integration. These recorded issues remain required fixes. **Next pending task: 5, timing and decision ownership.**

### Task 5 — complete: timing and decision ownership foundations

Read [the timing foundations report](doc/timing-foundations.md) for source authority, APIs, regression coverage, Godot contracts and remaining fixes. Completed:

- [x] Add explicit round/turn/phase start and end windows and the printed Command sequence; move legacy fixture scoring after non-mission Command-end effects.
- [x] Implement the supplied Rules Sequencing priority: current player chooses their effects in any order, followed by the opponent choosing theirs. Distinguish this user definition from unavailable app-only Player’s Rules.
- [x] Separate turn owner, temporary active role and decision owner; restore roles after moves, charges, attacks and nested reroll/faction decisions. Classify paired rerolls as chance.
- [x] Centralize actual-cost spending and per-player stratagem/per-unit phase limits, including shock, free-use bookkeeping, atomic rejection and spending before replacement dice/effects. Fix erroneous spending on declined options.
- [x] Reset phase usage for battlefield/reserve units and both armies’ fighting usage; reset turn history including reserves and retain the opponent’s turn flags.
- [x] Move existing Overwatch/Rapid Ingress to opponent Movement end and Heroic Intervention to opponent Charge end. Apply supported timing/target/cost gates without certifying later attack/charge effects.
- [x] Require end-turn coherency cleanup for both armies; archive one chosen model at a time without destruction callbacks and restore the Godot model selector’s target.
- [x] Preserve quads, bounded new timing state and editor action shapes; regenerate native/Godot bindings and validate deterministic rules, completed gameplay, gym observations and sanitized fuzz/replays.

Evidence: **97 PASS, 8 XFAIL, 0 XPASS** (23 new task-5 tests). The first two focused implementation stages separately pass **80/85** tests and type checking. Seed 40000 completes a full game in **346 actions** and shooting in **10**, including payload round trips and terminal owner −4. Python/gym completes **20 steps** with **9,950** action candidates and **163,673** finite observation values. New timing counters use standard bounded storage; existing identity/schema/history metadata still produces the previously documented non-tensorable Int warnings. State/observation schemas are **5**, action schema **3**. Fresh native/Godot bindings pass the headless selector/save/schema checks and new timing/coherency/Neural Disruption payload-shape assertions; interactive input/rendering remains unrun. The Clang-21 optimized/debug/sanitized/precondition/bounds fuzzer completes **28 mutation runs in 64 seconds**, coverage **6,679**, feature count **10,344**, without sanitizer failures or new failure artifacts. Native fixed-input replays of both completed games and the original geometry leak regression pass with leak detection enabled. Builds/logs/replays are outside the checkout in `/workspace/4hammer-validation`.

Task-5 completion establishes timing foundations, not complete core effects. At task-5 completion, eight known failures required fixes in tasks 7/8/9. Task 7 now fixes shock recovery/thresholds/Leadership and shock OC exclusion; task 8 must replace legacy OC/scoring and supply visibility; task 9 must fix fixed characteristics and support declared/batched dice and their rerolls. Tasks 10/12/14 own destruction, shooting/snap-shooting and fighting. Task 11 must replace anchor-only ingress/setup constraints. Tasks 13/15 must fix unsuccessful-charge flags, implement post-roll targets and both Heroic Intervention modes, exact Snap Shooting/action restrictions, Smokescreen, Counteroffensive and all other core effects. Task 17 must source faction/mission definitions and complete editor integration. D03/D09/D10/D12 remain unresolved, including the legacy extra-CP cap; record and fix these when their sources are supplied. **Task 6 is deferred by user instruction until full unit datasheets are supplied; task 7 is complete and the next pending task is 8, terrain, visibility and objective control.**

#### Follow-up — deployment editor reserve selection

- [x] Fix the collection mismatch in deployment selection: reserve UnitIDs cannot be selected using battlefield-model IDs. Add named legal reserve-unit buttons to `MultipleChoises.gd` and suppress battlefield selection for `RLCGameSelectUnit` in `InteractionManager.gd`.
- [x] Extend the headless Godot regression to press both armies’ deployment buttons, verify opposite ownership/regions, reject the incorrect battlefield ID and check the click-handler guard. The previous choice panel fails the new assertion; the corrected scripts pass. Direct engine checks also find legal opposing placements for all six faction fixtures.

- [x] Verify the reported “Done deploying” handoff through actual Godot buttons with different and identical army fixtures. Army 1 passes control to Army 2; after another placement Army 2 retains control while Army 1 has passed. Label deployment and finish buttons with Army 1/2 to expose decision ownership. The headless check passes against task-5 bindings; no engine handoff failure was reproduced. Deployment currently alternates after each placed unit, so the finish button belongs to the next decision owner.

`Rules.gd`, `TraceManager.gd`, Rulebook source, schemas and quad coordinates are unchanged. This fixes one editor workflow; it does not complete task 11’s full deployment rules or task 17’s complete integration. Their outstanding issues remain required fixes.

Tasks 1–5 establish the foundations. Task 6 attachment work is deferred by user instruction; continue independent tasks using explicit fixtures and retain attachment-dependent validation for the supplied datasheets. Geometry remains a combat prerequisite; the attack and damage pipelines should precede shooting, fighting and combat stratagems. Godot checks belong in every task that changes actions, followed by a complete integration pass in task 17.

Follow these dependencies when splitting work into implementation increments. A task may need smaller increments, but its complete scope must remain tracked. Record source uncertainties, external data dependencies and unsupported behavior rather than silently dropping requirements or calling partial coverage full-edition support.

## Godot action contract

Existing parameter shapes must remain meaningful: `UnitID`, `ModelID`, `BoardPosition`, and source-before-target ordering. New decisions such as selecting save groups or multiple charge targets need deliberate UI support where current autodetection cannot represent them. Read the detailed Godot compatibility instructions in [AGENTS.md](AGENTS.md) before changing action signatures; enumeration in the all-actions panel alone does not establish specialized control compatibility.

## Required fixes for identified issues

All confirmed implementation issues and mistakes identified in the coverage map, validation baseline, tests, gameplay checks or fuzzer must be fixed as part of this migration. Recording a defect or marking its test as an expected failure does not satisfy this requirement. This includes pre-existing bugs as well as incorrect behavior introduced during the edition update.

The [coverage map's defect register](doc/11th-edition-rule-coverage.md), [baseline report](doc/validation-baseline.md) and [known-discrepancy manifest](tests/known_discrepancies.json) are the initial fix backlog. Resolve each issue in its owning task, add a deterministic reproducer for source-inspection findings, and record the fix and passing validation. If investigation disproves a suspected issue, record the evidence and corrected finding instead of silently dropping it. Newly discovered defects must also receive an owner and regression coverage.

| Owning tasks | Required fixes already identified |
| --- | --- |
| 3, 4, 6 | Truncated CP/Advance/damage capacities; positional IDs shifting after removal; lost attachment provenance; distorted or clamped formation placement. |
| 5, 15 | Wrong stratagem cost and player usage checks; incorrect spending/usage on declined choices; missing chance classification for `reroll_pair`; inverted Overwatch eligibility. |
| 7, 8 | Mixed Leadership threshold; inappropriate shock clearing and missing shock restrictions; overwritten OC totals and incorrect ties; objective indexing/scoring defects confirmed by regression. |
| 9, 10, 12 | Fixed characteristics evaluating to zero; exact double/half wound thresholds; incorrect Lethal Hits, Heavy, Snap Shooting and Lone Operative behavior; attack iteration and destruction/removal defects confirmed by regression. |
| 13, 14, 17 | Charge/fight legality and sequencing mistakes; ambiguous or broken Godot controls when affected by migration; any additional integration, replay or fuzzer failures. |

For each fixed expected failure, move the desired-behavior assertion into the passing suite and remove its manifest entry. Do not weaken assertions, suppress failures or preserve incorrect behavior merely to retain compatibility. In particular, fix fixed-characteristic evaluation and test actual attack generation and damage; completed shooting scenarios are insufficient evidence while that defect exists.

An implementation task cannot be marked complete with confirmed defects assigned to it still unresolved. Task 17 must verify that the identified fix backlog is closed and the discrepancy manifest has no remaining expected failures. Missing source definitions and genuine ambiguities remain explicit dependencies requiring input; they must not be disguised as implementation fixes or silently waived.

## Completion and validation

Consider each task complete only when its cited rules have deterministic tests covering legal choices, illegal choices and boundary cases, and its affected bindings work. Record test counts/results, relevant scenario outcomes and any validation that remains unavailable.

The sanitized fuzzer adds coverage for crashes, invalid state and stalled action sequences; it cannot establish that the rules are correct by itself. Preserve and reproduce failures and convert them into regression cases. Follow the build and run instructions in AGENTS.md.

Full-edition completion also requires resolving the procedural reference's documented uncertainties and supplying missing faction, mission and app rules. These remain explicit dependencies. Do not invent those definitions or silently retain obsolete rules as substitutes.

### Task 6 — deferred by user instruction

The user instructed us to ignore attachment mechanics for now and will supply full unit datasheets after the other tasks. Do not implement task 6 or manufacture permitted Leader/Support attachments. Existing attachment behavior is legacy and is not certified against the new edition. Resume its complete scope after the datasheets arrive; task 7 may proceed independently using explicit mixed-unit fixtures.

### Task 7 — complete: Command phase and Battle-shock

Read [the Command/Battle-shock report](doc/command-battle-shock.md) for page-linked behavior, API contracts, validation and limits. Completed:

- [x] Leadership uses the lowest threshold and full 2D6 total, including the existing faction consumer that previously used only one die (p.9).
- [x] Preserve explicit Command start → Core CP for both players → Battle-shock → other abilities → Command end order (pp.30–31).
- [x] Roll once for live friendly battlefield units already shocked and/or at or below half-strength; recover only on success in this step, preserve opposing shock, and exclude empty slots (pp.9/30).
- [x] Correct exact/odd model-count and single-model wound thresholds; retain combined starting strength and distinguish strict below-half (p.86).
- [x] Apply shared model shock and OC exclusion, preserve own-stratagem targeting restrictions, and expose required start/completion shock gates for task 15 (p.9).
- [x] Restrict Insane Bravery to own Command Battle-shock step, with independent once-per-battle usage that survives resets/saves and centralized expenditure checks (p.56).
- [x] Promote all three task-7 discrepancy assertions and validate deterministic tests, CTest, Godot pending-recovery saves, Python/ML, seeded gameplay, native replays and sanitized fuzzing.

Evidence: **120 PASS, 5 XFAIL, 0 XPASS**; CTest **127 entries** including two passing compile fixtures and five explicit skips. State/observation schemas **6**, action schema **3**. Seeded full/shooting games complete in **347/10 actions**. Gym completes **20** legal finite-observation steps, **9,950** actions / **163,771** observations. Fresh matching native/Godot bindings pass a real Command recovery and save/reload at its chance boundary. Sanitized fuzzer: **25 runs in 69 seconds**, coverage **6,696**, features **10,676**, no reported failure. Completed full/shooting inputs and the original geometry sanitizer input replay without reported failures. Existing random smoke checks run 200 bounded full-game actions and complete three shooting scenarios.

The Python selection defect discovered during CTest validation is fixed: fresh configurations prefer the activated environment and reject missing `rlc` at configuration. Interactive GUI rendering/input remains unrun. Fixed characteristics still suppress actual combat (task 9), so completion smoke checks do not certify attack resolution.

Task 8 must fix the remaining objective aggregation/tie failures and full marker/scoring behavior; task 9 must fix the three remaining combat failures. Task 15 must integrate shock gates into actual mission-action decisions. Faction/mission sources remain task 17; task 6 remains deferred. Offboard app policy remains D10 for reserves/passenger integration in tasks 11/16; the existing battlefield Command loop does not certify an invented off-table recovery policy. **Next pending task: 8, terrain, visibility and objective control.**

### Task 8 — user-approved terrain abstraction

The user instructed us to implement terrain areas only, without physical terrain features, and assume models are always at least visible: a sight line crossing terrain makes a target partially obscured. Implement rectangular whole-quad areas with category flags, cover through this area-intersection approximation, and separate Hidden detection/history rules. Do not implement physical model-body line of sight, feature traversal/upper surfaces, enclosed Solid openings or complete-occlusion geometry in this task. This is an explicit simulation abstraction supplied by the user, not a claim that the PDF defines centre-line visibility or makes all terrain partially transparent. Preserve existing task-4 solid-box collision primitives without adding new feature rules. Exact feature/visibility behavior remains deferred; task 17 must make the area abstraction clear in integrations.

### Task 8 — complete within the user-adjusted scope

Read [the terrain/objective report](doc/terrain-objectives.md) for source pages, APIs, approximation and remaining obligations. Completed:

- [x] Add bounded whole-quad terrain areas with independent category flags, base-aware membership and transactional objective links/save validation.
- [x] Apply user-approved partial obscuration through area crossings; implement all-target-model cover as a ranged BS change and parameterless Ignores Cover detection (pp.25/50/82).
- [x] Implement model-level Dense-area Hidden, current/previous-turn attack history, inclusive default 15-inch detection and unit/per-model visibility gates. Actual attacks, including misses, break Hidden; skipped weapons do not (p.50).
- [x] Implement terrain objective range and 40mm marker fallback with inclusive 3-inch horizontal/5-inch vertical closest-part geometry (pp.52/88).
- [x] Fix OC aggregation and ties, initial uncontrolled state, phase/turn snapshots, secured absence/ties and phase-end-only loss, and unit control eligibility (pp.52–53).
- [x] Separate objective control from scoring; default core state awards no points. Retain the existing four-marker scoring only as an explicit legacy mission fixture and fix both-army marker indexing.
- [x] Promote both objective discrepancy assertions and validate deterministic tests, Godot native saves/helpers/selectors, gameplay/ML, sanitizer replays and mutation fuzzing.

Evidence: **144 PASS, 3 XFAIL, 0 XPASS**; CTest **149 entries**, including two passing compilation fixtures and three expected-failure skips. State/observation schemas **7**, action schema **3**. Seeded full/shooting games finish in **347/10 actions**. Gym completes **20** legal finite-observation steps, **9,950** action candidates / **164,014** observations. Existing CLI checks execute 200 bounded full-game actions and complete three shooting scenarios. Fresh matching native Godot bindings pass area construction, cover/Hidden, secured-objective absence and save restoration, plus prior deployment, selectors and Command recovery. Sanitized fuzzer: **31 runs in 74 seconds**, coverage **6,872**, features **12,695**, no reported failure/new failure artifact. Completed full/shooting inputs and the geometry leak regression replay successfully with leak detection enabled. The campaign log warns that an external symbolizer is unavailable; sanitizer instrumentation remains enabled but diagnostic frames would lack symbolic names. Interactive GUI rendering/input remains unrun.

Fixed characteristics still suppress actual combat and the three remaining expected failures belong to task 9; scenario completion is not combat certification. Task 12 must correct other legacy parameterless ability consumers, Lone Operative targeting and full shooting modes. Task 15 must apply visibility to its other effects/actions. Task 17 owns supplied missions, faction data, area configuration/rendering and disclosure of the approximation. Exact physical features/LOS are deferred by user instruction, not claimed implemented. Task 6 remains deferred. **Next pending task: 9, attack declaration and dice pipeline.**


### Task 9 — complete: attack declarations and dice pipeline

Implementation, citations and downstream limits are in [the task-9 report](doc/attack-declarations-dice.md); supplied source authority is in [the appendix supplement](doc/11th-edition-supplied-appendix.md).

- [x] Declare all selected weapons/targets before rolls; support fixed-A melee shares, distinct targets, duplicate guards and per-model eligibility.
- [x] Resolve one target completely, gather identical unresolved weapons and generate random A independently per weapon. Retain source identities across compaction and permit replacement of ineligible unresolved targets.
- [x] Collect complete hit/wound/save batches before rerolls; retain original eligibility, disallow second rerolls and commit Command Re-roll expenditure before chance. Preserve nested decision roles.
- [x] Fix bounded fixed-characteristic evaluation and exact doubled/halved Strength thresholds; promote all three remaining discrepancy assertions unchanged.
- [x] Implement natural/critical hit and wound results, net modifier caps, critical-only Lethal Hits, normal wound rolls for Sustained Hits extras and unit-keyword Anti. Correct presence checks for parameterless abilities.
- [x] Add ordered bounded modifier helpers and supplied post-modifier limits; apply existing skill/detection consumers without claiming automatic integration into all future effects.
- [x] Preserve Godot selector payload shapes and provide finite group/share/reroll buttons; bump state/observation schemas to **8** and action schema to **4**.
- [x] Record user assumption: random-A melee weapons do not exist. Assert fixed melee A rather than inventing a declaration/splitting policy.

Deterministic validation: **171 PASS, 0 XFAIL, 0 XPASS**; CTest **173/173 passing entries**, including two compilation fixtures. The empty discrepancy backlog is accepted while empty-baseline, duplicate and manifest-mismatch rejection remain enforced. Seed 40000 completes full/shooting games in **942/9 actions**; fresh gym validation checks **20** legal steps, **12,551** action candidates and **201,437** finite observations. Existing random smoke commands run 200 bounded full-game actions and complete three shooting scenarios. Fresh matching native/Godot artifacts and sanitized fuzzer build with RLC **0.4.13**, Clang **21** and Godot **4.6.3**.

Godot validation: the production choice panel and interaction manager pass weapon/group buttons, source-first declaration clicks, one-UnitID target choice, chance ownership, batch reroll buttons and pending-attack save/reload. The fixture skips remaining reserves and uses a single enemy model; no production deployment/interaction code was changed. Melee-share legality is covered deterministically; its buttons and interactive rendering are not exercised by this shooting harness. Rules.gd and TraceManager.gd remain unchanged.

Sanitized validation: both completed game inputs and the original geometry leak regression replay without reported failures. Mutation campaign completes **31 runs in 72 seconds**, coverage **7,393**, features **15,106**, with leak/precondition/bounds checks enabled and no failure artifacts. This short campaign is crash evidence, not semantic certification.

**Mandatory next fixes:** task 10 must replace the legacy save/allocation/damage bridge, including save/AP handling, per-attack allocation, excess damage, mortal/destruction timing and Hazardous. Task 11 must supply explicit movement-mode state and remaining random-M consumers. Task 12 must implement full ranged modes/pistol restrictions, Lone Operative and remaining ability consumers. Task 14 must replace legacy fight-on-death/melee sequencing; task 15 must integrate remaining combat stratagem effects. Modifier helpers are available, but future effect consumers require explicit integration and tests. Multiple Weapon Profiles remains unsupplied; other app/datasheet/mission gates remain open. Task 6 stays deferred. Preserve quads and the area-only visibility approximation. **Next pending task: 10, saves, damage and destruction.**


### Task 10 — complete: saves, damage and destruction

Read [the task-10 report](doc/saves-damage-destruction.md) for page-linked implementation, action contracts, bounded capacities and remaining owners. Completed:

- [x] Build live W/Sv/InSv groups with separate CHARACTER groups, stable membership and wounded/character priority; declare the defender's complete order before rolling saves (p.19).
- [x] Process the full save batch ascending, checking natural 1, InSv and AP-adjusted Sv against the same face; change groups as casualties occur and resolve each attack's damage independently without normal excess spill (pp.19–23).
- [x] Normalize legacy AP signs without changing magnitudes; implement visible CHARACTER-group PRECISION override/fallback and per-weapon half-range MELTA declaration snapshots (pp.83–84).
- [x] Roll Feel No Pain per potential wound, resolve normal damage before mortals, preserve ordinary mortal spill, and cap each DEVASTATING critical attack at one destroyed model (pp.24/80–81).
- [x] Count every selected hazardous weapon, collect all hazard dice before paid rerolls or damage, fail on 1–2, and inflict one/three mortals using each live model's MONSTER/VEHICLE keywords (p.24).
- [x] Remove casualties immediately without triggers; retain dead/ineligible models with stable provenance when triggered rules exist, delay attack-caused triggers until all target groups finish, and interrupt non-attack damage for immediate triggers (p.87).
- [x] Implement Deadly Demise on 6, inclusive 6-inch base range, separate random X per unit and physical retention through nearby damage; sequence pending destruction choices using supplied Rules Sequencing (pp.80/87).
- [x] Validate pending-death save round trips and reject malformed provenance atomically; preserve existing coherency cleanup and remove/archive triggered casualties exactly once.
- [x] Add labelled finite save/Precision group buttons and correct damage-model target context in InteractionManager; preserve Rules.gd and TraceManager.gd. Bump state/observation schemas to **9**, action schema to **5**.

Evidence: **202 PASS, 0 XFAIL, 0 XPASS**, with **204/204 CTest entries passing** including two compilation fixtures; the existing Python runner reports the same supported count and empty discrepancy backlog. Seed 40000 completes full/shooting games in **625/9 actions**. Gym validates **20** legal steps, **12,744** action candidates and **1,595,388** finite observations. The bounded 1,024-job stack materially expands inferred ML layout; old policy/save schemas are incompatible. Existing CLI checks execute 200 bounded full-game actions and complete three shooting scenarios.

Matching RLC **0.4.13**, Clang **21** and Godot **4.6.3** native/header/C++ artifacts pass production group buttons and actual defender clicks, all-save boundaries, pending-allocation save/reload and individual Feel No Pain/archival, alongside previous deployment, Command, terrain/objective and attack checks. This expanded harness needs an explicit `--timeout 120` on this machine; its former 30-second budget expired without a script error after the fixture assignment correction. Interactive rendering/mouse input, self-hazard UI clicks and all melee/Precision controls remain unrun and belong to task 17.

Sanitized fixed-input replays pass for both completed games and the original geometry leak regression, with leak/precondition/bounds checks enabled. Mutation fuzzing completes **25 runs in 78 seconds**, coverage **10,184**, features **23,383**, without reported sanitizer failures/crash artifacts. A **slow-unit performance artifact** preserves the full-game seed outside the checkout; it is not a crash and is not discarded. Requested 60-second duration is exceeded by slow individual inputs. This short campaign does not establish full semantic coverage.

**Mandatory remaining work:** task 6/17 must supply actual attachment permissions, component ability retention and new datasheets; core mixed-model fixtures do not certify attachments. Task 12 owns complete weapon-mode interactions and remaining modifier consumers. Task 14 must replace the legacy Fight on Death attack workflow; task 10 fixes its retained-casualty lifecycle but does not certify legacy faction/combat effects. Task 15 must route Explosives/Crushing Impact and other mortal effects through the common engine with exact timing/costs. Task 16 must put emergency disembarkation before transport Deadly Demise and implement passengers/offboard rules. Tasks 6/11/17 retain revived-model provenance, placement and supplied revival-effect obligations (p.88); no generic revival effect is invented. Task 17 owns supplied faction destruction hooks, complete interactive checks, real missions and new data. Multiple Weapon Profiles remains unsupplied. Low-level Unit damage helpers are storage fixtures and must not replace gameplay prevention/destruction actions.

Confirmed downstream defects must still be fixed in their owning tasks, even though the expected-failure manifest is now empty. Preserve quads and the area-only visibility approximation. **Next pending task: 11, movement and deployment.** Task 6 remains deferred by user instruction.

## Task 11 completion: movement and deployment

Read [the movement/deployment report](doc/movement-deployment.md) and its [coverage overlay](doc/11th-edition-rule-coverage.md#task-11-movementdeployment-overlay).

- [x] Exclude retained casualties from live engagement/coherency; use each surviving model's own M.
- [x] Add bounded movement/points/Scouts data and preserve same-turn restrictions and reserve/reposition provenance.
- [x] Implement mandatory movement selection, stationary, Normal/Advance, Ordered Retreat, Desperate Escape and shared hazard/destruction resolution.
- [x] Provide resumable per-model whole-quad paths, finite rotation, independent budgets, atomic rollback and final coherency validation.
- [x] Apply flying/Hover and Super-heavy Walker traversal/budget/temporary-Mobile rules within the area-only terrain abstraction.
- [x] Replace anchor-only deployment and ingress checks with every-base setup; search valid alternative presets and use adjacent mixed-base spacing.
- [x] Implement points-gated strategic reserves, round/edge/enemy-zone restrictions, Deep Strike, ingress locks, repositioning and end-round-3 expiry.
- [x] Implement pre-battle Scouts; assert uniform duplicate Scouts values per user instruction. Dynamic metadata requires runtime checks; constant datasheets must enforce this statically in task 17.
- [x] Implement explicitly granted surge, eligible closest targets and per-model reachable endpoint checks with other chosen positions fixed.
- [x] Preserve Godot action contracts and add reserve buttons, independent model clicks, waypoint controls and contextual movement choices. Rules.gd and TraceManager.gd are unchanged.
- [x] Apply user-directed destruction of units with no legal supported deployment instead of restarting or granting reserves; archive identities and destroyed models.

Deterministic validation: **243 supported assertions pass**, no remaining discrepancy assertions; **245/245 CTest entries pass**, including two compilation fixtures, in `/workspace/4hammer-validation/task11-final-policy-tests`. The destruction regression rejects a legally placeable unit and verifies identity/casualty archival for an unplaceable one. A native replay of the actual blocked mixed-base Squighog formation finds no supported placement and archives all four models; seeded full-game replay takes the destruction action at step 21 and completes.

Seed **40000** completes full/shooting games in **888/9 actions** with terminal owner **-4**. Matching replay artifacts are in `/workspace/4hammer-validation/task11-policy-replays`. Fresh gym validation checks **20** legal steps, **15,883** action candidates and **1,806,913** finite observations. Schemas are **10/6/10** (state/action/observation). Fresh native/header/C++ bindings in `/workspace/4hammer-validation/task11-policy-godot` pass the Godot deployment, phase, combat save/allocation and independent-movement click/waypoint/save regression.

Sanitized fuzzer `/workspace/4hammer-validation/task11-policy-fuzzer` completes **60 runs in 62 seconds**, coverage **7,650**, features **14,844**, with leak detection enabled and no failure artifacts. Corpus/artifacts are `/workspace/4hammer-validation/task11-policy-corpus` and `task11-policy-artifacts`. The completed full/shooting replays and original `geometry-placement-leak.bin` each pass fixed-input sanitizer replay with leak detection enabled. Fixed-input replay is distinct from the 60-run mutation campaign.

**Remaining mandatory fixes and scope:** attachments stay deferred (task 6); missing mission zones, points/datasheets and faction surge triggers belong to task 17. Whole-grid setup presets do not enumerate all physical formations; surge checks are conditional per-model endpoints, not a joint formation optimizer. Terrain features/continuous coordinates remain deferred by user instruction. Aircraft, passengers and transport Scouts belong to task 16; full charge/fight flight to tasks 13/14; complete shooting/action restrictions to tasks 12/15. Compound random-M data and revival's phase-start-anchor ambiguity remain explicit data/source obligations. Keep configured bounds and preserve unsupported-footprint assertions. Every identified downstream issue must still be fixed by its owning task; task-11 completion does not close those dependencies. **Next pending task: 12, shooting and weapon abilities.**

## Task 12 — shooting and weapon abilities (complete within deferred-data scope)

Implemented normal, assault, close-quarters and indirect selection; per-bearer eligibility, engaged Monster/Vehicle permissions, Snap target replacement and reroll gates, Lone Operative, conditional/duplicate abilities, declaration-time bonuses, optional per-critical Lethal Hits, Twin-linked, Heavy, One Shot and mandatory Extra Attacks. Read [the task-12 report](doc/shooting-weapon-abilities.md) for all 38 printed ability subsections and their remaining owners. The supplied Multiple Weapon Profiles appendix 04.01.03 now governs per-model profile exclusivity, Hunter keyword targeting and physical-weapon One Shot sharing. Legacy plasma pairs have explicit provenance.

Preserved the quad grid, area-only visibility approximation, bounded ML fields, and existing Rules.gd/TraceManager.gd. Current schemas are state/observation **11**, action **7**. New Godot shooting-mode, duplicate-ability and Lethal decisions use the production choice panel. Custom init/drop lifecycle guidance is committed separately.

Final compiler: **rl_language/rl_language_core 0.4.14**, upgraded at the user's request. A separate smoke check confirms duplicate variables are rejected as “Redeclaration of variable value”; the game source passes type checking without such errors. **276 supported assertions pass**, **278/278 CTest entries pass**, **0 XFAIL / 0 XPASS**. CTest completed in 198.94 seconds at `/workspace/4hammer-validation/task12-compiler14-ctest`.

Fresh matching native/Godot headers/C++ bindings pass the headless editor regression, including shooting/duplicate buttons, attack/save restoration, allocation/FNP, deployment and independent movement. Use `python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task12-compiler14-godot --timeout 300`: the expanded regression repeatedly scans all candidate actions and can exceed the earlier 120-second limit; the follow-up performance review below identifies the cost. Actual rendered mouse interaction and broader faction integration remain task 17.

Both RLC 0.4.14 sanitized fuzzers build with Clang 21 and precondition/bounds checks. The full-game root passes both preserved lifetime inputs and the 735-action full-game replay, then completes **224 mutation runs in 61 seconds** (seed 40000). The matching shooting root replays the **33-action** combat scenario with hit/wound/save/allocation decisions, then completes **1,117 mutation runs in 61 seconds** (seed 40001). No sanitizer failure or failure artifact was reported. Fixed replays and mutation campaigns are separate checks. The new deployment-search leak regression is `tests/fuzz-regressions/deployment-search-lifetime.bin`; moving ownership into single-exit wrappers fixes it without manual lifecycle hooks or disabled checks.

Seeded Python scenario completion and the 20-step gym check were run before the compiler upgrade under 0.4.13; their evidence is distinct from the 0.4.14 native replays and binding/tests above. Full-game enumeration is **15,954 candidates**, with **4,415,908 finite gym observations**. State/observation layout changes require new ML policies; historical metadata warnings are not certification that every identity/history field is tensorable. Reusable environment `install_script` and `start_skill` were updated to pin both compiler packages to 0.4.14; saving the draft does not publish a snapshot.

**Next pending task: 13, charges.** Task 6 remains deferred.

Mandatory remaining owners: attachment permissions/data remain deferred task 6; task 13 must produce genuine charge-move history for Lance; task 14 must complete Fight and Fight on Death; task 15 owns full action/stratagem eligibility and effects; task 16 owns transports, Firing Deck, transport Scouts and Aircraft; task 17 owns supplied new-edition datasheets/missions, actual faction effects and full interactive integration. Physical terrain features and continuous coordinates remain deferred by user instruction. Every recorded issue must be fixed by its owner, not treated as completed by shared infrastructure.

## Task 12 review follow-up

[The measured review](doc/task12-performance-review.md) identifies repeated Godot action-wrapper fetching as the performance bottleneck; serialization is milliseconds. A prototype outside the checkout reduces 107 action scans from 104.923 to 12.109 seconds while passing the same regression. **Mandatory task-17 fix:** optimise candidate fetching/filtering, with proper wrapper ownership and reset invalidation. Production Rules.gd and TraceManager.gd remain unchanged by user direction.

Corrected PISTOL/CLOSE-QUARTERS duplicate selection and identical-attack grouping (pp.17/78/83), retaining selected conditions. **277 assertions / 279 CTest entries pass**, fresh Godot bindings pass, and the matching shooting replay passes with leak detection. The later sandboxed mutation campaign's final LeakSanitizer thread-inspection error is recorded separately rather than counted as a pass.

## User-directed coordinate and numeric storage follow-up (complete)

Read [the storage report](doc/bounded-numeric-storage.md). Position actions now enumerate only usable interior quads: x=1–43 and y=1–29, **1,247** choices per position action. No z-coordinate action exists. Total candidates fall **15,954 → 15,516**. Model/editor x/y payloads and the board's dimensions remain unchanged; persisted path points and terrain corners now use small whole-inch domains rather than micrometre values. Calculations retain local floats and physical precision.

Raw identity/serial/stamp/schema numbers and Hidden<Float> movement distance are replaced with standard bounded storage. Zero encodes unset identity/history; recorded stamps use serial+1. Movement history stores integer segment data and computes float lengths on demand. Generated lifecycle hooks replace the partial UnitHistory initializer. Capacity and malformed-save checks reject unsupported values. State/observation schemas are **12**, action schema **8**. Older snapshots/policies/catalogs are incompatible; regenerate matching artifacts.

**281 assertions pass, 283/283 CTest entries pass**, no discrepancies, in `/workspace/4hammer-validation/bounded-storage-verified-tests`. Fresh native/header/C++ Godot bindings pass with `--timeout 300`, including migrated whole-quad terrain fixtures and existing selectors/save/allocation/movement checks. The 20-step gym check produces **4,769,367 finite observations** and no not-tensorable warnings. Seeded full-game play completes **735** actions at terminal owner **-4**. The current sanitized full-game fuzzer passes both lifetime inputs and **391 mutation runs in 61 seconds**; LeakSanitizer runs outside the sandbox because thread inspection failed inside it. Fixed input replay is separate from mutation evidence.

The preliminary negative-bound binding build failed because generated identifiers contained a minus sign; nonnegative offset encoding fixes this without changing the compiler or introducing Quantity. A geometry test fixture and the Godot terrain fixture still wrote micrometre values after storage changed; both were corrected to whole-quad values, and affected checks were rerun. No preliminary failed/unrun check is counted as a pass.

Production Rules.gd/TraceManager.gd remain unchanged. The measured action-wrapper fetch bottleneck remains a **mandatory task-17 fix**, with ownership/reset invalidation tests. Task 13 remains next; task 6 attachments and supplied datasheets remain deferred.


## Task 13 — charges (complete within preserved-grid scope)

Read [the charge report](doc/charges.md) and its [coverage overlay](doc/11th-edition-rule-coverage.md#task-13-charge-overlay).

- [x] Declare a friendly eligible live battlefield source before rolling; reject engagement, Advance/Fall Back, AIRCRAFT and repeated phase declarations (p.36).
- [x] Roll/re-roll the complete pair before ordered modifiers, apply the appendix's 12 cap, and select distinct targets afterward within both 12 inches and the actual maximum (pp.36–37).
- [x] Stage rigid or independent whole-quad paths; use the charge roll instead of M, full path distances and base sweeps, and atomic cancellation/restart/commit (pp.12/37).
- [x] Enforce every live model's approach, within-1/engagement obligations, final coherency, engagement with every selected target and no incidental enemies; search detours on the retained grid (p.37).
- [x] Keep failed/cancelled declarations distinct from successful movement; grant turn-local Fights First/Lance only after completion and stamp actual current-phase moves for Heroic targets (pp.37/57/81–82).
- [x] Integrate flight/Hover and AIRCRAFT charge/traversal restrictions; prevent Super-heavy Walker's Normal/Advance/Fall Back permission from leaking into charge paths (pp.71/74/82/85).
- [x] Implement both Heroic Intervention pre-roll modes, exact base/additional costs, Leap's actual successful current-phase targets and Fray's 6-inch caps (p.57).
- [x] Preserve editor UnitID/ModelID/BoardPosition shapes, charging-unit model highlights, flight/rotation choices and pending charge saves. Rules.gd and TraceManager.gd remain unchanged.
- [x] Keep all persisted numeric fields in standard bounded domains; reject malformed stamps/modifiers. State/observation schemas **13**, action **9** require fresh saves/policies/catalogs/bindings.

Deterministic validation: **311 supported assertions pass**, no discrepancy assertions; **313/313 CTest entries pass**, including two compilation fixtures, in **185.88 seconds** at `/workspace/4hammer-validation/task13-tests`. Thirty charge cases cover legal/illegal declarations and targets, failures/cancellation, pair re-rolls, movement beyond M, multiple targets, detours, model obligations, flight/Hover/Aircraft, Heroic costs/modes and serialization. Initial unsupported Float min/Bool payer calls were corrected. An intermediate run overlapped added test declarations and correctly failed the source-declaration freshness guard; its partial results are not counted as final evidence. Current source was frozen and both compilation fixtures/full suite rerun.

Fresh RLC **0.4.14**, Clang **21** and matching native/header/C++ Godot bindings in `/workspace/4hammer-validation/task13-godot` pass the headless regression with `--timeout 300`. The new checks exercise source-unit clicks, neutral pair chance input, two distinct enemy target clicks, charging-model highlights, whole-grid waypoint input and save/reload before final charge commit. Existing deployment, Command, terrain/objective, shooting and allocation/FNP checks also pass. Approximate complete harness wall time is **178 seconds**; per-action enumeration has not been separately re-profiled. Rendered mouse interaction and full Heroic-mode UI integration remain task 17.

Seed **40000** completes the full-game runner in **920 actions**, terminal owner **-4**; that scenario exercises five cancelled charge attempts, not successful-charge semantics. Successful/multi-target/detour charge semantics are established by deterministic tests and the new Godot fixture. Fresh gym validation checks **20** legal steps, **18,443** candidates and **6,033,519 finite observations**, with no not-tensorable warnings. New charge path/rotation inputs increase the catalog; each position domain remains the minimal supported **1,247 interior quads**, with no z-coordinate action.

The matching sanitized full-game fuzzer `/workspace/4hammer-validation/task13-fuzzer` passes the original geometry and deployment lifetime inputs and the fixed zero input with leak/precondition/bounds checks enabled. A fresh short-input mutation campaign completes **71 runs in 61 seconds**, coverage **9,444**, features **14,793**, without failures/artifacts. The current-schema 920-action full-game input separately replays in **33,002 ms** with no reported sanitizer failure. Sanitizer execution remains outside the sandbox for LeakSanitizer thread inspection. The external-symbolizer warning limits diagnostic names, not instrumentation; no checks were disabled. A short campaign is crash evidence, not semantic or complete charge coverage.

**Mandatory remaining fixes and limits:** task 14 must implement the full Fight/pile-in/consolidation sequence and Fights First consumer; task 15 must supply immediate post-charge Crushing Impact and remaining core effects. AIRCRAFT lifecycle remains task 16. Attachments remain deferred task 6, and supplied army/mission/faction rules and full interactive/performance integration remain task 17. The old target-first Overawing Magnificence branch charged CP but never consumed its charge-reduction flag; it is not fabricated into the new core sequence, and its sourced functional replacement remains mandatory task 17. The inherited Pouncing Leap cost discount remains explicitly legacy. Reachable endpoints hold other final models fixed, retain elevation and use horizontal quad routes; 16-waypoint paths and circular fixtures do not certify arbitrary simultaneous/continuous tabletop geometry. Terrain features and continuous coordinates remain deferred by user direction. Every identified downstream issue must still be fixed by its owner. **Next pending task: 14, fighting.**


## Task 14 — fighting (complete within preserved-grid scope)

Read [the Fight report](doc/fighting.md) and the task-14 coverage overlay. State/observation schemas are **14**, action **10**; regenerate saves, policies, catalogs and native/Godot bindings together.

- [x] Phase-wide optional Pile In for the current player, then opponent, with independent staged model paths and closest-target choices (pp.38–39).
- [x] Alternate eligible units starting with the current player; resolve Fights First before remaining units, refresh eligibility and permit passing only when no eligible unit remains in the required priority (pp.40–41).
- [x] Select Normal/Overrun fights, including Overrun's additional pile-in, using the shared full-unit declaration and damage pipeline (pp.40–41).
- [x] Phase-wide consolidation with ongoing/engaging/objective priorities and mandatory newly engaged opponent responses (pp.42–43).
- [x] Retain Fight on Death models until their own unit attacks or phase end, then resolve destruction effects and remove them; remove the immediate per-casualty retaliation bridge (user-supplied appendix; p.87).
- [x] Preserve bounded numeric storage, scoped decision ownership, Godot action-discovery shapes and pending-path saves. Rules.gd and TraceManager.gd remain unchanged.

Final matching validation under RLC **0.4.14** and Clang **21**: **345 supported assertions**, empty discrepancy manifest, **347/347 CTest entries pass in 235.69 seconds** at `/workspace/4hammer-validation/task14-tests`. The **34 focused Fight assertions** also pass in a standalone native Address/Undefined/LeakSanitizer driver. Fresh native/header/C++ bindings at `task14-godot` pass the headless regression, including closest-target/path restoration, alternating melee and retained-unit attacks.

Seed **40000** completes **920 actions**, terminal owner **-4**, with **20,254 candidates**. It contains cancelled charge attempts and no selected fights; it does not establish Fight semantics. Those are covered by deterministic cases, the focused sanitizer driver and the Godot fixture. The gym check completes **20 steps**, **6,132,581 finite observations**, with no not-tensorable warnings.

The matching `task14-fuzzer` passes both preserved lifetime inputs and a fixed zero input with leak/precondition/bounds checks enabled. A fresh short-input campaign completes **63 runs in 61 seconds**, coverage **10,192**, features **15,709**, without failure artifacts. The matching 920-action full-game input separately passes sanitizer replay in **36,533 ms**; fixed replay is not mutation coverage. LeakSanitizer runs outside the sandbox for thread inspection.

**Mandatory remaining owners and limits:** task 15 owns Counteroffensive, remaining core stratagems/actions and their new combat boundaries; task 16 owns transports/emergency disembarkation and Aircraft lifecycle. Attachments remain deferred task 6. Task 17 owns supplied army/mission/faction data, rendered interaction and the measured action-wrapper fetching/ownership fix. Legacy faction hooks are not new-edition certified and require that audit. Whole-quad circular geometry retains elevation, horizontal routes, fixed other final models and 16-waypoint paths; it is not a joint formation optimizer. Exact base contact is generally unavailable for existing bases on this grid. Continuous positions and physical terrain features remain deferred by user instruction. Every recorded issue must be fixed by its owner. **Next pending task: 15, core stratagems and actions.**


## Task 15 — core stratagems and actions (complete within deferred-data/visibility scope)

Read [the core stratagem/action report](doc/core-stratagems-actions.md). Every printed 15.01–15.12 card (pp.54–57) and 16.01 generic action rule (p.58) has an explicit implementation/consumer inventory.

- [x] Add Explosives: own Shooting eligibility, actual keyword bearer, unengaged visible 8-inch target, six D6 and common mortal/FNP/destruction resolution (p.56).
- [x] Add immediate post-successful-own-charge Crushing Impact, actual engaged model's T dice, independent six-mortal caps and damage to both units even after source destruction (p.56).
- [x] Add selected-character Epic Challenge Precision, including authorised retained fighters, with phase expiry (p.56).
- [x] Add Smokescreen at start of opponent Shooting, direct target cover and explicit intervening-base visibility approximation (p.57).
- [x] Add Counteroffensive immediately after enemy Fight-step attacks; grant Fights First and constrain the next friendly selection (p.57).
- [x] Audit existing Command Re-roll, Bravery, Ingress, Overwatch/Snap and Heroic consumers; remove the unused per-move Overwatch action, enforce same-phase/action shooting bans and preserve exact costs, windows and restrictions (pp.54–57).
- [x] Add generic action membership/OC/keyword/shock/movement/engagement/start/shooting gates, TITANIC exceptions, bounded independent cross-turn records, interruption and explicit-stamp completion (pp.9/34–35/57–58). Keep the DEPLOY DEVICE illustration unplayable.
- [x] Preserve quad inputs and numeric bounds, source-model click context and separate core effect source buttons. Expose bounded CP entries for the editor because fixed arrays lack generated getters. Rules.gd and TraceManager.gd remain unchanged.

State/observation schemas are **15**, action **11**. Final RLC **0.4.14** / Clang **21** validation: **382 supported assertions**, no discrepancies; **384/384 CTest entries pass in 254.53 seconds** at `/workspace/4hammer-validation/task15-tests`. The **37 focused core cases** also pass a standalone native Address/Undefined/LeakSanitizer driver with leak detection enabled in `task15-sanitized-core-tests`. Each implementation commit's intermediate game/test source is type checked; the generic lifecycle prerequisite was additionally checked with generated Python wrappers.

Fresh native/header/C++ bindings in `task15-godot` pass the complete headless regression with an explicit extended timeout. New checks exercise Explosives source buttons/bearer and target clicks/six dice, Crushing Impact target/bearer/T dice, Epic Challenge's character click, and Counteroffensive's next-unit selection. Existing deployment, Command, terrain/objectives, weapon/group/save restoration, FNP, charge and retained-unit Fight on Death checks pass. The harness uses explicit independent fixtures; resetting phase usage between Explosives and the pre-existing CP-reroll scenario is not legal-gameplay evidence. Smokescreen's direct/intervening cover and timing are established by deterministic cases; rendered mouse input and broader interactive integration remain task 17.

Seed **40000** completes **920 actions**, terminal owner **-4**, with **20,516 candidates**. That seed has no selected fights/new card activations; it is terminality/replay evidence, not certification of those rules. Focused cases and the Godot fixtures establish their behavior. The gym check completes **20 steps**, **9,351,760 finite observations**, without not-tensorable warnings. The additional effect frames/action records expand the inferred layout; old policies/saves/catalogs are incompatible and no performance improvement is claimed.

Final sanitized fuzzer `task15-final-fuzzer` passes both preserved lifetime inputs, fixed zero input and the current-schema full-game replay with leak/precondition/bounds checks enabled. The 920-action replay takes **52,321 ms** on this run. A fresh short-input campaign completes **58 runs in 64 seconds**, coverage **10,945**, features **16,679**, without failures or artifacts. Corpus/artifacts are `task15-final-corpus` / `task15-final-artifacts`; replay files are in `task15-verified-replays`. Fixed inputs and mutation runs are separate checks. LeakSanitizer runs outside the sandbox for thread inspection; no checks are disabled.

Preliminary failures are not final passes: an ordinary-death test incorrectly expected delayed destruction choices and was corrected to include Deadly Demise; an initial reading missed p.34's normal-shooting action ban and was restored before final checks. Overlap review replaced a single pending slot with bounded per-turn action records. Generated C++ rejected duplicate sibling `frm source` fields; renaming `explosives_source` fixes the binding while retaining its UnitID payload. The first Godot fixture attempted an unavailable fixed-array getter; a bounded entry accessor fixes it. Explosives legitimately consumed the per-unit stratagem allowance needed by the separate existing reroll fixture; the fixtures were separated explicitly. Superseded/stale builds are not counted as final evidence.

**Mandatory remaining owners and limits:** task 16 must integrate embarkation/departure/emergency movement with action interruption and implement transports/Aircraft. Task 17 must supply actual mission action timing/units/use limits/effects, new datasheets/EXPLOSIVES/GRENADES/SMOKE permissions and faction definitions; complete rendered interaction and fix the measured action-wrapper fetching/ownership bottleneck. Legacy faction discounts/hooks remain uncertified and require that audit. Attachments remain deferred task 6. Intervening smoke uses circular bases crossing centre sight segments, not bodies/silhouettes; physical terrain features and continuous coordinates remain user-deferred. Every identified downstream issue must be fixed by its owner. **Next pending task: 16, transports and Aircraft.**

## Task 16 — transports and Aircraft (in progress)

The user supplied appendix 01.02.02 (Persisting Rules Effects) and 01.02.04 (Not on the Battlefield); see `doc/11th-edition-supplied-appendix.md`. Offboard Command Battle-shock, passenger identity/capacity, embark/disembark/emergency timing, Firing Deck, transport Scouts and Aircraft lifecycle must all be implemented and validated before completion. Actual datasheet permissions remain task 17; use explicit fixtures rather than inferred faction permissions. Preserve quad inputs, bounded storage and editor action contracts. No completion evidence is claimed yet.
