# Working on 4Hammer

Your task is to modify the game rules requested by the user and validate their behavior with regression tests and the buildable rules fuzzer. Implement the requested mechanics in the Rulebook Language sources; preserve compatibility with the Godot editor's action discovery and generated bindings. Do not silently change unrelated mechanics.

Current Orks adapters live in `src/factions/orks/`; import them with full dotted
paths such as `factions.orks.army`, using the existing `src` include
root. Keep reusable mechanics in common modules. Faction reports and source
inventories live in `doc/factions/orks/`; start with its
[index](doc/factions/orks/README.md) and the
[module map](src/factions/orks/README.md). Source audits must recurse through
`src/`, not assume every module is at its root. The
[organization review](doc/file-organization-review.md) records completed faction refactoring and remaining shared-engine proposals.
Keep all current Orks datasheets in one `src/factions/orks/datasheets.rl` file.
Organize runtime mechanics by responsibility; never use implementation-order
categories such as Elite/Remaining. Use `make_orks_model`, one
`finalize_orks_unit`, and the shared explicit `make_source_usage`/
`source_use_limits` constructors instead of category wrappers. Preserve each
rule's identities, limits and live-conferral checks when consolidating helpers.
Source presentation metadata must use `Hidden<SourceLabel>`, never an owning
String in `SourceInstance`. Derive display text with `source_label_text` only
when a host requests a label; rule IDs/scopes remain the gameplay identities.

Use the existing isolated checkout; do not create a Git worktree unless requested. Inspect existing changes before editing. Unlike environment onboarding, a rule-change task permits the necessary source and test changes.

Read [the Rulebook design and architecture guide](doc/rulebook-architecture.md) for module responsibilities, frame/context ownership, identity, combat/movement/source pipelines and host integration. Keep it aligned when those structures change. ROADMAP.md remains the source of implementation status and validation evidence; the architecture guide does not certify pending mechanics.

For readers who know40K and Godot, start with [the engine guide](doc/engine-guide.md)
and [the state/property reference](doc/game-state-reference.md). Keep their field
meanings, lifetimes, source/derived distinction and examples aligned with actual
consumers when changing structs. The user requires these docs to remain Markdown;
code examples/diagrams belong in fenced blocks. Do not replace the authored
explanations with a generated declaration dump. Documentation-only changes need
field/link checks and execution of new examples, not another full rules build.

Preserve the existing quad-based game representation. Model positions, placement choices and movement destinations must remain on the whole-inch quad grid, using the existing BoardPosition action domain and Godot grid interactions. Do not introduce fractional model positions or migrate to continuous/non-quad coordinates during the edition update. Physical distance calculations may account for base sizes without changing the coordinate representation. A migration away from quads is deferred until the user explicitly requests it; document rules that the grid cannot faithfully express.

Earlier task-specific schema versions and test counts below are historical completion records. Use the latest completed batch section and ROADMAP.md for current versions and validation.

## 11th-edition migration plan

Read and use [ROADMAP.md](ROADMAP.md) before planning or implementing the edition migration. It contains the agreed 17 logically distinct tasks, their scope, source-page citations, dependencies, Godot requirements and completion criteria. Treat it as the canonical migration plan; update task status and validation evidence there as work proceeds. Distinguish completed documentation from implemented and tested mechanics. A request to document or plan work does not authorize implementation.

Task 1's inventory is in [the rule coverage map](doc/11th-edition-rule-coverage.md), with [full excerpt ownership](doc/11th-edition-source-coverage.tsv) and [named reference availability](doc/11th-edition-external-references.tsv). Use its subsection rows, planned regressions, task ownership and D01–D12 gates when implementing later tasks. Update coverage status with actual evidence; the initial partial/different/missing classifications are source-inspection findings, not passing tests or new-edition certification.

Task 2's executed evidence is in [the validation baseline report](doc/validation-baseline.md). Follow [tests/README.md](tests/README.md) and use the native CMake/CTest entrypoint: it discovers and individually runs every assertion and separately enumerates known discrepancies. Promote fixed discrepancy assertions into the passing suite and remove their manifest entries; an unexpected pass requires review rather than silently keeping an obsolete expected failure. The baseline includes 12 passing assertions and 12 expected failures; it does not certify core-rule coverage. Fixed characteristics currently evaluate to zero, so completed shooting/full-game smoke checks alone do not demonstrate combat resolution.

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

Work from `/workspace/4Hammer` and activate `source /workspace/4hammer-venv/bin/activate` when that environment exists. Use `rl_language==0.4.18` and matching `rl_language_core==0.4.18`; the user requested parallel compilation. Use `-j 4`; keep debug builds unoptimized and reserve `-O2` for optimized validation/fuzzing. Duplicate variable names remain rejected. Earlier compiler versions/counts below are historical. The formerly reported Boolean-operand error at the `is_character` declaration was caused by a bare function name at its call site; invoke `destroyed.is_character()` explicitly. The corrected sources pass 45 tests with 8 expected failures. Earlier recorded checks used 0.3.3. Consult README.md for installation if the prepared environment is unavailable.

`src/full_game.rl` defines the public `@classes` Game, faction selection and battle sequence. `src/rules.rl` implements phases/actions; `board.rl`, `units.rl`, `stats.rl`, `weapons.rl`, and `vector2d.rl` hold state and mechanics. `src/game_utils.rl` supplies the fuzzer and current-player classification. Keep legality preconditions, state transitions, player ownership, scoring, and finite action enumeration consistent. Nonterminal states must have legal actions. Chance decisions must remain classified as player `-1`; terminal states use `-4`.

## Rulebook Language guide

Sources: [language tour](https://rl-language.github.io/language_tour.html), [language reference](https://rl-language.github.io/language-reference.html), [action library](https://rl-language.github.io/stdlib/action.html), and [bounded arguments](https://rl-language.github.io/stdlib/bounded_arg.html). These were read from the official published-site repository, https://github.com/rl-language/rl-language.github.io, when the website returned HTTP 403. Documentation may describe newer releases or contain incomplete examples: use this checkout and the installed 0.4.18 standard library (`/workspace/4hammer-venv/lib/rlc/stdlib`) to confirm syntax and behavior. Do not upgrade the compiler merely to match a documentation example.

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

Prefer the individual CMake/CTest rule checks: activate the compatible environment, configure `cmake -S . -B build-tests -DBUILD_GAME=OFF`, then run `ctest --test-dir build-tests --output-on-failure -j 4`. CTest discovers each zero-argument Bool assertion, compiles each suite once using fixtures and runs each case in isolation. Known discrepancy false results are Skipped/XFAIL, not passes; unexpected passes and crashes fail. Reconfigure after test/manifest changes. See [tests/README.md](tests/README.md). The user requires no Python in the pure Rulebook test path: CMake discovers declarations, RLC builds a native library without `--python`/`--pylib`, and the C runner executes each assertion. Do not restore a Python runner, wrapper import or interpreter discovery for these tests. Separate host/ML Python tooling is still supported.

Add focused deterministic regression tests for changed mechanics, including legal/illegal actions and relevant boundaries or state transitions. The deterministic entrypoint is `tests/baseline.rl`, with desired-rule discrepancy assertions in `tests/known_discrepancies.rl` and their explicit manifest. CMake discovers zero-argument `test_*` functions returning Bool and links their native exports into the C runner. Run the individual CTest cases, including the build fixture. Verify discovery and executed counts: a zero-test success is not validation. Use Python checks where appropriate for bindings or action enumeration.

Run these existing headless smoke checks from the repository root:

```bash
rlc-random src/full_game.rl --iterations 1 --max-actions 200
rlc-random examples/single_shooting_maximize.rl -i src --iterations 3 --max-actions 5000
```

The first is bounded gameplay, not a completed full game. Confirm the shooting scenarios finish rather than exhaust the action limit (this CLI shares the action budget across iterations). Use `tools/check_gameplay_baseline.py` for seeded completion, decision-owner checks, payload round trips and replay inputs. Also exercise Python JIT/wrapper behavior when public state/actions change; `tools/check_gym_baseline.py` provides a bounded check, and `examples/gym_jit_example.py` runs from the repository root.

Build the sanitized fuzzer after changes. CMakeLists.txt defines target `rlc_rules_fuzzer`, output `rules_fuzzer`, with optimized/debug, precondition, bounds and sanitizer instrumentation. If a Godot-configured CMake build exists, build only that target rather than unrelated GUI/web/doc targets. Clang and its sanitizer runtime are required in addition to RLC. The current RLC 0.4.18 uses LLVM 21. Clang 21.1.8 and matching runtimes are prepared under `/workspace/4hammer-validation/toolchain21`; recreate them with `python tools/prepare_validation_clang21.py` on Debian 13 amd64. Its checksum pins come from verified LLVM repository metadata; runtime symlinks adapt Debian's layout without mixing versions. System GCC 14/libc headers, binutils and runtime dependencies must remain available. The older task-2 Clang 19 helper is historical and cannot link the current RLC fuzzer. Inspect linker diagnostics and require a runnable output: RLC may return zero even on link failure. See tests/README.md for the current commands and recorded result. The following direct build matches the RLC flags, avoids Godot dependencies, and successfully builds with RLC 0.4.13/Clang 21:

```bash
mkdir -p /workspace/4hammer-validation/corpus /workspace/4hammer-validation/artifacts
export LD_LIBRARY_PATH="/workspace/4hammer-validation/toolchain21/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
rlc src/full_game.rl -j 4 -O2 -g --fuzzer --sanitize \
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

Current validation is **120 PASS, 5 XFAIL, 0 XPASS**; state/observation schemas **6**, action schema **3**. Task 6 remains deferred by user instruction; task 8 is next. Fixed characteristics and objective aggregation/ties remain mandatory fixes. Resolve offboard source gate D10 when integrating reserves/passengers; do not infer a general recovery policy from the battlefield loop. That historical Python-based CTest configuration is superseded by the native runner described above; set `RLC_TEST_COMPILER` to select the compiler.

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

Use [the complete Orks audit](doc/factions/orks/orks-codebase-audit.md), [all 67 unit requirements](doc/factions/orks/orks-unit-requirements.tsv) and [the CP-card inventory](doc/factions/orks/orks-stratagem-costs.tsv) alongside ROADMAP.md. The faction page and every linked datasheet were readable on 2026-10-12; the scan includes Legends and Forge World. Audit completion is not implementation completion.

The user excludes unit/army/enhancement point accounting and detachment-point accounting. Support up to **three distinct detachments per player**, using bounded enum storage; do not count War Horde as three slots or enforce its printed DP cost. Continue tracking **CP costs**, discounts, surcharges, affordability, targets and use limits. Preserve all non-price eligibility and equipment rules. Explicitly accommodate point-free reserves rather than rejecting every Orks unit for missing points or inventing a unit-count reserve percentage; leave existing explicitly configured point-aware fixtures supported without developing a pricing system.

Implement one logically distinct batch/rule at a time, following the audit's dependency order and recording actual validation. Available Orks Leader/Support lists resolve that source gap, but task6 mechanics and other factions' permissions remain unfinished. Use web URLs and named abilities/sections for new citations, not fabricated core-PDF pages. Follow the audit's engine requirements, including compound dice, negated/conjunctive predicates, real loadout capacity, scoped event/use records, healing/revival, carrier-specific fractional seating, reaction permissions, hit provenance and psychic budgets. Do not silently turn oval/hull/multipart models into circles or leave confirmed defects unfixed.

## Army configuration and shared CP — batch 17.B

Read [the configuration report](doc/factions/orks/orks-configuration.md) and ROADMAP.md. `Faction` remains a legacy roster ID; `Board.armies[player]` / `army_for_player` holds actual `ArmyFaction`, a checked vector of at most three distinct `OrksDetachment` values and explicit reserve budget mode. Public roster selection uses point-free reserves, while standalone point-aware fixtures retain their default. Preserve every non-price reserve permission; never introduce an alternative percentage or DP budget.

Orks detachment selection uses a single enum and finish action, permits zero to three choices and automatically hands off after the third. All 15 packages are configuration options; their effects/cards/enhancements are later batches. The 40-card registry supplies base CP, package gates and common shocked/destroyed target policies, not their full printed action legality. Future consumers must still check source keywords, timing and triggers before committing expenditure. Free use consumes limits, and explicit final costs may increase by at most 1CP.

Schemas are state/observation **17**, action **13**. Keep `NEXT_STATE_SCHEMA_VERSION` one greater than `STATE_SCHEMA_VERSION`; equal endpoints make a zero-width storage range and break saves. Regenerate native libraries and Godot headers together. Avoid parameter names that shadow generated accessors: `final_cost`, rather than `cost`, is necessary when the function also calls `strat.cost()`. Preserve generated lifecycle methods and the existing grid/selectors.

Batch17.B is complete: 442 assertions /444 CTest entries, 16 focused native sanitizer cases, matching full headless Godot, completed gameplay/replay, ML and short mutation fuzzing pass. Consult the report/roadmap for artifacts and limits. Next is 17.C; do not mark detachments, their cards or datasheets implemented because their configuration/CP enum entries exist.

## Supported Orks source scope

The user excludes all Forge World and Warhammer Legends units, including Gargantuan Squiggoth. Implement only the54 standard datasheets from the67-card source audit. Retain historical audit rows/stable catalog codes as source records, with explicit excluded status; do not install excluded unit factories, abilities, permissions, weapons or geometry. Use generic core fixtures for modifier ignoring. Revisit capacity/geometry/permission requirements against included sources in the owning data batches; an excluded card is no longer a mandatory implementation dependency.

## Retire obsolete Orks implementation

The user authorises stripping the previous Orks implementation: it is no longer authoritative and need not be preserved for compatibility. Remove obsolete runtime cards/effects as the new source-driven batches replace them. Old profile/factory names still used by core regression fixtures may remain temporarily as explicitly uncertified scaffolding until17.H replaces the actual data; do not preserve their obsolete faction permissions or certify them as current datasheets.

## Keyword predicates — batch17.C1

Read [the predicate report](doc/factions/orks/orks-keyword-predicates.md) and ROADMAP.md. Weapon/Hunter conditions use `KeywordPredicate`: the conjunction of ALL, ANY and NONE groups. Unit queries use the union of constituent models; model queries use only that model's keywords. Retained models still in a unit remain constituents, while target/ability live-state checks are separate. Never flatten negations or adjacent source keywords into positive OR. Preserve each selected instance's condition, including temporary ANTI grants.

Store nine total keyword terms in contiguous groups with three bounded counts; compute the term count and semantic clause enum. Per-term categorical tags unnecessarily doubled the ML layout. The compact layout is14,493,920 observations with22,379 action candidates. Validate counts, total and keyword IDs before lookup; expand the documented bound explicitly for larger source conditions. Use typed count/keyword/clause bridges for Godot labels and refresh borrowed vector wrappers after mutations. Do not add custom lifecycle hooks or tensor encoding.

Schemas are state/observation **18**, action **14**, next-state **19**. The final suite passes465 assertions /467 CTest entries and24 native sanitizer cases. Full compact Godot interaction checks and focused final-body ANTI bindings pass. The two obsolete Orks card actions are removed; legacy profile factories remain uncertified scaffolding for later replacement. **Next:17.C2**, then17.C3–C4. ROADMAP.md holds final replay/fuzzer evidence; do not mark all17.C or any datasheet complete.

## Model characteristic consumers — batch17.C2a

Read [the model characteristic report](doc/model-characteristics.md) and ROADMAP.md. `Model.characteristic_modifiers` is a sparse checked list of16 enum/bounded records shared across characteristics. Filter by kind before the shared printed arithmetic; use the effective M/T/Sv/InSv/Ld/OC queries in actual consumers. Apply M arithmetic to the determined random base before movement extras; keep fixed Scouts/Surge distances distinct. Save groups use effective Sv/InSv, Leadership uses the best effective bearer value and Battle-shock's '-' still defeats OC bonuses. Legacy absent InSv (>6) is unmodifiable. Do not turn a model-scoped grant into a unit-wide effect.

Appendix05.02.01 requires the highest battlefield T for an unattached unit; keep the running maximum and exclude offboard models. Retained Fight on Death models remain battlefield constituents until removal, including for T. Attached bodyguard-only selection remains17.G. Guard bounded Toughness snapshots against silent clamping. Source grants, live auras and expiry must install/remove the correct records through their later source-instance consumers; this arithmetic infrastructure does not implement those effects.

Schemas are state/observation **19**, action **14**, next-state **20**. Final validation passes477 assertions /479 CTest entries,12 native sanitizer cases and focused matching Godot bindings. Compilation fixtures now allow600 seconds; individual assertions retain30 seconds. ROADMAP.md contains gameplay/ML/fuzzer measurements and limits. **Next:17.C2b**, weapon characteristic consumers; named selectors remain17.C2c, followed by17.C3/C4. Do not mark all17.C2 or any current datasheet complete.

## Fixed weapon queries — batch17.C2b1

Read [the fixed weapon report](doc/weapon-characteristics.md) and ROADMAP.md. Characteristic records share one16-entry list; `weapon_scope` is zero for bearer/all equipped weapons, otherwise slot+1. Use numeric operations when encoding printed improvements: improving AP/WS/BS subtracts from the stored number. Named physical-weapon grants still need17.C2c; one profile slot is not automatically every profile of a physical weapon.

Use effective Range for targets/replacements and half-range snapshots; keep the original ranged/melee category and special Melee/Torrent values. Gather effective S plus skill/AP operations. Core cover/Plunging Fire/AP increments belong before division/rounding, not after an already limited result. Compare effective skill/S/AP for identical groups. Refresh actual source/target IDs and battlefield T for each new group; stale context IDs must never choose another keyword subject. Bodyguard-only T stays17.G.

Borrowed Firing Deck declarations use carrier-wide modifiers; do not apply a carrier equipped-slot grant merely because its index matches the passenger's selected slot. Preserve generated lifecycle hooks, quad domains and Rules.gd/TraceManager.gd. RLC const declarations require literals: keep shared `MAX_WEAPON_SCOPES` equal to `MAX_WEAPONS+1`; the validation guard prevents capacity drift.

Schemas are state/observation20, action14, next-state21. ROADMAP.md owns final validation. **Next:17.C2b2**, A/D consumers, melee shares, random timing/re-rolls and complete D grouping. Named selectors remain17.C2c; source grants/auras/expiry and datasheets remain later batches. No current datasheet is certified by these fixtures.

Batch17.C2b1 final validation is497 assertions /499 CTest entries,20 native sanitizer cases, matching focused Godot and preserved/game replay plus54 mutation runs in65s. The measured layout is17,050,509 observations (+0.7%) with22,379 candidates; the final explicit-ID body fix does not alter it. Reconfigure CMake after adding test declarations: CTest alone does not regenerate its registration list. Intermediate source snapshots must remain buildable; the separate group-context commit was type-checked before the scoped query implementation.

## Attacks and Damage — batch17.C2b2

Read [the A/D report](doc/weapon-attacks-damage.md) and ROADMAP.md. Apply bearer/profile A before fixed melee shares; never multiply each split share again. At gathering, core bonuses contribute the difference of modified total A with/without the bonus, preserving printed arithmetic order. A locked zero replacement offers no melee selector. Retain the user-required assertion excluding random-A melee weapons.

Random ranged A remains independent per weapon at gathering; random D remains per damaging attack after allocation. Original dice and any permitted re-roll precede characteristic arithmetic. D group identity compares effective fixed values or the complete same-domain random mapping; fixed and random profiles remain distinct because of re-roll eligibility. Firing Deck uses carrier-wide numerical grants. Compound profile expressions, named selectors, live sources/expiry and incoming reductions remain later owners; these helpers do not install actual Orks grants or profiles.

Schemas are state/observation21, action14, next-state22. Regenerate matching libraries/headers; preserve the action domains, grid and Rules.gd/TraceManager.gd. Finish adding regression declarations before configuring/running CTest: editing the list while its fixture compiles makes the wrapper/library/source verification reject the run. Keep final and superseded checks distinct. ROADMAP.md records actual completion and final evidence.

Batch17.C2b2/17.C2b is complete:509 assertions /511 CTest entries,12 final sanitizer cases, matching focused Godot,878-action completed game,32.115s sanitized replay and24 mutation runs/69s pass. The layout is17,051,447 observations with22,379 candidates. **Next:17.C2c**, named selectors, then17.C3/C4.17.C2/task17 and actual Orks profiles remain pending.

## Named selectors — batch17.C2c

Read [the named-selector report](doc/named-selectors.md), [source crosswalk](doc/factions/orks/orks-named-identities.tsv) and ROADMAP.md. `named_identities.rl` catalogs67 datasheets,139 physical families and176 named profiles, including referenced enhancement/ability weapons without installing them. Stikka, Grabba Dragga and Snagga Klaw need distinct ranged/melee identities despite identical printed names. Known tags must match the actual profile's ranged/Melee classification. Standard source-row counts match all67 audit rows; referenced profiles are marked separately.

Store catalog identities as standard LinearlyDistributedInt codes, use enums only for typed queries/labels and keep unknown0 explicit. Never infer current datasheet identity from uncertified legacy factories or display strings. IDs are append-only within a schema; changing their order requires migration. New numeric fields and snapshots use generated lifecycle methods.

Characteristic filters conjunctively combine optional representative slot/physical group, family and profile. Family grants include all copies; profile grants exclude alternate profiles; physical grants include only that instance's nonzero group, with group0 matching only its own slot. Actual declared Range/skill/S/AP/A/D consumers use snapshotted names and current bearer grants. Firing Deck preserves passenger profile identity but applies carrier numerical grants; carrier equipped-instance grants and passenger-unit numerical buffs remain excluded. Typed label/read APIs avoid relying on unavailable fixed-array Godot getters.

Unit named queries use constituent identity union, model queries remain local, and datasheet-filtered model grants must not affect other constituents. Named/physical rule-grant helpers use existing per-slot declarations. Source installation/expiry, attachment lifecycle and actual stats/loadouts/abilities remain later owners. Schemas are state/observation22, action14, next-state23; preserve the grid and Rules.gd/TraceManager.gd. ROADMAP.md owns final validation and completion.

Batch17.C2c/17.C2 is complete:534 assertions /536 CTest entries,25 native sanitizer cases, matching focused Godot,878-action game,32.531s sanitized replay and50 mutation runs/62s pass. Layout:17,523,864 observations (+2.8%),22,379 candidates. **Next:17.C3**, Damaged, then17.C4. This is completed engine support; task17, live source effects and current profiles/abilities remain pending.

## Damaged — batch17.C3

Read [the Damaged report](doc/damaged.md) and ROADMAP.md. Core ability24.39 was verified in the cached Battlewagon tooltip: Damaged X gives -1 to a model's hit rolls while remaining wounds are at or below X. Store explicit `has_damaged` and standard bounded `damaged_threshold`; never infer the ability from low health or legacy factories. X can be zero; do not invent X>0 or X<starting-wounds constraints.

Every gathered group snapshots the actual bearer's current status, overriding stale context after damage/healing. Other models remain unaffected. Retained Fight on Death models at zero wounds still satisfy the condition; ordinary attack eligibility is separate. Firing Deck uses carrier status. Add the penalty to the ordinary hit sum before Heavy/engagement increments and the +/-1 cap; never modify WS/BS or subtract after capping. Keep Torrent and natural critical rules intact. Actual source data and selective ignoring remain later owners.

Schemas are state/observation23, action14, next-state24. Use generated lifecycle methods and matching rebuilt native/Godot artifacts; preserve grid/action domains and Rules.gd/TraceManager.gd. New fixture copies must reset `identity` before identification, and tests must read actual weapon skills rather than assume BS3. CurrentStateDescription has no equality trait; compare its `.value` explicitly. ROADMAP.md records final completion/evidence.

Batch17.C3 is complete:546 assertions /548 entries,12 native sanitizer cases, matching focused Godot,878-action game and20-step Gym pass. ROADMAP.md owns final replay/mutation evidence. **Next:17.C4**, incoming reductions and selective modifier ignoring; no current Orks datasheet is certified by these generic fixtures.

## Incoming AP/D — batch17.C4a

Read [the incoming modifier report](doc/incoming-attack-modifiers.md) and ROADMAP.md. Incoming recipient metadata is separate from outgoing bearer/profile grants. Merge its applicable any/ranged/melee AP/D operations before shared arithmetic, rounding and floors. Evaluate AP at actual allocation without changing InSv; evaluate normal/Devastating D once per allocated attack after original random rolls/re-rolls. Ordinary non-attack mortals bypass weapon characteristic modifiers.

Keep printed W/Sv/InSv allocation groups. Compare effective AP/D against every live recipient before grouping attacks, including the full random-D mapping: equality of rounded outgoing values alone is insufficient. Generated lifecycle, standard bounded storage, grid/action domains and Rules.gd/TraceManager.gd remain unchanged. Eight incoming entries share a16-operation combined limit; reject unsupported overflow rather than clamping. Source installation/conditions/expiry and actual datasheet grants retain later owners.

Schemas are state/observation24, action14, next-state25. 17.C4a is complete:558 assertions /560 entries,12 native sanitizer cases, matching focused Godot,878-action game,20-step Gym and fixed replay/mutation checks pass. ROADMAP.md owns final evidence and limits. Next is17.C4b, which must implement optional arbitrary subset selection with the correct player ownership and editor discovery (appendix02.02.02), rather than a blanket detrimental-modifier filter. Do not mark all17.C4 or actual Orks profiles complete.

## Shared17.D/E batch

The user requested implementing17.D and17.E together to avoid repeated compilation waits. Freeze both source/test lists, share final CTest/native/Godot/fuzzer builds and keep storage, physical/dice consumers, source infrastructure and reports in distinct buildable commits.17.C4b remains pending by the user's changed priority. Read [physical weapons/compound dice](doc/physical-weapons-compound-dice.md), [source instances/effects](doc/source-instances-effects.md) and ROADMAP.md.

The reviewed loadout envelope is13 profiles, group/scope14 and448 declarations (32×13+32 Firing Deck). Capacity does not authorise an option combination: actual Kill Tank quotas and all unit factories remain their source-data owners. Nazdreg's simultaneous ranged profiles are an explicit group permission; ordinary profile exclusivity and physical One Shot sharing remain. Physical Hazardous identity includes the original passenger weapon owner. Keep compound rolls as one to three explicit D3/D6 inputs plus intrinsic constant; re-roll every original die once before modifiers. Random-A melee remains asserted unsupported. Compute final random totals as a local Int and reject overflow before bounded assignment.

Source instances retain stable model/unit identities, exact rule codes, owner, interval limits and typed grants. Do not infer shared restrictions from names. Optional declines spend no usage; mandatory events cannot be skipped, and pending entries are rechecked. Legacy and source timing choices share controller groups. Source-model grants must resolve the model's current containing unit, including after transfer. Do not assign identities inside cancelled movement or ordinary shock as a side effect of empty event dispatch; actual setup/source registration supplies identities. Zero is never a resolvable unit/model handle.

Give each installed effect a unique linear key, copying the prototype before tagging it. Preserve overlapping sources independently. Expiry reaches all banks and casualty archives; next-own-turn uses the granting owner. Unit grants refresh returned members without duplication. Passive unit auras recheck live source, keywords and base range, removing on exit/death/disablement and reapplying on entry. Named/physical rule grants retain17.C2c selectors; stale declaration snapshots must check whether a source key remains active. Model-specific/wholly-within aura modes and specialized reaction handlers remain actual source-adapter work, never approximate them as unit auras.

Supported source/pending/effect/use capacities are64, effect keys1–4096 and rule codes1–512. Keep internal references linear; action selectors use their independent64-choice domain. Assert capacity overflow and rederive against playable army combinations as later adapters land. Stored numbers remain bounded/Bool/enum and generated lifecycle is retained. Avoid custom init/drop. RLC0.4.17 fixes the verified0.4.16 cleanup defect around constant-led Boolean expressions/direct constant loop bounds. Keep ordinary fixtures and generated lifecycle; no custom init/drop or compiler workarounds are required. The standalone diagnostic requested by the user remains outside the checkout. Use four compiler workers, unoptimized debug sanitizer builds and separate optimized validation builds.

Schemas are state/observation25, action15, next-state26 for this combined feature batch. MultipleChoises supplies source-selector buttons and source labels; Rules.gd/TraceManager.gd and quad coordinates remain unchanged. Regenerate matching bindings. ROADMAP.md owns final completion/evidence; no current complete Orks datasheet, CP-card effect, attachment or Waaagh/riled-up ability is certified by these generic fixtures.

Final shared17.D/E validation under0.4.17 passes596 assertions /598 CTest entries,38 cases in both unoptimized and optimized sanitizer/leak drivers, matching production source-button/weapon Godot checks,20-step finite Gym and preserved/game fuzzer replays plus41 mutation runs and a fresh878-action completed game. Four workers are configurable via RULE_TEST_COMPILER_JOBS; RULE_TEST_OPTIMIZE defaults OFF. Schemas25/15/25 (next26),22,678 action candidates and25,682,905 observations require matching ML policies. ROADMAP.md records concurrent-build timing, the retained historical slow-unit and limits; do not call it a controlled speedup. Next is17.C4b, then remaining source/data batches. The saved cloud setup/start draft pins0.4.17; saving does not publish it.


## Optional WS/BS and hit modifier subsets —17.C4b

Read [the modifier choice report](doc/modifier-ignoring.md) and updated architecture.17.C4 is complete within explicit WS/BS/hit scope; ROADMAP.md owns evidence. Next is17.F.619 supported assertions /621 CTest entries,23 unoptimized native sanitizer/leak cases, matching production Godot Apply/Ignore controls,20-step finite Gym and fixed replay plus43 mutation runs pass. Schemas26/16/26, next27;22,680 candidates and26,032,968 observations require matching policies/bindings.

Keep modifiers individual until optional selection, including beneficial items. Skill versus hit permission and any/ranged/melee scope follow the actual bearer/carrier. Re-rolls precede per-attack subsets; shared arithmetic/limits/caps follow them. Natural gates remain. Grouping compares original selectable lists and permission flags, not only all-applied sums. The no-permission aggregate path remains. ChooseAttackModifiers stores18 bounded operations and exposes one Bool, with ownership/UI restoration; never enumerate a2^18 mask or install a negative-only filter. Typed permission grants use existing exact-key source lifetime/archives. Other characteristic/roll ignoring needs the source adapter that introduces such an included rule (17.H–P); do not claim unqualified full support.

No actual unit grant is installed by these fixtures. Continue only54 standard Orks cards; all Forge World/Legends are excluded. Keep historical67 identity entries stable, and derive actual17.G permissions (10 Leader/7 Support),9 carrier requirements and17.H capacity review from included rows. Preserve small quad domains, Rules.gd/TraceManager.gd, generated lifecycle and bounded/linear/Bool/enum numeric storage. Compiler/core0.4.17, four workers, unoptimized debug and separately optimized fuzzer remain required. Keep logically distinct commits and source-linked rationale comments. Full rendered journeys and the recorded wrapper retrieval issue remain17.Q.


## Orks army rules and Warlord selection —17.F

Read [Orks army rules](doc/factions/orks/orks-army-rules.md), the updated architecture and supplied Warlord definition.17.F is complete as shared engine integration; next17.G resumes source-backed Orks Leader/Support mechanics. Current54 profiles/loadouts/specialized riled sources remain their datasheet owners. No Forge World/Legends adapter is authorized.

Current Waaagh! grants Advance re-rolls; riled grants5+ InSv, ranged Assault and charge permission when selected to Advance. Do not add old-edition melee A/S boosts. Keep sparse riled keys source-owned and separate overlapping permanent/timed copies. Own-unit passives follow the live source model's current unit across banks without external measurement; external auras keep battlefield/range/keyword gates. Snapshots of equipped/borrowed Assault keep the originating effect key. Preserve the selected Advance's stored charge waiver through buff changes and same-turn repositioning, then clear it at turn reset; unrelated restrictions remain.

War Cry is optional at either Command start, once per army per battle, until end of the next turn. Do not turn it into own-Command-only, next-start expiry or a round duration. Accepted effects outlive the source unit. Da Boss is mandatory at round start for the selected live Warlord with explicit metadata, grants literal1CP separately from Core CP and does not impose the inherited extra-CP flag as an unsupplied ceiling. Controller groups remain current player then opponent; own effects can be ordered freely.

The user supplied: select an army-faction CHARACTER unit, then a CHARACTER model; grant WARLORD. Required units/models constrain selection, with cannot-be-Warlord taking precedence. Preserve the stable selected model handle through transfer/death. Orks pre-formation UnitID/ModelID selectors use reserve buttons and selected_warlord_unit context; suppress battlefield clicks. Current unit adapters must supply real rule/keyword/required/prohibited metadata; do not certify a legacy roster by name.

Final648 assertions /650 CTest entries,29 unoptimized sanitizer/leak cases, matching Godot methods/buttons/click suppression, finite20-step Gym and preserved/game replays plus43 mutation runs pass. Schemas27/17/27, next28;22,746 candidates /26,128,335 observations require matching policies. Use compiler/core0.4.17 with four workers, unoptimized debug and separately optimized fuzzing. Release the harness-owned RLCLib Object before deferred quit. Preserve generated lifecycle, bounded numeric state, small quads, Rules.gd/TraceManager.gd and focused buildable commits. ROADMAP.md owns exact evidence and remaining fixes;17.Q retains wrapper performance/rendered integration.


## Attached units and included Orks permission metadata —17.G

Read [the attachment report](doc/attachments.md) and updated architecture.17.G implements the shared task6 core and all included10 Leader/seven Support lists; next17.H supplies current profiles/equipment/source adapters. Other factions still need permission data. Forge World/Legends stay excluded. Do not infer attachments from Character, size or a legacy factory's name: configure explicit roster datasheet/role/exact permission lists.

Keep one Leader and one Support slot, each potentially multi-model, in visible bounded `CheckedVector<AttachmentComponent,2>`. The bodyguard keeps the combined identity/starting strength after casualties; never split on bodyguard destruction. Every model/archive retains its original component, equipment/use history and Warlord handle. Use highest physical bodyguard T while any remain, then remaining Leader/Support maximum. Unit keyword union must not copy keywords into other models.

Typed unit abilities and source-instance grants follow their original component or specific bearer. Register live conditional sources before formation; their while-leading grants stay inactive until attachment. `requires_leading` means started attached even after bodyguard death. `source_alive` requires live source; `source_confers_rules` additionally supports p67's attacker interval. Destroyed retained models cannot become live action recipients. Release only the matching attacker before callbacks/removal and exclude retained corpses from half-strength. Single-model rule activation stays distinct. Whole-unit death waits for the final combined member and retains archived-bearer provenance; merge model/unit events in current-player then opponent groups. Revival provenance is implemented/tested, but actual heal/revive/setup remains17.J.

Painboss's Mounted/Mobile/Infantry/+4M changes apply only to that bearer; add4 through ordered arithmetic before division/rounding. Actual other Painboss abilities/profiles remain their data owner. The source-first `attach_unit` pair addresses reserves, so production choice-panel buttons label both units/role and battlefield clicks are suppressed. Preserve Rules.gd/TraceManager.gd, generated init/drop and small whole-quad coordinates.

Final682 assertions /684 CTests,34 unoptimized native sanitizer/leak cases, independent67-card/41-edge permission check, production attachment/Warlord/source Godot checks, finite20-step Gym, preserved and fresh1,000-action complete-game sanitized replays plus45 mutation runs pass. Schemas28/18/28, next29;22,746 candidates /26,183,041 observations require matching bindings/policies. ROADMAP.md owns pending-save evidence and the broad harness timeout; full rendered journeys/wrapper performance remain17.Q. Use compiler/core0.4.17 with `-j 4`, unoptimized debug and separate optimized fuzzer. Keep implementation/testing, editor controls and documentation in focused buildable commits.


## Current Orks profile/loadout data —17.H1

Read [the current data report](doc/factions/orks/orks-datasheets.md) and updated architecture.17.H1 adds source-backed data constructors for Beastboss, Beast Snagga Boyz and Squighog Boyz; next17.H2 implements Dodge Dis!, Keep Huntin', Mobbed, Bomb Squig and Brutal Impact. Proper oval geometry17.H3 and production roster promotion17.H4 remain mandatory before marking17.H/cards complete. All54 standard Orks units are planned. Exclude Forge World/Legends and points/detachment prices, while retaining CP rules.

Use the current raw HTML, not just the audit text: separate InSv boxes supply Beastboss5+, Snagga/Squighog6+, and the Hunter keyword header supplies MONSTER/VEHICLE. The constructors carry exact profile/weapon/keyword/Army Rules/attachment data, literal composition ranges and optional loadout checks. Thump Guns augment Boys' Choppa/Slugga. Choppa Standard/Hunter and Stikka ranged/melee share physical weapon identity. Current Big Choppa has Cleave2/S7; melee Stikka has no inherited Lance. New current data never inherits Morgrim/Beast Snagga/FNP grants from old factories.

Current Squighog models expose75x42/90x52 axes and set unsupported_footprint until real oval measurement/collision/setup/path/rotation/presentation exists on the existing quad anchors. Do not silently field them as circles or switch the public roster to incomplete adapters. Historical enum IDs/legacy fixtures remain stable; current data APIs use make_orks_* names. Current families need at most4 stored profiles per model and at most22 attached Snagga models; retain the validated13-profile/32-model envelopes while reviewing later included loadouts. Do not use excluded Kill Tank as a playable-data requirement.

The H1 enums/keywords change observation interpretation: schemas29/18/29, next30, with matching bindings/policies required. Keep stored numbers bounded/linear/Bool/enum and lifecycle generated. Native counts/source/Godot/fuzzer evidence belongs to ROADMAP.md. Avoid naming helper parameters after getter functions used in that body; catalog NamedWeapon/NamedWeaponProfile comparisons use .value because those enums do not define equal. Conditional attack rules query the current target, so capture pre-change expectations before mutating a target fixture. Preserve Rules.gd/TraceManager.gd, use compiler/core0.4.17 with -j4 written as separate arguments (-j 4), debug unoptimized and separate optimized fuzzing. Keep table/testing, constructor/binding and documentation commits separate and buildable.


## User update: oval approximation and combined work

The user now authorizes temporary circle geometry for oval bases. Preserve the original oval axes as immutable profile metadata and identify oval profiles explicitly, but use the long axis as the circle diameter consistently for distance, overlap, setup, paths, rotation and Godot rendering. Current Squighog Boy/Nob proxies are75/90mm circles for source75x42/90x52mm ovals. This overrides earlier instructions rejecting oval placement or prohibiting circle approximations. Exact oval geometry is deferred; unknown hull/multipart dimensions remain unsupported. Keep whole-quad anchors and bounded stored numbers.

Work on two related roadmap tasks in one implementation/validation batch when practical. The current pair is17.H2 special abilities and17.H3 temporary circular proxies. Finish source, tests and binding edits before costly compilation/testing, then validate the combined final state; rerun only affected checks after failures. Keep logically distinct, buildable commits and update ROADMAP statuses with actual evidence.


## Current Orks unit abilities and circular proxies —17.H2/H3

Read [the current ability report](doc/factions/orks/orks-datasheets.md) and ROADMAP.md.17.H2/H3 are complete within the user's temporary long-axis circle policy. Next17.H4 promotes the three current constructors into the production roster; parent17.H/full current-card gameplay remains incomplete. All54 standard cards stay planned; Forge World/Legends and price accounting remain excluded, CP retained.

Keep explicit source/component metadata: Keep Huntin' rule110 has two windows sharing one army-round counter; future Squigosaur adapters must reuse110. Bomb Squig rule111 is one original-unit battle token, spent when a target is accepted, including failed rolls. Idempotent registration must preserve these counters across formation, transfers/return and saves. Accepted riled grants survive source death and expire at next own turn through the common source framework. External target ranges/LOS require live battlefield units. Preserve Waaagh's selected-Advance permission snapshot; later Keep Huntin' cannot retroactively change an Advance selection.

Movement source dispatch combines targeted sources with ordinary grants in controller order, separately from destruction dispatch to avoid recursive action-frame ownership. choose_movement_source must remain distinct from choose_source_event; targeted Keep/Bomb/Mobbed actions each use one UnitID for Godot detection, with explicit labeled buttons. Dice remain roll/quantity for chance owner-1. Dodge Dis! stays a separate hit term/provenance before caps and optional ignoring; Brutal Impact enters ordinary outgoing D addition for all attacks after a completed charge. Mobbed uses the common shock pipeline with bounded-1/-2 penalties and target-owner restoration. Use live combined count for13+, not starting strength.

Preserve original oval axes/shape metadata, using75/90mm circle proxies throughout geometry and rendering until exact ovals are requested. Unknown hull/multipart data remains unsupported. Keep quads, bounded/linear/Bool/enum numbers, generated lifecycle and Rules.gd/TraceManager.gd unchanged. Source-table, native and Godot checks validate current adapters; legacy public-root fuzzer/full games do not certify roster promotion.

Current738 assertions /740 CTest entries have passing results across the initial739/740 run and corrected58/58 affected rerun;56 native sanitizer/leak cases, HTML tables, five Godot controls,20-step Gym, complete-game replays and20 mutation runs pass. ROADMAP.md owns exact logs, scope and corrected failures. Schemas30/19/30, next31;22,907 candidates /28,980,462 observations require matching policies. Compiler/core0.4.17, -j 4, unoptimized debug and separate-O2 fuzzing remain. Reuse compatible compiled Python bindings for Gym/gameplay; CTest's --pylib native library is not directly reusable in Godot, which needs the pure native build. LeakSanitizer may require execution outside the sandbox for process inspection; never disable its checks. Keep geometry/policy, ability/testing/binding and documentation commits separate and buildable.

## Current Orks roster and War Horde passive —17.H4/17.I1

Implement and validate these two batches together before the expensive shared
checks. Read [the roster/passive guide](doc/factions/orks/orks-roster-war-horde.md). Public Orks
selection now uses `make_orks_starter_roster`: Beastboss, four Squighogs and two
ten-model Snagga mobs with one Thump Gun each. Preserve the stable roster/action
identifier, label it current Orks, and exercise both players' actual mandatory
Warlord choices, reserve-ID compaction, attachment provenance, saves and combat.
Historical factories remain explicit core-test scaffolds; they must not be used
as evidence of current production cards. Oval models keep source axes and use
long-axis circles until exact geometry is authorized.

Get Stuck In is selected War Horde's friendly ORKS-unit melee Sustained Hits1,
including Extra Attacks. Gate it by source owner configuration, army faction,
unit keyword union and weapon profile; use ordinary declaration snapshots and
p78 duplicate selection. Beastboss conditional2 and unconditional1 are alternatives
selected before targets, never summed or automatically maximized.17.I1 covers
only this passive; enhancements/upgrades and six CP cards remain17.I2. Record
actual validation before marking17.H4/17.I1 complete. State/observation31,
action19; rebuild matching libraries/headers, preserve bounded ML state, whole
quads and editor action shapes. All54 standard cards remain planned.


17.H4/17.I1 executed evidence is in the latest ROADMAP.md section. All755
assertions have passing results across initial756/757 and corrected19/19 runs;
all17 new native sanitizer/leak cases, three Godot controls, HTML and unchanged
finite ML dimensions pass. Actual current-root mixed and two-Orks War Horde
games finish in1,158/1,346 legal actions. Read the exact replay/fuzzer evidence
and limits there; never substitute the earlier legacy-root traces as current
card validation. Next17.I2 upgrades/cards and independent17.J healing/revival
may be edited together, with expensive validation after edits.17.I1 is not full
War Horde completion, and the three starter families are not all54 cards.
Keep focused commits with each rule's own coverage and cite its actual source.

## Orks enhancement selection supplied by the user

Use the current core Select Enhancements rule together with the user's limits:
at most four counted enhancements, one per different unit, ordinary options
unique and on eligible CHARACTER bearers. An Upgrade may be on a non-CHARACTER
unit where its card permits; at most three copies of each Upgrade, with the
second and third copies excluded from the counted total. Epic Heroes and units
containing attached Epic Heroes cannot take any enhancement or Upgrade. Apply
these restrictions during selection and attachment; validate the final roster.
Do not calculate prices. Configuration may precede attachment to supply extra
Leader permissions and Flyboss CHARACTER membership; this is implementation
ordering, not a change to the final tabletop roster restrictions.

All noncircular footprints intentionally use circular proxies for now. Retain
source shape/axis metadata and annotate the approximation at geometry adapters.
Never fabricate an unknown hull size. The all-detachment batch remains in
progress until ROADMAP.md records actual effect and integration checks; enum
entries, eligibility tables and source extraction alone are not implementation.

Use [the ordinary detachment design](doc/factions/orks/orks-detachments.md) for the four package modules, source generations, cargo/offboard effects and flat reaction wrappers. Distinct enhancement recipients are original muster units; attaching two already enhanced units does not select another enhancement. The supplied Epic Hero exclusion still applies to the resulting attached unit. Turn/round timing windows run sequentially; reuse their completed child frame rather than retaining one inactive copy per boundary. Validate save/replay fixtures on the normal host stack. Record actual Game/layout growth and remaining performance work under17.Q.

Audit every new action frame's active lifetime before adding owning call-site storage. Frames that cannot have two simultaneous instances share one context slot in `Board.shared_actions` (or an existing direct Board slot); types with one existing owner can stay there. Check the entire descendant path for re-entry, including ordinary frame-producing helpers. Fully delegated siblings are sequential, but recursive descendants would invalidate sharing. Preserve required completed results in small caller-owned `frm` snapshots before another call overwrites the slot; do not copy whole frames. Run `python tools/check_action_frame_storage.py --wrapper <matching-wrapper.py> --output doc/action-frame-lifetimes.json` after regenerating bindings. Read the architecture guide's frame-sharing section; the static audit complements semantic, save/replay and sanitizer tests. Keep generated init/drop, bounded persisted fields and existing Godot action argument contracts.

Godot generated classes already use `get_member(index)` for structural access. Avoid persistent fields named `member`, which generate a colliding zero-argument `get_member`; use descriptive names such as `member_index`. Transient local loop names do not create exported getters. Regenerate the native library and headers together after binding fixes.

The combined ordinary-detachment and frame-sharing batch is complete within
ROADMAP.md's final evidence:111 action declarations/66 shared slots, Game34,544
inline bytes, schemas32/20/32 (next33); all15 passives/38 enhancements/40 CP cards.
Next17.P owns the remaining51 standard datasheet adapters and their specific
permissions/rules. Keep17.Q's measured wrapper retrieval/native slow-unit and
full rendered journeys as mandatory fixes; sharing frames is not a demonstrated
runtime speedup. Read the final roadmap section for test scope, corrected
binding fixtures and sanitizer/replay evidence. Do not reintroduce duplicate
serial frames or custom lifecycle hooks while adding the remaining units.


## Twelve current Orks adapters —17.P1

Read [the adapter guide](doc/factions/orks/orks-datasheets.md) and the latest ROADMAP
section. Boyz, Nobz, Warboss, Bigboss, Bannernob, Stormboyz, Warbikers, Deff Dread,
Killa Kans, Big Mek Dakkarig, Beastboss on Squigosaur and Mozrog now have checked
profiles/loadouts and source consumers.15/54 standard cards are implemented;
39 and arbitrary public roster selection remain17.P/17.Q. Keep source audits
and substantive regressions together in broad dependency batches, then run the
expensive builds once; rerun affected checks when corrections justify it.

Use original component identity for113/114 Ammo tokens, phase-owned effects
for ammo/Rokkit grants, existing110/112 shared army-round budgets, and live aura
queries. Rokkit selection belongs to SelectedFight before Overrun; ammo belongs
to own-Shooting attack selection. Per-unit hit contributions retain ignore
provenance and all34 choices/results must fit. Single-owner selection frames
stay with their callers; continue auditing every new frame for duplication and
re-entry. State/observation33, action21, next34 require matching bindings.
Warbiker75x42mm ovals intentionally use75mm circles. Preserve quads, bounded
state, generated init/drop, CP costs and excluded points/Forge World/Legends.

Executed evidence and limits are in ROADMAP: all931 assertions covered across
930 initial passes and59 corrected-source native sanitizer/individual CTest
passes;15-card HTML check; eight Godot controls; completed697-action game and
sanitized replay; separate semantic/action mutation campaigns. Godot validation
reuses the matching debug test engine with explicit installed libpython3.12
linkage; production pure-native build settings are unchanged. Godot rejects
RTLD_DEEPBIND loading under ASAN; keep native sanitizer/leak validation enabled
and separate. Fixed arrays need typed helpers/declarations, not direct generated
getters; normalize expected UI labels with GlobalRules.strip_symbols.


## Fourteen elite, Mek and Gretchin adapters —17.P2

Read [the adapter guide](doc/factions/orks/orks-datasheets.md) and the latest
ROADMAP section. Implement all fourteen related cards as one broad batch,
then validate the final combined state. The three Python migration commits
have been reverted at the user's request; keep native Rulebook assertions and
individual CTest registration. Do not add a compilation cache or port tests
back to Python. Compiler/core0.4.18 is installed; use four workers and keep
debug builds unoptimized. The user authorizes parallel builds to try the new
lower-memory compiler; report measured RSS and elapsed time without claiming
a controlled speedup from unlike workloads.

Healing must use one shared component frame for all banks, retain original
model identities/weapon usage and clear death-only flags. Gretchin transport
seats round the unit's actual Gretchin count up in pairs before adding ordinary
attached seats. Mek repairs target an actual model, preserve separate hit
contributions, reuse grant prototypes across turns and expire at next own
Movement. Kustom Force Field is ranged-only allocation InSv. Pulsa keeps one
target identity; Barrage reads successful hits; Shokk-boosta hazards count
actual models. Keep Runtherd correction shared and destruction-based.

Schema34/22/34 (next35) requires matching rebuilt clients. Executed validation
and remaining work are recorded in ROADMAP.md; this batch has994 passing
assertions and29/54 implemented cards, leaving25. Preserve quads, bounded
state, generated lifecycle, CP accounting
and excluded points/Forge World/Legends. The public roster picker and known
performance/rendered integration fixes remain17.Q.


17.P2 validation uses native Rulebook tests, not a Python migration or new
build cache. All63 new assertions also pass optimized ASAN/UBSAN/leak checks;
29-card HTML and67-card/41-edge permissions,120-frame storage audit, nine
Godot controls,20-step finite Gym and a fresh697-action game pass. Actual
parallel final native builds use about1.67/2.07GiB peak RSS for debug tests and
optimized sanitized fuzzer. Their elapsed times are281.773/268.733s under
concurrent validation, not a controlled speed comparison. Preserve Clang21
resource lookup when invoking it via virtual-environment links; RLC can return
zero after a linker failure, so require an actual runnable executable. The
saved cloud install/start draft pins0.4.18 and includes the runtime links;
saving the draft does not publish it. Follow the final ROADMAP evidence for
mutation/replay scope and the remaining17.P/17.Q fixes.


## Final25 standard Orks adapters —17.P3

Read [the final-card guide](doc/factions/orks/orks-datasheets.md) and ROADMAP.md. All54
included standard cards now have profile/loadout/source adapters. The final25
use `datasheets.rl` and the runtime domains in the module map; their111 new native
regressions bring the suite to1,105 passing assertions. Source metadata still
includes excluded identities for stable catalogs/permission audits, not playable
Forge World/Legends factories. Arbitrary public roster selection and the known
performance/rendered fixes remain mandatory17.Q work.

User policy2026-10-15 authorizes deliberately imprecise large circles for
Use-model hulls. Zero constructor input selects160mm Battlewagon/Gunwagon/Bunka,
100mm Mek Gunz,240mm Stompa,140mm Trukk; a positive bounded diameter overrides
it. These are arbitrary temporary proxies, not source dimensions. Keep source
base metadata0 and use the shared model-radius adapter. Retain oval short axes
and intentional long-axis circles. Preserve quads, bounded numeric state,
generated lifecycle, CP accounting and excluded points/detachment prices.

Keep source-event sequencing for bombs/withdrawals/Shadows/engines/Race; engine
expiry is next own Command. Use separate trigger/effect codes (Burna141/176),
original usage identities and one shared psychic-level pool. Registered sources
must recheck the live conferring ability: surviving bodyguards do not keep
Snikrot/Wartrike windows after their character dies. Preserve Squig Launchas hit
provenance through grouping. Disembark never owns Movement:
MovementPhase copies its completed/mode/slot results before tactical follow-up.
Ordinary/reactive exits and datasheet psychic rolls each share one context slot.
Makari/passenger/split-model editor choices use their real banks; keep Rules.gd
and TraceManager.gd unchanged. Every new function/action still needs source
rationale and actual regression coverage in its focused commit.

Executed evidence is in ROADMAP:54-card/253-row HTML audit,41 permission edges,
128 action routines/70 shared slots, Game40,096 / Board34,864 bytes; new111-case
sanitizer sweep, separate actual semantic/action mutations, preserved memory
replays/completed697-action game, ten Godot scripts and20-step finite Gym.
Schemas35/23/35 (next36) and31,185 candidates/16,368,602 observations require
matching clients. The public-roster Godot script exceeded180s concurrently and
passed alone with600s timeout; retain the performance fix in17.Q rather than
claiming a speedup. Native tests remain Rulebook/CTest, with no Python migration
or build-cache infrastructure. RLC0.4.18 uses-j4 (written `-j 4`); keep debug
unoptimized and optimized sanitizer builds separate.


## Current integration scope —17.Q

The user excludes rendered integration from this batch. Finish public roster
selection, non-rendering rule/host integration and review corrections. The user
will optimize valid-action discovery in the compiler: do not optimize, cache or
replace action enumeration, host filtering, legal masks or wrapper fetching.
Leave Rules.gd/TraceManager.gd's discovery paths unchanged. Earlier roadmap
requirements to optimize discovery are superseded by this instruction.

User ruling2026-10-15 requires one connected coherent group, in addition to the
printed neighbour and maximum-distance conditions. Two disconnected pairs are
illegal even when each pair has neighbours and the full unit fits within9in.
Use the2in horizontal/5in vertical neighbour graph over living models; corpses
cannot connect living groups. This resolves the printed-rule loophole by user
authority; do not silently remove the extra connectivity requirement.

User instruction2026-10-15: avoid separate rule implementations for offboard
units. Own-unit eligibility, CP/usage, psychic spending, rolls, grants, healing,
revival, mortality and death handling must share implementations across all
banks. Keep only bank selection and genuine range/visibility/placement/capacity
adapters. Read [the public roster/integration guide](doc/factions/orks/orks-custom-roster.md).
`orks_became_shocked` and `use_orks_psychic` store stable unit identities;
`DamageJob.bank` feeds the common damage engine. Do not restore an Orks-specific
offboard mortal/death engine or duplicate Breakin' Heads/Visions/Surly frames.
Restore `Board.damage_bank` after nested damage; Godot offboard choices must use
buttons against the actual bank, never stale battlefield indices. Surly uses the
normal model reset and reactivates an emptied unit. Destroying an unplaceable
transport must expire its passengers before the carrier models disappear.

Command Battle-shock must also use one bank scan and freeze recovery eligibility
for all units at STEP start (core p30; appendix01.02.04). A reserve/passenger unit
gaining shock during an earlier unit's test must not clear that new shock on a
later passed test. The final Command-scan follow-up uses state/observation37,
action24 and next-state38; earlier36/24 completion evidence is historical.


17.Q is complete within the user's supplied Orks/non-rendering/grid scope.
Final state/observation37, action24 and next-state38 pass1,184 native CTest
assertions,20 focused Godot scripts plus the full broad walkthrough,54-card
source audits, frame/finite-ML checks, four completed games and their sanitized
replays,79 new semantic sanitizer cases and separate semantic/action mutation
campaigns. See ROADMAP.md for exact evidence and remaining mission/geometry
limits. The broad Godot run is slow through unchanged discovery; the user owns
that compiler optimization. Pure Rulebook tests must remain entirely native.

## Shared ability procedures — generic-army refactor step5

User clarification2026-10-15: prioritize mechanics that other armies can reuse;
a refactor need not shrink every commit. Still measure all runtime sources,
including new generic modules, and report tests/docs separately. Keep distinct
concerns in distinct commits and preserve actual rule behavior.

Use `RoundResourceBudget` and `roll_spent_round_resource` for round-limited
resource rolls; callers own capacity, eligibility and effects. Use `reactive_move`
or `granted_move` for supported out-of-phase moves, retaining source restrictions
and restoring caller roles/constraints. `healing_rules.rl` owns `heal_unit` and
`return_model`: supply the real Board/Unit contexts, bank, placement policy and
bounded amount. Ordinary healing excludes Character casualties; explicit return
abilities call the shared return directly. Do not recreate faction/offboard
versions or three-wound chunk wrappers. Preserve original identity/equipment,
phase-start anchors, nearest-return constraints and real passenger capacity.

Orks adapters still own psychic failure/shock, source-specific usage, target
eligibility and effects. Generic procedures are not permission to apply an
ability absent from a datasheet. Targeted effects already use core damage/jobs
and source grants; do not add an unused universal ability interpreter. Review
shared frame lifetimes before introducing nested granted moves or returns.

Read the architecture guide and the final step5 ROADMAP evidence for the current
schema40/26 (state and observation40, action26, next-state41), validation and
remaining scope. The6 new faction-free assertions bring native CTest to1,190
assertions plus its compilation fixture. The generated Godot procedure test
also covers faction-free resource/reroll, movement, healing and model return.

The subsequent cleanup removes four unused legacy actions and five unused
helpers; see ROADMAP.md for names and evidence. Public attacks use declarations,
reserve arrivals use MovementPhase, and roster selection owns creation. Preserve
the still-tested `single_attack`, documented external `deployment_position_valid`
and compiler-invoked `gen_methods`/`fuzz`. Do not infer dead code from textual
reference counts alone, or remove active Orks hooks before replacing their
grant/source consumers. Original coverage inventories remain historical records.

## Orks responsibility cleanup —2026-10-16

The final module layout and construction/usage conventions are described at the
start of this file and in the Orks module map. Do not restore runtime categories
based on implementation order. Keep all54 current datasheets together; organize
abilities by their actual mechanic and share counters/procedures with other
armies. `make_source_usage` builds a specification only; owner, stable identities,
scope and phase/turn/round/battle limits must be explicit. Preserve live-conferral
rules and registration/contribution order when merging adapters.

Current state/observation41, action26 and next-state42 supersede the historical
versions above. Renamed internal frame fields require matching clients; public
action payload layout remains identical. Latest validation is1,193 native
assertions plus the compile fixture, exact54-default/184-variant constructor
comparisons, full frame/layout/source audits, focused Godot checks and sanitized
semantic/replay/mutation runs. Read the latest ROADMAP section for exact evidence
and limits. This cleanup removes17 batch helpers and317 runtime lines; further
shared-engine file proposals are pending, not authorization to implement them.

## Finite source labels —2026-10-16

Source records now store `Hidden<SourceLabel>` instead of display strings.
Choose a fixed enum value when registering an ability; `source_label_text`
materializes presentation text only on request. Keep rule codes/scopes as the
actual behavior/use identities. Source validation rejects unknown raw enum
values, including in saved state. Do not reintroduce owning labels or custom
init/drop for this metadata.

Latest completed schemas are state/observation42, action26 and next-state43;
older counts/versions above are historical. Final1,195 native assertions plus
the compile fixture, source/layout/frame audits, four focused Godot scripts and
sanitized source/memory/game/mutation checks pass. See the latest ROADMAP section
for evidence. The representation saves16 bytes per source record and eliminates
its label allocation/copy ownership without changing public action layouts.


## One weapon catalog and future faction behavior boundary —2026-10-16

Use actual `Weapon` entries for both model equipment and legal choice lists.
`EquippedWeapon` stores only `profile` and bounded `secondary_profile_of`: zero
is independent; positive N references the earlier same-model primary slot N−1.
No chains, self/future links or cross-family links. Derive family/exact-profile
selectors from the single catalog; do not restore NamedWeapon,
NamedWeaponProfile, Orks equipment-choice enums or parallel Model identity/group
arrays. Paired equipment holds two actual weapons. Set source-card defaults
explicitly; generated init/drop owns all fields. Nonattacking KFF/Pulsa tokens
must never offer attacks. Preserve Nazdreg's sourced simultaneous exception and
physical-copy One Shot/Hazardous provenance. The13-slot envelope is unchanged.

Latest completed schemas are state/observation43, action26, next-state44.
Matching clients are required; public action payload layout is identical.
The final ROADMAP evidence records1,198 native assertions plus compilation,
ten Godot scripts,54-card/source and238-roster comparisons, frame/finite-ML
checks and sanitized semantic/memory/game/mutation checks. Runtime sources
shrink568 lines; pure rule tests remain native with no Python runner/cache.

The user's next architecture goal concerns **functions and actions**, and
shared enums may retain Orks entries. Read the
[faction dispatch proposal](doc/faction-dispatch-review.md) and ROADMAP before
implementation. Core should call neutral mechanics/lifecycle queries and action
hooks; the composition layer dispatches to Orks domain adapters. Move whole
faction choice bodies, not just call names, while core retains controller order,
mandatory gates and common procedures. Extract already-generic source lifetime/
pool helpers into core. Keep all banks, original source provenance, CP/use rules,
Godot payloads and shared-frame non-re-entry. The assessment is documentation;
no dispatch implementation is included in this completed weapon change.
