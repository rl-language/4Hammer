# Task 9 — attack declarations and dice pipeline

Authority: core rules pp.16–23 and ability definitions pp.79–82, plus [the user-supplied appendix](11th-edition-supplied-appendix.md). Preserve whole-inch quads and the user-approved terrain-area visibility abstraction. Attachments remain deferred.

## Implemented behavior

Select each bearer's weapons before any target resolution. Declare targets for each weapon with per-model range, visibility and engagement legality; reject duplicate selections. Fixed-A melee shares must allocate the entire budget among distinct eligible targets. By user instruction, random-A melee weapons are assumed not to exist: declaration asserts fixed A instead of supplying a speculative split policy.

Resolve the chosen target completely before choosing the next. Select a declared weapon to gather all unresolved identical attacks against that target. Identity includes effective skill, strength, AP, damage characteristic, applicable rule presence/magnitude and relevant target protection. Determine random A separately for each weapon before combining counts. Stable model identities preserve declarations across compaction; dead bearers and nonviable targets cannot produce empty allocation choices. Invalid unresolved targets can be replaced under supplied appendix 04.03.03.

Collect original hit/wound/save dice into bounded face histograms before exposing reroll choices. Eligible original results are tracked separately from replacements, preventing a second reroll even when the replacement has the same face. Resolve replacement effects before modifiers. Restore decision roles after nested attacks; explicit chance actions retain owner −1. Commit Command Re-roll expenditure before its chance outcome. Random characteristic rerolls retain the entire represented roll's domain.

Natural one fails; natural six is critical. Exact doubled/halved Strength boundaries are inclusive. Apply cumulative hit/wound modifiers with net ±1 limits. Lethal Hits applies only to critical hits; Sustained Hits extras wound normally; Anti uses target unit keywords and its lowest applicable positive threshold. Snap Shooting hits on an unmodified six. Parameterless abilities use presence rather than numeric magnitude.

Fixed characteristics now return their actual bounded values. All three remaining baseline discrepancies are fixed and promoted unchanged; an empty discrepancy manifest is permitted but an empty supported suite remains an error.

The modifier helper uses replacement, multiplication, addition, division, subtraction and final upward rounding, preserves unmodifiable/zero replacement characteristics, and supplies characteristic/roll/charge/CP bounds. Signed modifier state uses a bounded magnitude plus a sign flag for standard ML inference. Existing cover skill and detection consumers apply supplied limits; future effect consumers must use these helpers rather than being assumed integrated automatically.

## Actions, bindings and storage

State/observation schema **8**, action schema **4**. Regenerate the matching Rulebook library, Godot header and C++ extension together. Existing source-first two-UnitID and one-UnitID selectors remain discoverable by the production editor. New finite `choose_attack_weapon`, `assign_attacks` and `select_reroll` choices have explicit choice-panel buttons. Dice remain chance actions. New frame values use standard bounded counters/checked collections; identity metadata remains the existing non-ML infrastructure.

Shared Board/declaration data uses `ctx`; suspended per-weapon gathering uses value `frm` snapshots. Complete pure grouping comparisons before suspending for random A. Avoid ordinary locals/references whose values would be needed after a child action resumes. Use unique persisted field names within a frame so Python/Godot exports remain valid.

## Required follow-up fixes

Task 10 must replace `resolve_legacy_attack_damage`: its single-model allocation and aggregated damage do not implement the new save groups, per-attack allocation, overflow/mortal rules or destruction timing. Its legacy save/AP handling, Hazardous and fight-on-death paths require correction and explicit tests. Passing task-9 hit/wound tests do not certify these downstream rules.

Task 11 supplies explicit movement-mode state; Heavy currently uses the legacy `has_moved` proxy. Task 12 must implement complete ranged modes/pistol restrictions, Lone Operative, remaining parameterless consumers and all weapon-ability interactions. Task 14 replaces complete melee sequencing/fight-on-death behavior. Task 15 integrates other combat stratagem effects. Task 17 supplies authoritative profiles, missions and faction data. Multiple Weapon Profiles remains a source gap. Random M/other random characteristic consumers and dice-expression representation must be implemented with their owning tasks and supplied data.

Interactive GUI rendering remains outside the headless harness; the area-only visibility approximation and deferred attachments are unchanged.

## Validation

**171 PASS, 0 XFAIL, 0 XPASS**; CTest **173/173** entries pass. Matching optimized/debug/check-enabled native/Godot bindings pass the production weapon/group buttons, target clicks, batch chance ownership and pending-attack save restoration. Melee-share buttons are supplied, but this shooting harness does not exercise them interactively.

Seed 40000 completes full/shooting scenarios in **942/9 actions**; the fresh gym checks 20 legal steps with **12,551** candidates and **201,437** finite observations. Existing CLI smoke checks execute 200 bounded full-game actions and complete three shooting games.

The freshly built sanitized fuzzer replays both completed inputs and the original geometry regression with no reported failure. Its campaign completes **31 runs in 72 seconds**, coverage **7,393**, features **15,106**, without failure artifacts. Leak/precondition/bounds checks remain enabled. These checks establish exercised stability, not comprehensive semantic coverage. Native artifacts and logs remain outside the checkout under `/workspace/4hammer-validation`.
