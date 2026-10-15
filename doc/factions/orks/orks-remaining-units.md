# Final standard Orks adapters

This batch completes the source adapters for the remaining25 standard Orks
cards, using the cached 11th-edition version1.2 cards retrieved2026-10-12 at
`https://wahapedia.ru/wh40k11ed/factions/orks/<slug>`. The index version2.7.1 is
separate. ROADMAP.md records executed validation; this document explains the
implementation. Forge World and Legends are excluded by user instruction.

`orks_remaining_data.rl` owns profiles, exact keywords/core metadata, physical
weapon copies and checked equipment choices. `orks_remaining_rules.rl` owns
live queries and source adapters. It reuses the existing combat, source,
movement, damage, psychic, reserve and transport engines.

| Card | Implemented source behavior |
| --- | --- |
| Battlewagon |22 Infantry seats, Mega Armour/Jump Pack2, Ghaz4; optional ball/klaw and0–4 Big Shootas; ranged incoming Damage−1 |
| Big’ed Bossbunka |11 Infantry seats, no Ghaz; Deck11; optional extra Big Shootas; passenger OC at an explicitly assigned friendly home marker; Fortification targeting/hit/fall-back exceptions; intervening circular base gives cover |
| Blitza-bommer | Opponent Fight-end visible, non-Lone-Operative target within24in; D6 selects D3/3/D3+3 mortals before normal Aircraft return |
| Boss Snikrot | Leader/Infiltrators/Stealth/Lone Operative; optional opponent Fight-end withdrawal only when every model is Hidden and unengaged; opponent Movement-end ingress from round1 |
| Burna-bommer | Optional missile rack; opponent Fight-end visible non-Lone-Operative/non-Monster/Vehicle target within36in;2+ gives D3 mortals and prevents Hidden/grants incoming Ignores Cover through end of next own turn |
| Dakkajet | Two physical Dual Supa-shootas plus optional third; own-Shooting hit+1 against non-Fly |
| Deffkilla Wartrike | Leader/Da Boss; Advance roll+1; own move-start/end free Speed Freeks target within6in, including its actual cargo: remove shock and rile to next own turn, once per army/round |
| Deffkoptas |3–6 models, one launcher replacement per three; Deep Strike; own-Shooting hit+1 after ingress this turn; optional unengaged opponent Fight-end withdrawal |
| Ghazghkull Thraka | One model, mandatory Warlord,4 transport seats; Lone Operative near another friendly Orks Infantry unit; non-stacking6in melee hit/wound+1 aura; once-army/battle Makari selects up to current-round friendly army units across all banks |
| Gorkanaut |12 Infantry seats/no Ghaz; Super-heavy Walker; Gut Hatch permits assault disembark after own Normal move; melee hit1 rerolls |
| Gunwagon |12 Infantry seats/Ghaz4; Kannon/Killkannon/Zzap choice and optional weapons; own-Shooting hit1 rerolls |
| Hunta Rig |22 Beast Snagga Infantry seats; FNP5/Deck11; Butcha Boyz gain2 attacks per actual passenger model, capped+22; Crushing Impact costs1CP less before affordability |
| Kill Rig |12 Beast Snagga Infantry seats; FNP5/psyker level1; optional selected-disembark Beastscent gives passenger wound+1 against Monster/Vehicle through turn; selected-Fight Warpath gives melee Lethal/Psychic |
| Kommandos | One Nob/nine Boys with independent extra-slot quotas; Found ’Em increases one enemy’s detection range by3 through turn; hit+1 against Hidden targets; existing Bomb Squig engine; optional formation split into two five-model units, independently choosing models and which half receives each token ability |
| Mek Gunz |1–3 independently equipped guns; crew tokens are wounds, not models; matching ranged weapon names plus an actual hit gives one target Wobbled/−1Ld/−2M/Grounded through next own turn |
| Morkanaut |12 Infantry seats/no Ghaz; Gut Hatch; own-Shooting hit1 rerolls; separate physical dual guns/launchers |
| Nazdreg | Leader/Da Boss/two seats; unit Deep Strike/ranged Ignores Cover; shared existing Intimidating Motivation budget; free unengaged enemy-move-end reaction within8in, D6 or optional fixed5 while riled, once per army/phase; all three Kustom Blasta X ranged profiles may shoot |
| Rukkatrukk Squigbuggies |1–2 models; post-shot non-Monster/Vehicle target must actually be hit by Squig Launchas; incoming status gives that target’s attacks hit−1 through next own turn |
| Stompa |22 Infantry seats/Ghaz4; permanently riled source passive; selected-disembark passengers riled through next own turn; printed2D6 Demise and five separate Big Shootas |
| Trukk |12 Infantry seats, no Ghaz/Jump Pack; Deck12; independent weapon/extra choice; opponent enemy-move-end within8in of actual carrier offers its passengers rapid disembark |
| Warbuggies |1–2 independently equipped vehicles; own-Movement visible non-Monster/Vehicle target within6in cannot be targeted with Fire Overwatch through turn |
| Wartrakks |1–2 models; each needs friendly non-Wartrakk Speed Freeks support within3in for Lone Operative; post-hit Busted makes friendly Speed Freeks attacks against that target Lethal through turn |
| Wazbom Blastajet | Optional gun swap, extra gun and force field; selected field gives InSv5/removes Smoke; own-Shooting wound+1 against Monster/Vehicle |
| Wazdakka Gutsmek | Mandatory own-Command engine selection through next own Command; Turbo permits Advance/Fall Back charging; Shokk optionally withdraws; Pulse Jet uses the faction special move below |
| Weirdboy | Support/psyker level1; once-army/round Da Jump rolls, withdraws and grants phase-duration unit Deep Strike; selected-Fight Warpath gives melee wound1 rerolls/Psychic |

All27 remaining printed “Lethal Hits: non-Monster/Vehicle” profiles retain
actual negative keyword predicates. ANTI and conditional Devastating Wounds
retain their own target clauses. Multiple profiles share one physical group;
duplicate physical weapons have separate groups. Nazdreg’s explicit exception
is per equipped ranged profile. No stored floating-point coordinates or custom
lifecycle methods are introduced.

## Deliberate geometry approximation

On2026-10-15 the user directed large temporary circular bases for cards marked
“Use model.” These are **arbitrary approximations**, not measured dimensions:

| Hull family | Temporary circular diameter |
| --- | --- |
| Battlewagon, Gunwagon, Big’ed Bossbunka |160mm |
| Mek Gunz |100mm per gun |
| Stompa |240mm |
| Trukk |140mm |

Passing `hull_mm = 0` selects that documented approximation. A positive bounded
millimetre diameter replaces it. `Profile.base_size()` remains0 for these source
cards; `ModelGeometry.proxy_diameter_mm` supplies the explicit proxy through the
shared radius/measurement helper. The short axes of actual oval bases remain
in immutable metadata; intentional long-axis circles remain the current policy.
All placements and inputs stay on the whole-quad44×30 grid.

Core p10/P10-06 says an M of “–” permits setup but forbids other movement.
The shared segment, rotation, movement-selection, charge and melee-lock guards
apply that restriction, including replacement-distance moves. Aircraft still
use ingress/setup instead of ordinary movement. Their printed OC “–” remains
unmodifiable.

## Timing, identity and bounded ownership

Six window sources join existing ordered pending events: both bombs, both
Fight-end withdrawals, Shadows ingress and Full Throttle. Mandatory effects
cannot be skipped while a legal target exists. Race joins normal move-start/end
events and keeps one army-round budget across both windows. Makari includes
army units offboard without inventing range/visibility to them. Typed source
keys own expiry, including next-own-Command for engines.

Registered unit sources also recheck the live conferring ability when offered.
An attached Snikrot or Wartrike dying disables its remaining windows even when
bodyguards survive; keeping the registration does not preserve a dead model's
ability. Accepted persisting effects still follow their recorded duration.

The new psychic roll frame is shared by Warpath, Beastscent and Da Jump. It
spends the same per-round level budget as Wurrband and one use per named
ability/phase. A psychic1 shocks the caster but does not cancel the printed
effect. A caster removed by a shock reaction cannot subsequently be moved or
receive a new effect. Da Jump’s unspecified duration follows the supplied
appendix01.02.02 phase default: its Deep Strike is available for same-phase
arrival, rather than permanently modifying the roster.

Hit bookkeeping distinguishes Squig Launchas hits from all other hits and
keeps that distinction during identical-attack grouping. Matching Mek Gunz
checks physical weapon names. Resulting attack modifiers retain separate
contributions for the existing arithmetic/cap/ignore-choice pipeline.

Ordinary and reactive exits share one context-owned Disembark frame. Tactical
follow-up Movement belongs to MovementPhase after the exit completes; a
Disembark frame therefore cannot recursively own Movement→Pilin’ Out→Disembark.
Callers copy only the completed flag, mode and passenger slot before reusing a
shared frame. Reactive passenger iteration records stable identities across
bank compaction. The psychic frame also has one shared slot; other new frames
have one game owner. Generated init/drop handles every owning field.

Godot preserves single-enum, single-UnitID/ModelID, boolean and BoardPosition
inputs. Named controls distinguish psychic/engine/split choices; Makari,
passenger and formation-model selectors use their actual bank, with battlefield
click inference disabled for those bank choices. Rules.gd and TraceManager.gd
remain unchanged. Schema35/23/35 and next36 require regenerated bindings.

## Limits and follow-up

Home objectives require an explicit mission `Objective.home` assignment; a
marker index is never guessed. Exact hulls/ovals/bodies and continuous geometry
remain deferred by user policy. Points and detachment prices remain excluded;
CP costs and limits remain active. The public starter still selects its three
families; arbitrary roster selection and the existing performance/rendered
integration issues are mandatory17.Q work. Adapter completion does not certify
those journeys. See ROADMAP.md for actual test/fuzzer/Godot evidence.
