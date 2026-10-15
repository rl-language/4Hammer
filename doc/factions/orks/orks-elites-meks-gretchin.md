# Orks elites, Meks and Gretchin

This fourteen-card batch uses the 11th-edition version1.2 cards retrieved
2026-10-12 from `https://wahapedia.ru/wh40k11ed/factions/orks/<slug>`.
ROADMAP.md records completion and executed checks. The independent HTML checker
compares every printed profile, invulnerable save and weapon row; regression
scenarios establish the ability semantics separately.

| Cards | Adapter and behavior |
| --- | --- |
| Flash Gitz | Kaptin plus4–9 Gitz; one physical Snazzgun with three profiles; own-Shooting AP improvement if source or target is near an objective |
| Meganobz |2–6 independently equipped models; five legal gun/melee combinations; incoming AP worsened; riled Fight hit bonus |
| Mek | Support permissions; ranged Ignores Cover; actual bearer-to-vehicle-model repair at move start/end; separate cumulative hit grants until next own Movement |
| Big Mek | Independent Drilla/Traktor swaps; ranged Ignores Cover/riled Sustained Hits; optional Advance result6, model traversal and per-model hazards |
| Big Mek in Mega Armour | Four gun/replacement choices and three optional extras; ranged-only unit4+ InSv; once-per-battle Command healing |
| Big Mek with Shokk Attack Gun | Printed ranged/compound profiles; More Dakka; standalone Lone Operative from nearby eligible friendly Infantry |
| Painboy | Support; mandatory Command healing plus optional once-per-battle D3 extra wounds |
| Painboss | Support; once-per-battle Beast Snagga healing within6in; stronger-S wound protection; existing Mounted attachment transformation |
| Breaka Boyz | Nob plus five Boys; checked independent replacements, Hunter hammer profiles, two Bomb Squigs and ordered charge+1 |
| Tankbustas | Nob plus five Boys; independent physical launchers, Hunter profiles, optional Pulsa equipment; once-per-battle target-identity AP/Lethal grant; post-hit Battle-shock; two Bomb Squigs |
| Warboss in Mega Armour | Leader, Da Boss, two transport seats, shared Intimidating Motivation budget and charge-end engaged-model mortals |
| Gretchin |10–20 models; one seat per pair rounded up per unit; actual-control objective securing |
| Runtherd | Support; optional round-limited direct destruction of D3 actual Gretchin to remove newly gained Battle-shock |
| Zodgrod Wortsnagga | Epic Hero Leader; source-bound riled permission and named Scavenged Shivs A/WS/S improvements |

`orks_elite_data.rl` owns exact factories and checked equipment alternatives.
`orks_elite_rules.rl` owns source adapters and the added healing, repair,
Battle-shock, shooting and charge actions. Existing source-event windows provide
controller sequencing; no parallel priority system is introduced. Original
component identities retain token use through attachment, casualty compaction,
revival and saves. Repair prototypes are reused across turns; each accepted
repair still installs its own effect key for cumulative modifiers and expiry.

Unit healing delegates to the faction-independent `Board.shared_actions.heal_unit`
frame in `healing_rules.rl`, with the complete allowance rather than three-wound
chunks. It heals wounded live models
before returning archived non-Characters, preserves original identities and
weapon-use history, clears death-only flags and asks for a legal grid position
on the battlefield. Offboard own-unit healing requires no external range
measurement; returning embarked models must fit the carrier's capacity. Gretchin
capacity is computed for the entire passenger unit, including ordinary attached
Character seats, and is recomputed when returning a model. Runtherd destruction
uses the ordinary destruction pipeline without adding wound prevention rolls.

Ranged-only force fields are allocation-group save inputs, so they cannot
silently grant melee InSv. Target AP and hit contributions enter the existing
modifier/ignore/cap pipeline. The hit-contribution bound includes all sixteen
possible per-model effect grants plus four unit contributions; every offered
modifier and selected result fits the corresponding fifty-choice bound.

All seventeen new model profiles have printed circular bases. Stored positions
remain whole quads, with transient floating-point distance calculations. All
persisted numbers remain bounded/linear integers, Bool or enums, and lifecycle
methods remain compiler-generated. No prices, Forge World or Legends are added.
The three-family public starter remains the current public roster; arbitrary
roster selection and complete rendered journeys remain17.Q.
