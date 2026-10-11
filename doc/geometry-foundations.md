# Task 4: geometry and movement foundations on the quad grid

The user explicitly requires the existing quad-based game to remain in place. Model x/y positions and player `BoardPosition` choices still use the 44×30 whole-inch grid. No fractional model positions, finer movement choices or Godot grid/rendering changes are introduced. The move away from quads is a separate future task.

## Representation and source authority

`src/geometry.rl` converts whole-inch positions into micrometres for calculations against existing millimetre base diameters and inch rule limits. This changes measurement precision, not placement precision. `ModelGeometry` stores bounded whole-inch elevation (0–30), orientation (0–359999 millidegrees), and an explicit unsupported-footprint flag. Existing fixture profiles retain their circular-diameter interpretation. Oval bases, hulls, physical model bodies and their visibility are not supplied by those profiles; unsupported footprints fail placement/path checks rather than being invented.

Terrain geometry is a bounded collection of up to 16 axis-aligned solid boxes with whole-inch corners. These are supporting surfaces/solid obstacles, not terrain-category rules or mission terrain areas. Malformed or off-grid extents are rejected by engine save validation. Finer terrain, arbitrary shapes, body collisions and realistic visibility remain unsupported. Capacities are implementation limits, not core-rule restrictions.

The user supplied the missing definitions: Within means any part of any model's base is within range; Wholly Within means the whole base of every model (or of the specified model) is within range; Closest Model/Unit uses straight-line base-to-base measurement. The implementations cover nearest-base model/unit distance and Within/Wholly Within of point-centred ranges. Other shape/range-area consumers must use the same quantifiers when implemented. These definitions are user authority, not additional wording attributed to the PDF. Table Quarter and Setting Up Large Models remain unsupplied D05 dependencies.

State/observation schemas are **4**; action schema remains **2**. Existing `UnitID`, `ModelID` and `BoardPosition` domains and action payload shapes are preserved. Existing `GameSkip` is reused for cancelling move/setup decisions. Legal-choice ranks and old observation layouts nevertheless change; regenerate policies/replays and matching native libraries.

## Implemented primitives and integration

- **Measurement (p.9):** nearest circular-base points, straight-line distance with height, all model pairs for closest units, and point-range Within/Wholly Within quantifiers. Closest-vector selection now includes model zero. Point-distance consumers use base edges rather than centre-only distance.
- **Engagement (pp.14–15):** inclusive two-inch horizontal and five-inch vertical limits; any opposing pair engages units. `Board.is_in_melee` uses these checks.
- **Coherency (p.14):** every model has a neighbour within two horizontal/five vertical inches; every pair stays within nine horizontal/five vertical inches. A long connected chain alone fails. End-turn removal and its trigger exclusions belong to task 5.
- **Movement (p.12, mixed characteristics p.87):** individual model paths contain multiple straight segments and final orientation. Each model spends its own M plus a caller-supplied allowance. Horizontal segment lengths plus vertical ascent/descent accumulate, including retracing; rotation is free for circular fixtures. Duplicate/out-of-range selectors and fractional endpoints are rejected.
- **Traversal (p.12):** swept full-base clearance rejects enemy crossings and narrow gaps; friendly models may be traversed but no endpoint overlaps are allowed. Caller policies explicitly carry sourced traversal/vertical exceptions for later tasks. Battlefield edges check the complete footprint. Legacy unit translation and consolidation no longer silently clamp positions at an edge.
- **Placement/rollback (pp.12/14):** candidate copies commit only after complete coherency, base bounds, no overlaps, support and requested engagement conditions pass. Illegal choices/probes preserve positions and history. Setup checks run before reserve removal; cancellation retains the selected unit and permits retry.
- **Simple elevation/support (p.48):** full-base support is required on a box's upper surface. A roof is excluded from its solid interior. Vertical travel requires proximity within half an inch horizontally of a feature unless the supplied policy allows an exception. Keyword-specific upper-floor/traversal permissions remain in tasks 8/11.

The existing editor movement action translates a whole formation to one quad anchor while using the board-aware primitives. Independent model-path choices are available as Rulebook helpers, not new public editor actions: the current one-ModelID selector addresses the attack target, so introducing movement model selection requires deliberate task-11 UI/workflow support. Compact grid formations are preset conveniences, not a claim that every possible legal tabletop formation can be placed. Failure to find a preset can be cancelled.

## Failures found and corrected during validation

Seed 40000 stalled after action 293 in an engaged unit's legacy Fall Back movement: no legal rigid translation remained. Move cancellation now preserves positions/history and exits that decision; deterministic coverage checks the trapped case. Full Fall Back permissions, Independent paths and the legacy phase flags are still task 11.

The initial sanitizer run found 50,883,072 leaked bytes in 645,738 allocations while enumerating placement. A ten-call native reproducer isolated owning candidate copies. Generated LLVM IR from RLC 0.4.13 included cleanup on the first return after allocating the copy but omitted it on later return paths. Staging wrappers now have a single exit after allocation and delegate checks to helpers operating on the staged candidate. The minimal reproducer and original 513-zero-byte sanitizer input pass with leak detection enabled; the latter is retained in `tests/fuzz-regressions/geometry-placement-leak.bin`. No instrumentation is disabled.

A roof-only endpoint originally counted as terrain interior; the half-open vertical interval now distinguishes touching a roof from entering the volume below it. Deterministic tests cover both directions and an actual interior crossing. The Godot rejected-placement test uses x=0, where the base crosses the edge: x=43 is still a legal centre for the selected small circular base.

## Validation evidence

- Deterministic runner: **74 PASS, 8 XFAIL, 0 XPASS**. Covers exact inclusive measurement thresholds, closest pairs, quantifiers, neighbour/all-pair coherency, mixed M, summed paths, free rotation, atomic rollback, illegal selectors/off-grid paths, collision clearance, roof support/contact, ascent cost/proximity, setup cancellation and malformed terrain saves. Existing expected failures remain mandatory fixes in their owning tasks.
- Seeded Python full game: seed 40000 completes in **474 actions**, with legal action payload round trips and terminal owner −4. Seeded shooting completes in **10 actions**. Completion still does not establish combat semantics: fixed characteristics evaluate to zero until the task-9 fix.
- Python/gym: **20 steps**, finite observations/legal masks; **7,469** action candidates and **156,098** observation values. Persistent raw identities remain intentionally outside the observation layout; standard bounded numeric geometry is inferred normally.
- Godot: fresh matching RLC-0.4.13 native library, generated header and C++ extension pass the headless schema, target/unit/location selector, rejected-edge-placement and save-replacement checks. Production `scripts/Rules.gd`, `scripts/TraceManager.gd` and grid rendering remain unchanged.
- Sanitized Clang-21/RLC-0.4.13 fuzzer: original leak input and completed full-game/shooting native replays pass. Fresh three-input mutation campaign: **32 runs in 61 seconds**, coverage **6,106**, feature count **12,314**, with no sanitizer failures/new failure artifacts. The original failure artifact is preserved; the regression seed is tracked.

Artifacts and logs are outside the checkout under `/workspace/4hammer-validation`; only the regression seed and reusable instructions are tracked. Interactive mouse input/rendering, web builds and repository-wide CMake targets are not validated by the headless binding test.

## Remaining owners and constraints

Task 5 owns end-turn incoherency removals without destruction triggers. Task 8 owns terrain categories, visibility and objective rules. Task 11 owns independent model decision workflows, movement modes, setup-specific constraints on **every** base, reserve timing/distances and keyword exceptions. Current legacy deployment-zone/reserve anchor predicates are not certified as full new-edition setup legality. Tasks 13/14 own charge/fight path permissions and sequencing; task 17 owns supplied datasheets/footprints and complete editor integration. The unprovided Large Models exception must not be invented. These tasks must fix their recorded issues; retaining an expected failure is not completion.
