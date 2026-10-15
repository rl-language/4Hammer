# Named selectors — batch17.C2c

Authority: the [67-datasheet Orks audit](factions/orks/orks-codebase-audit.md), [source identity crosswalk](factions/orks/orks-named-identities.tsv), supplied keyword scope appendix02.05.01, multiple profiles appendix04.01.03, core selection/grouping pp.16–17, weapon abilities p.78 and Firing Deck p.81. Hunta Rig's Fully Loaded Butchery specifically names Butcha Boyz; Big Mek With Shokk Attack Gun's Support Shokka excludes that named datasheet. These sources require identities beyond broad INFANTRY/ORKS keywords or display strings.

## Identities and scope

The catalog contains67 Orks datasheets,139 physical weapon families and176 named profiles. Its330 source rows include standard datasheet profiles and referenced ability/enhancement profiles; the crosswalk labels those scopes separately. Standard row counts match the existing audit for every datasheet. Case and apostrophe/hyphen spelling aliases share a catalog identity. Stikka, Grabba Dragga and Snagga Klaw require separate ranged/melee profile identities despite identical printed names. Known identity tags must match the actual profile's ranged/Melee category.

Catalog enums provide typed queries and editor labels; stored fields use ordinary LinearlyDistributedInt codes. Code0 is explicitly unknown. Legacy factories are not silently assigned current datasheet identities, and these names do not import stats, equipment permissions or actual faction grants. IDs are append-only within a storage schema; reordering them requires a schema migration.

Each model retains its datasheet identity and per-slot weapon-family/profile identities, including through copy/archive operations. Unit matching considers the union of current constituent identities, while model matching remains local (02.05.01); active/range/keyword/attachment eligibility remains the source rule's separate responsibility. Datasheet-filtered model characteristic grants affect only matching constituents. Attached-unit lifecycle remains17.G.

Characteristic selectors are conjunctive: optional physical instance/slot, named weapon family and named profile. A family selector applies across all equipped copies/profiles of that family; a profile selector excludes alternate named profiles. A physical-instance selector uses one owned representative slot and the existing nonzero profile group. Group0 means only that slot; an unrelated copy never inherits the grant. Named/physical rule-grant helpers feed the existing per-slot weapon-rule declarations. Source installation/expiry remains17.E; no new Orks effect is made active by this batch.

Declarations snapshot the selected family/profile identity. Actual Range, skill, S, AP, A and D consumers use those identities with current bearer grants. Firing Deck snapshots the passenger weapon's name, applies the carrier's matching family/profile-wide numerical grants, excludes the carrier's equipped-instance grants, and never imports passenger-unit numerical bonuses. Existing equipped-profile rules and carrier temporary rule policy remain intact (p.81).

Restore validation checks catalog bounds, profile/family/category consistency, grouped-family consistency and unused named slots in live/archived models. Invalid named selectors on model-only characteristics and physical selectors without a representative slot are rejected. Generated lifecycle methods own every new field.

Schemas: state/observation22, action14, next-state23. Grid/action domains and Rules.gd/TraceManager.gd are unchanged. Regenerate matching native libraries and Godot headers together. Full stats/loadouts, named source abilities, compound profiles, Damaged and incoming reductions retain their later roadmap owners.

Final frozen CTest passes534 assertions /536 registered entries in280.40s, with an empty discrepancy manifest (`/workspace/4hammer-validation/task17c2c-final-ctest.log`). All25 focused native cases pass ASAN/UBSAN and leak detection (`task17c2c-final-sanitized.log`, prepared driver `task17c2c-final-sanitized/driver`). Earlier builds without `final` predate the ranged/melee catalog correction and are superseded.

Matching generated header/native/C++ bindings in `task17c2c-final-godot` pass the named and prior weapon scripts (`task17c2c-final-godot.log`, `task17c2c-final-godot-weapon.log`). The named script uses an explicit generic fixture and existing physical groups; full interaction/rendered journeys were not rerun.

Gym passes20 steps,22,379 action candidates and17,523,864 finite observations (`task17c2c-final-gym.log`). Compact identity/scoping adds472,417 observations, about2.8%. Both preserved lifetime inputs and fixed zero input pass the final fuzzer (`task17c2c-final-replay-preserved.log`). Fresh short-seed mutation fuzzing completes50 runs in62s, coverage8,331 /features14,019, without failures/artifacts (`task17c2c-final-fuzz.log`).

Current-schema seed40000 completes878 actions at terminal owner-4 (`task17c2c-final-gameplay.log`, `task17c2c-final-replays/full_game-seed-40000.{bin,json,trace}`). Its final sanitized replay passes in32.531s (`task17c2c-final-replay-game.log`). These scaffold-roster checks do not certify current Orks datasheets.

17.C2c/17.C2 are complete. Next is17.C3, Damaged, followed by17.C4. Task17 and actual Orks profiles/abilities remain pending.
