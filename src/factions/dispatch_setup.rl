import factions.orks.enhancements
import factions.orks.roster

# Neutral setup entrypoints. This composition module is the only layer
# that selects concrete faction behavior; core algorithms do not inspect it.

# Composition hook: roster adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun build_faction_roster(Board board, Bool owner) -> BuildOrksRoster:
    return build_orks_roster(board, owner)

# Composition hook: roster adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun make_faction_starter_roster(UnitVector out, Bool owner) -> Faction:
    return make_orks_starter_roster(out, owner)

# Composition hook: roster adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun select_faction_warlord(Board board, Bool player) -> SelectOrksWarlord:
    return select_orks_warlord(board, player)

# Composition hook: roster adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun register_faction_force_dispositions(Board board):
    register_orks_force_dispositions(board)

# Composition hook: roster adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_muster_copies_valid(Board board) -> Bool:
    return orks_muster_copies_valid(board)

# Composition hook: roster adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun select_faction_detachments(Board board, Bool detachment_player) -> SelectOrksDetachments:
    return select_orks_detachments(board, detachment_player)

# Composition hook: enhancements adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_enhancement_attachment_valid(Unit leader, Unit bodyguard) -> Bool:
    return orks_enhancement_attachment_valid(leader, bodyguard)

# Composition hook: enhancements adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun select_faction_options(Board board, Bool owner) -> SelectOrksOptions:
    return select_orks_options(board, owner)
