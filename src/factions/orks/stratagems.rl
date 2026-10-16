import board
import source_effects

# A source choice needs a real battlefield actor; offboard units can keep
# their own effects but cannot select external ranged targets (01.02.04).
fun orks_support_actor(Board board, UnitID source, Bool owner) -> Bool:
    return source.get() < board.units.size() and board[source].owned_by_player1 == owner and !board[source].off_battlefield and has_live_model(board[source])

# Exact phase windows for the three start/end cards; target permissions and CP
# stay in the common registry (Mob Mentality, Dubious Restraint, Dread Power).
fun orks_support_card_valid(Board board, UnitID source, Stratagem card, Bool owner, TimingWindow window) -> Bool:
    if !orks_support_actor(board, source, owner) or owner != board.current_player or !board.can_target_strat(owner, card, board[source]):
        return false
    if card == Stratagem::orks_mob_mentality:
        return window == TimingWindow::command_start and board[source].has_keyword(Keyword::orks) and board[source].has_keyword(Keyword::infantry) and live_attachment_strength(board[source]) >= 13
    if card == Stratagem::orks_dubious_restraint:
        return (window == TimingWindow::movement_start or window == TimingWindow::movement_end) and orks_taktikal_unit(board[source]) and orks_controlled_objective(board, source)
    if card == Stratagem::orks_dread_power:
        return orks_dread_power_valid(board, board[source], owner)
    if card == Stratagem::orks_delicious_eating_squigs:
        return board.timing.phase == BattlePhase::movement and orks_type(board[source], OrksDatasheet::rukkatrukk_squigbuggies)
    return false

# Only an objective currently controlled by the selected unit can be secured.
# Marker control itself uses the core stored control snapshot (p52).
fun orks_controlled_objective(Board board, UnitID source) -> Bool:
    for objective in range(4):
        if board.unit_controls_objective(board[source], objective):
            return true
    return false

# Mob Mentality selects a visible nearby friendly ORKS beneficiary separately
# from its13+-model CP target. Delicious similarly targets the actual buggy.
fun orks_support_target(Board board, UnitID source, UnitID target, Stratagem card) -> Bool:
    if target.get() >= board.units.size() or !orks_support_actor(board, target, board[source].owned_by_player1) or !board[target].has_keyword(Keyword::orks):
        return false
    if card == Stratagem::orks_mob_mentality:
        return live_unit_distance(board[source], board[target]) <= 12.0 and unit_visible_to_unit(board, board[source], board[target])
    return board[target].has_keyword(Keyword::infantry) and live_unit_distance(board[source], board[target]) <= 3.0

# Typed selector stages retain the editor's one-unit / one-enum contracts.
# Delicious may select any number of DISTINCT friendly units, each heals3.
act use_orks_support_card(ctx Board board, frm UnitID source, frm Stratagem card) -> OrksSupportCard:
    if card == Stratagem::orks_dread_power:
        commit_orks_dread_power(board, board[source])
    else:
        board.commit_stratagem(board[source].owned_by_player1, card, board[source])
    if card == Stratagem::orks_mob_mentality:
        act choose_mob_mentality_target(frm UnitID mob) {orks_support_target(board, source, mob, card)}
        grant_orks_effect(board, source, mob, 300 + card.value, OrksEffectKind::automatic_shock_success, 1, SourceDuration::phase, invalid_entity_identity())
    if card == Stratagem::orks_dubious_restraint:
        act choose_orks_secured_objective(BInt<0, 4> objective) {board.unit_controls_objective(board[source], objective.value)}
        board.grant_secured_objective(objective.value, board[source].owned_by_player1)
    if card == Stratagem::orks_delicious_eating_squigs:
        frm healed : Bool[MAX_UNIT_COUNT]
        while true:
            actions:
                act finish_eating_squigs()
                    break
                act choose_squig_healing_unit(frm UnitID healing) {orks_support_target(board, source, healing, card), !healed[healing.get()]}
                    healed[healing.get()] = true
                    frm heal_three : FixedStat
                    heal_three = 3
                    board.orks_selected_unit = healing
                    board.shared_actions.heal_unit = heal_unit(board, board[healing], SourceBank::battlefield, heal_three)
                    subaction*(board, board[healing]) board.shared_actions.heal_unit

# Literal timing/keyword clauses for phase-end movement/withdrawal cards.
# Eligibility snapshots are captured at actual phase start (While Their
# Backs Are Turned) and Fight selection (Keep It Runnin').
fun orks_end_card_valid(Board board, UnitID source, Stratagem card, Bool owner, TimingWindow window) -> Bool:
    if !orks_support_actor(board, source, owner) or board.is_in_melee(board[source]) or !board.can_target_strat(owner, card, board[source]):
        return false
    if card == Stratagem::orks_while_their_backs_are_turned:
        return window == TimingWindow::movement_end and owner != board.current_player and orks_taktikal_unit(board[source]) and !board[source].history.phase_start_engagements.empty()
    if card == Stratagem::orks_instinctive_hunters:
        return window == TimingWindow::fight_end and owner != board.current_player and board[source].has_keyword(Keyword::beast_snagga) and orks_near_edge(board[source]) and board.reserve_units.has_capacity()
    if card == Stratagem::orks_keep_it_runnin:
        return window == TimingWindow::fight_end and board[source].has_keyword(Keyword::orks) and board[source].has_keyword(Keyword::infantry) and board[source].history.fight_eligible_phase == board.phase_serial.value + 1 and orks_fight_end_carrier_available(board, source)
    return false

# Source usage rechecks the once-per-army/battle cap after other simultaneous
# effects, preserving the user's current-player then opponent sequencing.
fun orks_morgog_valid(Board board, UnitID source, Bool owner, TimingWindow window) -> Bool:
    if !orks_support_actor(board, source, owner) or owner == board.current_player or !(window == TimingWindow::movement_end) or board.is_in_melee(board[source]):
        return false
    for member in range(board[source].models.size()):
        ref model = board[source][member]
        if model_has_orks_enhancement(board[source], model, OrksEnhancement::morgogs_finkin_cap) and source_usage_available(board, make_source_usage(board[source].owned_by_player1, 200 + OrksEnhancement::morgogs_finkin_cap.value, board[source].identity, model.identity, SourceUseScope::army, source_use_limits(0, 0, 0, 1))):
            return true
    return false

# Window dispatch lets the controller interleave faction effects with core
# effects. A compulsory Surly roll cannot be bypassed by finishing its group.
fun orks_package_window_available(Board board, UnitID source, Bool owner, TimingWindow window) -> Bool:
    if orks_surly_available(board, source, owner, window) or orks_morgog_valid(board, source, owner, window):
        return true
    if source.get() >= board.units.size():
        return false
    if window == TimingWindow::fight_start and board[source].owned_by_player1 == owner and orks_psychic_available(board, source, true):
        return true
    return orks_support_card_valid(board, source, Stratagem::orks_dubious_restraint, owner, window) or orks_end_card_valid(board, source, Stratagem::orks_while_their_backs_are_turned, owner, window) or orks_end_card_valid(board, source, Stratagem::orks_instinctive_hunters, owner, window) or orks_end_card_valid(board, source, Stratagem::orks_keep_it_runnin, owner, window)

# Iteration is over real unit slots, including a retired Surly archive; it is
# never a count of selected card labels substituted for actual eligibility.
fun orks_package_windows_remaining(Board board, Bool owner, TimingWindow window, Bool mandatory) -> Bool:
    let source : UnitID
    for slot in range(board.units.size()):
        source = slot
        if mandatory and orks_surly_available(board, source, owner, window) or !mandatory and orks_package_window_available(board, source, owner, window):
            return true
    return false

# Four end cards and optional psychic/Morgog branches share controller ordering
# but retain separate source costs/lifetimes and explicit carrier decisions.
act orks_package_window(ctx Board board, frm UnitID source, frm Bool owner, frm TimingWindow window) -> OrksPackageWindow:
    actions:
        act use_visions_of_violence() {window == TimingWindow::fight_start, board[source].owned_by_player1 == owner, orks_psychic_available(board, source, true)}
            board.shared_actions.use_orks_psychic = use_orks_psychic(board, source, true)
            subaction*(board) board.shared_actions.use_orks_psychic
        act use_morgogs_finkin_cap() {orks_morgog_valid(board, source, owner, window)}
            for member in range(board[source].models.size()):
                if model_has_orks_enhancement(board[source], board[source][member], OrksEnhancement::morgogs_finkin_cap):
                    commit_source_usage(board, make_source_usage(board[source].owned_by_player1, 200 + OrksEnhancement::morgogs_finkin_cap.value, board[source].identity, board[source][member].identity, SourceUseScope::army, source_use_limits(0, 0, 0, 1)))
            board.current_roll = rerollable_dice_roll(board, unit_is_riled_up(board[source]), false, false, owner, source)
            subaction*(board) board.current_roll
            frm distance_result_snapshot_2 = board.current_roll.result
            frm morgog_distance : StatModifier
            morgog_distance = distance_result_snapshot_2.value
            board.shared_actions.granted_move = reactive_move(board, source, morgog_distance, false)
            subaction*(board) board.shared_actions.granted_move
        act use_surly_as_a_squiggoth() {orks_surly_available(board, source, owner, window)}
            board.shared_actions.resolve_orks_surly = resolve_orks_surly(board, source, owner)
            subaction*(board) board.shared_actions.resolve_orks_surly
        act choose_orks_window_stratagem(frm Stratagem card) {orks_support_card_valid(board, source, card, owner, window) and card == Stratagem::orks_dubious_restraint or orks_end_card_valid(board, source, card, owner, window)}
            if card == Stratagem::orks_dubious_restraint:
                board.shared_actions.use_orks_support_card = use_orks_support_card(board, source, card)
                subaction*(board) board.shared_actions.use_orks_support_card
            else:
                board.commit_stratagem(owner, card, board[source])
                if card == Stratagem::orks_while_their_backs_are_turned:
                    frm six : StatModifier
                    six = 6
                    board.shared_actions.granted_move = reactive_move(board, source, six, false)
                    subaction*(board) board.shared_actions.granted_move
                if card == Stratagem::orks_instinctive_hunters:
                    let relocated = reposition_unit(board, source)
                    assert(relocated, "accepted withdrawal could not move to reserves")
                if card == Stratagem::orks_keep_it_runnin:
                    act choose_fight_end_transport(frm UnitID carrier) {orks_fight_end_transport_has_model(board, source, carrier)}
                    act choose_fight_end_carrier_model(ModelID model) {orks_fight_end_carrier(board, source, carrier, model)}
                    force_orks_fight_end_embark(board, source, carrier, model)

# Shared movement-phase sources can be used before selecting a move or between
# other units' activations. This prevents a source timing being narrowed to its
# own unit's move (Watchin'/Roar/Dread Power/Delicious source clauses).
fun orks_phase_support_available(Board board, UnitID source) -> Bool:
    return orks_movement_ability_available(board, source) or orks_support_card_valid(board, source, Stratagem::orks_dread_power, board.current_player, TimingWindow::none) or orks_support_card_valid(board, source, Stratagem::orks_delicious_eating_squigs, board.current_player, TimingWindow::none)

# Free abilities and paid cards remain distinct choices and share no invented
# once-per-phase cap. Each uses its own original source/CP usage rule.
act orks_phase_support(ctx Board board, frm UnitID source) -> OrksPhaseSupport:
    actions:
        act choose_orks_free_move_ability() {orks_movement_ability_available(board, source)}
            board.shared_actions.orks_movement_abilities = orks_movement_abilities(board, source)
            subaction*(board) board.shared_actions.orks_movement_abilities
        act choose_orks_phase_card(frm Stratagem card) {orks_support_card_valid(board, source, card, board.current_player, TimingWindow::none), card == Stratagem::orks_dread_power or card == Stratagem::orks_delicious_eating_squigs}
            board.shared_actions.use_orks_support_card = use_orks_support_card(board, source, card)
            subaction*(board) board.shared_actions.use_orks_support_card

# Headbutt measures from the retained Aircraft's death base, before removal.
# Other offboard units never acquire targets by using their last coordinates.
fun orks_headbutt_target(Board board, UnitID source, Model casualty, UnitID target) -> Bool:
    return target.get() < board.units.size() and orks_support_actor(board, target, !board[source].owned_by_player1) and live_distance_to_model(board[target], casualty) <= 12.0

# If no enemy can be selected, the replacement-demise effect has no valid use.
fun orks_headbutt_has_target(Board board, UnitID source, Model casualty) -> Bool:
    let target : UnitID
    for slot in range(board.units.size()):
        target = slot
        if orks_headbutt_target(board, source, casualty, target):
            return true
    return false

# Tramplasquig Charge changes the payable CP before affordability and use
# bookkeeping; it does not refund spent CP or bypass per-phase limits.
# https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
fun orks_datasheet_stratagem_cost(Stratagem card, Unit unit) -> Int:
    return max(0, card.cost() - int(card == Stratagem::crushing_impact and unit.has_ability(AbilityKind::tramplasquig_charge)))
