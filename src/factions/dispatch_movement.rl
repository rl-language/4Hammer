import factions.orks.movement
import factions.orks.psychic
import factions.orks.queries
import factions.orks.recovery
import factions.orks.transports

# Neutral movement entrypoints. This composition module is the only layer
# that selects concrete faction behavior; core algorithms do not inspect it.

# Assault Disembark and Gut Hatch grant specific post-move charge permission (Orks transport cards).
fun faction_assault_disembark(Board board, Unit carrier_unit) -> Bool:
    return orks_assault_disembark(board, carrier_unit)

# Minefield Detail supplies Scouts6; all combined printed Scouts values must match (Orks/Taktikal Brigade; user ruling).
fun faction_scouts_override(Unit unit) -> Int:
    return orks_scouts_override(unit)

# Completed Pulse Jet installs its source-owned charge/action/defence effects (Orks Pulse Jet Move).
fun faction_record_move_effects(Board board, UnitID id, MovementKind kind):
    orks_record_move_effects(board, id, kind)

# Pulse Engine supplies Pulse Jet selection permission (Orks/Wazdakka).
fun faction_special_move_available(Board board, Unit unit, MovementKind kind) -> Bool:
    return orks_special_move_available(board, unit, kind)

# Shokk-boosta permits model traversal without granting FLY or terrain traversal (Orks/Big-Mek).
fun faction_prepare_movement_policy(Unit unit, MovementKind kind, MovementGeometryPolicy policy):
    orks_prepare_movement_policy(unit, kind, policy)

# Pulse Jet traversal overrides remain separate from ordinary FLY/Walker costs (Orks Special Move Types).
fun faction_finish_movement_policy(MovementKind kind, MovementGeometryPolicy policy):
    orks_finish_movement_policy(kind, policy)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_move_charge_permission(Board board, Unit unit, MovementKind kind) -> Bool:
    return orks_move_charge_permission(board, unit, kind)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_charge_reroll(Board board, Unit unit) -> Bool:
    return orks_charge_reroll(board, unit)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun capture_faction_selected_move(Board board, UnitID source, MovementKind kind):
    capture_orks_selected_move(board, source, kind)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_forces_escape(Board board, Unit unit) -> Bool:
    return orks_forces_escape(board, unit)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_escape_penalty(Board board, Unit unit) -> Int:
    return orks_escape_penalty(board, unit)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_extra_escape_hazards(Board board, Unit unit) -> Int:
    return orks_extra_escape_hazards(board, unit)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_movement_abilities(Board board, UnitID source) -> OrksMovementAbilities:
    return orks_movement_abilities(board, source)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun select_faction_enemy_move_reaction(Board board, UnitID mover) -> OrksEnemyMoveReaction:
    return select_orks_enemy_move_reaction(board, mover)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_enemy_move_available(Board board, UnitID mover) -> Bool:
    return orks_enemy_move_available(board, mover)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_wagon_move_end(Board board, UnitID source) -> OrksWagonMoveEnd:
    return orks_wagon_move_end(board, source)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_wagon_charge_end(Board board, UnitID source) -> OrksWagonChargeEnd:
    return orks_wagon_charge_end(board, source)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_flyboss_ingress(Board board, UnitID source):
    orks_flyboss_ingress(board, source)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_ingress_round_allowed(Board board, Unit unit) -> Bool:
    return orks_ingress_round_allowed(board, unit)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_kaptin_redeploy(Board board) -> OrksKaptinRedeploy:
    return orks_kaptin_redeploy(board)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun commit_faction_race(Board board, SourceInstance instance, UnitID target):
    commit_orks_race(board, instance, target)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_datasheet_move_any(Board board, UnitID source) -> Bool:
    return orks_datasheet_move_any(board, source)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_datasheet_movement(Board board, UnitID source) -> OrksDatasheetMovement:
    return orks_datasheet_movement(board, source)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_kommando_formations(Board board) -> OrksKommandoFormations:
    return orks_kommando_formations(board)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_stampede_charge_bonus(Board board, Unit unit) -> Int:
    return orks_stampede_charge_bonus(board, unit)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_move_selection(Board board, UnitID actor, Bool charging) -> OrksMoveSelection:
    return orks_move_selection(board, actor, charging)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_move_mode(Board board, UnitID actor, MovementKind kind) -> OrksMoveMode:
    return orks_move_mode(board, actor, kind)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_fallback_selection(Board board, UnitID mover) -> OrksFallbackSelection:
    return orks_fallback_selection(board, mover)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_move_target_valid(Board board, SourceInstance instance, UnitID target) -> Bool:
    return orks_move_target_valid(board, instance, target)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_move_source_valid(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> Bool:
    return orks_move_source_valid(board, pending, event, player)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_move_sources_remaining(Board board, PendingSourceEvents pending, Bool player, Bool mandatory_only) -> Bool:
    return orks_move_sources_remaining(board, pending, player, mandatory_only)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun commit_faction_keep_huntin(Board board, PendingSourceEvents pending, SourceEventID event, Bool player, UnitID target):
    commit_orks_keep_huntin(board, pending, event, player, target)

# Composition hook: transports adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun register_faction_cargo_passives(Board board):
    register_orks_cargo_passives(board)

# Composition hook: transports adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_bunka_passenger_control(Board board, Model carrier, Bool player) -> Int:
    return orks_bunka_passenger_control(board, carrier, player)

# Composition hook: transports adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_trukk_reactions(Board board, UnitID mover) -> OrksTrukkReactions:
    return orks_trukk_reactions(board, mover)

# Composition hook: transports adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_disembark_selection(Board board, UnitID passenger, CarrierLocation carrier) -> OrksDisembarkSelection:
    return orks_disembark_selection(board, passenger, carrier)

# Composition hook: transports adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_passenger_space(Unit unit) -> Int:
    return orks_passenger_space(unit)

# Composition hook: recovery adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_replacement_slot(Board board) -> Int:
    return orks_replacement_slot(board)

# Composition hook: recovery adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun resolve_faction_bank_returns(Board board) -> OrksBankReturns:
    return resolve_orks_bank_returns(board)

# Composition hook: recovery adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun repair_faction_vehicle(Board board, SourceInstance instance) -> OrksVehicleRepair:
    return repair_orks_vehicle(board, instance)

# Composition hook: recovery adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_command_healing(Board board, SourceInstance instance) -> OrksCommandHealing:
    return orks_command_healing(board, instance)

# Composition hook: psychic adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_offboard_support_available(Board board, SourceBank bank, Bool owner, Bool visions) -> Bool:
    return orks_offboard_support_available(board, bank, owner, visions)

# Composition hook: psychic adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun choose_faction_offboard_support(Board board, Bool owner, Bool visions) -> OrksOffboardSupportSelection:
    return choose_orks_offboard_support(board, owner, visions)

# Composition hook: psychic adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_offboard_dread_power_available(Board board, SourceBank bank, Bool owner) -> Bool:
    return orks_offboard_dread_power_available(board, bank, owner)

# Composition hook: psychic adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun choose_faction_offboard_dread_power(Board board, Bool owner) -> OrksOffboardDreadPower:
    return choose_orks_offboard_dread_power(board, owner)
