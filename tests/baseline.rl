import full_game

# ANTI grants in the temporary attack list must obey their source exclusion,
# just as selected/intrinsic instances do (p.79; appendix02.05.01).
# Appendix02.02.01: modifications are cumulative, ordered and bearer-scoped.
# Fixed weapon consumers: appendix02.02.01, targeting p.16, grouping p.17,
# wound/hit p.18, saves p.19. Fixtures do not grant new Orks abilities.
fun orks17c2b_info(Board board, Int slot) -> AttackSequenceInfo:
    let declaration = make_declared_weapon(board, unit_id(0), 0, slot)
    return declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)

# A weapon-specific increment affects its slot, not its neighbour or other bearer.
fun test_orks17c2b_strength_slot_and_bearer_scope() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.append(equipped_weapon(Weapon::librarian_storm_bolter))
    board[0][0].characteristic_modifiers.append(weapon_characteristic_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 3, 0))
    let first = orks17c2b_info(board, 0)
    let second = orks17c2b_info(board, 1)
    return first.attack_strength() == 7 and second.attack_strength() == 4 and first.target_toughness.value == 4

# Bearer BS affects all ranged profiles; WS applies to melee instead (02.02.01).
fun test_orks17c2b_all_weapon_skills_and_melee_scope() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.append(equipped_weapon(Weapon::librarian_storm_bolter))
    board[0][0].weapons.append(equipped_weapon(Weapon::close_combat_weapon))
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::ballistic_skill, ModifierOperation::add, 1))
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::weapon_skill, ModifierOperation::subtract, 1))
    let first = orks17c2b_info(board, 0)
    let second = orks17c2b_info(board, 1)
    let melee = orks17c2b_info(board, 2)
    return effective_attack_skill(board, first) == 3 and effective_attack_skill(board, second) == 4 and effective_attack_skill(board, melee) == 2

# Cover's BS increment is before division and final rounding, not added later.
fun test_orks17c2b_cover_uses_modifier_operation_order() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::slugga
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::ballistic_skill, ModifierOperation::divide, 2))
    board.attack_info.target_has_cover = true
    let info = orks17c2b_info(board, 0)
    return effective_attack_skill(board, info) == 3

# A later chosen Ignores Cover still cancels the core increment before arithmetic.
fun test_orks17c2b_late_ignore_cover_recomputes_skill() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::cultist_bolt_pistol
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::ballistic_skill, ModifierOperation::divide, 2))
    board.attack_info.target_has_cover = true
    let info = orks17c2b_info(board, 0)
    if effective_attack_skill(board, info) != 3:
        return false
    info.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::ignore_cover))
    return effective_attack_skill(board, info) == 2

# Effective S changes both the wound table and the greater-S protection gate.
fun test_orks17c2b_strength_drives_wound_threshold() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 5))
    board[1][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 4))
    let info = orks17c2b_info(board, 0)
    if required_wound_roll(board, info) != 3:
        return false
    info.greater_strenght_wound_protection = true
    return required_wound_roll(board, info) == 4

# Effective AP participates in the actual save predicate (p.19).
fun test_orks17c2b_armour_penetration_changes_save() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::armour_penetration, ModifierOperation::subtract, 1))
    let info = orks17c2b_info(board, 0)
    let group : AllocationGroup
    group.save = 3
    group.invulnerable = 10
    let face : Dice
    face = 3
    return info.attack_penetration() == -1 and !attack_save_succeeds(group, face, info.attack_penetration()) and attack_save_succeeds(group, face, 0)

# Legacy explicit AP increments obey the same order; do not subtract after rounding.
fun test_orks17c2b_ap_increment_precedes_division() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::plasma_pistol_standard
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::armour_penetration, ModifierOperation::divide, 2))
    let info = orks17c2b_info(board, 0)
    info.penetration_bonus = true
    return info.attack_penetration() == -1

# Zero replacements lock core increments, and worsened AP never becomes positive.
fun test_orks17c2b_ap_zero_lock_and_worsening_limit() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::armour_penetration, ModifierOperation::add, 20))
    let worsened = orks17c2b_info(board, 0)
    if worsened.attack_penetration() != 0:
        return false
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::armour_penetration, ModifierOperation::replace, 0))
    let locked = orks17c2b_info(board, 0)
    locked.penetration_bonus = true
    return locked.attack_penetration() == 0

# Different raw BS profiles may group when their effective characteristics agree.
fun test_orks17c2b_group_identity_uses_effective_skill() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.append(equipped_weapon(Weapon::librarian_storm_bolter))
    board[0][0].characteristic_modifiers.append(weapon_characteristic_modifier(ModifiedCharacteristic::ballistic_skill, ModifierOperation::subtract, 1, 1))
    let left = orks17c2b_info(board, 0)
    let right = orks17c2b_info(board, 1)
    if !attacks_are_identical(board, left, right):
        return false
    # Same effective AP from different records must still group (p.17).
    left.penetration_bonus = true
    right.ap_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    return attacks_are_identical(board, left, right)

# Same raw profile with different effective S must resolve as separate groups.
fun test_orks17c2b_group_identity_splits_effective_strength() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.append(equipped_weapon(Weapon::captain_storm_bolter))
    board[0][0].characteristic_modifiers.append(weapon_characteristic_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 1, 1))
    let left = orks17c2b_info(board, 0)
    let right = orks17c2b_info(board, 1)
    return !attacks_are_identical(board, left, right)

# Current T for a new group replaces the enclosing target's stale initial snapshot.
fun test_orks17c2b_target_toughness_refresh_after_casualty() -> Bool:
    let board = damage_test_fixture()
    board[1][1].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 4))
    configure_attack_info(board, 0, 1, false, false)
    let first = orks17c2b_info(board, 0)
    board[1].remove_model(1)
    let next = orks17c2b_info(board, 0)
    return first.target_toughness.value == 8 and next.target_toughness.value == 4 and board.attack_info.target_toughness.value == 8

# Newly active target arithmetic also affects subsequent groups (02.02.01/05.02.01).
fun test_orks17c2b_target_toughness_refresh_after_modifier() -> Bool:
    let board = attack_declaration_fixture()
    configure_attack_info(board, 0, 1, false, false)
    board[1][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 2))
    let next = orks17c2b_info(board, 0)
    return next.target_toughness.value == 6 and board.attack_info.target_toughness.value == 4

# The new group's explicit identities control target-dependent rules, even
# when a neutral/stale enclosing context was supplied (pp.17/79;02.05.01).
fun test_orks17c2b_group_identity_refreshes_target_keyword_subject() -> Bool:
    let board = attack_declaration_fixture()
    board[1][0].keywords.append(Keyword::monster)
    board[2].owned_by_player1 = false
    board[2][0].position = board_position(5, 10)
    let declaration = make_declared_weapon(board, unit_id(2), 0, 0)
    declaration.current_target_rules.append(conditional_weapon_rule(WeaponRuleKind::anti_monster, 3, Keyword::monster))
    let neutral : AttackSequenceInfo
    let info = declared_attack_info(board, unit_id(2), unit_id(1), declaration, neutral)
    return info.source_unit_id.get() == 2 and info.target_unit_id.get() == 1 and critical_wound_threshold(board, info) == 3

# Actual target legality and replacement eligibility use effective Range (p.16/04.03.03).
fun test_orks17c2b_effective_range_changes_target_legality() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::bolt_pistol
    board[1][0].position = board_position(25, 5)
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    if declaration_target_valid(board, unit_id(0), declaration, unit_id(1), false):
        return false
    board[0][0].characteristic_modifiers.append(weapon_characteristic_modifier(ModifiedCharacteristic::range, ModifierOperation::add, 10, 0))
    return declaration_target_valid(board, unit_id(0), declaration, unit_id(1), false)

# Rapid Fire/Melta half-range is measured from the effective declaration Range.
fun test_orks17c2b_half_range_snapshot_uses_effective_range() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::bolt_pistol
    board[1][0].position = board_position(16, 5)
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    snapshot_weapon_target(board, unit_id(0), declaration, unit_id(1))
    if declaration.half_range[1]:
        return false
    board[0][0].characteristic_modifiers.append(weapon_characteristic_modifier(ModifiedCharacteristic::range, ModifierOperation::multiply, 2, 0))
    snapshot_weapon_target(board, unit_id(0), declaration, unit_id(1))
    return declaration.half_range[1]

# 'Melee' Range and '-' Torrent skill remain special, regardless of arithmetic.
fun test_orks17c2b_special_melee_range_and_torrent_skill() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::close_combat_weapon
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::range, ModifierOperation::add, 20))
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    if declaration_weapon_range(board, unit_id(0), declaration) != 0:
        return false
    board[0][0].weapons[0].profile = Weapon::pyreblaster
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::ballistic_skill, ModifierOperation::add, 3))
    let info = orks17c2b_info(board, 0)
    return effective_attack_skill(board, info) == 0

# Firing Deck uses carrier-wide modifiers, never its unrelated equipped slot grant.
fun test_orks17c2b_borrowed_weapon_modifier_scope() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 1))
    board[0][0].characteristic_modifiers.append(weapon_characteristic_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 5, 0))
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let own = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    declaration.borrowed_weapon = true
    let borrowed = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    return own.attack_strength() == 10 and borrowed.attack_strength() == 5

# Invalid scope/kind and nonexistent equipped slots cannot survive saved roots.
fun test_orks17c2b_invalid_weapon_modifier_scope_rejected() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].characteristic_modifiers.append(weapon_characteristic_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 1, 7))
    if valid_state_foundations(board):
        return false
    board[0][0].characteristic_modifiers.clear()
    let malformed = characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 1)
    malformed.weapon_scope = 1
    board[0][0].characteristic_modifiers.append(malformed)
    return !valid_state_foundations(board)

# Stored skill/AP operations need the same invalid-divisor checks before restore.
fun test_orks17c2b_invalid_attack_snapshot_modifiers_rejected() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.skill_modifiers.append(rule_modifier(ModifierOperation::divide, 0))
    if valid_state_foundations(board):
        return false
    board.attack_info.skill_modifiers.clear()
    board.attack_info.ap_modifiers.append(rule_modifier(ModifierOperation::divide, -1))
    return !valid_state_foundations(board)

# Real Game serialization preserves scoped data and gathered bounded S/operations.
fun test_orks17c2b_saved_weapon_characteristics_round_trip() -> Bool:
    let state = play()
    state.board = attack_declaration_fixture()
    state.board[0][0].characteristic_modifiers.append(weapon_characteristic_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, 0))
    state.board.attack_info = orks17c2b_info(state.board, 0)
    let restored = play()
    return set_state(restored, to_string(state)) and restored.board.attack_info.attack_strength() == 6 and restored.board[0][0].characteristic_modifiers[0].weapon_scope.value == 1

fun test_orks17c2_model_modifier_order_and_scope() -> Bool:
    let unit = make_infernus_squad()
    ref model = unit[0]
    model.characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::subtract, 1))
    model.characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::divide, 2))
    model.characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 1))
    model.characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::multiply, 2))
    model.characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::replace, 7))
    model.characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::save, ModifierOperation::add, 1))
    return model.effective_toughness() == 7 and unit[1].effective_toughness() == 4 and model.effective_save() == 4

# Appendix05.02.01: strongest T can occur after the first model and can change.
fun test_orks17c2_mixed_toughness_highest_and_casualty() -> Bool:
    let unit = make_infernus_squad()
    unit[1].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 3))
    if unit.get_unit_toughtness() != 7:
        return false
    unit.remove_model(1)
    return unit.get_unit_toughtness() == 4

# Offboard models do not provide T; Fight on Death models remain on the
# battlefield and in their unit until removal (05.02.01/supplied Fight on Death).
fun test_orks17c2_toughness_ignores_unavailable_models() -> Bool:
    let unit = make_infernus_squad()
    unit[1].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 20))
    unit[1].off_battlefield = true
    if unit.get_unit_toughtness() != 4:
        return false
    unit[1].off_battlefield = false
    unit[1].suffered_wounds = unit[1].profile.wounds()
    unit[1].state = ModelState::fight_on_death
    if unit.get_unit_toughtness() != 24:
        return false
    unit.remove_model(1)
    return unit.get_unit_toughtness() == 4

# Real attack preparation reads the mixed effective T, not static enum data (p.18).
fun test_orks17c2_attack_snapshots_effective_toughness() -> Bool:
    let board = damage_test_fixture()
    board[1][1].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 4))
    configure_attack_info(board, 0, 1, false, false)
    return board.attack_info.target_toughness.value == 8

# M modifiers apply to the determined random M, before Advance extras (02.02.03/p.33).
fun test_orks17c2_movement_fixed_and_random_budget() -> Bool:
    let unit = make_infernus_squad()
    unit[0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 2))
    unit[0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::subtract, 1))
    return model_move_budget(unit[0], MovementKind::normal, 3, 0, false) == 10 and model_move_budget(unit[0], MovementKind::normal, 3, 5, false) == 8 and model_move_budget(unit[0], MovementKind::scout, 4, 0, false) == 4

# Replacement zero locks further arithmetic, including characteristic minima (02.02.01).
fun test_orks17c2_zero_replacement_locks_model_characteristic() -> Bool:
    let unit = make_infernus_squad()
    unit[0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::replace, 0))
    unit[0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 9))
    return model_move_budget(unit[0], MovementKind::normal, 0, 0, false) == 0

# p.19: per-model modified Sv splits otherwise identical allocation groups.
fun test_orks17c2_save_group_effective_characteristics() -> Bool:
    let board = damage_test_fixture()
    board[1][1].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::save, ModifierOperation::subtract, 1))
    let groups = make_allocation_groups(board, board[1], board.attack_info)
    let face : Dice
    face = 2
    return groups.size() == 2 and groups[0].save.value == 3 and groups[1].save.value == 2 and !attack_save_succeeds(groups[0], face, 0) and attack_save_succeeds(groups[1], face, 0)

# '-' InSv cannot acquire a save by arithmetic; valid InSv is bounded at2+ (02.02.01).
fun test_orks17c2_invulnerable_special_and_floor() -> Bool:
    let unit = make_infernus_squad()
    unit[0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::invulnerable_save, ModifierOperation::subtract, 9))
    let captain = make_octavius()
    captain[0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::invulnerable_save, ModifierOperation::subtract, 9))
    return unit[0].effective_invulnerable_save() == unit[0].profile.invuln_save() and captain[0].effective_invulnerable_save() == 2

# Leadership takes the best modified bearer value, within5+..8+ (p.9/02.02.01).
fun test_orks17c2_leadership_effective_limits() -> Bool:
    let unit = make_infernus_squad()
    for i in range(unit.models.size()):
        unit[i].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::leadership, ModifierOperation::add, 9))
    if unit.get_leadership() != 8:
        return false
    unit[1].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::leadership, ModifierOperation::subtract, 20))
    return unit.get_leadership() == 5 and unit.leadership_roll_succeeds(5) and !unit.leadership_roll_succeeds(4)

# OC bonuses are bearer-scoped; Battle-shock's '-' defeats all of them (p.9).
fun test_orks17c2_objective_control_scope_and_shock() -> Bool:
    let unit = make_infernus_squad()
    unit[0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::objective_control, ModifierOperation::add, 3))
    if unit.model_objective_control(0) != 4 or unit.model_objective_control(1) != 1:
        return false
    unit.battle_socked = true
    return unit.model_objective_control(0) == 0 and unit.model_objective_control(1) == 0

# Save roots/archives reject invalid divisors before arithmetic (02.02.01 infrastructure).
fun test_orks17c2_invalid_modifier_metadata_rejected() -> Bool:
    let board = damage_test_fixture()
    board[1][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::save, ModifierOperation::divide, 0))
    if valid_state_foundations(board):
        return false
    board[1].remove_model(0)
    return !valid_state_foundations(board)

# Persisted modifiers survive the real atomic Game snapshot restore (02.02.01).
fun test_orks17c2_modifier_saved_state_round_trip() -> Bool:
    let state = play()
    state.board.units.append(make_infernus_squad())
    state.board.identify_units()
    state.board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 2))
    let restored = play()
    return set_state(restored, to_string(state)) and restored.board[0].get_unit_toughtness() == 6

fun test_orks17c_temporary_anti_obeys_exclusion() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    board[1][0].keywords.append(Keyword::monster)
    let info = board.attack_info
    info.temporary_weapon_abilities.append(conditional_weapon_rule(WeaponRuleKind::anti_monster, 3, orks17c_combined_predicate()))
    if critical_wound_threshold(board, info) != 3:
        return false
    board[1][0].keywords.append(Keyword::titanic)
    return critical_wound_threshold(board, info) == 6

# A matching ANTI family cannot override a missing ALL keyword. Keep VEHICLE
# present to prove this is the condition gate, not the family gate (p.79).
fun test_orks17c_temporary_anti_requires_all_keywords() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate : KeywordPredicate
    assert(append_keyword_condition(predicate, KeywordClause::all, Keyword::character), "fixture condition")
    let info = board.attack_info
    info.temporary_weapon_abilities.append(conditional_weapon_rule(WeaponRuleKind::anti_vehichle, 3, predicate))
    if critical_wound_threshold(board, info) != 3:
        return false
    board[1][1].keywords.clear()
    board[1][1].keywords.append(Keyword::vehicle)
    return critical_wound_threshold(board, info) == 6


# Clause groups must remain correct when datasheet fields are loaded in any
# order; inserting ALL before existing ANY/NONE terms must not change meaning.
fun test_orks17c_keyword_group_insertion_order() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate : KeywordPredicate
    assert(append_keyword_condition(predicate, KeywordClause::none, Keyword::titanic), "fixture condition")
    assert(append_keyword_condition(predicate, KeywordClause::any, Keyword::vehicle), "fixture condition")
    assert(append_keyword_condition(predicate, KeywordClause::all, Keyword::infantry), "fixture condition")
    assert(append_keyword_condition(predicate, KeywordClause::any, Keyword::monster), "fixture condition")
    let rule = conditional_weapon_rule(WeaponRuleKind::sustained_hit, 2, predicate)
    return unit_matches_keywords(board[1], predicate) and predicate.size() == 4 and predicate.required_count.value == 1 and predicate.alternative_count.value == 2 and predicate.excluded_count.value == 1 and weapon_ability_condition_keyword(rule, 0) == Keyword::infantry and weapon_ability_condition_clause(rule, 1) == KeywordClause::any and weapon_ability_condition_keyword(rule, 3) == Keyword::titanic

# Each scalar count can be individually in bounds while their sum exceeds the
# fixed array. Saved metadata must reject this before lookup/editor rendering.
fun test_orks17c_keyword_group_total_rejects_invalid_save() -> Bool:
    let state = play()
    state.board = orks17c_mixed_keyword_fixture()
    state.board.pending_weapon_abilities.append(conditional_weapon_rule(WeaponRuleKind::sustained_hit, 2, orks17c_combined_predicate()))
    let before = to_string(state)
    let corrupt = state
    corrupt.board.pending_weapon_abilities[0].target_condition.required_count = 4
    corrupt.board.pending_weapon_abilities[0].target_condition.alternative_count = 4
    corrupt.board.pending_weapon_abilities[0].target_condition.excluded_count = 4
    return !unit_matches_keywords(corrupt.board[1], corrupt.board.pending_weapon_abilities[0].target_condition) and !set_state(state, to_string(corrupt)) and to_string(state) == before


# Appendix02.05.01, https://wahapedia.ru/wh40k11ed/the-rules/rules-appendix/:
# an explicit fixture isolates keyword logic from old faction data.
fun orks17c_mixed_keyword_fixture() -> Board:
    let board = shooting12_fixture()
    board[1].models.resize(2)
    board[1][0].keywords.clear()
    board[1][1].keywords.clear()
    board[1][0].keywords.append(Keyword::infantry)
    board[1][1].keywords.append(Keyword::character)
    board[1][1].keywords.append(Keyword::vehicle)
    return board

# Adjacent INFANTRY plus slash MONSTER/VEHICLE excluding TITANIC: the source
# list means ALL AND ANY AND NONE, not a positive OR across every term.
fun orks17c_combined_predicate() -> KeywordPredicate:
    let predicate : KeywordPredicate
    assert(append_keyword_condition(predicate, KeywordClause::all, Keyword::infantry), "fixture condition")
    assert(append_keyword_condition(predicate, KeywordClause::any, Keyword::monster), "fixture condition")
    assert(append_keyword_condition(predicate, KeywordClause::any, Keyword::vehicle), "fixture condition")
    assert(append_keyword_condition(predicate, KeywordClause::none, Keyword::titanic), "fixture condition")
    return predicate

# Empty conditions do not add an artificial keyword requirement (p.78).
fun test_orks17c_empty_keyword_condition() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate : KeywordPredicate
    return unit_matches_keywords(board[1], predicate) and model_matches_keywords(board[1][0], predicate)

# Appendix02.05.01: different models can supply adjacent UNIT keywords;
# neither individual MODEL inherits a keyword from the other bearer.
fun test_orks17c_all_keywords_unit_union_and_model_scope() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate : KeywordPredicate
    assert(append_keyword_condition(predicate, KeywordClause::all, Keyword::infantry), "fixture condition")
    assert(append_keyword_condition(predicate, KeywordClause::all, Keyword::character), "fixture condition")
    return unit_matches_keywords(board[1], predicate) and !model_matches_keywords(board[1][0], predicate) and !model_matches_keywords(board[1][1], predicate)

# Appendix02.05.01: slashes/or mean any one listed keyword.
fun test_orks17c_any_keyword_alternatives() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate : KeywordPredicate
    assert(append_keyword_condition(predicate, KeywordClause::any, Keyword::monster), "fixture condition")
    assert(append_keyword_condition(predicate, KeywordClause::any, Keyword::vehicle), "fixture condition")
    return unit_matches_keywords(board[1], predicate) and !model_matches_keywords(board[1][0], predicate) and model_matches_keywords(board[1][1], predicate)

# Appendix02.05.01: one VEHICLE bearer excludes the entire non-VEHICLE unit,
# but does not turn the other individual model into a VEHICLE model.
fun test_orks17c_none_keywords_mixed_unit_exclusion() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate : KeywordPredicate
    assert(append_keyword_condition(predicate, KeywordClause::none, Keyword::vehicle), "fixture condition")
    return !unit_matches_keywords(board[1], predicate) and model_matches_keywords(board[1][0], predicate) and !model_matches_keywords(board[1][1], predicate)

# Combine ALL/ANY/NONE as conjunctions of clauses (appendix02.05.01).
fun test_orks17c_combined_keyword_clauses() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate = orks17c_combined_predicate()
    if !unit_matches_keywords(board[1], predicate) or model_matches_keywords(board[1][0], predicate):
        return false
    board[1][0].keywords.append(Keyword::titanic)
    return !unit_matches_keywords(board[1], predicate)

# Adjacent required keywords must not be weakened by a matching ANY clause.
fun test_orks17c_any_does_not_override_missing_all() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate = orks17c_combined_predicate()
    board[1][0].keywords.clear()
    return !unit_matches_keywords(board[1], predicate)

# ALL X plus NONE X is a contradiction, not an implicit exception.
fun test_orks17c_contradictory_keyword_condition() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate : KeywordPredicate
    assert(append_keyword_condition(predicate, KeywordClause::all, Keyword::infantry), "fixture condition")
    assert(append_keyword_condition(predicate, KeywordClause::none, Keyword::infantry), "fixture condition")
    return !unit_matches_keywords(board[1], predicate) and !model_matches_keywords(board[1][0], predicate)

# Duplicate identical metadata terms must not consume finite storage.
fun test_orks17c_duplicate_condition_is_idempotent() -> Bool:
    let predicate : KeywordPredicate
    if !append_keyword_condition(predicate, KeywordClause::all, Keyword::infantry):
        return false
    let before = to_string(predicate)
    return append_keyword_condition(predicate, KeywordClause::all, Keyword::infantry) and to_string(predicate) == before

# Preserve the old nine-keyword capacity; overflow is explicit and atomic.
fun test_orks17c_keyword_condition_capacity() -> Bool:
    let predicate : KeywordPredicate
    let keyword : Keyword
    for index in range(MAX_KEYWORD_TERMS):
        keyword.value = index
        if !append_keyword_condition(predicate, KeywordClause::any, keyword):
            return false
    if !append_keyword_condition(predicate, KeywordClause::any, keyword):
        return false
    let before = to_string(predicate)
    keyword.value = MAX_KEYWORD_TERMS
    return !append_keyword_condition(predicate, KeywordClause::any, keyword) and to_string(predicate) == before and predicate.size() == MAX_KEYWORD_TERMS

# Unknown numeric keywords cannot make a non-keyword condition accidentally
# true; malformed clause/count inputs are rejected before array indexing.
fun test_orks17c_invalid_condition_inputs_are_atomic() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate : KeywordPredicate
    let invalid : Keyword
    invalid.value = -1
    if append_keyword_condition(predicate, KeywordClause::none, invalid):
        return false
    invalid.value = 127
    if append_keyword_condition(predicate, KeywordClause::none, invalid):
        return false
    let clause : KeywordClause
    clause.value = 3
    return !append_keyword_condition(predicate, clause, Keyword::infantry) and predicate.size() == 0 and unit_matches_keywords(board[1], predicate)

# Raw field corruption is recoverable and cannot cause an unsafe lookup.
fun test_orks17c_invalid_condition_queries_fail_closed() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate = orks17c_combined_predicate()
    predicate.keywords[3].value = 127
    if unit_matches_keywords(board[1], predicate):
        return false
    predicate = orks17c_combined_predicate()
    predicate.required_count.value = -1
    if model_matches_keywords(board[1][0], predicate):
        return false
    predicate.required_count.value = 10
    return !unit_matches_keywords(board[1], predicate)

# Existing slash metadata constructors retain their ANY meaning (p.78).
fun test_orks17c_legacy_or_constructor_preserves_semantics() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let rule = conditional_weapon_rule(WeaponRuleKind::sustained_hit, 2, Keyword::monster, Keyword::vehicle)
    return board[1].weapon_rule_applies(rule) and rule.target_condition.size() == 2 and weapon_ability_condition_clause(rule, 0) == KeywordClause::any

# p.78: applicability gates both presence and magnitude of the selected rule.
fun test_orks17c_selected_weapon_condition_presence_and_parameter() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let rules : WeaponAbilitySet
    rules.append(conditional_weapon_rule(WeaponRuleKind::sustained_hit, 2, orks17c_combined_predicate()))
    if !chosen_weapon_has_rule(board, unit_id(1), rules, WeaponRuleKind::sustained_hit) or chosen_weapon_parameter(board, unit_id(1), rules, WeaponRuleKind::sustained_hit) != 2:
        return false
    board[1][0].keywords.append(Keyword::titanic)
    return !chosen_weapon_has_rule(board, unit_id(1), rules, WeaponRuleKind::sustained_hit) and chosen_weapon_parameter(board, unit_id(1), rules, WeaponRuleKind::sustained_hit) == 0

# ANTI's unmodified threshold also honours the whole condition (p.79).
fun test_orks17c_anti_uses_conjunctive_target_condition() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let info = board.attack_info
    info.weapon_rules_known = true
    info.selected_weapon_rules.append(conditional_weapon_rule(WeaponRuleKind::anti, 3, orks17c_combined_predicate()))
    if critical_wound_threshold(board, info) != 3:
        return false
    board[1][1].keywords.append(Keyword::titanic)
    return critical_wound_threshold(board, info) == 6

# Hunter profiles use the same unit condition at declaration/revalidation
# (appendix04.01.03/04.03.03), rather than accepting any one positive keyword.
fun test_orks17c_hunter_all_any_none_targeting() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    board[0][0].hunter_profile_conditions[0] = conditional_weapon_rule(WeaponRuleKind::anti, 0, orks17c_combined_predicate())
    let weapon = make_declared_weapon(board, unit_id(0), 0, 0)
    if !declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false):
        return false
    board[1][0].keywords.append(Keyword::titanic)
    return !declaration_target_valid(board, unit_id(0), weapon, unit_id(1), false)

# Keyword-union conditions change when a bearer actually leaves the unit
# (appendix02.05.01; destruction p.87), not when another model is inspected.
fun test_orks17c_keyword_union_after_casualty_removal() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let predicate = orks17c_combined_predicate()
    if !unit_matches_keywords(board[1], predicate):
        return false
    board[1].remove_model(1)
    return !unit_matches_keywords(board[1], predicate)

# Duplicate selection copies the selected source condition through save/restore
# and does not merge a different duplicate's restriction (p.78).
fun test_orks17c_pending_ability_choice_condition_round_trip() -> Bool:
    let board = orks17c_mixed_keyword_fixture()
    let rules : WeaponAbilitySet
    rules.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    rules.append(conditional_weapon_rule(WeaponRuleKind::sustained_hit, 2, orks17c_combined_predicate()))
    let pending = choose_weapon_abilities(board, rules)
    let restored = choose_weapon_abilities(board, rules)
    if !from_string(restored, to_string(pending)):
        return false
    let selected : WeaponAbilityChoice
    selected = 1
    restored.choose_weapon_ability(board, selected)
    return restored.is_done() and restored.chosen.size() == 1 and restored.chosen[0].target_condition.size() == 4 and chosen_weapon_parameter(board, unit_id(1), restored.chosen, WeaponRuleKind::sustained_hit) == 2

# Save infrastructure preserves model grants, Hunter filters and chosen/pending
# attack metadata (p.78; appendix02.05.01), with atomic rejection on corruption.
fun test_orks17c_condition_save_and_invalid_metadata_rejection() -> Bool:
    let state = play()
    state.board = orks17c_mixed_keyword_fixture()
    let rule = conditional_weapon_rule(WeaponRuleKind::sustained_hit, 2, orks17c_combined_predicate())
    state.board[0][0].additional_weapon_rules[0].append(rule)
    state.board[0][0].hunter_profile_conditions[0] = rule
    state.board.pending_weapon_abilities.append(rule)
    state.board.attack_info.selected_weapon_rules.append(rule)
    let restored = play()
    if !set_state(restored, to_string(state)) or !restored.board[1].weapon_rule_applies(restored.board[0][0].additional_weapon_rules[0][0]):
        return false
    let before = to_string(restored)
    let corrupt = state
    corrupt.board.pending_weapon_abilities[0].target_condition.keywords[0].value = 127
    return !set_state(restored, to_string(corrupt)) and to_string(restored) == before

# Archived metadata must remain valid for later lifecycle consumers (p.88).
fun test_orks17c_archived_hunter_condition_rejects_corruption() -> Bool:
    let state = play()
    state.board = orks17c_mixed_keyword_fixture()
    state.board[0][0].hunter_profile_conditions[0] = conditional_weapon_rule(WeaponRuleKind::anti, 0, orks17c_combined_predicate())
    state.board[0].remove_model(0)
    state.board[0].destroyed_models.value[0].hunter_profile_conditions[0].target_condition.keywords[0].value = 127
    return !valid_state_foundations(state.board)


# User point-free/three-detachment scope; Orks faction source and core p.8.
fun test_orks17b_roster_identities_and_armies() -> Bool:
    let chaos : UnitVector
    let orks : UnitVector
    let chaos_roster = make_zarkan_deamonkin(chaos, false)
    let ork_roster = make_orks_starter_roster(orks, true)
    return chaos_roster == Faction::zarkan_daemonkin and ork_roster == Faction::morgrim_butchas and army_faction_for_roster(chaos_roster) == ArmyFaction::chaos_space_marines and army_faction_for_roster(ork_roster) == ArmyFaction::orks and army_faction_for_roster(Faction::strike_force_octavius) == ArmyFaction::space_marines and army_faction_for_roster(Faction::vengeful_brethren) == ArmyFaction::space_marines and army_faction_for_roster(Faction::insidious_infiltrators) == ArmyFaction::tyranids and army_faction_for_roster(Faction::tristraen_gilded_blade) == ArmyFaction::adeptus_custodes

# Three distinct packages, even War Horde plus two others, use no DP budget.
fun test_orks17b_unique_three_package_bound() -> Bool:
    let army : ArmyConfiguration
    army.faction = ArmyFaction::orks
    if !army.record_detachment(OrksDetachment::war_horde) or army.record_detachment(OrksDetachment::war_horde) or army.record_detachment(OrksDetachment::none):
        return false
    if !army.record_detachment(OrksDetachment::da_big_hunt) or !army.record_detachment(OrksDetachment::green_tide):
        return false
    let before = to_string(army)
    return !army.record_detachment(OrksDetachment::bully_boyz) and to_string(army) == before and army.detachments.size() == 3 and army_configuration_valid(army)

# Non-Orks do not receive Orks choices; raw enum corruption must reject safely.
fun test_orks17b_non_orks_and_invalid_picks() -> Bool:
    let army : ArmyConfiguration
    army.faction = ArmyFaction::space_marines
    if army.record_detachment(OrksDetachment::war_horde):
        return false
    army.faction = ArmyFaction::orks
    let invalid : OrksDetachment
    invalid.value = -1
    if army.record_detachment(invalid):
        return false
    invalid.value = 16
    return !army.record_detachment(invalid) and army.detachments.empty()

# New configuration is independent of roster and the other player's picks.
fun test_orks17b_game_handoff_and_pending_selection_save() -> Bool:
    let state = play()
    state.pick_morgrim_butcha()
    state.choose_orks_detachment(OrksDetachment::war_horde)
    state.choose_orks_detachment(OrksDetachment::da_big_hunt)
    let restored = play()
    if !set_state(restored, to_string(state).to_indented_lines()) or get_current_player(restored) != 0 or can restored.choose_orks_detachment(OrksDetachment::war_horde):
        return false
    restored.choose_orks_detachment(OrksDetachment::green_tide)
    if can restored.finish_orks_options():
        restored.finish_orks_options()
    if get_current_player(restored) != 0 or !can restored.choose_warlord_unit(unit_id(0)):
        return false
    restored.choose_warlord_unit(unit_id(0))
    restored.choose_warlord_model(damage_test_model(0))
    if get_current_player(restored) != 1 or can restored.choose_orks_detachment(OrksDetachment::bully_boyz):
        return false
    restored.pick_morgrim_butcha()
    restored.choose_orks_detachment(OrksDetachment::bully_boyz)
    restored.finish_detachment_selection()
    if can restored.finish_orks_options():
        restored.finish_orks_options()
    restored.choose_warlord_unit(unit_id(4))
    restored.choose_warlord_model(damage_test_model(0))
    return restored.board.armies[0].detachments.size() == 3 and restored.board.armies[1].detachments.size() == 1 and restored.board.armies[0].reserve_budget == ReserveBudgetMode::point_free and restored.board.armies[1].reserve_budget == ReserveBudgetMode::point_free and valid_state_foundations(restored.board)

# Up to three permits finishing with zero or two; no fourth decision remains.
fun test_orks17b_optional_selection_zero_and_two() -> Bool:
    let board : Board
    board.armies[0].faction = ArmyFaction::orks
    board.armies[1].faction = ArmyFaction::orks
    let first = select_orks_detachments(board, false)
    first.finish_detachment_selection(board)
    let second = select_orks_detachments(board, true)
    second.choose_orks_detachment(board, OrksDetachment::war_horde)
    second.choose_orks_detachment(board, OrksDetachment::bully_boyz)
    second.finish_detachment_selection(board)
    return first.is_done() and second.is_done() and board.armies[0].detachments.empty() and board.armies[1].detachments.size() == 2 and board.current_decision_maker

# Serialized duplicates, wrong faction and invalid enum/mode values are not
# accepted as legal configuration (implementation invariant; source above).
fun test_orks17b_reject_malformed_configuration_save() -> Bool:
    let state = play()
    state.pick_morgrim_butcha()
    state.choose_orks_detachment(OrksDetachment::war_horde)
    let corrupt = state
    corrupt.board.armies[0].detachments.append(OrksDetachment::war_horde)
    if set_state(state, to_string(corrupt)):
        return false
    corrupt = state
    corrupt.board.armies[0].faction = ArmyFaction::tyranids
    if set_state(state, to_string(corrupt)):
        return false
    corrupt = state
    corrupt.board.armies[0].reserve_budget.value = 2
    return !set_state(state, to_string(corrupt)) and state.board.armies[0].detachments.size() == 1

# User point-free mode bypasses only the p.68 pricing cap, not ownership,
# repeated choice, Fortification exclusion or mandatory Aircraft reserves.
fun test_orks17b_point_free_reserve_permissions() -> Bool:
    let board : Board
    board.reserve_units.append(make_infernus_squad())
    board.identify_units()
    if strategic_reserve_valid(board, false, unit_id(0)):
        return false
    board.armies[0].reserve_budget = ReserveBudgetMode::point_free
    if !strategic_reserve_valid(board, false, unit_id(0)) or strategic_reserve_valid(board, true, unit_id(0)) or strategic_reserve_valid(board, false, unit_id(1)):
        return false
    board.reserve_units[0].history.strategic_reserve = true
    if strategic_reserve_valid(board, false, unit_id(0)):
        return false
    board.reserve_units[0].history.strategic_reserve = false
    board.reserve_units[0][0].keywords.append(Keyword::fortification)
    return !strategic_reserve_valid(board, false, unit_id(0))

# Unknown passenger prices cannot block an explicitly point-free carrier.
# Point-aware mode still rejects them; no passenger pricing is introduced.
fun test_orks17b_point_free_reserved_carrier_and_passengers() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    if !reposition_unit(board, unit_id(0)):
        return false
    board.reserve_units[0].history.strategic_reserve = false
    board.battle_points_limit = 100
    board.reserve_units[0].points_known = true
    board.reserve_units[0].points = 1
    if strategic_reserve_valid(board, false, unit_id(0)):
        return false
    board.armies[0].reserve_budget = ReserveBudgetMode::point_free
    return strategic_reserve_valid(board, false, unit_id(0))

# Source CP inventory: simultaneous selected packages share payer bookkeeping,
# but an unselected package grants no card (Orks cards; core p.54).
fun orks17b_cp_fixture() -> Board:
    let board = attack_fixture()
    board.identify_units()
    board.armies[0].faction = ArmyFaction::orks
    let horde = board.armies[0].record_detachment(OrksDetachment::war_horde)
    let swarm = board.armies[0].record_detachment(OrksDetachment::runt_swarm)
    let flyers = board.armies[0].record_detachment(OrksDetachment::flyboyz)
    board.command_points[0] = 5
    return board

fun test_orks17b_detachment_card_scope_and_base_cp() -> Bool:
    let board = orks17b_cp_fixture()
    if !board.can_use_strat(false, Stratagem::orks_hit_em_harder) or !board.can_use_strat(false, Stratagem::orks_infested_war_zone) or board.can_use_strat(false, Stratagem::orks_dakkastorm):
        return false
    board.command_points[0] = 1
    return Stratagem::orks_infested_war_zone.cost() == 2 and Stratagem::orks_hit_em_harder.cost() == 1 and !board.can_use_strat(false, Stratagem::orks_infested_war_zone) and board.can_use_strat(false, Stratagem::orks_hit_em_harder)

# Breakin' Heads overrides only shocked eligibility, preserving payment/use.
fun test_orks17b_shocked_exception_preserves_cost_and_limits() -> Bool:
    let board = orks17b_cp_fixture()
    board[0].battle_socked = true
    if board.can_target_strat(false, Stratagem::orks_hit_em_harder, board[0]) or !board.try_use_strat(false, Stratagem::orks_breakin_heads, board[0], 1):
        return false
    return board.command_points[0] == 4 and !board.can_target_strat(false, Stratagem::orks_breakin_heads, board[1]) and !board.can_target_strat(false, Stratagem::insane_bravery, board[0])

# The exception does not permit an unaffordable use or a foreign Orks target.
fun test_orks17b_exception_rejection_is_atomic() -> Bool:
    let board = orks17b_cp_fixture()
    board[0].battle_socked = true
    board.command_points[0] = 0
    if board.try_use_strat(false, Stratagem::orks_breakin_heads, board[0], 1):
        return false
    board.command_points[0] = 5
    return !board.try_use_strat(false, Stratagem::orks_breakin_heads, board[1], 1) and board.command_points[0] == 5 and !board.has_used_strat(Stratagem::orks_breakin_heads, 0) and !board[0].history.stratagem_targeted_by_player[0]

# Infested War Zone targets a real destroyed unit, not a live/empty placeholder;
# it remains 2CP and cannot be repeated or waive a shocked-target restriction.
fun test_orks17b_destroyed_unit_exception() -> Bool:
    let board = orks17b_cp_fixture()
    if board.can_target_strat(false, Stratagem::orks_infested_war_zone, board[0]):
        return false
    while !board[0].models.empty():
        board[0].remove_model(0)
    let empty : Unit
    if destroyed_stratagem_target(empty) or board.can_target_strat(false, Stratagem::orks_hit_em_harder, board[0]):
        return false
    board[0].battle_socked = true
    if board.can_target_strat(false, Stratagem::orks_infested_war_zone, board[0]):
        return false
    board[0].battle_socked = false
    return board.try_use_strat(false, Stratagem::orks_infested_war_zone, board[0], 2) and board.command_points[0] == 3 and !board.can_target_strat(false, Stratagem::orks_infested_war_zone, board[0])

# Destroyed Aircraft can be retained pending demise; do not require a fully
# emptied vector to recognise this printed destruction-time target.
fun test_orks17b_retained_destroyed_target_policy() -> Bool:
    let board = orks17b_cp_fixture()
    board[0].models.resize(1)
    board[0][0].state = ModelState::pending_destruction
    return board.can_target_strat(false, Stratagem::orks_flyin_headbutt, board[0]) and !board.can_target_strat(false, Stratagem::orks_infested_war_zone, board[1])

# Discount to zero and the +1CP Hulking Brutes option retain target limits;
# the cost primitive does not calculate points/DP (Orks cards; p.54).
fun test_orks17b_zero_and_surcharged_cp_use() -> Bool:
    let board = orks17b_cp_fixture()
    board[1].owned_by_player1 = false
    board.armies[0].detachments.clear()
    let selected = board.armies[0].record_detachment(OrksDetachment::bully_boyz)
    board.command_points[0] = 1
    if board.try_use_strat(false, Stratagem::orks_hulking_brutes, board[0], 2):
        return false
    board.command_points[0] = 2
    if !board.try_use_strat(false, Stratagem::orks_hulking_brutes, board[0], 2) or board.command_points[0] != 0:
        return false
    return !board.try_use_strat(false, Stratagem::orks_armed_to_da_teef, board[0], 0) and board.try_use_strat(false, Stratagem::crushing_impact, board[1], 0) and board.has_used_strat(Stratagem::crushing_impact, 0)

# Appendix02.02.01: final-cost overrides also obey the +1CP cap; invalid
# negative/excessive costs leave the balance and target bookkeeping intact.
fun test_orks17b_final_cp_cost_cap() -> Bool:
    let board = orks17b_cp_fixture()
    if board.try_use_strat(false, Stratagem::orks_hit_em_harder, board[0], -1) or board.try_use_strat(false, Stratagem::orks_hit_em_harder, board[0], 3) or board.try_use_strat(false, Stratagem::reroll, board[0], 3):
        return false
    return board.command_points[0] == 5 and !board[0].history.stratagem_targeted_by_player[0] and board.can_target_strat_with_cost(false, Stratagem::orks_hit_em_harder, board[0], 2)

# Core p.54: each player's phase use is independent, and the next phase
# clears use records without changing selected packages or CP balances.
fun test_orks17b_per_player_cp_and_phase_reset() -> Bool:
    let board = orks17b_cp_fixture()
    board.armies[1].faction = ArmyFaction::orks
    let selected_other = board.armies[1].record_detachment(OrksDetachment::war_horde)
    board.command_points[1] = 2
    if !board.try_use_strat(false, Stratagem::orks_hit_em_harder, board[0], 1) or !board.try_use_strat(true, Stratagem::orks_hit_em_harder, board[1], 1):
        return false
    board.begin_phase(BattlePhase::fight)
    return board.command_points[0] == 4 and board.command_points[1] == 1 and board.can_target_strat(false, Stratagem::orks_hit_em_harder, board[0]) and board.can_target_strat(true, Stratagem::orks_hit_em_harder, board[1]) and board.armies[0].detachments.size() == 3 and board.armies[1].detachments.size() == 1

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
    board.reserve_units[1].attachment_role = AttachmentRole::leader
    board.reserve_units[1].attach_to(board.reserve_units[0])
    board.reserve_units[0].capture_starting_strength()
    return board.reserve_units[0].starting_strenght == 6 and board.reserve_units[0][5].identity == model and board.reserve_units[0][5].original_unit == origin and board.reserve_units[0].attached_units[0].identity == origin and board.reserve_units[0].attached_units[0].starting_strength == 1

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


# pp.54/57: no affordable Overwatch source leaves no optional timing decision.
fun test_overwatch_with_no_cp_cannot_spend() -> Bool:
    let board = core15_fixture()
    board.command_points[1] = 0
    let sequence = resolve_timing_window(board, TimingWindow::movement_end)
    return sequence.is_done() and board.command_points[1] == 0 and !board.has_used_strat(Stratagem::overwatch, 1)

# pp.54/57: declining at the actual Movement-end boundary preserves CP/usage.
fun test_declining_overwatch_preserves_cp_and_usage() -> Bool:
    let board = core15_fixture()
    board.command_points[1] = 1
    let sequence = resolve_timing_window(board, TimingWindow::movement_end)
    if !(can sequence.finish_timing_rules(board)):
        return false
    sequence.finish_timing_rules(board)
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

# User retires obsolete Orks cards: no pre-Fight bellow and no old defensive
# payloads remain. Core Pile In starts directly without spending CP (pp.38/54).
fun test_orks17c_retired_stratagems_are_unavailable() -> Bool:
    let board : Board
    board.units.append(make_beastboss_morgrim())
    board.players_faction[0] = Faction::morgrim_butchas
    board.command_points[0] = 1
    let sequence = fight_phase(board)
    let obsolete : AnyGameAction
    let old_defence = s("tough_as_squig_hide {}")
    let old_bellow = s("use_bestial_bellow {unit: {id: 0}, target: {id: 0}}")
    let core_payload = s("finish_melee_step {}")
    return (can sequence.finish_melee_step(board)) and board.command_points[0] == 1 and from_string(obsolete, core_payload) and !from_string(obsolete, old_defence) and !from_string(obsolete, old_bellow)


fun test_accepting_overwatch_charges_only_opponent() -> Bool:
    let board = core15_fixture()
    board.command_points[0] = 0
    board.command_points[1] = 1
    let source = unit_id(1)
    let sequence = timing_overwatch(board, true)
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
    if unit.allows_action_start() or !unit.allows_action_completion():
        return false
    unit.battle_socked = true
    for i in range(unit.models.size()):
        if !unit.model_is_battle_shocked(i) or unit.model_objective_control(i) != 0:
            return false
    if unit.allows_action_start() or unit.allows_action_completion():
        return false
    unit.battle_socked = false
    return !unit.allows_action_start() and unit.allows_action_completion() and !unit.model_is_battle_shocked(0) and unit.model_objective_control(0) == 1 and unit.history.action_started

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
    board[0][0].weapons.append(equipped_weapon(Weapon::captain_storm_bolter))
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
    board[0][0].weapons.append(equipped_weapon(Weapon::librarian_storm_bolter))
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
    board[0][0].weapons.append(equipped_weapon(Weapon::relic_weapon))
    board[0][0].weapons.append(equipped_weapon(Weapon::force_weapon))
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
    board[0][0].weapons[0].profile = Weapon::relic_weapon
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
    board[0][0].weapons[0].profile = Weapon::relic_weapon
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
    board[0][0].weapons[0].profile = Weapon::smite_witchfire
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
    board[0][0].weapons.append(equipped_weapon(Weapon::librarian_storm_bolter))
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
    board[0][0].weapons.append(equipped_weapon(Weapon::smite_focused_witchfire))
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
    board[0][0].weapons[0].profile = Weapon::meltagun
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
    return board.units.size() == 1 and board[0].identity == identity and board[0].history.advanced_this_turn and board[0].battle_socked and board[0].history.repositioned and !board[0].allows_action_start()

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
    board[0][0].weapons.append(equipped_weapon(Weapon::bolt_pistol))
    board[0][0].weapons.append(equipped_weapon(Weapon::captain_storm_bolter))
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
    return rule.parameter == 2 and rule.target_condition.size() == 1 and weapon_ability_condition_keyword(rule, 0) == Keyword::vehicle and restored.board[0][0].weapons.size() == 1

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
    board[0][0].weapons[0].profile = Weapon::relic_weapon
    board[0][0].weapons.append(equipped_weapon(Weapon::force_weapon))
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

# p.14 and appendix01.02.04: offboard status must not mask collisions in
# prospective deployment search; a fully blocked home zone is unplaceable.
fun test_transport16_deployment_search_checks_offboard_geometry() -> Bool:
    let board : Board
    let unit = make_infernus_squad()
    unit.models.resize(1)
    unit.owned_by_player1 = true
    mark_unit_offboard(unit, true)
    # Occupy every interior home-zone quad with a battlefield base. A stored
    # offboard flag would incorrectly make every overlap check return false.
    for home_row in range(4):
        for half_row in range(2):
            let blockers : Unit
            for column in range(22 - half_row):
                let blocker : Model
                blocker.profile = Profile::infernus_squad
                blocker.position = board_position(1 + half_row * 22 + column, home_row + 1)
                blockers.models.append(blocker)
            board.units.append(blockers)
    return !deployment_has_position(board, unit) and unit.off_battlefield

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
    board[0][0].weapons.append(equipped_weapon(board[0][0].weapons[0].profile))
    board[0][0].weapons[0].secondary_profile_of = 0
    board[0][0].weapons[1].secondary_profile_of = 1
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
    return weapon_primary_id(legionaries[0], 0) == 1 and weapon_primary_id(legionaries[0], 1) == 1 and legionaries[1].weapons[0].secondary_profile_of.value == 0 and weapon_primary_id(hellblasters[0], 1) == 2 and weapon_primary_id(hellblasters[0], 2) == 2

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

# p.38: active player performs every optional Pile In before the opponent,
# and both movement stages precede mandatory attack selection.
fun test_fight14_phase_wide_pile_in_order() -> Bool:
    let board = fight14_fixture()
    let phase = fight_phase(board)
    if board.current_decision_maker or !(can phase.select_melee_unit(board, unit_id(0))) or (can phase.select_melee_unit(board, unit_id(1))):
        return false
    phase.finish_melee_step(board)
    if !board.current_decision_maker or !(can phase.select_melee_unit(board, unit_id(1))):
        return false
    phase.finish_melee_step(board)
    return !board.current_decision_maker and (can phase.select_fighting_unit(board, unit_id(0))) and !(can phase.select_melee_unit(board, unit_id(0)))

# pp.40/81: current player starts Fights First; every participating model
# needs the ability, while any completed charge grants it to the whole unit.
fun test_fight14_first_requires_all_models_or_charge() -> Bool:
    let board = fight14_fixture()
    board[0][0].abilities.append(AbilityKind::fight_first)
    let ordinary = board[0][0]
    ordinary.abilities.clear()
    ordinary.position.y = 7
    board[0].models.append(ordinary)
    if fight_first_unit(board[0]):
        return false
    board[0].has_charged = true
    board[1][0].abilities.append(AbilityKind::fight_first)
    let sequence = fight_step(board, true)
    return fight_first_unit(board[0]) and !board.current_decision_maker and (can sequence.select_fighting_unit(board, unit_id(0))) and !(can sequence.select_fighting_unit(board, unit_id(1))) and !(can sequence.pass_fight(board))

# p.40: when neither player has Fights First units, the current player
# moves the sequence into Remaining Combats and selects first.
fun test_fight14_remaining_combats_current_player_starts() -> Bool:
    let board = fight14_fixture()
    let sequence = fight_step(board, true)
    return !sequence.first and (can sequence.select_fighting_unit(board, unit_id(0))) and !(can sequence.pass_fight(board))

# p.40: legal passing transfers selection only when no unit of the required
# priority is available; an eligible normal unit cannot bypass enemy Fights First.
fun test_fight14_priority_pass_and_owner_transfer() -> Bool:
    let board = fight14_fixture()
    board[1][0].abilities.append(AbilityKind::fight_first)
    let sequence = fight_step(board, true)
    if !(can sequence.pass_fight(board)) or (can sequence.select_fighting_unit(board, unit_id(0))):
        return false
    sequence.pass_fight(board)
    return board.current_decision_maker and !(can sequence.pass_fight(board)) and (can sequence.select_fighting_unit(board, unit_id(1)))

# p.40: selecting consumes the fight immediately; an already selected unit
# cannot be chosen twice while nested weapon/attack decisions are unresolved.
fun test_fight14_selection_consumes_once_before_attacks() -> Bool:
    let board = fight14_fixture()
    let sequence = fight_step(board, true)
    sequence.select_fighting_unit(board, unit_id(0))
    return board[0].has_fought and !fight_unit_eligible(board, unit_id(0)) and (can sequence.choose_fight_kind(board, FightKind::normal)) and !(can sequence.choose_fight_kind(board, FightKind::overrun))

# p.40: a unit that was engaged at Fight-step start remains eligible after
# its opponent disappears; it selects Overrun and cannot select Normal.
fun test_fight14_start_engagement_survives_enemy_loss() -> Bool:
    let board = fight14_fixture()
    begin_fight_step(board)
    board[1].models.clear()
    return fight_unit_eligible(board, unit_id(0)) and fight_kind_valid(board, unit_id(0), FightKind::overrun) and !fight_kind_valid(board, unit_id(0), FightKind::normal)

# p.40: newly engaged units become eligible and can choose Overrun even
# while currently engaged; newly eligible Fights First restores priority.
fun test_fight14_new_engagement_restores_first_priority() -> Bool:
    let board = fight14_fixture()
    let other = board[1]
    other[0].position.x = 20
    other[0].abilities.append(AbilityKind::fight_first)
    board.units.append(other)
    begin_fight_step(board)
    if fight_unit_eligible(board, unit_id(2)):
        return false
    board[2][0].position = board_position(5, 7)
    refresh_fight_eligibility(board)
    return fight_unit_eligible(board, unit_id(2)) and player_can_fight(board, true, true) and fight_kind_valid(board, unit_id(2), FightKind::overrun) and board[2].history.fight_eligible_phase == board.phase_serial.value + 1

# pp.38/40: phase-wide Pile In is once per completed move; Overrun grants an
# additional one even when the phase-wide stamp is already present.
fun test_fight14_overrun_additional_pile_in() -> Bool:
    let board = fight14_fixture()
    board[0].history.pile_in_phase = board.phase_serial.value + 1
    return !melee_move_eligible(board, unit_id(0), false, false) and melee_move_eligible(board, unit_id(0), false, true)

# pp.38/42: candidate formation is private until final constraints pass;
# cancellation leaves position/distance/once-per-step stamps untouched.
fun test_fight14_pile_in_path_commit_and_cancel() -> Bool:
    let board = fight14_fixture()
    let sequence = melee_move(board, unit_id(0), false, false)
    sequence.select_melee_model(board, damage_test_model(0))
    sequence.choose_melee_approach(board, unit_id(1))
    sequence.melee_waypoint(board, board_position(6, 5))
    sequence.finish_melee_model(board)
    if board[0][0].position.x != 5 or !(can sequence.finish_melee_move(board)):
        return false
    sequence.finish_melee_move(board)
    if !sequence.completed or board[0][0].position.x != 6 or board[0].history.pile_in_phase != board.phase_serial.value + 1 or board[0][0].history.distance_moved_this_turn() != 1.0:
        return false
    let declined = melee_move(board, unit_id(1), false, false)
    declined.cancel_melee_move(board)
    return declined.is_done() and board[1][0].position.x == 8 and board[1].history.pile_in_phase == 0

# p.38: a charged unengaged unit chooses targets within 5, then must finish
# engaged. No target outside 5 is accepted, even with a 3-inch path budget.
fun test_fight14_unengaged_pile_targets_and_engaged_finish() -> Bool:
    let board = fight14_fixture()
    board[1][0].position.x = 11
    board[0].has_charged = true
    let sequence = melee_move(board, unit_id(0), false, false)
    if !(can sequence.select_melee_target(board, unit_id(1))) or (can sequence.finish_melee_targets(board)):
        return false
    sequence.select_melee_target(board, unit_id(1))
    sequence.finish_melee_targets(board)
    if can sequence.finish_melee_move(board):
        return false
    sequence.select_melee_model(board, damage_test_model(0))
    sequence.choose_melee_approach(board, unit_id(1))
    sequence.melee_waypoint(board, board_position(8, 5))
    sequence.finish_melee_model(board)
    return can sequence.finish_melee_move(board)

# pp.38/42: moved models must approach their own initial closest selected
# enemy; controller choices preserve exact closest-unit ties.
fun test_fight14_closest_target_ties_and_wrong_target() -> Bool:
    let board = fight14_fixture()
    let other = board[1]
    other[0].position = board_position(5, 8)
    board.units.append(other)
    let targets : Bool[MAX_UNIT_COUNT]
    targets[1] = true
    targets[2] = true
    if !nearest_melee_target_valid(board, board[0][0], targets, unit_id(1)) or !nearest_melee_target_valid(board, board[0][0], targets, unit_id(2)):
        return false
    board[2][0].position.y = 9
    return !nearest_melee_target_valid(board, board[0][0], targets, unit_id(2))

# pp.38/42: an initially engaged model must stay engaged with every original
# enemy unit, not only its chosen closest approach target.
fun test_fight14_preserve_every_original_model_engagement() -> Bool:
    let board = fight14_fixture()
    let other = board[1]
    other[0].position = board_position(5, 8)
    board.units.append(other)
    let candidate = board[0]
    candidate[0].position = board_position(6, 4)
    let targets : Bool[MAX_UNIT_COUNT]
    targets[1] = true
    targets[2] = true
    return !melee_placement_valid(board, board[0], candidate, unit_id(0), MeleeMoveKind::pile_in, targets, 0)

# pp.12/38/42: no enemy overlap and no path-budget reset across waypoints.
fun test_fight14_waypoint_total_and_enemy_collision() -> Bool:
    let board = fight14_fixture()
    let path : ModelPath
    path.model = 0
    if melee_waypoint_valid(board, board[0], path, board_position(8, 5), MeleeMoveKind::pile_in):
        return false
    path.append_point(geometry_point(5 * MICROMETRES_PER_INCH, 7 * MICROMETRES_PER_INCH, 0))
    return !melee_waypoint_valid(board, board[0], path, board_position(5, 9), MeleeMoveKind::pile_in)

# p.38: contact/overlap has zero base separation and is locked, including
# rotation. The current millimetre fixtures cannot express exact contact on
# whole quads, so this predicate boundary is not a valid placement fixture.
fun test_fight14_contact_lock_predicate_and_dead_models() -> Bool:
    let board = fight14_fixture()
    board[1][0].position = board[0][0].position
    if !melee_model_locked(board, board[0][0], board[0], MeleeMoveKind::pile_in):
        return false
    board[0][0].state = ModelState::fight_on_death
    return melee_model_locked(board, board[0][0], board[0], MeleeMoveKind::engaging)

# p.42: mandatory mode priority is ongoing, then nearby enemies, then objectives.
fun test_fight14_consolidation_mode_priority() -> Bool:
    let board = fight14_fixture()
    if !(consolidation_kind(board, board[0]) == MeleeMoveKind::ongoing):
        return false
    board[1][0].position.x = 9
    if !(consolidation_kind(board, board[0]) == MeleeMoveKind::engaging):
        return false
    board[1][0].position.x = 15
    return consolidation_kind(board, board[0]) == MeleeMoveKind::objective

# p.42: having been eligible earlier permits consolidation even after all
# enemies disappear; an unrelated unit cannot consolidate merely by choosing it.
fun test_fight14_consolidation_uses_earlier_eligibility() -> Bool:
    let board = fight14_fixture()
    begin_fight_step(board)
    board[1].models.clear()
    return melee_move_eligible(board, unit_id(0), true, false) and !melee_move_eligible(board, unit_id(1), true, false)

# p.42: engaging consolidation must engage every selected enemy, but may
# incidentally engage another enemy; it will be offered a response fight.
fun test_fight14_engaging_consolidation_all_targets_and_incidental() -> Bool:
    let board = fight14_fixture()
    board[1][0].position.x = 9
    let other = board[1]
    other[0].position = board_position(7, 7)
    board.units.append(other)
    let candidate = board[0]
    candidate[0].position.x = 7
    let targets : Bool[MAX_UNIT_COUNT]
    targets[1] = true
    if !melee_placement_valid(board, board[0], candidate, unit_id(0), MeleeMoveKind::engaging, targets, 0):
        return false
    board[2][0].position.x = 15
    targets[2] = true
    return !melee_placement_valid(board, board[0], candidate, unit_id(0), MeleeMoveKind::engaging, targets, 0)

# p.42: objective selection is within 3 inches of any live base; a moved
# model must end in objective range when a coherent endpoint can do so.
fun test_fight14_objective_consolidation_range() -> Bool:
    let board = fight14_fixture()
    board[1].models.clear()
    board.objectives[0].custom_position = true
    board.objectives[0].position = board_position(8, 5)
    board[0].history.fight_eligible_phase = board.phase_serial.value + 1
    if !melee_objective_valid(board, board[0], 0):
        return false
    let sequence = melee_move(board, unit_id(0), true, false)
    sequence.choose_melee_objective(board, fight14_objective(0))
    if !(can sequence.finish_melee_move(board)):
        return false
    sequence.finish_melee_move(board)
    return sequence.completed and board[0].history.consolidation_phase == board.phase_serial.value + 1 and !melee_move_eligible(board, unit_id(0), true, false)

# pp.42/52: terrain objectives use their linked area, not marker distance.
fun test_fight14_objective_terrain_area_distance() -> Bool:
    let board = fight14_fixture()
    board.terrain_areas.append(terrain_area(6, 4, 12, 6, false))
    board.objectives[0].terrain_objective = true
    board.objectives[0].area_id = 0
    board.objectives[0].custom_position = true
    board.objectives[0].position = board_position(12, 5)
    return melee_objective_valid(board, board[0], 0) and melee_objective_distance(board, board[0][0], 0) < 1.0

# p.42: consolidation response remains mandatory if an earlier response
# removes its enemy, so the unit may make an Overrun instead of disappearing.
fun test_fight14_consolidation_response_survives_enemy_loss() -> Bool:
    let board = fight14_fixture()
    board[1].history.consolidation_fight_pending = board.phase_serial.value + 1
    board[0].models.clear()
    return consolidation_response_valid(board, unit_id(1)) and has_consolidation_response(board, true) and fight_kind_valid(board, unit_id(1), FightKind::overrun)

# p.74: only FLYING bearers can attack AIRCRAFT in melee; a mixed unit's
# keyword cannot grant that permission to its non-flying model.
fun test_fight14_aircraft_melee_bearer_restriction() -> Bool:
    let board = fight14_fixture()
    board[1][0].keywords.append(Keyword::aircraft)
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    if declaration_target_valid(board, unit_id(0), declaration, unit_id(1), true):
        return false
    board[0][0].keywords.append(Keyword::fly)
    return declaration_target_valid(board, unit_id(0), declaration, unit_id(1), true)

# Supplied Fight on Death: no destruction triggers/removal when the enemy
# finishes attacking. Corpses stay ineligible as targets and ordinary attackers.
fun test_fight14_retained_death_waits_for_own_unit() -> Bool:
    let board = fight14_fixture()
    board.attack_info.fight_on_death_roll = 1
    let job = damage_job(DamageKind::normal, unit_id(0), unit_id(1), true, true, 2, board[0][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 2, true)
    let corpse = board[0][0].identity
    let jobs : DamageJobs
    let finished_enemy = resolve_damage_jobs(board, jobs, true, unit_id(1))
    return finished_enemy.is_done() and board[0].find_model(corpse) == 0 and board[0][0].destruction_pending and !destruction_ready(board[0][0], true, unit_id(1)) and !has_live_attack_recipient(board[0]) and !attack_model_allowed(board, unit_id(0), 0, true) and fight_unit_eligible(board, unit_id(0))

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

# pp.38–42 storage infrastructure: snapshots and once-per-step markers have
# bounded inferred ML layout; corrupted metadata cannot bypass save validation.
fun test_fight14_malformed_phase_stamp_rejected() -> Bool:
    let state = play()
    let board = fight14_fixture()
    state.board.units.append(board[0])
    state.board.identify_unit(state.board[0])
    state.board[0].history.consolidation_phase.value = MAX_PHASE_STAMP
    let text = to_string(state)
    let restored = play()
    return !set_state(restored, text)

# Four-slot objective selector matches the editor's finite numeric payload.
fun fight14_objective(Int value) -> BInt<0, 4>:
    let objective : BInt<0, 4>
    objective = value
    return objective

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

fun fight14_miss_attacks(FightStep sequence, Board board, UnitID source, UnitID target):
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

    if can sequence.decline_counteroffensive(board):
        sequence.decline_counteroffensive(board)

fun core15_miss_attacks(FightStep sequence, Board board, UnitID source, UnitID target):
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

fun fight14_miss_attacks(MeleeMoveStep sequence, Board board, UnitID source, UnitID target):
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

# p.40: completed activations alternate owners, and all eligible units must
# fight once. No optional end button can silently omit the second army.
fun test_fight14_alternates_complete_unit_attacks() -> Bool:
    let board = fight14_fixture()
    let sequence = fight_step(board, true)
    sequence.select_fighting_unit(board, unit_id(0))
    sequence.choose_fight_kind(board, FightKind::normal)
    fight14_miss_attacks(sequence, board, unit_id(0), unit_id(1))
    if !board.current_decision_maker or !(can sequence.select_fighting_unit(board, unit_id(1))) or (can sequence.pass_fight(board)):
        return false
    sequence.select_fighting_unit(board, unit_id(1))
    sequence.choose_fight_kind(board, FightKind::normal)
    fight14_miss_attacks(sequence, board, unit_id(1), unit_id(0))
    return sequence.is_done() and board[0].has_fought and board[1].has_fought and !board.current_decision_maker

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

# p.42: completing Engaging Consolidation immediately offers the newly
# engaged unfought enemy a mandatory response before any further moves.
fun test_fight14_engaging_consolidation_forces_response() -> Bool:
    let board = fight14_fixture()
    board[1][0].position.x = 9
    board[0].history.fight_eligible_phase = board.phase_serial.value + 1
    board[0].has_fought = true
    let sequence = melee_move_step(board, true)
    sequence.select_melee_unit(board, unit_id(0))
    sequence.select_melee_target(board, unit_id(1))
    sequence.finish_melee_targets(board)
    sequence.select_melee_model(board, damage_test_model(0))
    sequence.choose_melee_approach(board, unit_id(1))
    sequence.melee_waypoint(board, board_position(7, 5))
    sequence.finish_melee_model(board)
    sequence.finish_melee_move(board)
    if !board.current_decision_maker or !(can sequence.select_consolidation_fighter(board, unit_id(1))) or (can sequence.finish_melee_step(board)):
        return false
    sequence.select_consolidation_fighter(board, unit_id(1))
    sequence.choose_fight_kind(board, FightKind::normal)
    fight14_miss_attacks(sequence, board, unit_id(1), unit_id(0))
    return !board.current_decision_maker and board[1].has_fought and (can sequence.finish_melee_step(board))

# Supplied Fight on Death: a unit already selected to fight cannot fight a
# second time; any newly retained casualties wait until phase-end release.
fun test_fight14_already_fought_retained_unit_no_second_fight() -> Bool:
    let board = fight14_fixture()
    board[0].has_fought = true
    board.attack_info.fight_on_death_roll = 1
    let job = damage_job(DamageKind::normal, unit_id(0), unit_id(1), true, true, 2, board[0][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 2, true)
    return !fight_unit_eligible(board, unit_id(0)) and !destruction_ready(board[0][0], true, unit_id(1))

# pp.38/42: a moved model cannot skip engagement when a coherent reachable
# replacement exists, even if another model already engages the selected unit.
fun test_fight14_moved_model_must_engage_if_possible() -> Bool:
    let board = fight14_fixture()
    board[1][0].position.x = 10
    let other = board[0][0]
    other.position.y = 7
    board[0].models.append(other)
    let candidate = board[0]
    candidate[0].position = board_position(6, 6)
    candidate[1].position = board_position(8, 7)
    let targets : Bool[MAX_UNIT_COUNT]
    targets[1] = true
    let approaches : UnitID[MAX_UNIT_MODELS]
    approaches[0] = unit_id(1)
    approaches[1] = unit_id(1)
    return melee_placement_valid(board, board[0], candidate, unit_id(0), MeleeMoveKind::pile_in, targets, 0) and !melee_finish_valid(board, board[0], candidate, unit_id(0), MeleeMoveKind::pile_in, targets, approaches, 0) and candidate[0].position.x == 6

# pp.38/42 storage: a pending per-model path and closest-target choice retain
# their bounded state across a save round trip; positions commit only at finish.
fun test_fight14_pending_melee_path_round_trip() -> Bool:
    let board = fight14_fixture()
    let sequence = melee_move(board, unit_id(0), false, false)
    sequence.select_melee_model(board, damage_test_model(0))
    sequence.choose_melee_approach(board, unit_id(1))
    sequence.melee_waypoint(board, board_position(6, 5))
    let text = to_string(sequence)
    let restored : MeleeMove
    let index = 0
    if !from_string(restored, text, index):
        return false
    restored.finish_melee_model(board)
    restored.finish_melee_move(board)
    return restored.is_done() and restored.completed and board[0][0].position.x == 6

# pp.8/40: the selected unit owns the active/decision roles even while
# choosing its fight type, and both roles restore after an opposing activation.
# An invalid direct constructor cannot consume a fight or index a foreign slot.
fun test_fight14_selected_opponent_roles_and_invalid_constructor() -> Bool:
    let board = fight14_fixture()
    let invalid = selected_fight(board, unit_id(31))
    if !invalid.is_done() or board[0].has_fought or board.timing.active_player:
        return false
    let sequence = selected_fight(board, unit_id(1))
    if !board.current_decision_maker or !board.timing.active_player or board.current_player:
        return false
    sequence.choose_fight_kind(board, FightKind::normal)
    sequence.select_weapon(board, attack_test_slot(2))
    sequence.skip(board)
    sequence.declare_target(board, unit_id(1), unit_id(0))
    sequence.assign_attacks(board, attack_test_share(3))
    sequence.choose_attack_target(board, unit_id(0))
    sequence.no_defensive_stratagem(board)
    sequence.no_offensive_stratagem(board)
    sequence.choose_attack_weapon(board, attack_test_weapon(0))
    for i in range(3):
        sequence.roll(board, attack_test_die(1))
    if can sequence.keep_batch(board):
        sequence.keep_batch(board)
    return sequence.is_done() and !board.current_decision_maker and !board.timing.active_player and board[1].has_fought

# Task 15 fixtures use explicit core keywords, not guessed faction datasheets.
fun core15_fixture() -> Board:
    let board = charge13_fixture()
    board.begin_phase(BattlePhase::shooting)
    board[0].can_shoot = true
    board[1].can_shoot = true
    board[0][0].keywords.append(Keyword::grenades)
    return board

# p.56: all four added 1CP stratagems and Counteroffensive's 2CP cost.
fun test_core15_printed_costs() -> Bool:
    return Stratagem::explosives.cost() == 1 and Stratagem::crushing_impact.cost() == 1 and Stratagem::epic_challenge.cost() == 1 and Stratagem::smokescreen.cost() == 1 and Stratagem::counteroffensive.cost() == 2

# p.56: friendly source in own Shooting phase, not Advance/shock/engagement.
fun test_core15_explosives_source_gates() -> Bool:
    let board = core15_fixture()
    if !explosives_source_valid(board, unit_id(0)) or explosives_source_valid(board, unit_id(1)):
        return false
    board[0].history.advanced_this_turn = true
    if explosives_source_valid(board, unit_id(0)):
        return false
    board[0].history.advanced_this_turn = false
    board[0].battle_socked = true
    if explosives_source_valid(board, unit_id(0)):
        return false
    board[0].battle_socked = false
    board.begin_phase(BattlePhase::charge)
    return !explosives_source_valid(board, unit_id(0))

# p.56: an unengaged target in range of the actual keyword bearer is required.
fun test_core15_explosives_bearer_range_and_enemy_engagement() -> Bool:
    let board = core15_fixture()
    board[1][0].position.x = 14
    if !explosives_target_valid(board, unit_id(0), damage_test_model(0), unit_id(1)):
        return false
    board[1][0].position.x = 15
    if explosives_source_valid(board, unit_id(0)):
        return false
    board[1][0].position.x = 13
    let friend = board[0]
    friend[0].position.x = 11
    board.units.append(friend)
    return !explosives_target_valid(board, unit_id(0), damage_test_model(0), unit_id(1)) and !explosives_model_valid(board, unit_id(0), damage_test_model(1))

# p.56: choose a keyword bearer, not another model in its mixed unit.
fun test_core15_explosives_per_model_keyword() -> Bool:
    let board = core15_fixture()
    let ordinary = board[0][0]
    ordinary.keywords.clear()
    board[0].models.append(ordinary)
    return explosives_model_valid(board, unit_id(0), damage_test_model(0)) and !explosives_model_valid(board, unit_id(0), damage_test_model(1))

# pp.54/56: choose source, bearer, target; six neutral dice precede common
# mortal allocation. Selecting Explosives does not consume normal shooting.
fun test_core15_explosives_six_dice_and_one_mortal() -> Bool:
    let board = core15_fixture()
    let sequence = resolve_explosives(board, unit_id(0))
    if board.command_points[0] != 2 or board.moving_unit.get() != 0 or !(can sequence.choose_explosives_model(board, damage_test_model(0))):
        return false
    sequence.choose_explosives_model(board, damage_test_model(0))
    sequence.choose_explosives_target(board, unit_id(1))
    sequence.roll(board, attack_test_die(4))
    for i in range(5):
        sequence.roll(board, attack_test_die(1))
    if (can sequence.roll(board, attack_test_die(6))) or !(can sequence.select_mortal_model(board, damage_test_model(0))):
        return false
    sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[1][0].suffered_wounds == 1 and board[0].history.stratagem_targeted_by_player[0] and !board[0].has_shoot and shooting_unit_valid(board, unit_id(0)) and !explosives_source_valid(board, unit_id(0))

# pp.24/56/87: Explosives deaths use actual delayed destruction/archival,
# not low-level damage or a bespoke casualty deletion helper.
fun test_core15_explosives_common_destruction() -> Bool:
    let board = core15_fixture()
    board[1][0].has_deadly_demise = true
    board[1][0].deadly_demise = raw_stat(1)
    let sequence = resolve_explosives(board, unit_id(0))
    sequence.choose_explosives_model(board, damage_test_model(0))
    sequence.choose_explosives_target(board, unit_id(1))
    for i in range(6):
        sequence.roll(board, attack_test_die(4))
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.select_mortal_model(board, damage_test_model(0))
    if board[1].models.empty() or !(can sequence.choose_destruction_unit(board, unit_id(1))):
        return false
    sequence.choose_destruction_unit(board, unit_id(1))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    sequence.roll(board, attack_test_die(1))
    return sequence.is_done() and board[1].models.empty() and board[1].destroyed_models.value.size() == 1

# p.56: decline before a source is selected spends nothing; own Shooting
# phase exposes Explosives without requiring a normal ranged weapon.
fun test_core15_explosives_shooting_phase_entry() -> Bool:
    let board = core15_fixture()
    board[0][0].weapons.clear()
    let phase = shooting_phase(board)
    if !(can phase.use_explosives(board, unit_id(0))):
        return false
    phase.end_shooting_phase(board)
    return phase.is_done() and board.command_points[0] == 3 and !board.has_used_strat(Stratagem::explosives, 0)

# p.56: a successful own Charge-phase move and keyword are mandatory.
fun test_core15_crushing_success_phase_and_keyword_gates() -> Bool:
    let board = fight14_fixture()
    board[0][0].keywords.append(Keyword::monster)
    board[0].history.charge_move_phase = board.phase_serial.value + 1
    if crushing_source_valid(board, unit_id(0)):
        return false
    board.begin_phase(BattlePhase::charge)
    if crushing_source_valid(board, unit_id(0)):
        return false
    record_charge_move(board, unit_id(0))
    if !crushing_source_valid(board, unit_id(0)):
        return false
    board.current_player = true
    return !crushing_source_valid(board, unit_id(0))

# p.56: model selection requires that bearer to engage the chosen enemy.
fun test_core15_crushing_selected_model_engagement() -> Bool:
    let board = fight14_fixture()
    let far = board[0][0]
    far.position.x = 2
    board[0].models.append(far)
    return crushing_model_valid(board, unit_id(0), unit_id(1), damage_test_model(0)) and !crushing_model_valid(board, unit_id(0), unit_id(1), damage_test_model(1)) and !crushing_target_valid(board, unit_id(0), unit_id(0))

# p.56: T=4 generates four dice, ones wound the source, 5+ the enemy.
fun test_core15_crushing_both_mortal_totals() -> Bool:
    let board = fight14_fixture()
    board.begin_phase(BattlePhase::charge)
    board[0][0].keywords.append(Keyword::vehicle)
    record_charge_move(board, unit_id(0))
    let sequence = resolve_crushing_impact(board, unit_id(0))
    sequence.choose_impact_target(board, unit_id(1))
    sequence.choose_impact_model(board, damage_test_model(0))
    sequence.roll(board, attack_test_die(1))
    sequence.roll(board, attack_test_die(5))
    sequence.roll(board, attack_test_die(2))
    sequence.roll(board, attack_test_die(4))
    if sequence.self_amount != 1 or sequence.enemy_amount != 1 or (can sequence.roll(board, attack_test_die(6))):
        return false
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[0][0].suffered_wounds == 1 and board[1][0].suffered_wounds == 1 and board.command_points[0] == 2

# p.56: both self and enemy totals cap at six independently, not dice count.
fun test_core15_crushing_six_cap_per_unit() -> Bool:
    let board = fight14_fixture()
    board.begin_phase(BattlePhase::charge)
    board[0][0].keywords.append(Keyword::monster)
    board[0][0].profile = Profile::squighog_boyz
    record_charge_move(board, unit_id(0))
    let sequence = resolve_crushing_impact(board, unit_id(0))
    sequence.choose_impact_target(board, unit_id(1))
    sequence.choose_impact_model(board, damage_test_model(0))
    for i in range(7):
        sequence.roll(board, attack_test_die(1))
    return sequence.total == 7 and sequence.self_amount == 6 and sequence.enemy_amount == 0 and !(can sequence.roll(board, attack_test_die(1)))

# pp.37/56: only a completed charge exposes immediate Crushing Impact;
# accepting it pays before the target/model/dice sequence.
fun test_core15_crushing_after_real_charge_and_decline() -> Bool:
    let board = charge13_fixture()
    board.begin_phase(BattlePhase::charge)
    board[0][0].keywords.append(Keyword::monster)
    let sequence = charge(board, unit_id(0), ChargeKind::ordinary)
    sequence.roll_pair(board, attack_test_die(4), attack_test_die(4))
    sequence.keep_it(board, true)
    sequence.select_charge_target(board, unit_id(1))
    sequence.finish_charge_targets(board)
    sequence.charge_move_to(board, board_position(11, 5))
    if !(can sequence.crushing_impact(board)) or !(can sequence.decline_crushing_impact(board)):
        return false
    sequence.decline_crushing_impact(board)
    return sequence.is_done() and board[0].has_charged and board.command_points[0] == 3

# p.56: Epic Challenge chooses one CHARACTER, at selection rather than per
# attack target; ordinary living models do not inherit its Precision grant.
fun test_core15_epic_selected_character_only_melee() -> Bool:
    let board = fight14_fixture()
    board[0][0].keywords.append(Keyword::character)
    let ordinary = board[0][0]
    ordinary.keywords.clear()
    board[0].models.append(ordinary)
    let sequence = selected_fight(board, unit_id(0))
    if !(can sequence.epic_challenge(board)) or (can sequence.choose_fight_kind(board, FightKind::normal)):
        return false
    sequence.epic_challenge(board)
    if (can sequence.choose_epic_character(board, damage_test_model(1))):
        return false
    sequence.choose_epic_character(board, damage_test_model(0))
    let melee = make_declared_weapon(board, unit_id(0), 0, 2)
    let ranged = make_declared_weapon(board, unit_id(0), 0, 0)
    let other = make_declared_weapon(board, unit_id(0), 1, 2)
    return board.command_points[0] == 2 and declared_weapon_has_kind(melee, WeaponRuleKind::precision) and !declared_weapon_has_kind(ranged, WeaponRuleKind::precision) and !declared_weapon_has_kind(other, WeaponRuleKind::precision)

# pp.54/56: decline spends nothing; shock/used-unit restrictions remove it.
fun test_core15_epic_decline_and_stratagem_limits() -> Bool:
    let board = fight14_fixture()
    board[0][0].keywords.append(Keyword::character)
    let sequence = selected_fight(board, unit_id(0))
    sequence.decline_epic_challenge(board)
    if board.command_points[0] != 3 or !(can sequence.choose_fight_kind(board, FightKind::normal)):
        return false
    board[0].battle_socked = true
    return !epic_source_valid(board, unit_id(0))

# p.56: Precision expires at phase end, including retained model metadata.
fun test_core15_epic_phase_expiry() -> Bool:
    let board = fight14_fixture()
    board[0][0].history.epic_challenge = true
    board.begin_phase(BattlePhase::command)
    return !board[0][0].history.epic_challenge

# p.57: Smokescreen is only a start-of-opponent-Shooting window option.
fun test_core15_smoke_window_target_and_expiry() -> Bool:
    let board = core15_fixture()
    board[1][0].keywords.append(Keyword::smoke)
    if !timing_rule_available(board, TimingWindow::shooting_start, true, TimingRule::smokescreen) or timing_rule_available(board, TimingWindow::shooting_end, true, TimingRule::smokescreen) or smoke_source_valid(board, false, unit_id(0)):
        return false
    let window = resolve_timing_window(board, TimingWindow::shooting_start)
    window.choose_timing_rule(board, TimingRule::smokescreen)
    window.smokescreen(board, unit_id(1))
    if !window.is_done() or board.command_points[1] != 2 or !board[1].phase_modifiers.smokescreen or !smoke_cover_applies(board, board[0][0], unit_id(1)):
        return false
    board.begin_phase(BattlePhase::charge)
    return !board[1].phase_modifiers.smokescreen

# p.57 under circular-base approximation: an intervening smoke model grants
# cover to another target; moving it off the sight segment removes that cover.
fun test_core15_smoke_intervening_base_cover() -> Bool:
    let board = core15_fixture()
    let smoke = board[1]
    smoke[0].position = board_position(9, 5)
    smoke.phase_modifiers.smokescreen = true
    board.units.append(smoke)
    if !smoke_cover_applies(board, board[0][0], unit_id(1)):
        return false
    board[2][0].position.y = 9
    return !smoke_cover_applies(board, board[0][0], unit_id(1))

# p.57: Smokescreen affects the actual per-bearer attack snapshot, never melee.
fun test_core15_smoke_attack_cover_snapshot() -> Bool:
    let board = core15_fixture()
    board[1].phase_modifiers.smokescreen = true
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let info : AttackSequenceInfo
    let ranged = declared_attack_info(board, unit_id(0), unit_id(1), declaration, info)
    let melee = make_declared_weapon(board, unit_id(0), 0, 2)
    let close = declared_attack_info(board, unit_id(0), unit_id(1), melee, info)
    return ranged.target_has_cover and !close.target_has_cover

# p.57: Counteroffensive needs two CP, opposing Fight phase and eligible unit.
fun test_core15_counteroffensive_target_gates() -> Bool:
    let board = fight14_fixture()
    if !counteroffensive_target_valid(board, true, unit_id(1)) or counteroffensive_target_valid(board, false, unit_id(0)):
        return false
    board.command_points[1] = 1
    if counteroffensive_available(board, true):
        return false
    board.command_points[1] = 2
    board[1].has_fought = true
    return !counteroffensive_available(board, true)

# pp.40/57: after the current player's attacks, the opponent can grant Fights
# First to a remaining unit and must select it next, not a different friendly.
fun test_core15_counteroffensive_forces_next_own_selection() -> Bool:
    let board = fight14_fixture()
    board[0].has_charged = true
    let other = board[1]
    other.identity = 0
    other[0].identity = 0
    other[0].position = board_position(7, 7)
    other[0].abilities.append(AbilityKind::fight_first)
    board.units.append(other)
    if !fight_unit_eligible(board, unit_id(2)) or !fight_first_unit(board[2]):
        return false
    let sequence = fight_step(board, true)
    sequence.select_fighting_unit(board, unit_id(0))
    sequence.choose_fight_kind(board, FightKind::normal)
    core15_miss_attacks(sequence, board, unit_id(0), unit_id(1))
    if !(can sequence.counteroffensive(board, unit_id(1))) or !board.current_decision_maker:
        return false
    sequence.counteroffensive(board, unit_id(1))
    return board.command_points[1] == 1 and fight_first_unit(board[1]) and (can sequence.select_fighting_unit(board, unit_id(1))) and !(can sequence.select_fighting_unit(board, unit_id(2))) and !(can sequence.pass_fight(board))

# p.57: declining Counteroffensive spends nothing and leaves normal alternation.
fun test_core15_counteroffensive_decline() -> Bool:
    let board = fight14_fixture()
    let sequence = fight_step(board, true)
    sequence.select_fighting_unit(board, unit_id(0))
    sequence.choose_fight_kind(board, FightKind::normal)
    core15_miss_attacks(sequence, board, unit_id(0), unit_id(1))
    sequence.decline_counteroffensive(board)
    return board.command_points[1] == 3 and (can sequence.select_fighting_unit(board, unit_id(1))) and !board[1].phase_modifiers.counteroffensive

# p.58: battlefield, owner, live OC, shock/keywords and engagement gates.
fun test_core15_action_start_membership_and_keywords() -> Bool:
    let board = core15_fixture()
    if !action_start_valid(board, unit_id(0), false) or action_start_valid(board, unit_id(0), true) or action_start_valid(board, unit_id(31), false):
        return false
    board[0][0].keywords.append(Keyword::fortification)
    if action_start_valid(board, unit_id(0), false):
        return false
    board[0][0].keywords.clear()
    board[0][0].keywords.append(Keyword::aircraft)
    return !action_start_valid(board, unit_id(0), false)

# p.58: start commits no CP, locks another start/charge and non-TITANIC shooting.
fun test_core15_action_start_locks_and_completion() -> Bool:
    let board = core15_fixture()
    if !begin_unit_action(board, unit_id(0), false) or begin_unit_action(board, unit_id(0), false):
        return false
    if shooting_unit_valid(board, unit_id(0)) or charge_source_valid(board, unit_id(0), false):
        return false
    if !complete_unit_action(board, unit_id(0)) or complete_unit_action(board, unit_id(0)):
        return false
    return board[0].history.action_completed and board[0].history.action_started and !board[0].history.action_pending and board.command_points[0] == 3

# p.58: TITANIC bypasses engaged/action-start shooting bans, but not charge ban.
fun test_core15_action_titanic_exceptions() -> Bool:
    let board = fight14_fixture()
    board[0].can_shoot = true
    board[0][0].keywords.append(Keyword::titanic)
    board[0][0].keywords.append(Keyword::vehicle)
    if !begin_unit_action(board, unit_id(0), false):
        return false
    return shooting_kind_valid(board, unit_id(0), ShootingKind::close_quarters) and !charge_source_valid(board, unit_id(0), false)

# p.58: generic non-melee movement, even zero distance, fails pending action;
# Remain Stationary explicitly does not trigger movement (p.33).
fun test_core15_action_move_interrupt_and_stationary_exception() -> Bool:
    let board = core15_fixture()
    begin_unit_action(board, unit_id(0), false)
    record_move(board, unit_id(0), MovementKind::stationary)
    if !action_completion_valid(board, unit_id(0)):
        return false
    record_move(board, unit_id(0), MovementKind::normal)
    return !complete_unit_action(board, unit_id(0)) and board[0].history.action_failed and !board[0].history.action_completed

# pp.9/58: Battle-shock at completion blocks the effect; earlier shock that
# has recovered does not permanently fail an otherwise uninterrupted action.
fun test_core15_action_shock_completion_and_recovery() -> Bool:
    let board = core15_fixture()
    begin_unit_action(board, unit_id(0), false)
    board[0].battle_socked = true
    if action_completion_valid(board, unit_id(0)):
        return false
    board[0].battle_socked = false
    return complete_unit_action(board, unit_id(0))

# p.58: turn start unlocks a new start but keeps unfinished cross-turn actions.
fun test_core15_action_cross_turn_pending_and_departure() -> Bool:
    let board = core15_fixture()
    begin_unit_action(board, unit_id(0), false)
    board.start_turn_history()
    if board[0].history.action_started or !board[0].history.action_pending or !action_completion_valid(board, unit_id(0)):
        return false
    if !reposition_unit(board, unit_id(0)):
        return false
    return !complete_unit_action(board, unit_id(0)) and board.reserve_units[0].history.action_pending and board.reserve_units[0].history.action_failed

# pp.33/57–58: Advance alone does not prohibit Snap, but Fall Back and an
# action's general shooting ban still apply. TITANIC is explicitly excluded.
fun test_core15_overwatch_printed_source_eligibility() -> Bool:
    let board = core15_fixture()
    board[1].history.advanced_this_turn = true
    if !overwatch_source_valid(board, true, unit_id(1)):
        return false
    board[1].history.fell_back_this_turn = true
    if overwatch_source_valid(board, true, unit_id(1)):
        return false
    board[1].history.fell_back_this_turn = false
    board[1].history.action_started = true
    if overwatch_source_valid(board, true, unit_id(1)):
        return false
    board[1].history.action_started = false
    board[1][0].keywords.append(Keyword::titanic)
    return !overwatch_source_valid(board, true, unit_id(1))

# pp.34–35/57: all printed shooting types prohibit action starts until phase
# end; the restriction is independent of whether any weapon was selected.
fun test_core15_all_shooting_phase_action_lock() -> Bool:
    let board = core15_fixture()
    board[0].history.shot_this_phase = true
    if action_start_valid(board, unit_id(0), false):
        return false
    board.begin_phase(BattlePhase::charge)
    return action_start_valid(board, unit_id(0), false)

# pp.56/81: Explosives mortals allow the common per-wound Feel No Pain roll;
# the stratagem's six initial dice are not Command Re-roll eligible.
fun test_core15_explosives_feel_no_pain() -> Bool:
    let board = core15_fixture()
    board[1][0].profile = Profile::squighog_boyz
    let sequence = resolve_explosives(board, unit_id(0))
    sequence.choose_explosives_model(board, damage_test_model(0))
    sequence.choose_explosives_target(board, unit_id(1))
    for i in range(6):
        sequence.roll(board, attack_test_die(1 + 3 * int(i == 0)))
    sequence.select_mortal_model(board, damage_test_model(0))
    if !(can sequence.roll(board, attack_test_die(5))):
        return false
    sequence.roll(board, attack_test_die(5))
    return sequence.is_done() and board[1][0].suffered_wounds == 0 and board.command_points[1] == 3

# p.56: simultaneous generated impact amounts both resolve even when source
# losses destroy the charger before the opposing losses are allocated.
fun test_core15_crushing_source_death_does_not_cancel_enemy_mortals() -> Bool:
    let board = fight14_fixture()
    board.begin_phase(BattlePhase::charge)
    board[0][0].keywords.append(Keyword::vehicle)
    record_charge_move(board, unit_id(0))
    let sequence = resolve_crushing_impact(board, unit_id(0))
    sequence.choose_impact_target(board, unit_id(1))
    sequence.choose_impact_model(board, damage_test_model(0))
    sequence.roll(board, attack_test_die(1))
    sequence.roll(board, attack_test_die(1))
    sequence.roll(board, attack_test_die(5))
    sequence.roll(board, attack_test_die(5))
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.select_mortal_model(board, damage_test_model(0))
    if !board[0].models.empty() or !(can sequence.select_mortal_model(board, damage_test_model(0))):
        return false
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[1].models.empty() and board[0].destroyed_models.value.size() == 1 and board[1].destroyed_models.value.size() == 1

# p.56: failed or cancelled charge declarations never expose Crushing Impact.
fun test_core15_crushing_failed_charge_has_no_option() -> Bool:
    let board = charge13_fixture()
    board.begin_phase(BattlePhase::charge)
    board[0][0].keywords.append(Keyword::monster)
    let sequence = charge(board, unit_id(0), ChargeKind::ordinary)
    sequence.roll_pair(board, attack_test_die(1), attack_test_die(1))
    sequence.keep_it(board, true)
    sequence.cancel_charge(board)
    return sequence.is_done() and !crushing_source_valid(board, unit_id(0)) and board.command_points[0] == 3

# p.58: Pile In/consolidation are explicitly exempt from action interruption.
fun test_core15_action_pile_in_exempt_and_pending_round_trip() -> Bool:
    let board = fight14_fixture()
    board[0][0].keywords.append(Keyword::titanic)
    if !begin_unit_action(board, unit_id(0), false):
        return false
    let moving = melee_move(board, unit_id(0), false, false)
    moving.select_melee_model(board, damage_test_model(0))
    moving.choose_melee_approach(board, unit_id(1))
    moving.melee_waypoint(board, board_position(6, 5))
    moving.finish_melee_model(board)
    moving.finish_melee_move(board)
    let text = to_string(board)
    let restored : Board
    let offset = 0
    if !from_string(restored, text, offset):
        return false
    return moving.completed and action_completion_valid(restored, unit_id(0)) and complete_unit_action(restored, unit_id(0)) and restored[0].history.action_completed

# p.58: the lower-level out-of-phase Move entry also fails pending actions,
# even when the ordinary Movement-phase record_move caller is absent.
fun test_core15_action_direct_move_interrupt() -> Bool:
    let board = core15_fixture()
    begin_unit_action(board, unit_id(0), false)
    let moving = move(board, unit_id(0), 0)
    moving.move_to(board, unit_id(0), board_position(6, 5))
    return moving.completed and board[0].history.action_failed and !complete_unit_action(board, unit_id(0))

# Supplied Fight on Death plus p.56: retained CHARACTER models remain valid
# Epic Challenge recipients when selected with their own unit.
fun test_core15_epic_retained_character() -> Bool:
    let board = fight14_fixture()
    board[0][0].keywords.append(Keyword::character)
    board[0][0].state = ModelState::fight_on_death
    board[0][0].suffered_wounds = 2
    board[0][0].destruction_pending = true
    let sequence = selected_fight(board, unit_id(0))
    sequence.epic_challenge(board)
    return can sequence.choose_epic_character(board, damage_test_model(0))

# p.58: one start per turn permits another action in a later turn while an
# earlier mission action is still pending. Complete each by its own turn stamp.
fun test_core15_actions_overlap_across_turns_without_aliasing() -> Bool:
    let board = core15_fixture()
    begin_unit_action(board, unit_id(0), false)
    let first = board[0].history.action_records[0].started_turn
    board.start_turn_history()
    if !action_start_valid(board, unit_id(0), false) or !begin_unit_action(board, unit_id(0), false):
        return false
    let second = board[0].history.action_records[1].started_turn
    if first == second or !complete_unit_action(board, unit_id(0), first) or !board[0].history.action_pending or complete_unit_action(board, unit_id(0), first):
        return false
    return complete_unit_action(board, unit_id(0), second) and !board[0].history.action_pending

# p.58 bounded save infrastructure: zero/duplicate action handles and conflicting
# completion flags are rejected rather than redirecting a mission's effect.
fun test_core15_malformed_action_history_rejected() -> Bool:
    let board = core15_fixture()
    begin_unit_action(board, unit_id(0), false)
    if !valid_state_foundations(board):
        return false
    board[0].history.action_records[0].started_turn = 0
    if valid_state_foundations(board):
        return false
    board[0].history.action_records[0].started_turn = 1
    board[0].history.action_records[0].completed = true
    return !valid_state_foundations(board)

# Supplied appendix 01.02.04 / core pp.30/68: full-strength shocked reserves recover.
fun test_offboard_command_shocked_reserve_recovers() -> Bool:
    let board : Board
    board.reserve_units.append(make_infernus_squad())
    board.reserve_units[0].capture_starting_strength()
    board.reserve_units[0].battle_socked = true
    let step = battle_shock_step(board)
    let three : Dice
    three = 3
    if !(can step.roll_pair(board, three, three)):
        return false
    step.roll_pair(board, three, three)
    return step.is_done() and !board.reserve_units[0].battle_socked

# Supplied appendix 01.02.04 / core pp.30/86: exact half reserves also test.
fun test_offboard_command_half_reserve_fails() -> Bool:
    let board : Board
    board.reserve_units.append(make_octavius())
    board.reserve_units[0].capture_starting_strength()
    board.reserve_units[0][0].suffered_wounds = 3
    let step = battle_shock_step(board)
    let one : Dice
    one = 1
    if !(can step.roll_pair(board, one, one)):
        return false
    step.roll_pair(board, one, one)
    return step.is_done() and board.reserve_units[0].battle_socked

# Supplied appendix 01.02.04: our Command does not test healthy/foreign/empty reserves.
fun test_offboard_command_skips_ineligible_reserves() -> Bool:
    let board : Board
    board.reserve_units.append(make_infernus_squad())
    board.reserve_units[0].capture_starting_strength()
    board.reserve_units.append(make_tantus())
    board.reserve_units[1].owned_by_player1 = true
    board.reserve_units[1].battle_socked = true
    board.reserve_units.resize(3)
    let step = battle_shock_step(board)
    return step.is_done() and board.reserve_units[1].battle_socked

# Supplied appendix 01.02.04: each battlefield/offboard unit tests exactly once.
fun test_offboard_command_tests_battlefield_then_reserve() -> Bool:
    let board : Board
    board.units.append(make_infernus_squad())
    board[0].battle_socked = true
    board.reserve_units.append(make_infernus_squad())
    board.reserve_units[0].battle_socked = true
    let step = battle_shock_step(board)
    let three : Dice
    three = 3
    step.roll_pair(board, three, three)
    if step.is_done() or board[0].battle_socked or !board.reserve_units[0].battle_socked:
        return false
    step.roll_pair(board, three, three)
    return step.is_done() and !board.reserve_units[0].battle_socked

# 23.01 p.74: mandatory Aircraft reserves do not depend on optional points choices.
fun test_aircraft16_mandatory_formations_reserves() -> Bool:
    let board : Board
    board.reserve_units.append(make_infernus_squad())
    board.reserve_units.append(make_tantus())
    board.reserve_units[1][0].keywords.append(Keyword::aircraft)
    board.reserve_units[1].owned_by_player1 = true
    reserve_aircraft_for_formations(board)
    return !board.reserve_units[0].history.strategic_reserve and board.reserve_units[1].history.strategic_reserve and deployment_complete(board, true)

# 23.02 p.74: Aircraft have no Stationary/Normal/Advance/Fall Back moves.
fun test_aircraft16_only_ingress_move() -> Bool:
    let board = movement11_fixture()
    board[0][0].keywords.append(Keyword::aircraft)
    return !battlefield_move_eligible(board, unit_id(0), MovementKind::stationary) and !battlefield_move_eligible(board, unit_id(0), MovementKind::normal) and !battlefield_move_eligible(board, unit_id(0), MovementKind::advance) and !battlefield_move_eligible(board, unit_id(0), MovementKind::ordered_retreat) and movement_selection_complete(board, false)

# 23.02 p.74: round-one deferral consumes selection, never a Stationary move.
fun test_aircraft16_reserve_deferral_does_not_stall() -> Bool:
    let board : Board
    board.reserve_units.append(make_tantus())
    board.reserve_units[0][0].keywords.append(Keyword::aircraft)
    let phase = movement_phase(board)
    phase.select_reserve_unit(board, unit_id(0))
    if (can phase.reserve_remain_stationary(board)) or !(can phase.defer_aircraft_ingress(board)) or (can phase.place_at(board, board_position(5, 5))):
        return false
    phase.defer_aircraft_ingress(board)
    if !(can phase.end_move(board)):
        return false
    phase.end_move(board)
    return phase.is_done() and !board.reserve_units[0].has_moved and !board.reserve_units[0].history.has_ingressed

# 23.02 p.74: solely Aircraft engagement permits Normal and Advance.
fun test_aircraft16_engagement_exception() -> Bool:
    let board = fight14_fixture()
    board[1][0].keywords.append(Keyword::aircraft)
    if !board.is_in_melee(board[0]) or !battlefield_move_eligible(board, unit_id(0), MovementKind::normal) or !battlefield_move_eligible(board, unit_id(0), MovementKind::advance):
        return false
    board[1][0].keywords.clear()
    return !battlefield_move_eligible(board, unit_id(0), MovementKind::normal)

# 23.04 p.74: Aircraft source melee requires a FLYING target unit.
fun test_aircraft16_melee_source_requires_flying_target() -> Bool:
    let board = fight14_fixture()
    board[0][0].keywords.append(Keyword::aircraft)
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    if declaration_target_valid(board, unit_id(0), declaration, unit_id(1), true):
        return false
    board[1][0].keywords.append(Keyword::fly)
    return declaration_target_valid(board, unit_id(0), declaration, unit_id(1), true)

# 23.02 p.74 / appendix 01.02.02: only opponent Aircraft depart; effects survive.
fun test_aircraft16_opponent_turn_end_preserves_state() -> Bool:
    let board = fight14_fixture()
    board[0][0].keywords.append(Keyword::aircraft)
    board[1][0].keywords.append(Keyword::aircraft)
    board[1].battle_socked = true
    board[1].history.advanced_this_turn = true
    let identity = board[1].identity
    return_opponent_aircraft(board)
    return board.reserve_units.size() == 1 and board.reserve_units[0].identity == identity and board.reserve_units[0].battle_socked and board.reserve_units[0].history.advanced_this_turn and board.reserve_units[0].history.repositioned and board[1].empty() and board[1].retired and !board[0].empty() and valid_state_foundations(board)

# pp.68–69/74: repeated ingress restores the same slot and all identities.
fun test_aircraft16_repeated_ingress_reuses_slot() -> Bool:
    let board = movement11_fixture()
    board.current_round = 2
    board[0][0].keywords.append(Keyword::aircraft)
    let identity = board[0].identity
    for repetition in range(5):
        if !reposition_unit(board, unit_id(0)) or !battlefield_entry_available(board, board.reserve_units[0]):
            return false
        enter_from_reserves(board, unit_id(0), board_position(5, 10), MovementKind::ingress)
        if board.units.size() != 1 or board[0].identity != identity or board.reserve_units.size() != 0 or !valid_state_foundations(board):
            return false
    return true

# pp.73–74: one grounded target suffices; either Aircraft unit excludes Plunging Fire.
fun test_aircraft16_plunging_fire_exclusions_and_bounds() -> Bool:
    let board = shooting12_fixture()
    board[0][0].geometry.elevation = 3
    if !plunging_fire_applies(board, unit_id(0), 0, unit_id(1), true) or plunging_fire_applies(board, unit_id(0), 0, unit_id(1), false):
        return false
    board[0][0].keywords.append(Keyword::aircraft)
    if plunging_fire_applies(board, unit_id(0), 0, unit_id(1), true):
        return false
    board[0][0].keywords.clear()
    board[1][0].keywords.append(Keyword::aircraft)
    if plunging_fire_applies(board, unit_id(0), 0, unit_id(1), true):
        return false
    board[1][0].keywords.clear()
    for elevated_target in range(board[1].models.size()):
        board[1][elevated_target].geometry.elevation = 1
    return !plunging_fire_applies(board, unit_id(0), 0, unit_id(1), true)

# Task16 metadata/movement regressions: core pp.64–65/68–69/73–74/84;
# supplied appendix01.02.02/01.02.04 and user no-nesting assumption.
# Explicit metadata fixtures do not assert any actual faction transport grant
# (datasheets task17); capacities/types belong to each carrier model (p.64).
fun transport16_fixture() -> Board:
    let board : Board
    board.units.append(make_octavius())
    board[0][0].position = board_position(10, 10)
    board[0][0].keywords.append(Keyword::transport)
    board[0][0].keywords.append(Keyword::vehicle)
    board[0][0].transport_permissions_known = true
    board[0][0].transport_capacity = 6
    board[0][0].permitted_passenger_keywords.append(Keyword::infantry)
    board.units.append(make_infernus_squad())
    board[1].models.resize(2)
    board[1][0].position = board_position(12, 10)
    board[1][1].position = board_position(12, 12)
    board[1].capture_starting_strength()
    board.identify_units()
    board.begin_phase(BattlePhase::movement)
    record_move(board, unit_id(1), MovementKind::normal)
    return board

# Bounded fixture constructor for supplied explicit values (pp.64/81/84);
# this encodes test metadata, not a claim about any faction datasheet.
fun transport16_fixed_stat(Int number) -> FixedStat:
    let value : FixedStat
    value = number
    return value

# p.64: whole-unit permission and exact per-model seats, including weighted models.
fun test_transport16_capacity_permissions_and_seat_bounds() -> Bool:
    let board = transport16_fixture()
    if !transport_can_carry(board, board[1], board[0], 0):
        return false
    board[0][0].transport_capacity = 1
    if transport_can_carry(board, board[1], board[0], 0):
        return false
    board[0][0].transport_capacity = 3
    board[1][0].transport_space = 2
    if !transport_can_carry(board, board[1], board[0], 0):
        return false
    board[0][0].forbidden_passenger_keywords.append(Keyword::infantry)
    if transport_can_carry(board, board[1], board[0], 0):
        return false
    board[0][0].forbidden_passenger_keywords.clear()
    board[0][0].transport_permissions_known = false
    return !transport_can_carry(board, board[1], board[0], 0)

# p.64: only permitted moves, every base within3, no setup this turn.
fun test_transport16_embark_move_and_setup_gates() -> Bool:
    let board = transport16_fixture()
    let passenger = unit_id(1)
    let carrier = unit_id(0)
    let model = damage_test_model(0)
    if !embark_after_move_valid(board, passenger, carrier, model):
        return false
    board[1].history.was_set_up_this_turn = true
    if embark_after_move_valid(board, passenger, carrier, model):
        return false
    board[1].history.was_set_up_this_turn = false
    board[1].history.move_kind = MovementKind::stationary
    if embark_after_move_valid(board, passenger, carrier, model):
        return false
    board[1].history.move_kind = MovementKind::advance
    board[1][1].position = board_position(20, 20)
    return !embark_after_move_valid(board, passenger, carrier, model)

# pp.58/64 and appendix01.02.02: embarking fails actions, preserves identity,
# shock/effects and weapon usage, and retires its slot without duplicating IDs.
fun test_transport16_embark_preserves_identity_and_effects() -> Bool:
    let board = transport16_fixture()
    if !begin_unit_action(board, unit_id(1), false):
        return false
    board[1].battle_socked = true
    board[1][0].used_once_per_battle_weapon[0] = true
    let identity = board[1].identity
    let bearer = board[1][0].identity
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    return board[1].empty() and board[1].retired and board.embarked_units.size() == 1 and board.embarked_units[0].identity == identity and board.embarked_units[0][0].identity == bearer and board.embarked_units[0].battle_socked and board.embarked_units[0][0].used_once_per_battle_weapon[0] and board.embarked_units[0].history.action_failed and passenger_space_used(board, board[0][0].identity) == 2 and valid_state_foundations(board)

# p.64: carrier MODEL identities survive compaction within a multi-model unit.
fun test_transport16_carrier_identity_survives_model_compaction() -> Bool:
    let board = transport16_fixture()
    let second_carrier = board[0][0]
    second_carrier.identity = 0
    second_carrier.position = board_position(10, 12)
    board[0].models.append(second_carrier)
    board.identify_units()
    let carrier_identity = board[0][1].identity
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(1))
    board[0].remove_model(0)
    let location = find_passenger_carrier(board, carrier_identity)
    return location.found and location.model.get() == 0 and board.embarked_units[0].embarked_transport == carrier_identity and valid_state_foundations(board)

# Supplied appendix01.02.04: passengers have no foreign visibility/ranges,
# but retain self visibility/own ability range. Their old bases block no setup.
fun test_transport16_offboard_visibility_distance_and_collision() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    return !unit_visible_to_unit(board, board[0], board.embarked_units[0]) and !unit_visible_to_unit(board, board.embarked_units[0], board[0]) and unit_visible_to_unit(board, board.embarked_units[0], board.embarked_units[0]) and board.embarked_units[0][0].distance(board[0][0]) > 100.0 and board.embarked_units[0][0].distance(board.embarked_units[0][0]) == 0.0

# Appendix01.02.04 / p.30: embarked units test and recover in Command.
fun test_transport16_embarked_command_recovery() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    board.embarked_units[0].battle_socked = true
    board.begin_phase(BattlePhase::command)
    let step = battle_shock_step(board)
    let three : Dice
    three = 3
    step.roll_pair(board, three, three)
    return step.is_done() and !board.embarked_units[0].battle_socked

# Appendix01.02.02: phase effects expire offboard; shock/turn restrictions
# survive phase changes and One Shot survives both phase and turn resets.
fun test_transport16_offboard_expiry_uses_original_duration() -> Bool:
    let board = transport16_fixture()
    board[1].battle_socked = true
    board[1].phase_modifiers.smokescreen = true
    board[1][0].used_once_per_battle_weapon[0] = true
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    board.embarked_units[0].history.deck_shooting_locked = true
    board.begin_phase(BattlePhase::shooting)
    if board.embarked_units[0].phase_modifiers.smokescreen or !board.embarked_units[0].history.deck_shooting_locked or !board.embarked_units[0].battle_socked:
        return false
    board.start_turn_history()
    return !board.embarked_units[0].history.deck_shooting_locked and board.embarked_units[0].battle_socked and board.embarked_units[0][0].used_once_per_battle_weapon[0]

# p.65: same-phase embark/Advance/Fall Back forbid exit; reserved carrier does too.
fun test_transport16_disembark_phase_and_carrier_gates() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    if passenger_can_disembark(board, unit_id(0)):
        return false
    board.begin_phase(BattlePhase::movement)
    if !passenger_can_disembark(board, unit_id(0)):
        return false
    record_move(board, unit_id(0), MovementKind::advance)
    if passenger_can_disembark(board, unit_id(0)):
        return false
    if !reposition_unit(board, unit_id(0)):
        return false
    return !passenger_can_disembark(board, unit_id(0)) and board.embarked_units.size() == 1

# p.65: wholly within tests the farthest base point, not minimal base distance.
fun test_transport16_wholly_within_full_base_boundary() -> Bool:
    let board = transport16_fixture()
    board[1][0].profile = board[0][0].profile
    board[1][0].position = board_position(13, 10)
    if !passenger_wholly_within(board[1][0], board[0][0], 3):
        return false
    board[1][0].position = board_position(14, 10)
    return board[1][0].distance(board[0][0]) < 3.0 and !passenger_wholly_within(board[1][0], board[0][0], 3)

# p.65: mandatory modes choose Rapid after Normal, otherwise Tactical if legal.
fun test_transport16_mode_priority_and_exact_grid_search() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    board.begin_phase(BattlePhase::movement)
    let carrier = find_passenger_carrier(board, board.embarked_units[0].embarked_transport)
    if !(required_disembark_mode(board, board.embarked_units[0], carrier) == DisembarkMode::tactical):
        return false
    record_move(board, unit_id(0), MovementKind::normal)
    return required_disembark_mode(board, board.embarked_units[0], carrier) == DisembarkMode::rapid and transport_has_setup(board, board.embarked_units[0], carrier, DisembarkMode::rapid, -1)

# p.65: Rapid copies actual carrier ingress restrictions, not passenger Deep Strike.
fun test_transport16_rapid_inherits_carrier_ingress_rules() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    board.begin_phase(BattlePhase::movement)
    board[0].history.ingress_turn = board.turn_serial.value + 1
    board[0].history.ingress_used_deep_strike = false
    let carrier = find_passenger_carrier(board, board.embarked_units[0].embarked_transport)
    let candidate = board.embarked_units[0]
    mark_unit_offboard(candidate, false)
    candidate[0].abilities.append(AbilityKind::deep_strike)
    candidate[1].abilities.append(AbilityKind::deep_strike)
    candidate[0].position = board_position(12, 10)
    candidate[1].position = board_position(12, 12)
    if transport_setup_valid(board, candidate, carrier, DisembarkMode::rapid, -1):
        return false
    board[0].history.ingress_used_deep_strike = true
    return transport_setup_valid(board, candidate, carrier, DisembarkMode::rapid, -1)

# p.65: Tactical requires Normal/Advance afterwards; Stationary is forbidden.
fun test_transport16_tactical_requires_followup_move() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    board.begin_phase(BattlePhase::movement)
    let sequence = disembark(board, unit_id(0), false)
    sequence.confirm_disembark_mode(board, DisembarkMode::tactical)
    sequence.use_legal_disembark_setup(board)
    if !sequence.is_done() or !sequence.completed:
        return false
    let followup = movement(board, sequence.passenger_slot, false)
    if (can followup.remain_stationary(board)) or !(can followup.normal_move(board)) or !(can followup.advance(board, true)):
        return false
    followup.normal_move(board)
    followup.finish_move(board)
    return followup.is_done() and board.embarked_units.size() == 0 and board[1].history.disembarked_this_turn and board[1].history.move_kind == MovementKind::normal and valid_state_foundations(board)

# p.65: Rapid completes setup, forbids charge, and preserves original slot.
fun test_transport16_rapid_action_reuses_passenger_slot() -> Bool:
    let board = transport16_fixture()
    let identity = board[1].identity
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    board.begin_phase(BattlePhase::movement)
    record_move(board, unit_id(0), MovementKind::normal)
    let sequence = disembark(board, unit_id(0), false)
    if (can sequence.confirm_disembark_mode(board, DisembarkMode::combat)):
        return false
    sequence.confirm_disembark_mode(board, DisembarkMode::rapid)
    sequence.use_legal_disembark_setup(board)
    return sequence.is_done() and board[1].identity == identity and !board[1].can_charge and board[1].history.was_set_up_this_turn and !board[1].off_battlefield and board.units.size() == 2 and valid_state_foundations(board)

# p.68: passengers add to reserve points and share carrier deadline.
fun test_transport16_reserve_points_include_passengers() -> Bool:
    let board = transport16_fixture()
    board.battle_points_limit = 400
    board[0].points_known = true
    board[0].points = 100
    board[1].points_known = true
    board[1].points = 101
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    if !reposition_unit(board, unit_id(0)):
        return false
    board.reserve_units[0].history.strategic_reserve = false
    if strategic_reserve_valid(board, false, unit_id(0)):
        return false
    board.embarked_units[0].points = 100
    if !strategic_reserve_valid(board, false, unit_id(0)):
        return false
    board.embarked_units[0].points_known = false
    return !strategic_reserve_valid(board, false, unit_id(0))

# p.68–69: undeployed reserved passengers perish with their carrier, without ingress.
fun test_transport16_passengers_share_reserve_deadline() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    if !reposition_unit(board, unit_id(0)):
        return false
    board.reserve_units[0].history.repositioned = false
    board.current_round = 2
    expire_unused_reserves(board)
    return board.reserve_units.empty() and board.embarked_units.empty() and board.expired_reserves.value.size() == 2

# p.84: Dedicated Transport Scouts require every passenger and uniform values.
fun test_transport16_dedicated_transport_scouts_permission() -> Bool:
    let board = transport16_fixture()
    board[0][0].keywords.append(Keyword::dedicated_transport)
    board[0][0].position = board_position(10, 26)
    board[1][0].position = board_position(12, 26)
    board[1][1].position = board_position(12, 28)
    board[1][0].scout_distances.append(transport16_fixed_stat(6))
    board[1][1].scout_distances.append(transport16_fixed_stat(6))
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    if transport_scouts_distance(board, board[0]) != 6:
        return false
    board.embarked_units[0][1].scout_distances.clear()
    return transport_scouts_distance(board, board[0]) == 0

# Save infrastructure p.64: dangling/overfilled/foreign passenger links are rejected.
fun test_transport16_invalid_passenger_links_rejected() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    board[0][0].transport_capacity = 1
    if valid_state_foundations(board):
        return false
    board[0][0].transport_capacity = 6
    board.embarked_units[0].owned_by_player1 = true
    if valid_state_foundations(board):
        return false
    board.embarked_units[0].owned_by_player1 = false
    board.embarked_units[0].embarked_transport = 16000
    return !valid_state_foundations(board)

# p.64: qualifying out-of-phase moves can embark too, with source-controller
# decisions, caller restoration, and no prebattle Scouts embark exception.
fun test_transport16_out_of_phase_embark_owner_and_prebattle_gate() -> Bool:
    let board = transport16_fixture()
    board.current_player = true
    board.current_decision_maker = true
    board.timing.phase = BattlePhase::shooting
    if !has_embark_choice(board, unit_id(1)):
        return false
    let sequence = post_move_embark(board, unit_id(1))
    if board.current_decision_maker or !(can sequence.choose_embark_transport(board, unit_id(0))):
        return false
    sequence.decline_embark(board)
    if !sequence.is_done() or !board.current_decision_maker:
        return false
    board.prebattle_scouts = true
    return !has_embark_choice(board, unit_id(1))

# p.64: prebattle formation choices are whole-unit decisions and preserve IDs.
fun test_transport16_formation_action_starts_embarked() -> Bool:
    let board = transport16_fixture()
    board.reserve_units.append(board[0])
    board.reserve_units.append(board[1])
    board.units.clear()
    board.timing.phase = BattlePhase::none
    board.identify_units()
    let identity = board.reserve_units[1].identity
    let sequence = declare_transport_passengers(board)
    sequence.choose_formation_passenger(board, unit_id(1))
    sequence.choose_formation_transport(board, unit_id(0))
    sequence.choose_formation_carrier_model(board, damage_test_model(0))
    sequence.finish_transport_formations(board)
    return sequence.is_done() and board.embarked_units.size() == 1 and board.embarked_units[0].identity == identity and board.reserve_units.size() == 1 and valid_state_foundations(board)

# p.65: Combat becomes compulsory when enemy engagement blocks all Tactical
# placements; only enemies actually engaged with the carrier are allowed.
fun test_transport16_combat_priority_and_enemy_permissions() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    let enemies = make_infernus_squad()
    enemies.models.resize(4)
    enemies.owned_by_player1 = true
    enemies[0].position = board_position(7, 10)
    enemies[1].position = board_position(13, 10)
    enemies[2].position = board_position(10, 7)
    enemies[3].position = board_position(10, 13)
    board.units.append(enemies)
    board.identify_units()
    board.begin_phase(BattlePhase::movement)
    let carrier = find_passenger_carrier(board, board.embarked_units[0].embarked_transport)
    if !(required_disembark_mode(board, board.embarked_units[0], carrier) == DisembarkMode::combat):
        return false
    let sequence = disembark(board, unit_id(0), false)
    sequence.confirm_disembark_mode(board, DisembarkMode::combat)
    sequence.roll(board, attack_test_die(3))
    sequence.roll(board, attack_test_die(3))
    sequence.use_legal_disembark_setup(board)
    return sequence.is_done() and board[1].battle_socked and !board[1].can_charge and board.is_in_melee(board[1]) and valid_state_foundations(board)

# p.64 datasheet permissions must reject forbidden transport passengers before
# the user-directed no-nested-transports assertion can fire during enumeration.
fun test_transport16_type_rejection_precedes_nesting_assertion() -> Bool:
    let board = transport16_fixture()
    let outer = board[0]
    outer.identity = 0
    outer[0].identity = 0
    outer[0].position = board_position(10, 15)
    outer[0].forbidden_passenger_keywords.append(Keyword::transport)
    board.units.append(outer)
    board.identify_units()
    return !transport_can_carry(board, board[0], board[2], 0) and valid_state_foundations(board)
# pp.73–74: TOWERING range is inclusive12 and skill improvements coexist
# with cover; Aircraft exclusions are checked before grouping attack profiles.
fun test_aircraft16_towering_plunging_range_and_skill() -> Bool:
    let board = shooting12_fixture()
    board[0][0].position = board_position(5, 5)
    board[1][0].position = board_position(17, 5)
    board[0][0].keywords.append(Keyword::towering)
    if !plunging_fire_applies(board, unit_id(0), 0, unit_id(1), true):
        return false
    board[1][0].position = board_position(20, 5)
    if plunging_fire_applies(board, unit_id(0), 0, unit_id(1), true):
        return false
    let info : AttackSequenceInfo
    info.source = Weapon::captain_storm_bolter
    info.plunging_fire = true
    let improved = effective_attack_skill(board, info)
    info.target_has_cover = true
    return improved == max(2, info.source.skill() - 1) and effective_attack_skill(board, info) == info.source.skill()

# Emergency lifecycle regressions: hazards/setup before carrier demise/removal
# (core pp.64–65/80/87; supplied offboard appendix01.02.04).
# p.65: emergency precedes carrier Deadly Demise, including hazard choices.
fun test_transport16_emergency_before_deadly_demise() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    board[0][0].has_deadly_demise = true
    board[0][0].deadly_demise = transport16_fixed_stat(1)
    let job = damage_job(DamageKind::normal, unit_id(0), unit_id(0), false, false, 6, board[0][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 6, false)
    let jobs : DamageJobs
    let sequence = resolve_damage_jobs(board, jobs, false, unit_id(0))
    sequence.choose_destruction_unit(board, unit_id(0))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    if !(can sequence.choose_emergency_passenger(board, unit_id(0))):
        return false
    sequence.choose_emergency_passenger(board, unit_id(0))
    let three : Dice
    three = 3
    sequence.roll(board, three)
    if board.embarked_units.size() != 0 or !board[1].off_battlefield:
        return false
    sequence.roll(board, three)
    let one : Dice
    one = 1
    if board[1].off_battlefield or !board[1].battle_socked or board[1].can_charge or !(can sequence.roll(board, one)):
        return false
    sequence.roll(board, one)
    return sequence.is_done() and board[0].empty() and board[1].models.size() == 2 and valid_state_foundations(board)

# p.64–65: even a carrier without Deadly Demise is retained for emergency exit.
fun test_transport16_emergency_retains_plain_carrier() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    let job = damage_job(DamageKind::normal, unit_id(0), unit_id(0), false, false, 6, board[0][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 6, false)
    return board[0][0].destruction_pending and carrier_has_passengers(board, board[0][0].identity)

# p.65: no legal supported placement destroys passengers instead of stalling.
fun test_transport16_emergency_unplaceable_models_destroyed() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    board.terrain_geometry.append(geometry_box(0, 0, 0, BOARD_WIDTH, BOARD_HEIGHT, 20))
    let carrier = find_passenger_carrier(board, board.embarked_units[0].embarked_transport)
    let original = board.embarked_units[0]
    let candidate : Unit
    arrange_emergency_survivors(board, original, candidate, carrier, -1)
    return candidate.empty()

# p.65: hazards allocate before placing passengers; one failed infantry roll
# inflicts one mortal, then survivors are shocked with the charge ban.
fun test_transport16_emergency_hazard_damage_before_setup() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    let job = damage_job(DamageKind::normal, unit_id(0), unit_id(0), false, false, 6, board[0][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 6, false)
    let jobs : DamageJobs
    let sequence = resolve_damage_jobs(board, jobs, false, unit_id(0))
    sequence.choose_destruction_unit(board, unit_id(0))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    sequence.choose_emergency_passenger(board, unit_id(0))
    sequence.roll(board, attack_test_die(1))
    sequence.roll(board, attack_test_die(3))
    if !board[1].off_battlefield or !(can sequence.select_mortal_model(board, damage_test_model(0))):
        return false
    sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and !board[1].off_battlefield and board[1][0].suffered_wounds == 1 and board[1].battle_socked and !board[1].can_charge and valid_state_foundations(board)

# p.65: actual emergency resolution archives every unplaceable survivor and
# completes the carrier's removal, rather than hanging at a setup choice.
fun test_transport16_emergency_unplaceable_resolution_archives() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    board.terrain_geometry.append(geometry_box(0, 0, 0, BOARD_WIDTH, BOARD_HEIGHT, 20))
    let job = damage_job(DamageKind::normal, unit_id(0), unit_id(0), false, false, 6, board[0][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 6, false)
    let jobs : DamageJobs
    let sequence = resolve_damage_jobs(board, jobs, false, unit_id(0))
    sequence.choose_destruction_unit(board, unit_id(0))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    sequence.choose_emergency_passenger(board, unit_id(0))
    sequence.roll(board, attack_test_die(3))
    sequence.roll(board, attack_test_die(3))
    return sequence.is_done() and board[0].empty() and board[1].empty() and board[1].destroyed_models.value.size() == 2 and board.embarked_units.empty() and valid_state_foundations(board)

# Firing Deck regressions: per-model X, weapon attribution and passenger
# turn-long shooting restrictions (24.14 p.81).
# p.81: Firing Deck counts chosen models per carrier and excludes already-shot units.
fun test_transport16_firing_deck_model_limits() -> Bool:
    let board = transport16_fixture()
    board[0][0].firing_deck = 1
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    let selected : DeckSelections
    if !deck_passenger_valid(board, unit_id(0), damage_test_model(0), unit_id(0), damage_test_model(0), selected):
        return false
    let choice : DeckSelection
    choice.carrier = board[0][0].identity
    choice.passenger_model = board.embarked_units[0][0].identity
    selected.append(choice)
    if deck_passenger_valid(board, unit_id(0), damage_test_model(0), unit_id(0), damage_test_model(1), selected):
        return false
    selected.clear()
    board.embarked_units[0].history.shot_this_phase = true
    return !deck_passenger_valid(board, unit_id(0), damage_test_model(0), unit_id(0), damage_test_model(0), selected)

# p.81: ONE SHOT is excluded, weapons are attributed to the carrier, and
# physical passenger/carrier weapon slots and One Shot usage stay untouched.
fun test_transport16_firing_deck_weapon_provenance() -> Bool:
    let board = transport16_fixture()
    board[0][0].firing_deck = 1
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    let declarations : DeclaredWeapons
    if !deck_weapon_valid(board, unit_id(0), damage_test_model(0), unit_id(0), damage_test_model(0), 0, declarations):
        return false
    let weapon = make_deck_declaration(board, unit_id(0), damage_test_model(0), unit_id(0), damage_test_model(0), 0)
    if weapon.model_identity != board[0][0].identity or weapon.weapon.value != board.embarked_units[0][0].weapons[0].profile.value:
        return false
    board.embarked_units[0][0].additional_weapon_rules[0].append(weapon_rule(WeaponRuleKind::one_shot))
    return !deck_weapon_valid(board, unit_id(0), damage_test_model(0), unit_id(0), damage_test_model(0), 0, declarations) and !board.embarked_units[0][0].used_once_per_battle_weapon[0]

# p.81: even unselected passengers are locked until turn end, including after exit.
fun test_transport16_firing_deck_locks_all_passengers() -> Bool:
    let board = transport16_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    lock_deck_passengers(board, board[0][0].identity)
    let slot = stage_disembarking_passenger(board, unit_id(0))
    finish_disembark(board, slot, DisembarkMode::rapid)
    if shooting_unit_valid(board, slot) or !board[slot].history.deck_shooting_locked:
        return false
    board.begin_phase(BattlePhase::fight)
    if !board[slot].history.deck_shooting_locked:
        return false
    board.start_turn_history()
    return !board[slot].history.deck_shooting_locked

# p.81: deck selection appends temporary declarations through explicit
# passenger/model/weapon decisions and consumes X without consuming One Shot.
fun test_transport16_firing_deck_action_selection() -> Bool:
    let board = transport16_fixture()
    board[0][0].firing_deck = 1
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    let declarations : DeclaredWeapons
    let sequence = select_firing_deck(board, declarations, unit_id(0))
    sequence.select_firing_deck_passenger(board, declarations, unit_id(0))
    sequence.select_firing_deck_model(board, declarations, damage_test_model(0))
    let slot : BInt<0, MAX_WEAPONS>
    slot = 0
    sequence.select_firing_deck_weapon(board, declarations, slot)
    sequence.finish_firing_deck(board, declarations)
    return sequence.is_done() and declarations.size() == 1 and declarations[0].model_identity == board[0][0].identity and board.embarked_units[0].history.deck_shooting_locked and !board.embarked_units[0][0].used_once_per_battle_weapon[0]

# Appendix02.02.01/02.02.03: fixed A uses bearer/profile arithmetic before
# declaration and random A/D preserve their original dice until after re-rolls.
fun test_orks17c2b2_modified_melee_shares() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::choppa
    board[0][0].characteristic_modifiers.append(weapon_characteristic_modifier(ModifiedCharacteristic::attacks, ModifierOperation::add, 2, 0))
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let count = declaration_fixed_attacks(board, unit_id(0), declaration, 0)
    return count == 5

# Core increments enter addition before division, including random results.
fun test_orks17c2b2_random_arithmetic_after_reroll() -> Bool:
    let board = attack_declaration_fixture()
    board.command_points[0] = 2
    let modifiers : RuleModifiers
    modifiers.append(rule_modifier(ModifierOperation::multiply, 2))
    modifiers.append(rule_modifier(ModifierOperation::divide, 2))
    let characteristic = evaluate_weapon_characteristic(board, dice_stat(6), 3, false, unit_id(0), modifiers, ModifiedCharacteristic::damage)
    characteristic.quantity(board, attack_test_die(1))
    characteristic.keep_it(board, false)
    characteristic.reroll(board, attack_test_die(4))
    return characteristic.is_done() and characteristic.result.value == 6 and board.command_points[0] == 1

# Fixed D differences disappear when cumulative operations give the same D.
fun test_orks17c2b2_effective_fixed_damage_grouping() -> Bool:
    let left : AttackSequenceInfo
    let right : AttackSequenceInfo
    left.source = Weapon::librarian_storm_bolter
    right.source = left.source
    left.damage_modifiers.append(rule_modifier(ModifierOperation::add, 2))
    if same_effective_damage(left, right):
        return false
    right.damage_modifiers.append(rule_modifier(ModifierOperation::multiply, 3))
    return same_effective_damage(left, right)

# Comparing only one die face is insufficient for random D group identity.
fun test_orks17c2b2_random_damage_grouping_all_faces() -> Bool:
    let left : AttackSequenceInfo
    let right : AttackSequenceInfo
    left.source = Weapon::smite_witchfire
    right.source = left.source
    left.damage_modifiers.append(rule_modifier(ModifierOperation::multiply, 2))
    right.damage_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    return !same_effective_damage(left, right)

# A zero replacement is locked against later additions by appendix02.02.01.
fun test_orks17c2b2_zero_damage_replacement_locked() -> Bool:
    let board = attack_declaration_fixture()
    let modifiers : RuleModifiers
    modifiers.append(rule_modifier(ModifierOperation::replace, 0))
    let characteristic = evaluate_weapon_characteristic(board, raw_stat(2), 4, false, unit_id(0), modifiers, ModifiedCharacteristic::damage)
    return characteristic.is_done() and characteristic.result.value == 0

# Scoped D is captured from the actual selected bearer, including Firing Deck.
fun test_orks17c2b2_damage_snapshot_scope() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.append(equipped_weapon(Weapon::librarian_storm_bolter))
    board[0][0].characteristic_modifiers.append(weapon_characteristic_modifier(ModifiedCharacteristic::damage, ModifierOperation::add, 2, 0))
    let first = orks17c2b_info(board, 0)
    let second = orks17c2b_info(board, 1)
    return first.damage_modifiers.size() == 1 and second.damage_modifiers.empty()

# p.17: the actual share selector exposes modified A and gathering must not
# apply it a second time to each split share.
fun test_orks17c2b2_melee_share_selector_and_gathering() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::choppa
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::attacks, ModifierOperation::multiply, 2))
    board[1][0].position = board[0][0].position
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let targets = declare_weapon_targets(board, declaration, unit_id(0), true)
    targets.declare_target(board, unit_id(0), unit_id(1))
    let share : AttackShareChoice
    share = 6
    targets.assign_attacks(board, share)
    let gathered = gather_weapon_count(board, unit_id(0), unit_id(1), targets.weapon, true)
    return targets.is_done() and gathered.is_done() and gathered.result.value == 6

# Random ranged A is modified per weapon at gathering, not at declaration.
fun test_orks17c2b2_random_attacks_gathering() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::smite_witchfire
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::attacks, ModifierOperation::multiply, 2))
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let gathered = gather_weapon_count(board, unit_id(0), unit_id(1), declaration, false)
    gathered.quantity(board, attack_test_die(3))
    return gathered.is_done() and gathered.result.value == 6

# D modifiers are consumed by actual allocated damage, not just group labels.
fun test_orks17c2b2_allocated_damage_uses_modifier() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.damage_modifiers.append(rule_modifier(ModifierOperation::replace, 0))
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1))
    let model : ModelID
    damage.allocate_mortal(board, board[1], board[0], model)
    return damage.is_done() and board[1][0].suffered_wounds == 0

# Appendix02.02.01: replacing A by zero permits no melee share and must not
# strand the declaration at an input boundary with no legal choices.
fun test_orks17c2b2_zero_melee_attacks_no_selector() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::choppa
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::attacks, ModifierOperation::replace, 0))
    board[1][0].position = board[0][0].position
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let targets = declare_weapon_targets(board, declaration, unit_id(0), true)
    return targets.is_done()

# p.17: a multiplied A is split once; both targets keep their declared share.
fun test_orks17c2b2_modified_melee_split_not_multiplied_twice() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::choppa
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::attacks, ModifierOperation::multiply, 2))
    board[1][0].position = board[0][0].position
    board[2][0].position = board[0][0].position
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let targets = declare_weapon_targets(board, declaration, unit_id(0), true)
    targets.declare_target(board, unit_id(0), unit_id(1))
    targets.assign_attacks(board, attack_test_share(3))
    targets.declare_target(board, unit_id(0), unit_id(2))
    targets.assign_attacks(board, attack_test_share(3))
    let first = gather_weapon_count(board, unit_id(0), unit_id(1), targets.weapon, true)
    let second = gather_weapon_count(board, unit_id(0), unit_id(2), targets.weapon, true)
    return targets.is_done() and first.result.value == 3 and second.result.value == 3

# Appendix02.02.03: actual random D still waits for allocation and then
# applies operations to the selected original die before inflicting damage.
fun test_orks17c2b2_random_allocated_damage_uses_modifier() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.source = Weapon::smite_witchfire
    board.attack_info.damage_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1))
    if can damage.quantity(board, board[1], board[0], attack_test_die(2)):
        return false
    let model : ModelID
    damage.allocate_mortal(board, board[1], board[0], model)
    damage.quantity(board, board[1], board[0], attack_test_die(2))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Named selectors use audited identities, not uncertified legacy stats. This
# fixture deliberately tags generic profiles for selector/consumer regressions.
fun named17c2c_fixture() -> Board:
    let board = attack_declaration_fixture()
    board[0][0].weapons.clear()
    for slot in range(4):
        board[0][0].weapons.append(equipped_weapon(Weapon::captain_storm_bolter))
    board[0][0].weapons[0].profile = Weapon::orks_meganobz_kustom_shoota_aimed
    board[0][0].weapons[1].profile = Weapon::orks_meganobz_kustom_shoota_point_blank
    board[0][0].weapons[2].profile = Weapon::orks_meganobz_kustom_shoota_aimed
    board[0][0].weapons[3].profile = Weapon::orks_slugga
    board[0][0].weapons[0].secondary_profile_of = 0
    board[0][0].weapons[1].secondary_profile_of = 1
    board[0][0].weapons[2].secondary_profile_of = 0
    set_model_datasheet(board[0][0], OrksDatasheet::big_mek_in_mega_armour)
    return board

# Appendix04.01.03: all alternate profiles and copies share the named family.
fun test_named17c2c_family_grant_all_profiles_and_copies() -> Bool:
    let board = named17c2c_fixture()
    board[0][0].characteristic_modifiers.append(weapon_family_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, Weapon::orks_kustom_shoota))
    let first = orks17c2b_info(board, 0)
    let alternate = orks17c2b_info(board, 1)
    let copy = orks17c2b_info(board, 2)
    let unrelated = orks17c2b_info(board, 3)
    return first.attack_strength() == 6 and alternate.attack_strength() == 6 and copy.attack_strength() == 6 and unrelated.attack_strength() == 4

# A named profile restriction excludes a different profile of the same family.
fun test_named17c2c_profile_grant_excludes_alternate() -> Bool:
    let board = named17c2c_fixture()
    board[0][0].characteristic_modifiers.append(weapon_profile_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, Weapon::orks_meganobz_kustom_shoota_aimed))
    let first = orks17c2b_info(board, 0)
    let alternate = orks17c2b_info(board, 1)
    let copy = orks17c2b_info(board, 2)
    return first.attack_strength() == 6 and alternate.attack_strength() == 4 and copy.attack_strength() == 6

# A physical-instance grant includes its alternate but excludes a second copy.
fun test_named17c2c_physical_grant_distinguishes_copy() -> Bool:
    let board = named17c2c_fixture()
    board[0][0].characteristic_modifiers.append(physical_weapon_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, 0))
    let first = orks17c2b_info(board, 0)
    let alternate = orks17c2b_info(board, 1)
    let copy = orks17c2b_info(board, 2)
    return first.attack_strength() == 6 and alternate.attack_strength() == 6 and copy.attack_strength() == 4

# Group0 means an independent slot, never every other zero-group slot.
fun test_named17c2c_zero_group_selects_only_its_slot() -> Bool:
    let board = named17c2c_fixture()
    board[0][0].weapons[0].secondary_profile_of = 0
    board[0][0].weapons[1].secondary_profile_of = 0
    board[0][0].characteristic_modifiers.append(physical_weapon_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, 0))
    let first = orks17c2b_info(board, 0)
    let alternate = orks17c2b_info(board, 1)
    return first.attack_strength() == 6 and alternate.attack_strength() == 4

# Slot/family/profile predicates are conjunctive, not alternatives.
fun test_named17c2c_conjunctive_selectors() -> Bool:
    let board = named17c2c_fixture()
    let grant = weapon_family_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, Weapon::orks_kustom_shoota)
    grant.weapon_scope = 1
    grant.physical_scope = true
    grant.profile_name = Weapon::orks_meganobz_kustom_shoota_point_blank.value
    board[0][0].characteristic_modifiers.append(grant)
    let first = orks17c2b_info(board, 0)
    let alternate = orks17c2b_info(board, 1)
    let copy = orks17c2b_info(board, 2)
    return first.attack_strength() == 4 and alternate.attack_strength() == 6 and copy.attack_strength() == 4

# Unknown identity does not accidentally grant a named bonus to legacy models.
fun test_named17c2c_unknown_weapon_never_matches_name() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].characteristic_modifiers.append(weapon_family_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, Weapon::orks_kustom_shoota))
    let info = orks17c2b_info(board, 0)
    return info.attack_strength() == 4 and !model_matches_datasheet(board[0][0], OrksDatasheet::unknown)

# Actual targeting consumes named Range, not only attack-context snapshots.
fun test_named17c2c_named_range_target_legality() -> Bool:
    let board = named17c2c_fixture()
    board[1][0].position = board_position(30, 5)
    let old = make_declared_weapon(board, unit_id(0), 0, 0)
    if declaration_target_valid(board, unit_id(0), old, unit_id(1), false):
        return false
    board[0][0].characteristic_modifiers.append(weapon_family_modifier(ModifiedCharacteristic::range, ModifierOperation::add, 10, Weapon::orks_kustom_shoota))
    return declaration_target_valid(board, unit_id(0), old, unit_id(1), false)

# Named A/D reach the previous batch's real gathering and allocated snapshots.
fun test_named17c2c_named_attacks_and_damage_consumers() -> Bool:
    let board = named17c2c_fixture()
    board[0][0].characteristic_modifiers.append(weapon_family_modifier(ModifiedCharacteristic::attacks, ModifierOperation::add, 2, Weapon::orks_kustom_shoota))
    board[0][0].characteristic_modifiers.append(weapon_profile_modifier(ModifiedCharacteristic::damage, ModifierOperation::add, 1, Weapon::orks_meganobz_kustom_shoota_aimed))
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let count = gather_weapon_count(board, unit_id(0), unit_id(1), declaration, false)
    let info = orks17c2b_info(board, 0)
    return count.is_done() and count.result.value == 6 and info.damage_modifiers.size() == 1

# Appendix02.05.01: mixed unit identity is a union, model identity stays local.
fun test_named17c2c_unit_and_model_datasheet_scope() -> Bool:
    let unit = make_infernus_squad()
    set_model_datasheet(unit[0], OrksDatasheet::boyz)
    set_model_datasheet(unit[1], OrksDatasheet::big_mek_with_shokk_attack_gun)
    return unit_matches_datasheet(unit, OrksDatasheet::boyz) and unit_matches_datasheet(unit, OrksDatasheet::big_mek_with_shokk_attack_gun) and !model_matches_datasheet(unit[0], OrksDatasheet::big_mek_with_shokk_attack_gun) and !unit_matches_datasheet(unit, OrksDatasheet::unknown)

# Datasheet-filtered model grants must not buff unrelated attached constituents.
fun test_named17c2c_datasheet_model_grant_is_local() -> Bool:
    let unit = make_infernus_squad()
    set_model_datasheet(unit[0], OrksDatasheet::boyz)
    let grant = characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 2)
    grant_datasheet_characteristic(unit, OrksDatasheet::boyz, grant)
    return unit[0].effective_toughness() == 6 and unit[1].effective_toughness() == 4

# Named rule grants reach actual selected declarations (p.78/04.01.03).
fun test_named17c2c_named_weapon_rule_consumers() -> Bool:
    let board = named17c2c_fixture()
    grant_weapon_family_rule(board[0][0], Weapon::orks_kustom_shoota, weapon_rule(WeaponRuleKind::precision))
    let first = make_declared_weapon(board, unit_id(0), 0, 0)
    let alternate = make_declared_weapon(board, unit_id(0), 0, 1)
    let unrelated = make_declared_weapon(board, unit_id(0), 0, 3)
    return declared_weapon_has_kind(first, WeaponRuleKind::precision) and declared_weapon_has_kind(alternate, WeaponRuleKind::precision) and !declared_weapon_has_kind(unrelated, WeaponRuleKind::precision)

# Profile and physical rule grants remain narrower than a family grant.
fun test_named17c2c_profile_and_physical_rules() -> Bool:
    let board = named17c2c_fixture()
    grant_weapon_profile_rule(board[0][0], Weapon::orks_meganobz_kustom_shoota_point_blank, weapon_rule(WeaponRuleKind::ignore_cover))
    grant_physical_weapon_rule(board[0][0], 0, weapon_rule(WeaponRuleKind::precision))
    let first = make_declared_weapon(board, unit_id(0), 0, 0)
    let alternate = make_declared_weapon(board, unit_id(0), 0, 1)
    let copy = make_declared_weapon(board, unit_id(0), 0, 2)
    return !declared_weapon_has_kind(first, WeaponRuleKind::ignore_cover) and declared_weapon_has_kind(alternate, WeaponRuleKind::ignore_cover) and declared_weapon_has_kind(alternate, WeaponRuleKind::precision) and !declared_weapon_has_kind(copy, WeaponRuleKind::precision)

# Identity and name predicates must survive archives and text saves.
fun test_named17c2c_archive_keeps_datasheet_and_weapon_identity() -> Bool:
    let board = named17c2c_fixture()
    board[0].remove_model(0)
    ref archived = board[0].destroyed_models.value[0]
    return model_matches_datasheet(archived, OrksDatasheet::big_mek_in_mega_armour) and archived.weapons[0].profile.family_id() == Weapon::orks_kustom_shoota.value and valid_model_numeric_history(archived)

# Reject conflicting profile/family tags instead of accepting a false selector.
fun test_named17c2c_invalid_family_profile_metadata_rejected() -> Bool:
    let board = named17c2c_fixture()
    board[0][0].weapons[0].profile = Weapon::orks_slugga
    return !valid_model_numeric_history(board[0][0])

# Grouped alternate profiles must share their printed physical family.
fun test_named17c2c_invalid_group_family_rejected() -> Bool:
    let board = named17c2c_fixture()
    board[0][0].weapons[3].secondary_profile_of = 1
    return !valid_model_numeric_history(board[0][0])

# Raw values can bypass bounded assignment on restore; reject both catalogs.
fun test_named17c2c_invalid_catalog_codes_rejected() -> Bool:
    let board = named17c2c_fixture()
    board[0][0].datasheet.value = MAX_DATASHEETCODE
    if valid_model_numeric_history(board[0][0]):
        return false
    board[0][0].datasheet = 0
    board[0][0].weapons[0].profile.value = -1
    return !valid_model_numeric_history(board[0][0])

# Named or physical selectors cannot be attached to a model-only statistic.
fun test_named17c2c_invalid_named_grant_metadata_rejected() -> Bool:
    let grant = characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 1)
    grant.weapon_name = Weapon::orks_slugga.value
    let grants : CharacteristicModifiers
    grants.append(grant)
    return !valid_characteristic_modifiers(grants)

# A physical selector must specify an owned representative slot.
fun test_named17c2c_invalid_physical_scope_rejected() -> Bool:
    let grant = characteristic_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 1)
    grant.physical_scope = true
    let grants : CharacteristicModifiers
    grants.append(grant)
    return !valid_characteristic_modifiers(grants)

# Firing Deck keeps the passenger profile identity, while numerical grants
# belong to the carrier (p.81). A coincident carrier slot grant is excluded.
fun test_named17c2c_borrowed_named_grant_uses_passenger_identity() -> Bool:
    let board = named17c2c_fixture()
    let passenger = board[0]
    board.embarked_units.append(passenger)
    board[0][0].characteristic_modifiers.append(weapon_family_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, Weapon::orks_kustom_shoota))
    board[0][0].characteristic_modifiers.append(physical_weapon_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 10, 0))
    board.embarked_units[0][0].characteristic_modifiers.append(weapon_family_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 20, Weapon::orks_kustom_shoota))
    let declaration = make_deck_declaration(board, unit_id(0), damage_test_model(0), unit_id(0), damage_test_model(0), 1)
    let info = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    return info.attack_strength() == 6 and declaration.weapon_name.value == Weapon::orks_kustom_shoota.value and declaration.profile_name.value == Weapon::orks_meganobz_kustom_shoota_point_blank.value

# A carrier's equipped name is not the identity of a borrowed weapon.
fun test_named17c2c_borrowed_unrelated_name_does_not_match() -> Bool:
    let board = named17c2c_fixture()
    board.embarked_units.append(board[0])
    board[0][0].characteristic_modifiers.append(weapon_family_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, Weapon::orks_kustom_shoota))
    let declaration = make_deck_declaration(board, unit_id(0), damage_test_model(0), unit_id(0), damage_test_model(0), 3)
    let info = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    return info.attack_strength() == 4

# Declarations retain their selected profile's name despite later metadata
# changes; currently source effects still use the live bearer (pp.16–17).
fun test_named17c2c_declaration_identity_is_snapshot() -> Bool:
    let board = named17c2c_fixture()
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    board[0][0].weapons[0].secondary_profile_of = 0
    board[0][0].weapons[1].secondary_profile_of = 0
    board[0][0].weapons[0].profile = Weapon::orks_slugga
    board[0][0].characteristic_modifiers.append(weapon_family_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, Weapon::orks_kustom_shoota))
    let info = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    return info.attack_strength() == 6

# Real Game saves preserve catalog codes, physical scope and effective queries.
fun test_named17c2c_saved_name_and_grant_round_trip() -> Bool:
    let state = play()
    state.board = named17c2c_fixture()
    state.board[0][0].characteristic_modifiers.append(weapon_family_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, Weapon::orks_kustom_shoota))
    let restored = play()
    if !set_state(restored, to_string(state)):
        return false
    let info = orks17c2b_info(restored.board, 1)
    return model_matches_datasheet(restored.board[0][0], OrksDatasheet::big_mek_in_mega_armour) and info.attack_strength() == 6

# Catalog enums are used transiently; stored codes have exactly their domain.
fun test_named17c2c_catalog_bounds_and_profile_family() -> Bool:
    let datasheet : OrksDatasheet
    let weapon : Weapon
    let profile : Weapon
    let family = weapon_family(Weapon::orks_meganobz_kustom_shoota_point_blank)
    return max(datasheet) + 1 == MAX_DATASHEETCODE and max(weapon) + 1 == MAX_WEAPON_CODE and max(profile) + 1 == MAX_WEAPON_CODE and family.value == Weapon::orks_kustom_shoota.value

# Squighog Boyz Stikka is printed once in each attack table. Same-name
# ranged/melee profiles require distinct identity (datasheet/04.01.03):
# https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
fun test_named17c2c_same_printed_name_distinct_attack_profiles() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.append(equipped_weapon(Weapon::choppa))
    board[0][0].weapons[0].profile = Weapon::orks_stikka_ranged
    board[0][0].weapons[1].profile = Weapon::orks_stikka_melee
    board[0][0].characteristic_modifiers.append(weapon_profile_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 2, Weapon::orks_stikka_melee))
    let ranged = orks17c2b_info(board, 0)
    let melee = orks17c2b_info(board, 1)
    return ranged.attack_strength() == 5 and melee.attack_strength() == 7 and board[0][0].weapons[0].profile.family_id() == board[0][0].weapons[1].profile.family_id() and valid_model_numeric_history(board[0][0])

# One catalog makes mismatched attack-kind tags unrepresentable. Selection
# must follow the actual installed profile when it changes (core p16).
fun test_named17c2c_profile_attack_kind_metadata_rejected() -> Bool:
    let board = attack_declaration_fixture()
    let selected : Bool[MAX_WEAPONS]
    board[0][0].weapons[0].profile = Weapon::orks_stikka_ranged
    let ranged = weapon_selection_valid(board, unit_id(0), 0, 0, false, selected, false) and !weapon_selection_valid(board, unit_id(0), 0, 0, true, selected, false)
    board[0][0].weapons[0].profile = Weapon::orks_stikka_melee
    return ranged and valid_model_numeric_history(board[0][0]) and !weapon_selection_valid(board, unit_id(0), 0, 0, false, selected, false) and weapon_selection_valid(board, unit_id(0), 0, 0, true, selected, false)

# Core24.39 Damaged X: equal-or-less remaining wounds; no implicit grants.

fun test_damaged17c3_threshold_boundary_and_disabled() -> Bool:
    let model = make_infernus_squad()[0]
    model.damaged_threshold = 1
    model.suffered_wounds = 1
    if model.is_damaged():
        return false
    model.has_damaged = true
    if !model.is_damaged():
        return false
    model.suffered_wounds = 0
    return !model.is_damaged()

# Every new group refreshes bearer status; wounds on another model do not leak.
fun test_damaged17c3_bearer_scope_and_group_refresh() -> Bool:
    let board = attack_declaration_fixture()
    let other = board[0][0]
    other.identity = 0
    board[0].models.append(other)
    board.identify_units()
    board[0][0].has_damaged = true
    board[0][0].damaged_threshold = 1
    let initial = orks17c2b_info(board, 0)
    board[0][0].suffered_wounds = 1
    let damaged = orks17c2b_info(board, 0)
    let declaration = make_declared_weapon(board, unit_id(0), 1, 0)
    let healthy = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    return !initial.damaged_hit_penalty and damaged.damaged_hit_penalty and !healthy.damaged_hit_penalty

# Damaged subtracts before the +/-1 cap, rather than afterwards (02.02.01).
fun test_damaged17c3_combined_modifiers_before_cap() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.damaged_hit_penalty = true
    board.attack_info.hit_roll_bonus = true
    board.attack_info.profile_hit_roll_bonus.append(board.attack_info.source_profile)
    if get_hit_roll_bonus(board) != 1:
        return false
    board.attack_info.profile_hit_roll_bonus.clear()
    if get_hit_roll_bonus(board) != 0:
        return false
    board.attack_info.hit_roll_bonus = false
    board.attack_info.hit_roll_malus = true
    return get_hit_roll_bonus(board) == -1

# Actual hit classification uses Damaged while natural6 remains critical (p.18).
fun test_damaged17c3_actual_hit_threshold_and_critical() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].has_damaged = true
    board[0][0].damaged_threshold = 1
    board[0][0].suffered_wounds = 1
    board.attack_info = orks17c2b_info(board, 0)
    return classify_attack_hit(board, board.attack_info, attack_test_die(2), get_hit_roll_bonus(board)) == AttackRollResult::failed and classify_attack_hit(board, board.attack_info, attack_test_die(3), get_hit_roll_bonus(board)) == AttackRollResult::success and classify_attack_hit(board, board.attack_info, attack_test_die(6), get_hit_roll_bonus(board)) == AttackRollResult::critical

# Grouping distinguishes modified hit rolls of otherwise identical bearers.
fun test_damaged17c3_grouping_splits_damaged_and_healthy() -> Bool:
    let board = attack_declaration_fixture()
    let healthy = orks17c2b_info(board, 0)
    let damaged = healthy
    damaged.damaged_hit_penalty = true
    return !attacks_are_identical(board, healthy, damaged)

# A retained destroyed model remains Damaged while authorised to fight.
fun test_damaged17c3_retained_fight_on_death_is_damaged() -> Bool:
    let model = make_infernus_squad()[0]
    model.has_damaged = true
    model.damaged_threshold = 1
    model.suffered_wounds = model.profile.wounds()
    model.state = ModelState::fight_on_death
    return model.is_damaged()

# Firing Deck uses the carrier's Damaged status, not the passenger's (p.81).
fun test_damaged17c3_firing_deck_uses_carrier_status() -> Bool:
    let board = attack_declaration_fixture()
    board.embarked_units.append(board[0])
    board.embarked_units[0][0].has_damaged = true
    board.embarked_units[0][0].damaged_threshold = 1
    board.embarked_units[0][0].suffered_wounds = 1
    let declaration = make_deck_declaration(board, unit_id(0), damage_test_model(0), unit_id(0), damage_test_model(0), 0)
    let healthy = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    board[0][0].has_damaged = true
    board[0][0].damaged_threshold = 1
    board[0][0].suffered_wounds = 1
    let damaged = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    return !healthy.damaged_hit_penalty and damaged.damaged_hit_penalty

# Restore gates reject raw out-of-domain storage without inventing an X>0 rule.
fun test_damaged17c3_invalid_threshold_metadata() -> Bool:
    let model = make_infernus_squad()[0]
    model.has_damaged = true
    if !valid_model_numeric_history(model):
        return false
    model.damaged_threshold.value = -1
    if valid_model_numeric_history(model):
        return false
    model.damaged_threshold.value = MAX_WOUNDS
    return !valid_model_numeric_history(model)

# Game serialization preserves both supplied threshold and gathered hit state.
fun test_damaged17c3_saved_threshold_and_group_round_trip() -> Bool:
    let state = play()
    state.board = attack_declaration_fixture()
    state.board[0][0].has_damaged = true
    state.board[0][0].damaged_threshold = 1
    state.board[0][0].suffered_wounds = 1
    state.board.attack_info = orks17c2b_info(state.board, 0)
    let restored = play()
    return set_state(restored, to_string(state)) and restored.board[0][0].is_damaged() and restored.board.attack_info.damaged_hit_penalty and get_hit_roll_bonus(restored.board) == -1

# Healing above X removes the penalty at the next group, overriding stale context.
fun test_damaged17c3_healing_refresh_and_melee_consumer() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::choppa
    board[0][0].has_damaged = true
    board[0][0].damaged_threshold = 1
    board[0][0].suffered_wounds = 1
    board.attack_info = orks17c2b_info(board, 0)
    if !board.attack_info.damaged_hit_penalty or get_hit_roll_bonus(board) != -1:
        return false
    board[0][0].suffered_wounds = 0
    board.attack_info = orks17c2b_info(board, 0)
    return !board.attack_info.damaged_hit_penalty and get_hit_roll_bonus(board) == 0

# The actual hit/wound coroutine consumes the penalty; a nominal hit at BS2
# becomes a miss and no wound-roll selector is offered (core24.39/p.18).
fun test_damaged17c3_hit_batch_consumes_penalty() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].has_damaged = true
    board[0][0].damaged_threshold = 1
    board[0][0].suffered_wounds = 1
    board.attack_info = orks17c2b_info(board, 0)
    let batch = resolve_attack_dice(board, board[1], board[0], attack_test_count(1))
    batch.roll(board, board[1], board[0], attack_test_die(2))
    return batch.is_done() and batch.generated_hits.value == 0

# Torrent still makes no hit roll; Damaged cannot reduce automatic hits (p.85).
fun test_damaged17c3_torrent_keeps_automatic_hits() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::pyreblaster
    board[0][0].has_damaged = true
    board[0][0].damaged_threshold = 1
    board[0][0].suffered_wounds = 1
    board.attack_info = orks17c2b_info(board, 0)
    let batch = resolve_attack_dice(board, board[1], board[0], attack_test_count(1))
    if board.current_state.value != CurrentStateDescription::wound_roll.value or batch.generated_hits.value != 1:
        return false
    batch.roll(board, board[1], board[0], attack_test_die(4))
    return batch.is_done() and batch.generated_wounds.value == 1

# Incoming reductions use the allocated recipient and printed arithmetic
# (p.19, appendix02.02.01; Battlewagon Mobile Fortress/Deff Dread Dread 'Ard).
fun incoming17c4a_grant(ModifiedCharacteristic kind, ModifierOperation operation, Int amount, IncomingAttackScope scope) -> IncomingAttackModifier:
    return incoming_attack_modifier(kind, operation, amount, scope)

# Ranged-only defenses do not protect melee or change the bearer's own weapons.
fun test_incoming17c4a_scope_and_bearer_separation() -> Bool:
    let board = attack_declaration_fixture()
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(ModifiedCharacteristic::damage, ModifierOperation::subtract, 1, IncomingAttackScope::ranged))
    let empty : RuleModifiers
    let ranged = combined_incoming_modifiers(empty, board[1][0].incoming_attack_modifiers, ModifiedCharacteristic::damage, false)
    let melee = combined_incoming_modifiers(empty, board[1][0].incoming_attack_modifiers, ModifiedCharacteristic::damage, true)
    return modified_characteristic(3, ModifiedCharacteristic::damage, ranged, false) == 2 and melee.size() == 0 and board[1][0].characteristic_modifiers.size() == 0

# Outgoing multiplication and incoming subtraction combine before the floor.
fun test_incoming17c4a_order_floor_and_zero_lock() -> Bool:
    let outgoing : RuleModifiers
    outgoing.append(rule_modifier(ModifierOperation::multiply, 2))
    let incoming : IncomingAttackModifiers
    incoming.append(incoming17c4a_grant(ModifiedCharacteristic::damage, ModifierOperation::subtract, 3, IncomingAttackScope::any_attack))
    let combined = combined_incoming_modifiers(outgoing, incoming, ModifiedCharacteristic::damage, false)
    if modified_characteristic(2, ModifiedCharacteristic::damage, combined, false) != 1:
        return false
    outgoing.append(rule_modifier(ModifierOperation::replace, 0))
    combined = combined_incoming_modifiers(outgoing, incoming, ModifiedCharacteristic::damage, false)
    return modified_characteristic(2, ModifiedCharacteristic::damage, combined, false) == 0

# AP worsening caps at zero and does not modify InSv or natural-one failure.
fun test_incoming17c4a_ap_save_and_invulnerable() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.source = Weapon::choppa
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(ModifiedCharacteristic::armour_penetration, ModifierOperation::add, 2, IncomingAttackScope::any_attack))
    if board.attack_info.attack_penetration(board[1][0]) != 0:
        return false
    let group : AllocationGroup
    group.save = 3
    group.invulnerable = 4
    return attack_save_succeeds(group, attack_test_die(3), 0) and attack_save_succeeds(group, attack_test_die(4), -6) and !attack_save_succeeds(group, attack_test_die(1), 0)

# Actual Devastating damage consumes incoming D once before wound loss.
fun test_incoming17c4a_devastating_actual_consumer() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.damage_modifiers.append(rule_modifier(ModifierOperation::replace, 2))
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(ModifiedCharacteristic::damage, ModifierOperation::subtract, 1, IncomingAttackScope::any_attack))
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Random D is still rolled only after allocation; reductions precede its floor.
fun test_incoming17c4a_random_damage_after_allocation() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.source = Weapon::smite_witchfire
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(ModifiedCharacteristic::damage, ModifierOperation::subtract, 1, IncomingAttackScope::ranged))
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1))
    if can damage.quantity(board, board[1], board[0], attack_test_die(2)):
        return false
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    damage.quantity(board, board[1], board[0], attack_test_die(2))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Equal outgoing D can differ after a recipient operation; do not group them.
fun test_incoming17c4a_group_identity_before_rounding() -> Bool:
    let board = attack_declaration_fixture()
    let left = board.attack_info
    let right = left
    left.damage_modifiers.append(rule_modifier(ModifierOperation::replace, 3))
    left.damage_modifiers.append(rule_modifier(ModifierOperation::divide, 2))
    right.damage_modifiers.append(rule_modifier(ModifierOperation::replace, 2))
    if !same_effective_damage(left, right):
        return false
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(ModifiedCharacteristic::damage, ModifierOperation::multiply, 2, IncomingAttackScope::any_attack))
    return !same_effective_damage(left, right, board[1][0]) and !attacks_are_identical(board, left, right)

# AP/D defenses do not change the printed W/Sv/InSv allocation groups (p.19).
fun test_incoming17c4a_mixed_recipients_keep_printed_groups() -> Bool:
    let board = attack_declaration_fixture()
    let other = board[1][0]
    other.identity = 0
    other.incoming_attack_modifiers.append(incoming17c4a_grant(ModifiedCharacteristic::armour_penetration, ModifierOperation::add, 2, IncomingAttackScope::any_attack))
    board[1].models.append(other)
    board.identify_units()
    let groups = make_allocation_groups(board, board[1], board.attack_info)
    return groups.size() == 1 and groups[0].members.size() == 2

# Invalid loaded kind, scope and zero divisor are rejected before arithmetic.
fun test_incoming17c4a_restore_validation() -> Bool:
    let board = attack_declaration_fixture()
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(ModifiedCharacteristic::damage, ModifierOperation::subtract, 1, IncomingAttackScope::any_attack))
    if !valid_model_numeric_history(board[1][0]):
        return false
    board[1][0].incoming_attack_modifiers[0].scope.value = 3
    if valid_model_numeric_history(board[1][0]):
        return false
    board[1][0].incoming_attack_modifiers[0].scope = IncomingAttackScope::any_attack
    board[1][0].incoming_attack_modifiers[0].characteristic = ModifiedCharacteristic::strength
    if valid_model_numeric_history(board[1][0]):
        return false
    board[1][0].incoming_attack_modifiers[0].characteristic = ModifiedCharacteristic::damage
    board[1][0].incoming_attack_modifiers[0].modifier = rule_modifier(ModifierOperation::divide, 0)
    return !valid_model_numeric_history(board[1][0])

# Ordinary failed saves apply the reduction to this attack, without spilling (p.19).
fun test_incoming17c4a_normal_damage_consumer() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.source = Weapon::heavy_bolter
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(ModifiedCharacteristic::damage, ModifierOperation::subtract, 1, IncomingAttackScope::ranged))
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(1), attack_test_count(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Live allocated AP is used by the actual save, rather than the unprotected group (p.19).
fun test_incoming17c4a_normal_save_consumer() -> Bool:
    let board = attack_declaration_fixture()
    board.attack_info.source = Weapon::heavy_bolter
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(ModifiedCharacteristic::armour_penetration, ModifierOperation::add, 1, IncomingAttackScope::ranged))
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(1), attack_test_count(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.roll(board, board[1], board[0], attack_test_die(3))
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 0

# Non-attack mortal wound jobs bypass incoming weapon-D arithmetic (p.24).
fun test_incoming17c4a_nonattack_mortals_unmodified() -> Bool:
    let board = attack_declaration_fixture()
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(ModifiedCharacteristic::damage, ModifierOperation::replace, 0, IncomingAttackScope::any_attack))
    let damage = resolve_mortal_wounds(board, unit_id(1), unit_id(0), false, attack_test_count(1))
    damage.select_mortal_model(board, damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Saves preserve incoming metadata, independent of generated lifecycle (infrastructure).
fun test_incoming17c4a_saved_metadata_round_trip() -> Bool:
    let state = play()
    state.board = attack_declaration_fixture()
    state.board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(ModifiedCharacteristic::damage, ModifierOperation::subtract, 1, IncomingAttackScope::ranged))
    let restored = play()
    return set_state(restored, to_string(state)) and restored.board[1][0].incoming_attack_modifiers.size() == 1 and restored.board[1][0].incoming_attack_modifiers[0].modifier.signed_amount() == 1 and valid_model_numeric_history(restored.board[1][0])

# All67 source loadouts, including Kill Tank options, require at most13 stored
# profiles; declarations include32 Firing Deck selections (p.81/Orks sources).
fun test_physical17d_capacity_and_last_slot() -> Bool:
    # Capacity is model storage; actual final-slot legality is also checked
    # in the profile-selection regression below, using its live board.
    let unit = make_infernus_squad()
    unit.models.resize(1)
    unit[0].weapons.clear()
    for slot in range(MAX_WEAPONS):
        unit[0].weapons.append(equipped_weapon(Weapon::bolt_pistol))
    let selector : BInt<0, MAX_WEAPONS>
    let choices = enumerate(selector)
    let valid = MAX_WEAPONS == 13 and MAX_WEAPON_SCOPES == 14 and MAX_SELECTED_WEAPONS == MAX_UNIT_MODELS * MAX_WEAPONS + MAX_DECK_SELECTIONS and unit[0].weapons.size() == 13 and choices.size() == 13 and choices[12].value == 12
    return valid

# Nazdreg allows its three separate ranged profiles; ordinary copies still
# choose one profile (source UNIT COMPOSITION; appendix04.01.03).
fun test_physical17d_nazdreg_scoped_profile_exception() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.clear()
    equip_weapon(board[0][0], Weapon::orks_nazdreg_kustom_blasta_x_gatler, 0)
    equip_weapon(board[0][0], Weapon::orks_nazdreg_kustom_blasta_x_shoota, 1)
    equip_weapon(board[0][0], Weapon::orks_nazdreg_kustom_blasta_x_skorcha, 1)
    equip_weapon(board[0][0], Weapon::plasma_pistol_standard, 0)
    equip_weapon(board[0][0], Weapon::plasma_pistol_supercharge, 4)
    let selected : Bool[MAX_WEAPONS]
    selected[0] = true
    let permitted = weapon_selection_valid(board, unit_id(0), 0, 1, false, selected, false) and weapon_selection_valid(board, unit_id(0), 0, 2, false, selected, false)
    selected[0] = false
    selected[3] = true
    let ordinary = !weapon_selection_valid(board, unit_id(0), 0, 4, false, selected, false)
    selected[3] = false
    while board[0][0].weapons.size() < MAX_WEAPONS:
        board[0][0].weapons.append(equipped_weapon(Weapon::captain_storm_bolter))
    return permitted and ordinary and weapon_selection_valid(board, unit_id(0), 0, 12, false, selected, false) and !weapon_selection_valid(board, unit_id(0), 0, 13, false, selected, false)


# One Shot usage still belongs to a physical copy, independently of its name.
fun test_physical17d_one_shot_copies_independent() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.clear()
    for slot in range(4):
        board[0][0].weapons.append(equipped_weapon(Weapon::bolt_pistol))
        if slot % 2 == 1:
            board[0][0].weapons[slot].secondary_profile_of = slot
    consume_one_shot_profile(board[0][0], 0)
    return board[0][0].used_once_per_battle_weapon[0] and board[0][0].used_once_per_battle_weapon[1] and !board[0][0].used_once_per_battle_weapon[2] and !board[0][0].used_once_per_battle_weapon[3]

# Hazardous is rolled per selected physical weapon, not per simultaneous
# profile; independent copies and borrowed owners stay separate (p.81).
fun test_physical17d_hazardous_physical_identity() -> Bool:
    let board = attack_declaration_fixture()
    board.identify_units()
    board[0][0].weapons[0].secondary_profile_of = 0
    let first = make_declared_weapon(board, unit_id(0), 0, 0)
    first.selected_rules.append(weapon_rule(WeaponRuleKind::hazardous))
    let second = first
    second.slot = 1
    let third = second
    third.weapon_owner = board[1][0].identity
    let declarations : DeclaredWeapons
    declarations.append(first)
    declarations.append(second)
    declarations.append(third)
    return declared_hazardous_uses(declarations) == 2 and same_declared_physical_weapon(first, second) and !same_declared_physical_weapon(second, third)

# Metadata cannot permit a nonexistent/Melee/ungrouped simultaneous profile.
fun test_physical17d_profile_permission_restore_guard() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].secondary_profile_of.value = 1
    let self_link = !valid_model_equipment(board[0][0])
    board[0][0].weapons[0].secondary_profile_of = 0
    board[0][0].weapons.append(equipped_weapon(Weapon::captain_storm_bolter, 1))
    let linked = valid_model_equipment(board[0][0])
    board[0][0].weapons[0].secondary_profile_of.value = 2
    return self_link and linked and !valid_model_equipment(board[0][0]) and !permits_simultaneous_profile(board[0][0], 0)


# D3 inputs are actual faces1..3; intrinsic constants survive until modifiers.
fun test_compound17d_d3_sum_and_intrinsic_constant() -> Bool:
    let expression = compound_stat(2, 3, 2)
    let sequence = evaluate_random_stat(expression)
    if can sequence.quantity(attack_test_die(4)):
        return false
    sequence.quantity(attack_test_die(2))
    if sequence.is_done():
        return false
    sequence.quantity(attack_test_die(3))
    return sequence.is_done() and sequence.result.value == 7

# Stompa3D6+3 A is generated individually at gathering (02.02.03/source row).
fun test_compound17d_actual_stompa_attacks_gathering() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons[0].profile = Weapon::stompa_supa_gatler_point_blank
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let gathering = gather_weapon_count(board, unit_id(0), unit_id(1), declaration, false)
    gathering.quantity(board, attack_test_die(1))
    gathering.quantity(board, attack_test_die(6))
    gathering.quantity(board, attack_test_die(2))
    return gathering.is_done() and gathering.result.value == 12

# Re-roll all original dice once, retain the intrinsic +3, then multiply
# (01.05.02/02.02.03). One CP pays for the whole summed roll.
fun test_compound17d_whole_roll_reroll_before_modifiers() -> Bool:
    let board = attack_declaration_fixture()
    board.command_points[0] = 1
    let modifiers : RuleModifiers
    modifiers.append(rule_modifier(ModifierOperation::multiply, 2))
    let sequence = evaluate_weapon_characteristic(board, compound_stat(3, 6, 3), 0, false, unit_id(0), modifiers, ModifiedCharacteristic::damage)
    sequence.quantity(board, attack_test_die(1))
    sequence.quantity(board, attack_test_die(1))
    sequence.quantity(board, attack_test_die(1))
    sequence.keep_it(board, false)
    sequence.reroll(board, attack_test_die(6))
    sequence.reroll(board, attack_test_die(6))
    if sequence.is_done():
        return false
    sequence.reroll(board, attack_test_die(6))
    return sequence.is_done() and sequence.result.value == 42 and board.command_points[0] == 0

# Actual allocated D6+2 includes intrinsic +2 before incoming reductions.
fun test_compound17d_allocated_stompa_damage() -> Bool:
    let board = attack_declaration_fixture()
    board[1][0].profile = Profile::captain_octavius
    board.attack_info.source = Weapon::stompa_deffkannon_and_supa_rokkits
    board[1][0].incoming_attack_modifiers.append(incoming_attack_modifier(ModifiedCharacteristic::damage, ModifierOperation::subtract, 1, IncomingAttackScope::ranged))
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    damage.quantity(board, board[1], board[0], attack_test_die(2))
    return damage.is_done() and board[1][0].suffered_wounds == 3

# Random movement still determines one entire unit's M (02.02.03), while
# compound dice do not grant a Command Re-roll for movement characteristics.
fun test_compound17d_unit_random_movement() -> Bool:
    let board = movement11_fixture()
    board[0][0].has_random_movement = true
    board[0][0].random_movement = compound_stat(2, 3, 6)
    let sequence = movement(board, unit_id(0), false)
    sequence.quantity(board, attack_test_die(2))
    sequence.quantity(board, attack_test_die(3))
    return board[0].movement_override.value == 12 and can sequence.normal_move(board)

# Different original shapes do not group just because replacement D is equal;
# equivalent1D6 forms do (p.17/01.05.02/02.02.03).
fun test_compound17d_random_shape_group_identity() -> Bool:
    return same_damage_characteristic(dice_stat(6), compound_stat(1, 6, 0)) and !same_damage_characteristic(compound_stat(2, 3, 0), compound_stat(1, 6, 0)) and !same_damage_characteristic(compound_stat(1, 6, 2), compound_stat(1, 6, 3))

# Stored compound movement/demise survives save round trips with bounds intact.
fun test_compound17d_saved_expressions() -> Bool:
    let state = play()
    state.board = attack_declaration_fixture()
    state.board[0][0].has_random_movement = true
    state.board[0][0].random_movement = compound_stat(1, 6, 6)
    state.board[0][0].has_deadly_demise = true
    state.board[0][0].deadly_demise = compound_stat(2, 6, 0)
    let restored = play()
    return set_state(restored, to_string(state)) and stat_dice_count(restored.board[0][0].deadly_demise) == 2 and stat_intrinsic_constant(restored.board[0][0].random_movement) == 6

# Typed source fixtures exercise infrastructure, not install uncertified Orks abilities.
fun source17e_instance(Board board, Int unit, Int rule) -> SourceInstance:
    board.identify_units()
    let instance : SourceInstance
    instance.rule = rule
    instance.source_unit = board[unit].identity
    instance.source_model = board[unit][0].identity
    instance.owner = board[unit].owned_by_player1
    instance.trigger = SourceEventKind::timing_window
    instance.window = TimingWindow::movement_start
    instance.optional = true
    instance.grant = characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 2)
    return instance

fun source17e_id(Int value) -> SourceEventID:
    let result : SourceEventID
    result = value
    return result

fun source17e_trigger(Board board, SourceEventKind kind, Int unit) -> SourceEvent:
    let result = source_event(kind, board[unit].identity, invalid_entity_identity(), invalid_entity_identity())
    result.window = TimingWindow::movement_start
    result.movement = MovementKind::normal
    return result

# Source instances share the user's current-player/opponent order with legacy
# timing choices, rather than dispatching all sources before both players.
fun test_sources17e_timing_controller_order() -> Bool:
    let board = attack_declaration_fixture()
    let own = source17e_instance(board, 0, 1)
    let enemy = source17e_instance(board, 1, 2)
    register_source_instance(board, own)
    register_source_instance(board, enemy)
    let sequence = resolve_timing_window(board, TimingWindow::movement_start)
    if can sequence.choose_window_source(board, source17e_id(1)):
        return false
    sequence.choose_window_source(board, source17e_id(0))
    if !board.current_decision_maker or board[0][0].effective_movement(6) != 8:
        return false
    sequence.choose_window_source(board, source17e_id(1))
    return sequence.is_done() and !board.current_decision_maker and board[1][0].effective_movement(6) == 8

# Passing optional effects spends nothing; mandatory source instances cannot
# be skipped even when their only choice is a singleton (source/user sequencing).
fun test_sources17e_optional_decline_and_mandatory() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    register_source_instance(board, instance)
    let declined = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    declined.finish_source_events(board)
    if !declined.is_done() or board.source_uses.size() != 0 or board.source_effects.size() != 0:
        return false
    board.source_instances[0].optional = false
    let required = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    if can required.finish_source_events(board):
        return false
    required.choose_source_event(board, source17e_id(0))
    return required.is_done() and board.source_effects.size() == 1

# Duplicate per-army sources share usage, while players remain independent.
fun test_sources17e_shared_army_limit_rechecks_pending() -> Bool:
    let board = attack_declaration_fixture()
    let first = source17e_instance(board, 0, 1)
    first.limits.phase = 1
    let second = first
    register_source_instance(board, first)
    register_source_instance(board, second)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(1))
    return sequence.is_done() and board.source_effects.size() == 1 and !source_usage_available(board, first) and !source_usage_available(board, second)

# Simultaneous phase/turn/round/battle limits are all enforced; new intervals
# reset only their own counts, never the battle total (sourced Orks limits).
fun test_sources17e_combined_interval_limits() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    instance.limits.phase = 2
    instance.limits.turn = 3
    instance.limits.round = 4
    instance.limits.battle = 5
    commit_source_usage(board, instance)
    commit_source_usage(board, instance)
    if source_usage_available(board, instance):
        return false
    board.begin_phase(BattlePhase::movement)
    commit_source_usage(board, instance)
    if source_usage_available(board, instance):
        return false
    board.start_turn_history()
    commit_source_usage(board, instance)
    if source_usage_available(board, instance):
        return false
    board.current_round = 1
    board.begin_phase(BattlePhase::shooting)
    commit_source_usage(board, instance)
    board.start_turn_history()
    board.begin_phase(BattlePhase::fight)
    board.current_round = 2
    return !source_usage_available(board, instance) and board.source_uses[0].battle_uses.value == 5

# Equal grant values from different sources keep independent expiry handles.
fun test_sources17e_overlapping_grants_expire_independently() -> Bool:
    let board = attack_declaration_fixture()
    let first = source17e_instance(board, 0, 1)
    let second = source17e_instance(board, 0, 2)
    second.duration = SourceDuration::next_own_turn
    register_source_instance(board, first)
    register_source_instance(board, second)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(0))
    sequence.choose_source_event(board, source17e_id(1))
    if board[0][0].effective_movement(6) != 10:
        return false
    board.begin_phase(BattlePhase::shooting)
    return board.source_effects.size() == 1 and board[0][0].effective_movement(6) == 8 and valid_source_grant(board.source_instances[0].grant) and valid_source_grant(board.source_instances[1].grant)

# Next-own-turn effects survive the opponent's turn; duration belongs to the
# granting player's next turn, not the recipient's owner (01.02.02).
fun test_sources17e_next_own_turn_duration() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    instance.duration = SourceDuration::next_own_turn
    register_source_instance(board, instance)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(0))
    board.current_player = true
    board.start_turn_history()
    if board[0][0].effective_movement(6) != 8:
        return false
    board.current_player = false
    board.start_turn_history()
    return board.source_effects.size() == 0 and board[0][0].effective_movement(6) == 6

# Reserve/passenger transfers retain duration, and expiry reaches both banks
# (01.02.02); no physical range is measured in this fixture.
fun test_sources17e_expiry_in_reserve_and_passenger_banks() -> Bool:
    let board = attack_declaration_fixture()
    let own = source17e_instance(board, 0, 1)
    let enemy = source17e_instance(board, 1, 2)
    register_source_instance(board, own)
    register_source_instance(board, enemy)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(0))
    sequence.choose_source_event(board, source17e_id(1))
    board.embarked_units.append(board[1])
    board.units.erase(1)
    board.reserve_units.append(board[0])
    board.units.erase(0)
    board.begin_phase(BattlePhase::shooting)
    return board.source_effects.size() == 0 and board.reserve_units[0][0].effective_movement(6) == 6 and board.embarked_units[0][0].effective_movement(6) == 6

# Sources follow model identity after compaction; model grants do not affect
# another constituent merely because it shares the unit (pp.66/87).
fun test_sources17e_model_scope_and_stable_source() -> Bool:
    let board = attack_declaration_fixture()
    let other = board[0][0]
    other.identity = 0
    board[0].models.append(other)
    board.identify_units()
    let instance = source17e_instance(board, 0, 1)
    instance.source_model = board[0][1].identity
    instance.recipient = SourceTarget::source_model
    register_source_instance(board, instance)
    board[0].models.erase(0)
    let relocated = board[0]
    relocated.identity = 0
    board[0].models.clear()
    board[0].retired = true
    board.identify_unit(relocated)
    board.units.append(relocated)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(0))
    return sequence.is_done() and board[3][0].identity == instance.source_model and board[3][0].effective_movement(6) == 8

# Offboard own rules require explicit permission, and external range triggers
# stay unavailable even when that permission exists (01.02.04).
fun test_sources17e_offboard_permission_and_range() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    instance.trigger = SourceEventKind::move_end
    register_source_instance(board, instance)
    let event = source17e_trigger(board, SourceEventKind::move_end, 0)
    board.reserve_units.append(board[0])
    board.units.erase(0)
    if source_event_available(board, instance, event):
        return false
    instance.offboard_allowed = true
    if !source_event_available(board, instance, event):
        return false
    instance.subject = SourceSubject::any_unit
    instance.trigger_range = 6
    event.unit = board[0].identity
    return !source_event_available(board, instance, event)

# The real attack selection hook resolves its source before weapon choices.
fun test_sources17e_actual_attack_selection_hook() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    instance.trigger = SourceEventKind::attack_selection
    instance.grant = characteristic_modifier(ModifiedCharacteristic::attacks, ModifierOperation::add, 2)
    register_source_instance(board, instance)
    let sequence = attack(board, unit_id(0), unit_id(1), false, false)
    if can sequence.select_weapon(board, attack_test_slot(0)):
        return false
    sequence.choose_source_event(board, source17e_id(0))
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    return declaration_fixed_attacks(board, unit_id(0), declaration, 0) == 4 and can sequence.select_weapon(board, attack_test_slot(0))

# Source-only destruction hooks retain their victim and resolve at the printed
# release point; unrelated deaths can trigger an eligible observer (p.87).
fun test_sources17e_actual_destruction_observer_hook() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    instance.trigger = SourceEventKind::model_destroyed
    instance.subject = SourceSubject::enemy_unit
    instance.grant = characteristic_modifier(ModifiedCharacteristic::strength, ModifierOperation::add, 1)
    register_source_instance(board, instance)
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(1), unit_id(0), true, true, 2, board[1][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(0))
    if board[1][0].state.value != ModelState::pending_destruction.value:
        return false
    let empty : DamageJobs
    let cleanup = resolve_damage_jobs(board, empty, true, unit_id(0))
    cleanup.choose_destruction_unit(board, unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.choose_source_event(board, source17e_id(0))
    let modifiers = model_weapon_modifiers(board[0][0], 0, ModifiedCharacteristic::strength, false)
    return cleanup.is_done() and board[1].models.size() == 0 and modified_characteristic(4, ModifiedCharacteristic::strength, modifiers, false) == 5

# Expired weapon-rule snapshots do not resurrect a grant after phase cleanup.
fun test_sources17e_weapon_rule_snapshot_expiry() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    instance.grant = source_weapon_grant(weapon_rule(WeaponRuleKind::heavy))
    register_source_instance(board, instance)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(0))
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let info = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    if !info.has_weapon_rule(board, WeaponRuleKind::heavy):
        return false
    board.begin_phase(BattlePhase::shooting)
    return !info.has_weapon_rule(board, WeaponRuleKind::heavy)

# Passive auras update when either unit moves, and drop immediately with the
# source; offboard recipients do not receive range-based effects (01.02.04).
fun test_sources17e_live_aura_range_and_source() -> Bool:
    let board = attack_declaration_fixture()
    board[1].owned_by_player1 = false
    let instance = source17e_instance(board, 0, 1)
    instance.aura = true
    instance.optional = false
    instance.recipient = SourceTarget::event_unit
    instance.subject = SourceSubject::friendly_unit
    instance.duration = SourceDuration::battle
    instance.trigger_range = 6
    register_source_instance(board, instance)
    if board[1][0].effective_movement(6) != 8:
        return false
    board[1][0].position.x = 20
    refresh_source_effects(board, TimingWindow::none)
    if board[1][0].effective_movement(6) != 6:
        return false
    board[1][0].position.x = 10
    refresh_source_effects(board, TimingWindow::none)
    if board[1][0].effective_movement(6) != 8:
        return false
    board[0][0].suffered_wounds = 2
    refresh_source_effects(board, TimingWindow::none)
    return board.source_effects.size() == 0 and board[1][0].effective_movement(6) == 6

# Overlapping auras never erase another source's equal-valued arithmetic grant.
fun test_sources17e_aura_overlap_and_disable() -> Bool:
    let board = attack_declaration_fixture()
    board[1].owned_by_player1 = false
    let instance = source17e_instance(board, 0, 1)
    instance.aura = true
    instance.optional = false
    instance.recipient = SourceTarget::event_unit
    instance.subject = SourceSubject::friendly_unit
    instance.duration = SourceDuration::battle
    instance.trigger_range = 6
    register_source_instance(board, instance)
    instance = source17e_instance(board, 1, 2)
    instance.aura = true
    instance.optional = false
    instance.recipient = SourceTarget::event_unit
    instance.subject = SourceSubject::friendly_unit
    instance.duration = SourceDuration::battle
    instance.trigger_range = 6
    register_source_instance(board, instance)
    if board[0][0].effective_movement(6) != 10:
        return false
    board.source_instances[0].disabled = true
    refresh_source_effects(board, TimingWindow::none)
    return board[0][0].effective_movement(6) == 8 and board[1][0].effective_movement(6) == 8

# Unit grants reach a newly returned constituent once, without duplicating
# the surviving member's original grant (p.88/01.02.02).
fun test_sources17e_returned_constituent_refresh() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    instance.duration = SourceDuration::battle
    register_source_instance(board, instance)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(0))
    let returned = board[0][0]
    returned.identity = 0
    returned.characteristic_modifiers.clear()
    board[0].models.append(returned)
    board.identify_unit(board[0])
    refresh_source_effects(board, TimingWindow::none)
    refresh_source_effects(board, TimingWindow::none)
    return board[0][0].characteristic_modifiers.size() == 1 and board[0][1].characteristic_modifiers.size() == 1 and board[0][1].effective_movement(6) == 8

# Source/effect/usage identities survive full-game serialization and invalid
# source references are rejected by the save gate (bounded infrastructure).
fun test_sources17e_saved_records_and_invalid_reference() -> Bool:
    let state = play()
    state.board = attack_declaration_fixture()
    let instance = source17e_instance(state.board, 0, 1)
    instance.limits.battle = 2
    register_source_instance(state.board, instance)
    let sequence = resolve_source_event(state.board, source17e_trigger(state.board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(state.board, source17e_id(0))
    let restored = play()
    if !set_state(restored, to_string(state)) or restored.board.source_effects.size() != 1 or restored.board.source_uses[0].battle_uses.value != 1 or restored.board[0][0].effective_movement(6) != 8:
        return false
    restored.board.source_effects[0].source.value = 63
    return !valid_source_foundations(restored.board)

# Model/unit limits key the printed subject rather than flattening everything
# into one per-army counter (Orks source restriction wording).
fun test_sources17e_unit_model_and_player_use_keys() -> Bool:
    let board = attack_declaration_fixture()
    let first = source17e_instance(board, 0, 1)
    first.use_scope = SourceUseScope::unit
    first.limits.battle = 1
    let second = source17e_instance(board, 1, 1)
    second.use_scope = SourceUseScope::unit
    second.limits.battle = 1
    commit_source_usage(board, first)
    if source_usage_available(board, first) or !source_usage_available(board, second):
        return false
    first.use_scope = SourceUseScope::model
    return source_usage_available(board, first) and board.source_uses.size() == 1

# Source-installed incoming D reaches the actual allocated damage consumer.
fun test_sources17e_incoming_damage_grant_consumer() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    instance.recipient = SourceTarget::target_unit
    instance.grant = incoming_attack_modifier(ModifiedCharacteristic::damage, ModifierOperation::subtract, 1, IncomingAttackScope::ranged)
    register_source_instance(board, instance)
    let event = source17e_trigger(board, SourceEventKind::timing_window, 0)
    event.target = board[1].identity
    let trigger = resolve_source_event(board, event)
    trigger.choose_source_event(board, source17e_id(0))
    board.attack_info.damage_modifiers.append(rule_modifier(ModifierOperation::replace, 2))
    let damage = resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Named/physical source weapon rules retain17.C2c conjunctive scope and do
# not become bearer-wide merely because a generic event installed them.
fun test_sources17e_named_physical_weapon_rule_scope() -> Bool:
    let board = named17c2c_fixture()
    let instance = source17e_instance(board, 0, 1)
    let grant = source_weapon_grant(weapon_rule(WeaponRuleKind::precision))
    grant.weapon_scope = 1
    grant.physical_scope = true
    grant.weapon_name = board[0][0].weapons[0].profile.family_id()
    instance.grant = grant
    register_source_instance(board, instance)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(0))
    return model_weapon_has_rule(board[0][0], 0, WeaponRuleKind::precision) and model_weapon_has_rule(board[0][0], 1, WeaponRuleKind::precision) and !model_weapon_has_rule(board[0][0], 2, WeaponRuleKind::precision)

# Live aura eligibility rechecks compound target keywords, not only geometry.
fun test_sources17e_aura_keyword_condition_refresh() -> Bool:
    let board = attack_declaration_fixture()
    board[1].owned_by_player1 = false
    board[1][0].keywords.append(Keyword::vehicle)
    let instance = source17e_instance(board, 0, 1)
    instance.aura = true
    instance.optional = false
    instance.recipient = SourceTarget::event_unit
    instance.subject = SourceSubject::friendly_unit
    instance.duration = SourceDuration::battle
    instance.trigger_range = 6
    append_keyword_condition(instance.recipient_condition, KeywordClause::all, Keyword::vehicle)
    register_source_instance(board, instance)
    if board[0][0].effective_movement(6) != 6 or board[1][0].effective_movement(6) != 8:
        return false
    board[1][0].keywords.pop()
    refresh_source_effects(board, TimingWindow::none)
    return board[1][0].effective_movement(6) == 6

# Actual move-start/end events preserve independent source handles and expose
# choices around the movement endpoint rather than inventing phase triggers.
fun test_sources17e_actual_move_start_end_hooks() -> Bool:
    let board = movement11_fixture()
    let start = source17e_instance(board, 0, 1)
    start.trigger = SourceEventKind::move_start
    let end = source17e_instance(board, 0, 2)
    end.trigger = SourceEventKind::move_end
    register_source_instance(board, start)
    register_source_instance(board, end)
    let sequence = move(board, unit_id(0), 0)
    sequence.choose_movement_source(board, unit_id(0), source17e_id(0))
    sequence.move_to(board, unit_id(0), board_position(7, 5))
    sequence.choose_movement_source(board, unit_id(0), source17e_id(0))
    return sequence.is_done() and board[0][0].effective_movement(6) == 10

# Expired grants also leave casualty archives, so revival cannot resurrect a
# former phase effect (p.88/01.02.02).
fun test_sources17e_archived_grant_expiry() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    register_source_instance(board, instance)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(0))
    board[0].remove_model(0)
    board.begin_phase(BattlePhase::shooting)
    return board[0].destroyed_models.value[0].characteristic_modifiers.size() == 0 and board.source_effects.size() == 0

# Phase effects expire after that phase's end effects/mission work, before the
# following turn-end window (01.02.02; core pp.28–30).
fun test_sources17e_phase_end_expiry_before_turn_end() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    register_source_instance(board, instance)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(0))
    let end = resolve_timing_window(board, TimingWindow::movement_end)
    return end.is_done() and board.source_effects.size() == 0 and board[0][0].effective_movement(6) == 6

# Shock-end sources resolve after the two original dice and before the caller
# regains its decision owner (p.9/30/source event infrastructure).
fun test_sources17e_actual_shock_end_hook() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 1)
    instance.trigger = SourceEventKind::shock_end
    register_source_instance(board, instance)
    let sequence = battle_shock_test(board, board[0], false, false)
    sequence.roll_pair(board, board[0], attack_test_die(6), attack_test_die(6))
    sequence.choose_source_event(board, board[0], source17e_id(0))
    return sequence.is_done() and board[0][0].effective_movement(6) == 8

# Saved effect-key corruption cannot turn an unrelated manual modifier into a
# persisting source grant (source ownership/expiry infrastructure).
fun test_sources17e_forged_modifier_handle_rejected() -> Bool:
    let board = attack_declaration_fixture()
    board.identify_units()
    let modifier = characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 2)
    modifier.source_effect = 1
    board[0][0].characteristic_modifiers.append(modifier)
    return !valid_source_foundations(board)

# Actual2D6 Deadly Demise rolls two fresh dice per nearby unit, then resolves
# each mortal job while retaining the exploding model (core p.80/Stompa).
fun test_compound17d_actual_two_dice_deadly_demise() -> Bool:
    let board = damage_test_fixture()
    board[1][0].has_deadly_demise = true
    board[1][0].deadly_demise = compound_stat(2, 6, 0)
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(1), unit_id(0), true, true, 10, board[1][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(0))
    let empty : DamageJobs
    let cleanup = resolve_damage_jobs(board, empty, true, unit_id(0))
    cleanup.choose_destruction_unit(board, unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.roll(board, attack_test_die(6))
    for quantity_index in range(6):
        cleanup.quantity(board, attack_test_die(1))
    for last_unit_wound in range(2):
        cleanup.select_mortal_model(board, damage_test_model(0))
    for own_unit_wound in range(2):
        cleanup.select_mortal_model(board, damage_test_model(1))
    for first_unit_wound in range(2):
        cleanup.select_mortal_model(board, damage_test_model(0))
    return cleanup.is_done() and board[0].models.size() == 0 and board[1].models.size() == 0 and board[2].models.size() == 0

# Appendix02.02.02 permits every subset, including beneficial operations;
# this is a generic core fixture, not an excluded Forge World unit.
fun test_ignore17c4b_every_subset_before_arithmetic() -> Bool:
    let board = attack_declaration_fixture()
    let choices : AttackModifierChoices
    choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, 2), ModifierOrigin::characteristic))
    choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, -2), ModifierOrigin::characteristic))
    choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::multiply, 2), ModifierOrigin::characteristic))
    let valid = true
    for pattern in range(8):
        let selected = choose_attack_modifiers(board, choices, false, ModifierSelectionKind::ballistic_skill, true)
        let expected : SelectedAttackModifiers
        let divisor = 1
        for choice_index in range(3):
            let keep = ((pattern / divisor) % 2) == 1
            divisor = divisor * 2
            selected.apply_attack_modifier(board, keep)
            if keep:
                expected.append(choices[choice_index].modifier)
        valid = valid and selected.is_done() and apply_rule_modifiers(4, selected.result, false) == apply_rule_modifiers(4, expected, false)
    return valid

# No permission means the complete list applies without a new decision;
# empty lists never stall or change the caller's controller (02.02.02).
fun test_ignore17c4b_unpermitted_and_empty_skip_choices() -> Bool:
    let board = attack_declaration_fixture()
    board.current_decision_maker = true
    let choices : AttackModifierChoices
    choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, -1), ModifierOrigin::hit_penalty))
    let denied = choose_attack_modifiers(board, choices, false, ModifierSelectionKind::hit_roll, false)
    let empty : AttackModifierChoices
    let none = choose_attack_modifiers(board, empty, false, ModifierSelectionKind::hit_roll, true)
    return denied.is_done() and none.is_done() and denied.result.size() == 1 and none.result.size() == 0 and board.current_decision_maker

# Optional choice belongs to the affected attacker, not the turn owner or
# incoming source, and must restore nested caller/UI roles (02.02.02).
fun test_ignore17c4b_controller_and_context_restored() -> Bool:
    let board = attack_declaration_fixture()
    board.current_player = false
    board.current_decision_maker = false
    board.pending_modifier_kind = ModifierSelectionKind::weapon_skill
    board.pending_modifier_choice = attack_modifier_choice(rule_modifier(ModifierOperation::add, 3), ModifierOrigin::characteristic)
    let choices : AttackModifierChoices
    choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, -1), ModifierOrigin::damaged))
    let sequence = choose_attack_modifiers(board, choices, true, ModifierSelectionKind::hit_roll, true)
    let valid = board.current_decision_maker and board.pending_modifier_kind.value == ModifierSelectionKind::hit_roll.value and can sequence.apply_attack_modifier(board, false)
    sequence.apply_attack_modifier(board, false)
    return valid and sequence.is_done() and !board.current_decision_maker and board.pending_modifier_kind.value == ModifierSelectionKind::weapon_skill.value and board.pending_modifier_choice.modifier.amount == 3 and board.command_points[1] == 0

# Keeping only a detrimental contribution must remain possible; sign filtering
# would incorrectly force the beneficial one (02.02.02/02.02.01).
fun test_ignore17c4b_can_ignore_beneficial_hit_bonus() -> Bool:
    let board = attack_declaration_fixture()
    let choices : AttackModifierChoices
    choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, 1), ModifierOrigin::heavy))
    choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, -1), ModifierOrigin::damaged))
    let sequence = choose_attack_modifiers(board, choices, false, ModifierSelectionKind::hit_roll, true)
    sequence.apply_attack_modifier(board, false)
    sequence.apply_attack_modifier(board, true)
    return sequence.is_done() and selected_hit_bonus(sequence.result) == -1

# Cover/Plunging Fire remain separate BS choices. Operation order/floors apply
# after filtering, never to an already rounded all-applied BS (pp.50/73;02.02.02).
fun test_ignore17c4b_cover_plunging_and_skill_operation_order() -> Bool:
    let board = attack_declaration_fixture()
    let info = orks17c2b_info(board, 0)
    info.source = Weapon::slugga
    info.target_has_cover = true
    info.plunging_fire = true
    info.skill_modifiers.append(rule_modifier(ModifierOperation::divide, 2))
    let options = attack_skill_choices(board, info)
    let sequence = choose_attack_modifiers(board, options, false, ModifierSelectionKind::ballistic_skill, true)
    sequence.apply_attack_modifier(board, true)
    sequence.apply_attack_modifier(board, false)
    sequence.apply_attack_modifier(board, true)
    return options.size() == 3 and options[1].origin.value == ModifierOrigin::plunging_fire.value and options[2].origin.value == ModifierOrigin::cover.value and selected_attack_skill(info, sequence.result) == (info.source.skill() + 2) / 2

# Ignores Cover removes cover before optional choices; it never removes
# other modifiers or lets an absent '-' skill be modified (pp.82/85;02.02.01).
fun test_ignore17c4b_ignore_cover_and_torrent_special_skill() -> Bool:
    let board = attack_declaration_fixture()
    let info = orks17c2b_info(board, 0)
    info.target_has_cover = true
    info.selected_weapon_rules.append(weapon_rule(WeaponRuleKind::ignore_cover))
    let choices = attack_skill_choices(board, info)
    info.source = Weapon::stompa_supa_gatler_point_blank
    let selected : SelectedAttackModifiers
    selected.append(rule_modifier(ModifierOperation::add, 4))
    return choices.size() == 0 and selected_attack_skill(info, selected) == 0

# Heavy, Damaged, ordinary flags and both engagement contributions must be
# independently available before the +/-1 sum cap (pp.18/35/63/82;02.02.02).
fun test_ignore17c4b_hit_core_provenance_and_cap() -> Bool:
    let board = attack_declaration_fixture()
    let info = orks17c2b_info(board, 0)
    info.hit_roll_bonus = true
    info.hit_roll_malus = true
    info.damaged_hit_penalty = true
    info.heavy_bonus = true
    info.engaged_hit_penalties = 2
    info.selected_weapon_rules.append(weapon_rule(WeaponRuleKind::heavy))
    let choices = attack_hit_choices(board, info)
    let sequence = choose_attack_modifiers(board, choices, false, ModifierSelectionKind::hit_roll, true)
    for modifier_index in range(choices.size()):
        sequence.apply_attack_modifier(board, !choices[modifier_index].modifier.negative)
    return choices.size() == 6 and choices[2].origin.value == ModifierOrigin::damaged.value and choices[3].origin.value == ModifierOrigin::heavy.value and choices[4].origin.value == ModifierOrigin::engaged_source.value and choices[5].origin.value == ModifierOrigin::engaged_target.value and selected_hit_bonus(sequence.result) == 1

# Permission applies to one bearer and declared attack kind, with separate
# characteristic and roll categories (02.02.02; model/unit scope02.05.01).
fun test_ignore17c4b_permission_bearer_scope_and_kinds() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.append(equipped_weapon(Weapon::relic_weapon))
    board[0][0].attack_modifier_permissions.append(attack_modifier_permission(true, false, IncomingAttackScope::ranged))
    let ranged = orks17c2b_info(board, 0)
    let melee = orks17c2b_info(board, 1)
    let other = declared_attack_info(board, unit_id(1), unit_id(0), make_declared_weapon(board, unit_id(1), 0, 0), board.attack_info)
    return ranged.may_ignore_skill_modifiers and !ranged.may_ignore_hit_modifiers and !melee.may_ignore_skill_modifiers and !other.may_ignore_skill_modifiers

# Equal current BS can have different optional subsets; permission mismatches
# and canceling hit contributions must split groups (p.17/02.02.02).
fun test_ignore17c4b_grouping_preserves_available_subsets() -> Bool:
    let board = attack_declaration_fixture()
    let left = orks17c2b_info(board, 0)
    let right = left
    left.may_ignore_skill_modifiers = true
    if attacks_are_identical(board, left, right):
        return false
    right.may_ignore_skill_modifiers = true
    left.skill_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    left.skill_modifiers.append(rule_modifier(ModifierOperation::add, -1))
    if attacks_are_identical(board, left, right):
        return false
    left.skill_modifiers.clear()
    left.may_ignore_hit_modifiers = true
    right.may_ignore_hit_modifiers = true
    left.hit_roll_bonus = true
    left.hit_roll_malus = true
    return !attacks_are_identical(board, left, right)

# With no permission, equivalent effective profiles retain existing batching
# even if their unfiltered records differ (p.17;02.02.01).
fun test_ignore17c4b_no_permission_keeps_equivalent_grouping() -> Bool:
    let board = attack_declaration_fixture()
    let left = orks17c2b_info(board, 0)
    let right = left
    left.skill_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    left.skill_modifiers.append(rule_modifier(ModifierOperation::add, -1))
    return attacks_are_identical(board, left, right)

# Original natural one/six, Snap Shooting and Indirect's unmodified floor
# survive selected subsets; these are gates, not modifiers (pp.18/35/57).
fun test_ignore17c4b_natural_and_unmodified_hit_gates() -> Bool:
    let board = attack_declaration_fixture()
    let info = orks17c2b_info(board, 0)
    let valid = classify_attack_hit(board, info, attack_test_die(1), 1, 2) == AttackRollResult::failed and classify_attack_hit(board, info, attack_test_die(6), -1, 6) == AttackRollResult::critical
    info.only_hits_on_6 = true
    valid = valid and classify_attack_hit(board, info, attack_test_die(5), 1, 2) == AttackRollResult::failed
    info.only_hits_on_6 = false
    info.shooting_kind = ShootingKind::indirect
    info.indirect_stationary_visible = false
    info.selected_weapon_rules.append(weapon_rule(WeaponRuleKind::indirect_fire))
    return valid and classify_attack_hit(board, info, attack_test_die(5), 1, 2) == AttackRollResult::failed

# Real hit batches must allow distinct choices for identical original faces;
# two attacks do not have to keep the same subset (02.02.02/p.18).
fun test_ignore17c4b_actual_batch_per_attack_skill_and_hit() -> Bool:
    let board = attack_declaration_fixture()
    board.command_points[0] = 0
    board[0][0].attack_modifier_permissions.append(attack_modifier_permission(true, true, IncomingAttackScope::any_attack))
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::ballistic_skill, ModifierOperation::add, 1))
    board.attack_info = orks17c2b_info(board, 0)
    board.attack_info.hit_roll_malus = true
    let sequence = resolve_attack_dice(board, board[1], board[0], attack_test_count(2))
    sequence.roll(board, board[1], board[0], attack_test_die(2))
    sequence.roll(board, board[1], board[0], attack_test_die(2))
    let offered = can sequence.apply_attack_modifier(board, board[1], board[0], false)
    sequence.apply_attack_modifier(board, board[1], board[0], false)
    sequence.apply_attack_modifier(board, board[1], board[0], false)
    sequence.apply_attack_modifier(board, board[1], board[0], true)
    sequence.apply_attack_modifier(board, board[1], board[0], true)
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    return offered and sequence.is_done() and sequence.generated_hits == 1 and sequence.generated_wounds == 0 and board.current_decision_maker == false

# The hit chooser follows completed replacement dice, not an original failure;
# rerolls remain once per original die (02.02.01/01.05.02/02.02.02).
fun test_ignore17c4b_actual_reroll_then_select_modifiers() -> Bool:
    let board = attack_declaration_fixture()
    board.command_points[0] = 0
    board[0][0].attack_modifier_permissions.append(attack_modifier_permission(false, true, IncomingAttackScope::any_attack))
    board.attack_info = orks17c2b_info(board, 0)
    board.attack_info.hit_roll_malus = true
    board.attack_info.reroll_hits = true
    let sequence = resolve_attack_dice(board, board[1], board[0], attack_test_count(1))
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    let delayed = !can sequence.apply_attack_modifier(board, board[1], board[0], false)
    sequence.select_reroll(board, board[1], board[0], attack_test_die(1))
    sequence.reroll(board, board[1], board[0], attack_test_die(2))
    sequence.apply_attack_modifier(board, board[1], board[0], false)
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    return delayed and sequence.is_done() and sequence.generated_hits == 1

# Natural criticals skip meaningless ignoring decisions while preserving
# Sustained/Lethal and the old batch counts (pp.18/82/84).
fun test_ignore17c4b_actual_natural_criticals_without_choices() -> Bool:
    let board = attack_declaration_fixture()
    board.command_points[0] = 0
    board[0][0].attack_modifier_permissions.append(attack_modifier_permission(true, true, IncomingAttackScope::any_attack))
    board.attack_info = orks17c2b_info(board, 0)
    board.attack_info.hit_roll_malus = true
    let sequence = resolve_attack_dice(board, board[1], board[0], attack_test_count(2))
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    sequence.roll(board, board[1], board[0], attack_test_die(6))
    let no_choice = !can sequence.apply_attack_modifier(board, board[1], board[0], false)
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    return no_choice and sequence.is_done() and sequence.generated_hits == 1

# Opposing out-of-phase attacks use their own controller for ignoring and
# restore the nested caller after dice resolution (02.02.02/user sequencing).
fun test_ignore17c4b_actual_opponent_controller() -> Bool:
    let board = attack_declaration_fixture()
    board.command_points[1] = 0
    board[1][0].attack_modifier_permissions.append(attack_modifier_permission(false, true, IncomingAttackScope::any_attack))
    let declaration = make_declared_weapon(board, unit_id(1), 0, 0)
    board.attack_info = declared_attack_info(board, unit_id(1), unit_id(0), declaration, board.attack_info)
    board.attack_info.hit_roll_malus = true
    board.current_decision_maker = false
    let sequence = resolve_attack_dice(board, board[0], board[1], attack_test_count(1))
    sequence.roll(board, board[0], board[1], attack_test_die(5))
    let correct_owner = board.current_decision_maker
    sequence.apply_attack_modifier(board, board[0], board[1], false)
    sequence.roll(board, board[0], board[1], attack_test_die(1))
    return correct_owner and sequence.is_done() and !board.current_decision_maker

# Firing Deck attacks use the carrier's permission, not the passenger's;
# stable physical/borrowed identity remains separate (p.81/02.02.02).
fun test_ignore17c4b_borrowed_carrier_permissions() -> Bool:
    let board = attack_declaration_fixture()
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    declaration.borrowed_weapon = true
    board[0][0].attack_modifier_permissions.append(attack_modifier_permission(false, true, IncomingAttackScope::ranged))
    let info = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    return info.may_ignore_hit_modifiers and !info.may_ignore_skill_modifiers

# Source-owned permissions share expiry, overlaps, returned members and saved
# recipient integrity with numerical grants (01.02.02/02.02.02).
fun test_ignore17c4b_source_permission_expiry_and_overlap() -> Bool:
    let board = attack_declaration_fixture()
    let first = source17e_instance(board, 0, 31)
    first.grant = source_attack_modifier_grant(attack_modifier_permission(true, true, IncomingAttackScope::any_attack))
    register_source_instance(board, first)
    let second = first
    second.rule = 32
    second.duration = SourceDuration::turn
    register_source_instance(board, second)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(0))
    sequence.choose_source_event(board, source17e_id(1))
    board.begin_phase(BattlePhase::shooting)
    let still_allowed = attack_permission_available(board, board[0][0], false, true) and board[0][0].attack_modifier_permissions.size() == 1
    refresh_source_effects(board, TimingWindow::turn_end)
    return still_allowed and !attack_permission_available(board, board[0][0], false, true) and valid_source_foundations(board)

# Offboard/archive cleanup cannot revive an expired ignore permission
# (01.02.02/01.02.04/p.88); prototypes stay untagged.
fun test_ignore17c4b_source_permission_offboard_archive_cleanup() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 33)
    instance.grant = source_attack_modifier_grant(attack_modifier_permission(true, false, IncomingAttackScope::ranged))
    register_source_instance(board, instance)
    let sequence = resolve_source_event(board, source17e_trigger(board, SourceEventKind::timing_window, 0))
    sequence.choose_source_event(board, source17e_id(0))
    let copy = board[0]
    copy.identity = 0
    copy[0].identity = 0
    copy.retired = false
    board[0].remove_model(0)
    board.reserve_units.append(copy)
    board.begin_phase(BattlePhase::shooting)
    return board[0].destroyed_models.value[0].attack_modifier_permissions.size() == 0 and board.reserve_units[0][0].attack_modifier_permissions.size() == 0

# Invalid permissions/choice origins and forged lifetime handles must fail
# restore checks instead of authorizing an arbitrary new source (02.02.02).
fun test_ignore17c4b_invalid_permission_and_forged_handle() -> Bool:
    let board = attack_declaration_fixture()
    let permission = attack_modifier_permission(true, false, IncomingAttackScope::ranged)
    permission.scope.value = 9
    board[0][0].attack_modifier_permissions.append(permission)
    let scope_rejected = !valid_model_numeric_history(board[0][0])
    board[0][0].attack_modifier_permissions.clear()
    permission.scope.value = IncomingAttackScope::ranged.value
    permission.source_effect = 8
    board[0][0].attack_modifier_permissions.append(permission)
    let handle_rejected = !valid_source_foundations(board)
    board.pending_modifier_choice.origin.value = 99
    return scope_rejected and handle_rejected and !valid_state_foundations(board)

# The pending choice and ordinary permission list survive a complete Game
# save/restore; new schemas protect changed layouts (infrastructure/02.02.02).
fun test_ignore17c4b_saved_permission_and_pending_label() -> Bool:
    let state = play()
    state.board = attack_declaration_fixture()
    state.board[0][0].attack_modifier_permissions.append(attack_modifier_permission(true, true, IncomingAttackScope::any_attack))
    state.board.pending_modifier_kind = ModifierSelectionKind::hit_roll
    state.board.pending_modifier_choice = attack_modifier_choice(rule_modifier(ModifierOperation::add, -1), ModifierOrigin::heavy)
    let restored = play()
    return set_state(restored, to_string(state)) and restored.board[0][0].attack_modifier_permissions.size() == 1 and modifier_choice_label(restored.board) == modifier_choice_label(state.board) and restored.board.schema_version.value == STATE_SCHEMA_VERSION

# Core modifiers fit alongside every supported authored skill record;18 is
# a collection bound, while each Apply/Ignore payload still enumerates2 (02.02.02).
fun test_ignore17c4b_full_skill_list_plus_core_capacity() -> Bool:
    let board = attack_declaration_fixture()
    let info = orks17c2b_info(board, 0)
    for modifier_index in range(16):
        info.skill_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    info.plunging_fire = true
    info.target_has_cover = true
    let options = attack_skill_choices(board, info)
    let sequence = choose_attack_modifiers(board, options, false, ModifierSelectionKind::ballistic_skill, true)
    for selected_index in range(18):
        sequence.apply_attack_modifier(board, false)
    return options.size() == 18 and sequence.is_done() and sequence.result.size() == 0 and selected_attack_skill(info, sequence.result) == info.source.skill()


# A suspended chooser round-trips its index/result, not just the Board label;
# ctx ownership remains the caller's after restore (02.02.02 infrastructure).
fun test_ignore17c4b_pending_frame_round_trip() -> Bool:
    let board = attack_declaration_fixture()
    let choices : AttackModifierChoices
    choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, 2), ModifierOrigin::characteristic))
    choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, -1), ModifierOrigin::cover))
    let sequence = choose_attack_modifiers(board, choices, false, ModifierSelectionKind::ballistic_skill, true)
    sequence.apply_attack_modifier(board, true)
    let restored = choose_attack_modifiers(board, choices, false, ModifierSelectionKind::ballistic_skill, true)
    let parsed = from_string(restored, to_string(sequence))
    restored.apply_attack_modifier(board, false)
    return parsed and restored.is_done() and restored.result.size() == 1 and restored.result[0].signed_amount() == 2

# Roll arithmetic measures retained operations against the original die before
# applying the hit cap, including non-additive operations (02.02.01/02.02.02).
fun test_ignore17c4b_nonadditive_roll_arithmetic() -> Bool:
    let modifiers : SelectedAttackModifiers
    modifiers.append(rule_modifier(ModifierOperation::multiply, 2))
    let doubled = selected_hit_bonus(4, modifiers)
    modifiers.clear()
    modifiers.append(rule_modifier(ModifierOperation::replace, 1))
    return doubled == 1 and selected_hit_bonus(4, modifiers) == -1

# Current Army Rules fixtures, not replacement Orks datasheets. Profile data
# intentionally remains the small existing core combat fixture (Orks17.F).
fun orks17f_fixture() -> Board:
    let board = attack_declaration_fixture()
    board.armies[0].faction = ArmyFaction::orks
    board.armies[1].faction = ArmyFaction::orks
    board[0][0].keywords.append(Keyword::orks)
    board[1][0].keywords.append(Keyword::orks)
    board[0][0].has_waaagh = true
    board[1][0].has_waaagh = true
    board.identify_units()
    board.start_turn_history()
    return board

# Zero-key is an explicit intrinsic fixture grant; actual passives register
# stable model sources. No datasheet grants are inferred (Orks Waaagh!).
fun orks17f_intrinsic_riled(Model model):
    let grant : RuleEffectGrant
    grant.kind = RuleEffectKind::riled_up
    grant.amount = 1
    model.rule_effects.append(grant)

# Snapshot charge permission when selected to Advance, as Army Rules says;
# movement history persists it separately from subsequently changing buffs.
fun orks17f_select_advance(Board board, UnitID source):
    board[source].history.advance_allows_charge = unit_is_riled_up(board[source])
    record_move(board, source, MovementKind::advance)

# Only live ORKS units with explicit Waaagh! get the Advance re-roll.
fun test_orks17f_waaagh_eligibility() -> Bool:
    let board = orks17f_fixture()
    let valid = unit_has_waaagh(board[0])
    board[0][0].has_waaagh = false
    let absent = !unit_has_waaagh(board[0])
    board[0][0].has_waaagh = true
    board[0][0].keywords.clear()
    let foreign = !unit_has_waaagh(board[0])
    board[0][0].keywords.append(Keyword::orks)
    board[0][0].state = ModelState::pending_destruction
    return valid and absent and foreign and !unit_has_waaagh(board[0])

# Riled supplies a5+ InSv where absent, keeps a better printed save and uses
# shared subsequent arithmetic rather than replacing a better choice.
fun test_orks17f_riled_invulnerable_save() -> Bool:
    let board = orks17f_fixture()
    orks17f_intrinsic_riled(board[0][0])
    let absent = board[0][0].effective_invulnerable_save() == 5
    board[0][0].profile = Profile::captain_octavius
    let better = board[0][0].effective_invulnerable_save() == 4
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::invulnerable_save, ModifierOperation::add, -1))
    return absent and better and board[0][0].effective_invulnerable_save() == 3

# No inherited10th-edition +A/+S is introduced. Ranged Assault is per bearer,
# while melee and unrelated units retain their existing rules (Orks Waaagh!).
fun test_orks17f_riled_assault_only_ranged() -> Bool:
    let board = orks17f_fixture()
    orks17f_intrinsic_riled(board[0][0])
    let ranged = model_weapon_has_rule(board[0][0], 0, WeaponRuleKind::assault)
    let foreign = !model_weapon_has_rule(board[1][0], 0, WeaponRuleKind::assault)
    board[0][0].weapons.append(equipped_weapon(Weapon::choppa))
    let melee = !model_weapon_has_rule(board[0][0], 1, WeaponRuleKind::assault)
    let modifiers = model_weapon_modifiers(board[0][0], 1, ModifiedCharacteristic::attacks, false)
    return ranged and foreign and melee and modifiers.size() == 0

# Actual Assault mode and target legality consume the granted rule (pp.34–35;
# Orks Waaagh!). Riled does not permit shooting after Fall Back or engagement.
fun test_orks17f_assault_shooting_consumers() -> Bool:
    let board = orks17f_fixture()
    orks17f_intrinsic_riled(board[0][0])
    orks17f_select_advance(board, unit_id(0))
    board.begin_phase(BattlePhase::shooting)
    board[0].shooting_kind = ShootingKind::assault
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let valid = shooting_kind_valid(board, unit_id(0), ShootingKind::assault) and declaration_target_valid(board, unit_id(0), declaration, unit_id(1), false)
    board[0].history.fell_back_this_turn = true
    return valid and !shooting_unit_valid(board, unit_id(0))

# Charge permission belongs to this selected Advance even after riled expiry.
# Granting riled after an ordinary Advance cannot retroactively waive it.
fun test_orks17f_advance_charge_snapshot() -> Bool:
    let board = orks17f_fixture()
    orks17f_intrinsic_riled(board[0][0])
    orks17f_select_advance(board, unit_id(0))
    board[0][0].rule_effects.clear()
    let retained = charge_source_valid(board, unit_id(0), false)
    board.start_turn_history()
    orks17f_select_advance(board, unit_id(0))
    orks17f_intrinsic_riled(board[0][0])
    return retained and !charge_source_valid(board, unit_id(0), false)

# Other charge restrictions remain even for riled units (pp.33/65/74).
fun test_orks17f_charge_restrictions_and_reset() -> Bool:
    let board = orks17f_fixture()
    orks17f_intrinsic_riled(board[0][0])
    orks17f_select_advance(board, unit_id(0))
    board[0].history.fell_back_this_turn = true
    let fallback = !charge_source_valid(board, unit_id(0), false)
    board[0].history.fell_back_this_turn = false
    board[0].can_charge = false
    let unrelated = !charge_source_valid(board, unit_id(0), false)
    board.start_turn_history()
    return fallback and unrelated and !board[0].history.advance_allows_charge and !board[0].history.advanced_this_turn

# Waaagh! free re-roll enters the real Advance roll, without CP expenditure.
# This test stops at movement input; placement legality remains core fixtures.
fun test_orks17f_actual_advance_reroll() -> Bool:
    let board = orks17f_fixture()
    board.begin_phase(BattlePhase::movement)
    let sequence = movement(board, unit_id(0), false)
    sequence.advance(board, true)
    let die : Dice
    die = 2
    sequence.roll(board, die)
    let valid = can sequence.keep_it(board, false)
    sequence.keep_it(board, false)
    die = 5
    sequence.reroll(board, die)
    return valid and board.command_points[0] == 0 and board.current_roll.result.value == 5

# Command-start choice is available to both armies, with current player first.
# Declining War Cry spends no battle use and restores decision ownership.
fun test_orks17f_war_cry_decline_and_controller_order() -> Bool:
    let board = orks17f_fixture()
    board.begin_phase(BattlePhase::command)
    let sequence = resolve_timing_window(board, TimingWindow::command_start)
    let rule = OrksTimingRule::war_cry
    let first = !board.current_decision_maker and can sequence.choose_orks_timing_rule(board, rule)
    sequence.finish_timing_rules(board)
    let second = board.current_decision_maker and can sequence.choose_orks_timing_rule(board, rule)
    sequence.finish_timing_rules(board)
    return first and second and sequence.is_done() and !board.armies[0].war_cry_used and !board.armies[1].war_cry_used and !board.current_decision_maker

# Either Command start may call it once per army; the opponent never receives
# the other army's grant. Applying it spends no CP (Orks War Cry).
fun test_orks17f_war_cry_both_armies_and_once() -> Bool:
    let board = orks17f_fixture()
    board.begin_phase(BattlePhase::command)
    let sequence = resolve_timing_window(board, TimingWindow::command_start)
    sequence.choose_orks_timing_rule(board, OrksTimingRule::war_cry)
    let isolated = unit_is_riled_up(board[0]) and !unit_is_riled_up(board[1]) and board.armies[0].war_cry_used
    sequence.choose_orks_timing_rule(board, OrksTimingRule::war_cry)
    let resolved : Bool[2]
    return isolated and sequence.is_done() and unit_is_riled_up(board[1]) and board.armies[1].war_cry_used and !orks_timing_rule_available(board, TimingWindow::command_start, false, OrksTimingRule::war_cry, resolved) and board.command_points[0] == 0 and board.command_points[1] == 0

# Printed start window excludes Command abilities/end/round; configured
# non-Orks armies cannot activate a stray fixture's Waaagh! data.
fun test_orks17f_war_cry_wrong_window_and_faction() -> Bool:
    let board = orks17f_fixture()
    let resolved : Bool[2]
    let absent = !orks_timing_rule_available(board, TimingWindow::command_abilities, false, OrksTimingRule::war_cry, resolved) and !orks_timing_rule_available(board, TimingWindow::round_start, false, OrksTimingRule::war_cry, resolved)
    board.armies[0].faction = ArmyFaction::space_marines
    return absent and !war_cry_available(board, false)

# End of NEXT turn is distinct from end of activation turn and next start.
# Activation in either player's turn has the same two-turn interval.
fun test_orks17f_war_cry_end_next_turn() -> Bool:
    let board = orks17f_fixture()
    board.open_timing_window(TimingWindow::command_start)
    call_war_cry(board, false)
    board.close_timing_window()
    refresh_source_effects(board, TimingWindow::turn_end)
    let own_end = unit_is_riled_up(board[0])
    board.current_player = true
    board.start_turn_history()
    let next_start = unit_is_riled_up(board[0])
    refresh_source_effects(board, TimingWindow::turn_end)
    return own_end and next_start and !unit_is_riled_up(board[0]) and board.source_effects.empty() and board.armies[0].war_cry_used

# Offboard army units receive War Cry without illegal range/visibility tests;
# a missing Waaagh! ability is not granted by faction membership alone.
fun test_orks17f_war_cry_reserves_and_passengers() -> Bool:
    let board = orks17f_fixture()
    let reserved : Unit
    reserved = board[0]
    reserved.identity = invalid_entity_identity()
    reserved[0].identity = invalid_entity_identity()
    board.identify_unit(reserved)
    mark_unit_offboard(reserved, true)
    board.reserve_units.append(reserved)
    let embarked : Unit
    embarked = reserved
    embarked.identity = invalid_entity_identity()
    embarked[0].identity = invalid_entity_identity()
    board.identify_unit(embarked)
    board.embarked_units.append(embarked)
    board[1][0].has_waaagh = false
    board.open_timing_window(TimingWindow::command_start)
    call_war_cry(board, false)
    board.close_timing_window()
    return unit_is_riled_up(board[0]) and unit_is_riled_up(board.reserve_units[0]) and unit_is_riled_up(board.embarked_units[0]) and !unit_is_riled_up(board[1]) and board.source_effects.size() == 3

# A retained/destroyed source cannot cancel the accepted army-wide War Cry.
# Archived grants are nevertheless cleaned up at their printed expiry.
fun test_orks17f_war_cry_source_death_archive_cleanup() -> Bool:
    let board = orks17f_fixture()
    board.open_timing_window(TimingWindow::command_start)
    call_war_cry(board, false)
    board.close_timing_window()
    board[0][0].state = ModelState::pending_destruction
    board[0].remove_model(0)
    board.current_player = true
    board.start_turn_history()
    let persisted = is_riled_up(board[0].destroyed_models.value[0])
    refresh_source_effects(board, TimingWindow::turn_end)
    return persisted and !is_riled_up(board[0].destroyed_models.value[0])

# Overlapping permanent and War Cry copies retain independent handles; only
# live-model permanent sources end on source death (Stompa Effigy/Super Runts).
fun test_orks17f_permanent_and_war_cry_overlap() -> Bool:
    let board = orks17f_fixture()
    board[0][0].grants_unit_riled_up = true
    register_orks_passive_rules(board)
    register_orks_passive_rules(board)
    let single = board.source_instances.size() == 1 and board[0][0].rule_effects.size() == 1
    board.open_timing_window(TimingWindow::command_start)
    call_war_cry(board, false)
    board.close_timing_window()
    let overlap = board[0][0].rule_effects.size() == 2
    board.current_player = true
    board.start_turn_history()
    refresh_source_effects(board, TimingWindow::turn_end)
    return single and overlap and board[0][0].rule_effects.size() == 1 and unit_is_riled_up(board[0])

# Own-unit passives work in reserves/embarked banks; they are not external
# auras and require no range to an offboard unit (appendix01.02.04).
fun test_orks17f_permanent_offboard_bank_transfer() -> Bool:
    let board = orks17f_fixture()
    board[0][0].grants_unit_riled_up = true
    mark_unit_offboard(board[0], true)
    board.reserve_units.append(board[0])
    board.units.erase(0)
    register_orks_passive_rules(board)
    let reserved = unit_is_riled_up(board.reserve_units[0])
    board.embarked_units.append(board.reserve_units[0])
    board.reserve_units.erase(0)
    refresh_source_effects(board, TimingWindow::none)
    return reserved and unit_is_riled_up(board.embarked_units[0]) and board.source_effects.size() == 1

# Permanent source follows a transferred model's current unit, while overlap
# keys from other sources are retained. Attachment integration remains17.G.
fun test_orks17f_permanent_source_transfer() -> Bool:
    let board = orks17f_fixture()
    board[0].models.append(board[0][0])
    board[0][1].identity = invalid_entity_identity()
    board.identify_unit(board[0])
    board[0][0].grants_unit_riled_up = true
    register_orks_passive_rules(board)
    let target : Unit
    target.owned_by_player1 = false
    target.models.append(board[0][0])
    board[0].models.erase(0)
    board.identify_unit(target)
    board.units.append(target)
    refresh_source_effects(board, TimingWindow::none)
    return !unit_is_riled_up(board[0]) and unit_is_riled_up(board.units.back()) and board.source_effects.size() == 1

# A model death stops the source-bound passive for its surviving unit; Fight
# on Death retention is not active ability permission (destruction p.87).
fun test_orks17f_permanent_source_death() -> Bool:
    let board = orks17f_fixture()
    board[0].models.append(board[0][0])
    board[0][1].identity = invalid_entity_identity()
    board.identify_unit(board[0])
    board[0][0].grants_unit_riled_up = true
    register_orks_passive_rules(board)
    board[0][0].state = ModelState::pending_destruction
    refresh_source_effects(board, TimingWindow::none)
    return !unit_is_riled_up(board[0]) and !is_riled_up(board[0][0]) and board.source_effects.empty()

# Da Boss requires exactly the selected live Warlord's explicit ability, not
# an arbitrary living boss. Mandatory round-start1CP is separate from Core CP.
fun test_orks17f_da_boss_mandatory_once_per_window() -> Bool:
    let board = orks17f_fixture()
    board[0][0].has_da_boss = true
    board.armies[0].warlord = board[0][0].identity
    board[0][0].keywords.append(Keyword::character)
    board[0][0].keywords.append(Keyword::warlord)
    let sequence = resolve_timing_window(board, TimingWindow::round_start)
    let mandatory = !can sequence.finish_timing_rules(board)
    sequence.choose_orks_timing_rule(board, OrksTimingRule::da_boss)
    return mandatory and sequence.is_done() and board.command_points[0] == 1 and board.command_points[1] == 0 and !board.current_decision_maker

# Both players receive their own mandatory1CP in controller order. Neither
# gains it from a different player's Warlord (Orks Army Rules / Da Boss).
fun test_orks17f_da_boss_both_players() -> Bool:
    let board = orks17f_fixture()
    board[0][0].has_da_boss = true
    board[1][0].has_da_boss = true
    board.armies[0].warlord = board[0][0].identity
    board[0][0].keywords.append(Keyword::character)
    board[0][0].keywords.append(Keyword::warlord)
    board.armies[1].warlord = board[1][0].identity
    board[1][0].keywords.append(Keyword::character)
    board[1][0].keywords.append(Keyword::warlord)
    let sequence = resolve_timing_window(board, TimingWindow::round_start)
    sequence.choose_orks_timing_rule(board, OrksTimingRule::da_boss)
    let opponent = board.current_decision_maker and !can sequence.finish_timing_rules(board)
    sequence.choose_orks_timing_rule(board, OrksTimingRule::da_boss)
    return opponent and sequence.is_done() and board.command_points[0] == 1 and board.command_points[1] == 1

# Missing, foreign or destroyed Warlord never substitutes another model;
# selected reserve Warlord can use its own rule (appendix01.02.04).
fun test_orks17f_da_boss_identity_life_and_offboard() -> Bool:
    let board = orks17f_fixture()
    board[0][0].has_da_boss = true
    let unset = !da_boss_available(board, false)
    board.armies[0].warlord = board[1][0].identity
    let foreign = !da_boss_available(board, false) and !valid_orks_army_state(board)
    board.armies[0].warlord = board[0][0].identity
    board[0][0].keywords.append(Keyword::character)
    board[0][0].keywords.append(Keyword::warlord)
    mark_unit_offboard(board[0], true)
    board.reserve_units.append(board[0])
    board.units.erase(0)
    let offboard = da_boss_available(board, false)
    board.reserve_units[0][0].state = ModelState::pending_destruction
    return unset and foreign and offboard and !da_boss_available(board, false)

# Supplied11th-edition Da Boss lacks the legacy extra-CP ceiling. Existing
# CP is preserved and literal gain is not silently blocked by that old flag.
fun test_orks17f_da_boss_literal_cp_gain() -> Bool:
    let board = orks17f_fixture()
    board[0][0].has_da_boss = true
    board.armies[0].warlord = board[0][0].identity
    board[0][0].keywords.append(Keyword::character)
    board[0][0].keywords.append(Keyword::warlord)
    board.obtained_extra_cp_this_round[0] = true
    board.command_points[0] = 7
    let sequence = resolve_timing_window(board, TimingWindow::round_start)
    sequence.choose_orks_timing_rule(board, OrksTimingRule::da_boss)
    return sequence.is_done() and board.command_points[0] == 8

# Matching Game saves retain army usage, stable Warlord and pending riled
# effects. Bad keys/source metadata are rejected before effective consumers.
fun test_orks17f_saved_state_and_forged_handles() -> Bool:
    let game = play()
    game.board = orks17f_fixture()
    game.board.armies[0].warlord = game.board[0][0].identity
    game.board[0][0].keywords.append(Keyword::character)
    game.board[0][0].keywords.append(Keyword::warlord)
    game.board.open_timing_window(TimingWindow::command_start)
    call_war_cry(game.board, false)
    game.board.close_timing_window()
    let saved = to_string(game)
    let restored = play()
    let accepted = set_state(restored, saved)
    let retained = accepted and restored.board.armies[0].war_cry_used and is_riled_up(restored.board[0][0]) and restored.board.armies[0].warlord == game.board.armies[0].warlord
    restored.board[0][0].rule_effects[0].source_effect.value = 999
    return retained and !valid_state_foundations(restored.board)

# Stale selected Assault snapshots cannot outlive their riled effect (p.78;
# appendix01.02.02). This also tests the actual declaration-rule consumer.
fun test_orks17f_assault_snapshot_expiry() -> Bool:
    let board = orks17f_fixture()
    board.open_timing_window(TimingWindow::command_start)
    call_war_cry(board, false)
    board.close_timing_window()
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let before = chosen_weapon_has_rule(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::assault)
    board.current_player = true
    board.start_turn_history()
    refresh_source_effects(board, TimingWindow::turn_end)
    return before and !chosen_weapon_has_rule(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::assault) and !model_weapon_has_rule(board[0][0], 0, WeaponRuleKind::assault)

# User-supplied Warlord definition: an Orks Character unit, then a Character
# model. Other player/non-faction/non-Character candidates remain illegal.
fun orks17f_warlord_fixture() -> Board:
    let board = orks17f_fixture()
    board[0][0].keywords.append(Keyword::character)
    board[1][0].keywords.append(Keyword::character)
    mark_unit_offboard(board[0], true)
    mark_unit_offboard(board[1], true)
    board.reserve_units.append(board[0])
    board.reserve_units.append(board[1])
    board.units.clear()
    return board

# Real two-step selector rejects foreign/spare indices, grants WARLORD and
# restores the previous decision owner/context (user Warlord definition).
fun test_orks17f_actual_warlord_selection() -> Bool:
    let board = orks17f_warlord_fixture()
    board.current_decision_maker = true
    board.selected_warlord_unit = 1
    let sequence = select_orks_warlord(board, false)
    let unit : UnitID
    unit = 1
    let foreign = !can sequence.choose_warlord_unit(board, unit)
    unit = 31
    let spare = !can sequence.choose_warlord_unit(board, unit)
    unit = 0
    sequence.choose_warlord_unit(board, unit)
    let model : ModelID
    model = 31
    let spare_model = !can sequence.choose_warlord_model(board, model)
    model = 0
    sequence.choose_warlord_model(board, model)
    return foreign and spare and spare_model and sequence.is_done() and board.reserve_units[0][0].has_keyword(Keyword::warlord) and board.armies[0].warlord == board.reserve_units[0][0].identity and board.current_decision_maker and board.selected_warlord_unit.get() == 1 and valid_state_foundations(board)

# Forced named model takes precedence over an ordinary alternative; if several
# units require a Warlord, select one eligible required unit (user definition).
fun test_orks17f_required_warlord_and_model() -> Bool:
    let board = orks17f_warlord_fixture()
    board.reserve_units[0].models.append(board.reserve_units[0][0])
    board.reserve_units[0][1].identity = invalid_entity_identity()
    board.identify_unit(board.reserve_units[0])
    board.reserve_units[0][1].must_be_warlord = true
    let model : ModelID
    let ordinary = !warlord_model_valid(board, false, unit_id(0), model, Keyword::orks)
    model = 1
    return ordinary and warlord_model_valid(board, false, unit_id(0), model, Keyword::orks) and !warlord_unit_valid(board, false, unit_id(1), Keyword::orks)

# Prohibition overrides required status and excludes that model from both
# optional and forced eligibility (user Warlord definition).
fun test_orks17f_cannot_warlord_overrides_required() -> Bool:
    let board = orks17f_warlord_fixture()
    board.reserve_units[0].models.append(board.reserve_units[0][0])
    board.reserve_units[0][1].identity = invalid_entity_identity()
    board.identify_unit(board.reserve_units[0])
    board.reserve_units[0][0].must_be_warlord = true
    board.reserve_units[0][0].cannot_be_warlord = true
    let model : ModelID
    let prohibited = !warlord_model_valid(board, false, unit_id(0), model, Keyword::orks)
    model = 1
    return prohibited and warlord_model_valid(board, false, unit_id(0), model, Keyword::orks)

# A required unit can supply any eligible Character; the unit's faction union
# and model's Character status are checked independently (user definition).
fun test_orks17f_warlord_unit_and_character_conditions() -> Bool:
    let board = orks17f_warlord_fixture()
    board.reserve_units[0].must_supply_warlord = true
    let model : ModelID
    let required = warlord_model_valid(board, false, unit_id(0), model, Keyword::orks)
    board.reserve_units[0][0].keywords.clear()
    board.reserve_units[0][0].keywords.append(Keyword::orks)
    let non_character = !warlord_unit_valid(board, false, unit_id(0), Keyword::orks)
    board.reserve_units[0][0].keywords.clear()
    board.reserve_units[0][0].keywords.append(Keyword::character)
    return required and non_character and !warlord_unit_valid(board, false, unit_id(0), Keyword::orks)

# Two required units still allow exactly one Warlord; unit/model prohibitions
# must not be inferred from a datasheet name (user definition).
fun test_orks17f_multiple_required_units() -> Bool:
    let board = orks17f_warlord_fixture()
    board.reserve_units[1].owned_by_player1 = false
    board.reserve_units[0].must_supply_warlord = true
    board.reserve_units[1].must_supply_warlord = true
    let sequence = select_orks_warlord(board, false)
    let choices = can sequence.choose_warlord_unit(board, unit_id(0)) and can sequence.choose_warlord_unit(board, unit_id(1))
    sequence.choose_warlord_unit(board, unit_id(1))
    let model : ModelID
    sequence.choose_warlord_model(board, model)
    return choices and sequence.is_done() and !board.reserve_units[0][0].has_keyword(Keyword::warlord) and board.reserve_units[1][0].has_keyword(Keyword::warlord)

# Firing Deck's borrowed profile receives the carrier's riled Assault without
# modifying the passenger's equipped gun (p.81 / Orks Waaagh!).
fun test_orks17f_borrowed_carrier_assault() -> Bool:
    let board = orks17f_fixture()
    let passenger : Unit
    passenger = board[1]
    passenger.owned_by_player1 = false
    passenger.embarked_transport = board[0][0].identity
    mark_unit_offboard(passenger, true)
    board.embarked_units.append(passenger)
    board[1].models.clear()
    board[1].retired = true
    board[0][0].firing_deck = 1
    board[0][0].weapons.clear()
    orks17f_intrinsic_riled(board[0][0])
    let model : ModelID
    let declaration = make_deck_declaration(board, unit_id(0), model, unit_id(0), model, 0)
    return carrier_has_ranged_rule(board, unit_id(0), WeaponRuleKind::assault) and chosen_weapon_has_rule(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::assault) and !model_weapon_has_rule(board.embarked_units[0][0], 0, WeaponRuleKind::assault)

# P66/source-list fixtures use existing circle/profiles only as test data.
# Named attachment metadata does not claim complete current Orks datasheets.
fun attachment17g_fixture() -> Board:
    let board : Board
    let bodyguard = make_infernus_squad()
    for model in range(bodyguard.models.size()):
        bodyguard[model].abilities.clear()
    configure_orks_attachment(bodyguard, OrksDatasheet::boyz)
    board.reserve_units.append(bodyguard)
    let leader = make_tantus()
    leader[0].abilities.clear()
    configure_orks_attachment(leader, OrksDatasheet::warboss)
    board.reserve_units.append(leader)
    let support = make_octavius()
    support[0].abilities.clear()
    configure_orks_attachment(support, OrksDatasheet::painboy)
    board.reserve_units.append(support)
    board.identify_units()
    return board

# Move an already formed fixture to the battlefield; this is not a setup
# permission or a substitute for the later datasheet/geometry adapters.
fun attachment17g_battlefield(Board board):
    while !board.reserve_units.empty():
        mark_unit_offboard(board.reserve_units[0], false)
        board.units.append(board.reserve_units[0])
        board.reserve_units.erase(0)
    for unit in range(board.units.size()):
        for model in range(board[unit].models.size()):
            board[unit][model].position = board_position(5 + (model % 4) * 2 + unit * 15, 5 + (model / 4) * 2)
        board[unit].capture_starting_strength()
        board[unit].can_shoot = true
        board[unit].can_charge = true

# Typed per-component source helper: effects apply to the attached unit while
# its original Leader component confers them (pp.66–67/19.04).
fun attachment17g_source(Board board, EntityIdentity component, Int rule) -> SourceInstance:
    let source : SourceInstance
    source.source_unit = component
    source.rule = rule
    source.owner = false
    source.own_unit_passive = true
    source.offboard_allowed = true
    source.requires_live_source = true
    source.duration = SourceDuration::battle
    source.grant = source_characteristic_grant(characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 2))
    return source

# Main damage entry snapshots a real attacking unit rather than using low-level
# storage damage as a substitute for p67 timing (damage/destruction pp.19/87).
fun attachment17g_job(Int target, Int attacker, Bool from_attack) -> DamageJob:
    return damage_job(DamageKind::normal, unit_id(target), unit_id(attacker), true, from_attack, 1, invalid_entity_identity())

# All17 included Leader/Support rows, including the six-entry Big Mek maximum.
# Lists are independently checked against the retrieved attachment cards.
fun test_attachment17g_included_permission_role_counts() -> Bool:
    let leaders = 0
    let supports = 0
    let tag : OrksDatasheet
    for code in range(MAX_DATASHEETCODE):
        tag.value = code
        let unit : Unit
        configure_orks_attachment(unit, tag)
        if unit.attachment_role.value == AttachmentRole::leader.value:
            leaders = leaders + 1
        if unit.attachment_role.value == AttachmentRole::support.value:
            supports = supports + 1
    return leaders == 10 and supports == 7

# Explicit examples distinguish related cards: only Mega Armour/Nazdreg lead
# Meganobz, while Shokk Attack Gun lacks Big Mek's Flash Gitz/Breaka permissions.
fun test_attachment17g_exact_permission_lists() -> Bool:
    let mek : Unit
    configure_orks_attachment(mek, OrksDatasheet::big_mek)
    let big = mek.permitted_bodyguards.size() == 6 and mek.permitted_bodyguards[2].value == OrksDatasheet::flash_gitz.value and mek.permitted_bodyguards[5].value == OrksDatasheet::tankbustas.value
    configure_orks_attachment(mek, OrksDatasheet::big_mek_with_shokk_attack_gun)
    let shokk = mek.permitted_bodyguards.size() == 4 and mek.permitted_bodyguards[1].value == OrksDatasheet::mek_gunz.value and mek.permitted_bodyguards[2].value == OrksDatasheet::nobz.value
    configure_orks_attachment(mek, OrksDatasheet::nazdreg)
    return big and shokk and mek.permitted_bodyguards.size() == 1 and mek.permitted_bodyguards[0].value == OrksDatasheet::meganobz.value

# No excluded Forge World/Legends source receives an attachment implementation.
fun test_attachment17g_excluded_and_unknown_unavailable() -> Bool:
    let unit : Unit
    configure_orks_attachment(unit, OrksDatasheet::warboss_on_warbike)
    let legends = unit.attachment_role.value == 0 and unit.permitted_bodyguards.empty()
    configure_orks_attachment(unit, OrksDatasheet::gargantuan_squiggoth)
    let forge = unit.attachment_role.value == 0 and unit.permitted_bodyguards.empty()
    configure_orks_attachment(unit, OrksDatasheet::unknown)
    return legends and forge and unit.permitted_bodyguards.empty() and unit.attachment_role.value == 0

# P66 permits one role of each kind; identity/whole-model history is preserved.
fun test_attachment17g_leader_and_support_slots() -> Bool:
    let board = attachment17g_fixture()
    let leader = board.reserve_units[1].identity
    let support = board.reserve_units[2].identity
    let model = board.reserve_units[1][0].identity
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    let leader_only = board.reserve_units[0].attached_units.size() == 1 and !attachment_role_available(board.reserve_units[0], AttachmentRole::leader)
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    ref combined = board.reserve_units[0]
    return leader_only and combined.models.size() == 7 and combined.attached_units.size() == 2 and combined.attached_units[0].identity == leader and combined.attached_units[1].identity == support and combined[5].identity == model and combined[5].original_unit == leader and combined.starting_strenght == 7 and combined.bodyguard_starting_strength == 5 and valid_state_foundations(board)

# Support-first has the same role budgets, not a blanket one-character limit.
fun test_attachment17g_support_then_leader() -> Bool:
    let board = attachment17g_fixture()
    attach_reserved_unit(board, unit_id(2), unit_id(0), false)
    let support_only = !attachment_role_available(board.reserve_units[0], AttachmentRole::support) and attachment_role_available(board.reserve_units[0], AttachmentRole::leader)
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    return support_only and board.reserve_units[0].attached_units.size() == 2 and board.reserve_units[0].starting_strenght == 7

# Foreign, self, spare, wrong bodyguard, already-attached and in-battle choices
# are rejected without mutating state (p66/Godot bounded selectors).
fun test_attachment17g_legality_rejects_invalid_and_atomic() -> Bool:
    let board = attachment17g_fixture()
    let before = to_string(board)
    let rejected = !attachment_valid(board, unit_id(1), unit_id(1), false) and !attachment_valid(board, unit_id(31), unit_id(0), false) and !attachment_valid(board, unit_id(1), unit_id(31), false) and !attachment_valid(board, unit_id(1), unit_id(0), true) and !attachment_valid(board, unit_id(1), unit_id(2), false)
    let unchanged = to_string(board) == before
    board.reserve_units[0].roster_datasheet = OrksDatasheet::gretchin.value
    let wrong = !attachment_valid(board, unit_id(1), unit_id(0), false)
    board.reserve_units[0].roster_datasheet = OrksDatasheet::boyz.value
    board.start_turn_history()
    return rejected and unchanged and wrong and !attachment_valid(board, unit_id(1), unit_id(0), false)

# Generic p66 transfer supports multi-model leaders instead of asserting size1.
# Source components retain their own count within the combined starting strength.
fun test_attachment17g_multi_model_leader() -> Bool:
    let board = attachment17g_fixture()
    board.reserve_units[1].models.append(board.reserve_units[1][0])
    board.reserve_units[1][1].identity = invalid_entity_identity()
    board.identify_unit(board.reserve_units[1])
    let second = board.reserve_units[1][1].identity
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    return board.reserve_units[0].models.size() == 7 and board.reserve_units[0].attached_units[0].starting_strength == 2 and board.reserve_units[0][6].identity == second and valid_state_foundations(board)

# Duplicate Leaders/Supports cannot consume an existing role; empty/dead
# prebattle sources and overflow also cannot produce a valid action (p66).
fun test_attachment17g_duplicate_role_and_capacity() -> Bool:
    let board = attachment17g_fixture()
    configure_orks_attachment(board.reserve_units[2], OrksDatasheet::warboss)
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    let duplicate = !attachment_valid(board, unit_id(1), unit_id(0), false)
    let bounded = attachment17g_fixture()
    bounded.reserve_units[0].models.resize(32)
    for offset in range(27):
        let model = offset + 5
        bounded.reserve_units[0][model] = bounded.reserve_units[0][0]
        bounded.reserve_units[0][model].identity = invalid_entity_identity()
    bounded.identify_unit(bounded.reserve_units[0])
    return duplicate and !attachment_valid(bounded, unit_id(1), unit_id(0), false)

# Attaching an earlier reserve slot safely commits to the later target before
# erasure/compaction; persistent model/source references do not shift (p66/88).
fun test_attachment17g_source_before_target_compaction() -> Bool:
    let board = attachment17g_fixture()
    let bodyguard : Unit
    bodyguard = board.reserve_units[0]
    board.reserve_units[0] = board.reserve_units[1]
    board.reserve_units[1] = bodyguard
    let target = board.reserve_units[1].identity
    attach_reserved_unit(board, unit_id(0), unit_id(1), false)
    return board.reserve_units[0].identity == target and board.reserve_units[0].models.size() == 6 and board.reserve_units[0].attached_units.size() == 1

# Actual prebattle frame owns choices and restores its caller. Passing one
# player cannot let that player re-enter or prevent the other from attaching.
fun test_attachment17g_frame_owner_and_passes() -> Bool:
    let board = attachment17g_fixture()
    board.current_decision_maker = true
    let sequence = attach_leaders(board)
    let first = !board.current_decision_maker and can sequence.attach_unit(board, unit_id(1), unit_id(0))
    sequence.done_attaching(board)
    let second = board.current_decision_maker and !can sequence.attach_unit(board, unit_id(1), unit_id(0))
    sequence.done_attaching(board)
    return first and second and sequence.is_done() and board.current_decision_maker

# p67 unit keyword union does not copy Leader keywords into bodyguard models.
fun test_attachment17g_keyword_union_not_model_spread() -> Bool:
    let board = attachment17g_fixture()
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    return board.reserve_units[0].has_keyword(Keyword::psyker) and !board.reserve_units[0][0].has_keyword(Keyword::psyker) and board.reserve_units[0][5].has_keyword(Keyword::psyker)

# Bodyguard T outranks even a tougher Leader; when bodyguards are physically
# removed, remaining Leaders/Supports supply the maximum (p66/05.02.01).
fun test_attachment17g_bodyguard_toughness_then_remaining() -> Bool:
    let board = attachment17g_fixture()
    board.reserve_units[1][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 6))
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    let bodyguard_t = board[0][0].effective_toughness()
    let before = board[0].get_unit_toughtness() == bodyguard_t
    for casualty in range(5):
        board[0].remove_model(0)
    return before and board[0].get_unit_toughtness() == board[0][0].effective_toughness() and board[0].get_unit_toughtness() > bodyguard_t and board[0].attached_units.size() == 1

# Dead bodyguards do not split Leaders and Support or restore individual counts.
# Half-strength remains against the combined initial7 models (pp66/86).
fun test_attachment17g_bodyguard_death_keeps_combined_unit() -> Bool:
    let board = attachment17g_fixture()
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    for casualty in range(5):
        board[0].remove_model(0)
    return board.units.size() == 1 and board[0].models.size() == 2 and board[0].starting_strenght == 7 and board[0].attached_units.size() == 2 and board[0].is_at_or_below_half_strength() and component_started_leading(board[0], board[0][0].original_unit) and component_started_leading(board[0], board[0][1].original_unit)

# A typed unit ability spreads through the attached unit until its component's
# last member dies; a raw model-only modifier never spreads (p67/19.04).
fun test_attachment17g_scoped_unit_ability_and_model_modifier() -> Bool:
    let board = attachment17g_fixture()
    board.reserve_units[1].unit_abilities.append(AbilityKind::deep_strike)
    board.reserve_units[1][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 3))
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    let granted = board.reserve_units[0].all_have_ability(AbilityKind::deep_strike) and !board.reserve_units[0][0].has_ability(AbilityKind::deep_strike) and board.reserve_units[0][0].effective_movement(6) == 6 and board.reserve_units[0][5].effective_movement(6) == 9
    board.reserve_units[0].remove_model(5)
    return granted and !board.reserve_units[0].has_ability(AbilityKind::deep_strike)

# p67 component rules depend on the LAST member, not their first bearer.
fun test_attachment17g_multi_model_component_lifetime() -> Bool:
    let board = attachment17g_fixture()
    board.reserve_units[1].unit_abilities.append(AbilityKind::stealth)
    board.reserve_units[1].models.append(board.reserve_units[1][0])
    board.reserve_units[1][1].identity = invalid_entity_identity()
    board.identify_unit(board.reserve_units[1])
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    board.reserve_units[0].remove_model(5)
    let survivor = board.reserve_units[0].has_ability(AbilityKind::stealth)
    board.reserve_units[0].remove_model(5)
    return survivor and !board.reserve_units[0].has_ability(AbilityKind::stealth)

# Bodyguard-scoped rules end with the bodyguard component rather than with the
# attached unit's last Leader, and start again on a later validated revival.
fun test_attachment17g_bodyguard_rule_lifetime_and_revival() -> Bool:
    let board = attachment17g_fixture()
    board.reserve_units[0].unit_abilities.append(AbilityKind::stealth)
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    for casualty in range(5):
        board[0].remove_model(0)
    let gone = !board[0].has_ability(AbilityKind::stealth)
    let returned : Model
    returned = board[0].destroyed_models.value[0]
    board[0].destroyed_models.value.erase(0)
    restore_attachment_provenance(board[0], returned)
    board[0].models.append(returned)
    return gone and board[0].has_ability(AbilityKind::stealth) and board[0].starting_strenght == 6 and valid_state_foundations(board)

# Unit-only source identities resolve absorbed components instead of pointing
# at a removed reserve slot (pp66–67). Usage belongs to the current attached unit.
fun test_attachment17g_component_source_resolution() -> Bool:
    let board = attachment17g_fixture()
    let component = board.reserve_units[1].identity
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    let source = attachment17g_source(board, component, 200)
    source.requires_leading = true
    register_source_instance(board, source)
    let location = locate_source(board, component, invalid_entity_identity())
    return location.found and location.bank.value == SourceBank::reserves.value and location.unit.value == 0 and source_alive(board, source) and board.reserve_units[0][0].effective_movement(6) == 8 and valid_source_foundations(board)

# p67 leading permission persists after bodyguards die; an unattached Leader
# cannot use a rule with that condition merely because it has Leader metadata.
fun test_attachment17g_while_leading_after_bodyguard_death() -> Bool:
    let board = attachment17g_fixture()
    let component = board.reserve_units[1].identity
    let source = attachment17g_source(board, component, 201)
    source.requires_leading = true
    register_source_instance(board, source)
    let death_rule = source
    death_rule.own_unit_passive = false
    death_rule.trigger = SourceEventKind::unit_destroyed
    let death_event = source_event(SourceEventKind::unit_destroyed, component, invalid_entity_identity(), invalid_entity_identity())
    let solo = !source_alive(board, source) and board.reserve_units[0][0].effective_movement(6) == 6 and !source_event_available(board, death_rule, death_event)
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    for casualty in range(5):
        board[0].remove_model(0)
    refresh_source_effects(board, TimingWindow::none)
    death_event.unit = board[0].identity
    return solo and source_alive(board, source) and board[0][0].effective_movement(6) == 8 and source_event_available(board, death_rule, death_event)

# P67 registered source grants stay active through attack-caused source death,
# then expire before that attacker's destruction callbacks/removal.
fun test_attachment17g_attack_deferred_source_grant() -> Bool:
    let board = attachment17g_fixture()
    let component = board.reserve_units[1].identity
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    board[1].owned_by_player1 = true
    let source = attachment17g_source(board, component, 202)
    register_source_instance(board, source)
    let model : ModelID
    model = 5
    commit_wound_loss(board, attachment17g_job(0, 1, true), model, board[0][5].profile.wounds(), false)
    refresh_source_effects(board, TimingWindow::none)
    let retained = !source_alive(board, source) and source_confers_rules(board, source) and board[0][0].effective_movement(6) == 8 and board[0][5].attachment_abilities_retained
    release_attachment_rules(board, unit_id(1))
    return retained and !source_confers_rules(board, source) and board[0][0].effective_movement(6) == 6 and !board[0][5].attachment_abilities_retained

# Non-attack destruction has no attacking-unit interval; the grant ends now.
fun test_attachment17g_non_attack_source_expires_immediately() -> Bool:
    let board = attachment17g_fixture()
    let component = board.reserve_units[1].identity
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    board[1].owned_by_player1 = true
    let source = attachment17g_source(board, component, 203)
    register_source_instance(board, source)
    let model : ModelID
    model = 5
    commit_wound_loss(board, attachment17g_job(0, 1, false), model, board[0][5].profile.wounds(), false)
    refresh_source_effects(board, TimingWindow::none)
    return board[0].models.size() == 5 and !source_confers_rules(board, source) and board[0][0].effective_movement(6) == 6 and board.source_effects.empty()

# A unit-source grant returns when its original archived component member is
# revived; original wargear/physical usage/start counts are preserved (p67/88).
fun test_attachment17g_source_revival_restores_lifetime() -> Bool:
    let board = attachment17g_fixture()
    let component = board.reserve_units[1].identity
    board.reserve_units[1][0].used_once_per_battle_weapon[0] = true
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    let source = attachment17g_source(board, component, 204)
    source.requires_leading = true
    register_source_instance(board, source)
    board[0].remove_model(5)
    refresh_source_effects(board, TimingWindow::none)
    let expired = board[0][0].effective_movement(6) == 6
    let returned : Model
    returned = board[0].destroyed_models.value[0]
    board[0].destroyed_models.value.erase(0)
    restore_attachment_provenance(board[0], returned)
    board[0].models.append(returned)
    refresh_source_effects(board, TimingWindow::none)
    return expired and source_confers_rules(board, source) and board[0][0].effective_movement(6) == 8 and board[0][5].used_once_per_battle_weapon[0] and board[0].starting_strenght == 6 and valid_state_foundations(board)

# Painboss's own keyword/M changes do not alter other models or become a unit-
# wide characteristic grant (Runnin' wiv da Herd; Painboss source card).
fun test_attachment17g_painboss_mounted_bearer_only() -> Bool:
    let board = attachment17g_fixture()
    configure_orks_attachment(board.reserve_units[0], OrksDatasheet::squighog_boyz)
    board.reserve_units[0][0].keywords.append(Keyword::mounted)
    configure_orks_attachment(board.reserve_units[2], OrksDatasheet::painboss)
    attach_reserved_unit(board, unit_id(2), unit_id(0), false)
    return !board.reserve_units[0][5].has_keyword(Keyword::infantry) and board.reserve_units[0][5].has_keyword(Keyword::mobile) and board.reserve_units[0][5].has_keyword(Keyword::mounted) and board.reserve_units[0][5].effective_movement(6) == 10 and board.reserve_units[0][1].has_keyword(Keyword::infantry) and !board.reserve_units[0][1].has_keyword(Keyword::mobile) and board.reserve_units[0][1].effective_movement(6) == 6

# The+4 M is an addition before division/rounding, and infantry attachment does
# not activate it (Painboss card; appendix02.02.01).
fun test_attachment17g_painboss_arithmetic_and_infantry() -> Bool:
    let board = attachment17g_fixture()
    configure_orks_attachment(board.reserve_units[0], OrksDatasheet::beast_snagga_boyz)
    configure_orks_attachment(board.reserve_units[2], OrksDatasheet::painboss)
    board.reserve_units[2][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::divide, 2))
    attach_reserved_unit(board, unit_id(2), unit_id(0), false)
    let infantry = board.reserve_units[0][5].effective_movement(6) == 3 and board.reserve_units[0][5].has_keyword(Keyword::infantry)
    board.reserve_units[0][5].painboss_mounted_attachment = true
    return infantry and board.reserve_units[0][5].effective_movement(6) == 5

# Restore integrity rejects wrong component roles, strengths, origins and
# duplicate role slots rather than letting forged metadata change combat.
fun test_attachment17g_invalid_component_metadata() -> Bool:
    let board = attachment17g_fixture()
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    board.reserve_units[0].attached_units[0].role.value = 0
    let role = !valid_attachment_state(board.reserve_units[0])
    board.reserve_units[0].attached_units[0].role = AttachmentRole::leader
    board.reserve_units[0].starting_strenght = 5
    let strength = !valid_attachment_state(board.reserve_units[0])
    board.reserve_units[0].starting_strenght = 6
    board.reserve_units[0][5].original_unit = 999
    return role and strength and !valid_attachment_state(board.reserve_units[0])

# Matching Game saves retain bounded components and all original member IDs.
fun test_attachment17g_saved_components_round_trip() -> Bool:
    let game = play()
    game.board = attachment17g_fixture()
    attach_reserved_unit(game.board, unit_id(1), unit_id(0), false)
    attach_reserved_unit(game.board, unit_id(1), unit_id(0), false)
    let restored = play()
    return set_state(restored, to_string(game)) and restored.board.reserve_units[0].attached_units.size() == 2 and restored.board.reserve_units[0].starting_strenght == 7 and valid_state_foundations(restored.board)

# Lone Operative protection does not return just because bodyguards died;
# the source remains part of the same attached unit (p83/19.01.01).
fun test_attachment17g_lone_operative_stays_attached() -> Bool:
    let board = attachment17g_fixture()
    board.reserve_units[1][0].abilities.append(AbilityKind::lone_operative)
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    for casualty in range(5):
        board.reserve_units[0].remove_model(0)
    return !board.reserve_units[0].is_lone_operative() and board.reserve_units[0].has_ability(AbilityKind::lone_operative)

# Whole-unit effects wait for every component, including an archived bearer;
# p66 does not treat a Leader/bodyguard component death as unit destruction.
fun test_attachment17g_whole_unit_destruction_waits() -> Bool:
    let board = attachment17g_fixture()
    let component = board.reserve_units[1].identity
    let bearer = board.reserve_units[1][0].identity
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    let source = attachment17g_source(board, component, 205)
    source.source_model = bearer
    source.own_unit_passive = false
    source.requires_live_source = false
    source.trigger = SourceEventKind::unit_destroyed
    source.limits.battle = 1
    source.use_scope = SourceUseScope::unit
    register_source_instance(board, source)
    let model : ModelID
    model = 5
    commit_wound_loss(board, attachment17g_job(0, 0, false), model, board[0][5].profile.wounds(), false)
    let leader_death = !board[0].unit_destruction_event_issued and board[0].models.size() == 6
    model = 0
    for casualty in range(5):
        commit_wound_loss(board, attachment17g_job(0, 0, false), model, board[0][0].profile.wounds(), false)
    let bodyguard_death = !board[0].unit_destruction_event_issued and board[0].models.size() == 1
    commit_wound_loss(board, attachment17g_job(0, 0, false), model, board[0][0].profile.wounds(), false)
    let last = board[0][0].destroyed_whole_unit and board[0].unit_destruction_event_issued and live_attachment_strength(board[0]) == 0
    let jobs : DamageJobs
    let cleanup = resolve_damage_jobs(board, jobs, false, unit_id(0))
    cleanup.choose_destruction_unit(board, unit_id(0))
    cleanup.resolve_destruction_model(board, model)
    cleanup.choose_source_event(board, source17e_id(0))
    return leader_death and bodyguard_death and last and cleanup.is_done() and board[0].models.empty() and board[0].destroyed_models.value.size() == 7 and board.source_uses.size() == 1 and board.source_uses[0].subject == board[0].identity and board.source_uses[0].battle_uses == 1 and valid_state_foundations(board)

# Simultaneous model/unit destruction hooks share controller groups (user
# sequencing rule); the active player's hooks precede the opponent's.
fun test_attachment17g_merged_death_event_ownership() -> Bool:
    let board = attachment17g_fixture()
    let component = board.reserve_units[1].identity
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    board[1].owned_by_player1 = true
    let own = attachment17g_source(board, component, 206)
    own.own_unit_passive = false
    own.requires_live_source = false
    own.trigger = SourceEventKind::unit_destroyed
    own.limits.battle = 1
    register_source_instance(board, own)
    let opponent = attachment17g_source(board, board[1].identity, 207)
    opponent.owner = true
    opponent.own_unit_passive = false
    opponent.requires_live_source = false
    opponent.trigger = SourceEventKind::model_destroyed
    opponent.subject = SourceSubject::enemy_unit
    opponent.limits.battle = 1
    register_source_instance(board, opponent)
    board.current_decision_maker = true
    let event = source_event(SourceEventKind::model_destroyed, board[0].identity, board[1].identity, board[0][5].identity)
    let sequence = resolve_source_event(board, event, true)
    let first = !board.current_decision_maker and can sequence.choose_source_event(board, source17e_id(1)) and !can sequence.choose_source_event(board, source17e_id(0))
    sequence.choose_source_event(board, source17e_id(1))
    let second = board.current_decision_maker and can sequence.choose_source_event(board, source17e_id(0))
    sequence.choose_source_event(board, source17e_id(0))
    return first and second and sequence.is_done() and board.current_decision_maker and board.source_uses.size() == 2

# A specific bearer can confer a unit grant independently of surviving peers;
# the final attack cleanup expires it and archives the exact destroyed model.
fun test_attachment17g_bearer_cleanup_after_all_attacks() -> Bool:
    let board = attachment17g_fixture()
    let component = board.reserve_units[1].identity
    let bearer = board.reserve_units[1][0].identity
    board.reserve_units[1].models.append(board.reserve_units[1][0])
    board.reserve_units[1][1].identity = invalid_entity_identity()
    board.identify_unit(board.reserve_units[1])
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    let source = attachment17g_source(board, component, 208)
    source.source_model = bearer
    register_source_instance(board, source)
    let model : ModelID
    model = 5
    commit_wound_loss(board, attachment17g_job(0, 1, true), model, board[0][5].profile.wounds(), false)
    refresh_source_effects(board, TimingWindow::none)
    release_attachment_rules(board, unit_id(0))
    let retained = board[0][5].attachment_abilities_retained and board[0][0].effective_movement(6) == 8 and live_attachment_strength(board[0]) == 6
    let jobs : DamageJobs
    let cleanup = resolve_damage_jobs(board, jobs, true, unit_id(1))
    let expired = board[0][0].effective_movement(6) == 6
    cleanup.choose_destruction_unit(board, unit_id(0))
    cleanup.resolve_destruction_model(board, model)
    return retained and expired and cleanup.is_done() and board[0].models.size() == 6 and board[0].destroyed_models.value[0].identity == bearer and !board[0].destroyed_models.value[0].attachment_abilities_retained and valid_state_foundations(board)

# Single-model activation never borrows p67's retained unit-rule permission.
fun test_attachment17g_model_rule_not_retained_activation() -> Bool:
    let board = attachment17g_fixture()
    let component = board.reserve_units[1].identity
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    let source = attachment17g_source(board, component, 209)
    source.source_model = board[0][5].identity
    source.own_unit_passive = false
    source.trigger = SourceEventKind::attack_targeted
    register_source_instance(board, source)
    let model : ModelID
    model = 5
    commit_wound_loss(board, attachment17g_job(0, 1, true), model, board[0][5].profile.wounds(), false)
    let event = source_event(SourceEventKind::attack_targeted, board[0].identity, board[1].identity, invalid_entity_identity())
    let unit_rule = source_event_available(board, source, event)
    source.model_specific_rule = true
    return unit_rule and !source_event_available(board, source, event) and !source_confers_rules(board, source)

# The last bodyguard retains typed unit abilities through all attacks, while
# destroyed retained models never inflate current half-strength (p67/86).
fun test_attachment17g_bodyguard_attack_lifetime_and_half() -> Bool:
    let board = attachment17g_fixture()
    board.reserve_units[0].unit_abilities.append(AbilityKind::stealth)
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    for casualty in range(4):
        board[0].remove_model(0)
    let model : ModelID
    commit_wound_loss(board, attachment17g_job(0, 1, true), model, board[0][0].profile.wounds(), false)
    let retained = board[0].has_ability(AbilityKind::stealth) and board[0].all_have_ability(AbilityKind::stealth) and board[0].is_at_or_below_half_strength() and live_attachment_strength(board[0]) == 1
    release_attachment_rules(board, unit_id(1))
    return retained and !board[0].has_ability(AbilityKind::stealth) and board[0].starting_strenght == 6

# Real declarations consume bodyguard T, and refresh to remaining Leader T
# when every physical bodyguard is gone (p66/19.02; declaration p17).
fun test_attachment17g_actual_declaration_toughness() -> Bool:
    let board = attachment17g_fixture()
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    board[0][5].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::replace, 9))
    let declaration = make_declared_weapon(board, unit_id(1), 0, 0)
    let first = declared_attack_info(board, unit_id(1), unit_id(0), declaration, board.attack_info)
    for casualty in range(5):
        board[0].remove_model(0)
    let last = declared_attack_info(board, unit_id(1), unit_id(0), declaration, board.attack_info)
    return first.target_toughness == 4 and last.target_toughness == 9

# Warlord and physical One Shot identities survive formation, death and saves
# without reselecting the model (user Warlord definition; p67/88).
fun test_attachment17g_warlord_and_usage_identity() -> Bool:
    let game = play()
    game.board = attachment17g_fixture()
    let bearer = game.board.reserve_units[1][0].identity
    game.board.armies[0].warlord = bearer
    game.board.reserve_units[1][0].keywords.append(Keyword::warlord)
    game.board.reserve_units[1][0].used_once_per_battle_weapon[0] = true
    attach_reserved_unit(game.board, unit_id(1), unit_id(0), false)
    let formed = game.board.reserve_units[0][5].has_keyword(Keyword::warlord) and game.board.reserve_units[0][5].identity == bearer
    game.board.reserve_units[0].remove_model(5)
    let restored = play()
    let saved = set_state(restored, to_string(game))
    return formed and saved and restored.board.armies[0].warlord == bearer and restored.board.reserve_units[0].destroyed_models.value[0].used_once_per_battle_weapon[0] and restored.board.reserve_units[0].destroyed_models.value[0].identity == bearer

# Formation allows the bounded32-model boundary but rejects empty/dead source
# fixtures and duplicate Support roles (p66; implementation capacity32).
fun test_attachment17g_capacity_boundary_and_dead_source() -> Bool:
    let board = attachment17g_fixture()
    board.reserve_units[0].models.resize(30)
    for offset in range(25):
        let model = offset + 5
        board.reserve_units[0][model] = board.reserve_units[0][0]
        board.reserve_units[0][model].identity = invalid_entity_identity()
    board.identify_unit(board.reserve_units[0])
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    let boundary = board.reserve_units[0].models.size() == 32 and valid_state_foundations(board)
    let invalid = attachment17g_fixture()
    invalid.reserve_units[1][0].suffered_wounds = invalid.reserve_units[1][0].profile.wounds()
    let dead = !attachment_valid(invalid, unit_id(1), unit_id(0), false)
    invalid.reserve_units[1].models.clear()
    let empty = !attachment_valid(invalid, unit_id(1), unit_id(0), false)
    configure_orks_attachment(invalid.reserve_units[1], OrksDatasheet::painboy)
    invalid.reserve_units[1].models.append(invalid.reserve_units[2][0])
    invalid.reserve_units[1][0].identity = invalid_entity_identity()
    invalid.reserve_units[1][0].original_unit = invalid_entity_identity()
    invalid.identify_unit(invalid.reserve_units[1])
    attach_reserved_unit(invalid, unit_id(2), unit_id(0), false)
    return boundary and dead and empty and !attachment_valid(invalid, unit_id(1), unit_id(0), false)

# Current HTML profile tables, including their separately printed InSv boxes.
# Sources: Beastboss, Beast-Snagga-Boyz, Squighog-Boyz Orks card URLs.
fun orks17h1_profile_values(Profile profile, Int expected_movement, Int expected_toughness, Int expected_save, Int expected_invulnerable, Int expected_wounds, Int expected_leadership, Int expected_control, Int expected_fnp) -> Bool:
    return profile.movement() == expected_movement and profile.thoughness() == expected_toughness and profile.save() == expected_save and profile.invuln_save() == expected_invulnerable and profile.wounds() == expected_wounds and profile.leadership() == expected_leadership and profile.control() == expected_control and profile.feel_no_pain() == expected_fnp

# Whole printed weapon row: fixed A and D resolve without hidden chance input.
fun orks17h1_weapon_values(Weapon weapon, Int expected_range_value, Int expected_attacks, Int expected_skill, Int expected_strength, Int expected_ap, Int expected_damage) -> Bool:
    let generated = evaluate_random_stat(weapon.attacks())
    let inflicted = evaluate_random_stat(weapon.damage())
    return weapon.range() == expected_range_value and generated.is_done() and generated.result == expected_attacks and weapon.skill() == expected_skill and weapon.strenght() == expected_strength and weapon.penetration() == expected_ap and inflicted.is_done() and inflicted.result == expected_damage

# Small declaration fixture with real current Snagga loadout metadata; geometry
# is a circle fixture, not production roster integration or missing abilities.
fun orks17h1_attack_board() -> Board:
    let board : Board
    board.units.append(make_orks_beast_snagga_boyz(1, 9, 1))
    let target = make_infernus_squad()
    target.models.resize(1)
    target.owned_by_player1 = true
    target[0].position = board_position(4, 3)
    board.units.append(target)
    for model in range(board[0].models.size()):
        board[0][model].position = board_position(2 + (model % 3) * 2, 5 + (model / 3) * 2)
    board.identify_units()
    board.capture_starting_strengths()
    for unit in range(board.units.size()):
        board[unit].capture_starting_strength()
        board[unit].can_shoot = true
        board[unit].can_charge = true
    return board

# Beastboss now has T6,5+ InSv,6+ FNP, and one combined melee weapon.
fun test_orks17h1_beastboss_profile() -> Bool:
    let unit = make_orks_beastboss()
    return unit.models.size() == 1 and orks17h1_profile_values(unit[0].profile, 6, 6, 4, 5, 6, 6, 1, 6) and unit[0].profile.base_size() == 50.0 and profile_base_width(unit[0].profile) == 50.0

# Boy1W/Nob3W share6+ InSv; the old FNP6 is absent on both profiles.
fun test_orks17h1_snagga_profiles() -> Bool:
    let unit = make_orks_beast_snagga_boyz(1, 9, 0)
    return orks17h1_profile_values(unit[0].profile, 6, 5, 5, 6, 3, 7, 2, 10) and orks17h1_profile_values(unit[1].profile, 6, 5, 5, 6, 1, 7, 2, 10) and unit[0].profile.base_size() == 32.0 and unit[1].profile.base_size() == 32.0

# Both mounted types are T6,6+ InSv with no FNP; Nob has4W, Boy3W.
fun test_orks17h1_squighog_profiles() -> Bool:
    let unit = make_orks_squighog_boyz(1, 3)
    return orks17h1_profile_values(unit[0].profile, 10, 6, 4, 6, 4, 7, 2, 10) and orks17h1_profile_values(unit[1].profile, 10, 6, 4, 6, 3, 7, 2, 10)

# User-authorized long-axis circle proxies preserve original oval metadata.
fun test_orks17h1_squighog_circle_proxies_preserve_ovals() -> Bool:
    let unit = make_orks_squighog_boyz(1, 3)
    unit[0].position = board_position(5, 5)
    let board : Board
    return unit[0].profile.base_size() == 90.0 and profile_base_width(unit[0].profile) == 52.0 and unit[1].profile.base_size() == 75.0 and profile_base_width(unit[1].profile) == 42.0 and profile_has_oval_base(unit[0].profile) and profile_has_oval_base(unit[1].profile) and !unit[0].geometry.unsupported_footprint and !unit[1].geometry.unsupported_footprint and model_placement_valid(board, unit[0]) and setup_at_valid(board, unit, board_position(5, 27), MovementKind::normal, false)

# Literal ranges include intermediate counts; price tiers add no count rule.
fun test_orks17h1_snagga_composition_bounds() -> Bool:
    return orks_snagga_composition_valid(1, 9, 0) and orks_snagga_composition_valid(2, 18, 2) and orks_snagga_composition_valid(2, 11, 1) and !orks_snagga_composition_valid(0, 9, 0) and !orks_snagga_composition_valid(3, 9, 0) and !orks_snagga_composition_valid(1, 8, 0) and !orks_snagga_composition_valid(1, 19, 0)

# Optional quota is one additional Thump Gun per ten total models.
fun test_orks17h1_thump_gun_quota() -> Bool:
    return orks_snagga_composition_valid(1, 9, 1) and !orks_snagga_composition_valid(1, 9, 2) and orks_snagga_composition_valid(1, 18, 1) and !orks_snagga_composition_valid(1, 18, 2) and orks_snagga_composition_valid(2, 18, 2) and !orks_snagga_composition_valid(2, 18, 3) and !orks_snagga_composition_valid(1, 9, -1)

# Printed independent1–2/3–6 ranges are preserved without prices.
fun test_orks17h1_squighog_composition_bounds() -> Bool:
    return orks_squighog_composition_valid(1, 3) and orks_squighog_composition_valid(2, 6) and orks_squighog_composition_valid(2, 5) and !orks_squighog_composition_valid(0, 3) and !orks_squighog_composition_valid(3, 3) and !orks_squighog_composition_valid(1, 2) and !orks_squighog_composition_valid(1, 7)

# Minimum/maximal legal source composition produces bounded starting counts.
fun test_orks17h1_factories_capture_composition() -> Bool:
    let small = make_orks_beast_snagga_boyz(1, 9, 0)
    let large = make_orks_beast_snagga_boyz(2, 18, 2)
    let mounted = make_orks_squighog_boyz(2, 6)
    return small.models.size() == 10 and small.starting_strenght == 10 and large.models.size() == 20 and large.starting_strenght == 20 and mounted.models.size() == 8 and mounted.starting_strenght == 8 and large[1].profile == Profile::orks_beast_snagga_nob and large[2].profile == Profile::orks_beast_snagga_boy

# No inherited Morgrim/Beastboss/monster-hunter identity or old ability grants.
fun test_orks17h1_beastboss_keywords_and_army_metadata() -> Bool:
    let unit = make_orks_beastboss()
    return unit[0].has_keyword(Keyword::orks) and unit[0].has_keyword(Keyword::infantry) and unit[0].has_keyword(Keyword::beast_snagga) and unit[0].has_keyword(Keyword::character) and unit[0].has_keyword(Keyword::warboss) and !unit[0].has_keyword(Keyword::beastboss) and unit[0].has_da_boss and unit_has_waaagh(unit) and unit.has_ability(AbilityKind::dodge_dis) and unit.has_ability(AbilityKind::keep_huntin) and unit_matches_datasheet(unit, OrksDatasheet::beastboss) and unit.attachment_role.value == AttachmentRole::leader.value

# Battleline/Beast Snagga/Mob/Orks are actual keywords on every member.
fun test_orks17h1_snagga_keywords_and_metadata() -> Bool:
    let unit = make_orks_beast_snagga_boyz(2, 18, 0)
    let valid = unit.attachment_role.value == AttachmentRole::bodyguard.value and unit_has_waaagh(unit)
    for model in range(unit.models.size()):
        valid = valid and unit[model].has_keyword(Keyword::battleline) and unit[model].has_keyword(Keyword::infantry) and unit[model].has_keyword(Keyword::beast_snagga) and unit[model].has_keyword(Keyword::mob) and unit[model].has_keyword(Keyword::orks) and !unit[model].has_keyword(Keyword::monster_hunters) and unit[model].has_ability(AbilityKind::mobbed) and model_matches_datasheet(unit[model], OrksDatasheet::beast_snagga_boyz)
    return valid

# Explosives/Mobile are included, with no inherited infantry/squighog keyword.
fun test_orks17h1_squighog_keywords_and_metadata() -> Bool:
    let unit = make_orks_squighog_boyz(2, 6)
    let valid = unit_has_waaagh(unit)
    for model in range(unit.models.size()):
        valid = valid and unit[model].has_keyword(Keyword::mounted) and unit[model].has_keyword(Keyword::beast_snagga) and unit[model].has_keyword(Keyword::explosives) and unit[model].has_keyword(Keyword::mobile) and unit[model].has_keyword(Keyword::orks) and !unit[model].has_keyword(Keyword::infantry) and !unit[model].has_keyword(Keyword::squighog_boyz) and unit[model].has_ability(AbilityKind::bomb_squig) and unit[model].has_ability(AbilityKind::brutal_impact)
    return valid

# Beastboss has exactly two weapons, one combined six-attack melee profile.
fun test_orks17h1_beastboss_equipment() -> Bool:
    let unit = make_orks_beastboss()
    return unit[0].weapons.size() == 2 and equipped_weapon_family(unit[0], 0).value == Weapon::orks_beastboss_shoota.value and equipped_weapon_family(unit[0], 1).value == Weapon::orks_beastboss_klaw_and_beastchoppa.value and orks17h1_weapon_values(unit[0].weapons[0].profile, 18, 2, 4, 4, 0, 1) and orks17h1_weapon_values(unit[0].weapons[1].profile, 0, 6, 2, 12, -2, 2)

# Thump Gun augments the Boy's default equipment; a Nob never receives it.
fun test_orks17h1_thump_adds_without_replacing() -> Bool:
    let unit = make_orks_beast_snagga_boyz(2, 18, 2)
    return unit[0].weapons.size() == 2 and unit[1].weapons.size() == 2 and unit[2].weapons.size() == 4 and unit[3].weapons.size() == 4 and unit[4].weapons.size() == 3 and equipped_weapon_family(unit[2], 0).value == Weapon::orks_slugga.value and equipped_weapon_family(unit[2], 1).value == Weapon::orks_choppa_standard.value and equipped_weapon_family(unit[2], 3).value == Weapon::orks_thump_gun.value

# Every current Snagga row is fixed-A, including Thump Gun's3 (not D3/Blast).
fun test_orks17h1_snagga_weapon_table() -> Bool:
    return orks17h1_weapon_values(Weapon::orks_slugga, 12, 1, 5, 4, 0, 1) and orks17h1_weapon_values(Weapon::orks_thump_gun, 18, 3, 5, 6, 0, 2) and !Weapon::orks_thump_gun.has_rule(WeaponRuleKind::blast) and orks17h1_weapon_values(Weapon::orks_choppa_standard, 0, 3, 3, 5, -1, 1) and orks17h1_weapon_values(Weapon::orks_choppa_hunter, 0, 3, 3, 6, -2, 1) and orks17h1_weapon_values(Weapon::orks_power_snappa, 0, 3, 3, 8, -2, 2)

# Profile alternatives share one physical Choppa; reject selecting both.
fun test_orks17h1_choppa_physical_profile_selection() -> Bool:
    let board = orks17h1_attack_board()
    let selected : Bool[MAX_WEAPONS]
    let first = weapon_selection_valid(board, unit_id(0), 1, 1, true, selected, false)
    selected[1] = true
    return first and !weapon_selection_valid(board, unit_id(0), 1, 2, true, selected, false) and weapon_primary_id(board[0][1], 1) == 2 and weapon_primary_id(board[0][1], 2) == 2 and equipped_weapon_profile(board[0][1], 2).value == Weapon::orks_choppa_hunter.value

# Hunter may target either Monster or Vehicle, never an ordinary infantry unit.
fun test_orks17h1_hunter_actual_target_legality() -> Bool:
    let board = orks17h1_attack_board()
    let declaration = make_declared_weapon(board, unit_id(0), 1, 2)
    let excluded = !declaration_target_valid(board, unit_id(0), declaration, unit_id(1), true)
    board[1][0].keywords.append(Keyword::monster)
    let monster = declaration_target_valid(board, unit_id(0), declaration, unit_id(1), true)
    board[1][0].keywords.clear()
    board[1][0].keywords.append(Keyword::vehicle)
    return excluded and monster and declaration_target_valid(board, unit_id(0), declaration, unit_id(1), true)

# Whole-unit excluded keywords govern actual Lethal Hits, not allocated models.
fun test_orks17h1_lethal_hits_target_exclusion() -> Bool:
    let board = orks17h1_attack_board()
    let declaration = make_declared_weapon(board, unit_id(0), 1, 0)
    let ordinary = chosen_weapon_has_rule(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::letal_hits)
    board[1][0].keywords.append(Keyword::monster)
    let monster = !chosen_weapon_has_rule(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::letal_hits)
    board[1][0].keywords.clear()
    board[1][0].keywords.append(Keyword::vehicle)
    return ordinary and monster and !chosen_weapon_has_rule(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::letal_hits)

# Combined Beastboss Sustained Hits2 uses the same positive ANY condition.
fun test_orks17h1_beastboss_conditional_sustained() -> Bool:
    let board = orks17h1_attack_board()
    board[0] = make_orks_beastboss()
    board.identify_units()
    let declaration = make_declared_weapon(board, unit_id(0), 0, 1)
    let ordinary = !chosen_weapon_has_rule(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::sustained_hit)
    board[1][0].keywords.append(Keyword::vehicle)
    return ordinary and chosen_weapon_has_rule(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::sustained_hit) and chosen_weapon_parameter(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::sustained_hit) == 2

# The new anti-Monster/Vehicle4+ reaches the critical-wound consumer.
fun test_orks17h1_thump_actual_anti_consumer() -> Bool:
    let board = orks17h1_attack_board()
    let declaration = make_declared_weapon(board, unit_id(0), 1, 3)
    let ordinary = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    let ordinary_threshold = critical_wound_threshold(board, ordinary)
    board[1][0].keywords.append(Keyword::monster)
    let monster = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    return ordinary_threshold == 6 and critical_wound_threshold(board, monster) == 4 and declaration_fixed_attacks(board, unit_id(0), declaration, 0) == 3

# Full mounted weapon rows have the printed S7/Cleave2 Big Choppa and no Lance.
fun test_orks17h1_squighog_weapon_table() -> Bool:
    return orks17h1_weapon_values(Weapon::orks_saddlegit_shiv, 9, 1, 4, 3, 0, 1) and orks17h1_weapon_values(Weapon::orks_stikka_ranged, 9, 1, 5, 5, -1, 2) and orks17h1_weapon_values(Weapon::orks_big_choppa, 0, 4, 3, 7, -1, 2) and Weapon::orks_big_choppa.get_rule_parameter(WeaponRuleKind::cleave) == 2 and orks17h1_weapon_values(Weapon::orks_squig_jaws, 0, 3, 4, 6, -1, 2) and Weapon::orks_squig_jaws.has_rule(WeaponRuleKind::extra_attacks) and orks17h1_weapon_values(Weapon::orks_stikka_melee, 0, 3, 3, 5, -1, 2) and !Weapon::orks_stikka_melee.has_rule(WeaponRuleKind::lance)

# Mounted models retain all equipment, including melee Stikka absent before.
fun test_orks17h1_squighog_equipment_and_profiles() -> Bool:
    let unit = make_orks_squighog_boyz(1, 3)
    return unit[0].weapons.size() == 3 and unit[1].weapons.size() == 4 and equipped_weapon_family(unit[0], 0).value == Weapon::orks_slugga.value and equipped_weapon_family(unit[0], 1).value == Weapon::orks_big_choppa.value and equipped_weapon_family(unit[0], 2).value == Weapon::orks_squig_jaws.value and equipped_weapon_family(unit[1], 0).value == Weapon::orks_saddlegit_shiv.value and equipped_weapon_profile(unit[1], 1).value == Weapon::orks_stikka_ranged.value and equipped_weapon_profile(unit[1], 2).value == Weapon::orks_stikka_melee.value and weapon_primary_id(unit[1], 1) == weapon_primary_id(unit[1], 2)

# Each copy has fresh owning storage and per-model physical profile selection.
fun test_orks17h1_equipment_copies_are_independent() -> Bool:
    let unit = make_orks_beast_snagga_boyz(1, 9, 0)
    unit[1].used_once_per_battle_weapon[1] = true
    unit[1].weapons.clear()
    return unit[2].weapons.size() == 3 and !unit[2].used_once_per_battle_weapon[1]

# Real current data passes the new attachment permission and bodyguard T path.
fun test_orks17h1_current_beastboss_attachment() -> Bool:
    let board : Board
    board.reserve_units.append(make_orks_beast_snagga_boyz(1, 9, 0))
    board.reserve_units.append(make_orks_beastboss())
    board.identify_units()
    let permitted = attachment_valid(board, unit_id(1), unit_id(0), false)
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    return permitted and board[0].models.size() == 11 and board[0].starting_strenght == 11 and board[0].get_unit_toughtness() == 5 and board[0][10].effective_toughness() == 6 and unit_has_waaagh(board[0]) and valid_state_foundations(board)

# Source data survives a Game save with mixed profiles, names and optional guns.
fun test_orks17h1_current_data_saved_round_trip() -> Bool:
    let game = play()
    game.board.reserve_units.append(make_orks_beastboss())
    game.board.reserve_units.append(make_orks_beast_snagga_boyz(2, 18, 2))
    game.board.reserve_units.append(make_orks_squighog_boyz(2, 6))
    game.board.identify_units()
    let restored = play()
    return set_state(restored, to_string(game)) and restored.board.reserve_units[1].models.size() == 20 and restored.board.reserve_units[1][2].weapons.size() == 4 and equipped_weapon_profile(restored.board.reserve_units[1][2], 2).value == Weapon::orks_choppa_hunter.value and !restored.board.reserve_units[2][0].geometry.unsupported_footprint and profile_base_width(restored.board.reserve_units[2][0].profile) == 52.0 and valid_state_foundations(restored.board)

# This subtask supplies exact data; no incomplete card/legacy roster is promoted.
fun test_orks17h1_data_stage_has_no_unsourced_special_grants() -> Bool:
    let boss = make_orks_beastboss()
    let snagga = make_orks_beast_snagga_boyz(1, 9, 0)
    let hog = make_orks_squighog_boyz(1, 3)
    return boss.unit_abilities.empty() and snagga.unit_abilities.empty() and hog.unit_abilities.empty() and !boss[0].grants_unit_riled_up and !hog[0].has_random_movement and !hog[0].has_deadly_demise


# Current source fixture: circle-proxy Squighogs, real Beastboss/Snagga data,
# one enemy6W/no-FNP Character. Printed sources are the three Orks card URLs.
fun orks17h23_fixture() -> Board:
    let board : Board
    board.units.append(make_orks_beastboss())
    board.units.append(make_orks_squighog_boyz(1, 3))
    board.units.append(make_orks_beast_snagga_boyz(1, 9, 0))
    let enemy = make_octavius()
    enemy.owned_by_player1 = true
    enemy[0].position = board_position(15, 14)
    board.units.append(enemy)
    board[0][0].position = board_position(5, 5)
    for hog_index in range(board[1].models.size()):
        board[1][hog_index].position = board_position(5 + (hog_index % 2) * 4, 14 + (hog_index / 2) * 4)
    for boy_index in range(board[2].models.size()):
        board[2][boy_index].position = board_position(10 + (boy_index % 3) * 2, 4 + (boy_index / 3) * 2)
    board.identify_units()
    board.capture_starting_strengths()
    board.begin_phase(BattlePhase::movement)
    register_orks_datasheet_sources(board)
    return board

# Actual movement event snapshot; bounded action IDs remain independent.
fun orks17h23_move_event(Board board, Int source, Bool at_end, MovementKind kind) -> SourceEvent:
    let event = source_event(SourceEventKind::move_start, board[source].identity, invalid_entity_identity(), invalid_entity_identity())
    if at_end:
        event.kind = SourceEventKind::move_end
    event.movement = kind
    return event

# Resolve a stable printed source handle without relying on registration order.
fun orks17h23_source(Board board, Int rule, Int source, Bool at_end) -> SourceInstanceID:
    let result : SourceInstanceID
    let kind = SourceEventKind::move_start
    if at_end:
        kind = SourceEventKind::move_end
    for index in range(board.source_instances.size()):
        if board.source_instances[index].rule.value == rule and board.source_instances[index].source_unit == board[source].identity and board.source_instances[index].trigger.value == kind.value:
            result = index
    return result

# Repeated registration and bank changes preserve exactly two Keep windows
# and one unit Bomb token; no token/ability is inferred from a legacy factory.
fun test_orks17h23_registration_is_idempotent() -> Bool:
    let board = orks17h23_fixture()
    register_orks_datasheet_sources(board)
    let original = board.source_instances.size() == 3
    board.reserve_units.append(board[1])
    board.units[1].models.clear()
    register_orks_datasheet_sources(board)
    return original and board.source_instances.size() == 3 and valid_source_foundations(board)

# Keep Huntin': move start/end only, own Movement phase, never opposing turn.
fun test_orks17h23_keep_windows_and_phase() -> Bool:
    let board = orks17h23_fixture()
    let start = collect_source_events(board, orks17h23_move_event(board, 0, false, MovementKind::advance))
    let end = collect_source_events(board, orks17h23_move_event(board, 0, true, MovementKind::ordered_retreat))
    board.current_player = true
    let opponent = collect_source_events(board, orks17h23_move_event(board, 0, false, MovementKind::normal))
    board.current_player = false
    board.begin_phase(BattlePhase::shooting)
    let outside = collect_source_events(board, orks17h23_move_event(board, 0, false, MovementKind::normal))
    return start.size() == 1 and end.size() == 1 and opponent.empty() and outside.empty()

# Range is base-to-base and self selection is legal; friendly Beast Snagga
# is required. Spare IDs and offboard/non-Beast-Snagga/enemy units are illegal.
fun test_orks17h23_keep_target_boundaries() -> Bool:
    let board = orks17h23_fixture()
    let handle = orks17h23_source(board, ORKS_KEEP_HUNTIN_RULE, 0, false)
    ref instance = board.source_instances[handle.value]
    let near = orks_move_target_valid(board, instance, unit_id(0)) and orks_move_target_valid(board, instance, unit_id(2))
    board[2][0].position = board_position(13, 5)
    for offset in range(board[2].models.size() - 1):
        let index = offset + 1
        board[2][index].position = board_position(20, 5 + index)
    let far = !orks_move_target_valid(board, instance, unit_id(2))
    board[2].off_battlefield = true
    return near and far and !orks_move_target_valid(board, instance, unit_id(2)) and !orks_move_target_valid(board, instance, unit_id(3)) and !orks_move_target_valid(board, instance, unit_id(31))

# A decline consumes neither the shared use counter nor shock/riled changes.
fun test_orks17h23_keep_decline_spends_nothing() -> Bool:
    let board = orks17h23_fixture()
    board[0].battle_socked = true
    board.current_decision_maker = true
    let sequence = resolve_movement_sources(board, orks17h23_move_event(board, 0, false, MovementKind::normal))
    sequence.finish_source_events(board)
    return sequence.is_done() and board.current_decision_maker and board.source_uses.empty() and board[0].battle_socked and !unit_is_riled_up(board[0])

# Accepted target clears shock/riles immediately and exhausts the end window.
fun test_orks17h23_keep_accept_and_shared_windows() -> Bool:
    let board = orks17h23_fixture()
    board[2].battle_socked = true
    let sequence = resolve_movement_sources(board, orks17h23_move_event(board, 0, false, MovementKind::normal))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_keep_huntin_target(board, unit_id(2))
    let ending = resolve_movement_sources(board, orks17h23_move_event(board, 0, true, MovementKind::normal))
    return sequence.is_done() and ending.is_done() and !board[2].battle_socked and unit_is_riled_up(board[2]) and board.source_uses.size() == 1 and board.source_uses[0].round_uses.value == 1 and !board.current_decision_maker

# Duplicate bosses share the army limit, opposing armies do not; next round
# restores usage. This also specifies the future Squigosaur adapter's rule code.
fun test_orks17h23_keep_shared_army_round() -> Bool:
    let board = orks17h23_fixture()
    let duplicate = make_orks_beastboss()
    duplicate[0].position = board_position(5, 9)
    board.units.append(duplicate)
    let opposing = duplicate
    opposing.owned_by_player1 = true
    board.units.append(opposing)
    board.identify_units()
    register_orks_datasheet_sources(board)
    let first = orks17h23_source(board, ORKS_KEEP_HUNTIN_RULE, 0, false)
    let second = orks17h23_source(board, ORKS_KEEP_HUNTIN_RULE, 4, false)
    let enemy = orks17h23_source(board, ORKS_KEEP_HUNTIN_RULE, 5, false)
    commit_source_usage(board, board.source_instances[first.value])
    let shared = !source_usage_available(board, board.source_instances[second.value]) and source_usage_available(board, board.source_instances[enemy.value])
    board.current_round = board.current_round + 1
    return shared and source_usage_available(board, board.source_instances[second.value])

# Persist until the next own turn even if the boss dies or target embarks;
# the opponent's turn must not end the accepted effect (appendix01.02.02).
fun test_orks17h23_keep_duration_offboard_and_source_death() -> Bool:
    let board = orks17h23_fixture()
    let sequence = resolve_movement_sources(board, orks17h23_move_event(board, 0, false, MovementKind::normal))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_keep_huntin_target(board, unit_id(2))
    board[0][0].suffered_wounds = 6
    board.reserve_units.append(board[2])
    board.reserve_units.back().off_battlefield = true
    board[2].models.clear()
    board.current_player = true
    board.start_turn_history()
    let retained = unit_is_riled_up(board.reserve_units.back())
    board.current_player = false
    board.start_turn_history()
    return retained and !unit_is_riled_up(board.reserve_units.back()) and board.source_effects.empty()

# Actual move start/end integrations; the end hook appears only after a
# completed move, and completing a start source removes its end opportunity.
fun test_orks17h23_keep_actual_move_hooks() -> Bool:
    let board = orks17h23_fixture()
    let sequence = move(board, unit_id(0), 0)
    sequence.finish_source_events(board, unit_id(0))
    sequence.move_to(board, unit_id(0), board_position(6, 5))
    sequence.choose_movement_source(board, unit_id(0), source17e_id(0))
    sequence.choose_keep_huntin_target(board, unit_id(0), unit_id(0))
    return sequence.is_done() and sequence.completed and unit_is_riled_up(board[0]) and board[0][0].position.x.value == 6

# Dodge Dis! combines with other +1/-1 terms before the cumulative hit cap;
# cancelling its contribution must not remove the other contribution.
fun test_orks17h23_dodge_hit_pipeline_and_individual_choices() -> Bool:
    let board = orks17h23_fixture()
    configure_attack_info(board, 0, 3, false, false)
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let info = declared_attack_info(board, unit_id(0), unit_id(3), declaration, board.attack_info)
    info.hit_roll_bonus = true
    info.hit_roll_malus = true
    board.attack_info = info
    let options = attack_hit_choices(board, info)
    let result = resolve_attack_dice(board, board[3], board[0], attack_test_count(1))
    result.roll(board, board[3], board[0], attack_test_die(3))
    result.roll(board, board[3], board[0], attack_test_die(1))
    return info.unit_ability_hit_modifiers.size() == 1 and info.total_hit_modifier() == 1 and get_hit_roll_bonus(board) == 1 and options.size() == 3 and result.is_done() and result.generated_wounds == 0

# Attached unit attacks all receive Dodge Dis! until the boss's conferral
# ends; unsupported old factories have no new grants (core pp66-67).
fun test_orks17h23_dodge_attached_component_lifetime() -> Bool:
    let board : Board
    board.reserve_units.append(make_orks_beast_snagga_boyz(1, 9, 0))
    board.reserve_units.append(make_orks_beastboss())
    board.identify_units()
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    board.units.append(board.reserve_units[0])
    let target = make_octavius()
    target.owned_by_player1 = true
    board.units.append(target)
    configure_attack_info(board, 0, 1, false, true)
    let live = !board.attack_info.unit_ability_hit_modifiers.empty()
    board[0][10].suffered_wounds = 6
    board[0][10].state = ModelState::pending_destruction
    board[0][10].attachment_abilities_retained = true
    configure_attack_info(board, 0, 1, false, true)
    let retained = !board.attack_info.unit_ability_hit_modifiers.empty()
    board[0][10].attachment_abilities_retained = false
    configure_attack_info(board, 0, 1, false, true)
    return live and retained and board.attack_info.unit_ability_hit_modifiers.empty() and !make_beastboss_morgrim().has_ability(AbilityKind::dodge_dis)

# Bomb Squig: only completed Normal-move end in own Movement phase.
fun test_orks17h23_bomb_timing_gates() -> Bool:
    let board = orks17h23_fixture()
    let start = resolve_movement_sources(board, orks17h23_move_event(board, 1, false, MovementKind::normal))
    let advanced = resolve_movement_sources(board, orks17h23_move_event(board, 1, true, MovementKind::advance))
    let retreat = resolve_movement_sources(board, orks17h23_move_event(board, 1, true, MovementKind::ordered_retreat))
    board.current_player = true
    let opponent = resolve_movement_sources(board, orks17h23_move_event(board, 1, true, MovementKind::normal))
    board.current_player = false
    let normal = resolve_movement_sources(board, orks17h23_move_event(board, 1, true, MovementKind::normal))
    return start.is_done() and advanced.is_done() and retreat.is_done() and opponent.is_done() and can normal.choose_movement_source(board, source17e_id(0))

# Bomb selects one live visible enemy within12 base inches; area crossing
# only partially obscures under the user's visibility abstraction.
fun test_orks17h23_bomb_target_boundaries_and_visibility() -> Bool:
    let board = orks17h23_fixture()
    let handle = orks17h23_source(board, ORKS_BOMB_SQUIG_RULE, 1, true)
    ref instance = board.source_instances[handle.value]
    board.terrain_areas.append(terrain_area(11, 13, 12, 15, false))
    let visible = orks_move_target_valid(board, instance, unit_id(3)) and !orks_move_target_valid(board, instance, unit_id(1)) and !orks_move_target_valid(board, instance, unit_id(2))
    board[3][0].position = board_position(25, 14)
    let distant = !orks_move_target_valid(board, instance, unit_id(3))
    board[3][0].position = board_position(15, 14)
    board[3].off_battlefield = true
    return visible and distant and !orks_move_target_valid(board, instance, unit_id(3)) and !orks_move_target_valid(board, instance, unit_id(31))

# No legal target or declining the ability consumes nothing.
fun test_orks17h23_bomb_decline_or_no_target_preserves_token() -> Bool:
    let board = orks17h23_fixture()
    let sequence = resolve_movement_sources(board, orks17h23_move_event(board, 1, true, MovementKind::normal))
    sequence.finish_source_events(board)
    board[3].off_battlefield = true
    let unavailable = resolve_movement_sources(board, orks17h23_move_event(board, 1, true, MovementKind::normal))
    return sequence.is_done() and unavailable.is_done() and board.source_uses.empty()

# Spend the token at acceptance, even on a failed1/2; no Command re-roll or
# extra CP cost is invented, and subsequent rounds cannot restore the token.
fun test_orks17h23_bomb_failure_spends_token() -> Bool:
    let board = orks17h23_fixture()
    let sequence = resolve_movement_sources(board, orks17h23_move_event(board, 1, true, MovementKind::normal))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_bomb_squig_target(board, unit_id(3))
    let spent_before_roll = board.source_uses.size() == 1 and board.source_uses[0].battle_uses.value == 1
    sequence.roll(board, attack_test_die(2))
    board.current_round = board.current_round + 1
    let repeat = resolve_movement_sources(board, orks17h23_move_event(board, 1, true, MovementKind::normal))
    return spent_before_roll and sequence.is_done() and repeat.is_done() and board[3][0].suffered_wounds == 0 and board.command_points[0] == 0

# On3+ use explicit D3 chance, then enemy-owned mortal allocation with no save.
fun test_orks17h23_bomb_success_actual_mortal_allocation() -> Bool:
    let board = orks17h23_fixture()
    board.current_decision_maker = true
    let sequence = resolve_movement_sources(board, orks17h23_move_event(board, 1, true, MovementKind::normal))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_bomb_squig_target(board, unit_id(3))
    sequence.roll(board, attack_test_die(3))
    let bounded = !can sequence.quantity(board, attack_test_die(4))
    sequence.quantity(board, attack_test_die(3))
    let opponent = board.current_decision_maker
    for index in range(3):
        sequence.select_mortal_model(board, damage_test_model(0))
    return bounded and opponent and sequence.is_done() and board.current_decision_maker and board[3][0].suffered_wounds == 3 and board.source_effects.empty()

# Ordinary FNP is offered for every generated mortal; preventing one does not
# restore the token or change the other mortals (core pp24/81).
fun test_orks17h23_bomb_uses_feel_no_pain() -> Bool:
    let board = orks17h23_fixture()
    board[3][0].profile = Profile::orks_beastboss
    let sequence = resolve_movement_sources(board, orks17h23_move_event(board, 1, true, MovementKind::normal))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_bomb_squig_target(board, unit_id(3))
    sequence.roll(board, attack_test_die(6))
    sequence.quantity(board, attack_test_die(2))
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.roll(board, attack_test_die(6))
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.roll(board, attack_test_die(1))
    return sequence.is_done() and board[3][0].suffered_wounds == 1 and board.source_uses[0].battle_uses.value == 1

# Two units retain independent tokens; repeated registration preserves spent
# unit usage after a bank transfer (source unit/battle scope).
fun test_orks17h23_bomb_per_unit_usage() -> Bool:
    let board = orks17h23_fixture()
    let duplicate = make_orks_squighog_boyz(1, 3)
    board.units.append(duplicate)
    board.identify_units()
    register_orks_datasheet_sources(board)
    let first = orks17h23_source(board, ORKS_BOMB_SQUIG_RULE, 1, true)
    let second = orks17h23_source(board, ORKS_BOMB_SQUIG_RULE, 4, true)
    commit_source_usage(board, board.source_instances[first.value])
    register_orks_datasheet_sources(board)
    return !source_usage_available(board, board.source_instances[first.value]) and source_usage_available(board, board.source_instances[second.value]) and board.source_uses.size() == 1

# End-of-Normal-move hook is offered before ordinary embarkation; skipping
# the move cannot offer the end ability.
fun test_orks17h23_bomb_actual_move_and_skip() -> Bool:
    let board = orks17h23_fixture()
    let skipped = move(board, unit_id(1), 0)
    skipped.skip(board, unit_id(1))
    let no_end = skipped.is_done() and board.source_uses.empty()
    let moved = move(board, unit_id(1), 0)
    moved.finish_move(board, unit_id(1))
    moved.choose_movement_source(board, unit_id(1), source17e_id(0))
    moved.choose_bomb_squig_target(board, unit_id(1), unit_id(3))
    moved.roll(board, unit_id(1), attack_test_die(1))
    return no_end and moved.is_done() and moved.completed and board.source_uses[0].battle_uses.value == 1

# Mobbed requires engaged enemy Monster OR Vehicle; allies, infantry, reserve
# units and destroyed targets are excluded. No declared-target restriction.
fun test_orks17h23_mobbed_target_gates() -> Bool:
    let board = orks17h23_fixture()
    board[2].has_charged = true
    board[3][0].position = board_position(10, 3)
    let infantry = !orks_mobbed_target_valid(board, unit_id(2), unit_id(3))
    board[3][0].keywords.append(Keyword::vehicle)
    let vehicle = orks_mobbed_target_valid(board, unit_id(2), unit_id(3))
    board[3][0].keywords.clear()
    board[3][0].keywords.append(Keyword::monster)
    let monster = orks_mobbed_target_valid(board, unit_id(2), unit_id(3))
    board[3].off_battlefield = true
    return infantry and vehicle and monster and !orks_mobbed_target_valid(board, unit_id(2), unit_id(3)) and !orks_mobbed_target_valid(board, unit_id(2), unit_id(2))

# Exactly13 live combined members changes the penalty; corpses and starting
# strength cannot satisfy the threshold (Mobbed; core p66).
fun test_orks17h23_mobbed_strength_threshold() -> Bool:
    let unit = make_orks_beast_snagga_boyz(1, 12, 0)
    let large = orks_mobbed_penalty(unit) == 2
    unit[0].suffered_wounds = 3
    unit[0].state = ModelState::pending_destruction
    return large and unit.starting_strenght == 13 and orks_mobbed_penalty(unit) == 1

# A penalty changes a printed Leadership boundary; the opposing player owns
# the shock roll, without Insane Bravery or Command Re-roll outside Command.
fun test_orks17h23_mobbed_actual_shock_penalty() -> Bool:
    let board = orks17h23_fixture()
    board[2].has_charged = true
    board[3][0].position = board_position(10, 3)
    board[3][0].keywords.append(Keyword::vehicle)
    let sequence = resolve_orks_mobbed(board, unit_id(2))
    sequence.choose_mobbed_target(board, unit_id(3))
    let owner = board.current_decision_maker and !can sequence.insane_bravery(board, true)
    sequence.roll_pair(board, attack_test_die(3), attack_test_die(3))
    return owner and sequence.is_done() and board[3].battle_socked and !board.current_decision_maker

# Every eligible enemy must roll once; the charging player chooses their order.
fun test_orks17h23_mobbed_multiple_enemies_once_each() -> Bool:
    let board = orks17h23_fixture()
    board[2].has_charged = true
    board[3][0].position = board_position(10, 3)
    board[3][0].keywords.append(Keyword::vehicle)
    let second = board[3]
    second.identity = invalid_entity_identity()
    second[0].identity = invalid_entity_identity()
    second[0].original_unit = invalid_entity_identity()
    second[0].position = board_position(12, 3)
    board.units.append(second)
    board.identify_units()
    let sequence = resolve_orks_mobbed(board, unit_id(2))
    sequence.choose_mobbed_target(board, unit_id(4))
    sequence.roll_pair(board, attack_test_die(1), attack_test_die(1))
    let once = !can sequence.choose_mobbed_target(board, unit_id(4))
    sequence.choose_mobbed_target(board, unit_id(3))
    sequence.roll_pair(board, attack_test_die(6), attack_test_die(6))
    return once and sequence.is_done() and board[4].battle_socked and !board[3].battle_socked

# Brutal Impact is not restricted to melee: every ranged/melee/Jaws attack
# after a completed charge gains+1D; merely declaring a charge grants nothing.
fun test_orks17h23_brutal_all_profiles_and_charge_gate() -> Bool:
    let board = orks17h23_fixture()
    let ranged = make_declared_weapon(board, unit_id(1), 1, 0)
    let melee = make_declared_weapon(board, unit_id(1), 1, 2)
    let jaws = make_declared_weapon(board, unit_id(1), 1, 3)
    let before = declaration_modifiers(board, unit_id(1), ranged, ModifiedCharacteristic::damage).empty()
    record_charge_move(board, unit_id(1))
    let ranged_info = declared_attack_info(board, unit_id(1), unit_id(3), ranged, board.attack_info)
    let melee_info = declared_attack_info(board, unit_id(1), unit_id(3), melee, board.attack_info)
    let jaw_info = declared_attack_info(board, unit_id(1), unit_id(3), jaws, board.attack_info)
    return before and modified_characteristic(1, ModifiedCharacteristic::damage, ranged_info.damage_modifiers, false) == 2 and modified_characteristic(2, ModifiedCharacteristic::damage, melee_info.damage_modifiers, false) == 3 and modified_characteristic(2, ModifiedCharacteristic::damage, jaw_info.damage_modifiers, false) == 3

# Source+1D belongs in addition before division/subtraction, and the same-turn
# permission expires before the opponent turn (appendix02.02.01).
fun test_orks17h23_brutal_arithmetic_and_turn_expiry() -> Bool:
    let board = orks17h23_fixture()
    board[1].has_charged = true
    let divided = characteristic_modifier(ModifiedCharacteristic::damage, ModifierOperation::divide, 2)
    board[1][1].characteristic_modifiers.append(divided)
    let declaration = make_declared_weapon(board, unit_id(1), 1, 2)
    let modifiers = declaration_modifiers(board, unit_id(1), declaration, ModifiedCharacteristic::damage)
    let rounded = modified_characteristic(2, ModifiedCharacteristic::damage, modifiers, false) == 2
    board.current_player = true
    board.start_turn_history()
    let expired = declaration_modifiers(board, unit_id(1), declaration, ModifiedCharacteristic::damage)
    return rounded and modified_characteristic(2, ModifiedCharacteristic::damage, expired, false) == 1 and !board[1].has_charged

# Long-axis circles preserve original axes while allowing placement/movement.
# Shape metadata is immutable; stored positions remain whole quads.
fun test_orks17h23_oval_proxy_edge_overlap_and_rotation() -> Bool:
    let board : Board
    let unit = make_orks_squighog_boyz(1, 3)
    unit[0].position = board_position(1, 5)
    let edge = !model_placement_valid(board, unit[0])
    unit[0].position = board_position(3, 5)
    unit[1].position = board_position(6, 5)
    let overlap = model_bases_overlap(unit[0], unit[1])
    unit[1].position = board_position(7, 5)
    let separate = !model_bases_overlap(unit[0], unit[1])
    let original = unit[0].distance(unit[1])
    unit[0].geometry.rotation = 90000
    return edge and overlap and separate and unit[0].distance(unit[1]) == original and profile_has_oval_base(unit[0].profile) and profile_base_width(unit[0].profile) == 52.0

# Saved partial targeted source choice restores usage/owner/continuation.
fun test_orks17h23_targeted_source_frame_round_trip() -> Bool:
    let board = orks17h23_fixture()
    let sequence = resolve_movement_sources(board, orks17h23_move_event(board, 0, false, MovementKind::normal))
    sequence.choose_movement_source(board, source17e_id(0))
    let restored = sequence
    let parsed = from_string(restored, to_string(sequence))
    restored.choose_keep_huntin_target(board, unit_id(2))
    return parsed and restored.is_done() and unit_is_riled_up(board[2]) and board.source_uses.size() == 1 and valid_state_foundations(board)


# Actual charge completion suspends for mandatory Mobbed, rather than applying
# it to a failed/declaration-only attempt. A one-model fixture isolates timing.
fun test_orks17h23_mobbed_actual_charge_hook() -> Bool:
    let board = charge13_fixture()
    board.begin_phase(BattlePhase::charge)
    board[0][0].abilities.append(AbilityKind::mobbed)
    board[1][0].keywords.append(Keyword::vehicle)
    let sequence = charge(board, unit_id(0), ChargeKind::ordinary)
    sequence.roll_pair(board, attack_test_die(4), attack_test_die(4))
    sequence.keep_it(board, true)
    sequence.select_charge_target(board, unit_id(1))
    sequence.finish_charge_targets(board)
    sequence.charge_move_to(board, board_position(11, 5))
    let mandatory = !sequence.is_done() and board[0].has_charged and can sequence.resolve_mobbed(board)
    sequence.resolve_mobbed(board)
    sequence.choose_mobbed_target(board, unit_id(1))
    sequence.roll_pair(board, attack_test_die(1), attack_test_die(1))
    if can sequence.decline_crushing_impact(board):
        sequence.decline_crushing_impact(board)
    return mandatory and sequence.is_done() and board[1].battle_socked

# Bomb casualties use ordinary source-known destruction handling and spill
# remaining mortals into a new recipient (core pp24/87).
fun test_orks17h23_bomb_destruction_spills() -> Bool:
    let board = orks17h23_fixture()
    board[3] = make_infernus_squad()
    board[3].models.resize(2)
    board[3].owned_by_player1 = true
    for index in range(2):
        board[3][index].position = board_position(15 + index * 2, 14)
    board.identify_units()
    let sequence = resolve_movement_sources(board, orks17h23_move_event(board, 1, true, MovementKind::normal))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_bomb_squig_target(board, unit_id(3))
    sequence.roll(board, attack_test_die(3))
    sequence.quantity(board, attack_test_die(3))
    for index in range(3):
        sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[3].models.size() == 1 and board[3].destroyed_models.value.size() == 1 and board[3][0].suffered_wounds == 1

# Oval circle proxies use the same final-placement and rigid movement engine,
# keeping both source axes and rejecting a proxy crossing the board edge.
fun test_orks17h23_oval_proxy_actual_movement() -> Bool:
    let board = orks17h23_fixture()
    let sequence = move(board, unit_id(1), 0)
    let edge = !can sequence.move_to(board, unit_id(1), board_position(1, 14))
    sequence.move_to(board, unit_id(1), board_position(6, 14))
    sequence.finish_source_events(board, unit_id(1))
    return edge and sequence.is_done() and sequence.completed and board[1][0].position.x.value == 6 and profile_has_oval_base(board[1][0].profile) and profile_base_width(board[1][0].profile) == 52.0


# At13 live models Mobbed's-2 turns a7 into5, failing Ld6; at12 its-1
# turns the same7 into6 and passes. Test the real shock consumer, not only metadata.
fun test_orks17h23_mobbed_minus_two_boundary() -> Bool:
    let large = orks17h23_fixture()
    large[2] = make_orks_beast_snagga_boyz(1, 12, 0)
    large.identify_units()
    large[2].has_charged = true
    large[2][0].position = board_position(10, 4)
    large[3][0].position = board_position(10, 3)
    large[3][0].keywords.append(Keyword::vehicle)
    let sequence = resolve_orks_mobbed(large, unit_id(2))
    sequence.choose_mobbed_target(large, unit_id(3))
    sequence.roll_pair(large, attack_test_die(3), attack_test_die(4))
    let small = orks17h23_fixture()
    small[2].has_charged = true
    small[3][0].position = board_position(10, 3)
    small[3][0].keywords.append(Keyword::vehicle)
    let smaller = resolve_orks_mobbed(small, unit_id(2))
    smaller.choose_mobbed_target(small, unit_id(3))
    smaller.roll_pair(small, attack_test_die(3), attack_test_die(4))
    return sequence.is_done() and smaller.is_done() and large[3].battle_socked and !small[3].battle_socked

# Spending a Bomb token survives a saved Board and transfers to reserves;
# a duplicate registration never restores the printed per-unit-battle limit.
fun test_orks17h23_bomb_saved_usage_and_offboard_transfer() -> Bool:
    let game = play()
    game.board = orks17h23_fixture()
    let handle = orks17h23_source(game.board, ORKS_BOMB_SQUIG_RULE, 1, true)
    commit_source_usage(game.board, game.board.source_instances[handle.value])
    let saved = play()
    let parsed = set_state(saved, to_string(game))
    saved.board.reserve_units.append(saved.board[1])
    saved.board.reserve_units.back().off_battlefield = true
    saved.board[1].models.clear()
    register_orks_datasheet_sources(saved.board)
    return parsed and !source_usage_available(saved.board, saved.board.source_instances[handle.value]) and saved.board.source_uses[0].battle_uses.value == 1

# Current starter selection exercises production Warlord/formation flow,
# rather than the historical core-rule factory (Orks three current cards).
fun orks17h4_configured_game() -> Game:
    let game = play()
    game.pick_morgrim_butcha()
    game.choose_orks_detachment(OrksDetachment::war_horde)
    game.finish_detachment_selection()
    if can game.finish_orks_options():
        game.finish_orks_options()
    game.choose_warlord_unit(unit_id(0))
    game.choose_warlord_model(damage_test_model(0))
    game.pick_morgrim_butcha()
    game.finish_detachment_selection()
    if can game.finish_orks_options():
        game.finish_orks_options()
    game.choose_warlord_unit(unit_id(4))
    game.choose_warlord_model(damage_test_model(0))
    return game

# Source-backed starter has25 models in four units per army; no points/DP.
fun test_orks17h4_public_current_roster_profiles() -> Bool:
    let game = play()
    game.pick_morgrim_butcha()
    ref reserves = game.board.reserve_units
    return reserves.size() == 4 and reserves[0][0].profile == Profile::orks_beastboss and reserves[1].models.size() == 4 and reserves[2].models.size() == 10 and reserves[3].models.size() == 10 and reserves[1][0].profile == Profile::orks_nob_on_smasha_squig and reserves[2][0].profile == Profile::orks_beast_snagga_nob and reserves[2][1].weapons.size() == 4 and game.board.armies[0].reserve_budget == ReserveBudgetMode::point_free

# Each player's actual selection owns all its units; only their CHARACTER
# can be selected, using the user-supplied Warlord definition (17.F).
fun test_orks17h4_both_rosters_and_warlords() -> Bool:
    let game = orks17h4_configured_game()
    let correct = game.board.reserve_units.size() == 8
    for index in range(8):
        correct = correct and game.board.reserve_units[index].owned_by_player1 == (index >= 4)
    return correct and game.board.armies[0].warlord == game.board.reserve_units[0][0].identity and game.board.armies[1].warlord == game.board.reserve_units[4][0].identity and !can game.choose_warlord_unit(unit_id(0)) and can game.attach_unit(unit_id(0), unit_id(2)) and !can game.attach_unit(unit_id(0), unit_id(6))

# Warlord is mandatory before opponent selection and survives a pending save.
fun test_orks17h4_pending_warlord_save_and_handoff() -> Bool:
    let game = play()
    game.pick_morgrim_butcha()
    game.finish_detachment_selection()
    if can game.finish_orks_options():
        game.finish_orks_options()
    let pending = get_current_player(game) == 0 and !can game.pick_morgrim_butcha() and !can game.choose_warlord_unit(unit_id(1))
    game.choose_warlord_unit(unit_id(0))
    let restored = play()
    let parsed = set_state(restored, to_string(game))
    restored.choose_warlord_model(damage_test_model(0))
    return pending and parsed and get_current_player(restored) == 1 and can restored.pick_morgrim_butcha() and restored.board.armies[0].warlord == restored.board.reserve_units[0][0].identity

# Real formation selection transfers the Beastboss into its Snagga bodyguard;
# permanent Warlord identity survives reserve-slot compaction (pp66–67).
fun test_orks17h4_actual_attachment_preserves_warlord() -> Bool:
    let game = orks17h4_configured_game()
    let identity = game.board.armies[0].warlord
    game.attach_unit(unit_id(0), unit_id(2))
    ref combined = game.board.reserve_units[1]
    return combined.models.size() == 11 and combined[10].identity == identity and combined[10].profile == Profile::orks_beastboss and combined.has_ability(AbilityKind::dodge_dis) and game.board.armies[0].warlord == identity and valid_state_foundations(game.board)

# Both owners use source-first reserve IDs, including after first army merge.
fun test_orks17h4_both_actual_attachments_and_save() -> Bool:
    let game = orks17h4_configured_game()
    game.attach_unit(unit_id(0), unit_id(2))
    let opponent = can game.attach_unit(unit_id(3), unit_id(5)) and get_current_player(game) == 1
    game.attach_unit(unit_id(3), unit_id(5))
    let restored = play()
    let parsed = set_state(restored, to_string(game))
    return opponent and parsed and restored.board.reserve_units.size() == 6 and restored.board.reserve_units[1].models.size() == 11 and restored.board.reserve_units[4].models.size() == 11 and restored.board.reserve_units[4].owned_by_player1 and valid_state_foundations(restored.board)

# Source registration occurs after actual formation choices, on the surviving
# combined identities; printed abilities are available in the public battle.
fun test_orks17h4_actual_formation_registers_current_sources() -> Bool:
    let game = orks17h4_configured_game()
    game.attach_unit(unit_id(0), unit_id(2))
    game.done_attaching()
    game.done_attaching()
    return game.board.source_instances.size() >= 6 and game.board.reserve_units[1].has_ability(AbilityKind::mobbed) and game.board.reserve_units[1].has_ability(AbilityKind::keep_huntin) and game.board.reserve_units[0].has_ability(AbilityKind::bomb_squig) and valid_state_foundations(game.board)

# No old Orks random movement/Demise/equipment is introduced by public picks.
fun test_orks17h4_current_roster_no_legacy_grants() -> Bool:
    let units : UnitVector
    let roster = make_orks_starter_roster(units, true)
    let clean = roster == Faction::morgrim_butchas
    for unit_index in range(units.size()):
        for model_index in range(units[unit_index].models.size()):
            clean = clean and units[unit_index].unit_abilities.empty() and units[unit_index].owned_by_player1 == true
    return clean and units[1][0].weapons[1].profile.value == Weapon::orks_big_choppa.value and units[2][1].weapons[3].profile.value == Weapon::orks_thump_gun.value

# War Horde fixture selects the actual package for source's owner. Source:
# https://wahapedia.ru/wh40k11ed/factions/orks/#Get-Stuck-In
fun orks17i1_fixture() -> Board:
    let board = orks17h23_fixture()
    board.armies[0].faction = ArmyFaction::orks
    let selected = board.armies[0].record_detachment(OrksDetachment::war_horde)
    assert(selected, "fixture must select War Horde")
    return board

# Get Stuck In applies to every friendly ORKS melee weapon, including Jaws.
fun test_orks17i1_melee_main_extra_and_ranged_gate() -> Bool:
    let board = orks17i1_fixture()
    let main = model_weapon_rules(board, unit_id(1), 1, 2)
    let jaws = model_weapon_rules(board, unit_id(1), 1, 3)
    let ranged = model_weapon_rules(board, unit_id(1), 1, 1)
    return chosen_weapon_parameter(board, unit_id(3), main, WeaponRuleKind::sustained_hit) == 1 and chosen_weapon_parameter(board, unit_id(3), jaws, WeaponRuleKind::sustained_hit) == 1 and !chosen_weapon_has_rule(board, unit_id(3), ranged, WeaponRuleKind::sustained_hit) and available_weapon_has_rule(board, unit_id(1), 1, 3, WeaponRuleKind::sustained_hit)

# Merely belonging to Orks, or selecting another package, grants no passive.
fun test_orks17i1_requires_selected_war_horde() -> Bool:
    let board = orks17i1_fixture()
    board.armies[0].detachments.clear()
    let absent = !war_horde_melee_rule_applies(board, unit_id(2), Weapon::orks_choppa_standard)
    let other = board.armies[0].record_detachment(OrksDetachment::da_big_hunt)
    return absent and other and !war_horde_melee_rule_applies(board, unit_id(2), Weapon::orks_choppa_standard)

# Unit/army keywords are both required; opponent selection does not leak.
fun test_orks17i1_faction_keyword_and_opponent_gate() -> Bool:
    let board = orks17i1_fixture()
    let opponent = !war_horde_melee_rule_applies(board, unit_id(3), Weapon::orks_choppa_standard)
    for index in range(board[2].models.size()):
        board[2][index].keywords.clear()
    let keyword = !war_horde_melee_rule_applies(board, unit_id(2), Weapon::orks_choppa_standard)
    board.armies[0].faction = ArmyFaction::space_marines
    return opponent and keyword and !war_horde_melee_rule_applies(board, unit_id(1), Weapon::orks_choppa_standard)

# Friendly is source owner, independent of whose turn/decision it currently is.
fun test_orks17i1_owner_not_active_player() -> Bool:
    let board = orks17i1_fixture()
    board.current_player = true
    board.current_decision_maker = true
    let friendly = war_horde_melee_rule_applies(board, unit_id(1), Weapon::orks_big_choppa)
    board[1].owned_by_player1 = true
    let unavailable = !war_horde_melee_rule_applies(board, unit_id(1), Weapon::orks_big_choppa)
    board.armies[1].faction = ArmyFaction::orks
    let selected = board.armies[1].record_detachment(OrksDetachment::war_horde)
    return friendly and unavailable and selected and war_horde_melee_rule_applies(board, unit_id(1), Weapon::orks_big_choppa)

# This is a unit-keyword rule, not an individual bearer-keyword requirement.
fun test_orks17i1_unit_keyword_union_and_three_packages() -> Bool:
    let board = orks17i1_fixture()
    board[2][1].keywords.clear()
    let second = board.armies[0].record_detachment(OrksDetachment::da_big_hunt)
    let third = board.armies[0].record_detachment(OrksDetachment::green_tide)
    let rules = model_weapon_rules(board, unit_id(2), 1, 1)
    return second and third and !board[2][1].has_keyword(Keyword::orks) and chosen_weapon_parameter(board, unit_id(3), rules, WeaponRuleKind::sustained_hit) == 1 and board.armies[0].detachments.size() == 3

# A critical hit really produces one ordinary extra hit which rolls to wound;
# a non-critical does not. Get Stuck In is not a Lethal Hits grant (p84).
fun test_orks17i1_actual_critical_hit_consumer() -> Bool:
    let board = orks17i1_fixture()
    let declaration = make_declared_weapon(board, unit_id(1), 1, 2)
    board.attack_info = declared_attack_info(board, unit_id(1), unit_id(3), declaration, board.attack_info)
    let dice = resolve_attack_dice(board, board[3], board[1], attack_test_count(1))
    dice.roll(board, board[3], board[1], attack_test_die(6))
    let extra = dice.generated_hits == 2 and dice.generated_wounds == 0
    dice.roll(board, board[3], board[1], attack_test_die(1))
    dice.roll(board, board[3], board[1], attack_test_die(1))
    return extra and dice.is_done() and dice.generated_wounds == 0

# Beastboss conditional2 and detachment1 remain alternatives chosen BEFORE
# targets; the controlling player may choose1, never a summed3 (p78).
fun test_orks17i1_beastboss_duplicate_choose_one_and_save() -> Bool:
    let board = orks17i1_fixture()
    let rules = model_weapon_rules(board, unit_id(0), 0, 1)
    let selection = choose_weapon_abilities(board, rules)
    let index : WeaponAbilityChoice
    index = rules.size() - 1
    let legal = can selection.choose_weapon_ability(board, index)
    let restored = selection
    let parsed = from_string(restored, to_string(selection))
    restored.choose_weapon_ability(board, index)
    board[3][0].keywords.append(Keyword::vehicle)
    return legal and parsed and restored.is_done() and chosen_weapon_parameter(board, unit_id(3), restored.chosen, WeaponRuleKind::sustained_hit) == 1

# Selecting the intrinsic2 retains its Monster/Vehicle condition; declining
# the unconditional1 cannot silently fall back to it against ordinary targets.
fun test_orks17i1_beastboss_duplicate_choose_two_condition() -> Bool:
    let board = orks17i1_fixture()
    let rules = model_weapon_rules(board, unit_id(0), 0, 1)
    let selection = choose_weapon_abilities(board, rules)
    let index : WeaponAbilityChoice
    index = 0
    selection.choose_weapon_ability(board, index)
    let ordinary = chosen_weapon_parameter(board, unit_id(3), selection.chosen, WeaponRuleKind::sustained_hit) == 0
    board[3][0].keywords.append(Keyword::monster)
    return selection.is_done() and ordinary and chosen_weapon_parameter(board, unit_id(3), selection.chosen, WeaponRuleKind::sustained_hit) == 2

# Actual Select Weapons forwards the duplicate choice into saved declarations.
# This regression prevents a helper-only passive which real combat never uses.
fun test_orks17i1_actual_weapon_selection_and_snapshot() -> Bool:
    let board = orks17i1_fixture()
    let declarations : DeclaredWeapons
    let sequence = declare_model_weapons(board, declarations, unit_id(0), damage_test_model(0), true)
    sequence.select_weapon(board, declarations, attack_test_slot(1))
    let waiting = declarations.size() == 1 and !sequence.is_done()
    let index : WeaponAbilityChoice
    index = 1
    sequence.choose_weapon_ability(board, declarations, index)
    sequence.skip(board, declarations)
    return waiting and sequence.is_done() and declarations[0].selected_rules.size() == 1 and declarations[0].current_target_rules[0].parameter == 1

# Chosen rules remain serialized declaration snapshots; loading a current
# army retains both package configuration and its actual melee passive.
fun test_orks17i1_board_and_declaration_save() -> Bool:
    let game = play()
    game.board = orks17i1_fixture()
    game.board.attack.declarations.append(make_declared_weapon(game.board, unit_id(1), 1, 3))
    let restored = play()
    let parsed = set_state(restored, to_string(game))
    return parsed and restored.board.armies[0].has_detachment(OrksDetachment::war_horde) and chosen_weapon_parameter(restored.board, unit_id(3), restored.board.attack.declarations[0].selected_rules, WeaponRuleKind::sustained_hit) == 1 and valid_state_foundations(restored.board)

# Controlled source fixtures for all ordinary detachments. Tags added below
# exercise future-card consumers; these are NOT production datasheet profiles.
# Source: Orks ordinary Detachments, user enhancement/geometry policies.
fun orks17all_fixture(OrksDetachment package) -> Board:
    let board = orks17h1_attack_board()
    board[0].models.resize(1)
    board[0][0].position = board_position(5, 5)
    board[1][0].position = board_position(12, 5)
    board[0].capture_starting_strength()
    board[1][0].keywords.append(Keyword::orks)
    board.armies[0].faction = ArmyFaction::orks
    board.armies[1].faction = ArmyFaction::orks
    let selected = board.armies[0].record_detachment(package)
    let opposing = board.armies[1].record_detachment(package)
    board.command_points[0] = 10
    board.command_points[1] = 10
    board.begin_phase(BattlePhase::shooting)
    configure_attack_info(board, 0, 1, false, false)
    return board

# Make a reserve roster with distinct identities for isolated enhancement
# quota tests. Final army copy legality is exercised separately below.
fun orks17all_option_board(Int count, OrksDetachment package, Bool characters) -> Board:
    let board : Board
    board.armies[0].faction = ArmyFaction::orks
    let selected = board.armies[0].record_detachment(package)
    for index in range(count):
        let unit = make_orks_beastboss()
        if !characters:
            unit[0].keywords.clear()
            unit[0].keywords.append(Keyword::orks)
            unit[0].keywords.append(Keyword::infantry)
            unit[0].datasheet = OrksDatasheet::boyz.value
        board.reserve_units.append(unit)
    board.identify_units()
    return board

# Counterpart fixture metadata is literal, never inferred from a weapon name.
fun orks17all_tag(Unit unit, OrksDatasheet tag):
    unit.roster_datasheet = tag.value
    for member in range(unit.models.size()):
        unit[member].datasheet = tag.value

# User four-count policy includes each unique Upgrade once, however many
# eligible models are in the original upgraded unit.
fun test_orks17all_four_enhancement_limit() -> Bool:
    let board = orks17all_option_board(5, OrksDetachment::war_horde, true)
    apply_orks_option(board, unit_id(0), damage_test_model(0), OrksEnhancement::headwoppas_killchoppa, false)
    apply_orks_option(board, unit_id(1), damage_test_model(0), OrksEnhancement::da_boss_is_watchin, false)
    apply_orks_option(board, unit_id(2), damage_test_model(0), OrksEnhancement::kunnin_but_brutal, false)
    apply_orks_option(board, unit_id(3), damage_test_model(0), OrksEnhancement::follow_me_ladz, false)
    let package = board.armies[0].record_detachment(OrksDetachment::dread_mob)
    board.reserve_units[4][0].keywords.append(Keyword::big_mek)
    return !orks_option_selection_valid(board, unit_id(4), damage_test_model(0), OrksEnhancement::cybork_boosta, false) and !orks_any_option_available(board, false)

# An ordinary enhancement cannot repeat or share a unit with another choice.
fun test_orks17all_ordinary_unique_and_one_per_unit() -> Bool:
    let board = orks17all_option_board(2, OrksDetachment::war_horde, true)
    apply_orks_option(board, unit_id(0), damage_test_model(0), OrksEnhancement::headwoppas_killchoppa, false)
    return !orks_option_selection_valid(board, unit_id(1), damage_test_model(0), OrksEnhancement::headwoppas_killchoppa, false) and !orks_option_selection_valid(board, unit_id(0), damage_test_model(0), OrksEnhancement::follow_me_ladz, false) and orks_option_selection_valid(board, unit_id(1), damage_test_model(0), OrksEnhancement::follow_me_ladz, false)

# Upgrade copies2/3 consume no extra count, but a fourth is prohibited.
fun test_orks17all_upgrade_three_copies_non_character() -> Bool:
    let board = orks17all_option_board(4, OrksDetachment::green_tide, false)
    for index in range(3):
        apply_orks_option(board, unit_id(index), damage_test_model(0), OrksEnhancement::ardboyz, false)
    return !orks_option_selection_valid(board, unit_id(3), damage_test_model(0), OrksEnhancement::ardboyz, false) and !orks_option_selection_valid(board, unit_id(3), damage_test_model(0), OrksEnhancement::ferocious_show_off, false)

# With four counted choices already taken, a second/third existing Upgrade
# remains permitted. Ordinary options still require a Character.
fun test_orks17all_duplicate_upgrade_excluded_from_four_total() -> Bool:
    let board = orks17all_option_board(6, OrksDetachment::green_tide, false)
    let second = board.armies[0].record_detachment(OrksDetachment::war_horde)
    apply_orks_option(board, unit_id(0), damage_test_model(0), OrksEnhancement::ardboyz, false)
    for index in range(3):
        board.reserve_units[index + 1][0].keywords.append(Keyword::character)
    apply_orks_option(board, unit_id(1), damage_test_model(0), OrksEnhancement::headwoppas_killchoppa, false)
    apply_orks_option(board, unit_id(2), damage_test_model(0), OrksEnhancement::da_boss_is_watchin, false)
    apply_orks_option(board, unit_id(3), damage_test_model(0), OrksEnhancement::follow_me_ladz, false)
    let permitted = orks_option_selection_valid(board, unit_id(4), damage_test_model(0), OrksEnhancement::ardboyz, false)
    apply_orks_option(board, unit_id(4), damage_test_model(0), OrksEnhancement::ardboyz, false)
    return permitted and orks_option_selection_valid(board, unit_id(5), damage_test_model(0), OrksEnhancement::ardboyz, false)

# Neither an Epic bearer nor a unit containing another Epic model can take
# an ordinary option or an Upgrade (explicit user authority).
fun test_orks17all_epic_hero_and_containing_unit_excluded() -> Bool:
    let board = orks17all_option_board(2, OrksDetachment::green_tide, true)
    let second = board.armies[0].record_detachment(OrksDetachment::war_horde)
    board.reserve_units[0][0].keywords.append(Keyword::epic_hero)
    orks17all_tag(board.reserve_units[0], OrksDatasheet::boyz)
    let extra = board.reserve_units[1][0]
    extra.identity = 0
    extra.keywords.append(Keyword::epic_hero)
    board.reserve_units[1].models.append(extra)
    board.identify_units()
    return !orks_option_selection_valid(board, unit_id(0), damage_test_model(0), OrksEnhancement::ardboyz, false) and !orks_option_selection_valid(board, unit_id(1), damage_test_model(0), OrksEnhancement::follow_me_ladz, false)

# Attachment cannot circumvent the Epic exclusion or merge two enhanced units.
fun test_orks17all_attachment_enhancement_guard() -> Bool:
    let board = orks17all_option_board(3, OrksDetachment::war_horde, true)
    apply_orks_option(board, unit_id(0), damage_test_model(0), OrksEnhancement::follow_me_ladz, false)
    let clean = orks_enhancement_attachment_valid(board.reserve_units[0], board.reserve_units[1])
    board.reserve_units[1][0].keywords.append(Keyword::epic_hero)
    let epic = !orks_enhancement_attachment_valid(board.reserve_units[0], board.reserve_units[1])
    apply_orks_option(board, unit_id(2), damage_test_model(0), OrksEnhancement::headwoppas_killchoppa, false)
    # These are different original roster units, so both existing selections
    # survive attachment. The Epic Hero exclusion remains a final-unit check.
    return clean and epic and orks_enhancement_attachment_valid(board.reserve_units[0], board.reserve_units[2])

# Sources require their selected package, owner and actual model; spare IDs
# must be safely rejected during finite candidate enumeration.
fun test_orks17all_option_package_owner_and_spare_gates() -> Bool:
    let board = orks17all_option_board(1, OrksDetachment::green_tide, true)
    return !orks_option_selection_valid(board, unit_id(0), damage_test_model(0), OrksEnhancement::follow_me_ladz, false) and !orks_option_selection_valid(board, unit_id(0), damage_test_model(0), OrksEnhancement::ferocious_show_off, true) and !orks_option_selection_valid(board, unit_id(31), damage_test_model(0), OrksEnhancement::ferocious_show_off, false) and !orks_option_selection_valid(board, unit_id(0), damage_test_model(31), OrksEnhancement::ferocious_show_off, false)

# Follow Me Ladz applies to the bearer/unit through keyed effective M, and
# expires when its live source ceases to confer (p67/passive source lifetime).
fun test_orks17all_follow_me_ladz_effective_movement() -> Bool:
    let board = orks17all_fixture(OrksDetachment::war_horde)
    board[0][0].orks_enhancement = OrksEnhancement::follow_me_ladz
    let before = board[0][0].effective_movement(board[0][0].profile.movement())
    register_orks_option_passives(board)
    let increased = board[0][0].effective_movement(board[0][0].profile.movement()) == before + 2
    board[0][0].suffered_wounds = board[0][0].profile.wounds()
    refresh_source_effects(board, TimingWindow::none)
    return increased and board.source_effects.empty()

# Headwoppa and Brutal But Kunnin modify effective melee AP/D only, not the
# ranged profile, and Headwoppa requires an actual completed charge.
fun test_orks17all_headwoppa_charge_melee_gate() -> Bool:
    let board = orks17all_fixture(OrksDetachment::war_horde)
    board[0][0].orks_enhancement = OrksEnhancement::headwoppas_killchoppa
    let uncharged = orks17c2b_info(board, 1).attack_penetration()
    board[0].has_charged = true
    return orks17c2b_info(board, 1).attack_penetration() == uncharged - 1 and orks17c2b_info(board, 0).attack_penetration() == board[0][0].weapons[0].profile.penetration()

# D addition enters the ordered outgoing characteristic pipeline.
fun test_orks17all_brutal_but_kunnin_melee_damage() -> Bool:
    let board = orks17all_fixture(OrksDetachment::brute_bosses)
    board[0][0].orks_enhancement = OrksEnhancement::brutal_but_kunnin
    let melee = orks17c2b_info(board, 1)
    let ranged = orks17c2b_info(board, 0)
    return modified_characteristic(1, ModifiedCharacteristic::damage, melee.damage_modifiers, false) == 2 and modified_characteristic(1, ModifiedCharacteristic::damage, ranged.damage_modifiers, false) == 1

# Cybork and It Came From Da Drops enter characteristic additions before
# division/rounding; unrelated characteristics stay at their sourced values.
fun test_orks17all_cybork_and_drops_characteristics() -> Bool:
    let board = orks17all_fixture(OrksDetachment::dread_mob)
    board[0][0].orks_enhancement = OrksEnhancement::cybork_boosta
    let faster = board[0][0].effective_movement(6) == 8
    board[0][0].orks_enhancement = OrksEnhancement::it_came_from_da_drops
    return faster and board[0][0].effective_toughness() == board[0][0].profile.thoughness() + 1

# Ardboyz's explicit4+ save replaces the printed characteristic; its source
# component remains distinct from later attached Leaders (Green Tide card).
fun test_orks17all_ardboyz_save_replacement() -> Bool:
    let board = orks17all_fixture(OrksDetachment::green_tide)
    board[0][0].orks_enhancement = OrksEnhancement::ardboyz
    board[0][0].orks_upgrade_origin = board[0].identity
    register_orks_option_passives(board)
    return board[0][0].effective_save() == 4

# Green Tide's Boyz Sustained is independent of charged infantry Lethal, and
# the latter keeps its NONE Monster/Vehicle target condition.
fun test_orks17all_green_tide_sustained_and_lethal_targets() -> Bool:
    let board = orks17all_fixture(OrksDetachment::green_tide)
    orks17all_tag(board[0], OrksDatasheet::boyz)
    board[0].has_charged = true
    let rules = model_weapon_rules(board, unit_id(0), 0, 1)
    let infantry = chosen_weapon_parameter(board, unit_id(1), rules, WeaponRuleKind::sustained_hit) == 1 and chosen_weapon_has_rule(board, unit_id(1), rules, WeaponRuleKind::letal_hits)
    board[1][0].keywords.append(Keyword::vehicle)
    return infantry and !chosen_weapon_has_rule(board, unit_id(1), rules, WeaponRuleKind::letal_hits)

# Bully Boyz adds Sustained only to its named Nob/Meganob group, in melee.
fun test_orks17all_bully_boyz_named_melee_group() -> Bool:
    let board = orks17all_fixture(OrksDetachment::bully_boyz)
    let absent = !available_weapon_has_rule(board, unit_id(0), 0, 1, WeaponRuleKind::sustained_hit)
    orks17all_tag(board[0], OrksDatasheet::nobz)
    return absent and available_weapon_has_rule(board, unit_id(0), 0, 1, WeaponRuleKind::sustained_hit) and !available_weapon_has_rule(board, unit_id(0), 0, 0, WeaponRuleKind::sustained_hit)

# Shoota's Assault permission reaches actual shooting-mode and weapon gates;
# riled+3 Range is gathered through the declaration characteristic pipeline.
fun test_orks17all_shoota_assault_and_riled_range() -> Bool:
    let board = orks17all_fixture(OrksDetachment::shoota_boyz)
    board[0].history.advanced_this_turn = true
    board[0].has_run = true
    let assault = shooting_kind_valid(board, unit_id(0), ShootingKind::assault)
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let normal = declaration_weapon_range(board, unit_id(0), declaration)
    orks17f_intrinsic_riled(board[0][0])
    return assault and declaration_weapon_range(board, unit_id(0), declaration) == normal + 3

# Throat-slittas preserves its no-Monster/Vehicle restriction independently
# of Green Tide; ranged attacks cannot gain this melee Lethal source.
fun test_orks17all_throat_slittas_target_exclusion() -> Bool:
    let board = orks17all_fixture(OrksDetachment::taktikal_brigade)
    # The actual Slugga already has Lethal Hits; use a neutral ranged weapon
    # to test that the Upgrade itself confers nothing on ranged attacks.
    board[0][0].weapons[0].profile = Weapon::bolt_rifle
    board[0][0].orks_enhancement = OrksEnhancement::throat_slittas
    let melee = model_weapon_rules(board, unit_id(0), 0, 1)
    let allowed = chosen_weapon_has_rule(board, unit_id(1), melee, WeaponRuleKind::letal_hits)
    board[1][0].keywords.append(Keyword::monster)
    return allowed and !chosen_weapon_has_rule(board, unit_id(1), melee, WeaponRuleKind::letal_hits) and !available_weapon_has_rule(board, unit_id(0), 0, 0, WeaponRuleKind::letal_hits)

# Tellyporta excludes an attached unit with Vehicle membership, rather than
# just checking its infantry bearer (Bully Boyz source card).
fun test_orks17all_tellyporta_vehicle_exclusion() -> Bool:
    let board = orks17all_fixture(OrksDetachment::bully_boyz)
    board[0][0].orks_enhancement = OrksEnhancement::tellyporta_boss
    let granted = board[0].all_have_ability(AbilityKind::deep_strike)
    board[0][0].keywords.append(Keyword::vehicle)
    return granted and !board[0].all_have_ability(AbilityKind::deep_strike)

# Minefield Scouts6 requires not embarked, and every duplicate stays uniform
# under the user's static-value policy (Runt Swarm source upgrade).
fun test_orks17all_minefield_scouts_and_embarked_gate() -> Bool:
    let board = orks17all_fixture(OrksDetachment::runt_swarm)
    board[0][0].orks_enhancement = OrksEnhancement::minefield_detail
    let on_foot = scouts_distance(board[0]) == 6
    board[0].embarked_transport = board[1][0].identity
    return on_foot and scouts_distance(board[0]) == 0

# Runt and Taktikal waivers affect their selected movement only; fallback
# charge/shooting permissions survive subsequent source loss.
fun test_orks17all_fallback_permissions_snapshot() -> Bool:
    let board = orks17all_fixture(OrksDetachment::taktikal_brigade)
    orks17all_tag(board[0], OrksDatasheet::boyz)
    board[0][0].orks_enhancement = OrksEnhancement::kunnin_but_brutal
    capture_orks_selected_move(board, unit_id(0), MovementKind::ordered_retreat)
    board[0][0].orks_enhancement = OrksEnhancement::none
    record_move(board, unit_id(0), MovementKind::ordered_retreat)
    return board[0].can_shoot and board[0].can_charge and board[0].history.fallback_allows_charge and board[0].history.fallback_allows_shooting

# Runt's Action permission is only an Advance/Fall Back waiver; being
# shocked/starting a second action/after-shooting remain prohibitions.
fun test_orks17all_runt_action_waiver_preserves_other_gates() -> Bool:
    let board = orks17all_fixture(OrksDetachment::runt_swarm)
    orks17all_tag(board[0], OrksDatasheet::gretchin)
    capture_orks_selected_move(board, unit_id(0), MovementKind::advance)
    record_move(board, unit_id(0), MovementKind::advance)
    let allowed = board[0].allows_action_start()
    board[0].battle_socked = true
    return allowed and !board[0].allows_action_start()

# Da Big Hunt AP applies versus actual Monster/Vehicle union only; a
# friendly source in another selected package cannot borrow the benefit.
fun test_orks17all_hunt_ap_target_condition() -> Bool:
    let board = orks17all_fixture(OrksDetachment::da_big_hunt)
    let ordinary = orks17c2b_info(board, 0).attack_penetration()
    board[1][0].keywords.append(Keyword::vehicle)
    return orks17c2b_info(board, 0).attack_penetration() == ordinary - 1

# Unpredictable Genius rolls only for a single declared target; targeting
# several enemies is legal and does not satisfy its conditional trigger.
fun test_orks17all_madcap_single_target_condition() -> Bool:
    let declarations : DeclaredWeapons
    let first : DeclaredWeapon
    first.targeted[1] = true
    declarations.append(first)
    let same : DeclaredWeapon
    same.targeted[1] = true
    declarations.append(same)
    let single = single_declared_target(declarations) == 1
    declarations[1].targeted[2] = true
    return single and single_declared_target(declarations) == -1

# Try Dat Button table additions accumulate for distinct faces1/2, even
# though those faces belong to the same band. S/AP use their ordered consumers.
fun test_orks17all_button_cumulative_characteristics() -> Bool:
    let board = orks17all_fixture(OrksDetachment::dread_mob)
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let base = declaration_fixed_attacks(board, unit_id(0), declaration, 0)
    apply_orks_button(board, unit_id(0), attack_test_die(1))
    apply_orks_button(board, unit_id(0), attack_test_die(2))
    apply_orks_button(board, unit_id(0), attack_test_die(3))
    apply_orks_button(board, unit_id(0), attack_test_die(5))
    let info = orks17c2b_info(board, 0)
    return declaration_fixed_attacks(board, unit_id(0), declaration, 0) == base + 2 and info.attack_strength() == board[0][0].weapons[0].profile.strenght() + 2 and info.attack_penetration() == board[0][0].weapons[0].profile.penetration() - 1

# Speed Freeks receive real Assault and charge waivers on selected Advance,
# keeping normal action restrictions when not Gretchin/Mind On Mission.
fun test_orks17all_kult_advance_assault_and_charge() -> Bool:
    let board = orks17all_fixture(OrksDetachment::kult_of_speed)
    board[0][0].keywords.append(Keyword::speed_freeks)
    board[0].history.advance_allows_charge = orks_move_charge_permission(board, board[0], MovementKind::advance)
    capture_orks_selected_move(board, unit_id(0), MovementKind::advance)
    record_move(board, unit_id(0), MovementKind::advance)
    return board[0].can_charge and shooting_kind_valid(board, unit_id(0), ShootingKind::assault) and !board[0].allows_action_start()

# Flyboyz riled Aircraft/Deffkoptas contribute a hit term before the+/-1 cap.
fun test_orks17all_flyboyz_riled_hit_modifier() -> Bool:
    let board = orks17all_fixture(OrksDetachment::flyboyz)
    orks17all_tag(board[0], OrksDatasheet::deffkoptas)
    orks17f_intrinsic_riled(board[0][0])
    let info = orks17c2b_info(board, 0)
    return info.attack_hit_modifiers.size() == 1 and info.total_hit_modifier() == 1

# Brute Warboss3+/riled2+ has no CP cost, closes after selecting its unit to
# fight, and remains distinct from paid4+ permissions.
fun test_orks17all_brute_death_thresholds() -> Bool:
    let board = orks17all_fixture(OrksDetachment::brute_bosses)
    board[0][0].keywords.append(Keyword::warboss)
    let normal = orks_fight_death_threshold(board, board[0], board[0][0]) == 3
    orks17f_intrinsic_riled(board[0][0])
    let riled = orks_fight_death_threshold(board, board[0], board[0][0]) == 2
    board[0].has_fought = true
    return normal and riled and orks_fight_death_threshold(board, board[0], board[0][0]) == 0

# Wurrband uses actual living unit models, with one extra S per full5; no
# psychic ability is granted to non-Psyker or foreign-faction models.
fun test_orks17all_wurrband_psychic_weapon_strength() -> Bool:
    let board = orks17all_fixture(OrksDetachment::wurrband)
    board[0][0].keywords.append(Keyword::psyker)
    board[0][0].weapons[0].profile = Weapon::orks_eadbanger
    let info = orks17c2b_info(board, 0)
    return info.attack_strength() == 7

# Explicit source metadata changes muster copy limits after force disposition:
# Gretchin≤6 under Runt,≤3 otherwise. Replacement units are not re-mustered.
fun test_orks17all_roster_three_and_six_copy_limits() -> Bool:
    let board = orks17all_option_board(4, OrksDetachment::runt_swarm, false)
    for slot in range(board.reserve_units.size()):
        orks17all_tag(board.reserve_units[slot], OrksDatasheet::gretchin)
    let effective = muster_copies_valid(board)
    board.armies[0].detachments.clear()
    let limited = !muster_copies_valid(board)
    let selected = board.armies[0].record_detachment(OrksDetachment::runt_swarm)
    register_orks_force_dispositions(board)
    return effective and limited and selected and muster_copies_valid(board) and board.reserve_units[0].has_keyword(Keyword::battleline)

# Literal card actor fixtures keep applicability separate from expected effect.
# They use controlled stats and tags, not fabricated production datasheets.
fun orks17all_selected_card_fixture(Stratagem card, Bool melee) -> Board:
    let board = orks17all_fixture(card.orks_detachment())
    if melee:
        board.begin_phase(BattlePhase::fight)
    if card == Stratagem::orks_mow_em_down:
        board[0][0].keywords.append(Keyword::vehicle)
        board[0].has_charged = true
    if card == Stratagem::orks_unbridled_carnage:
        orks17all_tag(board[0], OrksDatasheet::boyz)
        board[0].has_charged = true
    if card == Stratagem::orks_armed_to_da_teef:
        orks17all_tag(board[0], OrksDatasheet::nobz)
    if card == Stratagem::orks_drive_by_bustin:
        board[0][0].keywords.append(Keyword::transport)
    if card == Stratagem::orks_vindictive_artillerists:
        orks17all_tag(board[0], OrksDatasheet::mek_gunz)
        # Isolate the card's three choices from the fixture Slugga's printed
        # Lethal Hits, which correctly survives the Sustained-only choice.
        board[0][0].weapons[0].profile = Weapon::bolt_rifle
    if card == Stratagem::orks_dakkastorm:
        board[0][0].keywords.append(Keyword::speed_freeks)
    if card == Stratagem::orks_long_uncontrolled_bursts:
        orks17all_tag(board[0], OrksDatasheet::deffkoptas)
    return board

# Real paid selection, source installation and declaration consumer for the
# ranged/melee weapon-ability cards. Costs and same-unit reuse are checked.
fun orks17all_selected_ability(Stratagem card, Bool melee, WeaponRuleKind expected, Int magnitude) -> Bool:
    let board = orks17all_selected_card_fixture(card, melee)
    let sequence = orks_attack_selection(board, unit_id(0), melee)
    sequence.choose_orks_attack_stratagem(board, card)
    let slot = int(melee)
    let rules = model_weapon_rules(board, unit_id(0), 0, slot)
    return sequence.is_done() and board.command_points[0] == 9 and chosen_weapon_has_rule(board, unit_id(1), rules, expected) and chosen_weapon_parameter(board, unit_id(1), rules, expected) == magnitude and !board.can_target_strat(false, card, board[0])

# War Horde's optional melee Lethal is a sourced ability, not a hit modifier.
fun test_orks17all_hit_em_harder_paid_ability() -> Bool:
    return orks17all_selected_ability(Stratagem::orks_hit_em_harder, true, WeaponRuleKind::letal_hits, 0)

# Vehicle charged melee Cleave1 excludes Walkers at actual selection.
fun test_orks17all_mow_em_down_paid_cleave() -> Bool:
    return orks17all_selected_ability(Stratagem::orks_mow_em_down, true, WeaponRuleKind::cleave, 1)

# Close-range Dakka grants Rapid1 when absent.
fun test_orks17all_close_range_dakka_paid_rapid() -> Bool:
    return orks17all_selected_ability(Stratagem::orks_close_range_dakka, false, WeaponRuleKind::rapid_fire, 1)

# Existing Rapid magnitude is improved, not treated as another competing
# instance, and its intrinsic value returns after this source expires.
fun test_orks17all_close_range_existing_rapid_and_expiry() -> Bool:
    let board = orks17all_selected_card_fixture(Stratagem::orks_close_range_dakka, false)
    board[0][0].additional_weapon_rules[0].append(weapon_rule(WeaponRuleKind::rapid_fire, 2))
    let sequence = orks_attack_selection(board, unit_id(0), false)
    sequence.choose_orks_attack_stratagem(board, Stratagem::orks_close_range_dakka)
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let enhanced = chosen_weapon_parameter(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::rapid_fire) == 3
    board.begin_phase(BattlePhase::charge)
    return enhanced and chosen_weapon_parameter(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::rapid_fire) == 2

# Shoota Never Enough Dakka uses ordinary duplicate Sustained selection.
fun test_orks17all_never_enough_dakka_paid_sustained() -> Bool:
    return orks17all_selected_ability(Stratagem::orks_never_enough_dakka, false, WeaponRuleKind::sustained_hit, 1)

# Kult's card affects ranged attacks only and spends its own source cost.
fun test_orks17all_dakkastorm_paid_sustained() -> Bool:
    return orks17all_selected_ability(Stratagem::orks_dakkastorm, false, WeaponRuleKind::sustained_hit, 1)

# Green Tide Unbridled A+1 is a melee addition after charging; ranged A stays
# unchanged, rather than being increased by the unit-wide grant.
fun test_orks17all_unbridled_carnage_melee_only_attacks() -> Bool:
    let board = orks17all_selected_card_fixture(Stratagem::orks_unbridled_carnage, true)
    let before = make_declared_weapon(board, unit_id(0), 0, 1)
    let attacks = declaration_fixed_attacks(board, unit_id(0), before, 0)
    let sequence = orks_attack_selection(board, unit_id(0), true)
    sequence.choose_orks_attack_stratagem(board, Stratagem::orks_unbridled_carnage)
    let ranged = make_declared_weapon(board, unit_id(0), 0, 0)
    return sequence.is_done() and declaration_fixed_attacks(board, unit_id(0), before, 0) == attacks + 1 and declaration_fixed_attacks(board, unit_id(0), ranged, 0) == 1

# Armed rerolls1 when not riled, all hits when riled; neither path sums hit
# modifiers or permits a second reroll of a single die.
fun test_orks17all_armed_to_da_teef_riled_rerolls() -> Bool:
    let board = orks17all_selected_card_fixture(Stratagem::orks_armed_to_da_teef, false)
    let sequence = orks_attack_selection(board, unit_id(0), false)
    sequence.choose_orks_attack_stratagem(board, Stratagem::orks_armed_to_da_teef)
    let normal = orks17c2b_info(board, 0)
    orks17f_intrinsic_riled(board[0][0])
    let riled = orks17c2b_info(board, 0)
    return normal.reroll1_hits and !normal.reroll_hits and riled.reroll1_hits and riled.reroll_hits

# Kustom+1 wound is conditional on the actual target not being M/V.
fun test_orks17all_kustom_dakka_non_vehicle_wound_bonus() -> Bool:
    let board = orks17all_selected_card_fixture(Stratagem::orks_kustom_dakka, false)
    let sequence = orks_attack_selection(board, unit_id(0), false)
    sequence.choose_orks_attack_stratagem(board, Stratagem::orks_kustom_dakka)
    let infantry = orks17c2b_info(board, 0).total_wound_modifier() == 1
    board[1][0].keywords.append(Keyword::vehicle)
    return infantry and orks17c2b_info(board, 0).total_wound_modifier() == 0

# Glowin+1AP requires within9in; distant targets are not upgraded.
fun test_orks17all_glowin_dakka_range_condition() -> Bool:
    let board = orks17all_selected_card_fixture(Stratagem::orks_glowin_dakka, false)
    let sequence = orks_attack_selection(board, unit_id(0), false)
    sequence.choose_orks_attack_stratagem(board, Stratagem::orks_glowin_dakka)
    let nearby = orks17c2b_info(board, 0).attack_penetration() == -1
    board[1][0].position = board_position(30, 5)
    return nearby and orks17c2b_info(board, 0).attack_penetration() == 0

# Long Uncontrolled Bursts gives full hit rerolls only against FLY.
fun test_orks17all_long_bursts_actual_fly_target() -> Bool:
    let board = orks17all_selected_card_fixture(Stratagem::orks_long_uncontrolled_bursts, false)
    let sequence = orks_attack_selection(board, unit_id(0), false)
    sequence.choose_orks_attack_stratagem(board, Stratagem::orks_long_uncontrolled_bursts)
    let grounded = !orks17c2b_info(board, 0).reroll_hits
    board[1][0].keywords.append(Keyword::fly)
    return grounded and orks17c2b_info(board, 0).reroll_hits

# Vindictive's three actual choices retain their complete sourced combinations.
fun test_orks17all_vindictive_three_modes_and_hazards() -> Bool:
    let all_good = true
    for index in range(3):
        let board = orks17all_selected_card_fixture(Stratagem::orks_vindictive_artillerists, false)
        let sequence = orks_attack_selection(board, unit_id(0), false)
        sequence.choose_orks_attack_stratagem(board, Stratagem::orks_vindictive_artillerists)
        let mode : OrksArtilleristMode
        mode.value = index
        sequence.choose_artillerist_mode(board, mode)
        let rules = model_weapon_rules(board, unit_id(0), 0, 0)
        all_good = all_good and sequence.is_done() and chosen_weapon_has_rule(board, unit_id(1), rules, WeaponRuleKind::letal_hits) == (index != 1) and chosen_weapon_has_rule(board, unit_id(1), rules, WeaponRuleKind::sustained_hit) == (index != 0) and chosen_weapon_has_rule(board, unit_id(1), rules, WeaponRuleKind::hazardous) == (index == 2)
    return all_good

# Supa-glowy's two tests are independent of ordinary Hazardous; selected
# alternate profiles of the same physical weapon do not double either count.
fun test_orks17all_supa_glowy_independent_hazard_counts() -> Bool:
    let board = orks17all_fixture(OrksDetachment::shoota_boyz)
    board[0][0].orks_enhancement = OrksEnhancement::supa_glowy_fing
    board[0][0].additional_weapon_rules[0].append(weapon_rule(WeaponRuleKind::hazardous))
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let declarations : DeclaredWeapons
    declarations.append(declaration)
    declarations.append(declaration)
    return chosen_weapon_parameter(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::anti) == 4 and chosen_weapon_has_rule(board, unit_id(1), declaration.selected_rules, WeaponRuleKind::devastating_wounds) and declared_hazardous_uses(declarations) == 3

# A physical Supa-only weapon has two tests; an ordinary-only weapon has one.
fun test_orks17all_hazard_types_not_interchangeable() -> Bool:
    let declarations : DeclaredWeapons
    let supa : DeclaredWeapon
    supa.slot = 0
    supa.selected_rules.append(weapon_rule(WeaponRuleKind::supa_hazardous))
    declarations.append(supa)
    let ordinary : DeclaredWeapon
    ordinary.slot = 1
    ordinary.selected_rules.append(weapon_rule(WeaponRuleKind::hazardous))
    declarations.append(ordinary)
    return declared_hazardous_uses(declarations) == 3 and MAX_HAZARDOUS_USES > 448 * 3

# Speediest uses natural1/2/3 failures even under a large hit bonus; natural6
# retains the ordinary critical outcome.
fun test_orks17all_speediest_natural_faces() -> Bool:
    let board = orks17all_fixture(OrksDetachment::kult_of_speed)
    board[1][0].keywords.append(Keyword::speed_freeks)
    let sequence = orks_attack_targeted(board, unit_id(0), unit_id(1), false)
    sequence.choose_orks_defence_stratagem(board, Stratagem::orks_speediest_freeks)
    let info = orks17c2b_info(board, 0)
    return classify_attack_hit(board, info, attack_test_die(3), 10, 2) == AttackRollResult::failed and classify_attack_hit(board, info, attack_test_die(4), 0, 2) == AttackRollResult::success and classify_attack_hit(board, info, attack_test_die(6), 0, 6) == AttackRollResult::critical

# Hulking's optional extra1CP is committed atomically with its base cost;
# choosing all ranged attacks grants protection even when S<=T.
fun test_orks17all_hulking_surcharge_and_all_attack_protection() -> Bool:
    let board = orks17all_fixture(OrksDetachment::bully_boyz)
    orks17all_tag(board[1], OrksDatasheet::nobz)
    let sequence = orks_attack_targeted(board, unit_id(0), unit_id(1), false)
    sequence.choose_orks_defence_stratagem(board, Stratagem::orks_hulking_brutes)
    let unspent = board.command_points[1] == 10
    sequence.choose_hulking_protection(board, true)
    return unspent and sequence.is_done() and board.command_points[1] == 8 and orks17c2b_info(board, 0).total_wound_modifier() == -1

# At1CP, the stronger option is illegal but the base option remains usable.
fun test_orks17all_hulking_unaffordable_surcharge_no_partial_spend() -> Bool:
    let board = orks17all_fixture(OrksDetachment::bully_boyz)
    orks17all_tag(board[1], OrksDatasheet::nobz)
    board.command_points[1] = 1
    let sequence = orks_attack_targeted(board, unit_id(0), unit_id(1), false)
    sequence.choose_orks_defence_stratagem(board, Stratagem::orks_hulking_brutes)
    let unaffordable = !can sequence.choose_hulking_protection(board, true) and board.command_points[1] == 1
    sequence.choose_hulking_protection(board, false)
    return unaffordable and board.command_points[1] == 0

# Defensive4+ retains its source-owner snapshot and the riled+1 captured at
# destruction; choosing one's own fight beforehand closes the card permission.
fun test_orks17all_paid_fight_on_death_thresholds() -> Bool:
    let board = orks17all_fixture(OrksDetachment::war_horde)
    board.begin_phase(BattlePhase::fight)
    let sequence = orks_attack_targeted(board, unit_id(0), unit_id(1), true)
    sequence.choose_orks_defence_stratagem(board, Stratagem::orks_orks_is_never_beaten)
    let ordinary = orks_fight_death_threshold(board, board[1], board[1][0]) == 4
    orks17f_intrinsic_riled(board[1][0])
    return ordinary and orks_fight_death_threshold(board, board[1], board[1][0]) == 3

# Actual damage rolls its faction permission NOW, retains a successful corpse,
# and does not require rolling that same permission on the later selection.
fun test_orks17all_actual_fight_on_death_damage_retention() -> Bool:
    let board = orks17all_fixture(OrksDetachment::war_horde)
    board.begin_phase(BattlePhase::fight)
    let defence = orks_attack_targeted(board, unit_id(0), unit_id(1), true)
    defence.choose_orks_defence_stratagem(board, Stratagem::orks_orks_is_never_beaten)
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(1), unit_id(0), true, true, board[1][0].wounds_left(), board[1][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(0))
    damage.roll(board, attack_test_die(4))
    return damage.is_done() and board[1].models.size() == 1 and board[1][0].state == ModelState::fight_on_death and board[1][0].destruction_pending and board[1][0].destruction_fight_roll == 1

# Crazed Rampage's Deff Dread+3 is not replaced by ordinary riled+1.
fun test_orks17all_crazed_deff_dread_threshold() -> Bool:
    let board = orks17all_fixture(OrksDetachment::dread_mob)
    board.begin_phase(BattlePhase::fight)
    board[1][0].keywords.append(Keyword::walker)
    orks17all_tag(board[1], OrksDatasheet::deff_dread)
    let sequence = orks_attack_targeted(board, unit_id(0), unit_id(1), true)
    sequence.choose_orks_defence_stratagem(board, Stratagem::orks_crazed_rampage)
    return orks_fight_death_threshold(board, board[1], board[1][0]) == 1 and board.command_points[1] == 9

# A retained all-dead unit can still receive its paid selection grant while
# it attacks; ordinary corpses receive no permission by being archived.
fun test_orks17all_retained_unit_stratagem_installation() -> Bool:
    let board = orks17all_fixture(OrksDetachment::war_horde)
    board.begin_phase(BattlePhase::fight)
    board[0][0].state = ModelState::fight_on_death
    board[0][0].suffered_wounds = board[0][0].profile.wounds()
    let sequence = orks_attack_selection(board, unit_id(0), true)
    sequence.choose_orks_attack_stratagem(board, Stratagem::orks_hit_em_harder)
    return sequence.is_done() and unit_rule_effect(board, board[0], RuleEffectKind::melee_lethal) == 1 and valid_source_foundations(board)

# Movement card selection spends before granting ordered M or advance dice
# modifiers, and a failed/absent selection leaves CP/history unchanged.
fun test_orks17all_fungus_fuel_effective_movement() -> Bool:
    let board = orks17all_fixture(OrksDetachment::war_horde)
    board.begin_phase(BattlePhase::movement)
    board[0][0].keywords.append(Keyword::mounted)
    let sequence = orks_move_selection(board, unit_id(0), false)
    sequence.choose_orks_move_stratagem(board, Stratagem::orks_fungus_fuel_injection)
    return sequence.is_done() and board.command_points[0] == 9 and board[0][0].effective_movement(6) == 8

# 'Ere We Go changes the Advance roll bonus, not M, and excludes other units.
fun test_orks17all_ere_we_go_advance_bonus() -> Bool:
    let board = orks17all_fixture(OrksDetachment::green_tide)
    board.begin_phase(BattlePhase::movement)
    let sequence = orks_move_selection(board, unit_id(0), false)
    sequence.choose_orks_move_stratagem(board, Stratagem::orks_ere_we_go)
    return sequence.is_done() and unit_rule_effect(board, board[0], RuleEffectKind::advance_plus_two) == 1 and board[0][0].effective_movement(6) == 6

# Mobile is a real sourced keyword, expires after its phase and does not add
# physical terrain features excluded by the user's area-only instruction.
fun test_orks17all_stomping_mobile_and_expiry() -> Bool:
    let board = orks17all_fixture(OrksDetachment::dread_mob)
    board.begin_phase(BattlePhase::charge)
    board[0][0].keywords.append(Keyword::walker)
    let sequence = orks_move_selection(board, unit_id(0), true)
    sequence.choose_orks_move_stratagem(board, Stratagem::orks_stomping_juggernaut)
    let granted = sequence.is_done() and board[0][0].has_keyword(Keyword::mobile)
    board.begin_phase(BattlePhase::fight)
    return granted and !board[0][0].has_keyword(Keyword::mobile)

# Mind On Mission affects only selected Advance/Fall Back, does not waive
# shock or after-shooting restrictions, and is not a new move type.
fun test_orks17all_mind_on_mission_action_permission() -> Bool:
    let board = orks17all_fixture(OrksDetachment::taktikal_brigade)
    board.begin_phase(BattlePhase::movement)
    orks17all_tag(board[0], OrksDatasheet::kommandos)
    let sequence = orks_move_mode(board, unit_id(0), MovementKind::advance)
    sequence.mind_on_mission(board)
    capture_orks_selected_move(board, unit_id(0), MovementKind::advance)
    record_move(board, unit_id(0), MovementKind::advance)
    return sequence.is_done() and board[0].allows_action_start() and board.command_points[0] == 9

# Wimp-kickaz forces escaping and applies cumulative-1 only while its own
# engaged source is riled, without affecting ordinary Advance rolls.
fun test_orks17all_wimp_escape_and_riled_penalty() -> Bool:
    let board = orks17all_fixture(OrksDetachment::bully_boyz)
    board[1][0].position = board_position(7, 5)
    board[1][0].orks_enhancement = OrksEnhancement::wimp_kickaz
    let forced = orks_forces_escape(board, board[0]) and orks_escape_penalty(board, board[0]) == 0
    orks17f_intrinsic_riled(board[1][0])
    return forced and orks_escape_penalty(board, board[0]) == 1

# Hunt's accepted unit forces Desperate Escape and counts ALL engaged Snagga
# units for its extra3 rolls against M/V (not just the unit that paid).
fun test_orks17all_hunt_escape_all_engaged_snaggas() -> Bool:
    let board = orks17all_fixture(OrksDetachment::da_big_hunt)
    board.begin_phase(BattlePhase::movement)
    board[1][0].position = board_position(7, 5)
    board[1][0].keywords.append(Keyword::beast_snagga)
    board[0][0].keywords.append(Keyword::vehicle)
    let reaction = orks_fallback_selection(board, unit_id(0))
    reaction.choose_hunting_escape_unit(board, unit_id(1))
    return reaction.is_done() and orks_forces_escape(board, board[0]) and orks_extra_escape_hazards(board, board[0]) == 3 and board.command_points[1] == 9

# An explicit reactive six-inch maximum is not a modified M; Follow Me Ladz
# cannot expand it to8, and roles/limits return to the caller after declining.
fun test_orks17all_reactive_distance_not_m_characteristic() -> Bool:
    let board = orks17all_fixture(OrksDetachment::war_horde)
    board[1][0].position = board_position(30, 5)
    board[0][0].orks_enhancement = OrksEnhancement::follow_me_ladz
    register_orks_option_passives(board)
    let six : StatModifier
    six = 6
    let sequence = reactive_move(board, unit_id(0), six, false)
    let exact = can sequence.move_to(board, board_position(11, 5)) and !can sequence.move_to(board, board_position(12, 5))
    sequence.skip(board)
    return exact and sequence.is_done() and board[0].movement_distance_limit == 0 and board.current_decision_maker == false

# Grove shielding pays for the separate Gretchin target, leaving the protected
# infantry's own stratagem-target allowance available (Runt Swarm/Grot Shields).
fun orks17all_grot_fixture() -> Board:
    let board = orks17all_fixture(OrksDetachment::runt_swarm)
    let grots = board[1]
    grots.identity = 0
    grots[0].identity = 0
    grots[0].original_unit = 0
    grots[0].position = board_position(12, 7)
    orks17all_tag(grots, OrksDatasheet::gretchin)
    board.units.append(grots)
    board.identify_units()
    let shield = orks_attack_targeted(board, unit_id(0), unit_id(1), false)
    shield.choose_grot_shield_unit(board, unit_id(2))
    return board

fun test_orks17all_grot_shield_separate_cp_target() -> Bool:
    let board = orks17all_grot_fixture()
    return board.command_points[1] == 9 and board[2].history.stratagem_targeted_by_player[1] and !board[1].history.stratagem_targeted_by_player[1] and orks_grot_shield(board, board[1]) == 2

# An original Lethal critical is cancelled, its separately generated Sustained
# hit survives, and the shield suffers1 actual mortal via ordinary allocation.
fun test_orks17all_grot_shield_original_lethal_and_sustained() -> Bool:
    let board = orks17all_grot_fixture()
    board.command_points[0] = 0
    board.attack_info.source = Weapon::orks_slugga
    board.attack_info.add_letal_hits()
    board.attack_info.add_sustained_hits(1)
    begin_attack_results(board)
    let dice = resolve_attack_dice(board, board[1], board[0], attack_test_count(1))
    dice.roll(board, board[1], board[0], attack_test_die(6))
    dice.use_lethal_hits(board, board[1], board[0], true)
    dice.select_mortal_model(board, board[1], board[0], damage_test_model(0))
    let intercepted = board[2][0].suffered_wounds == 1 and board[1][0].suffered_wounds == 0 and dice.generated_hits == 1 and dice.generated_wounds == 0
    dice.roll(board, board[1], board[0], attack_test_die(1))
    return intercepted and dice.is_done() and dice.generated_wounds == 0

# Torrent has no successful HIT ROLL and therefore is not intercepted.
fun test_orks17all_grot_shield_does_not_intercept_torrent() -> Bool:
    let board = orks17all_grot_fixture()
    board.command_points[0] = 0
    board.attack_info.source = Weapon::pyreblaster
    let dice = resolve_attack_dice(board, board[1], board[0], attack_test_count(1))
    dice.roll(board, board[1], board[0], attack_test_die(1))
    return dice.is_done() and board[2][0].suffered_wounds == 0 and dice.generated_hits == 1

# Post-attack reactions distinguish hits from real wounds after prevention;
# selecting a target alone does not trigger Gun-crazy or Goaded.
fun test_orks17all_post_attack_ledger_actual_hits_and_wounds() -> Bool:
    let board = orks17all_fixture(OrksDetachment::wreckas)
    orks17all_tag(board[1], OrksDatasheet::flash_gitz)
    begin_attack_results(board)
    let no_hit = !orks_post_attack_card_valid(board, unit_id(0), unit_id(1), Stratagem::orks_gun_crazy_show_offs, false)
    record_attack_hits(board, unit_id(1), 1)
    let hit = orks_post_attack_card_valid(board, unit_id(0), unit_id(1), Stratagem::orks_gun_crazy_show_offs, false)
    let other = board.armies[1].record_detachment(OrksDetachment::da_big_hunt)
    board[1][0].keywords.append(Keyword::beast_snagga)
    let not_wounded = !orks_post_attack_card_valid(board, unit_id(0), unit_id(1), Stratagem::orks_goaded_into_action, false)
    let job = damage_job(DamageKind::normal, unit_id(1), unit_id(0), true, true, 1, board[1][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 1, false)
    return no_hit and hit and not_wounded and orks_post_attack_card_valid(board, unit_id(0), unit_id(1), Stratagem::orks_goaded_into_action, false)

# Grab It permanently records this turn's no-charge permission alongside its
# objective-constrained normal move, rather than merely changing UI choices.
fun test_orks17all_grab_it_charge_lock_expiry() -> Bool:
    let board = orks17all_fixture(OrksDetachment::wreckas)
    grant_orks_effect(board, unit_id(0), unit_id(0), 300 + Stratagem::orks_grab_it.value, RuleEffectKind::no_charge, 1, SourceDuration::turn, invalid_entity_identity())
    board.begin_phase(BattlePhase::charge)
    let blocked = !charge_source_valid(board, unit_id(0), false)
    board.turn_serial = board.turn_serial + 1
    refresh_source_effects(board, TimingWindow::none)
    return blocked and unit_rule_effect(board, board[0], RuleEffectKind::no_charge) == 0

# New Infested units receive new unit/model identities and fresh usage/wounds;
# the original destroyed archive is retained, not revived or overwritten.
fun test_orks17all_infested_new_unit_identity_and_template() -> Bool:
    let board = orks17all_fixture(OrksDetachment::runt_swarm)
    orks17all_tag(board[1], OrksDatasheet::gretchin)
    board[1].capture_starting_strength()
    let original_unit = board[1].identity
    let original_model = board[1][0].identity
    board[1][0].used_once_per_battle_weapon[0] = true
    board[1][0].suffered_wounds = board[1][0].profile.wounds()
    board[1].remove_model(0)
    create_orks_replacement(board, unit_id(1))
    ref replacement = board.reserve_units[0]
    return board[1].identity == original_unit and board[1].destroyed_models.value[0].identity == original_model and replacement.identity != original_unit and replacement[0].identity != original_model and replacement[0].suffered_wounds == 0 and !replacement[0].used_once_per_battle_weapon[0] and replacement.is_generated_replacement and replacement.off_battlefield and replacement.history.strategic_reserve

# Actual unit death has the current activation serial. An earlier attack's
# casualty cannot spend Infested during a later enemy activation.
fun test_orks17all_infested_current_activation_gate() -> Bool:
    let board = orks17all_fixture(OrksDetachment::runt_swarm)
    orks17all_tag(board[1], OrksDatasheet::gretchin)
    board[1].capture_starting_strength()
    begin_attack_results(board)
    let job = damage_job(DamageKind::normal, unit_id(1), unit_id(0), true, true, 2, board[1][0].identity)
    commit_wound_loss(board, job, damage_test_model(0), 2, false)
    let current = orks_post_attack_card_valid(board, unit_id(0), unit_id(1), Stratagem::orks_infested_war_zone, false)
    begin_attack_results(board)
    return current and !orks_post_attack_card_valid(board, unit_id(0), unit_id(1), Stratagem::orks_infested_war_zone, false)

# Heal3 restores wounds individually before any non-Character revival.
fun test_orks17all_heal_wounded_model_before_revival() -> Bool:
    let board = orks17all_fixture(OrksDetachment::kult_of_speed)
    board[0][0].suffered_wounds = 1
    let count : FixedStat
    count = 3
    let healing = heal_unit(board, board[0], SourceBank::battlefield, count)
    healing.choose_healed_model(board, board[0], damage_test_model(0))
    return healing.is_done() and board[0][0].suffered_wounds == 0 and board[0].models.size() == 1

# Revival retains identity/equipment/One Shot, uses phase-start coherency and
# returns1W instead of creating a duplicate original model.
fun test_orks17all_heal_revives_original_identity_and_usage() -> Bool:
    let board = orks17all_fixture(OrksDetachment::kult_of_speed)
    let extra = board[0][0]
    extra.identity = 0
    extra.position = board_position(5, 7)
    extra.used_once_per_battle_weapon[0] = true
    board[0].models.append(extra)
    board.identify_units()
    board[0].capture_starting_strength()
    board.begin_phase(BattlePhase::movement)
    let identity = board[0][1].identity
    board[0][1].suffered_wounds = board[0][1].profile.wounds()
    board[0].remove_model(1)
    let count : FixedStat
    count = 1
    let healing = heal_unit(board, board[0], SourceBank::battlefield, count)
    healing.choose_healed_casualty(board, board[0], damage_test_model(0))
    healing.place_returned_model(board, board[0], board_position(5, 7))
    return healing.is_done() and board[0].models.size() == 2 and board[0][1].identity == identity and board[0][1].wounds_left() == 1 and board[0][1].used_once_per_battle_weapon[0] and board[0].destroyed_models.value.empty()

# Unit healing never returns a Character just because other models are full.
fun test_orks17all_healing_excludes_character_casualties() -> Bool:
    let board = orks17all_fixture(OrksDetachment::kult_of_speed)
    let extra = board[0][0]
    extra.identity = 0
    extra.keywords.append(Keyword::character)
    extra.position = board_position(5, 7)
    board[0].models.append(extra)
    board.identify_units()
    board[0].capture_starting_strength()
    board.begin_phase(BattlePhase::movement)
    board[0].remove_model(1)
    return !healing_archive_valid(board, board[0], SourceBank::battlefield, damage_test_model(0))

# A first returned model cannot anchor another return if it was absent at
# phase start; illegal new enemy engagements remain rejected.
fun test_orks17all_return_phase_start_and_new_engagement_gates() -> Bool:
    let board = orks17all_fixture(OrksDetachment::kult_of_speed)
    let returned = board[0][0]
    let old = return_position_valid(board, unit_id(0), returned, board_position(5, 7), ReturnPlacementPolicy::phase_start)
    board[0].history.phase_start_members.clear()
    let absent = !return_position_valid(board, unit_id(0), returned, board_position(5, 7), ReturnPlacementPolicy::phase_start)
    board[1][0].position = board_position(7, 7)
    return old and absent and !return_position_valid(board, unit_id(0), returned, board_position(5, 7), ReturnPlacementPolicy::phase_start)

# A psychic1 shocks but still grants Fights First; its level is spent, and a
# second same-phase use is unavailable (Wurrband/22.03.01).
fun test_orks17all_visions_psychic_one_still_grants_effect() -> Bool:
    let board = orks17all_fixture(OrksDetachment::wurrband)
    board[0][0].keywords.append(Keyword::psyker)
    board[0].psyker_level = 1
    board.begin_phase(BattlePhase::fight)
    let psychic = use_orks_psychic(board, unit_id(0), true)
    psychic.roll(board, attack_test_die(1))
    return psychic.is_done() and board[0].battle_socked and fight_first_unit(board[0]) and board[0].orks_psychic_usage.budget.spent == 1 and !orks_psychic_available(board, unit_id(0), true)

# Warphead's once-per-ability phase restriction is separate from its level2
# round budget. A new round restores budget; a phase alone does not.
fun test_orks17all_warphead_psychic_round_budget() -> Bool:
    let board = orks17all_fixture(OrksDetachment::wurrband)
    board[0][0].keywords.append(Keyword::psyker)
    board[0][0].orks_enhancement = OrksEnhancement::warphead
    board[0].orks_psychic_usage.budget.round_stamp = board.current_round.value + 1
    board[0].orks_psychic_usage.budget.spent = 2
    let spent = !orks_psychic_available(board, unit_id(0), false)
    board.begin_phase(BattlePhase::fight)
    let still_spent = !orks_psychic_available(board, unit_id(0), true)
    board.current_round = board.current_round + 1
    return spent and still_spent and orks_psychic_available(board, unit_id(0), true)

# Roar uses the enemy's normal shock rules after the psychic roll, excludes
# M/V, and consumes its own level even if the caster rolls a1.
fun test_orks17all_roar_psychic_one_and_enemy_shock() -> Bool:
    let board = orks17all_fixture(OrksDetachment::wurrband)
    board[0][0].keywords.append(Keyword::psyker)
    board[0].psyker_level = 1
    board.begin_phase(BattlePhase::movement)
    let psychic = use_orks_psychic(board, unit_id(0), false)
    psychic.roll(board, attack_test_die(1))
    psychic.choose_roar_target(board, unit_id(1))
    psychic.roll_pair(board, attack_test_die(1), attack_test_die(1))
    return psychic.is_done() and board[0].battle_socked and board[1].battle_socked and board.current_decision_maker == false

# Named plasma/slot lookalikes cannot acquire Snazzgun or Shokk-only upgrades.
fun test_orks17all_supa_snazz_named_weapon_gate() -> Bool:
    let board = orks17all_fixture(OrksDetachment::wreckas)
    board[0][0].orks_enhancement = OrksEnhancement::supa_snazz_dakka
    let absent = !available_weapon_has_rule(board, unit_id(0), 0, 0, WeaponRuleKind::rapid_fire)
    board[0][0].weapons[0].profile = Weapon::orks_flash_gitz_snazzgun_cutta
    let rules = model_weapon_rules(board, unit_id(0), 0, 0)
    return absent and chosen_weapon_parameter(board, unit_id(1), rules, WeaponRuleKind::rapid_fire) == 1

# Targetin' Squigs adds3 Range to the unit, excluding Torrent on the actual
# selected weapon (the named source card, not every numbered slot).
fun test_orks17all_targetin_squigs_torrent_exclusion() -> Bool:
    let board = orks17all_fixture(OrksDetachment::shoota_boyz)
    board[0][0].orks_enhancement = OrksEnhancement::targetin_squigs
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let ordinary = declaration_weapon_range(board, unit_id(0), declaration) == 15
    board[0][0].additional_weapon_rules[0].append(weapon_rule(WeaponRuleKind::torrent))
    let torrent = make_declared_weapon(board, unit_id(0), 0, 0)
    return ordinary and declaration_weapon_range(board, unit_id(0), torrent) == 12

# Ferocious uses current LIVE strength11+, not starting strength or corpses.
fun test_orks17all_ferocious_live_eleven_boundary() -> Bool:
    let board = orks17all_fixture(OrksDetachment::green_tide)
    board[0][0].orks_enhancement = OrksEnhancement::ferocious_show_off
    let bearer = make_declared_weapon(board, unit_id(0), 0, 1)
    let small = declaration_fixed_attacks(board, unit_id(0), bearer, 0)
    let additional = board[0][0]
    additional.identity = 0
    additional.orks_enhancement = OrksEnhancement::none
    for index in range(10):
        board[0].models.append(additional)
    board.identify_units()
    let large = declaration_fixed_attacks(board, unit_id(0), bearer, 0) == small + 1
    board[0].remove_model(10)
    return large and declaration_fixed_attacks(board, unit_id(0), bearer, 0) == small

# Proper Killy applies to its bearer, not every member of the unit.
fun test_orks17all_proper_killy_bearer_reroll_scope() -> Bool:
    let board = orks17all_fixture(OrksDetachment::brute_bosses)
    board[0][0].orks_enhancement = OrksEnhancement::proper_killy
    let extra = board[0][0]
    extra.identity = 0
    extra.orks_enhancement = OrksEnhancement::none
    board[0].models.append(extra)
    board.identify_units()
    let bearer = orks17c2b_info(board, 0)
    let declaration = make_declared_weapon(board, unit_id(0), 1, 0)
    let other = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    return bearer.reroll1_hits and !other.reroll1_hits

# Da Boss is Watchin' riles its own unit and consumes its army/battle token,
# while the effect survives source death until the next own turn.
fun test_orks17all_watchin_once_army_next_own_turn() -> Bool:
    let board = orks17all_fixture(OrksDetachment::war_horde)
    board.begin_phase(BattlePhase::movement)
    board[0][0].orks_enhancement = OrksEnhancement::da_boss_is_watchin
    let sequence = orks_movement_abilities(board, unit_id(0))
    sequence.choose_orks_movement_ability(board, OrksDetachmentAbility::da_boss_is_watchin)
    let accepted = sequence.is_done() and unit_is_riled_up(board[0]) and !orks_movement_ability_available(board, unit_id(0))
    board.turn_serial = board.turn_serial + 1
    board.current_player = true
    refresh_source_effects(board, TimingWindow::none)
    let opponent_turn = unit_is_riled_up(board[0])
    board.turn_serial = board.turn_serial + 1
    board.current_player = false
    refresh_source_effects(board, TimingWindow::none)
    return accepted and opponent_turn and !unit_is_riled_up(board[0])

# Reserve/passenger own abilities do not measure external range. Watchin'
# installs a real persistent effect in the reserve bank with the same token.
fun test_orks17all_offboard_watchin_own_unit() -> Bool:
    let board = orks17all_fixture(OrksDetachment::war_horde)
    board.begin_phase(BattlePhase::movement)
    board[0][0].orks_enhancement = OrksEnhancement::da_boss_is_watchin
    let moved = reposition_unit(board, unit_id(0))
    let before = orks_offboard_support_valid(board, SourceBank::reserves, unit_id(0), false, false)
    let sequence = choose_orks_offboard_support(board, false, false)
    sequence.choose_orks_support_bank(board, SourceBank::reserves)
    sequence.choose_orks_offboard_unit(board, unit_id(0))
    return moved and before and sequence.is_done() and unit_is_riled_up(board.reserve_units[0]) and !orks_offboard_support_valid(board, SourceBank::reserves, unit_id(0), false, false)

# Visions can be used on its own offboard unit, but this never provides
# visibility/range to enemy units for Roar or an attack.
fun test_orks17all_offboard_visions_no_external_visibility() -> Bool:
    let board = orks17all_fixture(OrksDetachment::wurrband)
    board[0][0].keywords.append(Keyword::psyker)
    board[0].psyker_level = 1
    let moved = reposition_unit(board, unit_id(0))
    board.begin_phase(BattlePhase::fight)
    let sequence = choose_orks_offboard_support(board, false, true)
    sequence.choose_orks_support_bank(board, SourceBank::reserves)
    sequence.choose_orks_offboard_unit(board, unit_id(0))
    sequence.roll(board, attack_test_die(1))
    return moved and sequence.is_done() and board.reserve_units[0].battle_socked and fight_first_unit(board.reserve_units[0]) and !unit_visible_to_unit(board, board.reserve_units[0], board[1])

# Offboard Dread Power pays for the real reserve unit, and its phase target
# history/persisting riled effect remain present on that unit.
fun test_orks17all_offboard_dread_power_paid_target() -> Bool:
    let board = orks17all_fixture(OrksDetachment::dread_mob)
    board.begin_phase(BattlePhase::movement)
    board[0][0].keywords.append(Keyword::walker)
    let moved = reposition_unit(board, unit_id(0))
    let sequence = choose_orks_offboard_dread_power(board, false)
    sequence.choose_orks_dread_bank(board, SourceBank::reserves)
    sequence.choose_offboard_dread_unit(board, unit_id(0))
    return moved and sequence.is_done() and board.command_points[0] == 9 and board.reserve_units[0].history.stratagem_targeted_by_player[0] and unit_is_riled_up(board.reserve_units[0])

# Source attacks are grouped separately when Speediest's unmodified-face
# failures differ, even if their final hit modifiers match (p17).
fun test_orks17all_grouping_preserves_natural_face_gates() -> Bool:
    let board = orks17all_fixture(OrksDetachment::kult_of_speed)
    let first = orks17c2b_info(board, 0)
    let second = first
    second.fail_hits_up_to_three = true
    return !attacks_are_identical(board, first, second)

# Unpredictable6 changes effective target T until this activation ends, then
# removes only its own key rather than every matching Toughness modifier.
fun test_orks17all_madcap_toughness_scoped_expiry() -> Bool:
    let board = orks17all_fixture(OrksDetachment::madcap_meks)
    board[0][0].keywords.append(Keyword::big_mek)
    let initial = board[1].get_unit_toughtness()
    let table = orks_unpredictable_genius(board, unit_id(0), unit_id(1))
    table.roll(board, attack_test_die(6))
    let changed = board[1].get_unit_toughtness() == initial - 1
    remove_scoped_source_effect(board, table.effect)
    return table.is_done() and changed and board[1].get_unit_toughtness() == initial

# Lifted adds FLY and removes cover only for the scoped activation; it does
# not permanently write the target's intrinsic keywords.
fun test_orks17all_madcap_lifted_keyword_and_cover() -> Bool:
    let board = orks17all_fixture(OrksDetachment::madcap_meks)
    board[0][0].keywords.append(Keyword::big_mek)
    let table = orks_unpredictable_genius(board, unit_id(0), unit_id(1))
    table.roll(board, attack_test_die(5))
    let lifted = board[1].has_keyword(Keyword::fly)
    remove_scoped_source_effect(board, table.effect)
    return lifted and !board[1].has_keyword(Keyword::fly)

# Madcap1's granted4+ keeps a better original save; it expires after shooting.
fun test_orks17all_madcap_invulnerable_grant_and_expiry() -> Bool:
    let board = orks17all_fixture(OrksDetachment::madcap_meks)
    board[0][0].keywords.append(Keyword::big_mek)
    let initial = board[1][0].effective_invulnerable_save()
    let table = orks_unpredictable_genius(board, unit_id(0), unit_id(1))
    table.roll(board, attack_test_die(1))
    let granted = board[1][0].effective_invulnerable_save() == 4
    remove_scoped_source_effect(board, table.effect)
    return granted and board[1][0].effective_invulnerable_save() == initial

# Temperamental's named-weapon Sustained2 belongs only to its bearer, not
# a second model with a coincidentally matching weapon slot/name.
fun test_orks17all_shokka_bearer_only_sustained() -> Bool:
    let board = orks17all_fixture(OrksDetachment::madcap_meks)
    board[0][0].orks_enhancement = OrksEnhancement::temperamental_shokka
    board[0][0].weapons[0].profile = Weapon::orks_big_mek_with_shokk_attack_gun_shokk_attack_gun
    let other = board[0][0]
    other.identity = 0
    other.orks_enhancement = OrksEnhancement::none
    board[0].models.append(other)
    board.identify_units()
    let selection = orks_shokka_selection(board, unit_id(0))
    selection.temperamental_shokka(board)
    selection.roll(board, attack_test_die(6))
    let first = model_weapon_rules(board, unit_id(0), 0, 0)
    let second = model_weapon_rules(board, unit_id(0), 1, 0)
    return selection.is_done() and chosen_weapon_parameter(board, unit_id(1), first, WeaponRuleKind::sustained_hit) == 2 and !chosen_weapon_has_rule(board, unit_id(1), second, WeaponRuleKind::sustained_hit)

# An intentional1 result grants Torrent and destroys that exact bearer AFTER
# shooting, compacting indices without killing the following model instead.
fun test_orks17all_shokka_destroy_after_shot_identity() -> Bool:
    let board = orks17all_fixture(OrksDetachment::madcap_meks)
    board[0][0].orks_enhancement = OrksEnhancement::temperamental_shokka
    board[0][0].weapons[0].profile = Weapon::orks_big_mek_with_shokk_attack_gun_shokk_attack_gun
    let doomed = board[0][0].identity
    let other = board[0][0]
    other.identity = 0
    other.orks_enhancement = OrksEnhancement::none
    other.position = board_position(5, 7)
    board[0].models.append(other)
    board.identify_units()
    let survivor = board[0][1].identity
    let selection = orks_shokka_selection(board, unit_id(0))
    selection.temperamental_shokka(board)
    selection.roll(board, attack_test_die(1))
    let torrent = available_weapon_has_rule(board, unit_id(0), 0, 0, WeaponRuleKind::torrent)
    let end = orks_shooting_option_end(board, unit_id(0))
    return torrent and end.is_done() and board[0].models.size() == 1 and board[0][0].identity == survivor and board[0].destroyed_models.value[0].identity == doomed

# Smoky uses intentional circular-base line crossing for partial obscuration;
# it never blocks visibility under the user's supplied approximation.
fun test_orks17all_smoky_circle_crossing_and_visibility() -> Bool:
    let board = orks17all_fixture(OrksDetachment::kult_of_speed)
    let blocker = make_orks_beast_snagga_boyz(1, 9, 0)
    blocker.models.resize(1)
    blocker[0].position = board_position(8, 5)
    blocker[0].orks_enhancement = OrksEnhancement::smoky_gubbinz
    board.units.append(blocker)
    board.identify_units()
    let obscured = orks_smoky_cover(board, board[0][0], board[1])
    let visible = unit_visible_to_unit(board, board[0], board[1])
    board[2][0].position = board_position(8, 10)
    return obscured and visible and !orks_smoky_cover(board, board[0][0], board[1])

# Blitz Wagon and Competitive Streak use normal charge rerolls; unrelated
# ordinary units cannot receive this option by sharing their army package.
fun test_orks17all_blitz_and_competitive_charge_rerolls() -> Bool:
    let board = orks17all_fixture(OrksDetachment::blitz_brigade)
    let absent = !orks_charge_reroll(board, board[0])
    board[0][0].keywords.append(Keyword::wagon)
    let wagon = orks_charge_reroll(board, board[0])
    board[1][0].orks_enhancement = OrksEnhancement::competitive_streak
    return absent and wagon and orks_charge_reroll(board, board[1])

# Impulsive lets its Aircraft ingress in round1 while the ordinary Aircraft
# still waits for round2. This is not a price/reserve-limit exception.
fun test_orks17all_impulsive_first_round_ingress_gate() -> Bool:
    let board = orks17all_fixture(OrksDetachment::flyboyz)
    board.begin_phase(BattlePhase::movement)
    board[0][0].keywords.append(Keyword::aircraft)
    let ordinary = !orks_ingress_round_allowed(board, board[0])
    board[0][0].orks_enhancement = OrksEnhancement::impulsive_recon
    let fast = orks_ingress_round_allowed(board, board[0])
    board[0].history.has_ingressed = true
    return ordinary and fast and !orks_ingress_round_allowed(board, board[0])

# Flyboss riles nearby Aircraft/Deffkoptas after actual ingress, excluding
# ordinary infantry and enemy units regardless of their flying keywords.
fun test_orks17all_flyboss_ingress_recipient_gate() -> Bool:
    let board = orks17all_fixture(OrksDetachment::flyboyz)
    board[0][0].orks_enhancement = OrksEnhancement::flyboss
    board[0][0].keywords.append(Keyword::aircraft)
    let friendly = make_orks_beast_snagga_boyz(1, 9, 0)
    friendly.models.resize(1)
    friendly[0].position = board_position(8, 5)
    orks17all_tag(friendly, OrksDatasheet::deffkoptas)
    board.units.append(friendly)
    board.identify_units()
    orks_flyboss_ingress(board, unit_id(0))
    return unit_is_riled_up(board[0]) and unit_is_riled_up(board[2]) and !unit_is_riled_up(board[1])

# A phase start clears stale battlefield revival anchors in both offboard
# banks; an arriving unit cannot claim it started the phase on the board.
fun test_orks17all_offboard_phase_start_snapshots_clear() -> Bool:
    let board = orks17all_fixture(OrksDetachment::kult_of_speed)
    let before = !board[0].history.phase_start_members.empty()
    let moved = reposition_unit(board, unit_id(0))
    board.begin_phase(BattlePhase::movement)
    return before and moved and board.reserve_units[0].history.phase_start_members.empty() and board.reserve_units[0].history.phase_start_engagements.empty()

# Named enhancement weapons use their exact printed characteristic/rule
# profiles, with D3 interpreted as fixed3 only where the card prints3.
fun test_orks17all_named_enhancement_weapon_profiles() -> Bool:
    return orks17h1_weapon_values(Weapon::orks_da_gobshot_thunderbuss, 24, 6, 4, 7, -2, 2) and orks17h1_weapon_values(Weapon::orks_da_krunch, 24, 3, 4, 5, -1, 1) and orks17h1_weapon_values(Weapon::orks_eadbanger, 24, 2, 4, 6, -3, 3) and Weapon::orks_da_gobshot_thunderbuss.get_rule_parameter(WeaponRuleKind::rapid_fire) == 6 and Weapon::orks_da_krunch.get_rule_parameter(WeaponRuleKind::blast) == 3 and Weapon::orks_eadbanger.has_rule(WeaponRuleKind::precision)

# Retained models keep riled status for their authorised attacks; ordinary
# pending corpses cannot substitute for an active riled unit.
fun test_orks17all_retained_riled_attack_status() -> Bool:
    let board = orks17all_fixture(OrksDetachment::bully_boyz)
    orks17f_intrinsic_riled(board[0][0])
    board[0][0].suffered_wounds = board[0][0].profile.wounds()
    board[0][0].state = ModelState::fight_on_death
    let retained = unit_is_riled_up(board[0])
    board[0][0].state = ModelState::pending_destruction
    return retained and !unit_is_riled_up(board[0])

# Board/source/declaration history round trips include schema32 and the new
# keyed fields. Incorrect enum values are rejected before any load commits.
fun test_orks17all_detachment_state_save_and_invalid_enum() -> Bool:
    let game = play()
    game.board = orks17all_fixture(OrksDetachment::shoota_boyz)
    grant_orks_effect(game.board, unit_id(0), unit_id(0), 300 + Stratagem::orks_never_enough_dakka.value, RuleEffectKind::ranged_sustained, 1, SourceDuration::phase, invalid_entity_identity())
    let restored = play()
    let good = set_state(restored, to_string(game)) and unit_rule_effect(restored.board, restored.board[0], RuleEffectKind::ranged_sustained) == 1
    game.board[0][0].orks_enhancement.value = 99
    return good and !set_state(restored, to_string(game)) and restored.board[0][0].orks_enhancement.value == 0

# Minimal explicit transport metadata validates cargo consumers without
# inventing Battlewagon/Morkanaut profiles or source base/hull sizes.
fun orks17all_transport_fixture() -> Board:
    let board = transport16_fixture()
    board.armies[0].faction = ArmyFaction::orks
    let package = board.armies[0].record_detachment(OrksDetachment::blitz_brigade)
    board[0][0].keywords.append(Keyword::orks)
    board[0][0].keywords.append(Keyword::wagon)
    for member in range(board[1].models.size()):
        board[1][member].keywords.append(Keyword::orks)
    board.command_points[0] = 10
    return board

# Blitzboss retains a BETTER native save, grants+2 M only while this bearer
# is cargo, and removes both keyed grants after disembark/death.
fun test_orks17all_blitzboss_cargo_lifetime_and_better_save() -> Bool:
    let board = orks17all_transport_fixture()
    board[1][0].orks_enhancement = OrksEnhancement::blitzboss
    let original_inv = board[0][0].effective_invulnerable_save()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    let cargo = board[0][0].effective_movement(6) == 8 and board[0][0].effective_invulnerable_save() == min(5, original_inv)
    board.embarked_units[0].embarked_transport = 0
    refresh_source_effects(board, TimingWindow::none)
    return cargo and board[0][0].effective_movement(6) == 6 and board[0][0].effective_invulnerable_save() == original_inv

# Targetin' Gizmos requires an actual Big Mek in this carrier; riled changes
# only the Sustained addition, and empty cargo ends both permissions.
fun test_orks17all_targetin_gizmos_actual_cargo_and_riled() -> Bool:
    let board = orks17all_transport_fixture()
    board[0][0].orks_enhancement = OrksEnhancement::targetin_gizmos
    board[1][0].keywords.append(Keyword::big_mek)
    let empty = !available_weapon_has_rule(board, unit_id(0), 0, 0, WeaponRuleKind::ignore_cover)
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    let cover = available_weapon_has_rule(board, unit_id(0), 0, 0, WeaponRuleKind::ignore_cover)
    orks17f_intrinsic_riled(board[0][0])
    let sustained = available_weapon_has_rule(board, unit_id(0), 0, 0, WeaponRuleKind::sustained_hit)
    board.embarked_units[0].embarked_transport = 0
    return empty and cover and sustained and !available_weapon_has_rule(board, unit_id(0), 0, 0, WeaponRuleKind::ignore_cover)

# Boss Boomer borrows the actual Warboss's ability and its distinct shared
# army-round counter, rather than treating its text as Keep Huntin'.
fun test_orks17all_boss_boomer_borrowed_ability_dependency() -> Bool:
    let board = orks17all_transport_fixture()
    board[0][0].orks_enhancement = OrksEnhancement::boss_boomer
    board[1][0].keywords.append(Keyword::warboss)
    board[1][0].abilities.append(AbilityKind::intimidating_motivation)
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    let borrowed = board[0][0].has_ability(AbilityKind::intimidating_motivation)
    let sources = collect_source_events(board, orks17h23_move_event(board, 0, false, MovementKind::normal))
    let registered = sources.size() == 1 and board.source_instances[sources[0].source.value].rule.value == ORKS_INTIMIDATING_RULE
    board.embarked_units[0].embarked_transport = 0
    refresh_source_effects(board, TimingWindow::none)
    let ceased = collect_source_events(board, orks17h23_move_event(board, 0, false, MovementKind::normal)).empty()
    return borrowed and registered and ceased and !board[0][0].has_ability(AbilityKind::intimidating_motivation)

# Readied triggers only after WAGON Normal completion; its passengers get
# Assault setup with charging permitted, rather than ordinary Rapid lock.
fun test_orks17all_readied_assault_disembark_permission() -> Bool:
    let board = orks17all_transport_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    record_move(board, unit_id(0), MovementKind::normal)
    let card = orks_wagon_move_end(board, unit_id(0))
    card.readied_brawlers(board)
    let carrier = find_passenger_carrier(board, board.embarked_units[0].embarked_transport)
    return card.is_done() and board.command_points[0] == 9 and required_disembark_mode(board, board.embarked_units[0], carrier) == DisembarkMode::assault

# Keep It Runnin' is a whole-unit6in exception, allows an already-selected
# unit, and respects actual carrier capacity rather than normal after-move3in.
fun test_orks17all_keep_running_six_inch_whole_unit_embark() -> Bool:
    let board = orks17all_transport_fixture()
    board.begin_phase(BattlePhase::fight)
    board[1][0].position = board_position(14, 10)
    board[1][1].position = board_position(14, 12)
    board[1].history.fight_eligible_phase = board.phase_serial.value + 1
    let eligible = orks_end_card_valid(board, unit_id(1), Stratagem::orks_keep_it_runnin, false, TimingWindow::fight_end)
    let card = orks_package_window(board, unit_id(1), false, TimingWindow::fight_end)
    card.choose_orks_window_stratagem(board, Stratagem::orks_keep_it_runnin)
    card.choose_fight_end_transport(board, unit_id(0))
    card.choose_fight_end_carrier_model(board, damage_test_model(0))
    return eligible and card.is_done() and board[1].retired and board.embarked_units.size() == 1 and board.embarked_units[0].models.size() == 2

# Wurrband transport contributors are actual models, not their weighted
# transport-space usage (one carrier's psychic weapon strength).
fun test_orks17all_psychic_passenger_count_not_seats() -> Bool:
    let board = orks17all_transport_fixture()
    board[1][0].transport_space = 3
    board[1][1].transport_space = 2
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    return embarked_models_for_psyker(board, board[0][0].identity) == 2 and passenger_space_used(board, board[0][0].identity) == 5

# Dreadherder measures from its bearer, grants a turn-long reroll to the
# selected Walker and does not require that bearer to shoot first.
fun test_orks17all_dreadherder_before_other_units_shoot() -> Bool:
    let board = orks17all_fixture(OrksDetachment::dread_mob)
    board[0][0].orks_enhancement = OrksEnhancement::dreadherder
    let walker = make_orks_beast_snagga_boyz(1, 9, 0)
    walker.models.resize(1)
    walker[0].keywords.append(Keyword::walker)
    walker[0].position = board_position(7, 5)
    board.units.append(walker)
    board.identify_units()
    let available = orks_dreadherder_available(board, unit_id(0))
    let selection = orks_dreadherder_shooting(board, unit_id(0))
    selection.choose_dreadherder_target(board, unit_id(2))
    let granted = unit_rule_effect(board, board[2], RuleEffectKind::reroll_hits_ones) == 1
    board.begin_phase(BattlePhase::fight)
    return available and granted and !board[0].has_shoot and unit_rule_effect(board, board[2], RuleEffectKind::reroll_hits_ones) == 1

# A successful Surly returns its original identity with3W at a nearest legal
# quad. Its once-per-army token prevents another source/attempt this battle.
fun test_orks17all_surly_original_identity_three_wounds() -> Bool:
    let board = orks17all_fixture(OrksDetachment::brute_bosses)
    let boss = make_octavius()
    boss.owned_by_player1 = true
    boss[0].position = board_position(12, 5)
    boss[0].keywords.append(Keyword::orks)
    boss[0].keywords.append(Keyword::warboss)
    boss[0].orks_enhancement = OrksEnhancement::surly_as_a_squiggoth
    board[1] = boss
    board.identify_units()
    let identity = board[1][0].identity
    board[1][0].suffered_wounds = board[1][0].profile.wounds()
    board[1][0].destroyed_phase = board.phase_serial.value + 1
    board[1].remove_model(0)
    let revival = resolve_orks_surly(board, unit_id(1), true)
    revival.choose_surly_casualty(board, damage_test_model(0))
    revival.roll(board, attack_test_die(2))
    revival.place_returned_model(board, board_position(12, 5))
    return revival.is_done() and board[1][0].identity == identity and board[1][0].wounds_left() == 3 and board[1].destroyed_models.value.empty() and !source_usage_available(board, make_source_usage(board[1].owned_by_player1, 200 + OrksEnhancement::surly_as_a_squiggoth.value, board[1].identity, board[1][0].identity, SourceUseScope::army, source_use_limits(0, 0, 0, 1)))

# Returned passengers need a real available seat; no-trigger destruction on
# lack of seats cannot start another death explosion/recursion (01.02.03).
fun test_orks17all_offboard_return_capacity_gate() -> Bool:
    let board = orks17all_transport_fixture()
    embark_battlefield_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    let returned = board.embarked_units[0][0]
    board.embarked_units[0].remove_model(0)
    let available = returned_passenger_permitted(board, board.embarked_units[0], returned)
    board[0][0].transport_capacity = 1
    return available and !returned_passenger_permitted(board, board.embarked_units[0], returned)

# At a full source arena, a disabled/dead unreferenced slot can be reused only
# with a new generation; a frozen pending event must never activate the new
# occupant even when owner/rule/type happen to match (identity infrastructure).
fun test_orks17all_source_arena_reuse_rejects_stale_generation() -> Bool:
    let board = orks17all_fixture(OrksDetachment::war_horde)
    let instance : SourceInstance
    instance.rule = 470
    instance.owner = false
    instance.source_unit = board[0].identity
    instance.window = TimingWindow::command_start
    instance.optional = true
    instance.grant = riled_up_grant()
    for slot in range(MAX_SOURCE_INSTANCES):
        let handle = register_source_instance(board, instance)
    let event : SourceEvent
    event.kind = SourceEventKind::timing_window
    event.window = TimingWindow::command_start
    let frozen = collect_source_events(board, event)
    let old_generation = board.source_instances[0].generation
    board.source_instances[0].disabled = true
    let reused = register_source_instance(board, instance)
    let choice : SourceEventID
    choice = 0
    return frozen.size() == MAX_SOURCE_INSTANCES and reused.value == 0 and board.source_instances[0].generation != old_generation and !pending_source_valid(board, frozen, choice, false) and valid_source_foundations(board)

# Slot recycling protects every ordinary reserve/passenger return slot. It
# applies only to NEW replacements, never compacts or redirects ordinary units.
fun test_orks17all_replacement_slot_reservation_protection() -> Bool:
    let board = orks17all_fixture(OrksDetachment::runt_swarm)
    while board.units.size() < MAX_UNIT_COUNT:
        let empty : Unit
        empty.retired = true
        board.units.append(empty)
    let reserved = make_orks_beast_snagga_boyz(1, 9, 0)
    reserved.models.resize(1)
    reserved.has_return_slot = true
    reserved.return_slot = 2
    board.reserve_units.append(reserved)
    return replacement_slot(board) == 3 and battlefield_entry_available(board, board.reserve_units[0])

# A live Surly end-phase archive cannot be evicted by a replacement arriving
# into a full arena before its mandatory revival chance (source lifecycle).
fun test_orks17all_replacement_slot_pending_surly_protection() -> Bool:
    let board = orks17all_fixture(OrksDetachment::brute_bosses)
    let boss = make_octavius()
    boss[0].orks_enhancement = OrksEnhancement::surly_as_a_squiggoth
    board.units.append(boss)
    board.identify_units()
    board[2][0].destroyed_phase = board.phase_serial.value + 1
    board[2].remove_model(0)
    while board.units.size() < MAX_UNIT_COUNT:
        let empty : Unit
        empty.retired = true
        board.units.append(empty)
    return replacement_slot(board) == 3

# The largest native permission list still has room for exactly one card-
# added bodyguard. Re-applying the same permission does not append a duplicate.
fun test_orks17all_extra_leader_permission_seven_slot_envelope() -> Bool:
    let board = orks17all_option_board(1, OrksDetachment::taktikal_brigade, true)
    orks17all_tag(board.reserve_units[0], OrksDatasheet::big_mek)
    configure_orks_attachment(board.reserve_units[0], OrksDatasheet::big_mek)
    let original = board.reserve_units[0].permitted_bodyguards.size()
    apply_orks_option(board, unit_id(0), damage_test_model(0), OrksEnhancement::kill_kommanda, false)
    let added = board.reserve_units[0].permitted_bodyguards.size() == original + 1
    orks_extra_bodyguard_permission(board.reserve_units[0], OrksDatasheet::kommandos)
    return added and board.reserve_units[0].permitted_bodyguards.size() == original + 1 and MAX_BODYGUARD_TYPES == 7

# Kill Kommanda's attached bearer gets Stealth/Infiltrators; bodyguard death
# ends that conditional active conferral, including a still-archived component.
fun test_orks17all_kill_kommanda_bearer_attachment_condition() -> Bool:
    let board = orks17all_option_board(2, OrksDetachment::taktikal_brigade, true)
    orks17all_tag(board.reserve_units[0], OrksDatasheet::big_mek)
    configure_orks_attachment(board.reserve_units[0], OrksDatasheet::big_mek)
    apply_orks_option(board, unit_id(0), damage_test_model(0), OrksEnhancement::kill_kommanda, false)
    orks17all_tag(board.reserve_units[1], OrksDatasheet::kommandos)
    board.reserve_units[1].attachment_role = AttachmentRole::bodyguard
    let bearer = board.reserve_units[0][0].identity
    attach_reserved_unit(board, unit_id(0), unit_id(1), false)
    let index = board.reserve_units[0].find_model(bearer)
    let attached = orks_model_grants_ability(board.reserve_units[0], board.reserve_units[0][index], AbilityKind::stealth)
    let bodyguard = 1 - index
    board.reserve_units[0].remove_model(bodyguard)
    return attached and !orks_model_grants_ability(board.reserve_units[0], board.reserve_units[0][0], AbilityKind::stealth)

# Source-marker ownership follows which player selected Wreckas. The target's
# objective can qualify even when the shooter was not within an objective.
fun test_orks17all_wrecka_target_objective_reroll() -> Bool:
    let board = orks17all_fixture(OrksDetachment::wreckas)
    orks17all_tag(board[0], OrksDatasheet::flash_gitz)
    board.mission_scoring = MissionScoringMode::legacy_four_markers
    let location = board.get_objectives_locations()[0]
    board[1][0].position = location
    return orks17c2b_info(board, 0).reroll1_hits

# Flyboss can make an otherwise non-Character Aircraft eligible for Warlord
# selection, but it remains an Upgrade and cannot be combined with another.
fun test_orks17all_flyboss_character_upgrade_muster() -> Bool:
    let board = orks17all_option_board(1, OrksDetachment::flyboyz, false)
    board.reserve_units[0][0].keywords.append(Keyword::aircraft)
    apply_orks_option(board, unit_id(0), damage_test_model(0), OrksEnhancement::flyboss, false)
    return board.reserve_units[0].has_keyword(Keyword::character) and board.reserve_units[0][0].has_keyword(Keyword::character) and !orks_option_selection_valid(board, unit_id(0), damage_test_model(0), OrksEnhancement::impulsive_recon, false)

# Optional declines do not consume army tokens, CP or phase-target history.
fun test_orks17all_optional_declines_leave_usage_unspent() -> Bool:
    let board = orks17all_fixture(OrksDetachment::war_horde)
    board[0][0].orks_enhancement = OrksEnhancement::da_boss_is_watchin
    board.begin_phase(BattlePhase::movement)
    let ability = orks_movement_abilities(board, unit_id(0))
    ability.finish_orks_movement_abilities(board)
    return ability.is_done() and board.source_uses.empty() and board.command_points[0] == 10 and orks_movement_ability_available(board, unit_id(0))

# A source effect installed in reserves keeps its duration and is removed at
# the next OWN turn, not merely because the opposing turn starts.
fun test_orks17all_offboard_effect_boundary_and_save() -> Bool:
    let game = play()
    game.board = orks17all_fixture(OrksDetachment::war_horde)
    game.board.begin_phase(BattlePhase::movement)
    game.board[0][0].orks_enhancement = OrksEnhancement::da_boss_is_watchin
    let moved = reposition_unit(game.board, unit_id(0))
    let ability = choose_orks_offboard_support(game.board, false, false)
    ability.choose_orks_support_bank(game.board, SourceBank::reserves)
    ability.choose_orks_offboard_unit(game.board, unit_id(0))
    let restored = play()
    let saved = set_state(restored, to_string(game))
    restored.board.current_player = true
    restored.board.turn_serial = restored.board.turn_serial + 1
    refresh_source_effects(restored.board, TimingWindow::none)
    let persists = unit_is_riled_up(restored.board.reserve_units[0])
    restored.board.current_player = false
    restored.board.turn_serial = restored.board.turn_serial + 1
    refresh_source_effects(restored.board, TimingWindow::none)
    return moved and saved and persists and !unit_is_riled_up(restored.board.reserve_units[0])


# Flyin' Headbutt replaces demise and must apply its8 rolled mortals BEFORE
# removing the destroyed Aircraft; this guards the work stack's LIFO order.
fun test_orks17all_headbutt_mortals_before_aircraft_removal() -> Bool:
    let board = orks17all_fixture(OrksDetachment::flyboyz)
    board[0][0].keywords.append(Keyword::aircraft)
    board[0][0].has_deadly_demise = true
    board[0][0].deadly_demise = raw_stat(6)
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(0), unit_id(1), true, true, 30, board[0][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(1))
    let empty : DamageJobs
    let cleanup = resolve_damage_jobs(board, empty, true, unit_id(1))
    cleanup.choose_destruction_unit(board, unit_id(0))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.flyin_headbutt(board)
    cleanup.choose_headbutt_target(board, unit_id(1))
    cleanup.roll(board, attack_test_die(4))
    for face in range(7):
        cleanup.roll(board, attack_test_die(1))
    let retained = board[0].models.size() == 1 and can cleanup.select_mortal_model(board, damage_test_model(0))
    cleanup.select_mortal_model(board, damage_test_model(0))
    return retained and cleanup.is_done() and board[0].models.size() == 0 and board[1][0].suffered_wounds == 1 and board.command_points[0] == 9

# Impulsive's first-own-Movement exception does not authorize another phase
# or the opponent's turn. Normal round2 ingress remains unaffected.
fun test_orks17all_impulsive_own_movement_only() -> Bool:
    let board = orks17all_fixture(OrksDetachment::flyboyz)
    board[0][0].keywords.append(Keyword::aircraft)
    board[0][0].orks_enhancement = OrksEnhancement::impulsive_recon
    let wrong_phase = !orks_ingress_round_allowed(board, board[0])
    board.begin_phase(BattlePhase::movement)
    let own = orks_ingress_round_allowed(board, board[0])
    board.current_player = true
    return wrong_phase and own and !orks_ingress_round_allowed(board, board[0])

# Dread Power spends CP on the selected Walker and keeps its riled effect
# through the opposing turn until the start of its next own turn.
fun test_orks17all_dread_power_battlefield_duration() -> Bool:
    let board = orks17all_fixture(OrksDetachment::dread_mob)
    board[0][0].keywords.append(Keyword::walker)
    board.begin_phase(BattlePhase::movement)
    let valid = orks_support_card_valid(board, unit_id(0), Stratagem::orks_dread_power, false, TimingWindow::none)
    let card = use_orks_support_card(board, unit_id(0), Stratagem::orks_dread_power)
    board.current_player = true
    board.turn_serial = board.turn_serial + 1
    refresh_source_effects(board, TimingWindow::none)
    let persists = unit_is_riled_up(board[0])
    board.current_player = false
    board.turn_serial = board.turn_serial + 1
    refresh_source_effects(board, TimingWindow::none)
    return valid and card.is_done() and board.command_points[0] == 9 and persists and !unit_is_riled_up(board[0])

# Mob Mentality pays on13+-model infantry; its separate visible nearby ORKS
# beneficiary auto-passes the command shock roll without a chance decision.
fun test_orks17all_mob_mentality_separate_beneficiary() -> Bool:
    let board = orks17all_fixture(OrksDetachment::green_tide)
    let mob = make_orks_beast_snagga_boyz(1, 12, 0)
    mob.owned_by_player1 = false
    board[0] = mob
    board[1].owned_by_player1 = false
    board.identify_units()
    for index in range(board[0].models.size()):
        board[0][index].position = board_position(5 + index % 4, 5 + index / 4)
    board.begin_phase(BattlePhase::command)
    let valid = orks_support_card_valid(board, unit_id(0), Stratagem::orks_mob_mentality, false, TimingWindow::command_start)
    let card = use_orks_support_card(board, unit_id(0), Stratagem::orks_mob_mentality)
    card.choose_mob_mentality_target(board, unit_id(1))
    board[1].battle_socked = true
    let penalty : LinearlyDistributedInt<0, 8>
    let shock = battle_shock_test(board, board[1], true, true, penalty)
    return valid and card.is_done() and shock.is_done() and !board[1].battle_socked and board.command_points[0] == 9 and board[0].history.used_stratagem_this_phase

# Delicious heals each distinct chosen nearby infantry by3, with one buggy
# payment; another selection of an already healed unit is illegal.
fun test_orks17all_delicious_distinct_units_one_payment() -> Bool:
    let board = orks17all_fixture(OrksDetachment::kult_of_speed)
    orks17all_tag(board[0], OrksDatasheet::rukkatrukk_squigbuggies)
    board[1].owned_by_player1 = false
    board[1][0].position = board_position(7, 5)
    board[1][0].suffered_wounds = 1
    board.begin_phase(BattlePhase::movement)
    let card = use_orks_support_card(board, unit_id(0), Stratagem::orks_delicious_eating_squigs)
    card.choose_squig_healing_unit(board, unit_id(1))
    card.choose_healed_model(board, damage_test_model(0))
    let no_repeat = !(can card.choose_squig_healing_unit(board, unit_id(1)))
    card.finish_eating_squigs(board)
    return no_repeat and card.is_done() and board[1][0].suffered_wounds == 0 and board.command_points[0] == 9

# A dead offboard Surly returns to its original reserve unit with3W and its
# original identity. No battlefield measurement/setup choice is generated.
fun test_orks17all_offboard_surly_original_return() -> Bool:
    let board = orks17all_fixture(OrksDetachment::brute_bosses)
    board[0][0].orks_enhancement = OrksEnhancement::surly_as_a_squiggoth
    let identity = board[0][0].identity
    let moved = reposition_unit(board, unit_id(0))
    board.reserve_units[0][0].suffered_wounds = board.reserve_units[0][0].profile.wounds()
    board.reserve_units[0][0].destroyed_phase = board.phase_serial.value + 1
    board.reserve_units[0].remove_model(0)
    let revival = return_orks_surly(board, board.reserve_units[0], SourceBank::reserves, unit_id(0), damage_test_model(0))
    revival.roll(board, board.reserve_units[0], attack_test_die(2))
    return moved and revival.is_done() and board.reserve_units[0][0].identity == identity and board.reserve_units[0][0].wounds_left() == 3 and board.reserve_units[0][0].off_battlefield

# Invalid Dreadherder entry must preserve its caller's decision owner.
fun test_orks17all_dreadherder_invalid_owner_restoration() -> Bool:
    let board = orks17all_fixture(OrksDetachment::dread_mob)
    board.current_decision_maker = true
    board.begin_phase(BattlePhase::movement)
    board.current_decision_maker = true
    let selection = orks_dreadherder_shooting(board, unit_id(0))
    return selection.is_done() and board.current_decision_maker


#12 current version1.2 Orks card adapters. Each test cites its source card;
# helper fixtures exercise actual declarations, rather than old army profiles.
fun orks17p1_fixture(Unit source) -> Board:
    let board = orks17h1_attack_board()
    board[0] = source
    for index in range(board[0].models.size()):
        board[0][index].position = board_position(5 + (index % 4) * 2, 5 + (index / 4) * 2)
    board[1][0].position = board_position(9, 5)
    board.identify_units()
    board.capture_starting_strengths()
    board.begin_phase(BattlePhase::shooting)
    configure_attack_info(board, 0, 1, false, false)
    return board

# Boyz: reusable literal-count fixture permits independently checked swaps.
fun orks17p1_boy_equipment(Int nobs, Int boys) -> OrksBoyzLoadouts:
    let equipment : OrksBoyzLoadouts
    for index in range(nobs + boys):
        let item = orks_boy_loadout()
        item.nob = index < nobs
        equipment.append(item)
    return equipment

# Nobz: independent per-five equipment quotas, no point-tier restriction.
fun orks17p1_nob_equipment(Int count) -> OrksNobLoadouts:
    let equipment : OrksNobLoadouts
    for index in range(count):
        equipment.append(Weapon::orks_kustom_shoota)
    return equipment

# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz: printed profile/InSv/FNP/base.
fun test_orks17p1_boy_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_boy, 6, 5, 5, 10, 1, 7, 2, 10) and Profile::orks_boy.base_size() == 32.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz: printed profile/InSv/FNP/base.
fun test_orks17p1_boyz_nob_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_boyz_nob, 6, 5, 5, 10, 3, 7, 2, 10) and Profile::orks_boyz_nob.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz: printed profile/InSv/FNP/base.
fun test_orks17p1_nob_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_nob, 6, 5, 4, 10, 3, 7, 1, 10) and Profile::orks_nob.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss: printed profile/InSv/FNP/base.
fun test_orks17p1_warboss_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_warboss, 6, 6, 4, 5, 6, 6, 1, 10) and Profile::orks_warboss.base_size() == 50.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Bigboss: printed profile/InSv/FNP/base.
fun test_orks17p1_bigboss_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_bigboss, 6, 5, 4, 10, 5, 7, 1, 10) and Profile::orks_bigboss.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Bannernob: printed profile/InSv/FNP/base.
fun test_orks17p1_bannernob_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_bannernob, 6, 5, 4, 5, 4, 7, 3, 10) and Profile::orks_bannernob.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Stormboyz: printed profile/InSv/FNP/base.
fun test_orks17p1_stormboy_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_stormboy, 12, 5, 5, 10, 1, 7, 1, 10) and Profile::orks_stormboy.base_size() == 32.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Stormboyz: printed profile/InSv/FNP/base.
fun test_orks17p1_stormboy_nob_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_stormboy_nob, 12, 5, 5, 10, 3, 7, 1, 10) and Profile::orks_stormboy_nob.base_size() == 32.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers: printed profile/InSv/FNP/base.
fun test_orks17p1_warbiker_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_warbiker, 12, 6, 4, 6, 3, 7, 2, 10) and Profile::orks_warbiker.base_size() == 75.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers: printed profile/InSv/FNP/base.
fun test_orks17p1_biker_nob_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_biker_nob, 12, 6, 4, 6, 4, 7, 2, 10) and Profile::orks_biker_nob.base_size() == 75.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread: printed profile/InSv/FNP/base.
fun test_orks17p1_deff_dread_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_deff_dread, 8, 9, 2, 6, 8, 7, 3, 10) and Profile::orks_deff_dread.base_size() == 60.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans: printed profile/InSv/FNP/base.
fun test_orks17p1_killa_kan_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_killa_kan, 8, 7, 3, 6, 5, 8, 2, 10) and Profile::orks_killa_kan.base_size() == 60.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-Dakkarig: printed profile/InSv/FNP/base.
fun test_orks17p1_big_mek_dakkarig_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_big_mek_dakkarig, 8, 8, 3, 5, 11, 7, 3, 10) and Profile::orks_big_mek_dakkarig.base_size() == 90.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur: printed profile/InSv/FNP/base.
fun test_orks17p1_beastboss_on_squigosaur_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_beastboss_on_squigosaur, 10, 9, 3, 5, 10, 6, 3, 5) and Profile::orks_beastboss_on_squigosaur.base_size() == 80.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad: printed profile/InSv/FNP/base.
fun test_orks17p1_mozrog_skragbad_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_mozrog_skragbad, 10, 9, 3, 4, 10, 6, 3, 5) and Profile::orks_mozrog_skragbad.base_size() == 80.0

# Boyz: literal1–2 Nobs/9–18 Boys, including intermediate compositions.
fun test_orks17p1_boy_count_boundaries() -> Bool:
    let small = orks17p1_boy_equipment(1, 9)
    let large = orks17p1_boy_equipment(2, 18)
    let intermediate = orks17p1_boy_equipment(2, 11)
    let invalid = orks17p1_boy_equipment(1, 8)
    return orks_boyz_loadout_valid(small) and orks_boyz_loadout_valid(large) and orks_boyz_loadout_valid(intermediate) and !orks_boyz_loadout_valid(invalid) and make_orks_boyz(large).models.size() == 20

# Boyz: all three different replacements coexist at ten models.
fun test_orks17p1_boy_independent_specials() -> Bool:
    let equipment = orks17p1_boy_equipment(1, 9)
    equipment[1].boy_gun = Weapon::orks_infantry_big_shoota
    equipment[2].boy_gun = Weapon::orks_rokkit_launcha_blasta
    equipment[3].boy_gun = Weapon::orks_burna
    let valid = orks_boyz_loadout_valid(equipment)
    let unit = make_orks_boyz(equipment)
    equipment[4].boy_gun = Weapon::orks_burna
    return valid and !orks_boyz_loadout_valid(equipment) and unit[1].weapons.size() == 3 and unit[2].weapons.size() == 4 and unit[3].weapons.size() == 3 and weapon_primary_id(unit[2], 2) == weapon_primary_id(unit[2], 3)

# Boyz: per-ten TOTAL models means nineteen permits one, twenty permits two.
fun test_orks17p1_boy_twenty_quota() -> Bool:
    let equipment = orks17p1_boy_equipment(2, 18)
    equipment[2].boy_gun = Weapon::orks_infantry_big_shoota
    equipment[3].boy_gun = Weapon::orks_infantry_big_shoota
    let valid = orks_boyz_loadout_valid(equipment)
    equipment.erase(19)
    return valid and !orks_boyz_loadout_valid(equipment)

# Boyz: Big Choppa removes both Nob weapons; other swaps retain a gun.
fun test_orks17p1_mixed_nob_weapons() -> Bool:
    let equipment = orks17p1_boy_equipment(2, 9)
    equipment[0].melee = Weapon::orks_infantry_big_choppa
    equipment[0].nob_gun = Weapon::none
    equipment[1].melee = Weapon::orks_power_klaw
    equipment[1].nob_gun = Weapon::orks_kombi_rokkit_busta
    let valid = orks_boyz_loadout_valid(equipment)
    let unit = make_orks_boyz(equipment)
    equipment[0].nob_gun = Weapon::orks_kustom_shoota
    return valid and unit[0].weapons.size() == 1 and unit[1].weapons.size() == 3 and unit[1].weapons[0].profile.value == Weapon::orks_power_klaw.value and !orks_boyz_loadout_valid(equipment)

# Nobz: independent Paired/heavy quotas per-five, all replacements exclusive.
fun test_orks17p1_nob_independent_replacements() -> Bool:
    let equipment = orks17p1_nob_equipment(5)
    equipment[0] = Weapon::orks_paired_krumpas
    equipment[1] = Weapon::orks_big_skorcha
    equipment[2] = Weapon::orks_kustom_big_shoota
    equipment[3] = Weapon::orks_infantry_big_choppa
    equipment[4] = Weapon::orks_kombi_rokkit_busta
    let valid = orks_nobz_loadout_valid(equipment)
    let unit = make_orks_nobz(equipment)
    return valid and unit[0].weapons[0].profile.value == Weapon::orks_paired_krumpas.value and unit[0].weapons.size() == 1 and unit[1].weapons[0].profile.value == Weapon::orks_kustom_choppa.value and unit[2].weapons.size() == 2 and unit[3].weapons.size() == 1 and unit[4].weapons.size() == 3

# Nobz: every restricted replacement rejects its second copy below ten.
fun test_orks17p1_nob_quota_boundaries() -> Bool:
    let valid = true
    for kind in range(4):
        let equipment = orks17p1_nob_equipment(10)
        let choice = orks_nob_loadout_choice(kind + 2)
        equipment[0] = choice
        equipment[1] = choice
        valid = valid and orks_nobz_loadout_valid(equipment)
        equipment.erase(9)
        valid = valid and !orks_nobz_loadout_valid(equipment)
    let too_small = orks17p1_nob_equipment(4)
    let too_big = orks17p1_nob_equipment(11)
    return valid and !orks_nobz_loadout_valid(too_small) and !orks_nobz_loadout_valid(too_big)

# Deff-Dread: twenty independent permitted arm combinations, fixed Klaws retained.
fun test_orks17p1_dread_all_arm_combinations() -> Bool:
    let valid = true
    for first_index in range(5):
        for second_index in range(5):
            if first_index != 1:
                let first = orks_dread_arm_choice(first_index)
                let second = orks_dread_arm_choice(second_index)
                let unit = make_orks_deff_dread(first, second)
                valid = valid and unit[0].weapons[0].profile.value == Weapon::orks_dread_klaws.value and weapon_primary_id(unit[0], 1) == 2 and weapon_primary_id(unit[0], unit[0].weapons.size() - 1) > 2
    return valid

# Deff-Dread: two Extra Klaws are distinct physical mandatory melee weapons.
fun test_orks17p1_dread_two_extra_klaws() -> Bool:
    let board = orks17p1_fixture(make_orks_deff_dread(Weapon::orks_extra_klaw, Weapon::orks_extra_klaw))
    let selected : Bool[MAX_WEAPONS]
    selected[1] = true
    let other = weapon_selection_valid(board, unit_id(0), 0, 2, true, selected, false)
    return other and board[0][0].weapons.size() == 3 and weapon_primary_id(board[0][0], 1) != weapon_primary_id(board[0][0], 2) and board[0][0].weapons[2].profile.has_rule(WeaponRuleKind::extra_attacks)

# Deff-Dread: Dread 'Ard affects incoming attack D, never non-attack mortal jobs.
fun test_orks17p1_dread_incoming_damage() -> Bool:
    let unit = make_orks_deff_dread()
    let modifiers : RuleModifiers
    let incoming = combined_incoming_modifiers(modifiers, unit[0].incoming_attack_modifiers, ModifiedCharacteristic::damage, true)
    return modified_characteristic(3, ModifiedCharacteristic::damage, incoming, false) == 2 and modified_characteristic(1, ModifiedCharacteristic::damage, incoming, false) == 1 and unit[0].has_deadly_demise and stat_dice_count(unit[0].deadly_demise) == 0

# Stormboyz/Warbikers/Kans: endpoints and printed keyword/Deep Strike metadata.
fun test_orks17p1_mobile_unit_compositions() -> Bool:
    let storm = make_orks_stormboyz(9, true)
    let bikes = make_orks_warbikers(5)
    let kans = make_orks_killa_kans(6)
    return storm.models.size() == 10 and storm[0].weapons[1].profile.value == Weapon::orks_power_klaw.value and storm.has_ability(AbilityKind::deep_strike) and storm.has_keyword(Keyword::fly) and bikes.models.size() == 6 and bikes.has_keyword(Keyword::speed_freeks) and kans.models.size() == 6 and kans.has_keyword(Keyword::grots) and !kans.has_keyword(Keyword::gretchin)

# Warbikers: documented circular proxy preserves both source axes.
fun test_orks17p1_biker_circle_proxy() -> Bool:
    let unit = make_orks_warbikers(2)
    return profile_has_oval_base(unit[0].profile) and profile_base_width(unit[0].profile) == 42.0 and unit[0].profile.base_size() == 75.0 and !unit[0].geometry.unsupported_footprint and unit[1].weapons.size() == 2 and weapon_primary_id(unit[0], 0) == weapon_primary_id(unit[0], 1)

# Killa-Kans: all three gun profiles are alternatives of one physical weapon.
fun test_orks17p1_kan_profile_exclusion() -> Bool:
    let board = orks17p1_fixture(make_orks_killa_kans(3))
    let selected : Bool[MAX_WEAPONS]
    let first = weapon_selection_valid(board, unit_id(0), 0, 0, false, selected, false)
    selected[0] = true
    return first and !weapon_selection_valid(board, unit_id(0), 0, 1, false, selected, false) and !weapon_selection_valid(board, unit_id(0), 0, 2, false, selected, false)

# Warboss/Bannernob/Bigboss: real Leader/Support roles and Da Boss only on Warboss.
fun test_orks17p1_boss_attachment_metadata() -> Bool:
    let leader = make_orks_warboss()
    let support = make_orks_bigboss()
    let banner = make_orks_bannernob()
    return leader.attachment_role.value == AttachmentRole::leader.value and leader[0].has_da_boss and support.attachment_role.value == AttachmentRole::support.value and !support[0].has_da_boss and banner.attachment_role.value == AttachmentRole::support.value and support[0].weapons[1].profile.has_rule(WeaponRuleKind::precision)

# Mozrog/Dakkarig/Squigosaur: no invented Leader or Da Boss metadata.
fun test_orks17p1_monster_and_mek_metadata() -> Bool:
    let mozrog = make_orks_mozrog_skragbad()
    let mek = make_orks_big_mek_dakkarig()
    let squigo = make_orks_beastboss_on_squigosaur(true)
    return mozrog.has_keyword(Keyword::epic_hero) and !mozrog.has_keyword(Keyword::warboss) and !mozrog[0].has_da_boss and !mek[0].has_da_boss and mek.has_keyword(Keyword::big_mek) and squigo[0].has_da_boss and squigo[0].weapons.size() == 5 and squigo.attachment_role.value != AttachmentRole::leader.value

# Ammo Runts: own Shooting only; battle-shock does not forbid free use.
fun test_orks17p1_ammo_timing_and_owner() -> Bool:
    let board = orks17p1_fixture(make_orks_boyz(1, 9))
    board[0].battle_socked = true
    let own = orks_ammo_available(board, unit_id(0), false)
    board.current_player = true
    let opponent = !orks_ammo_available(board, unit_id(0), false)
    board.current_player = false
    board.begin_phase(BattlePhase::fight)
    return own and opponent and !orks_ammo_available(board, unit_id(0), false) and !orks_ammo_available(board, unit_id(1), false)

# Ammo Runts: decline preserves token and caller owner, commit spends once.
fun test_orks17p1_ammo_selection_and_limit() -> Bool:
    let board = orks17p1_fixture(make_orks_boyz(1, 9))
    board.current_decision_maker = true
    let choice = orks_datasheet_selection(board, unit_id(0))
    choice.use_ammo_runts(board, false)
    let kept = choice.is_done() and board.current_decision_maker == true and orks_ammo_available(board, unit_id(0), false)
    let accepted = orks_datasheet_selection(board, unit_id(0))
    accepted.use_ammo_runts(board, true)
    return kept and accepted.is_done() and board.current_decision_maker == true and !orks_ammo_available(board, unit_id(0), false) and unit_rule_effect(board, board[0], RuleEffectKind::ammo_runts_hit) == 1 and valid_state_foundations(board)

# Ammo Runts: every member's ranged attack benefits; melee never does.
fun test_orks17p1_ammo_ranged_scope() -> Bool:
    let board = orks17p1_fixture(make_orks_nobz(5))
    commit_orks_ammo(board, unit_id(0), false)
    let ranged = make_declared_weapon(board, unit_id(0), 4, 1)
    let gun = declared_attack_info(board, unit_id(0), unit_id(1), ranged, board.attack_info)
    let melee = make_declared_weapon(board, unit_id(0), 4, 0)
    let chop = declared_attack_info(board, unit_id(0), unit_id(1), melee, board.attack_info)
    return gun.total_hit_modifier() == 1 and chop.total_hit_modifier() == 0 and attack_hit_choices(board, gun).size() == 1

# Boss Ammo Runt: bearer-only when attached, separate token from Boyz Ammo.
fun test_orks17p1_attached_ammo_tokens_and_scope() -> Bool:
    let board : Board
    board.reserve_units.append(make_orks_boyz(1, 9))
    board.reserve_units.append(make_orks_warboss())
    board.identify_units()
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    attachment17g_battlefield(board)
    board.begin_phase(BattlePhase::shooting)
    configure_attack_info(board, 0, 0, false, false)
    commit_orks_ammo(board, unit_id(0), false)
    commit_orks_ammo(board, unit_id(0), true)
    return unit_rule_effect(board, board[0], RuleEffectKind::ammo_runts_hit) == 1 and model_rule_effect(board, board[0][10], RuleEffectKind::boss_ammo_hit) == 1 and model_rule_effect(board, board[0][1], RuleEffectKind::boss_ammo_hit) == 0 and !orks_ammo_available(board, unit_id(0), true) and valid_state_foundations(board)

# Ammo Runts: phase effect expires while battle usage remains spent.
fun test_orks17p1_ammo_expiry_not_refresh() -> Bool:
    let board = orks17p1_fixture(make_orks_nobz(5))
    commit_orks_ammo(board, unit_id(0), false)
    board.begin_phase(BattlePhase::charge)
    let expired = unit_rule_effect(board, board[0], RuleEffectKind::ammo_runts_hit) == 0
    board.begin_phase(BattlePhase::shooting)
    return expired and !orks_ammo_available(board, unit_id(0), false)

# Boyz/Tide of Muscle: charged melee gains Lethal even versus Monster.
fun test_orks17p1_tide_charge_and_profile_scope() -> Bool:
    let board = orks17p1_fixture(make_orks_boyz(1, 9))
    let before = make_declared_weapon(board, unit_id(0), 1, 0)
    board[0].has_charged = true
    board[1][0].keywords.append(Keyword::monster)
    let melee = make_declared_weapon(board, unit_id(0), 1, 0)
    let ranged = make_declared_weapon(board, unit_id(0), 1, 2)
    return !declared_weapon_has_kind(before, WeaponRuleKind::letal_hits) and chosen_weapon_has_rule(board, unit_id(1), melee.selected_rules, WeaponRuleKind::letal_hits) and !chosen_weapon_has_rule(board, unit_id(1), ranged.selected_rules, WeaponRuleKind::letal_hits)

# Boyz/Never Too Busy: engagement alone waived; shock remains forbidden.
fun test_orks17p1_boy_action_engagement_waiver() -> Bool:
    let board = orks17p1_fixture(make_orks_boyz(1, 9))
    board[1][0].position = board_position(6, 5)
    let allowed = board.is_in_melee(board[0]) and action_start_valid(board, unit_id(0), false)
    board[0].battle_socked = true
    return allowed and !action_start_valid(board, unit_id(0), false)

# Nobz/Paired Krumpas: only the bearer's Kustom Krumpa receives both rerolls.
fun test_orks17p1_paired_krumpas_bearer_and_weapon() -> Bool:
    let equipment = orks17p1_nob_equipment(5)
    equipment[0] = Weapon::orks_paired_krumpas
    let board = orks17p1_fixture(make_orks_nobz(equipment))
    let paired = make_declared_weapon(board, unit_id(0), 0, 0)
    let ordinary = make_declared_weapon(board, unit_id(0), 1, 0)
    let yes = declared_attack_info(board, unit_id(0), unit_id(1), paired, board.attack_info)
    let no = declared_attack_info(board, unit_id(0), unit_id(1), ordinary, board.attack_info)
    return yes.reroll_hits and yes.reroll_wounds and !no.reroll_hits and !no.reroll_wounds

# Warboss/Might Is Right: charge buffs only own melee+3A/+2S.
fun test_orks17p1_warboss_charge_statistics() -> Bool:
    let board = orks17p1_fixture(make_orks_warboss())
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let before = declaration_fixed_attacks(board, unit_id(0), declaration, 0)
    board[0].has_charged = true
    let info = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    let gun = make_declared_weapon(board, unit_id(0), 0, 1)
    return before == 6 and declaration_fixed_attacks(board, unit_id(0), declaration, 0) == 9 and info.attack_strength() == 9 and declaration_fixed_attacks(board, unit_id(0), gun, 0) == 4

# Bigboss/Sumfin’: melee only, conferring source needed, corpse retention p67.
fun test_orks17p1_bigboss_hit_source_loss() -> Bool:
    let board = orks17p1_fixture(make_orks_bigboss())
    let melee = make_declared_weapon(board, unit_id(0), 0, 1)
    let gun = make_declared_weapon(board, unit_id(0), 0, 0)
    let yes = declared_attack_info(board, unit_id(0), unit_id(1), melee, board.attack_info)
    let no = declared_attack_info(board, unit_id(0), unit_id(1), gun, board.attack_info)
    board[0][0].state = ModelState::pending_destruction
    return yes.total_hit_modifier() == 1 and no.total_hit_modifier() == 0 and !board[0].has_ability(AbilityKind::sumfin_to_prove)

# Bannernob: addition precedes division/rounding, twelve/Into the Fray caps.
fun test_orks17p1_banner_order_and_caps() -> Bool:
    let unit = make_orks_bannernob()
    unit.phase_modifiers.charge_roll.append(rule_modifier(ModifierOperation::divide, 2))
    let rounded = charge_distance(unit, 4, ChargeKind::ordinary, false) == 3
    unit.phase_modifiers.charge_roll.clear()
    return rounded and charge_distance(unit, 12, ChargeKind::ordinary, false) == 12 and charge_distance(unit, 6, ChargeKind::into_the_fray, false) == 6

# Appendix02.02.02: every offered contribution can be kept, including all34.
fun test_orks17p1_modifier_full_capacity_and_origin() -> Bool:
    let board = orks17p1_fixture(make_orks_bigboss())
    let choices : AttackModifierChoices
    for index in range(34):
        choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, 1), ModifierOrigin::faction_datasheet))
    let sequence = choose_attack_modifiers(board, choices, false, ModifierSelectionKind::hit_roll, true)
    for index in range(34):
        sequence.apply_attack_modifier(board, true)
    return sequence.is_done() and sequence.result.size() == 34 and selected_hit_bonus(sequence.result) == 1

# Stormboyz/Rokkit Charge: optional pre-declaration+1A/S/Hazardous and expiry.
fun test_orks17p1_rokkit_selection_and_hazardous() -> Bool:
    let board = orks17p1_fixture(make_orks_stormboyz(4, false))
    board.begin_phase(BattlePhase::fight)
    board[0].has_charged = true
    let choice = orks_rokkit_selection(board, unit_id(0))
    choice.use_rokkit_charge(board, true)
    let melee = make_declared_weapon(board, unit_id(0), 1, 1)
    let info = declared_attack_info(board, unit_id(0), unit_id(1), melee, board.attack_info)
    let yes = choice.is_done() and declaration_fixed_attacks(board, unit_id(0), melee, 0) == 4 and info.attack_strength() == 6 and declared_weapon_has_kind(melee, WeaponRuleKind::hazardous)
    board.begin_phase(BattlePhase::shooting)
    return yes and unit_rule_effect(board, board[0], RuleEffectKind::rokkit_charge) == 0

# Stormboyz: declining and a non-charging fight grant nothing.
fun test_orks17p1_rokkit_decline_and_no_charge() -> Bool:
    let board = orks17p1_fixture(make_orks_stormboyz(4, true))
    board.begin_phase(BattlePhase::fight)
    let absent = orks_rokkit_selection(board, unit_id(0))
    board[0].has_charged = true
    let choice = orks_rokkit_selection(board, unit_id(0))
    choice.use_rokkit_charge(board, false)
    return absent.is_done() and choice.is_done() and unit_rule_effect(board, board[0], RuleEffectKind::rokkit_charge) == 0

# Warbikers/High Speed Carnage: charge+1S/D melee, not gun/uncharged.
fun test_orks17p1_biker_charge_melee_damage() -> Bool:
    let board = orks17p1_fixture(make_orks_warbikers(2))
    board[0].has_charged = true
    let melee = make_declared_weapon(board, unit_id(0), 1, 1)
    let gun = make_declared_weapon(board, unit_id(0), 1, 0)
    let chop = declared_attack_info(board, unit_id(0), unit_id(1), melee, board.attack_info)
    let ranged = declared_attack_info(board, unit_id(0), unit_id(1), gun, board.attack_info)
    return chop.attack_strength() == 6 and modified_characteristic(1, ModifiedCharacteristic::damage, chop.damage_modifiers, false) == 2 and ranged.attack_strength() == gun.weapon.strenght() and ranged.damage_modifiers.size() == 0

# Nobz/Get Out da Way: only Charge traverses enemy Infantry, not Monster/Vehicle.
fun test_orks17p1_nob_charge_traversal() -> Bool:
    let board = orks17p1_fixture(make_orks_nobz(5))
    board[0].models.resize(1)
    board[1][0].position = board_position(7, 5)
    let path : ModelPath
    let infantry = charge_waypoint_valid(board, board[0], path, board_position(9, 5), 6, false)
    board[1][0].keywords.append(Keyword::vehicle)
    let vehicle = !charge_waypoint_valid(board, board[0], path, board_position(9, 5), 6, false)
    board[0][0].keywords.append(Keyword::fly)
    return infantry and vehicle and charge_waypoint_valid(board, board[0], path, board_position(9, 5), 6, true)

# Killa-Kans/Spiteful Power Trip: every live target model's T matters.
fun test_orks17p1_kans_mixed_toughness_and_dead_model() -> Bool:
    let board = orks17p1_fixture(make_orks_killa_kans(3))
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    let ordinary = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    let high = make_orks_beastboss_on_squigosaur(false)
    board[1].models.append(high[0])
    board.identify_units()
    let mixed = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    board[1][1].state = ModelState::pending_destruction
    let dead = declared_attack_info(board, unit_id(0), unit_id(1), declaration, board.attack_info)
    return ordinary.total_hit_modifier() == 1 and mixed.total_hit_modifier() == 0 and dead.total_hit_modifier() == 1

# Dakkarig/Blitz Dem Gitz: declared non-Monster/Vehicle only, own Shooting.
fun test_orks17p1_blitz_target_and_gathering() -> Bool:
    let board = orks17p1_fixture(make_orks_big_mek_dakkarig())
    let declaration = make_declared_weapon(board, unit_id(0), 0, 0)
    declaration.targeted[1] = true
    let gathered = gather_weapon_count(board, unit_id(0), unit_id(1), declaration, false)
    let extra = gathered.is_done() and gathered.result == 14
    board[1][0].keywords.append(Keyword::vehicle)
    let vehicle = gather_weapon_count(board, unit_id(0), unit_id(1), declaration, false)
    board[1][0].keywords.clear()
    board.current_player = true
    let other_turn = gather_weapon_count(board, unit_id(0), unit_id(1), declaration, false)
    return extra and vehicle.result == 8 and other_turn.result == 8

# Dakkarig/Even More Dakka: riled ranged Sustained1, no melee grant.
fun test_orks17p1_dakkarig_riled_profile_scope() -> Bool:
    let board = orks17p1_fixture(make_orks_big_mek_dakkarig())
    let before = make_declared_weapon(board, unit_id(0), 0, 0)
    orks17f_intrinsic_riled(board[0][0])
    let gun = make_declared_weapon(board, unit_id(0), 0, 0)
    let feet = make_declared_weapon(board, unit_id(0), 0, 2)
    return !declared_weapon_has_kind(before, WeaponRuleKind::sustained_hit) and declared_weapon_has_kind(gun, WeaponRuleKind::sustained_hit) and !declared_weapon_has_kind(feet, WeaponRuleKind::sustained_hit)

# Squigosaur/Mozrog: Hunter target restrictions and D6+1 intrinsic expression.
fun test_orks17p1_monster_hunters_and_random_damage() -> Bool:
    let board = orks17p1_fixture(make_orks_mozrog_skragbad())
    let declaration = make_declared_weapon(board, unit_id(0), 0, 3)
    board[1][0].position = board_position(7, 5)
    let ordinary = !declaration_target_valid(board, unit_id(0), declaration, unit_id(1), true)
    board[1][0].keywords.append(Keyword::monster)
    let allowed = declaration_target_valid(board, unit_id(0), declaration, unit_id(1), true)
    return ordinary and allowed and stat_dice_count(declaration.weapon.damage()) == 1 and stat_dice_sides(declaration.weapon.damage()) == 6 and stat_intrinsic_constant(declaration.weapon.damage()) == 1

# Stampede aura: self qualifies, identical auras never stack; enemy/offboard don't.
fun test_orks17p1_stampede_aura_sources() -> Bool:
    let board = orks17p1_fixture(make_orks_beastboss_on_squigosaur(false))
    let other = make_orks_beastboss_on_squigosaur(false)
    other[0].position = board_position(8, 5)
    board.units.append(other)
    board.identify_units()
    let own = orks_stampede_charge_bonus(board, board[0]) == 1 and charge_distance(board, board[0], 5, ChargeKind::ordinary, false) == 6
    board[0].off_battlefield = true
    return own and orks_stampede_charge_bonus(board, board[0]) == 0

# Conditional Lone Operative: nearby Snagga, excluding MONSTER CHARACTER union.
fun test_orks17p1_snagga_following_live_and_distance() -> Bool:
    let board = orks17p1_fixture(make_orks_mozrog_skragbad())
    let before = !orks_lone_operative(board, board[0])
    let snagga = make_orks_beast_snagga_boyz(1, 9, 0)
    snagga.models.resize(1)
    snagga[0].position = board_position(8, 5)
    board.units.append(snagga)
    board.identify_units()
    let near = orks_lone_operative(board, board[0])
    board[2][0].position = board_position(12, 5)
    let far = !orks_lone_operative(board, board[0])
    board[2][0].position = board_position(8, 5)
    board[2].off_battlefield = true
    return before and near and far and !orks_lone_operative(board, board[0])

# Mozrog/Da Bigger Dey Iz: unit-wide melee wound rerolls only vs Mon/Vehicle.
fun test_orks17p1_mozrog_wound_rerolls_scope() -> Bool:
    let board = orks17p1_fixture(make_orks_mozrog_skragbad())
    let melee = make_declared_weapon(board, unit_id(0), 0, 2)
    let before = declared_attack_info(board, unit_id(0), unit_id(1), melee, board.attack_info)
    board[1][0].keywords.append(Keyword::vehicle)
    let yes = declared_attack_info(board, unit_id(0), unit_id(1), melee, board.attack_info)
    let ranged = make_declared_weapon(board, unit_id(0), 0, 0)
    let no = declared_attack_info(board, unit_id(0), unit_id(1), ranged, board.attack_info)
    return !before.reroll_wounds and yes.reroll_wounds and !no.reroll_wounds

# Mozrog/One Last Kill: printed2+ in Fight before its unit has fought.
fun test_orks17p1_mozrog_death_timing_threshold() -> Bool:
    let board = orks17p1_fixture(make_orks_mozrog_skragbad())
    let shooting = orks_fight_death_threshold(board, board[0], board[0][0]) == 0
    board.begin_phase(BattlePhase::fight)
    let fight = orks_fight_death_threshold(board, board[0], board[0][0]) == 2
    board[0].has_fought = true
    return shooting and fight and orks_fight_death_threshold(board, board[0], board[0][0]) == 0

# All twelve adapters survive actual Game serialization with physical groups.
fun test_orks17p1_all_unit_saved_round_trip() -> Bool:
    let state = play()
    state.board.reserve_units.append(make_orks_boyz(1, 9))
    state.board.reserve_units.append(make_orks_nobz(5))
    state.board.reserve_units.append(make_orks_warboss())
    state.board.reserve_units.append(make_orks_bigboss())
    state.board.reserve_units.append(make_orks_bannernob())
    state.board.reserve_units.append(make_orks_stormboyz(4, true))
    state.board.reserve_units.append(make_orks_warbikers(2))
    state.board.reserve_units.append(make_orks_deff_dread())
    state.board.reserve_units.append(make_orks_killa_kans(3))
    state.board.reserve_units.append(make_orks_big_mek_dakkarig())
    state.board.reserve_units.append(make_orks_beastboss_on_squigosaur(true))
    state.board.reserve_units.append(make_orks_mozrog_skragbad())
    state.board.identify_units()
    let restored = play()
    let saved = set_state(restored, to_string(state))
    return saved and restored.board.reserve_units.size() == 12 and weapon_primary_id(restored.board.reserve_units[6][0], 0) == weapon_primary_id(restored.board.reserve_units[6][0], 1) and restored.board.reserve_units[11][0].profile == Profile::orks_mozrog_skragbad and valid_state_foundations(restored.board)

# Mozrog: FNP is resolved first, then2+ at destruction; retained fighter has
# already passed its permission roll and does not roll that permission again.
fun test_orks17p1_mozrog_actual_death_success() -> Bool:
    let board = orks17p1_fixture(make_orks_mozrog_skragbad())
    board.begin_phase(BattlePhase::fight)
    board[0][0].suffered_wounds = 9
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(0), unit_id(1), true, true, 1, board[0][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(1))
    damage.roll(board, attack_test_die(1))
    damage.roll(board, attack_test_die(2))
    return damage.is_done() and board[0][0].state == ModelState::fight_on_death and board[0][0].destruction_fight_roll == 1 and board[0][0].destruction_pending

# Mozrog: saving the wound means no destroy-time permission roll.
fun test_orks17p1_mozrog_fnp_prevents_death() -> Bool:
    let board = orks17p1_fixture(make_orks_mozrog_skragbad())
    board.begin_phase(BattlePhase::fight)
    board[0][0].suffered_wounds = 9
    let jobs : DamageJobs
    jobs.append(damage_job(DamageKind::normal, unit_id(0), unit_id(1), true, true, 1, board[0][0].identity))
    let damage = resolve_damage_jobs(board, jobs, false, unit_id(1))
    damage.roll(board, attack_test_die(5))
    return damage.is_done() and board[0][0].is_alive() and !board[0][0].destruction_pending

# Actual Attack delegates the new decision before weapon declaration; refusing
# a free token restores source ownership and leaves ordinary weapon inputs.
fun test_orks17p1_attack_forwards_ammo_selection() -> Bool:
    let board = orks17p1_fixture(make_orks_warboss())
    board.current_decision_maker = true
    let sequence = attack(board, unit_id(0), unit_id(1), false, false)
    let offered = can sequence.use_boss_ammo_runt(board, true)
    sequence.use_boss_ammo_runt(board, false)
    return offered and !sequence.is_done() and orks_ammo_available(board, unit_id(0), true) and board.current_decision_maker == false

# Ammo effect and original battle usage survive the real save codec.
fun test_orks17p1_ammo_saved_provenance() -> Bool:
    let state = play()
    state.board = orks17p1_fixture(make_orks_nobz(5))
    commit_orks_ammo(state.board, unit_id(0), false)
    let restored = play()
    let saved = set_state(restored, to_string(state))
    return saved and unit_rule_effect(restored.board, restored.board[0], RuleEffectKind::ammo_runts_hit) == 1 and !orks_ammo_available(restored.board, unit_id(0), false) and valid_state_foundations(restored.board)


# Stormboyz: actual selected-fight frame offers the choice before FightKind.
fun test_orks17p1_selected_fight_forwards_rokkit() -> Bool:
    let board = orks17p1_fixture(make_orks_stormboyz(4, true))
    board.begin_phase(BattlePhase::fight)
    board[0].has_charged = true
    board[0].history.fight_eligible_phase = board.phase_serial.value + 1
    let sequence = selected_fight(board, unit_id(0))
    let offered = can sequence.use_rokkit_charge(board, true)
    sequence.use_rokkit_charge(board, true)
    return offered and !sequence.is_done() and unit_rule_effect(board, board[0], RuleEffectKind::rokkit_charge) == 1


# Fourteen current recovery, support and infantry fixtures. Sources are the card URLs on every
# profile and factory; explicit fixtures do not imply public roster coverage.

# https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_kaptin_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_kaptin, 6, 5, 4, 10, 3, 7, 1, 10) and Profile::orks_kaptin.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_flash_git_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_flash_git, 6, 5, 4, 10, 3, 7, 1, 10) and Profile::orks_flash_git.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_meganob_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_meganob, 5, 6, 2, 10, 3, 7, 1, 10) and Profile::orks_meganob.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Mek: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_mek_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_mek, 6, 5, 5, 10, 4, 7, 1, 10) and Profile::orks_mek.base_size() == 32.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_big_mek_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_big_mek, 6, 5, 3, 10, 6, 7, 1, 10) and Profile::orks_big_mek.base_size() == 50.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_big_mek_in_mega_armour_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_big_mek_in_mega_armour, 5, 6, 2, 10, 5, 7, 1, 10) and Profile::orks_big_mek_in_mega_armour.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_big_mek_with_shokk_attack_gun_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_big_mek_with_shokk_attack_gun, 6, 5, 4, 10, 5, 7, 1, 10) and Profile::orks_big_mek_with_shokk_attack_gun.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Painboy: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_painboy_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_painboy, 6, 5, 5, 10, 3, 7, 1, 10) and Profile::orks_painboy.base_size() == 32.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Painboss: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_painboss_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_painboss, 6, 5, 4, 6, 4, 7, 1, 10) and Profile::orks_painboss.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_breaka_boy_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_breaka_boy, 6, 5, 4, 10, 2, 7, 1, 10) and Profile::orks_breaka_boy.base_size() == 32.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_breaka_nob_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_breaka_nob, 6, 5, 4, 10, 3, 7, 1, 10) and Profile::orks_breaka_nob.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_tankbusta_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_tankbusta, 6, 5, 4, 10, 2, 7, 1, 10) and Profile::orks_tankbusta.base_size() == 32.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_tankbusta_nob_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_tankbusta_nob, 6, 5, 4, 10, 3, 7, 1, 10) and Profile::orks_tankbusta_nob.base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_warboss_in_mega_armour_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_warboss_in_mega_armour, 5, 7, 2, 5, 7, 6, 1, 10) and Profile::orks_warboss_in_mega_armour.base_size() == 50.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_gretchin_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_gretchin, 6, 2, 6, 10, 1, 8, 1, 10) and Profile::orks_gretchin.base_size() == 25.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_runtherd_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_runtherd, 6, 5, 5, 10, 3, 7, 1, 10) and Profile::orks_runtherd.base_size() == 32.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga: literal profile, InSv, absence of FNP and circular base.
fun test_orks17p2_zodgrod_wortsnagga_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_zodgrod_wortsnagga, 6, 5, 5, 6, 5, 7, 1, 10) and Profile::orks_zodgrod_wortsnagga.base_size() == 50.0

# Imported, already identified attachments must not collide with the separate
# enemy fixture's old IDs. Re-identify only that unrelated fresh component.
# Infrastructure for stable identity/attachment invariants (core pp66/86/88).
fun orks17p2_fixture(Unit source) -> Board:
    let board = orks17p1_fixture(source)
    board[1].identity = 0
    for member_index in range(board[1].models.size()):
        board[1][member_index].identity = 0
        board[1][member_index].original_unit = 0
    board.identify_units()
    board.capture_starting_strengths()
    assert(valid_state_foundations(board), "imported fixture identities must remain unique")
    return board

# Stable source lookup for the command/movement event fixtures, not game logic.
fun orks17p2_source(Board board, Int rule) -> SourceInstance:
    register_orks_datasheet_sources(board)
    let result : SourceInstance
    for index in range(board.source_instances.size()):
        if board.source_instances[index].rule.value == rule:
            result = board.source_instances[index]
    return result

# Snapshot an actual slot's current target-dependent attack characteristics.
fun orks17p2_info(Board board, Int slot) -> AttackSequenceInfo:
    let weapon = make_declared_weapon(board, unit_id(0), 0, slot)
    return declared_attack_info(board, unit_id(0), unit_id(1), weapon, board.attack_info)

# All fourteen constructors can be copied through an ordinary Game save.
# Sources: each card's Unit Composition; state identity/serialization pp86/88.
fun orks17p2_units() -> UnitVector:
    let units : UnitVector
    units.append(make_orks_flash_gitz(4))
    units.append(make_orks_meganobz(2))
    units.append(make_orks_mek())
    units.append(make_orks_big_mek(false, false))
    units.append(make_orks_big_mek_in_mega_armour(Weapon::orks_big_mek_in_mega_armour_kustom_shoota_aimed, Weapon::none))
    units.append(make_orks_big_mek_with_shokk_attack_gun())
    units.append(make_orks_painboy())
    units.append(make_orks_painboss())
    units.append(make_orks_breaka_boyz(false, 5, 5))
    units.append(make_orks_tankbustas(false, Weapon::none, 0))
    units.append(make_orks_warboss_in_mega_armour())
    units.append(make_orks_gretchin(10))
    units.append(make_orks_runtherd())
    units.append(make_orks_zodgrod_wortsnagga())
    return units

fun test_orks17p2_all_factories_round_trip() -> Bool:
    let game = play()
    game.board.reserve_units = orks17p2_units()
    game.board.identify_units()
    game.board.capture_starting_strengths()
    register_orks_passive_rules(game.board)
    register_orks_datasheet_sources(game.board)
    refresh_source_effects(game.board, TimingWindow::none)
    let restored = play()
    return set_state(restored, to_string(game)) and restored.board.reserve_units.size() == 14 and valid_state_foundations(restored.board)

# Literal counts include intermediate sizes, not just priced5/10 tiers.
# https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
fun test_orks17p2_flash_gitz_counts_and_physical_guns() -> Bool:
    let unit = make_orks_flash_gitz(5)
    let valid = unit.models.size() == 6 and unit[0].profile == Profile::orks_kaptin and unit[1].profile == Profile::orks_flash_git and make_orks_flash_gitz(9).models.size() == 10
    return valid and unit[0].weapons.size() == 4 and weapon_primary_id(unit[0], 0) == 1 and weapon_primary_id(unit[0], 1) == 1 and weapon_primary_id(unit[0], 2) == 1

# Combined replacement removes BOTH original weapons; all five choices coexist.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
fun test_orks17p2_meganob_mixed_replacements() -> Bool:
    let equipment : OrksMeganobLoadouts
    let choice = orks_meganob_loadout_choice(0)
    for index in range(5):
        choice = orks_meganob_loadout_choice(index)
        equipment.append(choice)
    let unit = make_orks_meganobz(equipment)
    return unit.models.size() == 5 and unit[0].weapons.size() == 3 and unit[1].weapons[0].profile.value == Weapon::orks_meganobz_killsaw.value and unit[2].weapons.size() == 4 and unit[3].weapons[0].profile.value == Weapon::orks_meganobz_killsaw.value and unit[4].weapons.size() == 1 and unit[4].weapons[0].profile.has_rule(WeaponRuleKind::twin_linked)

fun test_orks17p2_meganob_composition_and_invalid_enum() -> Bool:
    let equipment : OrksMeganobLoadouts
    let equipment_previous_1 = equipment.size()
    equipment.resize(1)
    for equipment_default_1 in range(1):
        if equipment_default_1 >= equipment_previous_1:
            equipment[equipment_default_1] = orks_meganob_loadout_choice(0)
    let invalid = !orks_meganob_loadout_valid(equipment)
    let equipment_previous_2 = equipment.size()
    equipment.resize(6)
    for equipment_default_2 in range(6):
        if equipment_default_2 >= equipment_previous_2:
            equipment[equipment_default_2] = orks_meganob_loadout_choice(0)
    let valid = orks_meganob_loadout_valid(equipment)
    equipment[0].gun = Weapon::none
    return invalid and valid and !orks_meganob_loadout_valid(equipment) and make_orks_meganobz(2).models.size() == 2

# Independent Big Mek weapon swaps and all twelve Mega Mek choices.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
fun test_orks17p2_mega_mek_all_equipment() -> Bool:
    let gun = orks_mega_mek_gun_choice(0)
    let extra = orks_mega_mek_extra_choice(0)
    let valid = true
    for gun_index in range(4):
        gun = orks_mega_mek_gun_choice(gun_index)
        for extra_index in range(3):
            extra = orks_mega_mek_extra_choice(extra_index)
            let unit = make_orks_big_mek_in_mega_armour(gun, extra)
            let expected_slots = 2
            if gun_index == 0:
                expected_slots = 3
            if gun_index == 2:
                expected_slots = 4
            valid = valid and unit[0].weapons.size() == expected_slots + int(extra_index != 0) and unit.has_ability(AbilityKind::kustom_force_field) == (extra_index == 2) and unit[0].transport_space == 2
    return valid

fun test_orks17p2_big_mek_independent_swaps() -> Bool:
    let standard = make_orks_big_mek(false, false)
    let changed = make_orks_big_mek(true, true)
    return standard[0].weapons[0].profile.value == Weapon::orks_big_mek_power_klaw.value and standard[0].weapons[1].profile.value == Weapon::orks_big_mek_kustom_mega_blasta.value and changed[0].weapons[0].profile.value == Weapon::orks_big_mek_drilla.value and changed[0].weapons[1].profile.has_rule(WeaponRuleKind::anti)

# Two distinct Boy swaps are legal; neither can consume the same Boy.
# Nob's replacement means two pistols, never two Hammer profiles as well.
# https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
fun test_orks17p2_breaka_full_replacements() -> Bool:
    let unit = make_orks_breaka_boyz(true, 0, 1)
    return unit.models.size() == 6 and unit[0].weapons.size() == 3 and unit[0].weapons[1].profile.value == unit[0].weapons[2].profile.value and unit[1].weapons.size() == 1 and unit[1].weapons[0].profile.value == Weapon::orks_breaka_boyz_knucklebustas.value and unit[2].weapons[0].profile.has_rule(WeaponRuleKind::hazardous) and unit[3].hunter_profile_conditions[1].target_condition.size() > 0 and !orks_breaka_loadout_valid(1, 1) and !orks_breaka_loadout_valid(-1, 5) and !orks_breaka_loadout_valid(5, 6)

# Nob keeps one pistol when replacing the other; the extra launcher is a
# second physical family with independently chosen Standard/Hunter profile.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun test_orks17p2_tankbusta_physical_counts() -> Bool:
    let standard = make_orks_tankbustas(false, Weapon::none, 0)
    let changed = make_orks_tankbustas(true, Weapon::orks_tankbustas_busta_rokkit_launcha_standard, 2)
    let pulsa = make_orks_tankbustas(false, Weapon::orks_pulsa_rokkit, 4)
    return standard[0].weapons.size() == 3 and standard[0].weapons[1].profile.value == standard[0].weapons[2].profile.value and changed[0].weapons.size() == 4 and changed[3].weapons.size() == 5 and weapon_primary_id(changed[3], 1) != weapon_primary_id(changed[3], 3) and pulsa[5].has_ability(AbilityKind::pulsa_rokkit) and !pulsa[1].has_ability(AbilityKind::pulsa_rokkit) and pulsa[5].weapons.size() == 4

# More Dakka's riled grant differs from plain Mek Kustom Dakka.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Mek,Big-Mek}
fun test_orks17p2_more_dakka_and_mek_scope() -> Bool:
    let board = orks17p2_fixture(make_orks_big_mek(false, false))
    let plain = model_weapon_rules(board, unit_id(0), 0, 1)
    orks17f_intrinsic_riled(board[0][0])
    let riled = model_weapon_rules(board, unit_id(0), 0, 1)
    let melee = model_weapon_rules(board, unit_id(0), 0, 0)
    board[0] = make_orks_mek()
    orks17f_intrinsic_riled(board[0][0])
    let mek = model_weapon_rules(board, unit_id(0), 0, 0)
    return chosen_weapon_has_rule(board, unit_id(1), plain, WeaponRuleKind::ignore_cover) and !chosen_weapon_has_rule(board, unit_id(1), plain, WeaponRuleKind::sustained_hit) and chosen_weapon_has_rule(board, unit_id(1), riled, WeaponRuleKind::sustained_hit) and !chosen_weapon_has_rule(board, unit_id(1), melee, WeaponRuleKind::ignore_cover) and chosen_weapon_has_rule(board, unit_id(1), mek, WeaponRuleKind::ignore_cover) and !chosen_weapon_has_rule(board, unit_id(1), mek, WeaponRuleKind::sustained_hit)

# Flash Gitz's OR condition is live and only applies in own Shooting.
# https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
fun test_orks17p2_finderz_objective_or_and_phase() -> Bool:
    let board = orks17p2_fixture(make_orks_flash_gitz(4))
    for index in range(4):
        board.set_objective_position(index, board_position(35, 25))
    let none = orks17p2_info(board, 1).attack_penetration() == -1
    board.set_objective_position(0, board[0][0].position)
    let source = orks17p2_info(board, 1).attack_penetration() == -2
    board.set_objective_position(0, board[1][0].position)
    let target = orks17p2_info(board, 1).attack_penetration() == -2
    board.current_player = true
    return none and source and target and orks17p2_info(board, 1).attack_penetration() == -1

# Unit incoming AP worsening also protects an attached Character; its
# separate riled hit bonus is Fight-only (not a permanent profile change).
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
fun test_orks17p2_meganob_defence_and_riled_fight() -> Bool:
    let board = orks17p2_fixture(make_orks_meganobz(2))
    board[1] = make_orks_meganobz(2)
    board.identify_units()
    let incoming = orks17p2_info(board, 0).attack_penetration() == -1
    let ordinary = orks17p2_info(board, 0).total_hit_modifier() == 0
    orks17f_intrinsic_riled(board[0][0])
    board.begin_phase(BattlePhase::fight)
    return incoming and ordinary and orks17p2_info(board, 0).total_hit_modifier() == 1

# Kustom Force Field is unit-wide only for ranged saves, and only equipped.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
fun test_orks17p2_force_field_ranged_only() -> Bool:
    let board = orks17p2_fixture(make_orks_big_mek_in_mega_armour(Weapon::orks_big_mek_in_mega_armour_kustom_shoota_aimed, Weapon::orks_kustom_force_field))
    let info : AttackSequenceInfo
    info.source = Weapon::captain_storm_bolter
    let ranged = make_allocation_groups(board, board[0], info)
    info.source = Weapon::relic_weapon
    let melee = make_allocation_groups(board, board[0], info)
    board[0][0].abilities.clear()
    info.source = Weapon::captain_storm_bolter
    let without = make_allocation_groups(board, board[0], info)
    return ranged[0].invulnerable == 4 and melee[0].invulnerable == 10 and without[0].invulnerable == 10

# Stronger incoming S uses the effective target T; equality is not enough.
# https://wahapedia.ru/wh40k11ed/factions/orks/Painboss
fun test_orks17p2_hardy_bioniks_threshold() -> Bool:
    let board = orks17p2_fixture(make_orks_big_mek(false, false))
    board[1] = make_orks_painboss()
    board.identify_units()
    let strong = orks17p2_info(board, 0)
    let penalty = required_wound_roll(board, strong)
    board[1][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::toughness, ModifierOperation::add, 5))
    let equal = orks17p2_info(board, 0)
    return strong.greater_strenght_wound_protection and penalty == 3 and required_wound_roll(board, equal) == 4

# Actual printed attachment permission, independent of the public roster.
fun orks17p2_attached(Unit bodyguard, Unit character) -> Unit:
    let board : Board
    board.reserve_units.append(bodyguard)
    board.reserve_units.append(character)
    board.identify_units()
    assert(attachment_valid(board, unit_id(1), unit_id(0), false), "source card attachment fixture must be legal")
    attach_reserved_unit(board, unit_id(1), unit_id(0), false)
    let unit = board.reserve_units[0]
    mark_unit_offboard(unit, false)
    return unit

# Mounted Painboss changes ONLY its own type/M; Hardy Bioniks remains unit-wide.
# https://wahapedia.ru/wh40k11ed/factions/orks/Painboss
fun test_orks17p2_painboss_actual_mounted_attachment() -> Bool:
    let unit = orks17p2_attached(make_orks_squighog_boyz(1, 3), make_orks_painboss())
    let bearer = unit.models.size() - 1
    return !unit[bearer].has_keyword(Keyword::infantry) and unit[bearer].has_keyword(Keyword::mounted) and unit[bearer].has_keyword(Keyword::mobile) and unit[bearer].effective_movement(6) == 10 and unit[0].profile.movement() == 10 and unit.has_ability(AbilityKind::hardy_bioniks)

# Source-wide field protection includes the actual attached Meganob bodyguard.
fun test_orks17p2_force_field_actual_bodyguard() -> Bool:
    let unit = orks17p2_attached(make_orks_meganobz(2), make_orks_big_mek_in_mega_armour(Weapon::orks_big_mek_in_mega_armour_kustom_shoota_aimed, Weapon::orks_kustom_force_field))
    let board = orks17p2_fixture(unit)
    let info : AttackSequenceInfo
    info.source = Weapon::captain_storm_bolter
    let groups = make_allocation_groups(board, board[0], info)
    return groups.size() == 2 and groups[0].invulnerable == 4 and groups[1].invulnerable == 4

# No own-unit, enemy-unit, other-SAG-unit or offboard proximity shortcut.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun
fun test_orks17p2_support_shokka_eligibility() -> Bool:
    let board = orks17p2_fixture(make_orks_big_mek_with_shokk_attack_gun())
    let enemy = !orks_shokka_supported(board, board[0])
    board[1].owned_by_player1 = false
    board[1][0].keywords.append(Keyword::orks)
    let friendly = orks_shokka_supported(board, board[0])
    set_model_datasheet(board[1][0], OrksDatasheet::big_mek_with_shokk_attack_gun)
    let excluded = !orks_shokka_supported(board, board[0])
    set_model_datasheet(board[1][0], OrksDatasheet::boyz)
    board[1].off_battlefield = true
    return enemy and friendly and excluded and !orks_shokka_supported(board, board[0])

# A healed vehicle model's bonus is not copied to another model in its unit.
# https://wahapedia.ru/wh40k11ed/factions/orks/Mek
fun test_orks17p2_mek_repair_model_scope() -> Bool:
    let board = orks17p2_fixture(make_orks_mek())
    board[1] = make_orks_killa_kans(3)
    board[1].owned_by_player1 = false
    board[1][0].position = board_position(8, 5)
    board[1][1].position = board_position(10, 5)
    board[1][0].suffered_wounds = 4
    board.identify_units()
    board.begin_phase(BattlePhase::movement)
    let instance = orks17p2_source(board, ORKS_MEK_REPAIR_RULE)
    let sequence = repair_orks_vehicle(board, instance)
    sequence.choose_mek_repair_unit(board, unit_id(1))
    sequence.choose_mek_repair_model(board, damage_test_model(0))
    sequence.quantity(board, attack_test_die(3))
    return sequence.is_done() and board[1][0].suffered_wounds == 1 and model_rule_effect(board, board[1][0], RuleEffectKind::clever_hit) == 1 and model_rule_effect(board, board[1][1], RuleEffectKind::clever_hit) == 0

fun test_orks17p2_mek_target_exclusions_and_bearer_range() -> Bool:
    let board = orks17p2_fixture(make_orks_mek())
    board[1] = make_orks_killa_kans(3)
    board[1].owned_by_player1 = false
    board[1][0].position = board_position(8, 5)
    board[1][1].position = board_position(20, 5)
    board.identify_units()
    let instance = orks17p2_source(board, ORKS_MEK_REPAIR_RULE)
    let valid = orks_mek_target_valid(board, instance, unit_id(1), damage_test_model(0)) and !orks_mek_target_valid(board, instance, unit_id(1), damage_test_model(1))
    board[1][0].keywords.append(Keyword::aircraft)
    let aircraft = !orks_mek_target_valid(board, instance, unit_id(1), damage_test_model(0))
    board[1][0].keywords.erase(board[1][0].keywords.size() - 1)
    board[1][0].keywords.append(Keyword::titanic)
    return valid and aircraft and !orks_mek_target_valid(board, instance, unit_id(1), damage_test_model(0))

# Mek's bonus survives next Command and expires BEFORE next Movement inputs.
# Source: Mek Clever Know-wotz; persisting effects01.02.02.
fun test_orks17p2_mek_bonus_precise_expiry() -> Bool:
    let board = orks17p2_fixture(make_orks_mek())
    board[1] = make_orks_killa_kans(3)
    board[1].owned_by_player1 = false
    board[1][0].position = board_position(8, 5)
    board.identify_units()
    board.begin_phase(BattlePhase::movement)
    let instance = orks17p2_source(board, ORKS_MEK_REPAIR_RULE)
    let repair = repair_orks_vehicle(board, instance)
    repair.choose_mek_repair_unit(board, unit_id(1))
    repair.choose_mek_repair_model(board, damage_test_model(0))
    repair.quantity(board, attack_test_die(1))
    board.turn_serial = board.turn_serial + 2
    board.begin_phase(BattlePhase::command)
    let during_command = model_rule_effect(board, board[1][0], RuleEffectKind::clever_hit) == 1
    board.begin_phase(BattlePhase::movement)
    return during_command and model_rule_effect(board, board[1][0], RuleEffectKind::clever_hit) == 0

# Distinct repairs remain distinct modifiers before caps/optional ignoring.
# Source: Mek; supplied modifiers02.02.01 and ignoring02.02.02.
fun test_orks17p2_repair_contributions_and_full_choice_capacity() -> Bool:
    let board = orks17p2_fixture(make_orks_killa_kans(3))
    grant_orks_model_effect(board, unit_id(0), damage_test_model(0), ORKS_MEK_REPAIR_RULE, RuleEffectKind::clever_hit)
    grant_orks_model_effect(board, unit_id(0), damage_test_model(0), ORKS_MEK_REPAIR_RULE + 10, RuleEffectKind::clever_hit)
    let info = orks17p2_info(board, 0)
    let independent = info.unit_hit_modifiers.size() == 3 and info.total_hit_modifier() == 3
    let choices : AttackModifierChoices
    for index in range(MAX_ATTACK_MODIFIER_CHOICES):
        choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, 1), ModifierOrigin::faction_datasheet))
    let sequence = choose_attack_modifiers(board, choices, false, ModifierSelectionKind::hit_roll, true)
    for index in range(MAX_ATTACK_MODIFIER_CHOICES):
        sequence.apply_attack_modifier(board, true)
    return independent and sequence.is_done() and sequence.result.size() == MAX_ATTACK_MODIFIER_CHOICES and selected_hit_bonus(sequence.result) == 1

# Ordinary model healing does not revive another model or spill to a neighbour.
# Big Mek repair: same source as above; appendix02.02.04.
fun test_orks17p2_repair_full_health_still_grants_bonus() -> Bool:
    let board = orks17p2_fixture(make_orks_mek())
    board[1] = make_orks_killa_kans(3)
    board[1].owned_by_player1 = false
    board[1][0].position = board_position(8, 5)
    board.identify_units()
    let instance = orks17p2_source(board, ORKS_MEK_REPAIR_RULE)
    let repair = repair_orks_vehicle(board, instance)
    repair.choose_mek_repair_unit(board, unit_id(1))
    repair.choose_mek_repair_model(board, damage_test_model(0))
    repair.quantity(board, attack_test_die(3))
    return repair.is_done() and board[1].models.size() == 3 and board[1][0].suffered_wounds == 0 and model_rule_effect(board, board[1][0], RuleEffectKind::clever_hit) == 1

# Mandatory Crude Surgery participates in the existing controller-order window;
# its optional Orderly token can be declined and retained for another Command.
# https://wahapedia.ru/wh40k11ed/factions/orks/Painboy
fun test_orks17p2_command_window_healing_and_decline_token() -> Bool:
    let board = orks17p2_fixture(make_orks_painboy())
    board[0][0].suffered_wounds = 2
    board.begin_phase(BattlePhase::command)
    let window = resolve_timing_window(board, TimingWindow::command_abilities)
    if can window.finish_timing_rules(board):
        return false
    let event : SourceEventID
    event = 0
    window.choose_window_source(board, event)
    window.use_grot_orderly(board, false)
    window.choose_healed_model(board, damage_test_model(0))
    window.choose_healed_model(board, damage_test_model(0))
    window.finish_timing_rules(board)
    let token = make_source_usage(board[0].owned_by_player1, ORKS_ORDERLY_RULE, board[0][0].original_unit, board[0][0].identity, SourceUseScope::unit, source_use_limits(0, 0, 0, 1))
    return window.is_done() and board[0][0].suffered_wounds == 0 and source_usage_available(board, token)

# Healing sum3+D3 is determined before allocation and can exceed the old3 cap.
# https://wahapedia.ru/wh40k11ed/factions/orks/Painboy
fun test_orks17p2_orderly_six_wounds_and_battle_token() -> Bool:
    let unit = orks17p2_attached(make_orks_nobz(5), make_orks_painboy())
    let board = orks17p2_fixture(unit)
    board[0][0].suffered_wounds = 2
    board[0][1].suffered_wounds = 2
    board[0][2].suffered_wounds = 2
    board.begin_phase(BattlePhase::command)
    let instance = orks17p2_source(board, ORKS_SURGERY_RULE)
    let sequence = orks_command_healing(board, instance)
    sequence.use_grot_orderly(board, true)
    sequence.quantity(board, attack_test_die(3))
    for index in range(3):
        sequence.choose_healed_model(board, damage_test_model(index))
        sequence.choose_healed_model(board, damage_test_model(index))
    let bearer = board[0].models.size() - 1
    let token = make_source_usage(board[0].owned_by_player1, ORKS_ORDERLY_RULE, board[0][bearer].original_unit, board[0][bearer].identity, SourceUseScope::unit, source_use_limits(0, 0, 0, 1))
    return sequence.is_done() and !source_usage_available(board, token) and board[0][0].suffered_wounds == 0 and board[0][1].suffered_wounds == 0 and board[0][2].suffered_wounds == 0

# The archive is a real original model and returns without stale death flags;
# one wound is spent returning it, followed by two wounds restoring its W.
# Unit-healing appendix02.02.04/01.02.03; Painboy source.
fun test_orks17p2_healing_archive_restores_original_model() -> Bool:
    let board = orks17p2_fixture(make_orks_nobz(5))
    let identity = board[0][4].identity
    board[0][4].used_once_per_battle_weapon[0] = true
    board[0].damage(4, 3)
    let count : FixedStat
    count = 3
    let healing = heal_unit(board, board[0], SourceBank::battlefield, count)
    healing.choose_healed_casualty(board, board[0], damage_test_model(0))
    healing.place_returned_model(board, board[0], board_position(5, 7))
    healing.choose_healed_model(board, board[0], damage_test_model(4))
    healing.choose_healed_model(board, board[0], damage_test_model(4))
    return healing.is_done() and board[0][4].identity == identity and board[0][4].suffered_wounds == 0 and board[0][4].used_once_per_battle_weapon[0] and !board[0][4].destruction_pending and board[0].destroyed_models.value.empty()

# No old battlefield coordinates or range measurements apply in reserves.
# Painboy Command self-healing works there via its own-unit ability01.02.04.
fun test_orks17p2_offboard_command_heals_own_unit() -> Bool:
    let board : Board
    board.reserve_units.append(make_orks_painboy())
    board.identify_units()
    mark_unit_offboard(board.reserve_units[0], true)
    board.reserve_units[0][0].suffered_wounds = 2
    board.begin_phase(BattlePhase::command)
    let instance = orks17p2_source(board, ORKS_SURGERY_RULE)
    let sequence = orks_command_healing(board, instance)
    sequence.use_grot_orderly(board, false)
    sequence.choose_healed_model(board, damage_test_model(0))
    sequence.choose_healed_model(board, damage_test_model(0))
    return sequence.is_done() and board.reserve_units[0][0].suffered_wounds == 0 and board.units.empty()

# Painboss can heal its own offboard unit but cannot measure to another bank.
# https://wahapedia.ru/wh40k11ed/factions/orks/Painboss; appendix01.02.04.
fun test_orks17p2_painboss_targets_banks_and_enemy() -> Bool:
    let board = orks17p2_fixture(make_orks_painboss())
    board[1] = make_orks_beast_snagga_boyz(1, 9, 0)
    board[1][0].position = board_position(9, 5)
    board[1].owned_by_player1 = false
    board.reserve_units.append(make_orks_painboss())
    board.identify_units()
    let instance = orks17p2_source(board, ORKS_PAINBOSS_RULE)
    let no_external = !orks_healing_target_valid(board, instance, SourceBank::battlefield, unit_id(0))
    let self = orks_healing_target_valid(board, instance, SourceBank::reserves, unit_id(0))
    return no_external and self and !orks_healing_target_valid(board, instance, SourceBank::battlefield, unit_id(1))

# Optional once-per-battle Fix Dat and Push Dat share limits by original unit.
fun test_orks17p2_healer_token_limits_and_registration_idempotence() -> Bool:
    let board = orks17p2_fixture(make_orks_big_mek_in_mega_armour(Weapon::orks_big_mek_in_mega_armour_kustom_shoota_aimed, Weapon::none))
    let instance = orks17p2_source(board, ORKS_ARMOUR_REPAIR_RULE)
    let count = board.source_instances.size()
    register_orks_datasheet_sources(board)
    let fresh = source_usage_available(board, instance)
    commit_source_usage(board, instance)
    board.phase_serial = board.phase_serial + 1
    return fresh and board.source_instances.size() == count and !source_usage_available(board, instance)

# Downtrodden rounds only source Gretchin, once for the whole passenger unit.
# https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
fun test_orks17p2_gretchin_grouped_rounding_and_characters() -> Bool:
    let ten = make_orks_gretchin(10)
    let eleven = make_orks_gretchin(11)
    let mixed = orks17p2_attached(eleven, make_orks_runtherd())
    return passenger_space(ten) == 5 and passenger_space(eleven) == 6 and passenger_space(make_orks_gretchin(20)) == 10 and passenger_space(mixed) == 7 and mixed.models.size() == 12

# Existing occupied seats and candidate units use the same grouped calculation.
# Transport core p64 and Gretchin Downtrodden; explicit generic carrier fixture.
fun test_orks17p2_gretchin_capacity_exact_and_overflow() -> Bool:
    let board : Board
    let carrier = make_orks_killa_kans(3)
    carrier.models.resize(1)
    carrier[0].keywords.append(Keyword::transport)
    carrier[0].transport_permissions_known = true
    carrier[0].transport_capacity = 5
    carrier[0].permitted_passenger_keywords.append(Keyword::infantry)
    board.units.append(carrier)
    board.identify_units()
    let ten = make_orks_gretchin(10)
    let eleven = make_orks_gretchin(11)
    return transport_can_carry(board, ten, board[0], 0) and !transport_can_carry(board, eleven, board[0], 0)

# Gretchin secure actual controlled objectives at own Movement end, retaining
# control after leaving; tied/uncontrolled markers do not become secured.
# https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
fun test_orks17p2_gretchin_secure_objective_and_leave() -> Bool:
    let board = orks17p2_fixture(make_orks_gretchin(10))
    board[1][0].position = board_position(35, 25)
    board.set_objective_position(0, board_position(5, 5))
    board.begin_phase(BattlePhase::movement)
    let instance = orks17p2_source(board, ORKS_SCAVENGERS_RULE)
    secure_orks_gretchin_objectives(board, instance)
    let secured = board.objectives[0].secured_by == ObjectiveController::army_0
    mark_unit_offboard(board[0], true)
    board.update_objective_control(true)
    return secured and board.get_objective_controller(0) == 0

# Source-bound Super Runts affects Scavenged Shivs, including improving WS by
# subtraction. Zodgrod's own weapons are unchanged; loss of the source removes it.
# https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga
fun test_orks17p2_zodgrod_shivs_and_source_lifetime() -> Bool:
    let unit = orks17p2_attached(make_orks_gretchin(10), make_orks_zodgrod_wortsnagga())
    let board = orks17p2_fixture(unit)
    register_orks_passive_rules(board)
    refresh_source_effects(board, TimingWindow::none)
    let shiv = orks17p2_info(board, 1)
    let riled = unit_is_riled_up(board[0])
    let improved = shiv.attack_strength() == 3 and effective_attack_skill(board, shiv) == 4
    let count = declaration_fixed_attacks(board, unit_id(0), make_declared_weapon(board, unit_id(0), 0, 1), 0)
    board[0].remove_model(10)
    refresh_source_effects(board, TimingWindow::none)
    let gone = orks17p2_info(board, 1)
    return riled and improved and count == 2 and gone.attack_strength() == 2 and !unit_is_riled_up(board[0])

# Four ACTUAL Gretchin are required; the support is not one of the four.
# Declining consumes no round usage and leaves shock unchanged.
# https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
fun test_orks17p2_runtherd_threshold_and_decline() -> Bool:
    let unit = orks17p2_attached(make_orks_gretchin(10), make_orks_runtherd())
    let board = orks17p2_fixture(unit)
    board[0].battle_socked = true
    let declined = orks_runtherd_shock(board, board[0])
    declined.use_runtherd(board, board[0], false)
    let preserved = declined.is_done() and board[0].battle_socked and board.source_uses.empty()
    while orks_live_gretchin(board[0]) > 3:
        board[0].remove_model(0)
    let no_fourth = orks_runtherd_shock(board, board[0])
    return preserved and no_fourth.is_done() and board[0].models.size() == 4

# Direct destruction bypasses even a hypothetical FNP, resolves removal, and
# spends the unit's round token. No damage prevention roll is fabricated.
# https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
fun test_orks17p2_runtherd_actual_destruction_and_round_limit() -> Bool:
    let unit = orks17p2_attached(make_orks_gretchin(10), make_orks_runtherd())
    let board = orks17p2_fixture(unit)
    board[0].battle_socked = true
    let sequence = orks_runtherd_shock(board, board[0])
    sequence.use_runtherd(board, board[0], true)
    sequence.quantity(board, board[0], attack_test_die(2))
    sequence.choose_punished_gretchin(board, board[0], damage_test_model(0))
    sequence.choose_punished_gretchin(board, board[0], damage_test_model(0))
    let cleared = sequence.is_done() and !board[0].battle_socked and orks_live_gretchin(board[0]) == 8
    board[0].battle_socked = true
    let same_round = orks_runtherd_shock(board, board[0])
    board.current_round = board.current_round + 1
    let next_round = orks_runtherd_shock(board, board[0])
    return cleared and same_round.is_done() and can next_round.use_runtherd(board, board[0], true)

# The own-unit correction is available offboard, with no position inputs.
# Runtherd; appendix01.02.04 and ordinary destruction.
fun test_orks17p2_runtherd_offboard_correction() -> Bool:
    let board : Board
    board.reserve_units.append(orks17p2_attached(make_orks_gretchin(10), make_orks_runtherd()))
    board.identify_units()
    mark_unit_offboard(board.reserve_units[0], true)
    board.reserve_units[0].battle_socked = true
    let sequence = orks_runtherd_shock(board, board.reserve_units[0])
    sequence.use_runtherd(board, board.reserve_units[0], true)
    sequence.quantity(board, board.reserve_units[0], attack_test_die(1))
    sequence.choose_punished_gretchin(board, board.reserve_units[0], damage_test_model(0))
    return sequence.is_done() and !board.reserve_units[0].battle_socked and board.reserve_units[0].models.size() == 10 and board.units.empty()

# Two Bomb Squig tokens, one per turn: unlike the Squighog single token.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Breaka-Boyz,Tankbustas}
fun test_orks17p2_bomb_two_per_battle_one_per_turn() -> Bool:
    let board = orks17p2_fixture(make_orks_breaka_boyz(false, 5, 5))
    let instance = orks17p2_source(board, ORKS_BOMB_SQUIG_RULE)
    let fresh = source_usage_available(board, instance)
    commit_source_usage(board, instance)
    let spent_turn = !source_usage_available(board, instance)
    board.turn_serial = board.turn_serial + 1
    let second = source_usage_available(board, instance)
    commit_source_usage(board, instance)
    board.turn_serial = board.turn_serial + 1
    return fresh and spent_turn and second and !source_usage_available(board, instance)

# Actual move-end selection still consumes a token on a failed detonation.
# No new die conventions, FNP or mortal allocation kernel is introduced.
fun test_orks17p2_breaka_actual_bomb_move_end() -> Bool:
    let board = orks17p2_fixture(make_orks_breaka_boyz(false, 5, 5))
    board.begin_phase(BattlePhase::movement)
    let event = source_event(SourceEventKind::move_end, board[0].identity, invalid_entity_identity(), invalid_entity_identity())
    event.movement = MovementKind::normal
    let sequence = resolve_movement_sources(board, event)
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_bomb_squig_target(board, unit_id(1))
    sequence.roll(board, attack_test_die(1))
    let instance = orks17p2_source(board, ORKS_BOMB_SQUIG_RULE)
    return sequence.is_done() and !source_usage_available(board, instance) and board[1][0].suffered_wounds == 0

# Trophy Hunters joins addition before division/rounding and the12 cap.
# https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
fun test_orks17p2_trophy_hunters_charge_order_and_cap() -> Bool:
    let unit = make_orks_breaka_boyz(false, 5, 5)
    let bonus = charge_distance(unit, 5, ChargeKind::ordinary, false) == 6
    unit.phase_modifiers.charge_roll.append(rule_modifier(ModifierOperation::divide, 2))
    return bonus and charge_distance(unit, 6, ChargeKind::ordinary, false) == 4 and charge_distance(unit, 30, ChargeKind::ordinary, false) == 12

# A Pulsa token belongs to the actual equipped bearer and marks one identity.
# Printed M/V and24in, not line of sight; declining costs nothing.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun test_orks17p2_pulsa_target_and_once_usage() -> Bool:
    let board = orks17p2_fixture(make_orks_tankbustas(false, Weapon::orks_pulsa_rokkit, 0))
    board[1][0].keywords.append(Keyword::monster)
    let sequence = orks_pulsa_selection(board, unit_id(0))
    sequence.use_pulsa_rokkit(board, true)
    sequence.choose_pulsa_target(board, unit_id(1))
    let info = orks17p2_info(board, 1)
    let marked = orks_pulsa_applies(board, board[0], board[1].identity)
    let spent = !orks_pulsa_available(board, unit_id(0))
    board.begin_phase(BattlePhase::charge)
    return sequence.is_done() and marked and spent and info.attack_penetration() == -3 and !orks_pulsa_applies(board, board[0], board[1].identity)

fun test_orks17p2_pulsa_decline_and_unavailable_target() -> Bool:
    let board = orks17p2_fixture(make_orks_tankbustas(false, Weapon::orks_pulsa_rokkit, 0))
    let no_monster = orks_pulsa_selection(board, unit_id(0))
    board[1][0].keywords.append(Keyword::vehicle)
    let sequence = orks_pulsa_selection(board, unit_id(0))
    sequence.use_pulsa_rokkit(board, false)
    return no_monster.is_done() and sequence.is_done() and orks_pulsa_available(board, unit_id(0)) and board.source_uses.empty()

# Retargeting to another enemy loses Pulsa even if it has the same keywords.
fun test_orks17p2_pulsa_does_not_follow_replacement_target() -> Bool:
    let board = orks17p2_fixture(make_orks_tankbustas(false, Weapon::orks_pulsa_rokkit, 0))
    board[1][0].keywords.append(Keyword::vehicle)
    let sequence = orks_pulsa_selection(board, unit_id(0))
    sequence.use_pulsa_rokkit(board, true)
    sequence.choose_pulsa_target(board, unit_id(1))
    let other = make_infernus_squad()
    other.owned_by_player1 = true
    board.units.append(other)
    board.identify_units()
    return orks_pulsa_applies(board, board[0], board[1].identity) and !orks_pulsa_applies(board, board[0], board[2].identity)

# Barrage requires an actual hit; -1 turns a natural6 against Ld6 into failure.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun test_orks17p2_rokkit_barrage_actual_hit_and_penalty() -> Bool:
    let board = orks17p2_fixture(make_orks_tankbustas(false, Weapon::none, 0))
    begin_attack_results(board)
    let none = orks_rokkit_barrage(board, unit_id(0))
    record_attack_hits(board, unit_id(1), 1)
    let sequence = orks_rokkit_barrage(board, unit_id(0))
    sequence.choose_rokkit_barrage_target(board, unit_id(1))
    sequence.roll_pair(board, attack_test_die(2), attack_test_die(4))
    return none.is_done() and sequence.is_done() and board[1].battle_socked

# Pure Shokk traversal does not give terrain traversal or permit the same
# passage in a Normal move. Final placement still uses the usual kernel.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
fun test_orks17p2_shokk_traversal_only_selected_advance() -> Bool:
    let unit = make_orks_big_mek(false, false)
    let ordinary = movement_policy(unit, unit[0], MovementKind::advance, false)
    unit.shokk_boosta_move = true
    let shokk = movement_policy(unit, unit[0], MovementKind::advance, false)
    let normal = movement_policy(unit, unit[0], MovementKind::normal, false)
    return !ordinary.traverse_enemies and shokk.traverse_enemies and !shokk.exclude_titanic and !shokk.exclude_monster_vehicle and !shokk.traverse_terrain and !normal.traverse_enemies

# An optional advance roll can stay at its rolled value or change to6; the
# actual move-end hazard source becomes mandatory only when Shokk was used.
fun test_orks17p2_shokk_actual_selection_and_six() -> Bool:
    let board = orks17p2_fixture(make_orks_big_mek(false, false))
    board[1][0].position = board_position(25, 20)
    board.begin_phase(BattlePhase::movement)
    let sequence = movement(board, unit_id(0), false)
    sequence.advance(board, true)
    sequence.use_shokk_boosta(board, true)
    sequence.roll(board, attack_test_die(2))
    sequence.keep_it(board, true)
    sequence.use_shokk_six(board, true)
    let extra = board[0].shokk_boosta_move and can sequence.move_to(board, board_position(16, 5))
    sequence.skip(board)
    return extra and !board[0].shokk_boosta_move

# The registered end effect rolls once for EACH model, not each weapon or
# only the Big Mek. Existing HazardRolls is used, including Command Re-roll.
fun test_orks17p2_shokk_hazards_mandatory_source() -> Bool:
    let board = orks17p2_fixture(make_orks_big_mek(false, false))
    board.command_points[0] = 1
    board.begin_phase(BattlePhase::movement)
    let inactive = orks17p2_source(board, ORKS_SHOKK_BOOST_RULE)
    let event = source_event(SourceEventKind::move_end, board[0].identity, invalid_entity_identity(), invalid_entity_identity())
    event.movement = MovementKind::advance
    let unavailable = !source_event_available(board, inactive, event)
    board[0].shokk_boosta_move = true
    let sequence = resolve_movement_sources(board, event)
    let pending = collect_source_events(board, event)
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.roll(board, attack_test_die(6))
    sequence.keep_batch(board)
    return unavailable and pending.size() == 1 and sequence.is_done() and board[0][0].suffered_wounds == 0

# Krushin' Impetus counts engaged MODELS and keeps the actual3+ threshold;
# moving the one source out of engagement removes it from the roll count.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
fun test_orks17p2_impetus_actual_engaged_model_roll() -> Bool:
    let board = orks17p2_fixture(make_orks_warboss_in_mega_armour())
    board[1][0].position = board_position(6, 5)
    let sequence = orks_krushin_impetus(board, unit_id(0))
    sequence.choose_impetus_target(board, unit_id(1))
    sequence.roll(board, attack_test_die(3))
    sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[1][0].suffered_wounds == 1

# Repeated start/end repairs retain separate modifiers but reuse their
# prototype after expiry; the finite source arena must not grow each turn.
# Orks/Mek Clever Know-wotz; appendix01.02.02.
fun test_orks17p2_repair_reuses_prototype_across_turns() -> Bool:
    let board = orks17p2_fixture(make_orks_mek())
    board[1] = make_orks_killa_kans(3)
    board[1].owned_by_player1 = false
    board[1][0].position = board_position(8, 5)
    board.identify_units()
    board.begin_phase(BattlePhase::movement)
    let instance = orks17p2_source(board, ORKS_MEK_REPAIR_RULE)
    let original_sources = board.source_instances.size()
    for turn_index in range(3):
        if turn_index > 0:
            board.turn_serial = board.turn_serial + 2
            refresh_source_effects(board, TimingWindow::movement_start)
        for boundary in range(2):
            let repair = repair_orks_vehicle(board, instance)
            repair.choose_mek_repair_unit(board, unit_id(1))
            repair.choose_mek_repair_model(board, damage_test_model(0))
            repair.quantity(board, attack_test_die(1))
    return board.source_instances.size() == original_sources + 1 and model_rule_effect(board, board[1][0], RuleEffectKind::clever_hit) == 2 and valid_source_foundations(board)


# Final25 standard Orks datasheets: printed profiles and procedural consumers.

# https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon: literal printed profile/InSv/FNP.
fun test_orks17p3_battlewagon_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_battlewagon, 10, 11, 3, 6, 16, 7, 5, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka: literal printed profile/InSv/FNP.
fun test_orks17p3_big_ed_bossbunka_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_big_ed_bossbunka, 0, 10, 3, 10, 12, 7, 0, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer: literal printed profile/InSv/FNP.
fun test_orks17p3_blitza_bommer_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_blitza_bommer, 0, 9, 3, 6, 12, 7, 0, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Boss-Snikrot: literal printed profile/InSv/FNP.
fun test_orks17p3_boss_snikrot_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_boss_snikrot, 6, 5, 5, 5, 6, 6, 1, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer: literal printed profile/InSv/FNP.
fun test_orks17p3_burna_bommer_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_burna_bommer, 0, 9, 3, 6, 12, 7, 0, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Dakkajet: literal printed profile/InSv/FNP.
fun test_orks17p3_dakkajet_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_dakkajet, 0, 9, 3, 6, 12, 7, 0, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike: literal printed profile/InSv/FNP.
fun test_orks17p3_deffkilla_wartrike_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_deffkilla_wartrike, 12, 6, 4, 5, 9, 6, 3, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas: literal printed profile/InSv/FNP.
fun test_orks17p3_deffkoptas_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_deffkoptas, 12, 6, 4, 6, 4, 7, 2, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka: literal printed profile/InSv/FNP.
fun test_orks17p3_ghazghkull_thraka_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_ghazghkull_thraka, 8, 10, 2, 4, 16, 6, 4, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut: literal printed profile/InSv/FNP.
fun test_orks17p3_gorkanaut_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_gorkanaut, 9, 12, 2, 6, 20, 7, 8, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon: literal printed profile/InSv/FNP.
fun test_orks17p3_gunwagon_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_gunwagon, 10, 12, 3, 6, 16, 7, 5, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig: literal printed profile/InSv/FNP.
fun test_orks17p3_hunta_rig_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_hunta_rig, 10, 10, 3, 6, 16, 7, 5, 5)

# https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig: literal printed profile/InSv/FNP.
fun test_orks17p3_kill_rig_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_kill_rig, 10, 10, 3, 6, 16, 7, 5, 5)

# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos: literal printed profile/InSv/FNP.
fun test_orks17p3_kommando_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_kommando, 6, 5, 5, 10, 1, 7, 1, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos: literal printed profile/InSv/FNP.
fun test_orks17p3_kommando_nob_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_kommando_nob, 6, 5, 5, 10, 3, 7, 1, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz: literal printed profile/InSv/FNP.
fun test_orks17p3_mek_gunz_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_mek_gunz, 5, 6, 4, 6, 6, 8, 2, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut: literal printed profile/InSv/FNP.
fun test_orks17p3_morkanaut_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_morkanaut, 9, 12, 2, 5, 20, 7, 8, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg: literal printed profile/InSv/FNP.
fun test_orks17p3_nazdreg_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_nazdreg, 5, 7, 2, 5, 8, 6, 1, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies: literal printed profile/InSv/FNP.
fun test_orks17p3_rukkatrukk_squigbuggies_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_rukkatrukk_squigbuggies, 12, 7, 4, 6, 9, 7, 3, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Stompa: literal printed profile/InSv/FNP.
fun test_orks17p3_stompa_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_stompa, 10, 14, 2, 5, 30, 6, 12, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Trukk: literal printed profile/InSv/FNP.
fun test_orks17p3_trukk_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_trukk, 12, 8, 4, 6, 10, 7, 2, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies: literal printed profile/InSv/FNP.
fun test_orks17p3_warbuggies_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_warbuggies, 12, 7, 4, 6, 9, 7, 3, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks: literal printed profile/InSv/FNP.
fun test_orks17p3_wartrakks_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_wartrakks, 12, 6, 4, 6, 7, 7, 3, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet: literal printed profile/InSv/FNP.
fun test_orks17p3_wazbom_blastajet_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_wazbom_blastajet, 0, 9, 3, 6, 12, 7, 0, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek: literal printed profile/InSv/FNP.
fun test_orks17p3_wazdakka_gutsmek_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_wazdakka_gutsmek, 14, 8, 3, 4, 10, 6, 3, 10)

# https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy: literal printed profile/InSv/FNP.
fun test_orks17p3_weirdboy_profile() -> Bool:
    return orks17h1_profile_values(Profile::orks_weirdboy, 6, 5, 5, 10, 4, 7, 1, 10)

# Test-only fixed constructors keep army-specific choices explicit. The large
# circular hulls are knowingly approximate by user instruction2026-10-15.
fun orks17p3_koptas(Int count, Int swaps) -> Unit:
    let equipment : OrksVehicleSwaps
    for index in range(count):
        equipment.append(index < swaps)
    return make_orks_deffkoptas(equipment)

fun orks17p3_buggies(Int count, Int swaps) -> Unit:
    let equipment : OrksVehicleSwaps
    for index in range(count):
        equipment.append(index < swaps)
    return make_orks_warbuggies(equipment)

fun orks17p3_guns(Int count, Weapon gun) -> Unit:
    let guns : OrksMekGuns
    for index in range(count):
        guns.append(gun)
    return make_orks_mek_gunz(guns, 0)

fun orks17p3_kommandos() -> Unit:
    let equipment : OrksKommandoLoadout
    let equipment_previous_1 = equipment.size()
    equipment.resize(10)
    for equipment_default_1 in range(10):
        if equipment_default_1 >= equipment_previous_1:
            equipment[equipment_default_1] = orks_kommando_equipment()
    return make_orks_kommandos(equipment)

# All25 adapter families coexist in a serializable roster without legacy data.
fun orks17p3_units() -> UnitVector:
    let units : UnitVector
    units.append(make_orks_battlewagon(0, 4, true, true))
    units.append(make_orks_big_ed_bossbunka(0, 3))
    units.append(make_orks_blitza_bommer())
    units.append(make_orks_boss_snikrot())
    units.append(make_orks_burna_bommer(true))
    units.append(make_orks_dakkajet(true))
    units.append(make_orks_deffkilla_wartrike())
    units.append(orks17p3_koptas(6, 2))
    units.append(make_orks_ghazghkull_thraka())
    units.append(make_orks_gorkanaut())
    units.append(make_orks_gunwagon(0, 4, true, true, true, Weapon::orks_gunwagon_kannon_frag))
    units.append(make_orks_hunta_rig())
    units.append(make_orks_kill_rig())
    units.append(orks17p3_kommandos())
    units.append(orks17p3_guns(3, Weapon::orks_mek_gunz_smasha_gun))
    units.append(make_orks_morkanaut())
    units.append(make_orks_nazdreg())
    units.append(make_orks_rukkatrukk_squigbuggies(2))
    units.append(make_orks_stompa(0))
    units.append(make_orks_trukk(0, true, Weapon::orks_trukk_buzzsaw))
    units.append(orks17p3_buggies(2, 1))
    units.append(make_orks_wartrakks(2))
    units.append(make_orks_wazbom_blastajet(true, true, true))
    units.append(make_orks_wazdakka_gutsmek())
    units.append(make_orks_weirdboy())
    return units

# https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon: named metadata/loadout coherence.
fun test_orks17p3_battlewagon_factory_metadata() -> Bool:
    let unit = make_orks_battlewagon(0, 4, true, true)
    let valid = unit.roster_datasheet.value == OrksDatasheet::battlewagon.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka: named metadata/loadout coherence.
fun test_orks17p3_big_ed_bossbunka_factory_metadata() -> Bool:
    let unit = make_orks_big_ed_bossbunka(0, 3)
    let valid = unit.roster_datasheet.value == OrksDatasheet::big_ed_bossbunka.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer: named metadata/loadout coherence.
fun test_orks17p3_blitza_bommer_factory_metadata() -> Bool:
    let unit = make_orks_blitza_bommer()
    let valid = unit.roster_datasheet.value == OrksDatasheet::blitza_bommer.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Boss-Snikrot: named metadata/loadout coherence.
fun test_orks17p3_boss_snikrot_factory_metadata() -> Bool:
    let unit = make_orks_boss_snikrot()
    let valid = unit.roster_datasheet.value == OrksDatasheet::boss_snikrot.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer: named metadata/loadout coherence.
fun test_orks17p3_burna_bommer_factory_metadata() -> Bool:
    let unit = make_orks_burna_bommer(true)
    let valid = unit.roster_datasheet.value == OrksDatasheet::burna_bommer.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Dakkajet: named metadata/loadout coherence.
fun test_orks17p3_dakkajet_factory_metadata() -> Bool:
    let unit = make_orks_dakkajet(true)
    let valid = unit.roster_datasheet.value == OrksDatasheet::dakkajet.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike: named metadata/loadout coherence.
fun test_orks17p3_deffkilla_wartrike_factory_metadata() -> Bool:
    let unit = make_orks_deffkilla_wartrike()
    let valid = unit.roster_datasheet.value == OrksDatasheet::deffkilla_wartrike.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas: named metadata/loadout coherence.
fun test_orks17p3_deffkoptas_factory_metadata() -> Bool:
    let unit = orks17p3_koptas(6, 2)
    let valid = unit.roster_datasheet.value == OrksDatasheet::deffkoptas.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka: named metadata/loadout coherence.
fun test_orks17p3_ghazghkull_thraka_factory_metadata() -> Bool:
    let unit = make_orks_ghazghkull_thraka()
    let valid = unit.roster_datasheet.value == OrksDatasheet::ghazghkull_thraka.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut: named metadata/loadout coherence.
fun test_orks17p3_gorkanaut_factory_metadata() -> Bool:
    let unit = make_orks_gorkanaut()
    let valid = unit.roster_datasheet.value == OrksDatasheet::gorkanaut.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon: named metadata/loadout coherence.
fun test_orks17p3_gunwagon_factory_metadata() -> Bool:
    let unit = make_orks_gunwagon(0, 4, true, true, true, Weapon::orks_gunwagon_kannon_frag)
    let valid = unit.roster_datasheet.value == OrksDatasheet::gunwagon.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig: named metadata/loadout coherence.
fun test_orks17p3_hunta_rig_factory_metadata() -> Bool:
    let unit = make_orks_hunta_rig()
    let valid = unit.roster_datasheet.value == OrksDatasheet::hunta_rig.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig: named metadata/loadout coherence.
fun test_orks17p3_kill_rig_factory_metadata() -> Bool:
    let unit = make_orks_kill_rig()
    let valid = unit.roster_datasheet.value == OrksDatasheet::kill_rig.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos: named metadata/loadout coherence.
fun test_orks17p3_kommandos_factory_metadata() -> Bool:
    let unit = orks17p3_kommandos()
    let valid = unit.roster_datasheet.value == OrksDatasheet::kommandos.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz: named metadata/loadout coherence.
fun test_orks17p3_mek_gunz_factory_metadata() -> Bool:
    let unit = orks17p3_guns(3, Weapon::orks_mek_gunz_smasha_gun)
    let valid = unit.roster_datasheet.value == OrksDatasheet::mek_gunz.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut: named metadata/loadout coherence.
fun test_orks17p3_morkanaut_factory_metadata() -> Bool:
    let unit = make_orks_morkanaut()
    let valid = unit.roster_datasheet.value == OrksDatasheet::morkanaut.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg: named metadata/loadout coherence.
fun test_orks17p3_nazdreg_factory_metadata() -> Bool:
    let unit = make_orks_nazdreg()
    let valid = unit.roster_datasheet.value == OrksDatasheet::nazdreg.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies: named metadata/loadout coherence.
fun test_orks17p3_rukkatrukk_squigbuggies_factory_metadata() -> Bool:
    let unit = make_orks_rukkatrukk_squigbuggies(2)
    let valid = unit.roster_datasheet.value == OrksDatasheet::rukkatrukk_squigbuggies.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Stompa: named metadata/loadout coherence.
fun test_orks17p3_stompa_factory_metadata() -> Bool:
    let unit = make_orks_stompa(0)
    let valid = unit.roster_datasheet.value == OrksDatasheet::stompa.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Trukk: named metadata/loadout coherence.
fun test_orks17p3_trukk_factory_metadata() -> Bool:
    let unit = make_orks_trukk(0, true, Weapon::orks_trukk_buzzsaw)
    let valid = unit.roster_datasheet.value == OrksDatasheet::trukk.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies: named metadata/loadout coherence.
fun test_orks17p3_warbuggies_factory_metadata() -> Bool:
    let unit = orks17p3_buggies(2, 1)
    let valid = unit.roster_datasheet.value == OrksDatasheet::warbuggies.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks: named metadata/loadout coherence.
fun test_orks17p3_wartrakks_factory_metadata() -> Bool:
    let unit = make_orks_wartrakks(2)
    let valid = unit.roster_datasheet.value == OrksDatasheet::wartrakks.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet: named metadata/loadout coherence.
fun test_orks17p3_wazbom_blastajet_factory_metadata() -> Bool:
    let unit = make_orks_wazbom_blastajet(true, true, true)
    let valid = unit.roster_datasheet.value == OrksDatasheet::wazbom_blastajet.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek: named metadata/loadout coherence.
fun test_orks17p3_wazdakka_gutsmek_factory_metadata() -> Bool:
    let unit = make_orks_wazdakka_gutsmek()
    let valid = unit.roster_datasheet.value == OrksDatasheet::wazdakka_gutsmek.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy: named metadata/loadout coherence.
fun test_orks17p3_weirdboy_factory_metadata() -> Bool:
    let unit = make_orks_weirdboy()
    let valid = unit.roster_datasheet.value == OrksDatasheet::weirdboy.value and !unit.empty()
    for member_index in range(unit.models.size()):
        valid = valid and valid_model_equipment(unit[member_index]) and unit[member_index].has_waaagh and unit[member_index].has_keyword(Keyword::orks) and unit[member_index].base_radius_micrometres() > 0.0
    return valid

# Large bounded proxy dimensions and new effect/action enums round trip.
fun test_orks17p3_all_adapters_round_trip() -> Bool:
    let state = play()
    state.board.reserve_units = orks17p3_units()
    state.board.identify_units()
    state.board.capture_starting_strengths()
    register_orks_passive_rules(state.board)
    register_orks_datasheet_sources(state.board)
    refresh_source_effects(state.board, TimingWindow::none)
    let restored = play()
    return set_state(restored, to_string(state)) and restored.board.reserve_units.size() == 25 and valid_state_foundations(restored.board)

# Temporary hull circles are explicit bounded geometry, not source dimensions.
fun test_orks17p3_intentionally_approximate_hulls_and_explicit_override() -> Bool:
    let wagon = make_orks_battlewagon(0, 0, false, false)
    let measured = make_orks_battlewagon(130, 0, false, false)
    return Profile::orks_battlewagon.base_size() == 0.0 and wagon[0].geometry.proxy_diameter_mm == 160 and wagon[0].base_radius_micrometres() == 80000.0 and measured[0].base_radius_micrometres() == 65000.0 and make_orks_stompa(0)[0].geometry.proxy_diameter_mm == 240

# Source axes survive deliberate long-axis circles for every remaining oval.
fun test_orks17p3_all_oval_axes_are_retained() -> Bool:
    return profile_has_oval_base(Profile::orks_wazdakka_gutsmek) and profile_base_width(Profile::orks_wazdakka_gutsmek) == 92.0 and Profile::orks_wazdakka_gutsmek.base_size() == 120.0 and profile_base_width(Profile::orks_gorkanaut) == 109.0 and profile_base_width(Profile::orks_wartrakks) == 70.0 and profile_base_width(Profile::orks_deffkoptas) == 42.0

# '-' M/OC cannot become movable/control-bearing characteristics via modifiers.
fun test_orks17p3_immobile_and_aircraft_absent_characteristics() -> Bool:
    let board = orks17p2_fixture(make_orks_big_ed_bossbunka(0, 0))
    board.begin_phase(BattlePhase::movement)
    board[0][0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 5))
    let aircraft = make_orks_dakkajet(false)
    aircraft[0].characteristic_modifiers.append(characteristic_modifier(ModifiedCharacteristic::objective_control, ModifierOperation::add, 4))
    return !battlefield_move_eligible(board, unit_id(0), MovementKind::normal) and battlefield_move_eligible(board, unit_id(0), MovementKind::stationary) and board[0][0].effective_movement(0) == 0 and aircraft[0].effective_objective_control() == 0

# All physical copies have different groups; profiles within each copy share.
fun test_orks17p3_gorkanaut_physical_weapon_copies() -> Bool:
    let unit = make_orks_gorkanaut()
    return unit[0].weapons.size() == 10 and weapon_primary_id(unit[0], 0) == weapon_primary_id(unit[0], 1) and weapon_primary_id(unit[0], 2) != weapon_primary_id(unit[0], 3) and weapon_primary_id(unit[0], 4) == weapon_primary_id(unit[0], 5) and weapon_primary_id(unit[0], 6) == weapon_primary_id(unit[0], 7) and weapon_primary_id(unit[0], 4) != weapon_primary_id(unit[0], 6)

# Nazdreg's explicit exception includes all THREE ranged profiles, not melee.
fun test_orks17p3_nazdreg_three_profiles_and_unit_deep_strike() -> Bool:
    let unit = make_orks_nazdreg()
    return unit[0].weapons.size() == 5 and permits_simultaneous_profile(unit[0], 0) and permits_simultaneous_profile(unit[0], 1) and permits_simultaneous_profile(unit[0], 2) and !permits_simultaneous_profile(unit[0], 3) and unit.has_ability(AbilityKind::deep_strike)

# Equipment removes SMOKE only when the force field was actually selected.
fun test_orks17p3_blastajet_field_changes_keyword_and_invulnerable() -> Bool:
    let field = make_orks_wazbom_blastajet(false, true, false)
    let smoke = make_orks_wazbom_blastajet(false, false, false)
    return field[0].effective_invulnerable_save() == 5 and !field[0].has_keyword(Keyword::smoke) and smoke[0].effective_invulnerable_save() == 6 and smoke[0].has_keyword(Keyword::smoke)

# The4-card all-option envelope fits the audited13 slots; no capacity inflation.
fun test_orks17p3_largest_equipment_envelope() -> Bool:
    return make_orks_gunwagon(0, 4, true, true, true, Weapon::orks_gunwagon_kannon_frag)[0].weapons.size() == 10 and make_orks_stompa(0)[0].weapons.size() == 10 and MAX_WEAPONS == 13

# Kommandos' one each/two Shootas quotas do not forbid independent extras on
# the same Boy, or silently give a Boy replacement to the Nob.
fun test_orks17p3_kommando_loadout_quotas_and_extras() -> Bool:
    let equipment : OrksKommandoLoadout
    let equipment_previous_1 = equipment.size()
    equipment.resize(10)
    for equipment_default_1 in range(10):
        if equipment_default_1 >= equipment_previous_1:
            equipment[equipment_default_1] = orks_kommando_equipment()
    equipment[1].burna = true
    equipment[1].rokkit = true
    equipment[1].breacha_ram = true
    equipment[1].kustom_shoota = true
    equipment[2].kustom_shoota = true
    let valid = orks_kommando_loadout_valid(equipment)
    let unit = make_orks_kommandos(equipment)
    equipment[3].kustom_shoota = true
    return valid and unit[1].weapons.size() == 6 and !orks_kommando_loadout_valid(equipment)

# Gork/Mork exclude Ghaz while Battlewagon/Gunwagon/Stompa admit4 seats.
fun test_orks17p3_transport_literal_permissions() -> Bool:
    let ghaz = make_orks_ghazghkull_thraka()
    let wagon = make_orks_battlewagon(0, 0, false, false)
    let gork = make_orks_gorkanaut()
    let trukk = make_orks_trukk(0, false, Weapon::none)
    let boyz = make_orks_beast_snagga_boyz(1, 9, 0)
    let rig = make_orks_hunta_rig()
    let ordinary = orks17p3_kommandos()
    return passenger_model_permitted(wagon[0], ghaz[0]) and passenger_space(ghaz) == 4 and !passenger_model_permitted(gork[0], ghaz[0]) and !passenger_model_permitted(trukk[0], ghaz[0]) and passenger_model_permitted(rig[0], boyz[0]) and !passenger_model_permitted(rig[0], ordinary[0])

# Gretchin alone halves seats; Jump Pack models really occupy2 seats and a
# Trukk forbids them regardless of its remaining capacity.
fun test_orks17p3_transport_jump_and_gretchin_seats() -> Bool:
    let stormboyz = make_orks_stormboyz(4, false)
    let trukk = make_orks_trukk(0, false, Weapon::none)
    return passenger_space(stormboyz) == 10 and passenger_space(make_orks_gretchin(11)) == 6 and !passenger_model_permitted(trukk[0], stormboyz[0])

# Passive query assertions exercise the same gathered attack snapshots as play.
# https://wahapedia.ru/wh40k11ed/factions/orks/Dakkajet (Strafing Run).
fun test_orks17p3_dakkajet_own_phase_non_fly_only() -> Bool:
    let board = orks17p2_fixture(make_orks_dakkajet(false))
    let own = orks17p2_info(board, 0)
    board[1][0].keywords.append(Keyword::fly)
    let flying = orks17p2_info(board, 0)
    board[1][0].keywords.clear()
    board.begin_phase(BattlePhase::fight)
    let other_phase = orks17p2_info(board, 0)
    return own.total_hit_modifier() == 1 and flying.total_hit_modifier() == 0 and other_phase.total_hit_modifier() == 0

# The ingress bonus requires this TURN, not merely having arrived before.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
fun test_orks17p3_kopta_ingress_turn_bonus() -> Bool:
    let board = orks17p2_fixture(orks17p3_koptas(3, 0))
    let before = orks17p2_info(board, 0)
    board[0].history.has_ingressed = true
    board[0].history.ingress_turn = board.turn_serial.value + 1
    let arrived = orks17p2_info(board, 0)
    board.turn_serial = board.turn_serial + 1
    let later = orks17p2_info(board, 0)
    return before.total_hit_modifier() == 0 and arrived.total_hit_modifier() == 1 and later.total_hit_modifier() == 0

# Only ranged incoming Damage receives Mobile Fortress's-1 before the D floor.
# https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon
fun test_orks17p3_mobile_fortress_ranged_damage_floor() -> Bool:
    let board = orks17p2_fixture(make_orks_warboss())
    board[1] = make_orks_battlewagon(0, 0, false, false)
    board[1].owned_by_player1 = true
    board.identify_units()
    let ranged = orks17p2_info(board, 1)
    let melee = orks17p2_info(board, 0)
    return modified_characteristic(1, ModifiedCharacteristic::damage, ranged.damage_modifiers, false) == 1 and modified_characteristic(3, ModifiedCharacteristic::damage, ranged.damage_modifiers, false) == 2 and modified_characteristic(3, ModifiedCharacteristic::damage, melee.damage_modifiers, false) == 3

# Big an' Stompy is melee-only; Big an' Shooty/Mobile Arsenal are own Shooting.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Gorkanaut,Morkanaut,Gunwagon}
fun test_orks17p3_naut_and_gunwagon_rerolls() -> Bool:
    let board = orks17p2_fixture(make_orks_gorkanaut())
    let ranged = orks17p2_info(board, 0)
    let melee = orks17p2_info(board, 9)
    board[0] = make_orks_morkanaut()
    board.identify_units()
    let mork = orks17p2_info(board, 0)
    board[0] = make_orks_gunwagon(0, 0, false, false, false, Weapon::orks_gunwagon_kannon_frag)
    board.identify_units()
    let gun = orks17p2_info(board, 1)
    board.begin_phase(BattlePhase::fight)
    let out_of_phase = orks17p2_info(board, 1)
    return !ranged.reroll1_hits and melee.reroll1_hits and mork.reroll1_hits and gun.reroll1_hits and !out_of_phase.reroll1_hits

# Ghaz cannot be his own nearby Infantry unit, but his aura affects himself.
# https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
fun test_orks17p3_ghaz_live_aura_and_other_unit_guard() -> Bool:
    let board = orks17p2_fixture(make_orks_ghazghkull_thraka())
    let alone = !orks_datasheet_lone_operative(board, board[0])
    let melee = orks17p2_info(board, 3)
    board.units.append(make_orks_runtherd())
    board[2][0].position = board_position(8, 5)
    board.identify_units()
    let guarded = orks_datasheet_lone_operative(board, board[0])
    mark_unit_offboard(board[2], true)
    return alone and melee.total_hit_modifier() == 1 and melee.total_wound_modifier() == 1 and guarded and !orks_datasheet_lone_operative(board, board[0])

# Wartrakks need support near EVERY model; another Wartrakk never qualifies.
# https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks
fun test_orks17p3_wartrakk_per_model_support() -> Bool:
    let board = orks17p2_fixture(make_orks_wartrakks(2))
    board[0][0].position = board_position(5, 5)
    board[0][1].position = board_position(25, 5)
    board.units.append(make_orks_deffkilla_wartrike())
    board[2][0].position = board_position(7, 5)
    board.identify_units()
    let incomplete = !orks_datasheet_lone_operative(board, board[0])
    board[0][1].position = board_position(9, 5)
    let supported = orks_datasheet_lone_operative(board, board[0])
    board[2] = make_orks_wartrakks(1)
    board[2][0].position = board_position(7, 5)
    return incomplete and supported and !orks_datasheet_lone_operative(board, board[0])

# Go fer da Weak Spot never improves attacks against ordinary Infantry.
# https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
fun test_orks17p3_weak_spot_monster_vehicle_and_phase() -> Bool:
    let board = orks17p2_fixture(make_orks_wazbom_blastajet(false, false, false))
    let infantry = orks17p2_info(board, 0)
    board[1][0].keywords.append(Keyword::vehicle)
    let vehicle = orks17p2_info(board, 0)
    board.current_player = true
    let opponent_turn = orks17p2_info(board, 0)
    return infantry.total_wound_modifier() == 0 and vehicle.total_wound_modifier() == 1 and opponent_turn.total_wound_modifier() == 0

# Non-stacking Prophet aura is lost when the source is offboard/dead.
# https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
fun test_orks17p3_prophet_no_offboard_or_stacked_aura() -> Bool:
    let board = orks17p2_fixture(make_orks_runtherd())
    board.units.append(make_orks_ghazghkull_thraka())
    board.units.append(make_orks_ghazghkull_thraka())
    board[2][0].position = board_position(8, 5)
    board[3][0].position = board_position(9, 5)
    board.identify_units()
    let nearby = orks17p2_info(board, 1)
    mark_unit_offboard(board[2], true)
    board[3][0].suffered_wounds = board[3][0].profile.wounds()
    return nearby.total_hit_modifier() == 1 and nearby.total_wound_modifier() == 1 and !orks_prophet_aura(board, board[0])

# Intentional circular bunker occlusion supplies cover, never invisibility.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
fun test_orks17p3_bunka_partial_obscuration() -> Bool:
    let board = orks17p2_fixture(make_orks_runtherd())
    board[0][0].position = board_position(5, 10)
    board[1][0].position = board_position(20, 10)
    board.units.append(make_orks_big_ed_bossbunka(0, 0))
    board[2][0].position = board_position(12, 10)
    board.identify_units()
    let covered = unit_has_benefit_of_cover(board, board[0][0], board[1])
    board[2][0].position = board_position(12, 20)
    return covered and unit_visible_to_unit(board, board[0], board[1]) and !unit_has_benefit_of_cover(board, board[0][0], board[1])

# Only-fortifications engagement is waived; another engaged enemy closes it.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
fun test_orks17p3_fortification_engagement_and_hazard_exception() -> Bool:
    let board = orks17p2_fixture(make_orks_runtherd())
    board[1] = make_orks_big_ed_bossbunka(0, 0)
    board[1].owned_by_player1 = true
    board[1][0].position = board_position(8, 5)
    board.identify_units()
    board.begin_phase(BattlePhase::movement)
    let exempt = orks_engaged_only_fortifications(board, board[0])
    let hazards = desperate_escape(board, unit_id(0))
    board.units.append(make_orks_runtherd())
    board[2].owned_by_player1 = true
    board[2][0].position = board_position(6, 5)
    board.identify_units()
    return exempt and hazards.is_done() and !orks_engaged_only_fortifications(board, board[0])

# Test-only cargo fixture uses the same stable carrier links as real embark.
# Sources: transports pp64-65; current source-specific passenger permissions.
fun orks17p3_cargo(Unit carrier, Unit passenger) -> Board:
    let board = orks17p2_fixture(carrier)
    board[1][0].position = board_position(35, 20)
    board.embarked_units.append(passenger)
    board.embarked_units[0].embarked_transport = board[0][0].identity
    board.identify_unit(board.embarked_units[0])
    mark_unit_offboard(board.embarked_units[0], true)
    board.identify_units()
    board.capture_starting_strengths()
    board.begin_phase(BattlePhase::movement)
    return board

# Raucous uses explicit friendly HOME assignment, not arbitrary marker index.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
fun test_orks17p3_bunka_home_objective_embarked_oc() -> Bool:
    let board = orks17p3_cargo(make_orks_big_ed_bossbunka(0, 0), make_orks_gretchin(10))
    board.objectives[0].custom_position = true
    board.objectives[0].position = board_position(5, 5)
    let unspecified = orks_bunka_passenger_control(board, board.objective_range_definition(0), board[0][0], false)
    board.objectives[0].home = ObjectiveHome::army_0
    let occupied = orks_bunka_passenger_control(board, board.objective_range_definition(0), board[0][0], false)
    let control = board.objective_control_level(board.objective_range_definition(0), false)
    board.embarked_units[0].battle_socked = true
    return unspecified == 0 and occupied == 10 and control == 10 and orks_bunka_passenger_control(board, board.objective_range_definition(0), board[0][0], false) == 0

# Butchery counts bodies, caps at22 and affects the named melee weapon only.
# https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
fun test_orks17p3_hunta_butchery_actual_bodies_and_cap() -> Bool:
    let board = orks17p3_cargo(make_orks_hunta_rig(), make_orks_beast_snagga_boyz(2, 18, 0))
    let butcha = make_declared_weapon(board, unit_id(0), 0, 2)
    let other = make_declared_weapon(board, unit_id(0), 0, 3)
    let modifiers = declaration_modifiers(board, unit_id(0), butcha, ModifiedCharacteristic::attacks)
    let others = declaration_modifiers(board, unit_id(0), other, ModifiedCharacteristic::attacks)
    return apply_rule_modifiers(0, modifiers, false) == 22 and apply_rule_modifiers(0, others, false) == 0

# The CP discount is applied before affordability; accepted free use consumes
# all ordinary target/phase limits (not a later refund).
# https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
fun test_orks17p3_hunta_crushing_discount_at_zero_cp() -> Bool:
    let board = orks17p2_fixture(make_orks_hunta_rig())
    board.command_points[0] = 0
    board.begin_phase(BattlePhase::charge)
    let affordable = board.can_target_strat(false, Stratagem::crushing_impact, board[0])
    board.commit_stratagem(false, Stratagem::crushing_impact, board[0])
    return affordable and board.command_points[0] == 0 and !board.can_target_strat(false, Stratagem::crushing_impact, board[0])

# Gut Hatch chooses assault only AFTER an actual Normal move, not ingress.
# https://wahapedia.ru/wh40k11ed/factions/orks/{Gorkanaut,Morkanaut}
fun test_orks17p3_gut_hatch_assault_after_normal_only() -> Bool:
    let board = orks17p3_cargo(make_orks_gorkanaut(), make_orks_runtherd())
    let location = find_passenger_carrier(board, board[0][0].identity)
    board[0].history.selected_move_phase = board.phase_serial.value + 1
    board[0].history.move_kind = MovementKind::normal
    let normal = required_disembark_mode(board, board.embarked_units[0], location)
    board[0].history.move_kind = MovementKind::ingress
    let ingress = required_disembark_mode(board, board.embarked_units[0], location)
    return normal == DisembarkMode::assault and ingress == DisembarkMode::rapid

# New windows are filtered through the existing pending-source ordering.
# Sources: Blitza/Burna bombs, Snikrot/Koptas opponent-end reserve rules.
fun test_orks17p3_bomb_window_mandatory_and_no_target_gate() -> Bool:
    let board = orks17p2_fixture(make_orks_blitza_bommer())
    board.current_player = true
    board.begin_phase(BattlePhase::fight)
    let source = orks17p2_source(board, 140)
    let event = source_event(SourceEventKind::timing_window, invalid_entity_identity(), invalid_entity_identity(), invalid_entity_identity())
    event.window = TimingWindow::fight_end
    let valid = source_event_available(board, source, event) and !source.optional
    board[1][0].abilities.append(AbilityKind::lone_operative)
    return valid and !source_event_available(board, source, event)

# Printed bombs use explicit D6 plus D3 branches and ordinary mortal damage.
# https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer
fun orks17p3_bomb_damage(Int face, Int d3, Int expected) -> Bool:
    let board = orks17p2_fixture(make_orks_blitza_bommer())
    # Keep a single recipient alive across every mortal allocation branch.
    board[1][0].profile = Profile::orks_ghazghkull_thraka
    board.current_player = true
    board.begin_phase(BattlePhase::fight)
    let source = orks17p2_source(board, 140)
    let sequence = orks_datasheet_window(board, source)
    sequence.choose_aircraft_bomb_target(board, unit_id(1))
    sequence.roll(board, attack_test_die(face))
    if face <= 3 or face == 6:
        sequence.quantity(board, attack_test_die(d3))
    for wound in range(expected):
        sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[1][0].suffered_wounds == expected

fun test_orks17p3_boom_bomb_low_branch() -> Bool:
    return orks17p3_bomb_damage(1, 2, 2)

fun test_orks17p3_boom_bomb_middle_branch() -> Bool:
    return orks17p3_bomb_damage(4, 1, 3)

fun test_orks17p3_boom_bomb_high_branch() -> Bool:
    return orks17p3_bomb_damage(6, 1, 4)

# A Burna1 fails without D3/status;2+ installs both consumers to next-turn end.
# https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer
fun test_orks17p3_burna_bomb_failed_roll() -> Bool:
    let board = orks17p2_fixture(make_orks_burna_bommer(false))
    board.current_player = true
    board.begin_phase(BattlePhase::fight)
    let sequence = orks_datasheet_window(board, orks17p2_source(board, 141))
    sequence.choose_aircraft_bomb_target(board, unit_id(1))
    sequence.roll(board, attack_test_die(1))
    return sequence.is_done() and board[1][0].suffered_wounds == 0 and unit_rule_effect(board, board[1], RuleEffectKind::burna_mark) == 0

fun test_orks17p3_burna_hidden_ignore_cover_duration() -> Bool:
    let board = orks17p2_fixture(make_orks_burna_bommer(false))
    board.current_player = true
    board.begin_phase(BattlePhase::fight)
    let sequence = orks_datasheet_window(board, orks17p2_source(board, 141))
    sequence.choose_aircraft_bomb_target(board, unit_id(1))
    sequence.roll(board, attack_test_die(2))
    sequence.quantity(board, attack_test_die(1))
    sequence.select_mortal_model(board, damage_test_model(0))
    let area : TerrainArea
    area.lower = geometry_point(7 * MICROMETRES_PER_INCH, 3 * MICROMETRES_PER_INCH, 0)
    area.upper = geometry_point(11 * MICROMETRES_PER_INCH, 7 * MICROMETRES_PER_INCH, 0)
    area.dense = true
    board.terrain_areas.append(area)
    let marked = !model_is_hidden(board, board[1], board[1][0]) and unit_rule_effect(board, board[1], RuleEffectKind::burna_mark) == 1
    let info = orks17p2_info(board, 0)
    board.turn_serial = board.turn_serial + 1
    board.current_player = false
    refresh_source_effects(board, TimingWindow::turn_start)
    let persists = unit_rule_effect(board, board[1], RuleEffectKind::burna_mark) == 1
    refresh_source_effects(board, TimingWindow::turn_end)
    return sequence.is_done() and marked and attack_ignores_cover(board, info) and persists and unit_rule_effect(board, board[1], RuleEffectKind::burna_mark) == 0 and model_is_hidden(board, board[1], board[1][0])

# Aerial Manoover cannot withdraw an engaged unit and preserves identity.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
fun test_orks17p3_kopta_reserve_window_and_identity() -> Bool:
    let board = orks17p2_fixture(orks17p3_koptas(3, 0))
    board[1][0].position = board_position(35, 20)
    board.current_player = true
    board.begin_phase(BattlePhase::fight)
    let identity = board[0].identity
    let source = orks17p2_source(board, 143)
    let event = source_event(SourceEventKind::timing_window, invalid_entity_identity(), invalid_entity_identity(), invalid_entity_identity())
    event.window = TimingWindow::fight_end
    let valid = source_event_available(board, source, event)
    let sequence = orks_datasheet_window(board, source)
    return valid and sequence.is_done() and board[0].retired and board.reserve_units[0].identity == identity and board.reserve_units[0].history.repositioned

# Snikrot requires every living model Hidden, not merely one; attached allies
# use their real terrain/history. Opponent first-round ingress is explicit.
# https://wahapedia.ru/wh40k11ed/factions/orks/Boss-Snikrot
fun test_orks17p3_snikrot_hidden_and_first_round_shadows() -> Bool:
    let board = orks17p2_fixture(orks17p2_attached(orks17p3_kommandos(), make_orks_boss_snikrot()))
    board[1][0].position = board_position(35, 20)
    board.current_player = true
    board.begin_phase(BattlePhase::fight)
    let source = orks17p2_source(board, 142)
    let event = source_event(SourceEventKind::timing_window, invalid_entity_identity(), invalid_entity_identity(), invalid_entity_identity())
    event.window = TimingWindow::fight_end
    let exposed = !source_event_available(board, source, event)
    let area : TerrainArea
    area.lower = geometry_point(3 * MICROMETRES_PER_INCH, 3 * MICROMETRES_PER_INCH, 0)
    area.upper = geometry_point(13 * MICROMETRES_PER_INCH, 13 * MICROMETRES_PER_INCH, 0)
    area.dense = true
    board.terrain_areas.append(area)
    let hidden = source_event_available(board, source, event)
    let sequence = orks_datasheet_window(board, source)
    board.begin_phase(BattlePhase::movement)
    let ingress = orks17p2_source(board, 144)
    event.window = TimingWindow::movement_end
    let shadows = source_event_available(board, ingress, event) and orks_ingress_round_allowed(board, board.reserve_units[0])
    let bearer = board.reserve_units[0].models.size() - 1
    board.reserve_units[0][bearer].suffered_wounds = board.reserve_units[0][bearer].profile.wounds()
    return exposed and hidden and sequence.is_done() and board.reserve_units.size() == 1 and shadows and has_live_model(board.reserve_units[0]) and !source_event_available(board, ingress, event)

# Get Back in da Race includes passenger units and shares its army/round limit.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
fun test_orks17p3_race_clears_cargo_shock_and_shared_limit() -> Bool:
    let board = orks17p3_cargo(make_orks_trukk(0, false, Weapon::none), make_orks_runtherd())
    board.units.append(make_orks_deffkilla_wartrike())
    board[2][0].position = board_position(8, 5)
    board.identify_units()
    register_orks_datasheet_sources(board)
    let instance = orks17p2_source(board, 147)
    board[0].battle_socked = true
    board.embarked_units[0].battle_socked = true
    commit_orks_race(board, instance, unit_id(0))
    let cargo = !board[0].battle_socked and !board.embarked_units[0].battle_socked and unit_is_riled_up(board[0]) and unit_is_riled_up(board.embarked_units[0]) and !source_usage_available(board, instance)
    # A registered source must stop when its actual attached conferrer dies,
    # even though the bodyguard still has live Speed Freeks models (core p67).
    let attached = orks17p2_fixture(orks17p2_attached(make_orks_warbikers(2), make_orks_deffkilla_wartrike()))
    attached.begin_phase(BattlePhase::movement)
    let registered = orks17p2_source(attached, 147)
    let event = source_event(SourceEventKind::move_end, attached[0].identity, invalid_entity_identity(), invalid_entity_identity())
    let living = source_event_available(attached, registered, event)
    let bearer = attached[0].models.size() - 1
    attached[0][bearer].suffered_wounds = attached[0][bearer].profile.wounds()
    return cargo and living and has_live_model(attached[0]) and !source_event_available(attached, registered, event)

# Makari selects at most the current round number; offboard army units are
# legal, duplicates are not, and the one army/battle token cannot refresh.
# https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
fun test_orks17p3_makari_count_banks_and_once_battle() -> Bool:
    let board = orks17p2_fixture(make_orks_ghazghkull_thraka())
    board.reserve_units.append(make_orks_runtherd())
    board.identify_units()
    board.reserve_units[0].history.strategic_reserve = true
    board.begin_phase(BattlePhase::movement)
    board.current_round = 1
    let sequence = orks_datasheet_movement(board, unit_id(0))
    sequence.choose_datasheet_move_ability(board, OrksDatasheetMoveAbility::makari)
    sequence.choose_makari_bank(board, SourceBank::reserves)
    sequence.choose_makari_unit(board, unit_id(0))
    sequence.choose_makari_bank(board, SourceBank::battlefield)
    sequence.choose_makari_unit(board, unit_id(0))
    return sequence.is_done() and unit_is_riled_up(board[0]) and unit_is_riled_up(board.reserve_units[0]) and !orks_datasheet_move_available(board, unit_id(0), OrksDatasheetMoveAbility::makari)

# Source-defined temporary detection and psychic defaults expire at turn/phase
# boundaries, rather than mutating the unit's printed characteristics.
# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
fun test_orks17p3_found_em_turn_grant_and_no_visibility_requirement() -> Bool:
    let board = orks17p2_fixture(orks17p3_kommandos())
    board.begin_phase(BattlePhase::movement)
    let sequence = orks_datasheet_movement(board, unit_id(0))
    sequence.choose_datasheet_move_ability(board, OrksDatasheetMoveAbility::found_em)
    sequence.choose_datasheet_move_target(board, unit_id(1))
    let active = unit_rule_effect(board, board[1], RuleEffectKind::found_detection) == 1
    refresh_source_effects(board, TimingWindow::turn_end)
    return sequence.is_done() and active and unit_rule_effect(board, board[1], RuleEffectKind::found_detection) == 0

# Scorch blocks targeting the affected enemy with Fire Overwatch, while no
# CP is spent and unrelated stratagems remain available.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
fun test_orks17p3_drive_by_blocks_overwatch_only() -> Bool:
    let board = orks17p2_fixture(orks17p3_buggies(1, 0))
    board.begin_phase(BattlePhase::movement)
    board.command_points[1] = 3
    let sequence = orks_datasheet_movement(board, unit_id(0))
    sequence.choose_datasheet_move_ability(board, OrksDatasheetMoveAbility::drive_by_skorchin)
    sequence.choose_datasheet_move_target(board, unit_id(1))
    return sequence.is_done() and !board.can_target_strat(true, Stratagem::overwatch, board[1]) and board.can_target_strat(true, Stratagem::reroll, board[1]) and board.command_points[1] == 3

# Warpath's psychic1 shocks but does not cancel either rule, and spends the
# shared psyker-level budget before the effect; no damage-roll reroll is added.
# https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy
fun test_orks17p3_weirdboy_warpath_one_still_grants() -> Bool:
    let board = orks17p2_fixture(make_orks_weirdboy())
    board.begin_phase(BattlePhase::fight)
    let sequence = orks_datasheet_fight_selection(board, unit_id(0))
    sequence.use_datasheet_warpath(board, true)
    sequence.roll(board, attack_test_die(1))
    let info = orks17p2_info(board, 1)
    return sequence.is_done() and board[0].battle_socked and info.reroll1_wounds and info.has_weapon_rule(board, WeaponRuleKind::psychic) and board[0].orks_psychic_usage.budget.spent == 1

# Kill Rig has the other Warpath: Lethal+Psychic, no Weirdboy wound reroll.
# https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
fun test_orks17p3_killrig_warpath_distinct_effect() -> Bool:
    let board = orks17p2_fixture(make_orks_kill_rig())
    board.begin_phase(BattlePhase::fight)
    let sequence = orks_datasheet_fight_selection(board, unit_id(0))
    sequence.use_datasheet_warpath(board, true)
    sequence.roll(board, attack_test_die(6))
    let info = orks17p2_info(board, 3)
    return sequence.is_done() and !info.reroll1_wounds and info.has_weapon_rule(board, WeaponRuleKind::psychic) and info.has_weapon_rule(board, WeaponRuleKind::letal_hits)

# Da Jump grants phase-only unit Deep Strike, including attached bodyguards,
# and moves even on a psychic1. The shared army/round token survives the bank.
# https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy
fun test_orks17p3_da_jump_one_and_same_phase_deep_strike() -> Bool:
    let source = orks17p2_attached(make_orks_beast_snagga_boyz(1, 9, 0), make_orks_weirdboy())
    let board = orks17p2_fixture(source)
    board.begin_phase(BattlePhase::movement)
    let sequence = orks_datasheet_movement(board, unit_id(0))
    sequence.choose_datasheet_move_ability(board, OrksDatasheetMoveAbility::da_jump)
    sequence.roll(board, attack_test_die(1))
    let current = board.reserve_units[0].all_have_ability(AbilityKind::deep_strike)
    refresh_source_effects(board, TimingWindow::movement_end)
    return sequence.is_done() and board[0].retired and board.reserve_units[0].battle_socked and current and !board.reserve_units[0].all_have_ability(AbilityKind::deep_strike)

# Existing Wurrband spells and datasheet spells consume the SAME level pool.
# Orks Unstable Energies; appendix22.03.01.
fun test_orks17p3_shared_psychic_budget_and_phase_restriction() -> Bool:
    let board = orks17p2_fixture(make_orks_weirdboy())
    board.begin_phase(BattlePhase::movement)
    board[0].orks_psychic_usage.budget.round_stamp = board.current_round.value + 1
    board[0].orks_psychic_usage.budget.spent = 1
    let spent = !orks_datasheet_psychic_available(board, unit_id(0), 151)
    board.current_round = board.current_round + 1
    let replenished = orks_datasheet_psychic_available(board, unit_id(0), 151)
    board[0].battle_socked = true
    return spent and replenished and !orks_datasheet_psychic_available(board, unit_id(0), 151)

# Beastscent affects the selected passenger's attacks, not the carrier, and
# only against Monster/Vehicle; a1 still grants the disembarking unit's effect.
# https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
fun test_orks17p3_beastscent_selected_cargo_and_one() -> Bool:
    let board = orks17p3_cargo(make_orks_kill_rig(), make_orks_beast_snagga_boyz(1, 9, 0))
    let carrier = find_passenger_carrier(board, board[0][0].identity)
    let sequence = orks_disembark_selection(board, unit_id(0), carrier)
    sequence.use_beastscent(board, true)
    sequence.roll(board, attack_test_die(1))
    return sequence.is_done() and board[0].battle_socked and unit_rule_effect(board, board.embarked_units[0], RuleEffectKind::beastscent) == 1 and unit_rule_effect(board, board[0], RuleEffectKind::beastscent) == 0

# Idol is mandatory and independent of permanent Waaagh! Effigy.
# https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
fun test_orks17p3_stompa_effigy_and_idol_cargo() -> Bool:
    let board = orks17p3_cargo(make_orks_stompa(0), make_orks_runtherd())
    register_orks_passive_rules(board)
    refresh_source_effects(board, TimingWindow::none)
    let carrier = find_passenger_carrier(board, board[0][0].identity)
    let selection = orks_disembark_selection(board, unit_id(0), carrier)
    return selection.is_done() and unit_is_riled_up(board[0]) and unit_is_riled_up(board.embarked_units[0]) and stat_dice_count(board[0][0].deadly_demise) == 2

# Post-shot status requires actual hit provenance; choosing declarations alone
# cannot activate Madcap Artillery, Bust 'Em or Squig Barrage.
# Sources: Orks/{Mek-Gunz,Wartrakks,Rukkatrukk-Squigbuggies}.
fun orks17p3_post_status(Weapon gun) -> Board:
    let board = orks17p2_fixture(orks17p3_guns(2, gun))
    begin_attack_results(board)
    record_attack_hits(board, unit_id(1), 1)
    let sequence = orks_resolve_hit_effects(board, unit_id(0))
    sequence.choose_datasheet_hit_target(board, unit_id(1))
    assert(sequence.is_done(), "post-shoot must complete after one target")
    return board

# Bubblechukka status is on the attacker, so all its targets gain cover.
fun test_orks17p3_madcap_bubblechukka_wobbled() -> Bool:
    let board = orks17p3_post_status(Weapon::orks_mek_gunz_bubblechukka)
    return unit_rule_effect(board, board[1], RuleEffectKind::wobbled) == 1 and unit_has_benefit_of_cover(board, board[1][0], board[0])

# Numeric effects use the ordered characteristic pipeline and correct Ld sign.
fun test_orks17p3_madcap_zapped_leadership() -> Bool:
    let board = orks17p3_post_status(Weapon::orks_mek_gunz_kustom_mega_kannon)
    return board[1][0].effective_leadership() == min(8, board[1][0].profile.leadership() + 1)

fun test_orks17p3_madcap_smashed_movement() -> Bool:
    let board = orks17p3_post_status(Weapon::orks_mek_gunz_smasha_gun)
    return board[1][0].effective_movement(board[1][0].profile.movement()) == max(1, board[1][0].profile.movement() - 2)

fun test_orks17p3_madcap_grounded_persists_to_next_own_turn() -> Bool:
    let board = orks17p3_post_status(Weapon::orks_mek_gunz_traktor_kannon)
    board.turn_serial = board.turn_serial + 1
    board.current_player = true
    refresh_source_effects(board, TimingWindow::turn_start)
    let persists = unit_rule_effect(board, board[1], RuleEffectKind::grounded) == 1
    board.turn_serial = board.turn_serial + 1
    board.current_player = false
    refresh_source_effects(board, TimingWindow::turn_start)
    return persists and unit_rule_effect(board, board[1], RuleEffectKind::grounded) == 0

# Mixed gun NAMES do not activate the common-weapon effect, even after a hit.
fun test_orks17p3_madcap_mixed_names_or_no_hits_do_nothing() -> Bool:
    let equipment : OrksMekGuns
    equipment.append(Weapon::orks_mek_gunz_smasha_gun)
    equipment.append(Weapon::orks_mek_gunz_bubblechukka)
    let board = orks17p2_fixture(make_orks_mek_gunz(equipment, 0))
    begin_attack_results(board)
    record_attack_hits(board, unit_id(1), 1)
    let mixed = orks_resolve_hit_effects(board, unit_id(0))
    board[0] = orks17p3_guns(1, Weapon::orks_mek_gunz_smasha_gun)
    board.identify_units()
    begin_attack_results(board)
    let no_hits = orks_resolve_hit_effects(board, unit_id(0))
    return mixed.is_done() and no_hits.is_done() and board.source_effects.empty()

# Hits from Sawn-off Shotgun cannot count as hits from Squig Launchas, even
# when another ranged profile generated an equal final attack result.
fun test_orks17p3_squig_barrage_named_hit_provenance() -> Bool:
    let board = orks17p2_fixture(make_orks_rukkatrukk_squigbuggies(1))
    begin_attack_results(board)
    board.attack_info.squig_launcha_weapon = false
    record_attack_hits(board, unit_id(1), 2)
    let shotgun = !orks_hit_effect_target_valid(board, unit_id(0), unit_id(1))
    board.attack_info.squig_launcha_weapon = true
    record_attack_hits(board, unit_id(1), 1)
    let launchas = orks_hit_effect_target_valid(board, unit_id(0), unit_id(1))
    let sequence = orks_resolve_hit_effects(board, unit_id(0))
    sequence.choose_datasheet_hit_target(board, unit_id(1))
    let effects = unit_rule_effect(board, board[1], RuleEffectKind::covered_squigs) == 1
    board[1][0].keywords.append(Keyword::monster)
    return shotgun and launchas and effects and !orks_hit_effect_target_valid(board, unit_id(0), unit_id(1))

# Busted grants Lethal only to friendly Speed Freeks attacks at that target.
fun test_orks17p3_wartrakk_busted_target_and_attacker_keywords() -> Bool:
    let board = orks17p2_fixture(make_orks_wartrakks(1))
    begin_attack_results(board)
    record_attack_hits(board, unit_id(1), 1)
    let sequence = orks_resolve_hit_effects(board, unit_id(0))
    sequence.choose_datasheet_hit_target(board, unit_id(1))
    let speed = orks17p2_info(board, 1)
    board[0][0].keywords.clear()
    let ordinary = orks17p2_info(board, 1)
    return sequence.is_done() and speed.has_weapon_rule(board, WeaponRuleKind::letal_hits) and !ordinary.has_weapon_rule(board, WeaponRuleKind::letal_hits)

# Full Throttle has a mandatory selection and persists through reserves until
# next own Command. Turbo waives Advance/Fall Back charge restrictions only.
# https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
fun test_orks17p3_full_throttle_turbo_duration() -> Bool:
    let board = orks17p2_fixture(make_orks_wazdakka_gutsmek())
    board.begin_phase(BattlePhase::command)
    let sequence = orks_datasheet_window(board, orks17p2_source(board, 145))
    sequence.choose_shokka_engine(board, OrksEngine::turbo)
    let turbo = orks_move_charge_permission(board, board[0], MovementKind::advance) and orks_move_charge_permission(board, board[0], MovementKind::ordered_retreat)
    board.begin_phase(BattlePhase::movement)
    board.turn_serial = board.turn_serial + 2
    refresh_source_effects(board, TimingWindow::turn_start)
    let before_command = unit_rule_effect(board, board[0], RuleEffectKind::turbo_engine) == 1
    refresh_source_effects(board, TimingWindow::command_start)
    return sequence.is_done() and turbo and before_command and unit_rule_effect(board, board[0], RuleEffectKind::turbo_engine) == 0

# Shokk Attack Engine preserves both unit/model identities on withdrawal.
fun test_orks17p3_full_throttle_shokk_reserves() -> Bool:
    let board = orks17p2_fixture(make_orks_wazdakka_gutsmek())
    board[1][0].position = board_position(35, 20)
    board.begin_phase(BattlePhase::command)
    let identity = board[0].identity
    let sequence = orks_datasheet_window(board, orks17p2_source(board, 145))
    sequence.choose_shokka_engine(board, OrksEngine::shokk)
    sequence.use_shokk_attack_engine(board, true)
    return sequence.is_done() and board[0].retired and board.reserve_units[0].identity == identity and unit_rule_effect(board, board.reserve_units[0], RuleEffectKind::shokk_engine) == 1

# Pulse Jet is D6+18, traverse-all with horizontal costs and mandatory
# unengaged finish; it forbids charges/actions and grants incoming-1hit.
# Source: Orks index Special Move Types/PULSE JET MOVE; Wazdakka Pulse Jet.
fun test_orks17p3_pulse_jet_actual_move_restrictions_and_defence() -> Bool:
    let board = orks17p2_fixture(make_orks_wazdakka_gutsmek())
    board[1][0].position = board_position(35, 20)
    board.begin_phase(BattlePhase::command)
    let engine = orks_datasheet_window(board, orks17p2_source(board, 145))
    engine.choose_shokka_engine(board, OrksEngine::pulse)
    board.begin_phase(BattlePhase::movement)
    let sequence = movement(board, unit_id(0), false)
    sequence.pulse_jet_move(board)
    sequence.roll(board, attack_test_die(6))
    let legal = can sequence.move_to(board, board_position(28, 5))
    sequence.move_to(board, board_position(28, 5))
    let policy = movement_policy(board[0], board[0][0], MovementKind::pulse_jet, false)
    return sequence.is_done() and legal and board[0][0].position.x == 28 and !board[0].can_charge and !action_start_valid(board, unit_id(0), false) and policy.traverse_enemies and policy.traverse_terrain and policy.free_vertical_movement and unit_rule_effect(board, board[0], RuleEffectKind::pulse_defence) == 1

# Nazdreg's free reaction does not pay CP or consume a Gretchin/Kopta card,
# uses the fixed5 option only while riled, and shares a per-army phase token.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
fun test_orks17p3_supreme_kunnin_free_fixed_five_shared_limit() -> Bool:
    let board = orks17p2_fixture(make_orks_nazdreg())
    board[1][0].position = board_position(12, 5)
    board.current_player = true
    board.begin_phase(BattlePhase::movement)
    grant_orks_payload(board, unit_id(0), unit_id(0), 165, riled_up_grant(), SourceDuration::turn)
    let eligible = orks_supreme_kunnin_valid(board, unit_id(1), unit_id(0))
    let sequence = select_orks_enemy_move_reaction(board, unit_id(1))
    sequence.choose_supreme_kunnin_unit(board, unit_id(0))
    sequence.choose_supreme_fixed_five(board, true)
    return eligible and sequence.is_done() and sequence.available and sequence.distance == 5 and !orks_supreme_kunnin_valid(board, unit_id(1), unit_id(0)) and board.command_points[0] == 0

# Reactive Trukk exit uses RAPID even when its carrier has not moved this
# phase, preserves links/owner and cannot be claimed by the current player.
# https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
fun test_orks17p3_pilin_out_actual_rapid_exit_and_owner() -> Bool:
    let board = orks17p3_cargo(make_orks_trukk(0, false, Weapon::none), make_orks_runtherd())
    board[1][0].position = board_position(14, 5)
    board.current_player = true
    board.current_decision_maker = true
    let sequence = orks_trukk_reactions(board, unit_id(1))
    sequence.choose_pilin_out_passenger(board, unit_id(0))
    let rapid = can sequence.confirm_disembark_mode(board, DisembarkMode::rapid)
    sequence.confirm_disembark_mode(board, DisembarkMode::rapid)
    sequence.disembark_at(board, board_position(9, 5))
    return sequence.is_done() and rapid and board.embarked_units.empty() and board.current_decision_maker and board.units.size() == 3 and board[2].history.disembarked_this_turn and !board[2].can_charge

# Same-phase embarkation cannot be evaded with reactive exits.
fun test_orks17p3_pilin_out_same_phase_embark_and_owner_gates() -> Bool:
    let board = orks17p3_cargo(make_orks_trukk(0, false, Weapon::none), make_orks_runtherd())
    board[1][0].position = board_position(14, 5)
    let handled : EntityIdentity[32]
    let own_turn = !orks_trukk_passenger_valid(board, unit_id(1), unit_id(0), handled)
    board.current_player = true
    board.embarked_units[0].history.embarked_phase = board.phase_serial.value + 1
    return own_turn and !orks_trukk_passenger_valid(board, unit_id(1), unit_id(0), handled)

# Split keeps every original model once and separates its two tokens; starting
# strength is5 for both, and only the original ten-model unit may split.
# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
fun test_orks17p3_kommando_split_models_tokens_and_starting_strength() -> Bool:
    let board : Board
    board.reserve_units.append(orks17p3_kommandos())
    board.identify_units()
    let first : Bool[10]
    for index in range(5):
        first[index] = true
    split_orks_kommandos(board, unit_id(0), first, true)
    let valid = board.reserve_units.size() == 2 and board.reserve_units[0].starting_strenght == 5 and board.reserve_units[1].starting_strenght == 5 and board.reserve_units[0].has_ability(AbilityKind::bomb_squig) and !board.reserve_units[0].has_ability(AbilityKind::found_em) and !board.reserve_units[1].has_ability(AbilityKind::bomb_squig) and board.reserve_units[1].has_ability(AbilityKind::found_em)
    return valid and !board.reserve_units[0].has_ability(AbilityKind::taktikal_know_wotz) and !board.reserve_units[1].has_ability(AbilityKind::taktikal_know_wotz) and valid_state_foundations(board)

# Actual formation decisions select5 distinct models and which half gets the
# bomb; the choice precedes attachments and never creates a third unit.
fun test_orks17p3_kommando_split_action_decisions() -> Bool:
    let board : Board
    board.reserve_units.append(orks17p3_kommandos())
    board.identify_units()
    let sequence = orks_kommando_formations(board)
    sequence.split_kommando_unit(board, true)
    for index in range(5):
        sequence.choose_split_kommando(board, damage_test_model(index))
    sequence.choose_split_bomb_squig(board, false)
    return sequence.is_done() and board.reserve_units.size() == 2 and board.reserve_units[1].has_ability(AbilityKind::bomb_squig) and board.reserve_units[0].has_ability(AbilityKind::found_em)

# Verify actual keyword matching, not just that Lethal Hits exists.
# Current weapon rows' non-Monster/Vehicle clauses; appendix02.05.01.
fun orks17p3_lethal_excludes(Weapon weapon) -> Bool:
    let rules = weapon.rules()
    let infantry : Unit
    let model : Model
    model.keywords.append(Keyword::infantry)
    infantry.models.append(model)
    let monster = infantry
    monster[0].keywords.append(Keyword::monster)
    let vehicle = infantry
    vehicle[0].keywords.append(Keyword::vehicle)
    for index in range(rules.size()):
        if rules[index].kind == WeaponRuleKind::letal_hits:
            return unit_matches_keywords(infantry, rules[index].target_condition) and !unit_matches_keywords(monster, rules[index].target_condition) and !unit_matches_keywords(vehicle, rules[index].target_condition)
    return false

# All27 printed conditional Lethal rules, including duplicated weapon families.
fun test_orks17p3_all_printed_lethal_exclusions() -> Bool:
    return orks17p3_lethal_excludes(Weapon::orks_battlewagon_big_shoota) and orks17p3_lethal_excludes(Weapon::orks_big_ed_bossbunka_big_shoota) and orks17p3_lethal_excludes(Weapon::orks_blitza_bommer_big_shoota) and orks17p3_lethal_excludes(Weapon::orks_blitza_bommer_dual_supa_shoota) and orks17p3_lethal_excludes(Weapon::orks_boss_snikrot_slugga) and orks17p3_lethal_excludes(Weapon::orks_burna_bommer_dual_big_shoota) and orks17p3_lethal_excludes(Weapon::orks_burna_bommer_dual_supa_shoota) and orks17p3_lethal_excludes(Weapon::orks_dakkajet_dual_supa_shoota) and orks17p3_lethal_excludes(Weapon::orks_deffkilla_wartrike_boomstikks) and orks17p3_lethal_excludes(Weapon::orks_deffkoptas_slugga) and orks17p3_lethal_excludes(Weapon::orks_ghazghkull_thraka_mork_s_roar_aimed) and orks17p3_lethal_excludes(Weapon::orks_gorkanaut_deffstorm_mega_shoota_aimed) and orks17p3_lethal_excludes(Weapon::orks_gorkanaut_dual_big_shoota) and orks17p3_lethal_excludes(Weapon::orks_gunwagon_big_shoota) and orks17p3_lethal_excludes(Weapon::orks_kommandos_kustom_shoota) and orks17p3_lethal_excludes(Weapon::orks_kommandos_slugga) and orks17p3_lethal_excludes(Weapon::orks_morkanaut_dual_big_shoota) and orks17p3_lethal_excludes(Weapon::orks_nazdreg_kustom_blasta_x_shoota) and orks17p3_lethal_excludes(Weapon::orks_rukkatrukk_squigbuggies_sawn_off_shotgun) and orks17p3_lethal_excludes(Weapon::orks_stompa_big_shoota) and orks17p3_lethal_excludes(Weapon::orks_stompa_supa_gatler_aimed) and orks17p3_lethal_excludes(Weapon::orks_trukk_dual_big_shoota) and orks17p3_lethal_excludes(Weapon::orks_warbuggies_extra_dakka) and orks17p3_lethal_excludes(Weapon::orks_warbuggies_mek_speshul_aimed) and orks17p3_lethal_excludes(Weapon::orks_wartrakks_kustom_shoota) and orks17p3_lethal_excludes(Weapon::orks_wazbom_blastajet_dual_supa_shoota) and orks17p3_lethal_excludes(Weapon::orks_wazdakka_gutsmek_psyko_gatler)

# Core p10/P10-06: M- means setup only. Other move types/rotations must not
# accidentally move a fortification using a charge/surge replacement budget.
fun test_orks17p3_immobile_cannot_charge_surge_or_pile_in() -> Bool:
    let board = orks17p2_fixture(make_orks_big_ed_bossbunka(0, 0))
    board.begin_phase(BattlePhase::charge)
    let policy : MovementGeometryPolicy
    policy.traverse_enemies = true
    policy.traverse_terrain = true
    let start = board[0][0].geometry_position()
    let finish = geometry_point(6 * MICROMETRES_PER_INCH, 5 * MICROMETRES_PER_INCH, 0)
    return !charge_source_valid(board, unit_id(0), false) and !model_segment_valid(board, board[0], board[0][0], start, finish, policy) and melee_model_locked(board, board[0][0], board[0], MeleeMoveKind::pile_in)

# Each current card is actually accepted through the public muster child;
# this is stronger than a factory allowlist or a source-enum membership test.
fun orks17q_muster_card(OrksDatasheet sheet) -> Bool:
    let board : Board
    board.armies[0].faction = ArmyFaction::orks
    let sequence = muster_orks_unit(board, false, sheet)
    if !(can sequence.add_orks_muster_unit(board)):
        return false
    sequence.add_orks_muster_unit(board)
    return sequence.is_done() and board.reserve_units.size() == 1 and board.reserve_units[0][0].datasheet.value == sheet.value and board.reserve_units[0].models.size() == orks_muster_min(sheet) and valid_state_foundations(board)

# Source: Orks/bannernob; public source-backed roster adapter.
fun test_orks17q_muster_bannernob() -> Bool:
    return orks17q_muster_card(OrksDatasheet::bannernob)

# Source: Orks/beastboss; public source-backed roster adapter.
fun test_orks17q_muster_beastboss() -> Bool:
    return orks17q_muster_card(OrksDatasheet::beastboss)

# Source: Orks/big_mek_dakkarig; public source-backed roster adapter.
fun test_orks17q_muster_big_mek_dakkarig() -> Bool:
    return orks17q_muster_card(OrksDatasheet::big_mek_dakkarig)

# Source: Orks/big_mek_with_shokk_attack_gun; public source-backed roster adapter.
fun test_orks17q_muster_big_mek_with_shokk_attack_gun() -> Bool:
    return orks17q_muster_card(OrksDatasheet::big_mek_with_shokk_attack_gun)

# Source: Orks/bigboss; public source-backed roster adapter.
fun test_orks17q_muster_bigboss() -> Bool:
    return orks17q_muster_card(OrksDatasheet::bigboss)

# Source: Orks/blitza_bommer; public source-backed roster adapter.
fun test_orks17q_muster_blitza_bommer() -> Bool:
    return orks17q_muster_card(OrksDatasheet::blitza_bommer)

# Source: Orks/boss_snikrot; public source-backed roster adapter.
fun test_orks17q_muster_boss_snikrot() -> Bool:
    return orks17q_muster_card(OrksDatasheet::boss_snikrot)

# Source: Orks/deffkilla_wartrike; public source-backed roster adapter.
fun test_orks17q_muster_deffkilla_wartrike() -> Bool:
    return orks17q_muster_card(OrksDatasheet::deffkilla_wartrike)

# Source: Orks/ghazghkull_thraka; public source-backed roster adapter.
fun test_orks17q_muster_ghazghkull_thraka() -> Bool:
    return orks17q_muster_card(OrksDatasheet::ghazghkull_thraka)

# Source: Orks/gorkanaut; public source-backed roster adapter.
fun test_orks17q_muster_gorkanaut() -> Bool:
    return orks17q_muster_card(OrksDatasheet::gorkanaut)

# Source: Orks/hunta_rig; public source-backed roster adapter.
fun test_orks17q_muster_hunta_rig() -> Bool:
    return orks17q_muster_card(OrksDatasheet::hunta_rig)

# Source: Orks/kill_rig; public source-backed roster adapter.
fun test_orks17q_muster_kill_rig() -> Bool:
    return orks17q_muster_card(OrksDatasheet::kill_rig)

# Source: Orks/mek; public source-backed roster adapter.
fun test_orks17q_muster_mek() -> Bool:
    return orks17q_muster_card(OrksDatasheet::mek)

# Source: Orks/morkanaut; public source-backed roster adapter.
fun test_orks17q_muster_morkanaut() -> Bool:
    return orks17q_muster_card(OrksDatasheet::morkanaut)

# Source: Orks/mozrog_skragbad; public source-backed roster adapter.
fun test_orks17q_muster_mozrog_skragbad() -> Bool:
    return orks17q_muster_card(OrksDatasheet::mozrog_skragbad)

# Source: Orks/nazdreg; public source-backed roster adapter.
fun test_orks17q_muster_nazdreg() -> Bool:
    return orks17q_muster_card(OrksDatasheet::nazdreg)

# Source: Orks/painboss; public source-backed roster adapter.
fun test_orks17q_muster_painboss() -> Bool:
    return orks17q_muster_card(OrksDatasheet::painboss)

# Source: Orks/painboy; public source-backed roster adapter.
fun test_orks17q_muster_painboy() -> Bool:
    return orks17q_muster_card(OrksDatasheet::painboy)

# Source: Orks/runtherd; public source-backed roster adapter.
fun test_orks17q_muster_runtherd() -> Bool:
    return orks17q_muster_card(OrksDatasheet::runtherd)

# Source: Orks/warboss_in_mega_armour; public source-backed roster adapter.
fun test_orks17q_muster_warboss_in_mega_armour() -> Bool:
    return orks17q_muster_card(OrksDatasheet::warboss_in_mega_armour)

# Source: Orks/wazdakka_gutsmek; public source-backed roster adapter.
fun test_orks17q_muster_wazdakka_gutsmek() -> Bool:
    return orks17q_muster_card(OrksDatasheet::wazdakka_gutsmek)

# Source: Orks/weirdboy; public source-backed roster adapter.
fun test_orks17q_muster_weirdboy() -> Bool:
    return orks17q_muster_card(OrksDatasheet::weirdboy)

# Source: Orks/zodgrod_wortsnagga; public source-backed roster adapter.
fun test_orks17q_muster_zodgrod_wortsnagga() -> Bool:
    return orks17q_muster_card(OrksDatasheet::zodgrod_wortsnagga)

# Source: Orks/battlewagon; public source-backed roster adapter.
fun test_orks17q_muster_battlewagon() -> Bool:
    return orks17q_muster_card(OrksDatasheet::battlewagon)

# Source: Orks/big_ed_bossbunka; public source-backed roster adapter.
fun test_orks17q_muster_big_ed_bossbunka() -> Bool:
    return orks17q_muster_card(OrksDatasheet::big_ed_bossbunka)

# Source: Orks/gunwagon; public source-backed roster adapter.
fun test_orks17q_muster_gunwagon() -> Bool:
    return orks17q_muster_card(OrksDatasheet::gunwagon)

# Source: Orks/big_mek; public source-backed roster adapter.
fun test_orks17q_muster_big_mek() -> Bool:
    return orks17q_muster_card(OrksDatasheet::big_mek)

# Source: Orks/big_mek_in_mega_armour; public source-backed roster adapter.
fun test_orks17q_muster_big_mek_in_mega_armour() -> Bool:
    return orks17q_muster_card(OrksDatasheet::big_mek_in_mega_armour)

# Source: Orks/beastboss_on_squigosaur; public source-backed roster adapter.
fun test_orks17q_muster_beastboss_on_squigosaur() -> Bool:
    return orks17q_muster_card(OrksDatasheet::beastboss_on_squigosaur)

# Source: Orks/burna_bommer; public source-backed roster adapter.
fun test_orks17q_muster_burna_bommer() -> Bool:
    return orks17q_muster_card(OrksDatasheet::burna_bommer)

# Source: Orks/dakkajet; public source-backed roster adapter.
fun test_orks17q_muster_dakkajet() -> Bool:
    return orks17q_muster_card(OrksDatasheet::dakkajet)

# Source: Orks/deff_dread; public source-backed roster adapter.
fun test_orks17q_muster_deff_dread() -> Bool:
    return orks17q_muster_card(OrksDatasheet::deff_dread)

# Source: Orks/stompa; public source-backed roster adapter.
fun test_orks17q_muster_stompa() -> Bool:
    return orks17q_muster_card(OrksDatasheet::stompa)

# Source: Orks/trukk; public source-backed roster adapter.
fun test_orks17q_muster_trukk() -> Bool:
    return orks17q_muster_card(OrksDatasheet::trukk)

# Source: Orks/warboss; public source-backed roster adapter.
fun test_orks17q_muster_warboss() -> Bool:
    return orks17q_muster_card(OrksDatasheet::warboss)

# Source: Orks/wazbom_blastajet; public source-backed roster adapter.
fun test_orks17q_muster_wazbom_blastajet() -> Bool:
    return orks17q_muster_card(OrksDatasheet::wazbom_blastajet)

# Source: Orks/beast_snagga_boyz; public source-backed roster adapter.
fun test_orks17q_muster_beast_snagga_boyz() -> Bool:
    return orks17q_muster_card(OrksDatasheet::beast_snagga_boyz)

# Source: Orks/squighog_boyz; public source-backed roster adapter.
fun test_orks17q_muster_squighog_boyz() -> Bool:
    return orks17q_muster_card(OrksDatasheet::squighog_boyz)

# Source: Orks/stormboyz; public source-backed roster adapter.
fun test_orks17q_muster_stormboyz() -> Bool:
    return orks17q_muster_card(OrksDatasheet::stormboyz)

# Source: Orks/warbikers; public source-backed roster adapter.
fun test_orks17q_muster_warbikers() -> Bool:
    return orks17q_muster_card(OrksDatasheet::warbikers)

# Source: Orks/killa_kans; public source-backed roster adapter.
fun test_orks17q_muster_killa_kans() -> Bool:
    return orks17q_muster_card(OrksDatasheet::killa_kans)

# Source: Orks/flash_gitz; public source-backed roster adapter.
fun test_orks17q_muster_flash_gitz() -> Bool:
    return orks17q_muster_card(OrksDatasheet::flash_gitz)

# Source: Orks/gretchin; public source-backed roster adapter.
fun test_orks17q_muster_gretchin() -> Bool:
    return orks17q_muster_card(OrksDatasheet::gretchin)

# Source: Orks/wartrakks; public source-backed roster adapter.
fun test_orks17q_muster_wartrakks() -> Bool:
    return orks17q_muster_card(OrksDatasheet::wartrakks)

# Source: Orks/rukkatrukk_squigbuggies; public source-backed roster adapter.
fun test_orks17q_muster_rukkatrukk_squigbuggies() -> Bool:
    return orks17q_muster_card(OrksDatasheet::rukkatrukk_squigbuggies)

# Source: Orks/breaka_boyz; public source-backed roster adapter.
fun test_orks17q_muster_breaka_boyz() -> Bool:
    return orks17q_muster_card(OrksDatasheet::breaka_boyz)

# Source: Orks/tankbustas; public source-backed roster adapter.
fun test_orks17q_muster_tankbustas() -> Bool:
    return orks17q_muster_card(OrksDatasheet::tankbustas)

# Source: Orks/boyz; public source-backed roster adapter.
fun test_orks17q_muster_boyz() -> Bool:
    return orks17q_muster_card(OrksDatasheet::boyz)

# Source: Orks/nobz; public source-backed roster adapter.
fun test_orks17q_muster_nobz() -> Bool:
    return orks17q_muster_card(OrksDatasheet::nobz)

# Source: Orks/meganobz; public source-backed roster adapter.
fun test_orks17q_muster_meganobz() -> Bool:
    return orks17q_muster_card(OrksDatasheet::meganobz)

# Source: Orks/deffkoptas; public source-backed roster adapter.
fun test_orks17q_muster_deffkoptas() -> Bool:
    return orks17q_muster_card(OrksDatasheet::deffkoptas)

# Source: Orks/warbuggies; public source-backed roster adapter.
fun test_orks17q_muster_warbuggies() -> Bool:
    return orks17q_muster_card(OrksDatasheet::warbuggies)

# Source: Orks/mek_gunz; public source-backed roster adapter.
fun test_orks17q_muster_mek_gunz() -> Bool:
    return orks17q_muster_card(OrksDatasheet::mek_gunz)

# Source: Orks/kommandos; public source-backed roster adapter.
fun test_orks17q_muster_kommandos() -> Bool:
    return orks17q_muster_card(OrksDatasheet::kommandos)

# Every declared model count, including intermediate unpriced sizes, is
# reachable through the editor field path and accepted by the source factory.
fun test_orks17q_all_composition_counts_reachable() -> Bool:
    let valid = true
    let sheet : OrksDatasheet
    for code in range(68):
        sheet.value = code
        if !orks_muster_included(sheet):
            continue
        let initial = orks_muster_draft(sheet)
        if orks_muster_min(sheet) == orks_muster_max(sheet):
            continue
        let count = orks_muster_min(sheet)
        while count <= orks_muster_max(sheet):
            valid = valid and orks_muster_value_valid(initial, 0, OrksMusterField::models, count)
            let draft = initial
            assign_orks_muster_value(draft, 0, OrksMusterField::models, count)
            let unit = make_orks_muster_unit(draft)
            valid = valid and unit.models.size() == count
            count = count + 1
    return valid

# Two Nobz remain legal with mixed guns; paired replacement is one atomic
# choice, so it cannot leave a forbidden ranged weapon (Orks/Boyz).
fun test_orks17q_muster_boyz_roles_paired_and_quotas() -> Bool:
    let draft = orks_muster_draft(OrksDatasheet::boyz)
    assign_orks_muster_value(draft, 0, OrksMusterField::models, 20)
    let both_nobs = draft.nobs.value == 2 and orks_muster_valid(draft)
    assign_orks_muster_value(draft, 0, OrksMusterField::primary, 2)
    let paired = draft.equipment[0].secondary.value == 3 and orks_muster_valid(draft)
    assign_orks_muster_value(draft, 2, OrksMusterField::primary, 1)
    assign_orks_muster_value(draft, 3, OrksMusterField::primary, 1)
    let quota = !orks_muster_value_valid(draft, 4, OrksMusterField::primary, 1)
    let unit = make_orks_muster_unit(draft)
    return both_nobs and paired and quota and unit.models.size() == 20 and unit[0].profile.value == Profile::orks_boyz_nob.value

# Distinct restricted Nob weapons each retain their own per-five quota.
fun test_orks17q_muster_nobz_quota_is_atomic() -> Bool:
    let draft = orks_muster_draft(OrksDatasheet::nobz)
    assign_orks_muster_value(draft, 0, OrksMusterField::primary, 2)
    return orks_muster_valid(draft) and !orks_muster_value_valid(draft, 1, OrksMusterField::primary, 2) and draft.equipment[1].primary.value == 0 and orks_muster_value_valid(draft, 1, OrksMusterField::primary, 3)

# Kommandos' independent extra slots may share a Boy, but cannot exceed the
# source's one/one/one/two quotas. Nob replacements remain independent.
fun test_orks17q_muster_kommando_independent_slots() -> Bool:
    let draft = orks_muster_draft(OrksDatasheet::kommandos)
    assign_orks_muster_value(draft, 1, OrksMusterField::extra_one, 1)
    assign_orks_muster_value(draft, 1, OrksMusterField::extra_two, 1)
    assign_orks_muster_value(draft, 1, OrksMusterField::extra_three, 1)
    assign_orks_muster_value(draft, 1, OrksMusterField::extra_four, 1)
    let unit = make_orks_muster_unit(draft)
    return unit[1].weapons.size() == 6 and !orks_muster_value_valid(draft, 2, OrksMusterField::extra_one, 1) and orks_muster_value_valid(draft, 2, OrksMusterField::extra_four, 1)

# Draft editing checks individual Koptas and each gun's independent type;
# these choices affect real weapon identities, not display-only metadata.
fun test_orks17q_muster_vehicle_individual_options() -> Bool:
    let koptas = orks_muster_draft(OrksDatasheet::deffkoptas)
    assign_orks_muster_value(koptas, 1, OrksMusterField::extra_one, 1)
    let kopta_quota = !orks_muster_value_valid(koptas, 2, OrksMusterField::extra_one, 1)
    let guns = orks_muster_draft(OrksDatasheet::mek_gunz)
    assign_orks_muster_value(guns, 0, OrksMusterField::models, 3)
    assign_orks_muster_value(guns, 1, OrksMusterField::primary, 1)
    assign_orks_muster_value(guns, 2, OrksMusterField::primary, 3)
    let unit = make_orks_muster_unit(guns)
    return kopta_quota and unit.models.size() == 3 and unit[1].weapons[0].profile.value == Weapon::orks_mek_gunz_bubblechukka.value and unit[2].weapons[0].profile.value == Weapon::orks_mek_gunz_traktor_kannon.value

# Cancelled drafts consume neither roster capacity nor persistent identities.
fun test_orks17q_muster_cancel_and_invalid_value() -> Bool:
    let board : Board
    let sequence = muster_orks_unit(board, false, OrksDatasheet::deff_dread)
    let field : OrksMusterField
    field = OrksMusterField::primary
    sequence.choose_orks_muster_field(board, field)
    let value : OrksMusterValue
    value = 1
    let no_skorcha_first = !(can sequence.choose_orks_muster_value(board, value))
    value = 2
    sequence.choose_orks_muster_value(board, value)
    sequence.cancel_orks_muster_unit(board)
    let untouched = board.next_identity.value == 0
    board.next_identity = MAX_ENTITY_IDENTITIES
    let full_identity_domain = !orks_muster_add_valid(board, false, orks_muster_draft(OrksDatasheet::warboss))
    return no_skorcha_first and sequence.is_done() and board.reserve_units.empty() and untouched and full_identity_domain

# Public finish requires a Character for Warlord selection; later opposite
# army decisions cannot be skipped or addressed through the wrong bank.
fun test_orks17q_muster_finish_requires_character_and_owns_roster() -> Bool:
    let board : Board
    board.armies[0].faction = ArmyFaction::orks
    let roster = build_orks_roster(board, false)
    let empty = !(can roster.finish_orks_roster(board))
    roster.choose_orks_muster_unit(board, OrksDatasheet::beastboss)
    roster.add_orks_muster_unit(board)
    let ready = can roster.finish_orks_roster(board)
    roster.finish_orks_roster(board)
    return empty and ready and roster.is_done() and !board.current_decision_maker and board.reserve_units.size() == 1

# Explicit user3/6 limits apply before committing a fourth unit; selected
# force dispositions participate without repeatedly registering all sources.
fun test_orks17q_muster_copy_limits_and_battleline_disposition() -> Bool:
    let board : Board
    board.armies[0].faction = ArmyFaction::orks
    let draft = orks_muster_draft(OrksDatasheet::gretchin)
    for index in range(3):
        board.reserve_units.append(make_orks_muster_unit(draft))
    let ordinary = !orks_muster_add_valid(board, false, draft)
    let recorded = board.armies[0].record_detachment(OrksDetachment::runt_swarm)
    let more = orks_muster_add_valid(board, false, draft)
    for extra_index in range(3):
        board.reserve_units.append(make_orks_muster_unit(draft))
    return ordinary and recorded and more and !orks_muster_add_valid(board, false, draft) and muster_copies_valid(board)

# All excluded identities stay unavailable through the actual public selector.
fun test_orks17q_muster_excludes_legends_and_forge_world() -> Bool:
    let board : Board
    board.armies[0].faction = ArmyFaction::orks
    let roster = build_orks_roster(board, false)
    return !(can roster.choose_orks_muster_unit(board, OrksDatasheet::gargantuan_squiggoth)) and !(can roster.choose_orks_muster_unit(board, OrksDatasheet::boss_zagstruk)) and !(can roster.choose_orks_muster_unit(board, OrksDatasheet::unknown))

# User ruling2026-10-15 and core Coherency FAQ: multiple nearby groups cannot replace one contiguous
# unit, even when every model has a neighbour and all pairs are within9in.
fun test_orks17q_coherency_rejects_disconnected_pairs() -> Bool:
    let unit = make_infernus_squad()
    unit.models.resize(4)
    unit[0].position = board_position(5, 5)
    unit[1].position = board_position(6, 5)
    unit[2].position = board_position(11, 5)
    unit[3].position = board_position(12, 5)
    let disconnected = !unit.is_coherent()
    unit[2].position = board_position(8, 5)
    unit[3].position = board_position(10, 5)
    return disconnected and unit.is_coherent()

# A retained destroyed model cannot bridge living groups (core pp14/87).
fun test_orks17q_coherency_dead_bridge_does_not_connect() -> Bool:
    let unit = make_infernus_squad()
    unit[0].position = board_position(5, 5)
    unit[1].position = board_position(6, 5)
    unit[2].position = board_position(8, 5)
    unit[3].position = board_position(10, 5)
    unit[4].position = board_position(11, 5)
    let before = unit.is_coherent()
    unit[2].state = ModelState::fight_on_death
    return before and !unit.is_coherent()

# Source-specific hit provenance must remain a subset of the attack's actual
# hits across saves (Orks/Rukkatrukk-Squigbuggies, Squig Barrage).
fun test_orks17q_saved_squig_hits_cannot_exceed_total() -> Bool:
    let board = orks17p2_fixture(make_orks_rukkatrukk_squigbuggies(1))
    begin_attack_results(board)
    ref record = attack_result_record(board, board[1].identity)
    record.successful_hits = 1
    record.tagged_hits[AttackHitTag::squig_launcha.value] = 2
    let invalid = !valid_attack_results(board)
    record.tagged_hits[AttackHitTag::squig_launcha.value] = 1
    return invalid and valid_attack_results(board)

# Both public custom rosters, pending equipment save/restore, actual Warlord
# handoff and attachment-source identities share the production root.
fun test_orks17q_public_rosters_pending_save_and_handoff() -> Bool:
    let game = play()
    game.pick_custom_orks()
    game.choose_orks_detachment(OrksDetachment::war_horde)
    game.finish_detachment_selection()
    let cannot_finish_empty = !can game.finish_orks_roster()
    game.choose_orks_muster_unit(OrksDatasheet::warboss)
    game.choose_orks_muster_field(OrksMusterField::primary)
    let restored = play()
    let saved = set_state(restored, to_string(game))
    let gun : OrksMusterValue
    gun = 2
    restored.choose_orks_muster_value(gun)
    restored.add_orks_muster_unit()
    restored.choose_orks_muster_unit(OrksDatasheet::boyz)
    restored.add_orks_muster_unit()
    restored.choose_orks_muster_unit(OrksDatasheet::trukk)
    restored.add_orks_muster_unit()
    restored.finish_orks_roster()
    if can restored.finish_orks_options():
        restored.finish_orks_options()
    restored.choose_warlord_unit(unit_id(0))
    restored.choose_warlord_model(damage_test_model(0))
    let handed_off = get_current_player(restored) == 1
    restored.pick_custom_orks()
    restored.finish_detachment_selection()
    restored.choose_orks_muster_unit(OrksDatasheet::boss_snikrot)
    restored.add_orks_muster_unit()
    restored.choose_orks_muster_unit(OrksDatasheet::kommandos)
    restored.add_orks_muster_unit()
    restored.finish_orks_roster()
    if can restored.finish_orks_options():
        restored.finish_orks_options()
    restored.choose_warlord_unit(unit_id(3))
    restored.choose_warlord_model(damage_test_model(0))
    return cannot_finish_empty and saved and handed_off and restored.board.reserve_units.size() == 5 and !restored.board.reserve_units[0].owned_by_player1 and restored.board.reserve_units[3].owned_by_player1 and valid_state_foundations(restored.board) and can restored.split_kommando_unit(false)

# Shared-rule fixtures vary storage only; real unit identity, owners and
# explicit passenger permissions remain intact (appendix01.02.04).
fun orks17q_bank_fixture(SourceBank bank, OrksDetachment package) -> Board:
    let board = orks17all_fixture(package)
    board[0][0].keywords.append(Keyword::psyker)
    board[0].psyker_level = 1
    if bank.value == SourceBank::reserves.value:
        let moved = reposition_unit(board, unit_id(0))
        assert(moved, "bank fixture transfer failed")
    if bank.value == SourceBank::embarked.value:
        board[1].owned_by_player1 = false
        board[1][0].keywords.append(Keyword::transport)
        board[1][0].transport_permissions_known = true
        board[1][0].transport_capacity = 20
        board[1][0].permitted_passenger_keywords.append(Keyword::infantry)
        transfer_embarked_unit(board, unit_id(0), board[1][0].identity)
    return board

# Wurrband Visions has one roll, budget, shock and phase effect in all banks.
# A final1 does not cancel the power; the caller's decision owner is restored.
fun test_orks17q_shared_visions_all_banks() -> Bool:
    let bank : SourceBank
    let valid = true
    for index in range(3):
        bank.value = index
        let board = orks17q_bank_fixture(bank, OrksDetachment::wurrband)
        board.begin_phase(BattlePhase::fight)
        board.current_decision_maker = true
        ref unit = source_bank_unit(board, bank, 0)
        let offered = orks_psychic_unit_available(board, unit, true)
        let psychic = use_orks_psychic(board, unit.identity, true)
        psychic.roll(board, attack_test_die(1))
        valid = valid and offered and psychic.is_done() and unit.battle_socked and fight_first_unit(unit) and unit.orks_psychic_usage.budget.spent == 1 and !orks_psychic_unit_available(board, unit, true) and board.current_decision_maker
    return valid

# Shared Watchin' installs the same keyed effect rather than one source per
# bank/use. Duplicate calls cannot grow the source registry (01.02.02).
fun test_orks17q_shared_watchin_all_banks() -> Bool:
    let bank : SourceBank
    let valid = true
    for index in range(3):
        bank.value = index
        let board = orks17q_bank_fixture(bank, OrksDetachment::war_horde)
        board.begin_phase(BattlePhase::movement)
        ref unit = source_bank_unit(board, bank, 0)
        unit[0].orks_enhancement = OrksEnhancement::da_boss_is_watchin
        let before = orks_watchin_available(board, unit)
        commit_orks_watchin(board, unit)
        let sources = board.source_instances.size()
        grant_orks_own_payload(board, unit, 200 + OrksEnhancement::da_boss_is_watchin.value, riled_up_grant(), SourceDuration::next_own_turn)
        valid = valid and before and unit_is_riled_up(unit) and !orks_watchin_available(board, unit) and board.source_instances.size() == sources
    return valid

# Dread Power has identical CP/history/effect behavior in all banks. Genuine
# external-target rules (Roar) remain unavailable offboard (01.02.04).
fun test_orks17q_shared_dread_power_all_banks() -> Bool:
    let bank : SourceBank
    let valid = true
    for index in range(3):
        bank.value = index
        let board = orks17q_bank_fixture(bank, OrksDetachment::dread_mob)
        board.begin_phase(BattlePhase::movement)
        ref unit = source_bank_unit(board, bank, 0)
        unit[0].keywords.append(Keyword::walker)
        let before = orks_dread_power_valid(board, unit, false)
        commit_orks_dread_power(board, unit)
        valid = valid and before and unit_is_riled_up(unit) and board.command_points[0] == 9 and unit.history.stratagem_targeted_by_player[0] and !orks_dread_power_valid(board, unit, false)
        if index > 0:
            valid = valid and !orks_psychic_unit_available(board, unit, false)
    return valid

# Mortal allocation, FNP and remaining wounds now share the same damage job
# and action shape in all banks (core pp24/81; appendix01.02.04).
fun test_orks17q_shared_mortals_and_prevention_all_banks() -> Bool:
    let bank : SourceBank
    let valid = true
    for index in range(3):
        bank.value = index
        let board = orks17q_bank_fixture(bank, OrksDetachment::war_horde)
        ref unit = source_bank_unit(board, bank, 0)
        unit[0].profile = Profile::beastboss_morgrim
        let original = unit[0].wounds_left()
        let count : CombatCounter
        count = 2
        let mortals = resolve_mortal_wounds(board, bank, unit_id(0), unit_id(0), false, count)
        mortals.select_mortal_model(board, damage_test_model(0))
        mortals.roll(board, attack_test_die(6))
        mortals.select_mortal_model(board, damage_test_model(0))
        mortals.roll(board, attack_test_die(1))
        valid = valid and mortals.is_done() and unit[0].wounds_left() == original - 1 and board.damage_bank.value == SourceBank::battlefield.value
    return valid

# Offboard deaths use common ordering and source cleanup, without a Deadly
# Demise range/roll. Battlefield deaths still retain that printed effect.
fun test_orks17q_shared_offboard_death_skips_external_geometry() -> Bool:
    let board = orks17q_bank_fixture(SourceBank::reserves, OrksDetachment::brute_bosses)
    ref unit = board.reserve_units[0]
    unit[0].has_deadly_demise = true
    unit[0].orks_enhancement = OrksEnhancement::surly_as_a_squiggoth
    let identity = unit[0].identity
    let job = damage_job(DamageKind::normal, unit_id(0), unit_id(0), false, false, unit[0].wounds_left(), identity)
    job.bank = SourceBank::reserves
    commit_wound_loss(board, job, damage_test_model(0), unit[0].wounds_left(), false)
    let jobs : DamageJobs
    let death = resolve_damage_jobs(board, jobs, false, unit_id(0))
    death.choose_destruction_unit(board, unit_id(0))
    death.resolve_destruction_model(board, damage_test_model(0))
    return death.is_done() and unit.models.empty() and unit.destroyed_models.value.size() == 1 and unit.destroyed_models.value[0].identity == identity

# Surly shares roll/token/three-wound reset in all banks. Only battlefield
# returns request placement; reserve/passenger returns need no coordinate.
fun test_orks17q_shared_surly_all_banks() -> Bool:
    let bank : SourceBank
    let valid = true
    for index in range(3):
        bank.value = index
        let board = orks17q_bank_fixture(bank, OrksDetachment::brute_bosses)
        ref unit = source_bank_unit(board, bank, 0)
        unit[0].orks_enhancement = OrksEnhancement::surly_as_a_squiggoth
        unit[0].destroyed_phase = board.phase_serial.value + 1
        unit[0].destruction_pending = true
        unit[0].destroying_unit_known = true
        unit[0].suffered_wounds = unit[0].profile.wounds()
        let identity = unit[0].identity
        unit.remove_model(0)
        let revival = return_orks_surly(board, unit, bank, unit_id(0), damage_test_model(0))
        revival.roll(board, unit, attack_test_die(2))
        if index == 0:
            revival.place_returned_model(board, unit, board_position(5, 5))
        valid = valid and revival.is_done() and !unit.retired and unit[0].identity == identity and unit[0].wounds_left() == 3 and !unit[0].destruction_pending and !unit[0].destroying_unit_known and unit[0].off_battlefield == (index != 0)
    return valid

# An unplaceable carrier is destroyed with its passengers, just like a carrier
# that misses reserve arrival. Otherwise saved games retain dangling links
# (user setup-failure ruling; core pp64/69).
fun test_orks17q_unplaceable_carrier_removes_passenger_links() -> Bool:
    let board = transport16_fixture()
    let carrier = board[0]
    let passenger = board[1]
    board.units.clear()
    board.reserve_units.append(carrier)
    board.reserve_units.append(passenger)
    mark_unit_offboard(board.reserve_units[0], true)
    mark_unit_offboard(board.reserve_units[1], true)
    embark_formation_unit(board, unit_id(1), unit_id(0), damage_test_model(0))
    destroy_unplaceable_reserve(board, unit_id(0))
    return board.reserve_units.empty() and board.embarked_units.empty() and board.expired_reserves.value.size() == 2 and valid_passenger_links(board)

# Breakin' Heads has one action sequence and one CP/D3/shock-removal rule in
# every bank. Source: War Horde card; appendix01.02.04; mortals core p24.
fun test_orks17q_shared_breakin_heads_all_banks() -> Bool:
    let bank : SourceBank
    let valid = true
    for index in range(3):
        bank.value = index
        let attached = orks17p2_attached(make_orks_beast_snagga_boyz(1, 9, 1), make_orks_beastboss())
        let board = orks17p2_fixture(attached)
        board.armies[0].faction = ArmyFaction::orks
        let selected = board.armies[0].record_detachment(OrksDetachment::war_horde)
        board.command_points[0] = 10
        if index == 1:
            let moved = reposition_unit(board, unit_id(0))
            assert(moved, "shock fixture reserve transfer failed")
        if index == 2:
            board[1][0].transport_permissions_known = true
            board[1][0].transport_capacity = 20
            board[1][0].permitted_passenger_keywords.append(Keyword::infantry)
            transfer_embarked_unit(board, unit_id(0), board[1][0].identity)
        ref unit = source_bank_unit(board, bank, 0)
        unit[0].profile = Profile::beastboss_morgrim
        unit.battle_socked = true
        board.current_decision_maker = true
        let sequence = orks_became_shocked(board, unit.identity)
        sequence.breakin_heads(board)
        sequence.quantity(board, attack_test_die(1))
        sequence.select_mortal_model(board, damage_test_model(0))
        sequence.roll(board, attack_test_die(6))
        valid = valid and sequence.is_done() and !unit.battle_socked and board.command_points[0] == 9 and unit.history.stratagem_targeted_by_player[0] and board.current_decision_maker
    return valid

# Common mortal jobs preserve their bank through a suspended-frame roundtrip;
# a restored reserve decision cannot accidentally allocate to board slot0.
fun test_orks17q_shared_mortal_frame_roundtrip() -> Bool:
    let board = orks17q_bank_fixture(SourceBank::reserves, OrksDetachment::war_horde)
    let original = board.reserve_units[0][0].wounds_left()
    let count : CombatCounter
    count = 1
    let pending = resolve_mortal_wounds(board, SourceBank::reserves, unit_id(0), unit_id(0), false, count)
    let text = to_string(pending)
    let restored : MortalWounds
    let parsed = from_string(restored, text)
    restored.select_mortal_model(board, damage_test_model(0))
    return parsed and restored.is_done() and board.reserve_units[0][0].wounds_left() == original - 1 and board[0].retired

# Turn/phase limits and movement flags reset identically in all three banks,
# while the opponent's turn-only fight/shoot usage survives (pp28–30/33/54).
fun test_orks17q_shared_boundary_resets_all_banks() -> Bool:
    let bank : SourceBank
    let valid = true
    for index in range(3):
        bank.value = index
        let board = orks17q_bank_fixture(bank, OrksDetachment::war_horde)
        ref unit = source_bank_unit(board, bank, 0)
        unit.has_run = true
        unit.has_moved = true
        unit.has_charged = true
        unit.can_shoot = false
        unit.can_charge = false
        unit.has_shoot = true
        unit.has_fought = true
        unit.history.used_stratagem_this_phase = true
        unit.history.stratagem_targeted_by_player[0] = true
        board.current_player = true
        board.start_turn_history()
        valid = valid and !unit.has_run and !unit.has_moved and !unit.has_charged and unit.can_shoot and unit.can_charge and unit.has_shoot and unit.has_fought
        board.begin_phase(BattlePhase::fight)
        valid = valid and !unit.has_fought and !unit.history.used_stratagem_this_phase and !unit.history.stratagem_targeted_by_player[0]
        board.current_player = false
        board.start_turn_history()
        valid = valid and !unit.has_shoot
    return valid

# Pending deaths across different banks belong to the same controller's
# ordering group. Selecting reserves first must not consume a battlefield ID
# with the same numeric slot (p87; supplied Rules Sequencing).
fun test_orks17q_shared_destruction_bank_order() -> Bool:
    let board = orks17q_bank_fixture(SourceBank::reserves, OrksDetachment::war_horde)
    board[1].owned_by_player1 = false
    board[1][0].state = ModelState::pending_destruction
    board[1][0].destruction_pending = true
    board[1][0].suffered_wounds = board[1][0].profile.wounds()
    board.reserve_units[0][0].state = ModelState::pending_destruction
    board.reserve_units[0][0].destruction_pending = true
    board.reserve_units[0][0].suffered_wounds = board.reserve_units[0][0].profile.wounds()
    let identity = board.reserve_units[0][0].identity
    let jobs : DamageJobs
    let death = resolve_damage_jobs(board, jobs, false, unit_id(0))
    let offered = can death.choose_destruction_bank(board, SourceBank::reserves)
    death.choose_destruction_bank(board, SourceBank::reserves)
    death.choose_destruction_unit(board, unit_id(0))
    death.resolve_destruction_model(board, damage_test_model(0))
    # The work stack resolves pending death triggers before queued removals.
    # Check which trigger was consumed, then check both archives at completion.
    let first = !board.reserve_units[0][0].destruction_pending and board[1][0].destruction_pending and board.reserve_units[0][0].identity == identity
    death.choose_destruction_unit(board, unit_id(1))
    death.resolve_destruction_model(board, damage_test_model(0))
    return offered and first and death.is_done() and board[1].models.empty() and board.reserve_units[0].models.empty() and board.reserve_units[0].destroyed_models.value[0].identity == identity and board.damage_bank.value == SourceBank::battlefield.value

# Command Battle-shock uses one scan and one frozen recovery policy for every
# bank (core p30; supplied Not On The Battlefield01.02.04).
fun test_orks17q_shared_command_shock_scan_all_banks() -> Bool:
    let bank : SourceBank
    let valid = true
    for index in range(3):
        bank.value = index
        let board = orks17q_bank_fixture(bank, OrksDetachment::war_horde)
        board.begin_phase(BattlePhase::command)
        board.has_used_insane_bravery[0] = true
        ref unit = source_bank_unit(board, bank, 0)
        unit.battle_socked = true
        let sequence = battle_shock_step(board)
        sequence.roll_pair(board, attack_test_die(6), attack_test_die(6))
        valid = valid and sequence.is_done() and !unit.battle_socked and unit.off_battlefield == (index != 0) and board.current_decision_maker == false
        if index > 0:
            # A later bank gaining shock during an earlier unit's test was
            # not shocked at STEP start. Passing must not clear that new shock.
            board.units.append(make_infernus_squad())
            ref earlier = board.units.back()
            earlier.models.resize(1)
            earlier.capture_starting_strength()
            board.identify_unit(earlier)
            earlier.battle_socked = true
            unit[0].suffered_wounds = unit[0].profile.wounds() - 1
            let subsequent = battle_shock_step(board)
            unit.battle_socked = true
            subsequent.roll_pair(board, attack_test_die(6), attack_test_die(6))
            subsequent.roll_pair(board, attack_test_die(6), attack_test_die(6))
            valid = valid and subsequent.is_done() and !earlier.battle_socked and unit.battle_socked
    return valid

# Shared resource accounting is not tied to a faction or a psychic ability.
# Appendix22.03.01/01.05.02: a reroll never consumes the resource a second time.
fun test_procedures_round_resource_reroll_and_owner() -> Bool:
    let board : Board
    board.current_decision_maker = true
    let budget : RoundResourceBudget
    let sequence = roll_spent_round_resource(board, budget, false, 1, true)
    let paid = budget.spent == 1 and !budget.available(board.current_round.value + 1, 1)
    sequence.roll(board, attack_test_die(1))
    let owns_reroll = !board.current_decision_maker
    sequence.keep_it(board, false)
    sequence.reroll(board, attack_test_die(6))
    return paid and owns_reroll and sequence.is_done() and sequence.result == 6 and budget.spent == 1 and board.current_decision_maker

# Zero capacity is unavailable even at a new round; only the stamp resets use.
fun test_procedures_round_resource_limits_and_reset() -> Bool:
    let budget : RoundResourceBudget
    let starts = !budget.available(1, 0) and budget.available(1, 2)
    budget.consume(1)
    let once = budget.available(1, 2) and !budget.available(1, 1)
    budget.consume(1)
    let full = !budget.available(1, 2) and budget.available(2, 2)
    budget.consume(2)
    return starts and once and full and budget.spent == 1 and budget.round_stamp == 2

# Granted moves work without faction abilities and restore all caller policy.
# Core pp33/70: declining records no completed move and never changes its M.
fun test_procedures_reactive_move_restores_context() -> Bool:
    let board = movement11_fixture()
    board.current_decision_maker = true
    board.timing.active_player = true
    board.move_requires_objective = true
    board[0].pending_move_kind = MovementKind::advance
    board[0].movement_distance_limit = 8
    board[0].move_takes_to_skies = true
    let distance : StatModifier
    distance = 3
    let sequence = reactive_move(board, unit_id(0), distance, false)
    let exact = can sequence.move_to(board, board_position(8, 5)) and !can sequence.move_to(board, board_position(9, 5))
    sequence.skip(board)
    return exact and sequence.is_done() and !sequence.completed and board[0].history.last_move_phase == 0 and board[0].pending_move_kind == MovementKind::advance and board[0].movement_distance_limit == 8 and board[0].move_takes_to_skies and board.move_requires_objective and board.current_decision_maker and board.timing.active_player

# A source's destination restriction constrains the same core path and is
# removed afterwards; marker control/OC is irrelevant (core pp33/52).
fun test_procedures_reactive_move_objective_and_history() -> Bool:
    let board = movement11_fixture()
    for objective in range(4):
        board.set_objective_position(objective, board_position(30, 20))
    board.set_objective_position(0, board_position(8, 5))
    let distance : StatModifier
    distance = 3
    let sequence = reactive_move(board, unit_id(0), distance, true)
    # Both destinations are three inches away; only the east endpoint is
    # within the marker range, measured between circular base edges.
    let constrained = !can sequence.move_to(board, board_position(2, 5)) and can sequence.move_to(board, board_position(8, 5))
    sequence.move_to(board, board_position(8, 5))
    return constrained and sequence.is_done() and sequence.completed and !board.move_requires_objective and board[0].history.last_move_phase == board.phase_serial.value + 1 and board[0].history.move_kind == MovementKind::normal and board[0].movement_distance_limit == 0

# The shared Healing02.02.04 procedure accepts the complete allowance; no
# faction wrapper or artificial three-wound chunk is needed for five wounds.
fun test_procedures_heal_full_allowance_without_faction() -> Bool:
    let board = movement11_fixture()
    for index in range(4):
        let extra = board[0][0]
        extra.identity = 0
        extra.position.x = 7 + 2 * index
        board[0].models.append(extra)
    board.identify_units()
    board[0].capture_starting_strength()
    for member in range(5):
        board[0][member].suffered_wounds = 1
    let count : FixedStat
    count = 5
    board.current_decision_maker = true
    let sequence = heal_unit(board, board[0], SourceBank::battlefield, count)
    for selected in range(5):
        sequence.choose_healed_model(board, board[0], damage_test_model(selected))
    let healed = true
    for member in range(5):
        healed = healed and board[0][member].suffered_wounds == 0
    return sequence.is_done() and healed and board.current_decision_maker and board[0].models.size() == 5

# An explicit Character-returning ability can use the placement/restoration
# operation directly. Death flags clear, One Shot and original identity remain
# (Returning Models01.02.03); nearest is measured from the actual death point.
fun test_procedures_return_original_model_nearest_without_faction() -> Bool:
    let board = movement11_fixture()
    board[0][0].keywords.append(Keyword::character)
    let identity = board[0][0].identity
    board[0][0].used_once_per_battle_weapon[0] = true
    board[0].damage(0, board[0][0].profile.wounds())
    board[0].retired = true
    let sequence = return_model(board, board[0], SourceBank::battlefield, unit_id(0), damage_test_model(0), ReturnPlacementPolicy::nearest_unengaged, 3)
    let nearest = can sequence.place_returned_model(board, board[0], board_position(5, 5)) and !can sequence.place_returned_model(board, board[0], board_position(4, 5))
    sequence.place_returned_model(board, board[0], board_position(5, 5))
    return nearest and sequence.is_done() and !board[0].retired and board[0][0].identity == identity and board[0][0].used_once_per_battle_weapon[0] and !board[0][0].destruction_pending and board[0][0].state == ModelState::normal and board[0].destroyed_models.value.empty()

# Shared construction must not spend a token, and per-army/unit/model keys
# must remain distinct (core pp66/88; printed source limits, e.g. Orks tokens).
fun test_usage_specification_preserves_scope_and_owner() -> Bool:
    let board = attack_declaration_fixture()
    board.units.append(make_orks_mek())
    board.identify_units()
    let limits = source_use_limits(0, 0, 0, 1)
    let army = make_source_usage(board[0].owned_by_player1, 490, board[0].identity, board[0][0].identity, SourceUseScope::army, limits)
    let duplicate = make_source_usage(board[0].owned_by_player1, 490, board[2].identity, board[2][0].identity, SourceUseScope::army, limits)
    let opponent = make_source_usage(!board[0].owned_by_player1, 490, board[1].identity, board[1][0].identity, SourceUseScope::army, limits)
    let unit = make_source_usage(board[0].owned_by_player1, 490, board[0].identity, board[0][0].identity, SourceUseScope::unit, limits)
    let model = make_source_usage(board[0].owned_by_player1, 490, board[0].identity, board[0][0].identity, SourceUseScope::model, limits)
    let not_spent = board.source_uses.empty() and source_usage_available(board, army)
    commit_source_usage(board, army)
    return not_spent and !source_usage_available(board, duplicate) and source_usage_available(board, opponent) and source_usage_available(board, unit) and source_usage_available(board, model)

# Limit construction preserves simultaneous interval restrictions. A new
# phase/turn never replenishes an exhausted round/battle budget (source cards).
fun test_usage_specification_combines_interval_limits() -> Bool:
    let board = attack_declaration_fixture()
    let spec = make_source_usage(board[0].owned_by_player1, 491, board[0].identity, invalid_entity_identity(), SourceUseScope::unit, source_use_limits(1, 1, 2, 3))
    commit_source_usage(board, spec)
    board.phase_serial = board.phase_serial + 1
    let turn_blocked = !source_usage_available(board, spec)
    board.turn_serial = board.turn_serial + 1
    let second = source_usage_available(board, spec)
    commit_source_usage(board, spec)
    board.phase_serial = board.phase_serial + 1
    board.turn_serial = board.turn_serial + 1
    let round_blocked = !source_usage_available(board, spec)
    board.current_round = board.current_round + 1
    let third = source_usage_available(board, spec)
    commit_source_usage(board, spec)
    board.phase_serial = board.phase_serial + 1
    board.turn_serial = board.turn_serial + 1
    board.current_round = board.current_round + 1
    return turn_blocked and second and round_blocked and third and !source_usage_available(board, spec)

# Explicit original model identity remains the model-scoped use key across
# a bank transfer; storage indices must not create another use (pp65/68/88).
fun test_usage_specification_survives_bank_transfer() -> Bool:
    let board = attack_declaration_fixture()
    let unit_identity = board[0].identity
    let model_identity = board[0][0].identity
    let spec = make_source_usage(board[0].owned_by_player1, 492, unit_identity, model_identity, SourceUseScope::model, source_use_limits(0, 0, 0, 1))
    commit_source_usage(board, spec)
    board.reserve_units.append(board[0])
    board.units.erase(0)
    let restored = make_source_usage(board.reserve_units[0].owned_by_player1, 492, unit_identity, model_identity, SourceUseScope::model, source_use_limits(0, 0, 0, 1))
    return !source_usage_available(board, restored) and restored.source_unit == unit_identity and restored.source_model == model_identity and source_usage_subject(board, restored) == model_identity

# Presentation metadata must survive a save without becoming a source-use key
# or changing its granted rule. Source/effect infrastructure, appendix01.02.02.
fun test_source_labels_restore_without_changing_effect() -> Bool:
    let state = play()
    state.board = attack_declaration_fixture()
    let instance = source17e_instance(state.board, 0, 1)
    instance.label.value = SourceLabel::crude_surgery
    register_source_instance(state.board, instance)
    let restored = play()
    let parsed = set_state(restored, to_string(state))
    let label_retained = parsed and restored.board.source_instances[0].label.value.value == SourceLabel::crude_surgery.value
    let sequence = resolve_source_event(restored.board, source17e_trigger(restored.board, SourceEventKind::timing_window, 0))
    let choice : GameChooseSourceEvent
    let text_retained = pretty_string(restored.board, choice) == "Crude Surgery"s
    sequence.choose_source_event(restored.board, source17e_id(0))
    return label_retained and text_retained and sequence.is_done() and restored.board[0][0].effective_movement(6) == 8

# Raw enum fields can be forged by the host/parser. The save gate must reject
# an unknown label atomically, just as it rejects invalid gameplay enums.
fun test_source_labels_reject_unknown_saved_value() -> Bool:
    let invalid = play()
    invalid.board = attack_declaration_fixture()
    let instance = source17e_instance(invalid.board, 0, 1)
    register_source_instance(invalid.board, instance)
    invalid.board.source_instances[0].label.value.value = max(instance.label.value) + 1
    let state = play()
    state.board.command_points[0] = 42
    return !valid_source_foundations(invalid.board) and !set_state(state, to_string(invalid)) and state.board.command_points[0] == 42

# One physical gun chooses one actual profile; a second copy remains available
# and spent One Shot history follows only its primary link (pp16/83,04.01.03).
fun test_weapon_catalog_primary_links_keep_copies_independent() -> Bool:
    let state = play()
    state.board = attack_declaration_fixture()
    state.board[0][0].weapons.clear()
    equip_weapon(state.board[0][0], Weapon::plasma_pistol_standard, 0)
    equip_weapon(state.board[0][0], Weapon::plasma_pistol_supercharge, 1)
    equip_weapon(state.board[0][0], Weapon::plasma_pistol_standard, 0)
    equip_weapon(state.board[0][0], Weapon::plasma_pistol_supercharge, 3)
    let restored = play()
    let parsed = set_state(restored, to_string(state))
    let selected : Bool[MAX_WEAPONS]
    selected[0] = true
    let choices = !weapon_selection_valid(restored.board, unit_id(0), 0, 1, false, selected, false) and weapon_selection_valid(restored.board, unit_id(0), 0, 3, false, selected, false)
    consume_one_shot_profile(restored.board[0][0], 0)
    return parsed and choices and restored.board[0][0].used_once_per_battle_weapon[0] and restored.board[0][0].used_once_per_battle_weapon[1] and !restored.board[0][0].used_once_per_battle_weapon[2] and !restored.board[0][0].used_once_per_battle_weapon[3]

# Forged links cannot create chains or cross-family aliases in saves; the
# save gate rejects them atomically (storage infrastructure for04.01.03).
fun test_weapon_catalog_rejects_chained_or_cross_family_links() -> Bool:
    let state = play()
    state.board = attack_declaration_fixture()
    state.board[0][0].weapons.clear()
    equip_weapon(state.board[0][0], Weapon::plasma_pistol_standard, 0)
    equip_weapon(state.board[0][0], Weapon::plasma_pistol_supercharge, 1)
    state.board[0][0].weapons.append(equipped_weapon(Weapon::plasma_pistol_supercharge, 2))
    let restored = play()
    restored.board.command_points[0] = 42
    let chained = !set_state(restored, to_string(state)) and restored.board.command_points[0] == 42
    state.board[0][0].weapons[2].secondary_profile_of = 1
    state.board[0][0].weapons[2].profile = Weapon::bolt_pistol
    return chained and !set_state(restored, to_string(state)) and restored.board.command_points[0] == 42

# Equipment shares the catalog but does not invent attacks or a compulsory
# melee selection (Orks Big Mek in Mega Armour/Tankbustas Wargear Options).
fun test_weapon_catalog_nonattacking_equipment_cannot_be_selected() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].weapons.clear()
    equip_weapon(board[0][0], Weapon::orks_kustom_force_field, 0)
    equip_weapon(board[0][0], Weapon::orks_pulsa_rokkit, 0)
    let selected : Bool[MAX_WEAPONS]
    return valid_model_equipment(board[0][0]) and !weapon_selection_valid(board, unit_id(0), 0, 0, true, selected, false) and !weapon_selection_valid(board, unit_id(0), 0, 1, false, selected, false) and may_finish_weapon_selection(board, unit_id(0), 0, true, false)

# Neutral hooks leave ordinary models unchanged without a faction effect.
# Dispatch infrastructure; core arithmetic/keyword/save rules remain pp10-19.
fun test_faction_dispatch_unmodified_model_defaults() -> Bool:
    let board = attack_declaration_fixture()
    ref model = board[0][0]
    let movement_modifiers : RuleModifiers
    let toughness_modifiers : RuleModifiers
    append_model_modifiers(model, ModifiedCharacteristic::movement, movement_modifiers)
    append_model_modifiers(model, ModifiedCharacteristic::toughness, toughness_modifiers)
    let permission : InvulnerableSavePermission
    permission.target = model.profile.invuln_save()
    append_model_save_permissions(model, permission)
    return faction_keyword_override(model, Keyword::mounted) == 0 and movement_modifiers.empty() and toughness_modifiers.empty() and permission.target.value == model.profile.invuln_save() and !model_has_fights_first_grant(model) and rule_charge_allowed(board, board[0]) and rule_action_allowed(board, board[0]) and rule_flight_allowed(board, board[0]) and faction_hidden_allowed(board, board[0])

# A faction-owned effect is consumed on its actual recipient, independently
# of which army owns that recipient (Orks psychic grants; core p67/01.02.02).
fun test_faction_dispatch_recipient_effect_without_army_inference() -> Bool:
    let board = attack_declaration_fixture()
    board.armies[0].faction = ArmyFaction::space_marines
    board.armies[1].faction = ArmyFaction::tyranids
    let grant : RuleEffectGrant
    grant.kind = RuleEffectKind::invulnerable_save
    grant.amount = 4
    let payload : SourceGrant
    payload = grant
    let key : SourceEffectKey
    key = 17
    install_source_grant(board[1][0], payload, key)
    let applied = board[1][0].effective_invulnerable_save() == 4 and model_has_source_grant(board[1][0], key)
    remove_source_grant(board[1][0], key)
    return applied and !model_has_source_grant(board[1][0], key) and board[1][0].effective_invulnerable_save() == board[1][0].profile.invuln_save()

# Generic source installation/removal routes faction payloads by their type,
# preserving overlapping ownership keys (01.02.02, core returning models p88).
fun test_faction_dispatch_overlapping_grants_keep_other_source() -> Bool:
    let board = attack_declaration_fixture()
    let grant : RuleEffectGrant
    grant.kind = RuleEffectKind::invulnerable_save
    grant.amount = 4
    let payload : SourceGrant
    payload = grant
    let first : SourceEffectKey
    let second : SourceEffectKey
    first = 18
    second = 19
    install_source_grant(board[0][0], payload, first)
    grant.kind = RuleEffectKind::invulnerable_save
    grant.amount = 5
    payload = grant
    install_source_grant(board[0][0], payload, second)
    remove_source_grant(board[0][0], first)
    return !model_has_source_grant(board[0][0], first) and model_has_source_grant(board[0][0], second) and board[0][0].effective_invulnerable_save() == 5

# A source's optional faction policy does not grant a generic caller transport
# permission; the shared known/capacity gate still owns eligibility (core p64).
fun test_faction_dispatch_neutral_hook_does_not_authorize_transport() -> Bool:
    let board = attack_declaration_fixture()
    return passenger_requirements_match(board[0][0], board[1][0]) and !passenger_model_permitted(board[0][0], board[1][0])

# Core source choices and faction timing choices remain peers, in either order.
# User Rules Sequencing; War Cry is Orks army policy, numeric grants core01.02.02.
fun faction_dispatch_timing_order(Bool faction_first, Bool mandatory) -> Bool:
    let board = orks17f_fixture()
    board.begin_phase(BattlePhase::command)
    let instance = source17e_instance(board, 0, 511)
    instance.window = TimingWindow::command_start
    instance.optional = !mandatory
    let handle = register_source_instance(board, instance)
    let sequence = resolve_timing_window(board, TimingWindow::command_start)
    let event = source17e_id(0)
    let both = can sequence.choose_window_source(board, event) and can sequence.choose_orks_timing_rule(board, OrksTimingRule::war_cry)
    let gated = !mandatory or !(can sequence.finish_timing_rules(board))
    if faction_first:
        sequence.choose_orks_timing_rule(board, OrksTimingRule::war_cry)
        sequence.choose_window_source(board, event)
    else:
        sequence.choose_window_source(board, event)
        sequence.choose_orks_timing_rule(board, OrksTimingRule::war_cry)
    let next_controller = board.current_decision_maker
    sequence.finish_timing_rules(board)
    return both and gated and next_controller and sequence.is_done() and board.armies[0].war_cry_used and !board.armies[1].war_cry_used and board[0][0].effective_movement(board[0][0].profile.movement()) == board[0][0].profile.movement() + 2

fun test_faction_dispatch_faction_then_core_timing() -> Bool:
    return faction_dispatch_timing_order(true, false)

fun test_faction_dispatch_core_then_faction_timing() -> Bool:
    return faction_dispatch_timing_order(false, false)

fun test_faction_dispatch_mandatory_core_choice_still_blocks_finish() -> Bool:
    return faction_dispatch_timing_order(true, true)

# A selected ordinary Advance completes its roll/reroll before its sibling
# move choices can be offered again (core p33; Orks free Advance re-roll).
fun test_faction_dispatch_selected_move_is_atomic() -> Bool:
    let board = orks17f_fixture()
    board.begin_phase(BattlePhase::movement)
    let sequence = movement(board, unit_id(0), false)
    let initial = can sequence.advance(board, true) and can sequence.normal_move(board)
    sequence.advance(board, true)
    let locked = !(can sequence.normal_move(board)) and !(can sequence.remain_stationary(board))
    sequence.roll(board, attack_test_die(2))
    sequence.keep_it(board, true)
    return initial and locked and sequence.kind == MovementKind::advance and sequence.extra.value == 2

# Faction special modes share the same choice point, then finish atomically;
# the common placement procedure consumes the returned bounded allowance.
# Orks index Pulse Jet Move D6+18; core movement/placement pp12/33.
fun test_faction_dispatch_special_move_is_peer_and_atomic() -> Bool:
    let board = attack_declaration_fixture()
    board.begin_phase(BattlePhase::movement)
    let grant : RuleEffectGrant
    grant.kind = RuleEffectKind::pulse_engine
    grant.amount = 1
    board[0][0].rule_effects.append(grant)
    let sequence = movement(board, unit_id(0), false)
    let peers = can sequence.normal_move(board) and can sequence.pulse_jet_move(board)
    sequence.pulse_jet_move(board)
    let locked = !(can sequence.normal_move(board))
    sequence.roll(board, attack_test_die(3))
    return peers and locked and sequence.kind == MovementKind::pulse_jet and sequence.extra.value == 21

# Shared persisting-effect infrastructure: reusing a source prototype retains
# independent overlapping effect keys (appendix01.02.02), without Orks metadata.
fun test_shared_hooks_reusable_grant_keeps_independent_effects() -> Bool:
    let board = attack_declaration_fixture()
    let instance = source17e_instance(board, 0, 511)
    instance.source_model = 0
    instance.recipient = SourceTarget::target_unit
    commit_reusable_unit_grant(board, instance, board[1].identity)
    commit_reusable_unit_grant(board, instance, board[1].identity)
    let before = board[1][0].effective_movement(6) == 10 and board.source_instances.size() == 1 and board.source_effects.size() == 2
    let first = board.source_effects[0].identity
    remove_scoped_source_effect(board, first)
    return before and board[1][0].effective_movement(6) == 8

# New-unit cleanup removes sourced values and retains intrinsic zero-key data
# (01.02.10). This is independent of the faction that supplied the modifier.
fun test_shared_hooks_cleanup_preserves_intrinsic_grants() -> Bool:
    let board = attack_declaration_fixture()
    let model = board[0][0]
    let intrinsic = characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 1)
    let temporary = intrinsic
    temporary.source_effect = 1
    model.characteristic_modifiers.append(intrinsic)
    model.characteristic_modifiers.append(temporary)
    strip_temporary_model_grants(model)
    return model.characteristic_modifiers.size() == 1 and model.characteristic_modifiers[0].source_effect.value == 0

# Adding a unit creates fresh identities and uses battle-start equipment;
# ordinary returning models instead keep their identity (01.02.10/core p88).
fun test_shared_hooks_replacement_uses_fresh_identity_and_template() -> Bool:
    let board = attack_declaration_fixture()
    board[0].capture_starting_strength()
    let original_id = board[0][0].identity
    board[0][0].suffered_wounds = 1
    board[0][0].weapons.clear()
    board[0].has_shoot = true
    let replacement = make_replacement_unit(board, board[0])
    return replacement.identity != board[0].identity and replacement[0].identity != original_id and replacement[0].original_unit == replacement.identity and replacement[0].weapons.size() == 1 and replacement[0].suffered_wounds == 0 and !replacement.has_shoot and replacement.history.strategic_reserve and replacement.off_battlefield and board[0][0].suffered_wounds == 1

# Common grants have their own keys even when no faction is selected. Granting
# InSv establishes a permission; a worse grant cannot worsen an existing save.
# Core p19 and appendix01.02.02/02.02.01.
fun test_shared_hooks_status_grants_and_best_invulnerable_save() -> Bool:
    let board = attack_declaration_fixture()
    let grant : RuleEffectGrant
    grant.kind = RuleEffectKind::invulnerable_save
    grant.amount = 3
    let payload : SourceGrant
    payload = grant
    let first : SourceEffectKey
    first = 91
    install_source_grant(board[1][0], payload, first)
    grant.amount = 5
    payload = grant
    let second : SourceEffectKey
    second = 92
    install_source_grant(board[1][0], payload, second)
    let best = board[1][0].effective_invulnerable_save() == min(3, board[1][0].profile.invuln_save())
    remove_source_grant(board[1][0], first)
    return best and board[1][0].effective_invulnerable_save() == min(5, board[1][0].profile.invuln_save()) and model_has_source_grant(board[1][0], second)

# Common permission consumers no longer need a faction adapter (pp38/40/58).
fun test_shared_hooks_common_permissions_without_faction() -> Bool:
    let board = attack_declaration_fixture()
    let status : RuleEffectGrant
    status.kind = RuleEffectKind::no_charge
    status.amount = 1
    board[0][0].rule_effects.append(status)
    status.kind = RuleEffectKind::no_action
    board[0][0].rule_effects.append(status)
    status.kind = RuleEffectKind::fights_first
    board[0][0].rule_effects.append(status)
    return !rule_charge_allowed(board, board[0]) and !rule_action_allowed(board, board[0]) and model_has_fights_first_grant(board[0][0]) and rule_charge_allowed(board, board[1])

# Invalid save grants cannot fabricate a1+ or missing/zero save (core p19).
fun test_shared_hooks_reject_invalid_invulnerable_grants() -> Bool:
    let status : RuleEffectGrant
    status.kind = RuleEffectKind::invulnerable_save
    status.amount = 1
    let invalid_low = !valid_rule_effect(status)
    status.amount = 7
    let invalid_high = !valid_rule_effect(status)
    status.amount = 4
    return invalid_low and invalid_high and valid_rule_effect(status)

# Hits and prevented wound losses are generic per-activation facts; starting
# another attack clears the ledger (core pp18-24/87).
fun test_shared_hooks_attack_results_are_faction_independent() -> Bool:
    let board = attack_declaration_fixture()
    begin_attack_results(board)
    record_attack_hits(board, unit_id(1), 3)
    let member : ModelID
    member = 0
    let remaining = board[1][0].wounds_left()
    record_attack_wound_loss(board, board[1], member, remaining + 7, true)
    let correct = board.attack_records.size() == 1 and board.attack_records[0].successful_hits == 3 and board.attack_records[0].wounds_lost == remaining and board.attack_records[0].tagged_hits[0] == 0
    end_attack_results(board)
    record_attack_hits(board, unit_id(1), 1)
    let closed = board.attack_records[0].successful_hits == 3
    begin_attack_results(board)
    return correct and closed and board.attack_records.empty() and board.attack_serial == 2

# Generic tagged counters cannot fabricate more hit triggers than actually
# occurred. Save integrity is shared regardless of which rule uses the tag.
fun test_shared_hooks_attack_tag_validation() -> Bool:
    let board = attack_declaration_fixture()
    begin_attack_results(board)
    record_attack_hits(board, unit_id(1), 2)
    board.attack_records[0].tagged_hits[0] = 3
    let rejected = !valid_attack_results(board)
    board.attack_records[0].tagged_hits[0] = 1
    return rejected and valid_attack_results(board)

# Shared Warlord selection accepts an explicitly supplied non-Orks faction
# keyword; no legacy army is automatically enabled by this fixture.
fun test_shared_hooks_warlord_uses_supplied_faction_keyword() -> Bool:
    let fixture = attack_declaration_fixture()
    let board : Board
    board.reserve_units.append(fixture[0])
    board.reserve_units[0][0].keywords.append(Keyword::character)
    board.reserve_units[0][0].keywords.append(Keyword::adeptus_astartes)
    board.armies[0].faction = ArmyFaction::space_marines
    let sequence = select_warlord(board, false, Keyword::adeptus_astartes, true)
    let member : ModelID
    member = 0
    let allowed = can sequence.choose_warlord_unit(board, unit_id(0))
    if allowed:
        sequence.choose_warlord_unit(board, unit_id(0))
        sequence.choose_warlord_model(board, member)
    return allowed and sequence.is_done() and board.armies[0].warlord == board.reserve_units[0][0].identity and board.reserve_units[0][0].has_keyword(Keyword::warlord)

# General limits distinguish counted enhancement types from repeated Upgrade
# copies, including the fourth distinct selection (user supplied Select Army).
fun test_shared_hooks_enhancement_limits() -> Bool:
    let counter : EnhancementSelectionCounter
    counter.record_choice(1)
    counter.record_choice(2)
    counter.record_choice(3)
    counter.record_choice(4)
    counter.record_choice(4)
    let full = counter.total == 4 and !counter.permits(5, true)
    counter.record_unit_copy(true)
    let ordinary_unique = !counter.permits(1, false)
    counter.record_unit_copy(true)
    let second_upgrade = counter.permits(1, true)
    counter.record_unit_copy(true)
    return full and ordinary_unique and second_upgrade and !counter.permits(1, true)

# Shared transport ALL requirements and named exclusions do not invent
# permissions; unknown carrier metadata still fails the core gate (p64).
fun test_shared_hooks_transport_metadata_requirements() -> Bool:
    let board = attack_declaration_fixture()
    let carrier = board[0][0]
    let passenger = board[1][0]
    carrier.required_passenger_keywords.append(Keyword::infantry)
    carrier.required_passenger_keywords.append(Keyword::orks)
    let wrong_faction = !passenger_requirements_match(carrier, passenger)
    passenger.keywords.append(Keyword::orks)
    let matches = passenger_requirements_match(carrier, passenger)
    passenger.datasheet = 1
    forbid_passenger_datasheet(carrier, 1)
    return wrong_faction and matches and !passenger_requirements_match(carrier, passenger) and !passenger_model_permitted(carrier, passenger)

# Half-seat allocation rounds once for the group and leaves ordinary members
# whole (core p64; card-specific divisors are constructor metadata).
fun test_shared_hooks_transport_grouped_seat_weights() -> Bool:
    let board = attack_declaration_fixture()
    let unit : Unit
    let half = board[0][0]
    half.transport_space = 1
    half.transport_space_divisor = 2
    unit.models.append(half)
    unit.models.append(half)
    unit.models.append(half)
    let ordinary = half
    ordinary.transport_space_divisor = 1
    ordinary.transport_space = 3
    unit.models.append(ordinary)
    return passenger_space(unit) == 5

# The same carrier can overlap two markers. Only the queried friendly home
# receives Raucous Occupants, never a nearby unrelated/enemy marker.
# Orks/Big'ed Bossbunka; objective control core p52.
fun test_ability_hooks_objective_context_does_not_leak_between_markers() -> Bool:
    let board = orks17p3_cargo(make_orks_big_ed_bossbunka(0, 0), make_orks_gretchin(10))
    board.objectives[0].custom_position = true
    board.objectives[0].position = board_position(5, 5)
    board.objectives[0].home = ObjectiveHome::army_0
    board.objectives[1].custom_position = true
    board.objectives[1].position = board_position(6, 5)
    board.objectives[1].home = ObjectiveHome::army_1
    let friendly = board.objective_control_level(board.objective_range_definition(0), false)
    let enemy_home = board.objective_control_level(board.objective_range_definition(1), false)
    board.objectives[1].home = ObjectiveHome::none
    let unassigned = board.objective_control_level(board.objective_range_definition(1), false)
    return friendly == 10 and enemy_home == 0 and unassigned == 0


# A unit ability can supply an arbitrary signed magnitude through the common
# hit pipeline, with independently ignorable terms and the ordinary cap.
# No Orks grant is involved; core p18 and appendix02.02.01/02.
fun test_ability_hooks_unit_hit_terms_are_not_boolean_bonuses() -> Bool:
    let board = attack_declaration_fixture()
    let info : AttackSequenceInfo
    info.unit_ability_hit_modifiers.append(rule_modifier(ModifierOperation::add, 3))
    info.unit_ability_hit_modifiers.append(rule_modifier(ModifierOperation::subtract, 1))
    board.attack_info = info
    let choices = attack_hit_choices(board, info)
    return info.total_hit_modifier() == 2 and get_hit_roll_bonus(board) == 1 and choices.size() == 2 and choices[0].modifier.signed_amount() == 3 and choices[1].modifier.signed_amount() == 1


# Calculation hooks preserve earlier operations and source distinctness;
# division happens after all additions (appendix02.02.01).
# Orks/Bannernob grants the one source-specific term used by this fixture.
fun test_ability_hooks_charge_terms_follow_common_operation_order() -> Bool:
    let board = attack_declaration_fixture()
    board[0][0].abilities.append(AbilityKind::waaagh_banner)
    let effects : ChargeRollEffects
    effects.modifiers.append(rule_modifier(ModifierOperation::divide, 2))
    append_charge_roll_effects(board[0], effects)
    return effects.modifiers.size() == 2 and modified_dice_result(7, effects.modifiers, false, true) == 4 and effects.modifiers[0].operation.value == ModifierOperation::divide.value


# Actual instances are supplied by the adapter; core does not manufacture a
# fixed Sustained Hits value. A preexisting3 and the army's1 remain distinct.
# Orks/War Horde; duplicate weapon abilities core p78.
fun test_ability_hooks_weapon_instances_preserve_prior_entries() -> Bool:
    let board = orks17h23_fixture()
    board.armies[0].faction = ArmyFaction::orks
    board.armies[0].detachments.append(OrksDetachment::war_horde)
    let before = to_string(board)
    let rules : WeaponAbilitySet
    rules.append(weapon_rule(WeaponRuleKind::sustained_hit, 3))
    let family : WeaponCode
    family = equipped_weapon_family(board[0][0], 1).value
    append_weapon_rules(board, unit_id(0), 0, board[0][0].weapons[1].profile, family, rules)
    let first = rules.size() == 2 and rules[0].parameter.value == 3 and rules[1].parameter.value == 1
    let repeated : WeaponAbilitySet
    repeated.append(weapon_rule(WeaponRuleKind::sustained_hit, 3))
    append_weapon_rules(board, unit_id(0), 0, board[0][0].weapons[1].profile, family, repeated)
    return first and repeated.size() == rules.size() and to_string(board) == before


# Advance grants are frozen before roll-stage effects. The later selected-
# movement handler must not rewrite them after their source has expired.
# Core pp32/36 and Orks/Waaagh! selected-to-Advance timing.
fun test_ability_hooks_advance_permission_is_not_recaptured_after_roll() -> Bool:
    let board = orks17f_fixture()
    orks17f_intrinsic_riled(board[0][0])
    capture_advance_charge_permission(board, unit_id(0))
    let selected = board[0].history.advance_allows_charge
    board[0][0].rule_effects.clear()
    capture_faction_selected_move(board, unit_id(0), MovementKind::advance)
    return selected and board[0].history.advance_allows_charge and !unit_is_riled_up(board[0])


# A generic source-owned status uses the same install/remove/duplicate path
# as other rule effects. No dedicated army lifecycle hook is needed.
# Infrastructure for persisting effects01.02.02, independent of status meaning.
fun test_ability_hooks_status_lifecycle_preserves_other_sources() -> Bool:
    let board = attack_declaration_fixture()
    let grant : RuleEffectGrant
    grant.kind = RuleEffectKind::riled_up
    grant.amount = 1
    let payload : SourceGrant
    payload = grant
    let first : SourceEffectKey
    let second : SourceEffectKey
    first = 31
    second = 32
    install_source_grant(board[0][0], payload, first)
    install_source_grant(board[0][0], payload, second)
    remove_source_grant(board[0][0], first)
    return board[0][0].rule_effects.size() == 1 and board[0][0].rule_effects[0].source_effect == second and model_has_source_grant(board[0][0], second) and !model_has_source_grant(board[0][0], first)


# Newly generalized modifier terms must pass ordinary save validation too.
# A forged divide-by-zero is rejected before core evaluates it (02.02.01).
fun test_ability_hooks_reject_invalid_unit_hit_term_on_save() -> Bool:
    let board = attack_declaration_fixture()
    let term = rule_modifier(ModifierOperation::divide, 1)
    term.amount = 0
    board.attack_info.unit_ability_hit_modifiers.append(term)
    return !valid_attack_results(board)


# Every supported term must fit simultaneously. Generalizing the old Boolean
# adds16 independent ability terms, not one slot (core p18; appendix02.02.02).
fun test_ability_hooks_full_hit_modifier_envelope() -> Bool:
    let board = attack_declaration_fixture()
    let info : AttackSequenceInfo
    for index in range(MAX_DATASHEET_HIT_MODIFIERS):
        info.unit_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    for index in range(16):
        info.attack_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
        info.unit_ability_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    info.hit_roll_bonus = true
    info.hit_roll_malus = true
    info.profile_hit_roll_bonus.append(info.source_profile)
    info.damaged_hit_penalty = true
    info.heavy_bonus = true
    info.selected_weapon_rules.append(weapon_rule(WeaponRuleKind::heavy))
    info.weapon_rules_known = true
    info.engaged_hit_penalties = 2
    let choices = attack_hit_choices(board, info)
    return choices.size() == MAX_ATTACK_MODIFIER_CHOICES
