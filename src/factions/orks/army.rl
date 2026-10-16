import board
import source_effects

# War Cry affects friendly ORKS units with Waaagh!, including offboard units;
# it neither measures to them nor grants the ability to an unrelated roster.
fun war_cry_available(Board board, Bool player) -> Bool:
    if board.armies[int(player)].faction != ArmyFaction::orks or board.armies[int(player)].war_cry_used:
        return false
    let available = false
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            available = available or (unit.owned_by_player1 == player and unit_has_waaagh(unit))
    return available

# A destroyed or different Character is not the selected Warlord. Own rules
# remain usable offboard without external visibility/range (appendix01.02.04).
fun da_boss_available(Board board, Bool player) -> Bool:
    if board.armies[int(player)].faction != ArmyFaction::orks or board.armies[int(player)].warlord.value == 0:
        return false
    let location = locate_source(board, invalid_entity_identity(), board.armies[int(player)].warlord)
    if !location.found:
        return false
    ref unit = source_bank_unit(board, location.bank, location.unit.value)
    let model = unit.find_model(board.armies[int(player)].warlord)
    return unit.owned_by_player1 == player and model >= 0 and unit[model].is_alive() and unit[model].has_da_boss

# War Cry is at either Command start; Da Boss is at battle-round start.
# Explicit per-group resolution prevents repeated inputs at the same window.
fun orks_timing_rule_available(Board board, TimingWindow window, Bool player, OrksTimingRule rule, Bool[2] resolved) -> Bool:
    if rule.value < 0 or rule.value > OrksTimingRule::da_boss.value or resolved[rule.value]:
        return false
    if rule.value == OrksTimingRule::war_cry.value:
        return window == TimingWindow::command_start and war_cry_available(board, player)
    return window == TimingWindow::round_start and da_boss_available(board, player)

# Availability joins the existing start-window loop; optional War Cry can be
# declined by finishing, but mandatory Da Boss cannot be skipped (Army Rules).
fun orks_timing_rules_remaining(Board board, TimingWindow window, Bool player, Bool[2] resolved, Bool mandatory_only) -> Bool:
    let rule : OrksTimingRule
    if !mandatory_only and orks_timing_rule_available(board, window, player, rule, resolved):
        return true
    rule = OrksTimingRule::da_boss
    return orks_timing_rule_available(board, window, player, rule, resolved)

# One disabled source record owns all War Cry installations. Effects persist
# independently of that source's death, and expire at the end of the next turn,
# not at next-turn start (War Cry; appendix01.02.02/01.02.04).
fun call_war_cry(Board board, Bool player):
    assert(board.timing.window == TimingWindow::command_start and war_cry_available(board, player), "War Cry is unavailable")
    let instance : SourceInstance
    instance.rule = 100
    instance.label.value = SourceLabel::war_cry
    instance.owner = player
    instance.trigger = SourceEventKind::timing_window
    instance.window = TimingWindow::command_start
    instance.recipient = SourceTarget::target_unit
    instance.duration = SourceDuration::end_next_turn
    instance.offboard_allowed = true
    instance.grant = riled_up_grant()
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            if unit.owned_by_player1 == player and unit_has_waaagh(unit):
                instance.source_unit = unit.identity
    let source = register_source_instance(board, instance)
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            if unit.owned_by_player1 != player or !unit_has_waaagh(unit):
                continue
            let entry : PendingSourceEvent
            entry.source = source.value
            entry.generation = board.source_instances[source.value].generation
            entry.event.kind = SourceEventKind::timing_window
            entry.event.window = TimingWindow::command_start
            entry.event.target = unit.identity
            let pending : PendingSourceEvents
            pending.append(entry)
            let event : SourceEventID
            commit_pending_source(board, pending, event, player)
    board.source_instances[source.value].disabled = true
    board.armies[int(player)].war_cry_used = true

# Da Boss says gain1CP. Core CP remains the separate Command step; no extra-CP
# cap is stated in the supplied11th-edition definition/appendix08.02.01.
fun resolve_orks_timing_rule(Board board, Bool player, OrksTimingRule rule):
    if rule.value == OrksTimingRule::war_cry.value:
        call_war_cry(board, player)
    else:
        assert(da_boss_available(board, player), "Da Boss has no live selected Warlord")
        assert(board.command_points[int(player)].value + 1 < MAX_CP, "CP capacity exceeded")
        board.command_points[int(player)] = board.command_points[int(player)] + 1

# Super Runts/Waaagh! Effigy are source-bound unit passives. Register only
# explicit metadata, never infer them from a legacy factory or a display name.
# https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
# https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga
# Datasheet factories remain17.H–P; these fixtures establish shared lifetime.
fun register_orks_passive_rules(Board board):
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            for model_index in range(unit.models.size()):
                if !unit[model_index].is_alive() or !unit[model_index].grants_unit_riled_up:
                    continue
                let present = false
                for source_index in range(board.source_instances.size()):
                    present = present or (board.source_instances[source_index].rule.value == 101 and board.source_instances[source_index].source_model == unit[model_index].identity)
                if present:
                    continue
                let instance : SourceInstance
                instance.rule = 101
                instance.label.value = SourceLabel::permanent_riled_up
                instance.source_unit = unit.identity
                instance.source_model = unit[model_index].identity
                instance.owner = unit.owned_by_player1
                instance.own_unit_passive = true
                instance.offboard_allowed = true
                instance.requires_live_source = true
                instance.duration = SourceDuration::battle
                instance.grant = riled_up_grant()
                let source = register_source_instance(board, instance)

# Stable Warlord/use metadata is infrastructure for Da Boss/War Cry. A dead
# Warlord keeps its identity; only the active ability query requires life.
fun valid_orks_army_state(Board board) -> Bool:
    let valid = true
    for player_index in range(2):
        ref army = board.armies[player_index]
        valid = valid and army.warlord.value >= 0 and army.warlord.value <= board.next_identity.value
        valid = valid and (!army.war_cry_used or army.faction == ArmyFaction::orks)
        if army.warlord.value == 0:
            continue
        let found = false
        let bank : SourceBank
        for bank_index in range(3):
            bank.value = bank_index
            for unit_index in range(source_bank_size(board, bank)):
                ref unit = source_bank_unit(board, bank, unit_index)
                if int(unit.owned_by_player1) != player_index:
                    continue
                for model_index in range(unit.models.size()):
                    found = found or (unit[model_index].identity == army.warlord and unit[model_index].has_keyword(Keyword::character) and unit[model_index].has_keyword(Keyword::warlord))
                for archive_index in range(unit.destroyed_models.value.size()):
                    found = found or (unit.destroyed_models.value[archive_index].identity == army.warlord and unit.destroyed_models.value[archive_index].has_keyword(Keyword::character) and unit.destroyed_models.value[archive_index].has_keyword(Keyword::warlord))
        for expired_index in range(board.expired_reserves.value.size()):
            ref expired = board.expired_reserves.value[expired_index]
            if int(expired.owned_by_player1) != player_index:
                continue
            for model_index in range(expired.models.size()):
                found = found or (expired[model_index].identity == army.warlord and expired[model_index].has_keyword(Keyword::character) and expired[model_index].has_keyword(Keyword::warlord))
            for archive_index in range(expired.destroyed_models.value.size()):
                found = found or (expired.destroyed_models.value[archive_index].identity == army.warlord and expired.destroyed_models.value[archive_index].has_keyword(Keyword::character) and expired.destroyed_models.value[archive_index].has_keyword(Keyword::warlord))
        valid = valid and found
    return valid

# A unit ability follows its live constituent union; corpses cannot keep an
# active army ability (Orks Waaagh! / appendix02.05.01 / destruction p.87).
fun unit_has_waaagh(Unit unit) -> Bool:
    let available = false
    for index in range(unit.models.size()):
        available = available or (model_confers_attached_abilities(unit[index]) and unit[index].has_waaagh)
    if !unit.attached_units.empty():
        available = available or (unit.bodyguard_waaagh and component_source_active(unit, unit.identity))
        for component_index in range(unit.attached_units.size()):
            available = available or (unit.attached_units[component_index].waaagh and component_source_active(unit, unit.attached_units[component_index].identity))
    return available and unit.has_keyword(Keyword::orks)

# All members receive each unit-wide riled grant. Read only live bearers for
# movement/shooting permissions (Orks Waaagh! / destruction p.87).
fun unit_is_riled_up(Unit unit) -> Bool:
    let active = false
    for index in range(unit.models.size()):
        active = active or ((unit[index].is_alive() or unit[index].state == ModelState::fight_on_death) and unit[index].is_riled_up())
    return active
