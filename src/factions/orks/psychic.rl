import board
import source_effects

# Wurrband counts actual passenger models, not occupied seats, and combines
# models in the psyker's unit OR embarked in that psyker model as printed.
fun embarked_models_for_psyker(Board board, EntityIdentity psyker) -> Int:
    let count = 0
    for passenger in range(board.embarked_units.size()):
        if board.embarked_units[passenger].embarked_transport == psyker:
            count = count + live_attachment_strength(board.embarked_units[passenger])
    return count

# Carrier psykers count their actual embarked models instead of their own
# unit; ordinary psykers count their unit (Wurrband Powers of da Waaagh!).
fun orks_psychic_contributors(Board board, Unit unit, Model model) -> Int:
    if model.has_keyword(Keyword::transport):
        return embarked_models_for_psyker(board, model.identity)
    return live_attachment_strength(unit)

# Exact model-level source membership determines the user's optional ability
# buttons. Warphead changes its unit's printed psychic level to2; other levels
# must come from explicit datasheet metadata, never an invented fallback.
fun orks_psyker_level(Unit unit) -> Int:
    let level = 0
    if component_source_active(unit, unit.identity):
        level = unit.psyker_level.value
    for component in range(unit.attached_units.size()):
        if component_source_active(unit, unit.attached_units[component].identity):
            level = max(level, unit.attached_units[component].psyker_level.value)
    for member in range(unit.models.size()):
        if unit[member].is_alive() and model_has_orks_enhancement(unit, unit[member], OrksEnhancement::warphead):
            level = max(level, 2)
    return level

# Wurrband's budget belongs to the unit in every bank (Unstable Energies;
# appendix22.03.01/01.02.04). Only the unmeasured own-unit Visions works offboard.
fun orks_psychic_unit_available(Board board, Unit unit, Bool visions) -> Bool:
    if !has_live_model(unit) or (!visions and unit.off_battlefield) or unit.battle_socked or !orks_package(board, unit, OrksDetachment::wurrband) or !unit.has_keyword(Keyword::orks) or !unit.has_keyword(Keyword::psyker):
        return false
    return unit.orks_psychic_usage.budget.available(board.current_round.value + 1, orks_psyker_level(unit)) and (visions and unit.orks_psychic_usage.visions_phase != board.phase_serial.value + 1 or !visions and unit.orks_psychic_usage.roar_phase != board.phase_serial.value + 1)

# Battlefield selectors retain their bounded UnitID contract. Eligibility and
# spending are shared with reserve/passenger own-unit uses (01.02.04).
fun orks_psychic_available(Board board, UnitID source, Bool visions) -> Bool:
    return source.get() < board.units.size() and orks_support_actor(board, source, board[source].owned_by_player1) and orks_psychic_unit_available(board, board[source], visions)

# Roar excludes Monster/Vehicle and measures to the unit, not the bearer.
fun orks_roar_target(Board board, UnitID source, UnitID target) -> Bool:
    return target.get() < board.units.size() and !board[target].off_battlefield and has_live_model(board[target]) and board[target].owned_by_player1 != board[source].owned_by_player1 and !board[target].has_keyword(Keyword::monster) and !board[target].has_keyword(Keyword::vehicle) and live_unit_distance(board[source], board[target]) <= 12.0

# A mandatory post-roll target is offered only if one exists before acceptance.
fun orks_roar_has_target(Board board, UnitID source) -> Bool:
    let target : UnitID
    for index in range(board.units.size()):
        target = index
        if orks_roar_target(board, source, target):
            return true
    return false

# All Orks psychic abilities use the same budget/roll and final1 response.
# Unstable Energies22.03.01; Warphead changes reroll permission, not usage.
act orks_psychic_test(ctx Board board, frm EntityIdentity subject) -> OrksPsychicTest:
    frm location = locate_source(board, subject, invalid_entity_identity())
    assert(location.found, "psychic source missing")
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = source_bank_unit(board, location.bank, location.unit.value).owned_by_player1
    board.current_roll = roll_spent_round_resource(board, source_bank_unit(board, location.bank, location.unit.value).orks_psychic_usage.budget, board.current_decision_maker, orks_psyker_level(source_bank_unit(board, location.bank, location.unit.value)), unit_has_orks_enhancement(source_bank_unit(board, location.bank, location.unit.value), OrksEnhancement::warphead))
    subaction*(board) board.current_roll
    location = locate_source(board, subject, invalid_entity_identity())
    if location.found and board.current_roll.result == 1:
        source_bank_unit(board, location.bank, location.unit.value).battle_socked = true
        board.shared_actions.orks_became_shocked = orks_became_shocked(board, subject)
        subaction*(board) board.shared_actions.orks_became_shocked
    board.current_decision_maker = previous_owner

# Wurrband uses one identity-backed psychic frame for all banks. Spend before
# rolling; a final1 shocks but does not cancel Visions (Unstable Energies).
# Resolve identity again after children: bank slots are storage, not identity.
act use_orks_psychic(ctx Board board, frm EntityIdentity subject, frm Bool visions) -> OrksPsychic:
    frm location = locate_source(board, subject, invalid_entity_identity())
    if !location.found or (!visions and location.bank.value != SourceBank::battlefield.value):
        return
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = source_bank_unit(board, location.bank, location.unit.value).owned_by_player1
    if visions:
        source_bank_unit(board, location.bank, location.unit.value).orks_psychic_usage.visions_phase = board.phase_serial.value + 1
    else:
        source_bank_unit(board, location.bank, location.unit.value).orks_psychic_usage.roar_phase = board.phase_serial.value + 1
    board.shared_actions.orks_psychic_test = orks_psychic_test(board, subject)
    subaction*(board) board.shared_actions.orks_psychic_test
    location = locate_source(board, subject, invalid_entity_identity())
    if location.found:
        if visions:
            if has_live_model(source_bank_unit(board, location.bank, location.unit.value)):
                let effect : OrksEffectGrant
                effect.kind = OrksEffectKind::fights_first
                effect.amount = 1
                grant_orks_own_payload(board, source_bank_unit(board, location.bank, location.unit.value), 440, effect, SourceDuration::phase)
        else:
            frm source : UnitID
            source = location.unit.value
            if location.bank.value == SourceBank::battlefield.value and orks_roar_has_target(board, source):
                act choose_roar_target(frm UnitID roar_target) {orks_roar_target(board, source, roar_target)}
                frm roar_penalty : LinearlyDistributedInt<0, 8>
                roar_penalty = live_attachment_strength(board[source]) / 10
                board.shared_actions.battle_shock_test = battle_shock_test(board, board[roar_target], false, false, roar_penalty)
                subaction*(board, board[roar_target]) board.shared_actions.battle_shock_test
    board.current_decision_maker = previous_owner

# Existing battlefield callers retain UnitID; only the shared frame stores the
# stable unit identity (source lifecycle pp66/87; no second psychic frame).
fun use_orks_psychic(Board board, UnitID source, Bool visions) -> OrksPsychic:
    let subject = invalid_entity_identity()
    if source.get() < board.units.size():
        subject = board[source].identity
    return use_orks_psychic(board, subject, visions)

# Appendix01.02.04 allows unmeasured OWN-unit abilities in reserves/passengers.
# This selector covers Watchin' and Visions; Roar cannot measure to an enemy.
fun orks_offboard_support_valid(Board board, SourceBank bank, UnitID source, Bool owner, Bool visions) -> Bool:
    if bank.value == SourceBank::battlefield.value or source.get() >= source_bank_size(board, bank):
        return false
    ref unit = source_bank_unit(board, bank, source.get())
    if unit.owned_by_player1 != owner or !has_live_model(unit):
        return false
    if visions:
        return orks_psychic_unit_available(board, unit, true)
    return orks_watchin_available(board, unit)

# Bank and unit choices are separate finite stages; spare IDs are rejected
# before indexing. This is an editor/storage distinction, not a game rule.
fun orks_offboard_support_available(Board board, SourceBank bank, Bool owner, Bool visions) -> Bool:
    if bank.value != SourceBank::reserves.value and bank.value != SourceBank::embarked.value:
        return false
    let source : UnitID
    for slot in range(source_bank_size(board, bank)):
        source = slot
        if orks_offboard_support_valid(board, bank, source, owner, visions):
            return true
    return false

# UnitID means a bank index here, so it has explicit labeled buttons rather
# than battlefield click autodetection (Godot action contract).
act choose_orks_offboard_support(ctx Board board, frm Bool owner, frm Bool visions) -> OrksOffboardSupportSelection:
    act choose_orks_support_bank(frm SourceBank bank) {orks_offboard_support_available(board, bank, owner, visions)}
    board.orks_support_bank = bank
    act choose_orks_offboard_unit(frm UnitID source) {orks_offboard_support_valid(board, bank, source, owner, visions)}
    board.orks_selected_unit = source
    if visions:
        board.shared_actions.use_orks_psychic = use_orks_psychic(board, source_bank_unit(board, bank, source.get()).identity, true)
        subaction*(board) board.shared_actions.use_orks_psychic
    else:
        commit_orks_watchin(board, source_bank_unit(board, bank, source.get()))

# Dread Power is unmeasured and may target a friendly reserve Walker in your
# Movement phase (source card; Not On The Battlefield01.02.04).
fun orks_offboard_dread_power_valid(Board board, SourceBank bank, UnitID source, Bool owner) -> Bool:
    return bank.value != SourceBank::battlefield.value and source.get() < source_bank_size(board, bank) and orks_dread_power_valid(board, source_bank_unit(board, bank, source.get()), owner)

# Dread Power has no range condition; the same source/CP gate applies to all
# banks (Dread Mob card; appendix01.02.04).
fun orks_dread_power_valid(Board board, Unit unit, Bool owner) -> Bool:
    return unit.owned_by_player1 == owner and owner == board.current_player and board.timing.phase == BattlePhase::movement and has_live_model(unit) and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::walker) and board.can_target_strat(owner, Stratagem::orks_dread_power, unit)

# Spend before the persisting own-unit effect, preserving actual unit history
# across embark/ingress (Dread Power; core p54; appendix01.02.02).
fun commit_orks_dread_power(Board board, Unit unit):
    board.commit_stratagem(unit.owned_by_player1, Stratagem::orks_dread_power, unit)
    grant_orks_own_payload(board, unit, 300 + Stratagem::orks_dread_power.value, riled_up_grant(), SourceDuration::next_own_turn)

# Only real bank entries can be selected, with CP affordability before the
# initial stage. No fake battlefield unit is created to grant riled status.
fun orks_offboard_dread_power_available(Board board, SourceBank bank, Bool owner) -> Bool:
    if bank.value != SourceBank::reserves.value and bank.value != SourceBank::embarked.value:
        return false
    let source : UnitID
    for slot in range(source_bank_size(board, bank)):
        source = slot
        if orks_offboard_dread_power_valid(board, bank, source, owner):
            return true
    return false

# Pay for the chosen unit before granting its effect, preserving the bank's
# per-unit phase history when that Walker later ingresses (core p54/01.02.02).
act choose_orks_offboard_dread_power(ctx Board board, frm Bool owner) -> OrksOffboardDreadPower:
    act choose_orks_dread_bank(frm SourceBank bank) {orks_offboard_dread_power_available(board, bank, owner)}
    board.orks_support_bank = bank
    act choose_offboard_dread_unit(frm UnitID source) {orks_offboard_dread_power_valid(board, bank, source, owner)}
    ref unit = source_bank_unit(board, bank, source.get())
    commit_orks_dread_power(board, unit)

# One psychic-level budget is shared with Wurrband; each named psychic ability
# is usable once per phase. Da Jump also shares one army/battle-round token.
# Sources: Orks/{Weirdboy,Kill-Rig}; faction Unstable Energies;22.03.01.
fun orks_datasheet_psychic_available(Board board, UnitID source, Int rule) -> Bool:
    if source.get() >= board.units.size() or board[source].off_battlefield or !has_live_model(board[source]) or board[source].battle_socked:
        return false
    ref unit = board[source]
    if (rule == 151 or rule == 162) and (board.timing.phase.value != BattlePhase::movement.value or unit.owned_by_player1 != board.current_player):
        return false
    if (rule == 152 or rule == 153) and board.timing.phase.value != BattlePhase::fight.value:
        return false
    let ability = AbilityKind::da_jump
    if rule == 152:
        ability = AbilityKind::weirdboy_warpath
    if rule == 153:
        ability = AbilityKind::kill_rig_warpath
    if rule == 162:
        ability = AbilityKind::beastscent
    if !unit.has_ability(ability):
        return false
    let psychic_usage_scope = SourceUseScope::unit
    if rule == 151:
        psychic_usage_scope = SourceUseScope::army
    let usage = make_source_usage(unit.owned_by_player1, rule, unit.identity, invalid_entity_identity(), psychic_usage_scope, source_use_limits(1, 0, 0, 0))
    if rule == 151:
        usage.limits.round = 1
    return unit.orks_psychic_usage.budget.available(board.current_round.value + 1, orks_psyker_level(unit)) and source_usage_available(board, usage)

# The printed ability keeps its own usage key; the psychic test is shared
# with Wurrband and other datasheets (Unstable Energies22.03.01).
fun orks_datasheet_psychic(Board board, UnitID source, BInt<151, 163> rule) -> OrksPsychicTest:
    assert(orks_datasheet_psychic_available(board, source, rule.value), "datasheet psychic unavailable")
    let psychic_usage_scope = SourceUseScope::unit
    if rule.value == 151:
        psychic_usage_scope = SourceUseScope::army
    let usage = make_source_usage(board[source].owned_by_player1, rule.value, board[source].identity, invalid_entity_identity(), psychic_usage_scope, source_use_limits(1, 0, 0, 0))
    if rule.value == 151:
        usage.limits.round = 1
    commit_source_usage(board, usage)
    return orks_psychic_test(board, board[source].identity)
