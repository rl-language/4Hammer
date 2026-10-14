# 11th-edition rule coverage map

Roadmap task 1: documentation inventory completed; its original classifications describe the pre-migration sources. This map describes source inspection, not new-edition compliance. Its regression cases are planning requirements; [task 2's validation report](validation-baseline.md) identifies the subset now exercised and distinguishes passing assertions from reproduced discrepancies.

Specification: [procedural/source-wording reference](11th-edition-core-rules-procedural.txt), Part II controls over Part I. Scope: the supplied 88-page PDF; its advertised p.89 index is absent. Reference subsection IDs below are the original IDs, not editorial entry numbers.

Inventory: **156 numbered subsections**, **31 supplemental entries**, **1114 retained excerpt locators** across **73 text-bearing pages**. The [excerpt ledger](11th-edition-source-coverage.tsv) maps every retained locator to coverage entries and task owners, including sidebars, examples, tables, FAQs and cross-reference panels. Page-level ownership in that ledger is a completeness index, not an assertion that every excerpt is itself an operative rule.

## Implemented progress overlay

Task 3's [state foundations report](state-foundations.md) records tested bounded storage/capacity, identity, provenance, archive/history and schema changes. CP/Advance storage (08.02/09.06) and actual-cost/own-player stratagem checks (15.01) now have passing assertions, alongside lifecycle boundary tests. Their complete subsection workflows remain owned by later tasks; the original table rows below are not promoted to full-rule implementation. Task 4's [geometry report](geometry-foundations.md) records quad-preserving measurements, coherency/engagement, transactional paths/setup and tested binding compatibility. The current suite has 74 passing assertions and 8 remaining mandatory discrepancy fixes. Full movement modes, setup-specific constraints, terrain/visibility and end-turn incoherency removal remain with their later owners. Consult ROADMAP.md for task completion status.

Task 7's [Command/Battle-shock report](command-battle-shock.md) records tested Leadership, exact strength boundaries, Command recovery, shock gates and Insane Bravery limits. The current suite has 120 passing assertions and five remaining mandatory discrepancy fixes in tasks 8/9. The original rows for 01.06/01.07, 08.01–08.05 and U17 are historical inspection findings: use the report for implemented behavior and its explicit task-8/15/17 and offboard source limits. Task 6 is deferred by the user until full datasheets arrive.

Task 9's [attack/declaration report](attack-declarations-dice.md) records implemented declaration/gathering/batch dice rules (04.01–04.03, 05.01–05.02), exact Strength thresholds and supplied appendix modifiers/rerolls/random characteristics/retargeting. All three remaining discrepancies are fixed and promoted unchanged; 171 supported assertions pass. D03/D11 are resolved only for the supplied definitions; Multiple Weapon Profiles remains unavailable. Legacy saves/damage and complete ability/mode workflows remain mandatory tasks 10/12/14/15, not certified by this overlay. The user-directed no-random-A-melee assumption is enforced with an assertion.

## Status conventions

- **partial**: related structures or behavior exist; audit/change/test still required.
- **different**: the inspected behavior conflicts with the supplied procedure. This does not, by itself, distinguish an edition change from an older bug.
- **missing**: no implementing path found; referenced code is the integration point, not proof of support.
- **external**: the required definition or publication was not supplied.
- **illustration/context**: supporting material; test its stated outcome or account for its scope without inventing a general rule.

Among numbered subsections, 52 have related partial support, 37 have conflicting behavior, and 67 have no implementing path found. No entry is certified implemented. A declared enum or profile property alone is not execution of the ability. Roadmap task numbers in tables identify implementation ownership; dependencies D01–D12 refer to the gate register below.

## Existing code evidence

Code links point to inspected entry points. Symbol names are more durable than line numbers as migration proceeds. Read called helpers and consuming bindings when implementing a row.

| Alias | Inspected entry point and related code |
| --- | --- |
| [STATE](../src/units.rl#L114) | Unit/Model fields, bounds and positional IDs; board state also in src/board.rl |
| [ARMY](../src/rules.rl#L1102) | Fixed faction choices; make_* factories in src/units.rl |
| [DATA](../src/stats.rl#L4) | AbilityKind, Keyword, Faction, Profile and Stratagem enums |
| [WEAPON](../src/weapons.rl#L21) | WeaponRuleKind, parameterized WeaponRule and fixed weapon profiles |
| [GEO](../src/units.rl#L72) | Model.distance; Unit.distance/move_to/arrange; integer BoardPosition in src/vector2d.rl; Board.is_in_melee |
| [CLOCK](../src/rules.rl#L989) | turn/round/battle/command_phase and phase-modifier resets |
| [CHANCE](../src/game_utils.rl#L52) | Chance-action classification and legal-action fuzzer |
| [DICE](../src/rules.rl#L50) | evaluate_random_stat and single/pair rerollable dice actions |
| [MORALE](../src/rules.rl#L580) | battle_shock_test/step; Unit.get_leadership/is_below_half_strenght |
| [ATTACK](../src/rules.rl#L145) | single_attack/resolve_weapon/resolve_model_attack/attack/_configure_attack/shooting_phase |
| [DAMAGE](../src/units.rl#L348) | Unit.damage/deal_mortal_wound_damage; on_model_destroyed and attack in rules.rl |
| [OBJECTIVE](../src/board.rl#L224) | get_objective_controller/score_objective/score and fixed four markers |
| [STRAT](../src/board.rl#L153) | can_use_strat/pay_strat/mark_strat_used; Stratagem enum and phase-specific offers |
| [ATTACH](../src/units.rl#L167) | attach_to/get_unit_toughtness/has_keyword/has_ability; attach_leaders in rules.rl |
| [MOVE](../src/rules.rl#L725) | move/movement/movement_phase/desperate_escape; formation translation |
| [DEPLOY](../src/rules.rl#L1031) | deployment_position_valid/deploy and attach_leaders before deployment |
| [RESERVE](../src/rules.rl#L859) | reserve_deployment; Board.reserve_units/is_position_valid_for_reserve |
| [CHARGE](../src/rules.rl#L791) | charge/charge_phase and per-charge Heroic Intervention |
| [FIGHT](../src/rules.rl#L744) | fight_step/fight_phase; automatic consolidate_torward before attacks |

Godot consumers: [Rules.gd](../scripts/Rules.gd), [MultipleChoises.gd](../scripts/MultipleChoises.gd), [InteractionManager.gd](../scripts/InteractionManager.gd), [SelectPointManager.gd](../scripts/SelectPointManager.gd); generated binding registration in [gdexample.cpp](../src/gdexample.cpp). Preserve action shapes or implement their UI deliberately.

## Numbered subsection coverage

Every numbered defining subsection has its own migration requirement and planned regression. Dependencies may gate only some edge cases, not the complete task.

### Section 01

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 01.01 — ARMIES; p. 8; `P08-02` | 3,17 | [STATE](../src/units.rl#L114), [ARMY](../src/rules.rl#L1102) | partial | Preserve army ownership separately from active controller; replace only with supplied army data. | Friendly/enemy ownership remains stable during opponent-turn activation. | D09 |
| 01.02 — UNITS AND MODELS; p. 8; `P08-04` | 3,4,6 | [STATE](../src/units.rl#L114), [GEO](../src/units.rl#L72), [ATTACH](../src/units.rl#L167) | partial | Represent bases, model membership and unit-scoped effects without losing model provenance. | Unit effect reaches every member; base edge affects distance; removing member preserves identity. | D05 |
| 01.03 — ACTIVE PLAYER AND OPPOSING PLAYER; p. 8; `P08-10` | 5 | [CLOCK](../src/rules.rl#L989), [CHANCE](../src/game_utils.rl#L52) | different | Add temporary active/opposing ownership during moves, shooting and fighting, including outside turns. | Opponent unit activation changes active player then restores it; round boundary uses first player. | D04 |
| 01.04 — MEASURING DISTANCES; p. 9; `P09-01` | 4 | [GEO](../src/units.rl#L72) | partial | Standardize nearest-base measurements and FRAME exception; add horizontal/vertical geometry. | Different base sizes, exact distance and hull exception yield consistent measurements. | D05 |
| 01.05 — DICE; p. 9; `P09-04` | 2,5,9 | [DICE](../src/rules.rl#L50), [CHANCE](../src/game_utils.rl#L52) | partial | Represent D6, D3, sums and additions as explicit chance actions; audit bounded results. | D3 maps 1/2 to 1, 3/4 to 2, 5/6 to 3; reroll_pair is chance. | D03 |
| 01.06 — LEADERSHIP ROLLS; p. 9; `P09-08` | 7 | [MORALE](../src/rules.rl#L580) | different | Use success against at least one Ld rather than maximum Ld. | Mixed Ld 6/8 succeeds on 6; 5 fails; 2D6 owner is controller. | D03 |
| 01.07 — BATTLE-SHOCK ROLLS; p. 9; `P09-10` | 7,8,15 | [MORALE](../src/rules.rl#L580), [OBJECTIVE](../src/board.rl#L224), [STRAT](../src/board.rl#L153) | partial | Apply shock to models, OC, own stratagem targeting and action eligibility/completion. | Shocked unit contributes no OC, rejects own stratagem and cannot complete action. | D03 |

### Section 02

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 02.01 — 1. DATASHEET NAME; p. 10; `P10-02` | 17 | [DATA](../src/stats.rl#L4) | partial | Preserve datasheet identity distinct from unit instance and displayed name. | Two instances of one datasheet retain separate state and shared definition. | D09 |
| 02.02 — 2. PROFILES; p. 10; `P10-04` | 3,9,17 | [DATA](../src/stats.rl#L4), [STATE](../src/units.rl#L114) | partial | Represent all printed characteristics including dash and random characteristics without silent clamps. | Dash differs from numeric zero; legal wounds/OC exceed current wrappers without truncation. | D03,D09 |
| 02.03 — 3. ABILITIES; p. 10; `P10-13` | 6,12,17 | [DATA](../src/stats.rl#L4), [ATTACH](../src/units.rl#L167) | partial | Separate core, faction and sourced abilities; track applicability and lifetime. | Attached source ability expires correctly; definition lookup cannot substitute old faction text. | D09 |
| 02.04 — 4. WEAPONS; p. 10; `P10-15` | 9,12,17 | [DATA](../src/stats.rl#L4), [WEAPON](../src/weapons.rl#L21) | partial | Represent complete weapon profiles and abilities, including signed AP, random values and keyword-qualified weapon abilities. | Profile conversion preserves range/A/skill/S/AP/D; different profiles form distinct batches. | D03,D11 |
| 02.05 — 5. KEYWORDS; p. 10; `P10-24` | 6,12 | [DATA](../src/stats.rl#L4), [ATTACH](../src/units.rl#L167) | partial | Maintain unit keyword union while preserving each model's own keywords. | Mixed PSYKER unit triggers unit-targeted ANTI without giving every model PSYKER. | D09 |
| 02.06 — 6. UNIT COMPOSITION AND OTHER RULES; p. 11; `P11-02` | 3,6,17 | [ARMY](../src/rules.rl#L1102), [ATTACH](../src/units.rl#L167) | partial | Replace fixed composition only from supplied datasheets; retain attachment permissions and provenance. | Composition limits and permitted bodyguards checked; unsupported definitions reported. | D09 |
| 02.07 — 7. WARGEAR OPTIONS; p. 11; `P11-03` | 17 | [ARMY](../src/rules.rl#L1102), [WEAPON](../src/weapons.rl#L21) | missing | Add supplied wargear options and validate selections; current factories fix equipment. | Allowed replacement succeeds; incompatible combination fails; source identity survives revival. | D09,D11 |

### Section 03

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 03.01 — MOVING UNITS; p. 12; `P12-02` | 4,11 | [MOVE](../src/rules.rl#L725), [GEO](../src/units.rl#L72) | different | Move models individually with per-model budgets, path segments, rotation and traversal checks. | Mixed M, path detour, free rotation and overlap legality tested independently. | D05 |
| 03.02 — SET UP; p. 14; `P14-01` | 4,11 | [DEPLOY](../src/rules.rl#L1031), [GEO](../src/units.rl#L72) | partial | Validate all placed models, coherency, engagement and every placement-specific constraint. | Anchor legal but trailing model illegal rejects setup; setup differs from movement. | D05 |
| 03.03 — COHERENCY; p. 14; `P14-08` | 4,5 | [GEO](../src/units.rl#L72), [CLOCK](../src/rules.rl#L989) | missing | Enforce local 2-inch/5-inch and whole-unit 9-inch/5-inch coherency; end-turn removal has no destruction triggers. | Exact horizontal/vertical limits; isolated chain; incoherent removal does not trigger Deadly Demise. | D05 |
| 03.04 — ENGAGEMENT; p. 14; `P14-13` | 4 | [GEO](../src/units.rl#L72) | different | Replace less-than-1 melee with inclusive 2-inch horizontal/5-inch vertical engagement. | At 2/5 engaged; just beyond either not engaged; mixed model pairs. | D05 |

### Section 04

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 04.01 — 1. SELECT WEAPONS; p. 16; `P16-04` | 9,12 | [ATTACK](../src/rules.rl#L145) | different | Finish legal weapon declarations before resolving any selected weapon. | No hit dice before declarations finish; melee weapon and extra attack selection constraints. | D11 |
| 04.02 — 2. SELECT TARGETS; p. 16; `P16-10` | 9 | [ATTACK](../src/rules.rl#L145), [GEO](../src/units.rl#L72) | different | Declare each weapon's target with printed visibility/range and split-target permissions. | Two declared targets; snapshot half-range and target count before casualties. | D05,D11 |
| 04.03 — 3. RESOLVE ATTACKS; p. 17; `P17-01` | 9 | [ATTACK](../src/rules.rl#L145), [DICE](../src/rules.rl#L50) | different | Group identical attacks by characteristics/abilities and resolve targets in prescribed order. | Identical profiles batch; different AP or abilities do not; later group uses declared snapshot. | D03,D11 |

### Section 05

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 05.01 — 1. HIT ROLLS; p. 18; `P18-06` | 9 | [ATTACK](../src/rules.rl#L145), [DICE](../src/rules.rl#L50) | partial | Use staged hit dice, unmodified 1 failure and 6 critical success; retain modifier dependency. | Six hits despite worsened threshold; one fails despite bonus; distinguish critical from ordinary hit. | D03 |
| 05.02 — 2. WOUND ROLLS; p. 18; `P18-09` | 9 | [ATTACK](../src/rules.rl#L145) | different | Use inclusive double/half Strength thresholds and staged critical wounds. | S=2T needs 2; 2S=T needs 6; one fails and six is critical. | D03 |
| 05.03 — 3. SAVE ROLLS; p. 19; `P19-01` | 10 | [ATTACK](../src/rules.rl#L145), [DAMAGE](../src/units.rl#L348) | different | Build save groups and legal order before rolling saves, then process ascending results. | Wounded non-character first, all non-characters before characters, wounded character priority; printed pp.20–23 examples. | D03,D06 |
| 05.04 — 4. INFLICT DAMAGE; p. 19; `P19-08` | 10 | [ATTACK](../src/rules.rl#L145), [DAMAGE](../src/units.rl#L348) | different | Resolve each ordered save through unmodified 1, InSv and AP-adjusted Sv, then per-attack wound loss. | Same die checked against InSv then Sv; current group changes mid-batch; excess normal damage not spilled. | D03,D06,D07 |

### Section 06

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 06.01 — VISIBILITY; p. 24; `P24-02` | 4,8,9 | [GEO](../src/units.rl#L72), [ATTACK](../src/rules.rl#L145) | missing | Add model visibility and full visibility from actual geometry and terrain. | One visible model enables permitted targeting; obscured base/body and terrain produce correct result. | D05 |
| 06.02 — MORTAL WOUNDS; p. 24; `P24-05` | 10 | [DAMAGE](../src/units.rl#L348), [ATTACK](../src/rules.rl#L145) | different | Allocate mortal wounds by wounded non-character/non-character/wounded character/character priority after normal damage. | Normal damage resolved before mortal pool; mortal spill and wounded group preference. | D07 |
| 06.03 — HAZARD ROLLS; p. 24; `P24-15` | 7,10 | [DICE](../src/rules.rl#L50), [DAMAGE](../src/units.rl#L348) | different | Generalize simultaneous hazard rolls: 1–2 fail, 1 mortal wound or 3 for all-MONSTER/VEHICLE units. | Roll 2 fails; 3 succeeds; mixed-keyword unit checks all models; applies mortal allocation. | D03 |

### Section 07

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 07.01 — 1. START OF BATTLE ROUND; p. 28; `P28-01` | 5 | [CLOCK](../src/rules.rl#L989) | missing | Add start-round timing window and round-boundary controller. | Start-round effect happens once before either Command phase. | D04,D09 |
| 07.02 — 2. PLAYER TURNS; p. 28; `P28-06` | 5,17 | [CLOCK](../src/rules.rl#L989) | partial | Retain ordered player turns but expose start/end-turn windows and mission-dependent duration. | Both players act in first-player order; start/end hooks occur exactly once. | D04,D09 |
| 07.03 — 3. END OF BATTLE ROUND; p. 28; `P28-09` | 5,11 | [CLOCK](../src/rules.rl#L989), [RESERVE](../src/rules.rl#L859) | missing | Add end-round window including unused reserve destruction at end round 3. | Third-round reserve cleanup after both turns, with explicit exemptions. | D04,D10 |

### Section 08

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 08.01 — 1. START OF COMMAND PHASE; p. 30; `P30-01` | 5,7 | [CLOCK](../src/rules.rl#L989), [MORALE](../src/rules.rl#L580) | missing | Expose start-Command effects before Core CP gain. | Ordered trace shows start hook then CP then shock. | D04 |
| 08.02 — 2. GAIN CORE CP; p. 30; `P30-03` | 3,5 | [CLOCK](../src/rules.rl#L989), [STRAT](../src/board.rl#L153) | partial | Grant both players Core CP; remove arbitrary storage cap and do not assume old extra-CP limit. | Both gain one; CP above 3 retained; distinguish published gain from unresolved extra-generation policy. | D12 |
| 08.03 — 3. BATTLE-SHOCK; p. 30; `P30-05` | 7 | [MORALE](../src/rules.rl#L580) | different | Roll for already-shocked or at/below-half own units; only success here clears existing shock. | Opponent shock persists; exact half tested; other successful shock roll does not clear existing shock. | D03 |
| 08.04 — 4. COMMAND ABILITIES; p. 30; `P30-10` | 5,7,17 | [CLOCK](../src/rules.rl#L989), [DATA](../src/stats.rl#L4) | different | Move command abilities after Battle-shock; replace faction behavior only from supplied rules. | Shock restrictions apply before command ability selection; sourced timing trace. | D04,D09 |
| 08.05 — 5. END OF COMMAND PHASE; p. 30; `P30-12` | 5,8,17 | [CLOCK](../src/rules.rl#L989), [OBJECTIVE](../src/board.rl#L224) | partial | Add end-Command window; make scoring conditional on mission rather than unconditional core behavior. | End-phase control recalculated; no scoring rule synthesized from current fixed mission. | D04,D09 |

### Section 09

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 09.01 — 1. START OF MOVEMENT PHASE; p. 32; `P32-01` | 5,11 | [CLOCK](../src/rules.rl#L989), [MOVE](../src/rules.rl#L725) | missing | Add start-Movement window. | Start effects resolve before selecting first moving unit. | D04 |
| 09.02 — 2. MOVE UNITS; p. 32; `P32-03` | 11 | [MOVE](../src/rules.rl#L725), [RESERVE](../src/rules.rl#L859) | different | Select move modes for all required units including off-board/stationary units; track per-phase move use. | Unit cannot move twice; off-board eligibility and stationary handling follow source. | D10 |
| 09.03 — 3. END OF MOVEMENT PHASE; p. 32; `P32-12` | 5,11,15 | [MOVE](../src/rules.rl#L725), [STRAT](../src/board.rl#L153) | partial | Add explicit end-Movement window for reserve-related effects and revised Overwatch. | Overwatch offered only at end opponent Movement; phase state resets correctly. | D04 |
| 09.04 — REMAIN STATIONARY; p. 33; `P33-01` | 11 | [MOVE](../src/rules.rl#L725) | missing | Add Remain Stationary mode without movement/rotation or move-trigger effects. | Stationary unit cannot rotate; no move trigger; distinct from normal move distance zero. | - |
| 09.05 — NORMAL MOVE; p. 33; `P33-05` | 4,11 | [MOVE](../src/rules.rl#L725), [GEO](../src/units.rl#L72) | partial | Apply Normal Move legality, per-model M and final engagement restrictions. | Engaged unit cannot choose normal except explicit Aircraft exception; mixed M tested. | D05 |
| 09.06 — ADVANCE MOVE; p. 33; `P33-10` | 11 | [MOVE](../src/rules.rl#L725), [DICE](../src/rules.rl#L50) | partial | Apply D6 Advance increment without StatModifier truncation and record advance restrictions. | Advance rolls 4–6 preserve full distance; assault vs charge/action eligibility. | D03 |
| 09.07 — FALL-BACK MOVE; p. 33; `P33-18` | 7,11 | [MOVE](../src/rules.rl#L725), [MORALE](../src/rules.rl#L580), [DAMAGE](../src/units.rl#L348) | different | Implement Ordered Retreat choice, per-model Desperate Escape hazards, traversal and post-move shock. | Non-shocked retreat choice; shocked fallback hazards; crossing enemies and final unengaged requirement. | D03,D05 |

### Section 10

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 10.01 — 1. START OF SHOOTING PHASE; p. 34; `P34-01` | 5,12,15 | [CLOCK](../src/rules.rl#L989), [ATTACK](../src/rules.rl#L145) | missing | Add start-Shooting window including opponent Smokescreen timing. | Smokescreen precedes target declaration; wrong phase rejected. | D04 |
| 10.02 — 2. SHOOT; p. 34; `P34-03` | 9,12 | [ATTACK](../src/rules.rl#L145) | partial | Separate unit shooting eligibility from usable weapons and mode; track once-per-phase selection. | No-ranged-weapon unit eligible to shoot; cannot shoot twice or act after shooting. | D11 |
| 10.03 — 3. END OF SHOOTING PHASE; p. 34; `P34-11` | 5,12 | [CLOCK](../src/rules.rl#L989), [ATTACK](../src/rules.rl#L145) | missing | Add end-Shooting window and retain attack history needed for hiding. | History survives into following turn; hook after final shot. | D04 |
| 10.04 — NORMAL SHOOTING; p. 34; `P34-13` | 12 | [ATTACK](../src/rules.rl#L145) | partial | Implement full normal-shooting eligibility and per-model weapon selection. | Engaged/advanced/fallen-back cases rejected unless printed exception; melee weapons excluded. | D11 |
| 10.05 — ASSAULT SHOOTING; p. 35; `P35-05` | 12 | [ATTACK](../src/rules.rl#L145), [WEAPON](../src/weapons.rl#L21) | partial | Implement Assault Shooting as an explicit mode using ASSAULT weapons. | Advanced unit can select only legal assault profiles; mode cannot permit forbidden action/charge. | - |
| 10.06 — CLOSE‑QUARTERS SHOOTING; p. 35; `P35-12` | 12 | [ATTACK](../src/rules.rl#L145), [WEAPON](../src/weapons.rl#L21) | different | Implement close-quarters mode, engaged target restrictions, model exceptions and BLAST exclusions. | Pistol alias works; engaged Monster/Vehicle and both p.88 BLAST FAQs. | D05 |
| 10.07 — INDIRECT SHOOTING; p. 35; `P35-21` | 8,12 | [ATTACK](../src/rules.rl#L145), [WEAPON](../src/weapons.rl#L21) | missing | Implement indirect mode: cover, no hit rerolls and unmodified failure thresholds with stationary spotter exception. | Unmodified 5 fails normally; stationary and friendly-visible case 4 hits; reroll unavailable. | D03,D05 |

### Section 11

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 11.01 — 1. START OF CHARGE PHASE; p. 36; `P36-01` | 5,13 | [CLOCK](../src/rules.rl#L989) | missing | Add start-Charge timing window. | Start effect resolves before charger selection. | D04 |
| 11.02 — 2. CHARGE; p. 36; `P36-03` | 13 | [CHARGE](../src/rules.rl#L791), [DICE](../src/rules.rl#L50) | different | Select charger and roll before selecting targets; targets meet 12-inch and actual-roll constraints. | No target decision before dice; multiple targets; failed/declined charge does not grant success effects. | D05,D11 |
| 11.03 — 3. END OF CHARGE PHASE; p. 36; `P36-10` | 5,13,15 | [CHARGE](../src/rules.rl#L791), [STRAT](../src/board.rl#L153) | missing | Add end-Charge window and move Heroic Intervention there. | Intervention occurs after all charges rather than after each charge. | D04 |
| 11.04 — CHARGE MOVE; p. 37; `P37-01` | 4,13 | [CHARGE](../src/rules.rl#L791), [GEO](../src/units.rl#L72) | different | Replace automatic translated formation with individual constrained charge movement. | All selected targets engaged; no unselected enemy engaged; within 1 if possible; successful charge grants Fights First. | D05 |

### Section 12

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 12.01 — 1. START OF FIGHT PHASE; p. 38; `P38-01` | 5,14 | [FIGHT](../src/rules.rl#L744) | partial | Expose start-Fight effects before phase-wide Pile In. | Start hook precedes every pile-in choice. | D04 |
| 12.02 — 2. PILE IN; p. 38; `P38-03` | 14 | [FIGHT](../src/rules.rl#L744) | missing | Add phase-wide Pile In selection in turn-owner then opponent order. | All first-player pile-ins precede opponent pile-ins; no normal fight interleaved. | D05 |
| 12.03 — PILE-IN MOVE; p. 38; `P38-05` | 4,14 | [FIGHT](../src/rules.rl#L744), [GEO](../src/units.rl#L72) | missing | Implement pile-in move eligibility, distance and closest-target constraints. | Eligible/unable unit, move budget and closest enemy with Aircraft exception. | D05 |
| 12.04 — 3. FIGHT; p. 40; `P40-02` | 14 | [FIGHT](../src/rules.rl#L744) | different | Rebuild FF/Remaining switching, starting-player rules and fight eligibility snapshots. | FF begins turn owner; Remaining begins transitioning player; new FF returns sequence; legal p.87 passing. | D04,D08 |
| 12.05 — NORMAL FIGHT; p. 40; `P40-12` | 9,14 | [FIGHT](../src/rules.rl#L744), [ATTACK](../src/rules.rl#L145) | partial | Apply normal-fight eligibility and separate attack declaration from movement. | Charged or start-step-engaged unit eligible after target loss; split melee declarations. | D08,D11 |
| 12.06 — OVERRUN FIGHT; p. 40; `P40-15` | 14 | [FIGHT](../src/rules.rl#L744) | missing | Implement overrun fight without treating overrun availability as general fight eligibility. | p.88 overrun FAQ: disengaged ineligible unit cannot overrun; otherwise permitted extra pile-in. | D08 |
| 12.07 — 4. CONSOLIDATE; p. 42; `P42-01` | 14 | [FIGHT](../src/rules.rl#L744) | missing | Add phase-wide consolidation after Fight step. | All fights resolve before consolidation; newly engaged enemies can fight as specified. | D08 |
| 12.08 — CONSOLIDATION MOVE; p. 42; `P42-03` | 4,8,14 | [FIGHT](../src/rules.rl#L744), [GEO](../src/units.rl#L72), [OBJECTIVE](../src/board.rl#L224) | different | Implement ordered ongoing/engaging/objective consolidation modes instead of automatic pre-attack motion. | Ongoing mode takes priority; objective option only if earlier modes unavailable; final coherency. | D05,D08 |
| 12.09 — 5. END OF FIGHT PHASE; p. 42; `P42-12` | 5,14 | [CLOCK](../src/rules.rl#L989), [FIGHT](../src/rules.rl#L744) | missing | Add end-Fight window after consolidation and its generated fights. | No end-phase effect fires before final consolidation-triggered combat. | D04 |

### Section 13

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 13.01 — PLACING TERRAIN; p. 46; `P46-01` | 4,8,17 | [GEO](../src/units.rl#L72), [OBJECTIVE](../src/board.rl#L224) | missing | Represent agreed terrain areas and mission placement, not just point objectives. | Multiple features share an area; features outside its boundary rejected by configuration. | D09 |
| 13.02 — TERRAIN CATEGORIES; p. 46; `P46-06` | 8 | [GEO](../src/units.rl#L72) | missing | Represent feature categories separately from area membership. | Mixed light/dense features in one area retain individual traversal rules. | - |
| 13.03 — EXPOSED; p. 46; `P46-08` | 8 | [GEO](../src/units.rl#L72) | missing | Add exposed category and prescribed traversal/visibility behavior. | Exposed area does not acquire dense restrictions merely by sharing an area. | D05 |
| 13.04 — LIGHT; p. 46; `P46-10` | 8 | [GEO](../src/units.rl#L72) | missing | Add light category and applicable cover/obscuring behavior. | Light feature traversable; area contributes obscuring under stated conditions. | D05 |
| 13.05 — DENSE; p. 46; `P46-12` | 8 | [GEO](../src/units.rl#L72) | missing | Add dense category with terrain-dependent movement/hiding/solid rules. | Dense area enables hiding; dense feature supplies solid behavior. | D05 |
| 13.06 — TERRAIN AND MOVEMENT; p. 48; `P48-01` | 4,8,11 | [GEO](../src/units.rl#L72), [MOVE](../src/rules.rl#L725) | missing | Implement horizontal/vertical keyword traversal, ascent cost, stable upper placement and no-overhang rules. | p.49 examples; MOBILE horizontal-only exception; 2-inch wall boundary; legal roof placement. | D05 |
| 13.07 — TERRAIN AND VISIBILITY; p. 50; `P50-01` | 8 | [GEO](../src/units.rl#L72) | missing | Apply cover/hidden/obscuring/solid as distinct visibility mechanisms. | LOS blocked vs visible-with-cover are distinct outcomes. | D05 |
| 13.08 — BENEFIT OF COVER; p. 50; `P50-03` | 8,12 | [ATTACK](../src/rules.rl#L145), [GEO](../src/units.rl#L72) | missing | Worsen attack BS by 1 when every target model qualifies for cover. | Mixed qualifying conditions allowed; one unprotected model removes cover; save unaffected. | D03 |
| 13.09 — HIDDEN; p. 50; `P50-07` | 5,8,12 | [GEO](../src/units.rl#L72), [STATE](../src/units.rl#L114) | missing | Track ranged attacks current/previous turn and default 15-inch detection range. | Exactly 15 detectable; firing history removes hidden status for correct turns. | D05 |
| 13.10 — OBSCURING; p. 50; `P50-11` | 8 | [GEO](../src/units.rl#L72) | missing | Block LOS when all sight lines cross relevant obscuring areas excluding endpoint areas. | Endpoint in same area exempt; alternate unblocked sight line preserves visibility. | D05 |
| 13.11 — SOLID; p. 50; `P50-13` | 8 | [GEO](../src/units.rl#L72) | missing | Block enclosed gaps at/below 3 inches and prohibit illegal protruding placement. | Door/window gap at 3 blocked; above 3 evaluated normally; mission override explicit. | D05,D09 |

### Section 14

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 14.01 — TERRAIN OBJECTIVES; p. 52; `P52-01` | 8 | [OBJECTIVE](../src/board.rl#L224), [GEO](../src/units.rl#L72) | different | Use terrain area containing objective point, with marker fallback only when applicable. | Model in objective terrain area contributes; non-terrain uses p.88 marker geometry. | D05,D09 |
| 14.02 — LEVEL OF CONTROL; p. 52; `P52-04` | 8 | [OBJECTIVE](../src/board.rl#L224), [MORALE](../src/rules.rl#L580) | different | Sum eligible model OC and update control at prescribed phase/turn boundaries; ties uncontrolled. | Two OC2 models beat OC3; equal totals uncontrolled; shock zeroes contribution. | D03 |
| 14.03 — SECURED OBJECTIVES; p. 52; `P52-09` | 8 | [OBJECTIVE](../src/board.rl#L224) | partial | Represent secured control and its tie/no-presence behavior under granting rules. | Secured objective retains eligible control through tie; enemy greater OC takes control. | D09 |

### Section 15

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 15.01 — USING STRATAGEMS; p. 54; `P54-01` | 3,5,15 | [STRAT](../src/board.rl#L153) | different | Correct own-player usage and actual cost, per-unit phase restrictions and shock eligibility; optional cost transactional. | One player using strat does not block other; one unit second strat forbidden; insufficient CP has no effects. | D03,D04 |
| 15.02 — COMMAND RE-ROLL; p. 56; `P56-01` | 5,9,15 | [DICE](../src/rules.rl#L50), [STRAT](../src/board.rl#L153) | different | Restrict Command Re-roll to listed rolls; one die from batch except whole charge; prohibit Leadership/shock. | Batch die chosen, charge rerolled in full; shock reroll unavailable; target-unit limit enforced. | D03 |
| 15.03 — EPIC CHALLENGE; p. 56; `P56-15` | 10,15 | [STRAT](../src/board.rl#L153), [ATTACK](../src/rules.rl#L145) | missing | Add Epic Challenge at character-unit fight selection and give selected character melee Precision until phase end. | Other models unchanged; expiry at phase end; only visible character groups eligible. | D06 |
| 15.04 — INSANE BRAVERY; p. 56; `P56-21` | 7,15 | [MORALE](../src/rules.rl#L580), [STRAT](../src/board.rl#L153) | partial | Apply pre-roll own Battle-shock-step automatic success once per battle. | Second use another phase rejected; out-of-step roll rejected; permitted success clears shock. | - |
| 15.05 — EXPLOSIVES; p. 56; `P56-28` | 10,15 | [STRAT](../src/board.rl#L153), [DAMAGE](../src/units.rl#L348) | missing | Implement Explosives model/target selection, eligibility and six-D6 mortal procedure. | Advance/engagement forbidden; exact 8-inch and visibility; 4+ counts MW without consuming normal shot by invention. | D05 |
| 15.06 — CRUSHING IMPACT; p. 56; `P56-37` | 10,13,15 | [STRAT](../src/board.rl#L153), [CHARGE](../src/rules.rl#L791), [DAMAGE](../src/units.rl#L348) | missing | Implement complete Crushing Impact selection, mortal sequence and self-hazard as printed. | Trigger only after eligible charge; target keywords, dice limits and resulting hazard damage. | D03,D05 |
| 15.07 — RAPID INGRESS; p. 57; `P57-01` | 11,15 | [RESERVE](../src/rules.rl#L859), [STRAT](../src/board.rl#L153) | partial | Implement Rapid Ingress at end opponent Movement after round 1, excluding Aircraft; spend only on actual use. | Decline pays nothing; round 1 and Aircraft reject; correct offboard passenger exclusion. | D10 |
| 15.08 — FIRE OVERWATCH; p. 57; `P57-08` | 12,15 | [STRAT](../src/board.rl#L153), [ATTACK](../src/rules.rl#L145) | different | Move Fire Overwatch to end opponent Movement; select visible target within 24 and eligible firing unit. | Exactly 24 allowed; no per-move/charge offer; no spend or mark when declined. | D05 |
| 15.09 — SNAP SHOOTING; p. 57; `P57-14` | 9,12,15 | [ATTACK](../src/rules.rl#L145), [DICE](../src/rules.rl#L50) | different | Implement Snap Shooting as unmodified-6 hits with no hit rerolls. | Five fails even if skill/bonus would hit; six hits; forbidden reroll cannot enumerate. | D03 |
| 15.10 — SMOKESCREEN; p. 57; `P57-20` | 8,12,15 | [STRAT](../src/board.rl#L153) | missing | Implement Smokescreen at start opponent Shooting with printed target/effect eligibility. | Wrong timing/keyword rejects; Stealth-derived cover follows all-model rule and effect duration. | D09 |
| 15.11 — HEROIC INTERVENTION; p. 57; `P57-26` | 13,14,15 | [CHARGE](../src/rules.rl#L791), [STRAT](../src/board.rl#L153) | different | Set Heroic Intervention base 1CP at end opponent Charge; optional Into the Fray +1CP caps modified charge roll at 6 and changes allowed targets. | Base vs enhanced affordability; Leap only targets charging enemies; enhanced mode targets within 6; successful charge follows normal FF rule; no per-charge trigger. | D04,D05 |
| 15.12 — COUNTEROFFENSIVE; p. 57; `P57-36` | 14,15 | [FIGHT](../src/rules.rl#L744), [STRAT](../src/board.rl#L153) | missing | Implement Counteroffensive 2CP in opponent Fight step with exact trigger and immediate next selection. | Wrong turn/window rejects; selected unit eligible and not fought; no extra activation invented. | D04,D08 |

### Section 16

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 16.01 — PERFORMING ACTIONS; p. 58; `P58-01` | 5,15,17 | [STATE](../src/units.rl#L114), [MOVE](../src/rules.rl#L725), [ATTACK](../src/rules.rl#L145) | missing | Add generic action start/completion lifecycle and restrictions; Deploy Device remains unusable example. | Shocked/advanced/fallen-back/shot cases; later movement/shock prevents completion; example never offered. | D09 |

### Section 17

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 17.01 — MOVING MONSTERS AND VEHICLES; p. 62; `P62-01` | 4,11 | [MOVE](../src/rules.rl#L725), [DATA](../src/stats.rl#L4) | missing | Add MONSTER/VEHICLE normal/advance traversal exceptions excluding other MONSTER/VEHICLE models. | Traverse infantry; cannot traverse another MV; no exception leaked into other move types. | D05 |
| 17.02 — FRAME; p. 62; `P62-03` | 4 | [GEO](../src/units.rl#L72), [DATA](../src/stats.rl#L4) | missing | Add FRAME model measurement and footprint exceptions. | Hull vs base distances and under-model placement use printed frame rules. | D05 |
| 17.03 — SHOOTING AT ENGAGED MONSTERS AND VEHICLES; p. 62; `P62-06` | 8,12 | [ATTACK](../src/rules.rl#L145), [DATA](../src/stats.rl#L4) | missing | Implement engaged MV targeting and hit penalties with BLAST prohibition. | Engaged shooter/target penalties apply at stated scope; p.63 examples and p.88 FAQs. | D03 |

### Section 18

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 18.01 — TRANSPORT CAPACITY; p. 64; `P64-01` | 3,16,17 | [STATE](../src/units.rl#L114), [DATA](../src/stats.rl#L4) | missing | Represent transport contents, capacity and datasheet-specific passengers. | Full unit must fit; attached unit counts all models; oversize passenger cost from data. | D09 |
| 18.02 — EMBARKING; p. 64; `P64-04` | 11,16 | [MOVE](../src/rules.rl#L725), [STATE](../src/units.rl#L114) | missing | Implement full-unit embark after permitted moves within 3 inches, excluding setup-turn units. | One passenger outside 3 rejects; advance/fallback permitted as stated; Scouts cannot embark. | D05,D10 |
| 18.03 — DISEMBARKING; p. 64; `P64-10` | 11,16 | [STATE](../src/units.rl#L114), [MOVE](../src/rules.rl#L725) | missing | Determine the required disembark mode in the printed priority order from transport history and passenger eligibility. | Transport setup/move history gates rapid/tactical/combat options; no partial-unit disembark. | D10 |
| 18.04 — DISEMBARK MOVE; p. 65; `P65-01` | 4,11,16 | [MOVE](../src/rules.rl#L725), [GEO](../src/units.rl#L72) | missing | Implement full printed rapid/tactical/combat disembark move sequence and subsequent restrictions. | Setup distance/all-model checks; mode-specific shoot/charge/move permissions. | D05,D10 |
| 18.05 — EMERGENCY DISEMBARK MOVE; p. 65; `P65-12` | 10,16 | [DAMAGE](../src/units.rl#L348), [STATE](../src/units.rl#L114) | missing | Implement emergency disembark, hazard checks and models unable to be placed. | Destroyed transport triggers sequence; failed placement and failed hazard produce stated casualties. | D03,D05,D07 |

### Section 19

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 19.01 — FORMING ATTACHED UNITS; p. 66; `P66-01` | 3,6,17 | [ATTACH](../src/units.rl#L167), [ARMY](../src/rules.rl#L1102) | different | Form attached units at Muster Armies with one Leader and one Support maximum and permitted bodyguards. | Duplicate leader/support rejected; allowed pair preserved with separate provenance. | D09 |
| 19.02 — ATTACKING ATTACHED UNITS; p. 66; `P66-06` | 6,9,10 | [ATTACH](../src/units.rl#L167), [ATTACK](../src/rules.rl#L145) | different | Use bodyguard highest T until gone and preserve attached-unit destruction accounting. | High-T leader does not inflate bodyguard T; last-bodyguard transition and last-model destruction. | D06,D07 |
| 19.03 — KEYWORDS IN ATTACHED UNITS; p. 67; `P67-01` | 6 | [ATTACH](../src/units.rl#L167), [DATA](../src/stats.rl#L4) | partial | Preserve unit keyword union without copying member keywords. | Unit MONSTER/PSYKER predicates differ from all-model predicates. | - |
| 19.04 — ABILITIES IN ATTACHED UNITS; p. 67; `P67-04` | 3,6,10 | [ATTACH](../src/units.rl#L167), [DATA](../src/stats.rl#L4), [DAMAGE](../src/units.rl#L348) | partial | Track ability source, destruction/expiry timing and surviving group provenance. | Reproduce p.67 ability table; source dies during attacks; temporary effects expire correctly. | D07,D10 |

### Section 20

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 20.01 — PLACING UNITS IN STRATEGIC RESERVES; p. 68; `P68-01` | 3,11,17 | [RESERVE](../src/rules.rl#L859), [ARMY](../src/rules.rl#L1102) | partial | Separate undeployed army from strategic reserves; enforce 50-percent points including passengers and excluding fortifications. | At cap accepted, above cap rejected; passenger points included; deployment pool not treated as arrivals. | D09 |
| 20.02 — REPOSITIONED UNITS; p. 68; `P68-04` | 5,11 | [RESERVE](../src/rules.rl#L859), [STATE](../src/units.rl#L114) | missing | Track repositioning separately and retain qualifying effects and arrival-deadline exemption. | Repositioned unit keeps ongoing effects, not expired ones; not destroyed as unused reserve end round 3. | D10 |
| 20.03 — ARRIVING FROM STRATEGIC RESERVES; p. 69; `P69-01` | 5,11 | [RESERVE](../src/rules.rl#L859), [CLOCK](../src/rules.rl#L989) | partial | Allow ingress from round 2 and destroy unused reserves end round 3 with stated exemptions. | Rounds 1/2 boundary, repositioned exemption and transport passenger exception. | D10 |
| 20.04 — INGRESS MOVE; p. 69; `P69-03` | 4,11 | [RESERVE](../src/rules.rl#L859), [GEO](../src/units.rl#L72) | different | Place wholly within 6-inch edge zone, more than 8 horizontally from enemies, no opponent DZ before round 3; restrict later moves. | Every model within edge zone; exactly 8 rejected; round 3 DZ opens; later move lock ends stated time. | D05,D10 |

### Section 21

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 21.01 — SURGE MOVES; p. 70; `P70-01` | 5,11,17 | [MOVE](../src/rules.rl#L725), [DATA](../src/stats.rl#L4) | missing | Connect supplied surge-trigger rules to generic surge procedure. | Only actual supplied trigger enables surge; do not synthesize faction trigger from example. | D04,D09 |
| 21.02 — SURGE MOVE; p. 70; `P70-03` | 4,11 | [MOVE](../src/rules.rl#L725), [GEO](../src/units.rl#L72) | missing | Implement unshocked/unengaged/not-moved eligibility and closest-enemy movement constraints. | Nearest target, per-model as-close-as-possible obligation, no incidental engagement and no second move. | D05 |
| 21.03 — FLYING MODELS; p. 71; `P71-04` | 4,11 | [MOVE](../src/rules.rl#L725), [DATA](../src/stats.rl#L4) | missing | Implement Take to the Skies option, -2 distance, vertical/traversal exceptions and Hover exemption. | Fly route vs ground route; normal/advance/fallback/charge coverage; Hover retains distance. | D05 |

### Section 22

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 22.01 — AURA ABILITIES; p. 72; `P72-01` | 6,17 | [DATA](../src/stats.rl#L4), [CLOCK](../src/rules.rl#L989) | partial | Generalize aura range, keyword filters, effect lifetime and duplicate prevention. | Two identical auras do not stack; entering/leaving range recomputes eligibility. | D03,D09,D10 |
| 22.02 — FACTION ABILITIES; p. 72; `P72-05` | 6,17 | [DATA](../src/stats.rl#L4), [ARMY](../src/rules.rl#L1102) | partial | Replace faction behavior only from supplied text; require matching faction ability applicability. | Attached mixed sources do not gain unsupported faction effect; old data explicitly legacy. | D09 |
| 22.03 — PSYCHIC ABILITIES; p. 72; `P72-08` | 6,12,17 | [DATA](../src/stats.rl#L4), [ATTACK](../src/rules.rl#L145) | partial | Distinguish psychic abilities and attacks for rule triggers. | Psychic ability vs psychic weapon trigger independently; no invented generic psychic phase. | D09 |
| 22.04 — WARGEAR ABILITIES; p. 72; `P72-10` | 6,17 | [DATA](../src/stats.rl#L4), [WEAPON](../src/weapons.rl#L21) | missing | Represent optional wargear abilities with their sourced applicability. | Removing/changing wargear changes only granted ability; revived model retains original gear. | D09 |
| 22.05 — PLUNGING FIRE; p. 73; `P73-01` | 4,8,12 | [GEO](../src/units.rl#L72), [ATTACK](../src/rules.rl#L145) | missing | Improve BS for visible ground-containing targets from >=3-inch surface or TOWERING within 12, with Aircraft exemption. | Exact 3 and 12 boundaries; target all elevated rejects; Aircraft cancels benefit. | D03,D05 |

### Section 23

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 23.01 — DEPLOYMENT; p. 74; `P74-01` | 11,16 | [RESERVE](../src/rules.rl#L859), [DATA](../src/stats.rl#L4) | missing | Force Aircraft into strategic reserves in Declare Battle Formations. | Aircraft cannot deploy normally; mandatory placement distinct from ordinary reserve choice. | D09 |
| 23.02 — MOVEMENT; p. 74; `P74-03` | 4,5,11,16 | [MOVE](../src/rules.rl#L725), [RESERVE](../src/rules.rl#L859), [GEO](../src/units.rl#L72) | missing | Aircraft ingress-only movement and opponent-turn exit; traversal, closest-target and engagement exceptions. | No normal move; exit exactly opponent end turn; non-Fly pile-in ignores Aircraft. | D05,D10 |
| 23.03 — SHOOTING; p. 74; `P74-05` | 8,12,16 | [ATTACK](../src/rules.rl#L145) | missing | Suppress Plunging Fire for attacks made by or targeting Aircraft. | Both attacker and target Aircraft cases remove only Plunging Fire benefit. | - |
| 23.04 — CHARGING AND FIGHTING; p. 74; `P74-07` | 13,14,16 | [CHARGE](../src/rules.rl#L791), [FIGHT](../src/rules.rl#L744) | missing | Prohibit Aircraft charging; restrict charge/melee targeting by FLYING units/models. | Non-Fly cannot charge or attack Aircraft; mixed unit checks model-specific melee permission. | D05 |

### Section 24

| Source ID / heading / page / locator | Tasks | Existing code | Status | Required change | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- |
| 24.01 — ABILITIES; p. 78; `P78-01` | 3,6,12 | [DATA](../src/stats.rl#L4), [WEAPON](../src/weapons.rl#L21) | partial | Represent parameterized core/weapon abilities and their scope without capacity truncation. | New abilities enumerate/serialize; model and weapon scopes remain separate. | D09 |
| 24.02 — DUPLICATED ABILITIES; p. 78; `P78-07` | 6,12 | [DATA](../src/stats.rl#L4), [WEAPON](../src/weapons.rl#L21) | partial | Offer controller choice of non-cumulative duplicate instances at the printed time, including differing numbers/keywords; flag Scouts edge cases. | Reproduce p.78 duplicate examples; unillustrated overlapping Scouts flagged. | D02 |
| 24.03 — [ANTI]; p. 79; `P79-01` | 9,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | partial | Generalize ANTI keyword matching and threshold critical wounds rather than three hardcoded variants. | Mixed-keyword target qualifies; threshold critical interacts correctly with Devastating Wounds. | - |
| 24.04 — [ASSAULT]; p. 79; `P79-04` | 12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | partial | Connect ASSAULT to assault-shooting mode with exact weapon eligibility. | Advanced unit's assault weapon usable, non-assault weapon unusable. | - |
| 24.05 — [BLAST]; p. 79; `P79-06` | 9,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | partial | Snapshot target model count for BLAST and BLAST X at target selection; prohibit engaged targets. | BLAST 2 vs 12 models adds 4; declared count survives casualties; p.88 exclusions. | D11 |
| 24.06 — [CLEAVE]; p. 79; `P79-10` | 9,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | missing | Implement CLEAVE X: one selected target for all weapon attacks, X additional dice per five declared target models. | CLEAVE 1 vs 16 adds 3; split weapon targets gives no bonus; casualties do not alter declared count. | D05,D11 |
| 24.07 — [CLOSE‑QUARTERS]; p. 80; `P80-01` | 12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | different | Add CLOSE-QUARTERS and map PISTOL alias without treating it as a one-weapon early return. | Multiple permitted close-quarters weapons and legal engaged target choice. | - |
| 24.08 — DEADLY DEMISE; p. 80; `P80-05` | 5,10 | [DAMAGE](../src/units.rl#L348), [DICE](../src/rules.rl#L50) | missing | Implement Deadly Demise after emergency disembark, on 6, within 6 inches, rolling random X separately per unit; honor attack destruction delay. | Passenger exit precedes demise roll; distinct random X per unit; qualifying attack-caused trigger delayed. | D03,D07 |
| 24.09 — DEEP STRIKE; p. 80; `P80-08` | 4,11 | [RESERVE](../src/rules.rl#L859), [GEO](../src/units.rl#L72) | partial | Implement Deep Strike alternative placement when making ingress, requiring every model to have the ability and more-than-8 horizontal distance. | Exactly 8 rejected, just beyond accepted; every model placement coherent and legal. | D05,D10 |
| 24.10 — [DEVASTATING WOUNDS]; p. 80; `P80-10` | 9,10,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | partial | Critical Devastating Wounds inflicts D mortal wounds after normal damage, limited to one model per critical wound. | Ordinary wound saves; ANTI critical qualifies; D3 vs W2 loses final mortal wound after destroying one model. | D03,D06 |
| 24.11 — [EXTRA ATTACKS]; p. 81; `P81-01` | 9,12,14 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | partial | Mandatorily declare all EXTRA ATTACKS weapons and one other melee weapon if possible. | All extra profiles declared; ordinary profile required if available; no invented modifier restriction. | D03 |
| 24.12 — FEEL NO PAIN; p. 81; `P81-04` | 10 | [DATA](../src/stats.rl#L4), [DAMAGE](../src/units.rl#L348) | missing | Activate Feel No Pain per would-be wound lost; current profiles declare values without damage handling. | Each normal/mortal wound offers proper roll; successful result prevents only that wound. | D03 |
| 24.13 — FIGHTS FIRST; p. 81; `P81-06` | 13,14 | [DATA](../src/stats.rl#L4), [FIGHT](../src/rules.rl#L744) | partial | Require ability at correct unit scope and grant successful-charge FF; obey new fight sequence. | Mixed unit without every-model FF does not qualify through any-member check; successful charge does. | D08 |
| 24.14 — FIRING DECK; p. 81; `P81-09` | 9,12,16 | [WEAPON](../src/weapons.rl#L21), [STATE](../src/units.rl#L114) | missing | Select up to X eligible passenger models, one non-ONE-SHOT ranged weapon each; grant weapons to transport for its attacks and bar passenger shooting until turn end. | Deck limit; already-shot passengers and ONE SHOT excluded; passenger shoot prohibition and temporary weapon expiry. | D09,D10 |
| 24.15 — [HAZARDOUS]; p. 81; `P81-12` | 10,12 | [WEAPON](../src/weapons.rl#L21), [DICE](../src/rules.rl#L50), [DAMAGE](../src/units.rl#L348) | different | After all unit attacks, roll simultaneous hazards equal to HAZARDOUS weapons selected in Select Weapons, then apply new mortal effects. | One model selecting two hazardous weapons gets two checks; 1–2 fails; all-MV damage; snapshot selected count. | D03 |
| 24.16 — [HEAVY]; p. 82; `P82-01` | 5,11,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145), [STATE](../src/units.rl#L114) | different | Use HEAVY's unengaged, not-setup-turn, no-model-moved-over-3 conditions rather than old has_moved flag. | Exactly 3 movement allowed; one model >3 disables; setup and engagement disable. | D03 |
| 24.17 — HOVER; p. 82; `P82-05` | 11,16 | [MOVE](../src/rules.rl#L725), [DATA](../src/stats.rl#L4) | missing | Add Hover's explicit Take to the Skies distance exception. | Fly Hover option avoids -2 while equivalent non-Hover pays it. | - |
| 24.18 — [IGNORES COVER]; p. 82; `P82-07` | 8,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | missing | Apply IGNORES COVER to cover benefit in targeting/hit pipeline; current enum alone is insufficient. | Cover BS penalty absent while unrelated modifiers remain. | D03 |
| 24.19 — [INDIRECT FIRE]; p. 82; `P82-09` | 8,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | missing | Connect INDIRECT FIRE ability to indirect-shooting mode and restrictions. | Ability-less weapon cannot select mode; permitted profile respects thresholds and reroll ban. | - |
| 24.20 — INFILTRATORS; p. 82; `P82-11` | 4,11 | [DEPLOY](../src/rules.rl#L1031), [GEO](../src/units.rl#L72) | partial | Use printed Infiltrators setup distance/zone rules for every model rather than anchor and legacy 9 inches. | Enemy distance and opponent-zone boundaries; all models checked; no legacy zone expansion assumed. | D05,D09 |
| 24.21 — [LANCE]; p. 82; `P82-13` | 9,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | partial | Apply LANCE to wound rolls only after successful charge and at printed scope. | Failed charger gets no bonus; source success history preserved; modifier policy gated. | D03 |
| 24.22 — LEADER; p. 82; `P82-15` | 6,17 | [DATA](../src/stats.rl#L4), [ATTACH](../src/units.rl#L167) | partial | Connect LEADER to valid Muster Armies attachments and provided bodyguard permissions. | Leader with forbidden bodyguard rejected despite CHARACTER keyword. | D09 |
| 24.23 — [LETHAL HITS]; p. 82; `P82-17` | 9,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | different | Offer LETHAL HITS only for critical hits; auto-wound is not critical wound; preserve choice. | Ordinary hit still rolls wound; critical may decline auto-wound; no automatic Devastating Wounds. | - |
| 24.24 — LONE OPERATIVE; p. 83; `P83-01` | 8,12 | [DATA](../src/stats.rl#L4), [ATTACK](../src/rules.rl#L145) | partial | Enforce Lone Operative with correct attacker-to-target distance and all-model scope. | At permitted boundary vs beyond; self-distance bug cannot permit remote targeting. | D05 |
| 24.25 — [MELTA]; p. 83; `P83-04` | 9,10,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | partial | Snapshot MELTA half-range at target selection and apply printed damage increment. | Different weapon ranges; exact half-range; no fixed 12-inch substitute; snapshot survives casualties. | D03,D11 |
| 24.26 — [ONE SHOT]; p. 83; `P83-07` | 3,9,12 | [WEAPON](../src/weapons.rl#L21), [STATE](../src/units.rl#L114) | missing | Persist ONE SHOT weapon use across phases, moves and revival. | Second use rejected; revived model does not regain expended one-shot weapon. | D10 |
| 24.27 — [PISTOL]; p. 83; `P83-11` | 12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | partial | Treat PISTOL as CLOSE-QUARTERS synonym under new shooting modes. | Equivalent profiles yield same legal choices; no old one-pistol-only early return. | - |
| 24.28 — [PRECISION]; p. 84; `P84-01` | 9,10,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145), [GEO](../src/units.rl#L72) | different | Limit PRECISION attacker choice to visible CHARACTER save groups and maintain current group until resolved/destroyed. | Non-character/hidden-character choice rejected; multiple characters remain separate groups. | D05,D06 |
| 24.29 — [PSYCHIC]; p. 84; `P84-03` | 9,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | missing | Offer PSYCHIC's optional ignoring of any/all BS/WS and hit modifiers; retain psychic attack tag. | Ignore selected penalties or bonuses without affecting wound/save modifiers. | D03 |
| 24.30 — [RAPID FIRE]; p. 84; `P84-05` | 9,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | partial | Snapshot RAPID FIRE half-range at Select Targets rather than resolution. | Exactly half-range grants X; target changes after declaration do not change attack count. | D11 |
| 24.31 — SCOUTS; p. 84; `P84-08` | 6,11,16 | [DEPLOY](../src/rules.rl#L1031), [RESERVE](../src/rules.rl#L859), [DATA](../src/stats.rl#L4) | missing | Add all-model Scouts pre-battle reserve/deployment/dedicated-transport alternatives. | Shared 6/8 examples; passenger eligibility; reserve setup wholly own DZ. | D02,D09 |
| 24.32 — SCOUT MOVE; p. 84; `P84-11` | 4,11 | [MOVE](../src/rules.rl#L725), [DEPLOY](../src/rules.rl#L1031) | missing | Implement Scout Move in pre-battle step, distance X and final >8 horizontally from enemies. | Exactly 8 rejected; phase restriction; p.88 no embark after scout. | D05,D09 |
| 24.33 — STEALTH; p. 85; `P85-01` | 8,12 | [DATA](../src/stats.rl#L4), [ATTACK](../src/rules.rl#L145) | different | Replace Stealth hit penalty with cover when every model has ability. | One missing Stealth removes benefit; cover changes BS and IGNORES COVER negates it. | D03 |
| 24.34 — SUPPORT; p. 85; `P85-03` | 6,17 | [DATA](../src/stats.rl#L4), [ATTACH](../src/units.rl#L167) | missing | Add Support attachment slot, permissions and provenance. | One leader plus one support allowed when data permits; second support rejected. | D09 |
| 24.35 — SUPER-HEAVY WALKER; p. 85; `P85-05` | 4,7,11 | [MOVE](../src/rules.rl#L725), [DATA](../src/stats.rl#L4) | missing | Implement Super-heavy Walker traversal, 4-inch terrain threshold and optional temporary MOBILE with shock roll. | TITANIC blocks traversal; 4-inch boundary; MOBILE expires after move; 1 shocks. | D03,D05 |
| 24.36 — [SUSTAINED HITS]; p. 85; `P85-09` | 9,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | partial | Generate X additional ordinary hits per critical hit; preserve critical origin separately. | Sustained 2 gives 3 hits; added hits do not inherit critical-only effects. | D03 |
| 24.37 — [TORRENT]; p. 85; `P85-12` | 9,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | partial | Use TORRENT ability for automatic hits rather than skill-zero inference. | No hit dice for Torrent; automatic hit is not invented critical hit. | D03 |
| 24.38 — [TWIN‑LINKED]; p. 85; `P85-14` | 9,12 | [WEAPON](../src/weapons.rl#L21), [ATTACK](../src/rules.rl#L145) | missing | Add TWIN-LINKED optional wound reroll in correct player decision window. | Wound reroll available without CP; prohibited reroll context still honored; one reroll chain. | D03 |

## Supplemental definitions, examples and FAQs

| Entry / source pages | Tasks | Code | Status | Material | Required treatment | Planned regression | Gates |
| --- | --- | --- | --- | --- | --- | --- | --- |
| U01; pp. 4–5 | 17 | [ARMY](../src/rules.rl#L1102), [DATA](../src/stats.rl#L4) | external | Battle preparation and mustering publications | Source complete army/mission inputs; distinguish overview from executable rules. | Configured mission supplies armies, zones, duration and scoring; no invented defaults. | D09 |
| U02; pp. 11 | 17 | [DATA](../src/stats.rl#L4), [WEAPON](../src/weapons.rl#L21) | illustration | Boyz sample datasheet | Keep as parsing/schema fixture, not a complete playable army or definition of Waaagh!. | Sample characteristics/weapon/keyword table preserved; unknown faction ability remains unresolved. | D09 |
| U03; pp. 13,15 | 4,11 | [GEO](../src/units.rl#L72), [MOVE](../src/rules.rl#L725) | illustration | Movement, coherency and engagement figures | Reproduce labelled figure outcomes after geometry migration. | Paths, multi-model coherency and horizontal/vertical engagement examples agree with captions. | D05 |
| U04; pp. 18 | 9 | [ATTACK](../src/rules.rl#L145) | illustration | Strength/Toughness table | Implement exact inclusive thresholds, including equality at twice/half. | All five table rows plus S=2T and 2S=T boundary cases. | D03 |
| U05; pp. 20–23 | 9,10 | [ATTACK](../src/rules.rl#L145), [DAMAGE](../src/units.rl#L348) | illustration | Both worked attack examples and graphical dice | Turn declared weapons, hit/wound batches and sorted saves into deterministic fixtures. | Reproduce pp.20–21 outcomes and pp.22–23 attached-group transitions from transcribed dice. | D03,D06 |
| U06; pp. 28–29,31 | 5,7,17 | [CLOCK](../src/rules.rl#L989), [MORALE](../src/rules.rl#L580) | context | Turn diagram and timing sidebars | Account for captions alongside numbered windows; source mission/faction timing separately. | Full trace matches specified phase order and controller changes. | D04,D09,D10 |
| U07; pp. 39,41,43 | 13,14 | [FIGHT](../src/rules.rl#L744), [CHARGE](../src/rules.rl#L791) | illustration | Pile-in, fight and consolidation examples | Preserve eligibility and phase-wide sequence demonstrated by diagrams. | Labelled example outcomes, overrun distinctions and newly engaged consolidation fights. | D05,D08 |
| U08; pp. 47,49,51 | 4,8 | [GEO](../src/units.rl#L72) | illustration | Terrain placement, movement and visibility figures | Test terrain areas separately from features; reproduce traversal/hiding/LOS captions. | Each p.49 model traversal example and p.51 hidden/detection/cover example. | D05 |
| U09; pp. 53 | 8 | [OBJECTIVE](../src/board.rl#L224) | illustration | Objective control diagrams | Reproduce control totals and secured outcomes without mission scoring assumptions. | All labelled control outcomes; tie and secured exceptions. | D09 |
| U10; pp. 55 | 5,15 | [STRAT](../src/board.rl#L153) | context | Stratagem graphical timing/cost key | Optional extra cost and timing semantics belong to canonical upright stratagem text. | Base and additional cost affordability; no duplicate illustrative stratagem definition. | D04 |
| U11; pp. 58 | 15,17 | [STATE](../src/units.rl#L114) | illustration | Deploy Device example action | Explicitly cannot be used; retain as structure illustration only. | No Deploy Device legal action in generated enumeration. | D09 |
| U12; pp. 63 | 12 | [ATTACK](../src/rules.rl#L145) | illustration | Engaged Monster/Vehicle shooting figures | Reproduce model-specific penalties and permitted targeting. | Every labelled p.63 engaged-shooting outcome; cross-check BLAST FAQ. | D03 |
| U13; pp. 67 | 6,10 | [ATTACH](../src/units.rl#L167), [DAMAGE](../src/units.rl#L348) | illustration | Attached-unit ability table | Preserve model/unit source distinction and post-destruction retention. | Each table row before and after losing bodyguard/leader source. | D07,D10 |
| U14; pp. 70 | 11 | [MOVE](../src/rules.rl#L725) | illustration | Surge example | Example trigger is illustrative; procedure moves toward closest enemy C, not shooter A. | Given trigger and D6=4, closest-unit choice and final engagement match caption. | D05,D09 |
| U15; pp. 73 | 8,12 | [ATTACK](../src/rules.rl#L145), [GEO](../src/units.rl#L72) | illustration | Plunging Fire figures | Apply BS improvement to both height-based and Towering ground-level examples. | Both p.73 examples; Aircraft exemptions. | D03,D05 |
| U16; pp. 78–85 | 6,9,10,11,12,16 | [DATA](../src/stats.rl#L4), [WEAPON](../src/weapons.rl#L21) | illustration | Core ability examples/designer notes | Examples supplement each individually mapped ability, including duplicate Scouts and Sustained Hits. | Printed numeric examples; Super-heavy MOBILE terrain effect; unresolved Scouts combinations flagged. | D02,D03 |
| U17; pp. 86 | 3,6,7 | [STATE](../src/units.rl#L114), [MORALE](../src/rules.rl#L580), [ATTACH](../src/units.rl#L167) | different | Starting strength and half-strength table | Capture at first-round start after attachments; surviving leader keeps combined starting strength; odd exact halves impossible. | Captain+5 starting 6: 3 at half, 2 below, lone full-wound Captain still below; singleton wound cases. | D09 |
| U18; pp. 87 | 3,6 | [STATE](../src/units.rl#L114) | partial | Adding a new unit | Capture starting strength when added, preserving ownership and stable identity. | New unit strength set on addition, unaffected by subsequent casualties; no positional-ID retargeting. | D09 |
| U19; pp. 87 | 3,5,10 | [DAMAGE](../src/units.rl#L348) | different | Destroyed | Resolve triggers before removal; attack-caused delay applies only if qualifying triggered rules exist; destroyed entities cannot act. | Immediate removal without trigger vs delayed removal with trigger; neither selects attacks/abilities illegally. | D07 |
| U20; pp. 87 | 4,11 | [MOVE](../src/rules.rl#L725) | different | Different move characteristics | Use per-model M for normal/advance rather than first-model formation budget. | M6/M9 members move 6/9 normally and 6+D6/9+D6 advancing. | D05 |
| U21; pp. 87 | 14 | [FIGHT](../src/rules.rl#L744) | different | Eligible to fight but unable to fight | Gate passing on all eligible units >5 inches and prescribed consecutive-pass termination. | Pass rejected with eligible unit within 5; accepted beyond 5; both-pass and opponent-none endings. | D05,D08 |
| U22; pp. 87 | 6,9,12 | [ATTACH](../src/units.rl#L167), [DATA](../src/stats.rl#L4) | partial | Mixed keywords | Unit union is distinct from individual model keywords for all rules, not just attachments. | Unit ANTI eligibility vs model traversal/character eligibility; loss of last keyword-bearing member. | - |
| U23; pp. 88 | 4,8 | [OBJECTIVE](../src/board.rl#L224), [GEO](../src/units.rl#L72) | different | Objectives not within a terrain area | Use flat 40mm marker, 3 horizontal/5 vertical range from closest marker part; permit movement over marker. | Exact 3/5 boundary including radius; marker not a movement obstacle. | D05 |
| U24; pp. 88 | 3,6,10,11 | [STATE](../src/units.rl#L114), [ATTACH](../src/units.rl#L167), [DAMAGE](../src/units.rl#L348) | missing | Revived | Restore original gear/enhancements/full wounds up to starting strength; attached provenance, placement and one-shot history persist. | Over-strength rejects; restored Leader/Support remains attached; no new enemy engagement; ambiguous phase-start anchor cases deferred. | D01,D10 |
| U25; pp. 88 | 12,15 | [ATTACK](../src/rules.rl#L145) | different | FAQ: no ranged weapons | Shooting eligibility is independent of whether ranged attacks can be made. | Unarmed eligible unit may start otherwise-legal supplied action. | D09 |
| U26; pp. 88 | 12 | [ATTACK](../src/rules.rl#L145), [WEAPON](../src/weapons.rl#L21) | missing | FAQ: close-quarters MV BLAST | BLAST cannot target engaged unit in close-quarters shooting. | Engaged MV shooter with BLAST cannot select engaged target. | - |
| U27; pp. 88 | 12 | [ATTACK](../src/rules.rl#L145), [WEAPON](../src/weapons.rl#L21) | missing | FAQ: engaged MV target BLAST | BLAST cannot target engaged MV even from unengaged shooter. | Unengaged BLAST shooter cannot target engaged MV. | - |
| U28; pp. 88 | 14 | [FIGHT](../src/rules.rl#L744) | missing | FAQ: overrun eligibility | Overrun option does not override general fight eligibility. | Became engaged after step start then disengaged: overrun unavailable. | D08 |
| U29; pp. 88 | 11,16 | [MOVE](../src/rules.rl#L725) | missing | FAQ: embark after scout | No embark after Scout Move; observe specified pre-battle step ordering. | Scout movement cannot offer embark action. | D09 |
| U30; pp. 9–88 | 1,4,5,9,10,11,17 | [DATA](../src/stats.rl#L4) | external | SEE ALSO and app cross-reference panels | Cross-references are dependencies, not reproduced general rules; retain inventory of each named external entry. | No old modifier cap, timing, healing, offboard or CP restriction silently becomes new-edition specification. | D03,D04,D05,D09,D10,D11,D12 |
| U31; pp. 25 | 4,8,9 | [GEO](../src/units.rl#L72), [ATTACK](../src/rules.rl#L145) | missing | Visible / fully visible model and unit definitions | Represent any-part model visibility and facing-part full visibility; for unit full visibility see through other members of that unit. | One visible member gives unit visibility; all facing parts of every model needed for full visibility; self-occlusion does not remove full visibility. | D05 |

## Source uncertainties and external-definition gates

These correspond to Part III I-01–I-12 of the reference. Preserve the exact printed rule while unresolved. Obtain missing definitions or an explicit interpretation before implementing behavior that depends on them; source gaps do not block independent printed mechanics.

| Gate | Source / problem | Affected work / required input |
| --- | --- | --- |
| D01 | p.88 Revived: “started that phase” vs “already on the battlefield when that rule was used” can select different anchors. | Tasks 3/6/10/11: clarification or explicit interpretation for arrival/repeated-revival edge cases. |
| D02 | p.78 duplicate Scouts overlapping-value wording; illustrated shared/mixed examples are clear. | Tasks 6/11: preserve examples; clarify unillustrated overlapping collections rather than inventing algorithm. |
| D03 | User supplied Modifiers 02.02.01, Random Characteristics 02.02.03 and Re-rolls 01.05.02 during task 9; see supplied-appendix report. | Definitions are available. Task 9 implements generic arithmetic/limits and attack dice; tasks 10/11/12/15 must integrate remaining consumers and dice expressions with supplied data. |
| D04 | Player’s Rules / Rules Sequencing cross-references (pp.8–9,54–55,70,86). The user supplied sequencing: current player chooses their effect order, then opponent chooses theirs. | Task 5 implements that supplied priority; it is not a quotation from the PDF. Other app-only Player’s Rules details remain unavailable. Explicit printed sequences remain authoritative. |
| D05 | User supplied Within/Wholly Within and Closest Model/Unit definitions; Table Quarter and Setting Up Large Models remain missing (pp.9,12–15,37–38,42,62,65,69–70,88). | See the geometry report. Preserve the user-required quad grid; document unsupported footprints/visibility and obtain remaining definitions before claiming exact tabletop fidelity. |
| D06 | New ordered save groups and same-result InSv/Sv checks (pp.19–23,84). | Tasks 9/10/12: printed procedure is available and must replace old allocation; unresolved random-damage details also D03. This is an architectural constraint, not wholly missing source. |
| D07 | Qualified destruction delay and source-ability retention (pp.66–67,80,87). | Tasks 3/6/10/16: distinguish immediate/delayed removal; identify separate unsettled pending-model interactions instead of universally keeping models alive. |
| D08 | General fight eligibility distinct from overrun availability; new FF switching and phase-wide movement (pp.38–43,87–88). | Task 14: source procedure is available; do not port old per-activation movement or unrestricted passing. |
| D09 | Mustering/points, complete datasheets, Leader/Support permissions, missions/scoring/duration, faction abilities and playable actions absent (pp.4–5,11,28–30,46,52,58,64,66,72). | Tasks 6/8/11/15/16/17: request respective publications/data when needed. Existing six faction factories and fixed mission are legacy fixtures, not new-edition authority. Boyz/Waaagh! and unusable Deploy Device do not supply missing definitions. |
| D10 | User supplied Not on the Battlefield01.02.04 and Persisting Rules Effects01.02.02 during task16. The readable appendix now supplies Healing or Regaining Lost Wounds02.02.04 and Revived and Adding Models01.02.03 in the Orks audit. | Task16 integrates supplied offboard/persistence policy. Healing/revival implementations and supplied faction consumers remain tasks6/17; see orks-codebase-audit.md. |
| D11 | User supplied Target No Longer Eligible or Viable 04.03.03; Multiple Weapon Profiles subsequently supplied as 04.01.03 (pp.17,37,79,83–84). | Task 9 permits unresolved-share replacement. Task 12 implements per-model physical profile grouping and Hunter predicates; tasks 13/17 retain other targeting/data obligations. |
| D12 | No reproduced general additional-CP cap or general damage-modification policy (pp.19,30,86). | Tasks 3/5/10: absence proves neither permission nor prohibition; do not silently retain existing extra-CP limit or arbitrary storage cap. |

## Existing defects and infrastructure risks

These are observed source-level defects or risks, not failures reproduced by a test in task 1. Task 2 establishes regression evidence and separates them from edition changes.

| Finding | Evidence | Owner / planned check |
| --- | --- | --- |
| Fixed characteristic evaluation checks Int although raw_stat produces a bounded integer; fixed A evaluates to zero. | `evaluate_random_stat`; `raw_stat`; task-2 `test_02_04_fixed_attack_characteristic` | Task 9: reproduce fixed attacks and damage, then verify actual combat resolution. Current shooting smoke completion does not prove attacks occurred. |
| Stratagem gate uses Heroic Intervention cost for every stratagem and checks the other player’s usage. | `Board.can_use_strat` | Tasks 2/5/15: one-CP affordability and independent player usage. |
| OC is overwritten instead of summed; nonzero ties select player 1. | `Board.get_objective_controller` | Tasks 2/8: OC2+OC2 vs OC3; equal totals. |
| Leadership selects maximum threshold; strict double/half wound comparisons miss equality. | `Unit.get_leadership`; `required_wound_roll` | Tasks 2/7/9: mixed Leadership and exact S/T boundaries. |
| Lone Operative compares source distance to itself in targeting gates. | `shooting_phase`; `overwatch` | Tasks 2/12/15: distant target remains unavailable. |
| Lethal Hits applies on any hit; Heavy checks has_moved; only_hits_on_6 configured but not enforced in single_attack. | `single_attack`; `get_hit_roll_bonus`; `_configure_attack` | Tasks 2/9/12/15: critical-only Lethal, Heavy eligibility, Snap Shooting dice. |
| Advance extra distance uses half-open 0..4 modifier storage; CP uses half-open 0..4; damage/result capacities also small. | `StatModifier`; `MAX_CP`; `Wounds`; `RandomStatResult` | Tasks 2/3/11: preserve 4–6 Advance and larger valid totals; capacity audit. |
| Positional IDs shift on erase; attached provenance is erased; formation placement may clamp members individually. | `remove_empty_units`; `attach_to`; `arrange`; `translate` | Tasks 3/4/6: stored target survives unrelated erase; placement does not distort/clamp silently. |
| reroll_pair missing from chance classification. | `default_get_current_player` | Tasks 2/5: every dice boundary reports player -1. |
| Fixed scoring/objectives and five-round loop are not core mission authority; pinned objective indexing/scoring requires audit. | `Board.score/score_objective`; `battle` | Tasks 2/8/17: asymmetric owner/marker scenarios; source-configured mission. |
| Non-CP mechanics can also fail: melee selection combines range-zero with distance check; iteration and fight-on-death removal need regression. | `resolve_model_attack`; `resolve_weapon`; `remove_figth_on_death_models` | Tasks 2/9/10/14: legal engaged melee attacks, each model attacks once, dead index-0 model removed. |
| Overwatch gating returns when can_use_strat is true and marks use before decline. | `overwatch` | Tasks 2/15: eligible use offered and decline changes neither CP nor usage. |
| No dedicated test suite; Clang/sanitizer toolchain missing at roadmap creation. | Existing examples, `CMakeLists.txt`, AGENTS.md validation notes | Task 2: real RUN/OK counts; build sanitized fuzzer, seed inputs longer than 8 bytes. |
| Finite action enumeration cost grows with domains; schema/action changes invalidate bindings, replays and learned observations. | `enumerate`; `@classes play`; observation writers; Godot selectors | Tasks 3/17 and every action-changing task: enumeration performance, schema versioning and explicit UI selection coverage. |
| Dedicated Bool question detector contradicts its member-count check; first matching action shape can be ambiguous. | `scripts/Rules.gd`; selectors in Godot scripts | Task 17 and affected action tasks: actual widgets tested, not only all-actions fallback. |

## Task 1 completion evidence and handoff

- Read the roadmap, source reference and Rulebook state/action/helper paths named above, plus Godot action enumeration. No implementation or test behavior changed.
- Verified every defining ID in the reference index has exactly one numbered row and a defining locator on its stated page.
- Verified every retained Part II locator is unique and has a ledger owner; all supplemental entry IDs are referenced. Internal source-page ownership accounts for supporting blocks without claiming independent semantics for figure labels or prose.
- Extracted all app/supporting cross-reference text into [the external-reference inventory](11th-edition-external-references.tsv); treat references to supplied numbered rules separately from absent app entries.
- Future deterministic test names should include the rule ID (for example `test_05_03_wounded_group_priority`); keep citation and fixture outcome with the test. These are plans, not existing tests.
- Next task is roadmap task 2. Do not mark semantic coverage complete until actual tests and bindings validate each rule; use the ledger to prevent omission while tasks are implemented.

## Task 5 implementation overlay

See [the timing report](timing-foundations.md) for implemented windows, active/decision roles, phase/unit stratagem limits, coherency cleanup and executed evidence. The original inspection rows above remain historical; phase bodies and core stratagem effects still require their later owning tasks. D04 sequencing was supplied by the user, while general Player’s Rules remains unavailable.

## Task 8 implementation overlay

See [the terrain/objective report](terrain-objectives.md) and ROADMAP.md for **144 PASS, 3 XFAIL, 0 XPASS**, Godot and sanitizer evidence. Original inspection rows remain historical. The user explicitly replaces physical visibility/feature rules with area-only partial obscuration; this does not establish exact printed LOS coverage.

| Source rows | Current result / remaining owner |
| --- | --- |
| 08.05 | End-phase control recalculation and separate explicitly selected mission scoring implemented/tested. Actual mission data remains task 17. |
| 13.01–13.05 | Bounded area configuration/category flags implemented; mixed-category areas retained. Feature placement and individual feature rules deferred by the user; actual layout data/configuration UI remains task 17. |
| 13.06, U08 movement examples | Physical feature traversal, upper surfaces and Solid openings deferred by user instruction. Task-4 primitives retained; independent movement decisions remain task 11. |
| 13.07–13.08, U08 cover examples | Per-model/all-target-model cover, BS change and user-approved centre-segment area obscuration implemented/tested. No save bonus or hit modifier substituted. |
| 13.09, U08 Hidden examples | Individual keyword/Dense membership, current/previous actual-attack history, never-fired case and inclusive detection/visibility gates implemented/tested. |
| 13.10–13.11, U31 physical visibility | Exact Obscuring/Solid/silhouette geometry deferred by the user. Physical visibility assumed; Hidden still restricts detection. Unit any-visible-member quantifier implemented. |
| 14.01–14.03, U09, U23 | Area/marker range, both-army OC sum, ties, boundary snapshots, secured absence/ties/phase-end loss and unit eligibility implemented/tested. Two former discrepancy assertions promoted. |
| U15 / Plunging Fire | Weapon ability remains task 12; physical upper surfaces deferred with features. |

The Ignores Cover consumer now checks parameterless ability presence. Other legacy parameter-based consumers still require task-12 correction. The three manifest failures all belong to task 9; fixed characteristics remain a mandatory fix, so full-game completion does not certify attacks. Physical feature deferral is an explicit scope adjustment, not a missing-source resolution or a claim of full rules fidelity.

## Task 10 implementation overlay

Read [the saves/damage/destruction report](saves-damage-destruction.md) and ROADMAP.md for **202 PASS, 0 XFAIL, 0 XPASS**, **204 passing CTest entries**, schema 9/5/9, Godot, gameplay and sanitizer evidence. Original inspection rows remain historical. Core allocation/damage is implemented; real attachments and new faction data remain deferred/source-gated.

| Source rows | Current result / remaining owner |
| --- | --- |
| 05.03–05.04, pp.20–23 worked examples | Live stable-identity W/Sv/InSv groups, separate characters, mandatory wounded/character tiers, pre-roll group order, ascending save faces, one die against InSv/AP-adjusted Sv, per-attack allocation and no excess normal spill implemented/tested. Mixed-model examples do not certify unavailable attachment grants/datasheets. |
| 06.02 | Ordinary-before-mortal damage, explicit mortal recipient priorities, individual prevention and ordinary spill implemented/tested. |
| 06.03 | All selected hazardous weapons counted; simultaneous original rolls, 1–2 failures, per-live-model MONSTER/VEHICLE test, one/three mortal wounds and paid reroll ownership implemented/tested. |
| 24.08 | Deadly Demise on 6, retained physical casualty, inclusive 6-inch base distance, per-unit random X and attack-trigger deferral implemented/tested. Emergency disembarkation/passengers remain task 16. |
| 24.10 / 24.12 | Critical Devastating damage after normal damage, no saves, one destroyed recipient per critical attack, excess discarded; Feel No Pain per would-be wound implemented/tested. Broader weapon-mode combinations remain task 12. |
| 24.25 / 24.28 | MELTA half-range declaration snapshot and per-attack increment; PRECISION visible CHARACTER group override and fallback implemented/tested. Full shooting modes and unsupplied profile/datasheet cases remain tasks 12/17. |
| U19 / destroyed models (p.87) | Immediate removal without triggers, conditional attack-caused delay, immediate non-attack trigger sequencing, pending-model ineligibility, stable provenance, save validation and exactly-once archival implemented/tested. Full Fight on Death attacks remain task 14; attachment ability retention remains task 6. |
| 15.03 / 15.05–15.06 | Core Precision and mortal engine available, but Epic Challenge, Explosives and Crushing Impact effects/timing remain task 15. |

Printed destruction/allocation foundations now have tests; D06/D07 are not blanket closures of attached/faction/transport dependencies. Generic modifier helpers require integration in later consumers. Legacy faction destruction hooks are preserved without inventing new-edition faction authority. The complete migration must still close every confirmed downstream defect assigned in ROADMAP.md.

## Task 11 movement/deployment overlay

Read [movement/deployment](movement-deployment.md) for implementation and configured limits. This overlay supersedes the original inventory only for the supported mechanics below.

| Source rows | Current result / remaining owner |
| --- | --- |
| 09.01–09.07; pp.32–33 | Explicit movement selection, stationary, Normal/Advance, per-model budgets and resumable paths, Ordered Retreat and Desperate Escape through shared damage/destruction engine. |
| 20.01–20.04; pp.68–69 | Explicit points-gated reserve selection, every-base ingress constraints, round restrictions, locks, repositioning and never-arrived expiry. Aircraft/passengers remain task 16. |
| 21.01–21.03; pp.70–71 | Explicitly granted surge, eligible closest targets, finite-grid reachable endpoints and per-model approach checks with other chosen positions fixed. Faction triggers/data remain task 17. |
| 24.09 / 24.17 / 24.20; pp.80–82 | All-model Deep Strike and Infiltrators setup checks, individual FLY traversal and non-Hover budget adjustment. Full charge/fight flight belongs to tasks 13/14. |
| 24.31–24.32; pp.84 | Pre-battle Scouts movement/setup; user requires uniform duplicate values, asserted for dynamic data. Transport alternatives remain task 16. |
| 24.35; p.85 | Super-heavy Walker traversal, optional temporary Mobile and end-move shock. Terrain-feature categories/heights remain deferred. |
| U19 / U20; p.87 | Pending corpses excluded from live engagement/coherency; each model uses its own M. |

Every-base deployment checks replace anchor-only checks. Whole-grid presets do not enumerate every possible formation; user-directed destruction archives units with no supported placement, rather than restarting deployment. Missing mission/points/datasheet geometry, attachments, revival anchors and terrain-feature definitions remain explicit dependencies, not closed source gates.

## Task 12 implementation overlay

[The shooting report](shooting-weapon-abilities.md) covers pp.34–35/57/62–63 and all 38 printed ability subsections on pp.78–85, distinguishing implemented rules from deferred owners. Supplied appendix 04.01.03 resolves the Multiple Weapon Profiles source gap: physical profiles are exclusive per model, Hunter predicates constrain targeting, and One Shot use is shared. Current evidence is 276 assertions, 278 CTest entries, fresh Godot bindings and both sanitized fuzzer roots under RLC 0.4.14. See ROADMAP.md for exact scope and checks; historical inventory classifications above remain initial findings.

## Task 13 charge overlay

Read [the charge report](charges.md) and ROADMAP.md for implementation, tests and deferred geometry. 11.01–11.04 (pp.36–37) now use source declaration, full-pair roll/reroll, post-roll multi-target selection and staged per-model constrained movement. Successful charge history supports Lance and charge-granted Fights First (24.21/24.13); task 14 still owns the full Fight consumer. Heroic Intervention 15.11 (p.57) uses both pre-roll modes, exact additional cost and actual current-phase charge targets. Flight/Hover (21.03/24.17) and the charging/traversal portion of Aircraft (23.02/23.04) have explicit gates; Aircraft ingress/offboard and melee rules remain tasks 16/14. Super-heavy Walker 24.35's ordinary movement permission cannot leak into charges.

Charges keep the user's quad grid, circular fixture bases and area-only terrain. Reachability holds other final models fixed, retains elevation and searches horizontal grid routes; it does not certify continuous geometry or simultaneous formation rearrangements. Mandatory later owners include post-charge Crushing Impact (15), all Fight sequencing (14), supplied attachment/data/faction/mission rules (6/17) and editor performance/integration (17). The nonfunctional old target-first Overawing Magnificence hook needs a supplied faction definition before restoration.

## Task 14 fighting overlay

[The fighting report](fighting.md) implements 12.01–12.09 (pp.38–43) as phase-wide Pile In, dynamic Fights First/remaining fights and phase-wide consolidation. Both movement steps resolve current-player choices first. Normal/Overrun, initial engagement snapshots, mandatory/legal passing, new eligibility, closest-target ties, per-model approach/engagement preservation and three consolidation modes have explicit kernels/actions. Engaging consolidation offers every newly engaged unfought opponent a response. Fights First 24.13 uses all participating models or successful charges; 23.04 melee Aircraft targeting is bearer-specific.

The user's supplied Fight on Death appendix changes U19/p.87 retention: destruction effects/removal wait until the model's own unit attacks or phase end, replacing immediate individual retaliation. Retained models use the common declarations/grouping pipeline with scoped permission and unit stratagem effects; failed legacy grant rolls still clean up. Generic timing is supplied authority; specific faction grants remain task 17. The preserved quad/area-only geometry and fixed-other-model endpoint limits remain explicit. Counteroffensive/remaining core effects are mandatory task 15, transport/emergency-disembark/lifecycle task 16, attachments deferred task 6, and full supplied-data/rendered/performance integration task 17.

## Task 15 core stratagem/action overlay

[The core stratagem/action report](core-stratagems-actions.md) audits every 15.01–15.12 card (pp.54–57) and 16.01 (p.58). Explosives/Crushing Impact use exact printed selections and initial dice, shared mortals/FNP/destruction and per-unit CP bookkeeping. Epic Challenge is a selected-character melee Precision grant; Counteroffensive grants Fights First and constrains the next friendly selection in the opponent's Fight step. Smokescreen has its start-of-opponent-Shooting window, direct target cover and an explicitly approximate intervening circular-base consumer. Existing reroll/Bravery/Ingress/Heroic/Snap consumers retain their printed windows and shared restrictions; the obsolete per-move Overwatch action is removed.

Generic actions have actual membership/OC/keyword/shock/move/engagement/start/shooting gates, TITANIC exceptions, bounded independent cross-turn records, interruption/departure and explicit-stamp completion. All shooting after-effect clauses (pp.34–35/57) remain enforced; 16.01's generic list alone is insufficient. DEPLOY DEVICE remains unplayable. No unavailable mission/faction permission is invented. Transport departure/movement belongs to task 16; supplied mission/data/faction/rendered/performance integration remains mandatory task 17, and attachments deferred task 6. Continuous geometry and physical terrain features remain user-deferred.

## Task16 implementation overlay

Read [the transport/Aircraft report](transports-aircraft.md) for 18.01–18.05 (pp.64–65), passenger reserves (pp.68–69), 22.05/23.01–23.04 (pp.73–74), Firing Deck24.14 (p.81) and transport Scouts24.31 (p.84). Printed mechanics and supplied offboard/persistence definitions have implementation and explicit metadata fixtures. ROADMAP.md holds final validation status; historical missing classifications above remain initial findings. Actual datasheet permissions, attachments, faction offboard consumers and rendered/performance integration remain their assigned owners. Preserve the documented quad/circular-base and fixed-other-model closeness limits.

## Task17 Orks source audit overlay

[The Orks codebase audit](orks-codebase-audit.md) examines every linked datasheet and the ordinary faction rules. The requirements matrix covers all 67 cards and the CP inventory covers 40 stratagems. Orks Leader/Support and carrier permissions now have readable sources; healing/revival and several other appendix definitions are available. These are source/implementation requirements, not new rule implementations or test passes. The user excludes point/DP accounting, requests up to three distinct detachments and retains CP costs; ROADMAP.md contains the pending batches and mandatory fixes.

## Task17.B configuration overlay

[The configuration report](orks-configuration.md) separates actual army identity from legacy roster IDs, implements independent selections of up to three Orks detachments and explicitly enables user-directed point-free public reserves. This adjusts the pricing portion of 20.01/p.68 without certifying new point totals or replacing them with another percentage. Existing point-aware fixtures remain supported. The CP registry covers all 40 source cards' costs/package gates, with common shocked/destroyed target exceptions; their full timing/keyword/effect actions remain later batches. Core 15.01/p.54 payment/use limits and the supplied appendix maximum +1CP increase retain deterministic coverage. ROADMAP.md owns final validation; selecting a package does not implement its effects or certify any of the 67 datasheets.

## Task17.C1 predicate overlay

[The keyword predicate report](orks-keyword-predicates.md) implements appendix02.05.01 ALL/ANY/NONE conditions with explicit unit/model scope, weapon presence/magnitude, ANTI and Hunter target consumers, saved metadata validation and editor labels. This resolves O02's compound-target predicate defect, while effective characteristics and other consumers remain17.C2–C4. The user-authorized obsolete Tough as Squig Hide and Bestial Bellow actions are removed. No legacy factory or current datasheet is certified; ROADMAP.md retains the pending source-driven consumers and final validation evidence.

## Task17.C2a model characteristic overlay

[The model characteristic report](model-characteristics.md) integrates supplied modifier arithmetic with model M/T/Sv/InSv/Ld/OC consumers, movement pp.12/33, attack configuration p.18, save groups p.19, Leadership/Battle-shock p.9 and objective control p.52. Appendix05.02.01's highest battlefield T now has a correct running maximum; retained Fight on Death models remain constituents until removal. Attached bodyguard-only selection remains17.G. O02 is partially resolved: weapon arithmetic, named selectors, Damaged, incoming reductions/ignoring modifiers and live source-effect consumers retain their pending owners. No current datasheet is certified.

## Task17.C2b1 fixed weapon overlay

[The fixed weapon report](weapon-characteristics.md) integrates effective Range/WS/BS/S/AP into actual targeting/half-range, hit/wound/save and grouping consumers (pp.16–19/50/79/83; supplied modifier appendix). It refreshes group source/target identities and battlefield T (05.02.01/02.05.01), and distinguishes borrowed Firing Deck profiles (p.81). O02 remains partial: A/D arithmetic/random timing/grouping, named selectors, Damaged, incoming reductions and live source effects retain pending owners. No current datasheet is certified; ROADMAP.md contains final evidence.

## Task17.C2b2 Attacks/Damage overlay

[The A/D report](weapon-attacks-damage.md) integrates scoped A into fixed melee declaration/shares and per-weapon ranged gathering, and scoped D into post-allocation normal/Devastating damage. Original random dice/re-rolls precede arithmetic; grouping compares effective fixed D or every same-domain random face. Zero-A declarations do not stall. O02 remains partial: named selectors, Damaged, incoming reductions, live sources and actual datasource grants remain pending. ROADMAP.md contains509 assertions /511 entries and final sanitizer/binding/game/replay/fuzzer evidence. No current datasheet is certified.

## Task17.C2c named-selector overlay

[The named-selector report](named-selectors.md) and [source identity crosswalk](orks-named-identities.tsv) add67 datasheet identities and139 families/176 profile identities, including distinct same-name ranged/melee profiles. Compact conjunctive selectors reach actual characteristic/weapon-rule consumers; mixed unit/model scope, archives, saves and Firing Deck identity are covered.534 assertions /536 entries,25 native sanitizer cases and final binding/ML/game/replay/fuzzer checks pass.17.C2 is complete; O02 remains partial pending Damaged, incoming reductions, selective ignoring, live source effects and actual datasheet grants. No current datasheet is certified by these generic fixtures.


## Task17.C3 Damaged overlay

[The Damaged report](damaged.md) implements website core ability24.39 with explicit threshold metadata and current bearer snapshots. Its -1 hit modifier precedes the supplied appendix02.02.01 cap; hits/criticals p.18, Torrent p.85 and Firing Deck p.81 retain their consumers.546 assertions /548 entries,12 sanitizer cases, focused bindings, game and replay/mutation validation pass. O02 remains partial pending incoming reductions/selective ignoring, live sources and actual datasheet grants. ROADMAP.md owns evidence and17.C4 is next.


## Task17.C4a incoming modifier overlay

[The incoming modifier report](incoming-attack-modifiers.md) adds recipient AP/D arithmetic to pp.17–19 saves/damage/grouping and p.80 Devastating consumers. Supplied appendix02.02.01 operations merge before rounding/limits;02.02.03 random D remains post-allocation, and p.24 ordinary mortals bypass weapon D. Ranged-only Mobile Fortress and all-attack Dread ’Ard source wording is recorded without installing those unit grants.558 assertions /560 entries,12 sanitizer cases, focused bindings/ML and replay/mutation validation pass. The fresh878-action game also passes. ROADMAP.md records final evidence; O02/17.C4 remain partial pending02.02.02 optional subset selection, live source effects and actual datasheets.


## Task17.D/E physical, dice and source overlay

[Physical weapons/compound dice](physical-weapons-compound-dice.md) implements appendix04.01.03 profile selection with Nazdreg's explicit source exception, core24.15/p.81 physical Hazardous counting, and appendix01.05.02/02.02.03 original summed re-rolls/random characteristics/constants in A/D/M/demise. [Source instances/effects](source-instances-effects.md) implements stable event/use/typed-grant infrastructure at core pp.16–19/28–38/87–88 with supplied current-player-first sequencing and01.02.02/01.02.04 expiry/offboard policy. Unit auras refresh source life, recipient keywords and base range; actual current faction abilities/specialized aura adapters remain their data owners.

Final0.4.17:596 supported assertions /598 entries,38 debug and optimized sanitizer/leak cases, production Godot source buttons/weapon checks, finite Gym and preserved/game replays plus41 mutation runs pass. ROADMAP.md owns exact evidence.17.D/E are complete as engine infrastructure;17.C4b selective modifier subsets and actual current datasheets/grants remain pending. These fixtures do not certify full Orks or all core rules.


## Task17.C4b optional attack modifier overlay

[Optional attack modifier subsets](modifier-ignoring.md) integrates retrieved appendix02.02.02 with explicit WS/BS/hit permissions, appendix02.02.01 arithmetic/re-roll precedence and pp.17–18 grouping/natural gates. Cover/Plunging Fire pp.50/73 and Heavy/Ignores Cover/engagement pp.82/35 retain separate choices; source effects use01.02.02/01.02.04.619 assertions /621 entries,23 native sanitizer/leak cases, production Godot choices, finite Gym and fixed replay/mutation checks pass. ROADMAP.md owns exact evidence.17.C4 is complete within these explicit categories; other ignore consumers and actual included54 datasheets remain source-adapter work. Forge World/Legends units are excluded. Next is17.F; this does not certify all Orks/core rules.


## Task17.F Orks army-rule overlay

[Orks army rules](orks-army-rules.md) implements retrieved faction Army Rules and user-supplied Warlord selection. Ordinary pp.33–37/65/81 restrictions remain, with sourced riled exceptions and appendix01.02.02/01.02.04 persistence/offboard handling. War Cry spans through next-turn end; Da Boss gains literal1CP separately from Core CP/appendix08.02.01. No old-edition melee A/S boost or excluded unit adapter is added.648 assertions /650 entries,29 sanitizer/leak cases, production Godot selectors/timing/click suppression, finite Gym and fixed replay/mutation checks pass. ROADMAP.md records exact evidence; actual current54 datasheets remain their source-data batches. Next17.G resumes Leader/Support/task6, not a Legends/Forge World migration.


## Task17.G attachment overlay

[Attached units](attachments.md) implements core19.01–19.04 (pp66–67), combined starting strength p86, attack destruction p87 and returning-component provenance p88, with appendix19.01.01/19.04.01/05.02.01. Formation requires explicit role, exact friendly permitted bodyguard, separate Leader/Support slots and checked combined capacity. Mixed keywords remain model-local; attack declarations use bodyguard T. Components stay combined after bodyguard loss. Conferred rules last through that attacker's full sequence, while live recipients remain separate. Whole-unit death waits for the final combined member and resolves archived-bearer provenance with merged controller groups.

All17 included Orks lists and41 edges match the independent source inventory;13 excluded cards receive no permissions. Painboss's formation-specific changes affect its bearer only.682 assertions /684 CTest entries,34 sanitizer/leak cases, production Godot reserve-pair/army/source checks, finite Gym, preserved/fresh complete-game replays and45 mutation runs pass; ROADMAP.md owns exact evidence. Generic revival provenance is covered; actual healing/revive/setup remains17.J. Current profiles/loadouts/grants remain17.H–P and other faction permissions remain unavailable. Historical source-inspection rows above are preserved; this overlay supersedes their task6 attachment deferral within these limits. Forge World/Legends remain excluded; full rendered journeys/wrapper performance remain17.Q.


## 17.H1 source-data overlay

[Current Orks profiles/loadouts](orks-current-unit-data.md) implements the data part of02.04–02.07 (core p11) for three source cards, including five model profiles,12 unique weapon profiles,13 printed rows, literal model-count ranges and optional equipment. Existing Hunter/physical-profile/conditional weapon/attachment/save consumers operate on the real data in explicit fixtures. No points/DP system is added. This does not certify all abilities or playable current cards:17.H2 supplies special abilities,17.H3 supplies supported ovals on quads, and17.H4 switches the roster. Other54-card work retains its roadmap owners; Forge World/Legends remain excluded. ROADMAP.md records final tests and source comparison.


## 17.H2/H3 source-ability and user-geometry overlay

[Current Orks abilities](orks-current-unit-rules.md) implements the five special abilities on the three current data families through actual move/charge, hit/D, Battle-shock and mortal/FNP/destruction consumers, including per-army/unit limits and source/bank/save lifetimes. Ovals now retain supplied axes/shape metadata while using explicitly user-authorized long-axis circles on the unchanged quad grid; exact oval geometry is deferred, unknown hull/multipart data remains unsupported. Current738 assertions have passing results across the initial full/corrected affected runs, with56 sanitizer/leak cases, HTML checks, five Godot controls, ML and replay/fuzzer evidence in ROADMAP.md.17.H4 still owns production roster promotion; full current-card games and the other standard datasheets are not certified by legacy-root smoke runs. Forge World/Legends remain excluded; rendered/performance work remains17.Q.


## Current Orks production roster and War Horde passive —17.H4/17.I1

[The roster/passive guide](orks-roster-war-horde.md) promotes the three current
Orks families into actual selection, Warlord and attachment flow and implements
Get Stuck In melee Sustained Hits1 with source-owner/package/faction/unit-keyword
gates. Existing declaration, duplicate-choice and critical-hit consumers resolve
the grant. Actual current games finish in1,158 and1,346 legal actions;755 supported
assertions have passing full/affected results, with17 native sanitizer cases,
three Godot controls, HTML/ML and native replay/fuzzer evidence in ROADMAP.md.
Earlier legacy-root results do not certify this switch. War Horde upgrades and
CP cards, other standard datasheets, rendered journeys and wrapper performance
remain later tasks. Circle proxies/quads and explicit missing geometry remain
the user-approved scope; no price/DP system or Forge World/Legends is added.
