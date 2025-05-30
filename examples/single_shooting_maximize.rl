import rules

@classes 
act play() -> Game:
    # create the board, set player zero as current player
    frm board : Board
    board.current_player = false

    # create enemy unit
    board.units.append(make_infernus_squad())
    board.units[0].owned_by_player1 = true
    board.units[0].move_to(make_board_position(10, 10))
    board.units[0].arrange()

    # select the unit to spawn, and spawn it
    act use_legionaries(Bool do_it)
    if do_it:
        board.units.append(make_legionaries())
    else:
        board.units.append(make_terminator_squad())

    board.units[1].owned_by_player1 = false
    board.units[1].move_to(make_board_position(5, 10))
    board.units[1].arrange()
    let source_id : UnitID
    source_id = 1
    let target_id : UnitID
    target_id = 0
    board.attack = attack(board, source_id, target_id, false, false)

    # resolve an attack
    subaction*(board) board.attack

# use the same decision making as a normal game
fun get_current_player(Game g) -> Int:
    if g.is_done():
        return -4
    let d : Dice
    d.value = 1
    if can g.roll(d):
        return -1
    if can g.reroll(d):
        return -1
    if can g.quantity(d):
        return -1
    return int(g.board.current_decision_maker)


fun score(Game g, Int player_id) -> Float:
    if g.board.units.size() < 2:
        return 0.0
    let count = g.board.units[1].models.size()
    if player_id == 0:
        # Player 0's score: models destroyed in player 1's unit
        return float(5- count)
    else:
        # Player 1's score: models remaining in their unit
        return float(count)

fun log_alive_models_player1(Game g) -> Int:
    return g.board.count_models(0)

fun log_alive_models_player2(Game g) -> Int:
    return g.board.count_models(1)

fun get_num_players() -> Int:
    return 2

fun max_game_lenght() -> Int:
    return 5000
