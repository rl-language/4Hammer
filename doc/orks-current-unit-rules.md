# Current Beast Snagga unit abilities:17.H2/H3

This batch implements the five printed special abilities on Beastboss, Beast Snagga Boyz and Squighog Boyz, alongside the user-authorized temporary oval circle approximation. It follows the retrieved11th-edition version1.2 HTML cards from2026-10-12. The public starter now uses these adapters (17.H4); all54 standard Orks cards remain planned, with Forge World/Legends excluded.

## Source and behavior

| Source | Ability | Implemented behavior |
| --- | --- | --- |
| [Beastboss](https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss) | Dodge Dis! | The current unit's ranged and melee attacks gain+1 to hit, individually represented before cumulative caps and optional ignoring. It affects attached constituents while the source confers unit rules. |
| Beastboss | Keep Huntin'! | At start/end of its move in its own Movement phase, optionally choose one friendly Beast Snagga unit within6 base inches, including itself. Clear shock immediately and install riled status until start of the next own turn. Both windows and all duplicate bearers share one army-round use; opponents have separate counters. Accepted effects survive source death and transfers to reserves/passengers. |
| [Beast Snagga Boyz](https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz) | Mobbed | After a completed charge, each engaged enemy Monster or Vehicle rolls Battle-shock once, whether or not it was a declared target. The charge controller orders targets, while their owners control shock choices. Roll penalty is-1 or-2 with13+ current live combined members. Failed/declared-only charges do not trigger it. |
| [Squighog Boyz](https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz) | Bomb Squig | At end of a completed Normal move in its own Movement phase, optionally choose one visible enemy within12 base inches. Spend the unit's once-per-battle token when the target is accepted. Explicit D6 succeeds on3+, then explicit D3 mortal wounds use ordinary target-owned allocation, FNP, spill/destruction and source provenance. Decline/no target spends nothing; a failed roll still spends the token. |
| Squighog Boyz | Brutal Impact | A completed charge this turn adds+1D to every attack, including ranged weapons and Jaws. The increment enters ordinary characteristic addition before division/rounding/reductions; it expires with charge history at turn boundaries. |

No points, detachment prices or additional CP expenditure is invented. Bomb Squig's D6/D3 rolls are not on Command Re-roll's supplied list. Waaagh's Advance charge permission is captured when Advance is selected; later Keep Huntin' does not retroactively change that selection. Source rules use explicit ability metadata; legacy factory names do not grant them. Current constructors use generated initialization/destruction.

## Architecture and lifecycle

`orks_unit_rules.rl` registers Keep Huntin' with two source instances using shared rule code110, and Bomb Squig with one instance per original component using code111. The future Beastboss on Squigosaur adapter must reuse110. Registration is idempotent across formation, bank changes and model return. Existing source counters/keys preserve army/unit scope, ownership, durations and saved state. Bomb's generic grant field is unused: accepted use dispatches damage rather than installing a modifier.

`resolve_movement_sources` combines these targeted choices and generic grants in the current-player then opposing-player groups. Movement uses it at actual start and successful end; stationary selection and failed/skipped movement have no move-end trigger. A distinct `choose_movement_source` avoids colliding with nested destruction choices. `choose_keep_huntin_target`, `choose_bomb_squig_target` and `choose_mobbed_target` each contain one UnitID, preserving the editor's existing click detection. The production choice panel also labels each target explicitly. Dice actions remain `roll`/`quantity` so default chance ownership is-1. Rules.gd/TraceManager.gd remain unchanged.

Dodge Dis! has a separate Bool snapshot and modifier origin; it does not overwrite another hit bonus or change WS/BS. The attachment engine controls unit-rule conferral during source death. Brutal Impact is appended to outgoing damage operations at declaration gathering and uses actual charge history. Mobbed reuses the existing shock action with a bounded penalty and ordinary start/end shock triggers, retaining Command recovery rules and denying outside-Command Insane Bravery.

Every stored numeric value remains bounded/linear/Bool/enum; distances are transient calculations. Shared source effect installation now accepts an already validated chosen recipient, allowing Keep Huntin' to target a different unit without changing its source identity or weakening generic recipient guards. Accepted riled grants use ordinary expiry in all banks and archives.

## Temporary oval policy

The source75x42mm Boy and90x52mm Nob bases retain both axes and explicit oval metadata. The user now authorizes75/90mm circular proxies using the long axis, through the same measurements, collisions, setup, paths, rotation and Godot rendering as existing circles. This approximation can change range/engagement and placement outcomes relative to exact ovals. It is documented user policy, not a claim of exact tabletop geometry. Rotation does not change a circle. Exact oval support is deferred; unknown hull/multipart dimensions remain unsupported. No fractional anchor or action domain is introduced.

## Validation and remaining work

The combined batch has738 supported assertions with passing results across the initial739/740 full run and corrected58/58 affected rerun. All56 native sanitizer/leak cases, HTML tables, five Godot controls,20-step Gym, preserved/fresh complete-game replays and20 mutation runs pass. ROADMAP.md records exact logs and corrected fixture/environment errors.17.H4 must promote these adapters into the public roster and validate actual current selections, attachments, movement/combat and complete games. Full rendered journeys and wrapper retrieval performance remain17.Q. Current data APIs and focused semantic fixtures do not certify every remaining Orks card.


17.H4 promotes these adapters through the public roster/Warlord/formation flow;
17.I1 adds War Horde melee Sustained Hits1 through ordinary declaration snapshots.
Read [the roster/passive guide](orks-roster-war-horde.md) and the latest ROADMAP.md
evidence; earlier full-game records in this report used legacy roster data.
