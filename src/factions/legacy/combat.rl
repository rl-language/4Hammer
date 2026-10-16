import board

# Compatibility abilities from the original roster fixtures. Their faction
# sources are not current-edition datasheet certification; keep named policy
# here, outside common casualty processing.

# Dispatch existing on-destruction abilities/stratagems after a casualty (core p.19).
# Feeder Tendrils checks the destroyed model, not the attacker; its faction
# definition is not in the supplied core book and still requires faction-source review.
act legacy_on_model_destroyed(ctx Board board,
                       ctx Unit source,
                       ctx Model destroyed) -> OnModelDestroyed:
    frm generated_mortal : CombatCounter
    if destroyed.is_character() and source.has_ability(AbilityKind::feeder_tendrils):
        board.add_extra_cp(int(source.owned_by_player1))

    frm previous_owner = board.current_decision_maker
    if !source.empty() and destroyed.has_keyword(Keyword::master_of_possession) and board.can_use_strat(!source.owned_by_player1, Stratagem::violent_unbidding):
        board.current_decision_maker = !source.owned_by_player1
        actions:
            act skip()
            # master of possessions can use violent unbidding
            act use_violent_unbidding()
                board.commit_stratagem(!source.owned_by_player1, Stratagem::violent_unbidding)
                # roll the dice to select the amount of mortal wounds inflicted
                act roll(frm Dice dice)
                if dice == 1:
                    board.current_decision_maker = previous_owner
                    return
                if dice == 6:
                    generated_mortal = 3
                if dice == 5:
                    act roll(frm Dice damage)
                    generated_mortal = damage.value / 2

    board.current_decision_maker = previous_owner
