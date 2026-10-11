import full_game

# These tests assert the desired contract, not the existing incorrect result.
# The Python baseline runner records each individually as an expected failure.
# Move passing cases into baseline.rl and remove the manifest entry when fixed.

# Rules 02.04/04.03, pp.10/17: a fixed A characteristic supplies that many dice.
# The implementation checks `stat is Int` although raw_stat wraps a bounded Int.
fun test_02_04_fixed_attack_characteristic() -> Bool:
    let attacks = evaluate_random_stat(raw_stat(4))
    return attacks.is_done() and attacks.result.value == 4

# Rule 05.02, p.18. Existing strict > misses the exact double boundary.
fun test_05_02_exact_double_strength() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    let info : AttackSequenceInfo
    info.source = Weapon::captain_storm_bolter
    info.target_toughness = info.source.strenght() / 2
    return required_wound_roll(board, info) == 2

# Rule 05.02, p.18. Existing strict < misses the exact half boundary.
fun test_05_02_exact_half_strength() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    let info : AttackSequenceInfo
    info.source = Weapon::captain_storm_bolter
    info.target_toughness = info.source.strenght() * 2
    return required_wound_roll(board, info) == 6

