import factions.orks.detachments
import factions.orks.queries
import factions.orks.stratagems

# Additional permission/veto contracts; true is not complete action legality.
# All hooks here are read-only. Core retains phase, ownership, CP, usage and
# ordinary geometry checks unless the particular hook explicitly overrides one.
# Concrete rules/citations: orks/{queries,stratagems,detachments}.rl and
# https://wahapedia.ru/wh40k11ed/factions/orks/.

# Veto Hidden while Burna Mark applies. True only allows the ordinary Hidden
# calculation to proceed; it does not establish terrain/obscuration conditions
# or make an offboard unit visible (Burna-Bommer card).
fun faction_hidden_allowed(Board board, Unit unit) -> Bool:
    return orks_hidden_allowed(board, unit)

# Return signed inches added to detection range against target: Found Em
# increases it, Extra Sneaky reduces it. Core combines this with other terms
# and clamps the final range to 9-30in (appendix Modifiers).
fun faction_detection_modifier(Board board, Unit target) -> Int:
    return orks_detection_modifier(board, target)

# Check that player selected the package supplying this stratagem. Cards
# without an Orks package pass through; this does not authorize their target,
# timing or payment (Orks detachment Stratagem sections).
fun faction_stratagem_selected(Board board, Bool player, Stratagem strat) -> Bool:
    return orks_stratagem_selected(board, player, strat)

# Apply faction-specific target vetoes after ordinary stratagem checks.
# Currently an Overwatch-blocked effect forbids that card; true supplies no
# phase, affordability or Battle-shock exception (Orks cards).
fun faction_stratagem_target_allowed(Board board, Bool player, Stratagem strat, Unit target) -> Bool:
    return orks_stratagem_target_allowed(board, player, strat, target)

# Require a friendly recipient for Orks package cards. Unassociated core
# cards pass this filter and retain their own target-owner policy; player is
# the payer/controller, not necessarily Board.current_player.
fun faction_stratagem_owner_allowed(Stratagem strat, Unit target, Bool player) -> Bool:
    return orks_stratagem_owner_allowed(strat, target, player)

# Validate provenance of an already attached model's faction conversion.
# A Painboss's Mounted marker must trace to a recorded Painboss component;
# this checks saved attachment integrity, not permission to choose a bodyguard.
fun faction_attachment_origin_valid(Unit unit, Model model) -> Bool:
    return orks_attachment_origin_valid(unit, model)

# Return an absolute nonnegative CP cost, not a discount or sentinel.
# Tramplasquig Charge reduces Crushing Impact by 1; other cards keep base cost.
# Core uses this same amount for affordability/payment and still records use.
fun faction_datasheet_stratagem_cost(Stratagem card, Unit unit) -> Int:
    return orks_datasheet_stratagem_cost(card, unit)

# Add a whole-unit ability permission without changing model-local abilities.
# Currently Nazdreg's Know-wotz/Tellyporta Boss grant Deep Strike subject to
# their live-source/unit restrictions; false leaves other ability sources intact.
fun faction_unit_grants_ability(Unit unit, AbilityKind kind) -> Bool:
    return orks_unit_grants_ability(unit, kind)

# Never Too Busy waives only the action's engagement restriction (Boyz card).
# True does not bypass shock, OC, movement, shooting or once-per-turn gates;
# the common action validator owns those remaining checks (core p58).
fun faction_action_while_engaged(Unit unit) -> Bool:
    return orks_action_while_engaged(unit)
