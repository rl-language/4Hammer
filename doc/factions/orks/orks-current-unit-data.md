# Current Orks profiles and loadouts:17.H1

This is the data step of17.H, covering Beastboss, Beast Snagga Boyz and Squighog Boyz. It adds current constructors in [orks_unit_data.rl](../../../src/factions/orks/orks_unit_data.rl), five model profiles and12 unique weapon profiles. 17.H2 adds their special abilities;17.H3 now uses user-authorized circular proxies for oval bases. The public starter now uses these adapters (17.H4); see the roster/passive guide. All54 standard Orks units remain planned; Forge World/Legends and points/detachment prices are excluded.

Sources are the retrieved11th-edition version1.2 HTML cards from2026-10-12:

- [Beastboss](https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss)
- [Beast Snagga Boyz](https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz)
- [Squighog Boyz](https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz)

The audit text extracts omit the separate invulnerable-save boxes and Hunter keyword header. The implementation uses the HTML tables, including those elements. `tools/check_orks_unit_tables.py` compares the compiled profile/weapon statistics directly with the HTML; its input is the cached source directory rather than copied implementation values.

## Model profiles

| Model | M | T | Sv | InSv | W | Ld | OC | FNP | Base |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Beastboss |6|6|4+|5+|6|6+|1|6+|50mm circle|
| Beast Snagga Boy |6|5|5+|6+|1|7+|2|None|32mm circle|
| Nob in Beast Snagga Boyz |6|5|5+|6+|3|7+|2|None|32mm circle|
| Squighog Boy |10|6|4+|6+|3|7+|2|None|75x42mm oval|
| Nob on Smasha Squig |10|6|4+|6+|4|7+|2|None|90x52mm oval|

M is in inches. These are new current enum entries; historical profile/weapon entries retain their IDs as explicit legacy fixture data. The current constructors inherit none of the legacy Morgrim/Beast Snagga/monster-hunter abilities. Squad members receive the printed keyword set and ORKS/Waaagh! metadata; Beastboss receives Character/Warboss/Da Boss and the exact Leader permission list. Current names use the existing compact catalog identities.

`profile_base_width` exposes the supplied short axis as immutable profile metadata. It adds no stored float. The user now authorizes long-axis circle proxies:75mm for Boys and90mm for Nobs, with `unsupported_footprint` false. `profile_has_oval_base` preserves the source shape. All distance, overlap, setup, path and rendering consumers use the same diameter on whole-quad anchors. Rotation does not change a circular proxy. Exact oval geometry is deferred. Hull dimensions remain separately unavailable.

## Constructors and composition

| Constructor | Accepted data |
| --- | --- |
| `make_orks_beastboss()` | One Beastboss with Shoota and the combined Beast Snagga Klaw and Beastchoppa |
| `make_orks_beast_snagga_boyz(nobs,boys,thump_guns)` |1–2 Nobs,9–18 Boys; zero to one additional Thump Gun per ten total models |
| `make_orks_squighog_boyz(nobs,boys)` |1–2 Nobs on Smasha Squig,3–6 Squighog Boys; temporary long-axis circle proxy |

The independent printed ranges are preserved, including intermediate totals. Prices are ignored; the10/20 and4/8 price rows do not invent additional composition constraints. Thump Guns equip Boys and augment their default Choppa/Slugga; they replace neither. Nob equipment remains Power Snappa/Slugga. Every Boy has both Choppa profiles as alternatives of one physical weapon. The Hunter profile requires MONSTER/VEHICLE, meaning either keyword, on the target unit.

Squighog Nobs have Big Choppa, Slugga and Squig's Jaws. Boys have Saddlegit's Shiv, Squig's Jaws and both ranged/melee Stikka profiles of one physical weapon. Jaws are Extra Attacks. Big Choppa has S7/Cleave2; the melee Stikka has no inherited Lance. Shoota/Slugga have conditional Lethal Hits excluding both MONSTER and VEHICLE; the combined Beastboss melee weapon has conditional Sustained Hits2 against either. Thump Gun has fixed3 attacks and Anti-Monster/Vehicle4+, with no inherited D3/Blast.

Stored state continues to use bounded/linear integers, Bool and enums, with generated lifecycle. Constructor counts are checked transient inputs; starting strength/model/weapon vectors are bounded. The caller assigns owner and stable identities through the existing Board APIs before attachment/saving. UnitRole/permission metadata is configured explicitly. The five profiles and12 weapon entries change enum/keyword interpretation, so state/observation schemas are31, with next-state32 and action schema19 after17.H4/17.I1.

## Capacity review

These families require at most four stored profiles per model: Boy with additional Thump Gun, or Squighog Boy. Maximum combined Snagga strength is20+one Leader+one Support=22, within the32-model envelope. The54 included-card inventory remains the active scope. Raw table row counts are alternatives, not equipped weapon counts: Boyz's15 rows do not establish15 owned profiles. Included Stompa has nine physical weapons and ten stored profiles (five Big Shootas plus two Supa-gatler alternatives), so the historical eight-slot limit remains insufficient. Keep the validated13-profile envelope; actual quotas/copies for the other families remain their17.H–P adapters. Excluded Kill Tank data is not a playable-loadout obligation.

## 17.H progress and remaining work

- 17.H2 (implemented/tested): Dodge Dis!, shared once-per-army-round Keep Huntin', Mobbed, Bomb Squig and Brutal Impact, each with source lifetime, real timing/ownership/target choices and damage/shock integration.
- 17.H3 (implemented/tested within user circle policy): use the user-authorized75/90mm circular proxies consistently; exact oval geometry is deferred.
- 17.H4: the public starter uses the current adapters; actual Warlord, attachment, save, combat and complete-game validation is recorded in ROADMAP.md.

The public starter fields these three current families. This does not certify the other51 included cards or other detachments. Read [the roster/passive guide](orks-roster-war-horde.md) for the production flow and War Horde scope. Healing/revival remains17.J and full rendered journeys/wrapper performance remain17.Q. [ROADMAP.md](../../../ROADMAP.md) records executed validation and the next subtask.


## 17.H1 executed validation (historical)

All709 CTest entries (707 assertions plus two fixtures),25 focused unoptimized native sanitizer/leak cases, the independent HTML statistics check and current/previous Godot binding controls pass. The matching optimized sanitized fuzzer passes preserved and completed-game inputs plus31 fresh mutation runs without failures. Gym remains finite with unchanged tensor dimensions and schema29 semantics. The public legacy-roster game completes1,000 legal actions; current constructor behavior is validated by focused fixtures. See ROADMAP.md for exact logs, corrected exploratory failures and remaining work.


Combined17.H2/H3 adds31 regression cases and current abilities/circular proxies. All738 supported assertions have passing executed results across the initial full run and corrected affected rerun;56 focused native sanitizer/leak cases, HTML comparison, five Godot controls, ML, complete-game replays and fuzzing pass. Read [the ability report](orks-current-unit-rules.md) and ROADMAP.md for current evidence and the remaining17.H4 roster switch.


Additional adapters are documented in [the twelve-card guide](orks-infantry-walkers.md)
and [the fourteen-card guide](orks-elites-meks-gretchin.md). Current adapter
coverage is29/54 standard cards; arbitrary public roster selection remains17.Q.
The current three-family starter and exclusions above are unchanged.
