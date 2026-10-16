import factions.orks.army
import factions.orks.effects
import factions.orks.queries
import factions.orks.sources

# Source lifecycle and timing contracts. SourceEventID indexes the supplied
# pending queue, not a unit bank. EntityIdentity and SourceEffectKey are stable
# identities; bank slots are not. Core owns generic grants/expiry/usage checks,
# while these hooks interpret faction payloads and named trigger policy.
# Returned frames borrow the real Board/queue/progress contexts; constructing a
# frame executes until its first input and can already change shared state.
# Concrete rules/citations: orks/{sources,army,effects}.rl and the Orks cards at
# https://wahapedia.ru/wh40k11ed/factions/orks/; persistence: appendix01.02.02.

# Validate bounds of private enhancement, upgrade-origin and riled-source
# fields on save/load. This is representation integrity, not tabletop legality;
# actual recipient/source relationships are checked by the handle hook below.
fun faction_model_state_valid(Model model) -> Bool:
    return orks_model_state_valid(model)

# Validate private psychic usage/budget stamps and counters on save/load.
# Generic Psyker level and other common unit state remain core responsibilities;
# passing this check alone does not mean a psychic ability is available.
fun faction_unit_state_valid(Unit unit) -> Bool:
    return orks_unit_state_valid(unit)

# Install only the faction extension of a committed grant: RiledUpGrant adds
# key to model.riled_source_effects. Unhandled payloads do nothing here; core
# installs common grant kinds. Caller owns deduplication and recipient choice.
fun faction_install_source_grant(Model model, SourceGrant installed, SourceEffectKey key):
    orks_install_source_grant(model, installed, key)

# Remove every riled-up entry with exactly key from this model, including an
# archived casualty passed by cleanup. Other source keys remain independent;
# core removes its own grant kinds separately (appendix01.02.02; core p88).
fun faction_remove_source_grant(Model model, SourceEffectKey key):
    orks_remove_source_grant(model, key)

# Recognize and validate a faction payload: currently an enabled RiledUpGrant.
# False also means an unhandled type, not rejection of every common payload;
# core combines this with validation of its generic SourceGrant alternatives.
fun faction_source_grant_valid(SourceGrant grant) -> Bool:
    return orks_source_grant_valid(grant)

# Test whether this model already holds the faction-owned grant key.
# Core ORs this with common grant stores to avoid reinstalling an existing
# grant on a returned model (core p88); no source is created or refreshed here.
fun faction_model_has_source_grant(Model model, SourceEffectKey key) -> Bool:
    return orks_model_has_source_grant(model, key)

# Check each stored riled-up key against its actual source recipient using
# core handle validation. Read-only save integrity check, not expiry cleanup;
# the common helper also defines acceptance of the zero-key sentinel.
fun faction_model_source_handles_valid(Board board, Model model) -> Bool:
    return orks_model_source_handles_valid(board, model)

# Register missing permanent enhancement passives from living bearers across
# battlefield, reserves and passengers. Repeated registration preserves source
# identity and spent uses (Follow Me Ladz, Ardboyz and Mekwaaagh options).
fun register_faction_option_passives(Board board):
    register_orks_option_passives(board)

# Apply named ability policy to a candidate instance/event after common
# source checks: required live ability, targets and selected-move constraints.
# Unhandled rule codes pass through; true alone does not commit the pending use.
fun faction_source_event_available(Board board, SourceInstance instance, SourceEvent event) -> Bool:
    return orks_source_event_available(board, instance, event)

# Discover/register datasheet triggers across all three unit banks using
# stable source identities and live-conferral metadata. Safe to revisit without
# resetting usage; common source code owns event generation and lifetime.
fun register_faction_datasheet_sources(Board board):
    register_orks_datasheet_sources(board)

# Register missing own-unit riled-up passives from explicit live bearer
# metadata across all banks (Super Runts/Waaagh! Effigy). Does not infer abilities
# from roster names; common source processing installs/removes their grants.
fun register_faction_passive_rules(Board board):
    register_orks_passive_rules(board)

# Validate Warlord identity/keyword ownership and War Cry metadata in saved
# state, including casualties/expired units. A dead Warlord remains identifiable;
# this is not a complete roster validator or a test that Da Boss can act now.
fun valid_faction_army_state(Board board) -> Bool:
    return valid_orks_army_state(board)

# Allow the unit's Waaagh! Advance re-roll. Read-only permission, not a riled-up
# test or a consumed reroll; core rolls the die, offers the choice and prevents
# a second reroll (Waaagh!; appendix01.05.02).
fun faction_advance_reroll(Unit unit) -> Bool:
    return unit_has_waaagh(unit)

# Read the riled-up permission to charge after Advance at move selection.
# Core captures this in movement history so later status changes do not alter
# the selected move's restrictions; this is not complete charge eligibility.
fun faction_advance_charge_status(Unit unit) -> Bool:
    return unit_is_riled_up(unit)

# Resolve one accepted pending timing event against its original queue.
# Adapter-specific rolls/targets/effects may mutate Board and mark the entry
# resolved/consume usage; unhandled rules use the common commit path.
fun faction_resolve_timing_source(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> OrksTimingSource:
    return orks_resolve_timing_source(board, pending, event, player)

# Offer one faction timing input beside the core peer menu. The returned
# frame sets started on acceptance; core must then finish that child before
# offering siblings. Borrow the original queue/progress, preserving controller
# order and common mandatory gates (user Rules Sequencing; Orks timing cards).
fun faction_timing_choice(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, TimingWindow window, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, window, player)

# Read whether this controller has a faction choice left in window, honoring
# progress and mandatory_only. Includes package rules and optional offboard
# Visions; false says nothing about unresolved common pending events.
fun faction_timing_options_remaining(Board board, TimingWindow window, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, window, player, progress, mandatory_only)

# Clear faction choice flags between controller groups in a timing window.
# Mutates only progress; it does not refresh source-use budgets, revoke grants
# or reset the shared pending queue (user Rules Sequencing).
fun reset_faction_timing_progress(FactionTimingProgress progress):
    orks_reset_timing_progress(progress)
