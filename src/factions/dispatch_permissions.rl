import factions.orks.detachments
import factions.orks.queries
import factions.orks.stratagems

# Orks transport passenger faction/type and Ghazghkull restrictions (Orks transport cards; core p64).
# Burna Mark prevents Hidden (Orks/Burna-Bommer).
fun faction_hidden_allowed(Board board, Unit unit) -> Bool:
    return orks_hidden_allowed(board, unit)

# Found Em and Extra Sneaky change detection range; core applies its shared9-30in cap (Orks cards).
fun faction_detection_modifier(Board board, Unit target) -> Int:
    return orks_detection_modifier(board, target)

# Source-owned no_charge restriction; core retains ordinary eligibility and expiry (Orks Pulse Jet/psychic cards).
# Source-owned no_action restriction; core retains ordinary eligibility and expiry (Orks Pulse Jet/psychic cards).
# Source-owned grounded restriction; core retains ordinary eligibility and expiry (Orks Pulse Jet/psychic cards).
# Only selected Orks packages grant their support cards; unassociated core cards pass through (Orks detachment sections).
fun faction_stratagem_selected(Board board, Bool player, Stratagem strat) -> Bool:
    return orks_stratagem_selected(board, player, strat)

# Named Orks effects forbid Overwatch on their target; core retains payment/shock/phase gates (Orks cards).
fun faction_stratagem_target_allowed(Board board, Bool player, Stratagem strat, Unit target) -> Bool:
    return orks_stratagem_target_allowed(board, player, strat, target)

# Orks support cards select friendly targets; generic core cards retain their own owner policy (Orks cards).
fun faction_stratagem_owner_allowed(Stratagem strat, Unit target, Bool player) -> Bool:
    return orks_stratagem_owner_allowed(strat, target, player)

# Only an attached Painboss may retain its bearer-specific Mounted conversion (Orks/Painboss).
fun faction_attachment_origin_valid(Unit unit, Model model) -> Bool:
    return orks_attachment_origin_valid(unit, model)

# Composition hook: stratagems adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_datasheet_stratagem_cost(Stratagem card, Unit unit) -> Int:
    return orks_datasheet_stratagem_cost(card, unit)

# Composition hook: detachments adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_unit_grants_ability(Unit unit, AbilityKind kind) -> Bool:
    return orks_unit_grants_ability(unit, kind)

# Never Too Busy waives only the engagement action gate (Orks/Boyz; core p58).
fun faction_action_while_engaged(Unit unit) -> Bool:
    return orks_action_while_engaged(unit)
