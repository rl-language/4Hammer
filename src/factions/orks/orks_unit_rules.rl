import factions.orks.orks_unit_data
import source_effects
import terrain_rules
import attack_declarations

# Shared rule codes are infrastructure for the printed per-army-round and
# per-unit-battle limits. Beastboss on Squigosaur must reuse110 in its adapter.
# Sources: Orks/Beastboss Keep Huntin'; Orks/Squighog-Boyz Bomb Squig.
const ORKS_KEEP_HUNTIN_RULE = 110
# Standard Warboss card, borrowed by Boss Boomer with its own army-round use.
const ORKS_INTIMIDATING_RULE = 112
const ORKS_BOMB_SQUIG_RULE = 111

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
fun register_orks_unit_rules(Board board):
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
                        instance.name.value = "Keep Huntin'!"s
                        if window_index >= 2:
                            instance.rule = ORKS_INTIMIDATING_RULE
                            instance.name.value = "Intimidating Motivation"s
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
                    instance.name.value = "Bomb Squig"s
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

    register_orks_elite_rules(board)
    register_orks_remaining_rules(board)

# Measured targets must be live battlefield units; no external range or LOS
# exists to reserves/passengers (appendix01.02.04). Self-targeting is allowed
# for Keep Huntin' because a unit is within its own range.
fun orks_move_target_valid(Board board, SourceInstance instance, UnitID target) -> Bool:
    if target.get() < 0 or target.get() >= board.units.size() or board[target].off_battlefield or !has_live_damage_recipient(board[target]):
        return false
    let location = locate_source(board, instance.source_unit, instance.source_model)
    if !location.found or location.bank.value != SourceBank::battlefield.value:
        return false
    ref source = source_bank_unit(board, location.bank, location.unit.value)
    if source.off_battlefield or !has_live_damage_recipient(source):
        return false
    if instance.rule.value == 147:
        return orks_race_target(board, source, target)
    if instance.rule.value == ORKS_KEEP_HUNTIN_RULE or instance.rule.value == ORKS_INTIMIDATING_RULE:
        return board[target].owned_by_player1 == instance.owner and (board[target].has_keyword(Keyword::beast_snagga) and instance.rule.value == ORKS_KEEP_HUNTIN_RULE or board[target].has_keyword(Keyword::orks) and instance.rule.value == ORKS_INTIMIDATING_RULE) and source.distance(board[target]) <= 6.0
    if instance.rule.value == ORKS_BOMB_SQUIG_RULE:
        return board[target].owned_by_player1 != instance.owner and source.distance(board[target]) <= 12.0 and unit_visible_to_unit(board, source, board[target])
    return false

# An optional ability with no legal target cannot introduce an input deadlock.
# Keep source handles separate from UnitID selectors (editor action contract).
fun orks_move_source_has_target(Board board, SourceInstance instance) -> Bool:
    let found = false
    let target : UnitID
    for index in range(board.units.size()):
        target = index
        found = found or orks_move_target_valid(board, instance, target)
    return found

# Movement dispatch includes ordinary grants and both targeted Orks abilities
# in the same controller/order group (user-supplied Rules Sequencing).
fun orks_move_source_valid(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> Bool:
    if !pending_source_valid(board, pending, event, player):
        return false
    ref instance = board.source_instances[pending[event.value].source.value]
    if instance.rule.value == ORKS_KEEP_HUNTIN_RULE or instance.rule.value == ORKS_INTIMIDATING_RULE or instance.rule.value == ORKS_BOMB_SQUIG_RULE or instance.rule.value == 147:
        return orks_move_source_has_target(board, instance)
    return true

# Keep the same mandatory/optional semantics as ordinary source events while
# excluding unavailable target selectors (Rules Sequencing; source timings).
fun orks_move_sources_remaining(Board board, PendingSourceEvents pending, Bool player, Bool mandatory_only) -> Bool:
    let found = false
    let event : SourceEventID
    for index in range(pending.size()):
        event = index
        if orks_move_source_valid(board, pending, event, player) and (!mandatory_only or !board.source_instances[pending[index].source.value].optional):
            found = true
    return found

# Accepted Keep Huntin' removes shock immediately and installs a persistent
# riled grant until the next own turn; source death must not end it early.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss (Keep Huntin'!).
fun commit_orks_keep_huntin(Board board, PendingSourceEvents pending, SourceEventID event, Bool player, UnitID target):
    assert(orks_move_source_valid(board, pending, event, player), "Keep Huntin' unavailable")
    ref instance = board.source_instances[pending[event.value].source.value]
    assert((instance.rule.value == ORKS_KEEP_HUNTIN_RULE or instance.rule.value == ORKS_INTIMIDATING_RULE) and orks_move_target_valid(board, instance, target), "invalid Keep Huntin' target")
    commit_source_effect_to_unit(board, instance, pending[event.value].source.value, board[target].identity)
    board[target].battle_socked = false
    pending[event.value].resolved = true

# Mobbed applies to each engaged enemy MONSTER or VEHICLE, regardless of
# whether it was declared as a charge target. Corpses/offboard units do not roll.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz (Mobbed).
fun orks_mobbed_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    return source.get() >= 0 and source.get() < board.units.size() and target.get() >= 0 and target.get() < board.units.size() and source.get() != target.get() and board[source].has_charged and board[source].has_ability(AbilityKind::mobbed) and !board[source].off_battlefield and !board[target].off_battlefield and has_live_damage_recipient(board[target]) and board[target].owned_by_player1 != board[source].owned_by_player1 and (board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle)) and board[source].is_engaged_with(board[target])

# The13+ threshold is the current combined live strength at charge end,
# not starting strength, original Boy count or a price tier (Mobbed; core p66).
fun orks_mobbed_penalty(Unit unit) -> Int:
    return 1 + int(live_model_count(unit) >= 13)
