import full_game

# User-required quad representation: physical calculations (core pp.9/12)
# must not admit fractional model/path coordinates during this migration.
fun test_geometry_preserves_whole_inch_quad_positions() -> Bool:
    let unit = make_infernus_squad()
    let point = geometry_point(5 * MICROMETRES_PER_INCH, 7 * MICROMETRES_PER_INCH, 2 * MICROMETRES_PER_INCH)
    unit[0].set_geometry_position(point)
    let fractional = geometry_point(5 * MICROMETRES_PER_INCH + 1, 7 * MICROMETRES_PER_INCH, 2 * MICROMETRES_PER_INCH)
    return unit[0].position.x.value == 5 and unit[0].position.y.value == 7 and unit[0].geometry.elevation.value == 2 and geometry_point_on_grid(unit[0].geometry_position()) and !geometry_point_on_grid(fractional)

fun attack_fixture() -> Board:
    let board : Board
    board.units.append(make_infernus_squad())
    board.units.append(make_infernus_squad())
    board[1].owned_by_player1 = true
    board.attack_info.source_unit_id = 0
    board.attack_info.target_unit_id = 1
    board.attack_info.source = Weapon::captain_storm_bolter
    board.attack_info.target_toughness = 4
    return board

# Rule 01.05, p.9, and 04.03, p.17: random characteristics expose bounded chance input.
fun test_01_05_random_characteristic_legality() -> Bool:
    let value = evaluate_random_stat(dice_stat(3))
    let three : Dice
    three = 3
    let four : Dice
    four = 4
    if !(can value.quantity(three)) or (can value.quantity(four)):
        return false
    value.quantity(three)
    return value.is_done() and value.result.value == 3

# Rule 05.01, p.18: an unmodified 1 fails without asking for wound/save allocation.
fun test_05_01_one_fails_hit() -> Bool:
    let board = attack_fixture()
    let sequence = single_attack(board, board[1], board[0])
    let one : Dice
    one = 1
    sequence.roll(board, board[1], board[0], one)
    return sequence.is_done() and board[1].models.size() == 5 and board[1][0].suffered_wounds == 0

# Rule 05.01, p.18: a successful supplied hit advances to the wound stage.
fun test_05_01_successful_hit_advances_to_wound() -> Bool:
    let board = attack_fixture()
    let sequence = single_attack(board, board[1], board[0])
    let six : Dice
    six = 6
    sequence.roll(board, board[1], board[0], six)
    return !sequence.is_done() and board.current_state.value == CurrentStateDescription::wound_roll.value and (can sequence.roll(board, board[1], board[0], six))

# Supported contracts, not a snapshot approving known rule defects.
# Rule 05.02, p.18: equal Strength/Toughness requires 4+.
fun test_05_02_equal_strength_toughness() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    let info : AttackSequenceInfo
    info.source = Weapon::captain_storm_bolter
    info.target_toughness = info.source.strenght()
    return required_wound_roll(board, info) == 4

# Rule 05.04, p.19: excess normal damage does not spill to another model.
fun test_05_04_normal_damage_does_not_spill() -> Bool:
    let unit = make_infernus_squad()
    if !unit.damage(0, 3):
        return false
    return unit.models.size() == 4 and unit[0].suffered_wounds == 0

# Rule 06.02, p.24: ordinary mortal wounds are applied one wound at a time.
fun test_06_02_mortal_damage_spills() -> Bool:
    let unit = make_infernus_squad()
    unit.deal_mortal_wound_damage(3)
    return unit.models.size() == 4 and unit[0].suffered_wounds == 1

# Rule 01.01, p.8: friendly/enemy follows army ownership, not turn owner.
fun test_01_01_army_ownership_is_stable() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    board.units[0].owned_by_player1 = true
    board.current_player = false
    return board[0].owner_id() == 1

# Rule 09.05, p.33: a normal move may not exceed the model's movement budget.
fun test_09_05_move_budget_legality() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    board[0].try_arrange_at(make_board_position(5, 10))
    let id = unit_id(0)
    let movement = move(board, id, 0)
    return (can movement.move_to(board, id, make_board_position(11, 10))) and !(can movement.move_to(board, id, make_board_position(12, 10)))

# Rule 01.05, p.9: supplied dice result is preserved when a free reroll is declined.
fun test_01_05_declining_reroll_preserves_result() -> Bool:
    let board : Board
    let dice_roll = rerollable_dice_roll(board, true, false, false, false)
    let dice : Dice
    dice = 2
    dice_roll.roll(board, dice)
    if !(can dice_roll.keep_it(board, true)):
        return false
    dice_roll.keep_it(board, true)
    return dice_roll.is_done() and dice_roll.result == 2 and board.command_points[0] == 0

# Binding contract: phase-inappropriate actions must not enumerate as legal.
fun test_game_initial_action_legality() -> Bool:
    let game = play()
    return (can game.pick_insidious_infiltrators()) and !(can game.end_move()) and get_current_player(game) == 0

# Binding contract: army selection advances ownership and preserves both armies.
fun test_game_army_selection_transition() -> Bool:
    let game = play()
    game.pick_insidious_infiltrators()
    if get_current_player(game) != 1 or game.board.reserve_units.size() != 5:
        return false
    game.pick_strike_force_octavious()
    return game.board.reserve_units.size() == 9 and game.board.reserve_units[0].owner_id() == 0 and game.board.reserve_units[5].owner_id() == 1

# Replay contract: serialize/parse a populated unit without losing casualties or placement.
fun test_unit_serialization_round_trip() -> Bool:
    let original = make_infernus_squad()
    original.move_to(make_board_position(10, 10))
    original.damage(0, 1)
    let restored : Unit
    let text = to_string(original)
    if !from_string(restored, text):
        return false
    return restored.models.size() == 5 and restored[0].suffered_wounds == 1 and restored[0].position.x == 10 and restored[0].position.y == 10

# Task 3 capacity regression; pp.30/33.
fun test_08_02_core_cp_gain_not_truncated() -> Bool:
    let board : Board
    board.command_points[0] = 3
    let phase = command_phase(board)
    return board.command_points[0] == 4


# Task 3 capacity regression; pp.30/33.
fun test_09_06_advance_increment_not_truncated() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    board[0].try_arrange_at(make_board_position(2, 10))
    let id = unit_id(0)
    let movement = move(board, id, 5)
    return can movement.move_to(board, id, make_board_position(13, 10))


# Task 3: model/unit lifecycle, pp.19–24 and 86–88. Action slots stay positional;
# persistent handles follow the entity and return -1 when it is gone.
fun test_identity_model_removal_does_not_retarget() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    board.identify_units()
    let removed = board[0][0].identity
    let survivor = board[0][1].identity
    board[0].damage(0, 2)
    return board[0].find_model(removed) == -1 and board[0].find_model(survivor) == 0 and board[0].destroyed_models.value[0].identity == removed

fun test_identity_unit_slots_are_not_reassigned() -> Bool:
    let board : Board
    board.units.append(make_tantus())
    board.units.append(make_octavius())
    board.identify_units()
    let removed = board[0].identity
    let survivor = board[1].identity
    board[0].damage(0, 100)
    board.remove_empty_units()
    return board.units.size() == 2 and board[0].retired and board.find_unit(removed) == -1 and board.find_unit(survivor) == 1

# Attachment component provenance is retained; eligibility is task 6 (pp.66–67).
fun test_attachment_preserves_component_identity() -> Bool:
    let board : Board
    board.reserve_units.append(make_infernus_squad())
    board.reserve_units.append(make_tantus())
    board.identify_units()
    let origin = board.reserve_units[1].identity
    let model = board.reserve_units[1][0].identity
    board.reserve_units[1].attach_to(board.reserve_units[0])
    board.reserve_units[0].capture_starting_strength()
    return board.reserve_units[0].starting_strenght == 6 and board.reserve_units[0][5].identity == model and board.reserve_units[0][5].original_unit == origin and board.reserve_units[0].attached_units.value[0].identity == origin and board.reserve_units[0].attached_units.value[0].starting_strength == 1

# p.86: starting strength counts models, not the legal model-index domain.
fun test_starting_strength_accepts_full_capacity() -> Bool:
    let unit : Unit
    let model : Model
    unit.models.resize(MAX_UNIT_MODELS)
    unit.capture_starting_strength()
    return unit.starting_strenght == MAX_UNIT_MODELS and !unit.models.try_append(model) and unit.models.size() == MAX_UNIT_MODELS

fun test_collection_overflow_is_explicit() -> Bool:
    let collection : CheckedVector<Int, 2>
    collection.append(1)
    collection.append(2)
    return !collection.has_capacity() and !collection.try_append(3) and collection.size() == 2 and collection[1] == 2

# pp.19–24: a large damage amount must destroy a model, not saturate below W.
fun test_damage_storage_handles_large_attack() -> Bool:
    let unit = make_tantus()
    if !unit.damage(0, 100):
        return false
    return unit.empty() and unit.destroyed_models.value[0].suffered_wounds == 100

# p.83 One Shot and p.88 returning models: preserve per-model usage in archives.
fun test_destroyed_model_keeps_weapon_usage_history() -> Bool:
    let unit = make_tantus()
    unit[0].used_once_per_battle_weapon[0] = true
    unit.damage(0, 100)
    let copy = unit
    return copy.destroyed_models.value[0].used_once_per_battle_weapon[0]

# pp.78–88: deferred destruction also handles the first/only model.
fun test_fight_on_death_removes_index_zero() -> Bool:
    let unit = make_tantus()
    unit.damage(0, 100, true)
    if unit.models.size() != 1:
        return false
    unit.remove_figth_on_death_models()
    return unit.empty() and unit.destroyed_models.value.size() == 1

# p.30 CP and p.33 Advance storage; versions are implementation compatibility.
fun test_schema_round_trip_and_legacy_rejection() -> Bool:
    let state = play()
    state.board.command_points[0] = 100
    let encoded = to_string(state)
    let restored = play()
    if !set_state(restored, encoded) or restored.board.command_points[0] != 100:
        return false
    state.board.schema_version.value = 1
    if set_state(restored, to_string(state)):
        return false
    return restored.board.command_points[0] == 100 and restored.board.schema_version.value == STATE_SCHEMA_VERSION

fun test_invalid_save_does_not_modify_state() -> Bool:
    let state = play()
    state.board.command_points[0] = 42
    let before = to_string(state)
    if set_state(state, "invalid"s):
        return false
    return to_string(state) == before

fun test_negative_cp_save_decode_is_rejected() -> Bool:
    let state = play()
    state.board.command_points[0] = 42
    let invalid = state
    invalid.board.command_points[0].value = -1
    return !set_state(state, to_string(invalid)) and state.board.command_points[0] == 42

fun test_history_survives_copy_and_phase_reset() -> Bool:
    let board : Board
    board.units.append(make_tantus())
    board[0].history.last_ranged_attack_turn = 7
    board[0].history.used_stratagem_this_phase = true
    board.has_used_shadow_in_the_warp[0] = true
    let copy = board
    copy.clear_phase_modifiers()
    return copy[0].history.last_ranged_attack_turn == 7 and !copy[0].history.used_stratagem_this_phase and copy.has_used_shadow_in_the_warp[0] and board[0].history.used_stratagem_this_phase

fun test_duplicate_identity_save_is_rejected() -> Bool:
    let state = play()
    state.pick_insidious_infiltrators()
    let before = to_string(state)
    let invalid = state
    invalid.board.reserve_units[1].identity = invalid.board.reserve_units[0].identity
    return !set_state(state, to_string(invalid)) and to_string(state) == before

fun test_empty_unit_is_not_a_shooting_target() -> Bool:
    let board = attack_fixture()
    board[0].can_shoot = true
    board[1].models.clear()
    let phase = shooting_phase(board)
    let source = unit_id(0)
    let target = unit_id(1)
    return !(can phase.select_target(board, source, target)) and (can phase.end_shooting_phase(board))

# Task 3 prerequisite: safe CP expenditure; p.54.
fun test_15_01_actual_stratagem_cost() -> Bool:
    let board : Board
    board.command_points[0] = 1
    return board.can_use_strat(false, Stratagem::reroll)


# Task 3 prerequisite: safe CP expenditure; p.54.
fun test_15_01_own_player_usage() -> Bool:
    let board : Board
    board.command_points[0] = 3
    board.mark_strat_used(Stratagem::reroll, 0)
    return !board.can_use_strat(false, Stratagem::reroll)


# Existing Overwatch expenditure defects exposed by checked CP (p.55).
# Its new-edition timing/eligibility remains task 15.
fun test_overwatch_with_no_cp_cannot_spend() -> Bool:
    let board = attack_fixture()
    board[1].can_shoot = true
    let moved = unit_id(0)
    let sequence = overwatch(board, moved)
    return sequence.is_done() and board.command_points[1] == 0 and !board.has_used_strat(Stratagem::overwatch, 1)

fun test_declining_overwatch_preserves_cp_and_usage() -> Bool:
    let board = attack_fixture()
    board.command_points[1] = 1
    board[1].can_shoot = true
    let moved = unit_id(0)
    let sequence = overwatch(board, moved)
    if !(can sequence.skip(board)):
        return false
    sequence.skip(board)
    return sequence.is_done() and board.command_points[1] == 1 and !board.has_used_strat(Stratagem::overwatch, 1)

fun test_oversized_collection_decode_is_rejected() -> Bool:
    let unchecked : BoundedVector<Int, 2>
    unchecked._data.append(1)
    unchecked._data.append(2)
    unchecked._data.append(3)
    let checked : CheckedVector<Int, 2>
    checked.append(42)
    return !from_string(checked, to_string(unchecked)) and checked.size() == 1 and checked[0] == 42

fun test_unassigned_identity_never_resolves() -> Bool:
    let board : Board
    board.units.append(make_tantus())
    let unassigned : EntityIdentity
    return board.find_unit(unassigned) == -1 and board[0].find_model(unassigned) == -1

fun test_phase_movement_and_setup_history() -> Bool:
    let board : Board
    board.units.append(make_tantus())
    board[0].mark_set_up()
    board[0].translate(3, 4)
    if !board[0][0].history.was_set_up_this_turn or board[0][0].history.distance_moved_this_turn.value != 5.0:
        return false
    board.start_turn_history()
    return board.turn_serial == 1 and !board[0].history.was_set_up_this_turn and !board[0][0].history.was_set_up_this_turn and board[0][0].history.distance_moved_this_turn.value == 0.0

# pp.54/56: own Command-step Bravery is charged to the active unit's owner.
fun test_insane_bravery_charges_the_units_owner() -> Bool:
    let board = attack_fixture()
    board.command_points[1] = 1
    board.current_player = true
    board.begin_phase(BattlePhase::command)
    let sequence = battle_shock_test(board, board[1], true, false)
    if !(can sequence.insane_bravery(board, board[1], true)):
        return false
    sequence.insane_bravery(board, board[1], true)
    return sequence.is_done() and board.command_points[0] == 0 and board.command_points[1] == 0 and board.has_used_strat(Stratagem::insane_bravery, 1) and !board.has_used_strat(Stratagem::insane_bravery, 0)

# Existing faction data: spending must match the cost/player actually gated.
# New-edition faction replacement remains dependent on task 17 supplied data.
fun test_bestial_bellow_rejects_missing_target_and_charges_correct_player() -> Bool:
    let board : Board
    board.units.append(make_beastboss_morgrim())
    board.units.append(make_infernus_squad())
    board[1].owned_by_player1 = true
    board.players_faction[0] = Faction::morgrim_butchas
    board.command_points[0] = 1
    let sequence = fight_phase(board)
    let source = unit_id(0)
    let target = unit_id(1)
    let missing = unit_id(MAX_UNIT_COUNT - 1)
    if can sequence.use_bestial_bellow(board, source, missing):
        return false
    if !(can sequence.use_bestial_bellow(board, source, target)):
        return false
    sequence.use_bestial_bellow(board, source, target)
    return board.command_points[0] == 0 and board.command_points[1] == 0 and board.has_used_strat(Stratagem::bestial_bellow, 0) and !board.has_used_strat(Stratagem::heroic_intervention, 1)

fun test_accepting_overwatch_charges_only_opponent() -> Bool:
    let board = attack_fixture()
    board.command_points[1] = 1
    board[1].can_shoot = true
    let moved = unit_id(0)
    let source = unit_id(1)
    let sequence = overwatch(board, moved)
    if !(can sequence.overwatch(board, source)):
        return false
    sequence.overwatch(board, source)
    return board.command_points[0] == 0 and board.command_points[1] == 0 and board.has_used_strat(Stratagem::overwatch, 1) and !board.has_used_strat(Stratagem::overwatch, 0)

# Bounds are reflected directly in standard enumeration/ML layout.
fun test_bounded_cp_layout_and_domain() -> Bool:
    let value : CommandPoints
    let domain = enumerate(value)
    return domain.size() == MAX_CP and domain[0] == 0 and domain[MAX_CP - 1] == MAX_CP - 1 and size_as_observation_tensor(value) == 1

fun test_bounded_storage_rejects_out_of_range_save() -> Bool:
    let state = play()
    state.board.command_points[0] = 42
    let invalid = state
    invalid.board.command_points[0].value = MAX_CP
    return !set_state(state, to_string(invalid)) and state.board.command_points[0] == 42

# p.33: preserve a complete D6 Advance and storage beyond the old result cap.
fun test_bounded_random_result_and_modifier_capacity() -> Bool:
    let sequence = evaluate_random_stat(dice_stat(6), 6)
    let six : Dice
    six = 6
    sequence.quantity(six)
    return sequence.is_done() and sequence.result == 12 and size_as_observation_tensor(sequence.result) == 1

# Bounded alternatives must survive pretty indentation in editor saves.
fun test_bounded_stat_indented_round_trip() -> Bool:
    let fixed = raw_stat(4)
    let restored : Stat
    if !from_string(restored, to_string(fixed).to_indented_lines()):
        return false
    if to_string(restored) != to_string(fixed):
        return false
    let dice = dice_stat(6)
    return from_string(restored, to_string(dice).to_indented_lines()) and to_string(restored) == to_string(dice)

fun test_indented_game_save_with_bounded_storage() -> Bool:
    let state = play()
    state.pick_insidious_infiltrators()
    state.pick_strike_force_octavious()
    let restored = play()
    return set_state(restored, to_string(state).to_indented_lines()) and to_string(restored) == to_string(state)

# Existing faction-trigger regression: the character predicate must be invoked
# on the destroyed model (destruction hook: core p.19; faction definition external).
fun test_destroyed_character_triggers_feeder_tendrils() -> Bool:
    let board : Board
    let source = make_infernus_squad()
    source[0].abilities.append(AbilityKind::feeder_tendrils)
    let destroyed = source[0]
    destroyed.keywords.append(Keyword::character)
    let event = on_model_destroyed(board, source, destroyed)
    return event.is_done() and board.command_points[0] == 1 and board.command_points[1] == 0

# An attacking character does not make a non-character casualty eligible;
# a character casualty also requires the attacker's existing faction ability.
fun test_feeder_tendrils_requires_character_casualty_and_ability() -> Bool:
    let board : Board
    let source = make_infernus_squad()
    let destroyed = source[0]
    source[0].keywords.append(Keyword::character)
    source[0].abilities.append(AbilityKind::feeder_tendrils)
    let first = on_model_destroyed(board, source, destroyed)
    if !first.is_done() or board.command_points[0] != 0:
        return false
    source[0].abilities.clear()
    destroyed.keywords.append(Keyword::character)
    let second = on_model_destroyed(board, source, destroyed)
    return second.is_done() and board.command_points[0] == 0 and board.command_points[1] == 0

# Task-4 fixtures use whole-inch cells; no fractional movement choices.
fun board_position(Int x, Int y) -> BoardPosition:
    let result : BoardPosition
    result.x = x
    result.y = y
    return result

fun geometry_fixture() -> Board:
    let board : Board
    let unit = make_infernus_squad()
    while unit.models.size() > 1:
        unit.models.erase(unit.models.size() - 1)
    unit[0].position = board_position(5, 5)
    board.units.append(unit)
    return board

fun geometry_path(Int model, Int x, Int y, Int z) -> ModelPath:
    let path : ModelPath
    path.model = model
    path.points.append(geometry_point(x * MICROMETRES_PER_INCH, y * MICROMETRES_PER_INCH, z * MICROMETRES_PER_INCH))
    return path

fun geometry_box(Int x1, Int y1, Int z1, Int x2, Int y2, Int z2) -> TerrainGeometry:
    let box : TerrainGeometry
    box.lower = geometry_point(x1 * MICROMETRES_PER_INCH, y1 * MICROMETRES_PER_INCH, z1 * MICROMETRES_PER_INCH)
    box.upper = geometry_point(x2 * MICROMETRES_PER_INCH, y2 * MICROMETRES_PER_INCH, z2 * MICROMETRES_PER_INCH)
    box.blocks_movement = true
    return box

# pp.14–15: exact thresholds are inclusive; one micrometre beyond is outside.
fun test_geometry_inclusive_horizontal_vertical_boundaries() -> Bool:
    return within_geometry_limits(50800.0, 127000, 2, 5) and !within_geometry_limits(50801.0, 127000, 2, 5) and !within_geometry_limits(50800.0, 127001, 2, 5) and within_geometry_limits(228600.0, 127000, 9, 5) and !within_geometry_limits(228601.0, 127000, 9, 5)

# p.9: millimetre base dimensions, rather than centres, determine engagement.
fun test_geometry_base_edges_and_height_engagement() -> Bool:
    let board = geometry_fixture()
    let other = board[0][0]
    other.position = board_position(8, 5)
    other.geometry.elevation = 5
    if !board[0][0].is_engaged_with(other):
        return false
    other.geometry.elevation = 6
    if board[0][0].is_engaged_with(other):
        return false
    other.geometry.elevation = 0
    other.position.x = 9
    return !board[0][0].is_engaged_with(other)

# p.9 and supplied Closest definition: include model zero and every target model.
fun test_geometry_closest_pair_is_not_first_target_only() -> Bool:
    let board = geometry_fixture()
    let other = board[0]
    other[0].position = board_position(30, 5)
    let close = other[0]
    close.position = board_position(8, 5)
    other.models.append(close)
    let direction = board[0].get_shortest_vector_to(other)
    return board[0].distance(other) < 2.0 and direction.x == 3 and direction.y == 0

# p.9 / supplied Within definitions: one base may be within while not all are wholly within.
fun test_geometry_within_wholly_within_quantifiers() -> Bool:
    let board = geometry_fixture()
    let point = geometry_point(3 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 0)
    if !unit_within_point(board[0], point, 2, false) or unit_within_point(board[0], point, 2, true):
        return false
    if !unit_within_point(board[0], point, 3, true):
        return false
    let far = board[0][0]
    far.position = board_position(20, 5)
    board[0].models.append(far)
    return unit_within_point(board[0], point, 3, false) and !unit_within_point(board[0], point, 3, true)

# p.9: a point's range reaches a base before reaching its centre.
fun test_geometry_point_distance_uses_base_and_height() -> Bool:
    let board = geometry_fixture()
    let point = board_position(2, 5)
    if board[0].distance(point) >= 3.0:
        return false
    board[0][0].geometry.elevation = 4
    return board[0].distance(point) > 4.0 and board[0].distance(point) < 5.0

# p.14: nearby neighbours do not excuse a chain wider than nine inches.
fun test_geometry_coherency_requires_neighbour_and_all_pairs() -> Bool:
    let board = geometry_fixture()
    let unit = board[0]
    let i = 1
    while i < 5:
        let model = unit[0]
        model.position.x = 5 + i * 3
        unit.models.append(model)
        i = i + 1
    if unit.is_coherent():
        return false
    unit.models.erase(unit.models.size() - 1)
    if !unit.is_coherent():
        return false
    unit[3].position.x = 16
    return !unit.is_coherent()

# pp.12/14: preset placement fits all bases, remains coherent and keeps whole cells.
fun test_geometry_quad_formation_has_no_overlapping_bases() -> Bool:
    let unit = make_infernus_squad()
    let anchor = board_position(5, 5)
    if !unit.try_arrange_at(anchor) or !unit.is_coherent():
        return false
    let i = 0
    while i < unit.models.size():
        if !geometry_point_on_grid(unit[i].geometry_position()):
            return false
        let j = i + 1
        while j < unit.models.size():
            if model_bases_overlap(unit[i], unit[j]):
                return false
            j = j + 1
        i = i + 1
    return true

# pp.12/14: failed setup and edge translations preserve original positions/history.
fun test_geometry_failed_placement_and_translation_are_atomic() -> Bool:
    let unit = make_infernus_squad()
    let anchor = board_position(5, 5)
    if !unit.try_arrange_at(anchor):
        return false
    let before = to_string(unit)
    let edge = board_position(43, 29)
    if unit.try_arrange_at(edge) or to_string(unit) != before:
        return false
    let offset : Vector2D
    offset.x = -10
    return !unit.try_translate(offset) and to_string(unit) == before

# p.12: the entire base must be inside the board, including at legal centre cells.
fun test_geometry_base_bounds_and_unsupported_footprint() -> Bool:
    let board = geometry_fixture()
    let edge = geometry_point(0, 5 * MICROMETRES_PER_INCH, 0)
    if model_inside_battlefield(board[0][0], edge):
        return false
    board[0][0].geometry.unsupported_footprint = true
    return !model_placement_valid(board, board[0][0])

# p.12: sum the whole path, rather than only displacement, including retracing.
fun test_geometry_path_budget_counts_all_segments() -> Bool:
    let board = geometry_fixture()
    let paths : Vector<ModelPath>
    let path = geometry_path(0, 8, 5, 0)
    path.points.append(geometry_point(5 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 0))
    paths.append(path)
    let slot : UnitID
    let policy : MovementGeometryPolicy
    if !try_move_models(board, slot, paths, 0, policy, true) or board[0][0].history.distance_moved_this_turn.value != 6.0:
        return false
    let before = to_string(board)
    paths[0].points[1].x = 4 * MICROMETRES_PER_INCH
    return !try_move_models(board, slot, paths, 0, policy, true) and to_string(board) == before

# p.87: movement characteristics belong to individual models, including mixed units.
fun test_geometry_mixed_movement_budgets_and_rollback() -> Bool:
    let board = geometry_fixture()
    let fast = board[0][0]
    fast.profile = Profile::possessed
    fast.position = board_position(7, 5)
    board[0].models.append(fast)
    let paths : Vector<ModelPath>
    paths.append(geometry_path(0, 11, 5, 0))
    paths.append(geometry_path(1, 16, 5, 0))
    let slot : UnitID
    let policy : MovementGeometryPolicy
    let before = to_string(board)
    if try_move_models(board, slot, paths, 0, policy, true) or to_string(board) != before:
        return false
    paths[1].points[0].x = 13 * MICROMETRES_PER_INCH
    if !try_move_models(board, slot, paths, 0, policy, true):
        return false
    board[0][1].position = board_position(7, 5)
    board[0][0].position = board_position(5, 5)
    paths[0].points[0].x = 13 * MICROMETRES_PER_INCH
    paths[1].points[0].x = 15 * MICROMETRES_PER_INCH
    let mixed_before = to_string(board)
    return !try_move_models(board, slot, paths, 0, policy, true) and to_string(board) == mixed_before

# p.12: friendly traversal is permitted, but final overlap is prohibited.
fun test_geometry_friendly_traversal_and_final_overlap() -> Bool:
    let board = geometry_fixture()
    let obstacle = board[0]
    obstacle[0].position = board_position(8, 5)
    board.units.append(obstacle)
    let slot : UnitID
    let target = board_position(11, 5)
    if !try_translate_unit(board, slot, target, 0):
        return false
    let before = to_string(board)
    target = board_position(8, 5)
    return !try_translate_unit(board, slot, target, 0) and to_string(board) == before

# p.12: crossing an enemy is illegal even when the end position is clear.
fun test_geometry_enemy_path_crossing_is_rejected() -> Bool:
    let board = geometry_fixture()
    let obstacle = board[0]
    obstacle.owned_by_player1 = true
    obstacle[0].position = board_position(8, 5)
    board.units.append(obstacle)
    let slot : UnitID
    let target = board_position(11, 5)
    let before = to_string(board)
    return !try_translate_unit(board, slot, target, 0) and to_string(board) == before

# p.12: failed legality probes must never mutate live state.
fun test_geometry_translation_probe_is_pure() -> Bool:
    let board = geometry_fixture()
    let before = to_string(board)
    let slot : UnitID
    let target = board_position(11, 5)
    return can_translate_unit(board, slot, target, 0) and to_string(board) == before

# p.12: reject off-grid paths, repeated model choices, and out-of-range model selectors.
fun test_geometry_invalid_paths_are_atomic() -> Bool:
    let board = geometry_fixture()
    let before = to_string(board)
    let slot : UnitID
    let policy : MovementGeometryPolicy
    let paths : Vector<ModelPath>
    paths.append(geometry_path(0, 6, 5, 0))
    paths[0].points[0].x = 6 * MICROMETRES_PER_INCH + 1
    if try_move_models(board, slot, paths, 0, policy, true) or to_string(board) != before:
        return false
    paths[0].points[0].x = 6 * MICROMETRES_PER_INCH
    paths.append(paths[0])
    if try_move_models(board, slot, paths, 0, policy, true) or to_string(board) != before:
        return false
    paths.erase(paths.size() - 1)
    paths[0].model = 1
    return !try_move_models(board, slot, paths, 0, policy, true) and to_string(board) == before

# p.12: rotation has no movement cost; on circular fixtures it does not change footprint.
fun test_geometry_rotation_is_free_on_circle_fixture() -> Bool:
    let board = geometry_fixture()
    let path : ModelPath
    path.final_rotation = 270000
    let paths : Vector<ModelPath>
    paths.append(path)
    let slot : UnitID
    let policy : MovementGeometryPolicy
    return try_move_models(board, slot, paths, 0, policy, true) and board[0][0].history.distance_moved_this_turn.value == 0.0 and board[0][0].geometry.rotation.value == 270000 and board[0][0].position.x.value == 5

# p.12: check swept bases through solid terrain, not just legal endpoints.
fun test_geometry_wall_crossing_is_rejected() -> Bool:
    let board = geometry_fixture()
    board.terrain_geometry.append(geometry_box(7, 3, 0, 9, 7, 2))
    let slot : UnitID
    let target = board_position(11, 5)
    let before = to_string(board)
    return !try_translate_unit(board, slot, target, 0) and to_string(board) == before

# p.48: elevated placement needs full support; upper-surface travel does not enter the solid.
fun test_geometry_roof_support_and_overhang() -> Bool:
    let board = geometry_fixture()
    let terrain = geometry_box(4, 4, 0, 8, 8, 2)
    board.terrain_geometry.append(terrain)
    board[0][0].geometry.elevation = 2
    if !model_placement_valid(board, board[0][0]):
        return false
    let start = geometry_point(5 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 2 * MICROMETRES_PER_INCH)
    let end = geometry_point(7 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 2 * MICROMETRES_PER_INCH)
    if segment_crosses_terrain(board[0][0], start, end, terrain):
        return false
    board[0][0].position.x = 4
    return !model_placement_valid(board, board[0][0])

# p.48: touching a roof only at the start/end does not enter its solid volume.
fun test_geometry_roof_endpoint_is_not_interior() -> Bool:
    let board = geometry_fixture()
    let terrain = geometry_box(4, 4, 0, 8, 8, 2)
    let roof = geometry_point(5 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 2 * MICROMETRES_PER_INCH)
    let above = geometry_point(5 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 3 * MICROMETRES_PER_INCH)
    let below = geometry_point(5 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, MICROMETRES_PER_INCH)
    return !segment_crosses_terrain(board[0][0], roof, above, terrain) and !segment_crosses_terrain(board[0][0], above, roof, terrain) and segment_crosses_terrain(board[0][0], roof, below, terrain)

# pp.12/48: horizontal plus vertical movement, not the hypotenuse, consumes M.
fun test_geometry_vertical_cost_and_terrain_proximity() -> Bool:
    let board = geometry_fixture()
    let start = geometry_point(5 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 0)
    let end = geometry_point(8 * MICROMETRES_PER_INCH, 9 * MICROMETRES_PER_INCH, 2 * MICROMETRES_PER_INCH)
    if segment_length(start, end) != float(7 * MICROMETRES_PER_INCH):
        return false
    let policy : MovementGeometryPolicy
    let up = geometry_point(5 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 2 * MICROMETRES_PER_INCH)
    if model_segment_valid(board, board[0], board[0][0], start, up, policy):
        return false
    board.terrain_geometry.append(geometry_box(6, 4, 0, 8, 8, 2))
    return model_segment_valid(board, board[0], board[0][0], start, up, policy)

# p.14: cancelled/failed reserve setup retains the source rather than partly placing it.
fun test_geometry_setup_validation_preserves_reserve() -> Bool:
    let board = geometry_fixture()
    board.reserve_units.append(board[0])
    let before = to_string(board)
    let occupied = board_position(5, 5)
    let free = board_position(20, 5)
    return !setup_candidate_valid(board, board.reserve_units[0], occupied) and setup_candidate_valid(board, board.reserve_units[0], free) and to_string(board) == before

# p.12: footprint tangency is allowed; a one-micrometre inward sweep overlaps.
# These calculation-only points never become model positions or player choices.
fun test_geometry_swept_base_tangency() -> Bool:
    let board = geometry_fixture()
    let radius = int(board[0][0].base_radius_micrometres() * 2.0)
    let obstacle = board[0][0]
    let centre = obstacle.geometry_position()
    let start = geometry_point(centre.x.value - 25400, centre.y.value + radius, 0)
    let end = geometry_point(centre.x.value + 25400, centre.y.value + radius, 0)
    if segment_crosses_model(board[0][0], start, end, obstacle):
        return false
    start.y = start.y.value - 1
    end.y = end.y.value - 1
    return segment_crosses_model(board[0][0], start, end, obstacle)

# p.12 / quad storage invariant: reject malformed or off-grid terrain in saves.
fun test_geometry_state_rejects_malformed_terrain() -> Bool:
    let board = geometry_fixture()
    board.identify_units()
    board.terrain_geometry.append(geometry_box(7, 3, 0, 9, 7, 2))
    if !valid_state_foundations(board):
        return false
    board.terrain_geometry[0].lower.x = 7 * MICROMETRES_PER_INCH + 1
    if valid_state_foundations(board):
        return false
    board.terrain_geometry[0].lower = board.terrain_geometry[0].upper
    return !valid_state_foundations(board)

# Geometry storage is bounded implementation infrastructure; match board dimensions.
fun test_geometry_physical_bounds_match_quad_board() -> Bool:
    return MAX_GEOMETRY_X == BOARD_WIDTH * MICROMETRES_PER_INCH + 1 and MAX_GEOMETRY_Y == BOARD_HEIGHT * MICROMETRES_PER_INCH + 1 and MAX_ELEVATION == 30 * MICROMETRES_PER_INCH + 1

# p.14: an illegal deployment keeps the selected reserve; cancellation permits retry.
fun test_geometry_deployment_cancel_retains_unit_and_owner() -> Bool:
    let board : Board
    board.reserve_units.append(make_infernus_squad())
    let sequence = deploy(board)
    let slot : UnitID
    sequence.select_unit(board, slot)
    let edge = board_position(43, 29)
    if (can sequence.deploy_at(board, edge)) or board.units.size() != 0:
        return false
    sequence.skip(board)
    return board.reserve_units.size() == 1 and board.units.size() == 0 and !board.current_decision_maker and (can sequence.select_unit(board, slot))

# p.12: a trapped move can be cancelled with no position/history changes.
# This reproduces the engaged rigid-formation move that stalled seed 40000.
fun test_geometry_trapped_move_has_cancel_action() -> Bool:
    let board = geometry_fixture()
    board[0][0].geometry.unsupported_footprint = true
    let before = to_string(board[0])
    let slot : UnitID
    let sequence = move(board, slot, 0)
    if !(can sequence.skip(board, slot)):
        return false
    sequence.skip(board, slot)
    return sequence.is_done() and to_string(board[0]) == before

# p.12: a model's full base must fit through a gap between enemy bases.
fun test_geometry_full_base_clearance_through_gap() -> Bool:
    let board = geometry_fixture()
    let obstacle = board[0]
    obstacle.owned_by_player1 = true
    obstacle[0].position = board_position(8, 4)
    let second = obstacle[0]
    second.position.y = 6
    obstacle.models.append(second)
    board.units.append(obstacle)
    let start = board[0][0].geometry_position()
    let end = geometry_point(11 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 0)
    let policy : MovementGeometryPolicy
    if model_segment_valid(board, board[0], board[0][0], start, end, policy):
        return false
    board[1][0].position.y = 3
    board[1][1].position.y = 7
    return model_segment_valid(board, board[0], board[0][0], start, end, policy)

# p.14: coherency's five-inch vertical limit applies to every model pair.
fun test_geometry_coherency_vertical_limit() -> Bool:
    let board = geometry_fixture()
    let second = board[0][0]
    second.position.x = 7
    second.geometry.elevation = 5
    board[0].models.append(second)
    if !board[0].is_coherent():
        return false
    board[0][1].geometry.elevation = 6
    return !board[0].is_coherent()

# Task-5 fixture: distinct whole-inch bases, owners and stable identities.
fun timing_fixture() -> Board:
    let board = geometry_fixture()
    let other = board[0]
    other.owned_by_player1 = true
    other[0].position = board_position(20, 5)
    board.units.append(other)
    board.identify_unit(board[0])
    board.identify_unit(board[1])
    board.command_points[0] = 3
    board.command_points[1] = 3
    return board

# p.54: a player's second stratagem on the same unit is forbidden, even
# when it is a different stratagem; the other player's record is independent.
fun test_timing_per_player_unit_stratagem_limit() -> Bool:
    let board = timing_fixture()
    if !board.try_use_strat(false, Stratagem::reroll, board[0], 1):
        return false
    if board.can_target_strat(false, Stratagem::overwatch, board[0]):
        return false
    return board.can_target_strat(true, Stratagem::overwatch, board[0]) and board.command_points[0] == 2 and board.command_points[1] == 3

# pp.9/54: shock bans the controller's target, not the opposing payer's target.
fun test_timing_shock_stratagem_target_ownership() -> Bool:
    let board = timing_fixture()
    board[0].battle_socked = true
    return !board.can_target_strat(false, Stratagem::reroll, board[0]) and board.can_target_strat(true, Stratagem::reroll, board[0])

# p.54: invalid cost, insufficient CP and repeat use have no partial effects.
fun test_timing_stratagem_failure_is_atomic() -> Bool:
    let board = timing_fixture()
    let before = to_string(board)
    if board.try_use_strat(false, Stratagem::reroll, board[0], -1) or board.try_use_strat(false, Stratagem::reroll, board[0], 4):
        return false
    return before == to_string(board)

# p.54: overrides including free use retain phase and per-unit restrictions.
fun test_timing_free_use_still_consumes_usage() -> Bool:
    let board = timing_fixture()
    board.command_points[0] = 0
    if !board.try_use_strat(false, Stratagem::reroll, board[0], 0):
        return false
    return board.command_points[0] == 0 and !board.can_use_strat_with_cost(false, Stratagem::reroll, 0) and !board.can_target_strat_with_cost(false, Stratagem::overwatch, board[0], 0)

# pp.28–30/54: phase reset includes reserves and both payers, not turn flags.
fun test_timing_phase_reset_includes_reserves() -> Bool:
    let board = timing_fixture()
    board.reserve_units.append(board[0])
    board.commit_stratagem(false, Stratagem::reroll, board[0])
    board.reserve_units[0].history.stratagem_targeted_by_player[1] = true
    board[0].has_moved = true
    board[1].has_fought = true
    board.begin_phase(BattlePhase::shooting)
    return board.timing.phase == BattlePhase::shooting and board.can_target_strat(false, Stratagem::reroll, board[0]) and !board.reserve_units[0].history.stratagem_targeted_by_player[1] and board[0].has_moved and !board[1].has_fought

# pp.28–30: the turn owner's flags reset without erasing enemy turn choices.
fun test_timing_turn_flags_reset_only_active_army() -> Bool:
    let board = timing_fixture()
    board[0].has_moved = true
    board[1].has_moved = true
    board.start_turn_history()
    return !board[0].has_moved and board[1].has_moved

# pp.9/54/56: accept CP reroll -> spend -> chance; restore caller afterward.
fun test_timing_pair_reroll_owner_spend_and_restore() -> Bool:
    let board = timing_fixture()
    board.current_decision_maker = false
    let dice_roll = rerollable_pair_dices_roll(board, false, false, true, true, unit_id(1))
    let one : Dice
    one = 1
    dice_roll.roll_pair(board, one, one)
    if board.current_decision_maker != true or !(can dice_roll.keep_it(board, false)):
        return false
    dice_roll.keep_it(board, false)
    if board.command_points[1] != 2 or !board[1].history.stratagem_targeted_by_player[1] or !(can dice_roll.reroll_pair(board, one, one)):
        return false
    dice_roll.reroll_pair(board, one, one)
    return dice_roll.is_done() and !board.current_decision_maker

# p.56: a declined CP reroll changes no expenditure/history and restores owner.
fun test_timing_declining_cp_reroll_preserves_state() -> Bool:
    let board = timing_fixture()
    board.current_decision_maker = true
    let dice_roll = rerollable_dice_roll(board, false, false, true, false, unit_id(0))
    let one : Dice
    one = 1
    dice_roll.roll(board, one)
    if board.current_decision_maker:
        return false
    dice_roll.keep_it(board, true)
    return dice_roll.is_done() and board.command_points[0] == 3 and !board.has_used_strat(Stratagem::reroll, 0) and board.current_decision_maker

# p.56: targetless/leadership compatibility cannot offer a CP reroll.
fun test_timing_targetless_roll_cannot_spend_cp() -> Bool:
    let board = timing_fixture()
    let dice_roll = rerollable_pair_dices_roll(board, false, false, true, false)
    let one : Dice
    one = 1
    dice_roll.roll_pair(board, one, one)
    return dice_roll.is_done() and board.command_points[0] == 3

# p.30 and user's sequencing definition: current group first, then opponent.
fun test_timing_current_player_then_opponent_effects() -> Bool:
    let board = timing_fixture()
    board.players_faction[0] = Faction::insidious_infiltrators
    board.players_faction[1] = Faction::insidious_infiltrators
    let window = resolve_timing_window(board, TimingWindow::command_abilities)
    if !(board.timing.stage == TimingStage::current_player_rules) or board.current_decision_maker:
        return false
    window.choose_timing_rule(board, TimingRule::shadow_in_the_warp)
    window.use_shadow_in_the_warp(board, false)
    if !board.current_decision_maker or !(board.timing.stage == TimingStage::opposing_player_rules):
        return false
    window.choose_timing_rule(board, TimingRule::shadow_in_the_warp)
    window.use_shadow_in_the_warp(board, false)
    return window.is_done() and !board.timing.open and board.timing.stage == TimingStage::closed and !board.current_decision_maker

# p.30 and user's sequencing definition: choose either available kind first.
fun test_timing_owner_can_choose_effect_order() -> Bool:
    let board = timing_fixture()
    board.players_faction[0] = Faction::strike_force_octavius
    let window = resolve_timing_window(board, TimingWindow::command_abilities)
    if !(can window.choose_timing_rule(board, TimingRule::oath_of_moment)) or !(can window.choose_timing_rule(board, TimingRule::objective_stratagem)):
        return false
    window.choose_timing_rule(board, TimingRule::objective_stratagem)
    window.skip(board)
    if can window.choose_timing_rule(board, TimingRule::objective_stratagem):
        return false
    if !(can window.choose_timing_rule(board, TimingRule::oath_of_moment)):
        return false
    window.choose_timing_rule(board, TimingRule::oath_of_moment)
    window.skip(board)
    return window.is_done()

# p.57: Overwatch and Rapid Ingress are only offered to opponent at Move end.
fun test_timing_overwatch_window_and_decline() -> Bool:
    let board = timing_fixture()
    if timing_rule_available(board, TimingWindow::movement_start, true, TimingRule::fire_overwatch) or timing_rule_available(board, TimingWindow::movement_end, false, TimingRule::fire_overwatch):
        return false
    let before = board.command_points[1]
    let window = resolve_timing_window(board, TimingWindow::movement_end)
    if !board.current_decision_maker or !(can window.choose_timing_rule(board, TimingRule::fire_overwatch)):
        return false
    window.finish_timing_rules(board)
    return window.is_done() and board.command_points[1] == before and !board.has_used_strat(Stratagem::overwatch, 1) and !board.current_decision_maker

# p.57: engaged, shocked and TITANIC Overwatch sources are excluded.
fun test_timing_overwatch_source_exclusions() -> Bool:
    let board = timing_fixture()
    let source = unit_id(1)
    if !overwatch_source_valid(board, true, source):
        return false
    board[1].battle_socked = true
    if overwatch_source_valid(board, true, source):
        return false
    board[1].battle_socked = false
    board[1][0].position = board_position(6, 5)
    return !overwatch_source_valid(board, true, source)

# p.57: first-round Rapid Ingress is prohibited; later reserve is eligible.
fun test_timing_rapid_ingress_round_gate_and_payment() -> Bool:
    let board = timing_fixture()
    board.reserve_units.append(board[1])
    if rapid_ingress_target_valid(board, true, unit_id(0)):
        return false
    board.current_round = 1
    let ingress = timing_rapid_ingress(board, true)
    ingress.select_ingress_unit(board, unit_id(0))
    if board.command_points[1] != 2 or !board.reserve_units[0].history.stratagem_targeted_by_player[1]:
        return false
    ingress.skip(board)
    return ingress.is_done() and board.reserve_units.size() == 1 and board.has_used_strat(Stratagem::rapid_ingress, 1)

# p.14: both armies remove incoherent models one at a time without death hooks.
fun test_timing_end_turn_coherency_mandatory_and_archived() -> Bool:
    let board = timing_fixture()
    let far = board[0][0]
    far.identity = -1
    far.position = board_position(40, 5)
    board[0].models.append(far)
    board.identify_unit(board[0])
    let removed_identity = board[0][1].identity
    let previous_target = unit_id(1)
    board.attack.target = previous_target
    let window = resolve_timing_window(board, TimingWindow::turn_end)
    if can window.finish_timing_rules(board):
        return false
    window.choose_timing_rule(board, TimingRule::regain_coherency)
    window.select_incoherent_unit(board, unit_id(0))
    if board.attack.target.get() != 0:
        return false
    let model : ModelID
    model = 1
    window.remove_incoherent_model(board, model)
    return window.is_done() and board[0].is_coherent() and board[0].destroyed_models.value.size() == 1 and board[0].destroyed_models.value[0].identity == removed_identity and board.attack.target.get() == 1 and board.command_points[0] == 3

# pp.28–30: empty windows complete without dummy decisions.
fun test_timing_empty_start_end_windows_close() -> Bool:
    let board = timing_fixture()
    let start = resolve_timing_window(board, TimingWindow::round_start)
    let finish = resolve_timing_window(board, TimingWindow::round_end)
    return start.is_done() and finish.is_done() and !board.timing.open and !board.current_decision_maker

# p.30: core CP and shock precede Command abilities; decline restores owner.
fun test_timing_command_phase_cp_before_ability() -> Bool:
    let board = timing_fixture()
    board.players_faction[0] = Faction::strike_force_octavius
    let command = command_phase(board)
    return board.command_points[0] == 4 and board.command_points[1] == 4 and board.timing.window == TimingWindow::command_abilities and (can command.choose_timing_rule(board, TimingRule::oath_of_moment))

# p.57: Heroic Intervention is at opponent Charge end, not individual charges.
fun test_timing_heroic_intervention_boundary() -> Bool:
    let board = timing_fixture()
    board[0][0].position = board_position(10, 5)
    board[0].has_charged = true
    return timing_rule_available(board, TimingWindow::charge_end, true, TimingRule::heroic_intervention) and !timing_rule_available(board, TimingWindow::charge_start, true, TimingRule::heroic_intervention) and !timing_rule_available(board, TimingWindow::charge_end, false, TimingRule::heroic_intervention) and Stratagem::heroic_intervention.cost() == 1

# p.8: an opposing unit's move changes the active role, then restores it.
fun test_timing_opponent_move_restores_roles() -> Bool:
    let board = timing_fixture()
    let source = unit_id(1)
    let movement = move(board, source, 0)
    if !board.timing.active_player or !board.current_decision_maker or board.current_player:
        return false
    movement.skip(board, source)
    return movement.is_done() and !board.timing.active_player and !board.current_decision_maker and !board.current_player

# p.8: shooting active role follows attacker even while defender decides.
fun test_timing_opponent_attack_restores_roles() -> Bool:
    let board = timing_fixture()
    board[1][0].position.x = 15
    let sequence = attack(board, unit_id(1), unit_id(0), false, true)
    if !board.timing.active_player or !board.current_decision_maker:
        return false
    let slot : BInt<0, MAX_WEAPONS>
    slot = 1
    sequence.select_weapon(board, slot)
    sequence.skip(board)
    sequence.declare_target(board, unit_id(1), unit_id(0))
    sequence.choose_attack_target(board, unit_id(0))
    if board.current_decision_maker:
        return false
    sequence.no_defensive_stratagem(board)
    if !board.current_decision_maker or !board.timing.active_player:
        return false
    sequence.no_offensive_stratagem(board)
    let weapon : AttackWeaponID
    weapon = 0
    sequence.choose_attack_weapon(board, weapon)
    let one : Dice
    one = 1
    sequence.quantity(board, one)
    sequence.keep_it(board, true)
    sequence.roll(board, one)
    sequence.keep_batch(board)
    return sequence.is_done() and !board.timing.active_player and !board.current_decision_maker and !board.current_player

# p.14 and supplied sequencing: opposing coherency is also mandatory,
# after the current player's removals have finished.
fun test_timing_both_armies_regain_coherency_in_order() -> Bool:
    let board = timing_fixture()
    let far = board[0][0]
    far.identity = -1
    far.position = board_position(40, 5)
    board[0].models.append(far)
    board[1].models.append(far)
    board.identify_unit(board[0])
    board.identify_unit(board[1])
    let window = resolve_timing_window(board, TimingWindow::turn_end)
    window.choose_timing_rule(board, TimingRule::regain_coherency)
    window.select_incoherent_unit(board, unit_id(0))
    let model : ModelID
    model = 1
    window.remove_incoherent_model(board, model)
    if !board.current_decision_maker or can window.finish_timing_rules(board):
        return false
    window.choose_timing_rule(board, TimingRule::regain_coherency)
    window.select_incoherent_unit(board, unit_id(1))
    window.remove_incoherent_model(board, model)
    return window.is_done() and board[0].is_coherent() and board[1].is_coherent() and !board.current_decision_maker

# Existing faction fixture, not a core ability: its chosen target owns the
# shock decision and receives the shock result (generic roles pp.8–9/30).
fun test_timing_neural_disruption_uses_chosen_target_context() -> Bool:
    let board = timing_fixture()
    board[0][0].abilities.append(AbilityKind::neural_disruption)
    board[1][0].position = board_position(10, 5)
    board.players_faction[0] = Faction::insidious_infiltrators
    board.command_points[1] = 0
    let sequence = neural_disruption(board)
    sequence.select_neural_disruption_target(board, unit_id(0), unit_id(1))
    let one : Dice
    one = 1
    sequence.roll_pair(board, one, one)
    if !board[1].battle_socked or board[0].battle_socked or board.current_decision_maker:
        return false
    sequence.skip(board)
    return sequence.is_done()

# p.8: an opposing charger owns its scoped role through dice/reroll input.
fun test_timing_opponent_charge_restores_roles() -> Bool:
    let board = timing_fixture()
    let sequence = charge(board, unit_id(1), unit_id(0), false)
    if !board.timing.active_player or !board.current_decision_maker:
        return false
    let one : Dice
    one = 1
    sequence.roll_pair(board, one, one)
    sequence.keep_it(board, true)
    return sequence.is_done() and !board.timing.active_player and !board.current_decision_maker

# Rule 01.06, p.9. Success against at least one Ld means the lowest threshold.
fun test_01_06_mixed_leadership() -> Bool:
    let unit = make_infernus_squad()
    unit[1].profile = Profile::beast_snagga_boy
    return unit.get_leadership() == 6

# p.86: odd model counts cannot be exactly half; use the unrounded threshold.
fun test_half_strength_odd_and_even_model_counts() -> Bool:
    let unit = make_infernus_squad()
    unit.capture_starting_strength()
    unit.models.erase(4)
    unit.models.erase(3)
    if unit.is_at_or_below_half_strength() or unit.is_below_half_strenght():
        return false
    unit.models.erase(2)
    if !unit.is_at_or_below_half_strength() or !unit.is_below_half_strenght():
        return false
    unit.starting_strenght = 4
    return unit.is_at_or_below_half_strength() and !unit.is_below_half_strenght()

# p.86: a lone model uses remaining wounds, including exact and odd boundaries.
fun test_half_strength_single_model_wounds() -> Bool:
    let unit = make_octavius()
    unit.capture_starting_strength()
    unit[0].suffered_wounds = 2
    if unit.is_at_or_below_half_strength():
        return false
    unit[0].suffered_wounds = 3
    if !unit.is_at_or_below_half_strength() or unit.is_below_half_strenght():
        return false
    unit[0].suffered_wounds = 4
    if !unit.is_below_half_strenght():
        return false
    unit[0].profile = Profile::librarian_tantus
    unit[0].suffered_wounds = 2
    if unit.is_at_or_below_half_strength():
        return false
    unit[0].suffered_wounds = 3
    return unit.is_at_or_below_half_strength() and unit.is_below_half_strenght()

# p.86: a surviving full-health leader uses combined initial strength.
# This fixture verifies the threshold only; task 6 attachment changes are deferred.
fun test_half_strength_combined_count_survives_casualties() -> Bool:
    let unit = make_octavius()
    unit.starting_strenght = 6
    return unit.is_at_or_below_half_strength() and unit.is_below_half_strenght()

# pp.19/86: retired/empty/uninitialized fixtures cannot require a shock roll.
fun test_half_strength_empty_and_uninitialized_units() -> Bool:
    let unit : Unit
    if unit.is_at_or_below_half_strength() or unit.is_below_half_strenght():
        return false
    unit = make_octavius()
    unit.starting_strenght = 0
    return !unit.is_at_or_below_half_strength() and !unit.is_below_half_strenght()

# Rule 08.03, p.30. Opponent's shock is not cleared by our Command phase.
fun test_08_03_opponent_shock_persists() -> Bool:
    let board : Board
    let unit = make_tantus()
    unit.owned_by_player1 = true
    unit.battle_socked = true
    board.units.append(unit)
    let step = battle_shock_step(board)
    return board[0].battle_socked

# p.30: a live full-strength unit still rolls if already battle-shocked.
fun test_command_shocked_full_strength_recovers_on_success() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    board[0].capture_starting_strength()
    board[0].battle_socked = true
    board.begin_phase(BattlePhase::command)
    let step = battle_shock_step(board)
    let three : Dice
    three = 3
    if !(can step.roll_pair(board, three, three)) or !board[0].battle_socked:
        return false
    step.roll_pair(board, three, three)
    return step.is_done() and !board[0].battle_socked

# pp.9/30: failure keeps existing shock and does not spend CP on a reroll.
fun test_command_failed_recovery_preserves_shock() -> Bool:
    let board : Board
    board.units.append(make_tantus())
    board[0].capture_starting_strength()
    board[0].battle_socked = true
    board.command_points[0] = 2
    board.begin_phase(BattlePhase::command)
    let step = battle_shock_step(board)
    let one : Dice
    one = 1
    if can step.insane_bravery(board, true):
        return false
    step.roll_pair(board, one, one)
    return step.is_done() and board[0].battle_socked and board.command_points[0] == 2

# p.30: meeting both conditions causes exactly one roll, including exact half.
fun test_command_exact_half_and_shocked_rolls_once() -> Bool:
    let board : Board
    board.units.append(make_octavius())
    board[0].capture_starting_strength()
    board[0][0].suffered_wounds = 3
    board[0].battle_socked = true
    let step = battle_shock_step(board)
    let three : Dice
    three = 3
    step.roll_pair(board, three, three)
    return step.is_done() and !board[0].battle_socked

# pp.30/86: multi-model exact half rolls; an odd count above half does not.
fun test_command_model_count_eligibility() -> Bool:
    let board : Board
    let unit = make_infernus_squad()
    unit.capture_starting_strength()
    unit.models.resize(3)
    board.units.append(unit)
    let no_roll = battle_shock_step(board)
    if !no_roll.is_done():
        return false
    board[0].starting_strenght = 6
    let half_roll = battle_shock_step(board)
    let one : Dice
    one = 1
    if !(can half_roll.roll_pair(board, one, one)):
        return false
    half_roll.roll_pair(board, one, one)
    return half_roll.is_done() and board[0].battle_socked

# pp.19/30: no roll/indexing for retired units or healthy units above half.
fun test_command_empty_and_healthy_units_are_skipped() -> Bool:
    let board : Board
    board.units.append(make_octavius())
    board[0].capture_starting_strength()
    board.units.append(make_tantus())
    board[1].damage(0, 100)
    board[1].battle_socked = true
    let step = battle_shock_step(board)
    return step.is_done() and !board[0].battle_socked and board[1].battle_socked

# pp.9/30: a successful roll outside the recovery step does not clear shock.
fun test_shock_success_outside_command_does_not_recover() -> Bool:
    let board = timing_fixture()
    board[1].battle_socked = true
    let step = battle_shock_test(board, board[1], false, false)
    let three : Dice
    three = 3
    if !board.current_decision_maker:
        return false
    step.roll_pair(board, board[1], three, three)
    return step.is_done() and board[1].battle_socked and !board.current_decision_maker

# p.9: 2D6 reaches the easier Ld6 exactly, although another model has Ld7.
fun test_shock_roll_uses_lowest_mixed_leadership() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    board[0][1].profile = Profile::beast_snagga_boy
    let step = battle_shock_test(board, board[0], false, false)
    let three : Dice
    three = 3
    step.roll_pair(board, board[0], three, three)
    if !step.is_done() or board[0].battle_socked:
        return false
    step = battle_shock_test(board, board[0], false, false)
    let two : Dice
    two = 2
    step.roll_pair(board, board[0], three, two)
    return step.is_done() and board[0].battle_socked

# p.56: Insane Bravery cannot be offered for an out-of-step faction shock roll.
fun test_bravery_only_in_own_command_shock_step() -> Bool:
    let board = timing_fixture()
    board.begin_phase(BattlePhase::command)
    let outside = battle_shock_test(board, board[0], false, false)
    let opposing = battle_shock_test(board, board[1], true, false)
    board.timing.phase = BattlePhase::movement
    let wrong_phase = battle_shock_test(board, board[0], true, false)
    return !(can outside.insane_bravery(board, board[0], true)) and !(can opposing.insane_bravery(board, board[1], true)) and !(can wrong_phase.insane_bravery(board, board[0], true))

# pp.54/56: declining Bravery preserves CP, once-per-battle flag and target use.
fun test_bravery_decline_preserves_battle_and_phase_limits() -> Bool:
    let board = timing_fixture()
    board.begin_phase(BattlePhase::command)
    let step = battle_shock_test(board, board[0], true, false)
    step.insane_bravery(board, board[0], false)
    let three : Dice
    three = 3
    step.roll_pair(board, board[0], three, three)
    return step.is_done() and board.command_points[0] == 3 and !board.has_used_insane_bravery[0] and !board[0].history.stratagem_targeted_by_player[0]

# p.56: accepting Bravery is successful without dice; later phases cannot reuse.
fun test_bravery_once_per_battle_survives_phase_and_turn_reset() -> Bool:
    let board = timing_fixture()
    board.begin_phase(BattlePhase::command)
    let step = battle_shock_test(board, board[0], true, false)
    step.insane_bravery(board, board[0], true)
    if !step.is_done() or board[0].battle_socked or board.command_points[0] != 2:
        return false
    board.begin_phase(BattlePhase::movement)
    board.start_turn_history()
    board.begin_phase(BattlePhase::command)
    let again = battle_shock_test(board, board[0], true, false)
    let three : Dice
    three = 3
    return board.has_used_insane_bravery[0] and !(can again.insane_bravery(board, board[0], true)) and (can again.roll_pair(board, board[0], three, three))

# p.30: CP is granted before shock; Command abilities wait until shock resolves.
fun test_command_cp_then_shock_then_abilities() -> Bool:
    let board = timing_fixture()
    board[0].battle_socked = true
    board.players_faction[0] = Faction::strike_force_octavius
    let command = command_phase(board)
    let three : Dice
    three = 3
    if board.command_points[0] != 4 or board.command_points[1] != 4 or (can command.choose_timing_rule(board, TimingRule::oath_of_moment)):
        return false
    command.roll_pair(board, three, three)
    return !board[0].battle_socked and (can command.choose_timing_rule(board, TimingRule::oath_of_moment)) and board.current_decision_maker == board.current_player

# Rule 01.07, p.9. Battle-shocked models contribute no OC.
fun test_01_07_shock_removes_objective_control() -> Bool:
    let board : Board
    let unit = make_tantus()
    unit.move_to(make_board_position(10, 10))
    unit.battle_socked = true
    board.units.append(unit)
    return board.get_objective_controller(10, 10) == -1


# p.9: every model inherits shock, OC '-', and the action start/completion ban.
# Full mission-action workflow remains task 15; these are its required gates.
fun test_shock_model_control_and_action_restrictions() -> Bool:
    let unit = make_infernus_squad()
    unit.history.action_started = true
    if !unit.allows_action_start() or !unit.allows_action_completion():
        return false
    unit.battle_socked = true
    for i in range(unit.models.size()):
        if !unit.model_is_battle_shocked(i) or unit.model_objective_control(i) != 0:
            return false
    if unit.allows_action_start() or unit.allows_action_completion():
        return false
    unit.battle_socked = false
    return unit.allows_action_start() and unit.allows_action_completion() and !unit.model_is_battle_shocked(0) and unit.model_objective_control(0) == 1 and unit.history.action_started

# p.9: a shocked friendly unit cannot erase a healthy unit's contribution.
# This tests the shock exclusion, not task 8's unfinished aggregation formula.
fun test_shock_control_exclusion_preserves_other_friendly_models() -> Bool:
    let board : Board
    let unit = make_tantus()
    unit[0].position = board_position(10, 10)
    board.units.append(unit)
    unit.battle_socked = true
    board.units.append(unit)
    return board.get_objective_controller(10, 10) == 0

# pp.54/56: all spending entrypoints observe battle-long Bravery usage.
fun test_bravery_central_battle_limit_and_independent_players() -> Bool:
    let board = timing_fixture()
    board.commit_stratagem(false, Stratagem::insane_bravery, board[0])
    board.clear_phase_modifiers()
    if board.can_use_strat(false, Stratagem::insane_bravery) or board.can_target_strat_with_cost(false, Stratagem::insane_bravery, board[0], 0):
        return false
    if board.try_use_strat(false, Stratagem::insane_bravery, board[0], 0):
        return false
    return board.can_target_strat(true, Stratagem::insane_bravery, board[1]) and board.can_target_strat(false, Stratagem::reroll, board[0]) and board.command_points[0] == 2

# p.9: the existing Dark Pact consumer must use both Leadership dice.
# This does not claim new-edition faction effect/eligibility certification.
fun test_leadership_consumer_uses_complete_pair_total() -> Bool:
    let board = timing_fixture()
    board.players_faction[0] = Faction::zarkan_daemonkin
    board.players_faction[1] = Faction::zarkan_daemonkin
    let strats = use_attack_stratagems(board, unit_id(0), unit_id(1), false)
    strats.no_defensive_stratagem(board)
    strats.use_dark_pact(board)
    let three : Dice
    three = 3
    strats.roll_pair(board, three, three)
    return (can strats.select_ability(board, true)) and board[0][0].suffered_wounds == 0

# Save infrastructure must preserve battle-long Bravery usage (p.56) and reject
# pre-task-7 schemas; the book does not prescribe serialization/version numbers.
fun test_bravery_battle_limit_save_round_trip() -> Bool:
    let state = play()
    state.board.has_used_insane_bravery[0] = true
    let restored = play()
    if !set_state(restored, to_string(state)):
        return false
    if !restored.board.has_used_insane_bravery[0] or restored.board.has_used_insane_bravery[1]:
        return false
    state.board.schema_version.value = 5
    return !set_state(restored, to_string(state)) and restored.board.has_used_insane_bravery[0]

# Rule 14.02, p.52. Two OC1 models beat one OC2 model only with an extra OC1.
fun test_14_02_sum_objective_control() -> Bool:
    let board : Board
    let friendly = make_infernus_squad()
    friendly.models.erase(4)
    friendly.models.erase(3)
    friendly.move_to(make_board_position(10, 10))
    friendly.owned_by_player1 = false
    let enemy = make_beast_snagga_boyz()
    while enemy.models.size() > 1:
        enemy.models.erase(enemy.models.size() - 1)
    enemy.move_to(make_board_position(10, 10))
    enemy.owned_by_player1 = true
    board.units.append(friendly)
    board.units.append(enemy)
    return board.get_objective_controller(10, 10) == 0

# Rule 14.02, p.52. An unsecured equal nonzero total is uncontrolled.
fun test_14_02_tied_objective_uncontrolled() -> Bool:
    let board : Board
    let a = make_tantus()
    a.move_to(make_board_position(10, 10))
    let b = a
    b.owned_by_player1 = true
    board.units.append(a)
    board.units.append(b)
    return board.get_objective_controller(10, 10) == -1

# Rule 15.01, p.54. A 1CP stratagem is affordable with 1CP.
# Rule 15.01, p.54. Usage belongs to the player who used the stratagem.
# Rule 08.02, p.30. Core CP gain must not disappear at the arbitrary storage cap.
# Does not assert a general additional-CP-generation policy (external gate D12).
# Rule 09.06, p.33. D6=5 must provide the complete five-inch increment.

# Area fixture uses whole-inch boundaries and explicit categories (pp.46–47).
fun terrain_area(Int x1, Int y1, Int x2, Int y2, Bool dense) -> TerrainArea:
    let area : TerrainArea
    area.lower = geometry_point(x1 * MICROMETRES_PER_INCH, y1 * MICROMETRES_PER_INCH, 0)
    area.upper = geometry_point(x2 * MICROMETRES_PER_INCH, y2 * MICROMETRES_PER_INCH, 0)
    area.dense = dense
    area.exposed = !dense
    return area

# p.88: closest base/marker edges, not centres, with separate vertical limit.
fun test_objective_marker_base_and_height_boundaries() -> Bool:
    let board : Board
    let model = make_octavius()[0]
    let objective : Objective
    objective.position = board_position(10, 10)
    model.position = board_position(14, 10)
    model.geometry.elevation = 5
    if !board.model_in_objective_range(model, objective):
        return false
    model.geometry.elevation = 6
    if board.model_in_objective_range(model, objective):
        return false
    model.geometry.elevation = 0
    model.position.x = 15
    if board.model_in_objective_range(model, objective):
        return false
    # 40mm marker + 50mm base is 45mm: at 4in centres the edge gap is <3in.
    model.position.x = 14
    model.geometry.unsupported_footprint = true
    return !board.model_in_objective_range(model, objective)

# pp.52/88: the whole terrain area is the objective, without a marker's height cap.
fun test_terrain_objective_uses_area_and_base_intersection() -> Bool:
    let board : Board
    board.terrain_areas.append(terrain_area(9, 9, 15, 15, true))
    board.set_objective_position(0, board_position(10, 10))
    if !board.link_objective_terrain_areas():
        return false
    let model = make_tantus()[0]
    model.position = board_position(15, 15)
    model.geometry.elevation = 10
    if !board.model_in_objective_range(model, board.objective_range_definition(0)):
        return false
    model.position = board_position(18, 10)
    return !board.model_in_objective_range(model, board.objective_range_definition(0))

# p.52: initial control is none, then snapshots change only at boundaries.
fun test_objective_control_initial_and_boundary_snapshot() -> Bool:
    let board : Board
    let unit = make_tantus()
    unit[0].position = board_position(12, 15)
    board.units.append(unit)
    if board.get_objective_controller(0) != -1:
        return false
    board.update_objective_control(true)
    if board.get_objective_controller(0) != 0:
        return false
    board[0][0].position = board_position(2, 2)
    if board.get_objective_controller(0) != 0:
        return false
    board.update_objective_control(false)
    return board.get_objective_controller(0) == -1

# p.52: securing survives absence and ties, and expires on superior opponent OC.
fun test_secured_objective_absence_tie_and_phase_loss() -> Bool:
    let board : Board
    let unit = make_tantus()
    unit[0].position = board_position(12, 15)
    board.units.append(unit)
    board.update_objective_control(true)
    board.grant_secured_objective(0, false)
    board[0][0].position = board_position(2, 2)
    board.update_objective_control(true)
    if board.get_objective_controller(0) != 0:
        return false
    unit.owned_by_player1 = true
    board.units.append(unit)
    board.update_objective_control(false)
    if board.get_objective_controller(0) != 0:
        return false
    board.update_objective_control(true)
    return board.get_objective_controller(0) == 1 and board.objectives[0].secured_by == ObjectiveController::none

# p.52: a secured tie keeps its owner; unsecure equal nonzero totals lose control.
fun test_secured_objective_equal_nonzero_totals() -> Bool:
    let board : Board
    let unit = make_tantus()
    unit[0].position = board_position(12, 15)
    board.units.append(unit)
    board.update_objective_control(true)
    board.grant_secured_objective(0, false)
    unit.owned_by_player1 = true
    board.units.append(unit)
    board.update_objective_control(true)
    return board.get_objective_controller(0) == 0 and board.objectives[0].secured_by == ObjectiveController::army_0

# p.53: controlling unit requires own army control, range and positive OC.
fun test_objective_controlling_unit_and_shock() -> Bool:
    let board : Board
    let unit = make_tantus()
    unit[0].position = board_position(12, 15)
    board.units.append(unit)
    board.update_objective_control(true)
    if !board.unit_controls_objective(board[0], 0):
        return false
    board[0].battle_socked = true
    if board.unit_controls_objective(board[0], 0):
        return false
    board.update_objective_control(true)
    return board.get_objective_controller(0) == -1 and !board.unit_controls_objective(board[0], -1)

# pp.30/52: core control grants no points; explicit legacy mission scores each ID.
fun test_mission_scoring_explicit_and_correct_for_both_players() -> Bool:
    let board : Board
    board.objectives[0].controller = ObjectiveController::army_0
    board.objectives[1].controller = ObjectiveController::army_1
    board.objectives[2].controller = ObjectiveController::army_0
    board.objectives[3].controller = ObjectiveController::army_1
    board.score()
    if board.score[0] != 0 or board.score[1] != 0:
        return false
    board.mission_scoring = MissionScoringMode::legacy_four_markers
    board.score()
    board.current_player = true
    board.score()
    return board.score[0] == 10 and board.score[1] == 10

# p.52: phase/turn hooks update control; start hooks must not do so.
fun test_objective_phase_and_turn_control_hooks() -> Bool:
    let board : Board
    let unit = make_tantus()
    unit[0].position = board_position(12, 15)
    board.units.append(unit)
    let start = resolve_timing_window(board, TimingWindow::movement_start)
    if !start.is_done() or board.get_objective_controller(0) != -1:
        return false
    let end = resolve_timing_window(board, TimingWindow::movement_end)
    if !end.is_done() or board.get_objective_controller(0) != 0:
        return false
    board[0][0].position = board_position(2, 2)
    let turn_end = resolve_timing_window(board, TimingWindow::turn_end)
    return turn_end.is_done() and board.get_objective_controller(0) == -1

# Save/configuration infrastructure retains boundary/secured state (p.52),
# rejects malformed areas and dangling links, and preserves schema compatibility.
fun test_objective_and_area_save_integrity() -> Bool:
    let state = play()
    state.board.terrain_areas.append(terrain_area(9, 9, 15, 15, true))
    state.board.set_objective_position(0, board_position(10, 10))
    state.board.link_objective_terrain_areas()
    state.board.objectives[0].controller = ObjectiveController::army_1
    state.board.objectives[0].secured_by = ObjectiveController::army_1
    let restored = play()
    if !set_state(restored, to_string(state)) or restored.board.get_objective_controller(0) != 1:
        return false
    state.board.objectives[0].area_id = 15
    if set_state(restored, to_string(state)):
        return false
    state.board.objectives[0].area_id = 0
    state.board.terrain_areas[0].upper = state.board.terrain_areas[0].lower
    return !set_state(restored, to_string(state)) and restored.board.objectives[0].secured_by == ObjectiveController::army_1

# pp.46/52 and user's scope: only valid categorized whole-quad areas are accepted.
fun test_terrain_area_categories_and_transactional_links() -> Bool:
    let board : Board
    let area = terrain_area(10, 10, 14, 20, false)
    area.light = true
    area.dense = true
    if !valid_terrain_area(area):
        return false
    board.terrain_areas.append(area)
    if !board.link_objective_terrain_areas() or !board.objectives[0].terrain_objective:
        return false
    board.terrain_areas.append(area)
    if board.link_objective_terrain_areas():
        return false
    if board.objectives[0].area_id.value != 0:
        return false
    area.exposed = false
    area.light = false
    area.dense = false
    return !valid_terrain_area(area)

# p.9 and supplied Within: a large base can intersect an area outside its centre.
fun test_terrain_area_membership_uses_base_and_model_keywords() -> Bool:
    let board : Board
    board.terrain_areas.append(terrain_area(10, 10, 15, 15, false))
    let model = make_tantus()[0]
    model.position = board_position(9, 12)
    model.profile = Profile::squighog_boyz
    if !board.model_in_terrain_area(model, 0):
        return false
    model.position.x = 8
    if board.model_in_terrain_area(model, 0):
        return false
    model.keywords.clear()
    if terrain_cover_model_kind(model):
        return false
    model.keywords.append(Keyword::swarm)
    return terrain_cover_model_kind(model)

# User's area-only approximation: crossing means partial, never physical blocking.
fun test_area_crossing_partial_visibility_and_cover() -> Bool:
    let board = geometry_fixture()
    let target = make_tantus()
    target[0].position = board_position(20, 5)
    board.terrain_areas.append(terrain_area(10, 4, 12, 6, true))
    if !model_visible_to_model(board, board[0][0], target, target[0]) or !model_partially_obscured(board, board[0][0], target[0]) or !unit_has_benefit_of_cover(board, board[0][0], target):
        return false
    target[0].position.y = 15
    return model_visible_to_model(board, board[0][0], target, target[0]) and !model_partially_obscured(board, board[0][0], target[0]) and !unit_has_benefit_of_cover(board, board[0][0], target)

# User's quad ray approximation includes tangent crossings and endpoints.
fun test_area_crossing_boundary_and_endpoint() -> Bool:
    let source = make_tantus()[0]
    let target = source
    source.position = board_position(5, 5)
    target.position = board_position(20, 5)
    let area = terrain_area(10, 5, 12, 7, false)
    if !sight_crosses_terrain_area(source, target, area):
        return false
    source.position.y = 4
    target.position.y = 4
    if sight_crosses_terrain_area(source, target, area):
        return false
    target.position = board_position(10, 6)
    return sight_crosses_terrain_area(source, target, area)

# p.50: all target models need cover, possibly from different conditions.
# Unit-level inherited Infantry cannot make a non-Infantry member eligible.
fun test_cover_requires_each_model_and_preserves_model_keywords() -> Bool:
    let board = geometry_fixture()
    board[0][0].position = board_position(2, 5)
    let target = make_infernus_squad()
    target.models.resize(2)
    target[0].position = board_position(18, 5)
    target[1].position = board_position(18, 10)
    target[1].profile = Profile::squighog_boyz
    board.terrain_areas.append(terrain_area(9, 4, 12, 6, false))
    if unit_has_benefit_of_cover(board, board[0][0], target):
        return false
    board.terrain_areas.append(terrain_area(19, 10, 21, 12, false))
    if !unit_has_benefit_of_cover(board, board[0][0], target):
        return false
    target[1].keywords.clear()
    return target.has_keyword(Keyword::infantry) and !unit_has_benefit_of_cover(board, board[0][0], target)

# p.50: a dense-area model is hidden until it fires; the previous turn matters.
fun test_hidden_current_previous_turn_and_never_fired() -> Bool:
    let board = geometry_fixture()
    board.terrain_areas.append(terrain_area(4, 4, 6, 6, true))
    if !model_is_hidden(board, board[0], board[0][0]):
        return false
    board.turn_serial = 10
    board.record_ranged_attacks(unit_id(0))
    if model_is_hidden(board, board[0], board[0][0]):
        return false
    board.start_turn_history()
    if model_is_hidden(board, board[0], board[0][0]):
        return false
    board.start_turn_history()
    return model_is_hidden(board, board[0], board[0][0])

# p.50: Hidden belongs to qualifying models in dense areas; light is insufficient.
fun test_hidden_dense_category_and_individual_keyword() -> Bool:
    let board = geometry_fixture()
    let area = terrain_area(4, 4, 6, 6, false)
    area.light = true
    board.terrain_areas.append(area)
    if model_is_hidden(board, board[0], board[0][0]):
        return false
    board.terrain_areas[0].dense = true
    board[0][0].keywords.clear()
    if model_is_hidden(board, board[0], board[0][0]):
        return false
    board[0][0].keywords.append(Keyword::beasts)
    return model_is_hidden(board, board[0], board[0][0])

# p.50: base-to-base detection, default 15in, explicit supplied range overrides.
fun test_hidden_detection_range_and_unit_visibility() -> Bool:
    let board = geometry_fixture()
    let target = make_tantus()
    target[0].position = board_position(22, 5)
    board.terrain_areas.append(terrain_area(21, 4, 23, 6, true))
    if model_visible_to_model(board, board[0][0], target, target[0]):
        return false
    if !model_visible_to_model(board, board[0][0], target, target[0], 20):
        return false
    board[0][0].position.x = 6
    if !model_visible_to_model(board, board[0][0], target, target[0]):
        return false
    if model_visible_to_model(board, board[0][0], target, target[0], -1):
        return false
    board[0][0].position.x = 5
    let visible = target[0]
    visible.position = board_position(25, 5)
    target.models.append(visible)
    if !model_can_see_unit(board, board[0][0], target) or !unit_visible_to_unit(board, board[0], target):
        return false
    target.models.clear()
    return !unit_visible_to_unit(board, board[0], target) and !unit_has_benefit_of_cover(board, board[0][0], target)

# p.50: BS worsens separately from hit modifiers/saves; p.82 Ignores Cover cancels.
fun test_cover_changes_bs_not_hit_modifier_or_save() -> Bool:
    let board = attack_fixture()
    board.attack_info.target_has_cover = true
    let base = board.attack_info.source.skill()
    let original_save = board[1][0].profile.save()
    if effective_attack_skill(board, board.attack_info) != base + 1 or board.attack_info.total_hit_modifier() != 0 or board[1][0].profile.save() != original_save:
        return false
    board.attack_info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::ignore_cover))
    if effective_attack_skill(board, board.attack_info) != base:
        return false
    board.attack_info.temporary_weapon_abilities.clear()
    board.attack_info.source = Weapon::relic_weapon
    return effective_attack_skill(board, board.attack_info) == board.attack_info.source.skill()

# pp.18/50: natural six succeeds even at modified BS7; natural one always fails.
fun test_cover_high_bs_natural_six_and_modified_threshold() -> Bool:
    let six : Dice
    six = 6
    let one : Dice
    one = 1
    let three : Dice
    three = 3
    return attack_hit_roll_succeeds(six, -1, 7) and !attack_hit_roll_succeeds(one, 10, 2) and attack_hit_roll_succeeds(three, 1, 4) and !attack_hit_roll_succeeds(three, 0, 4)

# p.50: native attack resolution uses covered BS and records even a missed shot.
fun test_cover_attack_hit_transition_and_actual_shot_history() -> Bool:
    let board = attack_fixture()
    board.attack_info.target_has_cover = true
    board.turn_serial = 4
    let attack = single_attack(board, board[1], board[0])
    let two : Dice
    two = 2
    attack.roll(board, board[1], board[0], two)
    if !attack.is_done() or board[0].history.last_ranged_attack_turn != 4:
        return false
    attack = single_attack(board, board[1], board[0])
    let three : Dice
    three = 3
    attack.roll(board, board[1], board[0], three)
    let expected = CurrentStateDescription::wound_roll
    return (can attack.roll(board, board[1], board[0], three)) and board.current_state.value == expected.value

# p.50: selecting a unit but skipping its weapons does not break Hidden.
fun test_skipped_shooting_does_not_record_ranged_attacks() -> Bool:
    let board = timing_fixture()
    board[0].can_shoot = true
    let shooting = shooting_phase(board)
    shooting.select_target(board, unit_id(0), unit_id(1))
    shooting.skip(board)
    return board[0].has_shoot and board[0].history.last_ranged_attack_turn == -1 and (can shooting.end_shooting_phase(board))

# pp.16/50/57: unit selectors, per-model weapons and Overwatch respect Hidden.
fun test_hidden_target_rejected_by_shooting_and_overwatch() -> Bool:
    let board = timing_fixture()
    board[0].can_shoot = true
    board[1][0].position.x = 22
    board.terrain_areas.append(terrain_area(21, 4, 23, 6, true))
    let shooting = shooting_phase(board)
    if can shooting.select_target(board, unit_id(0), unit_id(1)):
        return false
    if overwatch_target_valid(board, unit_id(0), unit_id(1)):
        return false
    board[1].history.last_ranged_attack_turn = board.turn_serial
    return (can shooting.select_target(board, unit_id(0), unit_id(1))) and overwatch_target_valid(board, unit_id(0), unit_id(1))

# Rules 02.04/04.03, pp.10/17: a fixed A characteristic supplies that many dice.
# The implementation checks `stat is Int` although raw_stat wraps a bounded Int.
fun test_02_04_fixed_attack_characteristic() -> Bool:
    let attacks = evaluate_random_stat(raw_stat(4))
    return attacks.is_done() and attacks.result.value == 4

# Rule 05.02, p.18. Existing strict > misses the exact double boundary.
fun test_05_02_exact_double_strength() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    let info : AttackSequenceInfo
    info.source = Weapon::captain_storm_bolter
    info.target_toughness = info.source.strenght() / 2
    return required_wound_roll(board, info) == 2

# Rule 05.02, p.18. Existing strict < misses the exact half boundary.
fun test_05_02_exact_half_strength() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    let info : AttackSequenceInfo
    info.source = Weapon::captain_storm_bolter
    info.target_toughness = info.source.strenght() * 2
    return required_wound_roll(board, info) == 6

# Test-only explicit characteristic/slot constructors retain finite domains.
fun attack_test_die(Int value) -> Dice:
    let result : Dice
    result = value
    return result

fun attack_test_count(Int value) -> CombatCounter:
    let result : CombatCounter
    result = value
    return result

fun attack_test_slot(Int value) -> BInt<0, MAX_WEAPONS>:
    let result : BInt<0, MAX_WEAPONS>
    result = value
    return result

fun attack_test_weapon(Int value) -> AttackWeaponID:
    let result : AttackWeaponID
    result = value
    return result

fun attack_test_share(Int value) -> AttackShareChoice:
    let result : AttackShareChoice
    result = value
    return result

# Explicit generic fixture, not a supplied army datasheet: one bolter bearer
# and two enemy units for declaration/grouping boundary tests (pp.16–18).
fun attack_declaration_fixture() -> Board:
    let board = attack_fixture()
    board[0].models.resize(1)
    board[1].models.resize(1)
    board[0][0].position = board_position(5, 5)
    board[1][0].position = board_position(10, 5)
    board[0][0].weapons.clear()
    board[0][0].weapons.append(Weapon::captain_storm_bolter)
    let other = board[1]
    other[0].identity = -1
    other.identity = -1
    other[0].position = board_position(10, 8)
    board.units.append(other)
    board.identify_units()
    return board

# p.16: all weapons and targets are declared before the first hit roll.
fun test_attack_declarations_precede_rolls_and_allow_different_targets() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.append(Weapon::librarian_storm_bolter)
    let sequence = attack(board, unit_id(0), unit_id(1), false, false)
    sequence.select_weapon(board, attack_test_slot(0))
    sequence.select_weapon(board, attack_test_slot(1))
    if can sequence.roll(board, attack_test_die(6)):
        return false
    sequence.skip(board)
    if (can sequence.declare_target(board, unit_id(1), unit_id(2))) or (can sequence.declare_target(board, unit_id(0), unit_id(0))):
        return false
    sequence.declare_target(board, unit_id(0), unit_id(1))
    if can sequence.choose_attack_target(board, unit_id(1)):
        return false
    sequence.declare_target(board, unit_id(0), unit_id(2))
    return sequence.declarations.size() == 2 and sequence.declarations[0].targeted[1] and sequence.declarations[1].targeted[2] and (can sequence.choose_attack_target(board, unit_id(1))) and (can sequence.choose_attack_target(board, unit_id(2))) and !(can sequence.roll(board, attack_test_die(6)))

# pp.16–17: range/visibility belong to each bearer, not another nearby member.
fun test_attack_declaration_per_model_range_and_engaged_target() -> Bool:
    let board = attack_declaration_fixture()
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    if !declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false):
        return false
    board[1][0].position = board_position(40, 5)
    if declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false):
        return false
    board[1][0].position = board_position(8, 5)
    return !declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false) and declaration_target_valid(board, unit_id(0), weapon, unit_id(1), true)

# p.16: no mixing ranged/melee selections, duplicate slots or two main melee
# weapons; ending before the required melee selection is illegal.
fun test_attack_weapon_selection_modes_duplicates_and_required_melee() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.append(Weapon::relic_weapon)
    board[0][0].weapons.append(Weapon::force_weapon)
    let selected : Bool[MAX_WEAPONS]
    if weapon_selection_valid(board, unit_id(0), 0, 0, true, selected, false) or weapon_selection_valid(board, unit_id(0), 0, 1, false, selected, false):
        return false
    if may_finish_weapon_selection(board, unit_id(0), 0, true, false):
        return false
    selected[0] = true
    return !weapon_selection_valid(board, unit_id(0), 0, 0, false, selected, false) and !weapon_selection_valid(board, unit_id(0), 0, 2, true, selected, true) and may_finish_weapon_selection(board, unit_id(0), 0, true, true)

# p.17: split shares add to A and allocate at least one per selected target.
fun test_attack_melee_split_budget_and_target_uniqueness() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0] = Weapon::relic_weapon
    board[1][0].position = board_position(8, 5)
    board[2][0].position = board_position(5, 8)
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    let targets = declare_weapon_targets(board, weapon, unit_id(0), true)
    targets.declare_target(board, unit_id(0), unit_id(1))
    if can targets.assign_attacks(board, attack_test_share(7)):
        return false
    targets.assign_attacks(board, attack_test_share(2))
    if can targets.declare_target(board, unit_id(0), unit_id(1)):
        return false
    targets.declare_target(board, unit_id(0), unit_id(2))
    if can targets.assign_attacks(board, attack_test_share(3)):
        return false
    targets.assign_attacks(board, attack_test_share(4))
    return targets.is_done() and targets.weapon.shares[1] == 2 and targets.weapon.shares[2] == 4

# p.17: a sole eligible target must receive all remaining melee attacks,
# preventing a partial allocation from creating a selector with no choices.
fun test_attack_melee_single_target_cannot_leave_unallocatable_share() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0] = Weapon::relic_weapon
    board[1][0].position = board_position(8, 5)
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    let targets = declare_weapon_targets(board, weapon, unit_id(0), true)
    targets.declare_target(board, unit_id(0), unit_id(1))
    return !(can targets.assign_attacks(board, attack_test_share(5))) and (can targets.assign_attacks(board, attack_test_share(6)))

# p.17: mandatory coalescing gathers three A2 weapons, not one model at a time.
# Disable Rapid Fire distance in this fixture to demonstrate exactly six dice.
fun test_attack_identical_weapons_gather_as_one_group() -> Bool:
    let board = attack_declaration_fixture()
    board[1][0].position.x = 22
    let declarations : DeclaredWeapons
    for i in range(3):
        let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
        weapon.targeted[1] = true
        declarations.append(weapon)
    configure_attack_info(board, 0, 1, false, false)
    let group = gather_attack_group(board, declarations, unit_id(0), unit_id(1), attack_test_weapon(1), false, board.attack_info)
    return group.is_done() and group.count == 6 and declarations[0].resolved[1] and declarations[1].resolved[1] and declarations[2].resolved[1]

# p.17: differing cover/BS, D kinds, abilities and roll rules cannot coalesce.
fun test_attack_group_identity_includes_characteristics_and_applicable_rules() -> Bool:
    let board = attack_declaration_fixture()
    let left = board.attack_info
    let right = left
    if !attacks_are_identical(board, left, right):
        return false
    right.target_has_cover = true
    if attacks_are_identical(board, left, right):
        return false
    right = left
    right.add_letal_hits()
    if attacks_are_identical(board, left, right):
        return false
    right = left
    right.reroll1_hits = true
    return !attacks_are_identical(board, left, right) and !same_damage_characteristic(raw_stat(3), dice_stat(3))

# Supplied appendix 02.02.03: random A is rolled separately for each identical
# weapon at gathering, then combined; neither weapon rolls damage or hits yet.
fun test_attack_random_attacks_per_weapon_before_group_hits() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0] = Weapon::smite_witchfire
    let declarations : DeclaredWeapons
    for i in range(2):
        let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
        weapon.targeted[1] = true
        declarations.append(weapon)
    configure_attack_info(board, 0, 1, false, false)
    let group = gather_attack_group(board, declarations, unit_id(0), unit_id(1), attack_test_weapon(0), false, board.attack_info)
    group.quantity(board, declarations, attack_test_die(2))
    if group.is_done() or group.count != 2:
        return false
    group.quantity(board, declarations, attack_test_die(5))
    return group.is_done() and group.count == 7

# Supplied appendix 04.03.03: moved-out-of-range and destroyed targets allow
# selecting a new target; keep the originally declared melee share unchanged.
fun test_attack_ineligible_target_can_be_redirected() -> Bool:
    let board = attack_declaration_fixture()
    let declarations : DeclaredWeapons
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    weapon.targeted[1] = true
    weapon.shares[1] = 2
    declarations.append(weapon)
    board[1][0].position.x = 40
    let correction = revalidate_attack_targets(board, declarations, unit_id(0), false)
    if can correction.retarget_weapon(board, declarations, unit_id(0), unit_id(1)):
        return false
    correction.retarget_weapon(board, declarations, unit_id(0), unit_id(2))
    return correction.is_done() and declarations[0].resolved[1] and declarations[0].targeted[2] and declarations[0].shares[2] == 2 and !declarations[0].resolved[2]

# pp.17/19: model compaction cannot transfer a declaration to another bearer.
fun test_attack_source_identity_survives_compaction_and_rejects_casualty() -> Bool:
    let board = attack_declaration_fixture()
    let other = board[0][0]
    other.identity = -1
    board[0].models.append(other)
    board.identify_unit(board[0])
    let weapon = make_declared_weapon(board, unit_id(0), 1, 0)
    board[0].models.erase(0)
    if declared_model_index(board, unit_id(0), weapon) != 0:
        return false
    board[0].models.clear()
    return declared_model_index(board, unit_id(0), weapon) == -1 and !declaration_has_target(board, unit_id(0), weapon, false)

# p.18 and supplied appendix 01.05.02: collect all original dice first; each
# original can be rerolled once and replacement dice cannot re-enter selection.
fun test_attack_batch_collects_before_rerolls_and_prevents_second_reroll() -> Bool:
    let board = attack_declaration_fixture()
    board.current_decision_maker = true
    let batch = collect_attack_dice(board, attack_test_count(2), true, false, false, false, unit_id(0))
    batch.roll(board, attack_test_die(1))
    if can batch.select_reroll(board, attack_test_die(1)):
        return false
    batch.roll(board, attack_test_die(1))
    if board.current_decision_maker:
        return false
    batch.select_reroll(board, attack_test_die(1))
    batch.reroll(board, attack_test_die(6))
    if can batch.select_reroll(board, attack_test_die(6)):
        return false
    batch.select_reroll(board, attack_test_die(1))
    batch.reroll(board, attack_test_die(6))
    return batch.is_done() and batch.pool.faces[5] == 2 and batch.pool.total == 2 and board.current_decision_maker

# p.56: declining spends nothing; accepted batch CP reroll commits before
# replacement dice and cannot pay again in the same phase/for the same unit.
fun test_attack_batch_command_reroll_cost_and_keep() -> Bool:
    let board = attack_declaration_fixture()
    board.command_points[0] = 2
    let batch = collect_attack_dice(board, attack_test_count(2), false, false, true, false, unit_id(0))
    batch.roll(board, attack_test_die(2))
    batch.roll(board, attack_test_die(3))
    if board.command_points[0] != 2:
        return false
    batch.select_reroll(board, attack_test_die(2))
    if board.command_points[0] != 1 or !board.has_used_strat(Stratagem::reroll, 0):
        return false
    batch.reroll(board, attack_test_die(6))
    return batch.is_done() and batch.pool.faces[5] == 1 and batch.pool.faces[2] == 1 and !(can batch.select_reroll(board, attack_test_die(3)))

# pp.18/82/84: only critical original hits trigger Lethal, and Sustained
# generated hits roll wounds normally. No wounds resolve before all hit inputs.
fun test_attack_critical_lethal_and_sustained_group_pipeline() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.add_letal_hits()
    board.attack_info.add_sustained_hits(2)
    let group = resolve_attack_dice(board, board[1], board[0], attack_test_count(2))
    group.roll(board, board[1], board[0], attack_test_die(6))
    if group.generated_hits != 0 or group.generated_wounds != 0:
        return false
    group.roll(board, board[1], board[0], attack_test_die(3))
    if group.generated_hits != 3 or group.generated_wounds != 1:
        return false
    group.roll(board, board[1], board[0], attack_test_die(1))
    group.roll(board, board[1], board[0], attack_test_die(1))
    if group.is_done():
        return false
    group.roll(board, board[1], board[0], attack_test_die(1))
    return group.is_done() and group.generated_wounds == 1

# p.18: natural critical wounds succeed even if modifiers require seven;
# ordinary hits/wounds do not become critical through positive modifiers.
fun test_attack_natural_criticals_and_modifier_boundaries() -> Bool:
    let board = attack_declaration_fixture()
    let info = board.attack_info
    if !(classify_attack_hit(board, info, attack_test_die(1), 10) == AttackRollResult::failed) or !(classify_attack_hit(board, info, attack_test_die(6), -10) == AttackRollResult::critical):
        return false
    if !(classify_attack_hit(board, info, attack_test_die(5), 1) == AttackRollResult::success):
        return false
    return classify_attack_wound(board, info, attack_test_die(6), 7) == AttackRollResult::critical and classify_attack_wound(board, info, attack_test_die(1), 1) == AttackRollResult::failed

# p.57: six-only shots cannot use positive modifiers to turn a five into a hit.
fun test_attack_snap_shooting_six_only_is_enforced() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.only_hits_on_6 = true
    return classify_attack_hit(board, board.attack_info, attack_test_die(5), 1) == AttackRollResult::failed and classify_attack_hit(board, board.attack_info, attack_test_die(6), -1) == AttackRollResult::critical

# Supplied appendix 02.02.01: bonuses lower the wound threshold, penalties
# increase it, and cumulative modifiers cap only after they are added.
fun test_attack_wound_modifier_direction_and_cap() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.wound_roll_bonus = true
    board.attack_info.profile_wound_roll_bonus.append(board.attack_info.source_profile)
    if required_wound_roll(board, board.attack_info) != 3:
        return false
    board.attack_info.wound_roll_malus = true
    if required_wound_roll(board, board.attack_info) != 3:
        return false
    board.attack_info.profile_wound_roll_bonus.clear()
    return required_wound_roll(board, board.attack_info) == 4

# pp.10/17/19: a fixed attack and damage actually remove wounds, proving that
# successful smoke completion no longer hides zero fixed characteristics.
fun test_attack_fixed_damage_reaches_live_model() -> Bool:
    let board = attack_declaration_fixture()
    let sequence = single_attack(board, board[1], board[0])
    sequence.roll(board, board[1], board[0], attack_test_die(3))
    sequence.roll(board, board[1], board[0], attack_test_die(4))
    let model : ModelID
    model = 0
    sequence.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    sequence.allocate_wound(board, board[1], board[0], model)
    return sequence.is_done() and board[1][0].suffered_wounds == 1

# Supplied appendix 02.02.01: operation order and only-final rounding; amounts
# use standard bounded numeric storage, separate from observation encoding.
fun test_attack_modifier_order_final_rounding_and_zero_lock() -> Bool:
    let modifiers : RuleModifiers
    let rule : RuleModifier
    rule.operation = ModifierOperation::subtract
    rule.amount = 1
    modifiers.append(rule)
    rule.operation = ModifierOperation::divide
    rule.amount = 2
    modifiers.append(rule)
    rule.operation = ModifierOperation::add
    rule.amount = 1
    modifiers.append(rule)
    rule.operation = ModifierOperation::multiply
    rule.amount = 2
    modifiers.append(rule)
    if apply_rule_modifiers(2, modifiers, false) != 2 or apply_rule_modifiers(-2, modifiers, true) != -2:
        return false
    rule.operation = ModifierOperation::replace
    rule.amount = 0
    modifiers.append(rule)
    return modified_characteristic(2, ModifiedCharacteristic::strength, modifiers, false) == 0

# Supplied appendix 02.02.01: characteristic, dice, charge and CP cost limits
# apply after cumulative arithmetic, without clamping stored CP balances.
fun test_attack_modifier_characteristic_roll_and_cost_bounds() -> Bool:
    if characteristic_limit(ModifiedCharacteristic::ballistic_skill, 7) != 6 or characteristic_limit(ModifiedCharacteristic::weapon_skill, 1) != 2 or characteristic_limit(ModifiedCharacteristic::leadership, 9) != 8 or characteristic_limit(ModifiedCharacteristic::leadership, 4) != 5:
        return false
    if characteristic_limit(ModifiedCharacteristic::save, 1) != 2 or characteristic_limit(ModifiedCharacteristic::armour_penetration, 2) != 0 or characteristic_limit(ModifiedCharacteristic::objective_control, -1) != 0 or characteristic_limit(ModifiedCharacteristic::detection_range, 31) != 30:
        return false
    let modifiers : RuleModifiers
    let rule : RuleModifier
    rule.operation = ModifierOperation::add
    rule.amount = 4
    modifiers.append(rule)
    return modified_dice_result(5, modifiers, true, false) == 6 and modified_dice_result(6, modifiers, false, false) == 10 and modified_dice_result(11, modifiers, false, true) == 12 and modified_cp_cost(1, modifiers) == 2

# p.79: unit keyword union activates ANTI; unmodified one still fails, and
# an ordinary noncritical wound does not inherit a critical ability trigger.
fun test_attack_anti_uses_unit_keyword_and_natural_one_precedence() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.source = Weapon::beastchoppa
    board[1][0].keywords.append(Keyword::monster)
    if !(classify_attack_wound(board, board.attack_info, attack_test_die(4), 6) == AttackRollResult::critical):
        return false
    board.attack_info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::anti_monster, 1))
    return classify_attack_wound(board, board.attack_info, attack_test_die(1), 1) == AttackRollResult::failed

# pp.18–19: allocation groups precede all saves; every save input precedes
# per-attack allocation and fixed damage. This case asserts that boundary.
fun test_attack_all_save_results_collected_before_damage() -> Bool:
    let board = attack_declaration_fixture()
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(2), attack_test_count(0))
    let model : ModelID
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    if board[1][0].suffered_wounds != 0 or board[1].empty():
        return false
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.allocate_wound(board, board[1], board[0], model)
    damage.allocate_wound(board, board[1], board[0], model)
    return damage.is_done() and board[1].empty()

# Supplied appendix 02.02.03: random D is rolled only after an actual damaging
# attack has a selected recipient, including critical save-bypassing wounds.
fun test_attack_random_damage_waits_for_allocation() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.source = Weapon::smite_witchfire
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1))
    if can damage.quantity(board, board[1], board[0], attack_test_die(1)):
        return false
    let model : ModelID
    damage.allocate_mortal(board, board[1], board[0], model)
    damage.quantity(board, board[1], board[0], attack_test_die(1))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# p.56 and supplied appendix 01.05.02: generated random A/D may reroll once;
# a kept characteristic neither spends CP nor requests a replacement result.
fun test_attack_random_characteristic_command_reroll_once() -> Bool:
    let board = attack_declaration_fixture()
    board.command_points[0] = 2
    let characteristic = evaluate_weapon_characteristic(board, dice_stat(3), 2, false, unit_id(0))
    characteristic.quantity(board, attack_test_die(1))
    characteristic.keep_it(board, false)
    if board.command_points[0] != 1 or (can characteristic.reroll(board, attack_test_die(4))):
        return false
    characteristic.reroll(board, attack_test_die(3))
    return characteristic.is_done() and characteristic.result == 5 and !(can characteristic.keep_it(board, false))

# p.17: finish all nonidentical groups against the selected unit before
# choosing another target, and consume each source model's weapon only once.
fun test_attack_finishes_selected_target_before_next_and_each_weapon_once() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.append(Weapon::librarian_storm_bolter)
    let sequence = attack(board, unit_id(0), unit_id(1), false, false)
    sequence.select_weapon(board, attack_test_slot(0))
    sequence.select_weapon(board, attack_test_slot(1))
    sequence.skip(board)
    sequence.declare_target(board, unit_id(0), unit_id(1))
    sequence.declare_target(board, unit_id(0), unit_id(1))
    sequence.choose_attack_target(board, unit_id(1))
    sequence.no_defensive_stratagem(board)
    sequence.no_offensive_stratagem(board)
    sequence.choose_attack_weapon(board, attack_test_weapon(0))
    # Captain bolter A2 + Rapid Fire2 at this range, all four miss.
    for i in range(4):
        sequence.roll(board, attack_test_die(1))
    if (can sequence.choose_attack_target(board, unit_id(1))) or (can sequence.choose_attack_weapon(board, attack_test_weapon(0))) or !(can sequence.choose_attack_weapon(board, attack_test_weapon(1))):
        return false
    sequence.choose_attack_weapon(board, attack_test_weapon(1))
    for i in range(4):
        sequence.roll(board, attack_test_die(1))
    return sequence.is_done() and sequence.declarations[0].made_attacks and sequence.declarations[1].made_attacks

# Test-only finite constructors for p.19 group and model selectors.
fun allocation_test_group(Int value) -> AllocationGroupID:
    let result : AllocationGroupID
    result = value
    return result

fun damage_test_model(Int value) -> ModelID:
    let result : ModelID
    result = value
    return result

# Mixed models are explicit core allocation fixtures, not attachment grants.
fun damage_test_fixture() -> Board:
    let board = attack_declaration_fixture()
    board[1].models.append(board[1][0])
    board[1][1].identity = -1
    board.identify_units()
    return board

# p.19: noncharacters combine by W/Sv/InSv, each character stays separate.
fun test_damage_allocation_group_membership() -> Bool:
    let board = damage_test_fixture()
    let captain = make_octavius()
    board[1].models.append(captain[0])
    board[1].models.append(captain[0])
    board.identify_units()
    let groups = make_allocation_groups(board, board[1], board.attack_info)
    return groups.size() == 3 and groups[0].members.size() == 2 and groups[1].character and groups[2].character and groups[1].members.size() == 1 and groups[1].members[0].value != groups[2].members[0].value

# p.19: wounded ordinary groups precede others; characters remain last, and
# wounded characters precede other characters. Duplicate/stale groups fail.
fun test_damage_allocation_order_priority_and_duplicates() -> Bool:
    let board = damage_test_fixture()
    board[1][1].profile = Profile::terminator_squad
    board[1][1].suffered_wounds = 1
    let captain = make_octavius()
    board[1].models.append(captain[0])
    board[1].models.append(captain[0])
    board[1][3].suffered_wounds = 1
    board.identify_units()
    let groups = make_allocation_groups(board, board[1], board.attack_info)
    let order = declare_allocation_order(board, groups, true)
    if can order.choose_save_group(board, allocation_test_group(0)) or can order.choose_save_group(board, allocation_test_group(2)):
        return false
    order.choose_save_group(board, allocation_test_group(1))
    if can order.choose_save_group(board, allocation_test_group(1)):
        return false
    order.choose_save_group(board, allocation_test_group(0))
    if can order.choose_save_group(board, allocation_test_group(2)):
        return false
    order.choose_save_group(board, allocation_test_group(3))
    order.choose_save_group(board, allocation_test_group(2))
    return order.is_done() and order.order.size() == 4

# p.19: select a wounded live member of the current group if possible.
fun test_damage_wounded_member_priority_and_live_identity() -> Bool:
    let board = damage_test_fixture()
    board[1][1].suffered_wounds = 1
    let groups = make_allocation_groups(board, board[1], board.attack_info)
    if allocation_model_valid(board[1], groups[0], damage_test_model(0)):
        return false
    if !allocation_model_valid(board[1], groups[0], damage_test_model(1)):
        return false
    board[1].remove_model(0)
    return allocation_model_valid(board[1], groups[0], damage_test_model(0)) and !allocation_model_valid(board[1], groups[0], damage_test_model(1))

# p.19: natural 1 fails; same result tests InSv before AP-adjusted Sv.
fun test_damage_invulnerable_armour_ap_and_natural_one() -> Bool:
    let group : AllocationGroup
    group.save = 2
    group.invulnerable = 4
    if attack_save_succeeds(group, attack_test_die(1), 0) or !attack_save_succeeds(group, attack_test_die(4), -5):
        return false
    group.invulnerable = 10
    group.save = 3
    return !attack_save_succeeds(group, attack_test_die(3), -1) and attack_save_succeeds(group, attack_test_die(4), -1) and attack_save_succeeds(group, attack_test_die(6), 0)

# p.19: AP is nonpositive; old factories mixed signs and could improve saves.
fun test_damage_all_weapon_ap_signs_are_consistent() -> Bool:
    let weapon : Weapon
    for i in range(max(weapon) + 1):
        weapon.value = i
        if weapon.penetration() > 0:
            return false
    return Weapon::relic_weapon.penetration() == -2 and Weapon::smite_witchfire.penetration() == -1

# pp.19/22–23: use the printed 1,1,3,4,5 saves. The explicit first group is
# wounded W3 models with two wounds remaining, not invented Geminae datasheets.
fun test_damage_ascending_saves_change_current_group() -> Bool:
    let board = attack_declaration_fixture()
    let term = make_terminator_squad()
    board[1].models.clear()
    board[1].models.append(term[0])
    board[1].models.append(term[0])
    board[1][0].suffered_wounds = 1
    board[1][1].suffered_wounds = 1
    let infantry = make_infernus_squad()
    board[1].models.append(infantry[0])
    let captain = make_octavius()
    board[1].models.append(captain[0])
    board.identify_units()
    board.attack_info.source = Weapon::heavy_bolter
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(5), attack_test_count(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(1))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(2))
    damage.roll(board, board[1], board[0], attack_test_die(5))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.roll(board, board[1], board[0], attack_test_die(4))
    damage.roll(board, board[1], board[0], attack_test_die(3))
    if board[1].models.size() != 4:
        return false
    damage.roll(board, board[1], board[0], attack_test_die(1))
    for i in range(5):
        damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1].models.size() == 1 and board[1][0].is_character() and board[1][0].suffered_wounds == 0 and board[1].destroyed_models.value.size() == 3

# p.19: D2 on a model with one remaining wound loses its excess; the next
# save is allocated to the next live model, not aggregated with the first.
fun test_damage_normal_attacks_do_not_aggregate_or_spill() -> Bool:
    let board = damage_test_fixture()
    board[1][0].suffered_wounds = 1
    board.attack_info.source = Weapon::heavy_bolter
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(2), attack_test_count(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.roll(board, board[1], board[0], attack_test_die(6))
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    if board[1].models.size() != 1 or board[1][0].suffered_wounds != 0:
        return false
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 0

# p.84: attacker's optional override applies only to a visible character
# group; defender still chooses that group's model and receives save choices.
fun test_damage_precision_character_group_and_fallback() -> Bool:
    let board = damage_test_fixture()
    let captain = make_octavius()
    board[1].models.append(captain[0])
    board[1][2].suffered_wounds = 5
    board.identify_units()
    board.attack_info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::precision))
    board.attack_info.precision_visibility_known = true
    board.attack_info.precision_visible_targets[2] = true
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(2), attack_test_count(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(1))
    if board.current_decision_maker or can damage.choose_precision_group(board, board[1], board[0], allocation_test_group(0)):
        return false
    damage.choose_precision_group(board, board[1], board[0], allocation_test_group(1))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    if can damage.allocate_wound(board, board[1], board[0], damage_test_model(0)):
        return false
    damage.allocate_wound(board, board[1], board[0], damage_test_model(2))
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1].models.size() == 2 and board[1][0].suffered_wounds == 1

# p.84: hidden/nonvisible characters do not expose the precision decision.
fun test_damage_precision_hidden_character_not_selectable() -> Bool:
    let board = damage_test_fixture()
    let captain = make_octavius()
    board[1].models.append(captain[0])
    board.identify_units()
    board.attack_info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::precision))
    board.attack_info.precision_visibility_known = true
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(1), attack_test_count(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(1))
    return !(can damage.choose_precision_group(board, board[1], board[0], allocation_test_group(1))) and (can damage.roll(board, board[1], board[0], attack_test_die(1)))

# p.81: all normal D wounds can be prevented independently; no loss is
# committed before the prevention rolls finish, including damage beyond W.
fun test_damage_feel_no_pain_normal_damage_each_wound() -> Bool:
    let board = damage_test_fixture()
    board[1][0].profile = Profile::beast_snagga_boy
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(1), unit_id(0), true, true, 3, board[1][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(0))
    damage.roll(board, attack_test_die(6))
    damage.roll(board, attack_test_die(1))
    if board[1][0].suffered_wounds != 0:
        return false
    damage.roll(board, attack_test_die(6))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# p.24: mortal priority ignores save groups; wounded noncharacters first,
# unwounded noncharacters before wounded characters, then other characters.
fun test_damage_mortal_recipient_priority() -> Bool:
    let board = damage_test_fixture()
    let captain = make_octavius()
    board[1].models.append(captain[0])
    board[1][2].suffered_wounds = 1
    if mortal_model_valid(board[1], damage_test_model(2)):
        return false
    board[1][1].suffered_wounds = 1
    return !mortal_model_valid(board[1], damage_test_model(0)) and mortal_model_valid(board[1], damage_test_model(1))

# pp.24/81: each mortal has its own FNP roll; prevention consumes a mortal,
# actual excess mortals spill after destruction of the previous recipient.
fun test_damage_mortal_feel_no_pain_and_spill() -> Bool:
    let board = damage_test_fixture()
    board[1][0].profile = Profile::beast_snagga_boy
    board[1][1].profile = Profile::beast_snagga_boy
    let mortals = resolve_mortal_wounds(board, unit_id(1), unit_id(0), true, attack_test_count(4))
    for i in range(4):
        mortals.select_mortal_model(board, damage_test_model(0))
        if i == 0:
            mortals.roll(board, attack_test_die(6))
        else:
            mortals.roll(board, attack_test_die(1))
    return mortals.is_done() and board[1].models.size() == 1 and board[1][0].suffered_wounds == 1

# p.80: each critical Devastating Wound can damage one model only; a D3
# critical destroys a W2 model and loses its final mortal wound.
fun test_damage_devastating_wounds_loses_per_attack_excess() -> Bool:
    let board = damage_test_fixture()
    board.attack_info.source = Weapon::smite_focused_witchfire
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    damage.quantity(board, board[1], board[0], attack_test_die(3))
    return damage.is_done() and board[1].models.size() == 1 and board[1][0].suffered_wounds == 0

# pp.24/80: a normal wound damages the first model before the critical mortal
# finishes it; mortals bypass saves rather than adding to normal damage.
fun test_damage_normal_before_devastating_mortals() -> Bool:
    let board = damage_test_fixture()
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(1), attack_test_count(1))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    if board[1][0].suffered_wounds != 1:
        return false
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1].models.size() == 1 and board[1][0].suffered_wounds == 0

# p.24: mixed monster/vehicle models qualify, mixed ordinary models do not.
fun test_damage_hazard_large_model_multiplier() -> Bool:
    let board = damage_test_fixture()
    board[1][0].keywords.append(Keyword::monster)
    board[1][1].keywords.append(Keyword::vehicle)
    if hazard_mortal_multiplier(board[1]) != 3:
        return false
    board[1][1].keywords.clear()
    return hazard_mortal_multiplier(board[1]) == 1

# pp.24/81: all hazard dice precede allocation; both 1 and 2 fail and each
# inflicts one ordinary mortal for a non-MONSTER/VEHICLE unit.
fun test_damage_hazard_batch_one_and_two_fail() -> Bool:
    let board = damage_test_fixture()
    let count : HazardousUses
    count = 3
    let hazards = resolve_hazards(board, unit_id(1), count)
    hazards.roll(board, attack_test_die(1))
    hazards.roll(board, attack_test_die(2))
    if board[1][0].suffered_wounds != 0:
        return false
    hazards.roll(board, attack_test_die(3))
    hazards.select_mortal_model(board, damage_test_model(0))
    hazards.select_mortal_model(board, damage_test_model(0))
    return hazards.is_done() and board[1].models.size() == 1

# p.81: HAZARDOUS counts selected weapons even if all targets were skipped.
fun test_damage_hazard_selected_but_skipped_weapon() -> Bool:
    let board = damage_test_fixture()
    board[0][0].weapons.clear()
    board[0][0].weapons.append(Weapon::smite_focused_witchfire)
    let sequence = attack(board, unit_id(0), unit_id(1), false, false)
    sequence.select_weapon(board, attack_test_slot(0))
    sequence.skip(board)
    sequence.skip_target(board)
    if !(can sequence.roll(board, attack_test_die(2))):
        return false
    sequence.roll(board, attack_test_die(2))
    sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[0][0].suffered_wounds == 1

# p.87: no triggered rule means immediate removal, not unconditional retention.
fun test_damage_no_trigger_immediate_destruction() -> Bool:
    let board = damage_test_fixture()
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(1), unit_id(0), true, true, 10, board[1][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(0))
    return damage.is_done() and board[1].models.size() == 1 and board[1].destroyed_models.value.size() == 1

# p.87: a real attack-caused trigger retains the model until the whole source
# activation finishes; the retained model cannot be allocated further damage.
fun test_damage_triggered_attack_death_is_deferred_and_ineligible() -> Bool:
    let board = damage_test_fixture()
    board[1][0].has_deadly_demise = true
    board[1][0].deadly_demise = raw_stat(1)
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(1), unit_id(0), true, true, 10, board[1][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(0))
    if !damage.is_done() or board[1].models.size() != 2 or board[1][0].is_alive() or mortal_model_valid(board[1], damage_test_model(0)):
        return false
    let empty_jobs : DamageJobs
    let cleanup = resolve_damage_jobs(board, empty_jobs, true, unit_id(0))
    cleanup.choose_destruction_unit(board, unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.roll(board, attack_test_die(1))
    return cleanup.is_done() and board[1].models.size() == 1 and board[1].destroyed_models.value.size() == 1

# pp.80/87: non-attack destruction triggers before the next ordinary mortal;
# a failed Deadly Demise still removes/archives exactly once.
fun test_damage_nonattack_trigger_interrupts_mortal_sequence() -> Bool:
    let board = damage_test_fixture()
    board[1][0].suffered_wounds = 1
    board[1][0].has_deadly_demise = true
    board[1][0].deadly_demise = raw_stat(1)
    let mortals = resolve_mortal_wounds(board, unit_id(1), unit_id(0), true, attack_test_count(2))
    mortals.select_mortal_model(board, damage_test_model(0))
    if can mortals.select_mortal_model(board, damage_test_model(1)):
        return false
    mortals.choose_destruction_unit(board, unit_id(1))
    mortals.resolve_destruction_model(board, damage_test_model(0))
    mortals.roll(board, attack_test_die(1))
    mortals.select_mortal_model(board, damage_test_model(0))
    return mortals.is_done() and board[1].models.size() == 1 and board[1][0].suffered_wounds == 1

# p.87 and supplied Rules Sequencing: current player's pending triggers are
# chosen before opponent triggers, with each owner choosing their own order.
fun test_damage_destruction_current_player_priority() -> Bool:
    let board = damage_test_fixture()
    board.current_player = true
    for i in range(2):
        board[i][0].state = ModelState::pending_destruction
        board[i][0].destruction_pending = true
    let jobs : DamageJobs
    let cleanup = resolve_damage_jobs(board, jobs, false, unit_id(0))
    if can cleanup.choose_destruction_unit(board, unit_id(0)):
        return false
    cleanup.choose_destruction_unit(board, unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.choose_destruction_unit(board, unit_id(0))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    return cleanup.is_done() and board[0].empty() and board[1].models.size() == 1

# p.83: MELTA range is snapshotted when selecting its target, not remeasured
# after declaration when a model/target changes its position.
fun test_damage_melta_declaration_snapshot() -> Bool:
    let board = damage_test_fixture()
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    weapon.weapon = Weapon::meltagun
    let declaration = declare_weapon_targets(board, weapon, unit_id(0), false)
    declaration.declare_target(board, unit_id(0), unit_id(1))
    let bonus = declaration.weapon.melta_bonus[1].value
    board[1][0].position.x = 30
    let info = declared_attack_info(board, unit_id(0), unit_id(1), declaration.weapon, board.attack_info)
    return bonus == weapon.weapon.get_rule_parameter(WeaponRuleKind::melta) and bonus > 0 and info.melta_damage_bonus.value == bonus

# pp.80/87: a successful demise damages nearby live units, then removes the
# physically retained corpse. This fixture has no embarked passengers (task 16).
fun test_damage_deadly_demise_retains_model_through_nearby_damage() -> Bool:
    let board = damage_test_fixture()
    board[1][0].has_deadly_demise = true
    board[1][0].deadly_demise = raw_stat(1)
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(1), unit_id(0), true, true, 10, board[1][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(0))
    let empty_jobs : DamageJobs
    let cleanup = resolve_damage_jobs(board, empty_jobs, true, unit_id(0))
    cleanup.choose_destruction_unit(board, unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.roll(board, attack_test_die(6))
    if board[1].models.size() != 2:
        return false
    cleanup.select_mortal_model(board, damage_test_model(0))
    cleanup.select_mortal_model(board, damage_test_model(1))
    if board[1].models.size() != 2:
        return false
    cleanup.select_mortal_model(board, damage_test_model(0))
    return cleanup.is_done() and board[0][0].suffered_wounds == 1 and board[1].models.size() == 1 and board[1][0].suffered_wounds == 1 and board[2][0].suffered_wounds == 1

# p.80: random demise amounts are determined separately for every nearby unit,
# not once reused for the entire explosion. Damage may itself destroy units.
fun test_damage_deadly_demise_random_amount_per_unit() -> Bool:
    let board = damage_test_fixture()
    board[1][0].has_deadly_demise = true
    board[1][0].deadly_demise = dice_stat(3)
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(1), unit_id(0), true, true, 10, board[1][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(0))
    let empty_jobs : DamageJobs
    let cleanup = resolve_damage_jobs(board, empty_jobs, true, unit_id(0))
    cleanup.choose_destruction_unit(board, unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.roll(board, attack_test_die(6))
    cleanup.quantity(board, attack_test_die(1))
    cleanup.quantity(board, attack_test_die(2))
    cleanup.quantity(board, attack_test_die(3))
    for i in range(2):
        cleanup.select_mortal_model(board, damage_test_model(0))
    for i in range(2):
        cleanup.select_mortal_model(board, damage_test_model(1))
    cleanup.select_mortal_model(board, damage_test_model(0))
    return cleanup.is_done() and board[0].empty() and board[1].empty() and board[2][0].suffered_wounds == 1

# pp.24/80/81: prevention is allowed for devastating mortals, but a failed
# prevention that destroys the recipient does not spill that critical's excess.
fun test_damage_devastating_feel_no_pain_and_one_model_limit() -> Bool:
    let board = damage_test_fixture()
    board[1][0].profile = Profile::beast_snagga_boy
    board[1][1].profile = Profile::beast_snagga_boy
    board.attack_info.source = Weapon::smite_focused_witchfire
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    damage.quantity(board, board[1], board[0], attack_test_die(3))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    return damage.is_done() and board[1].models.size() == 1 and board[1][0].suffered_wounds == 0

# p.80's cap concerns models damaged, not wounds successfully prevented. A
# prevented first mortal does not force another unwounded model out of eligibility.
fun test_damage_devastating_prevented_first_wound_allows_new_recipient() -> Bool:
    let board = damage_test_fixture()
    board[1][0].profile = Profile::beast_snagga_boy
    board[1][1].profile = Profile::beast_snagga_boy
    board.attack_info.source = Weapon::smite_focused_witchfire
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    damage.quantity(board, board[1], board[0], attack_test_die(3))
    damage.roll(board, board[1], board[0], attack_test_die(6))
    if !(can damage.select_mortal_model(board, board[1], board[0], damage_test_model(1))):
        return false
    damage.select_mortal_model(board, board[1], board[0], damage_test_model(1))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.roll(board, board[1], board[0], attack_test_die(6))
    return damage.is_done() and board[1][0].suffered_wounds == 0 and board[1][1].suffered_wounds == 1

# pp.24/56/81: a hazard batch allows one targeted CP reroll after originals,
# with replacement eligibility/cost separated from remaining failed hazards.
fun test_damage_hazard_command_reroll_owner_cost_and_result() -> Bool:
    let board = damage_test_fixture()
    board.command_points[1] = 2
    let count : HazardousUses
    count = 2
    let hazards = resolve_hazards(board, unit_id(1), count)
    hazards.roll(board, attack_test_die(1))
    hazards.roll(board, attack_test_die(2))
    if !board.current_decision_maker:
        return false
    hazards.select_reroll(board, attack_test_die(1))
    if board.command_points[1] != 1:
        return false
    hazards.reroll(board, attack_test_die(6))
    hazards.select_mortal_model(board, damage_test_model(0))
    return hazards.is_done() and board[1][0].suffered_wounds == 1 and board.command_points[1] == 1

# pp.24/81: three mortals for each failed all-large-unit hazard spill normally.
fun test_damage_large_unit_hazard_three_mortals_spill() -> Bool:
    let board = damage_test_fixture()
    for i in range(2):
        board[1][i].keywords.append(Keyword::vehicle)
    let count : HazardousUses
    count = 1
    let hazards = resolve_hazards(board, unit_id(1), count)
    hazards.roll(board, attack_test_die(2))
    for i in range(3):
        hazards.select_mortal_model(board, damage_test_model(0))
    return hazards.is_done() and board[1].models.size() == 1 and board[1][0].suffered_wounds == 1

# p.87: existing feeder-tendrils hook is deferred with the character casualty;
# its legacy faction effect is retained, not asserted as new-edition faction data.
fun test_damage_feeder_trigger_waits_until_activation_cleanup() -> Bool:
    let board = damage_test_fixture()
    board[0][0].abilities.append(AbilityKind::feeder_tendrils)
    board[1][0].keywords.append(Keyword::character)
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(1), unit_id(0), true, true, 10, board[1][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(0))
    if board.command_points[0] != 0 or !board[1][0].destruction_pending:
        return false
    let empty_jobs : DamageJobs
    let cleanup = resolve_damage_jobs(board, empty_jobs, true, unit_id(0))
    cleanup.choose_destruction_unit(board, unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    return cleanup.is_done() and board.command_points[0] == 1 and board[1].destroyed_models.value.size() == 1

# p.87: retained destroyed models contribute no OC and cannot supply active
# unit abilities; explicit on-destruction properties remain readable to hooks.
fun test_damage_pending_model_oc_and_active_ability_exclusion() -> Bool:
    let board = damage_test_fixture()
    board[1][0].abilities.append(AbilityKind::feeder_tendrils)
    board[1][0].state = ModelState::pending_destruction
    board[1][0].suffered_wounds = 2
    return board[1].model_objective_control(0) == 0 and !board[1].has_ability(AbilityKind::feeder_tendrils) and !board[1][0].is_alive()

# p.87: deferred trigger state, random demise and source identity survive saves;
# malformed provenance is rejected atomically rather than stranded forever.
fun test_damage_pending_death_save_round_trip_and_source_guard() -> Bool:
    let state = play()
    state.board = damage_test_fixture()
    state.board[1][0].state = ModelState::pending_destruction
    state.board[1][0].suffered_wounds = 2
    state.board[1][0].destruction_pending = true
    state.board[1][0].destroyed_by_attack = true
    state.board[1][0].destroying_unit_known = true
    state.board[1][0].destroying_unit = 0
    state.board[1][0].has_deadly_demise = true
    state.board[1][0].deadly_demise = dice_stat(3)
    let restored = play()
    if !set_state(restored, to_string(state)):
        return false
    let demise = restored.board[1][0].deadly_demise
    if demise is Dice:
        if demise.value != 3 or !restored.board[1][0].destruction_pending:
            return false
    else:
        return false
    let before = to_string(restored)
    state.board[1][0].destroying_unit = 31
    if set_state(restored, to_string(state)) or to_string(restored) != before:
        return false
    state.board[1][0].destroying_unit = 0
    state.board[1][0].destroying_unit_known = false
    return !set_state(restored, to_string(state)) and to_string(restored) == before
