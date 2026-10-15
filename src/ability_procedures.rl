import board

# A limited resource is paid before chance input; rerolls use the original die
# and do not spend again (core p9; appendix01.05.02/22.03.01). The caller owns
# eligibility, the capacity and the result's meaning; no faction is assumed.
fun roll_spent_round_resource(Board board, RoundResourceBudget budget, Bool player, Int capacity, Bool reroll) -> RerollableDice:
    assert(budget.available(board.current_round.value + 1, capacity), "round resource exhausted")
    budget.consume(board.current_round.value + 1)
    return rerollable_dice_roll(board, reroll, false, false, player)

# Out-of-phase movement reuses core paths, records only completed moves and
# restores caller constraints/roles (core pp33/70/74). The source supplies the
# distance and destination requirement; Surge also selects its closest target.
act granted_move(ctx Board board, frm UnitID source, frm StatModifier distance, frm MovementKind kind, frm Bool objective_required, frm Bool permitted) -> GrantedMove:
    assert(kind == MovementKind::normal or kind == MovementKind::surge, "unsupported granted move kind")
    if !permitted:
        return
    frm previous_owner = board.current_decision_maker
    frm previous_kind = board[source].pending_move_kind
    frm previous_limit = board[source].movement_distance_limit
    frm previous_skies = board[source].move_takes_to_skies
    frm previous_target = board.surge_target
    frm previous_objective = board.move_requires_objective
    frm previous_mover = board.constrained_mover
    board.current_decision_maker = board[source].owned_by_player1
    board[source].pending_move_kind = kind
    if kind == MovementKind::surge:
        act select_surge_target(frm UnitID target) {surge_target_valid(board, source, target)}
        board.surge_target = target
        previous_kind = MovementKind::normal
    else:
        board[source].movement_distance_limit = distance.value + 1
        board[source].move_takes_to_skies = false
        if board[source].has_keyword(Keyword::fly):
            act choose_reactive_skies(Bool take_to_skies)
            board[source].move_takes_to_skies = take_to_skies
    board.move_requires_objective = objective_required
    board.constrained_mover = source
    board.shared_actions.move = move(board, source, distance)
    subaction*(board, source) board.shared_actions.move
    frm completed = board.shared_actions.move.completed
    if completed:
        record_move(board, source, kind)
    board[source].pending_move_kind = previous_kind
    board[source].movement_distance_limit = previous_limit
    board[source].move_takes_to_skies = previous_skies
    board.surge_target = previous_target
    board.move_requires_objective = previous_objective
    board.constrained_mover = previous_mover
    board.current_decision_maker = previous_owner

# Reactive Normal moves have an absolute allowance, unaffected by M bonuses
# (core p33; source cards supply the reaction trigger and extra restrictions).
fun reactive_move(Board board, UnitID source, StatModifier distance, Bool objective_required) -> GrantedMove:
    return granted_move(board, source, distance, MovementKind::normal, objective_required, true)
