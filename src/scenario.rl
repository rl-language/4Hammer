import rules

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

@classes
act play() -> Game: # required
    frm board : Board # required
    board.oath_of_moment_target = MAX_UNIT_COUNT 
    board.players_faction[0] = Faction::strike_force_octavius
    make_octavious_strike_force(board.reserve_units, false)
    board.players_faction[1] = Faction::strike_force_octavius
    make_octavious_strike_force(board.reserve_units, true)

    act pick_starting_player(Bool first_player)
    board.starting_player = first_player 

    subaction*(board) battle = battle(board) 


fun score(Game g, Int player_id) -> Float:
    return float(g.board.score[player_id].value) 


fun log_p1_score(Game g) -> Int:
    return g.board.score[0].value 

fun log_p1_winner(Game g) -> Int:
    return int(g.board.score[0].value > g.board.score[1].value)

fun log_p2_score(Game g) -> Int:
    return g.board.score[1].value

fun log_models_left1(Game g) -> Int:
    return g.board.count_models(0)

fun log_models_left2(Game g) -> Int:
    return g.board.count_models(1)
