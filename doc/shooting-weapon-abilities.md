# Shooting and weapon abilities — task 12

Use the procedural reference, especially pp.16–18,34–35,57,62–63,78–85,88, and the supplied appendix. ROADMAP.md records final validation. The preserved quad grid, circle fixtures and area-only visibility abstraction remain in force; no new faction profiles or attachment permissions are invented.

## Shooting workflow

Select a friendly live unit that has not selected to shoot this phase, then choose an eligible shooting type before selecting weapons. The one-UnitID `select_shooting_unit` also supports units with no ranged weapons (p.88); the existing two-UnitID `select_target` remains a compatibility entrypoint whose target is a hint, followed by actual weapon declarations. Normal, assault, close-quarters and indirect eligibility follows pp.34–35. Snap shooting requires an explicit granting rule (p.57), targets a single visible unit within 24 inches and uses unmodified six-only hits with no hit rerolls. Target replacement uses supplied appendix 04.03.03 and retains one shared remaining Snap target per revalidation boundary.

Normal/indirect require an unengaged unit that did not advance. Assault requires an unengaged advanced unit with an ASSAULT weapon and selects only its ASSAULT weapons. Close-quarters requires engagement, no advance and an appropriate weapon or Monster/Vehicle unit. Non-Monster/Vehicle bearers select only sidearms against engaged enemies; Monster/Vehicle bearers can shoot elsewhere with their stated penalty. An engaged Monster/Vehicle target is permitted only in the attacking player's Shooting phase, with its separate hit penalty. BLAST still cannot target engaged units. Apply cumulative penalties before the +/-1 cap (pp.35/62–63/88).

PISTOL and CLOSE-QUARTERS are aliases. An ordinary model can select multiple sidearms, but cannot mix them with other ranged weapons. Monster/Vehicle bearers can mix categories. Each bearer checks its own live-base range and visibility. Retained corpses cannot extend ranges. Lone Operative restricts per-bearer visibility/indirect targeting, supports an explicit bounded X and is disabled by attached-unit provenance; attachment formation remains deferred to task 6.

Indirect weapons can target Hidden units, force cover even against visible targets, prohibit every hit reroll and fail natural 1–5. The threshold becomes natural 1–3 only with stationary-this-turn state and visibility to any friendly live unit. Allowed faces still use the normal hit rules (p.35). A zero-distance normal move is not Remain Stationary. Actual movement/setup history persists until the next turn. Turn-limited movement/charge compatibility flags expire for both armies, while own shooting selection resets at its own turn boundary.

Every selected shooting activation locks action starts only for the remainder of its phase, including zero-attack activations. Phase cleanup expires that lock off-table too. Complete mission actions/stratagem permissions remain task 15.

## Weapon declarations and effects

Select one instance of every duplicate weapon-ability family during Select Weapons (p.78); different ANTI keywords belong to one family. Preserve the original choice and explicitly choose between it and newly granted duplicate instances when later target effects grant abilities. Conditional abilities use the target unit's keyword union; slash-separated alternatives are OR conditions. Selected/current-target rule snapshots keep grouping and effects consistent.

BLAST/BLAST X, RAPID FIRE and CLEAVE use declaration-time live model counts and half-range snapshots. Replacement targets get new snapshots. BLAST defaults to one per complete five models; X scales that value. CLEAVE adds X per complete five only for an unsplit weapon. MELTA retains half-range through the attack. Reject bonuses beyond configured storage instead of silently clamping them.

HEAVY requires the owning player's Shooting phase, no engagement/setup and no live member moving more than three inches this turn (p.82). Actual <=3-inch moves can qualify. Cover changes BS and IGNORES COVER negates all cover sources; Stealth adds cover, not a hit modifier. LANCE consumes the charge-move flag with cumulative modifiers; task 13 must fix that flag's legacy unsuccessful-charge producer.

LETHAL HITS is optional independently for each original critical hit. Automatic wounds do not become critical wounds; Sustained extras still roll wounds. TORRENT alone grants ordinary automatic hits without critical-hit effects; unavailable skill data without Torrent is asserted. TWIN-LINKED gives optional free wound rerolls, once per original die. ONE SHOT is spent when its physical weapon is selected, including declined/targetless attacks, and remains on the archived bearer after revival. Every EXTRA ATTACKS weapon is mandatory in the shared fight declaration engine; full fighting remains task 14.

## Complete core-ability checklist

This covers all 38 printed subsections; owners distinguish implemented foundations from mechanics outside task 12.

| Rule | Source page | Status / remaining owner |
| --- | --- | --- |
| ANTI-X Y+ | 79 | Chosen instance, generic keyword condition and natural critical threshold; tasks 9/12. |
| ASSAULT | 79 | Unit qualification, assault mode and per-weapon selection; task 12. |
| BLAST / BLAST X | 79 | Snapshot count, X scaling and engaged-target rejection; task 12. |
| CLEAVE X | 79 | Snapshot count and unsplit-only bonus; task 12. |
| CLOSE-QUARTERS | 80 | Alias, bearer permissions and category selection; task 12. |
| Deadly Demise X | 80 | Task 10 engine; passengers/emergency disembarkation remain task 16. |
| Deep Strike | 80 | Task 11 every-base ingress. |
| DEVASTATING WOUNDS | 80 | Task 10 delayed, non-spilling critical damage engine. |
| EXTRA ATTACKS | 81 | Mandatory shared declaration; full fights remain task 14. |
| Feel No Pain X+ | 81 | Task 10 per-wound prevention; conditional faction definitions need supplied data. |
| Fights First | 81 | Complete step/eligibility workflow remains task 14. |
| Firing Deck X | 81 | Passenger weapon selection/locking remains task 16. |
| HAZARDOUS | 81 | Task 10 selected-weapon count and shared rolls/mortals/destruction. |
| HEAVY | 82 | Full printed own-phase/engagement/setup/distance checks; task 12. |
| Hover | 82 | Task 11 flying budget exemption. |
| IGNORES COVER | 82 | All cover sources negated; tasks 8/12. |
| INDIRECT FIRE | 82 | Indirect mode, visibility, cover, face gates and reroll prohibition; task 12. |
| Infiltrators | 82 | Task 11 all-model/every-base setup. |
| LANCE | 82 | Modifier consumer; genuine charge-move producer still task 13. |
| Leader | 82 | Deferred task 6 until supplied permissions/datasheets. |
| LETHAL HITS | 82 | Optional per-critical automatic wound, preserving Sustained extras; task 12. |
| Lone Operative / X | 83 | Per-bearer visibility/indirect range and attached-unit exemption; task 12. |
| MELTA X | 83 | Snapshot range and per-attack damage; tasks 10/12. |
| ONE SHOT | 83 | Physical-weapon battle use shared across grouped profiles and preserved through archival/revival; task 12. |
| PISTOL | 83 | Identical to CLOSE-QUARTERS; task 12. |
| PRECISION | 84 | Task 10 visible character-group selection and fallback. |
| PSYCHIC | 84 | Attack marker in selected rules; additional psychic-specific faction effects need supplied data. |
| RAPID FIRE X | 84 | Declaration-time half range and gather-time extra attacks; task 12. |
| Scouts X | 84 | Task 11 pre-battle workflow; user requires uniform duplicate values. Transport variant remains task 16. |
| Scout move | 84 | Task 11 movement/separation. |
| Stealth | 85 | All-live-model cover, cancelled by IGNORES COVER; tasks 8/12. |
| Support | 85 | Deferred task 6 until supplied permissions/datasheets. |
| Super-heavy Walker | 85 | Task 11 movement within the area-only abstraction; physical features deferred. |
| SUSTAINED HITS X | 85 | Original critical plus ordinary extra hits; tasks 9/12. |
| TORRENT | 85 | Ordinary automatic hits without invented critical results; task 12. |
| TWIN-LINKED | 85 | Optional free wound rerolls; task 12. |
| Ability presentation / target keywords (24.01) | 78 | Conditional attack rules, including OR keywords; task 12. |
| Duplicated abilities (24.02) | 78 | Weapon-family choices; current dynamic Scouts follow the user's uniform-value assertion. Additional numeric core data/attachments remain with supplied datasheets. |

## Storage and editor contracts

Current compiler packages are 0.4.14. State/observation schemas are 11; action schema is 7. Numeric rule parameters, keyword IDs/counts, mode enums and selectors use standard bounded storage. No custom Quantity or numeric tensor encoding is introduced. Phase/entity references retain the established metadata conventions. Supported limits: eight added rules per weapon slot, 32 selected ability instances, one primary plus eight alternative target keywords, 256 selected weapons and 4096 grouped dice. Compound random characteristics and new profile data remain task 17's source/data obligations.

Use generated `init`/`drop` on game-state classes. The user clarifies that custom lifecycle methods require manually initializing/dropping every field. Primitive keyword arrays avoid nested heap construction inside empty rule vectors. Setup legality rejects impossible first anchors before staging and reuses a single candidate during the deployment search; it still validates every base/preset and preserves the source.

Godot exposes shooting-type, duplicate-ability and per-critical Lethal choices with labels. The new source selector keeps one UnitID; existing target/model payloads remain. Fixed arrays of owning vectors require the explicit `grant_model_weapon_rule` data bridge. A borrowed field wrapper must retain its parent object; the regression keeps its temporary SelectWeapon payload alive while passing its slot. Rules.gd and TraceManager.gd are unchanged. The shooting fixture uses separated squads, the common chance classifier and a matching-source legal-rank fuzzer harness.

## Remaining source/dependency gates

The user supplied Multiple Weapon Profiles 04.01.03. Nonzero bounded group IDs identify profiles of a physical weapon within each model; zero denotes an independent slot. Selection excludes a second profile of the same weapon. Legacy plasma pairs are grouped explicitly, and One Shot consumes all profiles in that group. Hunter keyword predicates are snapshotted at declaration and checked for initial and replacement targets; actual Hunter datasheet permissions still require supplied data. Attachment formation/permissions, full charges/fights/actions, transports, actual faction abilities and new-edition datasheets remain with their roadmap owners. Complete integration must fix every recorded downstream issue rather than treating this report as full-edition certification.

## Validation

Task 12 is complete within its documented scope. RLC 0.4.14 passes all 276 assertions and 278 CTest entries; its duplicate-variable diagnostic was separately verified. Fresh matching Godot bindings pass with `--timeout 300`, covering production selectors/ability buttons, attack/save restoration, allocation and FNP. The full-game fuzzer passes both lifetime inputs and a full replay, plus 224 mutations in 61 seconds. The matching shooting fuzzer passes its combat replay plus 1,117 mutations in 61 seconds. Both use leak detection, precondition checks and bounds checks. See ROADMAP.md for artifact paths, compiler-specific gameplay/ML evidence and remaining owners.
