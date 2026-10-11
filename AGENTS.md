# Working on 4Hammer

Your task is to modify the game rules requested by the user and validate their behavior with regression tests and the buildable rules fuzzer. Implement the requested mechanics in the Rulebook Language sources; preserve compatibility with the Godot editor's action discovery and generated bindings. Do not silently change unrelated mechanics.

Use the existing isolated checkout; do not create a Git worktree unless requested. Inspect existing changes before editing. Unlike environment onboarding, a rule-change task permits the necessary source and test changes.

Preserve the existing quad-based game representation. Model positions, placement choices and movement destinations must remain on the whole-inch quad grid, using the existing BoardPosition action domain and Godot grid interactions. Do not introduce fractional model positions or migrate to continuous/non-quad coordinates during the edition update. Physical distance calculations may account for base sizes without changing the coordinate representation. A migration away from quads is deferred until the user explicitly requests it; document rules that the grid cannot faithfully express.

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

Work from `/workspace/4Hammer` and activate `source /workspace/4hammer-venv/bin/activate` when that environment exists. Use `rl_language==0.4.13` and matching `rl_language_core==0.4.13`. The formerly reported Boolean-operand error at the `is_character` declaration was caused by a bare function name at its call site; invoke `destroyed.is_character()` explicitly. The corrected sources pass 45 tests with 8 expected failures. Earlier recorded checks used 0.3.3. Consult README.md for installation if the prepared environment is unavailable.

`src/full_game.rl` defines the public `@classes` Game, faction selection and battle sequence. `src/rules.rl` implements phases/actions; `board.rl`, `units.rl`, `stats.rl`, `weapons.rl`, and `vector2d.rl` hold state and mechanics. `src/game_utils.rl` supplies the fuzzer and current-player classification. Keep legality preconditions, state transitions, player ownership, scoring, and finite action enumeration consistent. Nonterminal states must have legal actions. Chance decisions must remain classified as player `-1`; terminal states use `-4`.

## Rulebook Language guide

Sources: [language tour](https://rl-language.github.io/language_tour.html), [language reference](https://rl-language.github.io/language-reference.html), [action library](https://rl-language.github.io/stdlib/action.html), and [bounded arguments](https://rl-language.github.io/stdlib/bounded_arg.html). These were read from the official published-site repository, https://github.com/rl-language/rl-language.github.io, when the website returned HTTP 403. Documentation may describe newer releases or contain incomplete examples: use this checkout and the installed 0.4.13 standard library (`/workspace/4hammer-venv/lib/rlc/stdlib`) to confirm syntax and behavior. Do not upgrade the compiler merely to match a documentation example.

### Ordinary code and data

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
