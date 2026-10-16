# Public Orks roster and integration review

The public `pick_custom_orks` choice builds either player's roster from all54
included standard Orks cards. The historical starter remains available. Points,
detachment prices, Forge World/Legends and rendered integration are excluded by
the user. Select up to three detachments, configure units, select enhancements
and choose the Warlord before the existing formation/deployment sequence.

## Roster design

`roster.rl` owns a small `OrksMusterDraft`: card, composition, selected model
and bounded equipment choices. It does not store another Board or provisional
Unit in every draft frame. Field choices expose only the selected card/model's
source-supported alternatives. A changed composition resets equipment to a legal
default. Paired weapon replacements update together; full loadout/quota checks
run before an entry can be accepted.

`make_orks_muster_unit` dispatches to existing current-card constructors, so
profiles, physical weapons, abilities, attachment permissions and circular proxy
metadata have one owner. Accepting a unit allocates stable identities only after
copy/storage/identity bounds are checked. Each player may use up to16 of the32
unit slots; the roster requires a legal Character Warlord candidate before finish.
Remove/cancel choices address the owning player's prebattle roster only.

Three-copy/six-Battleline limits share `orks_muster_copy_limit`; detachment-granted
Battleline is considered before disposition registration as well as afterward.
This avoids selection-time and final-validation disagreement. Enhancements retain
the existing four-count, Upgrade duplicate and Epic Hero/attached-Epic restrictions.

Godot presents real card/model/equipment labels and staged choices. Draft model
indices and reserve roster indices use buttons; battlefield clicks do not supply
those values. No valid-action enumeration, filtering, masking or wrapper-fetching
optimization is part of this work; the user owns that work in the compiler.

## One rule implementation across unit banks

Battlefield, reserve and embarked storage are locations, not separate versions
of own-unit rules. Appendix01.02.04 permits unmeasured own-unit abilities offboard
while forbidding external visibility/distance measurements. The following paths
share their rule logic:

| Mechanic | Shared implementation | Location adapter |
| --- | --- | --- |
| Command Battle-shock | One `battle_shock_step` scan and step-start recovery snapshot for all banks | Iterate real banks |
| New Battle-shock / Breakin' Heads | `orks_became_shocked`, identity-backed frame, common Runtherd, CP/D3/shock removal | Find the current unit bank |
| Wurrband psychic use | `orks_psychic_unit_available`, one `use_orks_psychic` frame, one round/phase budget and Warphead roll | Roar requires battlefield range; Visions targets its own unit anywhere |
| Da Boss is Watchin' | `orks_watchin_available`, `commit_orks_watchin` | Bank selectors only |
| Dread Power | `orks_dread_power_valid`, `commit_orks_dread_power` | Bank selectors only |
| Surly | `orks_surly_casualty_valid`, `return_orks_surly` | Nearest legal quad on battlefield, capacity for passengers, no reserve coordinate |
| Healing | Generic `heal_unit`, `return_model` and model reset in `healing_rules.rl` | Legal placement or passenger capacity |
| Mortals / FNP / death | `resolve_mortal_wounds`, `prevent_wound_loss`, `commit_wound_loss`, `resolve_damage_jobs` | A `DamageJob.bank` identifies real storage; external death effects require battlefield membership |
| Turn/phase resets | Shared `Board` bank iteration for histories, flags, usage and phase snapshots | Only battlefield units acquire geometry anchors |
| Retained fighters | `release_phase_retained_fighters`, common destruction scan | Iterate all banks |
| Persisting grants | One keyed `grant_orks_typed_payload` installer | Stable source/recipient identities, no offboard range fabrication |

`orks_offboard_breakin_heads`, the second psychic/support effect frame, the Orks
mortal-wound frame, offboard death frame and offboard Surly rule were removed.
Remaining `offboard` selectors are thin UI/storage adapters: they select a real
bank/entry and call the shared rule. Generic geometry/offboard membership checks
and transport lifecycle operations remain necessary location infrastructure.

Damage jobs default to the battlefield, preserving existing attack callers.
Offboard own-unit jobs explicitly select reserves/passengers. One destruction
scan respects current-player-first ordering across all banks. A bank choice is
required only when that controller has pending deaths in multiple banks; all
other cases use the same unit/model choices directly. Godot's `damage_bank`
context identifies the selected collection and is restored after resolution.
Battlefield-only retaliation, demise ranges and emergency placement stay guarded;
no temporary battlefield slot is invented for an offboard unit.

Surly reuses the normal returned-model reset, clears death-only metadata, restores
provenance and reactivates an emptied unit. Healing, Runtherd and Surly use the
same wound/death/source infrastructure rather than a second Orks offboard engine.

## Review corrections

- Coherency additionally requires one connected live-model group, by explicit
  user ruling2026-10-15. Printed neighbour and maximum-distance checks remain.
  Dead models do not bridge disconnected living groups.
- Destroying an unplaceable reserve transport expires its passengers first,
  preventing dangling carrier identities in saved games. The already-existing
  reserve-deadline path uses that same passenger lifecycle helper.
- Saved Squig Launcha hit provenance cannot exceed total successful hits.
- Native Godot strings use generated ownership and UTF-8 in both directions.
  The previous non-owning allocation leaked native buffers; Latin-1 conversion
  corrupted non-ASCII names.
- Test fixtures follow the real enhancement-finish stage and effective
  detachment-granted Battleline limits.

## Scope and validation

Schemas are state/observation37 and action24 (next state38); rebuild native
libraries, Python metadata and Godot headers together. No custom lifecycle hooks
or new compilation caches are introduced. All stored numeric domains remain
bounded. Model positions remain whole-inch quads. Oval long-axis circles and
large arbitrary Use-model circles retain their explicit intentional imprecision.

Executed final checks and any remaining limitations are recorded in ROADMAP.md.
