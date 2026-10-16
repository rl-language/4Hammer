# Orks datasheets and ability integration

The54 included standard Orks cards share one construction module,
[datasheets.rl](../../../src/factions/orks/datasheets.rl). It owns factories,
loadout choices, composition checks, printed keyword/ability metadata and the17
Leader/Support permission lists. Runtime procedures are organized by mechanic
in the [module map](../../../src/factions/orks/README.md). There are no separate
implementation-batch categories.

The source is the11th-edition HTML retrieved2026-10-12 from
[Wahapedia's Orks faction](https://wahapedia.ru/wh40k11ed/factions/orks/).
Every factory retains its card URL. The [unit inventory](orks-unit-requirements.tsv)
covers all67 catalog cards, distinguishing54 included cards from13 excluded
Forge World/Legends cards. Prices and detachment prices are excluded; CP and
printed eligibility restrictions remain. [ROADMAP.md](../../../ROADMAP.md)
records migration history and actual validation.

## Construction and identity

`make_orks_model(profile, datasheet)` initializes the common profile, compact
datasheet identity, ORKS keyword and Waaagh! metadata. Concrete factories add
Infantry, Character and other keywords explicitly from their cards. No generic
Orks model becomes Infantry merely because another constructor needs it.

Equipment passes through shared `equip_weapon` with actual `Weapon` entries.
Alternate profiles carry a1-based reference to an earlier primary slot;
independent copies are separate primaries. There are no Orks equipment-choice,
named-weapon or named-profile enums: allowed lists contain actual catalog
entries, while Meganob selections pair two actual weapons. Hunter conditions
remain explicit per-slot rules. Factories install their chosen profiles and
companions directly. Nazdreg's simultaneous ranged profiles retain their
printed exception while sharing one physical copy. Kustom Force Field and Pulsa
Rokkit are nonattacking equipment entries; Paired Krumpas is an actual profile.

`finalize_orks_unit` supplies printed attachment permissions and captures
starting strength after every model/equipment choice is present. Both single-
and multi-model units use it. Callers assign the controlling player and let
Board allocate stable unit/model identities before attachment, source
registration, casualty bookkeeping or saving. Current `make_orks_*` factories
remain distinct from the old scenario roster factories in `units.rl`.

Generated init/drop owns all fields. Positions stay on whole quads, stored
numbers remain bounded/linear/Bool/enum, and calculations can use transient
floats. The envelope remains32 models per unit and13 equipped profile slots
per model. Raw source rows include alternatives and do not imply that every
profile is equipped simultaneously.

## Composition and equipment

| Family | Important construction properties |
| --- | --- |
| Beastboss, Snagga Boyz, Squighogs | Snaggas allow1–2 Nobs and9–18 Boys, with an additional Thump Gun per ten total models. Squighogs allow1–2 Nobs and3–6 Boys. Independent printed ranges permit intermediate totals. Thump Guns augment Boy equipment; Stikka ranged/melee and Choppa Standard/Hunter preserve physical identity. |
| Boyz, Nobz, Stormboyz, Warbikers | Checked per-model replacement lists retain quotas and bearer equipment. Ammo Runts belong to the unit or bearer as printed. Paired Krumpas is its actual equipped profile, with the sourced reroll behavior. |
| Deff Dread, Killa Kans | Arms are independent physical choices, Extra Klaws stay separate, and Kan Blasta profiles remain alternatives. Incoming reduction, demise and target-T conditions use shared combat consumers. |
| Meks, Painboy, Painboss, Runtherd, Gretchin | Factories supply their actual attachment roles, support metadata, healing/repair permissions and equipment. Crew tokens do not become extra models. |
| Flash Gitz, Meganobz, Breaka Boyz, Tankbustas | Profile-specific upgrades, Hunter alternatives, Pulsa and Barrage metadata remain explicit. Breaka/Tankbusta Bomb Squigs have two battle uses with a turn limit, unlike the Squighog single token. |
| Characters and epic heroes | Actual keywords, compulsory/prohibited Warlord metadata and bodyguard permissions are explicit. Names do not infer abilities. Ghazghkull/Makari retain distinct model roles. |
| Wagons, rigs, walkers, aircraft and other vehicles | Checked weapon counts/replacements, physical multi-profiles, source-specific passenger permissions, carrier capacity and optional equipment remain factory-owned. Stompa has nine default physical weapons and ten stored profiles. |
| Kommandos | The Nob and nine Boys have their printed equipment quotas. Prebattle splitting preserves original component identity, starting strength and Bomb Squig ownership. |

Profile/weapon enum identities remain in the shared catalogs for compatibility.
The constructors inherit none of the obsolete Morgrim/Beast Snagga grants.
The independent HTML audit checks63 model profiles and253 weapon rows across
all54 included cards, including separate InSv boxes and Hunter headers omitted
from the original text extracts.

## Shared ability paths

Combat has one datasheet weapon-rule hook, one characteristic-modifier hook
and one target-dependent attack-effect hook. They cover all cards and preserve
separate hit contributions, source keys and ignore-modifier provenance. Core
replacement/multiplication/addition/division/subtraction, rounding and caps
still apply. Identical-attack grouping retains physical weapon and hit identity.

Sources have one datasheet registration function and one faction availability
hook. Original unit/model handles, actual live conferral, offboard permissions
and target availability remain checked. Moving between banks, attaching,
returning or restoring a save never refreshes spent uses.

Use specifications are constructed with the shared `make_source_usage` and
`source_use_limits`. Scope and phase/turn/round/battle limits are explicit;
zero means no limit for that interval. Per-army keys share across duplicate
bearers; per-unit/model keys retain their appropriate identity. Checking or
constructing a specification spends nothing; accepting the ability commits it.
Printed overlapping restrictions remain conjunctive.

| Ability group | Runtime properties |
| --- | --- |
| Keep Huntin', Intimidating Motivation, Race | Start/end move windows share the appropriate army-round use. Accepted shock clearing and riled grants retain their printed duration; cargo follows its own permission. |
| Mobbed and Battle-shock reactions | Completed charges trigger engaged Monster/Vehicle targets; the charging player orders them and each target owner controls its test. The13+ penalty uses current live combined strength. Runtherd, Breakin' Heads and other own-unit reactions share the normal shock pipeline across banks. |
| Ammo Runts, Rokkit Charge, Dodge Dis!, Brutal Impact | Selection timing, original tokens, separate modifier contributions and completed-charge history feed the common declaration/attack machinery. No legacy A/S bonus is inferred. |
| Healing, model return and repairs | The shared healing/return procedures preserve original identity, equipment/use history, starting strength and legal placement. Ordinary unit healing excludes Character returns. Mek repairs heal an actual chosen model; separate hit grants expire at next own Movement and reuse the source prototype. |
| Kustom Force Field, Pulsa and Barrage | The Force Field applies only to ranged allocation. Pulsa retains its selected target identity; Barrage uses actual qualifying hits. Their grants do not silently follow replacement targets. |
| Psychic abilities | Warpath, Beastscent and Da Jump use the same level-budget roll as Wurrband. A psychic1 shocks the caster without cancelling the effect; a caster removed by the reaction cannot receive a new grant or be moved. Da Jump's unspecified duration uses the phase default. |
| Bombs, withdrawal, ingress and engines | Explicit source windows use controller sequencing. Bombs use ordinary mortal allocation/FNP/destruction; reserve movement uses shared setup. Full Throttle engines expire at next own Command. Dead Snikrot/Wartrike sources cannot confer new windows through surviving bodyguards. |
| Passenger reactions and cargo | Ordinary/reactive disembark share one context frame. Follow-up Movement belongs to MovementPhase, avoiding Disembark→Movement→Disembark recursion. Passenger iterations retain stable identities during bank compaction. Gretchin seat rounding is per actual unit, and counts for abilities are actual passengers rather than seat cost. |

## Geometry and host integration

Original oval axes/shape metadata remain available, but all noncircles use
intentional circular proxies. Squighog Boys/Nobs use75/90mm circles and
Warbikers use75mm circles. Exact silhouettes, hulls and oval geometry remain
deferred. The user authorizes temporary large circles where sources say
“use model”: Battlewagon/Gunwagon/Bossbunka160mm, Mek Gunz100mm, Stompa240mm,
Trukk140mm. These are arbitrary proxies, not source dimensions. Explicit
positive bounded diameters override the defaults.

Specialized editor choices retain their real reserve/passenger/formation banks
and the existing enum, Bool, UnitID, ModelID and BoardPosition contracts.
Public action names are preserved; internal Command-healing, timing-window and
post-shoot frames use responsibility names. State/observation43 rejects older
serialized frame-field names. Matching generated native/Godot bindings are
required after storage changes. Sources store a finite hidden label enum;
display strings are derived only when requested. ROADMAP.md owns compatibility
evidence.
