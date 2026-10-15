# 11th-edition rules migration roadmap

[The Rulebook design and architecture guide](doc/rulebook-architecture.md) documents the current engine structure and execution paths. The guide is completed documentation work; this roadmap owns implementation status and validation.

This roadmap tracks planning and implementation separately. Tasks 1–5 and 7–16 are complete within their documented scopes. Task6 attachment implementation remains unfinished; the Orks audit now supplies its Orks permission lists, while other factions still require data. Task17 implementation is pending, with its Orks source/requirements audit complete. Task8 retains the user-approved area-only visibility abstraction. Update status and record evidence as work is completed; do not mark a task complete merely because it compiles.

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
| 6 | Core implemented; included Orks permissions validated17.G | Rework attachments and unit characteristics | Implement Leader/Support attachment rules, combined starting strength, bodyguard toughness, keyword inheritance and ability lifetime (pp. 66–67, 86–88). Test what survives when bodyguards or attached characters die. Batch17.G validates the included10 Leader/seven Support lists; other factions still need data, current profiles17.H–P and revival/setup17.J remain separate. |
| 7 | Complete | Correct Command phase and Battle-shock | Implement the prescribed order, Leadership selection, at-or-below-half checks, persistent shock and its restrictions (pp. 8–9, 28–30). Test odd starting strengths, single-model units, already-shocked units and successful recovery. |
| 8 | Complete (user-adjusted scope) | Implement terrain, visibility and objective control | Implement terrain areas, category flags, BS cover and Hidden (pp.46–51). Under the user's explicit abstraction, area crossings give partial obscuration and physical visibility is assumed; physical features, exact obscuring/Solid LOS and feature traversal are deferred. Sum eligible OC, apply boundary control/ties/securing and marker range (pp.52–53,88). Keep mission scoring separate. |
| 9 | Complete | Replace the attack declaration and dice pipeline | Declare weapons and targets before resolution, support split attacks, form permitted attack groups, and implement hit/wound/critical rules (pp. 16–23). Test exact Strength/Toughness thresholds and declarations whose targets change during resolution. |
| 10 | Complete | Replace saves, damage and destruction | Implement save groups and their priority, simultaneous save rolls processed in ascending order, armour/invulnerable comparisons, Precision, normal-before-mortal damage, Feel No Pain, Hazardous and destruction timing (pp. 19–24, 78–88). Test mixed characters, wounded models and group changes during a batch. |
| 11 | Complete (preserved-grid scope) | Update movement and deployment systems | Implement Normal, Advance, Remain Stationary, Fall Back, Ordered Retreat and Desperate Escape (pp. 32–33). Add reserve entry/removal, repositioning, Scouts, Deep Strike, surge and flying movement (pp. 68–71, 78–85). Replace the remaining anchor-only deployment/reserve predicates with checks on every base, and provide an independent model-path decision workflow compatible with Godot. Test placement boundaries and round restrictions. |
| 12 | Complete within deferred-data scope | Update Shooting phase and weapon abilities | Implement normal, assault, close-quarters and indirect modes; engaged Monster/Vehicle shooting; and the revised weapon abilities (pp. 34–35, 62–63, 78–85). Maintain a checklist covering every published core ability, including currently absent ones. |
| 13 | Complete within preserved-grid scope | Replace the Charge sequence | Select the charging unit, roll, then select legal targets and perform the constrained movement (pp. 36–37). Support multiple targets and successful-charge Fights First. Test failed charges, prohibited chargers and incidental engagement with unselected enemies. |
| 14 | Complete within preserved-grid scope | Replace the Fight phase workflow | Implement phase-wide Pile In, alternating fights with the correct starting player, changing eligibility/Fights First, and phase-wide consolidation (pp. 38–43, 87). Test Overrun, newly engaged units and legal passing. |
| 15 | Complete within deferred-data/visibility scope | Implement the revised core stratagems and actions | Implement each core stratagem's exact cost, timing, targets and effects (pp. 54–58). Include end-of-opponent-Movement Overwatch and end-of-Charge Heroic Intervention. Implement generic action eligibility without inventing unavailable mission actions. |
| 16 | Complete within documented grid/data scope | Add transport and aircraft systems | Capacity, embarkation, disembarkation modes, emergency procedures, passenger/reserve interactions and Aircraft exceptions implemented and validated (pp. 64–65, 74). Actual datasheet permissions remain task 17. |
| 17 | Complete within supplied Orks, grid and non-rendering scope | Integrate army data, Godot and full-game validation | Update supplied new-edition datasheets, faction rules and mission configuration. Orks use up to three distinct detachments, no point/DP accounting, and full CP costs. Regenerate bindings and exercise every changed action through Godot, Python and replay. Run deterministic scenarios, completed games and the sanitized fuzzer; turn every discovered failure into a regression case. |

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

### Task 6 — core implemented; included Orks permission fixtures validated

The original deferral ended when the Orks source audit supplied the permission lists and the user authorized task17. Batch17.G implements generic Leader/Support formation, bounded component identity/starting strength, bodyguard-only Toughness, unit/model keyword scope and source lifetimes through destruction/return. All17 included Orks permission lists are implemented and independently cross-checked. Read [the attachment report](doc/attachments.md) and the batch17.G evidence below.

Actual current roster factories/profiles/loadouts/source-specific grants remain17.H–P. Other factions have no invented attachment permission. The revival provenance API is tested; actual heal/revive eligibility/setup remains17.J. Forge World/Legends are excluded. The historical deferred statements under prior task completions describe their state at the time, not a current prohibition.

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

## Task 16 — transports and Aircraft (complete within documented scope)

The user supplied appendix 01.02.02 (Persisting Rules Effects) and 01.02.04 (Not on the Battlefield); see `doc/11th-edition-supplied-appendix.md`. Implementation and validation status follow below. Actual datasheet permissions remain task 17; use explicit fixtures rather than inferred faction permissions. Preserve quad inputs, bounded storage and editor action contracts.

Read [the transport/Aircraft report](doc/transports-aircraft.md). Current schemas are state/observation **16**, action **12**.

- [x] Bounded, explicit transport permissions/capacity, stable passenger storage and formation choices (p.64).
- [x] Post-move embarkation and mandatory Rapid/Tactical/Combat disembarkation with shared setup kernels and movement restrictions (pp.64–65).
- [x] Emergency passenger hazards/setup before carrier Deadly Demise/removal, including unplaceable casualties (p.65).
- [x] Passenger reserve points/expiry, Dedicated Transport Scouts and Firing Deck declarations/turn locks (pp.68–69/81/84).
- [x] Supplied offboard/persisting-effect policy, including reserve/passenger Command Battle-shock and effect expiry.
- [x] Aircraft formations, reserve return/slot reuse, Ingress-only movement and combat/Plunging Fire exceptions (pp.73–74).
- [x] Godot reserve/passenger/offboard selectors, bounded layouts and matching generated artifacts; Rules.gd and TraceManager.gd unchanged.
- [x] Complete Godot sequence, terminal gameplay and current-schema sanitized terminal replay.

**Validation already complete:** RLC **0.4.14**, Clang **21**, **426 supported assertions**, empty discrepancy manifest and **428/428 CTest entries passed in 332.93 seconds** (`task16-fixed-ctest.log`, `/workspace/4hammer-validation/task16-tests`). The **48 focused assertions** pass a standalone Address/Undefined/LeakSanitizer driver (`task16-sanitized-tests/fixed-run.log`). Fresh sanitized fuzzer `task16-fixed-fuzzer` replays both preserved lifetime inputs and the fixed zero input; a new seed40000 campaign completes **47 runs in 61 seconds**, coverage **8,063**, features **13,828**, with no failures or artifacts. LeakSanitizer thread inspection ran outside the sandbox; checks were retained. Short fuzzing does not establish semantic completeness, and current army factories have no supplied real transport permissions; explicit fixtures establish those mechanics.

Fresh matching native/header/C++ Godot artifacts at `/workspace/4hammer-validation/task16-godot` pass the full Godot **4.6.3** headless regression with `--timeout 900` (`task16-final-godot-run.log`). The sequence covers deployment buttons, Command recovery, terrain/objective saves, Firing Deck passenger/model/weapon buttons and offboard context, physical attacks/saves/FNP, pending-state restoration, charge targets/staged paths, core stratagem bearer controls, Pile In and alternating/Fight on Death melee. Earlier assertion failures were diagnosed and fixed, rather than accepted as timeouts. Formation, ordinary/emergency disembarkation and Aircraft decisions have deterministic action coverage and compiled generated bindings; complete editor journeys for those paths remain task17, alongside rendered interaction and the measured enumeration overhead. The larger runner budget is not a speed improvement.

**Identified mistakes fixed:** deployment search retained offboard flags and could mask all collisions, leaving only repeating select/skip choices; prospective candidates now clear those flags, with a fully occupied home-zone regression. The Godot charge fixture assumed slot2 despite an earlier embarked unit retiring that slot; it now uses the actual appended index. That fourth append grows the unit vector and invalidates earlier borrowed element wrappers; charger/model wrappers are now fetched again after the append. Earlier failed gameplay/Godot outputs remain external diagnostic artifacts and are not passing evidence. The user directs transport-in-transport to assert when otherwise eligible; ordinary permission/capacity rejection precedes that assertion.

The corrected seed **40000** full-game check completes **920 actions**, terminal owner **-4**, with **23,387 enumerated candidates** (`task16-fixed-gameplay.log`). Its current-schema sanitized replay passes in **52,503 ms** (`task16-fixed-terminal-replay.log`). It destroys one unplaceable deployment unit, has five cancelled charge attempts and selects no fights; this is completion/ownership evidence, not transport or combat semantic coverage. The schema16 gym check completes **20 steps** with **13,949,421 finite observations** and no not-tensorable warnings (`task16-gym.log`); the later deployment-search fix changes no numeric layout.

**Mandatory remaining scope:** actual transport/passenger permissions and points, complete datasheets, sourced faction/mission/offboard effects, rendered interaction and the measured wrapper-fetch performance fix remain task17; attachments remain deferred task6. Preserve the user-directed quad/area-only geometry scope and the report's fixed-other-model emergency closeness limit. No unsupported nested transport mechanics or faction rules are invented. Every identified remaining issue must still be fixed by its owner.

At task16 completion, task17 was next and task6 still awaited full datasheets. The following Orks audit now supplies its Orks permission lists; implementation remains pending.

## Task 17 — Orks implementation and scoped integration complete

The user now supplies the readable [Orks faction page](https://wahapedia.ru/wh40k11ed/factions/orks/) and directs this scope: **no army/unit/enhancement points, no detachment costs, up to three distinct selected detachments per player, and full CP costs**. This replaces the previously proposed point/DP-accounting batch. Do not make War Horde use three selection slots. Preserve non-price equipment/ability/attachment conditions and the user-directed quad/visibility/numeric-storage scope.

Use [the complete codebase audit and batch plan](doc/orks-codebase-audit.md), [the 67-unit requirements matrix](doc/orks-unit-requirements.tsv) and [the 40-stratagem CP inventory](doc/orks-stratagem-costs.tsv). Every linked datasheet was retrieved and examined on 2026-10-12, including 12 Legends entries and one Forge World entry. Fourteen Leader lists and seven Support lists now provide Orks attachment permissions. The appendix is also readable and supplies healing/revival definitions; availability is not implementation.

**Supported unit scope (user update):** implement the54 standard Orks datasheets. All12 Legends cards and the Forge World Gargantuan Squiggoth are excluded. The67-card audit/catalog remains historical source coverage; `implementation_scope` in the requirements matrix distinguishes the54 included rows from13 excluded rows. Later unit/geometry/transport/attachment batches must derive their requirements from included sources.17.C4b remains generic appendix02.02.02 support, with explicit fixtures rather than an excluded unit implementation.

- [x] **17.A:** Read the faction page, all 67 datasheets and relevant appendix definitions; classify per-unit engine/data requirements, source variants, geometry gaps and CP cards. Verify complete coverage without modifying game code.
- [x] **17.B:** Separate army identity, select up to three unique detachments, support point-free reserve configuration and retain correct CP eligibility/payment, discounts, surcharges and explicit target exceptions.
- [x] **17.C1:** ALL/ANY/NONE keyword predicates, explicit unit/model scope, actual weapon/Hunter target consumers, saved metadata validation and editor labels. Retire obsolete Orks runtime cards under the user's new instruction.
- [x] **17.C2:** Effective characteristic consumers and named weapon/unit selectors, preserving source scope, random-characteristic timing, arithmetic order and special values.
  - [x] **17.C2a:** Sparse bearer-scoped M/T/Sv/InSv/Ld/OC arithmetic, actual movement/attack/save/Leadership/objective consumers and mixed-Toughness maximum fix.
  - [x] **17.C2b:** Weapon characteristic consumers.
    - [x] **17.C2b1:** Effective fixed Range/WS/BS/S/AP, slot/bearer scope, ordered core increments, group identity/T refresh and actual targeting/hit/wound/save consumers.
    - [x] **17.C2b2:** Effective A/D, fixed melee shares, random-characteristic timing/re-rolls and complete damage grouping. Preserve the user-required assertion for nonexistent random-A melee weapons.
  - [x] **17.C2c:** Named physical-weapon/profile and datasheet selectors, with actual source consumers; live aura/conditional grants retain their later batch owners.
- [x] **17.C3:** Damaged remaining-wounds metadata and the hit-roll consumer, applied before the cumulative +/-1 cap.
- [x] **17.C4:** Incoming AP/damage reductions and selective modifier ignoring, with actual save/damage consumers and grouping boundaries.
  - [x] **17.C4a:** Recipient-specific incoming AP/D arithmetic, ranged/melee scope, actual saves/normal/Devastating damage, restore checks and identical-attack boundaries. Implemented and validated; see final evidence below.
  - [x] **17.C4b:** Explicit optional subset selection for ignore-modifier permissions (appendix02.02.02), including generic WS/BS and hit-roll consumers; preserve chooser ownership, core modifier provenance and Godot action discovery. Do not substitute an automatic negative-only filter.
- [x] **17.D–E:** Physical weapon capacity/profile selection, compound dice and source-instance event/use/effect records. The user requested implementing/testing D and E together to share expensive compilation. Keep distinct implementation commits.
  - [x] **17.D1:** Physical profile capacity/copies, Nazdreg’s explicit profile exception and physical Hazardous/One Shot provenance.
  - [x] **17.D2:** Compound D3/D6 characteristics/constants, whole-roll re-rolls, actual A/D/M/demise consumers, grouping and save codec.
  - [x] **17.E:** Stable source events/limits, owned timed grants, offboard/archive expiry, live unit auras and explicit editor source choices. Actual source abilities remain their later batches.
- [x] **17.F:** Current Waaagh!/riled-up consumers, War Cry, Da Boss and user-supplied Warlord selection; source/profile metadata remains each actual datasheet's owner.
- [x] **17.G:** Source-backed Orks Leader/Support attachments and task6 lifecycle, using the included10 Leader/7 Support permission lists.
- [x] **17.H:** Replace the existing three Orks unit families with current profiles, equipment and source-specific abilities; review included loadout capacities and oval geometry.
  - [x] **17.H1:** Current profiles, literal composition/loadout constructors, named physical profiles/Hunter restrictions and data/HTML cross-checks; keep incomplete adapters out of the production roster.
  - [x] **17.H2:** Each source-specific ability: Dodge Dis!, Keep Huntin', Mobbed, Bomb Squig and Brutal Impact, with actual event/target/damage/shock consumers.
  - [x] **17.H3:** User-authorized temporary circular proxies for supplied75x42/90x52 oval bases: preserve source axes, use75/90mm long-axis diameters consistently on existing quad anchors and in Godot; exact oval geometry deferred.
  - [x] **17.H4:** Promote completed current adapters into the existing Orks roster; validate actual selection, attachments, combat, saves and full games.
- [x] **17.I–N:** War Horde one rule/card at a time; healing/revival; carrier permission/seating and Trukk; special/reactive movement; hit/kill provenance and post-attack effects; psychic systems and their units.
  - [x] **17.I1:** War Horde Get Stuck In passive, actual selected-package/ORKS-unit/melee gating and duplicate Sustained Hits choice; implemented/tested alongside17.H4 with shared validation.
  - [x] **17.I2:** War Horde enhancements/upgrades and all six CP cards, validated in the combined ordinary-detachment batch below.
- [x] **17.O–P:** Remaining ordinary detachments and every remaining datasheet by dependency family. Include the additional Runt Swarm replacement/hit-interception systems. Preserve oval metadata and use the user-authorized long-axis circle approximation for now; hull/multipart dimensions remain explicit dependencies. Keep grid coordinates.
  - [x] **17.O:** All15 ordinary detachment passives,38 enhancements/upgrades and40 CP cards, including Runt Swarm replacements/interception; see combined completion evidence below.
  - [x] **17.P:** All51 additional standard datasheet adapters, actual carrier seating/permissions and source-specific unit rules are implemented and validated in17.P1–P3; all54 included cards have adapters. Arbitrary public roster selection remains17.Q.
- [x] **17.Q:** Complete the arbitrary current-card roster picker, non-rendering combination/integration checks, saves/replays/ML, representative full games and sanitized fuzzing; review errors and simplify shared code. User update2026-10-15 excludes rendered integration and assigns valid-action discovery/wrapper-filtering optimization to the compiler; earlier performance/rendered requirements below are historical and superseded. Fix all other identified mistakes.

**Confirmed work that must be fixed:**17.D resolves the eight-slot Stompa capacity defect with a reviewed13-profile envelope; actual unit loadout quotas/data remain pending; 17.C1 resolves the former positive-OR-only weapon/Hunter predicate defect; other scoped condition consumers remain pending; transport permission OR-lists and universal integer seat costs cannot implement all nine included carrier requirements or grouped Gretchin rounding. Static attack-characteristic getters and boolean bonuses lack several modifier consumers. 17.E resolves generic source-instance event/use/effect tracking alongside legacy timing groups; source-specific reactive movement/shooting handlers remain17.L/M. Healing/revival, psychic budgets, post-shoot hit ledgers, Kommandos formation splitting and Runt Swarm replacement/hit interception need implementation. Thirty datasheets require oval/hull/multipart footprint work or additional dimensions. Batch17.B resolves the point-dependent reserve gate through explicit point-free public configuration. These are requirements from source/code inspection, not newly passing tests.

**Audit verification:** exactly 67 unique unit rows match the faction page's linked datasheets, all downloads succeeded, all source-labelled records are 11th edition, and all requirement IDs resolve to the audit. The 40 ordinary CP-card rows match the source cards; Hulking Brutes records its optional +1CP, and Infested War Zone records its 2CP base. Batch17.A made only documentation changes; implementation tests were not rerun for that audit because no game or test code changed. Source snapshots/hashes are outside the checkout at `/workspace/4hammer-validation/orks-audit-2026-10-12`.

Task6's Orks source deferral and shared mechanics are resolved in17.G; other factions still need permission data. **17.C4–17.H and17.I1 are complete within their recorded scope and the user-approved circle approximation. Next:17.I2 (War Horde upgrades/cards), alongside17.J healing/revival where independent.** Exact ovals are deferred by user direction. Mark later batches complete only after their actual rule, binding and sanitizer validation. Missing dimensions, source ambiguities and preserved visibility limits remain explicit dependencies; ignoring prices does not authorise inventing alternate reserve percentages or removing CP restrictions.

### Batch17.B — implemented and validated

Read [the configuration report](doc/orks-configuration.md). Army identity is separate from the preserved legacy roster enum; each player can select zero to three distinct packages from all 15 ordinary Orks detachments. Third selection automatically hands off. Public games explicitly use point-free reserves, including carriers/passengers, while existing point-aware fixtures retain their configured cap checks. Forty Orks cards now have source-backed CP costs and selected-package gates; shared eligibility supports printed shocked/destroyed target exceptions, free use and +1CP surcharges with unchanged expenditure/use limits. Card effects/full timing and keyword conditions remain later batches.

**Issues found and fixed:** the Chaos and Morgrim roster factories returned the Tyranid identifier; both now return their own legacy IDs. Explicit final-cost inputs previously bypassed the +1CP increase cap; common eligibility now rejects that bypass atomically. The initial schema17 build accidentally retained upper bound17; the corrected half-open `[17,18)` storage restores every save test. No point/DP system, alternate reserve percentage, grid migration or custom lifecycle hook was introduced.

**Validation:** 442 supported assertions / 444 individual CTest entries pass, with empty discrepancies; final CTest took 339.42 seconds at `/workspace/4hammer-validation/task17b-tests`, log `task17b-ctest-final.log`. Sixteen focused native assertions pass address/undefined-behavior sanitizers with leak detection (`task17b-sanitized-tests`, `task17b-sanitized-run.log`). The configuration-only intermediate commit passes type checking. All 40 registered costs/package gates match the source inventory. Fresh matching native/header/C++ bindings pass the full headless Godot harness (`task17b-godot`, `task17b-godot-run.log`), including actual detachment buttons/pending save/both-player handoff and existing deployment/Command/terrain/attacks/transports/charges/Fight controls. Rules.gd and TraceManager.gd remain unchanged; actual interactive rendering is still 17.Q.

Seed40000 selects Morgrim with Wreckas/Runt Swarm, uses point-free reserves and completes **571 actions**, terminal owner **-4** (`task17b-replays`). Its matching sanitized replay and both preserved lifetime inputs plus the fixed zero input pass. Fresh mutation fuzzing completes **25 runs /64s**, coverage 8,191 / features 11,422, without sanitizer failures or crash artifacts (`task17b-fuzzer`, `task17b-fuzz.log`). The 20-step ML check reports **23,404 candidates /13,952,097 finite observations**, with no not-tensorable diagnostics (`task17b-gym.log`); gameplay/ML reuse the fresh CTest wrapper importing full_game. Schemas are state/observation **17**, action **13**. These checks certify this configuration/CP batch, not complete Orks rules or any current datasheet. Next is 17.C; attachments, detachment/card effects, all 67 data migrations and wrapper performance remain assigned later work.

### Batch17.C1 — compound keyword predicates and obsolete card removal

- [x] Add bounded ALL/ANY/NONE conditions and explicit unit/model keyword queries (appendix02.05.01).
- [x] Apply conditions to weapon presence/magnitude, selected and temporary ANTI, Hunter declarations/replacement and duplicate-instance selection.
- [x] Validate saved condition roots/archives and display compound duplicate-ability labels through typed Godot bridges.
- [x] Remove obsolete Tough as Squig Hide and Bestial Bellow runtime cards under the user's instruction; retain uncertified profile factories only as temporary17.H scaffolding.
- [x] Pass465 supported assertions /467 CTest entries,24 native sanitized cases, full compact headless Godot and focused final-body Godot coverage.

Read [the predicate report](doc/orks-keyword-predicates.md) for source semantics, save-validation limits and precise artifact provenance. State/observation schemas are18, action14 and next-state19. The initial per-term categorical tags doubled ML observations; compact grouped storage fixes that mistake and produces14,493,920 finite observations (+3.9% over17.B), without tensor warnings. Action candidates are22,379 after card removal; coordinate domains are unchanged. Seed40000 completes878 actions, terminal owner-4, and gym passes20 steps. The full compact Godot interaction harness predates the final body-only temporary-ANTI filter fix; fresh final bindings and a focused regression cover that fix, as do the final CTest and sanitizer suites.

The final-source sanitized fuzzer (`task17c1-verified-fuzzer`) replays both preserved lifetime inputs, the fixed zero input and the878-action completed game with leak detection (`task17c1-replay-verified.log`); the game replay takes27.717s. Fresh mutation fuzzing completes **54 runs in67s**, coverage11,391 /features16,623, without sanitizer failures or crash artifacts (`task17c1-fuzz-verified.log`). **Next:17.C2**, effective characteristic consumers and named selectors;17.C3 Damaged and17.C4 incoming reductions/ignoring modifiers remain pending. No datasheet, Waaagh!, attachment, detachment effect or CP-card effect is certified by this predicate batch. Every remaining issue retains its assigned owner, including the wrapper-fetch performance fix in17.Q.

### Batch17.C2a — model characteristic queries and consumers

- [x] Add one sparse, bounded16-record model modifier list and reuse supplied operation order/rounding/limits (appendix02.02.01).
- [x] Integrate effective M/T/Sv/InSv/Ld/OC into movement budgets/path validation, initial attack configuration, Crushing Impact, save groups, Leadership and objective/action eligibility.
- [x] Fix the shadowed Toughness maximum (appendix05.02.01); exclude offboard models and retain battlefield Fight on Death constituents until removal.
- [x] Preserve absent InSv, replacement-zero locking and Battle-shock OC; reject invalid live/archived modifier metadata and assert bounded Toughness snapshot capacity.
- [x] Pass477 assertions /479 CTest entries,12 final native sanitizer cases and fresh matching focused Godot bridges.

The final suite passes in249.04s (`task17c2-model-ctest-verified.log`) with an empty discrepancy manifest. Native/header/C++ artifacts in `task17c2-model-final-godot` pass the model-characteristic and keyword-predicate scripts; the entire interaction harness/rendered journeys were not rerun. The final sanitized fuzzer replays both lifetime regressions, zero input and schema19 game; mutation fuzzing completes51 runs in64s, coverage11,407 /features16,643, without failures/artifacts. Read [the report](doc/model-characteristics.md) for provenance and scope. A concurrent compilation exceeded the old300s fixture ceiling; the separate infrastructure change permits600s for compilation only, retaining30s individual assertion limits.

Schemas are state/observation19, action14 and next-state20. Final-source seed40000 completes **878 actions**, terminal owner **-4**, and its replay bytes match the validated sanitized replay (`task17c2-model-gameplay-final.log`, `task17c2-model-final-replays`). The final20-step ML check reports **22,379 action candidates /16,932,944 finite observations**, without tensor warnings (`task17c2-model-gym-final.log`). Sparse model arithmetic adds about16.8% to observations; action domains/grid coordinates remain unchanged. **Next:17.C2b**, weapon characteristic arithmetic, random timing and complete effective grouping, including live target-T refresh after changes between groups. Named selectors remain17.C2c. Attached bodyguard-only selection and source-instance/aura/expiry consumers retain17.G/17.E owners. No datasheet or detachment effect is certified, and17.C2 remains in progress.

### Batch17.C2b1 — fixed weapon characteristics and group context

- [x] Add bounded profile-slot scope to the shared16-record modifier list; preserve bearer-wide WS/BS and borrowed Firing Deck distinctions.
- [x] Use effective Range for targeting/replacement/half-range, effective S for wound/protection, and effective AP for saves.
- [x] Combine cover/Plunging Fire/AP increments at the printed addition step; preserve Melee/Torrent and replacement-zero semantics.
- [x] Compare effective skill/S/AP for grouping, including equivalent values from different modifier records.
- [x] Refresh explicit source/target IDs and current battlefield T for every new group; add direct identity/keyword/casualty regressions.
- [x] Pass497 assertions /499 individually registered CTest entries,20 final native sanitizer cases and matching final focused Godot bridges.

The final suite passes in246.70s (`task17c2b1-ctest-complete.log`), with an empty discrepancy manifest. The20-case sanitizer driver uses leak detection (`task17c2b1-sanitized-run-verified.log`). Fresh native/header/C++ artifacts in `task17c2b1-verified-godot` pass weapon and prior model scripts, including explicit IDs against a neutral context (`task17c2b1-godot-verified.log`, `task17c2b1-godot-model-verified.log`); the entire interaction harness/rendered journeys were not rerun. The final `task17c2b1-verified-fuzzer` replays both preserved lifetime inputs, zero input and schema20 game, with the game input taking27.236s. Fresh mutation fuzzing completes54 runs in65s, coverage11,407 /features16,683, without sanitizer failures/artifacts.

The fixed-characteristic build completes seed40000 in878 actions, terminal owner-4 (`task17c2b1-gameplay.log`); after the body-only explicit-ID correction, the final sanitized fuzzer replays that matching input. The20-step ML check reports22,379 candidates /17,050,509 finite observations, without tensor warnings (`task17c2b1-gym.log`). Layout is unchanged by the ID correction. Sparse scope/operation snapshots add about0.7% over17.C2a; coordinate/action domains remain unchanged. State/observation schemas20, action14 and next-state21. Read [the report](doc/weapon-characteristics.md) for exact source semantics and validation limits. The separate context/T commit's source snapshot type-checks before the scoped modifier commit.

**Next:17.C2b2**, A/D arithmetic, fixed melee shares, random timing/re-rolls and complete damage grouping; keep the user's nonexistent-random-melee-A assertion. Named selectors remain17.C2c, followed by17.C3/C4. Source-instance/aura/expiry, attached bodyguard-only T and datasheets retain17.E/17.G/17.H owners. No current datasheet is certified and17.C2b/17.C2 remain in progress.

## Batch17.C2b2 validation

[The A/D report](doc/weapon-attacks-damage.md) documents bearer/profile A before fixed melee shares, independent ranged A gathering, post-allocation per-attack D, original dice/re-rolls before arithmetic, ordered core increments, zero-A selector avoidance and effective fixed/random D grouping. The user-required random-melee-A assertion remains. This is engine infrastructure; current Orks grants and profiles are still pending.

Final frozen CTest passes **509 assertions /511 entries**, empty discrepancies, **292.22s** (`/workspace/4hammer-validation/task17c2b2-ctest-final.log`). All **12** final focused native cases pass ASAN/UBSAN and leak detection (`task17c2b2-sanitized-final.log`). Matching generated/native/C++ bindings in `task17c2b2-godot` pass focused weapon and model scripts; full rendered/interaction journeys were not rerun. The earlier CTest attempt rejected a changing declaration list and is superseded, not passing evidence.

The final fuzzer passes both preserved lifetime inputs and fixed zero input (`task17c2b2-replay-preserved.log`). Fresh short-seed mutation fuzzing completes **24 runs /69s**, coverage8,139 /features11,381, without failures/artifacts (`task17c2b2-fuzz.log`). Gym passes20 steps, **22,379 candidates /17,051,447 finite observations** (`task17c2b2-gym.log`), only938 more observations than the prior batch. State/observation21, action14, next-state22; quad/action domains and production Rules.gd/TraceManager.gd remain unchanged.

Current-schema seed40000 completes **878 actions**, terminal owner-4 (`task17c2b2-gameplay.log`, `task17c2b2-replays/full_game-seed-40000.{json,trace,bin}`). The final sanitized replay passes in **32.115s** (`task17c2b2-replay-game.log`). These scaffold-roster integration checks do not certify current Orks data.

**17.C2b2 and17.C2b are complete. Next:17.C2c**, named physical-weapon/profile and datasheet selectors, followed by17.C3/C4. Source instances, compound profiles, attachments and datasheets retain their later owners.17.C2/task17 remain in progress. All identified errors must still be fixed by their owning batches.


## Batch17.C2c completion

[Named-selector report](doc/named-selectors.md) and [source crosswalk](doc/orks-named-identities.tsv):67 datasheets,139 physical weapon families,176 named profiles and330 source rows, including separately marked referenced enhancement/ability profiles. All standard datasheet row counts match the audit. Correct identical printed names with distinct ranged/melee identities for Stikka, Grabba Dragga and Snagga Klaw; validate actual attack-kind consistency. This catalog imports identities, not stats/loadouts or active faction grants.

Conjunctive slot/physical/family/profile modifiers now feed actual Range/skill/S/AP/A/D consumers. Named/physical rule grants feed selected per-slot declarations. Unit/model named scope remains distinct; archives and saves preserve compact tags. Firing Deck snapshots passenger identity while using carrier numerical grants and excluding carrier equipped-instance grants. Generated lifecycle, quads and production Rules.gd/TraceManager.gd remain intact.

Final CTest passes **534 assertions /536 entries**, empty discrepancies, **280.40s** (`/workspace/4hammer-validation/task17c2c-final-ctest.log`). All **25** focused native cases pass ASAN/UBSAN/leak detection (`task17c2c-final-sanitized.log`). Matching header/native/C++ in `task17c2c-final-godot` passes named and prior weapon scripts; full rendered/interaction journeys were not rerun. Earlier non-final builds predate the catalog correction and are superseded.

Schemas: state/observation22, action14, next-state23. Gym passes20 steps with **22,379 candidates /17,523,864 finite observations**, about2.8% growth (`task17c2c-final-gym.log`). Current-schema seed40000 completes **878 actions**, terminal owner-4 (`task17c2c-final-gameplay.log`, `task17c2c-final-replays`); the final sanitized game replay passes in **32.531s** (`task17c2c-final-replay-game.log`). Both lifetime inputs and fixed zero pass separately. Fresh short-seed mutation fuzzing completes **50 runs /62s**, coverage8,331 /features14,019, without failures/artifacts (`task17c2c-final-fuzz.log`).

**17.C2c and17.C2 are complete. Next:17.C3**, Damaged remaining-wounds metadata and hit penalty before cumulative +/-1, then17.C4 incoming reductions/selective ignoring. O02/task17 remain partial; source installation/expiry17.E, compound/capacity17.D, attachment17.G and actual current datasheets17.H and subsequent families remain mandatory. Every identified error, including the17.Q wrapper bottleneck, retains its fixing owner.


## Batch17.C3 completion

[The Damaged report](doc/damaged.md) records website core ability24.39, verified in the cached Battlewagon tooltip. Explicit bearer metadata feeds each gathered group's current remaining-wounds status. The penalty joins hit modifiers before their cumulative cap; healing refreshes it, mixed models remain independent, retained Fight on Death models qualify and Firing Deck uses the carrier. Threshold zero is permitted; raw invalid metadata is rejected. No current datasheet grant is installed.

Final CTest passes **546 assertions /548 entries in370.03s** (`/workspace/4hammer-validation/task17c3-ctest-verified.log`). All12 focused native cases pass ASAN/UBSAN/leak detection (`task17c3-sanitized-verified.log`, driver `task17c3-sanitized/driver-verified`). Initial enum syntax, duplicate fixture identity and assumed BS errors were corrected; earlier runs are superseded. Matching native/header/C++ artifacts in `task17c3-godot` pass the Damaged and prior weapon scripts; full rendered/interaction journeys were not rerun.

Schemas are state/observation23, action14, next-state24. Seed40000 completes878 actions, terminal owner-4 (`task17c3-gameplay.log`, `task17c3-replays`). Gym passes20 steps with22,379 candidates /17,538,387 observations (+14,523, about0.083%); action/grid domains remain unchanged (`task17c3-gym.log`). The sanitized fuzzer replays both preserved lifetime inputs, the fixed zero input and the completed game, whose replay takes34.252s (`task17c3-replay-verified.log`).

Fresh short-seed mutation fuzzing completes **50 runs in61s**, coverage11,254 /features18,064, without sanitizer failures or crash artifacts (`task17c3-fuzz-verified.log`, empty `task17c3-fuzz-artifacts`). This bounded robustness check does not certify every rule or current datasheet.

**17.C3 is complete. Next:17.C4**, incoming AP/D reductions and selective modifier ignoring in actual save/damage/grouping consumers. O02/task17 remain partial; actual Orks profiles/grants, live sources, attachments and later families retain their owners. All identified errors must be fixed by their owning batches, including the17.Q wrapper bottleneck.


## Batch17.C4a completion

[The incoming AP/D report](doc/incoming-attack-modifiers.md) records source-backed recipient arithmetic, explicit ranged/melee scope and real allocation/save/normal/Devastating consumers. Incoming operations merge before rounding/floors; ordinary non-attack mortal jobs bypass weapon D. Printed W/Sv/InSv allocation groups remain intact, while attack identity checks every live recipient's complete AP/D mapping. Restore validation and generated lifecycle preserve bounded state. This implements generic support, not current unit profiles or source grants.

Final CTest passes **558 assertions /560 entries in404.27s**, empty discrepancies (`/workspace/4hammer-validation/task17c4a-final-ctest.log`). All12 focused native cases pass ASAN/UBSAN/leak detection (`task17c4a-sanitized.log`, `task17c4a-sanitized/driver`). The initial fixture used an unavailable CheckedVector.empty helper; its corrected size comparison is in the final verified build. The superseded first run is not passing evidence.

Matching native/header/C++ artifacts in `task17c4a-godot` pass the incoming-modifier and prior weapon scripts (`task17c4a-godot.log`, `task17c4a-godot-weapon.log`); full rendered/interaction journeys were not rerun. Schemas are state/observation24, action14, next-state25. The20-step Gym check reports **22,379 action candidates /18,932,339 finite observations**, +1,393,952 (about7.95%) (`task17c4a-gym.log`). Grid/action domains and production Rules.gd/TraceManager.gd remain unchanged. Gameplay/ML reuse the newly compiled CTest wrapper importing full_game; they do not reuse the prior batch's native library.

The sanitized fuzzer passes both preserved lifetime inputs, the fixed zero input and the existing878-action game replay, taking **33.921s** for that game (`task17c4a-replay.log`). Fresh short-seed mutation fuzzing completes **31 runs in62s**, coverage8,188 /features11,508, without sanitizer failures or crash artifacts (`task17c4a-fuzz.log`, empty `task17c4a-fuzz-artifacts`). These scaffold rosters do not install new incoming grants; the12 focused tests supply those explicitly. The campaign verifies robustness, not complete faction rules.

Fresh schema24 seed40000 completes **878 actions**, terminal owner **-4** (`task17c4a-gameplay.log`, `task17c4a-replays`). Its input bytes match the sanitized replay exactly. **17.C4a is complete.** **Next:17.C4b**, optional arbitrary subset selection for selective modifier ignoring, including WS/BS/hit-roll permissions, correct chooser ownership and Godot discovery.17.C4/task17 and O02 remain partial. Source installation/expiry and actual profiles/grants retain their later owners; all identified issues, including17.Q wrapper retrieval performance, must be fixed by the owning batches.


## Shared17.D/E completion

The user requested implementing these independent batches together with shared costly validation. [Physical weapons/compound dice](doc/physical-weapons-compound-dice.md) records the reviewed13-profile envelope, ordinary physical-copy exclusivity, explicit Nazdreg simultaneous-profile permission, One Shot/Hazardous provenance, original compound dice/constants, complete summed re-rolls and actual A/D/M/demise consumers. [Source events/effects](doc/source-instances-effects.md) records stable source identity, current-player/opponent ownership, optional/mandatory choices, conjunctive army/unit/model limits, independently owned expiry across every bank/archive and live unit auras. Numerical/incoming/weapon grants reach their actual consumers; returned/transferred constituents and forged saved handles have explicit coverage.

Final compiler packages are **rl_language/rl_language_core0.4.17**, installed from public PyPI because the mirror initially lagged. Every build uses **-j4**. Debug builds are **unoptimized**; separate optimized sanitizer/fuzzer validation uses **-O2**. The unchanged standalone constant-loop reproduction that leaked128 bytes in0.4.16 now passes with leak detection. Both original capacity fixtures pass without workarounds or custom init/drop. The earlier theory that unused Board copies caused the leak was incorrect: constant-expression control flow omitted generated cleanup. Earlier0.4.14/16 builds are superseded by the final0.4.17 evidence.

Final CTest: **596 supported assertions /598 entries**, empty discrepancy manifest, **598/598 pass in436.45s** (`task17de-compiler17-ctest.log`, `task17de-compiler17-tests`). All **38 focused cases** pass Address/Undefined/LeakSanitizer in **both debug and optimized builds**, with leak detection enabled (`task17de-sanitized/driver-debug17` and `driver-optimized17`, corresponding logs). Four compiler workers are now configurable through `RULE_TEST_COMPILER_JOBS`; CTest process parallelism is independent. `RULE_TEST_OPTIMIZE` defaults OFF. This concurrent build duration is not a controlled comparison of compiler speeds.

Matching freshly generated header/native/C++ artifacts are in `task17de-compiler17-godot`. The new source/weapon script and prior weapon script pass. Coverage includes the **production source-choice panel/button and label**,13 slots, compound inputs and phase expiry (`task17de-compiler17-godot-source-final.log`, `task17de-compiler17-godot-weapon-final.log`). Earlier failed harness attempts are superseded by these final matching-library checks. Full rendered journeys remain17.Q. Production Rules.gd/TraceManager.gd are unchanged.

Schemas are **state/observation25, action15, next-state26**. Final20-step Gym passes with **22,678 candidates /25,682,905 finite observations**, without tensor warnings (`task17de-compiler17-gym.log`). This is299 additional action candidates (+1.34%) and6,750,566 observations (+35.65%) versus17.C4a; grid domains are unchanged. Wrapper retrieval performance remains a mandatory17.Q fix.

The final optimized sanitized fuzzer `task17de-compiler17-fuzzer` passes both preserved lifetime inputs, a fixed zero input and the completed878-action current-schema game input (`task17de-compiler17-replay.log`). The game replay takes56.749s while other checks run; this is not a controlled speed benchmark. A fresh short-seed campaign completes **41 runs in62s**, coverage13,571/features22,614, with no sanitizer failure or artifacts (`task17de-compiler17-fuzz.log`, `task17de-compiler17-fuzz-artifacts`). Earlier0.4.14 mutation work emitted a slow-unit artifact, not a crash; retain `task17de-fuzz-artifacts/slow-unit-9b077bbd55fc3718e25dd9b80b89423cd9495633` for17.Q performance work.

Fresh 0.4.17 seed40000 completes **878 actions**, terminal owner **-4**, with all legal-choice/text round trips checked (`task17de-compiler17-gameplay.log`, `task17de-compiler17-replays`). Its input bytes match the successfully replayed final fuzzer input exactly.

**17.D1/D2 and17.E are complete. Next:17.C4b**, optional arbitrary modifier subsets with correct chooser ownership and editor discovery. Task17/O02 remain partial. Actual included Nazdreg/Stompa/standard profiles/loadouts/source abilities, Waaagh/riled-up, attachments, healing/revival, reactive movement/shooting, hit/kill/psychic provenance and datasheet-specific effects remain their named later batches. Model/wholly-within auras require exact source adapters;64-instance/effect/use capacities and4096 monotonic handles must be reviewed against playable army combinations. Unsupported oval/hull geometry remains explicit. All remaining identified errors must be fixed by their owners.

The onboarding install/start draft pins0.4.17 and documents four workers, unoptimized debugging and separate optimized validation. It is saved, not published.


## Batch17.C4b completion

[Optional attack modifier subsets](doc/modifier-ignoring.md) implements appendix02.02.02 for explicit WS/BS and hit-roll permissions, scoped to any/ranged/melee attacks. Original re-rolls precede per-attack Apply/Ignore choices, including beneficial items. Authored skill operations, Cover/Plunging Fire and individual Heavy/Damaged/engagement/ordinary/profile hit contributions retain provenance until subset arithmetic. Natural gates, ordered operations/rounding/limits and±1 hit cap remain. Mixed bearers/different available subsets cannot share permission through grouping. Empty/unpermitted choices retain the aggregate path. Typed source permission grants share exact-key overlap/expiry, offboard/archive cleanup and returned-member refresh.

**User scope update applied:** only54 standard Orks datasheets are planned. The12 Legends and Gargantuan Squiggoth Forge World card are excluded in AGENTS/audit/requirements. Historical67-card catalog identities remain stable. No excluded unit grant or factory is installed.17.G derives attachment permissions from included rows (10 Leader,7 Support);17.K/P derives9 included carrier requirements.17.H must recheck loadout capacity against included data; the existing13-profile engine envelope is not an obligation to implement excluded Kill Tank. General ignore consumers beyond WS/BS/hit belong to the17.H–P source adapter that introduces such an included rule.

Final RLC/core0.4.17:619 supported assertions, empty discrepancy manifest, **621/621 CTest entries pass in325.08s** (`task17c4b-tests`, `task17c4b-ctest-final.log`). All23 focused cases pass unoptimized native Address/Undefined/LeakSanitizer with leak detection (`task17c4b-sanitized/driver-final`, `task17c4b-sanitized-final.log`). Debug builds remain unoptimized, four workers; the optimized sanitized fuzzer is separate. Earlier context/skill/indirect fixture failures are superseded by corrected final assertions.

Matching native/header/C++ Godot artifacts (`task17c4b-godot`) pass actual one-Bool choice methods and production Apply/Ignore buttons/labels, owner restoration, typed permissions and existing source/weapon checks (`task17c4b-godot-ignore.log`, `task17c4b-godot-source.log`, `task17c4b-godot-weapon.log`). Rules.gd/TraceManager.gd and quad coordinate domains remain unchanged. Full rendered journeys remain17.Q. No custom init/drop was added.

Schemas **state/observation26, action16, next-state27**.20-step Gym passes **22,680 candidates /26,032,968 finite observations**, without tensor warnings (`task17c4b-gym.log`):+2 candidates and+350,063 observations (~1.36%) versus17.D/E. Matching policies are required. Wrapper retrieval performance remains17.Q, not a claimed speedup.

The final optimized sanitized fuzzer (`task17c4b-fuzzer`) passes both preserved lifetime inputs, zero input and the preceding878-action complete-game input; that fixed replay takes60.824s (`task17c4b-replay.log`). Fresh short seeds complete **43 mutation runs in63s**, coverage13,701/features22,656, no sanitizer failures or crash artifacts (`task17c4b-mutation.log`, `task17c4b-corpus`, `task17c4b-artifacts`). Legacy armies carry no new permission; focused fixtures establish its semantics. Fixed replay and mutation are distinct checks.

Fresh schema26 seed40000 completes **878 actions**, terminal owner **-4**, with payload round trips and owner checks (`task17c4b-gameplay.log`, `task17c4b-replays`). Its input bytes equal the sanitized replay exactly; completion therefore has matching final-engine replay coverage. The Python wrapper path remains slow and belongs to17.Q.

**17.C4b and17.C4 are complete within the explicit WS/BS/hit scope. Next:17.F**, Waaagh!/riled-up, War Cry and Da Boss. Task17/O02 remain partial: actual included profiles/grants, other ignore consumers when required, specialized reactions/aura modes, attachments, healing/revival, movement/shooting reactions, hit/kill/psychic provenance and remaining54 datasheets retain their owners. All identified issues must be fixed by their owning batches, including17.Q wrapper retrieval. Unsupported oval/hull geometry and user visibility abstraction remain explicit.


## Batch17.F completion

[Orks army rules](doc/orks-army-rules.md) implements current Waaagh! Advance re-rolls; source-owned riled5+ InSv/ranged Assault/Advance charge permission; optional once-per-army-battle War Cry at either Command start through the end of the next turn; mandatory selected-Warlord Da Boss1CP at round start; and the user-supplied unit/model Warlord definition. It does not add old-edition melee A/S boosts. Live explicit metadata, faction/Character keywords, required unit/model rules and prohibitions govern Warlord selection. The selected model gains WARLORD and the army stores its stable identity. Other players, dead/different models and spare indices cannot substitute.

Riled status is one typed source grant with exact-key overlap/expiry/returned-member/archive handling. A new own-unit passive mode follows its source model's current unit across battlefield/reserve/passenger banks without external measurement, and ends on source death/disablement. War Cry's accepted effects survive the source unit's death and expire after next-turn end effects. Actual equipped and Firing Deck Assault snapshots keep the source key. Advance charge permission is captured at selection and reset at turn boundaries; later buff changes cannot alter that Advance, and other restrictions remain. Da Boss grants the literal1CP separately from Core CP, without imposing the inherited extra-CP flag as an unsupplied ceiling.

**Source/authorization:** cached Orks Army Rules from2026-10-12; Stompa Effigy/Zodgrod Super Runts for passive semantics; user-supplied Warlord definition2026-10-13 retained in the appendix reference. No actual current unit factory/grant is inferred from legacy names. Only54 standard cards remain planned; Forge World/Legends stay excluded. Current roster adapters must supply their explicit keywords/rules/required/prohibited Warlord data; old uncertified rosters bypass the unavailable current Warlord choice.

Final RLC/core0.4.17, four workers, debug unoptimized: **648 supported assertions /650 CTest entries,650/650 pass in315.50s** (`task17f-tests`, `task17f-ctest-final.log`). All **29 focused cases** pass unoptimized Address/Undefined/LeakSanitizer with leak detection (`task17f-sanitized/driver-final`, `task17f-sanitized-final.log`). Initial failures were an obsolete schema26 test expectation and a wrong transfer-fixture destination; corrected final assertions pass. No custom init/drop was introduced. The source/status prerequisite plus11 assertions is independently type checked before the gameplay integration.

Matching native/header/C++ Godot artifacts (`task17f-godot`) pass actual Warlord methods/unit-model buttons, offboard click suppression, mandatory Da Boss CP and War Cry labels/status (`task17f-godot-check-final.log`). Prior modifier and physical-weapon/source controls pass (`task17f-godot-modifiers.log`, `task17f-godot-sources.log`). The new harness releases its RLCLib Object, retaining leak rejection. Full rendered journeys remain17.Q. Rules.gd/TraceManager.gd and whole-quad coordinate domains are preserved.

Schemas **state/observation27, action17, next-state28**.20-step Gym passes **22,746 candidates /26,128,335 finite observations**, no tensor warnings (`task17f-gym.log`):+66 candidates (~0.29%) and+95,367 observations (~0.37%) versus17.C4b. Matching ML policies/bindings are required; the known wrapper retrieval bottleneck remains17.Q.

Final optimized sanitized fuzzer (`task17f-fuzzer`) passes both preserved lifetime inputs, zero input and the preceding878-action game; that replay takes **70.571s** (`task17f-replay.log`). Fresh short seeds complete **43 runs in64s**, coverage13,935/features22,861, no sanitizer failures or crash artifacts (`task17f-mutation.log`, `task17f-corpus`, `task17f-artifacts`). Legacy games do not carry the new metadata; focused native/Godot fixtures establish its semantics, while completed-game/fuzzer checks establish integration. Fixed replay and mutation are distinct checks.

Fresh schema27 seed40000 completes **878 actions**, terminal owner **-4**, with payload round trips and owner checks (`task17f-gameplay.log`, `task17f-replays`). Its input bytes equal the preceding input already replayed against the final sanitized engine, giving matching complete-game coverage. This is legacy-roster integration, not current Orks semantic certification.

**17.F is complete as shared engine integration. Next:17.G**, actual Orks Leader/Support mechanics and resumed task6. Actual54 current profiles/loadouts/source adapters and reactive riled abilities remain17.H–P; the effect/instance/key envelopes need review against those playable armies. All identified issues must be fixed by their owning batches, including17.Q wrapper retrieval and remaining rendered journeys. Hull/oval geometry and user visibility limits remain explicit.


## Batch17.G completion

- [x] Resume core task6 with explicit roles, one Leader/one Support slots, exact prebattle source-first reserve permissions and atomic capacity/ownership rejection (p66/19.01).
- [x] Preserve all model/component identities, wargear/use history and combined starting strength after bodyguard destruction; use two visible bounded component records (pp66–67/86–88;19.01.01).
- [x] Use highest bodyguard T while any physical bodyguard remains, then highest remaining Leader/Support T; retain model-local keywords with unit union (pp66–67/05.02.01).
- [x] Distinguish typed unit abilities from bearer-only data; resolve absorbed component sources and started-leading permission after bodyguard death (p67/19.04.01).
- [x] Retain conferred rules through that attacker's full sequence without making destroyed recipients alive; release only the matching attacker before delayed callbacks/removal. Count live strength for half-strength (pp67/86–87).
- [x] Emit whole-unit destruction only for the final combined member; merge model/unit events under supplied controller ordering. Preserve unit-death provenance when a bearer was archived earlier; revival provenance restores the source interval (pp66–67/88).
- [x] Implement all included10 Leader/seven Support lists,41 permission edges; no excluded/unknown attachment grants. Painboss's own Mounted/Mobile/Infantry/+4M changes remain bearer-only and use shared arithmetic.
- [x] Provide production reserve-pair labels, suppress battlefield clicks and update matching schema/binding expectations. Rules.gd/TraceManager.gd, generated lifecycle and small quads remain unchanged.

Sources: core pp66–67/86–88, appendix19.01.01/19.04.01/05.02.01 and each card's retrieved Leader/Support list, inventory2026-10-12. [The attachment report](doc/attachments.md) distinguishes generic mechanics/metadata from actual current profiles and revival/setup. Other faction permissions remain unsupplied.

Final compiler/core0.4.17, four workers, debug unoptimized: **682 assertions /684 CTest entries;684/684 pass in400.04s** (`task17g-tests`, `task17g-ctest-final.log`). The34 new `test_attachment17g_*` cases all pass Address/Undefined/LeakSanitizer with leak detection (`task17g-sanitized/driver-final`, `task17g-sanitized-final.log`). Independent runtime/source-inventory comparison checks all67 catalog identities, all17 included role/lists and41 edges, plus13 excluded cards (`tools/check_orks_attachment_permissions.py`, `task17g-permission-check-final.log`). No custom init/drop or compiler workaround was introduced.

Matching native/header/C++ artifacts (`task17g-godot`) pass real attachment methods/role slots, source-first pair payloads, production labels and offboard click suppression (`task17g-godot-attachments-final.log`), and prior Warlord/army and weapon/source controls (`task17g-godot-army-final.log`, `task17g-godot-sources-final.log`). An exploratory broad harness timed out at45s; the documented large journey requires up to1200s and remains17.Q. Its obsolete implicit-attachment fixture was replaced with explicit source metadata. The focused prefix of that harness passes explicit prebattle metadata, the pending source-first attachment pair and root Game save restoration (`task17g-godot-attachment-save-final.log`); no complete broad/rendered journey is claimed.

Schemas **state/observation28, action18, next-state29**.20-step Gym passes **22,746 candidates /26,183,041 finite observations**, no tensor warnings (`task17g-gym-final.log`). Candidates are unchanged; observations increase54,706 (~0.21%) from17.F. Matching policies/bindings remain required. Wrapper retrieval/performance remains17.Q.

Final optimized sanitized fuzzer (`task17g-fuzzer-final`) passes both preserved lifetime regressions, zero input and the new completed game (`task17g-replay-final.log`). The preceding game also passed the initial attachment build (`task17g-replay.log`). Fresh short-seed mutation finishes **45 runs in61s**, coverage13,943/features25,381, with no sanitizer failures or crash artifacts (`task17g-mutation-final.log`, `task17g-corpus-final`, `task17g-artifacts-final`). Fresh schema28 seed40000 completes **1,000 legal actions**, terminal owner **-4**, with payload round trips/owner checks (`task17g-gameplay.log`, `task17g-replays`). Its changed input separately passes the final sanitized engine in49.260s (`task17g-replay-final.log`); this is not a controlled timing comparison. Legacy-roster integration does not exercise current attachment metadata; focused semantic/permission/Godot fixtures supply that evidence.

**Confirmed mistakes fixed:** unsupported range/misspelled helper in new fixtures; an archived-bearer unit-death lookup gap; obsolete implicit permissions in the broad Godot fixture; conditional source registration incorrectly requiring an already attached Leader. Registration now verifies physical liveness while activation preserves its while-leading gate, including explicit own-destruction events. The first two failed type checks were corrected before native validation. No passing assertion was disabled. All remaining identified issues retain fixing owners, including17.Q's measured wrapper retrieval bottleneck.

**17.G is complete as engine/permission metadata integration. Next:17.H**, replace the three legacy Orks unit families with current profiles, equipment and source-specific abilities; review included loadout capacities/oval geometry. Actual54 current datasheets, actual healing/revival/setup17.J and specialized reactions remain their owners. Exclude all Forge World/Legends, ignore points/detachment prices, track CP and preserve bounded storage/quads/user visibility approximation.


## Batch17.H1 completion — current profiles and checked loadouts

[The data report](doc/orks-current-unit-data.md) documents current Beastboss, Beast Snagga Boyz and Squighog Boyz constructors, five model profiles and12 unique weapon profiles. The source is the retrieved2026-10-12 version1.2 HTML cards, including separate InSv boxes and Hunter keyword headers omitted by the text extracts. The independent `tools/check_orks_unit_tables.py` compares compiled numerical statistics with those HTML tables: **3 cards,5 profiles,13 printed weapon rows PASS** (`task17h1-source-tables-final.log`). FNP, bases, keywords, composition and conditional rules receive separate source/semantic coverage; the table check does not certify the whole card.

The25 new `test_orks17h1_*` assertions cover all current profiles/equipment, literal composition ranges, illegal quotas, additional Thump Guns, physical profile selection/Hunter restrictions, conditional Lethal/Sustained Hits, the actual Anti4+ consumer, fixed Thump A, shared Stikka identity, copy independence, current attachment Toughness, saved data and unsupported oval rejection. Final **707 assertions /709 CTests all pass** (`task17h1-tests`, `task17h1-ctest-fixed.log`,324.85s). The unoptimized native ASAN/UBSAN/leak driver **task17h1-sanitized/driver-final** passes all25 with leak detection enabled (`task17h1-sanitized-final.log`). Intermediate table-only commit sources/tests separately typecheck (`task17h1-tables-stage/type.log`).

Matching unoptimized native/header/C++ artifacts are **task17h1-godot**. New `tests/godot_orks_unit_data.gd` passes generated constructors/stat fields, named labels/loadouts, actual attachments, unsupported oval guards and root Game saves (`task17h1-godot-data.log`). Prior attachment and weapon/source controls also pass (`task17h1-godot-attachments.log`, `task17h1-godot-sources.log`). Full broad/rendered journeys remain17.Q; Rules.gd/TraceManager.gd stay unchanged.

Schemas are **state/observation29, action18, next-state30**. New enums/keywords change observation interpretation even though tensor dimensions stay unchanged.20-step Gym passes with **22,746 candidates /26,183,041 finite observations**, no tensor warnings (`task17h1-gym.log`); matching bindings/policies remain required. Fresh seed40000 completes **1,000 legal actions**, terminal owner-4, with payload round trips/ownership checks (`task17h1-gameplay.log`, `task17h1-replays`). Its binary input equals the prior17.G game input and passes the final sanitized engine. This remains legacy-roster completion evidence; focused native/Godot fixtures validate the current data APIs.

The final optimized sanitized **task17h1-fuzzer** passes both preserved lifetime regressions, zero input and the completed game (`task17h1-replay.log`). Fresh mutation finishes **31 runs in66s**, coverage13,939/features22,711, without sanitizer failures or crash artifacts (`task17h1-mutation.log`, `task17h1-corpus`, `task17h1-artifacts`). Replay timings are not a controlled performance comparison; the measured wrapper retrieval bottleneck remains a mandatory17.Q fix.

**Mistakes corrected:** helper/constant spelling, duplicate local names, parameters shadowing getter functions, enum comparisons lacking equal, an incorrect Godot label and a Thump fixture querying an ordinary threshold after changing its target to MONSTER. The fixture now captures its pre-change threshold and retains the actual critical-wound consumer assertion. The earlier typecheck/708-of709 logs are superseded by the final passing log; no failing assertion was disabled. Generated lifecycle remains in use; no compiler workaround or custom init/drop was added.

**17.H1 is complete; next17.H2** implements Dodge Dis!, Keep Huntin', Mobbed, Bomb Squig and Brutal Impact with real source/timing/target/damage/shock integration.17.H3 must implement75x42/90x52 oval geometry on existing quad anchors; current models deliberately reject unsupported placement.17.H4 must promote complete adapters into the production roster and validate actual current gameplay. Parent17.H and all three full cards remain incomplete. All54 standard units remain planned; Forge World/Legends and points/detachment prices remain excluded, CP retained. Every identified remaining issue must be fixed by its named owner.


## Current user direction — combined17.H2/H3

Use circles temporarily for oval models, retaining source axes and explicit oval metadata. The long axis is the proxy diameter (Squighog75mm, Nob90mm). This supersedes prior oval-placement rejection and exact-oval prerequisites; exact oval geometry is deferred, with circle distance/collision/setup/path/rendering semantics documented. Unknown hull/multipart models remain unsupported. Implement17.H2 special abilities and17.H3 proxies together, then run the expensive combined validation after edits are complete.17.H4 production roster promotion follows this pair. Historical completion records above describe their original scope.


## Combined17.H2/H3 completion — unit abilities and temporary oval proxies

[The ability/geometry report](doc/orks-current-unit-rules.md) implements Beastboss Dodge Dis!/Keep Huntin', Snagga Mobbed and Squighog Bomb Squig/Brutal Impact from the three retrieved11th-edition version1.2 source cards. Dodge Dis! has a separate pre-cap hit contribution/ignoring origin; Brutal Impact enters outgoing damage addition for every ranged/melee/Jaws attack after a completed charge. Keep Huntin' offers actual start/end movement targets with a shared army-round key and next-own-turn riled lifetime/shock removal. Bomb Squig spends the original unit's battle token at acceptance, then uses explicit D6/D3 and ordinary opponent-owned mortal/FNP/spill/destruction handling. Mobbed resolves every engaged enemy Monster/Vehicle shock roll after completed charge movement, with-1/-2 at13 live combined models and actual controller restoration. Source handles follow attachment/bank/save provenance. No custom init/drop or unbounded numeric state is added.

**User geometry override applied:** original75x42/90x52 oval axes and `profile_has_oval_base` remain metadata;75/90mm long-axis circles now drive existing distance, overlap, full-base setup, paths, rotation and Godot rendering. This is an explicit approximation, not exact oval certification. Exact ovals are deferred; unknown hull/multipart dimensions remain unsupported. Whole-quad positions/action domains and Rules.gd/TraceManager.gd remain unchanged.

There are **738 supported assertions /740 registered CTest entries**. The first complete run passes **739/740 in333.79s** (`task17h23-tests`, `task17h23-ctest.log`); one updated placement fixture wrongly requested ordinary deployment outside its owner's home zone. The fixture now uses a legal home-zone anchor. The corrected affected run passes **58/58**:57 assertions (all31 new17.H2/H3 cases,25 current-data cases and the existing generic actual-move source hook) plus the compilation fixture, in274.61s (`task17h23-ctest-corrected.log`). Every registered assertion therefore has a passing executed result across these runs; no full740/740 rerun is claimed and no assertion was disabled. Intermediate circle-only commit sources/tests separately typecheck (`task17h23-circle-stage/type.log`).

Final unoptimized native **ASAN/UBSAN/leak checks pass all56 focused cases**, exit0 (`task17h23-sanitized/driver-final`, `libtests-final.so`, `task17h23-sanitized-final.log`). The sandbox initially blocked LeakSanitizer process inspection after the semantic passes; the same binary succeeds outside that sandbox with leak detection still enabled. No compiler bug/workaround is inferred. The source HTML check remains **3 cards /5 profiles /13 printed weapon rows PASS** (`task17h23-source-tables.log`).

Matching pure Rulebook native/header/C++ artifacts are **task17h23-godot**, unoptimized. New targeted source choices, labels, one-UnitID click discovery, token use and saves pass (`task17h23-godot-rules.log`). Current data/circle metadata, existing attachment, modifier ignoring and weapon/source controls also pass (`task17h23-godot-data.log`, `task17h23-godot-attachments.log`, `task17h23-godot-modifiers.log`, `task17h23-godot-sources.log`). A label fixture was corrected to use the production lowercase formatting. An attempted reuse of CTest's Python-linked native library was rejected by Godot's loader; final Godot validation uses a fresh pure native build, with no added Python dependency. Full broad/rendered journeys remain17.Q.

Schemas **state/observation30, action19, next-state31** require matching bindings/policies.20-step Gym passes **22,907 candidates /28,980,462 finite observations** (`task17h23-gym.log`), using the compatible compiled Python suite without another JIT build. This adds161 candidates (~0.71%) and2,797,421 observation values (~10.68%) versus17.H1; coordinates stay unchanged. The new choices and bounded frames increase layout size; no speedup is claimed and the measured wrapper retrieval bottleneck remains a mandatory17.Q fix.

Fresh seed40000 completes **1,000 legal actions**, terminal owner-4, with payload round trips/ownership checks (`task17h23-gameplay.log`, `task17h23-replays`). Its binary input matches17.H1's game input. Final optimized sanitized **task17h23-fuzzer** passes both preserved lifetime inputs, zero input and the fresh complete game (`task17h23-replay.log`); that game replays in45.897s, not a controlled timing comparison. Fresh mutation completes **20 runs in66s**, coverage15,972/features22,719, no sanitizer failures or crash artifacts (`task17h23-mutation.log`, `task17h23-corpus`, `task17h23-artifacts`). The public root still uses the legacy roster: these games/fuzzer runs certify integration/lifetimes, while focused native/Godot fixtures establish current ability semantics.

**Mistakes fixed:** new movement-source action names initially collided with nested destruction actions' frame/value argument forms; `choose_movement_source` now has its own source-ID payload and ordinary `roll` retains chance classification. A two-argument range call, deployment-zone fixture and Godot case-format expectation were corrected. Expensive tests were delayed until the combined edits were complete; only affected semantic cases were rerun after the fixture correction. All remaining identified defects retain mandatory owners.

**17.H2 and17.H3 are complete within the user's temporary circle policy. Next:17.H4**, promote the three current adapters into the actual Orks roster and validate current Warlord, attachments, equipment, movement/combat, saves and complete games. Parent17.H/full production cards remain incomplete until that switch. All54 standard cards remain planned; Forge World/Legends and points/detachment prices remain excluded, CP retained. Exact ovals are deferred, while remaining datasheet abilities, missing hull geometry, full rendered journeys and wrapper performance retain their named owners.


###17.H4/17.I1 combined implementation and validation —2026-10-14

The public Orks starter now fields the completed current Beastboss, four-model
Squighog unit and two ten-model Snagga mobs with one additional Thump Gun each.
The stable Morgrim action/enum remains compatible; the editor labels it current
Orks. Actual mandatory Warlord selection precedes opponent handoff, and formation
attachments preserve Warlord/component identities after reserve-slot compaction.
Historical Orks factories remain explicit core-test scaffolds, outside this
public choice. Read `doc/orks-roster-war-horde.md`.

War Horde Get Stuck In uses the cached faction definition: friendly ORKS units'
melee attacks have Sustained Hits1. Source owner configuration, selected package,
army faction, unit keyword union and melee profile gate the grant. Extra Attacks
receive it; ranged attacks do not. Existing p78 duplicate selection chooses
unconditional1 versus Beastboss's conditional2 before targets; no summation or
automatic maximum is introduced. Ordinary declarations, critical-hit/wound
consumers and saves carry the selected instance. No new action signature, stored
float, custom init/drop, point/DP cost or terrain/visibility geometry is added.
Rules.gd and TraceManager.gd are unchanged. State/observation31, action19, next32.

Executed evidence (external outputs in `/workspace/4hammer-validation`):

- Discovery: **757 CTest entries**,755 supported assertions plus two compilation
  fixtures. Initial full run: **756/757**,411.18s, with only the new two-player
  attachment fixture aborting; `task17h4i1-ctest.log`. Corrected affected rerun:
  **19/19**,305.28s (18 assertions plus compilation),
  `task17h4i1-ctest-corrected.log`. All755 assertions have passing executed results
  across those runs; this is not a second full757-entry run.
- Added17 focused regressions, all passing with unoptimized native Address,
  UndefinedBehavior and LeakSanitizers: `task17h4i1-sanitized-final.log`, matching
  `task17h4i1-sanitized/{libtests-final.so,driver-final}`. Earlier fixture failure
  was corrected and all17 rerun; leak detection remains enabled outside the
  sandbox because process inspection is required.
- The roster-only prerequisite commit is independently type-checked in
  `task17h4i1-roster-stage/type.{rl,log}`. Final code is freshly compiled by CTest,
  native sanitizers, pure Godot and the optimized sanitized fuzzer withRLC0.4.17
  and `-j 4`; debug builds remain unoptimized.
- Fresh matching pure Godot header/native/C++ libraries in`task17h4i1-godot`;
  three controls PASS: current production roster/Warlord/attachment/pending-save
  and duplicate-choice journey (`task17h4i1-godot-roster-corrected.log`), current
  data/proxies (`...-godot-data.log`) and unit-rule controls (`...-godot-rules.log`).
  The initial60-second production journey timed out; the corrected180-second
  budget passes. Full rendered/mouse journeys remain17.Q.
- Independent cached HTML comparison PASS: three cards, five profiles,13 weapon
  rows (`task17h4i1-source-tables.log`).20-step ML PASS: unchanged22,907 candidates
  and28,980,462 finite observation values (`task17h4i1-gym.log`).
- Actual current-root mixed matchup, seed40000: **1,158 legal actions**, completed
  with terminal owner-4 (`task17h4i1-gameplay.log`). Two actual Orks starters, War
  Horde selected for both owners, seed40001: **1,346 legal actions**, completed
  with terminal owner-4 (`task17h4i1-orks-game.log`). The latter includes reserve
  arrivals, real shooting/melee and Keep Huntin'/Bomb Squig/Mobbed. Both check
  decision ownership and payload text round trips; traces/inputs are in
  `task17h4i1-replays`. Python elapsed589.881s for the latter overlaps other
  compilation/testing and is not a controlled performance comparison.
- Fresh optimized sanitized fuzzer `task17h4i1-fuzzer` passes both preserved
  deployment/geometry inputs (1.900s/6.975s), zero input (4.025s) and fresh mixed
  completed game (66.051s); see `task17h4i1-preserved-{0,1}.log` and
  `task17h4i1-replay-mixed.log`. Fresh two-Orks completed-game replay also PASS (54.076s), recorded separately
  in`task17h4i1-replay-orks.log`. Short mutation campaign: **15 runs in69s**,
  coverage14,452/features19,737, no failure artifacts; `task17h4i1-mutation.log`.
  Fuzzing is crash/memory evidence, not semantic proof of the entire faction.

Corrected mistakes: the new fixture incorrectly assumed attachment ownership
changed only after `done_attaching`; actual formation choices alternate after
each action, including attachment. Correct both fixture and Godot journey;
production formation behavior is unchanged. Type-check corrections used the
actual unit-level ability collection, explicit Weapon enum values and both
shared contexts for the nested Select Weapons action. No failing check is
disabled and no compiler-bug/minimal-file workflow is revived.

**17.H (three current starter families) and17.I1 (passive only) are complete.**
17.I2 still owns War Horde enhancements/upgrades and all six CP cards.17.J–P own
remaining mechanics and the other51 included standard cards. All54 remain the
plan; Forge World/Legends are excluded, CP retained, exact ovals deferred in
favor of the user-approved circles. Unknown hull/multipart dimensions, full
rendered journeys, mission/faction completion and wrapper-performance issues
remain explicit dependencies with named owners. Every remaining identified
issue must be fixed before its owning task is marked complete.

### User-directed combined remaining-detachment batch —2026-10-14 (in progress)

The user requests all remaining ordinary detachments in one implementation batch,
including the rest of War Horde. Combine17.I2/17.O with necessary shared parts of
17.J/L/M/N: all15 passives,38 enhancements/upgrades and40 stratagem effects, source
and combination regressions, Godot controls and final grouped tests/fuzzing.
Retain separate focused commits. This does not authorize invented datasheet
profiles, points/DP costs or Boarding Actions/Forge World/Legends content.

Supplied policy: at most4 counted enhancements; ordinary options unique; up to3
copies per Upgrade with only its first instance counting. Epic Heroes and units
containing attached Epic Heroes cannot take options. The accessible core page
also requires a different unit per option. Roster copies are at most3, or6 for
Battleline. All noncircular geometry uses an intentional circle approximation,
annotated in code; Smoky Gubbinz uses circular-base sight crossings. Missing
actual hull dimensions still belong to the datasheet adapters.

Implementation/validation is in progress; do not mark15 detachments complete
from configuration, partial helpers or CP tables. Every effect must reach its
actual source window, preserve ownership/durations/provenance and pass its
meaningful regressions. Group expensive checks after edits; type checking during
implementation may diagnose source/signature issues without rerunning suites.

The user additionally requests a complete action-frame lifetime audit. Move
duplicated frames that cannot be active simultaneously into single Board context
slots, preserving only necessary completed results in caller snapshots. Audit
all action declarations and ordinary frame constructors, reject recursive
re-entry, and check generated frame multiplicity with
`tools/check_action_frame_storage.py`. Type checking has passed; final native,
save/replay, Godot and sanitizer validation of the shared layout remains pending.
Record measured layout sizes and executed results before marking this complete.

### Action-frame storage prerequisite —2026-10-14

The user requests auditing every action and sharing types that cannot have two
active copies. The core prerequisite audits76 declarations, moves39 duplicated
frame types into `Board.shared_actions`, and retains the three existing direct
Board slots. Fully delegated siblings execute sequentially; ordinary helpers
and constructor descendants are checked for recursive re-entry. Callers copy
only required completed results before slot reuse. The generated layout has
one stored copy of each shared type and no duplicate frame type in Game.

The isolated prerequisite's baseline typechecks and its fresh Python metadata
audit passes: Game19,712 bytes, Board18,496 bytes. Artifacts are in
`/workspace/4hammer-validation/shared-core-frame-stage`. This is prerequisite
build/layout evidence; final combined semantic, save/replay, Godot and sanitizer
evidence belongs to the following detachment batch. State/observation32,
next33; action19 is unchanged by this storage refactor. Regenerate matching
bindings. Generated lifecycle, bounded storage, quads and editor argument shapes
are preserved. Wrapper retrieval performance remains17.Q.

### Combined batch validation progress —2026-10-14

The final shared layout's unoptimized native suite passes **872/872 assertions**
in150.79s on the normal8MiB host stack (`shared-frames-ctest.log`). Bindings and
native code were regenerated together; no assertion is skipped or disabled.
The complete frame audit passes **111 declarations /66 single context slots**,
no duplicate frame type in Game and no constructor re-entry, including ordinary
helper paths. Native inline sizes are **Game34,544 bytes /Board28,752 bytes**
(`shared-frames-layout.log`, `doc/action-frame-lifetimes.json`). The preceding
partially reused-window layout measured Game771,696/Board81,448 bytes; this is
a storage comparison, not a runtime speed benchmark.

Independent source checks pass15 ordinary packages,38 enhancement identities
(including13 Upgrades),40 stratagem identities/printed CP; three current-card
tables/five profiles/13 weapon rows; and67 catalog identities/41 permitted
attachment edges (`shared-frames-{orks,unit,attachment}-source.log`). The source
check strips the separately checked UPGRADE heading badge from card names.
Twenty-step Gym passes **29,381 candidates /15,095,745 finite observation values**
(`shared-frames-gym.log`), schemas32/20/32, next33. This reduces the observation
layout despite the added package decisions; matching policies/bindings remain
required. The wrapper retrieval bottleneck remains17.Q.

Final Godot,131 native sanitizer cases (117 new plus14 existing core
frame/save/lifetime cases), complete games and optimized sanitized fuzzer checks
are still running or pending. This progress record does not mark the detachment
batch or final frame validation complete.

Final-field-name native ASAN/UBSAN/leak validation passes **131/131**, including
all117 new package assertions and14 existing core frame/save/lifetime cases
(`shared-frames-sanitized-run.log`, `orks-detachments-sanitized/driver-final`).
Leak detection remains enabled; execution used the permitted external process
inspection environment. Both earlier shared-layout current-root games complete:
mixed seed40000 in697 actions and two Orks/three-package/actual-enhancement
seed40001 in836 actions (`shared-frames-gameplay.log`,
`shared-frames-orks-game.log`, `orks-detachments-replays`). These recorded Python
games precede the internal `member`→`member_index` binding rename; action ranks
and argument shapes are unchanged, and their inputs still require final fuzzer
replay. No controlled runtime speedup is claimed.

Godot's C++ getter collision is fixed by renaming three persistent `member`
fields; the corrected C++ build passes (`shared-frames-godot-cpp-fixed.log`).
The preliminary option script incorrectly requested a getter for the raw army
array, so it now calls the existing `army_for_player` helper. Final matching
native Godot execution and sanitized fuzzer evidence remain pending.

Focused source commits preserve prerequisite order: core serial frame storage
(`0516a58`); ordinary package definitions/passive/source consumers with29 new
regressions (`998479a`); actual core combat/movement/timing wiring with the
remaining88 new regressions. The package prerequisite independently passes full
Python code generation and the layout audit (`orks-package-foundation-stage`):
111 declarations/66 single slots, Game29,448/Board28,088 bytes. Its first wrapper
check revealed a narrow Mobbed penalty parameter against the widened shock
signature; the prerequisite now uses the same bounded0–7 domain as the final
source and passes code generation. No source-level compiler workaround is used.

Final matching Godot native/header/C++ artifacts in `orks-detachments-godot`
pass six controls: new detachment/options/pending save; current roster/both
Warlords/attachments; current data/proxies; targeted unit rules; physical
weapons/compound/source choices; and selective modifier ignoring. Logs are
`shared-frames-godot-{options,roster,data,sources}-final.log`,
`shared-frames-godot-{unit-rules,modifiers}-corrected.log`. The source/option
production controls pass without Godot errors or leaked-instance reports.
The initial unit-rule check retained obsolete31/19 schema assertions; every
existing Godot fixture is now aligned to32/20. The modifier fixture also
retained the obsolete18-choice generated class name; it now borrows the
actual choice alias from a retained frame instead of naming its capacity.
These are corrected test/binding mistakes; no assertion was disabled.
Full rendered/mouse journeys remain17.Q.

The final optimized sanitized fuzzer builds with compiler/core0.4.17, four
workers and-O2 (`shared-frames-fuzzer-build.log`). All five fixed replays pass
with leak detection: preserved deployment0.826s, geometry6.749s, zero6.715s;
current mixed697-action input110.703s and two-Orks836-action input92.768s
(`shared-frames-replay-{deployment,geometry,zero,mixed,orks}.log`). These timings
overlap other validation and are not controlled speed comparisons. The first
mutation corpus included the complete games, whose initialization exceeded the
60-second budget. That preliminary campaign finished after seed initialization without mutations; final mutation
uses two513-byte short seeds in `shared-frames-short-corpus`, with full games
retained separately as completed fixed-input replay evidence.

Four additional focused Godot controls also pass with the same final libraries:
attachments, Orks army/Warlord rules, incoming modifiers and model
characteristics (`shared-frames-godot_{attachments,orks_army,incoming_modifiers,
model_characteristics}-final.log`). Other schema assertions were updated
mechanically; unexecuted broad/rendered journeys remain17.Q.

### Combined ordinary-detachment and action-frame completion —2026-10-14

**17.I2 and17.O are complete within the supplied scope.** All15 ordinary
passives,38 enhancements/upgrades and40 CP cards reach their real declaration,
phase, movement, attack, destruction, transport/offboard and psychic windows.
Shared healing/return, reaction movement/shooting, hit/wound provenance,
replacement and psychic-budget mechanics support the packages. Actual units
that exercise these outside the three current starter families remain17.P;
their missing profiles, hull sizes, seating/permissions and unit rules are not
invented or certified.17.I–N therefore retains its datasheet work. Exclude
Boarding Actions, Forge World/Legends, points and detachment prices; track CP,
max3 detachments and the supplied enhancement/copy limits.

The requested complete frame audit is also complete:111 declarations,66 single
context slots, no duplicate Game frame types and no constructor re-entry.
Required completed results are retained in small caller snapshots. Native
inline Game/Board storage is34,544/28,752 bytes; no runtime speedup is claimed.
State/observation32, action20, next33 require matching regenerated bindings.
Generated lifecycle, bounded persisted numbers, whole quads, circle proxies and
Rules.gd/TraceManager.gd are preserved.

Executed final-batch evidence:872/872 unoptimized CTest assertions;131/131
final-field-name native ASAN/UBSAN/leak cases; source checks for78 cards/15
packages and the existing unit/attachment tables;20-step finite Gym; two
completed current-root games; all five final sanitized fixed replays; and
**16 mutation runs in81s**, coverage20,048/features29,611, with no sanitizer
failure or crash artifacts (`shared-frames-mutation-short.log`,
`shared-frames-short-{corpus,artifacts}`). The preceding complete-game corpus
consumed its budget during initialization (**3 runs/119s**, no mutations); it
is not substituted for the final campaign. Its112-second slow-unit artifact
remains in`shared-frames-artifacts` for the mandatory17.Q performance fix.
The campaign warns that an external symbolizer is unavailable; instrumentation
and leak detection remain enabled, with addresses retained in the log. Tooling
for symbolic diagnostics also remains17.Q.

All14 focused Godot controls pass with the final native/header/C++ build. The
four last controls cover keyword predicates, named physical identities, Damaged
and weapon characteristics (`shared-frames-godot_{keyword_predicates,
named_identities,damaged,weapon_characteristics}-final.log`). The broader
`godot_state.gd` and rendered/mouse journeys remain17.Q; their schema assertions
are aligned but this batch does not claim they ran.

The872-assertion full run and Python complete games precede only the three
internal member→member_index binding renames. All117 new cases plus14 existing
frame/save/lifetime cases pass final-source sanitizers, all selected Godot
controls use regenerated final-source libraries, and both completed inputs pass
the final optimized sanitized engine. No second full872-case run is claimed.
No failing test was disabled. Corrected errors include source helper signatures,
fixture weapon assumptions/formation handoff, package-window duplication,
Godot reserved getters, outdated fixture schema/capacity names and oversized
mutation initialization. Remaining issues retain their named fixing owners.

Next17.P: implement the remaining standard unit families in dependency batches,
using the completed package/shared mechanics and the source matrix.17.Q must
still fix measured wrapper retrieval/native slow inputs and complete the full
rendered journeys; task17 and the whole edition migration remain incomplete.

###17.P1 complete — twelve standard unit adapters

Implement Boyz, Nobz, Warboss, Bigboss, Bannernob, Stormboyz, Warbikers,
Deff Dread, Killa Kans, Big Mek Dakkarig, Beastboss on Squigosaur and Mozrog
Skragbad together from the retrieved2026-10-12 version1.2 cards. Add15 exact
profiles, complete per-model loadouts and their source-owned abilities using
existing attack, movement, aura, damage and delayed-fight kernels. Reuse110/112
shared Keep Huntin’/Intimidating Motivation limits. Batch source edits and
regressions before expensive native validation, as requested by the user.

The public starter remains three families; arbitrary roster selection remains
17.Q integration. This batch brings implemented adapter coverage to15/54, leaving39.
Constructors alone do not certify mechanics. Preserve bounded state,
generated lifecycle, quads, intentional source-sized circles, no prices and CP
tracking. Schema33/21/33 (next34) requires matching rebuilt bindings. Any issues
found must be fixed with regression coverage before completion.


17.P1 executed evidence —2026-10-14 (`/workspace/4hammer-validation/orks-p1`):

-59 new regressions cover15 profiles, literal composition/loadout boundaries,
 all20 legal Dread arm combinations, physical alternatives/Extra Klaws, source
 tokens/duration/ownership/saves, live target conditions, modifiers, charge
 traversal, auras, actual gathering, attack/fight delegation and Mozrog death.
 The full unoptimized CTest run executes931 assertions:930 pass; one test
 incorrectly assumed Shootas lacked their printed conditional Lethal Hits.
 Correct the test to query the selected Monster target. The compiled game
 passes the corrected assertions directly (`tide-corrected.log`), and all59
 corrected-source native ASAN/UBSAN/leak cases pass, both together and as59
 individual CTests (`sanitized/run.log`, `sanitized/ctest.log`). These runs
 cover all931 assertions; no second full932-entry CTest run is claimed.
-Independent original-HTML comparison passes15 cards/20 model profiles/79
 printed weapon rows, including InSv, fixed/random expressions and weapon
 rules. Attachment inventory remains67 identities/41 permission edges.
-Frame audit passes113 actions/66 shared slots/no duplicated frames. Game/Board
 inline sizes34,744/28,944 bytes. Each new selection frame has one owner.
-20-step Gym passes29,387 action candidates and15,265,917 finite observations.
 Only six Bool candidates were added; whole-quad coordinate bounds are unchanged.
 Fresh seed40000 current-root gameplay completes697 legal actions, terminal-4.
 The optimized sanitized engine replays its exact input in96.439s and both
 preserved deployment/geometry lifetime inputs without sanitizer failures.
-Eight matching Godot controls pass: new twelve-unit constructors/decisions,
 existing data, unit rules, modifier ignoring, detachments, attachments, weapons/
 sources and current roster/Warlord/save journey. Artifacts reuse the current
 unoptimized Python-linked native engine with an explicit dependency on the
 installed matching libpython3.12; generated header and C++ extension are fresh.
 This is validation artifact reuse, not a production CMake dependency change.
 Direct sanitizer-library loading was rejected by Godot's RTLD_DEEPBIND mode;
 native sanitizer checks remain separate and enabled. Fixed-array getter and
 normalized-label fixture mistakes were corrected. Broad/rendered checks17.Q
 remain pending; no pure-native Godot rebuild or rendered journey is claimed.
-Fixture-assisted fuzzer uses a copy of the current full-game root/catalog and
 original action-fuzz loop, plus one selected semantic assertion per input.
 All59 one-byte seeds initialize successfully;265 runs/61s validate semantic
 fixtures (this corpus stays below the action-input length). A separate73-byte
 seed campaign exercises actual actions:78 runs/62s,28 new units added,
 coverage13,174/features17,057. Both campaigns and fixed replays keep ASAN,
 UBSAN, bounds/preconditions and leaks enabled; no crash artifacts. Missing
 external symbolizer warnings retain their17.Q diagnostics owner. This does
 not certify complete games using all12 new units through the public roster.

Fixed issues: source-effect/provenance validators now admit the new enum entries;
 modifier result/index capacity accommodates all34 offered contributions;
 borrowed weapons receive carrier datasheet rules; Nobz traversal preserves FLY;
 Rokkit Charge is selected before Overrun/attacks. Rule functions cite source
 cards or applicable core/appendix wording. Generated lifecycle, bounded state,
 circle proxies, CP tracking and Rules.gd/TraceManager.gd are preserved.

17.P remains open for39 standard cards. Arbitrary public roster selection,
 unsupported hull data, full rendered journeys and measured wrapper/native
 performance fixes retain their existing17.P/17.Q owners. All issues identified
 must be fixed and validated; do not turn documentation/table coverage into
 claims that these remaining mechanics are complete.


###17.P2 complete — fourteen elite, Mek and Gretchin adapters

Flash Gitz, Meganobz, Mek, Big Mek, Big Mek in Mega Armour, Big Mek with Shokk
Attack Gun, Painboy, Painboss, Breaka Boyz, Tankbustas, Warboss in Mega Armour,
Gretchin, Runtherd and Zodgrod Wortsnagga use the same retrieved2026-10-12
version1.2 cards. See [the adapter guide](doc/orks-elites-meks-gretchin.md).
All source/tests were batched before expensive validation.25 data assertions
and38 behavior assertions accompany17 model profiles,53 weapon rows, checked
loadouts, attachment metadata and the complete printed abilities of these cards.
Coverage is29/54 standard adapters, leaving25. Public roster selection remains
17.Q; the existing current starter still contains three families.

Implemented behavior includes all-bank Command healing, optional Orderly,
original-casualty revival/weapon use/death-flag reset, actual Mek model repair
range and next-own-Movement duration, separately ignorable cumulative repairs,
ranged-only Force Field InSv, More Dakka and stronger-S protection, Shokk
Advance/traversal/per-model hazards, hit-ledger Barrage, target-identity Pulsa,
charge bonuses/mortals, objective securing, grouped Gretchin seats, Runtherd
direct destruction and source-bound Super Runts. Shared healing serves the
older detachment wrapper and offboard/embarked capacity checks. Repair source
prototypes are reused across turns, with separate effect keys retained.

The three Python-test migration commits are reverted. Native Rulebook tests
and individual CTests remain; no build cache was introduced. Compiler/core
0.4.18, four workers and parallel native builds are verified. Debug builds are
unoptimized; the sanitized fuzzer uses separate-O2. Clang21 runtime/resource
links are fixed for venv invocations; a compiler exit0 after failed linking was
rejected until a nonempty runnable instrumented executable existed.

Executed evidence —2026-10-14 (`/workspace/4hammer-validation/orks-p2`):

- All994 final-source assertions pass, with no XFAIL/skip/discrepancy cases.
  CTest registers995 entries including one compilation fixture. The fixture
  passed, and the final994 individual cases pass in143.78s (`ctest-final.log`).
  An initial992/994 run caught two fixture errors: imported attachments collided
  with an unrelated enemy's old identities; a hazard test attempted a reroll
  decision with no available reroll. Corrected fixtures re-identify the separate
  enemy, assert valid identities and explicitly fund the declined CP reroll.
  No game check was disabled.63/63 direct native cases also pass after correction.
- All63 new assertions execute successfully in the final ASAN/UBSAN/leak fuzzer
  as63 one-byte semantic seeds plus the empty initialization input:64 runs/26s
  (`fuzzer/semantic-seeds.log`). These inputs exercise semantics, not actions.
- Independent original-HTML comparison passes29 cards/37 model profiles/132
  printed weapon rows (`source-check-final.log`). Attachment inventory remains
  67 identities/41 edges, including all13 excluded cards checked.
- Final frame audit passes120 action routines/68 shared context slots, with
  no duplicated frames or nested re-entry (`frame-audit-final.log` and the
  checked-in lifetime inventory). Game/Board are38,176/32,360 inline bytes.
  The new shared healing and Runtherd frames have one slot each; remaining new
  frames have one owner. No custom init/drop or unbounded stored numbers.
- Matching generated header/C++/native artifacts pass nine Godot controls:
  the new fourteen-card constructors/source/save/Pulsa/eight-selector test,
  previous infantry/walkers, current data, unit rules, modifier ignoring,
  detachments, attachments, weapons/sources and current roster/Warlord/save.
  The new control passes again with the final native engine
  (`godot-elites-final.log`, `godot-results.json`). Schema-aligned remaining
  scripts were not all executed. Rules.gd/TraceManager.gd and production CMake
  dependencies are unchanged. Validation reuses the matching debug test engine
  with explicit installed libpython3.12 linkage/path; native sanitizer checks
  remain separate from Godot's RTLD_DEEPBIND loader.
-20-step Gym passes29,623 action candidates and15,457,965 finite observations
  (`gym.log`), up236 candidates/+192,048 observations versus17.P1. There are
  289 player-facing payload types;120 counts coroutine/frame routines. Whole-
  quad x/y domains remain unchanged. Schemas34/22/34, next35 require matching
  clients/policies.
- Fresh current-root seed40000 completes697 legal actions, terminal owner-4,
  including ownership and textual payload round trips (`gameplay.log`,
  `replays`). Its input equals the prior697-action stream; a direct native
  replay independently reaches the terminal state (`native-replay.log`). The
  Python host journey remains slow and retains17.Q's performance owner.
- Final optimized sanitized engine replays both preserved lifetime inputs and
  the fresh completed697-action input with leaks enabled. The game replay
  takes89.779s (`fuzzer/replays/results.json`). A separate one-byte semantic
  mutation campaign finishes235 runs/61s, coverage16,115/features22,308. A
  separate73-byte-seeded action campaign finishes85 runs/61s, coverage13,288/
  features19,284 (`fuzzer/*-mutations.log`). Both finish without crash artifacts
  or sanitizer failures. The fixture-assisted harness uses the current full
  game/catalog and original action-fuzz loop; one-byte cases cannot execute an
  action. Missing external-symbolizer warnings retain their17.Q diagnostics
  owner, with addresses preserved and instrumentation enabled.
- Final concurrent builds with four workers each take281.773s for the debug
  test library and268.733s for the optimized sanitized fuzzer; measured peak
  RSS is1,746,724/2,166,468KiB (about1.67/2.07GiB). These are successful native
  builds under concurrent validation, not a controlled speedup or16x memory
  comparison (`native-tests-final.json`, `native-fuzzer-corrected.json`).

All newly identified implementation/fixture/binding/linking issues are fixed.
The source matrix marks these14 completed adapters.17.P remains open for25
standard cards. Arbitrary public roster selection, missing hull dimensions,
full rendered journeys and measured wrapper/native performance/symbolizer work
retain17.P/17.Q owners and must still be fixed and validated. This batch does
not certify public full games containing every new card. No prices, Forge World,
Legends, non-quad migration or custom lifecycle hooks were added. The reusable
cloud install/start draft now pins0.4.18 and captures the validated runtime
links; draft saving is separate from publication.


###17.P3 — All25 remaining standard cards (complete,2026-10-15)

The current user request authorizes finishing all remaining included cards in
one implementation/validation batch. Profile/loadout adapters and source
consumers are implemented for Battlewagon, Big'ed Bossbunka, Blitza-bommer, Boss
Snikrot, Burna-bommer, Dakkajet, Deffkilla Wartrike, Deffkoptas, Ghazghkull Thraka,
Gorkanaut, Gunwagon, Hunta Rig, Kill Rig, Kommandos, Mek Gunz, Morkanaut, Nazdreg,
Rukkatrukk Squigbuggies, Stompa, Trukk, Warbuggies, Wartrakks, Wazbom Blastajet,
Wazdakka Gutsmek and Weirdboy. Forge World/Legends remain excluded.

The user now explicitly authorizes large temporary circular bases for the six
Use-model hull families. They are deliberate imprecision, never claimed source
dimensions; immutable source base metadata remains0. Factories also accept
explicit replacement millimetre diameters. Other source ovals continue to use
long-axis circles with their short axes retained. No points/detachment prices,
continuous model positions or custom lifecycle hooks are introduced.

Implementation, native regressions and the combined checks below are complete.
All54 included standard cards now have source adapters. Public arbitrary roster
selection and the previously recorded performance/rendered integration fixes
remain mandatory17.Q work.


**Executed17.P3 validation** (artifacts under
`/workspace/4hammer-validation/orks-p3`, compiler/core0.4.18):

- **1,105/1,105 native assertions pass** as individual CTest cases, including
  **111 new regressions**. The initial compile fixture passed; after the final
  corrections the native library was rebuilt and all cases rerun.1,106
  registered CTest entries include that fixture. Final full case run:181.00s,
  `ctest-final.log`.
  The baseline's994 existing cases also passed the initial combined run.
- All111 new cases pass optimized ASAN/UBSAN/LeakSanitizer in the source-derived
  scenario fuzzer:111 one-byte seeds plus empty initialization,112 runs/37s,
  `semantic-corrected.log`. A separate small-seed, one-byte campaign performs
  **112 runs/61s** (`semantic-mutation-active.log`). The earlier large-corpus
  60s run only initialized its corpus and is NOT counted as mutation evidence.
- Actual game-action mutation performs **42 runs/62s** using the retained
  corpus originating with the73-byte seed, with maximum length8192
  (`action-mutation.log`). Cases with <=8 bytes do not
  advance the original game's action loop; semantic and action campaigns are
  distinct evidence. These bounded campaigns establish no exhaustive coverage.
- Both preserved lifetime/leak regressions and the prior completed-game input
  pass on the fresh sanitized executable with leak detection enabled
  (`replays/sanitized.log`). The697-action replay also completes on the fresh
  debug native engine, terminal owner−4,31,185 candidates
  (`replays/native-full-game.log`). This replays a preserved completed game;
  it is not a newly generated Python-host game or a54-card roster journey.
- Independent HTML check passes **54 cards/63 profiles/253 weapon rows**,
  including literal non-Monster/Vehicle Lethal predicates (`html-check.log`).
  Permissions remain **67 identities/41 edges**,10 Leader/7 Support cards;
  excluded identities are checked, not made playable (`attachments-check.log`).
- Frame audit passes **128 action routines/70 shared slots**, no duplicates
  or nested re-entry; Game40,096 / Board34,864 inline bytes (`frame-audit.log`,
  `doc/action-frame-lifetimes.json`). No custom init/drop was introduced.
- Matching fresh Godot headers/C++/debug engine pass the new control script:
  all25 source identities,21 directly bound constructors, source/save round
  trip, approximate hulls, actual engine choice and11 named/bank controls.
  Prior elites, infantry, data, unit rules, modifier ignoring, detachments,
  attachments, weapons/sources and public roster controls also pass (ten
  scripts including the new one). `godot/control-results.json` records the
  initial nine-script run: the public-roster journey hit180s under concurrent
  load, then passed alone with600s timeout (`godot/orks_roster-retry.log`).
  This is the known slow host journey, not evidence of a performance fix.
- Fresh20-step Gym check passes with **31,185 candidates/16,368,602 finite
  observations** (`gym.log`). State/action/observation schemas are **35/23/35**,
  next-state36. Whole-quad position domains remain44×30.

The final native correction builds use four workers, debug unoptimized and a
separate `-O2 -g` sanitized fuzzer. Measured native debug build261.935s,
1,849,240KiB peak RSS; sanitized build244.353s,2,289,664KiB peak RSS
(`native-tests-final.json`, `native-fuzzer-corrected.json`). These concurrent
workloads are not a controlled speed comparison. Godot reuses the matching
CTest debug engine with explicit installed libpython linkage; sanitizer/leak
execution remains separate because Godot rejects ASAN RTLD_DEEPBIND loading.

**Corrections made during validation:** Burna Bomb's persisting grant now uses
rule176, separate from its already consumed rule141 trigger; it no longer
spends a once-phase allowance twice. Registered windows recheck their live
conferring ability, so surviving bodyguards cannot keep Snikrot/Wartrike
windows after their attached character dies; both cases have regressions.
Printed27 non-Monster/Vehicle Lethal rows
retain their exclusion predicates. M- now prevents charge/surge/pile-in paths
and rotation as well as ordinary movement (core p10/P10-06). Fixtures were
corrected to identify manually staged passengers, keep a bomb recipient alive,
use actual weapon slots, avoid an invalid Ghaz-as-carrier link, distinguish an
intrinsic Lethal weapon from Busted's grant, and simulate next Command with the
correct phase. The Godot success marker and ctypes pointer reads were fixed
without weakening assertions. All initial failures are superseded by the
passing final runs; old logs/artifacts are retained outside the checkout.

**Next:17.Q.** Implement the arbitrary current-card roster picker, repair the
measured wrapper retrieval/slow-unit execution and complete the outstanding
rendered/full-army journeys. Home-objective ownership requires explicit mission
metadata; source ovals and the user-approved large hull circles remain deliberate
geometry approximations and may constrain placement in the legacy mission.
Exact hull/oval geometry, points and Forge World/Legends remain excluded by the
user. Preserve all identified remaining issues as mandatory fixes;54 adapters
alone do not certify complete edition/mission/host integration.

###17.Q — Public roster and shared-bank integration (complete,2026-10-15)

Read [the public roster and integration guide](doc/orks-custom-roster.md).
User scope excludes rendering and valid-action-discovery optimization; the latter
belongs to the compiler. Earlier performance/rendered obligations are superseded.
Points, detachment prices, Forge World/Legends and exact oval/hull geometry stay
excluded. Mission-specific new-edition scoring still needs mission data; public
full-game checks use the explicitly labelled legacy four-marker fixture.

- [x] Public custom selection for all54 included cards, source-supported model
  counts and per-model equipment, full loadout quotas, cancellation/removal,
  copy/storage/identity limits, all three detachments and actual Warlord handoff.
- [x] Share effective detachment-granted Battleline copy limits at draft/final
  validation, preserving three/six limits and enhancement/Epic restrictions.
- [x] Require one connected coherent live-model group by the user's explicit
  ruling, while retaining printed neighbour/distance checks (core p14).
- [x] Use generated ownership and UTF-8 for native Godot strings. The former
  native-buffer leak and corrupted non-ASCII names have regressions.
- [x] Share own-unit rules across battlefield/reserves/passengers: shock and
  Breakin' Heads, psychic budgets/rolls, Watchin', Dread Power, Surly, healing,
  mortal/FNP/death processing, source grants and turn/phase resets. Remaining
  offboard selectors only choose real storage; genuine geometry/capacity stays
  explicit. No temporary battlefield unit is fabricated for an offboard effect.
- [x] Destroy an unplaceable carrier's passengers before removing that carrier;
  saved games no longer retain dangling passenger identities. Validate saved
  Squig Launcha hits as a subset of total successful hits.
- [x] Source audits:54 cards,63 profiles,253 weapon rows;67 identities/41
  attachment edges;15 detachments/38 options/13 Upgrade tags/40 CP cards.
- [x] Four fresh native public-roster games include all54 cards across eight
  armies and all15 detachments. They finish in985/1,163/1,053/714 actions,
  terminal owner−4, and all four terminal saves restore successfully. These
  roster/engine journeys do not mean every source ability fired in each game.
- [x] Bounded Gym observations remain finite for20 steps:31,319 candidates,
  16,395,288 observations, seed40000. No new custom lifecycle hooks, Python test
  migration, compilation cache or product discovery optimization was introduced.
- [x] The79 new native cases pass the final ASAN/UBSAN/leak sweep (80 runs
  including empty input). Semantic mutation performs175 runs/62s; active
  game-action mutation uses a fresh73-byte seed and performs62 runs/62s.
  Both preserved memory inputs also pass. Fixed replay execution and mutation
  campaigns are separate evidence.
- [x] Twenty matching focused Godot scripts pass, including custom roster,
  shared-bank selectors, string ownership and existing rule controls. Source
  audits,126-action/67-slot frame audit and20-step finite Gym pass at schema37.
- [x] Replace Python test orchestration entirely with native CMake discovery,
  RLC library compilation (no wrapper/`--pylib`) and a C runner per assertion;
  all1,184 assertions and the fixture pass (354.69s total,342.76s compilation).
  Error/skip contracts pass; `ldd` and undefined-symbol inspection show no
  Python dependency. A case also passes with an empty environment and no
  Python on PATH. Repeating a filtered run takes0.16s with no recompilation.
- [x] All four schema37 completed-game binaries replay with ASAN/UBSAN/leak
  checks enabled (77.7/138.8/136.4/92.4s), without diagnostics.
- [x] Complete the broad Godot host walkthrough: deployment/Command recovery,
  terrain/objective saves, Explosives, keyword labels, Firing Deck offboard
  context, shooting/save/allocation snapshots, multi-target charge/path restore,
  Epic Challenge, Counteroffensive, Pile In, alternating fights and Fight on Death.
  This passes in addition to all1,184 native assertions,20 focused Godot scripts
  and four sanitized game replays.

Artifacts are under `/workspace/4hammer-validation/orks-q`. The unoptimized
CTest compilation fixture succeeds with-j4 (693.873s, peak1,866,536KiB under
concurrent validation). After correcting only an assertion in the new ordering
fixture, its matching native library was rebuilt without changing wrapper/API
layout (440.077s, peak1,865,920KiB). The optimized sanitizer build uses-O2/-g/-j4
(376.268s, peak2,289,280KiB). These concurrent timings are not controlled speed
comparisons. AddressSanitizer's supported explicit addr2line configuration now
provides source/function diagnostics without an external-symbolizer warning.

The ordering fixture initially assumed queued removals happened before the next
pending death trigger. Its corrected assertion checks the chosen bank's trigger
flag first and both archives at completion. Native and sanitizer results agree;
the engine ordering was preserved. Godot fixtures were corrected to finish
available enhancement selection, read the shared hit-dice collector, use typed
Trukk constructor arguments and label the death-bank enum once. Those were test
or integration defects, not reasons to weaken rule assertions.

The frame audit passes126 action routines/67 shared slots, zero duplicate frames
and zero nested re-entry: Game37,648 / Board35,472 inline bytes. This removes four
frame types and3,016 Game bytes relative to the first custom-roster draft. That completed validation used state/observation36, action24 and next-state37.
The final Command-scan follow-up below supersedes that internal-state schema.


**Final Command-scan follow-up:** the remaining three Command Battle-shock
loops now share one bank scan and freeze recovery eligibility for all banks at
the STEP start (core p30; appendix01.02.04). Previously the reserve/passenger
loops sampled eligibility later. A new regression checks all three banks and
specifically simulates an offboard unit gaining shock during an earlier unit's
test: a later passed roll must not clear that newly gained shock. This adds one
assertion (1,184 total;79 new in17.Q). State/observation37, action24 and next-state38
require newly matching native/Python/Godot artifacts. The schema37 frame audit
reports Game37,696 / Board35,472 bytes; candidate count stays31,319 and bounded
observation size is16,395,288. All1,184 assertions passed with the prior runner;
the user then required removing Python from CTest entirely. The replacement
native runner and fresh library pass all1,184 assertions. Native contract
fixtures confirm false results, crashes and XPASS fail; XFAIL returns77; unknown
names and malformed signatures/manifests are rejected. The old Python runners
were removed rather than retained as alternate test entrypoints. Historical
state36 build timings above are not speed comparisons with the new test path.


**17.Q completion:** all scoped rule, public-roster, non-rendering host, save,
ML and sanitizer checks above pass on the final schema37 source. The broad
Godot script completes with its final PASS and no reported errors/leaked
instances; it takes approximately35 minutes through the unchanged production
action-discovery path. The user owns discovery optimization in the compiler;
no optimization or cache was introduced here. Rendered journeys remain excluded.
The legacy four-marker mission, whole-inch quads, intentional circular footprint
proxies and unavailable mission-specific new-edition data retain their explicit
limits; this is scoped integration completion, not certification of unspecified
missions or every possible army/ability combination.

## Shared ability procedures — generic-army refactor step5

This is step5 of the subsequent generic-army refactor, separate from migration
task5 (timing). The user approved independent commits and then clarified that
reuse by other armies takes priority over forcing a line reduction. This batch
extracts common procedures; it does not replace the faction catalogs, source
registries or the remaining Orks-specific effect metadata.

- [x] Share round-resource accounting and the spent-before-roll/reroll procedure.
  Orks Wurrband and datasheet psychic actions share one psychic-test adapter;
  capacities, failure Battle-shock and card effects remain source decisions.
- [x] Share reactive Normal moves and Surge through `granted_move` and core
  `Move`. Preserve Surge goals, optional objective destinations, completed-move
  history and caller role/constraint restoration.
- [x] Share wound healing and original-model return across abilities/banks.
  Remove the faction healing wrapper, repeated restoration/placement paths and
  three-wound chunking. Keep phase-start versus nearest-unengaged placement,
  wounded-first/Character restrictions, passenger capacity and original usage.
- [x] Review recurring targeted effects. Their mortality/jobs/grant pipelines
  are already shared; differing roll meanings and eligibility stay explicit.
  No additional universal target/effect interpreter is justified in this batch.
- [x] Native CTest:1,190 assertions plus compilation fixture pass, with no
  Python test runtime. Six new assertions exercise generic resource accounting,
  rerolls, context restoration, objective restrictions, full healing allowances
  and explicit Character return on non-Orks fixtures. Existing all-bank,
  psychic, Surge, healing, Surly and capacity regressions remain passing.
- [x] Frame audit:125 action routines/66 shared slots, no duplicate frames or
  nested re-entry; Game34,160 / Board31,936 bytes. Both shrink by3,536 bytes
  compared with the final17.Q schema37 layout.
- [x] Sanitizer sweep:34 focused semantic inputs plus empty input pass with
  ASAN/UBSAN/leak detection. Both preserved memory inputs pass. Separate semantic
  mutation performs131 runs/62s; actual action mutation performs42 runs/62s.
- [x] Fresh native985-action game finishes at owner−4 and restores its final
  save. Twenty Gym steps retain finite observations:30,072 candidates and
  16,390,831 observation values, seed40000. Discovery remains unchanged.
- [x] All21 matching focused Godot scripts pass, including the new faction-free
  shared-procedure bindings and existing roster/attachment/save/selector paths.
  The fresh985-action game also replays with ASAN/UBSAN/leak checks in61.67s.

State/observation40, action26 and next-state41 require matching generated
artifacts. Surly and ordinary return now share the existing one-BoardPosition
`place_returned_model` input; `place_surly_model` is removed. Stored quantities
remain bounded; generated lifecycle, whole-inch quads and intentional circular
proxies are retained. Rules.gd, TraceManager and action discovery are unchanged.

Measured against984267d, all runtime `src` files together lose15 physical lines
and28 nonblank/noncomment lines, including both new generic modules. Orks-named
files lose264 physical lines, mostly moved into shared code. This is a modest
net text reduction, not a264-line removal from the whole engine. Regression
tests and architecture/validation documentation grow separately. Artifacts and
per-file measurements are under `/workspace/4hammer-validation/shared-procedures`.

The initial new objective fixture wrongly treated a diagonal destination as out
of range: circular model and marker radii made it legal. The corrected fixture
compares equally distant east/west moves and preserves the base-edge rule.
Final native validation takes329.14s including309.11s for the unoptimized-j4
compile fixture; those concurrent timings are not a speed comparison. Sanitized
compilation remains a separate optimized-O2/-g build. The earlier instruction to
avoid Python in pure rule tests remains in force; Python here only orchestrates
host/ML checks, reads generated metadata and prepares sanitizer artifacts.

**Step5 complete.** The three implementation commits independently cover
resource/psychic procedures, granted movement, and healing/model return. A
separate validation/documentation commit records the host regression and
architecture. Earlier17.Q broad-walkthrough/source-audit results remain their
historical evidence; this batch reruns the21 focused host scripts, native suite,
frame/ML checks, fresh game and sanitizer checks above. Future generic catalog,
grant and source-dispatch work remains outside this completed procedure batch.

## Cleanup after shared ability procedures

- [x] Remove the unreachable `resolve_model_attack`/`resolve_weapon` chain.
  Public combat already uses declarations and grouped resolution. Preserve
  `single_attack`, which is still exercised by native regression fixtures.
- [x] Remove unused `reserve_deployment` and `spawn_unit` actions and the
  spawn-only `ProfileToUse`/`Player` enums. Actual arrivals stay in
  `movement_phase`; actual creation stays in roster selection/data factories.
- [x] Remove five unused helpers/wrappers: `model_weapon_range`,
  `unit_has_ranged_rule`, `orks_post_attack_available`, `no_weapon_rules` and
  the old `make_morgrim_butchas` roster wrapper. Their live effective-weapon,
  targeted-card, weapon-rule and current roster paths remain in use.
- [x] Check references across sources, tests, examples, host scripts and tools;
  remove the deleted entries from the checked-in HTML overviews. Original
  migration inventory references remain historical source evidence.
- [x] Correct stale architecture text about the three-family-only roster,
  pending Orks migration/consumers, old healing frames and compiler version.
  Preserve the documented external `deployment_position_valid` helper and
  implicit compiler entrypoints `gen_methods`/`fuzz`; a single textual occurrence
  alone does not prove a public or reflected entrypoint is unused.
- [x] Native CTest: all1,190 assertions and the compilation fixture pass
  (296.85s including286.45s compilation, unoptimized-j4). Existing regressions
  exercise the retained single-attack, arrival, roster, weapon and card paths;
  no new mirrored tests were added for deleting unused code.
- [x] Four fresh Godot smoke checks pass: shared procedures, custom roster,
  weapons/sources and shared-bank controls, using regenerated header/extension
  and the fresh native library. The full broad walkthrough was not repeated.
- [x] Frame audit:121 routines, down from125;66 shared slots, no duplicates or
  nested re-entry. Game34,160 / Board31,936 bytes remain unchanged.
- [x] Exact generated layout comparison passes for Game (401 reachable types),
  Board (375) and AnyGameAction (351), including fields, offsets, bounds encoded
  in types and payload ordering. Schema40/26/41 is retained.
- [x] All34 focused semantic sanitizer inputs plus empty input and both
  preserved memory inputs pass. Separate semantic112-run/63s and action28-run/61s
  mutation campaigns and the previous985-action completed-game replay pass ASAN/UBSAN/leak
  checks; the replay takes81.33s. Fixed replay and mutation remain distinct.

The two source commits remove185 runtime lines (143 from unreachable actions
and their private enums,42 from unused helpers); no rule, field or supported
action is added. Active Orks grant/registration hooks remain necessary until
the separate generic-grant/source refactor replaces their consumers. Removing
those hooks here would remove implemented abilities rather than clean up dead
code. Artifacts are under `/workspace/4hammer-validation/cleanup`.

Removing unused native exports still requires regenerating the Godot header
and rebuilding its extension together with the native library. No supported
Game field or payload is intentionally changed; compare their complete
generated layouts and action ordering; this batch confirms schema40/26/41.

**Cleanup complete:** two focused source commits remove185 runtime lines;
the separate documentation/validation commit refreshes architecture and the
frame inventory. Public gameplay, state layout, coordinates and discovery are
unchanged. Active generic-grant/source work remains a future task.
