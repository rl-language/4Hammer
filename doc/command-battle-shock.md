# Command phase and Battle-shock — task 7

Core authority: Leadership and Battle-shock, p.9 (procedural A7–A8); Command phase, pp.30–31 (G1); starting/half-strength, p.86 (W1); Insane Bravery, p.56 (N4). Reproduced source wording in the procedural reference controls. Task 6 attachment changes are deferred by user instruction until full datasheets are supplied.

## Implemented behavior

- Leadership succeeds when the full 2D6 total reaches any model's Leadership characteristic. `get_leadership()` selects the lowest threshold; `leadership_roll_succeeds()` rejects empty units. Both Battle-shock and the existing Dark Pact consumer use the full pair total. This does not certify new-edition faction effects or permissions.
- Command start effects precede both players gaining one Core CP. The Battle-shock step precedes other Command abilities. Existing task-5 end effects precede the legacy mission scoring fixture; task 8/17 must still replace its objective/scoring behavior.
- Each live friendly battlefield unit rolls once if already shocked and/or at or below half-strength. No automatic shock expiration occurs. Opposing units retain their shock. Empty/retired units do not roll.
- The step snapshots which units were shocked at its start. A successful roll here clears that existing shock; failure applies/retains shock. A successful ordinary shock roll outside this step does not clear existing shock.
- Multi-model strength compares twice the remaining model count to the preserved starting count. Single-model strength compares twice the remaining wounds to W. Exact half is included for Command eligibility; the separate strict-below helper excludes equality. Odd counts are not rounded, and combined initial strength is preserved even for a full-health lone surviving leader. These tests do not implement deferred attachment rules.
- Shock is unit state shared by every model. `model_is_battle_shocked()` exposes that inheritance; `model_objective_control()` contributes zero while shocked. The legacy objective query excludes shocked units so their presence cannot erase a healthy friendly contribution. Its other aggregation, ties, marker geometry and securing defects remain task 8.
- The existing targeting gate rejects the controller's stratagems against shocked units; an opposing player's target is not rejected by this restriction. `allows_action_start()` and `allows_action_completion()` expose the shock prohibition. They are only shock gates: task 15 must combine them with the full action workflow and supplied mission conditions.
- Insane Bravery is offered immediately before an eligible friendly roll in the active player's Command Battle-shock step. Existing shock blocks the controller's targeting; no exception was invented. Accepting spends 1CP, records target/phase use and battle-long use, and succeeds without dice. Declining spends nothing. Battle-long use survives phase/turn cleanup and is checked by centralized expenditure entrypoints independently for each player. Command Re-roll remains unavailable for Leadership/Battle-shock rolls.

## Compatibility

State and observation schemas are **6**; action schema remains **3**. New board state is a bounded two-Bool Insane Bravery record; step/frame snapshots use finite Bool arrays/flags. Numeric state/action domains retain their existing bounds. Older saves are rejected transactionally.

No action payload shape changed. The existing one-Bool Bravery choices and two-die chance payload are preserved. Godot headers and native libraries must be regenerated together. Quads and grid action domains are unchanged. `scripts/Rules.gd` and `scripts/TraceManager.gd` are unchanged.

## Validation

- Deterministic suite: **120 PASS**, **5 XFAIL**, **0 XPASS**. The three task-7 discrepancy assertions (mixed Leadership, shock OC, opposing shock persistence) are promoted unchanged into the passing suite and removed from the manifest. Added cases cover exact/odd half-strength, single-model wounds, preserved combined counts, recovery/failure, one roll for both conditions, empty slots, out-of-step success, restrictions, Bravery timing/decline/battle limits and save compatibility.
- CTest: **127 entries**: 120 supported assertions, five explicit expected-failure skips, two compilation fixtures. The Python discovery correction prefers the activated environment; incompatible Python is rejected at configuration rather than after compilation.
- Seed 40000: full game completes in **347 actions**, shooting in **10**, with legal-action/payload round trips and correct terminal ownership. These remain smoke checks; fixed characteristics still suppress actual combat until task 9.
- Existing random CLI smoke checks: 200 bounded full-game actions and three completed shooting scenarios (32 actions total), below the shared 5,000-action limit.
- Completed full/shooting replay inputs and the original geometry leak regression execute through the sanitized native fuzzer without reported failures; leak detection remains enabled.
- Gym/JIT: **20 legal steps**, finite observations, **9,950** enumerated actions and **163,771** observation values.
- Fresh optimized/debug/precondition/bounds native fuzzer built with RLC 0.4.13 and Clang 21. Sanitizers, including leak detection, remain enabled. Seeded mutation campaign: **25 runs in 69 seconds**, coverage **6,696**, feature count **10,676**, no reported failure/artifact. Low iteration count reflects expensive full-game action enumeration and is not rule certification.
- Headless Godot 4.6.3 passes selectors, army choices, both-army deployment/finish handoff, save replacement, and a real Command recovery roll. Save/reload while waiting for its dice preserves shock, recovery snapshot and chance owner `-1`; success restores active-player decision ownership and shock gates. Interactive rendering/input was not exercised.

Artifacts/logs are outside the checkout under `/workspace/4hammer-validation/task7-*` and `/workspace/4hammer-validation/logs/task7-*`.

## Required follow-up

The remaining expected failures are fixed characteristics/exact wound thresholds (task 9) and objective aggregation/ties (task 8). They are mandatory fixes, not accepted behavior. Task 15 must integrate the shock gates into actual action start/completion decisions; no mission action was invented here. Task 17 must replace old faction/datasheet/mission fixtures with supplied data. Task 6 remains deferred.

General off-battlefield eligibility, persisting effects and healing app definitions remain source gate D10. This implementation covers the existing battlefield-unit Command loop; it does not invent an off-table roll/recovery policy for reserves/passengers. Tasks 11/16 must integrate their printed reserve/transport rules and resolve that policy when the supporting definitions are supplied. General extra-CP limits and characteristic/damage modifiers remain their existing source gates.
