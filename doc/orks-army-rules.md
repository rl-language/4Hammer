# Waaagh!, riled-up, War Cry and Da Boss —17.F

This batch implements the current shared Orks army-rule consumers and pre-formation Warlord selection. It does not replace legacy profiles or certify any current datasheet. Only the54 standard Orks cards remain planned; Forge World and Legends stay excluded.

## Authority

[Orks Army Rules: Waaagh!, War Cry and Da Boss](https://wahapedia.ru/wh40k11ed/factions/orks/) were retrieved2026-10-12. The cached Army Rules section says:

-  Friendly ORKS units with Waaagh! may re-roll Advance rolls and become riled up as other rules state.
-  While riled up, a unit has5+ InSv; its ranged attacks have Assault; when selected to Advance, that Advance does not prevent declaring a charge.
-  War Cry is once per battle per army, at the start of **the** Command phase. Friendly ORKS units with Waaagh! become riled up until the **end of the next turn**.
-  At battle-round start, gain1CP if a model with Da Boss is the selected Warlord.

There is no old-edition melee A/S boost in this wording. These are web sources, not core-PDF quotations.

The user supplied the full Warlord selection definition on2026-10-13; it is retained in [the supplied reference](11th-edition-supplied-appendix.md#select-your-warlord--user-supplied-during17f). Select an army-faction CHARACTER unit, then an eligible CHARACTER model; it gains WARLORD. Required units/model rules restrict the choice; cannot-be-Warlord overrides required status. [Ghazghkull](https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka) specifically requires its model, represented separately from a unit-level requirement.

Permanent unit-riled wording is supported by [Stompa: Waaagh! Effigy](https://wahapedia.ru/wh40k11ed/factions/orks/Stompa) and [Zodgrod: Super Runts](https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga). Their actual factories, profiles and other abilities remain their datasheet batches.

Core pp.33–35/36–37/65/81 supply ordinary movement, shooting, charge, transport and Firing Deck restrictions. Appendix01.02.02/01.02.04 supplies persistence and offboard rules;02.02.01 supplies save arithmetic. Appendix08.02.01 defines Core CP without the inherited extra-CP ceiling.

## State and consumers

Models have explicit Waaagh!/Da Boss/permanent-riled metadata, Warlord prohibition/required-model flags and a checked list of eight owned riled-effect keys. Units can carry a required-Warlord-unit flag. ArmyConfiguration keeps the selected model’s stable identity and once-per-battle War Cry usage. ORKS and WARLORD keywords are appended to the existing enum; legacy roster names do not supply these new flags.

A typed `RiledUpGrant` uses the existing source-instance/effect framework. It installs one status key on each live recipient, so overlapping permanent/timed copies remain independent. A model selects the better printed/riled base InSv before applicable characteristic modifiers. Equipped and borrowed ranged profiles receive Assault with that effect key; melee receives no Assault. The declaration consumer checks key activity, preventing a stale snapshot from restoring an expired grant. Firing Deck uses the carrier’s riled status without rewriting the passenger’s weapon.

The actual Advance sequence uses Waaagh! for its free re-roll, retaining original-dice/one-re-roll/CP ownership. `UnitHistory.advance_allows_charge` snapshots riled eligibility when Advance is selected. Later expiry preserves that Advance’s exception, while a later buff cannot retroactively grant it. Turn reset clears the snapshot across all banks; same-turn repositioning preserves it. Fall Back, engagement, Aircraft, actions, ingress and unrelated transport charge locks remain.

Permanent source-bound status uses a distinct own-unit passive mode. It follows the source model’s current containing unit, also in reserves/passengers, with no external range/visibility measurement. Source death/disablement removes its copy; transfer removes the old-unit copy and installs a new-unit copy. Returned members refresh without duplicate grants. Existing external auras retain battlefield/range/keyword conditions. Source/key capacities remain64 instances/effects and4096 monotonic keys, with asserted overflow; later actual adapters must review combined army requirements.

## Timing and Warlord decisions

A separate one-enum Orks timing input joins the existing current-player/opponent controller groups. Each controller may order it with their other eligible effects. War Cry is optional at either Command start; finishing without it spends no use or CP. Accepting creates one disabled source record owning grants to all currently eligible friendly units across battlefield/reserve/passenger banks. Effects require no ongoing live source. End-next-turn expiry occurs after that turn’s end-window effects, not at next-turn start or at activation-turn end. Source expiry reaches archives.

Da Boss is mandatory at round start: finishing is blocked until the selected live Warlord’s rule resolves. It gains literal1CP once in that controller’s window; the opposing player’s rule is separate. A destroyed/foreign/different boss does not substitute for the Warlord. An offboard selected Warlord can use its own rule. Da Boss does not pass through the legacy `obtained_extra_cp_this_round` flag: the supplied11th-edition rule/appendix gives no such ceiling. Core CP remains the separate Command step. Other inherited CP consumers remain their source-data owners.

Orks army selection delegates Warlord choice before formations. The first UnitID addresses the reserve roster; the second ModelID addresses the chosen unit. Preconditions exclude foreign units, missing faction/Character keywords, prohibited models and spare selector indices, and respect eligible required-unit/model choices. Stable identity and the WARLORD keyword survive model transfer/death. Invalid saved identity/ownership/status handles are rejected. A legacy roster lacking current ORKS metadata has no current Warlord choice; current roster/profile migration remains17.H–P, rather than manufacturing a certified model from its old name.

Source rule codes100 (War Cry) and101 (generic source-bound permanent riled) are reserved here. Permanent copies belong to separate model handles; equal display names never imply shared usage restrictions.

## Godot and compatibility

The choice panel offers named Warlord unit/model buttons and War Cry/Da Boss labels. InteractionManager suppresses battlefield clicks for both offboard Warlord selectors. UnitID/ModelID/one-enum payload shapes remain standard. Rules.gd, TraceManager.gd and small whole-quad coordinate domains are preserved.

Schemas are state/observation27, action17, next-state28. Matching native/header/C++ and ML policies are required. The catalog has22,746 candidates (+66, about0.29%) and26,128,335 finite observations (+95,367, about0.37%) relative to17.C4b. All added authored persistent numbers use bounded/linear/Bool/enum types. Generated lifecycle remains; no custom init/drop was added.

## Validation

Final RLC/core0.4.17 with four workers; unoptimized debug native/CTest/Godot, separately optimized sanitized fuzzer; Clang21 and Godot4.6.3.

- 648 supported assertions, empty discrepancy manifest:650/650 CTest entries pass in315.50s (`task17f-tests`, `task17f-ctest-final.log`).
- All29 focused cases pass the unoptimized Address/Undefined/LeakSanitizer driver with leak detection (`task17f-sanitized/driver-final`, `task17f-sanitized-final.log`).
- Matching Godot artifacts pass actual Warlord unit/model methods/buttons, offboard click suppression, mandatory Da Boss and War Cry labels/status, plus preceding modifier controls (`task17f-godot-check-final.log`, `task17f-godot-modifiers.log`). Full rendered journeys remain17.Q.
- The20-step Gym check passes the finite layout above without tensor warnings (`task17f-gym.log`).
- The optimized sanitized fuzzer passes both preserved lifetime inputs, zero input and the preceding878-action game; the full-game replay takes70.571s (`task17f-replay.log`). Fresh short seeds execute43 mutation runs in64s, coverage13,935/features22,861, without sanitizer failure or crash artifacts (`task17f-mutation.log`).

Fresh schema27 seed40000 completes878 actions with terminal owner-4 (`task17f-gameplay.log`, `task17f-replays`). Its input bytes exactly match the completed-game input already replayed against the final sanitized engine.

Focused tests cover explicit eligibility, better/absent/modified InSv, ranged-only Assault, actual shooting/charge/Advance re-roll consumers, charge snapshots and retained restrictions, both controllers/declines/once-per-army use/wrong windows, exact next-turn expiry, reserves/passengers/source death/archives, permanent overlap/idempotence/offboard transfer/current-unit following/death, mandatory Da Boss/owner/identity/life/offboard/literalCP, saved/forged status, stale Assault snapshots, actual Warlord choices/required models/prohibitions/unit-faction and Character conditions/multiple required units, and borrowed carrier Assault.

Initial failures were an obsolete schema26 test expectation and a transfer fixture’s wrong destination slot; corrected assertions above pass. The new Godot harness was corrected to use generated class getters, production-normalized labels and release its owned RLCLib object; final checks retain leak rejection. Legacy roster games do not carry the new army-rule metadata, so focused fixtures establish these semantics and full-game/fuzzer checks establish integration. Actual current profiles, source-specific riled reactions, attachments and all remaining units retain their roadmap owners. Next is17.G.
