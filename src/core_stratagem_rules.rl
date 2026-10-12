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

# p.56: keyword belongs to the selected living bearer, not a mixed unit's ally.
fun explosives_model_valid(Board board, UnitID source, ModelID model) -> Bool:
    return source.get() < board.units.size() and model.get() < board[source].models.size() and board[source][model].is_alive() and (board[source][model].has_keyword(Keyword::explosives) or board[source][model].has_keyword(Keyword::grenades))

# p.56: target is unengaged and within 8 inches of the selected bearer, visible
# under the user's area-only approximation. No weapon range is substituted.
fun explosives_target_valid(Board board, UnitID source, ModelID model, UnitID target) -> Bool:
    return explosives_model_valid(board, source, model) and target.get() < board.units.size() and has_live_model(board[target]) and board[target].owned_by_player1 != board[source].owned_by_player1 and !board.is_in_melee(board[target]) and live_distance_to_model(board[target], board[source][model]) <= 8.0 and model_can_see_unit(board, board[source][model], board[target])

# p.56: never accept a source/bearer with no legal target and strand its selector.
fun explosives_model_has_target(Board board, UnitID source, ModelID model) -> Bool:
    for i in range(board.units.size()):
        let target : UnitID
        target = i
        if explosives_target_valid(board, source, model, target):
            return true
    return false

# p.56: own Shooting phase, unengaged, eligible to shoot, no Advance; CP/unit
# limits apply to the friendly source. Explosives does not consume shooting.
fun explosives_source_valid(Board board, UnitID source) -> Bool:
    if !(board.timing.phase == BattlePhase::shooting) or !shooting_unit_valid(board, source) or board.is_in_melee(board[source]) or board[source].history.advanced_this_turn or board[source].has_run or !board.can_target_strat(board.current_player, Stratagem::explosives, board[source]):
        return false
    for i in range(board[source].models.size()):
        let model : ModelID
        model = i
        if explosives_model_has_target(board, source, model):
            return true
    return false

# p.56: the selected bearer itself must engage a living enemy model.
fun crushing_model_engaged(Model model, Unit target) -> Bool:
    for i in range(target.models.size()):
        if target[i].is_alive() and model.is_engaged_with(target[i]):
            return true
    return false

# p.56: choose the engaged enemy before an engaged living Monster/Vehicle
# bearer. Unit-wide qualification does not require the selected model's keyword.
fun crushing_model_valid(Board board, UnitID source, UnitID target, ModelID model) -> Bool:
    return source.get() < board.units.size() and target.get() < board.units.size() and model.get() < board[source].models.size() and board[source][model].is_alive() and crushing_model_engaged(board[source][model], board[target])

# p.56: Crushing Impact belongs immediately after a successful own Charge-
# phase move, never a failed declaration or an opponent's Heroic Intervention.
fun crushing_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    return source.get() < board.units.size() and target.get() < board.units.size() and has_live_model(board[target]) and board[source].owned_by_player1 != board[target].owned_by_player1 and board[source].is_engaged_with(board[target])

# p.56: successful move provenance plus printed MONSTER/VEHICLE and CP gates.
fun crushing_source_valid(Board board, UnitID source) -> Bool:
    if source.get() >= board.units.size() or !(board.timing.phase == BattlePhase::charge) or board[source].owned_by_player1 != board.current_player or !has_live_model(board[source]) or board[source].history.charge_move_phase != board.phase_serial.value + 1 or (!board[source].has_keyword(Keyword::monster) and !board[source].has_keyword(Keyword::vehicle)) or !board.can_target_strat(board.current_player, Stratagem::crushing_impact, board[source]):
        return false
    for i in range(board.units.size()):
        let target : UnitID
        target = i
        if crushing_target_valid(board, source, target):
            return true
    return false

# p.56: retained authorised CHARACTER fighters remain eligible (supplied Fight
# on Death); ordinary corpses cannot receive a new melee-weapon grant.
fun epic_model_valid(Board board, UnitID source, ModelID model) -> Bool:
    return source.get() < board.units.size() and model.get() < board[source].models.size() and fight_model_present(board[source][model]) and board[source][model].has_keyword(Keyword::character)

# p.56: just-selected friendly CHARACTER unit, with a selectable bearer and CP.
fun epic_source_valid(Board board, UnitID source) -> Bool:
    if source.get() >= board.units.size() or !(board.timing.phase == BattlePhase::fight) or !board.can_target_strat(board[source].owned_by_player1, Stratagem::epic_challenge, board[source]):
        return false
    for i in range(board[source].models.size()):
        let model : ModelID
        model = i
        if epic_model_valid(board, source, model):
            return true
    return false

# p.57: start of opponent's Shooting phase; duration expires with modifiers.
fun smoke_source_valid(Board board, Bool player, UnitID source) -> Bool:
    return source.get() < board.units.size() and player != board.current_player and board.timing.phase == BattlePhase::shooting and board[source].owned_by_player1 == player and has_live_model(board[source]) and board[source].has_keyword(Keyword::smoke) and board.can_target_strat(player, Stratagem::smokescreen, board[source])

# p.57: direct SMOKE targets always gain cover. A target is not fully
# visible if any of its models is partially obscured by a smoke model.
# Use circular bases crossing centre sight segments under the retained grid
# abstraction; physical bodies/silhouettes remain unavailable, not invented.
fun smoke_cover_applies(Board board, Model observer, UnitID target) -> Bool:
    if board[target].phase_modifiers.smokescreen:
        return true
    for m in range(board[target].models.size()):
        if board[target][m].is_alive():
            for u in range(board.units.size()):
                if board[u].phase_modifiers.smokescreen:
                    for s in range(board[u].models.size()):
                        if board[u][s].is_alive():
                            let centre = board[u][s].geometry_position()
                            let radius = board[u][s].base_radius_micrometres()
                            let finish = board[target][m].geometry_position()
                            let start = observer.geometry_position()
                            if point_segment_distance_squared(float(centre.x.value), float(centre.y.value), float(start.x.value), float(start.y.value), float(finish.x.value), float(finish.y.value)) <= radius * radius:
                                return true
    return false

# p.57: after an enemy unit's attacks in the opponent's Fight step, target
# any friendly eligible unit, even one without intrinsic Fights First.
fun counteroffensive_target_valid(Board board, Bool player, UnitID source) -> Bool:
    return source.get() < board.units.size() and player != board.current_player and board.timing.phase == BattlePhase::fight and board[source].owned_by_player1 == player and fight_unit_eligible(board, source) and board.can_target_strat(player, Stratagem::counteroffensive, board[source])

# p.57: avoid presenting an empty optional Counteroffensive decision.
fun counteroffensive_available(Board board, Bool player) -> Bool:
    for i in range(board.units.size()):
        let source : UnitID
        source = i
        if counteroffensive_target_valid(board, player, source):
            return true
    return false
