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

# p.54: expenditure follows the using unit's owner, including opposing shock tests.
fun test_insane_bravery_charges_the_units_owner() -> Bool:
    let board = attack_fixture()
    board.command_points[1] = 1
    let sequence = battle_shock_test(board, board[1])
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

