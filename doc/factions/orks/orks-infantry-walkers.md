# Twelve additional current Orks adapters

Sources are the 11th-edition version1.2 cards retrieved2026-10-12, under
`https://wahapedia.ru/wh40k11ed/factions/orks/<slug>`; the cached original HTML
supplies invulnerable saves omitted from the text extracts. See
[ROADMAP.md](../../../ROADMAP.md) for validation and completion status.

| Cards | New mechanics |
| --- | --- |
| Boyz, Nobz | Literal composition ranges; independently checked per-model replacements; unit Ammo Runts; charged Lethal Hits; engaged action waiver; charge traversal excluding Monster/Vehicle; bearer-only Paired Krumpas rerolls |
| Warboss, Bigboss, Bannernob | Leader/Support permissions; bearer Ammo Runt; charged bearer A/S; shared army-round Intimidating Motivation; unit melee hit bonus; ordered charge bonus |
| Stormboyz, Warbikers | Deep Strike; optional charged fight A/S/Hazardous; charged melee S/D; shared physical combi profiles |
| Deff Dread, Killa Kans | Independent physical arm replacements and Extra Klaws; incoming D reduction; demise1; three alternate Kan Blasta profiles; hit bonus checking every live target model's effective T |
| Big Mek Dakkarig | Riled ranged Sustained Hits; target-dependent Blitzkannon A at gathering |
| Beastboss on Squigosaur, Mozrog Skragbad | Hunter restrictions and Extra Attacks; shared Keep Huntin'; nonstacking charge aura; conditional live Lone Operative; Monster/Vehicle melee wound rerolls; destroy-time2+ delayed fight; intrinsic D6+1 |

`orks_infantry_data.rl` builds source profiles, keywords, equipment and attachment
metadata. Boyz/Nobz checked loadouts express independent per-model choices; gun
profile alternatives share physical groups, while two Extra Klaws remain two
weapons. Paired Krumpas is a bounded Bool on its bearer, not a new attack profile.
No prices, Forge World or Legends are added.

`orks_datasheet_rules.rl` connects source abilities to the existing combat and
movement pipelines. Tokens113/114 use original-unit identity and battle limits;
phase effects use source generations and survive saves without refreshing use.
Existing110/112 Keep Huntin'/Intimidating Motivation budgets are reused.
Unit hit contributions retain their own ignore-modifier provenance. Selection
frames have one owner and generated lifecycle; no custom init/drop is introduced.

Charged melee and declared-target modifiers enter the normal characteristic
arithmetic. Banner and Stampede additions precede division, rounding and charge
caps. Nobz traversal applies only to charge paths and preserves ordinary final
collision checks and FLY's broader permission. Model footprints remain whole-quad
positions with transient physical calculations;75x42 Warbiker ovals intentionally
use75mm circles and retain both source axes for a later geometry migration.

The existing three-family public starter is unchanged. These twelve constructors
are available to native/Python/Godot callers and scenario/roster integration;
arbitrary public roster selection remains17.Q.15 of54 included standard cards
have adapters after this batch; the other39 still require their own data and
abilities. A source-number comparison alone does not certify ability semantics.


The subsequent [fourteen-card batch](orks-elites-meks-gretchin.md) extends
adapter coverage to29/54; the15/54 count above records17.P1's own completion.
ROADMAP.md owns the latest executed evidence and remaining25-card work.
