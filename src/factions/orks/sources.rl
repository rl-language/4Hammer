import board
import source_effects

# Permanent Follow Me Ladz/Ardboyz/Mekwaaagh! grants reuse the established
# live-source machinery; bodyguard upgrades use their original component.
fun register_orks_option_passives(Board board):
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            for bearer in range(unit.models.size()):
                ref model = unit[bearer]
                let option = model.orks_enhancement
                if !model.is_alive() or (option.value != OrksEnhancement::follow_me_ladz.value and option.value != OrksEnhancement::ardboyz.value and option.value != OrksEnhancement::mekwaaagh_mastermind.value):
                    continue
                let instance : SourceInstance
                instance.rule = 200 + option.value
                instance.label.value = SourceLabel::permanent_orks_option
                instance.owner = unit.owned_by_player1
                instance.source_unit = model.original_unit
                instance.source_model = model.identity
                if option.value == OrksEnhancement::ardboyz.value:
                    instance.source_unit = model.orks_upgrade_origin
                    instance.source_model = 0
                instance.own_unit_passive = true
                instance.offboard_allowed = true
                instance.requires_live_source = true
                instance.duration = SourceDuration::battle
                instance.grant = riled_up_grant()
                if option.value == OrksEnhancement::follow_me_ladz.value:
                    instance.grant = characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 2)
                if option.value == OrksEnhancement::ardboyz.value:
                    instance.grant = characteristic_modifier(ModifiedCharacteristic::save, ModifierOperation::replace, 4)
                if !orks_unit_source_registered(board, instance):
                    let handle = register_source_instance(board, instance)

# Save integrity covers the new bounded activation ledger and modifier stacks;
# these are implementation invariants, not additional tabletop restrictions.
fun valid_orks_detachment_foundations(Board board) -> Bool:
    if board.orks_attack_serial.value < 0 or board.orks_attack_serial.value >= 1025 or board.orks_reaction_target.value < 0 or board.orks_reaction_target.value > board.next_identity.value:
        return false
    if !valid_rule_modifiers(board.attack_info.orks_hit_modifiers) or !valid_rule_modifiers(board.attack_info.orks_wound_modifiers):
        return false
    for record in range(board.orks_attack_records.size()):
        ref entry = board.orks_attack_records[record]
        if entry.target.value <= 0 or entry.target.value > board.next_identity.value or entry.successful_hits.value < 0 or entry.successful_hits.value >= MAX_COMBAT_COUNTER or entry.wounds_lost.value < 0 or entry.wounds_lost.value >= MAX_COMBAT_COUNTER:
            return false
        # Squig Barrage's weapon-specific hits are a subset of all hits;
        # malformed saves cannot fabricate post-shot triggers (Squigbuggies).
        if entry.squig_launcha_hits.value < 0 or entry.squig_launcha_hits.value > entry.successful_hits.value:
            return false
        for previous in range(record):
            if board.orks_attack_records[previous].target == entry.target:
                return false
    return true

# Custom windows are offered only in the right bank with a valid target;
# mandatory bombs with no legal target never strand phase completion.
# Source cards' explicit windows; core timing pp28-30 and reserve p69.
fun orks_source_event_available(Board board, SourceInstance instance, SourceEvent event) -> Bool:
    if instance.rule.value == ORKS_MEK_REPAIR_RULE:
        let conditional_target : UnitID
        let conditional_model : ModelID
        for conditional_unit_index in range(board.units.size()):
            conditional_target = conditional_unit_index
            for conditional_member in range(board[conditional_unit_index].models.size()):
                conditional_model = conditional_member
                if orks_mek_target_valid(board, instance, conditional_target, conditional_model):
                    return true
        return false
    if instance.rule.value == ORKS_SHOKK_BOOST_RULE:
        let conditional_location = locate_source(board, instance.source_unit, instance.source_model)
        return conditional_location.found and conditional_location.bank.value == SourceBank::battlefield.value and board[conditional_location.unit.value].shokk_boosta_move and event.movement == MovementKind::advance
    if instance.rule.value < 140 or instance.rule.value > 147:
        return true
    let location = locate_source(board, instance.source_unit, invalid_entity_identity())
    if !location.found:
        return false
    ref unit = source_bank_unit(board, location.bank, location.unit.value)
    # Registration survives attachment/bank changes; live unit membership must
    # still confer this ability. A surviving bodyguard cannot replace a slain
    # Snikrot/Wartrike (core p67; these cards' conferring abilities).
    let required = AbilityKind::boom_bomb
    if instance.rule.value == 141:
        required = AbilityKind::burna_bomb
    if instance.rule.value == 142:
        required = AbilityKind::kunnin_infiltrator
    if instance.rule.value == 143:
        required = AbilityKind::aerial_manoover
    if instance.rule.value == 144:
        required = AbilityKind::deff_from_shadows
    if instance.rule.value == 145:
        required = AbilityKind::full_throttle
    if instance.rule.value == 147:
        required = AbilityKind::get_back_in_da_race
    if !unit.has_ability(required):
        return false
    if instance.rule.value == 145:
        return true
    if instance.rule.value == 144:
        return location.bank.value == SourceBank::reserves.value and unit.history.strategic_reserve and battlefield_entry_available(board, unit)
    if location.bank.value != SourceBank::battlefield.value or unit.off_battlefield or !has_live_model(unit):
        return false
    if instance.rule.value == 142 or instance.rule.value == 143:
        return board.reserve_units.has_capacity() and !board.is_in_melee(unit) and (instance.rule.value == 143 or unit_is_hidden(board, unit))
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if instance.rule.value == 147:
            if orks_race_target(board, unit, target):
                return true
        else:
            let source : UnitID
            source = location.unit.value
            if orks_aircraft_bomb_target(board, source, target, instance.rule.value == 141):
                return true
    return false

# One timing-window owner handles all six window sources sequentially.
# Bomb damage uses normal mortal/FNP/destruction; ingress uses existing setup.
# Sources: Orks/{Blitza-bommer,Burna-bommer,Boss-Snikrot,Deffkoptas,Wazdakka-Gutsmek}.
act orks_datasheet_window(ctx Board board, frm SourceInstance instance) -> OrksDatasheetWindow:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = instance.owner
    frm location = locate_source(board, instance.source_unit, invalid_entity_identity())
    frm source : UnitID
    source = location.unit.value
    commit_source_usage(board, instance)
    if instance.rule.value == 140 or instance.rule.value == 141:
        frm burna = instance.rule.value == 141
        act choose_aircraft_bomb_target(frm UnitID target) {orks_aircraft_bomb_target(board, source, target, burna)}
        act roll(Dice bomb_result)
        frm bomb_face = bomb_result
        frm amount : CombatCounter
        amount = 3
        if burna or bomb_face.value <= 3 or bomb_face == 6:
            if !burna or bomb_face.value >= 2:
                board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
                subaction* board.shared_actions.evaluate_random_stat
                amount = board.shared_actions.evaluate_random_stat.result.value
                if !burna and bomb_face == 6:
                    amount = amount + 3
            else:
                amount = 0
        if burna and bomb_face.value >= 2:
            # Separate the lasting grant from rule141's consumed window token.
            # Burna-bommer/Burna Bomb: one trigger, not a second ability use.
            grant_orks_effect(board, source, target, 176, OrksEffectKind::burna_mark, 1, SourceDuration::end_next_turn, invalid_entity_identity())
        board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, target, source, true, amount)
        subaction*(board) board.shared_actions.resolve_mortal_wounds
    if instance.rule.value == 142 or instance.rule.value == 143:
        assert(reposition_unit(board, source), "reposition eligibility changed")
    if instance.rule.value == 144:
        actions:
            act cancel_shadows_ingress()
            act shadows_ingress_at(BoardPosition position) {battlefield_entry_available(board, board.reserve_units[source.get()]), setup_at_valid(board, board.reserve_units[source.get()], position, MovementKind::ingress, false)}
                enter_from_reserves(board, source, position, MovementKind::ingress)
    if instance.rule.value == 145:
        act choose_shokka_engine(frm OrksEngine engine)
        frm payload : OrksEffectGrant
        payload.kind = OrksEffectKind::turbo_engine
        if engine.value == OrksEngine::shokk.value:
            payload.kind = OrksEffectKind::shokk_engine
        if engine.value == OrksEngine::pulse.value:
            payload.kind = OrksEffectKind::pulse_engine
        grant_orks_own_payload(board, source_bank_unit(board, location.bank, location.unit.value), 170 + engine.value, payload, SourceDuration::next_own_command)
        if engine.value == OrksEngine::shokk.value and location.bank.value == SourceBank::battlefield.value and !board.is_in_melee(board[source]) and board.reserve_units.has_capacity():
            act use_shokk_attack_engine(Bool shokk)
            if shokk:
                assert(reposition_unit(board, source), "Shokk Attack Engine requires reserve capacity")
    board.current_decision_maker = previous_owner

# Duplicate registration must not reset usage or create multiple tokens when
# a model transfers banks, attaches, or returns (core pp66/88; source limits).
fun orks_unit_source_registered(Board board, SourceInstance instance) -> Bool:
    let found = false
    for index in range(board.source_instances.size()):
        ref existing = board.source_instances[index]
        found = found or (existing.rule == instance.rule and existing.source_unit == instance.source_unit and existing.source_model == instance.source_model and existing.trigger.value == instance.trigger.value)
    return found

# Register explicit ability metadata after identities exist; attachment
# provenance also allows registration after formation or a bank transfer.
# Keep Huntin' has two windows sharing one army-round counter. Bomb Squig is
# one source per original unit, not one token per Boy or attached constituent.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss
# https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
fun register_orks_datasheet_sources(Board board):
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            for model_index in range(unit.models.size()):
                ref model = unit[model_index]
                if !model.is_alive():
                    continue
                if model.has_ability(AbilityKind::keep_huntin) or model.has_ability(AbilityKind::intimidating_motivation):
                    for window_index in range(4):
                        if window_index < 2 and !model.has_ability(AbilityKind::keep_huntin) or window_index >= 2 and !model.has_ability(AbilityKind::intimidating_motivation):
                            continue
                        let instance : SourceInstance
                        instance.rule = ORKS_KEEP_HUNTIN_RULE
                        instance.label.value = SourceLabel::keep_huntin
                        if window_index >= 2:
                            instance.rule = ORKS_INTIMIDATING_RULE
                            instance.label.value = SourceLabel::intimidating_motivation
                        instance.source_unit = model.original_unit
                        instance.source_model = model.identity
                        instance.owner = unit.owned_by_player1
                        instance.phase = BattlePhase::movement
                        instance.own_turn_only = true
                        instance.trigger = SourceEventKind::move_start
                        if window_index % 2 == 1:
                            instance.trigger = SourceEventKind::move_end
                        instance.optional = true
                        instance.use_scope = SourceUseScope::army
                        instance.limits.round = 1
                        instance.duration = SourceDuration::next_own_turn
                        instance.grant = riled_up_grant()
                        for cargo_source in range(board.source_instances.size()):
                            ref dependency = board.source_instances[cargo_source]
                            if dependency.source_model == model.identity and (dependency.rule.value == 462 and window_index < 2 or dependency.rule.value == 463 and window_index >= 2):
                                instance.required_embarked_model = dependency.required_embarked_model
                                instance.required_carrier_model = dependency.required_carrier_model
                        if !orks_unit_source_registered(board, instance):
                            let source = register_source_instance(board, instance)
                        else:
                            for known in range(board.source_instances.size()):
                                ref registered = board.source_instances[known]
                                if registered.rule.value == instance.rule.value and registered.source_model == instance.source_model and registered.trigger.value == instance.trigger.value:
                                    registered.required_embarked_model = instance.required_embarked_model
                                    registered.required_carrier_model = instance.required_carrier_model
                if model.has_ability(AbilityKind::bomb_squig):
                    let instance : SourceInstance
                    instance.rule = ORKS_BOMB_SQUIG_RULE
                    instance.label.value = SourceLabel::bomb_squig
                    instance.source_unit = model.original_unit
                    instance.owner = unit.owned_by_player1
                    instance.phase = BattlePhase::movement
                    instance.own_turn_only = true
                    instance.trigger = SourceEventKind::move_end
                    instance.restrict_movement = true
                    instance.movement = MovementKind::normal
                    instance.optional = true
                    instance.use_scope = SourceUseScope::unit
                    instance.limits.battle = 1
                    # Orks/{Breaka-Boyz,Tankbustas}/Bomb Squigs:
                    # two tokens and a turn limit, unlike Squighog Boyz.
                    if model_matches_datasheet(model, OrksDatasheet::breaka_boyz) or model_matches_datasheet(model, OrksDatasheet::tankbustas):
                        instance.limits.battle = 2
                        instance.limits.turn = 1
                    if !orks_unit_source_registered(board, instance):
                        let source = register_source_instance(board, instance)

    let bearer_bank : SourceBank
    for bearer_bank_index in range(3):
        bearer_bank.value = bearer_bank_index
        for bearer_unit_index in range(source_bank_size(board, bearer_bank)):
            ref bearer_unit = source_bank_unit(board, bearer_bank, bearer_unit_index)
            for bearer_member_index in range(bearer_unit.models.size()):
                ref bearer_model = bearer_unit[bearer_member_index]
                if !bearer_model.is_alive():
                    continue
                for bearer_entry in range(6):
                    let bearer_available = bearer_entry == 0 and bearer_model.has_ability(AbilityKind::crude_surgery) or bearer_entry == 1 and bearer_model.has_ability(AbilityKind::fix_dat_armour_up) or bearer_entry == 2 and bearer_model.has_ability(AbilityKind::push_dat_bit_back_in) or bearer_entry == 3 and bearer_model.has_ability(AbilityKind::clever_know_wotz) or bearer_entry == 4 and bearer_model.has_ability(AbilityKind::thievin_scavengers) or bearer_entry == 5 and bearer_model.has_ability(AbilityKind::shokk_boosta)
                    if !bearer_available:
                        continue
                    let bearer_instance : SourceInstance
                    bearer_instance.rule = ORKS_SURGERY_RULE + bearer_entry
                    bearer_instance.source_unit = bearer_model.original_unit
                    bearer_instance.source_model = bearer_model.identity
                    bearer_instance.owner = bearer_unit.owned_by_player1
                    bearer_instance.own_turn_only = true
                    bearer_instance.use_scope = SourceUseScope::unit
                    bearer_instance.grant = riled_up_grant()
                    bearer_instance.trigger = SourceEventKind::timing_window
                    bearer_instance.window = TimingWindow::command_abilities
                    bearer_instance.phase = BattlePhase::command
                    bearer_instance.offboard_allowed = true
                    bearer_instance.optional = bearer_entry != 0
                    bearer_instance.limits.phase = 1
                    bearer_instance.label.value = SourceLabel::crude_surgery
                    if bearer_entry == 1:
                        bearer_instance.label.value = SourceLabel::fix_dat_armour_up
                        bearer_instance.limits.battle = 1
                    if bearer_entry == 2:
                        bearer_instance.label.value = SourceLabel::push_dat_bit_back_in
                        bearer_instance.limits.battle = 1
                    if bearer_entry == 3:
                        bearer_instance.label.value = SourceLabel::clever_know_wotz
                        bearer_instance.offboard_allowed = false
                        bearer_instance.trigger = SourceEventKind::move_start
                        bearer_instance.window = TimingWindow::none
                        bearer_instance.phase = BattlePhase::movement
                        bearer_instance.limits.phase = 0
                    if bearer_entry == 4:
                        bearer_instance.label.value = SourceLabel::thievin_scavengers
                        bearer_instance.rule = ORKS_SCAVENGERS_RULE
                        bearer_instance.source_model = 0
                        bearer_instance.offboard_allowed = false
                        bearer_instance.window = TimingWindow::movement_end
                        bearer_instance.phase = BattlePhase::movement
                        bearer_instance.optional = false
                    if bearer_entry == 5:
                        bearer_instance.label.value = SourceLabel::shokk_boosta_hazards
                        bearer_instance.rule = ORKS_SHOKK_BOOST_RULE
                        bearer_instance.offboard_allowed = false
                        bearer_instance.trigger = SourceEventKind::move_end
                        bearer_instance.restrict_movement = true
                        bearer_instance.movement = MovementKind::advance
                        bearer_instance.phase = BattlePhase::movement
                        bearer_instance.optional = false
                        bearer_instance.limits.phase = 0
                    if !orks_unit_source_registered(board, bearer_instance):
                        let bearer_handle = register_source_instance(board, bearer_instance)
                    if bearer_entry == 3:
                        bearer_instance.trigger = SourceEventKind::move_end
                        if !orks_unit_source_registered(board, bearer_instance):
                            let bearer_end_handle = register_source_instance(board, bearer_instance)
    let window_bank : SourceBank
    for window_bank_index in range(3):
        window_bank.value = window_bank_index
        for window_slot in range(source_bank_size(board, window_bank)):
            ref window_unit = source_bank_unit(board, window_bank, window_slot)
            for window_entry in range(6):
                let window_ability = AbilityKind::boom_bomb
                if window_entry == 1:
                    window_ability = AbilityKind::burna_bomb
                if window_entry == 2:
                    window_ability = AbilityKind::kunnin_infiltrator
                if window_entry == 3:
                    window_ability = AbilityKind::aerial_manoover
                if window_entry == 4:
                    window_ability = AbilityKind::deff_from_shadows
                if window_entry == 5:
                    window_ability = AbilityKind::full_throttle
                if !window_unit.has_ability(window_ability):
                    continue
                let window_instance = make_source_usage(window_unit.owned_by_player1, 140 + window_entry, window_unit.identity, invalid_entity_identity(), SourceUseScope::unit, source_use_limits(1, 0, 0, 0))
                window_instance.trigger = SourceEventKind::timing_window
                window_instance.window = TimingWindow::fight_end
                window_instance.phase = BattlePhase::fight
                window_instance.opposing_turn_only = true
                window_instance.optional = window_entry >= 2
                window_instance.grant = riled_up_grant()
                window_instance.label.value = SourceLabel::boom_bomb
                if window_entry == 1:
                    window_instance.label.value = SourceLabel::burna_bomb
                if window_entry == 2:
                    window_instance.label.value = SourceLabel::kunnin_infiltrator
                if window_entry == 3:
                    window_instance.label.value = SourceLabel::aerial_manoover
                if window_entry == 4:
                    window_instance.label.value = SourceLabel::deff_from_the_shadows
                if window_entry == 5:
                    window_instance.label.value = SourceLabel::full_throttle
                if window_entry == 4:
                    window_instance.window = TimingWindow::movement_end
                    window_instance.phase = BattlePhase::movement
                    window_instance.offboard_allowed = true
                if window_entry == 5:
                    window_instance.window = TimingWindow::command_abilities
                    window_instance.phase = BattlePhase::command
                    window_instance.opposing_turn_only = false
                    window_instance.own_turn_only = true
                    window_instance.optional = false
                    window_instance.offboard_allowed = true
                if !orks_unit_source_registered(board, window_instance):
                    let window_handle = register_source_instance(board, window_instance)
            if window_unit.has_ability(AbilityKind::get_back_in_da_race):
                for window_entry in range(2):
                    let window_instance = make_source_usage(window_unit.owned_by_player1, 147, window_unit.identity, invalid_entity_identity(), SourceUseScope::army, source_use_limits(1, 0, 0, 0))
                    window_instance.limits.phase = 0
                    window_instance.limits.round = 1
                    window_instance.trigger = SourceEventKind::move_start
                    if window_entry == 1:
                        window_instance.trigger = SourceEventKind::move_end
                    window_instance.phase = BattlePhase::movement
                    window_instance.own_turn_only = true
                    window_instance.optional = true
                    window_instance.duration = SourceDuration::next_own_turn
                    window_instance.grant = riled_up_grant()
                    window_instance.label.value = SourceLabel::get_back_in_da_race
                    if !orks_unit_source_registered(board, window_instance):
                        let window_handle = register_source_instance(board, window_instance)
