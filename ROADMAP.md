# 11th-edition rules migration roadmap

This roadmap tracks planning and implementation separately. Tasks 1–4 (coverage inventory, validation baseline, state foundations and quad geometry primitives) are complete; tasks 5–17 remain pending. Update task status and record evidence as work is completed; do not mark a task complete merely because it compiles.

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
| 5 | Pending | Rebuild timing and decision ownership | Add explicit phase/turn start and end windows, active/opposing controller changes, and correctly classified chance decisions (pp. 8–9, 28–30). Centralize CP spending and stratagem eligibility, including per-player and per-unit restrictions (pp. 54–57). |
| 6 | Pending | Rework attachments and unit characteristics | Implement Leader/Support attachment rules, combined starting strength, bodyguard toughness, keyword inheritance and ability lifetime (pp. 66–67, 86–88). Test what survives when bodyguards or attached characters die. New faction attachment permissions require supplied data. |
| 7 | Pending | Correct Command phase and Battle-shock | Implement the prescribed order, Leadership selection, at-or-below-half checks, persistent shock and its restrictions (pp. 8–9, 28–30). Test odd starting strengths, single-model units, already-shocked units and successful recovery. |
| 8 | Pending | Implement terrain, visibility and objective control | Add terrain categories, cover as a Ballistic Skill change, hiding, obscuring and traversal (pp. 46–51). Sum eligible OC and apply control timing, ties and securing rules (pp. 52–53, 88). Keep mission scoring separate from objective control. |
| 9 | Pending | Replace the attack declaration and dice pipeline | Declare weapons and targets before resolution, support split attacks, form permitted attack groups, and implement hit/wound/critical rules (pp. 16–23). Test exact Strength/Toughness thresholds and declarations whose targets change during resolution. |
| 10 | Pending | Replace saves, damage and destruction | Implement save groups and their priority, simultaneous save rolls processed in ascending order, armour/invulnerable comparisons, Precision, normal-before-mortal damage, Feel No Pain, Hazardous and destruction timing (pp. 19–24, 78–88). Test mixed characters, wounded models and group changes during a batch. |
| 11 | Pending | Update movement and deployment systems | Implement Normal, Advance, Remain Stationary, Fall Back, Ordered Retreat and Desperate Escape (pp. 32–33). Add reserve entry/removal, repositioning, Scouts, Deep Strike, surge and flying movement (pp. 68–71, 78–85). Replace the remaining anchor-only deployment/reserve predicates with checks on every base, and provide an independent model-path decision workflow compatible with Godot. Test placement boundaries and round restrictions. |
| 12 | Pending | Update Shooting phase and weapon abilities | Implement normal, assault, close-quarters and indirect modes; engaged Monster/Vehicle shooting; and the revised weapon abilities (pp. 34–35, 62–63, 78–85). Maintain a checklist covering every published core ability, including currently absent ones. |
| 13 | Pending | Replace the Charge sequence | Select the charging unit, roll, then select legal targets and perform the constrained movement (pp. 36–37). Support multiple targets and successful-charge Fights First. Test failed charges, prohibited chargers and incidental engagement with unselected enemies. |
| 14 | Pending | Replace the Fight phase workflow | Implement phase-wide Pile In, alternating fights with the correct starting player, changing eligibility/Fights First, and phase-wide consolidation (pp. 38–43, 87). Test Overrun, newly engaged units and legal passing. |
| 15 | Pending | Implement the revised core stratagems and actions | Implement each core stratagem's exact cost, timing, targets and effects (pp. 54–58). Include end-of-opponent-Movement Overwatch and end-of-Charge Heroic Intervention. Implement generic action eligibility without inventing unavailable mission actions. |
| 16 | Pending | Add transport and aircraft systems | Implement capacity, embarkation, disembarkation modes, emergency procedures, passenger/reserve interactions and Aircraft exceptions (pp. 64–65, 74). These are substantial new systems, not adjustments to existing functionality. |
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

Tasks 1–5 establish the foundations. Attachments and geometry should precede combat; the attack and damage pipelines should precede shooting, fighting and combat stratagems. Godot checks belong in every task that changes actions, followed by a complete integration pass in task 17.

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
