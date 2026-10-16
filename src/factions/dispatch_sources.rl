import factions.orks.army
import factions.orks.effects
import factions.orks.queries
import factions.orks.sources


# Source lifecycle and timing contract. SourceEventID indexes the supplied
# pending queue, never a unit bank. SourceEffectKey/EntityIdentity are stable
# handles. Queries are pure; lifecycle commands mutate only the stated extension
# storage. Registration must tolerate repeated calls without resetting uses.
# Core owns common grant kinds, source identity/expiry and controller groups.
# Action frames borrow the original contexts; peer construction is side-effect
# free until input. See README.md for result and context lifetime conventions.

# Validate the ranges and internal consistency of extension-owned model data,
# including archived models passed by core save validation. Return true if no
# extension invariant is violated. Do not repair state, register effects or
# require that the model is alive; cross-source handles have a separate hook.
fun faction_model_state_valid(Model model) -> Bool:
    return orks_model_state_valid(model)

# Validate extension-owned counters/stamps and other unit metadata when core
# validates stored state. Return true if there are no additional constraints.
# This is not an ability-availability check: offboard and destroyed units can
# retain valid usage history. Leave shared unit validation and state unchanged.
fun faction_unit_state_valid(Unit unit) -> Bool:
    return orks_unit_state_valid(unit)

# Install extension-owned parts of installed on model under exactly key.
# Unhandled/common payload kinds are a no-op; core installs their common parts.
# Caller chooses recipients and avoids duplicate installation. Do not create
# another source, spend usage, change lifetime or update unrelated recipients.
fun faction_install_source_grant(Model model, SourceGrant installed, SourceEffectKey key):
    orks_install_source_grant(model, installed, key)

# Remove every extension-owned grant matching exactly key from this model.
# Core calls this during cleanup for current and archived recipients, and removes
# common grant kinds separately. Missing keys are a no-op; overlapping grants
# with different keys must survive. Do not erase intrinsic data or whole sources.
fun faction_remove_source_grant(Model model, SourceEffectKey key):
    orks_remove_source_grant(model, key)

# Recognize and validate an extension-owned SourceGrant alternative. Return
# false for an unhandled alternative as well as an invalid payload; core ORs
# this result with validation of its common alternatives. This is pure type/
# payload validation, not recipient selection or permission to apply an effect.
fun faction_source_grant_valid(SourceGrant grant) -> Bool:
    return orks_source_grant_valid(grant)

# Return whether model already holds an extension grant under key. Core ORs
# this with common grant stores when refreshing recipients, including returned
# models, to avoid duplicate installation. Return false when absent; do not
# refresh lifetime, install the missing grant or infer it merely from its source.
fun faction_model_has_source_grant(Model model, SourceEffectKey key) -> Bool:
    return orks_model_has_source_grant(model, key)

# Validate extension-owned grant keys against Board's source-effect records
# and actual recipient identities. Core validates common stores separately.
# Follow source_handle_matches_model: zero is an unsourced grant; nonzero keys
# must name an effect recording this model. Validate only; do not expire/repair.
fun faction_model_source_handles_valid(Board board, Model model) -> Bool:
    return orks_model_source_handles_valid(board, model)

# Register source instances supplied by selected roster options across all
# unit banks, using their real bearer/component provenance. Repeated calls must
# reuse existing registrations without resetting usage or duplicating grants.
# Core source refresh owns installing, expiring and extending recipient effects.
fun register_faction_option_passives(Board board):
    register_orks_option_passives(board)

# Apply extra rule-specific eligibility to instance/event within core's
# source_event_available checks. Return true for unhandled rules to defer;
# false vetoes this event. Check any extra target-existence/source conditions
# without consuming use; core checks remaining location/range/lifetime gates.
fun faction_source_event_available(Board board, SourceInstance instance, SourceEvent event) -> Bool:
    return orks_source_event_available(board, instance, event)

# Register missing triggers described by model/unit datasheet metadata in
# all banks. Repeated setup and timing/movement calls must preserve registration
# identity and usage. Registered metadata must allow later availability checks
# to reject lost conferring sources; do not resolve their triggered abilities.
fun register_faction_datasheet_sources(Board board):
    register_orks_datasheet_sources(board)

# Register source instances for continuously conferred army/datasheet passives
# across all banks, with explicit recipient, live-source and offboard policy.
# Repeated registration must preserve source identity/usage. Common source
# refresh applies these passives; registration itself is not a fresh activation.
fun register_faction_passive_rules(Board board):
    register_orks_passive_rules(board)

# Validate additional army-level state/provenance during core save validation,
# including identities whose models have died or changed banks. Return true
# where no extra invariant applies. Distinguish legal retained history from
# current activation eligibility; do not rewrite the roster or refresh usage.
fun valid_faction_army_state(Board board) -> Bool:
    return valid_orks_army_state(board)

# Return whether unit has an additional permission to reroll its Advance die
# at the common Advance-roll boundary. Core offers/executes the reroll before
# modifiers and enforces the one-reroll limit. False grants no permission;
# this query must not roll, spend or alter the selected movement kind.
fun faction_advance_reroll(Unit unit) -> Bool:
    return unit_has_waaagh(unit)

# Read a unit-local permission to charge after selecting Advance. Core ORs
# this with faction_move_charge_permission and captures the result before the
# Advance roll. Return false if absent; later status changes must not rewrite
# that captured permission. This is not complete charge-source eligibility.
fun faction_advance_charge_status(Unit unit) -> Bool:
    return unit_is_riled_up(unit)

# Resolve one accepted timing event for player against the original pending
# queue. Caller checked pending_source_valid; construction may index the event
# immediately. Complete its required choices/effects and mark that entry resolved,
# committing required usage once. Preserve other entries and return control to
# player; core owns controller ordering and the surrounding timing window.
fun faction_resolve_timing_source(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> OrksTimingSource:
    return orks_resolve_timing_source(board, pending, event, player)

# Offer one extension timing choice alongside the core peer for this window/
# player. Construction must not mutate Board, queues or progress. Set started
# immediately after accepting the first input; then complete that effect and
# update its own progress before returning. Borrow the original contexts; core
# owns controller groups, mandatory finish gates and core_progress decisions.
fun faction_timing_choice(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, TimingWindow window, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, window, player)

# Report whether player has an unresolved extension choice in window, using
# the same eligibility/progress policy as the timing peer. mandatory_only filters
# out optional choices and controls core's finish gate. Default false; generic
# pending source events and common timing choices are counted separately.
fun faction_timing_options_remaining(Board board, TimingWindow window, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, window, player, progress, mandatory_only)

# Reset only the adapter-owned per-controller timing-choice progress before
# core starts that controller's group. Do not refresh army/source usage, remove
# effects or reset the pending queue. Subsequent availability and choice hooks
# must interpret the same reset record consistently.
fun reset_faction_timing_progress(FactionTimingProgress progress):
    orks_reset_timing_progress(progress)
