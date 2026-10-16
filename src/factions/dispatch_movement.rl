import factions.orks.movement
import factions.orks.psychic
import factions.orks.queries
import factions.orks.recovery
import factions.orks.transports

# Movement, setup and transport extension contracts. Unless explicitly stated,
# UnitID indexes battlefield units; disembark's passenger is an embarked-bank
# slot and source-event IDs index their supplied queue. Queries are read-only;
# policy/registration hooks mutate their named output or Board. Returned frames
# borrow shared contexts and may mutate Board during construction/resumption.
# Permissions waive only the named restriction; core retains endpoint legality,
# coherency, bank transfers and controller sequencing (core pp32-37/62-65).
# Concrete effects/citations: orks/{movement,queries,transports,recovery}.rl and
# https://wahapedia.ru/wh40k11ed/factions/orks/ (named cards/detachments).

# Grant the carrier's passengers a specific post-move charge exception
# (Assault Disembark/Gut Hatch). True is not general disembark permission;
# core still checks carrier movement, exit placement and other charge gates.
fun faction_assault_disembark(Board board, Unit carrier_unit) -> Bool:
    return orks_assault_disembark(board, carrier_unit)

# Return an absolute Scouts distance in inches, or -1 to use printed Scouts.
# Minefield Detail supplies 6in when eligible; combined printed Scouts must
# match that value, as required by the user's static-assert ruling.
fun faction_scouts_override(Unit unit) -> Int:
    return orks_scouts_override(unit)

# After a completed move, install mode-specific consequences on id.
# Pulse Jet records charge/action prohibitions and its defensive grant with
# their own durations; do not call for a merely staged/cancelled placement.
fun faction_record_move_effects(Board board, UnitID id, MovementKind kind):
    orks_record_move_effects(board, id, kind)

# Test whether a faction rule supplies the selected special movement kind.
# Currently Pulse Engine permits Pulse Jet; ordinary unit/movement legality
# is still checked separately before offering/accepting the choice.
fun faction_special_move_available(Board board, Unit unit, MovementKind kind) -> Bool:
    return orks_special_move_available(board, unit, kind)

# Adjust policy before ordinary traversal processing for this unit/mode.
# A selected Shokk-boosta Advance crosses enemy models without exclusions;
# it does not grant FLY, terrain traversal or legalize final overlap.
fun faction_prepare_movement_policy(Unit unit, MovementKind kind, MovementGeometryPolicy policy):
    orks_prepare_movement_policy(unit, kind, policy)

# Apply final mode overrides after ordinary movement policy is assembled.
# Pulse Jet crosses enemies/terrain with free vertical movement; common
# endpoint overlap, engagement and board constraints still apply.
fun faction_finish_movement_policy(MovementKind kind, MovementGeometryPolicy policy):
    orks_finish_movement_policy(kind, policy)

# Read an additional charge-after-Advance/Fall-Back permission for kind
# (Turbo Engine, Kult of Speed and applicable fallback options). False supplies
# no exception; core combines other permissions and captures selection history.
fun faction_move_charge_permission(Board board, Unit unit, MovementKind kind) -> Bool:
    return orks_move_charge_permission(board, unit, kind)

# Read a charge-roll reroll permission from Blitz Brigade Wagons or
# Competitive Streak. Does not roll, consume use or bypass charge eligibility;
# core handles the whole-roll reroll and one-reroll limit (appendix01.05.02).
fun faction_charge_reroll(Board board, Unit unit) -> Bool:
    return orks_charge_reroll(board, unit)

# Snapshot faction fallback charge/shooting and selected-move action waivers
# on the battlefield unit's history, and install selection-triggered grants.
# Call at mode selection, before effects can change; not after final placement.
fun capture_faction_selected_move(Board board, UnitID source, MovementKind kind):
    capture_orks_selected_move(board, source, kind)

# Test whether an actually engaged enemy forces this unit to take Desperate
# Escape when falling back (Wimp-kickaz/Hunt). No rolls or damage occur here;
# core combines this with ordinary fallback/escape conditions.
fun faction_forces_escape(Board board, Unit unit) -> Bool:
    return orks_forces_escape(board, unit)

# Return a nonnegative amount subtracted from each Desperate Escape die.
# Each engaged riled Wimp-kickaz source contributes 1; zero adds no penalty.
# Hunt's extra shocked penalty is applied separately by the core hazard batch.
fun faction_escape_penalty(Board board, Unit unit) -> Int:
    return orks_escape_penalty(board, unit)

# Return the number of extra Desperate Escape D6 rolls, not mortal wounds.
# An active Hunt trigger against Monster/Vehicle adds three per engaged Beast
# Snagga unit; core rolls and resolves failed-roll mortals (core p33).
fun faction_extra_escape_hazards(Board board, Unit unit) -> Int:
    return orks_extra_escape_hazards(board, unit)

# Offer optional unit-source abilities before its move selection, sharing
# their usage gates with the phase-wide menu. Resolves Watchin'/psychic Roar
# fully; finishing this menu neither moves the unit nor completes its activation.
fun faction_movement_abilities(Board board, UnitID source) -> OrksMovementAbilities:
    return orks_movement_abilities(board, source)

# Resolve remaining Wagon-specific charge-end effects after the shared
# ordered charge-effect menu. Returns the shock-test action for the completed
# charger; Mobbed/Impetus ordering is handled by separate combat hooks.
fun faction_charge_finished(Board board, UnitID source) -> OrksWagonChargeEnd:
    return orks_wagon_charge_end(board, source)

# After source is placed on the battlefield, apply its Flyboss ingress
# grants to eligible nearby allies using the actual new position. Mutates
# source grants; does not place the arriving unit or waive reserve restrictions.
fun faction_after_reserve_arrival(Board board, UnitID source):
    orks_flyboss_ingress(board, source)

# Return whether the reserve unit passes arrival-round policy, including
# ordinary later rounds and Deff from Shadows/Impulsive Recon exceptions.
# Does not authorize placement, eligibility or a second arrival (core pp62-63).
fun faction_ingress_round_allowed(Board board, Unit unit) -> Bool:
    return orks_ingress_round_allowed(board, unit)

# After both armies deploy, resolve Kaptin's Hat redeploy choices, including
# its permitted Strategic Reserves transfer. Owns the source's selection/use
# and restores decision ownership; core still owns ordinary deployment order.
fun faction_prebattle_redeploy(Board board) -> OrksKaptinRedeploy:
    return orks_kaptin_redeploy(board)

# Resolve Kommando prebattle split choices before ordinary attachments.
# Changes unit/component membership with stable model/equipment provenance;
# does not perform battlefield movement or general Leader selection.
fun faction_prebattle_formations(Board board) -> OrksKommandoFormations:
    return orks_kommando_formations(board)

# Return additive charge-roll inches from a nearby Thundering Stampede
# source: 1 if present, otherwise 0. Multiple qualifying sources do not stack
# this aura; core combines distinct bonuses and applies the charge-roll cap.
fun faction_charge_aura_bonus(Board board, Unit unit) -> Int:
    return orks_stampede_charge_bonus(board, unit)

# Offer paid/source choices once actor is selected, before move-mode/charge
# resolution. charging selects the appropriate menu; accepted choices can
# spend CP and install movement effects before any placement is attempted.
fun faction_move_selection(Board board, UnitID actor, Bool charging) -> OrksMoveSelection:
    return orks_move_selection(board, actor, charging)

# Offer choices tied to the already chosen movement kind, before placement.
# Mind Mostly overrides the selected Advance/Fall-Back action restriction;
# it does not waive all action gates or perform the move.
fun faction_move_mode(Board board, UnitID actor, MovementKind kind) -> OrksMoveMode:
    return orks_move_mode(board, actor, kind)

# Offer the opponent's Hunt reaction to mover selecting Fall Back.
# The qualifying enemy pays/receives the effect, not mover; the child completes
# that choice and restores decision owner before ordinary escape rolls.
fun faction_fallback_selection(Board board, UnitID mover) -> OrksFallbackSelection:
    return orks_fallback_selection(board, mover)

# Read whether pending[event] is selectable by player now: generation,
# source usage/ownership and ability-specific target existence all matter.
# Does not consume or resolve the queue entry; event is not a UnitID.
fun faction_movement_event_available(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> Bool:
    return orks_move_source_valid(board, pending, event, player)

# Scan the same movement-source queue/eligibility policy for this controller,
# optionally counting only mandatory entries. Used for finish gates; includes
# common source fallback paths, not just explicitly named faction effects.
fun faction_movement_events_remaining(Board board, PendingSourceEvents pending, Bool player, Bool mandatory_only) -> Bool:
    return orks_move_sources_remaining(board, pending, player, mandatory_only)

# Refresh cargo-dependent sources from actual carrier/passenger identities
# and re-register affected datasheet sources. Mutates Board source metadata;
# does not replace common transport permission/capacity/seat calculations.
fun register_faction_cargo_passives(Board board):
    register_orks_cargo_passives(board)

# Return extra OC contributed through this carrier, not the carrier's total
# OC. Raucous/Bossbunka checks passengers and the owner's home objective;
# no distance/visibility is measured from an embarked unit (core p54/01.02.04).
fun faction_passenger_objective_control(Board board, Model carrier, Bool player) -> Int:
    return orks_bunka_passenger_control(board, carrier, player)

# Run passenger-owned Idol/Beastscent choices before exit placement.
# passenger indexes embarked_units; carrier identifies the actual carrier bank.
# Accepted grants can persist if placement is cancelled; this child neither
# compacts the passenger bank nor completes a Movement activation (core p64).
fun faction_disembark_selection(Board board, UnitID passenger, CarrierLocation carrier) -> OrksDisembarkSelection:
    return orks_disembark_selection(board, passenger, carrier)

# Resolve eligible Surly casualties in reserves and embarked units at phase
# cleanup, current player then opponent, using the shared return procedure.
# Battlefield returns have a separate entrypoint; this is not a generic bank move.
fun faction_pending_returns(Board board) -> OrksBankReturns:
    return resolve_orks_bank_returns(board)

# Resolve one accepted event against the original pending queue, marking
# resolution/usage and executing its rolls, targets or damage. Handles named
# movement abilities, falling back to common commit for unhandled source rules.
fun faction_resolve_movement_source(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> OrksMovementSource:
    return orks_resolve_movement_source(board, pending, event, player)

# Peer alternative to ordinary move modes: started becomes true only on an
# accepted input. On completion, kind selects the mode and extra is its budget
# (Pulse Jet D6+18 inches, not M plus that value); core then performs placement.
fun faction_special_move_choice(Board board, UnitID id) -> OrksSpecialMoveChoice:
    return orks_special_move_choice(board, id)

# Offer Shokk-boosta before the common Advance die/reroll. Accepting sets
# selected-move metadata, not a rolled distance; subsequent policy/roll hooks
# read it and finish_faction_move_selection clears it after the attempt.
fun faction_prepare_advance(Board board, UnitID id) -> OrksPrepareAdvance:
    return orks_prepare_advance(board, id)

# After ordinary Advance rerolls, offer supported replacements of the die
# result (Shokk-boosta/Unstoppable Momentum). Mutates current_roll.result;
# core adds M and separate distance bonuses afterwards.
fun faction_modify_advance_roll(Board board, UnitID id) -> OrksModifyAdvanceRoll:
    return orks_modify_advance_roll(board, id)

# Return additional Advance distance in inches: Fuel Mixa Grot and the
# source-owned Advance+2 effect. This is neither an M change nor replacement
# of the common Advance die result (Orks cards).
fun faction_advance_distance_bonus(Board board, Unit unit) -> Int:
    return orks_advance_distance_bonus(board, unit)

# Clear the temporary Shokk-boosta selection after this placement attempt,
# including cancellation. Does not erase captured movement history or revoke
# longer-lived effects installed by a completed move.
fun finish_faction_move_selection(Board board, UnitID id):
    orks_finish_move_selection(board, id)

# After committed placement, finish Wagon effects, reactive Trukk exits and
# enemy move reactions before common optional embarkation. Borrow the live
# Board and finish the child before reusing shared movement frames.
fun faction_after_move(Board board, UnitID id) -> OrksAfterMove:
    return orks_after_move(board, id)

# Peer menu offering one faction Movement-phase activation beside core
# choices. started distinguishes the selected child; finish its atomic ability
# before returning to the phase menu. Bank adapters select the real source.
fun faction_movement_phase_choice(Board board) -> OrksMovementPhaseChoice:
    return orks_movement_phase_choice(board)

# Return additive unit charge-roll inches from Banner/Trophy Hunters.
# These distinct contributions can add together; core combines the aura/roll
# terms and applies the final charge cap (Orks Bannernob/Breaka-Boyz cards).
fun faction_unit_charge_bonus(Unit unit) -> Int:
    return orks_unit_charge_bonus(unit)

# Adjust only traversal policy for Get Out da Way, using the original unit:
# allow crossing enemies except Monster/Vehicle. Does not alter final charge
# target, overlap, engagement or coherency requirements (Nobz; core pp36-37).
fun faction_charge_traversal(Unit original, MovementGeometryPolicy policy):
    orks_charge_traversal(original, policy)

# Test whether destroyed_models[archive] in this unit still has a Surly
# return pending; archive is not a live model slot. Core preserves its old slot
# accordingly. True promises neither a successful roll nor legal return placement.
fun faction_casualty_has_pending_return(Board board, Unit unit, ModelID archive) -> Bool:
    return orks_surly_casualty_valid(board, unit, archive)

# Clear private per-unit psychic usage when core constructs a NEW unit.
# Fresh identities, common history and bank insertion belong to the shared
# replacement constructor; ordinary resurrection must retain its original unit.
fun prepare_faction_replacement_unit(Unit unit):
    prepare_orks_replacement_unit(unit)

# Reset private riled-up/upgrade-origin metadata for a NEW replacement model.
# Preserve core's newly assigned original-component mapping; replacement is
# the fresh unit identity. Does not reset an ordinary returned casualty.
fun prepare_faction_replacement_model(Model model, EntityIdentity replacement):
    prepare_orks_replacement_model(model, replacement)
