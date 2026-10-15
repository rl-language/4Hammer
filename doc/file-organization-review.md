# File ownership and naming review

The faction directory move groups the14 existing Orks modules under
[`src/factions/orks/`](../src/factions/orks/README.md), and their12 reports/four
source inventories under [`doc/factions/orks/`](factions/orks/README.md).
Public function/type names and mechanics are unchanged. The following are
review recommendations, not completed function moves or rule changes.

## Recommended next changes

| Priority | Current location and examples | Recommended owner/name | Reason and constraints |
| --- | --- | --- | --- |
| 1 | [`units.rl`](../src/units.rl): legacy factories from `make_tantus` through the old patrol builders, including `make_beastboss_morgrim`, `make_beast_snagga_boyz`, `make_squighog_boyz` | `legacy/rosters.rl`; eventually prefix ambiguous factories with `make_legacy_` | Roughly690 lines of old roster content sit between entity definitions and query helpers. Separate fixture/compatibility data from the current Orks factories. Some old rosters remain selectable, so do not delete them or claim current-edition certification. Keep enum IDs stable. |
| 2 | [`units.rl`](../src/units.rl): `unit_has_waaagh`, `unit_is_riled_up` | `factions/orks/orks_army_rules.rl`; consider `orks_unit_has_waaagh`, `orks_unit_is_riled_up` | These query Orks army abilities and faction grants, rather than the generic structure of a Unit. Keep their live-source, component and bank semantics. Renaming must update generated binding consumers. |
| 3 | [`attachment_rules.rl`](../src/attachment_rules.rl): `configure_orks_attachment`, `orks_bodyguard_permission` | Faction `orks_attachment_data.rl`, keeping shared attachment mechanics in `attachment_rules.rl` | Seventeen Orks Leader/Support permission lists are faction data embedded in the generic attachment engine. Move their source-linked table and builder together, retaining stable catalog IDs and existing core attachment predicates. |
| 4 | [`rules.rl`](../src/rules.rl): `select_orks_detachments`, `resolve_orks_mobbed`, `orks_active_muster_field_label`, `orks_active_muster_value_label` | Detachment selection in `orks_roster.rl`; Mobbed in a faction `orks_datasheet_actions.rl`; roster label adapters beside roster code or in an explicit host adapter | Faction implementations remain in the central phase file after relocation. Core phases should call faction actions, rather than contain their bodies. The two label helpers read `pick_army.roster.entry`, so their dependency on that generated caller frame must remain explicit. |
| 5 | [`rules.rl`](../src/rules.rl): random-stat and re-roll actions; `resolve_damage_jobs`, `prevent_wound_loss`, `resolve_mortal_wounds`; timing-window actions | `dice_actions.rl`, `damage_actions.rl`, `timing_actions.rl`, alongside existing predicate/data modules | Separate interactive procedures from phase orchestration. Move complete overload families and their nearby rationale comments together. Keep generated frame/action names and shared context ownership stable. Extract one cohesive block per commit; do not split merely to meet a line limit. |
| 6 | [`orks_remaining_rules.rl`](../src/factions/orks/orks_remaining_rules.rl), [`orks_detachment_support.rl`](../src/factions/orks/orks_detachment_support.rl) | Group movement/transport reactions, source registration and timing adapters by responsibility | `remaining` and `support` cover several unrelated subsystems. For example, `orks_trukk_reactions`/`orks_disembark_selection` belong together, while `split_orks_kommandos`/`orks_kommando_formations` belong with formation rules. Preserve source-specific permissions while reusing shared movement, damage and healing procedures. |
| 7 | [`orks_roster.rl`](../src/factions/orks/orks_roster.rl): equipment conversion, validators, labels and interactive muster | Separate roster data/validation from roster actions if the file continues growing | Most of the795-line file is already one coherent roster subsystem. Prefer two clearly named modules over a file for every helper. `orks_muster_field_label` and `orks_muster_value_label` are display adapters, not tabletop validation. |
| 8 | [`orks_remaining_rules.rl`](../src/factions/orks/orks_remaining_rules.rl): `unit_is_hidden`; [`source_effects.rl`](../src/source_effects.rl): `riled_up_grant` | Whole-unit Hidden query in `terrain_rules.rl`; riled grant factory in `orks_army_rules.rl` | The former only aggregates the generic `model_is_hidden` query; the latter constructs an Orks army effect inside the shared source engine. These are examples of functions on the wrong side of the faction boundary. |
| 9 | [`board.rl`](../src/board.rl): `valid_state_foundations`, `valid_unit_identities`, `valid_model_numeric_history`, `valid_unit_numeric_history` and related validators | `state_validation.rl` | Restore validation is a distinct responsibility from Board storage and queries. Move the related validation family together; retain its calls to source/attachment validation. |
| 10 | [`rules.rl`](../src/rules.rl): `set_state`, diagnostic `main`, `pretty_string`; `invalid_entity_identity` | A host/serialization adapter and a separate CLI example; identity constructor in `state_types.rl` | Host labels, restore entrypoints and a debugging program obscure the phase/action code. `invalid_entity_identity` is a generic zero-identity constructor, not damage resolution. Preserve compiler-invoked pretty-string instantiations and current external APIs. |

The first three are the clearest small changes. Larger orchestration and
faction-module splits should follow separately, with tests after a combined
edit batch. Existing cross-module frame/type references mean the import graph
is not a strict acyclic dependency graph. Use RLC's action graph and the frame
storage audit when moving interactive procedures.

## Naming improvements

| Current name | Suggested name | Why |
| --- | --- | --- |
| `get_hit_roll_bonus` | `hit_roll_modifier` | The return value can be a penalty, not only a bonus. |
| `rerollable_pair_dices_roll` | `rerollable_two_dice_roll` | Names the actual two-die procedure and avoids the plural typo. Move its overloads together. |
| `orks_elite_bearer` | `make_orks_infantry_model` | The helper sets the Infantry keyword, including on non-Characters; “elite” is a migration batch. |
| `finish_orks_elite_unit` | `make_orks_single_model_unit` | It constructs a one-model Unit, attachment permissions and starting strength; the current name hides that result. |
| `orks_remaining_usage` | `orks_datasheet_usage` | It builds a SourceInstance usage key for datasheet rules, independent of which implementation batch introduced them. |
| `make_beast_snagga_boyz`, `make_squighog_boyz` | `make_legacy_beast_snagga_boyz`, `make_legacy_squighog_boyz` | Distinguishes legacy fixtures from current `make_orks_*` factories. |

These are candidates, not blanket renaming instructions. Keep public IDs,
serialized state/action names and the Godot `UnitID`/`ModelID` discovery contract
stable. Ordinary function renames can still change generated host methods;
action renames also affect payload catalogs and replay compatibility. Audit
consumers and validate matching bindings before applying any rename. Avoid
cosmetic renaming of all exported symbols merely because their files moved.

## Boundaries to preserve

Do not move shared healing, granted movement, source effects or damage into the
Orks folder merely because current cards use them. Likewise, `Profile`, `Weapon`
and `Stratagem` contain both common/legacy and faction data: their single enum
definitions cannot be separated by moving a few alternative declarations.
A catalog/metadata redesign would be a separate change, with explicit identity
and observation compatibility work.

C++/runtime binding files could later move from `src/` to `bindings/godot/`.
That requires updating native/web build paths, includes and packaging; it does
not improve rule ownership enough to bundle with the faction relocation.
The large native `tests/baseline.rl` also merits a later subsystem split, but
CTest currently builds a library per suite: design that split to avoid repeated
expensive compilation. Keep pure rule tests native.
