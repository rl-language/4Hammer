import factions.orks.movement
import factions.orks.psychic
import factions.orks.queries
import factions.orks.recovery
import factions.orks.transports

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
fun faction_charge_finished(Board board, UnitID source) -> OrksWagonChargeEnd:
    return orks_wagon_charge_end(board, source)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_after_reserve_arrival(Board board, UnitID source):
    orks_flyboss_ingress(board, source)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_ingress_round_allowed(Board board, Unit unit) -> Bool:
    return orks_ingress_round_allowed(board, unit)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_prebattle_redeploy(Board board) -> OrksKaptinRedeploy:
    return orks_kaptin_redeploy(board)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_prebattle_formations(Board board) -> OrksKommandoFormations:
    return orks_kommando_formations(board)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_charge_aura_bonus(Board board, Unit unit) -> Int:
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
fun faction_movement_event_available(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> Bool:
    return orks_move_source_valid(board, pending, event, player)

# Composition hook: movement adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_movement_events_remaining(Board board, PendingSourceEvents pending, Bool player, Bool mandatory_only) -> Bool:
    return orks_move_sources_remaining(board, pending, player, mandatory_only)

# Composition hook: transports adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun register_faction_cargo_passives(Board board):
    register_orks_cargo_passives(board)

# Composition hook: transports adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_passenger_objective_control(Board board, Model carrier, Bool player) -> Int:
    return orks_bunka_passenger_control(board, carrier, player)

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
fun faction_pending_returns(Board board) -> OrksBankReturns:
    return resolve_orks_bank_returns(board)

# Delegate one accepted source; ctx pending is the original controller queue, not a copy.
fun faction_resolve_movement_source(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> OrksMovementSource:
    return orks_resolve_movement_source(board, pending, event, player)

# Faction special modes remain alternatives to ordinary core moves, without a new selector input.
fun faction_special_move_choice(Board board, UnitID id) -> OrksSpecialMoveChoice:
    return orks_special_move_choice(board, id)

# Faction choices made before rolling Advance; shared reroll arithmetic remains core.
fun faction_prepare_advance(Board board, UnitID id) -> OrksPrepareAdvance:
    return orks_prepare_advance(board, id)

# Faction roll replacements occur after ordinary Advance/rerolls and before distance contributions.
fun faction_modify_advance_roll(Board board, UnitID id) -> OrksModifyAdvanceRoll:
    return orks_modify_advance_roll(board, id)

# Fuel Mixa Grot and source-owned Advance+2 contribute without replacing the shared roll (Orks cards).
fun faction_advance_distance_bonus(Board board, Unit unit) -> Int:
    return orks_advance_distance_bonus(board, unit)

# End source-owned selected-move permissions after its placement attempt.
fun finish_faction_move_selection(Board board, UnitID id):
    orks_finish_move_selection(board, id)

# Delegate complete faction move-end reactions before the common optional embarkation window.
fun faction_after_move(Board board, UnitID id) -> OrksAfterMove:
    return orks_after_move(board, id)

# Offer one faction Movement-phase ability alongside core choices; no preliminary faction input.
fun faction_movement_phase_choice(Board board) -> OrksMovementPhaseChoice:
    return orks_movement_phase_choice(board)

# Banner/Trophy Hunters add their distinct unit-wide charge contributions (Orks/Bannernob/Breaka-Boyz).
fun faction_unit_charge_bonus(Unit unit) -> Int:
    return orks_unit_charge_bonus(unit)

# Get Out da Way permits charge traversal only; common final overlap/engagement checks remain mandatory (Orks/Nobz).
fun faction_charge_traversal(Unit original, MovementGeometryPolicy policy):
    orks_charge_traversal(original, policy)
