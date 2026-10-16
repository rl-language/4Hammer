import factions.orks.army
import factions.orks.effects
import factions.orks.queries
import factions.orks.sources

# Validate bounded Orks effects/enhancement handles on save load; infrastructure, not another tabletop restriction.
fun faction_model_state_valid(Model model) -> Bool:
    return orks_model_state_valid(model)

# Validate bounded Orks psychic usage on save load; generic Psyker level validation remains core.
fun faction_unit_state_valid(Unit unit) -> Bool:
    return orks_unit_state_valid(unit)

# Orks typed/riled grants share generic source handles and expiry (Waaagh!/01.02.02).
fun faction_install_source_grant(Model model, SourceGrant installed, SourceEffectKey key):
    orks_install_source_grant(model, installed, key)

# Remove only the matching Orks effect/riled key, including archived models (01.02.02; core p88).
fun faction_remove_source_grant(Model model, SourceEffectKey key):
    orks_remove_source_grant(model, key)

# Validate faction typed source payloads before loading/dispatch; generic arithmetic validation stays core.
fun faction_source_grant_valid(SourceGrant grant) -> Bool:
    return orks_source_grant_valid(grant)

# Returned members inherit only missing faction-owned grant keys (core p88/01.02.02).
fun faction_model_has_source_grant(Model model, SourceEffectKey key) -> Bool:
    return orks_model_has_source_grant(model, key)

# Restored faction grants must refer to their real source recipients; preserve existing handle validation.
fun faction_model_source_handles_valid(Board board, Model model) -> Bool:
    return orks_model_source_handles_valid(board, model)

# Composition hook: sources adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun register_faction_option_passives(Board board):
    register_orks_option_passives(board)

# Composition hook: sources adapter owns eligibility and its cited rule; contexts and source identity are preserved.
# Composition hook: sources adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_source_event_available(Board board, SourceInstance instance, SourceEvent event) -> Bool:
    return orks_source_event_available(board, instance, event)

# Composition hook: sources adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun register_faction_datasheet_sources(Board board):
    register_orks_datasheet_sources(board)

# Composition hook: army adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun register_faction_passive_rules(Board board):
    register_orks_passive_rules(board)

# Composition hook: army adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun valid_faction_army_state(Board board) -> Bool:
    return valid_orks_army_state(board)

# Composition hook: army adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_advance_reroll(Unit unit) -> Bool:
    return unit_has_waaagh(unit)

# Composition hook: army adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_advance_charge_status(Unit unit) -> Bool:
    return unit_is_riled_up(unit)

# Route the originating source ability, preserving pending generation/use checks and controller ordering.
fun faction_resolve_timing_source(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> OrksTimingSource:
    return orks_resolve_timing_source(board, pending, event, player)

# Return one faction alternative action; core retains simultaneous interleaving and finish gates.
# Both alternatives use the same original timing contexts; the selected child
# completes before the next simultaneous choice (user Rules Sequencing).
fun faction_timing_choice(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, TimingWindow window, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, window, player)

# Orks mandatory/optional timing availability; core owns controller grouping (user Rules Sequencing).
fun faction_timing_options_remaining(Board board, TimingWindow window, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, window, player, progress, mandatory_only)

# Faction-local timing progress uses generated initialization; no custom lifecycle.
fun reset_faction_timing_progress(FactionTimingProgress progress):
    orks_reset_timing_progress(progress)
