# Ordinary Orks detachments

This batch implements the15 ordinary packages from the [Orks faction page](https://wahapedia.ru/wh40k11ed/factions/orks/), including their38 enhancements/upgrades and40 stratagems. [The source inventory](orks-detachment-source-inventory.tsv) identifies each card and its containing source section. Boarding Actions, Legends, Forge World, points and detachment prices are excluded. CP remains part of the engine. This is package integration, not completion of the remaining standard datasheet adapters or the entire edition migration.

The user permits up to three selected detachments. Ordinary enhancements are unique, assigned to different original roster units and count toward a four-enhancement army limit. Upgrades may have three copies, with the second and third excluded from that count. Epic Heroes, and units containing attached Epic Heroes, cannot receive either kind. Ordinary options require a Character; Upgrade eligibility follows the individual card. The non-Battleline/Battleline copy limits are3/6. Warlord selection runs after options so Flyboss can confer Character first. Attachment preserves already assigned options on distinct original units; the Epic Hero exclusion is checked again against the resulting unit.

## Design

`orks_detachment_types.rl` defines the finite option, effect, attack-record and psychic-budget types. `orks_detachment_rules.rl` implements eligibility, passives, characteristic/weapon consumers, source installation and transport dependencies. `orks_detachment_actions.rl` handles cards selected at attack/move declaration, defence, Dread Mob's dice and original-hit interception. `orks_detachment_support.rl` handles phase windows, healing/return, psychic actions, post-attack reactions, reserve entry and prebattle redeployment. `rules.rl` connects these helpers to the existing core action, damage and timing pipelines.

Every accepted lasting effect has a source key and duration. Printed native characteristics remain available to the normal replacement/multiplication/addition/division/subtraction pipeline. Separate Hazardous and Supa-hazardous sources retain independent tests; a numeric Rapid/Cleave improvement is added to the existing magnitude and removed on expiry. Declaration snapshots include actual physical weapon/profile identity and the shooter's selected-unit objective condition. Generated Sustained hits remain distinct from the original rolled hits intercepted by Grot Shields. Hit and wound records distinguish successful hits from actual wounds lost after prevention.

A source-arena handle includes a generation. At capacity, a disabled/dead, unreferenced source slot can be reused; frozen pending events reject another generation. Source keys and entity identities remain distinct from current unit/model selectors. A replacement Gret unit gets new identities and its captured battle-start equipment, wounds and fresh battle usage. Its original destroyed archive is preserved. Safe battlefield slot reuse protects reserve return slots, pending destruction and compulsory Surly returns.

Serial subactions share the single frame slots in `Board.shared_actions`, with the existing direct attack/dice slots retained. The audit covers all113 action declarations and verifies66 shared types have exactly one stored copy. Completed hit pools, modifier selections and reaction results are copied into small caller-owned snapshots before reuse; whole child frames are not copied. See [the architecture guide](../../rulebook-architecture.md#sharing-frames-with-disjoint-active-lifetimes) and [the lifetime inventory](../../action-frame-lifetimes.json).

Reactions use flat wrappers. `attack_with_orks_reactions` runs a core attack, its post-attack windows and any queued reaction shooting; it does not recursively embed another attack frame. Enemy movement hooks similarly return the selected reactor and distance to the enclosing movement wrapper. A reactive move stores a separate bounded distance limit rather than replacing M, so an existing M bonus cannot enlarge a printed6-inch reaction. All nested decisions restore the caller's decision owner and active player.

## Cargo and offboard units

A transport-dependent grant records both carrier and passenger identities. Blitzboss's carrier movement/invulnerable bonuses require its live bearer aboard. Boss Boomer borrows rules only from an actual Warboss passenger; Targetin' Gizmos checks actual Big Mek cargo. Moving that passenger elsewhere or losing its bearer ends the dependency. Passenger-model counts used by Wurrband are model counts, not occupied seats. Better native invulnerable saves remain available.

Offboard own-unit abilities use the real reserve/passenger bank. They never substitute remembered battlefield coordinates to measure external ranges or visibility. Psychic levels and round/phase spending, Battle-shock, accepted persisting effects and source usage survive bank transitions. Newly shocked passengers/reserves can resolve their own Breakin' Heads mortals through allocation, prevention and destruction. Retained Fight-on-Death models receive their deferred destruction processing at phase end.

Healing restores wounded live members first, then original eligible non-Character casualties with1W, preserving equipment, identity and once-per-battle usage. Setup checks phase-start coherency anchors and forbids engaging a new enemy. Surly's explicit3W return uses its own closest-legal-position exception. Offboard returned models stay in their original bank; an embarked return additionally requires a permitted available seat. Lack of capacity leaves the model destroyed without further triggers, per appendix01.02.03. Persistent effects follow appendix01.02.02; offboard visibility/range follows01.02.04.

## Geometry and host integration

Positions and action coordinates remain whole-inch quads. Distance/collision computations use transient floats. Every persisted number remains bounded/linear, Bool or enum. Oval and other noncircular footprints deliberately use circular proxies where known dimensions exist, with intentional approximation comments. Smoky Gubbinz uses sight segments crossing those bases as partial obscuration under the user's visibility policy. Missing hull dimensions are not invented.

The editor continues discovering the generated named actions. Option selection stages use one enum, reserve UnitID and ModelID; separate support targets, archived casualties and source-bank choices receive explicit buttons. Hulk's final1/2CP choice is shown before spending. Godot Rules.gd and TraceManager.gd remain outside this change.

State/observation schemas are32, action20 and next-state33. Regenerate matching native libraries, Python wrappers and Godot headers together. Existing models/policies need matching layouts. No custom init/drop hooks were introduced.

## Validation

The `test_orks17all_*` cases exercise package ownership, eligibility/copies/attachments, passive consumers, CP/expiry, attack distinctions, retained destruction, movement limits, cargo lifetimes, healing/return, offboard effects and bounded identities. Run CTest using the repository's documented configuration, with compiler-jobs4 and debug optimization off. The source metadata comparison is `tools/check_orks_detachments.py --wrapper ... --source-dir ...`; it checks the separately retrieved ordinary-card identities, package mapping, Upgrade tagging and printed CP, not the meaning of the effect prose.

ROADMAP.md records executed results and outstanding owners. Type checking alone, or card metadata comparison alone, does not establish that a detachment works. Full rendered journeys, wrapper-retrieval performance, the remaining standard datasheets and exact geometry retain their roadmap owners.
