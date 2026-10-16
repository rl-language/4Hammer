import factions.orks.enhancements
import factions.orks.roster

# Army construction/composition contracts. Current interactive adapters build
# Orks; legacy roster identities remain composition data. Queries are read-only;
# returned setup frames can mutate Board as they initialize/resume. Core owns
# battle/deployment order, shared roster limits and common Warlord selection.
# Concrete eligibility/citations: orks/{roster,enhancements}.rl and the Orks
# Detachments/Datasheets at https://wahapedia.ru/wh40k11ed/factions/orks/.
# User policy omits points/detachment costs and permits at most three detachments.

# Run the custom Orks muster for owner: add/configure units in reserve_units,
# with finish gated by roster requirements including a Warlord candidate.
# Does not deploy or attach them; shared roster limits still apply.
fun build_faction_roster(Board board, Bool owner) -> BuildOrksRoster:
    return build_orks_roster(board, owner)

# Append the predefined starter units to out and assign owner; do not clear
# existing units. Return the legacy roster identifier used by composition,
# not the army's general faction enum (Orks starter roster data).
fun make_faction_starter_roster(UnitVector out, Bool owner) -> Faction:
    return make_orks_starter_roster(out, owner)

# Invoke shared Warlord selection with the adapter's faction keyword and
# eligibility policy. Stores stable identity/keyword, not a bank index;
# unsupported non-Orks armies currently offer no inputs (supplied Warlord rule).
fun select_faction_warlord(Board board, Bool player) -> SelectWarlord:
    return select_orks_warlord(board, player)

# Apply selected package Battleline grants to qualifying units in all three
# banks, retaining existing keywords. This mutates unit keyword metadata;
# copy-limit queries use faction_force_battleline before those grants exist.
fun register_faction_force_dispositions(Board board):
    register_orks_force_dispositions(board)

# Let detachment_player choose distinct packages, up to the user limit of
# three, or finish. Updates army configuration and decision owner; non-Orks
# armies skip this menu. No points or detachment-cost calculation is performed.
fun select_faction_detachments(Board board, Bool detachment_player) -> SelectOrksDetachments:
    return select_orks_detachments(board, detachment_player)

# Veto combining these units when existing enhancement/upgrade selections
# would violate the user-supplied Epic Hero attachment exclusion. Does not
# grant Leader permission, select new options or remove illegal options.
fun faction_enhancement_attachment_valid(Unit leader, Unit bodyguard) -> Bool:
    return orks_enhancement_attachment_valid(leader, bodyguard)

# Run pre-attachment enhancement/upgrade choices on owner's reserve roster.
# Enforces shared selection limits plus catalog eligibility and installs option
# metadata/equipment. No points/CP payment is introduced for roster options.
fun select_faction_options(Board board, Bool owner) -> SelectOrksOptions:
    return select_orks_options(board, owner)

# Composition entrypoint: choose legacy/custom roster, set point-free army
# identity, then select detachments, custom units if requested, options and
# Warlord. Units remain in reserves for later formation/attachment/deployment;
# current_player here is the roster's owner, not a new battle-turn transition.
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

# Validate one prospective package addition: Orks army, known non-none
# enum, spare capacity and no duplicate. Does not mutate configuration;
# the bounded collection enforces the user maximum of three.
fun faction_detachment_selection_valid(ArmyConfiguration army, OrksDetachment detachment) -> Bool:
    return orks_detachment_selection_valid(army, detachment)

# Check only faction/package compatibility in existing configuration:
# non-Orks armies must not contain Orks detachments. This is a save-integrity
# subcheck, not duplicate/capacity validation or complete army legality.
fun faction_army_configuration_valid(ArmyConfiguration army) -> Bool:
    return orks_army_configuration_valid(army)

# Translate historical roster IDs to the army faction used by rule queries.
# The current fallback is Space Marines for remaining IDs; this is a literal
# composition mapping, not validation or faction inference from unit contents.
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

# Predict whether selected packages grant this unit Battleline, without
# mutating it. Shared muster copy limits use this before disposition keywords
# are installed; normal Battleline membership is checked separately.
fun faction_force_battleline(Board board, Unit unit) -> Bool:
    return orks_force_battleline(board, unit)
