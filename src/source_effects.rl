import board

# Printed source examples for shared limits: Nazdreg's Intimidating Motivation
# and Supreme Kunnin', and Beast Snagga Boyz' Bomb Squig. These are framework
# examples, not installed ability effects:
# https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz

# Bank bridges preserve stable source/recipient identities through reserve and
# passenger transfers (supplied01.02.02/01.02.04; core pp.65/68/88).
fun source_bank_size(Board board, SourceBank bank) -> Int:
    if bank.value == SourceBank::reserves.value:
        return board.reserve_units.size()
    if bank.value == SourceBank::embarked.value:
        return board.embarked_units.size()
    return board.units.size()

fun source_bank_unit(Board board, SourceBank bank, Int index) -> ref Unit:
    if bank.value == SourceBank::reserves.value:
        return board.reserve_units[index]
    if bank.value == SourceBank::embarked.value:
        return board.embarked_units[index]
    return board.units[index]

# A model source follows its actual constituent, not its former vector index;
# a unit-only source follows the stable unit (attachments/destruction pp.66/87).
fun locate_source(Board board, EntityIdentity unit_identity, EntityIdentity model_identity) -> SourceLocation:
    let result : SourceLocation
    if unit_identity.value <= 0 and model_identity.value <= 0:
        return result
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            if unit.retired:
                continue
            if model_identity.value == 0:
                for component in range(unit.attached_units.size()):
                    if unit.attached_units[component].identity == unit_identity:
                        result.found = true
                        result.bank = bank
                        result.unit = unit_index
            if model_identity.value == 0 and unit.identity == unit_identity:
                result.found = true
                result.bank = bank
                result.unit = unit_index
            for model_index in range(unit.models.size()):
                if model_identity.value > 0 and unit[model_index].identity == model_identity:
                    result.found = true
                    result.bank = bank
                    result.unit = unit_index
    return result

# While-leading eligibility follows original component provenance, including
# an archived bearer at whole-unit destruction (pp66–67/19.01–19.04).
fun source_started_leading(Unit unit, SourceInstance instance) -> Bool:
    let component = instance.source_unit
    if instance.source_model.value > 0:
        for model in range(unit.models.size()):
            if unit[model].identity == instance.source_model:
                component = unit[model].original_unit
        for archive in range(unit.destroyed_models.value.size()):
            if unit.destroyed_models.value[archive].identity == instance.source_model:
                component = unit.destroyed_models.value[archive].original_unit
    return component_started_leading(unit, component)

# Sources cannot become a different model when casualties compact its unit.
# Own destruction triggers are separately authorised by their event (p.87).
fun source_alive(Board board, SourceInstance instance) -> Bool:
    let location = locate_source(board, instance.source_unit, instance.source_model)
    if instance.disabled or !location.found or !orks_source_transport_dependency(board, instance):
        return false
    ref unit = source_bank_unit(board, location.bank, location.unit.value)
    if instance.source_model.value == 0:
        let alive = false
        for member in range(unit.models.size()):
            alive = alive or (unit[member].original_unit == instance.source_unit and unit[member].is_alive())
        return alive and (!instance.requires_leading or source_started_leading(unit, instance))
    let model = unit.find_model(instance.source_model)
    return model >= 0 and unit[model].is_alive() and (!instance.requires_leading or source_started_leading(unit, instance))

# P67 unit/bearer grants retain their conferred effects through attack end,
# but this predicate does not make a destroyed model a live action recipient.
fun source_confers_rules(Board board, SourceInstance instance) -> Bool:
    if instance.model_specific_rule:
        return source_alive(board, instance)
    let location = locate_source(board, instance.source_unit, instance.source_model)
    if instance.disabled or !location.found or !orks_source_transport_dependency(board, instance):
        return false
    ref unit = source_bank_unit(board, location.bank, location.unit.value)
    if instance.source_model.value == 0:
        return component_source_active(unit, instance.source_unit) and (!instance.requires_leading or source_started_leading(unit, instance))
    let model = unit.find_model(instance.source_model)
    return model >= 0 and model_confers_attached_abilities(unit[model]) and (!instance.requires_leading or source_started_leading(unit, instance))

# Source rules use explicit rule codes for printed shared limits; equal names
# do not infer shared restrictions. All numeric metadata is standard bounded.
fun register_source_instance(Board board, SourceInstance instance) -> SourceInstanceID:
    assert(instance.rule.value > 0 and instance.rule.value < 513 and instance.source_unit.value > 0, "invalid source rule identity")
    # Army data exists before the optional formation choice (p66). Register
    # an actually live source even while its while-leading condition is false;
    # source_alive/conferral still enforce that condition during activation.
    let physical_source = instance
    physical_source.requires_leading = false
    assert(source_alive(board, physical_source) or (instance.allow_retained_source and orks_retained_source_present(board, instance)), "source must exist when registered")
    let candidate = board.source_instances.size()
    let reusable = reusable_orks_source_slot(board)
    if reusable >= 0:
        candidate = reusable
    assert(candidate >= 0 and candidate < MAX_SOURCE_INSTANCES, "source instance capacity exceeded")
    let id : SourceInstanceID
    id = candidate
    assert(valid_source_grant(instance.grant), "invalid source grant")
    let location = locate_source(board, instance.source_unit, instance.source_model)
    assert(source_bank_unit(board, location.bank, location.unit.value).owned_by_player1 == instance.owner, "source owner mismatch")
    assert(board.next_source_generation.value + 1 < MAX_SOURCE_EFFECT_KEY, "source generation capacity exceeded")
    board.next_source_generation = board.next_source_generation + 1
    instance.generation = board.next_source_generation
    if reusable >= 0:
        board.source_instances[reusable] = instance
    else:
        board.source_instances.append(instance)
    assert(valid_source_foundations(board), "invalid source metadata")
    refresh_source_effects(board, TimingWindow::none)
    return id

# Event snapshots are implementation infrastructure for actual move/attack/
# shock/destruction boundaries; event kind is not an invented faction ability.
fun source_event(SourceEventKind kind, EntityIdentity unit, EntityIdentity target, EntityIdentity model) -> SourceEvent:
    let result : SourceEvent
    result.kind = kind
    result.unit = unit
    result.target = target
    result.model = model
    return result

# Whole-unit death belongs to the surviving attached container even when a
# bearer died earlier. This fallback is only event provenance, not proof of
# a live source or ongoing conferral (p66/19.02; p67/19.04).
fun source_event_location(Board board, SourceInstance instance, SourceEvent event) -> SourceLocation:
    let location = locate_source(board, instance.source_unit, instance.source_model)
    if !location.found and event.kind.value == SourceEventKind::unit_destroyed.value and !instance.model_specific_rule:
        location = locate_source(board, instance.source_unit, invalid_entity_identity())
    return location

# Per-army/unit/model keys remain distinct. Attached model sources resolve the
# current containing unit for per-unit use (pp.66–67; sourced Orks restrictions).
fun source_usage_subject(Board board, SourceInstance instance) -> EntityIdentity:
    let result : EntityIdentity
    if instance.use_scope.value == SourceUseScope::model.value:
        result = instance.source_model
    if instance.use_scope.value == SourceUseScope::unit.value:
        result = instance.source_unit
        let location = locate_source(board, instance.source_unit, invalid_entity_identity())
        if location.found:
            result = source_bank_unit(board, location.bank, location.unit.value).identity
    return result

# A shared printed rule code and scope share counters across duplicate sources,
# but never across players (e.g. Nazdreg once-per-phase/round per army).
fun source_usage_index(Board board, SourceInstance instance) -> Int:
    let subject = source_usage_subject(board, instance)
    let found = -1
    for usage_index in range(board.source_uses.size()):
        ref record = board.source_uses[usage_index]
        if record.rule == instance.rule and record.owner == instance.owner and record.scope.value == instance.use_scope.value and record.subject == subject:
            found = usage_index
    return found

# Multiple interval limits are conjunctive: e.g. Bomb Squigs once per turn
# and twice per battle. Stale phase/turn/round counters read as zero.
fun source_usage_available(Board board, SourceInstance instance) -> Bool:
    let index = source_usage_index(board, instance)
    if index < 0:
        return true
    ref record = board.source_uses[index]
    return (instance.limits.phase.value == 0 or record.phase_stamp.value != board.phase_serial.value or record.phase_uses.value < instance.limits.phase.value) and (instance.limits.turn.value == 0 or record.turn_stamp.value != board.turn_serial.value or record.turn_uses.value < instance.limits.turn.value) and (instance.limits.round.value == 0 or record.round_stamp.value != board.current_round.value or record.round_uses.value < instance.limits.round.value) and (instance.limits.battle.value == 0 or record.battle_uses.value < instance.limits.battle.value)

# Consume only an accepted source; declines do not spend usage. Stable keys
# keep limits when models die or move offboard (printed source restrictions).
fun commit_source_usage(Board board, SourceInstance instance):
    assert(source_usage_available(board, instance), "source use limit exceeded")
    if instance.limits.phase.value == 0 and instance.limits.turn.value == 0 and instance.limits.round.value == 0 and instance.limits.battle.value == 0:
        return
    let index = source_usage_index(board, instance)
    if index < 0:
        let record : SourceUseRecord
        record.rule = instance.rule
        record.owner = instance.owner
        record.scope = instance.use_scope
        record.subject = source_usage_subject(board, instance)
        board.source_uses.append(record)
        index = board.source_uses.size() - 1
    ref usage = board.source_uses[index]
    if usage.phase_stamp.value != board.phase_serial.value:
        usage.phase_uses = 0
    if usage.turn_stamp.value != board.turn_serial.value:
        usage.turn_uses = 0
    if usage.round_stamp.value != board.current_round.value:
        usage.round_uses = 0
    usage.phase_stamp = board.phase_serial.value
    usage.turn_stamp = board.turn_serial.value
    usage.round_stamp = board.current_round.value
    assert(usage.phase_uses.value + 1 < MAX_CHARACTERISTIC and usage.turn_uses.value + 1 < MAX_CHARACTERISTIC and usage.round_uses.value + 1 < MAX_CHARACTERISTIC and usage.battle_uses.value + 1 < MAX_CHARACTERISTIC, "source use counter capacity exceeded")
    usage.phase_uses = usage.phase_uses + 1
    usage.turn_uses = usage.turn_uses + 1
    usage.round_uses = usage.round_uses + 1
    usage.battle_uses = usage.battle_uses + 1

# Explicit offboard permission never authorises visibility/range measurement
# to/from reserves/passengers (supplied01.02.04). Conditional ranges use bases.
fun source_event_available(Board board, SourceInstance instance, SourceEvent event) -> Bool:
    if instance.disabled or instance.aura or instance.own_unit_passive or instance.trigger.value != event.kind.value or (event.kind.value == SourceEventKind::timing_window.value and instance.window.value != event.window.value) or !source_usage_available(board, instance):
        return false
    if instance.phase.value != BattlePhase::none.value and instance.phase.value != board.timing.phase.value:
        return false
    if (instance.own_turn_only and instance.owner != board.current_player) or (instance.opposing_turn_only and instance.owner == board.current_player):
        return false
    if instance.restrict_movement and (event.kind.value == SourceEventKind::move_start.value or event.kind.value == SourceEventKind::move_end.value) and instance.movement.value != event.movement.value:
        return false
    if !orks_elite_event_available(board, instance, event):
        return false
    let location = source_event_location(board, instance, event)
    # Explicit death permission does not waive a while-leading condition.
    if instance.requires_leading and (!location.found or !source_started_leading(source_bank_unit(board, location.bank, location.unit.value), instance)):
        return false
    let own_destruction = event.kind.value == SourceEventKind::model_destroyed.value and instance.source_model.value > 0 and instance.source_model == event.model
    let own_unit_destruction = false
    if event.kind.value == SourceEventKind::unit_destroyed.value and location.found and !instance.model_specific_rule:
        own_unit_destruction = event.unit == source_bank_unit(board, location.bank, location.unit.value).identity
    own_destruction = own_destruction or own_unit_destruction
    if !own_destruction and (!location.found or !(source_alive(board, instance) or (!instance.model_specific_rule and source_confers_rules(board, instance)))):
        return false
    if location.found and location.bank.value != SourceBank::battlefield.value and !instance.offboard_allowed:
        return false
    if instance.requires_unengaged and (!location.found or location.bank.value != SourceBank::battlefield.value or board.is_in_melee(source_bank_unit(board, location.bank, location.unit.value))):
        return false
    let recipient = instance.source_unit
    if location.found:
        recipient = source_bank_unit(board, location.bank, location.unit.value).identity
    if instance.recipient.value == SourceTarget::event_unit.value:
        recipient = event.unit
    if instance.recipient.value == SourceTarget::target_unit.value:
        recipient = event.target
    let recipient_location = locate_source(board, recipient, invalid_entity_identity())
    if instance.recipient.value == SourceTarget::source_model.value and !source_alive(board, instance):
        return false
    if !recipient_location.found or (!has_live_damage_recipient(source_bank_unit(board, recipient_location.bank, recipient_location.unit.value)) and !(own_unit_destruction and recipient == event.unit)) or !unit_matches_keywords(source_bank_unit(board, recipient_location.bank, recipient_location.unit.value), instance.recipient_condition):
        return false
    if event.kind.value == SourceEventKind::timing_window.value:
        return true
    let subject = locate_source(board, event.unit, invalid_entity_identity())
    if !subject.found:
        return false
    ref event_unit = source_bank_unit(board, subject.bank, subject.unit.value)
    let own_identity = instance.source_unit
    if location.found:
        own_identity = source_bank_unit(board, location.bank, location.unit.value).identity
    if instance.subject.value == SourceSubject::own_unit.value and event.unit != own_identity:
        return false
    if instance.subject.value == SourceSubject::target_unit.value and event.target != own_identity:
        return false
    if instance.subject.value == SourceSubject::friendly_unit.value and event_unit.owned_by_player1 != instance.owner:
        return false
    if instance.subject.value == SourceSubject::enemy_unit.value and event_unit.owned_by_player1 == instance.owner:
        return false
    if instance.trigger_range.value > 0:
        if event.unit == own_identity:
            return true
        if !location.found or location.bank.value != SourceBank::battlefield.value or subject.bank.value != SourceBank::battlefield.value:
            return false
        return source_bank_unit(board, location.bank, location.unit.value).distance(event_unit) <= float(instance.trigger_range.value)
    return true

# Freeze eligible source handles, not one Boolean per rule kind. Re-check each
# handle at resolution so earlier choices can consume a shared limit or kill it.
fun collect_source_events(Board board, SourceEvent event) -> PendingSourceEvents:
    refresh_source_effects(board, TimingWindow::none)
    let pending : PendingSourceEvents
    for source_index in range(board.source_instances.size()):
        if source_event_available(board, board.source_instances[source_index], event):
            let entry : PendingSourceEvent
            entry.source = source_index
            entry.generation = board.source_instances[source_index].generation
            entry.event = event
            pending.append(entry)
    return pending

# Each controller sees only its own still-eligible source instances; no stale
# record or invalid action-domain index may dereference a missing source.
fun pending_source_valid(Board board, PendingSourceEvents pending, SourceEventID id, Bool player) -> Bool:
    return id.value >= 0 and id.value < pending.size() and !pending[id.value].resolved and pending[id.value].source.value >= 0 and pending[id.value].source.value < board.source_instances.size() and board.source_instances[pending[id.value].source.value].owner == player and pending[id.value].generation == board.source_instances[pending[id.value].source.value].generation and source_event_available(board, board.source_instances[pending[id.value].source.value], pending[id.value].event)

fun source_events_remaining(Board board, PendingSourceEvents pending, Bool player, Bool mandatory_only) -> Bool:
    let result = false
    let id : SourceEventID
    for index in range(pending.size()):
        id = index
        if pending_source_valid(board, pending, id, player) and (!mandatory_only or !board.source_instances[pending[index].source.value].optional):
            result = true
    return result

# Install one uniquely tagged grant. Expiring identical overlapping sources
# removes only its own copy (supplied01.02.02; source grants17.E).
fun install_source_grant(Model model, SourceGrant grant, SourceEffectKey key):
    let installed = grant
    if installed is CharacteristicModifier:
        installed.source_effect = key
        model.characteristic_modifiers.append(installed)
    if installed is IncomingAttackModifier:
        installed.source_effect = key
        model.incoming_attack_modifiers.append(installed)
    if installed is AttackModifierPermission:
        installed.source_effect = key
        model.attack_modifier_permissions.append(installed)
    if installed is OrksEffectGrant:
        installed.source_effect = key
        model.orks_effects.append(installed)
    if installed is RiledUpGrant:
        model.riled_source_effects.append(key)
    if installed is SourceWeaponGrant:
        installed.rule.source_effect = key
        for slot in range(model.weapons.size()):
            if source_weapon_slot_matches(model, installed, slot):
                model.additional_weapon_rules[slot].append(installed.rule)

# Effects target stable recipients in any bank and keep their original duration
# through embark/reserve transfers (supplied01.02.02/01.02.04).
fun commit_pending_source(Board board, PendingSourceEvents pending, SourceEventID id, Bool player):
    assert(pending_source_valid(board, pending, id, player), "ineligible source event")
    ref instance = board.source_instances[pending[id.value].source.value]
    let target = instance.source_unit
    if instance.recipient.value == SourceTarget::source_unit.value or instance.recipient.value == SourceTarget::source_model.value:
        let source_location = source_event_location(board, instance, pending[id.value].event)
        if source_location.found:
            target = source_bank_unit(board, source_location.bank, source_location.unit.value).identity
    if instance.recipient.value == SourceTarget::event_unit.value:
        target = pending[id.value].event.unit
    if instance.recipient.value == SourceTarget::target_unit.value:
        target = pending[id.value].event.target
    let recipient_location = locate_source(board, target, invalid_entity_identity())
    assert(recipient_location.found, "source effect recipient disappeared")
    assert(has_live_damage_recipient(source_bank_unit(board, recipient_location.bank, recipient_location.unit.value)) or pending[id.value].event.kind.value == SourceEventKind::unit_destroyed.value, "source effect has no live recipient")
    commit_source_effect_to_unit(board, instance, pending[id.value].source.value, target)
    pending[id.value].resolved = true

# Remove a handle, not every equal-valued modifier. Archives are included so
# later revival cannot resurrect expired grants (returning models p.88).
fun remove_source_grant(Model model, SourceEffectKey key):
    let effect_index = model.orks_effects.size()
    while effect_index > 0:
        effect_index = effect_index - 1
        if model.orks_effects[effect_index].source_effect == key:
            model.orks_effects.erase(effect_index)
    let index = model.characteristic_modifiers.size()
    while index > 0:
        index = index - 1
        if model.characteristic_modifiers[index].source_effect == key:
            model.characteristic_modifiers.erase(index)
    index = model.incoming_attack_modifiers.size()
    while index > 0:
        index = index - 1
        if model.incoming_attack_modifiers[index].source_effect == key:
            model.incoming_attack_modifiers.erase(index)
    index = model.attack_modifier_permissions.size()
    while index > 0:
        index = index - 1
        if model.attack_modifier_permissions[index].source_effect == key:
            model.attack_modifier_permissions.erase(index)
    index = model.riled_source_effects.size()
    while index > 0:
        index = index - 1
        if model.riled_source_effects[index] == key:
            model.riled_source_effects.erase(index)
    for slot in range(model.weapons.size()):
        index = model.additional_weapon_rules[slot].size()
        while index > 0:
            index = index - 1
            if model.additional_weapon_rules[slot][index].source_effect == key:
                model.additional_weapon_rules[slot].erase(index)

# Phase default, explicit turn/round/next-own-turn duration and live-source
# conditions expire at their actual boundaries in every bank (01.02.02).
fun refresh_source_effects(Board board, TimingWindow ended):
    let index = board.source_effects.size()
    while index > 0:
        index = index - 1
        ref effect = board.source_effects[index]
        let phase_end = ended == TimingWindow::command_end or ended == TimingWindow::movement_end or ended == TimingWindow::shooting_end or ended == TimingWindow::charge_end or ended == TimingWindow::fight_end
        let expired = effect.duration.value == SourceDuration::phase.value and (effect.phase_stamp.value != board.phase_serial.value or phase_end)
        expired = expired or (effect.duration.value == SourceDuration::turn.value and (effect.turn_stamp.value != board.turn_serial.value or ended == TimingWindow::turn_end))
        expired = expired or (effect.duration.value == SourceDuration::round.value and (effect.round_stamp.value != board.current_round.value or ended == TimingWindow::round_end))
        expired = expired or (effect.duration.value == SourceDuration::next_own_turn.value and effect.owner == board.current_player and effect.turn_stamp.value != board.turn_serial.value)
        # War Cry ends after the next turn, not at its start or at the end of
        # the activation turn (Orks Army Rules / War Cry).
        expired = expired or (effect.duration.value == SourceDuration::end_next_turn.value and (board.turn_serial.value > effect.turn_stamp.value + 1 or (ended == TimingWindow::turn_end and board.turn_serial.value > effect.turn_stamp.value)))
        # Mek/Clever Know-wotz ends at next Movement, not next turn start.
        expired = expired or (effect.duration.value == SourceDuration::next_own_movement.value and effect.owner == board.current_player and (ended == TimingWindow::movement_start or board.timing.phase == BattlePhase::movement) and effect.turn_stamp.value != board.turn_serial.value)
        expired = expired or (effect.requires_live_source and !source_confers_rules(board, board.source_instances[effect.source.value]))
        if board.source_instances[effect.source.value].aura or board.source_instances[effect.source.value].own_unit_passive:
            let target_location = locate_source(board, effect.target_unit, invalid_entity_identity())
            expired = expired or !target_location.found
            if target_location.found:
                expired = expired or !source_aura_target(board, board.source_instances[effect.source.value], target_location)
        if !expired:
            refresh_effect_members(board, effect)
            continue
        let bank : SourceBank
        for bank_index in range(3):
            bank.value = bank_index
            for unit_index in range(source_bank_size(board, bank)):
                ref unit = source_bank_unit(board, bank, unit_index)
                for model_index in range(unit.models.size()):
                    remove_source_grant(unit[model_index], effect.identity)
                for archived_index in range(unit.destroyed_models.value.size()):
                    remove_source_grant(unit.destroyed_models.value[archived_index], effect.identity)
        board.source_effects.erase(index)
    for source_index in range(board.source_instances.size()):
        ref instance = board.source_instances[source_index]
        if (!instance.aura and !instance.own_unit_passive) or !source_confers_rules(board, instance):
            continue
        let recipient_bank : SourceBank
        for bank_index in range(3):
            recipient_bank.value = bank_index
            for unit_index in range(source_bank_size(board, recipient_bank)):
                let target_location : SourceLocation
                target_location.found = true
                target_location.unit = unit_index
                target_location.bank = recipient_bank
                if !source_aura_target(board, instance, target_location):
                    continue
                let existing = -1
                for effect_index in range(board.source_effects.size()):
                    if board.source_effects[effect_index].source.value == source_index and board.source_effects[effect_index].target_unit == source_bank_unit(board, recipient_bank, unit_index).identity:
                        existing = effect_index
                if existing >= 0:
                    continue
                assert(board.next_source_effect.value + 1 < MAX_SOURCE_EFFECT_KEY, "source effect key capacity exceeded")
                board.next_source_effect = board.next_source_effect + 1
                let aura_effect : SourceEffect
                aura_effect.identity = board.next_source_effect
                aura_effect.source = source_index
                aura_effect.target_unit = source_bank_unit(board, recipient_bank, unit_index).identity
                aura_effect.unit_scope = true
                aura_effect.duration = SourceDuration::battle
                aura_effect.requires_live_source = true
                aura_effect.owner = instance.owner
                aura_effect.phase_stamp = board.phase_serial.value
                aura_effect.turn_stamp = board.turn_serial.value
                aura_effect.round_stamp = board.current_round.value
                for recipient in range(source_bank_unit(board, recipient_bank, unit_index).models.size()):
                    if source_bank_unit(board, recipient_bank, unit_index)[recipient].is_alive():
                        install_source_grant(source_bank_unit(board, recipient_bank, unit_index)[recipient], instance.grant, aura_effect.identity)
                        aura_effect.recipients.append(source_bank_unit(board, recipient_bank, unit_index)[recipient].identity)
                board.source_effects.append(aura_effect)

# Saved declaration snapshots cannot revive an expired weapon-rule grant
# merely because its old value remains in a queued attack (pp.17/01.02.02).
fun source_grant_active(Board board, SourceEffectKey key) -> Bool:
    if key.value == 0:
        return true
    let active = false
    for index in range(board.source_effects.size()):
        active = active or board.source_effects[index].identity == key
    return active

# Named/physical weapon grants keep the same conjunctive selector semantics as
#17.C2c; a source does not grant every equipped weapon merely through timing.
fun source_weapon_slot_matches(Model model, SourceWeaponGrant grant, Int slot) -> Bool:
    if grant.weapon_name.value > 0 and grant.weapon_name != model.weapon_names[slot]:
        return false
    if grant.profile_name.value > 0 and grant.profile_name != model.weapon_profile_names[slot]:
        return false
    if grant.weapon_scope.value == 0:
        return true
    let representative = grant.weapon_scope.value - 1
    return representative == slot or (grant.physical_scope and representative < model.weapons.size() and model.weapon_profile_groups[representative].value > 0 and model.weapon_profile_groups[representative] == model.weapon_profile_groups[slot])

# Default source weapon grants cover equipped profiles; callers restrict them
# by slot/physical instance/name/profile as the printed source requires.
fun source_weapon_grant(WeaponRule rule) -> SourceWeaponGrant:
    let result : SourceWeaponGrant
    result.rule = rule
    return result

# Validate typed source payloads before loading/dispatch, rather than permitting
# invalid modifiers, foreign ownership or forged effect handles into consumers.
fun valid_source_grant(SourceGrant grant) -> Bool:
    let valid = false
    if grant is OrksEffectGrant:
        valid = grant.kind.value > 0 and grant.kind.value <= max(grant.kind) and grant.amount.value >= 0 and grant.associated_unit.value >= 0
    if grant is CharacteristicModifier:
        let entries : CharacteristicModifiers
        entries.append(grant)
        valid = valid_characteristic_modifiers(entries) and grant.source_effect.value == 0
    if grant is IncomingAttackModifier:
        let incoming : IncomingAttackModifiers
        incoming.append(grant)
        valid = valid_incoming_attack_modifiers(incoming) and grant.source_effect.value == 0
    if grant is AttackModifierPermission:
        valid = valid_attack_modifier_permission(grant) and grant.source_effect.value == 0
    if grant is RiledUpGrant:
        valid = grant.enabled
    if grant is SourceWeaponGrant:
        valid = valid_weapon_condition(grant.rule) and grant.rule.source_effect.value == 0 and grant.weapon_scope.value >= 0 and grant.weapon_scope.value < MAX_WEAPON_SCOPES and grant.weapon_name.value >= 0 and grant.weapon_name.value < MAX_WEAPONNAMECODE and grant.profile_name.value >= 0 and grant.profile_name.value < MAX_WEAPONPROFILECODE and (!grant.physical_scope or grant.weapon_scope.value > 0)
    return valid

# Persistent metadata is bounded infrastructure, not a license for new rules.
# Dead/absent sources may retain usage/persisting effects; IDs must stay valid.
fun valid_source_foundations(Board board) -> Bool:
    if board.next_source_generation.value < 0 or board.next_source_generation.value >= MAX_SOURCE_EFFECT_KEY:
        return false
    if board.next_source_effect.value < 0 or board.next_source_effect.value >= MAX_SOURCE_EFFECT_KEY:
        return false
    for source_index in range(board.source_instances.size()):
        ref instance = board.source_instances[source_index]
        if instance.generation.value <= 0 or instance.generation.value > board.next_source_generation.value or instance.required_embarked_model.value < 0 or instance.required_embarked_model.value > board.next_identity.value or instance.required_carrier_model.value < 0 or instance.required_carrier_model.value > board.next_identity.value:
            return false
        if instance.rule.value <= 0 or instance.rule.value >= 513 or instance.source_unit.value <= 0 or instance.source_unit.value > board.next_identity.value or instance.source_model.value < 0 or instance.source_model.value > board.next_identity.value:
            return false
        if instance.trigger.value < 0 or instance.trigger.value > SourceEventKind::unit_destroyed.value or instance.window.value < 0 or instance.window.value > TimingWindow::fight_end.value or instance.phase.value < 0 or instance.phase.value > BattlePhase::fight.value or instance.subject.value < 0 or instance.subject.value > SourceSubject::target_unit.value or instance.use_scope.value < 0 or instance.use_scope.value > SourceUseScope::model.value or instance.recipient.value < 0 or instance.recipient.value > SourceTarget::source_model.value or instance.duration.value < 0 or instance.duration.value > SourceDuration::next_own_movement.value:
            return false
        let keyword : Keyword
        if !instance.recipient_condition.valid(max(keyword)):
            return false
        if instance.aura and (instance.recipient.value != SourceTarget::event_unit.value or instance.duration.value != SourceDuration::battle.value or instance.trigger_range.value <= 0 or instance.optional or instance.recipient.value == SourceTarget::source_model.value or instance.subject.value == SourceSubject::target_unit.value or instance.limits.phase.value > 0 or instance.limits.turn.value > 0 or instance.limits.round.value > 0 or instance.limits.battle.value > 0):
            return false
        if instance.own_unit_passive and (instance.aura or instance.recipient.value != SourceTarget::source_unit.value or instance.duration.value != SourceDuration::battle.value or !instance.requires_live_source or instance.optional or instance.trigger_range.value != 0 or instance.limits.phase.value > 0 or instance.limits.turn.value > 0 or instance.limits.round.value > 0 or instance.limits.battle.value > 0):
            return false
        if (instance.own_turn_only and instance.opposing_turn_only) or (instance.use_scope.value == SourceUseScope::model.value and instance.source_model.value == 0) or (instance.recipient.value == SourceTarget::source_model.value and instance.source_model.value == 0) or !valid_source_grant(instance.grant):
            return false
        let location = locate_source(board, instance.source_unit, instance.source_model)
        if location.found and source_bank_unit(board, location.bank, location.unit.value).owned_by_player1 != instance.owner:
            return false
        if instance.trigger_range.value < 0 or instance.trigger_range.value >= MAX_CHARACTERISTIC or instance.movement.value < 0 or instance.movement.value > MovementKind::emergency_disembark.value:
            return false
        if instance.limits.phase.value < 0 or instance.limits.phase.value >= MAX_CHARACTERISTIC or instance.limits.turn.value < 0 or instance.limits.turn.value >= MAX_CHARACTERISTIC or instance.limits.round.value < 0 or instance.limits.round.value >= MAX_CHARACTERISTIC or instance.limits.battle.value < 0 or instance.limits.battle.value >= MAX_CHARACTERISTIC:
            return false
    for effect_index in range(board.source_effects.size()):
        ref effect = board.source_effects[effect_index]
        if effect.identity.value <= 0 or effect.identity.value > board.next_source_effect.value or effect.source.value < 0 or effect.source.value >= board.source_instances.size() or effect.duration.value < 0 or effect.duration.value > SourceDuration::next_own_movement.value or effect.owner != board.source_instances[effect.source.value].owner:
            return false
        if effect.phase_stamp.value < 0 or effect.phase_stamp.value > board.phase_serial.value or effect.turn_stamp.value < 0 or effect.turn_stamp.value > board.turn_serial.value or effect.round_stamp.value < 0 or effect.round_stamp.value > board.current_round.value:
            return false
        for prior in range(effect_index):
            if board.source_effects[prior].identity == effect.identity:
                return false
        for recipient in range(effect.recipients.size()):
            if effect.recipients[recipient].value <= 0 or effect.recipients[recipient].value > board.next_identity.value:
                return false
    for usage_index in range(board.source_uses.size()):
        ref usage = board.source_uses[usage_index]
        if usage.rule.value <= 0 or usage.rule.value >= 513 or usage.scope.value < 0 or usage.scope.value > SourceUseScope::model.value or usage.subject.value < 0 or usage.subject.value > board.next_identity.value or (usage.scope.value != SourceUseScope::army.value and usage.subject.value == 0):
            return false
        if usage.phase_stamp.value < 0 or usage.phase_stamp.value > board.phase_serial.value or usage.turn_stamp.value < 0 or usage.turn_stamp.value > board.turn_serial.value or usage.round_stamp.value < 0 or usage.round_stamp.value > board.current_round.value:
            return false
        if usage.phase_uses.value < 0 or usage.phase_uses.value >= MAX_CHARACTERISTIC or usage.turn_uses.value < 0 or usage.turn_uses.value >= MAX_CHARACTERISTIC or usage.round_uses.value < 0 or usage.round_uses.value >= MAX_CHARACTERISTIC or usage.battle_uses.value < 0 or usage.battle_uses.value >= MAX_CHARACTERISTIC:
            return false
        for prior in range(usage_index):
            ref earlier = board.source_uses[prior]
            if earlier.rule == usage.rule and earlier.owner == usage.owner and earlier.scope.value == usage.scope.value and earlier.subject == usage.subject:
                return false
    for pending_index in range(board.active_source_events.size()):
        ref pending = board.active_source_events[pending_index]
        if pending.source.value < 0 or pending.source.value >= board.source_instances.size() or pending.event.kind.value < 0 or pending.event.kind.value > SourceEventKind::unit_destroyed.value:
            return false
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            for model_index in range(unit.models.size()):
                if !valid_model_source_handles(board, unit[model_index]):
                    return false
            for archived in range(unit.destroyed_models.value.size()):
                if !valid_model_source_handles(board, unit.destroyed_models.value[archived]):
                    return false
    return true

# Passive unit auras are recomputed from live battlefield sources and recipient
# keywords/range at boundaries; no distance is measured to an offboard unit
# (supplied01.02.04/02.05.01; range/base definitions supplied by the user).
fun source_aura_target(Board board, SourceInstance instance, SourceLocation target) -> Bool:
    let location = locate_source(board, instance.source_unit, instance.source_model)
    if !source_confers_rules(board, instance) or !location.found:
        return false
    # Own-unit passive abilities need no external measurement and remain
    # available offboard, unlike auras (appendix01.02.04; Super Runts/Effigy).
    if instance.own_unit_passive:
        return location.bank.value == target.bank.value and location.unit.value == target.unit.value and (target.bank.value == SourceBank::battlefield.value or instance.offboard_allowed)
    if location.bank.value != SourceBank::battlefield.value or target.bank.value != SourceBank::battlefield.value:
        return false
    ref caster = source_bank_unit(board, location.bank, location.unit.value)
    ref recipient = source_bank_unit(board, target.bank, target.unit.value)
    if recipient.retired or recipient.off_battlefield or !has_live_damage_recipient(recipient) or !unit_matches_keywords(recipient, instance.recipient_condition):
        return false
    if instance.subject.value == SourceSubject::own_unit.value and caster.identity != recipient.identity:
        return false
    if instance.subject.value == SourceSubject::friendly_unit.value and recipient.owned_by_player1 != instance.owner:
        return false
    if instance.subject.value == SourceSubject::enemy_unit.value and recipient.owned_by_player1 == instance.owner:
        return false
    if instance.phase.value != BattlePhase::none.value and instance.phase.value != board.timing.phase.value:
        return false
    if (instance.own_turn_only and instance.owner != board.current_player) or (instance.opposing_turn_only and instance.owner == board.current_player):
        return false
    return caster.identity == recipient.identity or caster.distance(recipient) <= float(instance.trigger_range.value)

# Unit effects extend to returned/new constituents without duplicating a grant
# already carried by a surviving model (returning models p.88/01.02.02).
fun model_has_source_grant(Model model, SourceEffectKey key) -> Bool:
    let present = false
    for orks_effect in range(model.orks_effects.size()):
        present = present or model.orks_effects[orks_effect].source_effect == key
    for index in range(model.characteristic_modifiers.size()):
        present = present or model.characteristic_modifiers[index].source_effect == key
    for incoming_index in range(model.incoming_attack_modifiers.size()):
        present = present or model.incoming_attack_modifiers[incoming_index].source_effect == key
    for permission_index in range(model.attack_modifier_permissions.size()):
        present = present or model.attack_modifier_permissions[permission_index].source_effect == key
    for riled_index in range(model.riled_source_effects.size()):
        present = present or model.riled_source_effects[riled_index] == key
    for slot in range(model.weapons.size()):
        for rule_index in range(model.additional_weapon_rules[slot].size()):
            present = present or model.additional_weapon_rules[slot][rule_index].source_effect == key
    return present

fun refresh_effect_members(Board board, SourceEffect effect):
    if !effect.unit_scope:
        return
    let location = locate_source(board, effect.target_unit, invalid_entity_identity())
    if !location.found:
        return
    ref unit = source_bank_unit(board, location.bank, location.unit.value)
    for index in range(unit.models.size()):
        if (!unit[index].is_alive() and !(unit[index].state == ModelState::fight_on_death)) or model_has_source_grant(unit[index], effect.identity):
            continue
        install_source_grant(unit[index], board.source_instances[effect.source.value].grant, effect.identity)
        let known = false
        for recipient in range(effect.recipients.size()):
            known = known or effect.recipients[recipient] == unit[index].identity
        if !known:
            effect.recipients.append(unit[index].identity)

# Grant handles must belong to a recorded recipient; otherwise a forged saved
# modifier could evade expiry or acquire another source's lifetime (17.E).
fun source_handle_matches_model(Board board, SourceEffectKey key, EntityIdentity model) -> Bool:
    if key.value == 0:
        return true
    let valid = false
    for effect in range(board.source_effects.size()):
        if board.source_effects[effect].identity != key:
            continue
        for recipient in range(board.source_effects[effect].recipients.size()):
            valid = valid or board.source_effects[effect].recipients[recipient] == model
    return valid

fun valid_model_source_handles(Board board, Model model) -> Bool:
    let valid = true
    for index in range(model.characteristic_modifiers.size()):
        valid = valid and source_handle_matches_model(board, model.characteristic_modifiers[index].source_effect, model.identity)
    for incoming in range(model.incoming_attack_modifiers.size()):
        valid = valid and source_handle_matches_model(board, model.incoming_attack_modifiers[incoming].source_effect, model.identity)
    for permission_index in range(model.attack_modifier_permissions.size()):
        valid = valid and source_handle_matches_model(board, model.attack_modifier_permissions[permission_index].source_effect, model.identity)
    for riled_index in range(model.riled_source_effects.size()):
        valid = valid and source_handle_matches_model(board, model.riled_source_effects[riled_index], model.identity)
    for slot in range(model.weapons.size()):
        for rule in range(model.additional_weapon_rules[slot].size()):
            valid = valid and source_handle_matches_model(board, model.additional_weapon_rules[slot][rule].source_effect, model.identity)
    return valid

# Typed alternative bridge lets callers/bindings supply a numerical grant
# without storing unbounded characteristics or exposing compiler internals.
fun source_characteristic_grant(CharacteristicModifier grant) -> SourceGrant:
    let result : SourceGrant
    result = grant
    return result

#02.02.02 permission grants share the existing source lifetime/prototype
# ownership, including overlaps and offboard/archived recipients (01.02.02).
fun source_attack_modifier_grant(AttackModifierPermission permission) -> SourceGrant:
    let result : SourceGrant
    result = permission
    return result


# One typed status installs all three printed riled benefits through consumers,
# with exact-key expiry rather than independent buff lifetimes (Orks Waaagh!).
fun riled_up_grant() -> SourceGrant:
    let grant : RiledUpGrant
    grant.enabled = true
    let result : SourceGrant
    result = grant
    return result


# Simultaneous model/unit destruction rules share controller groups and choice
# ordering; a source has exactly one trigger, so the total fits the source arena (p.66/87;
# user-supplied Rules Sequencing). Non-destruction dispatch remains unchanged.
fun collect_destruction_sources(Board board, SourceEvent model_event, Bool unit_destroyed) -> PendingSourceEvents:
    let pending = collect_source_events(board, model_event)
    if unit_destroyed:
        let unit_event = model_event
        unit_event.kind = SourceEventKind::unit_destroyed
        let additional = collect_source_events(board, unit_event)
        for event in range(additional.size()):
            pending.append(additional[event])
    return pending


# Shared installation infrastructure: an accepted source may choose a different
# recipient (Beastboss/Keep Huntin'). Eligibility is checked by its caller.
# Source-owned timed effects persist/expire in every bank (appendix01.02.02).
fun commit_source_effect_to_unit(Board board, SourceInstance instance, Int source_index, EntityIdentity target):
    let location = locate_source(board, target, invalid_entity_identity())
    assert(location.found, "source effect recipient disappeared")
    ref unit = source_bank_unit(board, location.bank, location.unit.value)
    assert(!unit.models.empty(), "source effect has no recipient")
    assert(board.next_source_effect.value + 1 < MAX_SOURCE_EFFECT_KEY and board.source_effects.has_capacity(), "source effect capacity exceeded")
    board.next_source_effect = board.next_source_effect + 1
    let effect : SourceEffect
    effect.identity = board.next_source_effect
    effect.source = source_index
    effect.target_unit = target
    effect.unit_scope = instance.recipient.value != SourceTarget::source_model.value
    effect.owner = instance.owner
    effect.duration = instance.duration
    effect.requires_live_source = instance.requires_live_source
    effect.phase_stamp = board.phase_serial.value
    effect.turn_stamp = board.turn_serial.value
    effect.round_stamp = board.current_round.value
    for model_index in range(unit.models.size()):
        if (unit[model_index].is_alive() or unit[model_index].state == ModelState::fight_on_death) and (instance.recipient.value != SourceTarget::source_model.value or unit[model_index].identity == instance.source_model):
            install_source_grant(unit[model_index], instance.grant, effect.identity)
            effect.recipients.append(unit[model_index].identity)
    board.source_effects.append(effect)
    commit_source_usage(board, instance)
