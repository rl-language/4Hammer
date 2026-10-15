import orks_remaining_data
import orks_elite_rules

# Non-stacking live aura: same named ability contributes once. The source
# unit itself qualifies; offboard units cannot measure to others (01.02.04).
# https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
fun orks_prophet_aura(Board board, Unit unit) -> Bool:
    if unit.off_battlefield or !unit.has_keyword(Keyword::orks):
        return false
    for source in range(board.units.size()):
        ref actor = board[source]
        if !actor.off_battlefield and actor.owned_by_player1 == unit.owned_by_player1 and actor.has_ability(AbilityKind::prophet_waaagh) and live_unit_distance(actor, unit) <= 6.0:
            return true
    return false

# Each Wartrakk model needs a qualifying neighbouring Speed Freeks unit;
# Ghaz requires ANOTHER friendly Infantry unit. Neither can use reserve ranges.
# Sources: Orks/Wartrakks Speednob Support; Ghazghkull-Thraka Da Grand Warlord's Ladz.
fun orks_remaining_lone_operative(Board board, Unit unit) -> Bool:
    if unit.off_battlefield or !has_live_model(unit):
        return false
    if unit.has_ability(AbilityKind::grand_warlords_ladz):
        for ally in range(board.units.size()):
            ref nearby = board[ally]
            if nearby.identity != unit.identity and !nearby.off_battlefield and has_live_model(nearby) and nearby.owned_by_player1 == unit.owned_by_player1 and nearby.has_keyword(Keyword::orks) and nearby.has_keyword(Keyword::infantry) and live_unit_distance(unit, nearby) <= 3.0:
                return true
    if unit.has_ability(AbilityKind::speednob_support):
        let all_supported = true
        for member_index in range(unit.models.size()):
            if !unit[member_index].is_alive():
                continue
            let supported = false
            for ally in range(board.units.size()):
                ref nearby = board[ally]
                supported = supported or (!nearby.off_battlefield and has_live_model(nearby) and nearby.owned_by_player1 == unit.owned_by_player1 and nearby.has_keyword(Keyword::speed_freeks) and !orks_type(nearby, OrksDatasheet::wartrakks) and live_distance_to_model(nearby, unit[member_index]) <= 3.0)
            all_supported = all_supported and supported
        return all_supported
    return false

# Unit-wide intrinsic/granted rules are read at declaration. Psychic Warpath
# does not grant the same bonus to ranged attacks (source cards;04.01.03).
# https://wahapedia.ru/wh40k11ed/factions/orks/{Nazdreg,Kill-Rig,Weirdboy}
fun append_orks_remaining_weapon_rules(Board board, Unit unit, Weapon selected, WeaponAbilitySet result):
    if selected.range() > 0 and unit.has_ability(AbilityKind::nazdregs_know_wotz):
        result.append(weapon_rule(WeaponRuleKind::ignore_cover))
    if selected.range() == 0:
        if unit_orks_effect(board, unit, OrksEffectKind::psychic_warpath) > 0:
            result.append(weapon_rule(WeaponRuleKind::letal_hits))
        if unit_orks_effect(board, unit, OrksEffectKind::psychic_warpath) > 0 or unit_orks_effect(board, unit, OrksEffectKind::weirdboy_warpath) > 0:
            result.append(weapon_rule(WeaponRuleKind::psychic))

# Butchery counts actual embarked models, not transport seats, caps at+22,
# and changes only the Butcha Boyz weapon (not its two Extra Attacks weapons).
# https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
fun append_orks_remaining_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    if kind.value == ModifiedCharacteristic::attacks.value and board[source].has_ability(AbilityKind::fully_loaded_butchery) and declaration.weapon_name.value == NamedWeapon::butcha_boyz.value:
        let count = 0
        for member_index in range(board[source].models.size()):
            if board[source][member_index].is_alive():
                count = count + embarked_models_for_psyker(board, board[source][member_index].identity)
        result.append(rule_modifier(ModifierOperation::add, min(22, count * 2)))

# Target-dependent modifiers keep their original operations and separate hit
# contributions so the standard cap/ignore/grouping machinery still applies.
# Sources: Orks/{Battlewagon,Dakkajet,Deffkoptas,Ghazghkull-Thraka,Gorkanaut,
# Gunwagon,Morkanaut,Kommandos,Wazbom-Blastajet,Mek-Gunz,Wartrakks,Kill-Rig}.
fun append_orks_remaining_attack_effects(Board board, UnitID source, UnitID target, DeclaredWeapon declaration, AttackSequenceInfo info):
    ref unit = board[source]
    ref victim = board[target]
    let ranged = declaration.weapon.range() > 0
    let own_shooting = ranged and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 == board.current_player
    let monster_vehicle = victim.has_keyword(Keyword::monster) or victim.has_keyword(Keyword::vehicle)
    if ranged and victim.has_ability(AbilityKind::mobile_fortress):
        info.damage_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    if own_shooting and unit.has_ability(AbilityKind::strafing_run) and !victim.has_keyword(Keyword::fly):
        info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if own_shooting and unit.has_ability(AbilityKind::deff_from_above) and unit.history.has_ingressed and unit.history.ingress_turn == board.turn_serial.value + 1:
        info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if own_shooting and (unit.has_ability(AbilityKind::mobile_arsenal) or unit.has_ability(AbilityKind::big_an_shooty)) or !ranged and unit.has_ability(AbilityKind::big_an_stompy):
        info.reroll1_hits = true
    if own_shooting and monster_vehicle and unit.has_ability(AbilityKind::weak_spot):
        info.orks_wound_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if !ranged and orks_prophet_aura(board, unit):
        info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
        info.orks_wound_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if unit.has_ability(AbilityKind::nowhere_to_hide) and unit_is_hidden(board, victim):
        info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if unit_orks_effect(board, unit, OrksEffectKind::covered_squigs) > 0:
        info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    if unit_orks_effect(board, victim, OrksEffectKind::pulse_defence) > 0:
        info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    if ranged and orks_engaged_only_fortifications(board, victim) and info.shooting_kind.value != ShootingKind::close_quarters.value:
        info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    if ranged and unit_orks_effect(board, victim, OrksEffectKind::burna_mark) > 0:
        info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::ignore_cover))
    if unit_orks_effect(board, victim, OrksEffectKind::busted) > 0 and unit.has_keyword(Keyword::speed_freeks) and unit.owned_by_player1 != victim.owned_by_player1:
        info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::letal_hits))
    if unit_orks_effect(board, unit, OrksEffectKind::beastscent) > 0 and monster_vehicle:
        info.orks_wound_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if !ranged and unit_orks_effect(board, unit, OrksEffectKind::weirdboy_warpath) > 0:
        info.reroll1_wounds = true

# Hidden is a whole-unit condition for Kommandos/Snikrot. A single exposed
# living model fails it; retained corpses are not extra required members.
# Sources: Orks/Kommandos Nowhere to Hide; Boss-Snikrot Kunnin' Infiltrator.
fun unit_is_hidden(Board board, Unit unit) -> Bool:
    if unit.off_battlefield or !has_live_model(unit):
        return false
    for member_index in range(unit.models.size()):
        if unit[member_index].is_alive() and !model_is_hidden(board, unit, unit[member_index]):
            return false
    return true

# Fortification's explicit ranged-target exception applies only to an enemy
# engaged exclusively with Fortification units, with a live conferring bunker.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
fun orks_engaged_only_fortifications(Board board, Unit unit) -> Bool:
    let found = false
    for enemy in range(board.units.size()):
        ref foe = board[enemy]
        if foe.owned_by_player1 != unit.owned_by_player1 and !foe.off_battlefield and has_live_model(foe) and unit.is_engaged_with(foe):
            if !foe.has_keyword(Keyword::fortification):
                return false
            found = found or foe.has_ability(AbilityKind::fortification_rules)
    return found

# User-approved abstraction: a circular bunker base crossing the centre sight
# segment gives partial obscuration. Exact hull silhouettes remain deferred.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka (Ramshackle Cover).
fun orks_ramshackle_obscures(Board board, Model observer, Model target) -> Bool:
    for bunker in range(board.units.size()):
        ref source = board[bunker]
        if source.off_battlefield or !source.has_ability(AbilityKind::ramshackle_cover):
            continue
        for member_index in range(source.models.size()):
            ref obstacle = source[member_index]
            if !obstacle.is_alive() or obstacle.identity == observer.identity or obstacle.identity == target.identity:
                continue
            let radius = obstacle.base_radius_micrometres()
            if point_segment_distance_squared(float(obstacle.position.x.value * MICROMETRES_PER_INCH), float(obstacle.position.y.value * MICROMETRES_PER_INCH), float(observer.position.x.value * MICROMETRES_PER_INCH), float(observer.position.y.value * MICROMETRES_PER_INCH), float(target.position.x.value * MICROMETRES_PER_INCH), float(target.position.y.value * MICROMETRES_PER_INCH)) <= radius * radius:
                return true
    return false

# Wobbled is on the attacking unit; benefit of cover belongs to its targets.
# https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz (Bubblechukka).
fun orks_wobbled_observer(Board board, Model observer) -> Bool:
    for unit_index in range(board.units.size()):
        if board[unit_index].find_model(observer.identity) >= 0:
            return unit_orks_effect(board, board[unit_index], OrksEffectKind::wobbled) > 0
    return false

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

# Tramplasquig Charge changes the payable CP before affordability and use
# bookkeeping; it does not refund spent CP or bypass per-phase limits.
# https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
fun orks_datasheet_stratagem_cost(Stratagem card, Unit unit) -> Int:
    return max(0, card.cost() - int(card == Stratagem::crushing_impact and unit.has_ability(AbilityKind::tramplasquig_charge)))

# Source codes140-176 are independent from detachment/enhancement codes.
# Unit identity preserves source usage across attachments and bank transfers.
# Sources: the current Orks25 remaining datasheets; appendix01.02.02/22.03.01.
fun orks_remaining_usage(Unit unit, Int rule, Bool army, Bool battle) -> SourceInstance:
    let usage : SourceInstance
    usage.rule = rule
    usage.owner = unit.owned_by_player1
    usage.source_unit = unit.identity
    usage.use_scope = SourceUseScope::unit
    usage.limits.phase = 1
    if army:
        usage.use_scope = SourceUseScope::army
    if battle:
        usage.limits.battle = 1
    return usage

# Register simultaneous printed windows with the existing player-chosen order,
# not a separate phase-end loop. Unit-wide sources are registered once even
# when every Kopta/Kommando carries the same intrinsic ability.
# Sources: Orks/{Blitza-bommer,Burna-bommer,Boss-Snikrot,Deffkoptas,Wazdakka-Gutsmek}.
fun register_orks_remaining_rules(Board board):
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for slot in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, slot)
            for entry in range(6):
                let ability = AbilityKind::boom_bomb
                if entry == 1:
                    ability = AbilityKind::burna_bomb
                if entry == 2:
                    ability = AbilityKind::kunnin_infiltrator
                if entry == 3:
                    ability = AbilityKind::aerial_manoover
                if entry == 4:
                    ability = AbilityKind::deff_from_shadows
                if entry == 5:
                    ability = AbilityKind::full_throttle
                if !unit.has_ability(ability):
                    continue
                let instance = orks_remaining_usage(unit, 140 + entry, false, false)
                instance.trigger = SourceEventKind::timing_window
                instance.window = TimingWindow::fight_end
                instance.phase = BattlePhase::fight
                instance.opposing_turn_only = true
                instance.optional = entry >= 2
                instance.grant = riled_up_grant()
                instance.name.value = "Boom Bomb"s
                if entry == 1:
                    instance.name.value = "Burna Bomb"s
                if entry == 2:
                    instance.name.value = "Kunnin Infiltrator"s
                if entry == 3:
                    instance.name.value = "Aerial Manoover"s
                if entry == 4:
                    instance.name.value = "Deff from the Shadows"s
                if entry == 5:
                    instance.name.value = "Full Throttle"s
                if entry == 4:
                    instance.window = TimingWindow::movement_end
                    instance.phase = BattlePhase::movement
                    instance.offboard_allowed = true
                if entry == 5:
                    instance.window = TimingWindow::command_abilities
                    instance.phase = BattlePhase::command
                    instance.opposing_turn_only = false
                    instance.own_turn_only = true
                    instance.optional = false
                    instance.offboard_allowed = true
                if !orks_unit_source_registered(board, instance):
                    let handle = register_source_instance(board, instance)
            if unit.has_ability(AbilityKind::get_back_in_da_race):
                for entry in range(2):
                    let instance = orks_remaining_usage(unit, 147, true, false)
                    instance.limits.phase = 0
                    instance.limits.round = 1
                    instance.trigger = SourceEventKind::move_start
                    if entry == 1:
                        instance.trigger = SourceEventKind::move_end
                    instance.phase = BattlePhase::movement
                    instance.own_turn_only = true
                    instance.optional = true
                    instance.duration = SourceDuration::next_own_turn
                    instance.grant = riled_up_grant()
                    instance.name.value = "Get Back in da Race!"s
                    if !orks_unit_source_registered(board, instance):
                        let handle = register_source_instance(board, instance)

# Bomb selection excludes Lone Operative even at close distance. Burna also
# excludes Monster/Vehicle; both use actual visibility and base distance.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Blitza-bommer,Burna-bommer}
fun orks_aircraft_bomb_target(Board board, UnitID source, UnitID target, Bool burna) -> Bool:
    if target.get() >= board.units.size() or board[target].off_battlefield or !has_live_model(board[target]) or board[target].owned_by_player1 == board[source].owned_by_player1 or orks_lone_operative(board, board[target]):
        return false
    if burna and (board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle)):
        return false
    return unit_visible_to_unit(board, board[source], board[target]) and live_unit_distance(board[source], board[target]) <= float(24 + 12 * int(burna))

# Custom windows are offered only in the right bank with a valid target;
# mandatory bombs with no legal target never strand phase completion.
# Source cards' explicit windows; core timing pp28-30 and reserve p69.
fun orks_remaining_event_available(Board board, SourceInstance instance, SourceEvent event) -> Bool:
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

# Race's grant includes cargo; source-unit range is battlefield only, whereas
# the cargo receives an army effect without an offboard measurement.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
fun orks_race_target(Board board, Unit source, UnitID target) -> Bool:
    return target.get() < board.units.size() and !board[target].off_battlefield and has_live_model(board[target]) and board[target].owned_by_player1 == source.owned_by_player1 and board[target].has_keyword(Keyword::speed_freeks) and live_unit_distance(source, board[target]) <= 6.0

# Race retains the shared per-army/round budget across both start/end windows.
# Cargo is selected by actual carrier identity, not TRANSPORT unit anchor.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
fun commit_orks_race(Board board, SourceInstance instance, UnitID target):
    let location = locate_source(board, instance.source_unit, invalid_entity_identity())
    assert(location.found and source_bank_unit(board, location.bank, location.unit.value).has_ability(AbilityKind::get_back_in_da_race) and orks_race_target(board, source_bank_unit(board, location.bank, location.unit.value), target), "invalid Race target")
    commit_source_usage(board, instance)
    board[target].battle_socked = false
    grant_orks_payload(board, target, target, 168, riled_up_grant(), SourceDuration::next_own_turn)
    for passenger in range(board.embarked_units.size()):
        ref cargo = board.embarked_units[passenger]
        if board[target].find_model(cargo.embarked_transport) >= 0:
            cargo.battle_socked = false
            grant_orks_own_payload(board, cargo, 168, riled_up_grant(), SourceDuration::next_own_turn)

# The selected engine lasts to next own Command, including offboard time.
# No point/CP expenditure or unstated bonus is introduced.
# https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek (Full Throttle).
enum OrksEngine:
    turbo
    shokk
    pulse

# One timing-window owner handles all six window sources sequentially.
# Bomb damage uses normal mortal/FNP/destruction; ingress uses existing setup.
# Sources: Orks/{Blitza-bommer,Burna-bommer,Boss-Snikrot,Deffkoptas,Wazdakka-Gutsmek}.
act orks_remaining_window(ctx Board board, frm SourceInstance instance) -> OrksRemainingWindow:
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

# Post-shot effects share one chosen-target action, with eligibility based on
# successful hits. Squig Launchas provenance is separate from other weapons.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Mek-Gunz,Wartrakks,Rukkatrukk-Squigbuggies}
fun orks_remaining_post_target(Board board, UnitID source, UnitID target) -> Bool:
    if !orks_barrage_target_valid(board, source, target):
        return false
    if board[source].has_ability(AbilityKind::squig_barrage):
        if board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle):
            return false
        for record in range(board.orks_attack_records.size()):
            if board.orks_attack_records[record].target == board[target].identity and board.orks_attack_records[record].squig_launcha_hits.value > 0:
                return true
        return false
    return true

# Each surviving Mek Gunz model must have the same ranged WEAPON NAME.
# Different profiles of one weapon are not different equipment (04.01.03).
# https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz (Madcap Artillery).
fun orks_matching_mek_guns(Unit unit) -> Int:
    let family = -1
    for member_index in range(unit.models.size()):
        if !unit[member_index].is_alive() or !model_matches_datasheet(unit[member_index], OrksDatasheet::mek_gunz):
            continue
        for slot in range(unit[member_index].weapons.size()):
            if unit[member_index].weapons[slot].range() == 0:
                continue
            if family >= 0 and family != unit[member_index].weapon_names[slot].value:
                return -1
            family = unit[member_index].weapon_names[slot].value
    return family

# The attack owns this frame; normal target choice precedes weapon Hazardous
# checks, preserving hit provenance when the firing model later dies (p81).
# Sources: Orks/Mek-Gunz Madcap Artillery; Wartrakks Bust 'Em; Squig Barrage.
act orks_remaining_post_shoot(ctx Board board, frm UnitID source) -> OrksRemainingPostShoot:
    if !has_live_model(board[source]) or !(board[source].has_ability(AbilityKind::madcap_artillery) or board[source].has_ability(AbilityKind::bust_em) or board[source].has_ability(AbilityKind::squig_barrage)):
        return
    if board[source].has_ability(AbilityKind::madcap_artillery) and orks_matching_mek_guns(board[source]) < 0:
        return
    frm available = false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        available = available or orks_remaining_post_target(board, source, target)
    if !available:
        return
    act choose_datasheet_hit_target(frm UnitID victim) {orks_remaining_post_target(board, source, victim)}
    if board[source].has_ability(AbilityKind::squig_barrage):
        grant_orks_effect(board, source, victim, 156, OrksEffectKind::covered_squigs, 1, SourceDuration::next_own_turn, invalid_entity_identity())
    if board[source].has_ability(AbilityKind::bust_em):
        grant_orks_effect(board, source, victim, 157, OrksEffectKind::busted, 1, SourceDuration::turn, invalid_entity_identity())
    if board[source].has_ability(AbilityKind::madcap_artillery):
        frm gun : WeaponNameCode
        gun = orks_matching_mek_guns(board[source])
        if gun.value == NamedWeapon::bubblechukka.value:
            grant_orks_effect(board, source, victim, 158, OrksEffectKind::wobbled, 1, SourceDuration::next_own_turn, invalid_entity_identity())
        if gun.value == NamedWeapon::traktor_kannon.value:
            grant_orks_effect(board, source, victim, 159, OrksEffectKind::grounded, 1, SourceDuration::next_own_turn, invalid_entity_identity())
        if gun.value == NamedWeapon::smasha_gun.value:
            grant_orks_payload(board, source, victim, 160, characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::subtract, 2), SourceDuration::next_own_turn)
        if gun.value == NamedWeapon::kustom_mega_kannon.value:
            grant_orks_payload(board, source, victim, 161, characteristic_modifier(ModifiedCharacteristic::leadership, ModifierOperation::add, 1), SourceDuration::next_own_turn)

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
    let spent = 0
    if unit.orks_psychic_usage.round_stamp.value == board.current_round.value + 1:
        spent = unit.orks_psychic_usage.spent.value
    let usage = orks_remaining_usage(unit, rule, rule == 151, false)
    if rule == 151:
        usage.limits.round = 1
    return spent < orks_psyker_level(unit) and source_usage_available(board, usage)

# Shared sequential roll frame; callers snapshot no results and apply their
# printed effect even after a1. No partial custom lifecycle is used.
# Orks/Weirdboy and Kill-Rig psychic rolls; Unstable Energies/22.03.01.
act orks_datasheet_psychic(ctx Board board, frm UnitID source, frm BInt<151, 163> rule) -> OrksDatasheetPsychic:
    assert(orks_datasheet_psychic_available(board, source, rule.value), "datasheet psychic unavailable")
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = board[source].owned_by_player1
    frm usage = orks_remaining_usage(board[source], rule.value, rule.value == 151, false)
    if rule.value == 151:
        usage.limits.round = 1
    commit_source_usage(board, usage)
    if board[source].orks_psychic_usage.round_stamp.value != board.current_round.value + 1:
        board[source].orks_psychic_usage.round_stamp = board.current_round.value + 1
        board[source].orks_psychic_usage.spent = 0
    board[source].orks_psychic_usage.spent = board[source].orks_psychic_usage.spent + 1
    board.current_roll = rerollable_dice_roll(board, unit_has_orks_enhancement(board[source], OrksEnhancement::warphead), false, false, board[source].owned_by_player1, source)
    subaction*(board) board.current_roll
    if board.current_roll.result == 1:
        board[source].battle_socked = true
        board.shared_actions.orks_became_shocked = orks_became_shocked(board, source)
        subaction*(board) board.shared_actions.orks_became_shocked
    board.current_decision_maker = previous_owner

# Warpath is chosen at SelectedFight BEFORE Pile In/Overrun. The shared roll
# spends the same level budget used by any other psychic ability this round.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Weirdboy,Kill-Rig}
act orks_datasheet_fight_selection(ctx Board board, frm UnitID source) -> OrksDatasheetFightSelection:
    frm rule : BInt<151, 163>
    rule = 152
    if board[source].has_ability(AbilityKind::kill_rig_warpath):
        rule = 153
    if orks_datasheet_psychic_available(board, source, rule.value):
        act use_datasheet_warpath(Bool warpath)
        if warpath:
            board.shared_actions.orks_datasheet_psychic = orks_datasheet_psychic(board, source, rule)
            subaction*(board) board.shared_actions.orks_datasheet_psychic
            frm kind = OrksEffectKind::weirdboy_warpath
            if rule.value == 153:
                kind = OrksEffectKind::psychic_warpath
            if has_live_model(board[source]):
                grant_orks_effect(board, source, source, rule.value, kind, 1, SourceDuration::phase, invalid_entity_identity())

# Free Movement abilities keep independent printed limits and eligibility.
# Target choice is checked BEFORE acceptance to prevent empty mandatory steps.
# Sources: Orks/{Ghazghkull-Thraka,Kommandos,Warbuggies,Weirdboy}.
enum OrksDatasheetMoveAbility:
    makari
    found_em
    drive_by_skorchin
    da_jump

# Named movement effects do not invent visibility for Found 'Em or range for
# Makari. Drive-by's explicit visible/non-Monster/Vehicle restrictions remain.
# Sources: Orks/Kommandos Found 'Em; Warbuggies Drive-by Skorchin'.
fun orks_datasheet_move_target(Board board, UnitID source, UnitID target, Bool skorch) -> Bool:
    if target.get() >= board.units.size() or board[target].off_battlefield or !has_live_model(board[target]) or board[target].owned_by_player1 == board[source].owned_by_player1:
        return false
    if skorch and (board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle) or !unit_visible_to_unit(board, board[source], board[target])):
        return false
    return live_unit_distance(board[source], board[target]) <= float(12 - 6 * int(skorch))

# Stable source-use counters survive transfers/revival. Makari is army/battle,
# Da Jump army/round; ordinary free selection abilities resolve once per phase.
# Source cards' Movement clauses and explicit once-per-army restrictions.
fun orks_datasheet_move_available(Board board, UnitID source, OrksDatasheetMoveAbility ability) -> Bool:
    if source.get() >= board.units.size() or board[source].off_battlefield or board[source].owned_by_player1 != board.current_player or board.timing.phase.value != BattlePhase::movement.value or !has_live_model(board[source]):
        return false
    ref unit = board[source]
    if ability.value == OrksDatasheetMoveAbility::makari.value:
        return unit.has_ability(AbilityKind::makari_banner) and source_usage_available(board, orks_remaining_usage(unit, 148, true, true))
    if ability.value == OrksDatasheetMoveAbility::da_jump.value:
        return board.reserve_units.has_capacity() and orks_datasheet_psychic_available(board, source, 151)
    let skorch = ability.value == OrksDatasheetMoveAbility::drive_by_skorchin.value
    if (!skorch and !unit.has_ability(AbilityKind::found_em)) or (skorch and !unit.has_ability(AbilityKind::drive_by_skorchin)) or !source_usage_available(board, orks_remaining_usage(unit, 149 + int(skorch), false, false)):
        return false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_datasheet_move_target(board, source, target, skorch):
            return true
    return false

# Finite action domain contains four ability names, not new positions or
# Cartesian products of unit/model/weapon selectors (Godot action contract).
fun orks_datasheet_move_any(Board board, UnitID source) -> Bool:
    let ability : OrksDatasheetMoveAbility
    for kind in range(4):
        ability.value = kind
        if orks_datasheet_move_available(board, source, ability):
            return true
    return false

# Makari selects zero..round friendly army units, including offboard own-army
# units without ranges; the shared bank selector prevents duplicate targets.
# https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
fun orks_makari_target(Board board, SourceBank bank, UnitID target, Bool owner, EntityIdentity[5] selected) -> Bool:
    if target.get() >= source_bank_size(board, bank):
        return false
    ref unit = source_bank_unit(board, bank, target.get())
    if unit.owned_by_player1 != owner or !unit.has_keyword(Keyword::orks) or !has_live_model(unit):
        return false
    for index in range(5):
        if selected[index] == unit.identity:
            return false
    return true

# One MovementPhase owns this selector; accepted psychic1 still moves the
# unit to reserves. Default effect duration is this phase (01.02.02), allowing
# Deep Strike on same-phase ingress rather than permanent roster mutation.
# Sources: Orks/Ghazghkull-Thraka Makari; Kommandos; Warbuggies; Weirdboy Da Jump.
act orks_datasheet_movement(ctx Board board, frm UnitID source) -> OrksDatasheetMovement:
    frm previous_bank = board.orks_support_bank
    act choose_datasheet_move_ability(frm OrksDatasheetMoveAbility ability) {orks_datasheet_move_available(board, source, ability)}
    if ability.value == OrksDatasheetMoveAbility::makari.value:
        commit_source_usage(board, orks_remaining_usage(board[source], 148, true, true))
        frm chosen : EntityIdentity[5]
        frm count : BInt<0, 6>
        while count.value < board.current_round.value + 1:
            actions:
                act finish_makari_targets()
                    break
                act choose_makari_bank(frm SourceBank bank)
                    board.orks_support_bank = bank
                    actions:
                        act cancel_makari_bank()
                        act choose_makari_unit(UnitID target) {orks_makari_target(board, bank, target, board[source].owned_by_player1, chosen)}
                            ref unit = source_bank_unit(board, bank, target.get())
                            chosen[count.value] = unit.identity
                            grant_orks_own_payload(board, unit, 165, riled_up_grant(), SourceDuration::next_own_turn)
                            count = count + 1
    if ability.value == OrksDatasheetMoveAbility::found_em.value or ability.value == OrksDatasheetMoveAbility::drive_by_skorchin.value:
        frm skorch = ability.value == OrksDatasheetMoveAbility::drive_by_skorchin.value
        act choose_datasheet_move_target(frm UnitID target) {orks_datasheet_move_target(board, source, target, skorch)}
        commit_source_usage(board, orks_remaining_usage(board[source], 149 + int(skorch), false, false))
        frm kind = OrksEffectKind::found_detection
        if skorch:
            kind = OrksEffectKind::overwatch_blocked
        grant_orks_effect(board, source, target, 166 + int(skorch), kind, 1, SourceDuration::turn, invalid_entity_identity())
    if ability.value == OrksDatasheetMoveAbility::da_jump.value:
        frm jump_rule : BInt<151, 163>
        jump_rule = 151
        board.shared_actions.orks_datasheet_psychic = orks_datasheet_psychic(board, source, jump_rule)
        subaction*(board) board.shared_actions.orks_datasheet_psychic
        if has_live_model(board[source]):
            grant_orks_effect(board, source, source, 163, OrksEffectKind::jump_deep_strike, 1, SourceDuration::phase, invalid_entity_identity())
            assert(reposition_unit(board, source), "Da Jump requires reserve capacity")
    board.orks_support_bank = previous_bank

# Supreme Kunnin' is free, once per phase PER ARMY, and checks the enemy's
# completed endpoint. It cannot trigger from the controlling player's moves.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
fun orks_supreme_kunnin_valid(Board board, UnitID mover, UnitID source) -> Bool:
    return mover.get() < board.units.size() and source.get() < board.units.size() and board.timing.phase == BattlePhase::movement and board[source].owned_by_player1 != board.current_player and board[source].owned_by_player1 != board[mover].owned_by_player1 and !board[source].off_battlefield and has_live_model(board[source]) and board[source].has_ability(AbilityKind::supreme_kunnin) and !board.is_in_melee(board[source]) and live_unit_distance(board[source], board[mover]) <= 8.0 and source_usage_available(board, orks_remaining_usage(board[source], 154, true, false))

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
            board.shared_actions.orks_datasheet_psychic = orks_datasheet_psychic(board, carrier.unit, rule)
            subaction*(board) board.shared_actions.orks_datasheet_psychic
            frm payload : OrksEffectGrant
            payload.kind = OrksEffectKind::beastscent
            payload.amount = 1
            grant_orks_own_payload(board, board.embarked_units[passenger.get()], 169, payload, SourceDuration::turn)

# Taktikal Know-wotz splits the exact10 models into two five-model components
# BEFORE attachments/transport formations. Original model identities/equipment
# survive; each resulting unit receives exactly one of the two token abilities.
# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
fun split_orks_kommandos(Board board, UnitID source, Bool[10] first_group, Bool bomb_first):
    assert(source.get() < board.reserve_units.size() and board.reserve_units.has_capacity(), "split needs a roster slot")
    ref original = board.reserve_units[source.get()]
    assert(original.models.size() == 10 and original.attached_units.empty() and orks_type(original, OrksDatasheet::kommandos), "split must precede attachments")
    let count = 0
    for member_index in range(10):
        count = count + int(first_group[member_index])
    assert(count == 5, "each split Kommando unit needs five models")
    let second : Unit
    second.name = "Kommandos (split)"s
    second.owned_by_player1 = original.owned_by_player1
    configure_orks_attachment(second, OrksDatasheet::kommandos)
    let first_models : CheckedVector<Model, MAX_UNIT_MODELS>
    for member_index in range(10):
        let model = original[member_index]
        let bomb = first_group[member_index] == bomb_first
        let ability_index = model.abilities.size()
        while ability_index > 0:
            ability_index = ability_index - 1
            if model.abilities[ability_index] == AbilityKind::taktikal_know_wotz or model.abilities[ability_index] == AbilityKind::bomb_squig and !bomb or model.abilities[ability_index] == AbilityKind::found_em and bomb:
                model.abilities.erase(ability_index)
        if first_group[member_index]:
            first_models.append(model)
        else:
            second.models.append(model)
    original.models = first_models
    original.destroyed_models.value.clear()
    original.capture_starting_strength()
    board.identify_unit(second)
    for member_index in range(second.models.size()):
        second[member_index].original_unit = second.identity
    second.capture_starting_strength()
    board.reserve_units.append(second)

# Each initial unit gets one optional split decision in its owner's order;
# resulting five-model units cannot split again or refill a spent Bomb Squig.
# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos (Declare Battle Formations).
act orks_kommando_formations(ctx Board board) -> OrksKommandoFormations:
    frm source : UnitIterator
    frm previous_owner = board.current_decision_maker
    while source.value < board.reserve_units.size():
        if board.reserve_units[source.value].has_ability(AbilityKind::taktikal_know_wotz) and board.reserve_units[source.value].models.size() == 10 and board.reserve_units.has_capacity():
            board.current_decision_maker = board.reserve_units[source.value].owned_by_player1
            act split_kommando_unit(Bool split)
            if split:
                frm selected : Bool[10]
                frm count : BInt<0, 6>
                while count.value < 5:
                    act choose_split_kommando(ModelID member_index) {member_index.get() < 10, !selected[member_index.get()]}
                    selected[member_index.get()] = true
                    count = count + 1
                act choose_split_bomb_squig(Bool first_group)
                frm slot : UnitID
                slot = source.value
                split_orks_kommandos(board, slot, selected, first_group)
        source = source + 1
    board.current_decision_maker = previous_owner
