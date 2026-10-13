# Optional attack modifier subsets —17.C4b

The engine now supports explicit permissions to ignore WS/BS and hit-roll modifiers. Each ordinary hit can apply or ignore any subset of its applicable modifiers, including beneficial modifiers. This is generic core machinery with explicit fixtures; it installs no new Orks datasheet. The user excludes all Forge World and Legends units, including Gargantuan Squiggoth.

## Rule authority

[Appendix02.02.02, Ignore Modifiers](https://wahapedia.ru/wh40k11ed/the-rules/rules-appendix/#Ignore-Modifiers), retrieved2026-10-12, permits ignoring all or only some modifiers. Appendix02.02.01 supplies operation order, rounding, characteristic limits, re-roll precedence and the cumulative hit cap;01.05.02 retains original re-roll rules. These are appendix sources, not core-PDF page quotations. See [the retained definitions](11th-edition-supplied-appendix.md).

Core pp.17–18 require identical-attack grouping and unmodified hit gates. Heavy p.82, engagement penalties p.35, Cover/Ignores Cover pp.50/82 and Plunging Fire p.73 retain separate contributions. Damaged uses website core24.39, as recorded in [the Damaged report](damaged.md). Source effects retain supplied01.02.02/01.02.04 persistence/offboard policy.

## Data and execution

`AttackModifierPermission` explicitly distinguishes skill from hit-roll permission and any/ranged/melee attack scope. A model owns a checked list of at most8 permissions. Zero source key denotes an intrinsic fixture grant; a source-installed grant receives its own effect key. Registration, overlapping expiry, returned-member refresh and archive cleanup use the existing source framework. Saved metadata rejects invalid scopes, empty permissions and forged ownership handles.

Declaration/gathering reads the actual bearer. Firing Deck uses the carrier’s permission; a mixed unit cannot borrow another member’s permission. Gathered context stores the applicable permission flags. When permissions are present, grouping compares original skill and exact selectable operation/provenance lists as well as the existing effective attack identity. Equal all-applied sums can allow different subsets, so they cannot alone authorize grouping. The no-permission path keeps existing equivalence and aggregate classification.

`modifier_choices.rl` retains up to16 authored skill operations plus separate Cover and Plunging Fire items, for18 choices. Hit contributions retain ordinary bonus/penalty, profile bonus, Damaged, Heavy and both engagement penalties separately. Applying Ignores Cover removes Cover before constructing the selectable list.

Original hit dice and any re-rolls are collected first. For each ordinary result2–5, the source controller chooses WS/BS items, then hit-roll items. The `ChooseAttackModifiers` child persists bounded index/list/result fields and exposes one-Bool `apply_attack_modifier`: Apply or Ignore. Sequential decisions represent all subsets without an exponential mask in the global action catalog. It restores the caller’s decision owner and pending UI context. Applying/ignoring an item spends no CP or source usage; obtaining the permission remains its source’s own rule.

The selected operations use shared replacement/multiplication/addition/division/subtraction order, one final rounding and characteristic limits. Hit-roll arithmetic uses the original face before capping the net modifier at±1. Natural1/6, indirect unmodified restrictions, Snap six-only and special Torrent skill remain unchanged. No permission or an empty list produces no extra decision. Natural critical/failure results skip choices that cannot change their classification.

The integration covers explicit WS/BS and hit-roll permissions. The appendix’s unqualified permission across every characteristic/roll is broader; additional consumers belong to the source-adapter batch that introduces such an included rule (17.H–P). This batch does not certify movement, save, damage or other characteristic ignoring, nor introduce a negative-only automatic filter.

## Godot and compatibility

`MultipleChoises.gd` recognizes `RLCGameApplyAttackModifier` in its existing one-Bool path. Buttons include Apply/Ignore and the characteristic, modifier origin, operation and signed amount. The action retains one member; Rules.gd, TraceManager.gd and whole-quad coordinate domains are unchanged.

State/observation schemas26, action16 and next-state bound27 require matching native/header/C++ and ML policies. The catalog has22,680 candidates, two more than17.D/E, and26,032,968 finite observation values (+350,063, about1.36%). All authored persistent numbers remain bounded/linear/Bool/enum. Generated lifecycle owns the new collections and frames; there is no custom init/drop.

## Executed validation

RLC/core0.4.17 with four compiler workers; debug native and CTest builds unoptimized, optimized fuzzer separate; Clang21 and Godot4.6.3.

- 619 supported assertions and an empty discrepancy manifest:621/621 CTest entries pass in325.08s, including two compilation fixtures (`task17c4b-ctest-final.log`).
- 23 focused cases pass the final unoptimized Address/Undefined/LeakSanitizer driver, with leak detection (`task17c4b-sanitized/driver-final`, `task17c4b-sanitized-final.log`).
- Matching generated Godot artifacts pass the production Apply/Ignore panel and one-Bool payload checks, plus existing physical-weapon/source and characteristic checks (`task17c4b-godot-ignore.log`, `task17c4b-godot-source.log`, `task17c4b-godot-weapon.log`).
- 20-step Gym check passes with the layout above, no tensor warnings (`task17c4b-gym.log`).
- Optimized sanitized fuzzer passes both preserved lifetime inputs,65-byte zero input and the previous878-action complete-game replay; the latter takes60.824s (`task17c4b-replay.log`). Fresh short-seed mutation executes43 runs in63s, coverage13,701/features22,656, without sanitizer failures or crash artifacts (`task17c4b-mutation.log`).

Fresh schema26 seed40000 completes878 actions with terminal owner-4 (`task17c4b-gameplay.log`, `task17c4b-replays`). Its input bytes match the already sanitized game replay exactly.

Focused tests cover all eight subsets of three operations; unpermitted/empty lists; ownership and UI restoration; ignoring beneficial contributions; Cover/Plunging ordering; Ignores Cover/Torrent; Heavy/Damaged/engagement provenance and caps; bearer/kind/scope; conservative and unchanged grouping; natural/indirect gates; actual per-attack differing subsets and re-roll precedence; actual opponent ownership; borrowed carrier permission; overlapping/offboard/archive expiry; forged metadata; Game saves;18-item capacity; suspended chooser round trips; and nonadditive roll arithmetic.

Two early test fixtures had incorrect expectations/context: the Cover calculation used the wrong base skill, and the indirect fixture retained the stationary/visible exception. The final tests above correct their setup and pass; earlier failed logs are superseded. Full rendered journeys remain17.Q. Legacy rosters carry no optional permission, so completed-game/fuzzer checks establish integration and memory safety, while focused fixtures establish the new choice semantics. [ROADMAP.md](../ROADMAP.md) records the fresh gameplay result and remaining work. Next is17.F.
