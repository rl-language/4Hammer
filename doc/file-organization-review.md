# File ownership and naming review

The faction directory relocation and the subsequent responsibility refactor
are complete as source changes. [ROADMAP.md](../ROADMAP.md) records executed
validation. The [Orks module map](../src/factions/orks/README.md) is the current
source layout; [the datasheet guide](factions/orks/orks-datasheets.md) explains
all54 current cards. Implementation history does not define runtime categories.

## Applied faction cleanup

- All current datasheet factories, equipment/composition validators and printed
  Orks attachment permissions live in one `datasheets.rl` file.
- Removed the Infantry/Elite constructor wrapper. `make_orks_model` sets common
  Orks metadata; concrete factories supply their actual printed keywords.
- Removed the two batch model/equipment dispatchers. Exact metadata and physical
  profile choices now live directly with each owning factory.
- Single- and multi-model units share `finalize_orks_unit`; one equipment helper
  family handles named profiles, physical groups and explicit Hunter conditions.
- Three use-limit constructors became the generic `make_source_usage` and
  `source_use_limits` mechanism, with explicit owner, original identities,
  scope and all four interval limits. Actual counters remain shared.
- Merged six combat contribution helpers into the three datasheet interfaces;
  merged source registration and availability into one path each.
- Runtime modules are army, roster, detachments, enhancements, stratagems,
  types, effects, sources, combat, movement, recovery, transports, psychic and
  morale. Predicates and actions for one mechanic stay together.
- Moved Orks army queries/actions out of common entity/phase files, moved the
  riled-up grant builder into faction effects, and moved whole-unit Hidden
  aggregation into the common terrain module.
- Internal frames/caller fields now describe Command healing, datasheet timing
  windows and hit effects. Public input/action names remain stable; state and
  observation schemas advance to41 for the renamed serialized frame fields.

## Remaining shared-engine proposals

These are outside this faction refactor and are not completed work.

| Current location | Proposed owner/change | Reason |
| --- | --- | --- |
| Legacy factories in `units.rl` | `legacy/rosters.rl`, with ambiguous factories explicitly named `make_legacy_*` | Roughly690 lines of selectable old roster/fixture data obscure generic entity definitions. Preserve enum IDs and distinguish these from current cards. |
| Dice, damage and timing procedures in `rules.rl` | Cohesive `dice_actions.rl`, `damage_actions.rl`, `timing_actions.rl` modules | Core phase orchestration should invoke these procedures rather than contain every body. Move complete overload families with their rationale and context ownership. |
| Board restore validators | `state_validation.rl` | Identity/history/attachment/source validation is distinct from storage and ordinary Board queries. |
| `set_state`, diagnostic `main`, `pretty_string` | Host/serialization adapter and separate CLI example | Preserve compiler-invoked binding instantiations and public compatibility. |
| `invalid_entity_identity` | Shared identity/storage primitives | A zero identity is generic infrastructure, not damage resolution. |
| `get_hit_roll_bonus`, `rerollable_pair_dices_roll` | `hit_roll_modifier`, `rerollable_two_dice_roll` | Clarify penalties and the actual two-die procedure; audit generated host consumers before renaming. |
| C++/runtime glue in `src/` | `bindings/godot/` | Requires native/web build and packaging updates, separate from rule ownership. |
| Large native `tests/baseline.rl` | Subsystem organization with a shared compilation strategy | Avoid compiling another rules library for every small test group. Keep pure rule tests native. |

Shared profile/weapon catalogs still contain common, legacy and current Orks
enum entries. Their stable identities and single enum definitions require a
separate data/catalog redesign if they are to be partitioned further. Do not
move common healing, damage, movement or source counters into a faction folder.
