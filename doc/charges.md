# Charges — task 13

Authority: core pp.36–37 (11.01–11.04), Heroic Intervention p.57 (15.11), Flying p.71 (21.03), Aircraft p.74 (23.04), Fights First p.81 (24.13), Lance/Hover p.82 (24.17/24.21), and the supplied appendix's modifiers/re-rolls. Read the reproduced wording in `11th-edition-core-rules-procedural.txt` and `11th-edition-supplied-appendix.md`.

## Implemented procedure

Choose one friendly, live battlefield unit that has not declared a charge this phase. Reject engaged, advancing, falling-back, locked-ingress and AIRCRAFT units, and require an enemy within 12 inches of a live base. Declaration consumes the phase's opportunity regardless of the outcome; it does not grant successful-charge effects.

Roll 2D6 and resolve an eligible free/paid full-pair re-roll before modifying the result. The phase-scoped `charge_roll` modifier list uses the existing ordered modifier engine and caps the result at 12. Its effect producers still require supplied datasheet/faction rules. Heroic's Into the Fray caps the modified result at 6. A FLYING unit may then take to the skies, reducing the move's maximum by 2 unless the unit has Hover. Only flying bearers receive enemy traversal and horizontal-only costs. Super-heavy Walker's ordinary-movement traversal exception does not apply to charges. All models may traverse AIRCRAFT, but final overlaps remain forbidden; only FLYING units may select AIRCRAFT as charge targets.

After rolling, select one or more distinct enemies within both 12 inches and the move's full maximum distance, measured between nearest live bases. Reaching engagement alone cannot make an out-of-range target selectable. Finish selecting targets before proposing movement. Cancelling at either decision stage leaves positions and distance history unchanged and retains the declaration/expenditure.

Movement can use a validated rigid translation or independent per-model waypoint paths. Each path uses the charge limit instead of M, pays its complete length, sweeps full circular bases, and preserves the existing terrain-area/grid scope. Intermediate engagement is allowed; ending atop another base is not. Stage the formation privately until final coherency and all charge constraints pass. Independent paths may be restarted; no partial proposal changes battlefield positions.

Every live model must become closer to at least one selected target's nearest live base. A model that can legally finish within 1 inch of a selected target must do so; otherwise it must finish engaged if possible. Check reachable endpoints over the retained finite grid, including detours around blocking bases. The final unit must engage every selected enemy and must not engage any unselected enemy. Commit once, then record successful-charge movement and turn-local Fights First/Lance eligibility. Restore the caller's active/decision roles and moving-model selector context.

Heroic Intervention resolves at opponent Charge end. Choose a friendly eligible source and then its mode before rolling/spending. Leap to Defend costs the existing 1CP base and only permits enemies that actually made charge moves this phase. Into the Fray costs an additional CP and permits any enemy within 6 inches and the move's maximum. Existing legacy Pouncing Leap discount remains an explicitly old faction fixture, not new-edition authority. Both modes use the same charge engine; cancellation does not refund committed CP or targeting limits.

## State and editor contracts

State/observation schemas are **13**, action schema **9**. Declaration and successful-move phase stamps are standard bounded `PhaseStamp` values with zero meaning unset and serial+1 meaning recorded. The move's maximum is `LinearlyDistributedInt<0,13>`. Targets and completed-model flags are Bool arrays. Persisted paths use bounded grid points and integer segment history; floats and graph distances are calculation locals. Default generated lifecycle methods initialize/drop all fields. Save validation rejects invalid charge stamps and malformed modifier values/operations.

New charger/target selectors each take one `UnitID`; model selectors take one `ModelID`; destinations take one `BoardPosition`. Target selection and model movement occur at different suspension points, avoiding simultaneous selectors of the same shape. `InteractionManager.gd` highlights `board.moving_unit` for `SelectChargingModel`, and the existing choice panel exposes finite target-finalization/cancel/restart/finish and flight/rotation choices. Rules.gd and TraceManager.gd remain unchanged.

Old saves, ML policies, candidate indices and ordered replay ranks are incompatible. Rebuild Rulebook native code, generated Godot headers and the C++ extension together. Binary lifetime regression inputs still serve as legal-choice fuzzer inputs, not unchanged semantic action traces.

## Scope and required remaining work

Whole-inch quad positions, circular fixtures and area-only terrain/visibility remain user-directed approximations. Endpoint obligations hold other models' final positions fixed, as in task 11's surge validator; this is not a simultaneous formation rearrangement optimizer. Paths remain bounded to 16 waypoints and current inputs retain a model's elevation. Graph reachability uses horizontal grid routes at that elevation; physical feature surfaces, unsupported footprints and continuous positions are deferred. These limits must remain explicit rather than claiming exact arbitrary tabletop geometry.

Task 14 must replace Fight/pile-in/consolidation sequencing and integrate the completed-charge Fights First history; task 15 must implement Crushing Impact immediately after successful charges and the remaining core effects. Actual AIRCRAFT ingress/offboard behavior remains task 16. Attachments remain deferred task 6; mission geometry, datasheets, faction hooks and full interactive integration remain task 17.

The old target-first `use_overawing_magnificence` branch set an unused `charge_reduction` flag and charged CP without affecting the roll. It is not carried into the new core sequence as a fabricated faction rule; restoring a sourced, functional faction effect is mandatory task-17 work. Existing Heroic Pouncing Leap cost provenance remains explicitly legacy.

## Validation

Initial checks are not final evidence: an unsupported Float `min` implementation call and a Bool test payer argument were corrected, and a run overlapping test discovery edits was rejected by the runner's source-declaration guard. Obsolete preliminary native/fuzzer/gameplay builds were stopped and rebuilt against the final source.


Final matching checks: **311 supported assertions / 313 CTest entries pass** in **185.88 seconds**, with an empty discrepancy manifest. Artifacts: `/workspace/4hammer-validation/task13-tests`, `task13-godot`, `task13-fuzzer`, `task13-replays`, `task13-corpus`, `task13-artifacts`.

The Godot headless regression passes production charger/two-target/model clicks, chance ownership, bounded waypoint input and restoration of a pending staged path before successful completion, along with all preceding deployment/Command/terrain/shooting/allocation checks. Approximate full harness wall time is **178 seconds**; actual rendered interaction, full Heroic-mode GUI checks and wrapper-fetch optimisation remain task 17.

Seed 40000 finishes a full game in **920 actions** at terminal owner **-4**; its five charge attempts are cancelled, so successful-charge semantics come from the deterministic/Godot cases. Gym checks **20** legal steps, **18,443** action candidates and **6,033,519 finite observations** without not-tensorable warnings. Every position action still uses **1,247 interior quads**, and no z-coordinate action exists. The extra charge/rotation decisions expand the catalog; no action-fetch optimisation is claimed.

Sanitized geometry/deployment lifetime inputs and a fixed zero input pass with leak/precondition/bounds checks enabled. A fresh short-input campaign finishes **71 mutation runs in 61 seconds** (coverage **9,444**, features **14,793**) without failure artifacts. The separately completed current-schema full-game input passes fixed replay in **33,002 ms**. LeakSanitizer runs outside the sandbox for thread inspection; an unavailable external symbolizer only limits symbolic diagnostic names. This short campaign does not establish full charge semantics or coverage. No instrumentation was disabled.
