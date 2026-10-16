import factions.orks.army
import factions.orks.effects
import factions.orks.queries
import factions.orks.sources

# Calculation/event-specific contracts for any army implementation. Queries
# are pure; appenders mutate only their initialized output. Actions borrow
# original contexts, finish accepted work atomically and restore controller
# ownership. Core owns common mechanics, sequencing and frame lifetime.
# See README.md and doc/army-api.md; named rule citations belong in adapters.

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
