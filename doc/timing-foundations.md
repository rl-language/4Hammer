# Timing and decision ownership foundations — task 5

Task 5 establishes the timing infrastructure; it does not complete the later phase engines or stratagem effects. The game remains on the whole-inch quad grid. No production changes were made to `scripts/Rules.gd` or `scripts/TraceManager.gd`.

## Authority and implemented sequence

The user supplied the app-only Rules Sequencing definition: **first the current player's effects, in any order that player wishes; then the opponent's effects, in any order that opponent wishes**. This is supplied clarification, not text reproduced from the PDF. Printed internal sequences and mission-last end windows remain authoritative. Other app-only Player's Rules details are unavailable.

`TimingWindow`, `TimingStage` and `BattlePhase` are finite enums in `state_types.rl`; `Board.timing` records the current phase/window/controller and whether a window is open. `resolve_timing_window` offers an enum choice among currently available effects, records resolved/declined kinds, completes the current player's group before the opponent's group, and closes the window after the mission stage. Empty windows finish automatically; no unspecified effect or mission achievement is synthesized.

| Boundary | Implementation | Core pages |
| --- | --- | --- |
| Battle round | Start before either turn; end after both turns. First-turn player is active outside turns. | 8, 28 |
| Player turn | Start, Command, Movement, Shooting, Charge, Fight, end. | 29 |
| Command | Start window, both players' Core CP gain, Battle-shock step, ordered Command abilities, end window. Legacy fixture scoring follows non-mission effects at Command end. | 30 |
| Other phases | Start window, existing phase body, end window. Phase-local effects/use records expire after the end window. | 32, 34, 36, 38–42 |
| Turn end | Both armies' mandatory coherency cleanup, current army first. | 14, 29 |

The existing Command ability fixtures are individually selectable. Neural Disruption's controller chooses source/target pairs and source order; the selected enemy unit, rather than the source, receives its Battle-shock test. Declining Shadow in the Warp restores the calling decision owner.

## Roles, chance and spending

`Board.current_player` remains the turn owner. `Board.timing.active_player` represents the tabletop active role (p.8), which temporarily follows a selected moving/shooting/fighting unit's controller. `Board.current_decision_maker` identifies the owner of the current input. Move/charge/attack completion restores the calling roles, including after the existing fight-on-death branch. Defenders can make decisions without becoming the shooting unit's active player. `default_get_current_player` classifies `roll`, `roll_pair`, `reroll`, **`reroll_pair`**, and random-characteristic inputs as chance (`-1`); completed games remain `-4`.

Targeted Command Re-roll uses the affected friendly unit's owner (pp.54/56). Accepting commits expenditure/history before replacement chance input; keeping the original result spends nothing. Targetless compatibility overloads allow free rerolls, not targetless CP spending. Leadership/Battle-shock and Desperate Escape are absent from the printed Command Re-roll list and cannot spend it. Attack/damage characteristic batches still need the new declaration/dice pipeline in task 9.

`can_target_strat` and its explicit-cost counterpart enforce nonempty targets, affordability, the using player's once-per-stratagem-per-phase record, that player's once-per-target-unit-per-phase record, and the controlling player's Battle-shock prohibition (pp.9/54). `commit_stratagem[_with_cost]` spends and records use together; `try_use_strat` rejects invalid input without mutation. A supplied zero-cost override still consumes both limits. Names avoid collisions with generated `can_*` Godot bindings. Known unit-targeted legacy options use these helpers; unsupplied faction target definitions remain explicit exceptions to complete target coverage.

Phase reset clears both players' records on battlefield and reserve units and resets phase-local fighting usage for both armies. Turn history resets include reserves; active-army movement/shooting/charge flags reset without erasing the opponent's flags. The existing additional-CP-per-round carrier now resets at round start, rather than each Command phase; its legacy cap remains an unresolved D12 policy requiring supplied authority.

## Existing options moved to their printed windows

- **Fire Overwatch** is offered only at the end of the opponent's Movement phase (p.57), with an unengaged, non-TITANIC, non-shocked friendly source and an enemy target within 24 inches. Source selection commits CP before target/shooting choices. Declining the timing rule spends nothing. The old per-move/per-charge calls are gone. The standalone legacy `overwatch` helper remains for historical regressions and is not called by the game sequence.
- **Rapid Ingress** is offered at that same opponent Movement end, targets the chosen reserve unit, excludes AIRCRAFT and round one, and spends before setup (pp.54/57). Cancellation after accepting retains the unit in reserves but retains the committed expenditure. Complete every-base entry restrictions remain task 11.
- **Heroic Intervention** moves from individual-charge prompts to opponent Charge end, with base cost 1CP and the printed friendly-unengaged/VEHICLE CHARACTER-or-WALKER restriction (p.57). The supported legacy path represents Leap to Defend. Full Into the Fray (+1CP), roll-before-target selection and successful-charge eligibility remain required tasks 13/15; the legacy charge flag is not yet proof a charge move succeeded. Its faction Pouncing Leap discount remains a fixture needing task-17 data.

## Coherency and Godot contracts

At turn end, an owner cannot finish their group while they have an incoherent unit (p.14). They choose an incoherent UnitID and remove one ModelID at a time until it is coherent, then choose another unit if needed. Removal goes through the identity/archive primitive and bypasses destruction callbacks. The temporary `board.attack.target` supplies the unit required by Godot's existing one-ModelID selector and is restored afterward.

Timing-kind choices use one enum; coherency/ingress/intervention/Overwatch unit choices use one UnitID; model removal uses one ModelID; ingress uses BoardPosition. Neural Disruption uses two UnitIDs, source first and target second. Matching generated native libraries and headers are required. Legacy objective-index and dice payload widgets retain their previous limitations; the new timing choices do not claim to fix them.

State/observation schemas are **5**; action schema is **3**. Old saves, policies and ordered action traces require regeneration. Numeric state stays bounded for inferred ML layout.

## Validation

Executed results: **97 PASS, 8 XFAIL, 0 XPASS**; completed seed-40000 full/shooting games in **346/10 actions**; gym **20 steps**, **9,950** action candidates and **163,673** observation values. Fresh native Godot bindings pass the headless schema/selector/save and new payload-shape assertions. Sanitized fuzzing completes **28 runs in 64 seconds** (coverage **6,679**, features **10,344**) without reported failures or new artifacts. Native replays of both completed scenarios and the original geometry leak input pass with leak detection enabled. The first two focused implementation stages pass **80/85** tests and type checking. ROADMAP.md records this evidence and the next task. The deterministic suite covers affordability and atomic rejection, free-use limits, per-player/unit records, phase/reserve/turn lifetime, CP reroll ownership and decline, chosen effect order and controller transfer, legal/illegal windows, source restrictions, mandatory cleanup for both armies, archived model identity/selector restoration, move/charge/attack role restoration, Command CP ordering and the correct Neural Disruption context.

Native artifacts, build logs and seeded replay traces are outside the checkout in `/workspace/4hammer-validation`. Headless Godot checks cover binding shapes and existing selector/save APIs, not interactive mouse input or rendering. Sanitized fuzzing checks memory/state safety and available actions; it does not establish all rule semantics or combat resolution.

## Required follow-up fixes

Task 6 owns attachment rules. Task 7 must fix shock recovery/persistence, strength thresholds and mixed Leadership. Task 8 must replace legacy OC/scoring and add visibility. Task 9 must fix fixed-characteristic evaluation and provide the declared/batched dice pipeline, including random attack/damage reroll choices. Tasks 10/12/14 must replace legacy destruction, shooting/snap shooting and fight resolution; existing Overwatch six-only/no-hit-reroll/action-ban effects are not certified. Task 11 must fix anchor-only reserve setup and implement full movement/arrival exceptions. Tasks 13/15 must complete Heroic Intervention modes and all other core stratagem effects, including Smokescreen and Counteroffensive at the supplied boundaries. Task 17 must supply faction/mission data and exercise complete editor workflows. D03/D09/D10/D12 remain source dependencies; sequencing alone does not close them. These are required fixes, not waived defects.
