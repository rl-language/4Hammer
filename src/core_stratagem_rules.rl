import fight_rules
import terrain_rules

# p.58: mission definitions supply timing, units, use limits and effects.
# This generic gate deliberately does not create the unplayable example action.
fun action_start_valid(Board board, UnitID source, Bool player) -> Bool:
    if source.get() >= board.units.size() or board[source].owned_by_player1 != player or !has_live_model(board[source]) or !board[source].allows_action_start():
        return false
    if board.is_in_melee(board[source]) and !board[source].has_keyword(Keyword::titanic):
        return false
    let control = false
    for i in range(board[source].models.size()):
        control = control or board[source].model_objective_control(i) > 0
    return control

# p.58: generic start commits turn restrictions and pending completion only;
# a supplied mission must first validate its own additional conditions/limit.
fun begin_unit_action(Board board, UnitID source, Bool player) -> Bool:
    if !action_start_valid(board, source, player):
        return false
    assert(board[source].history.action_records.has_capacity(), "unit action history capacity exceeded")
    let progress : UnitActionProgress
    progress.started_turn = board.turn_serial.value + 1
    board[source].history.action_records.append(progress)
    board[source].history.action_started = true
    board[source].history.action_pending = true
    board[source].history.action_failed = false
    board[source].history.action_completed = false
    return true

# p.58: a turn stamp uniquely identifies each unit's action (one start/turn).
# A mission retains it when starting; earlier pending actions can coexist.
fun action_progress_index(Unit unit, TurnStamp started) -> Int:
    for i in range(unit.history.action_records.size()):
        if unit.history.action_records[i].started_turn == started:
            return i
    return -1

# pp.9/58: completion checks the specific mission action's movement/departure
# history, battlefield membership and current shock; melee moves are exempt.
fun action_completion_valid(Board board, UnitID source, TurnStamp started) -> Bool:
    if source.get() >= board.units.size() or !has_live_model(board[source]) or !board[source].allows_action_completion():
        return false
    let index = action_progress_index(board[source], started)
    return index >= 0 and !board[source].history.action_records[index].resolved and !board[source].history.action_records[index].failed

# p.58 infrastructure: convenience overload refers to the latest started action;
# cross-turn mission consumers use the explicit start-stamp overload above.
fun action_completion_valid(Board board, UnitID source) -> Bool:
    if source.get() >= board.units.size() or board[source].history.action_records.empty():
        return false
    return action_completion_valid(board, source, board[source].history.action_records.back().started_turn)

# p.58: consume exactly one action at its supplied completion boundary and
# return whether the mission must resolve its effect. Others remain pending.
fun complete_unit_action(Board board, UnitID source, TurnStamp started) -> Bool:
    let valid = action_completion_valid(board, source, started)
    if source.get() < board.units.size():
        let index = action_progress_index(board[source], started)
        if index >= 0 and !board[source].history.action_records[index].resolved:
            board[source].history.action_records[index].resolved = true
            board[source].history.action_records[index].completed = valid
            board[source].history.action_records[index].failed = !valid
            board[source].history.action_completed = valid
            board[source].history.action_failed = !valid
            board[source].history.action_pending = false
            for i in range(board[source].history.action_records.size()):
                board[source].history.action_pending = board[source].history.action_pending or !board[source].history.action_records[i].resolved
    return valid

# p.58 infrastructure: latest-action convenience; callers with earlier pending
# actions pass their start stamp rather than accidentally completing another.
fun complete_unit_action(Board board, UnitID source) -> Bool:
    if source.get() >= board.units.size() or board[source].history.action_records.empty():
        return false
    return complete_unit_action(board, source, board[source].history.action_records.back().started_turn)
