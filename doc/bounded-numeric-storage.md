# Bounded numeric storage and minimal quad inputs

User direction: keep x/y for quad input and actual positions, perform geometry/distance calculations with local floats, and persist numeric game/frame data only through BInt, LinearlyDistributedInt, Bool or enums. Hidden Int/Float game fields do not satisfy that requirement. Standard containers, bounded wrappers and compiler-owned coroutine metadata retain their primitive implementation fields; these are not new unbounded game-value wrappers.

## Coordinates and calculations

The board remains 44×30 whole-inch quads. Model position storage stays `CoordinateX` 0–43 and `CoordinateY` 0–29, including the default/off-table zero values. BoardPosition's custom action enumeration emits only x=1–43 and y=1–29: positive-size model bases cannot fit on the zero edges. Each position action has **1,247** candidates instead of 1,320; the full action catalog falls from **15,954 to 15,516**, a reduction of 438 (2.75%). This does not remove the separately measured Godot wrapper-fetch bottleneck. There is no z-coordinate action.

Persisted movement waypoints use StoredGridPoint with x=0–43, y=0–29 and z=0–30, in whole inches. Terrain corners include the outer board edges and use StoredTerrainPoint with x=0–44, y=0–30 and z=0–30. The existing area-only terrain abstraction is unchanged; old solid-box primitives remain available for geometry fixtures without adding feature gameplay.

Physical-precision GeometryPoint values are now calculation temporaries, reconstructed from those grid values. Existing base diameters and geometry functions keep their calculation precision. Distances/intersections use local floats; actual saved coordinates do not use micrometre-scale domains. Malformed path/corner values are rejected instead of changing the board or quantizing coordinates. Godot's existing BoardPosition x/y payload and getters remain intact.

## Movement distance

ModelHistory no longer persists Hidden<Float> distance. It stores up to **128** bounded squared horizontal segment lengths (0–2690) plus a bounded total vertical distance (0–3840 whole inches). Queries sum float square roots and vertical distance on demand. Diagonals and retracing preserve calculation precision without a rounded or hidden float total. Existing free-vertical path policy is retained by the owning movement helper. Zero-length segments need no entry; normal zero-distance moves still set the separate movement-kind/history flags.

Capacity overflow is asserted rather than clamped or silently dropped. The 128-segment bound is a supported implementation limit, not a printed game rule. Changing it requires updating layout/version guidance. Turn cleanup clears history through generated owning-container lifecycle methods. No custom init/drop was added. The old legacy attack frame's float distance cache is removed; its range guard computes the current distance locally.

## Identity and timing metadata

EntityIdentity and the allocation counter are standard LinearlyDistributedInt values with storage range 0–16384. Identity **0 means unset**; allocated identities are 1-based and remain stable through compaction/destruction/return. Allocation asserts before exhausting the **16,384** supported identities.

Phase counters store 0–63 and turn counters 0–15. History stamps store zero for unset and serial+1 for a recorded phase/turn (phase stamps 0–64, turn stamps 0–16). The current five-round game needs 60 phase-boundary increments and 10 turns. Bounds reject unsupported overflow and malformed saved values. These limits are infrastructure rather than tabletop rules.

Nonnegative encoding avoids RLC 0.4.14's invalid generated Python/Godot identifiers for negative template bounds. Generated initialization supplies zero stamps/identities and false Booleans; UnitHistory's partial custom initializer is removed. StateSchema is a singleton standard bounded value initialized to the current schema. The initial failed negative-bound binding build is not passing validation evidence.

## Schemas and validation

Current schemas: **state 12, action 8, observation 12**. Older saves, legal-rank catalogs and ML policies must not be treated as current-format inputs. Rebuild matching native/header/C++/Python artifacts after these representation changes.

Current deterministic validation: **281 assertions / 283 CTest entries pass**, including metadata defaults/layout, exact float diagonal calculations after history save/restore, invalid history/serial rejection, geometry/terrain/rollback, shooting and alias regressions. Tests writing path coordinates now use quad values rather than old micrometre values.

The 20-step gym check reports **15,516 actions** and **4,769,367 finite observations**, with no “not tensorable” warnings. Seeded current-schema full-game play completes **735** actions with terminal owner **-4**. The current full-game fuzzer passes both preserved lifetime inputs and **391 mutation runs in 61 seconds** with leak, precondition and bounds checks enabled. LeakSanitizer runs outside the sandbox because its thread inspection failed during the preceding sandboxed review. Fresh matching native/header/C++ Godot validation passes with `--timeout 300`; its terrain fixture now writes whole-quad corner values. See ROADMAP.md for final artifact paths.
