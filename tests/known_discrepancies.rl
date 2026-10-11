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

# Rule 14.02, p.52. Two OC1 models beat one OC2 model only with an extra OC1.
fun test_14_02_sum_objective_control() -> Bool:
    let board : Board
    let friendly = make_infernus_squad()
    friendly.models.erase(4)
    friendly.models.erase(3)
    friendly.move_to(make_board_position(10, 10))
    friendly.owned_by_player1 = false
    let enemy = make_beast_snagga_boyz()
    while enemy.models.size() > 1:
        enemy.models.erase(enemy.models.size() - 1)
    enemy.move_to(make_board_position(10, 10))
    enemy.owned_by_player1 = true
    board.units.append(friendly)
    board.units.append(enemy)
    return board.get_objective_controller(10, 10) == 0

# Rule 14.02, p.52. An unsecured equal nonzero total is uncontrolled.
fun test_14_02_tied_objective_uncontrolled() -> Bool:
    let board : Board
    let a = make_tantus()
    a.move_to(make_board_position(10, 10))
    let b = a
    b.owned_by_player1 = true
    board.units.append(a)
    board.units.append(b)
    return board.get_objective_controller(10, 10) == -1

# Rule 01.07, p.9. Battle-shocked models contribute no OC.
fun test_01_07_shock_removes_objective_control() -> Bool:
    let board : Board
    let unit = make_tantus()
    unit.move_to(make_board_position(10, 10))
    unit.battle_socked = true
    board.units.append(unit)
    return board.get_objective_controller(10, 10) == -1

# Rule 15.01, p.54. A 1CP stratagem is affordable with 1CP.
# Rule 15.01, p.54. Usage belongs to the player who used the stratagem.
# Rule 08.02, p.30. Core CP gain must not disappear at the arbitrary storage cap.
# Does not assert a general additional-CP-generation policy (external gate D12).
# Rule 09.06, p.33. D6=5 must provide the complete five-inch increment.
# Rule 08.03, p.30. Opponent's shock is not cleared by our Command phase.
fun test_08_03_opponent_shock_persists() -> Bool:
    let board : Board
    let unit = make_tantus()
    unit.owned_by_player1 = true
    unit.battle_socked = true
    board.units.append(unit)
    let step = battle_shock_step(board)
    return board[0].battle_socked
