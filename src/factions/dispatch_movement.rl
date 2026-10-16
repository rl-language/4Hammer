import factions.orks.movement
import factions.orks.psychic
import factions.orks.queries
import factions.orks.recovery
import factions.orks.transports


# Movement/transport extension contract. UnitID indexes battlefield units
# unless the individual hook says otherwise; source event IDs index pending.
# Queries are pure. Policy/output arguments are caller-owned mutable references.
# Core owns staged placement, final geometry/coherency, bank transfers and phase
# order. Permissions alter only the stated gate. Frames borrow the live Board;
# peer-menu construction must not mutate it before an accepted input.
# See README.md for ownership, source identity and result lifetime conventions.

# Return permission for required_disembark_mode to offer Assault rather than
# Rapid after the carrier's qualifying Normal/Ingress move. The passenger may
# decline Assault; core applies that mode's exit/charge rules. False grants no
# mode exception and does not prohibit ordinary disembarkation.
fun faction_assault_disembark(Board board, Unit carrier_unit) -> Bool:
    return orks_assault_disembark(board, carrier_unit)

# Return an absolute Scouts allowance in inches, or a negative value to use
# core's printed-distance calculation. Nonnegative values replace that result;
# zero gives no Scouts movement. Check conditions/duplicate-value compatibility
# of the override here; core still validates placement and prebattle timing.
fun faction_scouts_override(Unit unit) -> Int:
    return orks_scouts_override(unit)

# Called by record_move after a movement kind is committed, never merely for
# staging/legality discovery. Record mode-specific restrictions/grants on this
# battlefield source with their required lifetimes. Preserve common history
# already recorded by core; unsupported kinds are a no-op.
fun faction_record_move_effects(Board board, UnitID id, MovementKind kind):
    orks_record_move_effects(board, id, kind)

# Report additional permission to select this special movement kind for unit.
# Return false for unsupported/inapplicable kinds. Core still checks ordinary
# battlefield eligibility and geometry; returning true must not roll distance,
# consume use or commit any movement effects.
fun faction_special_move_available(Board board, Unit unit, MovementKind kind) -> Bool:
    return orks_special_move_available(board, unit, kind)

# Adjust traversal policy after core initializes the movement-kind defaults
# and before common Walker/flight processing. Mutate policy only, for the given
# unit/kind; later core processing may override it. Do not grant a keyword,
# change positions or waive endpoint validation as a side effect.
fun faction_prepare_movement_policy(Unit unit, MovementKind kind, MovementGeometryPolicy policy):
    orks_prepare_movement_policy(unit, kind, policy)

# Apply final kind-specific traversal overrides after common movement policy
# and the prepare hook. Mutate only policy; no applicable override is a no-op.
# This changes path traversal/cost, not final overlap, board boundaries,
# engagement or coherency checks enforced by placement.
fun faction_finish_movement_policy(MovementKind kind, MovementGeometryPolicy policy):
    orks_finish_movement_policy(kind, policy)

# Read additional permission to charge after the selected movement kind.
# Core captures it in Advance/Fall-Back history and combines other permission
# sources; false grants no exception. Resolve applicability now, without changing
# history or treating this as complete later charge eligibility.
# Return an additional permission to reroll the common charge roll. Core ORs
# this with ordinary permissions, rerolls the complete pair before modifiers
# and enforces the one-reroll limit. Default false; no roll, payment, movement
# or source-use mutation may occur in this query.
# Record extension consequences of selecting kind on the battlefield source:
# capture action/shooting/charge waivers in selection history and install any
# selection-triggered grants. Called before placement, including fallback
# reaction handling; it must not record a completed move or change positions.
fun capture_faction_selected_move(Board board, UnitID source, MovementKind kind):
    capture_orks_selected_move(board, source, kind)

# Return whether additional live engagement conditions force unit's selected
# Fall Back to use Desperate Escape. Core queries this both for ordinary-retreat
# eligibility and after fallback reactions; it rechecks at that later boundary.
# Default false; core rolls hazards and applies resulting damage separately.
fun faction_forces_escape(Board board, Unit unit) -> Bool:
    return orks_forces_escape(board, unit)

# Return the nonnegative penalty subtracted from each ordinary Desperate
# Escape die, or zero. Core counts results <= 2 after this penalty as failures;
# it also applies this penalty to the extra batch. Do not return a roll count,
# change the unit's characteristics or resolve wounds here.
fun faction_escape_penalty(Board board, Unit unit) -> Int:
    return orks_escape_penalty(board, unit)

# Return the nonnegative number of additional Desperate Escape D6 rolls,
# or zero. Core rolls this separate batch, applies the escape penalty and its
# extra Battle-shock penalty, then resolves failed-roll mortal wounds normally.
# This query returns neither automatic failures nor a damage amount.
fun faction_extra_escape_hazards(Board board, Unit unit) -> Int:
    return orks_extra_escape_hazards(board, unit)

# Resolve optional source abilities when this battlefield unit is selected
# for Movement, before paid move-selection choices and mode selection. Check
# their own usage/targets and finish each nested effect. Return completed if
# none apply; finishing the menu must not consume ordinary movement by itself.
fun faction_movement_abilities(Board board, UnitID source) -> OrksMovementAbilities:
    return orks_movement_abilities(board, source)

# Resolve remaining extension effects after core has completed a successful
# charge and drained the ordered core/faction charge-effect menu. source is the
# charger, not necessarily any effect's recipient. Complete all nested choices/
# tests before returning; simultaneous menu effects belong in charge_choice.
fun faction_charge_finished(Board board, UnitID source) -> OrksWagonChargeEnd:
    return orks_wagon_charge_end(board, source)

# Called after source has been placed in its battlefield slot by reserve
# arrival. Record immediate arrival-triggered grants using its actual location,
# not stale reserve coordinates. Do not perform placement again or waive arrival
# eligibility; no applicable trigger is a no-op.
fun faction_after_reserve_arrival(Board board, UnitID source):
    orks_flyboss_ingress(board, source)

# Return whether this reserve unit passes the arrival-round gate at the
# current timing, including ordinary permitted rounds and any exceptions.
# This is the whole round-policy result, not just an extra permission; core
# separately validates entry capacity, eligibility and placement.
fun faction_ingress_round_allowed(Board board, Unit unit) -> Bool:
    return orks_ingress_round_allowed(board, unit)

# After both armies deploy, resolve permitted prebattle redeploy/withdrawal
# choices with their source limits and bank permissions. Core owns normal
# deployment order. Preserve model identity/history through moves, allocate
# only required new identities, and restore incoming decision ownership.
fun faction_prebattle_redeploy(Board board) -> OrksKaptinRedeploy:
    return orks_kaptin_redeploy(board)

# Resolve extension battle-formation choices before shared attachments and
# deployment. Splits/transfers must preserve model/equipment/use provenance and
# assign valid identities/component metadata to resulting units. Finish without
# inputs if unavailable; leave ordinary Leader selection to the next core step.
fun faction_prebattle_formations(Board board) -> OrksKommandoFormations:
    return orks_kommando_formations(board)

# Return the signed additive charge-roll contribution requiring Board context,
# in inches, or zero. Determine applicable sources and their stacking policy;
# exclude offboard measurements. Core combines the unit bonus and ordered roll
# modifiers, then applies charge and flight limits.
# Resolve permitted choices after actor is selected, before charge resolution
# or movement-mode selection. charging distinguishes those two call boundaries.
# Accepted choices own their CP/use and grants; they do not themselves commit
# movement. Complete nested effects and restore the caller's decision ownership.
fun faction_move_selection(Board board, UnitID actor, Bool charging) -> OrksMoveSelection:
    return orks_move_selection(board, actor, charging)

# Resolve extension choices after actor's Advance/Fall-Back kind is selected,
# before placement and selection-history capture. Record accepted permissions
# with their source lifetime; they waive only their specified gates. No applicable
# choice returns completed. This does not execute or complete the selected move.
fun faction_move_mode(Board board, UnitID actor, MovementKind kind) -> OrksMoveMode:
    return orks_move_mode(board, actor, kind)

# Resolve reactions to mover selecting Fall Back before the final forced-
# escape check and hazard rolls. mover is the falling-back battlefield unit;
# reaction payer/recipient can belong to its opponent. Commit accepted costs/
# effects and restore decision ownership; do not roll the core escape batch.
fun faction_fallback_selection(Board board, UnitID mover) -> OrksFallbackSelection:
    return orks_fallback_selection(board, mover)

# Validate pending[event] for player, including bounds, unresolved state,
# source generation/ownership/use and any required target existence. Return
# false when unavailable without changing the queue. This must match the
# resolver's accepted choices; a selectable event must have a completion path.
fun faction_movement_event_available(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> Bool:
    return orks_move_source_valid(board, pending, event, player)

# Report whether player has any selectable movement-source event using the
# same predicate as faction_movement_event_available. mandatory_only counts
# only nonoptional entries and controls core's finish gate. Include unhandled
# events supported by common commit; return false for an empty/exhausted queue.
fun faction_movement_events_remaining(Board board, PendingSourceEvents pending, Bool player, Bool mandatory_only) -> Bool:
    return orks_move_sources_remaining(board, pending, player, mandatory_only)

# Refresh/register cargo-dependent source metadata after completed embark
# transfers, using actual carrier/model/passenger identities across banks.
# Repeated calls must preserve source usage and avoid duplicate registrations.
# Core owns transport permissions, capacity and the bank transfer itself.
fun register_faction_cargo_passives(Board board):
    register_orks_cargo_passives(board)

# Append additional control for this exact scored marker and live carrier.
# Core calls only for an in-range friendly model in an unshocked unit; cargo
# contributes only where its rule permits. Pure; no distances from cargo and
# no objective/mission mutation (core pp52/64; appendix01.02.04).
fun append_objective_control_effects(Board board, Objective objective, Model carrier, Bool player, ObjectiveControlEffects effects):
    effects.additional_control = effects.additional_control.value + orks_bunka_passenger_control(board, objective, carrier, player)

# Resolve passenger options before disembark placement/decline. passenger
# indexes embarked_units; carrier is the already resolved CarrierLocation.
# Record accepted costs/grants at this boundary even if later exit is declined;
# keep that bank slot valid until core transfers it. Do not place passengers
# or complete a Movement activation on core's behalf.
fun faction_disembark_selection(Board board, UnitID passenger, CarrierLocation carrier) -> OrksDisembarkSelection:
    return orks_disembark_selection(board, passenger, carrier)

# During phase-retained cleanup, resolve extension casualty returns for reserve
# and embarked banks in core sequencing order, current player then opponent.
# Reuse common return/placement/damage procedures and restore decision ownership.
# Battlefield return windows are separate; preserve original model/weapon usage.
fun faction_pending_returns(Board board) -> OrksBankReturns:
    return resolve_orks_bank_returns(board)

# Resolve one accepted pending movement event for player against the original
# queue. Caller validated faction_movement_event_available; construction may
# index it immediately. Finish required targets/rolls/effects, commit required
# usage once, and mark the entry resolved while preserving other entries.
# Return decision ownership to player; core owns controller-group order.
fun faction_resolve_movement_source(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> OrksMovementSource:
    return orks_resolve_movement_source(board, pending, event, player)

# Peer menu beside ordinary move modes. Construction must leave Board
# unchanged; set started on first accepted input and complete the mode's dice/
# choices. Core reads kind/extra only after selection and completion, then places
# models through the shared movement procedure. extra must use that kind's
# model_move_budget convention: it may be an addition or an absolute allowance.
fun faction_special_move_choice(Board board, UnitID id) -> OrksSpecialMoveChoice:
    return orks_special_move_choice(board, id)

# Resolve choices needed before the common Advance die/reroll. May record
# temporary selected-move metadata, but must not roll the common die or commit
# placement. Finish without inputs when inapplicable; later policy/roll hooks
# can read this state and finish_faction_move_selection clears temporary state.
fun faction_prepare_advance(Board board, UnitID id) -> OrksPrepareAdvance:
    return orks_prepare_advance(board, id)

# After the common Advance die and rerolls, resolve permitted replacements
# or adjustments of current_roll.result before core computes move distance.
# Do not add M or separately returned distance bonuses here. Preserve roll
# history/ownership and leave the result unchanged when no exception is chosen.
fun faction_modify_advance_roll(Board board, UnitID id) -> OrksModifyAdvanceRoll:
    return orks_modify_advance_roll(board, id)

# Return additional signed Advance distance in inches, or zero. Core adds
# this after the final Advance die result; it does not change printed/effective
# M or replace the die. No movement, use consumption or grant installation
# may occur while evaluating this contribution.
# Clear temporary extension selection state after the movement attempt,
# including failed/cancelled placement. Preserve captured selection history and
# effects whose explicit duration continues. Do not undo paid choices, move
# models again or erase common completion/history flags.
fun finish_faction_move_selection(Board board, UnitID id):
    orks_finish_move_selection(board, id)

# After a completed nonstationary move, resolve extension follow-up reactions
# before core's optional embarkation. Complete each nested action using shared
# procedures, preserving caller context and valid identities through bank/death
# changes. Do not re-enter an already active shared Move/Attack frame.
fun faction_after_move(Board board, UnitID id) -> OrksAfterMove:
    return orks_after_move(board, id)

# Peer menu beside core Movement-phase activations. Construct without Board
# mutation, even when no input is enabled. Set started on acceptance, then
# finish the selected atomic ability before core reopens the phase menu.
# Resolve bank selectors against the actual source; do not finish the core phase.
fun faction_movement_phase_choice(Board board) -> OrksMovementPhaseChoice:
    return orks_movement_phase_choice(board)

# Return the signed additive unit-local charge-roll contribution in inches,
# or zero, based on the supplied unit's current eligible sources. Core adds
# Board-dependent aura contributions and applies modifier order/caps. This is
# not final charge distance and must not consume a charge or roll.
# Adjust charge path traversal policy using the original unit rather than
# staged positions. Mutate only policy and preserve higher-priority common
# permissions where required. Core retains total distance, target engagement,
# final overlap/coherency and board-boundary validation.
fun faction_charge_traversal(Unit original, MovementGeometryPolicy policy):
    orks_charge_traversal(original, policy)

# Report whether destroyed_models[archive] has an unresolved extension return
# that requires its unit's original slot. archive is an archived-model selector.
# replacement_slot uses true to prevent recycling that UNIT's retired battlefield
# slot. No roll or revival occurs here; false adds no reservation.
fun faction_casualty_has_pending_return(Board board, Unit unit, ModelID archive) -> Bool:
    return orks_surly_casualty_valid(board, unit, archive)

# Reset extension-owned per-unit transient/usage state on a NEW replacement
# working copy, whose unit identity is already fresh. Core owns common history,
# model restoration and subsequent component/model identity remapping. Do not
# use this reset for ordinary revival or mutate the original roster unit.
fun prepare_faction_replacement_unit(Unit unit):
    prepare_orks_replacement_unit(unit)

# Prepare extension metadata on a NEW replacement model after core assigns
# its fresh identity/original component. replacement is the new containing-unit
# identity. Remap persistent option provenance and clear transient effects
# without overwriting core identities; ordinary returned casualties skip this.
fun prepare_faction_replacement_model(Model model, EntityIdentity replacement):
    prepare_orks_replacement_model(model, replacement)

# Waive only Desperate Escape hazards for this actual Fall Back; never grants
# shooting at an engaged target or waives a separate forced-escape rule.
# Core still applies Battle-shock and ordinary move legality (core p33).
fun permits_escape_without_hazards(Board board, Unit unit) -> Bool:
    return orks_engaged_only_fortifications(board, unit)

# Append unit-local charge terms; no Board/range query is possible in this
# overload. Preserve earlier operations; core applies ordering and the12 cap.
# Pure and repeatable (core p37; supplied appendix02.02.01).
fun append_charge_roll_effects(Unit unit, ChargeRollEffects effects):
    append_orks_charge_roll_effects(unit, effects)

# Board-aware charge calculation includes applicable live external sources.
# Core supplies an initialized accumulator; no dice/CP/use/state changes.
# A reroll permission does not bypass the one-reroll rule (core pp16/37).
fun append_charge_roll_effects(Board board, Unit unit, ChargeRollEffects effects):
    append_orks_charge_roll_effects(board, unit, effects)

# Advance has its own roll boundary and output. Contributions are evaluated
# before rerolls and refreshed after accepted roll-stage effects; core applies
# their arithmetic after rerolls (core p32; appendix02.02.01).
fun append_advance_roll_effects(Board board, Unit unit, AdvanceRollEffects effects):
    append_orks_advance_roll_effects(board, unit, effects)

# Calculate only waivers associated with this selected movement kind. Core
# captures them in history at selection; later source changes cannot rewrite
# that event. No grants, costs or movement are committed here (pp32-33/36/58).
fun append_selected_move_permissions(Board board, Unit unit, MovementKind kind, SelectedMovePermissions permissions):
    append_orks_selected_move_permissions(board, unit, kind, permissions)
