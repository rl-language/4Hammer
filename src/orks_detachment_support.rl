import orks_detachment_actions

# Usage belongs to the printed bearer/army scope, not an action-frame address.
# Da Boss is Watchin'/Morgog/Surly are once per battle PER ARMY. Psychic phase
# and round budgets are separate (Unstable Energies; appendix22.03.01).
fun orks_option_usage(Unit unit, Model model, OrksEnhancement option) -> SourceInstance:
    let instance : SourceInstance
    instance.rule = 200 + option.value
    instance.owner = unit.owned_by_player1
    instance.source_unit = unit.identity
    instance.source_model = model.identity
    instance.use_scope = SourceUseScope::army
    instance.limits.battle = 1
    return instance

# A source choice needs a real battlefield actor; offboard units can keep
# their own effects but cannot select external ranged targets (01.02.04).
fun orks_support_actor(Board board, UnitID source, Bool owner) -> Bool:
    return source.get() < board.units.size() and board[source].owned_by_player1 == owner and !board[source].off_battlefield and has_live_model(board[source])

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

# Movement-phase free abilities may be used between activations and before
# selecting a particular unit; the same source usage gate governs both hooks.
fun orks_movement_ability_valid(Board board, UnitID source, OrksDetachmentAbility ability) -> Bool:
    if !orks_support_actor(board, source, board.current_player) or !(board.timing.phase == BattlePhase::movement):
        return false
    ref unit = board[source]
    if ability.value == OrksDetachmentAbility::roar_of_mork.value:
        return orks_psychic_available(board, source, false) and orks_roar_has_target(board, source)
    if ability.value == OrksDetachmentAbility::da_boss_is_watchin.value:
        return orks_watchin_available(board, unit)
    return false

# Avoid exposing an unavailable choice stage to legacy/non-Orks fixtures.
fun orks_movement_ability_available(Board board, UnitID source) -> Bool:
    return orks_movement_ability_valid(board, source, OrksDetachmentAbility::roar_of_mork) or orks_movement_ability_valid(board, source, OrksDetachmentAbility::da_boss_is_watchin)

# Watchin' riles its OWN unit to next own turn, once per army/battle; Roar
# selects an enemy after its psychic roll. Source: the two Orks option cards.
act orks_movement_abilities(ctx Board board, frm UnitID source) -> OrksMovementAbilities:
    while orks_movement_ability_available(board, source):
        actions:
            act finish_orks_movement_abilities()
                break
            act choose_orks_movement_ability(OrksDetachmentAbility ability) {orks_movement_ability_valid(board, source, ability)}
                if ability.value == OrksDetachmentAbility::roar_of_mork.value:
                    board.shared_actions.use_orks_psychic = use_orks_psychic(board, source, false)
                    subaction*(board) board.shared_actions.use_orks_psychic
                else:
                    commit_orks_watchin(board, board[source])

# Returning Models01.02.03 forbids a new engagement and requires coherency
# with phase-start members. Quads and intentional circular proxies remain.
fun orks_return_position_valid(Board board, UnitID target, Model returned, BoardPosition position, Bool surly) -> Bool:
    let candidate : Model
    candidate = returned
    candidate.position = position
    candidate.off_battlefield = false
    candidate.state = ModelState::normal
    if !model_placement_valid(board, candidate):
        return false
    let coherent = 0
    for unit_index in range(board.units.size()):
        ref unit = board.units[unit_index]
        for member in range(unit.models.size()):
            ref other = unit[member]
            if other.off_battlefield or !fight_model_present(other):
                continue
            if model_bases_overlap(candidate, other):
                return false
            if unit_index == target.get() and other.is_alive():
                let phase_start = false
                for original in range(board[target].history.phase_start_members.size()):
                    phase_start = phase_start or board[target].history.phase_start_members[original] == other.identity
                if phase_start and candidate.is_engaged_with(other):
                    coherent = coherent + 1
            if unit.owned_by_player1 != board[target].owned_by_player1 and candidate.is_engaged_with(other):
                if surly:
                    return false
                let already_engaged = false
                for enemy in range(board[target].history.phase_start_engagements.size()):
                    already_engaged = already_engaged or board[target].history.phase_start_engagements[enemy] == unit.identity
                if !already_engaged:
                    return false
    if !surly and live_attachment_strength(board[target]) > 0:
        return coherent >= min(2, 1 + int(live_attachment_strength(board[target]) + 1 >= 7))
    if surly and live_attachment_strength(board[target]) > 0:
        # Surly still returns to a coherent unit; its special rule lifts only
        # the phase-start restriction and requires unengaged setup.
        let neighbours = 0
        for member in range(board[target].models.size()):
            if board[target][member].is_alive() and candidate.is_engaged_with(board[target][member]):
                neighbours = neighbours + 1
        return neighbours >= 1 + int(live_attachment_strength(board[target]) + 1 >= 7)
    return true

# Setup searches the finite supported grid for a legal return before asking
# the controller for a position; unavailable placement cannot deadlock a frame.
fun orks_return_has_position(Board board, UnitID target, Model returned, Bool surly) -> Bool:
    let position : BoardPosition
    for x in range(BOARD_WIDTH):
        for y in range(BOARD_HEIGHT):
            position.x = x
            position.y = y
            if orks_return_position_valid(board, target, returned, position, surly):
                return true
    return false

# Archive selection preserves physical weapon usage and original identity.
# Heal a wounded living model before reviving a non-Character (02.02.04).
fun orks_heal_wounded(Unit unit) -> Bool:
    for member in range(unit.models.size()):
        if unit[member].is_alive() and unit[member].suffered_wounds > 0:
            return true
    return false

# No Character revival is inferred from unit healing. Explicit Surly returns
# its own bearer separately with the card's3-wound exception (01.02.03).
fun orks_heal_archive_valid(Board board, UnitID target, ModelID archive) -> Bool:
    if archive.get() >= board[target].destroyed_models.value.size() or orks_heal_wounded(board[target]) or !board[target].models.has_capacity():
        return false
    ref returned = board[target].destroyed_models.value[archive.get()]
    return !returned.is_character() and orks_return_has_position(board, target, returned, false)

# Unit healing spends one wound at a time and stops at starting strength. It
# returns original models/equipment with1W, never generates new identities.
act heal_orks_unit(ctx Board board, frm UnitID target, frm BInt<0, 4> count) -> OrksUnitHealing:
    board.orks_selected_unit = target
    board.shared_actions.heal_orks_component = heal_orks_component(board, board[target], SourceBank::battlefield, count)
    subaction*(board, board[target]) board.shared_actions.heal_orks_component

# Runtherd and War Horde Breakin' Heads are own-unit shock responses in every
# bank (named source cards; appendix01.02.04). Share eligibility, CP, D3 and
# shock removal; only mortal allocation dispatch depends on location (p24).
act orks_became_shocked(ctx Board board, frm EntityIdentity subject) -> OrksBecameShocked:
    frm location = locate_source(board, subject, invalid_entity_identity())
    if !location.found:
        return
    board.shared_actions.orks_runtherd_shock = orks_runtherd_shock(board, source_bank_unit(board, location.bank, location.unit.value))
    subaction*(board, source_bank_unit(board, location.bank, location.unit.value)) board.shared_actions.orks_runtherd_shock
    location = locate_source(board, subject, invalid_entity_identity())
    if !location.found or !orks_breakin_heads_available(board, source_bank_unit(board, location.bank, location.unit.value)):
        return
    board.orks_support_bank = location.bank
    board.orks_selected_unit = location.unit.value
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = source_bank_unit(board, location.bank, location.unit.value).owned_by_player1
    actions:
        act decline_breakin_heads()
        act breakin_heads()
            board.commit_stratagem(source_bank_unit(board, location.bank, location.unit.value).owned_by_player1, Stratagem::orks_breakin_heads, source_bank_unit(board, location.bank, location.unit.value))
            board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
            subaction* board.shared_actions.evaluate_random_stat
            frm wounds_result_snapshot_1 = board.shared_actions.evaluate_random_stat.result
            frm head_losses : CombatCounter
            head_losses = wounds_result_snapshot_1.value
            frm target : UnitID
            target = location.unit.value
            board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, location.bank, target, target, false, head_losses)
            subaction*(board) board.shared_actions.resolve_mortal_wounds
            location = locate_source(board, subject, invalid_entity_identity())
            if location.found:
                source_bank_unit(board, location.bank, location.unit.value).battle_socked = false
    board.current_decision_maker = previous_owner

# War Horde's explicit shocked-target exception stays in the stratagem
# registry; bank membership does not duplicate or relax its target conditions.
fun orks_breakin_heads_available(Board board, Unit unit) -> Bool:
    return unit.battle_socked and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::infantry) and !unit.attached_units.empty() and board.can_target_strat(unit.owned_by_player1, Stratagem::orks_breakin_heads, unit)

# Battlefield source callers translate selectors at the boundary; reserves and
# passengers already have a stable identity (core pp65/68; appendix01.02.04).
fun orks_became_shocked(Board board, UnitID target) -> OrksBecameShocked:
    let subject = invalid_entity_identity()
    if target.get() < board.units.size():
        subject = board[target].identity
    return orks_became_shocked(board, subject)

# Exact phase windows for the three start/end cards; target permissions and CP
# stay in the common registry (Mob Mentality, Dubious Restraint, Dread Power).
fun orks_support_card_valid(Board board, UnitID source, Stratagem card, Bool owner, TimingWindow window) -> Bool:
    if !orks_support_actor(board, source, owner) or owner != board.current_player or !board.can_target_strat(owner, card, board[source]):
        return false
    if card == Stratagem::orks_mob_mentality:
        return window == TimingWindow::command_start and board[source].has_keyword(Keyword::orks) and board[source].has_keyword(Keyword::infantry) and live_attachment_strength(board[source]) >= 13
    if card == Stratagem::orks_dubious_restraint:
        return (window == TimingWindow::movement_start or window == TimingWindow::movement_end) and orks_taktikal_unit(board[source]) and orks_controlled_objective(board, source)
    if card == Stratagem::orks_dread_power:
        return orks_dread_power_valid(board, board[source], owner)
    if card == Stratagem::orks_delicious_eating_squigs:
        return board.timing.phase == BattlePhase::movement and orks_type(board[source], OrksDatasheet::rukkatrukk_squigbuggies)
    return false

# Only an objective currently controlled by the selected unit can be secured.
# Marker control itself uses the core stored control snapshot (p52).
fun orks_controlled_objective(Board board, UnitID source) -> Bool:
    for objective in range(4):
        if board.unit_controls_objective(board[source], objective):
            return true
    return false

# Mob Mentality selects a visible nearby friendly ORKS beneficiary separately
# from its13+-model CP target. Delicious similarly targets the actual buggy.
fun orks_support_target(Board board, UnitID source, UnitID target, Stratagem card) -> Bool:
    if target.get() >= board.units.size() or !orks_support_actor(board, target, board[source].owned_by_player1) or !board[target].has_keyword(Keyword::orks):
        return false
    if card == Stratagem::orks_mob_mentality:
        return live_unit_distance(board[source], board[target]) <= 12.0 and unit_visible_to_unit(board, board[source], board[target])
    return board[target].has_keyword(Keyword::infantry) and live_unit_distance(board[source], board[target]) <= 3.0

# Typed selector stages retain the editor's one-unit / one-enum contracts.
# Delicious may select any number of DISTINCT friendly units, each heals3.
act use_orks_support_card(ctx Board board, frm UnitID source, frm Stratagem card) -> OrksSupportCard:
    if card == Stratagem::orks_dread_power:
        commit_orks_dread_power(board, board[source])
    else:
        board.commit_stratagem(board[source].owned_by_player1, card, board[source])
    if card == Stratagem::orks_mob_mentality:
        act choose_mob_mentality_target(frm UnitID mob) {orks_support_target(board, source, mob, card)}
        grant_orks_effect(board, source, mob, 300 + card.value, OrksEffectKind::automatic_shock_success, 1, SourceDuration::phase, invalid_entity_identity())
    if card == Stratagem::orks_dubious_restraint:
        act choose_orks_secured_objective(BInt<0, 4> objective) {board.unit_controls_objective(board[source], objective.value)}
        board.grant_secured_objective(objective.value, board[source].owned_by_player1)
    if card == Stratagem::orks_delicious_eating_squigs:
        frm healed : Bool[MAX_UNIT_COUNT]
        while true:
            actions:
                act finish_eating_squigs()
                    break
                act choose_squig_healing_unit(frm UnitID healing) {orks_support_target(board, source, healing, card), !healed[healing.get()]}
                    healed[healing.get()] = true
                    frm heal_three : BInt<0, 4>
                    heal_three = 3
                    board.shared_actions.heal_orks_unit = heal_orks_unit(board, healing, heal_three)
                    subaction*(board) board.shared_actions.heal_orks_unit

# Edge withdrawal is measured to any part of any live circular base, while
# no Enemy Engagement is waived (Instinctive Hunters; supplied Within).
fun orks_near_edge(Unit unit) -> Bool:
    for member in range(unit.models.size()):
        ref model = unit[member]
        if model.is_alive():
            let radius = model.base_radius_micrometres()
            let clearance = min(min(model.position.x.value, BOARD_WIDTH - model.position.x.value), min(model.position.y.value, BOARD_HEIGHT - model.position.y.value))
            if float(clearance * MICROMETRES_PER_INCH) - radius <= float(6 * MICROMETRES_PER_INCH):
                return true
    return false

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

# Literal timing/keyword clauses for phase-end movement/withdrawal cards.
# Eligibility snapshots are captured at actual phase start (While Their
# Backs Are Turned) and Fight selection (Keep It Runnin').
fun orks_end_card_valid(Board board, UnitID source, Stratagem card, Bool owner, TimingWindow window) -> Bool:
    if !orks_support_actor(board, source, owner) or board.is_in_melee(board[source]) or !board.can_target_strat(owner, card, board[source]):
        return false
    if card == Stratagem::orks_while_their_backs_are_turned:
        return window == TimingWindow::movement_end and owner != board.current_player and orks_taktikal_unit(board[source]) and !board[source].history.phase_start_engagements.empty()
    if card == Stratagem::orks_instinctive_hunters:
        return window == TimingWindow::fight_end and owner != board.current_player and board[source].has_keyword(Keyword::beast_snagga) and orks_near_edge(board[source]) and board.reserve_units.has_capacity()
    if card == Stratagem::orks_keep_it_runnin:
        return window == TimingWindow::fight_end and board[source].has_keyword(Keyword::orks) and board[source].has_keyword(Keyword::infantry) and board[source].history.fight_eligible_phase == board.phase_serial.value + 1 and orks_fight_end_carrier_available(board, source)
    return false

# Source usage rechecks the once-per-army/battle cap after other simultaneous
# effects, preserving the user's current-player then opponent sequencing.
fun orks_morgog_valid(Board board, UnitID source, Bool owner, TimingWindow window) -> Bool:
    if !orks_support_actor(board, source, owner) or owner == board.current_player or !(window == TimingWindow::movement_end) or board.is_in_melee(board[source]):
        return false
    for member in range(board[source].models.size()):
        ref model = board[source][member]
        if model_has_orks_enhancement(board[source], model, OrksEnhancement::morgogs_finkin_cap) and source_usage_available(board, orks_option_usage(board[source], model, OrksEnhancement::morgogs_finkin_cap)):
            return true
    return false

# Surly is a compulsory end-phase roll, not a free revival choice or a new
# model. Only its bearer destroyed in THIS phase can consume the army token.
fun orks_surly_archive_valid(Board board, UnitID source, ModelID archive, Bool owner) -> Bool:
    if source.get() >= board.units.size() or board[source].owned_by_player1 != owner or archive.get() >= board[source].destroyed_models.value.size():
        return false
    return orks_surly_casualty_valid(board, board[source], archive)

# One casualty predicate for all banks: the actual bearer, this phase and its
# unspent army token. Source: Surly as a Squiggoth; appendix01.02.03.
fun orks_surly_casualty_valid(Board board, Unit unit, ModelID archive) -> Bool:
    if archive.get() >= unit.destroyed_models.value.size():
        return false
    ref model = unit.destroyed_models.value[archive.get()]
    return model.orks_enhancement.value == OrksEnhancement::surly_as_a_squiggoth.value and model.destroyed_phase == board.phase_serial.value + 1 and source_usage_available(board, orks_option_usage(unit, model, OrksEnhancement::surly_as_a_squiggoth))

# No distances are measured from offboard units; Surly uses its archived
# physical death location instead (source card, not reserve visibility).
fun orks_surly_available(Board board, UnitID source, Bool owner, TimingWindow window) -> Bool:
    if source.get() >= board.units.size() or !(window == TimingWindow::command_end or window == TimingWindow::movement_end or window == TimingWindow::shooting_end or window == TimingWindow::charge_end or window == TimingWindow::fight_end):
        return false
    let archive : ModelID
    for member in range(board[source].destroyed_models.value.size()):
        archive = member
        if orks_surly_archive_valid(board, source, archive, owner):
            return true
    return false

# A returned Surly model must choose a nearest legal whole-quad location.
# Compare squared centre distances; equal circular bases cancel from the
# nearest-location comparison. Exact continuous/oval geometry stays deferred.
fun orks_surly_position_valid(Board board, UnitID source, Model model, BoardPosition position) -> Bool:
    if !orks_return_position_valid(board, source, model, position, true):
        return false
    let chosen = (position.x.value - model.position.x.value) * (position.x.value - model.position.x.value) + (position.y.value - model.position.y.value) * (position.y.value - model.position.y.value)
    let alternative : BoardPosition
    for x in range(BOARD_WIDTH):
        for y in range(BOARD_HEIGHT):
            let other = (x - model.position.x.value) * (x - model.position.x.value) + (y - model.position.y.value) * (y - model.position.y.value)
            if other < chosen:
                alternative.x = x
                alternative.y = y
                if orks_return_position_valid(board, source, model, alternative, true):
                    return false
    return true

# Source mandates the roll even if placement cannot be supported. A passed
# roll returns the original bearer with3W, retaining once-only weapon history.
act resolve_orks_surly(ctx Board board, frm UnitID source, frm Bool owner) -> OrksSurly:
    act choose_surly_casualty(frm ModelID archive) {orks_surly_archive_valid(board, source, archive, owner)}
    board.shared_actions.return_orks_surly = return_orks_surly(board, board[source], SourceBank::battlefield, source, archive)
    subaction*(board, board[source]) board.shared_actions.return_orks_surly

# One Surly roll/usage/restoration path. Battlefield returns select a nearest
# legal quad; passengers need capacity; reserves need no position (01.02.03).
act return_orks_surly(ctx Board board, ctx Unit unit, frm SourceBank bank, frm UnitID source, frm ModelID archive) -> OrksSurlyReturn:
    frm returned : Model
    returned = unit.destroyed_models.value[archive.get()]
    commit_source_usage(board, orks_option_usage(unit, returned, OrksEnhancement::surly_as_a_squiggoth))
    act roll(Dice surly_face)
    if surly_face.value >= 2 and unit.models.has_capacity():
        frm placeable = true
        if bank.value == SourceBank::battlefield.value:
            placeable = orks_return_has_position(board, source, returned, true)
            if placeable:
                act place_surly_model(BoardPosition position) {orks_surly_position_valid(board, source, returned, position)}
                returned.position = position
        else:
            placeable = orks_return_capacity(board, unit, returned)
        if placeable:
            prepare_orks_healed_model(returned, bank.value != SourceBank::battlefield.value)
            returned.suffered_wounds = max(0, returned.profile.wounds() - 3)
            restore_attachment_provenance(unit, returned)
            unit.models.append(returned)
            unit.retired = false
            unit.destroyed_models.value.erase(archive.get())
            refresh_source_effects(board, TimingWindow::none)

# Window dispatch lets the controller interleave faction effects with core
# effects. A compulsory Surly roll cannot be bypassed by finishing its group.
fun orks_package_window_available(Board board, UnitID source, Bool owner, TimingWindow window) -> Bool:
    if orks_surly_available(board, source, owner, window) or orks_morgog_valid(board, source, owner, window):
        return true
    if source.get() >= board.units.size():
        return false
    if window == TimingWindow::fight_start and board[source].owned_by_player1 == owner and orks_psychic_available(board, source, true):
        return true
    return orks_support_card_valid(board, source, Stratagem::orks_dubious_restraint, owner, window) or orks_end_card_valid(board, source, Stratagem::orks_while_their_backs_are_turned, owner, window) or orks_end_card_valid(board, source, Stratagem::orks_instinctive_hunters, owner, window) or orks_end_card_valid(board, source, Stratagem::orks_keep_it_runnin, owner, window)

# Iteration is over real unit slots, including a retired Surly archive; it is
# never a count of selected card labels substituted for actual eligibility.
fun orks_package_windows_remaining(Board board, Bool owner, TimingWindow window, Bool mandatory) -> Bool:
    let source : UnitID
    for slot in range(board.units.size()):
        source = slot
        if mandatory and orks_surly_available(board, source, owner, window) or !mandatory and orks_package_window_available(board, source, owner, window):
            return true
    return false

# Four end cards and optional psychic/Morgog branches share controller ordering
# but retain separate source costs/lifetimes and explicit carrier decisions.
act orks_package_window(ctx Board board, frm UnitID source, frm Bool owner, frm TimingWindow window) -> OrksPackageWindow:
    actions:
        act use_visions_of_violence() {window == TimingWindow::fight_start, board[source].owned_by_player1 == owner, orks_psychic_available(board, source, true)}
            board.shared_actions.use_orks_psychic = use_orks_psychic(board, source, true)
            subaction*(board) board.shared_actions.use_orks_psychic
        act use_morgogs_finkin_cap() {orks_morgog_valid(board, source, owner, window)}
            for member in range(board[source].models.size()):
                if model_has_orks_enhancement(board[source], board[source][member], OrksEnhancement::morgogs_finkin_cap):
                    commit_source_usage(board, orks_option_usage(board[source], board[source][member], OrksEnhancement::morgogs_finkin_cap))
            board.current_roll = rerollable_dice_roll(board, unit_is_riled_up(board[source]), false, false, owner, source)
            subaction*(board) board.current_roll
            frm distance_result_snapshot_2 = board.current_roll.result
            frm morgog_distance : StatModifier
            morgog_distance = distance_result_snapshot_2.value
            board.shared_actions.granted_move = reactive_move(board, source, morgog_distance, false)
            subaction*(board) board.shared_actions.granted_move
        act use_surly_as_a_squiggoth() {orks_surly_available(board, source, owner, window)}
            board.shared_actions.resolve_orks_surly = resolve_orks_surly(board, source, owner)
            subaction*(board) board.shared_actions.resolve_orks_surly
        act choose_orks_window_stratagem(frm Stratagem card) {orks_support_card_valid(board, source, card, owner, window) and card == Stratagem::orks_dubious_restraint or orks_end_card_valid(board, source, card, owner, window)}
            if card == Stratagem::orks_dubious_restraint:
                board.shared_actions.use_orks_support_card = use_orks_support_card(board, source, card)
                subaction*(board) board.shared_actions.use_orks_support_card
            else:
                board.commit_stratagem(owner, card, board[source])
                if card == Stratagem::orks_while_their_backs_are_turned:
                    frm six : StatModifier
                    six = 6
                    board.shared_actions.granted_move = reactive_move(board, source, six, false)
                    subaction*(board) board.shared_actions.granted_move
                if card == Stratagem::orks_instinctive_hunters:
                    let relocated = reposition_unit(board, source)
                    assert(relocated, "accepted withdrawal could not move to reserves")
                if card == Stratagem::orks_keep_it_runnin:
                    act choose_fight_end_transport(frm UnitID carrier) {orks_fight_end_transport_has_model(board, source, carrier)}
                    act choose_fight_end_carrier_model(ModelID model) {orks_fight_end_carrier(board, source, carrier, model)}
                    force_orks_fight_end_embark(board, source, carrier, model)

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

# Reactions rely on the actual completed activation ledger and original enemy
# unit. Hit/lost-wound criteria are distinct, and the user's no-price scope
# does not erase CP expenditure or destroyed-target exceptions.
fun orks_post_attack_card_valid(Board board, UnitID attacker, UnitID target, Stratagem card, Bool melee) -> Bool:
    if target.get() >= board.units.size() or attacker.get() >= board.units.size():
        return false
    ref unit = board[target]
    let hit = false
    let lost = false
    let destroyed = false
    for record in range(board.orks_attack_records.size()):
        if board.orks_attack_records[record].target == unit.identity:
            hit = board.orks_attack_records[record].successful_hits > 0
            lost = board.orks_attack_records[record].wounds_lost > 0
            destroyed = board.orks_attack_records[record].destroyed
    if !board.can_target_strat(unit.owned_by_player1, card, unit):
        return false
    if card == Stratagem::orks_infested_war_zone:
        return destroyed and unit.orks_destroyed_attack == board.orks_attack_serial and unit.owned_by_player1 != board[attacker].owned_by_player1 and orks_original_type(unit, OrksDatasheet::gretchin) and board.reserve_units.has_capacity()
    if melee or !(board.timing.phase == BattlePhase::shooting) or unit.off_battlefield or !has_live_model(unit):
        return false
    if card == Stratagem::orks_grab_it:
        return target.get() == attacker.get() and unit.owned_by_player1 == board.current_player and orks_wrecka_unit(unit) and !board.is_in_melee(unit)
    if unit.owned_by_player1 == board.current_player or unit.owned_by_player1 == board[attacker].owned_by_player1:
        return false
    if card == Stratagem::orks_gun_crazy_show_offs:
        return hit and (orks_type(unit, OrksDatasheet::flash_gitz) or orks_type(unit, OrksDatasheet::tankbustas)) and has_live_model(board[attacker]) and (shooting_kind_valid(board, target, ShootingKind::normal) or shooting_kind_valid(board, target, ShootingKind::assault) or shooting_kind_valid(board, target, ShootingKind::close_quarters) or shooting_kind_valid(board, target, ShootingKind::indirect))
    if card == Stratagem::orks_goaded_into_action:
        return lost and unit.has_keyword(Keyword::beast_snagga) and !board.is_in_melee(unit) and has_surge_target(board, target)
    return false

# A destroyed unit loses its live keyword union but its original datasheet
# remains in battle-start metadata. This helper is ONLY for destruction cards;
# ordinary attached keyword tests must still exclude extinct components (p67).
fun orks_original_type(Unit unit, OrksDatasheet kind) -> Bool:
    for member in range(unit.battle_start_models.value.size()):
        if model_matches_datasheet(unit.battle_start_models.value[member], kind):
            return true
    return false

# Any optional absent card exits automatically. Infested's2CP cost and Grot
# Shield damage can create a relevant death even outside declared targets.
fun orks_post_attack_available(Board board, UnitID attacker, Bool melee) -> Bool:
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_infested_war_zone, melee) or orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_grab_it, melee) or orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_gun_crazy_show_offs, melee) or orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_goaded_into_action, melee):
            return true
    return false

# A selected beneficiary must offer an actual source card, not just have a
# ledger entry. Separate UnitID and Stratagem choices avoid a large product.
fun orks_post_attack_target_valid(Board board, UnitID attacker, UnitID target, Bool melee) -> Bool:
    return orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_infested_war_zone, melee) or orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_grab_it, melee) or orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_gun_crazy_show_offs, melee) or orks_post_attack_card_valid(board, attacker, target, Stratagem::orks_goaded_into_action, melee)

# No recursive Attack frame is stored inside an Attack. Gun-crazy returns a
# queued actor; the flat outer runner performs its ordinary shooting later.
act resolve_orks_post_attack(ctx Board board, frm UnitID attacker, frm Bool melee) -> OrksPostAttack:
    frm previous_owner = board.current_decision_maker
    frm reaction_available = false
    frm reaction_source : UnitID
    frm owner = board.current_player
    frm controllers : BInt<0, 3>
    while controllers.value < 2:
        board.current_decision_maker = owner
        while orks_post_attack_owner_available(board, attacker, melee, owner):
            actions:
                act finish_orks_attack_reactions()
                    break
                act choose_orks_attack_reaction_unit(frm UnitID recipient) {orks_post_attack_target_valid(board, attacker, recipient, melee), board[recipient].owned_by_player1 == owner}
                    act choose_orks_attack_reaction_card(frm Stratagem card) {orks_post_attack_card_valid(board, attacker, recipient, card, melee)}
                    board.commit_stratagem(owner, card, board[recipient])
                    if card == Stratagem::orks_infested_war_zone:
                        create_orks_replacement(board, recipient)
                    if card == Stratagem::orks_grab_it:
                        grant_orks_effect(board, recipient, recipient, 300 + card.value, OrksEffectKind::no_charge, 1, SourceDuration::turn, invalid_entity_identity())
                        frm six : StatModifier
                        six = 6
                        board.shared_actions.granted_move = reactive_move(board, recipient, six, true)
                        subaction*(board) board.shared_actions.granted_move
                    if card == Stratagem::orks_gun_crazy_show_offs:
                        reaction_available = true
                        reaction_source = recipient
                    if card == Stratagem::orks_goaded_into_action:
                        board.current_roll = rerollable_dice_roll(board, unit_is_riled_up(board[recipient]), false, false, owner, recipient)
                        subaction*(board) board.current_roll
                        frm distance_result_snapshot_2 = board.current_roll.result
                        frm goad_distance : StatModifier
                        goad_distance = distance_result_snapshot_2.value
                        board.shared_actions.granted_move = surge(board, recipient, goad_distance, true)
                        subaction*(board) board.shared_actions.granted_move
                    board.current_decision_maker = owner
        owner = !owner
        controllers = controllers + 1
    board.current_decision_maker = previous_owner

# Exactly two controller groups follow Rules Sequencing. A destroyed source
# can still pay a destroyed-unit card through its retained metadata.
fun orks_post_attack_owner_available(Board board, UnitID attacker, Bool melee, Bool owner) -> Bool:
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if board[target].owned_by_player1 == owner and orks_post_attack_target_valid(board, attacker, target, melee):
            return true
    return false

# Flat attack/reaction queue: every Gun-crazy use consumes the ordinary shared
# once-per-phase stratagem limit, so repeated reactions end by rule rather than
# an invented depth cutoff. Its sole target is the enemy unit that just shot.
act attack_with_orks_reactions(ctx Board board, frm UnitID source, frm UnitID target, frm Bool melee, frm Bool overwatch) -> AttackWithOrksReactions:
    frm caller_target = board.orks_reaction_target
    frm continuing = true
    frm first = true
    while continuing:
        if !first:
            act choose_reaction_shooting_kind(ShootingKind kind) {shooting_kind_valid(board, source, kind)}
            board[source].shooting_kind = kind
        board.attack = attack(board, source, target, melee, overwatch)
        subaction*(board) board.attack
        board.shared_actions.resolve_orks_post_attack = resolve_orks_post_attack(board, source, melee)
        subaction*(board) board.shared_actions.resolve_orks_post_attack
        frm post_reaction_available_snapshot_1 = board.shared_actions.resolve_orks_post_attack.reaction_available
        frm post_reaction_source_snapshot_1 = board.shared_actions.resolve_orks_post_attack.reaction_source
        continuing = post_reaction_available_snapshot_1
        if continuing:
            target = source
            source = post_reaction_source_snapshot_1
            melee = false
            overwatch = false
            board.orks_reaction_target = board[target].identity
            first = false
    board.orks_reaction_target = caller_target

# Move-end reactions require the enemy's completed move within8in. Scarper
# uses6in if attached, Whirligig6in if riled; otherwise each rollsD6. The
# target must remain unengaged and pays its own exact1CP (Orks source cards).
fun orks_enemy_move_card_valid(Board board, UnitID mover, UnitID target, Stratagem card) -> Bool:
    if mover.get() >= board.units.size() or target.get() >= board.units.size() or !(board.timing.phase == BattlePhase::movement) or board[target].owned_by_player1 == board.current_player or board[target].owned_by_player1 == board[mover].owned_by_player1 or !orks_support_actor(board, target, board[target].owned_by_player1) or board.is_in_melee(board[target]) or live_unit_distance(board[mover], board[target]) > 8.0 or !board.can_target_strat(board[target].owned_by_player1, card, board[target]):
        return false
    return card == Stratagem::orks_scarper and orks_type(board[target], OrksDatasheet::gretchin) or card == Stratagem::orks_whirligig_evasion and orks_type(board[target], OrksDatasheet::deffkoptas)

# A Move frame cannot contain a reactive Move frame recursively. This hook
# returns the selected move parameters to the flat activation wrapper.
act select_orks_enemy_move_reaction(ctx Board board, frm UnitID mover) -> OrksEnemyMoveReaction:
    frm available = false
    frm target : UnitID
    frm distance : StatModifier
    frm previous_owner = board.current_decision_maker
    if orks_enemy_move_available(board, mover):
        board.current_decision_maker = !board[mover].owned_by_player1
        actions:
            act decline_orks_move_reaction()
            act choose_supreme_kunnin_unit(frm UnitID nazdreg) {orks_supreme_kunnin_valid(board, mover, nazdreg)}
                commit_source_usage(board, orks_remaining_usage(board[nazdreg], 154, true, false))
                target = nazdreg
                available = true
                frm fixed_five = false
                if unit_is_riled_up(board[nazdreg]):
                    act choose_supreme_fixed_five(Bool five)
                    fixed_five = five
                distance = 5
                if !fixed_five:
                    act roll(Dice kunnin_distance)
                    distance = kunnin_distance.value
            act choose_orks_move_reaction_unit(frm UnitID reaction) {orks_enemy_move_card_valid(board, mover, reaction, Stratagem::orks_scarper) or orks_enemy_move_card_valid(board, mover, reaction, Stratagem::orks_whirligig_evasion)}
                frm card : Stratagem
                card = Stratagem::orks_scarper
                if !orks_type(board[reaction], OrksDatasheet::gretchin):
                    card = Stratagem::orks_whirligig_evasion
                board.commit_stratagem(board[reaction].owned_by_player1, card, board[reaction])
                target = reaction
                available = true
                distance = 6
                if card == Stratagem::orks_scarper and board[reaction].attached_units.empty() or card == Stratagem::orks_whirligig_evasion and !unit_is_riled_up(board[reaction]):
                    act roll(Dice escape_distance)
                    distance = escape_distance.value
    board.current_decision_maker = previous_owner

# Actual eligible units, not chosen datasheet labels, determine availability.
fun orks_enemy_move_available(Board board, UnitID mover) -> Bool:
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_supreme_kunnin_valid(board, mover, target) or orks_enemy_move_card_valid(board, mover, target, Stratagem::orks_scarper) or orks_enemy_move_card_valid(board, mover, target, Stratagem::orks_whirligig_evasion):
            return true
    return false

# Readied Brawlers grants an explicit Assault Disembark permission to its
# WAGON's passengers after a successful Normal move, not before selection.
act orks_wagon_move_end(ctx Board board, frm UnitID source) -> OrksWagonMoveEnd:
    if board[source].owned_by_player1 != board.current_player or !(board.timing.phase == BattlePhase::movement) or !(board[source].history.move_kind == MovementKind::normal) or !board[source].has_keyword(Keyword::wagon) or !board.can_target_strat(board[source].owned_by_player1, Stratagem::orks_readied_brawlers, board[source]):
        return
    actions:
        act decline_readied_brawlers()
        act readied_brawlers()
            board.commit_stratagem(board[source].owned_by_player1, Stratagem::orks_readied_brawlers, board[source])
            grant_orks_effect(board, source, source, 300 + Stratagem::orks_readied_brawlers.value, OrksEffectKind::assault_disembark, 1, SourceDuration::phase, invalid_entity_identity())

# A completed charge, not a declared/failed charge, triggers Impending Krunch;
# each currently engaged enemy makes its own-1 shock roll (Blitz Brigade).
act orks_wagon_charge_end(ctx Board board, frm UnitID source) -> OrksWagonChargeEnd:
    if board[source].owned_by_player1 != board.current_player or !(board.timing.phase == BattlePhase::charge) or !board[source].has_charged or !board[source].has_keyword(Keyword::wagon) or !board.can_target_strat(board[source].owned_by_player1, Stratagem::orks_impending_krunch, board[source]):
        return
    actions:
        act decline_impending_krunch()
        act impending_krunch()
            board.commit_stratagem(board[source].owned_by_player1, Stratagem::orks_impending_krunch, board[source])
            frm targets : Bool[MAX_UNIT_COUNT]
            for slot in range(board.units.size()):
                targets[slot] = board[slot].owned_by_player1 != board[source].owned_by_player1 and has_live_model(board[slot]) and board[source].is_engaged_with(board[slot])
            while orks_pending_units(targets):
                act choose_krunch_target(frm UnitID target) {target.get() < board.units.size(), targets[target.get()]}
                targets[target.get()] = false
                frm penalty : LinearlyDistributedInt<0, 8>
                penalty = 1
                board.shared_actions.battle_shock_test = battle_shock_test(board, board[target], false, false, penalty)
                subaction*(board, board[target]) board.shared_actions.battle_shock_test

# Finite target flags permit player-chosen order without compaction hazards.
fun orks_pending_units(Bool[MAX_UNIT_COUNT] pending) -> Bool:
    for slot in range(MAX_UNIT_COUNT):
        if pending[slot]:
            return true
    return false

# Flyboss's ingress effect measures from the newly set up Aircraft, not its
# reserve coordinates. Accepted riled effects persist to next own turn.
fun orks_flyboss_ingress(Board board, UnitID source):
    if !unit_has_orks_enhancement(board[source], OrksEnhancement::flyboss):
        return
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_support_actor(board, target, board[source].owned_by_player1) and (board[target].has_keyword(Keyword::aircraft) or orks_type(board[target], OrksDatasheet::deffkoptas)) and board[target].has_keyword(Keyword::orks) and live_unit_distance(board[source], board[target]) <= 6.0:
            grant_orks_payload(board, source, target, 200 + OrksEnhancement::flyboss.value, riled_up_grant(), SourceDuration::next_own_turn)

# Impulsive Recon allows the first own Movement phase (round1), subject to
# ordinary ingress placement; the zero-based round alone does not waive it.
fun orks_ingress_round_allowed(Board board, Unit unit) -> Bool:
    return board.current_round >= 1 or (unit.has_ability(AbilityKind::deff_from_shadows) and unit.owned_by_player1 != board.current_player and board.timing.phase == BattlePhase::movement) or (unit.owned_by_player1 == board.current_player and board.timing.phase == BattlePhase::movement and unit.has_keyword(Keyword::aircraft) and unit_has_orks_enhancement(unit, OrksEnhancement::impulsive_recon) and !unit.history.has_ingressed)

# Unpredictable Genius triggers only when all declared ranged attacks share
# one target. Multiple-target declarations remain legal and do NOT trigger it.
# Madcap Meks source; target declarations/core grouping pp16-17.
fun orks_single_declared_target(DeclaredWeapons declarations) -> Int:
    let target = -1
    for weapon in range(declarations.size()):
        for unit in range(MAX_UNIT_COUNT):
            if declarations[weapon].targeted[unit]:
                if target >= 0 and target != unit:
                    return -1
                target = unit
    return target

# The actual selected source keywords, not profile names or a guessed legacy
# Big Mek factory, determine whether the table roll is required.
fun orks_madcap_actor(Board board, Unit unit) -> Bool:
    return orks_package(board, unit, OrksDetachment::madcap_meks) and unit.owned_by_player1 == board.current_player and board.timing.phase == BattlePhase::shooting and (unit.has_keyword(Keyword::big_mek) or orks_type(unit, OrksDatasheet::mek_gunz) or orks_type(unit, OrksDatasheet::morkanaut) or orks_type(unit, OrksDatasheet::wazbom_blastajet))

# Hop Splat selects an OTHER enemy within3in of the chosen target. No eligible
# other enemy means no selection/damage; no original-target substitution.
fun orks_hop_splat_target(Board board, UnitID source, UnitID target, UnitID other) -> Bool:
    return other.get() < board.units.size() and other.get() != target.get() and orks_support_actor(board, other, !board[source].owned_by_player1) and live_unit_distance(board[target], board[other]) <= 3.0

# Scoped grants cease after this shooting activation, rather than at phase
# end. Their keys are returned to the caller for precise overlapping expiry.
act orks_unpredictable_genius(ctx Board board, frm UnitID source, frm UnitID target) -> OrksUnpredictableGenius:
    frm effect : SourceEffectKey
    if !orks_madcap_actor(board, board[source]):
        return
    act roll(Dice genius_face)
    if genius_face == 1:
        grant_orks_effect(board, source, target, 470, OrksEffectKind::invulnerable_four, 1, SourceDuration::phase, invalid_entity_identity())
        effect = board.next_source_effect
    if genius_face == 4:
        grant_orks_effect(board, source, source, 470, OrksEffectKind::hit_plus_one, 1, SourceDuration::phase, invalid_entity_identity())
        effect = board.next_source_effect
    if genius_face == 5:
        grant_orks_effect(board, source, target, 470, OrksEffectKind::lifted, 1, SourceDuration::phase, invalid_entity_identity())
        effect = board.next_source_effect
    if genius_face == 6:
        grant_orks_payload(board, source, target, 470, characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, -1), SourceDuration::phase)
        effect = board.next_source_effect
    if genius_face == 2 or genius_face == 3:
        frm other_available = false
        let other : UnitID
        for slot in range(board.units.size()):
            other = slot
            other_available = other_available or orks_hop_splat_target(board, source, target, other)
        if other_available:
            act choose_hop_splat_target(frm UnitID splash_target) {orks_hop_splat_target(board, source, target, splash_target)}
            board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
            subaction* board.shared_actions.evaluate_random_stat
            frm damage_result_snapshot_1 = board.shared_actions.evaluate_random_stat.result
            frm amount : CombatCounter
            amount = damage_result_snapshot_1.value
            board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, splash_target, source, true, amount)
            subaction*(board) board.shared_actions.resolve_mortal_wounds

# Source-owned removal scans every bank/archive, preserving equal buffs from
# unrelated sources. Infrastructure for Madcap's explicit 'until ... has shot'.
fun remove_orks_scoped_effect(Board board, SourceEffectKey key):
    if key.value == 0:
        return
    let bank : SourceBank
    for b in range(3):
        bank.value = b
        for slot in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, slot)
            for member in range(unit.models.size()):
                remove_source_grant(unit[member], key)
            for archived in range(unit.destroyed_models.value.size()):
                remove_source_grant(unit.destroyed_models.value[archived], key)
    let index = board.source_effects.size() - 1
    while index >= 0:
        if board.source_effects[index].identity == key:
            board.source_effects.erase(index)
        index = index - 1

# Temperamental Shokka is optional once at this selection and affects its
# actual bearer; each branch keeps chance input explicit (source upgrade).
act orks_shokka_selection(ctx Board board, frm UnitID source) -> OrksShokkaSelection:
    frm member_index : ModelIterator
    while member_index.value < board[source].models.size():
        if model_has_orks_enhancement(board[source], board[source][member_index.value], OrksEnhancement::temperamental_shokka):
            frm bearer : ModelID
            bearer = member_index.value
            actions:
                act decline_temperamental_shokka()
                act temperamental_shokka()
                    act roll(Dice shokka_face)
                    frm kind : OrksEffectKind
                    kind = OrksEffectKind::shokka_attacks
                    if shokka_face == 1:
                        kind = OrksEffectKind::shokka_torrent
                        grant_orks_model_effect(board, source, bearer, 480, OrksEffectKind::shokka_destroy)
                    if shokka_face == 6:
                        kind = OrksEffectKind::shokka_sustained
                    grant_orks_model_effect(board, source, bearer, 481, kind)
        member_index = member_index + 1

# Enhanced Runt-maw chooses an enemy actually hit by the unit's attacks. Its
# Leadership ROLL penalty persists until next own turn, never alters Ld stats.
fun orks_runt_maw_target(Board board, UnitID source, UnitID target) -> Bool:
    if target.get() >= board.units.size() or !orks_support_actor(board, target, !board[source].owned_by_player1):
        return false
    for record in range(board.orks_attack_records.size()):
        if board.orks_attack_records[record].target == board[target].identity and board.orks_attack_records[record].successful_hits > 0:
            return true
    return false

# Model destruction bypasses wound prevention, then runs ordinary destruction
# triggers. It is not damage, and cannot retroactively add weapon Hazardous.
act orks_shooting_option_end(ctx Board board, frm UnitID source) -> OrksShootingOptionEnd:
    subaction*(board) barrage = orks_rokkit_barrage(board, source)
    if unit_has_orks_enhancement(board[source], OrksEnhancement::enhanced_runt_maw):
        frm target_available = false
        let target : UnitID
        for slot in range(board.units.size()):
            target = slot
            target_available = target_available or orks_runt_maw_target(board, source, target)
        if target_available:
            act choose_runt_maw_target(frm UnitID snotlings) {orks_runt_maw_target(board, source, snotlings)}
            grant_orks_effect(board, source, snotlings, 200 + OrksEnhancement::enhanced_runt_maw.value, OrksEffectKind::snotling_leadership_penalty, 1, SourceDuration::next_own_turn, invalid_entity_identity())
    frm member_index : ModelIterator
    while member_index.value < board[source].models.size():
        if board[source][member_index.value].is_alive() and model_orks_effect(board, board[source][member_index.value], OrksEffectKind::shokka_destroy) > 0:
            frm bearer : ModelID
            bearer = member_index.value
            frm identity = board[source][bearer].identity
            let job = damage_job(DamageKind::normal, source, source, false, false, board[source][bearer].wounds_left(), identity)
            commit_wound_loss(board, job, bearer, board[source][bearer].wounds_left(), false)
            frm jobs : DamageJobs
            board.shared_actions.resolve_damage_jobs = resolve_damage_jobs(board, jobs, false, source)
            subaction*(board) board.shared_actions.resolve_damage_jobs
            let remaining = board[source].find_model(identity)
            if remaining >= 0:
                member_index = remaining + 1
        else:
            member_index = member_index + 1

# Dreadherder's Shooting-phase selection is conditional on its bearer being
# within3in of a friendly non-Big-Mek ORKS Walker. The selected Walker may be
# Big Mek; the exclusion belongs to the preceding proximity clause, not target.
fun orks_dreadherder_target(Board board, UnitID source, UnitID target) -> Bool:
    if target.get() >= board.units.size() or !orks_support_actor(board, target, board[source].owned_by_player1) or !board[target].has_keyword(Keyword::orks) or !board[target].has_keyword(Keyword::walker):
        return false
    for bearer in range(board[source].models.size()):
        ref model = board[source][bearer]
        if model_has_orks_enhancement(board[source], model, OrksEnhancement::dreadherder):
            let proximate = false
            for nearby in range(board.units.size()):
                ref walker = board.units[nearby]
                if !walker.off_battlefield and has_live_model(walker) and walker.owned_by_player1 == board[source].owned_by_player1 and walker.has_keyword(Keyword::orks) and walker.has_keyword(Keyword::walker) and !walker.has_keyword(Keyword::big_mek) and live_distance_to_model(walker, model) <= 3.0:
                    proximate = true
            if proximate and live_distance_to_model(board[target], model) <= 3.0:
                return true
    return false

# One selection per phase belongs to this ability's printed phase period;
# its accepted hit-reroll grant lasts through the TURN, including Fight.
act orks_dreadherder_shooting(ctx Board board, frm UnitID source) -> OrksDreadherderShooting:
    frm previous_owner = board.current_decision_maker
    if !orks_support_actor(board, source, board.current_player) or !(board.timing.phase == BattlePhase::shooting):
        return
    board.current_decision_maker = board[source].owned_by_player1
    frm available = false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        available = available or orks_dreadherder_target(board, source, target)
    frm usage : SourceInstance
    usage.rule = 200 + OrksEnhancement::dreadherder.value
    usage.owner = board[source].owned_by_player1
    usage.source_unit = board[source].identity
    usage.use_scope = SourceUseScope::unit
    usage.limits.phase = 1
    if available and source_usage_available(board, usage):
        actions:
            act decline_dreadherder()
            act choose_dreadherder_target(frm UnitID walker) {orks_dreadherder_target(board, source, walker)}
                commit_source_usage(board, usage)
                grant_orks_effect(board, source, walker, 200 + OrksEnhancement::dreadherder.value, OrksEffectKind::reroll_hits_ones, 1, SourceDuration::turn, invalid_entity_identity())
    board.current_decision_maker = previous_owner

# Shared movement-phase sources can be used before selecting a move or between
# other units' activations. This prevents a source timing being narrowed to its
# own unit's move (Watchin'/Roar/Dread Power/Delicious source clauses).
fun orks_phase_support_available(Board board, UnitID source) -> Bool:
    return orks_movement_ability_available(board, source) or orks_support_card_valid(board, source, Stratagem::orks_dread_power, board.current_player, TimingWindow::none) or orks_support_card_valid(board, source, Stratagem::orks_delicious_eating_squigs, board.current_player, TimingWindow::none)

# Free abilities and paid cards remain distinct choices and share no invented
# once-per-phase cap. Each uses its own original source/CP usage rule.
act orks_phase_support(ctx Board board, frm UnitID source) -> OrksPhaseSupport:
    actions:
        act choose_orks_free_move_ability() {orks_movement_ability_available(board, source)}
            board.shared_actions.orks_movement_abilities = orks_movement_abilities(board, source)
            subaction*(board) board.shared_actions.orks_movement_abilities
        act choose_orks_phase_card(frm Stratagem card) {orks_support_card_valid(board, source, card, board.current_player, TimingWindow::none), card == Stratagem::orks_dread_power or card == Stratagem::orks_delicious_eating_squigs}
            board.shared_actions.use_orks_support_card = use_orks_support_card(board, source, card)
            subaction*(board) board.shared_actions.use_orks_support_card

# Mob Mentality occurs at the Battle-shock STEP start, after command CP gain,
# before recovery eligibility is frozen; it is not a Command-phase-start rule.
act orks_mob_mentality_step(ctx Board board) -> OrksMobMentalityStep:
    while orks_mob_mentality_available(board):
        actions:
            act decline_mob_mentality()
                break
            act choose_mob_mentality_source(frm UnitID source) {orks_support_card_valid(board, source, Stratagem::orks_mob_mentality, board.current_player, TimingWindow::command_start)}
                board.shared_actions.use_orks_support_card = use_orks_support_card(board, source, Stratagem::orks_mob_mentality)
                subaction*(board) board.shared_actions.use_orks_support_card

# At most one use per payer/phase is consumed when the beneficiary is chosen.
fun orks_mob_mentality_available(Board board) -> Bool:
    let source : UnitID
    for slot in range(board.units.size()):
        source = slot
        if orks_support_card_valid(board, source, Stratagem::orks_mob_mentality, board.current_player, TimingWindow::command_start):
            return true
    return false

# Headbutt measures from the retained Aircraft's death base, before removal.
# Other offboard units never acquire targets by using their last coordinates.
fun orks_headbutt_target(Board board, UnitID source, Model casualty, UnitID target) -> Bool:
    return target.get() < board.units.size() and orks_support_actor(board, target, !board[source].owned_by_player1) and live_distance_to_model(board[target], casualty) <= 12.0

# If no enemy can be selected, the replacement-demise effect has no valid use.
fun orks_headbutt_has_target(Board board, UnitID source, Model casualty) -> Bool:
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_headbutt_target(board, source, casualty, target):
            return true
    return false

# Kaptin's Hat redeploys up to3 friendly ORKS infantry after BOTH armies deploy;
# its permission includes Strategic Reserves without a price/cost calculation.
# An embarked source can use this unmeasured army ability (01.02.04).
fun orks_kaptin_source(Board board, Bool owner) -> SourceInstance:
    let result : SourceInstance
    let bank : SourceBank
    for b in range(3):
        bank.value = b
        for slot in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, slot)
            if unit.owned_by_player1 != owner:
                continue
            for member in range(unit.models.size()):
                if model_has_orks_enhancement(unit, unit[member], OrksEnhancement::kaptins_hat):
                    result = orks_option_usage(unit, unit[member], OrksEnhancement::kaptins_hat)
    return result

# A unit is redeployed at most once by this source, even if its reserve bank
# index changes. Battlefield slots remain stable through the round trip.
fun orks_kaptin_target(Board board, UnitID target, Bool owner, Bool[MAX_UNIT_COUNT] selected) -> Bool:
    return orks_support_actor(board, target, owner) and board[target].has_keyword(Keyword::orks) and board[target].has_keyword(Keyword::infantry) and !selected[target.get()] and board.reserve_units.has_capacity()

# Accepted prebattle redeploy keeps equipment/identities and actual source
# permissions; terrain/whole-base placement uses the usual setup kernel.
act orks_kaptin_redeploy(ctx Board board) -> OrksKaptinRedeploy:
    frm owner = board.starting_player
    frm controllers : BInt<0, 3>
    while controllers.value < 2:
        board.current_decision_maker = owner
        frm instance : SourceInstance
        instance = orks_kaptin_source(board, owner)
        if instance.rule.value != 0 and source_usage_available(board, instance):
            actions:
                act decline_kaptins_hat()
                act kaptins_hat()
                    commit_source_usage(board, instance)
                    frm selected : Bool[MAX_UNIT_COUNT]
                    frm count : BInt<0, 4>
                    while count.value < 3:
                        actions:
                            act finish_kaptin_redeploy()
                                break
                            act choose_kaptin_redeploy_unit(frm UnitID target) {orks_kaptin_target(board, target, owner, selected)}
                                selected[target.get()] = true
                                count = count + 1
                                frm original : Unit
                                original = board[target]
                                let moved = reposition_unit(board, target)
                                assert(moved, "redeploy unit could not leave battlefield")
                                frm reserve : UnitID
                                reserve = board.reserve_units.size() - 1
                                actions:
                                    act kaptin_strategic_reserves()
                                        # Prebattle selection is not a reactive
                                        # reposition exempt from reserve deadline.
                                        board.reserve_units[reserve.get()].history.repositioned = false
                                    act place_kaptin_redeploy(BoardPosition position) {setup_at_valid(board, board.reserve_units[reserve.get()], position, MovementKind::normal, board.reserve_units[reserve.get()].all_have_ability(AbilityKind::infiltrators))}
                                        enter_from_reserves(board, reserve, position, MovementKind::normal)
                                        board[target].history = original.history
        owner = !owner
        controllers = controllers + 1
    board.current_decision_maker = board.starting_player

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

# Watchin' is an own-unit, once-per-army ability in every bank; only living
# bearers confer it. Source: Da Boss is Watchin'; appendix01.02.04.
fun orks_watchin_available(Board board, Unit unit) -> Bool:
    if unit.owned_by_player1 != board.current_player or !(board.timing.phase == BattlePhase::movement) or !has_live_model(unit):
        return false
    for member in range(unit.models.size()):
        ref model = unit[member]
        if model.is_alive() and model_has_orks_enhancement(unit, model, OrksEnhancement::da_boss_is_watchin) and source_usage_available(board, orks_option_usage(unit, model, OrksEnhancement::da_boss_is_watchin)):
            return true
    return false

# Commit the same army token and persisting grant irrespective of bank
# (Da Boss is Watchin'; appendix01.02.02/01.02.04).
fun commit_orks_watchin(Board board, Unit unit):
    for bearer in range(unit.models.size()):
        if unit[bearer].is_alive() and model_has_orks_enhancement(unit, unit[bearer], OrksEnhancement::da_boss_is_watchin):
            commit_source_usage(board, orks_option_usage(unit, unit[bearer], OrksEnhancement::da_boss_is_watchin))
    grant_orks_own_payload(board, unit, 200 + OrksEnhancement::da_boss_is_watchin.value, riled_up_grant(), SourceDuration::next_own_turn)

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

# Reviving an embarked model returns it to that unit if capacity permits;
# lack of capacity destroys it with NO further triggers (01.02.03). A reserve
# return is offboard too: never use last battlefield coordinates for placement.
fun orks_return_capacity(Board board, Unit unit, Model model) -> Bool:
    if unit.embarked_transport.value == 0:
        return true
    let carrier = find_passenger_carrier(board, unit.embarked_transport)
    if !carrier.found:
        return false
    let bank = SourceBank::battlefield
    if carrier.reserve:
        bank = SourceBank::reserves
    ref transport = source_bank_unit(board, bank, carrier.unit.get())[carrier.model]
    if !unit.models.has_capacity():
        return false
    let candidate : Unit
    candidate = unit
    candidate.models.append(model)
    return passenger_model_permitted(transport, model) and passenger_space_used(board, unit.embarked_transport) - orks_passenger_space(unit) + orks_passenger_space(candidate) <= transport.transport_capacity.value

# Reserve/passenger phase-end selection delegates to the SAME Surly rule as
# battlefield timing windows. This adapter only iterates banks (01.02.04);
# retained deaths have already resolved through the common damage engine.
act resolve_orks_bank_returns(ctx Board board) -> OrksBankReturns:
    frm previous_owner = board.current_decision_maker
    frm owner = board.current_player
    frm controllers : BInt<0, 3>
    while controllers.value < 2:
        board.current_decision_maker = owner
        frm bank : SourceBank
        frm bank_count : BInt<0, 3>
        bank_count = 0
        while bank_count.value < 2:
            bank.value = bank_count.value + 1
            frm slot : UnitIterator
            slot = 0
            while slot.value < source_bank_size(board, bank):
                if source_bank_unit(board, bank, slot.value).owned_by_player1 == owner:
                    frm archive : ModelIterator
                    archive = 0
                    while archive.value < source_bank_unit(board, bank, slot.value).destroyed_models.value.size():
                        frm revive : ModelID
                        revive = archive.value
                        if orks_surly_casualty_valid(board, source_bank_unit(board, bank, slot.value), revive):
                            frm source : UnitID
                            source = slot.value
                            board.shared_actions.return_orks_surly = return_orks_surly(board, source_bank_unit(board, bank, slot.value), bank, source, revive)
                            subaction*(board, source_bank_unit(board, bank, slot.value)) board.shared_actions.return_orks_surly
                        else:
                            archive = archive + 1
                slot = slot + 1
            bank_count = bank_count + 1
        owner = !owner
        controllers = controllers + 1
    board.current_decision_maker = previous_owner

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

# Dreadherder can be used before other units shoot; selecting its bearer to
# shoot is not required and must not consume the bearer's shooting opportunity.
fun orks_dreadherder_available(Board board, UnitID source) -> Bool:
    if !orks_support_actor(board, source, board.current_player) or !(board.timing.phase == BattlePhase::shooting):
        return false
    let usage : SourceInstance
    usage.rule = 200 + OrksEnhancement::dreadherder.value
    usage.owner = board[source].owned_by_player1
    usage.source_unit = board[source].identity
    usage.use_scope = SourceUseScope::unit
    usage.limits.phase = 1
    if !source_usage_available(board, usage):
        return false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_dreadherder_target(board, source, target):
            return true
    return false
