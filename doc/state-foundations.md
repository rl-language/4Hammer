# Task 3 — state, identity and capacity foundations

Implemented storage foundations, not the complete new-edition mechanics. Source anchors: CP (p.30), Advance (p.33), model damage/destruction (pp.19–24), attachment components (pp.66–67), One Shot history (p.83), and starting strength/returning models (pp.86/88). The precise rule workflows remain owned by their later roadmap tasks.

## Bounded values and supported collection capacities

At the user's request, the custom unbounded `Quantity` type and its hand-written observation encoding have been removed. Stored values use standard `LinearlyDistributedInt` types, so Rulebook can infer their finite domains and linear ML layout directly. Storage domains remain separate from selectable action argument domains.

| Stored values | Supported inclusive range |
| --- | --- |
| CP | 0–256 |
| Score | 0–200 |
| Fixed characteristics and Toughness | 0–256 |
| Stat modifiers, including Advance increments | 0–256 |
| Random-stat results | 0–512 |
| Generated combat counters and wounds suffered | 0–4096 |
| Hazardous uses | 0–256 |
| Starting strength, including attachment components | 0–32 |

These are configurable supported ranges, not tabletop limits. The upper template bound is exclusive. They retain the tested CP gain above 3, full D6 Advance, damage 100, and 32-model starting strength, while restoring the standard library's bounded assignment/arithmetic behavior (clamping at the configured edges). Text parsing rejects out-of-range values, and the engine's transactional save helper preserves the destination on failure. There is no replacement custom numeric wrapper or observation function. Check new supplied datasheets/mission maxima against these bounds during task 17 rather than relying on clamping to make an unsupported configuration valid. Fixed characteristic evaluation still produces zero and remains an expected failure owned by task 9.

`CheckedVector` replaces silently truncating collections used for units, models, weapons, abilities, keywords, temporary attack modifiers and used-stratagem records. Append/resize reject overflow; `try_append` returns false without mutation. Text decoding uses an unbounded temporary vector before checking capacity, because the standard library's bounded-vector parser itself silently drops extra elements.

Configured limits are 32 battlefield/reserve unit slots per collection, 32 models per unit, 8 weapons per model, 16 abilities, 32 keywords, 8 temporary attack modifiers per collection, and 32 used stratagem records per player. These are implementation configuration limits, not tabletop restrictions. Unsupported configurations must fail explicitly; task 17 must check supplied armies against them or increase them and regenerate/version affected interfaces. Battlefield slots include retired units and are never reused during a game.

`UnitID.id`, `ModelID.id`, `BoardPosition.x/y` and action argument order retain their editor contracts. ID assignment rejects an invalid slot; finite domains remain half-open. Increasing unit/model/weapon domains changes enumeration and observation sizes even without changing public action names.

## Identity, provenance and lifecycle storage

A board allocates monotonically increasing `EntityIdentity` values to units and models when armies are selected or a unit is spawned. `-1` means unassigned and never resolves. Unit/model identity is distinct from positional action selectors.

Battlefield unit removal retires an empty slot without compacting/reusing it, so stored positional unit targets cannot redirect to another entity. Selecting an empty battlefield unit is rejected. Model removal still compacts the live model vector for existing controls; persistent model references must use `EntityIdentity` and `find_model`, which follows survivors and returns -1 for destroyed models. Later attack-group/save-group implementations must use these handles for references that cross removals.

Destroyed model snapshots retain identity, original unit, characteristics, wound state and per-weapon once-per-battle usage. Deferred fight-on-death cleanup now includes index 0 and archives removals; Desperate Escape also uses the archive path. Returning-model eligibility and consuming/restoring archived entries belong to tasks 10/11. Archives must not be copied back into the live roster while retaining a duplicate live identity.

Attachments retain each added component's unit identity, original model identities, original component starting strength and name. Combined starting strength is captured after the attachment step and before deployment, using a bounded count rather than a model index. Leader/Support permissions, bodyguard characteristic selection and detachment behavior remain task 6. Its implementation must preserve provenance when components separate.

Turn/phase serials and history fields record movement phase, ranged-attack turn, setup status, actual translated distance, action progress and per-phase stratagem use. Copies/saves preserve history. Turn-start clears setup/movement history; phase cleanup clears per-phase usage while retaining turn history and once-per-battle fields. Timing windows, restrictions, action transitions and exact movement paths are later tasks; the new fields alone do not implement their rules.

## Compatibility

State and observation schemas are version **3**; the unchanged action domain remains version **2**, exposed through `get_*_schema_version()`. Save loading parses a candidate, checks its schema and identity consistency, then replaces the destination; failed/malformed/incompatible loads leave it unchanged. Duplicate allocated identities are rejected, including archives and attachment components. The engine save helper enforces these checks. Direct Godot state assignment and automatic UI refresh after loading are unchanged; editor integration is deferred to task 17.

Godot trace parsing is unchanged and does not enforce a schema header; adding editor trace compatibility checks is deferred to task 17. Old state/action traces and trained policy dimensions are incompatible and must not be treated as current replays. The seeded runner records all three schemas in its JSON sidecar. Its `.trace` is a diagnostic TSV, not the Godot action-file format; `.bin` files are opaque fuzzer choices and require their sidecar to identify the originating schema. Old corpus bytes may be reused as arbitrary mutation seeds, not as compatibility evidence.

Raw identity/epoch integers are deliberately excluded from current ML tensors; the compiler reports this exclusion. Stored bounded values use the standard library's inferred linear observation encoding; the former custom normalization is gone. Current full-game dimensions are **7,469 enumerated actions** and **149,836 observation values**, compared with task 2's 4,499/6,551. Task 17 must integrate new policies/configuration with the new dimensions; retaining an old policy is not supported.

## Prerequisite fixes discovered during validation

Checked CP exposed an existing Overwatch underflow in seeded gameplay. Corrected actual stratagem-cost/own-player usage checks, Insane Bravery's eligibility/payer, Bestial Bellow's payer/recorded stratagem and missing target bounds, and Overwatch's affordability/opponent payer/usage-on-acceptance. Marking usage is idempotent. These are early fixes from tasks 5/15, not completion of their new timing, target restrictions or per-unit usage rules. Two cost/usage discrepancies were promoted alongside the two capacity discrepancies.

Native Godot validation also required explicit `Ref`/`RefCounted` includes in `gdexample.cpp`. `RLCLib` is an Object rather than a RefCounted instance. The test harness frees its library explicitly; changing production ownership is deferred to task 17. A capacity helper is named `has_capacity`, because `can_append` conflicts with the compiler-generated `can append` binding.

## Executed validation

- Deterministic runner: **43 passing tests**, **8 expected failures**, **0 unexpected passes**. Passing coverage includes bounded storage/ML-layout and capacity boundaries, failed decode/load preservation, schema rejection, duplicate identities, unit/model removal, provenance, starting strength, archived weapon usage, deferred removal and history resets.
- Seed 40000: full game completes in **646 actions**; shooting scenario in **11**. Payload round trips and decision-owner domains pass. Both inputs replay through the final sanitized native fuzzer.
- JIT/gym: **20 legal steps**, finite observations, current dimensions verified. Existing random smoke commands execute 200 bounded full-game actions and complete three shooting games (50 total actions).
- Sanitized fuzzer: optimized/debug, precondition and bounds checks; **376 runs in 61 seconds**, coverage 6,629, feature count 21,019; no reported crash/assertion/sanitizer failure and no failure artifacts.
- Godot **4.6.3**, regenerated bindings/native library, godot-cpp 4.3 commit `d5cc777a89d899665fb61f1650ef0dc0cf6488c4`: headless tests exercise schema exports, army choices, source/target selector shape, unit/location selection, action application, engine save loading and explicit state replacement. `tests/godot_state.gd` and `tools/check_godot_state.py` preserve the check. No interactive rendering/mouse session or full combat GUI validation was run.

Logs, matching native libraries, SDK and replay files are outside the checkout under `/workspace/4hammer-validation`. The remaining expected failures belong to tasks 7–9; completed smoke games still do not prove attack resolution while fixed characteristics evaluate to zero. Geometry, complete attachments, timing, revival, One Shot enforcement, actions and faction/mission data remain explicitly pending in ROADMAP.md.

## Bounded-storage revision validation

The follow-up restores bounded ML inference without changing `scripts/Rules.gd` or `scripts/TraceManager.gd`. The updated suite passes 43 assertions with the same 8 expected failures and 0 unexpected passes. New assertions verify the CP enumeration domain and inferred tensor size, out-of-range save rejection, and a random result of 12 beyond the former result cap. Gym again completes 20 steps with 7,469 actions and 149,836 finite observation values; the unchanged width does not make the new encoding compatible with observation schema 2. Seed 40000 again completes full game/shooting in 646/11 actions with state/observation schema 3 and action schema 2. The earlier 376-run fuzz campaign above is historical; fresh matching native/Godot bindings pass the headless check, both completed inputs replay successfully, and a sanitized mutation campaign completes 363 runs in 61 seconds (coverage 6,681; feature count 21,781), without reported failures. Added fixed/dice Stat and populated Game indented-save round trips cover the RLC 0.3.3 type-name formatting incompatibility; stable fixed/dice tags preserve the standard bounded ML types.
