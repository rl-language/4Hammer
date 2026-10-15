# Orks implementation documentation

The current faction implementation covers all54 standard Orks datasheets and
15 ordinary detachments. The project tracks CP and allows at most three selected
detachments; it excludes points/detachment prices, Forge World and Legends.
The source inventory retains excluded cards as historical catalog records.
[ROADMAP.md](../../../ROADMAP.md) records completed validation and remaining
scope limits.

Start with the [40K/Godot engine guide](../../engine-guide.md),
[architecture guide](../../rulebook-architecture.md) and
[state reference](../../game-state-reference.md) for the shared engine.
The [source module map](../../../src/factions/orks/README.md) explains where
faction code lives and which responsibilities remain shared.

| Topic | Documentation |
| --- | --- |
| Source audit and requirements | [Codebase audit](orks-codebase-audit.md), [unit requirements](orks-unit-requirements.tsv), [named identities](orks-named-identities.tsv) |
| Configuration and eligibility | [Army configuration](orks-configuration.md), [keyword predicates](orks-keyword-predicates.md) |
| Army rules | [Waaagh!, War Cry, riled-up and Warlord](orks-army-rules.md) |
| Detachments and CP | [Detachment implementation](orks-detachments.md), [source inventory](orks-detachment-source-inventory.tsv), [CP inventory](orks-stratagem-costs.tsv) |
| Initial current cards | [Profiles/loadouts](orks-current-unit-data.md), [abilities](orks-current-unit-rules.md) |
| Datasheet families | [Infantry, walkers and monsters](orks-infantry-walkers.md), [elites, Meks and Gretchin](orks-elites-meks-gretchin.md), [remaining standard cards](orks-remaining-units.md) |
| Public roster | [Starter roster and War Horde](orks-roster-war-horde.md), [custom roster and bank integration](orks-custom-roster.md) |

These reports include historical migration checkpoints. Use their source and
mechanism explanations together with the latest ROADMAP completion record;
an earlier report's test count or pending-batch statement is not current status.
