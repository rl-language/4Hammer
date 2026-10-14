import orks_detachment_rules

# Literal selection windows for source cards. Ranged cards say YOUR Shooting
# phase; Fight cards apply in either player's Fight phase. Unit CP targeting
# and package ownership are still the shared p54 policy.
fun orks_selected_stratagem_valid(Board board, UnitID actor, Stratagem strat, Bool melee) -> Bool:
    if actor.get() >= board.units.size() or !board.can_target_strat(board[actor].owned_by_player1, strat, board[actor]):
        return false
    ref unit = board[actor]
    let own_shooting = !melee and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 == board.current_player
    let fighting = melee and board.timing.phase == BattlePhase::fight
    if strat == Stratagem::orks_hit_em_harder:
        return fighting and unit.has_keyword(Keyword::orks)
    if strat == Stratagem::orks_mow_em_down:
        return fighting and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::vehicle) and !unit.has_keyword(Keyword::walker) and unit.has_charged
    if strat == Stratagem::orks_close_range_dakka:
        return own_shooting and unit.has_keyword(Keyword::orks)
    if strat == Stratagem::orks_unbridled_carnage:
        return fighting and orks_type(unit, OrksDatasheet::boyz) and unit.has_charged
    if strat == Stratagem::orks_armed_to_da_teef:
        return (fighting or own_shooting) and (orks_type(unit, OrksDatasheet::nobz) or orks_type(unit, OrksDatasheet::meganobz))
    if strat == Stratagem::orks_kustom_dakka or strat == Stratagem::orks_glowin_dakka or strat == Stratagem::orks_never_enough_dakka:
        return own_shooting and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::infantry)
    if strat == Stratagem::orks_drive_by_bustin:
        return own_shooting and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::transport)
    if strat == Stratagem::orks_vindictive_artillerists:
        return own_shooting and orks_type(unit, OrksDatasheet::mek_gunz)
    if strat == Stratagem::orks_dakkastorm:
        return own_shooting and unit.has_keyword(Keyword::speed_freeks)
    if strat == Stratagem::orks_long_uncontrolled_bursts:
        return own_shooting and unit.has_keyword(Keyword::orks) and (unit.has_keyword(Keyword::aircraft) or orks_type(unit, OrksDatasheet::deffkoptas))
    return false

# Expose a source enum only when an actual card fits this activation. Keeping
# absent hooks automatic avoids spurious decline inputs in ordinary attacks.
fun orks_selected_stratagem_remaining(Board board, UnitID actor, Bool melee) -> Bool:
    let strat : Stratagem
    for card in range(max(strat) + 1):
        strat.value = card
        if orks_selected_stratagem_valid(board, actor, strat, melee):
            return true
    return false

# Each accepted effect pays CP BEFORE resolution and uses a keyed source grant;
# its default lifetime is this phase unless the source states otherwise (01.02.02).
act orks_attack_selection(ctx Board board, frm UnitID actor, frm Bool melee) -> OrksAttackSelection:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = board[actor].owned_by_player1
    while orks_selected_stratagem_remaining(board, actor, melee):
        actions:
            act finish_orks_attack_selection()
                break
            act choose_orks_attack_stratagem(frm Stratagem selected_card) {orks_selected_stratagem_valid(board, actor, selected_card, melee)}
                board.commit_stratagem(board[actor].owned_by_player1, selected_card, board[actor])
                frm effect : OrksEffectKind
                effect = OrksEffectKind::melee_lethal
                if selected_card == Stratagem::orks_mow_em_down:
                    effect = OrksEffectKind::cleave_increment
                if selected_card == Stratagem::orks_close_range_dakka:
                    effect = OrksEffectKind::rapid_fire_increment
                if selected_card == Stratagem::orks_unbridled_carnage:
                    # The melee-only addition is gathered per selected weapon.
                    effect = OrksEffectKind::unbridled_attacks
                if selected_card == Stratagem::orks_armed_to_da_teef:
                    effect = OrksEffectKind::armed_to_da_teef
                if selected_card == Stratagem::orks_kustom_dakka:
                    effect = OrksEffectKind::wound_bonus_non_monster_vehicle
                if selected_card == Stratagem::orks_glowin_dakka:
                    effect = OrksEffectKind::close_range_ap
                if selected_card == Stratagem::orks_never_enough_dakka or selected_card == Stratagem::orks_dakkastorm:
                    effect = OrksEffectKind::ranged_sustained
                if selected_card == Stratagem::orks_drive_by_bustin:
                    effect = OrksEffectKind::deck_hit_bonus
                if selected_card == Stratagem::orks_long_uncontrolled_bursts:
                    effect = OrksEffectKind::reroll_hits_fly
                if selected_card == Stratagem::orks_vindictive_artillerists:
                    act choose_artillerist_mode(frm OrksArtilleristMode mode)
                    effect = OrksEffectKind::ranged_lethal
                    if mode.value == OrksArtilleristMode::sustained.value:
                        effect = OrksEffectKind::ranged_sustained
                    if mode.value == OrksArtilleristMode::both_hazardous.value:
                        effect = OrksEffectKind::vindictive_all
                grant_orks_effect(board, actor, actor, 300 + selected_card.value, effect, 1, SourceDuration::phase, invalid_entity_identity())
    # Dread Mob is optional, separate from CP targeting and not blocked by shock.
    if (melee and board.timing.phase == BattlePhase::fight or !melee and board.timing.phase == BattlePhase::shooting and board[actor].owned_by_player1 == board.current_player) and orks_package(board, board[actor], OrksDetachment::dread_mob) and board[actor].has_keyword(Keyword::orks) and board[actor].has_keyword(Keyword::walker) and !board[actor].has_keyword(Keyword::titanic):
        actions:
            act decline_try_dat_button()
            act choose_button_dice(frm Bool two_dice)
                frm first_button : Dice
                act roll(Dice button_face)
                first_button = button_face
                apply_orks_button(board, actor, button_face)
                if two_dice:
                    frm second_button : Dice
                    second_button = first_button
                    while second_button.value == first_button.value:
                        act roll(Dice other_button)
                        second_button = other_button
                    apply_orks_button(board, actor, second_button)
                    grant_orks_effect(board, actor, actor, 410, OrksEffectKind::button_hazard, 1, SourceDuration::phase, invalid_entity_identity())
    board.current_decision_maker = previous_owner

# Every distinct die supplies its relevant cumulative characteristic addition;
# only identical D6 faces repeat (Try Dat Button!, not identical table bands).
fun apply_orks_button(Board board, UnitID actor, Dice face):
    let effect = OrksEffectKind::button_attacks
    if face.value >= 3 and face.value <= 4:
        effect = OrksEffectKind::button_strength
    if face.value >= 5:
        effect = OrksEffectKind::button_ap
    grant_orks_effect(board, actor, actor, 410 + face.value, effect, 1, SourceDuration::phase, invalid_entity_identity())

# Defensive cards trigger for the actual targeted unit, not a guessed initial
# target before declarations. Grot Shields selects a DIFFERENT CP target below.
fun orks_targeted_stratagem_valid(Board board, UnitID source, UnitID target, Stratagem strat, Bool melee) -> Bool:
    if source.get() >= board.units.size() or target.get() >= board.units.size() or board[source].owned_by_player1 == board[target].owned_by_player1 or !board.can_target_strat(board[target].owned_by_player1, strat, board[target]):
        return false
    ref unit = board[target]
    let fighting = melee and board.timing.phase == BattlePhase::fight
    let opposing_shooting = !melee and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 != board.current_player
    if strat == Stratagem::orks_orks_is_never_beaten:
        return fighting and unit.has_keyword(Keyword::orks) and !unit.has_keyword(Keyword::titanic)
    if strat == Stratagem::orks_too_arrogant_to_die:
        return fighting and (orks_type(unit, OrksDatasheet::nobz) or orks_type(unit, OrksDatasheet::meganobz))
    if strat == Stratagem::orks_crazed_rampage:
        return fighting and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::walker) and !unit.has_keyword(Keyword::titanic)
    if strat == Stratagem::orks_hulking_brutes:
        return opposing_shooting and (orks_type(unit, OrksDatasheet::nobz) or orks_type(unit, OrksDatasheet::meganobz))
    if strat == Stratagem::orks_speediest_freeks:
        return opposing_shooting and unit.has_keyword(Keyword::speed_freeks)
    return false

# A rejected surcharge cannot spend the base CP first. The defending owner
# chooses the printed1CP/2CP option, then commits the final legal cost atomically.
act orks_attack_targeted(ctx Board board, frm UnitID source, frm UnitID target, frm Bool melee) -> OrksAttackTargeted:
    frm owner = board[target].owned_by_player1
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = owner
    while orks_targeted_stratagem_remaining(board, source, target, melee):
        actions:
            act finish_orks_attack_targeted()
                break
            act choose_orks_defence_stratagem(frm Stratagem defence_card) {orks_targeted_stratagem_valid(board, source, target, defence_card, melee)}
                frm extra_cost : BInt<0, 2>
                frm effect : OrksEffectKind
                effect = OrksEffectKind::fight_on_death_four
                if defence_card == Stratagem::orks_crazed_rampage:
                    effect = OrksEffectKind::fight_on_death_dread
                if defence_card == Stratagem::orks_speediest_freeks:
                    effect = OrksEffectKind::fail_hits_one_to_three
                if defence_card == Stratagem::orks_hulking_brutes:
                    act choose_hulking_protection(Bool all_attacks) {board.can_target_strat_with_cost(owner, defence_card, board[target], defence_card.cost() + int(all_attacks))}
                    extra_cost = int(all_attacks)
                    effect = OrksEffectKind::strong_wound_protection
                    if all_attacks:
                        effect = OrksEffectKind::all_wound_protection
                board.commit_stratagem_with_cost(owner, defence_card, board[target], defence_card.cost() + extra_cost.value)
                grant_orks_effect(board, target, target, 300 + defence_card.value, effect, 1, SourceDuration::phase, invalid_entity_identity())
    if orks_grot_shield_available(board, source, target, melee):
        actions:
            act decline_grot_shields()
            act choose_grot_shield_unit(frm UnitID shield) {orks_grot_shield_unit_valid(board, source, target, shield, melee)}
                board.commit_stratagem(owner, Stratagem::orks_grot_shields, board[shield])
                grant_orks_effect(board, shield, target, 300 + Stratagem::orks_grot_shields.value, OrksEffectKind::grot_shield, 1, SourceDuration::phase, board[shield].identity)
    board.current_decision_maker = previous_owner

# Only the five printed defensive cards can appear at this hook; enum capacity
# is never substituted for phase/unit/package eligibility (Orks source cards).
fun orks_targeted_stratagem_remaining(Board board, UnitID source, UnitID target, Bool melee) -> Bool:
    let strat : Stratagem
    for card in range(max(strat) + 1):
        strat.value = card
        if orks_targeted_stratagem_valid(board, source, target, strat, melee):
            return true
    return false

# Grot Shields pays for a GRETCHIN unit while protecting nearby non-Gretchin
# ORKS infantry. Payer, stratagem target and beneficiary remain distinct.
fun orks_grot_shield_unit_valid(Board board, UnitID source, UnitID target, UnitID shield, Bool melee) -> Bool:
    if melee or source.get() >= board.units.size() or target.get() >= board.units.size() or shield.get() >= board.units.size() or !(board.timing.phase == BattlePhase::shooting):
        return false
    ref recipient = board[target]
    ref grots = board[shield]
    return recipient.owned_by_player1 != board.current_player and board[source].owned_by_player1 != recipient.owned_by_player1 and recipient.has_keyword(Keyword::orks) and recipient.has_keyword(Keyword::infantry) and !orks_type(recipient, OrksDatasheet::gretchin) and !grots.off_battlefield and grots.owned_by_player1 == recipient.owned_by_player1 and orks_type(grots, OrksDatasheet::gretchin) and live_unit_distance(grots, recipient) <= 3.0 and board.can_target_strat(grots.owned_by_player1, Stratagem::orks_grot_shields, grots)

# No dead-end offboard/empty shielding choices are synthesized for the UI.
fun orks_grot_shield_available(Board board, UnitID source, UnitID target, Bool melee) -> Bool:
    let shield : UnitID
    for unit in range(board.units.size()):
        shield = unit
        if orks_grot_shield_unit_valid(board, source, target, shield, melee):
            return true
    return false

# Selection precedes Advance dice and Fall Back mode hazards. Fungus-Fuel,
# 'Ere We Go and Stomping Juggernaut use their exact actor/window requirements.
fun orks_move_card_valid(Board board, UnitID actor, Stratagem card, Bool charging) -> Bool:
    if actor.get() >= board.units.size() or board[actor].owned_by_player1 != board.current_player or !board.can_target_strat(board[actor].owned_by_player1, card, board[actor]):
        return false
    ref unit = board[actor]
    if card == Stratagem::orks_stomping_juggernaut:
        return unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::walker) and ((charging and board.timing.phase == BattlePhase::charge) or (!charging and board.timing.phase == BattlePhase::movement))
    if charging or !(board.timing.phase == BattlePhase::movement):
        return false
    if card == Stratagem::orks_fungus_fuel_injection:
        return unit.has_keyword(Keyword::orks) and (unit.has_keyword(Keyword::mounted) or unit.has_keyword(Keyword::vehicle))
    if card == Stratagem::orks_ere_we_go:
        return orks_type(unit, OrksDatasheet::beast_snagga_boyz) or orks_type(unit, OrksDatasheet::boyz)
    return false

# Optional absent source cards return without extra inputs in core fixtures.
fun orks_move_cards_remaining(Board board, UnitID actor, Bool charging) -> Bool:
    return orks_move_card_valid(board, actor, Stratagem::orks_stomping_juggernaut, charging) or orks_move_card_valid(board, actor, Stratagem::orks_fungus_fuel_injection, charging) or orks_move_card_valid(board, actor, Stratagem::orks_ere_we_go, charging)

# These grants precede the actual movement/charge snapshot. Mobile remains a
# real keyword; user area-only geometry does not invent dense physical features.
act orks_move_selection(ctx Board board, frm UnitID actor, frm Bool charging) -> OrksMoveSelection:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = board[actor].owned_by_player1
    while orks_move_cards_remaining(board, actor, charging):
        actions:
            act finish_orks_move_selection()
                break
            act choose_orks_move_stratagem(frm Stratagem move_card) {orks_move_card_valid(board, actor, move_card, charging)}
                board.commit_stratagem(board[actor].owned_by_player1, move_card, board[actor])
                if move_card == Stratagem::orks_fungus_fuel_injection:
                    grant_orks_payload(board, actor, actor, 300 + move_card.value, characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 2), SourceDuration::phase)
                else:
                    frm effect : OrksEffectKind
                    effect = OrksEffectKind::mobile
                    if move_card == Stratagem::orks_ere_we_go:
                        effect = OrksEffectKind::advance_plus_two
                    grant_orks_effect(board, actor, actor, 300 + move_card.value, effect, 1, SourceDuration::phase, invalid_entity_identity())
    board.current_decision_maker = previous_owner

# Mind Mostly on the Mission triggers only after selecting Advance/Fall Back,
# and waives only those action-start restrictions (Taktikal Brigade source).
act orks_move_mode(ctx Board board, frm UnitID actor, frm MovementKind kind) -> OrksMoveMode:
    if board[actor].owned_by_player1 != board.current_player or !(board.timing.phase == BattlePhase::movement) or !orks_taktikal_unit(board[actor]) or !(kind == MovementKind::advance or kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape) or !board.can_target_strat(board[actor].owned_by_player1, Stratagem::orks_mind_mostly_on_the_mission, board[actor]):
        return
    actions:
        act decline_mind_on_mission()
        act mind_on_mission()
            board.commit_stratagem(board[actor].owned_by_player1, Stratagem::orks_mind_mostly_on_the_mission, board[actor])
            grant_orks_effect(board, actor, actor, 300 + Stratagem::orks_mind_mostly_on_the_mission.value, OrksEffectKind::action_move_permission, 1, SourceDuration::phase, invalid_entity_identity())

# The Da Big Hunt CP target is an engaged friendly Beast Snagga unit; the
# enemy mover is a separate subject and may not pay/receive the stratagem.
fun orks_escape_target_valid(Board board, UnitID mover, UnitID snaggas) -> Bool:
    return mover.get() < board.units.size() and snaggas.get() < board.units.size() and board.timing.phase == BattlePhase::movement and board[snaggas].owned_by_player1 != board.current_player and board[mover].owned_by_player1 != board[snaggas].owned_by_player1 and board[snaggas].has_keyword(Keyword::beast_snagga) and board[snaggas].is_engaged_with(board[mover]) and board.can_target_strat(board[snaggas].owned_by_player1, Stratagem::orks_where_d_ya_fink_you_re_going, board[snaggas])

# Recheck the current engagement before exposing the reaction, preserving
# actual fall-back selection timing and controller ownership (source card).
fun orks_escape_reaction_available(Board board, UnitID mover) -> Bool:
    let target : UnitID
    for index in range(board.units.size()):
        target = index
        if orks_escape_target_valid(board, mover, target):
            return true
    return false

# Accepted reaction forces the Desperate Escape mode before hazard rolls;
# the printed unit-granted rule remains active for this Movement phase.
act orks_fallback_selection(ctx Board board, frm UnitID mover) -> OrksFallbackSelection:
    if !orks_escape_reaction_available(board, mover):
        return
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = !board[mover].owned_by_player1
    actions:
        act decline_hunting_escape()
        act choose_hunting_escape_unit(frm UnitID hunters) {orks_escape_target_valid(board, mover, hunters)}
            board.commit_stratagem(board[hunters].owned_by_player1, Stratagem::orks_where_d_ya_fink_you_re_going, board[hunters])
            grant_orks_effect(board, hunters, hunters, 300 + Stratagem::orks_where_d_ya_fink_you_re_going.value, OrksEffectKind::hunt_escape_hazards, 1, SourceDuration::phase, invalid_entity_identity())
    board.current_decision_maker = previous_owner

# Resolve one mortal per cancelled rolled hit through the ordinary prevention,
# allocation and destruction engine; stop when no shielding model remains.
# Runt Swarm/Grot Shields; core mortal wounds p24, destruction p87.
act intercept_orks_hits(ctx Board board, frm UnitID target, frm CombatCounter count) -> OrksHitInterception:
    frm intercepted : CombatCounter
    while count > 0 and orks_grot_shield(board, board[target]) >= 0:
        frm shield : UnitID
        shield = orks_grot_shield(board, board[target])
        frm one : CombatCounter
        one = 1
        board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, shield, target, false, one)
        subaction*(board) board.shared_actions.resolve_mortal_wounds
        intercepted = intercepted + 1
        count = count - 1
