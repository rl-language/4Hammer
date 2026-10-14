# Task 2 — validation baseline

Recorded 2026-10-11 against tracked source HEAD `e7e0a21fb482bd79609f6a88fc691a53652716ab`. No game implementation or Godot action signatures changed. Tests, runners and toolchain preparation were added; edition mechanics remain pending.

## Executed checks

| Check | Observed result | What it establishes |
| --- | --- | --- |
| `python tools/run_rule_tests.py` | 12 RUN / 12 OK in supported suite; 12 XFAIL / 0 XPASS in discrepancy suite; exit 0 | Supported contracts pass; all individually enumerated discrepancies are reproduced, not silently skipped. |
| Existing full-game `rlc-random`, one iteration, 200 actions | Exit 0; exactly 200 actions | Bounded gameplay only; does not claim completion. |
| Existing shooting `rlc-random`, three iterations, shared 5000-action budget | Exit 0; three completed scenarios, 13/12/21 actions | All three finish well within the shared budget; does not establish that attacks were generated. |
| Seeded full-game runner, seed 40000 | Completed in 376 actions; 4499 enumerated payloads; final owner -4 | Legal-choice checks, action text round trips and terminal-state completion for Vengeful Brethren vs Morgrim's Butchas. |
| Seeded shooting runner, seed 40000 | Completed in 11 actions; 67 enumerated payloads; final owner -4 | Scenario completes and payloads round-trip; recorded trace contains weapon selections but no dice because fixed attack counts evaluate to zero. |
| Python JIT / gym wrapper | 20 steps; 4499 actions; observation size 6551; finite observations | Current Python/ML interface can compile, select legal actions and step. This is not a trained-policy or Godot GUI check. |
| Clang/sanitizer toolchain | Clang 19.1.7; five SHA256-checked Debian packages extracted under `/workspace/4hammer-validation/toolchain` | Required linker/compiler runtimes are now available without a system installation. |
| Direct optimized sanitized fuzzer build | Exit 0, using debug info, precondition and bounds checks | Repository full-game fuzzer builds; no Godot/CMake build needed. |
| Mutation campaign, seed 40000, 60-second requested duration | Exit 0; 640 runs in 61 seconds; final coverage counter 6318, feature count 18991, corpus 230 inputs; no failure artifact | No crash/assertion/sanitizer failure was reported in this bounded campaign. Counters describe instrumentation coverage, not rule coverage. |
| Fixed-input sanitized replay | Full-game 376-choice input and shooting 11-choice input both exit 0 | Those two saved input sequences replay through the native fuzzer; these are fixed-input checks, not additional mutation campaigns. |

Logs, native executable, downloaded packages, traces, seeded input binaries and JSON outcomes are in `/workspace/4hammer-validation`. Generated artifacts remain outside the repository. Commands and pinned toolchain recreation are in [tests/README.md](../tests/README.md).

## Deterministic suite and discrepancies

[The supported suite](../tests/python/baseline.py) covers random-characteristic legality, failed/successful hit-stage transitions, equal Strength/Toughness, normal damage not spilling, ordinary mortal damage spilling, stable ownership, move-distance legality, declining rerolls, initial action legality, army-selection ownership and unit serialization.

[The desired-rule assertions](../tests/python/known_discrepancies.py) and [manifest](../tests/known_discrepancies.json) reproduce these twelve problems:

| Problem | Source | Classification / implementation owner |
| --- | --- | --- |
| Fixed characteristics evaluate to zero: `raw_stat` stores a bounded integer but the evaluator checks `stat is Int`. | 02.04 / 04.03, pp.10/17 | Existing evaluator defect; task 9. It affects attack counts and potentially fixed damage. Shooting completion is consequently weak evidence. |
| Strength exactly twice Toughness returns the wrong wound threshold. | 05.02, p.18 | Existing comparison defect; task 9. |
| Strength exactly half Toughness returns the wrong wound threshold. | 05.02, p.18 | Existing comparison defect; task 9. |
| Mixed Leadership uses the highest threshold instead of success against at least one characteristic. | 01.06, p.9 | Source conflict; old-edition provenance not established; task 7. |
| Objective control overwrites contributions instead of summing. | 14.02, p.52 | Existing aggregation defect; task 8. |
| Nonzero unsecured objective ties favor player 1. | 14.02, p.52 | Existing tie-handling defect; task 8. |
| Battle-shock does not remove OC contribution. | 01.07, p.9 | Missing shock effect; tasks 7/8. |
| Stratagem eligibility uses Heroic Intervention's cost instead of the requested stratagem's cost. | 15.01, p.54 | Existing wrong-cost defect; task 5. |
| Stratagem usage is checked for the opposing player. | 15.01, p.54 | Existing wrong-player defect; task 5. |
| Core CP gain disappears when the arbitrary storage bound is reached. | 08.02, p.30 | Capacity defect; task 3. Does not resolve missing general additional-CP policy D12. |
| An Advance increment of five inches is truncated. | 09.06, p.33 | Capacity defect; task 3, then movement task 11. |
| Our Battle-shock step clears the opponent's existing shock. | 08.03, p.30 | Lifecycle must change; task 7. |

Expected failures assert desired behavior and return false on current code. Crashes, missing tests and unexpected passes fail the runner. Fixes must promote the assertions into the supported suite and remove their manifest entries. These are independent regressions, not tests asserting that incorrect behavior should continue.

## Limits and handoff

The initially empty attacking-unit fixture caused a native crash because `required_wound_roll` dereferences the source unit. The fixture was corrected to supply a valid source; no engine code was changed or checks disabled. That setup error is not counted as a reproduced gameplay defect.

Only the twelve listed discrepancies have deterministic reproductions here. The coverage map's other source-inspection risks, including chance classification for `reroll_pair`, remain work for their owning tasks. No claim is made that all published mechanics, all factions, all save/charge/fight paths or rare interactions are tested.

The fuzzer harness checks legal-action progress and native safety, not game semantics; 640 runs are a starting baseline. The public 5000-action bound and finite action enumeration need review as the new workflows grow. Semantic tests and focused corpus seeds must grow with each migration task.

Godot GUI, generated Godot bindings, web builds and the repository-wide CMake build were not exercised in task 2. Current state/action shapes were preserved. Missing faction/mission/app definitions and the twelve source gates remain unresolved.

Task 2 is complete as a validation baseline, with the known failures recorded. Next is task 3: state/identity/capacity foundations. Do not expand this completion claim into edition compliance or silently fix unrelated rule workflows.
