# Attached units: core mechanics and Orks permissions

Batch17.G implements formation and component lifetimes for the included Orks Leader/Support lists. It resumes the generic task6 mechanics. It does not install current model profiles, loadouts or all datasheet abilities; those remain17.H–P. Other factions still need their permission lists. Forge World and Legends are excluded.

The specification is core pp.66–67 (19.01–19.04), starting strength p.86, destruction p.87 and returning models p.88, with supplied/retrieved appendix19.01.01,19.04.01 and05.02.01. [The procedural reference](11th-edition-core-rules-procedural.txt) retains the printed wording; [the unit inventory](orks-unit-requirements.tsv) records each card URL and retrieval date2026-10-12.

## Formation and state

[attachment_rules.rl](../src/attachment_rules.rl) owns permissions, provenance validation, source lifetimes and metadata configuration. `configure_orks_attachment` supplies explicit roster datasheet, role and exact permitted bodyguard identities. Character status and model count do not grant permission. Unmarked legacy roster factories cannot attach until their current data adapters supply the metadata. A component can have several models.

`attach_leaders` offers source-first `attach_unit(UnitID attach_source, UnitID attach_target)` decisions against the reserve bank before battle. Both units must be live, owned by the deciding player, identified and unretired. The source must be an unattached Leader or Support; the destination must be its permitted bodyguard with that role slot free. The combined32-model bound and two-component capacity are checked before mutation. One Leader and one Support can attach in either order. Passing ends that player's participation; the caller's owner is restored afterward.

The target keeps its persistent identity. Every transferred model keeps its identity, original component, wounds, equipment and use history. The consumed reserve slot is erased after the transfer. `Unit.attached_units` is a visible `CheckedVector<AttachmentComponent,2>`, replacing unbounded hidden records. Each record preserves component identity, original count, role, datasheet and typed unit abilities. Combined starting strength remains the original combined count after casualties. Destroyed bodyguards do not split the unit or reset Leader/Support starting strength.

`valid_attachment_state` checks roles, unique role slots, bounds, original model/archive membership and combined counts. Board's existing registry validates global identity uniqueness. Numeric storage uses bounded or linearly distributed integers, enums and Bool; generated lifecycle remains automatic.

## Keywords, Toughness and ability scope

Unit keyword queries see component models' keyword union. Individual models keep their own keywords. Bodyguard Toughness is the highest effective T among bodyguard models physically on the battlefield; only when none remain does the highest remaining Leader/Support T apply. Attack declarations use this query. Destroyed retained models remain physically present until their existing removal boundary.

`Unit.unit_abilities` explicitly describes rules affecting the unit or its models. Attached records preserve each source component's list. These rules apply to the combined unit while a member of that original component confers them. Intrinsic per-model characteristic modifiers remain on the bearer. Current data adapters must distinguish these scopes; legacy ability vectors alone do not certify current Orks datasheets.

Unit-only `SourceInstance` handles can resolve an absorbed component's identity to the combined unit. Per-unit usage follows the combined containing unit, including after an archived bearer dies. `requires_leading` checks that the source started attached; it remains satisfied after bodyguard death. A live conditional source can be registered before formation, but its grants/activation remain inactive until it attaches, including its own destruction triggers. `model_specific_rule` keeps single-model activation distinct from unit-rule conferral.

## Destruction and returning models

`source_alive` requires an actually live original source. `source_confers_rules` additionally accepts a retained source while the attacking unit finishes all its attacks (p.67). These predicates are deliberately separate: retained casualties cannot become live action recipients. A specific bearer can confer a unit rule independently of surviving peers; a unit-source rule lasts until its component's last member dies.

`commit_wound_loss` retains a conferring attack casualty even without another death ability. Its existing destroying-unit provenance associates the interval with the actual attacker. `release_attachment_rules` clears only that attacker's interval; `resolve_damage_jobs(...,finish_attacks=true,...)` invokes it before destruction callbacks/removal. Non-attack source death expires immediately. Typed grants and raw unit-scoped abilities follow the same lifetime. Half-strength counts live models and excludes retained destroyed models.

`SourceEventKind::unit_destroyed` is separate from model destruction. It is emitted only when the combined unit's last live model dies, never just because a component died. A unit-wide death rule still resolves through attachment provenance when its bearer was archived earlier. Single-model rules do not gain this exception. Model and whole-unit hooks are collected into one decision window: current player's effects in their chosen order, then the opponent's, preserving the supplied sequencing rule. A bounded marker prevents duplicate emission in the same destruction interval.

`restore_attachment_provenance` is the boundary for later revival: it preserves original component, starting counts and equipment/use identities, clears transient death flags and reopens unit destruction tracking. Source rules resume when a valid returned member is restored. Actual healing, revive eligibility, placement and equipped-data reconstruction remain17.J; the regression fixtures restore archived members to test lifetime/provenance only.

## Included Orks permission metadata

| Source | Role | Permitted bodyguards |
| --- | --- | --- |
| Beastboss | Leader | Beast Snagga Boyz |
| Big Mek | Leader | Boyz, Breaka Boyz, Flash Gitz, Mek Gunz, Nobz, Tankbustas |
| Big Mek in Mega Armour | Leader | Meganobz, Mek Gunz |
| Big Mek with Shokk Attack Gun | Leader | Boyz, Mek Gunz, Nobz, Tankbustas |
| Boss Snikrot | Leader | Kommandos |
| Deffkilla Wartrike | Leader | Warbikers |
| Nazdreg | Leader | Meganobz |
| Warboss | Leader | Boyz, Breaka Boyz, Nobz |
| Warboss in Mega Armour | Leader | Meganobz |
| Zodgrod Wortsnagga | Leader | Gretchin |
| Bannernob | Support | Boyz, Nobz |
| Bigboss | Support | Boyz, Breaka Boyz, Nobz |
| Mek | Support | Boyz, Flash Gitz, Mek Gunz, Nobz, Tankbustas |
| Painboss | Support | Beast Snagga Boyz, Squighog Boyz |
| Painboy | Support | Boyz, Breaka Boyz, Flash Gitz, Nobz, Tankbustas |
| Runtherd | Support | Gretchin |
| Weirdboy | Support | Beast Snagga Boyz, Boyz |

The largest list has six entries. No excluded/unknown source is given an attachment role or list. The stable67-card catalog retains historical identifiers.

Painboss's [Runnin' wiv da Herd](https://wahapedia.ru/wh40k11ed/factions/orks/Painboss) is implemented here because formation determines it: when attached to a MOUNTED unit, only that bearer loses INFANTRY, gains MOBILE/MOUNTED and receives+4"M. The addition enters shared modifier arithmetic before division/rounding; it does not rewrite other models. Painboss's profile, weapons and other abilities remain their data owner.

## Godot and compatibility

Matching native libraries and generated headers export both reserve UnitIDs in source-first order. Production `MultipleChoises.gd` presents named role/source/bodyguard buttons. `InteractionManager.gd` suppresses battlefield clicks for this reserve-bank pair. `Rules.gd`, `TraceManager.gd` and small whole-inch quad coordinate domains are preserved.

Schemas are state/observation28, action18, next-state29. Save/replay consumers, generated bindings and ML policies must match. [ROADMAP.md](../ROADMAP.md) and [tests/README.md](../tests/README.md) record executed evidence and limitations. The34 semantic cases, all67-card/41-edge permission cross-check, production Godot controls, pending-root-save subset, finite Gym and sanitized complete-game/replay/mutation checks are recorded in ROADMAP.md. Tests use explicit circle/profile fixtures; they do not certify every current datasheet or rendered editor journey.
