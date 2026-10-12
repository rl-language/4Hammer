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
    board[0].history.last_ranged_attack_turn = 8
    board[0].history.used_stratagem_this_phase = true
    board.has_used_shadow_in_the_warp[0] = true
    let copy = board
    copy.clear_phase_modifiers()
    return copy[0].history.last_ranged_attack_turn == 8 and !copy[0].history.used_stratagem_this_phase and copy.has_used_shadow_in_the_warp[0] and board[0].history.used_stratagem_this_phase

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
    if !board[0][0].history.was_set_up_this_turn or board[0][0].history.distance_moved_this_turn() != 5.0:
        return false
    board.start_turn_history()
    return board.turn_serial == 1 and !board[0].history.was_set_up_this_turn and !board[0][0].history.was_set_up_this_turn and board[0][0].history.distance_moved_this_turn() == 0.0

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
    path.append_point(geometry_point(x * MICROMETRES_PER_INCH, y * MICROMETRES_PER_INCH, z * MICROMETRES_PER_INCH))
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
    path.append_point(geometry_point(5 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 0))
    paths.append(path)
    let slot : UnitID
    let policy : MovementGeometryPolicy
    if !try_move_models(board, slot, paths, 0, policy, true) or board[0][0].history.distance_moved_this_turn() != 6.0:
        return false
    let before = to_string(board)
    paths[0].points[1].x = 4
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
    paths[1].points[0].x = 13
    if !try_move_models(board, slot, paths, 0, policy, true):
        return false
    board[0][1].position = board_position(7, 5)
    board[0][0].position = board_position(5, 5)
    paths[0].points[0].x = 13
    paths[1].points[0].x = 15
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
    paths[0].points[0].x.value = BOARD_WIDTH
    if try_move_models(board, slot, paths, 0, policy, true) or to_string(board) != before:
        return false
    paths[0].points[0].x = 6
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
    return try_move_models(board, slot, paths, 0, policy, true) and board[0][0].history.distance_moved_this_turn() == 0.0 and board[0][0].geometry.rotation.value == 270000 and board[0][0].position.x.value == 5

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
    board.terrain_geometry[0].lower.x.value = MAX_TERRAIN_X
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
    board[0].can_shoot = true
    board[1].can_shoot = true
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
fun test_timing_turn_movement_flags_expire_for_both_armies() -> Bool:
    let board = timing_fixture()
    board[0].has_moved = true
    board[1].has_moved = true
    board[0].has_shoot = true
    board[1].has_shoot = true
    board.start_turn_history()
    return !board[0].has_moved and !board[1].has_moved and !board[0].has_shoot and board[1].has_shoot

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
    far.identity = 0
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
    board[0].history.charge_move_phase = board.phase_serial.value + 1
    board[1].can_charge = true
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
    far.identity = 0
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
    board[1][0].position.x = 13
    board[1].can_charge = true
    let sequence = charge(board, unit_id(1), ChargeKind::ordinary)
    if !board.timing.active_player or !board.current_decision_maker:
        return false
    let one : Dice
    one = 1
    sequence.roll_pair(board, one, one)
    sequence.keep_it(board, true)
    sequence.cancel_charge(board)
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
    if !attack.is_done() or board[0].history.last_ranged_attack_turn != 5:
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
    shooting.choose_shooting_kind(board, ShootingKind::normal)
    shooting.skip(board)
    return board[0].has_shoot and board[0].history.last_ranged_attack_turn == 0 and (can shooting.end_shooting_phase(board))

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
    board[1].history.last_ranged_attack_turn = board.turn_serial.value + 1
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
    other[0].identity = 0
    other.identity = 0
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
    other.identity = 0
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
    group.use_lethal_hits(board, board[1], board[0], true)
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
    board[1][1].identity = 0
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
    board[0][0].weapons[0] = Weapon::meltagun
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
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

# pp.12/33: explicit single-model board avoids unavailable faction/mission data.
fun movement11_fixture() -> Board:
    let board = geometry_fixture()
    board.phase_serial = 3
    board[0].can_charge = true
    board[0].can_shoot = true
    board.timing.phase = BattlePhase::movement
    board.identify_units()
    return board

# p.33: normal/advance require unengaged; Ordered Retreat requires unshocked.
fun test_movement11_modes_and_shock_legality() -> Bool:
    let board = movement11_fixture()
    let enemy = board[0]
    enemy.identity = 0
    enemy[0].identity = 0
    enemy.owned_by_player1 = true
    enemy[0].position = board_position(8, 5)
    board.units.append(enemy)
    let id = unit_id(0)
    if battlefield_move_eligible(board, id, MovementKind::normal) or !battlefield_move_eligible(board, id, MovementKind::ordered_retreat):
        return false
    board[0].battle_socked = true
    return !battlefield_move_eligible(board, id, MovementKind::ordered_retreat) and battlefield_move_eligible(board, id, MovementKind::desperate_escape) and battlefield_move_eligible(board, id, MovementKind::stationary)

# p.32: phase end requires explicit selection of every unit, including reserves.
fun test_movement11_mandatory_selection_including_reserves() -> Bool:
    let board = movement11_fixture()
    board.reserve_units.append(board[0])
    if movement_selection_complete(board, false):
        return false
    record_move(board, unit_id(0), MovementKind::stationary)
    if movement_selection_complete(board, false):
        return false
    board.reserve_units[0].history.selected_move_phase = board.phase_serial.value + 1
    return movement_selection_complete(board, false)

# p.33: stationary neither rotates nor records an actual move/charge restriction.
fun test_movement11_stationary_has_no_move_event() -> Bool:
    let board = movement11_fixture()
    let before = board[0][0].position
    let selected = movement(board, unit_id(0), false)
    selected.remain_stationary(board)
    return selected.is_done() and board[0][0].position.x == before.x and board[0][0].position.y == before.y and board[0].history.last_move_phase == 0 and board[0].history.selected_move_phase == board.phase_serial.value + 1 and board[0].can_charge == true

# pp.12/87: independently move mixed-M models, permitting intermediate
# incoherency but requiring coherent final placement and each own distance.
fun test_movement11_independent_models_stage_then_commit() -> Bool:
    let board = movement11_fixture()
    let fast = board[0][0]
    fast.profile = Profile::possessed
    board[0].models.append(fast)
    board[0][1].position = board_position(7, 5)
    let id = unit_id(0)
    let sequence = move(board, id, 0)
    sequence.select_moving_model(board, id, damage_test_model(0))
    sequence.waypoint(board, id, board_position(11, 5))
    sequence.finish_model(board, id)
    if board[0][0].position.x != 5 or (can sequence.finish_move(board, id)):
        return false
    sequence.select_moving_model(board, id, damage_test_model(1))
    if can sequence.waypoint(board, id, board_position(17, 5)):
        return false
    sequence.waypoint(board, id, board_position(13, 5))
    sequence.finish_model(board, id)
    if can sequence.select_moving_model(board, id, damage_test_model(1)):
        return false
    sequence.finish_move(board, id)
    return sequence.completed and board[0][0].position.x == 11 and board[0][1].position.x == 13

# p.12: all straight segments add up, including retracing; skip rolls back.
fun test_movement11_waypoint_budget_and_atomic_cancel() -> Bool:
    let board = movement11_fixture()
    let id = unit_id(0)
    let before = to_string(board[0])
    let sequence = move(board, id, 0)
    sequence.select_moving_model(board, id, damage_test_model(0))
    sequence.waypoint(board, id, board_position(9, 5))
    if can sequence.waypoint(board, id, board_position(5, 5)):
        return false
    sequence.finish_model(board, id)
    sequence.skip(board, id)
    return !sequence.completed and to_string(board[0]) == before

# p.12: rotate circular fixtures freely; one degree choice changes no position.
fun test_movement11_free_rotation_and_invalid_model_id() -> Bool:
    let board = movement11_fixture()
    let id = unit_id(0)
    let sequence = move(board, id, 0)
    if can sequence.select_moving_model(board, id, damage_test_model(1)):
        return false
    sequence.select_moving_model(board, id, damage_test_model(0))
    let rotation : MovementRotation
    rotation = 90
    sequence.rotate_model(board, id, rotation)
    sequence.finish_model(board, id)
    sequence.finish_move(board, id)
    return board[0][0].geometry.rotation.value == 90000 and board[0][0].position.x == 5 and board[0][0].history.distance_moved_this_turn() == 0.0

# p.33: Advance's full D6 allowance persists and forbids charge/action start.
fun test_movement11_advance_roll_budget_and_flags() -> Bool:
    let board = movement11_fixture()
    board.command_points[0] = 0
    let sequence = movement(board, unit_id(0), false)
    sequence.advance(board, true)
    sequence.roll(board, attack_test_die(6))
    if !(can sequence.move_to(board, board_position(17, 5))) or (can sequence.move_to(board, board_position(18, 5))):
        return false
    sequence.move_to(board, board_position(17, 5))
    return sequence.is_done() and board[0].has_run and board[0].history.advanced_this_turn and !board[0].can_charge and !board[0].allows_action_start()

# p.33: Ordered Retreat offers no hazards and cannot cross enemy bases.
fun test_movement11_ordered_retreat_path_and_flags() -> Bool:
    let board = movement11_fixture()
    let enemy = board[0]
    enemy.owned_by_player1 = true
    enemy[0].position = board_position(7, 5)
    board.units.append(enemy)
    let sequence = movement(board, unit_id(0), false)
    sequence.ordered_retreat(board)
    if can sequence.roll(board, attack_test_die(3)) or can sequence.move_to(board, board_position(11, 5)):
        return false
    sequence.move_to(board, board_position(2, 5))
    return board[0].history.fell_back_this_turn and !board[0].can_shoot and !board[0].can_charge and !board[0].allows_action_start()

# pp.24/33: Desperate Escape hazards are mortal wounds, allow FNP and can
# cross enemies; an unshocked surviving unit then rolls Battle-shock.
fun test_movement11_desperate_escape_hazards_and_post_shock() -> Bool:
    let board = movement11_fixture()
    let enemy = board[0]
    enemy.owned_by_player1 = true
    enemy[0].position = board_position(7, 5)
    board.units.append(enemy)
    let sequence = movement(board, unit_id(0), false)
    sequence.desperate_escape(board)
    sequence.roll(board, attack_test_die(2))
    sequence.select_mortal_model(board, damage_test_model(0))
    if board[0][0].suffered_wounds != 1:
        return false
    sequence.move_to(board, board_position(11, 5))
    sequence.roll_pair(board, attack_test_die(1), attack_test_die(1))
    return sequence.is_done() and board[0].battle_socked and board[0][0].position.x == 11

# p.33: already shocked Desperate Escape does not offer a second shock roll.
fun test_movement11_shocked_escape_no_extra_shock_roll() -> Bool:
    let board = movement11_fixture()
    board[0].battle_socked = true
    let enemy = board[0]
    enemy.owned_by_player1 = true
    enemy[0].position = board_position(7, 5)
    board.units.append(enemy)
    let sequence = movement(board, unit_id(0), false)
    sequence.desperate_escape(board)
    sequence.roll(board, attack_test_die(3))
    sequence.move_to(board, board_position(11, 5))
    return sequence.is_done() and board[0].battle_socked

# p.71/82: Take to the Skies costs 2 for all models; Hover is its exception.
fun test_movement11_flying_budget_and_hover() -> Bool:
    let board = movement11_fixture()
    board[0][0].keywords.append(Keyword::fly)
    if model_move_budget(board[0][0], MovementKind::normal, 0, -1, true) != 4:
        return false
    board[0][0].abilities.append(AbilityKind::hover)
    return model_move_budget(board[0][0], MovementKind::normal, 0, -1, true) == 6

# p.71: only the flying models gain enemy traversal; mixed units keep the
# non-FLY member's ordinary collision rule, even when the unit takes skies.
fun test_movement11_mixed_flying_per_model_traversal() -> Bool:
    let board = movement11_fixture()
    let enemy = board[0]
    enemy.owned_by_player1 = true
    enemy[0].position = board_position(7, 5)
    board.units.append(enemy)
    let path : ModelPath
    path.model = 0
    if waypoint_valid(board, board[0], path, board_position(9, 5), MovementKind::normal, 0, -1, true):
        return false
    board[0][0].keywords.append(Keyword::fly)
    return waypoint_valid(board, board[0], path, board_position(9, 5), MovementKind::normal, 0, -1, true)

# p.71: flying distance ignores vertical movement while grounded movement adds it.
fun test_movement11_flying_vertical_distance() -> Bool:
    let board = movement11_fixture()
    board[0][0].keywords.append(Keyword::fly)
    let path : ModelPath
    path.model = 0
    path.append_point(geometry_point(5 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 3 * MICROMETRES_PER_INCH))
    return path_distance(board[0][0], path, true) == 0.0 and path_distance(board[0][0], path, false) == float(3 * MICROMETRES_PER_INCH)

# p.85: walker traversal cannot cross TITANIC, but can cross ordinary enemies.
fun test_movement11_super_heavy_walker_traversal() -> Bool:
    let board = movement11_fixture()
    board[0][0].abilities.append(AbilityKind::super_heavy_walker)
    let enemy = board[0]
    enemy[0].abilities.clear()
    enemy.owned_by_player1 = true
    enemy[0].position = board_position(8, 5)
    board.units.append(enemy)
    let path : ModelPath
    path.model = 0
    if !waypoint_valid(board, board[0], path, board_position(11, 5), MovementKind::normal, 0, -1, false):
        return false
    board[1][0].keywords.append(Keyword::titanic)
    return !waypoint_valid(board, board[0], path, board_position(11, 5), MovementKind::normal, 0, -1, false)

# p.85: temporary MOBILE ends with the move, and its end roll shocks on 1.
fun test_movement11_walker_mobile_lifetime_and_shock() -> Bool:
    let board = movement11_fixture()
    board[0][0].abilities.append(AbilityKind::super_heavy_walker)
    let sequence = movement(board, unit_id(0), false)
    sequence.normal_move(board)
    sequence.walker_mobile(board, true)
    if !board[0][0].has_keyword(Keyword::mobile):
        return false
    sequence.move_to(board, board_position(6, 5))
    if board[0][0].has_keyword(Keyword::mobile):
        return false
    sequence.roll(board, attack_test_die(1))
    return sequence.is_done() and board[0].battle_socked

# Supplied 02.02.03: determine entire unit's random M once on selection;
# characteristic determination cannot use Command Re-roll (p.56).
fun test_movement11_random_movement_once_for_unit() -> Bool:
    let board = movement11_fixture()
    board[0][0].has_random_movement = true
    board[0][0].random_movement = dice_stat(3)
    board.command_points[0] = 5
    let sequence = movement(board, unit_id(0), false)
    sequence.quantity(board, attack_test_die(2))
    if can sequence.reroll(board, attack_test_die(3)):
        return false
    sequence.normal_move(board)
    if can sequence.move_to(board, board_position(8, 5)):
        return false
    sequence.move_to(board, board_position(7, 5))
    return sequence.is_done() and board[0].movement_override.value == MOVE_M_UNSET and board.command_points[0] == 5

# p.14: every base must fit the home zone; merely fitting the anchor fails.
fun test_movement11_deployment_whole_base_boundary() -> Bool:
    let board = movement11_fixture()
    let unit = board[0]
    unit.owned_by_player1 = true
    board.units.clear()
    return setup_at_valid(board, unit, board_position(5, 4), MovementKind::normal, false) and !setup_at_valid(board, unit, board_position(5, 5), MovementKind::normal, false)

# p.82: Infiltrators require every model and strict >8 from enemy zones/models.
fun test_movement11_infiltrator_horizontal_clearance() -> Bool:
    let board = movement11_fixture()
    board[0].owned_by_player1 = true
    if setup_at_valid(board, board[0], board_position(5, 17), MovementKind::normal, true):
        return false
    return setup_at_valid(board, board[0], board_position(5, 16), MovementKind::normal, true)

# p.69: reserves start in round 2, wholly within the union of 6-inch edges;
# before round 3 the opposite deployment zone is excluded, even at the side.
fun test_movement11_ingress_round_edge_and_opponent_zone() -> Bool:
    let board = movement11_fixture()
    let unit = board[0]
    board.units.clear()
    board.current_round = 1
    if !setup_at_valid(board, unit, board_position(5, 10), MovementKind::ingress, false) or setup_at_valid(board, unit, board_position(6, 10), MovementKind::ingress, false) or setup_at_valid(board, unit, board_position(2, 2), MovementKind::ingress, false):
        return false
    board.current_round = 2
    return setup_at_valid(board, unit, board_position(2, 2), MovementKind::ingress, false)

# p.69: no distant tail may escape edge-strip restrictions after an anchor fits.
fun test_movement11_ingress_each_model_edge_strip() -> Bool:
    let board = movement11_fixture()
    board[0].models.append(board[0][0])
    board[0][0].position = board_position(5, 10)
    board[0][1].position = board_position(7, 10)
    let candidate = board[0]
    board.units.clear()
    return !setup_rules_valid(board, candidate, MovementKind::ingress, false)

# pp.69/80: all-model Deep Strike bypasses edge/opponent-zone restrictions;
# mixed permissions do not. It never waives the strict enemy distance.
fun test_movement11_deep_strike_all_models_and_distance() -> Bool:
    let board = movement11_fixture()
    let candidate = board[0]
    candidate[0].abilities.append(AbilityKind::deep_strike)
    candidate[0].position = board_position(20, 20)
    if !setup_rules_valid(board, candidate, MovementKind::ingress, false):
        return false
    candidate.models.append(candidate[0])
    candidate[1].position = board_position(22, 20)
    candidate[1].abilities.clear()
    if setup_rules_valid(board, candidate, MovementKind::ingress, false):
        return false
    candidate[1].abilities.append(AbilityKind::deep_strike)
    board[0].owned_by_player1 = true
    board[0][0].position = board_position(13, 20)
    return !setup_rules_valid(board, candidate, MovementKind::ingress, false)

# p.69: arrival locks later moves and captures ingress/setup history.
fun test_movement11_ingress_history_and_lock() -> Bool:
    let board = movement11_fixture()
    board.reserve_units.append(board[0])
    board.units.clear()
    enter_from_reserves(board, unit_id(0), board_position(5, 20), MovementKind::ingress)
    return board.reserve_units.empty() and board[0].history.has_ingressed and board[0].history.ingress_locked and board[0].history.was_set_up_this_turn and !battlefield_move_eligible(board, unit_id(0), MovementKind::normal)

# p.14: failed ingress/cancel retains the reserve and its previous selection.
fun test_movement11_ingress_cancel_then_stationary() -> Bool:
    let board = movement11_fixture()
    board.reserve_units.append(board[0])
    board.units.clear()
    board.current_round = 0
    let phase = movement_phase(board)
    phase.select_reserve_unit(board, unit_id(0))
    if can phase.place_at(board, board_position(5, 20)):
        return false
    phase.skip(board)
    phase.select_reserve_unit(board, unit_id(0))
    phase.reserve_remain_stationary(board)
    phase.end_move(board)
    return phase.is_done() and board.reserve_units.size() == 1 and board.units.empty()

# p.68: repositioning keeps ongoing effects, advance/fall-back flags and stable
# identity while retiring, not compacting, the original battlefield slot.
fun test_movement11_reposition_preserves_identity_and_restrictions() -> Bool:
    let board = movement11_fixture()
    board[0].battle_socked = true
    record_move(board, unit_id(0), MovementKind::advance)
    let identity = board[0].identity
    if !reposition_unit(board, unit_id(0)) or !board[0].empty() or !board[0].retired:
        return false
    enter_from_reserves(board, unit_id(0), board_position(5, 20), MovementKind::ingress)
    return board.units.size() == 2 and board[1].identity == identity and board[1].history.advanced_this_turn and board[1].battle_socked and board[1].history.repositioned and !board[1].allows_action_start()

# p.69: expire never-arrived reserves at end round 3, exempt repositioned ones,
# and preserve the destroyed roster rather than losing its archive.
fun test_movement11_unused_reserve_deadline_and_exemption() -> Bool:
    let board = movement11_fixture()
    board[0].history.strategic_reserve = true
    board.reserve_units.append(board[0])
    board[0].history.repositioned = true
    board.reserve_units.append(board[0])
    board.current_round = 1
    expire_unused_reserves(board)
    if board.reserve_units.size() != 2:
        return false
    board.current_round = 2
    expire_unused_reserves(board)
    return board.reserve_units.size() == 1 and board.reserve_units[0].history.repositioned and board.expired_reserves.value.size() == 1 and board.expired_reserves.value[0].destroyed_models.value.size() == 1

# p.68: exactly half of configured points is legal; unknown data and
# FORTIFICATIONS cannot be voluntarily placed in strategic reserves.
fun test_movement11_strategic_reserve_points_and_fortification() -> Bool:
    let board = movement11_fixture()
    board.units.clear()
    let unit = make_infernus_squad()
    board.reserve_units.append(unit)
    board.battle_points_limit = 1000
    board.reserve_units[0].points_known = true
    board.reserve_units[0].points = 500
    if !strategic_reserve_valid(board, false, unit_id(0)):
        return false
    board.reserve_units[0].points = 501
    if strategic_reserve_valid(board, false, unit_id(0)):
        return false
    board.reserve_units[0].points = 500
    board.reserve_units[0][0].keywords.append(Keyword::fortification)
    return !strategic_reserve_valid(board, false, unit_id(0))

# User instruction: Scouts values are uniform, mismatches assert. Test its
# pure validation predicate without intentionally crashing the supported suite.
fun test_movement11_scouts_uniform_value_guard() -> Bool:
    let board = movement11_fixture()
    board[0][0].scout_distances.append(movement11_scout_value(6))
    board[0].models.append(board[0][0])
    if scouts_distance(board[0]) != 6:
        return false
    board[0][1].scout_distances[0] = movement11_scout_value(8)
    if scouts_values_uniform(board[0]):
        return false
    board[0][1].scout_distances.clear()
    return scouts_distance(board[0]) == 0

# p.84: scout setup from reserves must be wholly in own home zone; ordinary
# scout movement also finishes strictly more than 8 horizontally from enemies.
fun test_movement11_scout_setup_and_move_distance() -> Bool:
    let board = movement11_fixture()
    let candidate = board[0]
    candidate.owned_by_player1 = true
    candidate[0].position = board_position(20, 4)
    if !setup_rules_valid(board, candidate, MovementKind::scout, false):
        return false
    candidate[0].position = board_position(12, 5)
    return !movement_finish_valid(board, candidate, unit_id(1), MovementKind::scout)

# p.70: closest target ignores Aircraft and permits tied nearest enemy choices.
fun test_movement11_surge_closest_and_aircraft() -> Bool:
    let board = attack_declaration_fixture()
    if !surge_target_valid(board, unit_id(0), unit_id(1)) or surge_target_valid(board, unit_id(0), unit_id(2)):
        return false
    board[1][0].keywords.append(Keyword::aircraft)
    return surge_target_valid(board, unit_id(0), unit_id(2)) and !surge_target_valid(board, unit_id(0), unit_id(1))

# p.70: a generic surge is never offered without an actual granting trigger.
fun test_movement11_surge_requires_trigger_and_unshocked() -> Bool:
    let board = movement11_fixture()
    let distance : StatModifier
    distance = 3
    let absent = surge(board, unit_id(0), distance, false)
    board[0].battle_socked = true
    let shocked = surge(board, unit_id(0), distance, true)
    return absent.is_done() and shocked.is_done()

# p.70: a reachable engaged endpoint outranks an endpoint that stays away;
# when out of reach, take the closest legal finite-grid endpoint.
fun test_movement11_surge_approach_obligations() -> Bool:
    let board = attack_declaration_fixture()
    board.surge_target = 1
    let candidate = board[0]
    if surge_goals_valid(board, board[0], candidate, unit_id(0), 3):
        return false
    candidate[0].position = board_position(8, 5)
    if !complete_move_valid(board, board[0], candidate, unit_id(0), MovementKind::surge, 3):
        return false
    board[1][0].position = board_position(20, 5)
    board[2][0].position = board_position(30, 8)
    candidate[0].position = board_position(8, 5)
    return surge_goals_valid(board, board[0], candidate, unit_id(0), 3)

# p.87: retained dead models cannot supply engagement or coherency neighbours.
fun test_movement11_pending_corpses_not_engagement_or_neighbours() -> Bool:
    let board = movement11_fixture()
    let enemy = board[0]
    enemy.owned_by_player1 = true
    enemy[0].position = board_position(8, 5)
    enemy[0].state = ModelState::pending_destruction
    board.units.append(enemy)
    board[0].models.append(board[0][0])
    board[0][1].position = board_position(8, 5)
    board[0][1].state = ModelState::pending_destruction
    return !board.is_in_melee(board[0]) and board[0].is_coherent()

# Finite source-data fixture constructor for Scouts distances (pp.78/84).
fun movement11_scout_value(Int value) -> FixedStat:
    let result : FixedStat
    result = value
    return result

# pp.12/14: five 40mm Terminators need a different coherent preset to fit
# the lower deployment zone. Probe and commit must use the same layout.
fun test_movement11_setup_searches_valid_preset_and_commits_it() -> Bool:
    let board : Board
    let unit = make_terminator_squad()
    unit.owned_by_player1 = true
    board.reserve_units.append(unit)
    board.identify_units()
    let position = board_position(5, 1)
    if !setup_at_valid(board, board.reserve_units[0], position, MovementKind::normal, false):
        return false
    enter_from_reserves(board, unit_id(0), position, MovementKind::normal)
    return board.reserve_units.empty() and unit_in_home_zone(board[0], true) and unit_placement_valid(board, board[0], 0, true)

# p.70: completing a generic out-of-phase move also consumes the phase's
# surge eligibility; the caller need not be the Movement phase action.
fun test_movement11_generic_move_blocks_later_surge() -> Bool:
    let board = attack_declaration_fixture()
    let source = unit_id(0)
    let moved = move(board, source, 0)
    moved.move_to(board, source, board_position(6, 5))
    let distance : StatModifier
    distance = 3
    let subsequent = surge(board, source, distance, true)
    return subsequent.is_done() and board[0].history.last_move_phase == board.phase_serial.value + 1

# p.87: do not strand a pending battlefield trigger by transferring its
# retained model into reserves. The rejected transfer preserves all state.
fun test_movement11_reposition_pending_trigger_rejected_atomically() -> Bool:
    let board = damage_test_fixture()
    board[1][0].state = ModelState::pending_destruction
    board[1][0].destruction_pending = true
    let before = to_string(board)
    return !reposition_unit(board, unit_id(1)) and to_string(board) == before

# p.69: ingress is not a shooting/charge prohibition once its next-Charge
# move lock ends; fresh reserve factories must receive valid core gates.
fun test_movement11_ingress_allows_shooting_and_later_charge() -> Bool:
    let board = movement11_fixture()
    let reserve = make_infernus_squad()
    board.units.clear()
    board.reserve_units.append(reserve)
    enter_from_reserves(board, unit_id(0), board_position(2, 20), MovementKind::ingress)
    return board[0].can_shoot and board[0].can_charge and board[0].history.ingress_locked

# p.68: a repositioned unit retains restrictions in the same turn, but those
# turn-long restrictions expire at its next turn even while still in reserves.
fun test_movement11_reserve_new_turn_expires_movement_restrictions() -> Bool:
    let board = movement11_fixture()
    record_move(board, unit_id(0), MovementKind::advance)
    if !reposition_unit(board, unit_id(0)):
        return false
    board.start_turn_history()
    return !board.reserve_units[0].has_run and !board.reserve_units[0].history.advanced_this_turn and board.reserve_units[0].can_shoot and board.reserve_units[0].can_charge

# pp.12/14: one larger bearer plus ten smaller bases has a coherent lower-zone
# preset; conservative uniform spacing must not hide a legal mixed layout.
# This explicit geometry fixture does not grant new-edition attachment rights.
fun test_movement11_mixed_base_preset_does_not_over_space() -> Bool:
    let board : Board
    let unit = make_beast_snagga_boyz()
    let leader = make_beastboss_morgrim()
    unit.models.append(leader[0])
    unit.owned_by_player1 = true
    board.reserve_units.append(unit)
    board.identify_units()
    let position = board_position(5, 1)
    if !setup_at_valid(board, board.reserve_units[0], position, MovementKind::normal, false):
        return false
    enter_from_reserves(board, unit_id(0), position, MovementKind::normal)
    return board[0].is_coherent() and unit_in_home_zone(board[0], true) and unit_placement_valid(board, board[0], 0, true)

# pp.12/33/85: walker grants cannot revoke friendly traversal or Desperate
# Escape's independent permission to cross all enemy models, even TITANIC.
fun test_movement11_walker_does_not_revoke_other_traversal_permissions() -> Bool:
    let board = movement11_fixture()
    board[0][0].abilities.append(AbilityKind::super_heavy_walker)
    let obstacle = board[0]
    obstacle[0].keywords.append(Keyword::titanic)
    obstacle[0].position = board_position(7, 5)
    board.units.append(obstacle)
    let path : ModelPath
    path.model = 0
    if !waypoint_valid(board, board[0], path, board_position(11, 5), MovementKind::normal, 0, -1, false):
        return false
    board[1].owned_by_player1 = true
    return waypoint_valid(board, board[0], path, board_position(11, 5), MovementKind::desperate_escape, 0, -1, false)

# pp.12/14: the 90mm/75mm row fits between two deployed bases only when
# each adjacent pair gets its own whole-quad clearance (4,3,3 inches).
fun test_movement11_mixed_row_fits_gap_between_deployed_models() -> Bool:
    let board : Board
    let blocker = make_infernus_squad()
    blocker.models.resize(1)
    blocker.owned_by_player1 = true
    board.units.append(blocker)
    board.units.append(blocker)
    board[0][0].position = board_position(12, 3)
    board[1][0].position = board_position(27, 3)
    let unit = make_squighog_boyz()
    unit.owned_by_player1 = true
    board.reserve_units.append(unit)
    board.identify_units()
    let position = board_position(15, 2)
    if !setup_at_valid(board, board.reserve_units[0], position, MovementKind::normal, false):
        return false
    enter_from_reserves(board, unit_id(0), position, MovementKind::normal)
    return board[2][3].position.x == 25 and unit_placement_valid(board, board[2], 2, true) and unit_in_home_zone(board[2], true)

# User direction: destroy units with no legal supported deployment. A valid
# unit cannot take that action; rejected setup must not silently become reserves.
fun test_movement11_unplaceable_unit_destroyed_and_archived() -> Bool:
    let board : Board
    let unit = make_infernus_squad()
    unit.models.resize(1)
    board.reserve_units.append(unit)
    board.identify_units()
    let identity = board.reserve_units[0].identity
    let sequence = deploy(board)
    sequence.select_unit(board, unit_id(0))
    if can sequence.destroy_unplaceable_unit(board):
        return false
    board.reserve_units[0][0].geometry.unsupported_footprint = true
    if !(can sequence.destroy_unplaceable_unit(board)):
        return false
    sequence.destroy_unplaceable_unit(board)
    return board.reserve_units.empty() and board.expired_reserves.value.size() == 1 and board.expired_reserves.value[0].identity == identity and board.expired_reserves.value[0].destroyed_models.value.size() == 1

# Task-12 fixtures supply explicit rules, not invented faction datasheets (pp.78–85).
fun shooting12_fixture() -> Board:
    let board = attack_declaration_fixture()
    board.begin_phase(BattlePhase::shooting)
    board[0].can_shoot = true
    board.command_points[0] = 3
    return board

# pp.34–35: modes depend on engagement and advance, not a single can_shoot flag.
fun test_shooting12_mode_eligibility_and_advance_assault() -> Bool:
    let board = shooting12_fixture()
    if !shooting_kind_valid(board, unit_id(0), ShootingKind::normal) or shooting_kind_valid(board, unit_id(0), ShootingKind::snap):
        return false
    board[0].history.advanced_this_turn = true
    if shooting_unit_valid(board, unit_id(0)):
        return false
    board[0][0].additional_weapon_rules[0].append(weapon_rule(WeaponRuleKind::assault))
    return shooting_kind_valid(board, unit_id(0), ShootingKind::assault) and !shooting_kind_valid(board, unit_id(0), ShootingKind::normal) and !shooting_kind_valid(board, unit_id(0), ShootingKind::indirect)

# pp.34/58/88: no ranged weapon still permits selecting; shooting locks action
# starts only until phase end, and the unit cannot select twice in that phase.
fun test_shooting12_no_weapon_unit_selection_and_phase_action_lock() -> Bool:
    let board = shooting12_fixture()
    board[0][0].weapons.clear()
    let phase = shooting_phase(board)
    phase.select_shooting_unit(board, unit_id(0))
    phase.choose_shooting_kind(board, ShootingKind::normal)
    phase.skip(board)
    if !board[0].has_shoot or board[0].allows_action_start() or (can phase.select_shooting_unit(board, unit_id(0))):
        return false
    board.begin_phase(BattlePhase::charge)
    return board[0].allows_action_start()

# pp.33–35/58/87: fallback/actions/retired units and the wrong owner cannot shoot.
fun test_shooting12_source_restrictions() -> Bool:
    let board = shooting12_fixture()
    if shooting_unit_valid(board, unit_id(1)):
        return false
    board[0].history.fell_back_this_turn = true
    if shooting_unit_valid(board, unit_id(0)):
        return false
    board[0].history.fell_back_this_turn = false
    board[0].history.action_started = true
    if shooting_unit_valid(board, unit_id(0)):
        return false
    board[0].history.action_started = false
    board[0][0].state = ModelState::pending_destruction
    return !shooting_unit_valid(board, unit_id(0))

# pp.80/83: multiple pistols can be selected; ordinary models cannot mix the
# sidearm categories, while a Monster/Vehicle bearer can select both.
fun test_shooting12_pistol_alias_exclusive_categories_and_vehicle_exception() -> Bool:
    let board = shooting12_fixture()
    board[0][0].weapons.append(Weapon::bolt_pistol)
    board[0][0].weapons.append(Weapon::captain_storm_bolter)
    board[0][0].additional_weapon_rules[2].append(weapon_rule(WeaponRuleKind::close_quarters))
    let sequence = attack(board, unit_id(0), unit_id(1), false, false)
    sequence.select_weapon(board, attack_test_slot(1))
    if (can sequence.select_weapon(board, attack_test_slot(0))) or !(can sequence.select_weapon(board, attack_test_slot(2))):
        return false
    sequence.select_weapon(board, attack_test_slot(2))
    if sequence.declarations.size() != 2:
        return false
    board[0][0].keywords.append(Keyword::vehicle)
    return can sequence.select_weapon(board, attack_test_slot(0))

# pp.35/62–63/88: engaged non-vehicles are prohibited; engaged vehicles are
# targets only in the firing player's Shooting phase, and Blast still fails.
fun test_shooting12_engaged_target_vehicle_and_blast_gates() -> Bool:
    let board = shooting12_fixture()
    let friendly = board[0]
    friendly[0].position = board_position(11, 5)
    friendly.identity = 0
    friendly[0].identity = 0
    board.units.append(friendly)
    board.identify_units()
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    if declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false):
        return false
    board[1][0].keywords.append(Keyword::vehicle)
    if !declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false):
        return false
    let info = declared_attack_info(board, unit_id(0), unit_id(1), weapon, board.attack_info)
    if info.engaged_hit_penalties != 1:
        return false
    weapon.selected_rules.append(weapon_rule(WeaponRuleKind::blast))
    if declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false):
        return false
    weapon.selected_rules.clear()
    board.current_player = true
    return !declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false)

# p.35: engaged ordinary bearers use only sidearms against their engaged
# enemies; the Monster/Vehicle bearer has a penalty for other ranged attacks.
fun test_shooting12_close_quarters_permissions_and_penalty_exception() -> Bool:
    let board = shooting12_fixture()
    board[1][0].position = board_position(7, 5)
    board[0].shooting_kind = ShootingKind::close_quarters
    board[0][0].additional_weapon_rules[0].append(weapon_rule(WeaponRuleKind::close_quarters))
    if !shooting_kind_valid(board, unit_id(0), ShootingKind::close_quarters):
        return false
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    if !declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false) or declaration_target_valid(board, unit_id(0), weapon, unit_id(2), false):
        return false
    board[0][0].keywords.append(Keyword::monster)
    let info = declared_attack_info(board, unit_id(0), unit_id(1), weapon, board.attack_info)
    if info.engaged_hit_penalties != 0:
        return false
    weapon.selected_rules.clear()
    weapon.current_target_rules.clear()
    info = declared_attack_info(board, unit_id(0), unit_id(2), weapon, board.attack_info)
    return declaration_target_valid(board, unit_id(0), weapon, unit_id(2), false) and info.engaged_hit_penalties == 1

# p.83 / supplied modifier appendix: Lone Operative uses bearer-to-target
# distance; a nearby unit-mate cannot give a distant bearer visibility.
fun test_shooting12_lone_operative_per_bearer_and_custom_range() -> Bool:
    let board = shooting12_fixture()
    board[1][0].abilities.append(AbilityKind::lone_operative)
    board[1][0].position = board_position(20, 5)
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    if declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false):
        return false
    let nearby = board[0][0]
    nearby.position = board_position(10, 5)
    board[0].models.append(nearby)
    if !unit_visible_to_unit(board, board[0], board[1]) or declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false):
        return false
    board[1].lone_operative_range = 15
    return declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false)

# pp.35/50/82–83: indirect permits Hidden targets but still respects per-bearer
# Lone Operative. Cover is forced even when the target is ordinarily visible.
fun test_shooting12_indirect_visibility_lone_operative_and_cover() -> Bool:
    let board = shooting12_fixture()
    board[1][0].position = board_position(27, 5)
    board.terrain_areas.append(terrain_area(26, 4, 28, 6, true))
    board[0][0].additional_weapon_rules[0].append(weapon_rule(WeaponRuleKind::indirect_fire))
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    if declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false):
        return false
    board[0].shooting_kind = ShootingKind::indirect
    if !declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false):
        return false
    board.terrain_areas.clear()
    let info = declared_attack_info(board, unit_id(0), unit_id(1), weapon, board.attack_info)
    if !info.target_has_cover:
        return false
    board[1][0].abilities.append(AbilityKind::lone_operative)
    return !declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false)

# p.35: indirect fails natural 1–5, or 1–3 when stationary and a friendly unit
# sees the target. Positive hit modifiers cannot bypass these natural-face gates.
fun test_shooting12_indirect_unmodified_faces_and_stationary_tracking() -> Bool:
    let board = shooting12_fixture()
    board[0].shooting_kind = ShootingKind::indirect
    board[0][0].additional_weapon_rules[0].append(weapon_rule(WeaponRuleKind::indirect_fire))
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    board[0].history.made_move_this_turn = true
    let info = declared_attack_info(board, unit_id(0), unit_id(1), weapon, board.attack_info)
    if !(classify_attack_hit(board, info, attack_test_die(5), 10) == AttackRollResult::failed):
        return false
    board[0].history.made_move_this_turn = false
    record_move(board, unit_id(0), MovementKind::stationary)
    info = declared_attack_info(board, unit_id(0), unit_id(1), weapon, board.attack_info)
    if !info.indirect_stationary_visible or !(classify_attack_hit(board, info, attack_test_die(3), 10) == AttackRollResult::failed) or !(classify_attack_hit(board, info, attack_test_die(4), 0) == AttackRollResult::success):
        return false
    board[0][0].history.was_set_up_this_turn = true
    return !stationary_this_turn(board[0])

# pp.35/57: snap and indirect prohibit every hit reroll, including paid CP.
fun test_shooting12_snap_hit_rerolls_forbidden_and_single_target() -> Bool:
    let board = shooting12_fixture()
    board.attack_info.only_hits_on_6 = true
    board.attack_info.reroll_hits = true
    let dice = resolve_attack_dice(board, board[1], board[0], attack_test_count(1))
    dice.roll(board, board[1], board[0], attack_test_die(3))
    if !dice.is_done() or dice.generated_hits != 0 or board.command_points[0] != 3:
        return false
    board[0].shooting_kind = ShootingKind::snap
    board.attack_info.target_unit_id = 1
    board[0].snap_target = 1
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    return declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false) and !declaration_target_valid(board, unit_id(0), weapon, unit_id(2), false)

# p.35: even an ordinary visible indirect target prohibits hit rerolls.
fun test_shooting12_indirect_hit_rerolls_forbidden() -> Bool:
    let board = shooting12_fixture()
    board.attack_info.shooting_kind = ShootingKind::indirect
    board.attack_info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::indirect_fire))
    board.attack_info.reroll_hits = true
    let dice = resolve_attack_dice(board, board[1], board[0], attack_test_count(1))
    dice.roll(board, board[1], board[0], attack_test_die(5))
    return dice.is_done() and dice.generated_hits == 0 and board.command_points[0] == 3

# p.82: Heavy allows an actual <=3in move, but no setup, engagement, opponent
# turn, or larger movement by any live member, including another model.
fun test_shooting12_heavy_complete_conditions() -> Bool:
    let board = shooting12_fixture()
    board.attack_info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::heavy))
    board[0].has_moved = true
    board[0][0].history.reset_movement_distance()
    board[0][0].history.record_movement_segment(3, 0, 0)
    if get_hit_roll_bonus(board) != 1:
        return false
    board[0][0].history.reset_movement_distance()
    board[0][0].history.record_movement_segment(3, 1, 0)
    if get_hit_roll_bonus(board) != 0:
        return false
    board[0][0].history.reset_movement_distance()
    board[0].history.was_set_up_this_turn = true
    if get_hit_roll_bonus(board) != 0:
        return false
    board[0].history.was_set_up_this_turn = false
    board.current_player = true
    return get_hit_roll_bonus(board) == 0

# pp.79/84: Blast X and Rapid Fire snapshot target-selection count/range and
# ignore later casualties/reposition; pending corpses are not counted.
fun test_shooting12_blast_and_rapid_fire_declaration_snapshots() -> Bool:
    let board = shooting12_fixture()
    let model = board[1][0]
    board[1].models.resize(11)
    for i in range(11):
        board[1][i] = model
    board[0][0].additional_weapon_rules[0].append(weapon_rule(WeaponRuleKind::blast, 2))
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    snapshot_weapon_target(board, unit_id(0), weapon, unit_id(1))
    let before = gathering_extra_attacks(board, unit_id(0), unit_id(1), weapon)
    board[1].models.resize(1)
    board[1][0].position = board_position(30, 5)
    return before == 6 and gathering_extra_attacks(board, unit_id(0), unit_id(1), weapon) == before

# p.79: Cleave adds X per five models only when a weapon's attacks all target
# one unit; a split must not receive that addition.
fun test_shooting12_cleave_unsplit_and_split() -> Bool:
    let board = shooting12_fixture()
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    weapon.selected_rules.clear()
    weapon.selected_rules.append(weapon_rule(WeaponRuleKind::cleave, 3))
    weapon.current_target_rules = weapon.selected_rules
    weapon.targeted[1] = true
    weapon.target_model_counts[1] = 12
    if gathering_extra_attacks(board, unit_id(0), unit_id(1), weapon) != 6:
        return false
    weapon.targeted[2] = true
    return gathering_extra_attacks(board, unit_id(0), unit_id(1), weapon) == 0

# p.83: One Shot is spent at Select Weapons, even when attacks are declined.
# The model archive retains slot usage rather than granting a revived weapon.
fun test_shooting12_one_shot_selection_and_archive() -> Bool:
    let board = shooting12_fixture()
    board[0][0].additional_weapon_rules[0].append(weapon_rule(WeaponRuleKind::one_shot))
    let sequence = attack(board, unit_id(0), unit_id(1), false, false)
    sequence.select_weapon(board, attack_test_slot(0))
    if !board[0][0].used_once_per_battle_weapon[0]:
        return false
    sequence.skip(board)
    sequence.skip_target(board)
    board[0].remove_model(0)
    let revived = board[0].destroyed_models.value[0]
    board[0].models.append(revived)
    let selected : Bool[MAX_WEAPONS]
    return !weapon_selection_valid(board, unit_id(0), 0, 0, false, selected, false)

# p.78: duplicate numeric abilities are alternatives, not max/sum; different
# ANTI keywords are the same duplicate family and require one selected instance.
fun test_shooting12_duplicate_ability_choice_and_anti_family() -> Bool:
    let board = shooting12_fixture()
    let rules : WeaponAbilitySet
    rules.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    rules.append(weapon_rule(WeaponRuleKind::sustained_hit, 2))
    rules.append(weapon_rule(WeaponRuleKind::anti_monster, 4))
    rules.append(weapon_rule(WeaponRuleKind::anti_vehichle, 2))
    let choice = choose_weapon_abilities(board, rules)
    let index : WeaponAbilityChoice
    index = 0
    choice.choose_weapon_ability(board, index)
    index = 2
    choice.choose_weapon_ability(board, index)
    return choice.is_done() and choice.chosen.size() == 2 and choice.chosen[0].parameter == 1 and choice.chosen[1].kind == WeaponRuleKind::anti_monster

# pp.78–79: chosen conditional abilities apply to the unit keyword union only.
fun test_shooting12_conditional_generic_anti_and_sustained() -> Bool:
    let board = shooting12_fixture()
    let info = board.attack_info
    info.weapon_rules_known = true
    info.selected_weapon_rules.append(conditional_weapon_rule(WeaponRuleKind::anti, 2, Keyword::vehicle))
    info.selected_weapon_rules.append(conditional_weapon_rule(WeaponRuleKind::sustained_hit, 3, Keyword::vehicle))
    if info.has_weapon_rule(board, WeaponRuleKind::sustained_hit) or critical_wound_threshold(board, info) != 6:
        return false
    board[1][0].keywords.append(Keyword::vehicle)
    return info.has_weapon_rule(board, WeaponRuleKind::sustained_hit) and info.max_weapon_parameter(board, WeaponRuleKind::sustained_hit) == 3 and critical_wound_threshold(board, info) == 2

# p.85: Twin-linked is an optional free wound reroll, never a second reroll.
fun test_shooting12_twin_linked_wound_reroll() -> Bool:
    let board = shooting12_fixture()
    board.attack_info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::twin_linked))
    board.attack_info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::devastating_wounds))
    board.command_points[0] = 0
    let dice = resolve_attack_dice(board, board[1], board[0], attack_test_count(1))
    dice.roll(board, board[1], board[0], attack_test_die(6))
    dice.roll(board, board[1], board[0], attack_test_die(1))
    if !(can dice.select_reroll(board, board[1], board[0], attack_test_die(1))):
        return false
    dice.select_reroll(board, board[1], board[0], attack_test_die(1))
    dice.reroll(board, board[1], board[0], attack_test_die(6))
    return dice.is_done() and dice.generated_critical_wounds == 1 and board.command_points[0] == 0

# p.82: decline automatic Lethal wounding to retain a critical wound opportunity.
fun test_shooting12_lethal_hits_optional_decline() -> Bool:
    let board = shooting12_fixture()
    board.attack_info.add_letal_hits()
    board.attack_info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::devastating_wounds))
    board.command_points[0] = 0
    let dice = resolve_attack_dice(board, board[1], board[0], attack_test_count(1))
    dice.roll(board, board[1], board[0], attack_test_die(6))
    dice.use_lethal_hits(board, board[1], board[0], false)
    dice.roll(board, board[1], board[0], attack_test_die(6))
    return dice.is_done() and dice.generated_critical_wounds == 1 and dice.generated_wounds == 0

# User lifecycle instruction: preserve generated owning-field initialization;
# ability magnitudes/conditions are bounded and survive save round trips (p.78).
fun test_shooting12_bounded_ability_metadata_round_trip() -> Bool:
    let state = play()
    state.board = shooting12_fixture()
    state.board[0][0].additional_weapon_rules[0].append(conditional_weapon_rule(WeaponRuleKind::sustained_hit, 2, Keyword::vehicle))
    let restored = play()
    if !set_state(restored, to_string(state)):
        return false
    let rule = restored.board[0][0].additional_weapon_rules[0][0]
    return rule.parameter == 2 and rule.target_restricted and rule.target_keyword.value == Keyword::vehicle.value and restored.board[0][0].weapons.size() == 1

# p.82: each original critical hit can independently use/decline Lethal Hits.
fun test_shooting12_mixed_lethal_hits_choices() -> Bool:
    let board = shooting12_fixture()
    board.command_points[0] = 0
    board.attack_info.add_letal_hits()
    board.attack_info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::devastating_wounds))
    let dice = resolve_attack_dice(board, board[1], board[0], attack_test_count(2))
    dice.roll(board, board[1], board[0], attack_test_die(6))
    dice.roll(board, board[1], board[0], attack_test_die(6))
    dice.use_lethal_hits(board, board[1], board[0], true)
    dice.use_lethal_hits(board, board[1], board[0], false)
    dice.roll(board, board[1], board[0], attack_test_die(6))
    return dice.is_done() and dice.generated_wounds == 1 and dice.generated_critical_wounds == 1

# p.78: granting another duplicate cannot silently override/maximize the
# original choice; each target's original rules remain available separately.
fun test_shooting12_new_grant_duplicate_choice_preserves_original() -> Bool:
    let board = shooting12_fixture()
    board[0][0].additional_weapon_rules[0].append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    let declarations : DeclaredWeapons
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    weapon.targeted[1] = true
    declarations.append(weapon)
    let info = board.attack_info
    info.add_sustained_hits(2)
    let sequence = prepare_target_weapon_abilities(board, declarations, unit_id(0), unit_id(1), info)
    let first_sustained : WeaponAbilityChoice
    first_sustained = 1
    sequence.choose_weapon_ability(board, declarations, first_sustained)
    return sequence.is_done() and chosen_weapon_parameter(board, unit_id(1), declarations[0].current_target_rules, WeaponRuleKind::sustained_hit) == 1 and declarations[0].selected_rules.size() == 2

# pp.33/57/82: Advance/Fall Back/Lance effects expire before the opposing turn;
# already-selected shooting history is retained until its proper own turn reset.
fun test_shooting12_opponent_turn_clears_movement_shooting_restrictions() -> Bool:
    let board = shooting12_fixture()
    board[0].has_run = true
    board[0].has_charged = true
    board[0].can_shoot = false
    board[0].history.fell_back_this_turn = true
    board[0].has_shoot = true
    board.current_player = true
    board.start_turn_history()
    return !board[0].has_run and !board[0].has_charged and board[0].can_shoot and !board[0].history.fell_back_this_turn and board[0].has_shoot

# p.81: every Extra Attacks weapon must be selected in the shared fight
# declaration engine; finishing after just the ordinary melee weapon is illegal.
fun test_shooting12_extra_attacks_selection_is_mandatory() -> Bool:
    let board = shooting12_fixture()
    board[0][0].weapons[0] = Weapon::relic_weapon
    board[0][0].weapons.append(Weapon::force_weapon)
    board[0][0].additional_weapon_rules[1].append(weapon_rule(WeaponRuleKind::extra_attacks))
    let declarations : DeclaredWeapons
    let sequence = declare_model_weapons(board, declarations, unit_id(0), damage_test_model(0), true)
    sequence.select_weapon(board, declarations, attack_test_slot(0))
    if can sequence.skip(board, declarations):
        return false
    sequence.select_weapon(board, declarations, attack_test_slot(1))
    return can sequence.skip(board, declarations)

# pp.9/87: a nearer retained corpse cannot extend a ranged weapon's reach.
fun test_shooting12_range_ignores_nearer_retained_corpses() -> Bool:
    let board = shooting12_fixture()
    let corpse = board[1][0]
    corpse.position = board_position(10, 5)
    corpse.state = ModelState::pending_destruction
    board[1].models.append(corpse)
    board[1][0].position = board_position(35, 5)
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    return live_distance_to_model(board[1], board[0][0]) > 24.0 and !declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false)

# pp.57 / supplied appendix 04.03.03: a vanished Snap target can be replaced,
# retaining a single shared visible target for the remaining declarations.
fun test_shooting12_snap_ineligible_target_replacement() -> Bool:
    let board = shooting12_fixture()
    board[0].shooting_kind = ShootingKind::snap
    board[0].snap_target = 1
    let declarations : DeclaredWeapons
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    weapon.targeted[1] = true
    declarations.append(weapon)
    board[1].models.clear()
    let correction = revalidate_attack_targets(board, declarations, unit_id(0), false)
    if !(can correction.retarget_weapon(board, declarations, unit_id(0), unit_id(2))):
        return false
    correction.retarget_weapon(board, declarations, unit_id(0), unit_id(2))
    return correction.is_done() and board[0].snap_target.get() == 2 and declarations[0].targeted[2] and declaration_target_valid(board, unit_id(0), declarations[0], unit_id(2), false)

# p.82 / modifier appendix: Lance's +1 and a -1 wound effect cancel before the cap.
fun test_shooting12_lance_modifiers_cumulative_before_cap() -> Bool:
    let board = shooting12_fixture()
    board.attack_info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::lance))
    board.attack_info.wound_roll_malus = true
    board[0].has_charged = true
    return required_wound_roll(board, board.attack_info) == base_wound_threshold(board.attack_info.source.strenght(), board.attack_info.target_toughness.value)

# p.78: INFANTRY/BEASTS is one OR condition, not two accumulating instances.
fun test_shooting12_conditional_keyword_alternatives() -> Bool:
    let board = shooting12_fixture()
    let info = board.attack_info
    info.weapon_rules_known = true
    info.selected_weapon_rules.append(conditional_weapon_rule(WeaponRuleKind::sustained_hit, 2, Keyword::monster, Keyword::beasts))
    if info.has_weapon_rule(board, WeaponRuleKind::sustained_hit):
        return false
    board[1][0].keywords.append(Keyword::beasts)
    return info.has_weapon_rule(board, WeaponRuleKind::sustained_hit) and info.max_weapon_parameter(board, WeaponRuleKind::sustained_hit) == 2

# pp.14/84: early anchor rejection is necessary-only; full layout checks remain
# required, and search staging must not move the original or consume weapon data.
fun test_shooting12_deployment_prefilter_and_search_preserve_source() -> Bool:
    let board = shooting12_fixture()
    let unit = board[0]
    unit[0].additional_weapon_rules[0].append(conditional_weapon_rule(WeaponRuleKind::sustained_hit, 1, Keyword::monster, Keyword::vehicle))
    let original = to_string(unit)
    let result = deployment_has_position(board, unit)
    let unchanged = to_string(unit) == original
    return result and unchanged and !setup_at_valid(board, unit, board_position(5, 5), MovementKind::normal, false) and setup_anchor_possible(unit, board_position(5, 5), MovementKind::normal, true)

# p.85: Torrent produces ordinary automatic hits, no hit dice or critical-hit
# Lethal/Sustained effects, even during Snap Shooting; wound rolls still occur.
fun test_shooting12_torrent_automatic_hits_without_critical_effects() -> Bool:
    let board = shooting12_fixture()
    board.attack_info.source = Weapon::pyreblaster
    board.attack_info.only_hits_on_6 = true
    board.attack_info.add_letal_hits()
    board.attack_info.add_sustained_hits(2)
    board.command_points[0] = 0
    let dice = resolve_attack_dice(board, board[1], board[0], attack_test_count(2))
    if dice.generated_hits != 2 or dice.generated_wounds != 0 or board.current_state.value != CurrentStateDescription::wound_roll.value:
        return false
    dice.roll(board, board[1], board[0], attack_test_die(1))
    dice.roll(board, board[1], board[0], attack_test_die(1))
    return dice.is_done() and dice.generated_wounds == 0

# Supplied appendix 04.01.03: profiles are exclusive per weapon, not per unit.
fun test_shooting12_physical_profiles_and_shared_one_shot() -> Bool:
    let board = shooting12_fixture()
    board[0][0].weapons.append(board[0][0].weapons[0])
    board[0][0].weapon_profile_groups[0] = 1
    board[0][0].weapon_profile_groups[1] = 1
    let selected : Bool[MAX_WEAPONS]
    selected[0] = true
    if weapon_selection_valid(board, unit_id(0), 0, 1, false, selected, false):
        return false
    selected[0] = false
    if !weapon_selection_valid(board, unit_id(0), 0, 1, false, selected, false):
        return false
    consume_one_shot_profile(board[0][0], 0)
    return board[0][0].used_once_per_battle_weapon[1] and !weapon_selection_valid(board, unit_id(0), 0, 1, false, selected, false)

# Supplied appendix 04.01.03: Hunter target restrictions survive snapshots.
fun test_shooting12_hunter_profile_target_keywords() -> Bool:
    let board = shooting12_fixture()
    board[0][0].hunter_profile_conditions[0] = conditional_weapon_rule(WeaponRuleKind::anti, 0, Keyword::monster)
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    if declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false):
        return false
    board[1][0].keywords.append(Keyword::monster)
    return declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false)

# Legacy datasheet fixtures encode paired plasma profiles of one weapon.
fun test_shooting12_legacy_plasma_profile_groups() -> Bool:
    let legionaries = make_legionaries()
    let hellblasters = make_hellblaster_squad()
    return legionaries[0].weapon_profile_groups[0].value == 1 and legionaries[0].weapon_profile_groups[1].value == 1 and legionaries[1].weapon_profile_groups[0].value == 0 and hellblasters[0].weapon_profile_groups[1].value == 1 and hellblasters[0].weapon_profile_groups[2].value == 1

# pp.17/78/83: spelling aliases require one duplicate choice and cannot split
# identical attacks, while the selected instance retains its target condition.
fun test_shooting12_sidearm_alias_duplicates_and_attack_grouping() -> Bool:
    let board = shooting12_fixture()
    let rules : WeaponAbilitySet
    rules.append(weapon_rule(WeaponRuleKind::pistol))
    rules.append(conditional_weapon_rule(WeaponRuleKind::close_quarters, 0, Keyword::vehicle))
    let choice = choose_weapon_abilities(board, rules)
    if choice.is_done():
        return false
    let index : WeaponAbilityChoice
    index = 1
    choice.choose_weapon_ability(board, index)
    if !choice.is_done() or choice.chosen.size() != 1 or chosen_weapon_has_rule(board, unit_id(1), choice.chosen, WeaponRuleKind::close_quarters):
        return false
    board[1][0].keywords.append(Keyword::vehicle)
    if !chosen_weapon_has_rule(board, unit_id(1), choice.chosen, WeaponRuleKind::close_quarters):
        return false
    let left = board.attack_info
    left.weapon_rules_known = true
    left.selected_weapon_rules.append(weapon_rule(WeaponRuleKind::pistol))
    let right = left
    right.selected_weapon_rules.clear()
    right.selected_weapon_rules.append(weapon_rule(WeaponRuleKind::close_quarters))
    if !attacks_are_identical(board, left, right):
        return false
    right.selected_weapon_rules.clear()
    return !attacks_are_identical(board, left, right)

# User-requested minimal coordinate choices, preserving the existing 44x30
# grid and x/y editor payload; zero-edge centres never fit a positive base.
fun test_geometry_action_positions_enumerate_only_interior_quads() -> Bool:
    let position : BoardPosition
    let candidates = enumerate(position)
    let valid = candidates.size() == (BOARD_WIDTH - 1) * (BOARD_HEIGHT - 1)
    for i in range(candidates.size()):
        valid = valid and candidates[i].x.value == 1 + i / (BOARD_HEIGHT - 1) and candidates[i].y.value == 1 + i % (BOARD_HEIGHT - 1)
    return valid

# User numeric-storage requirement: generated defaults retain the zero sentinel
# and bounded metadata is visible to the standard ML layout, not ignored Ints.
fun test_storage_bounded_metadata_defaults_and_observation_layout() -> Bool:
    let identity : EntityIdentity
    let history : UnitHistory
    let schema : StateSchema
    return identity.value == 0 and history.last_move_phase == 0 and history.selected_move_phase == 0 and history.last_ranged_attack_turn == 0 and history.move_kind == MovementKind::stationary and !history.shot_this_phase and schema.value == STATE_SCHEMA_VERSION and size_as_observation_tensor(identity) == 1 and size_as_observation_tensor(history.last_move_phase) == 1

# p.12 / user requirement: path positions stay in quads; two diagonal segments
# retain their exact float length across a save without a persisted float total.
fun test_storage_integer_segments_preserve_diagonal_path_and_save() -> Bool:
    let board = geometry_fixture()
    let path = geometry_path(0, 6, 6, 0)
    path.append_point(geometry_point(7 * MICROMETRES_PER_INCH, 7 * MICROMETRES_PER_INCH, 0))
    if path.points[0].x.value != 6 or path.points[0].y.value != 6:
        return false
    let paths : Vector<ModelPath>
    paths.append(path)
    let policy : MovementGeometryPolicy
    let success = try_move_models(board, unit_id(0), paths, 0, policy, true)
    let history = board[0][0].history
    let restored : ModelHistory
    let parsed = from_string(restored, to_string(history))
    let error = restored.distance_moved_this_turn() - 2.0 * sqrt(2.0)
    let valid = success and parsed and restored.horizontal_segments.size() == 2 and error < 0.000000001 and error > -0.000000001
    restored.record_movement_segment(1, 0, 0)
    valid = valid and restored.distance_moved_this_turn() > 3.0
    restored.reset_movement_distance()
    return valid and restored.distance_moved_this_turn() == 0.0 and restored.horizontal_segments.empty()

# Metadata/history upper bounds cannot be bypassed by a malformed saved value.
fun test_storage_rejects_out_of_range_serials_and_movement_history() -> Bool:
    let state = play()
    state.board = geometry_fixture()
    state.board.identify_units()
    let invalid = state
    invalid.board.phase_serial.value = MAX_PHASE_SERIAL
    let valid = !set_state(state, to_string(invalid))
    invalid = state
    invalid.board[0][0].history.vertical_distance.value = MAX_VERTICAL_DISTANCE
    valid = valid and !set_state(state, to_string(invalid))
    invalid = state
    invalid.board[0].history.last_ranged_attack_turn.value = MAX_TURN_STAMP
    return valid and !set_state(state, to_string(invalid)) and state.board.phase_serial == 0

# Core pp.36–37 fixture: one living circular-base model per army, 8 inches
# centre separation; IDs/permissions are explicit rather than default data.
fun charge13_fixture() -> Board:
    let board = geometry_fixture()
    let enemy = board[0]
    enemy.owned_by_player1 = true
    enemy[0].position = board_position(13, 5)
    board.units.append(enemy)
    board[0].can_charge = true
    board[1].can_charge = true
    board.command_points[0] = 3
    board.command_points[1] = 3
    board.identify_unit(board[0])
    board.identify_unit(board[1])
    return board

# p.36: select a friendly unit, not a target, before neutral chance input.
fun test_charge13_declaration_precedes_targets() -> Bool:
    let board = charge13_fixture()
    let phase = charge_phase(board)
    if !(can phase.select_charging_unit(board, unit_id(0))) or (can phase.select_charging_unit(board, unit_id(1))):
        return false
    phase.select_charging_unit(board, unit_id(0))
    let four : Dice
    four = 4
    return (can phase.roll_pair(board, four, four)) and !(can phase.select_charge_target(board, unit_id(1))) and !board[0].has_charged and board[0].history.declared_charge_phase == board.phase_serial.value + 1

# p.36: engagement, Advance, Fall Back and once-per-phase declaration gates.
fun test_charge13_source_prohibitions() -> Bool:
    let board = charge13_fixture()
    if !charge_source_valid(board, unit_id(0), false):
        return false
    board[0].history.advanced_this_turn = true
    if charge_source_valid(board, unit_id(0), false):
        return false
    board[0].history.advanced_this_turn = false
    board[0].history.fell_back_this_turn = true
    if charge_source_valid(board, unit_id(0), false):
        return false
    board[0].history.fell_back_this_turn = false
    board[1][0].position.x = 8
    return !charge_source_valid(board, unit_id(0), false) and !charge_source_valid(board, unit_id(31), false)

# p.36: proximity is <=12 inches base to base, never centre/anchor only.
fun test_charge13_twelve_inch_declaration_range() -> Bool:
    let board = charge13_fixture()
    board[1][0].position.x = 18
    if !charge_source_valid(board, unit_id(0), false):
        return false
    board[1][0].position.x = 19
    return !charge_source_valid(board, unit_id(0), false)

# p.36: failed double one leaves position/history distance untouched and
# cannot grant Fights First/Lance or be declared again in the same phase.
fun test_charge13_failed_attempt_no_success_flags() -> Bool:
    let board = charge13_fixture()
    let phase = charge_phase(board)
    phase.select_charging_unit(board, unit_id(0))
    let one : Dice
    one = 1
    phase.roll_pair(board, one, one)
    phase.keep_it(board, true)
    if can phase.select_charge_target(board, unit_id(1)):
        return false
    phase.cancel_charge(board)
    return !board[0].has_charged and board[0].history.charge_move_phase == 0 and board[0][0].position.x == 5 and board[0][0].history.distance_moved_this_turn() == 0.0 and !(can phase.select_charging_unit(board, unit_id(0))) and (can phase.end_charge(board))

# p.37: being able to reach engagement is insufficient if target is beyond
# the roll's full range. Selection is after the roll, not before.
fun test_charge13_post_roll_full_target_range() -> Bool:
    let board = charge13_fixture()
    board[1][0].position.x = 14
    let sequence = charge(board, unit_id(0), ChargeKind::ordinary)
    let three : Dice
    let four : Dice
    three = 3
    four = 4
    sequence.roll_pair(board, three, four)
    sequence.keep_it(board, true)
    return !(can sequence.select_charge_target(board, unit_id(1))) and !(can sequence.finish_charge_targets(board)) and (can sequence.cancel_charge(board))

# pp.9/36/56: reroll both dice once; target range uses the replacement total.
fun test_charge13_pair_reroll_replacement_targets() -> Bool:
    let board = charge13_fixture()
    let sequence = charge(board, unit_id(0), ChargeKind::ordinary)
    let one : Dice
    let four : Dice
    one = 1
    four = 4
    sequence.roll_pair(board, one, one)
    sequence.keep_it(board, false)
    sequence.reroll_pair(board, four, four)
    return board.command_points[0] == 2 and (can sequence.select_charge_target(board, unit_id(1))) and !(can sequence.reroll_pair(board, four, four))

# p.37: selecting the same enemy twice is illegal; multiple distinct targets
# remain selectable, and moving begins only after explicit finalization.
fun test_charge13_multi_target_selection() -> Bool:
    let board = charge13_fixture()
    let other = board[1]
    other[0].position = board_position(13, 8)
    board.units.append(other)
    let sequence = charge(board, unit_id(0), ChargeKind::ordinary)
    let six : Dice
    six = 6
    sequence.roll_pair(board, six, six)
    sequence.keep_it(board, true)
    sequence.select_charge_target(board, unit_id(1))
    if can sequence.select_charge_target(board, unit_id(1)):
        return false
    sequence.select_charge_target(board, unit_id(2))
    return sequence.target_count == 2 and (can sequence.finish_charge_targets(board)) and !(can sequence.charge_move_to(board, board_position(11, 5)))

# p.37: cancellation after target selection commits no staged positions.
fun test_charge13_cancel_movement_is_atomic() -> Bool:
    let board = charge13_fixture()
    let sequence = charge(board, unit_id(0), ChargeKind::ordinary)
    let four : Dice
    four = 4
    sequence.roll_pair(board, four, four)
    sequence.keep_it(board, true)
    sequence.select_charge_target(board, unit_id(1))
    sequence.finish_charge_targets(board)
    let model : ModelID
    model = 0
    sequence.select_charging_model(board, model)
    sequence.charge_waypoint(board, board_position(11, 5))
    sequence.finish_charge_model(board)
    sequence.cancel_charge(board)
    return sequence.is_done() and board[0][0].position.x == 5 and !board[0].has_charged and board[0][0].history.distance_moved_this_turn() == 0.0 and !charge_source_valid(board, unit_id(0), false)

# p.37: a completed move, even beyond M, grants charge-only history and the
# legacy Fights First consumer/Lance, and restores the caller's input context.
fun test_charge13_success_uses_roll_not_m() -> Bool:
    let board = charge13_fixture()
    board[1][0].position.x = 14
    let sequence = charge(board, unit_id(0), ChargeKind::ordinary)
    let four : Dice
    four = 4
    sequence.roll_pair(board, four, four)
    sequence.keep_it(board, true)
    sequence.select_charge_target(board, unit_id(1))
    sequence.finish_charge_targets(board)
    if !(can sequence.charge_move_to(board, board_position(12, 5))):
        return false
    sequence.charge_move_to(board, board_position(12, 5))
    return sequence.is_done() and board[0].has_charged and board[0].history.charge_move_phase == board.phase_serial.value + 1 and board[0].history.declared_charge_phase == board.phase_serial.value + 1 and board[0][0].history.distance_moved_this_turn() == 7.0 and !charge_source_valid(board, unit_id(0), false)

# p.37: an engaged endpoint is illegal if a legal within-1 endpoint exists.
fun test_charge13_within_one_obligation() -> Bool:
    let board = charge13_fixture()
    let targets : Bool[MAX_UNIT_COUNT]
    targets[1] = true
    return !charge_translate_valid(board, board[0], unit_id(0), board_position(10, 5), targets, 8, false) and charge_translate_valid(board, board[0], unit_id(0), board_position(11, 5), targets, 8, false) and board[0][0].position.x == 5

# p.37: never incidentally engage an unselected enemy at the final endpoint.
fun test_charge13_incidental_enemy_rejected() -> Bool:
    let board = charge13_fixture()
    let other = board[1]
    other[0].position = board_position(11, 7)
    board.units.append(other)
    let targets : Bool[MAX_UNIT_COUNT]
    targets[1] = true
    return !charge_translate_valid(board, board[0], unit_id(0), board_position(11, 5), targets, 8, false)

# p.37: every selected target must be engaged by the complete final unit.
fun test_charge13_all_selected_targets_engaged() -> Bool:
    let board = charge13_fixture()
    let other = board[1]
    other[0].position = board_position(13, 10)
    board.units.append(other)
    let targets : Bool[MAX_UNIT_COUNT]
    targets[1] = true
    targets[2] = true
    return !charge_translate_valid(board, board[0], unit_id(0), board_position(11, 5), targets, 12, false)

# p.37: each model must become closer to the nearest base of some target,
# not merely closer to a distant model while moving away from the unit.
fun test_charge13_closer_uses_nearest_target_base() -> Bool:
    let board = charge13_fixture()
    let far = board[1][0]
    far.position = board_position(5, 20)
    board[1].models.append(far)
    let finish = board[0][0]
    finish.position = board_position(4, 6)
    let targets : Bool[MAX_UNIT_COUNT]
    targets[1] = true
    return !charge_model_closer(board, board[0][0], finish, targets)

# pp.12/37: full base sweep and complete path distance cannot be bypassed by
# several individually short waypoints; failed probes leave shared state alone.
fun test_charge13_waypoint_total_and_collision() -> Bool:
    let board = charge13_fixture()
    let path : ModelPath
    path.model = 0
    if charge_waypoint_valid(board, board[0], path, board_position(14, 5), 12, false):
        return false
    path.append_point(geometry_point(8 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 0))
    path.append_point(geometry_point(5 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 0))
    return !charge_waypoint_valid(board, board[0], path, board_position(8, 5), 8, false) and board[0][0].position.x == 5

# Appendix 02.02.01 and pp.57/71/82: ordered modifiers, 12/6 caps and
# whole-unit flight reduction; Hover exempts that reduction.
fun test_charge13_modifiers_mode_caps_and_hover() -> Bool:
    let board = charge13_fixture()
    board[0].phase_modifiers.charge_roll.append(rule_modifier(ModifierOperation::add, 20))
    if charge_distance(board[0], 2, ChargeKind::ordinary, false) != 12 or charge_distance(board[0], 2, ChargeKind::into_the_fray, false) != 6 or charge_distance(board[0], 2, ChargeKind::ordinary, true) != 10:
        return false
    board[0][0].abilities.append(AbilityKind::hover)
    return charge_distance(board[0], 2, ChargeKind::ordinary, true) == 12

# p.71: traversal belongs only to FLY bearers when flight is chosen; grounded
# charge paths cannot cross enemies, and shared maximum distance remains capped.
fun test_charge13_flying_traversal_only_when_chosen() -> Bool:
    let board = charge13_fixture()
    board[0][0].keywords.append(Keyword::fly)
    let path : ModelPath
    path.model = 0
    return charge_waypoint_valid(board, board[0], path, board_position(14, 5), 10, true) and !charge_waypoint_valid(board, board[0], path, board_position(14, 5), 10, false)

# p.57: Leap to Defend requires actual movement this phase, not a declaration
# or a successful charge from an earlier phase. Fray permits non-chargers.
fun test_charge13_heroic_target_modes() -> Bool:
    let board = charge13_fixture()
    board[1][0].position.x = 11
    board[1].has_charged = true
    if charge_target_valid(board, unit_id(0), unit_id(1), 12, ChargeKind::leap_to_defend):
        return false
    board[1].history.charge_move_phase = board.phase_serial.value + 1
    if !charge_target_valid(board, unit_id(0), unit_id(1), 12, ChargeKind::leap_to_defend) or !charge_target_valid(board, unit_id(0), unit_id(1), 6, ChargeKind::into_the_fray):
        return false
    board[1][0].position.x = 13
    return !charge_target_valid(board, unit_id(0), unit_id(1), 12, ChargeKind::into_the_fray)

# p.57: Into the Fray costs one additional CP and is chosen before rolling;
# failed/cancelled charge retains the committed expenditure and targeting limit.
fun test_charge13_heroic_fray_cost_before_roll() -> Bool:
    let board = charge13_fixture()
    board[1][0].position.x = 11
    board.current_player = true
    let sequence = timing_heroic_intervention(board, false)
    sequence.select_intervening_unit(board, unit_id(0))
    if can sequence.choose_intervention_mode(board, ChargeKind::leap_to_defend):
        return false
    sequence.choose_intervention_mode(board, ChargeKind::into_the_fray)
    if board.command_points[0] != 1 or !board.has_used_strat(Stratagem::heroic_intervention, 0):
        return false
    let six : Dice
    six = 6
    sequence.roll_pair(board, six, six)
    sequence.cancel_charge(board)
    return sequence.is_done() and board.command_points[0] == 1 and !board[0].has_charged and !heroic_source_valid(board, false, unit_id(0))

# p.57: VEHICLE intervention sources require CHARACTER or WALKER, and
# insufficient CP cannot open an unusable mode decision.
fun test_charge13_heroic_source_cost_and_vehicle() -> Bool:
    let board = charge13_fixture()
    board[1][0].position.x = 11
    board[0][0].keywords.append(Keyword::vehicle)
    if heroic_source_valid(board, false, unit_id(0)):
        return false
    board[0][0].keywords.append(Keyword::walker)
    if !heroic_source_valid(board, false, unit_id(0)):
        return false
    board.command_points[0] = 1
    return !heroic_source_valid(board, false, unit_id(0))

# pp.36–37/82: Lance uses only completed moves, and charge-only Fights First
# expires at either player's turn boundary; an old declaration is phase-local.
fun test_charge13_success_expires_at_turn_boundary() -> Bool:
    let board = charge13_fixture()
    record_charge_move(board, unit_id(0))
    board[0].history.declared_charge_phase = board.phase_serial.value + 1
    board.start_turn_history()
    board.begin_phase(BattlePhase::charge)
    return !board[0].has_charged and charge_source_valid(board, unit_id(0), false) and board[0].history.charge_move_phase != board.phase_serial.value + 1

# p.36 infrastructure: declaration and successful-move stamps are bounded
# save metadata; malformed stamps must not bypass once-per-phase eligibility.
fun test_charge13_malformed_stamp_rejected() -> Bool:
    let state = play()
    state.board.units.append(charge13_fixture()[0])
    state.board.identify_unit(state.board[0])
    state.board[0].history.declared_charge_phase.value = MAX_PHASE_STAMP
    let text = to_string(state)
    let restored = play()
    return !set_state(restored, text)

# pp.12/37: the same charge may engage several declared units when its final
# bases meet all targets and the per-model approach obligations.
fun test_charge13_multiple_targets_success() -> Bool:
    let board = charge13_fixture()
    board[1][0].position.y = 4
    let other = board[1]
    other[0].position.y = 6
    board.units.append(other)
    let targets : Bool[MAX_UNIT_COUNT]
    targets[1] = true
    targets[2] = true
    return charge_translate_valid(board, board[0], unit_id(0), board_position(11, 5), targets, 8, false)

# pp.12/37: independent paths can detour around an unselected enemy; accepted
# waypoints stage privately, and final charge history records the whole route.
fun test_charge13_independent_detour_commits_whole_path() -> Bool:
    let board = charge13_fixture()
    board[1][0].position.x = 15
    let obstacle = board[1]
    obstacle[0].position.x = 9
    board.units.append(obstacle)
    let sequence = charge(board, unit_id(0), ChargeKind::ordinary)
    let five : Dice
    five = 5
    sequence.roll_pair(board, five, five)
    sequence.keep_it(board, true)
    sequence.select_charge_target(board, unit_id(1))
    sequence.finish_charge_targets(board)
    let model : ModelID
    model = 0
    sequence.select_charging_model(board, model)
    sequence.charge_waypoint(board, board_position(8, 3))
    sequence.charge_waypoint(board, board_position(12, 3))
    sequence.charge_waypoint(board, board_position(13, 5))
    sequence.finish_charge_model(board)
    if board[0][0].position.x != 5 or !(can sequence.finish_charge_move(board)):
        return false
    sequence.finish_charge_move(board)
    let distance = board[0][0].history.distance_moved_this_turn()
    return board[0].has_charged and board[0][0].position.x == 13 and distance > 9.8 and distance < 10.0 and !board[0].is_engaged_with(board[2])

# p.37: the within-1 obligation includes reachable detours, not only clear
# straight-line approaches; legality probing restores the staged endpoint.
fun test_charge13_reachable_detour_goal_required() -> Bool:
    let board = charge13_fixture()
    board[1][0].position.x = 15
    let obstacle = board[1]
    obstacle[0].position.x = 9
    board.units.append(obstacle)
    let candidate = board[0]
    candidate[0].position.x = 12
    let targets : Bool[MAX_UNIT_COUNT]
    targets[1] = true
    return !charge_finish_valid(board, board[0], candidate, unit_id(0), targets, 10, false) and candidate[0].position.x == 12 and board[0][0].position.x == 5

# pp.12/37: coherent placement alone is insufficient if a model moves away
# from every selected target; all live models have their own obligation.
fun test_charge13_every_model_must_approach() -> Bool:
    let board = charge13_fixture()
    board[0][0].position = board_position(9, 5)
    let extra = board[0][0]
    extra.position = board_position(10, 7)
    board[0].models.append(extra)
    let candidate = board[0]
    candidate[0].position = board_position(11, 5)
    candidate[1].position = board_position(10, 8)
    let targets : Bool[MAX_UNIT_COUNT]
    targets[1] = true
    return charge_source_valid(board, unit_id(0), false) and charge_placement_valid(board, candidate, unit_id(0), targets) and !charge_finish_valid(board, board[0], candidate, unit_id(0), targets, 8, false)

# p.36: on-battlefield membership/eligibility is necessary even when a
# low-level constructor is invoked directly; invalid construction changes nothing.
fun test_charge13_invalid_source_constructor_no_effect() -> Bool:
    let board = charge13_fixture()
    board[0].history.advanced_this_turn = true
    let sequence = charge(board, unit_id(0), ChargeKind::ordinary)
    return sequence.is_done() and board[0].history.declared_charge_phase == 0 and !board[0].has_charged

# p.36 infrastructure: cancellation consumes the declaration, but source,
# target and independent-path state survive a serialized pending charge.
fun test_charge13_pending_path_round_trip() -> Bool:
    let board = charge13_fixture()
    let sequence = charge(board, unit_id(0), ChargeKind::ordinary)
    let four : Dice
    four = 4
    sequence.roll_pair(board, four, four)
    sequence.keep_it(board, true)
    sequence.select_charge_target(board, unit_id(1))
    sequence.finish_charge_targets(board)
    let model : ModelID
    model = 0
    sequence.select_charging_model(board, model)
    sequence.charge_waypoint(board, board_position(11, 5))
    let serialized = to_string(sequence)
    let restored : Charge
    let index = 0
    if !from_string(restored, serialized, index):
        return false
    restored.finish_charge_model(board)
    restored.finish_charge_move(board)
    return restored.is_done() and board[0].has_charged and board[0][0].position.x == 11

# p.85: Super-heavy Walker's Normal/Advance/Fall Back traversal exception
# cannot leak into charges merely because their paths share geometry helpers.
fun test_charge13_super_heavy_walker_cannot_cross_enemy() -> Bool:
    let board = charge13_fixture()
    board[0][0].abilities.append(AbilityKind::super_heavy_walker)
    let path : ModelPath
    path.model = 0
    return !charge_waypoint_valid(board, board[0], path, board_position(14, 5), 12, false)

# p.74: AIRCRAFT cannot charge; only FLYING units may select them, but
# every model can cross an Aircraft's base en route to another selected target.
fun test_charge13_aircraft_source_target_and_traversal() -> Bool:
    let board = charge13_fixture()
    board[1][0].keywords.append(Keyword::aircraft)
    if charge_source_valid(board, unit_id(1), true) or charge_target_valid(board, unit_id(0), unit_id(1), 12, ChargeKind::ordinary):
        return false
    let path : ModelPath
    path.model = 0
    if !charge_waypoint_valid(board, board[0], path, board_position(14, 5), 12, false):
        return false
    board[0][0].keywords.append(Keyword::fly)
    return charge_target_valid(board, unit_id(0), unit_id(1), 12, ChargeKind::ordinary)

# p.36 / appendix 02.02.01 storage: reject out-of-domain charge modifiers
# atomically rather than accepting corrupt bounded fields in a saved game.
fun test_charge13_malformed_modifier_rejected() -> Bool:
    let state = play()
    let board = charge13_fixture()
    state.board.units.append(board[0])
    state.board.identify_unit(state.board[0])
    state.board[0].phase_modifiers.charge_roll.append(rule_modifier(ModifierOperation::add, 1))
    state.board[0].phase_modifiers.charge_roll[0].amount.value = MAX_RULE_MODIFIER
    let serialized = to_string(state)
    let restored = play()
    return !set_state(restored, serialized)

# pp.38–42 fixture: two single live models, friendly at (5,5), enemy at
# (8,5), with 1.74-inch base separation and neutral core faction fixtures.
fun fight14_fixture() -> Board:
    let board = charge13_fixture()
    board[1][0].position.x = 8
    board.begin_phase(BattlePhase::fight)
    return board


# Shared fixture activation misses all three ordinary melee attacks. It
# traverses declarations/grouping without manufacturing target damage.
fun fight14_miss_attacks(Attack sequence, Board board, UnitID source, UnitID target):
    sequence.select_weapon(board, attack_test_slot(2))
    sequence.skip(board)
    sequence.declare_target(board, source, target)
    sequence.assign_attacks(board, attack_test_share(3))
    sequence.choose_attack_target(board, target)
    sequence.no_defensive_stratagem(board)
    sequence.no_offensive_stratagem(board)
    sequence.choose_attack_weapon(board, attack_test_weapon(0))
    for i in range(3):
        sequence.roll(board, attack_test_die(1))
    if can sequence.keep_batch(board):
        sequence.keep_batch(board)


# Supplied Fight on Death: source exception permits retained melee weapons
# and targets with the unit, and unit stratagem effects apply to them too.
fun test_fight14_retained_attack_exception_and_stratagem() -> Bool:
    let board = fight14_fixture()
    board[0][0].suffered_wounds = board[0][0].profile.wounds()
    board[0][0].state = ModelState::fight_on_death
    board[0][0].destruction_pending = true
    board[0][0].destruction_fight_roll = 1
    let sequence = attack(board, unit_id(0), unit_id(1), true, false)
    if !(can sequence.select_weapon(board, attack_test_slot(2))):
        return false
    sequence.select_weapon(board, attack_test_slot(2))
    sequence.skip(board)
    sequence.declare_target(board, unit_id(0), unit_id(1))
    sequence.assign_attacks(board, attack_test_share(3))
    sequence.choose_attack_target(board, unit_id(1))
    return board.allow_destroyed_attack and (can sequence.no_defensive_stratagem(board)) and board.can_target_strat(false, Stratagem::reroll, board[0])


# Supplied Fight on Death: phase-end fallback releases delayed triggers,
# resolves their model choice, then removes/archives each corpse exactly once.
fun test_fight14_phase_end_retained_cleanup() -> Bool:
    let board = fight14_fixture()
    board.attack_info.fight_on_death_roll = 1
    let job = damage_job(DamageKind::normal, unit_id(0), unit_id(1), true, true, 2, board[0][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 2, true)
    let cleanup = cleanup_phase_retained(board)
    cleanup.choose_destruction_unit(board, unit_id(0))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    return cleanup.is_done() and board[0].models.empty() and board[0].destroyed_models.value.size() == 1 and !board.allow_destroyed_attack


# Supplied Fight on Death / p.87: other death triggers remain pending too;
# Deadly Demise rolls only after the unit attacks or phase-end release.
fun test_fight14_retained_demise_trigger_delayed() -> Bool:
    let board = fight14_fixture()
    board[0][0].has_deadly_demise = true
    board[0][0].deadly_demise = raw_stat(1)
    board.attack_info.fight_on_death_roll = 1
    let job = damage_job(DamageKind::normal, unit_id(0), unit_id(1), true, true, 2, board[0][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 2, true)
    let jobs : DamageJobs
    let enemy_end = resolve_damage_jobs(board, jobs, true, unit_id(1))
    if !enemy_end.is_done():
        return false
    let cleanup = cleanup_phase_retained(board)
    cleanup.choose_destruction_unit(board, unit_id(0))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    if !(can cleanup.roll(board, attack_test_die(1))):
        return false
    cleanup.roll(board, attack_test_die(1))
    return cleanup.is_done() and board[0].models.empty()


# Supplied Fight on Death: failed legacy permission rolls skip corpse weapon
# selection but still release and archive it after the unit's activation.
fun test_fight14_failed_legacy_grant_still_cleans_up() -> Bool:
    let board = fight14_fixture()
    board.attack_info.fight_on_death_roll = 4
    let job = damage_job(DamageKind::normal, unit_id(0), unit_id(1), true, true, 2, board[0][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 2, true)
    let sequence = attack(board, unit_id(0), unit_id(1), true, false)
    sequence.roll(board, attack_test_die(1))
    sequence.choose_destruction_unit(board, unit_id(0))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    return sequence.is_done() and board[0].models.empty() and board[0].destroyed_models.value.size() == 1 and !board.allow_destroyed_attack


# Supplied Fight on Death: retained models use the full declaration/group
# pipeline, then their own destruction effects run and they are archived once.
fun test_fight14_retained_model_attacks_with_unit_then_removed() -> Bool:
    let board = fight14_fixture()
    board.attack_info.fight_on_death_roll = 1
    let job = damage_job(DamageKind::normal, unit_id(0), unit_id(1), true, true, 2, board[0][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 2, true)
    let sequence = attack(board, unit_id(0), unit_id(1), true, false)
    fight14_miss_attacks(sequence, board, unit_id(0), unit_id(1))
    if board[0].models.size() != 1 or !board[0][0].destruction_released:
        return false
    sequence.choose_destruction_unit(board, unit_id(0))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    return sequence.is_done() and board[0].models.empty() and board[0].destroyed_models.value.size() == 1 and !board.allow_destroyed_attack and board[1][0].suffered_wounds == 0
