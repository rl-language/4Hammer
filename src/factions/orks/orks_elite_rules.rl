import factions.orks.datasheets
import factions.orks.orks_datasheet_rules
import factions.orks.orks_detachment_support

# Rule codes retain per-original-unit token history through attachments and
# revival. Source: Orks/Painboy, Painboss, Big-Mek-In-Mega-Armour, Tankbustas.
const ORKS_SURGERY_RULE = 120
const ORKS_ARMOUR_REPAIR_RULE = 121
const ORKS_PAINBOSS_RULE = 122
const ORKS_MEK_REPAIR_RULE = 123
const ORKS_ORDERLY_RULE = 124
const ORKS_RUNTHERD_RULE = 125
const ORKS_PULSA_RULE = 126
const ORKS_SCAVENGERS_RULE = 127
const ORKS_SHOKK_BOOST_RULE = 128

# A model's supported source remains distinct from its attached bodyguards.
# Support Shokka excludes whole SAG units, including itself, and measures
# from the actual bearer, never from a closer bodyguard (core p83).
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun
fun orks_shokka_supported(Board board, Unit unit) -> Bool:
    if unit.off_battlefield or !unit.attached_units.empty():
        return false
    for bearer in range(unit.models.size()):
        if !unit[bearer].is_alive() or !unit[bearer].has_ability(AbilityKind::support_shokka):
            continue
        for other in range(board.units.size()):
            ref ally = board[other]
            if !ally.off_battlefield and has_live_model(ally) and ally.owned_by_player1 == unit.owned_by_player1 and ally.has_keyword(Keyword::orks) and ally.has_keyword(Keyword::infantry) and !orks_type(ally, OrksDatasheet::big_mek_with_shokk_attack_gun) and live_distance_to_model(ally, unit[bearer]) <= 3.0:
                return true
    return false

# Big Mek's More Dakka is unit-wide; Mek's Kustom Dakka lacks Sustained Hits.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Big-Mek,Mek}
fun append_orks_elite_weapon_rules(Unit unit, Weapon selected, WeaponAbilitySet result):
    if selected.range() > 0:
        if unit.has_ability(AbilityKind::more_dakka) or unit.has_ability(AbilityKind::kustom_dakka):
            result.append(weapon_rule(WeaponRuleKind::ignore_cover))
        if unit.has_ability(AbilityKind::more_dakka) and unit_is_riled_up(unit):
            result.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))

# Super Runts improves only Scavenged Shivs, including the inverse numeric
# direction of WS. Its riled permission is registered by the existing passive
# source engine and is lost/restored with the actual Zodgrod source.
# https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga
fun append_orks_elite_modifiers(Unit unit, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    if unit.has_ability(AbilityKind::super_runts) and declaration.weapon_name.value == NamedWeapon::scavenged_shivs.value:
        if kind.value == ModifiedCharacteristic::attacks.value or kind.value == ModifiedCharacteristic::strength.value:
            result.append(rule_modifier(ModifierOperation::add, 1))
        if kind.value == ModifiedCharacteristic::weapon_skill.value:
            result.append(rule_modifier(ModifierOperation::subtract, 1))

# Pulsa affects its recorded target identity for the phase, not a later
# replacement target. The target need not remain within24in after selection.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun orks_pulsa_applies(Board board, Unit source, EntityIdentity target) -> Bool:
    for bearer in range(source.models.size()):
        for index in range(source[bearer].orks_effects.size()):
            ref effect = source[bearer].orks_effects[index]
            if effect.kind.value == OrksEffectKind::pulsa_target.value and effect.associated_unit == target and source_grant_active(board, effect.source_effect):
                return true
    return false

# Contributions enter the existing characteristic/cap/ignore pipeline.
# AP is improved by subtracting, worsened by adding; duplicates of the same
# unit ability do not multiply. Distinct repair modifiers remain cumulative.
# Sources: Orks/Flash-Gitz, Meganobz, Painboss, Mek, Tankbustas.
fun append_orks_elite_attack_effects(Board board, UnitID source, UnitID target, DeclaredWeapon declaration, AttackSequenceInfo info):
    ref unit = board[source]
    ref victim = board[target]
    let bearer = declared_model_index(board, source, declaration)
    if declaration.weapon.range() > 0 and unit.has_ability(AbilityKind::finderz_keeperz) and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 == board.current_player and (unit_in_any_objective_range(board, unit) or unit_in_any_objective_range(board, victim)):
        info.ap_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    if victim.has_ability(AbilityKind::arrogant_invulnerability):
        info.ap_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if victim.has_ability(AbilityKind::hardy_bioniks):
        info.greater_strenght_wound_protection = true
    if declaration.weapon.range() == 0 and board.timing.phase == BattlePhase::fight and unit.has_ability(AbilityKind::krumpin_time) and unit_is_riled_up(unit):
        info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if bearer >= 0:
        for repair_index in range(unit[bearer].orks_effects.size()):
            ref repair = unit[bearer].orks_effects[repair_index]
            if repair.kind.value == OrksEffectKind::clever_hit.value and source_grant_active(board, repair.source_effect):
                info.orks_unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, max(1, repair.amount.value)))
    if orks_pulsa_applies(board, unit, victim.identity):
        info.ap_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
        info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::letal_hits))

# Kustom Force Field is equipment on the living/retained source, unit-wide
# and RANGED only. Do not grant a permanent model InSv that works in melee.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
fun orks_allocation_invulnerable(Unit unit, Model model, AttackSequenceInfo info) -> Int:
    let save = model.effective_invulnerable_save()
    if info.source.range() > 0 and unit.has_ability(AbilityKind::kustom_force_field):
        save = min(save, 4)
    return save

# The repair grants a model hit bonus even when it was already at full W.
# Range is bearer-to-model; forbidden Aircraft/Titanic and other banks cannot
# qualify. A vehicle unit's nearby member cannot stand in for a distant model.
# https://wahapedia.ru/wh40k11ed/factions/orks/Mek
fun orks_mek_target_valid(Board board, SourceInstance source, UnitID target, ModelID model) -> Bool:
    if target.get() >= board.units.size() or model.get() >= board[target].models.size() or board[target].off_battlefield or board[target].owned_by_player1 != source.owner:
        return false
    ref recipient = board[target][model]
    if !recipient.is_alive() or !recipient.has_keyword(Keyword::orks) or !recipient.has_keyword(Keyword::vehicle) or recipient.has_keyword(Keyword::aircraft) or recipient.has_keyword(Keyword::titanic):
        return false
    let location = locate_source(board, source.source_unit, source.source_model)
    if !location.found or location.bank.value != SourceBank::battlefield.value:
        return false
    ref actor = board[location.unit.value]
    let bearer = actor.find_model(source.source_model)
    return bearer >= 0 and actor[bearer].is_alive() and actor[bearer].distance(recipient) <= 3.0

# Invariants for all-bank own-unit healing; range-based Painboss targets
# remain battlefield units except for its own unit's explicit self-range.
# Sources: Orks/Painboy, Painboss, Big-Mek-In-Mega-Armour; appendix01.02.04.
fun orks_elite_heal_target(Board board, SourceInstance instance, SourceBank bank, UnitID target) -> Bool:
    if target.get() >= source_bank_size(board, bank):
        return false
    ref unit = source_bank_unit(board, bank, target.get())
    if unit.owned_by_player1 != instance.owner or !has_live_model(unit):
        return false
    let source = locate_source(board, instance.source_unit, instance.source_model)
    if !source.found:
        return false
    ref actor = source_bank_unit(board, source.bank, source.unit.value)
    if instance.rule.value != ORKS_PAINBOSS_RULE:
        return unit.identity == actor.identity
    if !unit.has_keyword(Keyword::beast_snagga):
        return false
    if unit.identity == actor.identity:
        return true
    return bank.value == SourceBank::battlefield.value and source.bank.value == SourceBank::battlefield.value and !unit.off_battlefield and !actor.off_battlefield and live_unit_distance(actor, unit) <= 6.0

# Preserve the general event machinery's ordering/limits while excluding
# deadlocked selectors and inactive conditional move-end hazards.
# Sources: Mek Clever Know-wotz, Big Mek Shokk-boosta, Gretchin Scavengers.
fun orks_elite_event_available(Board board, SourceInstance instance, SourceEvent event) -> Bool:
    if instance.rule.value == ORKS_MEK_REPAIR_RULE:
        let target : UnitID
        let model : ModelID
        for unit_index in range(board.units.size()):
            target = unit_index
            for member in range(board[unit_index].models.size()):
                model = member
                if orks_mek_target_valid(board, instance, target, model):
                    return true
        return false
    if instance.rule.value == ORKS_SHOKK_BOOST_RULE:
        let location = locate_source(board, instance.source_unit, instance.source_model)
        return location.found and location.bank.value == SourceBank::battlefield.value and board[location.unit.value].shokk_boosta_move and event.movement == MovementKind::advance
    return true

# Idempotent sources preserve token consumption on attachment/bank transfers.
# Current player chooses among these and existing simultaneous effects using
# choose_window_source/choose_movement_source; no second priority system.
# Sources: Orks/{Painboy,Painboss,Big-Mek-In-Mega-Armour,Mek,Gretchin,Big-Mek}.
fun register_orks_elite_rules(Board board):
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            for member_index in range(unit.models.size()):
                ref model = unit[member_index]
                if !model.is_alive():
                    continue
                for entry in range(6):
                    let available = entry == 0 and model.has_ability(AbilityKind::crude_surgery) or entry == 1 and model.has_ability(AbilityKind::fix_dat_armour_up) or entry == 2 and model.has_ability(AbilityKind::push_dat_bit_back_in) or entry == 3 and model.has_ability(AbilityKind::clever_know_wotz) or entry == 4 and model.has_ability(AbilityKind::thievin_scavengers) or entry == 5 and model.has_ability(AbilityKind::shokk_boosta)
                    if !available:
                        continue
                    let instance : SourceInstance
                    instance.rule = ORKS_SURGERY_RULE + entry
                    instance.source_unit = model.original_unit
                    instance.source_model = model.identity
                    instance.owner = unit.owned_by_player1
                    instance.own_turn_only = true
                    instance.use_scope = SourceUseScope::unit
                    instance.grant = riled_up_grant()
                    instance.trigger = SourceEventKind::timing_window
                    instance.window = TimingWindow::command_abilities
                    instance.phase = BattlePhase::command
                    instance.offboard_allowed = true
                    instance.optional = entry != 0
                    instance.limits.phase = 1
                    instance.name.value = "Crude Surgery"s
                    if entry == 1:
                        instance.name.value = "Fix Dat Armour Up"s
                        instance.limits.battle = 1
                    if entry == 2:
                        instance.name.value = "Push Dat Bit Back In"s
                        instance.limits.battle = 1
                    if entry == 3:
                        instance.name.value = "Clever Know-wotz"s
                        instance.offboard_allowed = false
                        instance.trigger = SourceEventKind::move_start
                        instance.window = TimingWindow::none
                        instance.phase = BattlePhase::movement
                        instance.limits.phase = 0
                    if entry == 4:
                        instance.name.value = "Thievin' Scavengers"s
                        instance.rule = ORKS_SCAVENGERS_RULE
                        instance.source_model = 0
                        instance.offboard_allowed = false
                        instance.window = TimingWindow::movement_end
                        instance.phase = BattlePhase::movement
                        instance.optional = false
                    if entry == 5:
                        instance.name.value = "Shokk-boosta hazards"s
                        instance.rule = ORKS_SHOKK_BOOST_RULE
                        instance.offboard_allowed = false
                        instance.trigger = SourceEventKind::move_end
                        instance.restrict_movement = true
                        instance.movement = MovementKind::advance
                        instance.phase = BattlePhase::movement
                        instance.optional = false
                        instance.limits.phase = 0
                    if !orks_unit_source_registered(board, instance):
                        let handle = register_source_instance(board, instance)
                    if entry == 3:
                        instance.trigger = SourceEventKind::move_end
                        if !orks_unit_source_registered(board, instance):
                            let end_handle = register_source_instance(board, instance)

# Securing uses actual control/range/OC at this selected end-window effect.
# No generic Battleline or points-based securing permission is invented.
# https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
fun secure_orks_gretchin_objectives(Board board, SourceInstance instance):
    let location = locate_source(board, instance.source_unit, invalid_entity_identity())
    if !location.found or location.bank.value != SourceBank::battlefield.value:
        return
    board.update_objective_control(true)
    for objective in range(4):
        if board.unit_controls_objective(board[location.unit.value], objective):
            board.grant_secured_objective(objective, instance.owner)

# A successful repair heals only the selected model, never revives a model.
# The hit grant has its own recipient identity and survives source death.
# https://wahapedia.ru/wh40k11ed/factions/orks/Mek (Clever Know-wotz).
act repair_orks_vehicle(ctx Board board, frm SourceInstance instance) -> OrksVehicleRepair:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = instance.owner
    act choose_mek_repair_unit(frm UnitID target) {orks_mek_unit_has_target(board, instance, target)}
    board.orks_selected_unit = target
    act choose_mek_repair_model(frm ModelID repaired) {orks_mek_target_valid(board, instance, target, repaired)}
    board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
    subaction* board.shared_actions.evaluate_random_stat
    board[target][repaired].suffered_wounds = max(0, board[target][repaired].suffered_wounds.value - board.shared_actions.evaluate_random_stat.result.value)
    frm grant : SourceInstance
    grant.rule = ORKS_MEK_REPAIR_RULE
    grant.owner = instance.owner
    grant.source_unit = board[target].identity
    grant.source_model = board[target][repaired].identity
    grant.recipient = SourceTarget::source_model
    grant.duration = SourceDuration::next_own_movement
    grant.name.value = "Clever Know-wotz"s
    frm payload : OrksEffectGrant
    payload.kind = OrksEffectKind::clever_hit
    payload.amount = 1
    grant.grant = payload
    # Repeated repairs reuse the model's grant prototype, while separate
    # effect keys keep both start/end hit contributions until their expiry.
    # A new source slot per repair would exhaust the finite source arena.
    let grant_index = -1
    for source_index in range(board.source_instances.size()):
        ref existing = board.source_instances[source_index]
        if existing.rule.value == ORKS_MEK_REPAIR_RULE and existing.source_model == grant.source_model and existing.duration.value == SourceDuration::next_own_movement.value:
            grant_index = source_index
    if grant_index < 0:
        let handle = register_source_instance(board, grant)
        grant_index = handle.value
    commit_source_effect_to_unit(board, grant, grant_index, board[target].identity)
    board.current_decision_maker = previous_owner

# Unit selection is separate from model selection to preserve Godot inputs.
# Orks/Mek Clever Know-wotz's bearer-to-model range, not unit-anchor range.
fun orks_mek_unit_has_target(Board board, SourceInstance instance, UnitID target) -> Bool:
    if target.get() >= board.units.size():
        return false
    let member : ModelID
    for index in range(board[target].models.size()):
        member = index
        if orks_mek_target_valid(board, instance, target, member):
            return true
    return false


# All-bank command healing calls the same one-wound kernel as existing
# revival cards. Roll optional D3 BEFORE allocating any of the total wounds.
# Sources: Orks/Painboy, Painboss, Big-Mek-In-Mega-Armour;02.02.04.
act orks_elite_command(ctx Board board, frm SourceInstance instance) -> OrksEliteCommand:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = instance.owner
    frm actor = locate_source(board, instance.source_unit, instance.source_model)
    frm bank = actor.bank
    frm target : UnitID
    target = actor.unit.value
    if instance.rule.value == ORKS_PAINBOSS_RULE and bank.value == SourceBank::battlefield.value:
        act choose_painboss_healing_unit(UnitID recipient) {orks_elite_heal_target(board, instance, SourceBank::battlefield, recipient)}
        target = recipient
    frm remaining : FixedStat
    remaining = 3
    if instance.rule.value == ORKS_SURGERY_RULE:
        frm bearer : ModelID
        bearer = source_bank_unit(board, actor.bank, actor.unit.value).find_model(instance.source_model)
        frm token = make_source_usage(source_bank_unit(board, actor.bank, actor.unit.value).owned_by_player1, ORKS_ORDERLY_RULE, source_bank_unit(board, actor.bank, actor.unit.value)[bearer].original_unit, source_bank_unit(board, actor.bank, actor.unit.value)[bearer].identity, SourceUseScope::unit, source_use_limits(0, 0, 0, 1))
        if source_usage_available(board, token):
            act use_grot_orderly(Bool use_orderly)
            if use_orderly:
                commit_source_usage(board, token)
                board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
                subaction* board.shared_actions.evaluate_random_stat
                remaining = remaining.value + board.shared_actions.evaluate_random_stat.result.value
    board.shared_actions.heal_unit = heal_unit(board, source_bank_unit(board, bank, target.get()), bank, remaining)
    subaction*(board, source_bank_unit(board, bank, target.get())) board.shared_actions.heal_unit
    board.current_decision_maker = previous_owner

# That'll Learn Ya counts actual living Gretchin, not GROTS keywords or
# attached Characters. It directly destroys the chosen models, without FNP.
# https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
fun orks_live_gretchin(Unit unit) -> Int:
    let count = 0
    for member in range(unit.models.size()):
        count = count + int(unit[member].is_alive() and model_matches_datasheet(unit[member], OrksDatasheet::gretchin))
    return count

# Own-unit correction also works in reserves/transports (01.02.04). Spend the
# round token before D3; resolve each normal destruction before clearing shock.
# https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
act orks_runtherd_shock(ctx Board board, ctx Unit unit) -> OrksRuntherdShock:
    if !unit.battle_socked or !unit.has_ability(AbilityKind::thatll_learn_ya) or orks_live_gretchin(unit) < 4:
        return
    frm bearer : ModelID
    for index in range(unit.models.size()):
        if unit[index].is_alive() and unit[index].has_ability(AbilityKind::thatll_learn_ya):
            bearer = index
    frm token = make_source_usage(unit.owned_by_player1, ORKS_RUNTHERD_RULE, unit[bearer].original_unit, unit[bearer].identity, SourceUseScope::unit, source_use_limits(0, 0, 1, 0))
    if !source_usage_available(board, token):
        return
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = unit.owned_by_player1
    act use_runtherd(Bool learn)
    if learn:
        commit_source_usage(board, token)
        board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
        subaction* board.shared_actions.evaluate_random_stat
        frm remaining = board.shared_actions.evaluate_random_stat.result
        while remaining.value > 0:
            act choose_punished_gretchin(frm ModelID casualty) {casualty.get() < unit.models.size(), unit[casualty].is_alive(), model_matches_datasheet(unit[casualty], OrksDatasheet::gretchin)}
            frm location = locate_source(board, unit.identity, invalid_entity_identity())
            assert(location.found, "Runtherd unit lost its bank")
            frm slot : UnitID
            slot = location.unit.value
            let job = damage_job(DamageKind::normal, slot, slot, false, false, unit[casualty].wounds_left(), unit[casualty].identity)
            job.bank = location.bank
            commit_wound_loss(board, job, casualty, unit[casualty].wounds_left(), false)
            frm jobs : DamageJobs
            board.shared_actions.resolve_damage_jobs = resolve_damage_jobs(board, jobs, false, slot)
            subaction*(board) board.shared_actions.resolve_damage_jobs
            remaining = remaining - 1
        unit.battle_socked = false
    board.current_decision_maker = previous_owner

# Each actually engaged source model contributes one D6; do not use unit
# size, charge distance or a weapon's Strength. Printed3+ causes1 mortal.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
fun orks_impetus_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    return target.get() < board.units.size() and !board[target].off_battlefield and has_live_model(board[target]) and board[target].owned_by_player1 != board[source].owned_by_player1 and board[source].is_engaged_with(board[target])

# One Charge owns this frame, sharing existing chance/mortal/destruction
# frames. Simultaneous Mobbed/Crushing/Impetus are ordered by the controller.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
act orks_krushin_impetus(ctx Board board, frm UnitID source) -> OrksKrushinImpetus:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = board[source].owned_by_player1
    act choose_impetus_target(frm UnitID target) {orks_impetus_target_valid(board, source, target)}
    frm amount : CombatCounter
    frm member_index : ModelIterator
    while member_index.value < board[source].models.size():
        frm engaged = false
        for enemy in range(board[target].models.size()):
            engaged = engaged or (board[source][member_index.value].is_alive() and board[target][enemy].is_alive() and board[source][member_index.value].is_engaged_with(board[target][enemy]))
        if engaged:
            act roll(Dice impact)
            amount = amount + int(impact.value >= 3)
        member_index = member_index + 1
    board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, target, source, false, amount)
    subaction*(board) board.shared_actions.resolve_mortal_wounds
    board.current_decision_maker = previous_owner

# Target choice needs no LOS clause; the printed24in and M/V restrictions
# apply at selection. After selection, stable target identity controls grants.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun orks_pulsa_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    return target.get() < board.units.size() and !board[target].off_battlefield and has_live_model(board[target]) and board[target].owned_by_player1 != board[source].owned_by_player1 and (board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle)) and live_unit_distance(board[source], board[target]) <= 24.0

# No unavailable target may leave this free optional selection stuck.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas (Pulsa Rokkit).
fun orks_pulsa_available(Board board, UnitID source) -> Bool:
    if board.timing.phase.value != BattlePhase::shooting.value or board[source].owned_by_player1 != board.current_player or !board[source].has_ability(AbilityKind::pulsa_rokkit):
        return false
    let bearer = -1
    for member in range(board[source].models.size()):
        if board[source][member].is_alive() and board[source][member].has_ability(AbilityKind::pulsa_rokkit):
            bearer = member
    if bearer < 0 or !source_usage_available(board, make_source_usage(board[source].owned_by_player1, ORKS_PULSA_RULE, board[source][bearer].original_unit, board[source][bearer].identity, SourceUseScope::unit, source_use_limits(0, 0, 0, 1))):
        return false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_pulsa_target_valid(board, source, target):
            return true
    return false

# One Attack owns the pre-declaration Pulsa choice; declining spends nothing.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
act orks_pulsa_selection(ctx Board board, frm UnitID source) -> OrksPulsaSelection:
    if !orks_pulsa_available(board, source):
        return
    act use_pulsa_rokkit(Bool pulsa)
    if pulsa:
        act choose_pulsa_target(frm UnitID target) {orks_pulsa_target_valid(board, source, target)}
        for member in range(board[source].models.size()):
            if board[source][member].is_alive() and board[source][member].has_ability(AbilityKind::pulsa_rokkit):
                commit_source_usage(board, make_source_usage(board[source].owned_by_player1, ORKS_PULSA_RULE, board[source][member].original_unit, board[source][member].identity, SourceUseScope::unit, source_use_limits(0, 0, 0, 1)))
        grant_orks_effect(board, source, source, ORKS_PULSA_RULE, OrksEffectKind::pulsa_target, 1, SourceDuration::phase, board[target].identity)

# Rokkit Barrage uses actual successful hit records, not declarations; it
# never fires in Overwatch/out-of-phase shooting. Choose exactly one hit unit.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun orks_barrage_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    if target.get() >= board.units.size() or board[target].off_battlefield or !has_live_model(board[target]) or board[target].owned_by_player1 == board[source].owned_by_player1:
        return false
    for entry in range(board.orks_attack_records.size()):
        if board.orks_attack_records[entry].target == board[target].identity and board.orks_attack_records[entry].successful_hits.value > 0:
            return true
    return false

# The standard shock frame applies the printed-1 and all shock transitions.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
act orks_rokkit_barrage(ctx Board board, frm UnitID source) -> OrksRokkitBarrage:
    if board.timing.phase.value != BattlePhase::shooting.value or board[source].owned_by_player1 != board.current_player or !board[source].has_ability(AbilityKind::rokkit_barrage):
        return
    frm available = false
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        available = available or orks_barrage_target_valid(board, source, target)
    if available:
        act choose_rokkit_barrage_target(frm UnitID shocked) {orks_barrage_target_valid(board, source, shocked)}
        frm penalty : LinearlyDistributedInt<0, 8>
        penalty = 1
        board.shared_actions.battle_shock_test = battle_shock_test(board, board[shocked], false, false, penalty)
        subaction*(board, board[shocked]) board.shared_actions.battle_shock_test

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
