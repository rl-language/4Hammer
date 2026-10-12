# Attacks and Damage — batch17.C2b2

Authority: core declarations/grouping p.17, allocation/damage p.19, Rapid Fire/Melta/Cleave pp.79–83, Command Re-roll p.56, and the user-supplied [Modifiers, Random Characteristics and Re-rolls appendix](11th-edition-supplied-appendix.md) 02.02.01/02.02.03/01.05.02. This is engine support; it does not install or certify current Orks datasheets.

The existing sparse bearer/profile modifier records now feed A and D. Firing Deck keeps carrier-wide scope and excludes unrelated carrier equipped-slot grants. Fixed melee A is modified before shares are assigned. Each target receives its declared share without multiplying it again. Target-specific core gathering bonuses enter addition before division/subtraction/rounding; gathering adds the difference between total modified A with and without that bonus. A locked zero replacement offers no share selector. The user-directed assertion excluding random-A melee weapons remains.

Ranged A is determined separately per selected weapon at gathering. Damage remains per damaging attack, after allocation, for both ordinary and Devastating Wounds. Original random dice and any one permitted Command Re-roll precede characteristic arithmetic; Rapid Fire/Blast/Cleave/Melta increments enter the addition step. Result storage remains bounded and unsupported overflow asserts rather than silently clamping. Compound printed dice expressions such as D6+1 remain17.D; this batch does not reinterpret a printed expression's literal term as a modifier.

Gathered groups retain D operations. Fixed damage groups compare effective D. Random damage groups require the same original die domain and equal effective results for every possible original face. Fixed and random expressions remain distinct because random characteristics permit a re-roll. Matching AP/S/skill and all other existing group requirements still apply.

State/observation schema21 and next-state22 account for new bounded operation snapshots in attack/coroutine state. Action schema14 and quad input domains are unchanged. Native libraries and Godot headers must be regenerated together. Source grants, named physical weapon selectors, conditional auras, incoming reductions and datasheets remain their later roadmap batches.

The final CTest run passes509 assertions /511 registered entries with an empty discrepancy manifest in292.22s (`/workspace/4hammer-validation/task17c2b2-ctest-final.log`). All12 focused final native cases pass ASAN/UBSAN and leak detection (`task17c2b2-sanitized-final.log`). Matching generated header/C++/native bindings in `task17c2b2-godot` pass the weapon and prior model scripts; the complete interaction harness/rendered journeys were not rerun.

Both preserved lifetime inputs and fixed zero input pass the final fuzzer (`task17c2b2-replay-preserved.log`). A fresh short-seed mutation campaign completes24 runs in69s, coverage8,139 /features11,381, with no failures or artifacts (`task17c2b2-fuzz.log`). This bounded search is robustness evidence, not proof of tabletop semantics.

Gym completes20 steps with22,379 candidates and17,051,447 finite observations (`task17c2b2-gym.log`): only938 more observation values than17.C2b1. The first CTest attempt was correctly rejected after declarations changed during compilation; it is superseded by the frozen final run, not counted as a passing check.

Current-schema seed40000 completes878 actions, terminal owner-4 (`task17c2b2-gameplay.log`, `task17c2b2-replays`). Its final sanitized replay passes in32.115s (`task17c2b2-replay-game.log`). These legacy scaffold rosters establish integration, not current datasheet correctness.

17.C2b is complete. Next is17.C2c, named selectors;17.C2 and task17 remain in progress.
