# Orks rule modules

This folder contains the current Orks faction adapters. Shared game state,
combat, movement, healing and source-effect procedures remain in `src/`.
Start with [the Orks documentation index](../../../doc/factions/orks/README.md)
for faction scope, sources and implementation reports.

| Modules | Responsibility |
| --- | --- |
| `orks_army_rules.rl` | Waaagh!, riled-up grants, War Cry, Da Boss and Warlord eligibility |
| `orks_detachment_types.rl` | Faction-specific enhancement, effect, use and attack records |
| `orks_detachment_rules.rl` | Enhancement selection, detachment predicates, grants, source registration and roster restrictions |
| `orks_detachment_actions.rl` | Attack selection, targeted stratagems, movement modes, Fall Back reactions and hit interception |
| `orks_detachment_support.rl` | Psychic tests, timing choices, healing/return adapters, shooting support and reactions |
| `orks_unit_data.rl`, `orks_infantry_data.rl`, `orks_elite_data.rl`, `orks_remaining_data.rl` | Current model factories, equipment choices and composition validation |
| `orks_unit_rules.rl`, `orks_datasheet_rules.rl`, `orks_elite_rules.rl`, `orks_remaining_rules.rl` | Datasheet permissions, source registration, targeting, grants and aura queries |
| `orks_roster.rl` | Public custom roster selection and loadout decisions |

The `elite` and `remaining` names record the original implementation batches;
they are not exclusive unit categories. Read the factories and adapters before
assigning a new card to a file. A later responsibility-based split can improve
these names without mixing that refactor into the directory relocation.

Compile from the existing entrypoint (`src/full_game.rl`), or include `src`
with `-i src` when compiling tests/scenarios. Imports use the full module path,
for example `import factions.orks.orks_army_rules`. Keep exported `orks_*`
functions and `Orks*` types stable: a directory is not a declaration namespace.

This is an organizational boundary, not an independent library. Core
orchestration still invokes faction hooks, and core state/source records still
refer to some Orks types. The architecture guide describes those shared
compilation and frame dependencies. Put reusable procedures in common modules;
keep source-specific permissions, triggers and effects in these adapters.
