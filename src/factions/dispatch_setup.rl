import factions.orks.enhancements
import factions.orks.roster

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
fun faction_roster_copies_valid(Board board) -> Bool:
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

# Composition owns the existing faction/roster menu; shared battle order stays core.
act pick_army(ctx Board board, frm Bool current_player) -> PickFaction:
    board.current_decision_maker = current_player
    frm custom_orks = false
    actions:
        act pick_custom_orks()
        board.players_faction[int(current_player)] = Faction::morgrim_butchas
        custom_orks = true
        act pick_strike_force_octavious()
        board.players_faction[int(current_player)] = make_octavious_strike_force(board.reserve_units, current_player)
        act pick_insidious_infiltrators()
        board.players_faction[int(current_player)] = make_insidious_infiltrators(board.reserve_units, current_player)
        act pick_zarkan_deamonkin()
        board.players_faction[int(current_player)] = make_zarkan_deamonkin(board.reserve_units, current_player)
        act pick_morgrim_butcha()
        board.players_faction[int(current_player)] = make_faction_starter_roster(board.reserve_units, current_player)
        act pick_tristean_gilded_blade()
        board.players_faction[int(current_player)] = make_tristrean_gilded_blade(board.reserve_units, current_player)

        act pick_vengeful_brethren()
        board.players_faction[int(current_player)] = make_vengeful_brethren(board.reserve_units, current_player)

    board.armies[int(current_player)].faction = army_faction_for_roster(board.players_faction[int(current_player)])
    board.armies[int(current_player)].reserve_budget = ReserveBudgetMode::point_free
    board.identify_units()
    board.shared_actions.select_orks_detachments = select_faction_detachments(board, current_player)
    subaction*(board) board.shared_actions.select_orks_detachments
    if custom_orks:
        subaction*(board) roster = build_faction_roster(board, current_player)
    board.shared_actions.select_orks_options = select_faction_options(board, current_player)
    subaction*(board) board.shared_actions.select_orks_options
    board.shared_actions.select_orks_warlord = select_faction_warlord(board, current_player)
    subaction*(board) board.shared_actions.select_orks_warlord

# Only Orks select Orks detachments; finite catalog, duplicate and user maximum-three gates remain explicit (Orks index).
fun faction_detachment_selection_valid(ArmyConfiguration army, OrksDetachment detachment) -> Bool:
    return orks_detachment_selection_valid(army, detachment)

# Saved Orks detachments require the actual Orks army faction (roster integrity; core p8).
fun faction_army_configuration_valid(ArmyConfiguration army) -> Bool:
    return orks_army_configuration_valid(army)

# Legacy/current roster identity is composition data, independent of core phases.
fun army_faction_for_roster(Faction roster) -> ArmyFaction:
    if roster == Faction::insidious_infiltrators:
        return ArmyFaction::tyranids
    if roster == Faction::zarkan_daemonkin:
        return ArmyFaction::chaos_space_marines
    if roster == Faction::morgrim_butchas:
        return ArmyFaction::orks
    if roster == Faction::tristraen_gilded_blade:
        return ArmyFaction::adeptus_custodes
    return ArmyFaction::space_marines
