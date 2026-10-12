# Fixed weapon characteristics — batch17.C2b1

Authority: supplied [Modifiers appendix02.02.01](11th-edition-supplied-appendix.md), [Multiple Toughness Characteristics appendix05.02.01 and keyword scope02.05.01](https://wahapedia.ru/wh40k11ed/the-rules/rules-appendix/), core targeting p.16, identical attacks p.17, hit/wound p.18, saves p.19, cover p.50, Rapid Fire/Melta pp.79/83, and Firing Deck p.81. This is fixed-weapon engine infrastructure, not new Orks grants or certified datasheets.

## Scope and arithmetic

The existing sparse16-entry `Model.characteristic_modifiers` list now includes `weapon_scope`: zero applies to the bearer/all equipped weapons, and slot+1 affects one owned profile slot. This ordinary linear bounded field avoids eight separate modifier vectors. Bearer BS affects all ranged profiles; WS affects all melee profiles. Source encoders choose numeric operations: an improvement of AP/WS/BS is subtraction, not numeric addition. Physical/named weapon selectors, including distributing a physical weapon grant across profiles, remain17.C2c.

`MAX_WEAPONS` and `MAX_WEAPON_SCOPES` live together in state_types. RLC0.4.14 accepts only literal const declarations, so the latter is written9 and validation checks that it equals MAX_WEAPONS+1. Later capacity work must update both. Scoped entries cannot name nonexistent equipped slots or apply weapon scope to model-only characteristics.

Target and replacement legality use effective Range. Half-range is captured against that effective declaration Range for Rapid Fire/Melta. A Melee sentinel stays Melee; a Torrent '-' skill stays unmodifiable. Weapon selection still uses the profile's original ranged/melee category.

Gathered attack info snapshots effective bounded S and the relevant skill/AP operations. Cover, Plunging Fire and explicit AP increments enter the addition step before division, subtraction, final rounding and limits. Keeping skill operations allows a later Ignores Cover grant to cancel the core increment correctly. Wound thresholds and greater-S protection use effective S; save success uses effective AP. Group comparison uses effective skill/S/AP, not raw profiles or AP-bonus bookkeeping. A/D comparison/consumers remain17.C2b2.

Every newly gathered group refreshes source/target IDs and current battlefield T. Enclosing context retains its chosen rule flags; it cannot select a different keyword subject or freeze T after earlier casualties/modifiers. Attached bodyguard-only T remains17.G. Strength/T snapshots assert capacity rather than clamp.

Firing Deck declarations are explicitly borrowed. They use the carrier's bearer-wide modifiers, while ignoring unrelated carrier equipped-slot grants; passenger-unit modifiers do not become carrier grants. The marker does not change public weapon/unit selectors. Named profile conditions and live source-instance/aura/expiry consumers retain their assigned later owners.

## Storage, bindings and validation

State/observation schemas are20, action14 and next-state21. Grid positions/action domains, Rules.gd and TraceManager.gd remain unchanged. Persisted numeric metadata uses standard bounded fields/enums; there is no custom tensor codec or lifecycle hook. Board skill/AP operation roots and live/archive scoped metadata are validated on restore; this does not claim universal coroutine integrity.

The final suite passes **497 assertions /499 CTest entries** in246.70s (`task17c2b1-ctest-complete.log`), with an empty discrepancy manifest. All20 focused cases pass native address/undefined-behavior sanitizers and leak detection (`task17c2b1-sanitized-run-verified.log`). The20 focused native cases cover scope, operation order, live Ignores Cover, actual hit/wound/save queries, effective grouping (including equivalent AP from different records), T/identity refresh, range/half-range, special values, borrowed profiles, malformed metadata and Game restoration. Prepared final native/header/C++ bindings are `task17c2b1-verified-godot`; focused headless scripts exercise the weapon and prior model APIs. Full rendered journeys/the entire interaction harness were not rerun.

**Next:17.C2b2**, Attacks and Damage, including random values/re-rolls and complete D grouping. Do not mark17.C2b or17.C2 complete. Named selectors, Damaged, incoming reductions, live effect instances and actual data remain pending in their own batches.

Final headless logs are `task17c2b1-godot-verified.log` and `task17c2b1-godot-model-verified.log`, including direct neutral-context ID assertions. The final fuzzer replays both lifetime regressions, zero input and the878-action schema20 game (`task17c2b1-replay-verified.log`, game27.236s). Its mutation campaign completes54 runs in65s, coverage11,407 /features16,683, without failures/artifacts (`task17c2b1-fuzz-verified.log`). The fixed-characteristic build completed the game before the final body-only identity correction; the final fuzzer replay is separate evidence. Legacy rosters remain uncertified.

Gym completes20 steps with22,379 candidates and17,050,509 finite observations, without tensor warnings (`task17c2b1-gym.log`). The body-only identity correction preserves that layout. The increase over17.C2a is about0.7%; action/grid domains remain unchanged. These checks certify this fixed-query batch, not random A/D or all source-dependent modifiers.

The later [A/D batch](weapon-attacks-damage.md) is now complete. Current next work is17.C2c; the historical17.C2b1 evidence above remains unchanged.
