import board
import source_effects

# Cargo keyword checks use actual living passenger models in this specific
# carrier. Seats/other transports and offboard distance never count (p64).
fun orks_carrier_has_passenger(Board board, Model carrier, Bool big_mek) -> Bool:
    for passenger in range(board.embarked_units.size()):
        ref unit = board.embarked_units[passenger]
        if unit.embarked_transport != carrier.identity:
            continue
        for member in range(unit.models.size()):
            if unit[member].is_alive() and (big_mek and orks_big_mek(unit[member]) or !big_mek and unit[member].has_keyword(Keyword::warboss)):
                return true
    return false

# Cargo passives reuse keyed own-unit source grants, with an explicit passenger
# dependency. Blitzboss ceases immediately on disembark/death; its accepted
# source usage history is never reset when cargo returns (source card;01.02.02).
fun register_orks_cargo_passives(Board board):
    for passenger in range(board.embarked_units.size()):
        ref unit = board.embarked_units[passenger]
        let carrier = find_passenger_carrier(board, unit.embarked_transport)
        if !carrier.found:
            continue
        let bank = SourceBank::battlefield
        if carrier.reserve:
            bank = SourceBank::reserves
        ref carrier_unit = source_bank_unit(board, bank, carrier.unit.get())
        ref carrier_model = carrier_unit[carrier.model]
        for member in range(unit.models.size()):
            ref bearer = unit[member]
            if !bearer.is_alive():
                continue
            let blitz = model_has_orks_enhancement(unit, bearer, OrksEnhancement::blitzboss) and !carrier_unit.has_keyword(Keyword::walker)
            let boomer = unit_has_orks_enhancement(carrier_unit, OrksEnhancement::boss_boomer) and bearer.has_keyword(Keyword::warboss)
            for effect_index in range(4):
                if effect_index < 2 and !blitz or effect_index >= 2 and !boomer:
                    continue
                if effect_index == 2 and !bearer.has_ability(AbilityKind::keep_huntin) or effect_index == 3 and !bearer.has_ability(AbilityKind::intimidating_motivation):
                    continue
                let instance : SourceInstance
                instance.rule = 460 + effect_index
                instance.owner = carrier_unit.owned_by_player1
                instance.source_unit = carrier_unit.identity
                instance.source_model = carrier_model.identity
                instance.required_embarked_model = bearer.identity
                instance.required_carrier_model = carrier_model.identity
                instance.own_unit_passive = true
                instance.requires_live_source = true
                instance.offboard_allowed = true
                instance.duration = SourceDuration::battle
                instance.label.value = SourceLabel::orks_cargo_enhancement
                instance.grant = characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 2)
                if effect_index == 1:
                    let protection : RuleEffectGrant
                    protection.kind = RuleEffectKind::invulnerable_save
                    protection.amount = 5
                    instance.grant = protection
                if effect_index >= 2:
                    let ability : RuleEffectGrant
                    ability.kind = RuleEffectKind::borrowed_keep_huntin
                    if effect_index == 3:
                        ability.kind = RuleEffectKind::borrowed_intimidation
                    ability.amount = 1
                    instance.grant = ability
                let registered = -1
                for known in range(board.source_instances.size()):
                    if board.source_instances[known].rule.value == instance.rule.value and board.source_instances[known].source_model == instance.source_model:
                        registered = known
                if registered < 0:
                    let added = register_source_instance(board, instance)
                else:
                    board.source_instances[registered].required_embarked_model = bearer.identity
    refresh_source_effects(board, TimingWindow::none)
    register_orks_datasheet_sources(board)

# Fight-end embarkation has its own whole-unit6in requirement. It deliberately
# does not reuse normal after-move3in or same-phase disembark restrictions.
fun orks_fight_end_carrier(Board board, UnitID passenger, UnitID carrier, ModelID model) -> Bool:
    if carrier.get() >= board.units.size() or board[carrier].off_battlefield or model.get() >= board[carrier].models.size() or !transport_can_carry(board, board[passenger], board[carrier], model.get()):
        return false
    for member in range(board[passenger].models.size()):
        if board[passenger][member].is_alive() and !passenger_wholly_within(board[passenger][member], board[carrier][model], 6):
            return false
    return true

# Every permitted carrier model is checked independently; a unit may contain
# more than one transport model and capacity is model-specific (p64).
fun orks_fight_end_carrier_available(Board board, UnitID passenger) -> Bool:
    let carrier : UnitID
    let model : ModelID
    for slot in range(board.units.size()):
        carrier = slot
        for member in range(board[carrier].models.size()):
            model = member
            if orks_fight_end_carrier(board, passenger, carrier, model):
                return true
    return false

# First-stage carrier selection cannot strand the second-stage model choice.
fun orks_fight_end_transport_has_model(Board board, UnitID passenger, UnitID carrier) -> Bool:
    if carrier.get() >= board.units.size():
        return false
    let model : ModelID
    for member in range(board[carrier].models.size()):
        model = member
        if orks_fight_end_carrier(board, passenger, carrier, model):
            return true
    return false

# Keep It Runnin' explicitly grants embarkation; copy the transport bank/slot
# transition while retaining histories, effects and original model identities.
fun force_orks_fight_end_embark(Board board, UnitID passenger, UnitID carrier, ModelID model):
    assert(orks_fight_end_carrier(board, passenger, carrier, model), "illegal Fight-end embark")
    transfer_embarked_unit(board, passenger, board[carrier][model].identity)

# Raucous Occupants adds the OC of embarked models only at an explicitly
# assigned friendly home marker. No mission/home marker is guessed.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
fun orks_bunka_passenger_control(Board board, Model carrier, Bool player) -> Int:
    if !carrier.is_alive() or !carrier.has_ability(AbilityKind::raucous_occupants):
        return 0
    let at_home = false
    for marker in range(4):
        if board.objectives[marker].home.value == int(player) + 1 and board.model_in_objective_range(carrier, board.objective_range_definition(marker)):
            at_home = true
    let control = 0
    if at_home:
        for passenger in range(board.embarked_units.size()):
            ref cargo = board.embarked_units[passenger]
            if cargo.embarked_transport == carrier.identity:
                for member_index in range(cargo.models.size()):
                    control = control + max(0, cargo.model_objective_control(member_index))
    return control

# A rapid exit is a reaction to the actual carrier MODEL within8in. A prior
# same-phase embark still forbids exit; already handled passengers are skipped.
# https://wahapedia.ru/wh40k11ed/factions/orks/Trukk (Pilin' Out); core p65.
fun orks_trukk_passenger_valid(Board board, UnitID mover, UnitID passenger, EntityIdentity[32] handled) -> Bool:
    if mover.get() >= board.units.size() or passenger.get() >= board.embarked_units.size() or board.timing.phase.value != BattlePhase::movement.value:
        return false
    ref cargo = board.embarked_units[passenger.get()]
    if cargo.owned_by_player1 == board.current_player or cargo.owned_by_player1 == board[mover].owned_by_player1 or cargo.history.embarked_phase == board.phase_serial.value + 1 or !battlefield_entry_available(board, cargo):
        return false
    for index in range(32):
        if handled[index] == cargo.identity:
            return false
    let carrier = find_passenger_carrier(board, cargo.embarked_transport)
    return carrier.found and !carrier.reserve and board[carrier.unit][carrier.model].is_alive() and board[carrier.unit][carrier.model].has_ability(AbilityKind::pilin_out) and live_distance_to_model(board[mover], board[carrier.unit][carrier.model]) <= 8.0

# Finite bank scan, independent of compacted passenger indices after an exit.
# Orks/Trukk Pilin' Out; core transport setup p65.
fun orks_trukk_passenger_any(Board board, UnitID mover, EntityIdentity[32] handled) -> Bool:
    let passenger : UnitID
    for slot in range(board.embarked_units.size()):
        passenger = slot
        if orks_trukk_passenger_valid(board, mover, passenger, handled):
            return true
    return false

# Movement owns this flat reaction hook; Disembark has no Movement child, so
# ordinary and reactive exits safely share the single context-owned frame.
# https://wahapedia.ru/wh40k11ed/factions/orks/Trukk (Pilin' Out).
act orks_trukk_reactions(ctx Board board, frm UnitID mover) -> OrksTrukkReactions:
    frm previous_owner = board.current_decision_maker
    frm handled : EntityIdentity[32]
    frm count : BInt<0, 33>
    while orks_trukk_passenger_any(board, mover, handled):
        board.current_decision_maker = !board[mover].owned_by_player1
        actions:
            act finish_pilin_out()
                break
            act choose_pilin_out_passenger(frm UnitID passenger) {orks_trukk_passenger_valid(board, mover, passenger, handled)}
                handled[count.value] = board.embarked_units[passenger.get()].identity
                count = count + 1
                board.shared_actions.disembark = disembark(board, passenger, true)
                subaction*(board) board.shared_actions.disembark
    board.current_decision_maker = previous_owner

# Idol is mandatory on selection; Beastscent is optional and spends the same
# psychic budget as Warpath. Cancelled exits still had a selected passenger.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Stompa,Kill-Rig}
act orks_disembark_selection(ctx Board board, frm UnitID passenger, frm CarrierLocation carrier) -> OrksDisembarkSelection:
    if board.timing.phase.value != BattlePhase::movement.value or board[carrier.unit].owned_by_player1 != board.current_player:
        return
    if board[carrier.unit].has_ability(AbilityKind::idol_of_belligerence):
        grant_orks_own_payload(board, board.embarked_units[passenger.get()], 164, riled_up_grant(), SourceDuration::next_own_turn)
    if orks_datasheet_psychic_available(board, carrier.unit, 162):
        act use_beastscent(Bool beastscent)
        if beastscent:
            frm rule : BInt<151, 163>
            rule = 162
            board.shared_actions.orks_psychic_test = orks_datasheet_psychic(board, carrier.unit, rule)
            subaction*(board) board.shared_actions.orks_psychic_test
            frm payload : RuleEffectGrant
            payload.kind = RuleEffectKind::beastscent
            payload.amount = 1
            grant_orks_own_payload(board, board.embarked_units[passenger.get()], 169, payload, SourceDuration::turn)

# Downtrodden rounds the Gretchin group up ONCE per embarked unit, then
# adds ordinary attached-model seats. Never halve a Character or round every
# Gretchin separately; all actually stored weights remain bounded integers.
# https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
fun orks_passenger_space(Unit unit) -> Int:
    let gretchin = 0
    let ordinary = 0
    for member in range(unit.models.size()):
        if model_matches_datasheet(unit[member], OrksDatasheet::gretchin):
            gretchin = gretchin + 1
        else:
            ordinary = ordinary + max(unit[member].transport_space.value, 2 * int(unit[member].has_keyword(Keyword::mega_armour) or unit[member].has_keyword(Keyword::jump_pack)))
    return ordinary + (gretchin + 1) / 2
