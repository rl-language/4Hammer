# Working on 4Hammer

Your task is to modify the game rules requested by the user and validate their behavior with regression tests and the buildable rules fuzzer. Implement the requested mechanics in the Rulebook Language sources; preserve compatibility with the Godot editor's action discovery and generated bindings. Do not silently change unrelated mechanics.

Use the existing isolated checkout; do not create a Git worktree unless requested. Inspect existing changes before editing. Unlike environment onboarding, a rule-change task permits the necessary source and test changes.

Preserve the existing quad-based game representation. Model positions, placement choices and movement destinations must remain on the whole-inch quad grid, using the existing BoardPosition action domain and Godot grid interactions. Do not introduce fractional model positions or migrate to continuous/non-quad coordinates during the edition update. Physical distance calculations may account for base sizes without changing the coordinate representation. A migration away from quads is deferred until the user explicitly requests it; document rules that the grid cannot faithfully express.

Earlier task-specific schema versions and test counts below are historical completion records. Use the latest completed batch section and ROADMAP.md for current versions and validation.

## 11th-edition migration plan

Read and use [ROADMAP.md](ROADMAP.md) before planning or implementing the edition migration. It contains the agreed 17 logically distinct tasks, their scope, source-page citations, dependencies, Godot requirements and completion criteria. Treat it as the canonical migration plan; update task status and validation evidence there as work proceeds. Distinguish completed documentation from implemented and tested mechanics. A request to document or plan work does not authorize implementation.

Task 1's inventory is in [the rule coverage map](doc/11th-edition-rule-coverage.md), with [full excerpt ownership](doc/11th-edition-source-coverage.tsv) and [named reference availability](doc/11th-edition-external-references.tsv). Use its subsection rows, planned regressions, task ownership and D01–D12 gates when implementing later tasks. Update coverage status with actual evidence; the initial partial/different/missing classifications are source-inspection findings, not passing tests or new-edition certification.

Task 2's executed evidence is in [the validation baseline report](doc/validation-baseline.md). Follow [tests/README.md](tests/README.md) and run `python tools/run_rule_tests.py`: it verifies real RUN/OK counts and separately enumerates known discrepancies. Promote fixed discrepancy assertions into the passing suite and remove their manifest entries; an unexpected pass requires review rather than silently keeping an obsolete expected failure. The baseline includes 12 passing assertions and 12 expected failures; it does not certify core-rule coverage. Fixed characteristics currently evaluate to zero, so completed shooting/full-game smoke checks alone do not demonstrate combat resolution.

Task 3 is complete; read [the state foundations report](doc/state-foundations.md) before later implementation. Current validation is 45 passing tests and 8 remaining discrepancy assertions. Use standard bounded types for numeric state so Rulebook can infer the ML layout; do not reintroduce an unbounded Quantity wrapper or custom numeric observation encoding. Bounded storage/checked collections are separate from action domains; persistent handles are distinct from UnitID/ModelID selectors. Battlefield unit slots are retired rather than compacted, while model vectors compact and persistent model references must resolve EntityIdentity. Preserve archived weapon usage and attachment provenance. State/observation schemas are 3 and action schema is 2; regenerate matching native libraries and Godot headers together. `has_capacity` avoids a generated `can_append` binding collision. Task 3 alone does not complete later mechanics; consult the task-4 geometry progress below and do not infer complete timing, attachment, revival or combat rules from history/storage fields.

Use [the procedural core-rules reference](doc/11th-edition-core-rules-procedural.txt) as the specification, with reproduced source wording taking precedence over editorial summaries. Maintain a subsection-level coverage map and page-linked regression tests. Record ambiguities and missing mission, faction or app definitions explicitly; do not invent resolutions or claim full-edition coverage while those dependencies remain.

The roadmap proceeds through: (1) rule coverage, (2) validation baseline, (3) state and identity, (4) geometry, (5) timing and decision ownership, (6) attachments, (7) Command phase and Battle-shock, (8) terrain and objectives, (9) attack declarations and dice, (10) saves/damage/destruction, (11) movement and deployment, (12) shooting and weapon abilities, (13) charges, (14) fighting, (15) core stratagems and actions, (16) transports and aircraft, and (17) army data, Godot and full-game integration. Consult ROADMAP.md for the complete scope and acceptance criteria of each task rather than treating this summary as sufficient.

Tasks 1–5 establish foundations. Geometry and attachments precede combat; attack and damage pipelines precede shooting, fighting and combat stratagems. Validate Godot compatibility in every task that changes actions, then perform complete integration in task 17. New save-group and multiple-charge-target decisions may require explicit UI support; preserve the existing action parameter contracts described below.

Complete a task only after deterministic tests cover its cited rules, legal and illegal choices, and boundaries, and affected bindings work. Use sanitized fuzzing to find crashes, invalid states and stalled action sequences, not as proof of rule semantics. Record unavailable checks and external dependencies in ROADMAP.md; preserve failures and add regression coverage.

## Geometry foundations and preserved grid

Read [the task-4 geometry report](doc/geometry-foundations.md) for bounded geometry, supplied definitions, primitive APIs, regressions and limits. Current state/observation schemas are 4; action schema remains 2. The suite has 74 PASS, 8 XFAIL and 0 XPASS. The task-3 schema/count statements above describe its historical completion. Keep circle-fixture assumptions explicit and fail unsupported footprints; do not invent hull/oval/body data or Large Models exceptions. Terrain boxes are grid-aligned solid supports, not terrain-category/visibility rules. Existing editor movement still translates a whole formation; task 11 owns independent model decisions and all setup-specific constraints on every base. Task 5 owns end-turn incoherent removal without destruction triggers.

RLC 0.4.13's generated cleanup was observed to omit owning-local destruction on later return paths. Use a single exit after allocating Unit/Board/vector copies in staging wrappers; delegate early checks to helpers operating on the staged candidate. Preserve the original sanitizer regression input in `tests/fuzz-regressions`; run it with leak detection enabled after changing these helpers. Do not treat a semantic test as a memory-safety check.

## Timing foundations

Read [the task-5 timing report](doc/timing-foundations.md). Task 5 adds explicit round/turn/phase windows, ordered effect choices, active-role restoration, targeted stratagem bookkeeping and mandatory end-turn coherency removal. The user supplied Rules Sequencing: current player chooses their effects in any order, then the opponent chooses theirs. This is user authority, not a PDF quotation; other app-only Player’s Rules details remain unavailable. Keep turn owner (`current_player`), active role (`timing.active_player`), decision owner (`current_decision_maker`) and chance owner (`-1`) distinct. Restore the caller’s roles after nested moves/attacks/decisions.

Use `can_target_strat[_with_cost]` and `commit_stratagem[_with_cost]` for known unit targets. Check each payer’s phase/unit limits, shock eligibility and actual cost; spend before the effect. Free use still consumes limits. `try_use_strat` rejects invalid input atomically. Avoid helper names that collide with generated `can_*` Godot bindings. Declining a timing rule or reroll spends nothing; cancelling an already accepted Rapid Ingress retains committed expenditure. Preserve one-enum timing choices, source-first two-UnitID Neural Disruption and the target-backed ModelID coherency selector.

Current validation is **97 PASS, 8 XFAIL, 0 XPASS**; state/observation schemas **5**, action schema **3**. Earlier counts/schema statements describe historical task completions. Timing foundations do not certify new phase bodies, snapshot dice, snap shooting or all core stratagem effects. Read the timing report’s mandatory follow-up list and ROADMAP.md; task 6 is next. General modifier/CP-cap/offboard policy and new faction/mission definitions still require supplied sources. Preserve quads and bounded ML state.

## Focused commits and rule rationale

Create multiple logically distinct commits when work covers separate concerns. Each commit must do one precise thing, include its relevant regression coverage, and have a concrete title explaining the resulting change. Separate source/reference documentation, roadmap/agent guidance, validation infrastructure, bounded storage, identity/lifecycle behavior, compatibility helpers, individual rule fixes and Godot build changes where practical. Avoid bundling unrelated changes into a single migration commit. Keep prerequisite order reviewable and intermediate source states buildable; prefer adding/updating tests with their implementation. Rewrite an already pushed branch only when the user requests it, and use `--force-with-lease` to protect concurrent work.

For each new or materially changed Rulebook `fun`/`act`, add a nearby comment explaining why the helper/transition exists and which rule requires the behavior. Cite the original core page and, where useful, the subsection in `doc/11th-edition-core-rules-procedural.txt`. Distinguish current implementation from mechanics deferred to later ROADMAP tasks. For serialization, schema, ML or storage helpers, say that the mechanism is implementation infrastructure rather than a tabletop rule; cite the game invariant it supports without claiming the book prescribes the representation. Faction-specific effects require their supplied faction source; do not invent a core citation for the effect itself.

## Rules and toolchain

Work from `/workspace/4Hammer` and activate `source /workspace/4hammer-venv/bin/activate` when that environment exists. Use `rl_language==0.4.14` and matching `rl_language_core==0.4.14`; the user requested the updated compiler that rejects duplicate variable names. The formerly reported Boolean-operand error at the `is_character` declaration was caused by a bare function name at its call site; invoke `destroyed.is_character()` explicitly. The corrected sources pass 45 tests with 8 expected failures. Earlier recorded checks used 0.3.3. Consult README.md for installation if the prepared environment is unavailable.

`src/full_game.rl` defines the public `@classes` Game, faction selection and battle sequence. `src/rules.rl` implements phases/actions; `board.rl`, `units.rl`, `stats.rl`, `weapons.rl`, and `vector2d.rl` hold state and mechanics. `src/game_utils.rl` supplies the fuzzer and current-player classification. Keep legality preconditions, state transitions, player ownership, scoring, and finite action enumeration consistent. Nonterminal states must have legal actions. Chance decisions must remain classified as player `-1`; terminal states use `-4`.

## Rulebook Language guide

Sources: [language tour](https://rl-language.github.io/language_tour.html), [language reference](https://rl-language.github.io/language-reference.html), [action library](https://rl-language.github.io/stdlib/action.html), and [bounded arguments](https://rl-language.github.io/stdlib/bounded_arg.html). These were read from the official published-site repository, https://github.com/rl-language/rl-language.github.io, when the website returned HTTP 403. Documentation may describe newer releases or contain incomplete examples: use this checkout and the installed 0.4.14 standard library (`/workspace/4hammer-venv/lib/rlc/stdlib`) to confirm syntax and behavior. Do not upgrade the compiler merely to match a documentation example.

### Ordinary code and data

User-supplied lifecycle semantics: defining `init` replaces automatic initialization of **every field**, and defining `drop` replaces automatic destruction of **every field**. A custom method must manually call each field's corresponding `init`/`drop`, including owning containers and nested classes. These hooks are error prone and primarily intended for primitive storage classes such as Vector. Prefer compiler-generated lifecycle methods on game-state classes; do not add a partial initializer/destructor just to set new fields. Audit existing custom hooks when extending their classes.

Rulebook is a statically typed, indentation-based compiled language, not Python. `import rules` resolves a `.rl` module via the source/include paths; `-i src` makes this project's modules available to standalone scenarios/tests. Use `#` comments, `let x = expression` for inferred locals, and `let x : Type` for explicitly typed locals. Function parameters put the type first: `fun damage(Unit unit, Int amount) -> Bool:`. Class fields also put the type first, such as `BoardPosition position`. Primitive types include Int, Bool, Float, and Byte; use explicit conversions such as `int(...)` and `float(...)` where needed.

`cls` defines fields and methods; methods use `self`. `enum` defines named alternatives accessed as `Keyword::character`, and may also define methods. `using` creates type aliases; `fun<T>` and `cls<Int min, Int max>` illustrate type and compile-time value parameters. Operators can be implemented by methods such as `assign`, `equal`, `add`, and `less`; therefore arithmetic/assignment on bounded wrappers need not behave like raw integer operations.

Function arguments are passed by reference: helper functions can mutate their caller's board, unit, vector or parse index. Ordinary return values are copied unless declared `ref`. Assigning a state to another variable copies its value; do not confuse that with a helper's reference parameter. Check the relevant method signature before assuming a fetched element is a copy or a mutable reference. Ordinary `let` locals do not persist across action suspension.

Use `if`/`else`, `while`, and the collection APIs already used in the repository. Containers include Vector and BoundedVector; inspect capacity and index constraints before append/erase/access. Erasing units/models can invalidate stored numeric IDs. Alternative types (`A | B`) are tagged unions; `if obj is T` narrows a value for type-specific handling. `for alternative of value` and `for field of value` support compile-time structural traversal; the generated-action helpers use these to instantiate behavior for each action type.

### Actions are resumable state machines

A top-level `act play() -> Game:` declares an action function and a generated frame type Game. Calling `play()` constructs its state and executes up to the first input boundary. Inside it, `act choose(...)` is a suspension point exposed as a callable method. Calling that method supplies input and resumes ordinary computation until the next action boundary or completion. `Game` is the coroutine frame, not an ordinary function return annotation. `state.is_done()` reports completion; the generated resume index is `-1` when finished.

Use `frm` for variables/parameters that must survive a suspension or be exposed as frame fields. For example, `frm board : Board` gives the caller access to `Game.board`; `act choose(frm UnitID unit)` retains the chosen ID for later action steps. Values passed into `frm` action-function parameters are copied into the frame. Do not leave cross-action state in an ordinary `let` local or accidentally create a separate board copy.

Use `ctx` for caller-owned state that is not stored inside the child frame. For example, `act attack(ctx Board board, ...) -> Attack:` operates on the shared board, and subsequent child-action calls require that context. `subaction*(board, ...) child = attack(...)` forwards the named contexts to child actions so callers can act through the outer frame. Match context order/types and lifetime to the child signature.

`actions:` offers alternative branches at the current decision point: each starts with an `act`, followed by that choice's effects. Sequential `act` statements instead impose a sequence. A loop can revisit a choice; ensure it progresses or provides a legal exit. `subaction* child = ...` delegates interactions until the child finishes; `subaction` without `*` delegates a single step. This is how attack, deployment, turn and battle sequences compose. Reusing/reinitializing child frames must preserve the intended shared contexts and saved state.

### Legality and generated action values

An action can attach preconditions in braces: `act select_unit(UnitID unit) {unit.get() < board.units.size()}`. Preconditions gate availability; the current resume point also gates which method is callable. `can state.select_unit(unit)` checks the call without executing its effects. Put legality in preconditions rather than accepting an illegal input and undoing its effects afterward. Guard index accesses with safe bounds checks; a legality predicate must itself be safe to evaluate for every enumerated candidate.

`@classes` additionally generates a payload class for each exposed action (for example GameSelectWeapon) and an alternative type AnyGameAction. A payload stores the arguments, not the whole game. `can apply(action, state)` checks legality and `apply(action, state)` advances the frame. These values can be copied, serialized, replayed and inspected by Python/Godot. Renaming actions or changing their payload fields affects generated bindings, serialized traces and editor discovery. Keep action effects deterministic for a supplied payload; represent random results as explicit dice actions rather than introducing hidden randomness.

`enumerate(action)` builds candidate payloads from the available argument domains; it does not mean all candidates are legal now. Filter with `can apply`. Generic structural enumeration combines member possibilities, so domain sizes multiply. Prefer finite, meaningful wrappers/enums and avoid unnecessarily expanding argument ranges. This is shared infrastructure for the editor, random runner, ML interface and fuzzer.

### Bounded types and serialization in this game

The installed bounded_arg library uses half-open ranges `[min, max)`: BInt<0, MAX_UNIT_COUNT> enumerates IDs 0 through MAX_UNIT_COUNT - 1. BInt and LinearlyDistributedInt both provide finite integer domains, but their ML representations differ (one-hot versus linear). Their assignment and common arithmetic operators clamp to the domain; direct `.value` writes can bypass those operators. Inspect the implementation before relying on overflow, out-of-range rejection, or rounding. Bounds are enumeration limits, not a substitute for checking actual collection sizes and gameplay legality.

Preserve UnitID/ModelID wrappers with their `id` fields and BoardPosition with its `x`/`y` wrappers for Godot. Use bounded domains to limit possible actions and explicit preconditions to limit valid actions. State/trace serialization uses helpers such as `to_string`, `from_string`, `to_byte_vector`, and `from_byte_vector`; parsing may mutate its output and index arguments by reference. Check parse success before using results, and distinguish serialization round trips from rule correctness. Copyable/default-constructible state enables replay, branching simulations and fuzzing; use shared `ctx` objects deliberately when data cannot live in the frame.

For every changed mechanic, trace execution from the initial frame through its suspension points: what is persisted, which context is mutated, whose decision it is, which payloads enumerate, which are legal, and how the branch terminates. Test those transitions directly rather than relying only on a full random game.

## Godot editor compatibility

Read `scripts/Rules.gd`, `InteractionManager.gd`, `MultipleChoises.gd`, `SelectPointManager.gd`, and `boardl.gd` before changing action signatures. `src/gdexample.cpp` registers compiler-generated bindings from `rules.inc`; the UI inspects those bindings rather than parsing rule source.

`GlobalRules` enumerates `RLCAnyGameAction` on reset/state replacement, filters with `library.can_apply(action, state)`, and inspects each action's `unwrap()`, `members_count()` and `get_member(index)`. Applying an action refreshes legal actions and emits state-change signals. Preserve enumerable argument types and sound preconditions; new actions must be included in generated enumeration and have usable labels.

The editor recognizes these exact shapes:

| Action parameters | Editor behavior |
| --- | --- |
| No parameters | Choice button labeled from generated class name. |
| One enum | Choice buttons labeled by enum literal. |
| One Bool | True/false choice buttons. |
| One UnitID | Click a unit; member 0's `id` receives its unit index. |
| Two UnitID parameters | Click source then target; source MUST be member 0 and target member 1. |
| One ModelID | Click a model of the current attack target unit; member 0's `id` receives the model index. |
| One BoardPosition | Click a board location; member 0 has bounded `x`/`y` fields. |

Deployment is an explicit exception to battlefield clicking: `GameSelectUnit.unit_id` indexes `Board.reserve_units`, while model sprites use `Board.units` IDs. `MultipleChoises.gd` must offer each legal deployment action as a named reserve-unit button; `InteractionManager.gd` must suppress its battlefield unit-click handler for `RLCGameSelectUnit`. Do not reinterpret a deployed model ID as a reserve ID. The Godot regression presses these buttons for both armies and checks owner transfer and invalid ID rejection. Reserve arrival actions need the same collection audit when task 11 changes their UI.

Do not substitute raw Ints for UnitID/ModelID/BoardPosition, reorder source/target, or add parameters and assume existing specialized controls will still work. Selectors return the first matching legal action type and construct a fresh instance; avoid simultaneous ambiguous actions of the same shape unless you explicitly provide UI support. Model selection relies on `Game.board.attack.target.id`. Location highlighting uses `x * 100 + y`, and click conversion uses a 64-pixel grid with a 32-pixel offset; changes to coordinates or board dimensions require auditing these assumptions.

`RLCGameSelectWeapon` is explicitly recognized in MultipleChoises.gd and `GameSelectWeapon` in `pretty_string` in rules.rl. `RLCGameSkip` is explicitly ignored by the same-type detector. Generated class names have an assumed `RLCGame` prefix removed by `substr(7)`. Renaming these actions or the public Game requires auditing their consumers. Retain `gen_methods()` in game_utils.rl and its generic pretty-string instantiations needed by bindings. Preserve state fields and helpers used by rendering, scoring, serialization and network clients, or update all affected consumers deliberately.

Existing limitation: `get_question_action()` checks member 0 for Bool while requiring `members_count() == 0`; this is inconsistent. Do not assume the dedicated accept/reject widget works for a new Boolean action. The one-Bool MultipleChoises path is separate. Report or fix this only when relevant to the requested change.

The all-actions panel offers an enumeration-based fallback, but does not establish that specialized board interactions work. When changing actions, regenerate Godot bindings, review affected consumers, and exercise the relevant controls when Godot is available. Report unrun GUI validation explicitly.

## Validation after rule changes

Prefer the individual CMake/CTest rule checks: activate the compatible environment, configure `cmake -S . -B build-tests -DBUILD_GAME=OFF`, then run `ctest --test-dir build-tests --output-on-failure -j 4`. CTest discovers each zero-argument Bool assertion, compiles each suite once using fixtures and runs each case in isolation. Known discrepancy false results are Skipped/XFAIL, not passes; unexpected passes and crashes fail. Reconfigure after test/manifest changes. See [tests/README.md](tests/README.md); keep the existing Python runner functional.

Add focused deterministic regression tests for changed mechanics, including legal/illegal actions and relevant boundaries or state transitions. The deterministic entrypoint is `tests/baseline.rl`, with desired-rule discrepancy assertions in `tests/known_discrepancies.rl` and their explicit manifest. `rlc-test` discovers zero-argument `test_*` functions returning Bool. Run `python tools/run_rule_tests.py`, or run `rlc-test tests/baseline.rl -i src` and the separate discrepancy check. Verify actual RUN/OK counts: a zero-test success is not validation. Use Python checks where appropriate for bindings or action enumeration.

Run these existing headless smoke checks from the repository root:

```bash
rlc-random src/full_game.rl --iterations 1 --max-actions 200
rlc-random examples/single_shooting_maximize.rl -i src --iterations 3 --max-actions 5000
```

The first is bounded gameplay, not a completed full game. Confirm the shooting scenarios finish rather than exhaust the action limit (this CLI shares the action budget across iterations). Use `tools/check_gameplay_baseline.py` for seeded completion, decision-owner checks, payload round trips and replay inputs. Also exercise Python JIT/wrapper behavior when public state/actions change; `tools/check_gym_baseline.py` provides a bounded check, and `examples/gym_jit_example.py` runs from the repository root.

Build the sanitized fuzzer after changes. CMakeLists.txt defines target `rlc_rules_fuzzer`, output `rules_fuzzer`, with optimized/debug, precondition, bounds and sanitizer instrumentation. If a Godot-configured CMake build exists, build only that target rather than unrelated GUI/web/doc targets. Clang and its sanitizer runtime are required in addition to RLC. The current RLC 0.4.13 uses LLVM 21. Clang 21.1.8 and matching runtimes are prepared under `/workspace/4hammer-validation/toolchain21`; recreate them with `python tools/prepare_validation_clang21.py` on Debian 13 amd64. Its checksum pins come from verified LLVM repository metadata; runtime symlinks adapt Debian's layout without mixing versions. System GCC 14/libc headers, binutils and runtime dependencies must remain available. The older task-2 Clang 19 helper is historical and cannot link the current RLC fuzzer. Inspect linker diagnostics and require a runnable output: RLC may return zero even on link failure. See tests/README.md for the current commands and recorded result. The following direct build matches the RLC flags, avoids Godot dependencies, and successfully builds with RLC 0.4.13/Clang 21:

```bash
mkdir -p /workspace/4hammer-validation/corpus /workspace/4hammer-validation/artifacts
export LD_LIBRARY_PATH="/workspace/4hammer-validation/toolchain21/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
rlc src/full_game.rl -O2 -g --fuzzer --sanitize \
  --emit-precondition-checks --emit-bound-checks \
  --clang=/workspace/4hammer-validation/toolchain21/usr/lib/llvm-21/bin/clang \
  -o /workspace/4hammer-validation/rules_fuzzer-0.4.13
test -x /workspace/4hammer-validation/rules_fuzzer-0.4.13
/workspace/4hammer-validation/rules_fuzzer-0.4.13 \
  /workspace/4hammer-validation/corpus -max_total_time=60 -max_len=4096 \
  -artifact_prefix=/workspace/4hammer-validation/artifacts/
```

Seed the corpus with byte sequences long enough to drive actions: fuzz() consumes 8-byte action choices while `index + 8 < input.size()`. Inputs of at most 8 bytes do not exercise an action. The harness maps choices to currently legal actions and asserts on a nonterminal state with none. Fuzzing finds crashes, assertions and sanitizer failures; deterministic tests must establish the intended rule semantics. Preserve failing inputs, reproduce them, and add regression coverage. Do not disable checks to get a passing run. Keep generated outputs outside the checkout or in existing ignored build paths.

Report test counts/results, gameplay scope, fuzzer build and run outcome/duration, any reproducer, and GUI checks performed or unavailable. Distinguish repository bugs from missing tools. Never claim a check ran or passed without evidence.

## User-directed attachment deferral

The user deferred task 6 (attachments and unit characteristics) until they supply full unit datasheets after the other work. Skip attachment implementation for now; retain its unresolved scope in ROADMAP.md and proceed with task 7 and subsequent independent tasks. Do not infer attachment permissions from old factories or invent datasheet rules.

## Command phase and Battle-shock

Read [the task-7 report](doc/command-battle-shock.md). Leadership uses the complete 2D6 total and the lowest threshold. Command recovery requires a roll for already-shocked or at/below-half friendly units; only success in that step clears its initial shock snapshot. Opponent shock and successful outside-step rolls do not clear shock. Use doubled remaining counts/wounds for exact/odd thresholds; keep strict below-half separate from at-or-below eligibility.

Use unit-level shock inheritance, `model_objective_control`, `allows_action_start` and `allows_action_completion` when integrating later mechanics. The latter are only shock gates; task 15 must implement full action eligibility and completion. Insane Bravery is own Command-step only, blocked by existing shock targeting, once per battle independently for each player; its Board usage record must survive cleanup and saves. Do not bypass centralized battle/phase/target expenditure checks.

Current validation is **120 PASS, 5 XFAIL, 0 XPASS**; state/observation schemas **6**, action schema **3**. Task 6 remains deferred by user instruction; task 8 is next. Fixed characteristics and objective aggregation/ties remain mandatory fixes. Resolve offboard source gate D10 when integrating reserves/passengers; do not infer a general recovery policy from the battlefield loop. CMake prefers the activated Python and rejects missing `rlc` during configuration; explicitly set `Python3_EXECUTABLE` when replacing a stale cached interpreter.

## User-directed task-8 terrain scope

Implement terrain areas only. The user supplied the visibility approximation: assume models are always at least visible, and terrain crossings make them partially obscured. Use whole-quad rectangular areas and explicit category flags; do not implement physical features, model silhouettes, enclosed Solid openings or feature-specific traversal/upper-surface rules. Keep Hidden detection/history independent of physical visibility. Clearly distinguish this user-approved approximation from the printed rules and retain its limits in ROADMAP.md. Existing solid-box geometry primitives need not be removed or expanded.

## Terrain and objective foundations — task 8

Read [the task-8 report](doc/terrain-objectives.md). Task 8 is complete within the user-adjusted area-only scope. Use `terrain_rules.rl` for per-model eligibility, Hidden/detection, unit visibility and cover. Area intersections give partial obscuration; they do not block physical visibility or movement. Hidden depends on actual ranged attacks this/previous turn; call `record_ranged_attacks` when resolving real attacks, not on selection/skip. Ignores Cover must check ability presence: legacy parameter-based lookups miss parameterless rules. Other affected consumers remain mandatory task-12 fixes.

Use Board's configured/default objective points and transactional `link_objective_terrain_areas`; do not silently choose among overlapping areas. Objective control is a stored phase/turn boundary snapshot, with secured loss only at phase end. `unit_controls_objective` distinguishes unit eligibility from army ownership. Terrain range uses base membership; fallback markers use closest-part 3/5 range. Keep mission scoring explicit: a bare Board scores nothing, while `full_game.rl` selects the legacy four-marker fixture. Its layout/faction securing grants are not supplied new-edition mission/datasheet authority. Keep the four objective slots and up to 16 bounded areas until explicitly extending configuration capacity; preserve default Board field initialization.

Current validation: **144 PASS, 3 XFAIL, 0 XPASS**; CTest **149 entries** including two compile fixtures and three expected-failure skips. State/observation schemas **7**, action schema **3**; earlier counts are historical. Fresh native/Godot bindings pass terrain/Hidden/secured-control saves and existing selectors/deployment/Command tests. Remaining discrepancy assertions are mandatory task-9 fixes. Task 6 remains deferred; **task 9 is next**. Task 17 must provide area configuration/rendering and supplied mission/faction data. Physical features and exact LOS remain deferred by user instruction.


## Attack declarations and dice — task 9

Read [the task-9 report](doc/attack-declarations-dice.md) and [supplied appendix definitions](doc/11th-edition-supplied-appendix.md), then use ROADMAP.md for remaining work. Declare weapons/targets before resolution; resolve one target completely; gather identical attacks and determine random A separately per weapon. Fixed melee shares consume their complete budget. **The user directs us to assume random-A melee weapons do not exist; assert fixed A rather than inventing a split policy.**

Collect all original dice in each bounded batch before rerolls; retain original eligibility independently from replacement faces. Each die is rerolled at most once, before modifiers, and replacements can trigger dice effects. Preserve explicit chance ownership, source identities and caller decision roles. For suspended gathering, finish pure comparisons before the child action and retain a value `frm` weapon snapshot; do not retain ordinary locals/references across suspension. Persisted frame names must be unique for generated Python/Godot exports.

Use ordered modifier helpers with bounded magnitude/sign storage and final rounding; apply their limits when integrating future effects. Current state/observation schemas are **8**, action schema **4**. Existing UnitID click-selector shapes remain intact; numeric group/share/reroll choices require the production choice-panel buttons. Do not change Rules.gd or TraceManager.gd as part of this task.

All former discrepancy assertions are promoted unchanged; the manifest is empty. Keep empty-baseline rejection. Legacy save/allocation/damage/Hazardous/fight-on-death behavior remains a mandatory task-10/14 replacement, not certified by task-9 hit/wound tests. Full shooting modes/pistols/Lone Operative remain task 12; explicit movement state remains task 11. Multiple Weapon Profiles and other unsupplied app/datasheet/mission definitions remain source gaps. Task 6 remains deferred. Consult ROADMAP.md for final validation evidence and next-task status.

## Saves, damage and destruction — task 10

Read [the task-10 report](doc/saves-damage-destruction.md) and ROADMAP.md. Current state/observation schemas are **9**, action schema **5**; all earlier counts/schemas describe historical completions. Validate the current **202** supported assertions and empty discrepancy manifest, with **204** CTest entries including compilation fixtures.

Build live allocation groups by W/Sv/InSv with separate CHARACTER groups; declare priority order before collecting saves, then process ascending faces and allocate each attack separately (pp.19–23). Preserve stable group membership and wounded-model priority. PRECISION selects a visible character group, not an unrestricted opponent model (p.84). Normal damage precedes mortal wounds; discard excess ordinary/Devastating damage per attack, while ordinary mortals spill (pp.19/24/80). All prevention, mortal allocation and destruction must use the common action engine; low-level Unit damage helpers are storage fixtures, not gameplay substitutes.

Keep destruction provenance and pending corpses across saves, excluding them from ordinary targeting, OC and active abilities. Delay attack-triggered rules until the attacking unit finishes all targets, resolve immediate non-attack triggers before continuing damage, retain Deadly Demise geometry through its effects, then archive exactly once (pp.80/87). Sequence current player's triggers before opponent's, with each choosing their order per the user-supplied definition. Task 14 owns complete Fight on Death combat; task 16 must add emergency disembarkation before transport demise; task 17 owns new faction effects. Do not claim those are complete merely because core lifecycle infrastructure exists.

Use bounded AllocationGroupID choices and existing ModelID payloads. The production choice panel labels save groups; damage/destruction ModelID controls must use `board.attack_info.target_unit_id` in InteractionManager, which may differ from the original attack target for hazards or cascades. Preserve Rules.gd and TraceManager.gd. Regenerate matching library/header/C++ artifacts together. The larger bounded work-stack layout produces **1,595,388** full-game observations and **12,744** action candidates; old ML policies are incompatible. Keep explicit configured bounds and overflow assertions rather than unbounded storage or silent dropping.

For Godot's expanded save/damage harness use `python tools/check_godot_state.py --build-path /workspace/4hammer-validation/task10-godot --timeout 120`; the default 30-second timeout remains available for smaller checks. Actual mouse input/rendering, all numeric melee/share controls and broader faction integration remain task 17. Consult ROADMAP.md for completed validation and remaining mandatory fixes. **Next pending task: 11, movement and deployment.** Task 6 remains deferred until supplied datasheets.

## Movement and deployment — task 11

Read [the task-11 report](doc/movement-deployment.md) and ROADMAP.md. State/observation schemas are **10**, action schema **6**. Preserve whole-quad actions, bounded movement values and existing generated Unit initialization. Random movement overrides store `M+1`, with zero meaning unset. Explicitly type owning `frm Unit` snapshots before assigning reference-returning board lookups; inferred reference frames do not provide rollback snapshots. Keep owning staging helpers single-exit for sanitizer cleanup.

Use the common setup kernel for deployment, Scouts and ingress: validate every base and search supported column presets against all placement constraints, then commit the exact candidate. Mixed-base row spacing uses actual adjacent pairs. The user directs **destroy units that cannot be placed**, rather than restart deployment or grant free reserves. Offer destruction only when the complete supported placement search finds no legal position; archive identities and destroyed models without inventing battlefield death positions. This is user authority, not a PDF rule.

Current Scouts metadata is dynamic: assert every instance has the same value; validate that assumption statically when constant datasheets arrive. Keep reserve selectors separate from battlefield UnitID clicks. Route independent model moves through `board.moving_unit`, stage waypoints until final coherent placement, and restore decision roles after nested moves. Keep same-turn Advance/Fall Back restrictions through repositioning and reset owned reserve history at the next turn. Do not claim missing points, attachment permissions, terrain features, transports, Aircraft, faction surge triggers or exact continuous formations are implemented. Next pending task after task-11 validation is **12, shooting and weapon abilities**; task 6 remains deferred.

## Shooting and weapon abilities — task 12

Read [the task-12 report](doc/shooting-weapon-abilities.md) and supplied appendix 04.01.03 in [the appendix reference](doc/11th-edition-supplied-appendix.md). State/observation schemas are **12**, action schema **8**. These supersede historical schema statements above. Use ROADMAP.md for completion evidence and remaining owners.

Choose a shooting mode before weapon declarations. Preserve per-bearer live range, mode-specific engagement permissions, Snap's shared target and indirect natural-face/reroll rules. Snapshot original selected abilities, declaration counts/half range and Hunter predicates; keep current-target abilities separate when intervening effects grant duplicates. Lethal Hits is optional per original critical, not per batch. Phase-local shooting locks expire for battlefield and reserve units. Turn-limited movement flags expire for both armies.

For multiple profiles, nonzero `Model.weapon_profile_groups` IDs identify one physical weapon within that model; zero means an independent slot. Select only one profile of each physical weapon per activation. One Shot spends every profile of that physical weapon, including when no attacks are made. Clear profile metadata when reusing a Model with a different loadout. Hunter predicate storage reuses WeaponRule's bounded keyword condition only; its kind/parameter do not grant an ability. Populate permissions from supplied datasheets rather than inferring them.

Prefer generated lifecycle hooks. Keep fixed primitive keyword arrays and bounded profile IDs. Setup search may reuse one owning staged candidate and reject necessarily invalid anchors before copying, but must still validate all bases and supported presets. Retain unique persisted frame names across alternative action branches; generated bindings can collide even when branches are exclusive. Godot wrappers borrowing a member must retain the parent payload for their entire lifetime. Preserve Rules.gd and TraceManager.gd.

RLC 0.4.14 rejects duplicate variable names. Keep names unique in each function/action scope and across action-frame branches; use the compiler diagnostic instead of relying on later C++/Godot failures. Historical 0.4.13 diagnostics and evidence above remain historical.

## User-required numeric storage

Every numeric value persisted in game state or an action frame must use BInt, LinearlyDistributedInt, Bool or an enum; hiding an Int/Float does not satisfy this rule. Primitive standard containers/bounded wrappers may contain their implementation fields, but game metadata such as identities, serials and movement history must be bounded too. Use bounded quad x/y for action inputs and actual positions. Calculate distances and intersections with local floats; do not expand coordinate action domains to physical-precision values. Preserve exact grid movement by storing bounded integer segment data rather than an unbounded floating cumulative distance. Re-run ML layout checks after changing persistent representations and bump affected schemas.

Read [the bounded-storage follow-up](doc/bounded-numeric-storage.md) for current numeric representations. Identity/stamp zero means unset; recorded serials are stored as serial+1, and identities are 1-based. The change avoids RLC 0.4.14 negative-template binding names. Phase/turn counters have checked bounds; movement distance comes from bounded squared grid segments plus vertical distance, not a hidden float. Actual paths and terrain corners use small whole-quad storage. Physical GeometryPoint values are calculation temporaries only. Position enumeration excludes impossible zero edges, preserving BoardPosition payload/getters. Current evidence is **281 assertions / 283 CTest entries**, fresh Godot bindings, a finite 20-step gym check without not-tensorable warnings, and sanitized current-schema checks. Preserve the measured task-17 wrapper-fetch optimisation obligation; coordinate trimming reduces candidates by 438 but does not remove that bottleneck.

## Charges — task 13

Read [the charge report](doc/charges.md) and ROADMAP.md. Declare the source before rolling, then select distinct targets within both 12 inches and the modified maximum; never select targets merely because engagement could be reached. A failed/cancelled declaration consumes this phase's opportunity but grants no successful-charge effects. Only completed moves set `has_charged` and `history.charge_move_phase`; `declared_charge_phase` records attempts. Preserve bounded stamp/distance/path storage and generated lifecycle methods.

Use the shared charge kernel for ordinary charges and both Heroic Intervention modes (pp.36–37/57), with per-model approach/within-1/engagement obligations, final coherency, all-target engagement and no incidental enemies. Super-heavy Walker traversal does not apply to charges (p.85); flight/Hover and AIRCRAFT restrictions have separate sourced gates (pp.71/74/82). Endpoint reachability uses the preserved horizontal whole-grid domain with other final models fixed; do not call it a joint formation optimizer or continuous geometry.

Charge model clicks must use `board.moving_unit`, not the attack target. New `UnitID`, `ModelID` and `BoardPosition` selectors preserve editor payload shapes and are separated by suspension points. State/observation schemas are **13**, action **9**; regenerate matching native/Godot artifacts. Keep Rules.gd and TraceManager.gd unchanged. Task 14 owns full Fight integration, task 15 post-charge Crushing Impact, task 16 Aircraft lifecycle and task 17 sourced faction/mission/data/editor work. The legacy target-first Overawing Magnificence branch had no applied effect; its sourced replacement remains mandatory task 17.

## Fighting — task 14

Read [the fighting report](doc/fighting.md), the user-supplied Fight on Death appendix and ROADMAP.md. The Fight phase is phase-wide Pile In, mandatory alternating fights and phase-wide consolidation (pp.38–43). Current player starts; passing requires no eligible unit of the required priority. Re-evaluate eligibility and Fights First after every activation, and keep the engagement snapshot taken after Pile In. Overrun grants an extra optional pile-in. Engaging consolidation queues every engaged unfought enemy for mandatory responses.

Fight on Death models stay until their **own unit has attacked or phase end**, then resolve destruction effects and remove/archive them. Never restore the old immediate retaliation bridge. Use the scoped Board attack exception, shared declarations/grouping and release helpers; retain original destruction provenance. Legacy grants/thresholds are not supplied new-edition faction authority. All-dead retained units may be selected for their authorised attack, but retained models remain invalid ordinary targets/active ability sources/movers.

Keep per-model closest ties controller-owned, preserve prior engagements, enforce 3-inch complete paths and objective/enemy consolidation mode priority. Melee model clicks use `board.moving_unit`. State/observation schemas **14**, action **10** require matching rebuilt bindings. Persisted numbers remain standard bounded values/enums; endpoint Float arrays are locals. Declare owning Unit frame snapshots explicitly and assign them after declaration; inferred snapshots tested here were empty. Generated init/drop handles every field. Keep Rules.gd/TraceManager.gd and the whole-quad/area-only geometry scope unchanged. Counteroffensive/core effects remain task 15, transports/Aircraft task 16, supplied faction/data/rendered integration/performance task 17, attachments deferred task 6.

## Core stratagems and actions — task 15

Read [the core stratagem/action report](doc/core-stratagems-actions.md) and ROADMAP.md. Keep all core cards on their printed pp.54–57 boundaries; use the shared CP/target limits and mortal/FNP/destruction engine. Crushing Impact belongs immediately after a successful own Charge-phase move; Epic Challenge grants Precision to one participating CHARACTER's melee weapons; Counteroffensive is a Fight-step decision that constrains the next friendly selection. Do not restore per-move Overwatch. All printed shooting types prohibit subsequent action starts until phase end (pp.34–35/57); reread after-effect clauses as well as p.58's generic list.

Mission consumers must supply their actual action definitions and validate timing/units/use limits before `begin_unit_action`. Retain the bounded start-turn stamp and complete that specific action through the explicit-stamp overload; multiple actions may remain pending across turns. Non-melee movement/departure must call `interrupt_actions`; Pile In/consolidation and Remain Stationary are exempt. Never make the unusable DEPLOY DEVICE illustration playable. Transport interruption belongs to task 16; actual mission/data/faction/rendered integration and the measured wrapper-fetch fix remain task 17.

Current schemas are state/observation **15**, action **11**. Regenerate artifacts together. New bearer selectors use `board.moving_unit`; simultaneous core effect/ordinary unit choices need distinct source buttons. Preserve Rules.gd/TraceManager.gd and existing quads. Smokescreen's intervening-base sight-segment approximation is explicit and must not be described as physical silhouette visibility. Generated lifecycle methods own every added record/vector field.

Use distinct `frm` parameter names across sibling actions in the same enclosing act. Their generated fields/accessors share one class even when DSL branches are separate; task 15 renamed `explosives_source` to avoid a duplicate `ShootingPhase::source` in Godot C++. Keep selector payload types/shapes intact and compile the generated C++ before claiming editor compatibility.

## User-directed transport nesting assumption

Assume a TRANSPORT never embarks inside another TRANSPORT. Assert this on otherwise eligible embarkation; check ordinary datasheet/type/capacity rejection first so enumerating invalid passenger candidates does not assert. This is user authority, not a printed core prohibition. Do not implement nested transport storage/lifecycle.

## Transports and Aircraft — task 16

Read [the transport/Aircraft report](doc/transports-aircraft.md) and ROADMAP.md. Transport capacity, seat costs, passenger keywords and Firing Deck require explicit known metadata; unknown datasheet permissions grant nothing. Preserve the passenger bank, stable carrier/model identity and retired return slots. Never compact battlefield slots when a unit embarks or enters reserves. Deployment searches must clear offboard flags on their prospective candidate, just as actual setup validation does; otherwise collision checks can falsely report a placement and prevent the required destruction of an unplaceable unit (p.14, user direction).

Use the common movement/setup and damage engine: post-move embark decisions restore the source controller and caller context; Tactical disembarkation requires a follow-up Normal/Advance move; emergency passengers resolve hazards and setup before carrier Deadly Demise/removal (pp.64–65). Keep raw hazard recipients distinct from ordinary attack targets. Firing Deck declarations borrow weapon rules but use carrier identity/grants, and lock every passenger against later shooting that turn (p.81). Expire effects in all banks; required Command Battle-shock includes passengers/reserves (supplied appendix01.02.02/01.02.04).

Aircraft reserve in formations, return at opponent turn end and reuse their original battlefield slot. First-round arrival restrictions need an explicit defer selection, not an illegal Stationary move (p.74). State/observation schemas are **16**, action **12**; regenerate matching artifacts. Offboard choices use buttons, carrier model clicks use `board.moving_unit`; preserve Rules.gd/TraceManager.gd and the quad grid. Integration tests must use actual appended slot indices when earlier fixtures retire slots. Actual datasheets, deferred attachments, sourced faction/mission consumers, rendered interaction and measured wrapper-fetch performance remain tasks6/17 and must be completed there.

Godot wrappers borrowing vector elements must be fetched again after vector mutations that can relocate storage. Retaining a parent payload protects its lifetime, not the address of an element moved by append/erase. Refresh unit/model wrappers after adding battlefield units and after restoring state; staged-move assertions must inspect the current battlefield model.

## User-directed Orks integration scope

Use [the complete Orks audit](doc/orks-codebase-audit.md), [all 67 unit requirements](doc/orks-unit-requirements.tsv) and [the CP-card inventory](doc/orks-stratagem-costs.tsv) alongside ROADMAP.md. The faction page and every linked datasheet were readable on 2026-10-12; the scan includes Legends and Forge World. Audit completion is not implementation completion.

The user excludes unit/army/enhancement point accounting and detachment-point accounting. Support up to **three distinct detachments per player**, using bounded enum storage; do not count War Horde as three slots or enforce its printed DP cost. Continue tracking **CP costs**, discounts, surcharges, affordability, targets and use limits. Preserve all non-price eligibility and equipment rules. Explicitly accommodate point-free reserves rather than rejecting every Orks unit for missing points or inventing a unit-count reserve percentage; leave existing explicitly configured point-aware fixtures supported without developing a pricing system.

Implement one logically distinct batch/rule at a time, following the audit's dependency order and recording actual validation. Available Orks Leader/Support lists resolve that source gap, but task6 mechanics and other factions' permissions remain unfinished. Use web URLs and named abilities/sections for new citations, not fabricated core-PDF pages. Follow the audit's engine requirements, including compound dice, negated/conjunctive predicates, real loadout capacity, scoped event/use records, healing/revival, carrier-specific fractional seating, reaction permissions, hit provenance and psychic budgets. Do not silently turn oval/hull/multipart models into circles or leave confirmed defects unfixed.

## Army configuration and shared CP — batch 17.B

Read [the configuration report](doc/orks-configuration.md) and ROADMAP.md. `Faction` remains a legacy roster ID; `Board.armies[player]` / `army_for_player` holds actual `ArmyFaction`, a checked vector of at most three distinct `OrksDetachment` values and explicit reserve budget mode. Public roster selection uses point-free reserves, while standalone point-aware fixtures retain their default. Preserve every non-price reserve permission; never introduce an alternative percentage or DP budget.

Orks detachment selection uses a single enum and finish action, permits zero to three choices and automatically hands off after the third. All 15 packages are configuration options; their effects/cards/enhancements are later batches. The 40-card registry supplies base CP, package gates and common shocked/destroyed target policies, not their full printed action legality. Future consumers must still check source keywords, timing and triggers before committing expenditure. Free use consumes limits, and explicit final costs may increase by at most 1CP.

Schemas are state/observation **17**, action **13**. Keep `NEXT_STATE_SCHEMA_VERSION` one greater than `STATE_SCHEMA_VERSION`; equal endpoints make a zero-width storage range and break saves. Regenerate native libraries and Godot headers together. Avoid parameter names that shadow generated accessors: `final_cost`, rather than `cost`, is necessary when the function also calls `strat.cost()`. Preserve generated lifecycle methods and the existing grid/selectors.

Batch17.B is complete: 442 assertions /444 CTest entries, 16 focused native sanitizer cases, matching full headless Godot, completed gameplay/replay, ML and short mutation fuzzing pass. Consult the report/roadmap for artifacts and limits. Next is 17.C; do not mark detachments, their cards or datasheets implemented because their configuration/CP enum entries exist.

## Retire obsolete Orks implementation

The user authorises stripping the previous Orks implementation: it is no longer authoritative and need not be preserved for compatibility. Remove obsolete runtime cards/effects as the new source-driven batches replace them. Old profile/factory names still used by core regression fixtures may remain temporarily as explicitly uncertified scaffolding until17.H replaces the actual data; do not preserve their obsolete faction permissions or certify them as current datasheets.

## Keyword predicates — batch17.C1

Read [the predicate report](doc/orks-keyword-predicates.md) and ROADMAP.md. Weapon/Hunter conditions use `KeywordPredicate`: the conjunction of ALL, ANY and NONE groups. Unit queries use the union of constituent models; model queries use only that model's keywords. Retained models still in a unit remain constituents, while target/ability live-state checks are separate. Never flatten negations or adjacent source keywords into positive OR. Preserve each selected instance's condition, including temporary ANTI grants.

Store nine total keyword terms in contiguous groups with three bounded counts; compute the term count and semantic clause enum. Per-term categorical tags unnecessarily doubled the ML layout. The compact layout is14,493,920 observations with22,379 action candidates. Validate counts, total and keyword IDs before lookup; expand the documented bound explicitly for larger source conditions. Use typed count/keyword/clause bridges for Godot labels and refresh borrowed vector wrappers after mutations. Do not add custom lifecycle hooks or tensor encoding.

Schemas are state/observation **18**, action **14**, next-state **19**. The final suite passes465 assertions /467 CTest entries and24 native sanitizer cases. Full compact Godot interaction checks and focused final-body ANTI bindings pass. The two obsolete Orks card actions are removed; legacy profile factories remain uncertified scaffolding for later replacement. **Next:17.C2**, then17.C3–C4. ROADMAP.md holds final replay/fuzzer evidence; do not mark all17.C or any datasheet complete.
