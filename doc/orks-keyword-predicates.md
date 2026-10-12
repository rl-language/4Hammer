# Orks keyword predicates and retired runtime cards — 17.C1

Source: [Rules Appendix, Using Keywords & Mixed Keywords in Units 02.05.01](https://wahapedia.ru/wh40k11ed/the-rules/rules-appendix/), weapon abilities core p.78, and Multiple Weapon Profiles / Hunter profiles appendix04.01.03. The user explicitly retires the previous Orks implementation. This is the first sub-batch of17.C; effective characteristics, named weapon selectors, Damaged, incoming reductions and selective modifier ignoring remain17.C2–C4.

## Conditions and subjects

`KeywordPredicate` expresses the conjunction of three groups:

- Every ALL keyword must be present: adjacent keywords in the source.
- At least one ANY keyword must be present when that group is nonempty: slash/comma/or alternatives.
- No NONE keyword may be present: exclusions and non-KEYWORD conditions.

Empty groups impose no additional requirement. Conflicting ALL/NONE terms remain a literal false condition. Identical terms are idempotent; they do not consume storage twice.

`unit_matches_keywords` reads the union of the unit's current constituent models, including retained models still in the unit. Archived models are not members. `model_matches_keywords` reads only that model's own keywords. Unit conditions may therefore be supplied by different models; model conditions cannot borrow a keyword from a different bearer. Existing live-target/ability gates remain separate from keyword classification.

`WeaponRule.target_condition` replaces the previous positive-OR-only fields. The ordinary single/two-keyword constructors preserve their ANY meaning. Explicit predicate data supports conjunctions/exclusions without granting a new player action. The shared target consumer applies it to selected weapon presence/magnitude, ANTI thresholds and Hunter declarations/replacement eligibility. Duplicate selection retains the chosen instance's full condition. Removing a keyword-bearing model changes subsequent unit queries naturally.

## Storage, saves and editor

Nine total terms preserve the former first keyword plus eight alternatives capacity. Fixed keyword-code storage is partitioned into ALL, ANY and NONE groups using three ordinary `LinearlyDistributedInt` counts. The total and semantic `KeywordClause` enum are computed when needed. There is no custom observation encoding or lifecycle hook. Unknown active keyword IDs, negative/out-of-range group counts and totals over nine fail validation before lookup. Data insertion is atomic and groups retain their meaning regardless of insertion order. Conditions needing more than nine terms must explicitly expand/support the data bound; do not drop terms or weaken them into OR.

The first implementation stored a categorical tag for each term. Its ML check exposed **28,044,395 observations**, an avoidable doubling. The final grouped representation produces **14,493,920 finite observations**, about **3.9%** above batch17.B, and **22,379 action candidates**. No not-tensorable warnings occur. The reduction from23,404 candidates comes from removing the two obsolete actions; coordinate domains remain unchanged.

Saved Board pending/selected/temporary rules and live/archived model grants/Hunter conditions are checked before state restoration. Battlefield, reserve and passenger banks use the same model validation. Keyword queries also fail closed on malformed metadata. These checks extend the existing saved-state foundation gate; they do not claim that every unrelated coroutine field has general integrity validation.

Godot obtains condition count, keyword and logical clause through typed helper functions because fixed arrays do not have the required editor interface. Duplicate-ability buttons display conjunctions, parenthesised alternatives and exclusions distinctly, for example `against infantry and (monster or vehicle); excluding titanic`. The existing unit/model/grid selectors are preserved. Rules.gd and TraceManager.gd remain unchanged.

State/observation schemas are **18**, action schema **14**. Regenerate native libraries and Godot headers together; previous snapshots/action traces need their matching version.

## Retired Orks code

Tough as Squig Hide and Bestial Bellow actions and their CP enum entries are removed. Fight now enters its core Pile In step directly, without the old Orks prelude. A regression verifies both the direct transition and rejection of the old action payloads, with a valid core payload as a parsing control.

Legacy Orks profiles/factories still support several core geometry, FNP and lifecycle fixtures and the staged public roster. They are explicitly uncertified scaffolding until17.H supplies current data; they do not justify restoring obsolete permissions. No legacy compatibility requirement prevents their later removal. The four unused legacy ability labels can be retired with those factories. Source-backed Waaagh!, attachments, detachments, stratagem effects and all67 datasheets remain their assigned later batches.

## Validation

**465 supported assertions /467 CTest entries** pass in272.21s, with an empty discrepancy manifest (`task17c1-ctest-final-anti.log`). The final native focused driver passes **24 cases** under address/undefined-behavior sanitizers and leak detection (`task17c1-sanitized-run-final-anti.log`). Cases cover unit/model scope, ALL/ANY/NONE combinations, contradictions, duplicate/capacity/invalid input boundaries, insertion order, selected and temporary ANTI, Hunter targeting, casualty changes, pending duplicate selection, saves/invalid root/archive data and retirement of the old payloads.

Matching compact native/header/C++ artifacts pass the full headless Godot interaction harness (`task17c1-godot-run-compact.log`), including the compound duplicate-ability label. A subsequent body-only fix adds missing condition checks to temporary ANTI grants. Fresh matching final bindings additionally pass `tests/godot_keyword_predicates.gd`, covering the final filter through the real Godot/native boundary (`task17c1-godot-focused-final.log`). The final 467-entry suite and 24-case sanitizer driver include that fix. The full interaction harness was not rerun after this body-only change.

The compact build completes seed40000 in **878 actions**, terminal owner **-4**, and the 20-step gym check confirms the finite layout above (`task17c1-gameplay-compact.log`, `task17c1-gym-compact.log`). These checks use uncertified legacy roster scaffolding; they do not establish current Orks datasheet or detachment effects. The final-source `task17c1-verified-fuzzer` replays both preserved lifetime inputs, the fixed zero input and the878-action game with address/undefined-behavior sanitizers and leak detection (`task17c1-replay-verified.log`). The game replay takes27.717s. Fresh mutation fuzzing completes **54 runs in67s**, coverage11,391 /features16,623, with no sanitizer failures or crash artifacts (`task17c1-fuzz-verified.log`). Fixed replay and short mutation fuzzing supplement deterministic rule tests; they do not prove complete faction semantics.

Next is **17.C2**: effective characteristic consumers and named selectors. Damaged and incoming reductions remain17.C3–C4; no current datasheet is certified by this batch.
