import factions.orks.enhancements
import factions.orks.roster


# Muster and setup composition contract. Core owns battle order, identity
# allocation and shared muster restrictions; adapters supply selectable content,
# extra eligibility and roster effects. Queries are pure. Setup actions borrow
# Board and operate on the supplied owner's reserve roster before formations/
# deployment. No army points or detachment-price calculation is requested.
# Concrete catalog/frame types remain current composition choices, not portable
# interface guarantees. See README.md and the contract review for limitations.

# Construct the chosen owner's custom reserve roster after detachment choice
# and before options/Warlord selection. Add/configure only that owner's units;
# enforce shared copy restrictions and finish only with a selectable legal
# roster. Core subsequently forms attachments and deploys; do not do either here.
fun build_faction_roster(Board board, Bool owner) -> BuildOrksRoster:
    return build_orks_roster(board, owner)

# Append the owner's predefined roster to out without clearing other entries;
# ensure capacity and assign ownership. Return its legacy Faction roster ID,
# not an ArmyFaction keyword. Caller sets army configuration and identifies
# models afterward. This constructs data and exposes no interactive decisions.
fun make_faction_starter_roster(UnitVector out, Bool owner) -> Faction:
    return make_orks_starter_roster(out, owner)

# Select the owner's Warlord from the completed reserve roster under shared
# Character/faction and required/prohibited rules. Store the chosen model's
# stable identity and keyword, never a mutable slot. Use the shared selection
# procedure; return completed without inputs where this adapter is not enabled.
fun select_faction_warlord(Board board, Bool player) -> SelectWarlord:
    return select_orks_warlord(board, player)

# Apply roster-wide keyword dispositions granted by the selected configuration
# to qualifying units across all banks. Preserve intrinsic keywords and make
# repeated calls safe. Core calls before and after formations; the pure
# faction_force_battleline query must predict the corresponding muster status.
fun register_faction_force_dispositions(Board board):
    register_orks_force_dispositions(board)

# Offer the permitted distinct detachments for detachment_player and write
# that army's configuration before roster options. Enforce selection validity
# and the configured maximum (currently three), provide a legal finish path,
# and skip unsupported armies. Do not deploy units or calculate detachment prices.
fun select_faction_detachments(Board board, Bool detachment_player) -> SelectOrksDetachments:
    return select_orks_detachments(board, detachment_player)

# Veto combining leader/bodyguard if their already selected options would
# violate option-recipient/attachment restrictions. Return true when compatible.
# Do not select/remove options or grant Leader/bodyguard permission; core
# checks the remaining attachment requirements and preserves original recipients.
fun faction_enhancement_attachment_valid(Unit leader, Unit bodyguard) -> Bool:
    return orks_enhancement_attachment_valid(leader, bodyguard)

# Choose legal enhancements/upgrades on owner's reserve roster after units
# and detachments, before attachments/Warlord selection. Enforce shared counts
# and recipient exclusions plus catalog eligibility; record bearer/component
# provenance and install chosen data. A finish/decline spends no battle resources.
fun select_faction_options(Board board, Bool owner) -> SelectOrksOptions:
    return select_orks_options(board, owner)

# Composition entrypoint used once per roster owner by full_game: choose the
# roster, set ArmyFaction and point-free reserve policy, identify units, then
# select detachments, custom roster when applicable, options and Warlord.
# current_player is this action's roster owner. Leave units in setup banks;
# core owns subsequent formations, attachments, deployment and battle turns.
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

# Validate one prospective detachment addition without modifying army.
# Check supported faction/catalog membership, duplicate exclusion and available
# selection capacity. Core calls this before append; validation of an already
# stored full configuration is a separate contract. The type is catalog-specific.
fun faction_detachment_selection_valid(ArmyConfiguration army, OrksDetachment detachment) -> Bool:
    return orks_detachment_selection_valid(army, detachment)

# Validate additional faction/catalog compatibility of stored army configuration
# as part of core save validation. Return true when no extra constraint applies.
# Core separately checks enum validity, duplicates and common configuration
# invariants; this predicate must not repair or change the selection.
fun faction_army_configuration_valid(ArmyConfiguration army) -> Bool:
    return orks_army_configuration_valid(army)

# Map a supported legacy roster ID to its ArmyFaction configuration value.
# Composition must define this mapping for each offered roster before core rules
# query army identity. This is catalog translation, not inference from models
# or validation of an arbitrary integer; caller supplies a supported roster.
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

# Predict whether selected configuration grants Battleline to unit before
# disposition metadata is installed. Core ORs this with ordinary membership
# when enforcing copy limits. Return false for no grant; do not change the
# unit, select a detachment or implement the copy-count algorithm here.
fun faction_force_battleline(Board board, Unit unit) -> Bool:
    return orks_force_battleline(board, unit)
