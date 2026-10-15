import board

# A limited resource is paid before chance input; rerolls use the original die
# and do not spend again (core p9; appendix01.05.02/22.03.01). The caller owns
# eligibility, the capacity and the result's meaning; no faction is assumed.
fun roll_spent_round_resource(Board board, RoundResourceBudget budget, Bool player, Int capacity, Bool reroll) -> RerollableDice:
    assert(budget.available(board.current_round.value + 1, capacity), "round resource exhausted")
    budget.consume(board.current_round.value + 1)
    return rerollable_dice_roll(board, reroll, false, false, player)
