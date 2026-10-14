"""Deterministic game-rule regressions, implemented entirely in Python.

Rule/page citations and scenarios preserve the original Rulebook suite.
Use native value copies explicitly; Python assignment otherwise aliases.
"""
from bindings import rl, copy as value_copy, assign


# ANTI grants in the temporary attack list must obey their source exclusion,
# just as selected/intrinsic instances do (p.79; appendix02.05.01).
# Appendix02.02.01: modifications are cumulative, ordered and bearer-scoped.
# Fixed weapon consumers: appendix02.02.01, targeting p.16, grouping p.17,
# wound/hit p.18, saves p.19. Fixtures do not grant new Orks abilities.
def orks17c2b_info(board, slot):
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, slot))
    return value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))

# A weapon-specific increment affects its slot, not its neighbour or other bearer.
def test_orks17c2b_strength_slot_and_bearer_scope():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.append(rl.Weapon.librarian_storm_bolter())
    board[0][0].characteristic_modifiers.append(rl.weapon_characteristic_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 3, 0))
    first = value_copy(orks17c2b_info(board, 0))
    second = value_copy(orks17c2b_info(board, 1))
    return first.attack_strength() == 7 and second.attack_strength() == 4 and (first.target_toughness.value == 4)

# Bearer BS affects all ranged profiles; WS applies to melee instead (02.02.01).
def test_orks17c2b_all_weapon_skills_and_melee_scope():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.append(rl.Weapon.librarian_storm_bolter())
    board[0][0].weapons.append(rl.Weapon.close_combat_weapon())
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.ballistic_skill(), rl.ModifierOperation.add(), 1))
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.weapon_skill(), rl.ModifierOperation.subtract(), 1))
    first = value_copy(orks17c2b_info(board, 0))
    second = value_copy(orks17c2b_info(board, 1))
    melee = value_copy(orks17c2b_info(board, 2))
    return rl.effective_attack_skill(board, first) == 3 and rl.effective_attack_skill(board, second) == 4 and (rl.effective_attack_skill(board, melee) == 2)

# Cover's BS increment is before division and final rounding, not added later.
def test_orks17c2b_cover_uses_modifier_operation_order():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.slugga()
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.ballistic_skill(), rl.ModifierOperation.divide(), 2))
    board.attack_info.target_has_cover = True
    info = value_copy(orks17c2b_info(board, 0))
    return rl.effective_attack_skill(board, info) == 3

# A later chosen Ignores Cover still cancels the core increment before arithmetic.
def test_orks17c2b_late_ignore_cover_recomputes_skill():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.cultist_bolt_pistol()
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.ballistic_skill(), rl.ModifierOperation.divide(), 2))
    board.attack_info.target_has_cover = True
    info = value_copy(orks17c2b_info(board, 0))
    if rl.effective_attack_skill(board, info) != 3:
        return False
    info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.ignore_cover()))
    return rl.effective_attack_skill(board, info) == 2

# Effective S changes both the wound table and the greater-S protection gate.
def test_orks17c2b_strength_drives_wound_threshold():
    board = value_copy(attack_declaration_fixture())
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 5))
    board[1][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 4))
    info = value_copy(orks17c2b_info(board, 0))
    if rl.required_wound_roll(board, info) != 3:
        return False
    info.greater_strenght_wound_protection = True
    return rl.required_wound_roll(board, info) == 4

# Effective AP participates in the actual save predicate (p.19).
def test_orks17c2b_armour_penetration_changes_save():
    board = value_copy(attack_declaration_fixture())
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.armour_penetration(), rl.ModifierOperation.subtract(), 1))
    info = value_copy(orks17c2b_info(board, 0))
    group = rl.new('AllocationGroup')
    group.save = 3
    group.invulnerable = 10
    face = rl.new('Dice')
    assign(face, 3)
    return info.attack_penetration() == -1 and (not rl.attack_save_succeeds(group, face, info.attack_penetration())) and rl.attack_save_succeeds(group, face, 0)

# Legacy explicit AP increments obey the same order; do not subtract after rounding.
def test_orks17c2b_ap_increment_precedes_division():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.plasma_pistol_standard()
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.armour_penetration(), rl.ModifierOperation.divide(), 2))
    info = value_copy(orks17c2b_info(board, 0))
    info.penetration_bonus = True
    return info.attack_penetration() == -1

# Zero replacements lock core increments, and worsened AP never becomes positive.
def test_orks17c2b_ap_zero_lock_and_worsening_limit():
    board = value_copy(attack_declaration_fixture())
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.armour_penetration(), rl.ModifierOperation.add(), 20))
    worsened = value_copy(orks17c2b_info(board, 0))
    if worsened.attack_penetration() != 0:
        return False
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.armour_penetration(), rl.ModifierOperation.replace(), 0))
    locked = value_copy(orks17c2b_info(board, 0))
    locked.penetration_bonus = True
    return locked.attack_penetration() == 0

# Different raw BS profiles may group when their effective characteristics agree.
def test_orks17c2b_group_identity_uses_effective_skill():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.append(rl.Weapon.librarian_storm_bolter())
    board[0][0].characteristic_modifiers.append(rl.weapon_characteristic_modifier(rl.ModifiedCharacteristic.ballistic_skill(), rl.ModifierOperation.subtract(), 1, 1))
    left = value_copy(orks17c2b_info(board, 0))
    right = value_copy(orks17c2b_info(board, 1))
    if not rl.attacks_are_identical(board, left, right):
        return False
    # Same effective AP from different records must still group (p.17).
    left.penetration_bonus = True
    right.ap_modifiers.append(rl.rule_modifier(rl.ModifierOperation.subtract(), 1))
    return rl.attacks_are_identical(board, left, right)

# Same raw profile with different effective S must resolve as separate groups.
def test_orks17c2b_group_identity_splits_effective_strength():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.append(rl.Weapon.captain_storm_bolter())
    board[0][0].characteristic_modifiers.append(rl.weapon_characteristic_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 1, 1))
    left = value_copy(orks17c2b_info(board, 0))
    right = value_copy(orks17c2b_info(board, 1))
    return not rl.attacks_are_identical(board, left, right)

# Current T for a new group replaces the enclosing target's stale initial snapshot.
def test_orks17c2b_target_toughness_refresh_after_casualty():
    board = value_copy(damage_test_fixture())
    board[1][1].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 4))
    rl.configure_attack_info(board, 0, 1, False, False)
    first = value_copy(orks17c2b_info(board, 0))
    board[1].remove_model(1)
    next = value_copy(orks17c2b_info(board, 0))
    return first.target_toughness.value == 8 and next.target_toughness.value == 4 and (board.attack_info.target_toughness.value == 8)

# Newly active target arithmetic also affects subsequent groups (02.02.01/05.02.01).
def test_orks17c2b_target_toughness_refresh_after_modifier():
    board = value_copy(attack_declaration_fixture())
    rl.configure_attack_info(board, 0, 1, False, False)
    board[1][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 2))
    next = value_copy(orks17c2b_info(board, 0))
    return next.target_toughness.value == 6 and board.attack_info.target_toughness.value == 4

# The new group's explicit identities control target-dependent rules, even
# when a neutral/stale enclosing context was supplied (pp.17/79;02.05.01).
def test_orks17c2b_group_identity_refreshes_target_keyword_subject():
    board = value_copy(attack_declaration_fixture())
    board[1][0].keywords.append(rl.Keyword.monster())
    board[2].owned_by_player1 = False
    board[2][0].position = board_position(5, 10)
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(2), 0, 0))
    declaration.current_target_rules.append(rl.conditional_weapon_rule(rl.WeaponRuleKind.anti_monster(), 3, rl.Keyword.monster()))
    neutral = rl.new('AttackSequenceInfo')
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(2), rl.unit_id(1), declaration, neutral))
    return info.source_unit_id.get() == 2 and info.target_unit_id.get() == 1 and (rl.critical_wound_threshold(board, info) == 3)

# Actual target legality and replacement eligibility use effective Range (p.16/04.03.03).
def test_orks17c2b_effective_range_changes_target_legality():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.bolt_pistol()
    board[1][0].position = board_position(25, 5)
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), False):
        return False
    board[0][0].characteristic_modifiers.append(rl.weapon_characteristic_modifier(rl.ModifiedCharacteristic.range(), rl.ModifierOperation.add(), 10, 0))
    return rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), False)

# Rapid Fire/Melta half-range is measured from the effective declaration Range.
def test_orks17c2b_half_range_snapshot_uses_effective_range():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.bolt_pistol()
    board[1][0].position = board_position(16, 5)
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    rl.snapshot_weapon_target(board, rl.unit_id(0), declaration, rl.unit_id(1))
    if declaration.half_range[1]:
        return False
    board[0][0].characteristic_modifiers.append(rl.weapon_characteristic_modifier(rl.ModifiedCharacteristic.range(), rl.ModifierOperation.multiply(), 2, 0))
    rl.snapshot_weapon_target(board, rl.unit_id(0), declaration, rl.unit_id(1))
    return declaration.half_range[1]

# 'Melee' Range and '-' Torrent skill remain special, regardless of arithmetic.
def test_orks17c2b_special_melee_range_and_torrent_skill():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.close_combat_weapon()
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.range(), rl.ModifierOperation.add(), 20))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if rl.declaration_weapon_range(board, rl.unit_id(0), declaration) != 0:
        return False
    board[0][0].weapons[0] = rl.Weapon.pyreblaster()
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.ballistic_skill(), rl.ModifierOperation.add(), 3))
    info = value_copy(orks17c2b_info(board, 0))
    return rl.effective_attack_skill(board, info) == 0

# Firing Deck uses carrier-wide modifiers, never its unrelated equipped slot grant.
def test_orks17c2b_borrowed_weapon_modifier_scope():
    board = value_copy(attack_declaration_fixture())
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 1))
    board[0][0].characteristic_modifiers.append(rl.weapon_characteristic_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 5, 0))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    own = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    declaration.borrowed_weapon = True
    borrowed = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    return own.attack_strength() == 10 and borrowed.attack_strength() == 5

# Invalid scope/kind and nonexistent equipped slots cannot survive saved roots.
def test_orks17c2b_invalid_weapon_modifier_scope_rejected():
    board = value_copy(attack_declaration_fixture())
    board[0][0].characteristic_modifiers.append(rl.weapon_characteristic_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 1, 7))
    if rl.valid_state_foundations(board):
        return False
    board[0][0].characteristic_modifiers.clear()
    malformed = value_copy(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 1))
    malformed.weapon_scope = 1
    board[0][0].characteristic_modifiers.append(malformed)
    return not rl.valid_state_foundations(board)

# Stored skill/AP operations need the same invalid-divisor checks before restore.
def test_orks17c2b_invalid_attack_snapshot_modifiers_rejected():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.skill_modifiers.append(rl.rule_modifier(rl.ModifierOperation.divide(), 0))
    if rl.valid_state_foundations(board):
        return False
    board.attack_info.skill_modifiers.clear()
    board.attack_info.ap_modifiers.append(rl.rule_modifier(rl.ModifierOperation.divide(), -1))
    return not rl.valid_state_foundations(board)

# Real Game serialization preserves scoped data and gathered bounded S/operations.
def test_orks17c2b_saved_weapon_characteristics_round_trip():
    state = value_copy(rl.play())
    state.board = attack_declaration_fixture()
    state.board[0][0].characteristic_modifiers.append(rl.weapon_characteristic_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, 0))
    state.board.attack_info = orks17c2b_info(state.board, 0)
    restored = value_copy(rl.play())
    return rl.set_state(restored, rl.to_string(state)) and restored.board.attack_info.attack_strength() == 6 and (restored.board[0][0].characteristic_modifiers[0].weapon_scope.value == 1)

def test_orks17c2_model_modifier_order_and_scope():
    unit = value_copy(rl.make_infernus_squad())
    model = unit[0]
    model.characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.subtract(), 1))
    model.characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.divide(), 2))
    model.characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 1))
    model.characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.multiply(), 2))
    model.characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.replace(), 7))
    model.characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.save(), rl.ModifierOperation.add(), 1))
    return model.effective_toughness() == 7 and unit[1].effective_toughness() == 4 and (model.effective_save() == 4)

# Appendix05.02.01: strongest T can occur after the first model and can change.
def test_orks17c2_mixed_toughness_highest_and_casualty():
    unit = value_copy(rl.make_infernus_squad())
    unit[1].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 3))
    if unit.get_unit_toughtness() != 7:
        return False
    unit.remove_model(1)
    return unit.get_unit_toughtness() == 4

# Offboard models do not provide T; Fight on Death models remain on the
# battlefield and in their unit until removal (05.02.01/supplied Fight on Death).
def test_orks17c2_toughness_ignores_unavailable_models():
    unit = value_copy(rl.make_infernus_squad())
    unit[1].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 20))
    unit[1].off_battlefield = True
    if unit.get_unit_toughtness() != 4:
        return False
    unit[1].off_battlefield = False
    unit[1].suffered_wounds = unit[1].profile.wounds()
    unit[1].state = rl.ModelState.fight_on_death()
    if unit.get_unit_toughtness() != 24:
        return False
    unit.remove_model(1)
    return unit.get_unit_toughtness() == 4

# Real attack preparation reads the mixed effective T, not static enum data (p.18).
def test_orks17c2_attack_snapshots_effective_toughness():
    board = value_copy(damage_test_fixture())
    board[1][1].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 4))
    rl.configure_attack_info(board, 0, 1, False, False)
    return board.attack_info.target_toughness.value == 8

# M modifiers apply to the determined random M, before Advance extras (02.02.03/p.33).
def test_orks17c2_movement_fixed_and_random_budget():
    unit = value_copy(rl.make_infernus_squad())
    unit[0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.movement(), rl.ModifierOperation.add(), 2))
    unit[0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.movement(), rl.ModifierOperation.subtract(), 1))
    return rl.model_move_budget(unit[0], rl.MovementKind.normal(), 3, 0, False) == 10 and rl.model_move_budget(unit[0], rl.MovementKind.normal(), 3, 5, False) == 8 and (rl.model_move_budget(unit[0], rl.MovementKind.scout(), 4, 0, False) == 4)

# Replacement zero locks further arithmetic, including characteristic minima (02.02.01).
def test_orks17c2_zero_replacement_locks_model_characteristic():
    unit = value_copy(rl.make_infernus_squad())
    unit[0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.movement(), rl.ModifierOperation.replace(), 0))
    unit[0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.movement(), rl.ModifierOperation.add(), 9))
    return rl.model_move_budget(unit[0], rl.MovementKind.normal(), 0, 0, False) == 0

# p.19: per-model modified Sv splits otherwise identical allocation groups.
def test_orks17c2_save_group_effective_characteristics():
    board = value_copy(damage_test_fixture())
    board[1][1].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.save(), rl.ModifierOperation.subtract(), 1))
    groups = value_copy(rl.make_allocation_groups(board, board[1], board.attack_info))
    face = rl.new('Dice')
    assign(face, 2)
    return groups.size() == 2 and groups[0].save.value == 3 and (groups[1].save.value == 2) and (not rl.attack_save_succeeds(groups[0], face, 0)) and rl.attack_save_succeeds(groups[1], face, 0)

# '-' InSv cannot acquire a save by arithmetic; valid InSv is bounded at2+ (02.02.01).
def test_orks17c2_invulnerable_special_and_floor():
    unit = value_copy(rl.make_infernus_squad())
    unit[0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.invulnerable_save(), rl.ModifierOperation.subtract(), 9))
    captain = value_copy(rl.make_octavius())
    captain[0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.invulnerable_save(), rl.ModifierOperation.subtract(), 9))
    return unit[0].effective_invulnerable_save() == unit[0].profile.invuln_save() and captain[0].effective_invulnerable_save() == 2

# Leadership takes the best modified bearer value, within5+..8+ (p.9/02.02.01).
def test_orks17c2_leadership_effective_limits():
    unit = value_copy(rl.make_infernus_squad())
    for i in range(unit.models.size()):
        unit[i].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.leadership(), rl.ModifierOperation.add(), 9))
    if unit.get_leadership() != 8:
        return False
    unit[1].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.leadership(), rl.ModifierOperation.subtract(), 20))
    return unit.get_leadership() == 5 and unit.leadership_roll_succeeds(5) and (not unit.leadership_roll_succeeds(4))

# OC bonuses are bearer-scoped; Battle-shock's '-' defeats all of them (p.9).
def test_orks17c2_objective_control_scope_and_shock():
    unit = value_copy(rl.make_infernus_squad())
    unit[0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.objective_control(), rl.ModifierOperation.add(), 3))
    if unit.model_objective_control(0) != 4 or unit.model_objective_control(1) != 1:
        return False
    unit.battle_socked = True
    return unit.model_objective_control(0) == 0 and unit.model_objective_control(1) == 0

# Save roots/archives reject invalid divisors before arithmetic (02.02.01 infrastructure).
def test_orks17c2_invalid_modifier_metadata_rejected():
    board = value_copy(damage_test_fixture())
    board[1][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.save(), rl.ModifierOperation.divide(), 0))
    if rl.valid_state_foundations(board):
        return False
    board[1].remove_model(0)
    return not rl.valid_state_foundations(board)

# Persisted modifiers survive the real atomic Game snapshot restore (02.02.01).
def test_orks17c2_modifier_saved_state_round_trip():
    state = value_copy(rl.play())
    state.board.units.append(rl.make_infernus_squad())
    state.board.identify_units()
    state.board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 2))
    restored = value_copy(rl.play())
    return rl.set_state(restored, rl.to_string(state)) and restored.board[0].get_unit_toughtness() == 6

def test_orks17c_temporary_anti_obeys_exclusion():
    board = value_copy(orks17c_mixed_keyword_fixture())
    board[1][0].keywords.append(rl.Keyword.monster())
    info = value_copy(board.attack_info)
    info.temporary_weapon_abilities.append(rl.conditional_weapon_rule(rl.WeaponRuleKind.anti_monster(), 3, orks17c_combined_predicate()))
    if rl.critical_wound_threshold(board, info) != 3:
        return False
    board[1][0].keywords.append(rl.Keyword.titanic())
    return rl.critical_wound_threshold(board, info) == 6

# A matching ANTI family cannot override a missing ALL keyword. Keep VEHICLE
# present to prove this is the condition gate, not the family gate (p.79).
def test_orks17c_temporary_anti_requires_all_keywords():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = rl.new('KeywordPredicate')
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.all(), rl.Keyword.character()), "fixture condition"
    info = value_copy(board.attack_info)
    info.temporary_weapon_abilities.append(rl.conditional_weapon_rule(rl.WeaponRuleKind.anti_vehichle(), 3, predicate))
    if rl.critical_wound_threshold(board, info) != 3:
        return False
    board[1][1].keywords.clear()
    board[1][1].keywords.append(rl.Keyword.vehicle())
    return rl.critical_wound_threshold(board, info) == 6


# Clause groups must remain correct when datasheet fields are loaded in any
# order; inserting ALL before existing ANY/NONE terms must not change meaning.
def test_orks17c_keyword_group_insertion_order():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = rl.new('KeywordPredicate')
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.none(), rl.Keyword.titanic()), "fixture condition"
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.any(), rl.Keyword.vehicle()), "fixture condition"
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.all(), rl.Keyword.infantry()), "fixture condition"
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.any(), rl.Keyword.monster()), "fixture condition"
    rule = value_copy(rl.conditional_weapon_rule(rl.WeaponRuleKind.sustained_hit(), 2, predicate))
    return rl.unit_matches_keywords(board[1], predicate) and predicate.size() == 4 and (predicate.required_count.value == 1) and (predicate.alternative_count.value == 2) and (predicate.excluded_count.value == 1) and (rl.weapon_ability_condition_keyword(rule, 0) == rl.Keyword.infantry()) and (rl.weapon_ability_condition_clause(rule, 1) == rl.KeywordClause.any()) and (rl.weapon_ability_condition_keyword(rule, 3) == rl.Keyword.titanic())

# Each scalar count can be individually in bounds while their sum exceeds the
# fixed array. Saved metadata must reject this before lookup/editor rendering.
def test_orks17c_keyword_group_total_rejects_invalid_save():
    state = value_copy(rl.play())
    state.board = orks17c_mixed_keyword_fixture()
    state.board.pending_weapon_abilities.append(rl.conditional_weapon_rule(rl.WeaponRuleKind.sustained_hit(), 2, orks17c_combined_predicate()))
    before = value_copy(rl.to_string(state))
    corrupt = value_copy(state)
    corrupt.board.pending_weapon_abilities[0].target_condition.required_count = 4
    corrupt.board.pending_weapon_abilities[0].target_condition.alternative_count = 4
    corrupt.board.pending_weapon_abilities[0].target_condition.excluded_count = 4
    return not rl.unit_matches_keywords(corrupt.board[1], corrupt.board.pending_weapon_abilities[0].target_condition) and (not rl.set_state(state, rl.to_string(corrupt))) and (rl.to_string(state) == before)


# Appendix02.05.01, https://wahapedia.ru/wh40k11ed/the-rules/rules-appendix/:
# an explicit fixture isolates keyword logic from old faction data.
def orks17c_mixed_keyword_fixture():
    board = value_copy(shooting12_fixture())
    board[1].models.resize(2)
    board[1][0].keywords.clear()
    board[1][1].keywords.clear()
    board[1][0].keywords.append(rl.Keyword.infantry())
    board[1][1].keywords.append(rl.Keyword.character())
    board[1][1].keywords.append(rl.Keyword.vehicle())
    return value_copy(board)

# Adjacent INFANTRY plus slash MONSTER/VEHICLE excluding TITANIC: the source
# list means ALL AND ANY AND NONE, not a positive OR across every term.
def orks17c_combined_predicate():
    predicate = rl.new('KeywordPredicate')
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.all(), rl.Keyword.infantry()), "fixture condition"
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.any(), rl.Keyword.monster()), "fixture condition"
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.any(), rl.Keyword.vehicle()), "fixture condition"
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.none(), rl.Keyword.titanic()), "fixture condition"
    return value_copy(predicate)

# Empty conditions do not add an artificial keyword requirement (p.78).
def test_orks17c_empty_keyword_condition():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = rl.new('KeywordPredicate')
    return rl.unit_matches_keywords(board[1], predicate) and rl.model_matches_keywords(board[1][0], predicate)

# Appendix02.05.01: different models can supply adjacent UNIT keywords;
# neither individual MODEL inherits a keyword from the other bearer.
def test_orks17c_all_keywords_unit_union_and_model_scope():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = rl.new('KeywordPredicate')
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.all(), rl.Keyword.infantry()), "fixture condition"
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.all(), rl.Keyword.character()), "fixture condition"
    return rl.unit_matches_keywords(board[1], predicate) and (not rl.model_matches_keywords(board[1][0], predicate)) and (not rl.model_matches_keywords(board[1][1], predicate))

# Appendix02.05.01: slashes/or mean any one listed keyword.
def test_orks17c_any_keyword_alternatives():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = rl.new('KeywordPredicate')
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.any(), rl.Keyword.monster()), "fixture condition"
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.any(), rl.Keyword.vehicle()), "fixture condition"
    return rl.unit_matches_keywords(board[1], predicate) and (not rl.model_matches_keywords(board[1][0], predicate)) and rl.model_matches_keywords(board[1][1], predicate)

# Appendix02.05.01: one VEHICLE bearer excludes the entire non-VEHICLE unit,
# but does not turn the other individual model into a VEHICLE model.
def test_orks17c_none_keywords_mixed_unit_exclusion():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = rl.new('KeywordPredicate')
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.none(), rl.Keyword.vehicle()), "fixture condition"
    return not rl.unit_matches_keywords(board[1], predicate) and rl.model_matches_keywords(board[1][0], predicate) and (not rl.model_matches_keywords(board[1][1], predicate))

# Combine ALL/ANY/NONE as conjunctions of clauses (appendix02.05.01).
def test_orks17c_combined_keyword_clauses():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = value_copy(orks17c_combined_predicate())
    if not rl.unit_matches_keywords(board[1], predicate) or rl.model_matches_keywords(board[1][0], predicate):
        return False
    board[1][0].keywords.append(rl.Keyword.titanic())
    return not rl.unit_matches_keywords(board[1], predicate)

# Adjacent required keywords must not be weakened by a matching ANY clause.
def test_orks17c_any_does_not_override_missing_all():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = value_copy(orks17c_combined_predicate())
    board[1][0].keywords.clear()
    return not rl.unit_matches_keywords(board[1], predicate)

# ALL X plus NONE X is a contradiction, not an implicit exception.
def test_orks17c_contradictory_keyword_condition():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = rl.new('KeywordPredicate')
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.all(), rl.Keyword.infantry()), "fixture condition"
    assert rl.append_keyword_condition(predicate, rl.KeywordClause.none(), rl.Keyword.infantry()), "fixture condition"
    return not rl.unit_matches_keywords(board[1], predicate) and (not rl.model_matches_keywords(board[1][0], predicate))

# Duplicate identical metadata terms must not consume finite storage.
def test_orks17c_duplicate_condition_is_idempotent():
    predicate = rl.new('KeywordPredicate')
    if not rl.append_keyword_condition(predicate, rl.KeywordClause.all(), rl.Keyword.infantry()):
        return False
    before = value_copy(rl.to_string(predicate))
    return rl.append_keyword_condition(predicate, rl.KeywordClause.all(), rl.Keyword.infantry()) and rl.to_string(predicate) == before

# Preserve the old nine-keyword capacity; overflow is explicit and atomic.
def test_orks17c_keyword_condition_capacity():
    predicate = rl.new('KeywordPredicate')
    keyword = rl.new('Keyword')
    for index in range(rl.MAX_KEYWORD_TERMS):
        keyword.value = index
        if not rl.append_keyword_condition(predicate, rl.KeywordClause.any(), keyword):
            return False
    if not rl.append_keyword_condition(predicate, rl.KeywordClause.any(), keyword):
        return False
    before = value_copy(rl.to_string(predicate))
    keyword.value = rl.MAX_KEYWORD_TERMS
    return not rl.append_keyword_condition(predicate, rl.KeywordClause.any(), keyword) and rl.to_string(predicate) == before and (predicate.size() == rl.MAX_KEYWORD_TERMS)

# Unknown numeric keywords cannot make a non-keyword condition accidentally
# true; malformed clause/count inputs are rejected before array indexing.
def test_orks17c_invalid_condition_inputs_are_atomic():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = rl.new('KeywordPredicate')
    invalid = rl.new('Keyword')
    invalid.value = -1
    if rl.append_keyword_condition(predicate, rl.KeywordClause.none(), invalid):
        return False
    invalid.value = 127
    if rl.append_keyword_condition(predicate, rl.KeywordClause.none(), invalid):
        return False
    clause = rl.new('KeywordClause')
    clause.value = 3
    return not rl.append_keyword_condition(predicate, clause, rl.Keyword.infantry()) and predicate.size() == 0 and rl.unit_matches_keywords(board[1], predicate)

# Raw field corruption is recoverable and cannot cause an unsafe lookup.
def test_orks17c_invalid_condition_queries_fail_closed():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = value_copy(orks17c_combined_predicate())
    predicate.keywords[3].value = 127
    if rl.unit_matches_keywords(board[1], predicate):
        return False
    predicate = orks17c_combined_predicate()
    predicate.required_count.value = -1
    if rl.model_matches_keywords(board[1][0], predicate):
        return False
    predicate.required_count.value = 10
    return not rl.unit_matches_keywords(board[1], predicate)

# Existing slash metadata constructors retain their ANY meaning (p.78).
def test_orks17c_legacy_or_constructor_preserves_semantics():
    board = value_copy(orks17c_mixed_keyword_fixture())
    rule = value_copy(rl.conditional_weapon_rule(rl.WeaponRuleKind.sustained_hit(), 2, rl.Keyword.monster(), rl.Keyword.vehicle()))
    return board[1].weapon_rule_applies(rule) and rule.target_condition.size() == 2 and (rl.weapon_ability_condition_clause(rule, 0) == rl.KeywordClause.any())

# p.78: applicability gates both presence and magnitude of the selected rule.
def test_orks17c_selected_weapon_condition_presence_and_parameter():
    board = value_copy(orks17c_mixed_keyword_fixture())
    rules = rl.new('WeaponAbilitySet')
    rules.append(rl.conditional_weapon_rule(rl.WeaponRuleKind.sustained_hit(), 2, orks17c_combined_predicate()))
    if not rl.chosen_weapon_has_rule(board, rl.unit_id(1), rules, rl.WeaponRuleKind.sustained_hit()) or rl.chosen_weapon_parameter(board, rl.unit_id(1), rules, rl.WeaponRuleKind.sustained_hit()) != 2:
        return False
    board[1][0].keywords.append(rl.Keyword.titanic())
    return not rl.chosen_weapon_has_rule(board, rl.unit_id(1), rules, rl.WeaponRuleKind.sustained_hit()) and rl.chosen_weapon_parameter(board, rl.unit_id(1), rules, rl.WeaponRuleKind.sustained_hit()) == 0

# ANTI's unmodified threshold also honours the whole condition (p.79).
def test_orks17c_anti_uses_conjunctive_target_condition():
    board = value_copy(orks17c_mixed_keyword_fixture())
    info = value_copy(board.attack_info)
    info.weapon_rules_known = True
    info.selected_weapon_rules.append(rl.conditional_weapon_rule(rl.WeaponRuleKind.anti(), 3, orks17c_combined_predicate()))
    if rl.critical_wound_threshold(board, info) != 3:
        return False
    board[1][1].keywords.append(rl.Keyword.titanic())
    return rl.critical_wound_threshold(board, info) == 6

# Hunter profiles use the same unit condition at declaration/revalidation
# (appendix04.01.03/04.03.03), rather than accepting any one positive keyword.
def test_orks17c_hunter_all_any_none_targeting():
    board = value_copy(orks17c_mixed_keyword_fixture())
    board[0][0].hunter_profile_conditions[0] = rl.conditional_weapon_rule(rl.WeaponRuleKind.anti(), 0, orks17c_combined_predicate())
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if not rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False):
        return False
    board[1][0].keywords.append(rl.Keyword.titanic())
    return not rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False)

# Keyword-union conditions change when a bearer actually leaves the unit
# (appendix02.05.01; destruction p.87), not when another model is inspected.
def test_orks17c_keyword_union_after_casualty_removal():
    board = value_copy(orks17c_mixed_keyword_fixture())
    predicate = value_copy(orks17c_combined_predicate())
    if not rl.unit_matches_keywords(board[1], predicate):
        return False
    board[1].remove_model(1)
    return not rl.unit_matches_keywords(board[1], predicate)

# Duplicate selection copies the selected source condition through save/restore
# and does not merge a different duplicate's restriction (p.78).
def test_orks17c_pending_ability_choice_condition_round_trip():
    board = value_copy(orks17c_mixed_keyword_fixture())
    rules = rl.new('WeaponAbilitySet')
    rules.append(rl.weapon_rule(rl.WeaponRuleKind.sustained_hit(), 1))
    rules.append(rl.conditional_weapon_rule(rl.WeaponRuleKind.sustained_hit(), 2, orks17c_combined_predicate()))
    pending = value_copy(rl.choose_weapon_abilities(board, rules))
    restored = value_copy(rl.choose_weapon_abilities(board, rules))
    if not rl.from_string(restored, rl.to_string(pending)):
        return False
    selected = rl.new('WeaponAbilityChoice')
    assign(selected, 1)
    restored.choose_weapon_ability(board, selected)
    return restored.is_done() and restored.chosen.size() == 1 and (restored.chosen[0].target_condition.size() == 4) and (rl.chosen_weapon_parameter(board, rl.unit_id(1), restored.chosen, rl.WeaponRuleKind.sustained_hit()) == 2)

# Save infrastructure preserves model grants, Hunter filters and chosen/pending
# attack metadata (p.78; appendix02.05.01), with atomic rejection on corruption.
def test_orks17c_condition_save_and_invalid_metadata_rejection():
    state = value_copy(rl.play())
    state.board = orks17c_mixed_keyword_fixture()
    rule = value_copy(rl.conditional_weapon_rule(rl.WeaponRuleKind.sustained_hit(), 2, orks17c_combined_predicate()))
    state.board[0][0].additional_weapon_rules[0].append(rule)
    state.board[0][0].hunter_profile_conditions[0] = rule
    state.board.pending_weapon_abilities.append(rule)
    state.board.attack_info.selected_weapon_rules.append(rule)
    restored = value_copy(rl.play())
    if not rl.set_state(restored, rl.to_string(state)) or not restored.board[1].weapon_rule_applies(restored.board[0][0].additional_weapon_rules[0][0]):
        return False
    before = value_copy(rl.to_string(restored))
    corrupt = value_copy(state)
    corrupt.board.pending_weapon_abilities[0].target_condition.keywords[0].value = 127
    return not rl.set_state(restored, rl.to_string(corrupt)) and rl.to_string(restored) == before

# Archived metadata must remain valid for later lifecycle consumers (p.88).
def test_orks17c_archived_hunter_condition_rejects_corruption():
    state = value_copy(rl.play())
    state.board = orks17c_mixed_keyword_fixture()
    state.board[0][0].hunter_profile_conditions[0] = rl.conditional_weapon_rule(rl.WeaponRuleKind.anti(), 0, orks17c_combined_predicate())
    state.board[0].remove_model(0)
    state.board[0].destroyed_models.value[0].hunter_profile_conditions[0].target_condition.keywords[0].value = 127
    return not rl.valid_state_foundations(state.board)


# User point-free/three-detachment scope; Orks faction source and core p.8.
def test_orks17b_roster_identities_and_armies():
    chaos = rl.new('UnitVector')
    orks = rl.new('UnitVector')
    chaos_roster = value_copy(rl.make_zarkan_deamonkin(chaos, False))
    ork_roster = value_copy(rl.make_orks_starter_roster(orks, True))
    return chaos_roster == rl.Faction.zarkan_daemonkin() and ork_roster == rl.Faction.morgrim_butchas() and (rl.army_faction_for_roster(chaos_roster) == rl.ArmyFaction.chaos_space_marines()) and (rl.army_faction_for_roster(ork_roster) == rl.ArmyFaction.orks()) and (rl.army_faction_for_roster(rl.Faction.strike_force_octavius()) == rl.ArmyFaction.space_marines()) and (rl.army_faction_for_roster(rl.Faction.vengeful_brethren()) == rl.ArmyFaction.space_marines()) and (rl.army_faction_for_roster(rl.Faction.insidious_infiltrators()) == rl.ArmyFaction.tyranids()) and (rl.army_faction_for_roster(rl.Faction.tristraen_gilded_blade()) == rl.ArmyFaction.adeptus_custodes())

# Three distinct packages, even War Horde plus two others, use no DP budget.
def test_orks17b_unique_three_package_bound():
    army = rl.new('ArmyConfiguration')
    army.faction = rl.ArmyFaction.orks()
    if not army.record_detachment(rl.OrksDetachment.war_horde()) or army.record_detachment(rl.OrksDetachment.war_horde()) or army.record_detachment(rl.OrksDetachment.none()):
        return False
    if not army.record_detachment(rl.OrksDetachment.da_big_hunt()) or not army.record_detachment(rl.OrksDetachment.green_tide()):
        return False
    before = value_copy(rl.to_string(army))
    return not army.record_detachment(rl.OrksDetachment.bully_boyz()) and rl.to_string(army) == before and (army.detachments.size() == 3) and rl.army_configuration_valid(army)

# Non-Orks do not receive Orks choices; raw enum corruption must reject safely.
def test_orks17b_non_orks_and_invalid_picks():
    army = rl.new('ArmyConfiguration')
    army.faction = rl.ArmyFaction.space_marines()
    if army.record_detachment(rl.OrksDetachment.war_horde()):
        return False
    army.faction = rl.ArmyFaction.orks()
    invalid = rl.new('OrksDetachment')
    invalid.value = -1
    if army.record_detachment(invalid):
        return False
    invalid.value = 16
    return not army.record_detachment(invalid) and army.detachments.empty()

# New configuration is independent of roster and the other player's picks.
def test_orks17b_game_handoff_and_pending_selection_save():
    state = value_copy(rl.play())
    state.pick_morgrim_butcha()
    state.choose_orks_detachment(rl.OrksDetachment.war_horde())
    state.choose_orks_detachment(rl.OrksDetachment.da_big_hunt())
    restored = value_copy(rl.play())
    if not rl.set_state(restored, rl.to_string(state).to_indented_lines()) or rl.get_current_player(restored) != 0 or restored.can_choose_orks_detachment(rl.OrksDetachment.war_horde()):
        return False
    restored.choose_orks_detachment(rl.OrksDetachment.green_tide())
    if restored.can_finish_orks_options():
        restored.finish_orks_options()
    if rl.get_current_player(restored) != 0 or not restored.can_choose_warlord_unit(rl.unit_id(0)):
        return False
    restored.choose_warlord_unit(rl.unit_id(0))
    restored.choose_warlord_model(damage_test_model(0))
    if rl.get_current_player(restored) != 1 or restored.can_choose_orks_detachment(rl.OrksDetachment.bully_boyz()):
        return False
    restored.pick_morgrim_butcha()
    restored.choose_orks_detachment(rl.OrksDetachment.bully_boyz())
    restored.finish_detachment_selection()
    if restored.can_finish_orks_options():
        restored.finish_orks_options()
    restored.choose_warlord_unit(rl.unit_id(4))
    restored.choose_warlord_model(damage_test_model(0))
    return restored.board.armies[0].detachments.size() == 3 and restored.board.armies[1].detachments.size() == 1 and (restored.board.armies[0].reserve_budget == rl.ReserveBudgetMode.point_free()) and (restored.board.armies[1].reserve_budget == rl.ReserveBudgetMode.point_free()) and rl.valid_state_foundations(restored.board)

# Up to three permits finishing with zero or two; no fourth decision remains.
def test_orks17b_optional_selection_zero_and_two():
    board = rl.new('Board')
    board.armies[0].faction = rl.ArmyFaction.orks()
    board.armies[1].faction = rl.ArmyFaction.orks()
    first = value_copy(rl.select_orks_detachments(board, False))
    first.finish_detachment_selection(board)
    second = value_copy(rl.select_orks_detachments(board, True))
    second.choose_orks_detachment(board, rl.OrksDetachment.war_horde())
    second.choose_orks_detachment(board, rl.OrksDetachment.bully_boyz())
    second.finish_detachment_selection(board)
    return first.is_done() and second.is_done() and board.armies[0].detachments.empty() and (board.armies[1].detachments.size() == 2) and board.current_decision_maker

# Serialized duplicates, wrong faction and invalid enum/mode values are not
# accepted as legal configuration (implementation invariant; source above).
def test_orks17b_reject_malformed_configuration_save():
    state = value_copy(rl.play())
    state.pick_morgrim_butcha()
    state.choose_orks_detachment(rl.OrksDetachment.war_horde())
    corrupt = value_copy(state)
    corrupt.board.armies[0].detachments.append(rl.OrksDetachment.war_horde())
    if rl.set_state(state, rl.to_string(corrupt)):
        return False
    corrupt = value_copy(state)
    corrupt.board.armies[0].faction = rl.ArmyFaction.tyranids()
    if rl.set_state(state, rl.to_string(corrupt)):
        return False
    corrupt = value_copy(state)
    corrupt.board.armies[0].reserve_budget.value = 2
    return not rl.set_state(state, rl.to_string(corrupt)) and state.board.armies[0].detachments.size() == 1

# User point-free mode bypasses only the p.68 pricing cap, not ownership,
# repeated choice, Fortification exclusion or mandatory Aircraft reserves.
def test_orks17b_point_free_reserve_permissions():
    board = rl.new('Board')
    board.reserve_units.append(rl.make_infernus_squad())
    board.identify_units()
    if rl.strategic_reserve_valid(board, False, rl.unit_id(0)):
        return False
    board.armies[0].reserve_budget = rl.ReserveBudgetMode.point_free()
    if not rl.strategic_reserve_valid(board, False, rl.unit_id(0)) or rl.strategic_reserve_valid(board, True, rl.unit_id(0)) or rl.strategic_reserve_valid(board, False, rl.unit_id(1)):
        return False
    board.reserve_units[0].history.strategic_reserve = True
    if rl.strategic_reserve_valid(board, False, rl.unit_id(0)):
        return False
    board.reserve_units[0].history.strategic_reserve = False
    board.reserve_units[0][0].keywords.append(rl.Keyword.fortification())
    return not rl.strategic_reserve_valid(board, False, rl.unit_id(0))

# Unknown passenger prices cannot block an explicitly point-free carrier.
# Point-aware mode still rejects them; no passenger pricing is introduced.
def test_orks17b_point_free_reserved_carrier_and_passengers():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    if not rl.reposition_unit(board, rl.unit_id(0)):
        return False
    board.reserve_units[0].history.strategic_reserve = False
    board.battle_points_limit = 100
    board.reserve_units[0].points_known = True
    board.reserve_units[0].points = 1
    if rl.strategic_reserve_valid(board, False, rl.unit_id(0)):
        return False
    board.armies[0].reserve_budget = rl.ReserveBudgetMode.point_free()
    return rl.strategic_reserve_valid(board, False, rl.unit_id(0))

# Source CP inventory: simultaneous selected packages share payer bookkeeping,
# but an unselected package grants no card (Orks cards; core p.54).
def orks17b_cp_fixture():
    board = value_copy(attack_fixture())
    board.identify_units()
    board.armies[0].faction = rl.ArmyFaction.orks()
    horde = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.war_horde()))
    swarm = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.runt_swarm()))
    flyers = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.flyboyz()))
    board.command_points[0] = 5
    return value_copy(board)

def test_orks17b_detachment_card_scope_and_base_cp():
    board = value_copy(orks17b_cp_fixture())
    if not board.can_use_strat(False, rl.Stratagem.orks_hit_em_harder()) or not board.can_use_strat(False, rl.Stratagem.orks_infested_war_zone()) or board.can_use_strat(False, rl.Stratagem.orks_dakkastorm()):
        return False
    board.command_points[0] = 1
    return rl.Stratagem.orks_infested_war_zone().cost() == 2 and rl.Stratagem.orks_hit_em_harder().cost() == 1 and (not board.can_use_strat(False, rl.Stratagem.orks_infested_war_zone())) and board.can_use_strat(False, rl.Stratagem.orks_hit_em_harder())

# Breakin' Heads overrides only shocked eligibility, preserving payment/use.
def test_orks17b_shocked_exception_preserves_cost_and_limits():
    board = value_copy(orks17b_cp_fixture())
    board[0].battle_socked = True
    if board.can_target_strat(False, rl.Stratagem.orks_hit_em_harder(), board[0]) or not board.try_use_strat(False, rl.Stratagem.orks_breakin_heads(), board[0], 1):
        return False
    return board.command_points[0] == 4 and (not board.can_target_strat(False, rl.Stratagem.orks_breakin_heads(), board[1])) and (not board.can_target_strat(False, rl.Stratagem.insane_bravery(), board[0]))

# The exception does not permit an unaffordable use or a foreign Orks target.
def test_orks17b_exception_rejection_is_atomic():
    board = value_copy(orks17b_cp_fixture())
    board[0].battle_socked = True
    board.command_points[0] = 0
    if board.try_use_strat(False, rl.Stratagem.orks_breakin_heads(), board[0], 1):
        return False
    board.command_points[0] = 5
    return not board.try_use_strat(False, rl.Stratagem.orks_breakin_heads(), board[1], 1) and board.command_points[0] == 5 and (not board.has_used_strat(rl.Stratagem.orks_breakin_heads(), 0)) and (not board[0].history.stratagem_targeted_by_player[0])

# Infested War Zone targets a real destroyed unit, not a live/empty placeholder;
# it remains 2CP and cannot be repeated or waive a shocked-target restriction.
def test_orks17b_destroyed_unit_exception():
    board = value_copy(orks17b_cp_fixture())
    if board.can_target_strat(False, rl.Stratagem.orks_infested_war_zone(), board[0]):
        return False
    while not board[0].models.empty():
        board[0].remove_model(0)
    empty = rl.new('Unit')
    if rl.destroyed_stratagem_target(empty) or board.can_target_strat(False, rl.Stratagem.orks_hit_em_harder(), board[0]):
        return False
    board[0].battle_socked = True
    if board.can_target_strat(False, rl.Stratagem.orks_infested_war_zone(), board[0]):
        return False
    board[0].battle_socked = False
    return board.try_use_strat(False, rl.Stratagem.orks_infested_war_zone(), board[0], 2) and board.command_points[0] == 3 and (not board.can_target_strat(False, rl.Stratagem.orks_infested_war_zone(), board[0]))

# Destroyed Aircraft can be retained pending demise; do not require a fully
# emptied vector to recognise this printed destruction-time target.
def test_orks17b_retained_destroyed_target_policy():
    board = value_copy(orks17b_cp_fixture())
    board[0].models.resize(1)
    board[0][0].state = rl.ModelState.pending_destruction()
    return board.can_target_strat(False, rl.Stratagem.orks_flyin_headbutt(), board[0]) and (not board.can_target_strat(False, rl.Stratagem.orks_infested_war_zone(), board[1]))

# Discount to zero and the +1CP Hulking Brutes option retain target limits;
# the cost primitive does not calculate points/DP (Orks cards; p.54).
def test_orks17b_zero_and_surcharged_cp_use():
    board = value_copy(orks17b_cp_fixture())
    board[1].owned_by_player1 = False
    board.armies[0].detachments.clear()
    selected = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.bully_boyz()))
    board.command_points[0] = 1
    if board.try_use_strat(False, rl.Stratagem.orks_hulking_brutes(), board[0], 2):
        return False
    board.command_points[0] = 2
    if not board.try_use_strat(False, rl.Stratagem.orks_hulking_brutes(), board[0], 2) or board.command_points[0] != 0:
        return False
    return not board.try_use_strat(False, rl.Stratagem.orks_armed_to_da_teef(), board[0], 0) and board.try_use_strat(False, rl.Stratagem.crushing_impact(), board[1], 0) and board.has_used_strat(rl.Stratagem.crushing_impact(), 0)

# Appendix02.02.01: final-cost overrides also obey the +1CP cap; invalid
# negative/excessive costs leave the balance and target bookkeeping intact.
def test_orks17b_final_cp_cost_cap():
    board = value_copy(orks17b_cp_fixture())
    if board.try_use_strat(False, rl.Stratagem.orks_hit_em_harder(), board[0], -1) or board.try_use_strat(False, rl.Stratagem.orks_hit_em_harder(), board[0], 3) or board.try_use_strat(False, rl.Stratagem.reroll(), board[0], 3):
        return False
    return board.command_points[0] == 5 and (not board[0].history.stratagem_targeted_by_player[0]) and board.can_target_strat_with_cost(False, rl.Stratagem.orks_hit_em_harder(), board[0], 2)

# Core p.54: each player's phase use is independent, and the next phase
# clears use records without changing selected packages or CP balances.
def test_orks17b_per_player_cp_and_phase_reset():
    board = value_copy(orks17b_cp_fixture())
    board.armies[1].faction = rl.ArmyFaction.orks()
    selected_other = value_copy(board.armies[1].record_detachment(rl.OrksDetachment.war_horde()))
    board.command_points[1] = 2
    if not board.try_use_strat(False, rl.Stratagem.orks_hit_em_harder(), board[0], 1) or not board.try_use_strat(True, rl.Stratagem.orks_hit_em_harder(), board[1], 1):
        return False
    board.begin_phase(rl.BattlePhase.fight())
    return board.command_points[0] == 4 and board.command_points[1] == 1 and board.can_target_strat(False, rl.Stratagem.orks_hit_em_harder(), board[0]) and board.can_target_strat(True, rl.Stratagem.orks_hit_em_harder(), board[1]) and (board.armies[0].detachments.size() == 3) and (board.armies[1].detachments.size() == 1)

# User-required quad representation: physical calculations (core pp.9/12)
# must not admit fractional model/path coordinates during this migration.
def test_geometry_preserves_whole_inch_quad_positions():
    unit = value_copy(rl.make_infernus_squad())
    point = value_copy(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH, 7 * rl.MICROMETRES_PER_INCH, 2 * rl.MICROMETRES_PER_INCH))
    unit[0].set_geometry_position(point)
    fractional = value_copy(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH + 1, 7 * rl.MICROMETRES_PER_INCH, 2 * rl.MICROMETRES_PER_INCH))
    return unit[0].position.x.value == 5 and unit[0].position.y.value == 7 and (unit[0].geometry.elevation.value == 2) and rl.geometry_point_on_grid(unit[0].geometry_position()) and (not rl.geometry_point_on_grid(fractional))

def attack_fixture():
    board = rl.new('Board')
    board.units.append(rl.make_infernus_squad())
    board.units.append(rl.make_infernus_squad())
    board[1].owned_by_player1 = True
    board.attack_info.source_unit_id = 0
    board.attack_info.target_unit_id = 1
    board.attack_info.source = rl.Weapon.captain_storm_bolter()
    board.attack_info.target_toughness = 4
    return value_copy(board)

# Rule 01.05, p.9, and 04.03, p.17: random characteristics expose bounded chance input.
def test_01_05_random_characteristic_legality():
    value = value_copy(rl.evaluate_random_stat(rl.dice_stat(3)))
    three = rl.new('Dice')
    assign(three, 3)
    four = rl.new('Dice')
    assign(four, 4)
    if not value.can_quantity(three) or value.can_quantity(four):
        return False
    value.quantity(three)
    return value.is_done() and value.result.value == 3

# Rule 05.01, p.18: an unmodified 1 fails without asking for wound/save allocation.
def test_05_01_one_fails_hit():
    board = value_copy(attack_fixture())
    sequence = value_copy(rl.single_attack(board, board[1], board[0]))
    one = rl.new('Dice')
    assign(one, 1)
    sequence.roll(board, board[1], board[0], one)
    return sequence.is_done() and board[1].models.size() == 5 and (board[1][0].suffered_wounds == 0)

# Rule 05.01, p.18: a successful supplied hit advances to the wound stage.
def test_05_01_successful_hit_advances_to_wound():
    board = value_copy(attack_fixture())
    sequence = value_copy(rl.single_attack(board, board[1], board[0]))
    six = rl.new('Dice')
    assign(six, 6)
    sequence.roll(board, board[1], board[0], six)
    return not sequence.is_done() and board.current_state.value == rl.CurrentStateDescription.wound_roll().value and sequence.can_roll(board, board[1], board[0], six)

# Supported contracts, not a snapshot approving known rule defects.
# Rule 05.02, p.18: equal Strength/Toughness requires 4+.
def test_05_02_equal_strength_toughness():
    board = rl.new('Board')
    board.units.append(rl.make_infernus_squad())
    info = rl.new('AttackSequenceInfo')
    info.source = rl.Weapon.captain_storm_bolter()
    info.target_toughness = info.source.strenght()
    return rl.required_wound_roll(board, info) == 4

# Rule 05.04, p.19: excess normal damage does not spill to another model.
def test_05_04_normal_damage_does_not_spill():
    unit = value_copy(rl.make_infernus_squad())
    if not unit.damage(0, 3):
        return False
    return unit.models.size() == 4 and unit[0].suffered_wounds == 0

# Rule 06.02, p.24: ordinary mortal wounds are applied one wound at a time.
def test_06_02_mortal_damage_spills():
    unit = value_copy(rl.make_infernus_squad())
    unit.deal_mortal_wound_damage(3)
    return unit.models.size() == 4 and unit[0].suffered_wounds == 1

# Rule 01.01, p.8: friendly/enemy follows army ownership, not turn owner.
def test_01_01_army_ownership_is_stable():
    board = rl.new('Board')
    board.units.append(rl.make_infernus_squad())
    board.units[0].owned_by_player1 = True
    board.current_player = False
    return board[0].owner_id() == 1

# Rule 09.05, p.33: a normal move may not exceed the model's movement budget.
def test_09_05_move_budget_legality():
    board = rl.new('Board')
    board.units.append(rl.make_infernus_squad())
    board[0].try_arrange_at(rl.make_board_position(5, 10))
    id = value_copy(rl.unit_id(0))
    movement = value_copy(rl.move(board, id, 0))
    return movement.can_move_to(board, id, rl.make_board_position(11, 10)) and (not movement.can_move_to(board, id, rl.make_board_position(12, 10)))

# Rule 01.05, p.9: supplied dice result is preserved when a free reroll is declined.
def test_01_05_declining_reroll_preserves_result():
    board = rl.new('Board')
    dice_roll = value_copy(rl.rerollable_dice_roll(board, True, False, False, False))
    dice = rl.new('Dice')
    assign(dice, 2)
    dice_roll.roll(board, dice)
    if not dice_roll.can_keep_it(board, True):
        return False
    dice_roll.keep_it(board, True)
    return dice_roll.is_done() and dice_roll.result == 2 and (board.command_points[0] == 0)

# Binding contract: phase-inappropriate actions must not enumerate as legal.
def test_game_initial_action_legality():
    game = value_copy(rl.play())
    return game.can_pick_insidious_infiltrators() and (not game.can_end_move()) and (rl.get_current_player(game) == 0)

# Binding contract: army selection advances ownership and preserves both armies.
def test_game_army_selection_transition():
    game = value_copy(rl.play())
    game.pick_insidious_infiltrators()
    if rl.get_current_player(game) != 1 or game.board.reserve_units.size() != 5:
        return False
    game.pick_strike_force_octavious()
    return game.board.reserve_units.size() == 9 and game.board.reserve_units[0].owner_id() == 0 and (game.board.reserve_units[5].owner_id() == 1)

# Replay contract: serialize/parse a populated unit without losing casualties or placement.
def test_unit_serialization_round_trip():
    original = value_copy(rl.make_infernus_squad())
    original.move_to(rl.make_board_position(10, 10))
    original.damage(0, 1)
    restored = rl.new('Unit')
    text = value_copy(rl.to_string(original))
    if not rl.from_string(restored, text):
        return False
    return restored.models.size() == 5 and restored[0].suffered_wounds == 1 and (restored[0].position.x == 10) and (restored[0].position.y == 10)

# Task 3 capacity regression; pp.30/33.
def test_08_02_core_cp_gain_not_truncated():
    board = rl.new('Board')
    board.command_points[0] = 3
    phase = value_copy(rl.command_phase(board))
    return board.command_points[0] == 4


# Task 3 capacity regression; pp.30/33.
def test_09_06_advance_increment_not_truncated():
    board = rl.new('Board')
    board.units.append(rl.make_infernus_squad())
    board[0].try_arrange_at(rl.make_board_position(2, 10))
    id = value_copy(rl.unit_id(0))
    movement = value_copy(rl.move(board, id, 5))
    return movement.can_move_to(board, id, rl.make_board_position(13, 10))


# Task 3: model/unit lifecycle, pp.19–24 and 86–88. Action slots stay positional;
# persistent handles follow the entity and return -1 when it is gone.
def test_identity_model_removal_does_not_retarget():
    board = rl.new('Board')
    board.units.append(rl.make_infernus_squad())
    board.identify_units()
    removed = value_copy(board[0][0].identity)
    survivor = value_copy(board[0][1].identity)
    board[0].damage(0, 2)
    return board[0].find_model(removed) == -1 and board[0].find_model(survivor) == 0 and (board[0].destroyed_models.value[0].identity == removed)

def test_identity_unit_slots_are_not_reassigned():
    board = rl.new('Board')
    board.units.append(rl.make_tantus())
    board.units.append(rl.make_octavius())
    board.identify_units()
    removed = value_copy(board[0].identity)
    survivor = value_copy(board[1].identity)
    board[0].damage(0, 100)
    board.remove_empty_units()
    return board.units.size() == 2 and board[0].retired and (board.find_unit(removed) == -1) and (board.find_unit(survivor) == 1)

# Attachment component provenance is retained; eligibility is task 6 (pp.66–67).
def test_attachment_preserves_component_identity():
    board = rl.new('Board')
    board.reserve_units.append(rl.make_infernus_squad())
    board.reserve_units.append(rl.make_tantus())
    board.identify_units()
    origin = value_copy(board.reserve_units[1].identity)
    model = value_copy(board.reserve_units[1][0].identity)
    board.reserve_units[1].attachment_role = rl.AttachmentRole.leader()
    board.reserve_units[1].attach_to(board.reserve_units[0])
    board.reserve_units[0].capture_starting_strength()
    return board.reserve_units[0].starting_strenght == 6 and board.reserve_units[0][5].identity == model and (board.reserve_units[0][5].original_unit == origin) and (board.reserve_units[0].attached_units[0].identity == origin) and (board.reserve_units[0].attached_units[0].starting_strength == 1)

# p.86: starting strength counts models, not the legal model-index domain.
def test_starting_strength_accepts_full_capacity():
    unit = rl.new('Unit')
    model = rl.new('Model')
    unit.models.resize(rl.MAX_UNIT_MODELS)
    unit.capture_starting_strength()
    return unit.starting_strenght == rl.MAX_UNIT_MODELS and (not unit.models.try_append(model)) and (unit.models.size() == rl.MAX_UNIT_MODELS)

def test_collection_overflow_is_explicit():
    collection = rl.new('CheckedVector<Int, 2>')
    collection.append(1)
    collection.append(2)
    return not collection.has_capacity() and (not collection.try_append(3)) and (collection.size() == 2) and (collection[1] == 2)

# pp.19–24: a large damage amount must destroy a model, not saturate below W.
def test_damage_storage_handles_large_attack():
    unit = value_copy(rl.make_tantus())
    if not unit.damage(0, 100):
        return False
    return unit.empty() and unit.destroyed_models.value[0].suffered_wounds == 100

# p.83 One Shot and p.88 returning models: preserve per-model usage in archives.
def test_destroyed_model_keeps_weapon_usage_history():
    unit = value_copy(rl.make_tantus())
    unit[0].used_once_per_battle_weapon[0] = True
    unit.damage(0, 100)
    copy = value_copy(unit)
    return copy.destroyed_models.value[0].used_once_per_battle_weapon[0]

# pp.78–88: deferred destruction also handles the first/only model.
def test_fight_on_death_removes_index_zero():
    unit = value_copy(rl.make_tantus())
    unit.damage(0, 100, True)
    if unit.models.size() != 1:
        return False
    unit.remove_figth_on_death_models()
    return unit.empty() and unit.destroyed_models.value.size() == 1

# p.30 CP and p.33 Advance storage; versions are implementation compatibility.
def test_schema_round_trip_and_legacy_rejection():
    state = value_copy(rl.play())
    state.board.command_points[0] = 100
    encoded = value_copy(rl.to_string(state))
    restored = value_copy(rl.play())
    if not rl.set_state(restored, encoded) or restored.board.command_points[0] != 100:
        return False
    state.board.schema_version.value = 1
    if rl.set_state(restored, rl.to_string(state)):
        return False
    return restored.board.command_points[0] == 100 and restored.board.schema_version.value == rl.STATE_SCHEMA_VERSION

def test_invalid_save_does_not_modify_state():
    state = value_copy(rl.play())
    state.board.command_points[0] = 42
    before = value_copy(rl.to_string(state))
    if rl.set_state(state, rl.s('invalid')):
        return False
    return rl.to_string(state) == before

def test_negative_cp_save_decode_is_rejected():
    state = value_copy(rl.play())
    state.board.command_points[0] = 42
    invalid = value_copy(state)
    invalid.board.command_points[0].value = -1
    return not rl.set_state(state, rl.to_string(invalid)) and state.board.command_points[0] == 42

def test_history_survives_copy_and_phase_reset():
    board = rl.new('Board')
    board.units.append(rl.make_tantus())
    board[0].history.last_ranged_attack_turn = 8
    board[0].history.used_stratagem_this_phase = True
    board.has_used_shadow_in_the_warp[0] = True
    copy = value_copy(board)
    copy.clear_phase_modifiers()
    return copy[0].history.last_ranged_attack_turn == 8 and (not copy[0].history.used_stratagem_this_phase) and copy.has_used_shadow_in_the_warp[0] and board[0].history.used_stratagem_this_phase

def test_duplicate_identity_save_is_rejected():
    state = value_copy(rl.play())
    state.pick_insidious_infiltrators()
    before = value_copy(rl.to_string(state))
    invalid = value_copy(state)
    invalid.board.reserve_units[1].identity = invalid.board.reserve_units[0].identity
    return not rl.set_state(state, rl.to_string(invalid)) and rl.to_string(state) == before

def test_empty_unit_is_not_a_shooting_target():
    board = value_copy(attack_fixture())
    board[0].can_shoot = True
    board[1].models.clear()
    phase = value_copy(rl.shooting_phase(board))
    source = value_copy(rl.unit_id(0))
    target = value_copy(rl.unit_id(1))
    return not phase.can_select_target(board, source, target) and phase.can_end_shooting_phase(board)

# Task 3 prerequisite: safe CP expenditure; p.54.
def test_15_01_actual_stratagem_cost():
    board = rl.new('Board')
    board.command_points[0] = 1
    return board.can_use_strat(False, rl.Stratagem.reroll())


# Task 3 prerequisite: safe CP expenditure; p.54.
def test_15_01_own_player_usage():
    board = rl.new('Board')
    board.command_points[0] = 3
    board.mark_strat_used(rl.Stratagem.reroll(), 0)
    return not board.can_use_strat(False, rl.Stratagem.reroll())


# pp.54/57: no affordable Overwatch source leaves no optional timing decision.
def test_overwatch_with_no_cp_cannot_spend():
    board = value_copy(core15_fixture())
    board.command_points[1] = 0
    sequence = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.movement_end()))
    return sequence.is_done() and board.command_points[1] == 0 and (not board.has_used_strat(rl.Stratagem.overwatch(), 1))

# pp.54/57: declining at the actual Movement-end boundary preserves CP/usage.
def test_declining_overwatch_preserves_cp_and_usage():
    board = value_copy(core15_fixture())
    board.command_points[1] = 1
    sequence = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.movement_end()))
    if not sequence.can_finish_timing_rules(board):
        return False
    sequence.finish_timing_rules(board)
    return sequence.is_done() and board.command_points[1] == 1 and (not board.has_used_strat(rl.Stratagem.overwatch(), 1))

def test_oversized_collection_decode_is_rejected():
    unchecked = rl.new('BoundedVector<Int, 2>')
    unchecked._data.append(1)
    unchecked._data.append(2)
    unchecked._data.append(3)
    checked = rl.new('CheckedVector<Int, 2>')
    checked.append(42)
    return not rl.from_string(checked, rl.to_string(unchecked)) and checked.size() == 1 and (checked[0] == 42)

def test_unassigned_identity_never_resolves():
    board = rl.new('Board')
    board.units.append(rl.make_tantus())
    unassigned = rl.new('EntityIdentity')
    return board.find_unit(unassigned) == -1 and board[0].find_model(unassigned) == -1

def test_phase_movement_and_setup_history():
    board = rl.new('Board')
    board.units.append(rl.make_tantus())
    board[0].mark_set_up()
    board[0].translate(3, 4)
    if not board[0][0].history.was_set_up_this_turn or board[0][0].history.distance_moved_this_turn() != 5.0:
        return False
    board.start_turn_history()
    return board.turn_serial == 1 and (not board[0].history.was_set_up_this_turn) and (not board[0][0].history.was_set_up_this_turn) and (board[0][0].history.distance_moved_this_turn() == 0.0)

# pp.54/56: own Command-step Bravery is charged to the active unit's owner.
def test_insane_bravery_charges_the_units_owner():
    board = value_copy(attack_fixture())
    board.command_points[1] = 1
    board.current_player = True
    board.begin_phase(rl.BattlePhase.command())
    sequence = value_copy(rl.battle_shock_test(board, board[1], True, False))
    if not sequence.can_insane_bravery(board, board[1], True):
        return False
    sequence.insane_bravery(board, board[1], True)
    return sequence.is_done() and board.command_points[0] == 0 and (board.command_points[1] == 0) and board.has_used_strat(rl.Stratagem.insane_bravery(), 1) and (not board.has_used_strat(rl.Stratagem.insane_bravery(), 0))

# User retires obsolete Orks cards: no pre-Fight bellow and no old defensive
# payloads remain. Core Pile In starts directly without spending CP (pp.38/54).
def test_orks17c_retired_stratagems_are_unavailable():
    board = rl.new('Board')
    board.units.append(rl.make_beastboss_morgrim())
    board.players_faction[0] = rl.Faction.morgrim_butchas()
    board.command_points[0] = 1
    sequence = value_copy(rl.fight_phase(board))
    obsolete = rl.new('AnyGameAction')
    old_defence = value_copy(rl.s('tough_as_squig_hide {}'))
    old_bellow = value_copy(rl.s('use_bestial_bellow {unit: {id: 0}, target: {id: 0}}'))
    core_payload = value_copy(rl.s('finish_melee_step {}'))
    return sequence.can_finish_melee_step(board) and board.command_points[0] == 1 and rl.from_string(obsolete, core_payload) and (not rl.from_string(obsolete, old_defence)) and (not rl.from_string(obsolete, old_bellow))


def test_accepting_overwatch_charges_only_opponent():
    board = value_copy(core15_fixture())
    board.command_points[0] = 0
    board.command_points[1] = 1
    source = value_copy(rl.unit_id(1))
    sequence = value_copy(rl.timing_overwatch(board, True))
    if not sequence.can_overwatch(board, source):
        return False
    sequence.overwatch(board, source)
    return board.command_points[0] == 0 and board.command_points[1] == 0 and board.has_used_strat(rl.Stratagem.overwatch(), 1) and (not board.has_used_strat(rl.Stratagem.overwatch(), 0))

# Bounds are reflected directly in standard enumeration/ML layout.
def test_bounded_cp_layout_and_domain():
    value = rl.new('CommandPoints')
    domain = value_copy(rl.enumerate(value))
    return domain.size() == rl.MAX_CP and domain[0] == 0 and (domain[rl.MAX_CP - 1] == rl.MAX_CP - 1) and (rl.size_as_observation_tensor(value) == 1)

def test_bounded_storage_rejects_out_of_range_save():
    state = value_copy(rl.play())
    state.board.command_points[0] = 42
    invalid = value_copy(state)
    invalid.board.command_points[0].value = rl.MAX_CP
    return not rl.set_state(state, rl.to_string(invalid)) and state.board.command_points[0] == 42

# p.33: preserve a complete D6 Advance and storage beyond the old result cap.
def test_bounded_random_result_and_modifier_capacity():
    sequence = value_copy(rl.evaluate_random_stat(rl.dice_stat(6), 6))
    six = rl.new('Dice')
    assign(six, 6)
    sequence.quantity(six)
    return sequence.is_done() and sequence.result == 12 and (rl.size_as_observation_tensor(sequence.result) == 1)

# Bounded alternatives must survive pretty indentation in editor saves.
def test_bounded_stat_indented_round_trip():
    fixed = value_copy(rl.raw_stat(4))
    restored = rl.new('Stat')
    if not rl.from_string(restored, rl.to_string(fixed).to_indented_lines()):
        return False
    if rl.to_string(restored) != rl.to_string(fixed):
        return False
    dice = value_copy(rl.dice_stat(6))
    return rl.from_string(restored, rl.to_string(dice).to_indented_lines()) and rl.to_string(restored) == rl.to_string(dice)

def test_indented_game_save_with_bounded_storage():
    state = value_copy(rl.play())
    state.pick_insidious_infiltrators()
    state.pick_strike_force_octavious()
    restored = value_copy(rl.play())
    return rl.set_state(restored, rl.to_string(state).to_indented_lines()) and rl.to_string(restored) == rl.to_string(state)

# Existing faction-trigger regression: the character predicate must be invoked
# on the destroyed model (destruction hook: core p.19; faction definition external).
def test_destroyed_character_triggers_feeder_tendrils():
    board = rl.new('Board')
    source = value_copy(rl.make_infernus_squad())
    source[0].abilities.append(rl.AbilityKind.feeder_tendrils())
    destroyed = value_copy(source[0])
    destroyed.keywords.append(rl.Keyword.character())
    event = value_copy(rl.on_model_destroyed(board, source, destroyed))
    return event.is_done() and board.command_points[0] == 1 and (board.command_points[1] == 0)

# An attacking character does not make a non-character casualty eligible;
# a character casualty also requires the attacker's existing faction ability.
def test_feeder_tendrils_requires_character_casualty_and_ability():
    board = rl.new('Board')
    source = value_copy(rl.make_infernus_squad())
    destroyed = value_copy(source[0])
    source[0].keywords.append(rl.Keyword.character())
    source[0].abilities.append(rl.AbilityKind.feeder_tendrils())
    first = value_copy(rl.on_model_destroyed(board, source, destroyed))
    if not first.is_done() or board.command_points[0] != 0:
        return False
    source[0].abilities.clear()
    destroyed.keywords.append(rl.Keyword.character())
    second = value_copy(rl.on_model_destroyed(board, source, destroyed))
    return second.is_done() and board.command_points[0] == 0 and (board.command_points[1] == 0)

# Task-4 fixtures use whole-inch cells; no fractional movement choices.
def board_position(x, y):
    result = rl.new('BoardPosition')
    result.x = x
    result.y = y
    return value_copy(result)

def geometry_fixture():
    board = rl.new('Board')
    unit = value_copy(rl.make_infernus_squad())
    while unit.models.size() > 1:
        unit.models.erase(unit.models.size() - 1)
    unit[0].position = board_position(5, 5)
    board.units.append(unit)
    return value_copy(board)

def geometry_path(model, x, y, z):
    path = rl.new('ModelPath')
    path.model = model
    path.append_point(rl.geometry_point(x * rl.MICROMETRES_PER_INCH, y * rl.MICROMETRES_PER_INCH, z * rl.MICROMETRES_PER_INCH))
    return value_copy(path)

def geometry_box(x1, y1, z1, x2, y2, z2):
    box = rl.new('TerrainGeometry')
    box.lower = rl.geometry_point(x1 * rl.MICROMETRES_PER_INCH, y1 * rl.MICROMETRES_PER_INCH, z1 * rl.MICROMETRES_PER_INCH)
    box.upper = rl.geometry_point(x2 * rl.MICROMETRES_PER_INCH, y2 * rl.MICROMETRES_PER_INCH, z2 * rl.MICROMETRES_PER_INCH)
    box.blocks_movement = True
    return value_copy(box)

# pp.14–15: exact thresholds are inclusive; one micrometre beyond is outside.
def test_geometry_inclusive_horizontal_vertical_boundaries():
    return rl.within_geometry_limits(50800.0, 127000, 2, 5) and (not rl.within_geometry_limits(50801.0, 127000, 2, 5)) and (not rl.within_geometry_limits(50800.0, 127001, 2, 5)) and rl.within_geometry_limits(228600.0, 127000, 9, 5) and (not rl.within_geometry_limits(228601.0, 127000, 9, 5))

# p.9: millimetre base dimensions, rather than centres, determine engagement.
def test_geometry_base_edges_and_height_engagement():
    board = value_copy(geometry_fixture())
    other = value_copy(board[0][0])
    other.position = board_position(8, 5)
    other.geometry.elevation = 5
    if not board[0][0].is_engaged_with(other):
        return False
    other.geometry.elevation = 6
    if board[0][0].is_engaged_with(other):
        return False
    other.geometry.elevation = 0
    other.position.x = 9
    return not board[0][0].is_engaged_with(other)

# p.9 and supplied Closest definition: include model zero and every target model.
def test_geometry_closest_pair_is_not_first_target_only():
    board = value_copy(geometry_fixture())
    other = value_copy(board[0])
    other[0].position = board_position(30, 5)
    close = value_copy(other[0])
    close.position = board_position(8, 5)
    other.models.append(close)
    direction = value_copy(board[0].get_shortest_vector_to(other))
    return board[0].distance(other) < 2.0 and direction.x == 3 and (direction.y == 0)

# p.9 / supplied Within definitions: one base may be within while not all are wholly within.
def test_geometry_within_wholly_within_quantifiers():
    board = value_copy(geometry_fixture())
    point = value_copy(rl.geometry_point(3 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 0))
    if not rl.unit_within_point(board[0], point, 2, False) or rl.unit_within_point(board[0], point, 2, True):
        return False
    if not rl.unit_within_point(board[0], point, 3, True):
        return False
    far = value_copy(board[0][0])
    far.position = board_position(20, 5)
    board[0].models.append(far)
    return rl.unit_within_point(board[0], point, 3, False) and (not rl.unit_within_point(board[0], point, 3, True))

# p.9: a point's range reaches a base before reaching its centre.
def test_geometry_point_distance_uses_base_and_height():
    board = value_copy(geometry_fixture())
    point = value_copy(board_position(2, 5))
    if board[0].distance(point) >= 3.0:
        return False
    board[0][0].geometry.elevation = 4
    return board[0].distance(point) > 4.0 and board[0].distance(point) < 5.0

# p.14: nearby neighbours do not excuse a chain wider than nine inches.
def test_geometry_coherency_requires_neighbour_and_all_pairs():
    board = value_copy(geometry_fixture())
    unit = value_copy(board[0])
    i = value_copy(1)
    while i < 5:
        model = value_copy(unit[0])
        model.position.x = 5 + i * 3
        unit.models.append(model)
        i = i + 1
    if unit.is_coherent():
        return False
    unit.models.erase(unit.models.size() - 1)
    if not unit.is_coherent():
        return False
    unit[3].position.x = 16
    return not unit.is_coherent()

# pp.12/14: preset placement fits all bases, remains coherent and keeps whole cells.
def test_geometry_quad_formation_has_no_overlapping_bases():
    unit = value_copy(rl.make_infernus_squad())
    anchor = value_copy(board_position(5, 5))
    if not unit.try_arrange_at(anchor) or not unit.is_coherent():
        return False
    i = value_copy(0)
    while i < unit.models.size():
        if not rl.geometry_point_on_grid(unit[i].geometry_position()):
            return False
        j = value_copy(i + 1)
        while j < unit.models.size():
            if rl.model_bases_overlap(unit[i], unit[j]):
                return False
            j = j + 1
        i = i + 1
    return True

# pp.12/14: failed setup and edge translations preserve original positions/history.
def test_geometry_failed_placement_and_translation_are_atomic():
    unit = value_copy(rl.make_infernus_squad())
    anchor = value_copy(board_position(5, 5))
    if not unit.try_arrange_at(anchor):
        return False
    before = value_copy(rl.to_string(unit))
    edge = value_copy(board_position(43, 29))
    if unit.try_arrange_at(edge) or rl.to_string(unit) != before:
        return False
    offset = rl.new('Vector2D')
    offset.x = -10
    return not unit.try_translate(offset) and rl.to_string(unit) == before

# p.12: the entire base must be inside the board, including at legal centre cells.
def test_geometry_base_bounds_and_unsupported_footprint():
    board = value_copy(geometry_fixture())
    edge = value_copy(rl.geometry_point(0, 5 * rl.MICROMETRES_PER_INCH, 0))
    if rl.model_inside_battlefield(board[0][0], edge):
        return False
    board[0][0].geometry.unsupported_footprint = True
    return not rl.model_placement_valid(board, board[0][0])

# p.12: sum the whole path, rather than only displacement, including retracing.
def test_geometry_path_budget_counts_all_segments():
    board = value_copy(geometry_fixture())
    paths = rl.new('Vector<ModelPath>')
    path = value_copy(geometry_path(0, 8, 5, 0))
    path.append_point(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 0))
    paths.append(path)
    slot = rl.new('UnitID')
    policy = rl.new('MovementGeometryPolicy')
    if not rl.try_move_models(board, slot, paths, 0, policy, True) or board[0][0].history.distance_moved_this_turn() != 6.0:
        return False
    before = value_copy(rl.to_string(board))
    paths[0].points[1].x = 4
    return not rl.try_move_models(board, slot, paths, 0, policy, True) and rl.to_string(board) == before

# p.87: movement characteristics belong to individual models, including mixed units.
def test_geometry_mixed_movement_budgets_and_rollback():
    board = value_copy(geometry_fixture())
    fast = value_copy(board[0][0])
    fast.profile = rl.Profile.possessed()
    fast.position = board_position(7, 5)
    board[0].models.append(fast)
    paths = rl.new('Vector<ModelPath>')
    paths.append(geometry_path(0, 11, 5, 0))
    paths.append(geometry_path(1, 16, 5, 0))
    slot = rl.new('UnitID')
    policy = rl.new('MovementGeometryPolicy')
    before = value_copy(rl.to_string(board))
    if rl.try_move_models(board, slot, paths, 0, policy, True) or rl.to_string(board) != before:
        return False
    paths[1].points[0].x = 13
    if not rl.try_move_models(board, slot, paths, 0, policy, True):
        return False
    board[0][1].position = board_position(7, 5)
    board[0][0].position = board_position(5, 5)
    paths[0].points[0].x = 13
    paths[1].points[0].x = 15
    mixed_before = value_copy(rl.to_string(board))
    return not rl.try_move_models(board, slot, paths, 0, policy, True) and rl.to_string(board) == mixed_before

# p.12: friendly traversal is permitted, but final overlap is prohibited.
def test_geometry_friendly_traversal_and_final_overlap():
    board = value_copy(geometry_fixture())
    obstacle = value_copy(board[0])
    obstacle[0].position = board_position(8, 5)
    board.units.append(obstacle)
    slot = rl.new('UnitID')
    target = value_copy(board_position(11, 5))
    if not rl.try_translate_unit(board, slot, target, 0):
        return False
    before = value_copy(rl.to_string(board))
    target = board_position(8, 5)
    return not rl.try_translate_unit(board, slot, target, 0) and rl.to_string(board) == before

# p.12: crossing an enemy is illegal even when the end position is clear.
def test_geometry_enemy_path_crossing_is_rejected():
    board = value_copy(geometry_fixture())
    obstacle = value_copy(board[0])
    obstacle.owned_by_player1 = True
    obstacle[0].position = board_position(8, 5)
    board.units.append(obstacle)
    slot = rl.new('UnitID')
    target = value_copy(board_position(11, 5))
    before = value_copy(rl.to_string(board))
    return not rl.try_translate_unit(board, slot, target, 0) and rl.to_string(board) == before

# p.12: failed legality probes must never mutate live state.
def test_geometry_translation_probe_is_pure():
    board = value_copy(geometry_fixture())
    before = value_copy(rl.to_string(board))
    slot = rl.new('UnitID')
    target = value_copy(board_position(11, 5))
    return rl.can_translate_unit(board, slot, target, 0) and rl.to_string(board) == before

# p.12: reject off-grid paths, repeated model choices, and out-of-range model selectors.
def test_geometry_invalid_paths_are_atomic():
    board = value_copy(geometry_fixture())
    before = value_copy(rl.to_string(board))
    slot = rl.new('UnitID')
    policy = rl.new('MovementGeometryPolicy')
    paths = rl.new('Vector<ModelPath>')
    paths.append(geometry_path(0, 6, 5, 0))
    paths[0].points[0].x.value = rl.BOARD_WIDTH
    if rl.try_move_models(board, slot, paths, 0, policy, True) or rl.to_string(board) != before:
        return False
    paths[0].points[0].x = 6
    paths.append(paths[0])
    if rl.try_move_models(board, slot, paths, 0, policy, True) or rl.to_string(board) != before:
        return False
    paths.erase(paths.size() - 1)
    paths[0].model = 1
    return not rl.try_move_models(board, slot, paths, 0, policy, True) and rl.to_string(board) == before

# p.12: rotation has no movement cost; on circular fixtures it does not change footprint.
def test_geometry_rotation_is_free_on_circle_fixture():
    board = value_copy(geometry_fixture())
    path = rl.new('ModelPath')
    path.final_rotation = 270000
    paths = rl.new('Vector<ModelPath>')
    paths.append(path)
    slot = rl.new('UnitID')
    policy = rl.new('MovementGeometryPolicy')
    return rl.try_move_models(board, slot, paths, 0, policy, True) and board[0][0].history.distance_moved_this_turn() == 0.0 and (board[0][0].geometry.rotation.value == 270000) and (board[0][0].position.x.value == 5)

# p.12: check swept bases through solid terrain, not just legal endpoints.
def test_geometry_wall_crossing_is_rejected():
    board = value_copy(geometry_fixture())
    board.terrain_geometry.append(geometry_box(7, 3, 0, 9, 7, 2))
    slot = rl.new('UnitID')
    target = value_copy(board_position(11, 5))
    before = value_copy(rl.to_string(board))
    return not rl.try_translate_unit(board, slot, target, 0) and rl.to_string(board) == before

# p.48: elevated placement needs full support; upper-surface travel does not enter the solid.
def test_geometry_roof_support_and_overhang():
    board = value_copy(geometry_fixture())
    terrain = value_copy(geometry_box(4, 4, 0, 8, 8, 2))
    board.terrain_geometry.append(terrain)
    board[0][0].geometry.elevation = 2
    if not rl.model_placement_valid(board, board[0][0]):
        return False
    start = value_copy(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 2 * rl.MICROMETRES_PER_INCH))
    end = value_copy(rl.geometry_point(7 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 2 * rl.MICROMETRES_PER_INCH))
    if rl.segment_crosses_terrain(board[0][0], start, end, terrain):
        return False
    board[0][0].position.x = 4
    return not rl.model_placement_valid(board, board[0][0])

# p.48: touching a roof only at the start/end does not enter its solid volume.
def test_geometry_roof_endpoint_is_not_interior():
    board = value_copy(geometry_fixture())
    terrain = value_copy(geometry_box(4, 4, 0, 8, 8, 2))
    roof = value_copy(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 2 * rl.MICROMETRES_PER_INCH))
    above = value_copy(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 3 * rl.MICROMETRES_PER_INCH))
    below = value_copy(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, rl.MICROMETRES_PER_INCH))
    return not rl.segment_crosses_terrain(board[0][0], roof, above, terrain) and (not rl.segment_crosses_terrain(board[0][0], above, roof, terrain)) and rl.segment_crosses_terrain(board[0][0], roof, below, terrain)

# pp.12/48: horizontal plus vertical movement, not the hypotenuse, consumes M.
def test_geometry_vertical_cost_and_terrain_proximity():
    board = value_copy(geometry_fixture())
    start = value_copy(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 0))
    end = value_copy(rl.geometry_point(8 * rl.MICROMETRES_PER_INCH, 9 * rl.MICROMETRES_PER_INCH, 2 * rl.MICROMETRES_PER_INCH))
    if rl.segment_length(start, end) != float(7 * rl.MICROMETRES_PER_INCH):
        return False
    policy = rl.new('MovementGeometryPolicy')
    up = value_copy(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 2 * rl.MICROMETRES_PER_INCH))
    if rl.model_segment_valid(board, board[0], board[0][0], start, up, policy):
        return False
    board.terrain_geometry.append(geometry_box(6, 4, 0, 8, 8, 2))
    return rl.model_segment_valid(board, board[0], board[0][0], start, up, policy)

# p.14: cancelled/failed reserve setup retains the source rather than partly placing it.
def test_geometry_setup_validation_preserves_reserve():
    board = value_copy(geometry_fixture())
    board.reserve_units.append(board[0])
    before = value_copy(rl.to_string(board))
    occupied = value_copy(board_position(5, 5))
    free = value_copy(board_position(20, 5))
    return not rl.setup_candidate_valid(board, board.reserve_units[0], occupied) and rl.setup_candidate_valid(board, board.reserve_units[0], free) and (rl.to_string(board) == before)

# p.12: footprint tangency is allowed; a one-micrometre inward sweep overlaps.
# These calculation-only points never become model positions or player choices.
def test_geometry_swept_base_tangency():
    board = value_copy(geometry_fixture())
    radius = value_copy(int(board[0][0].base_radius_micrometres() * 2.0))
    obstacle = value_copy(board[0][0])
    centre = value_copy(obstacle.geometry_position())
    start = value_copy(rl.geometry_point(centre.x.value - 25400, centre.y.value + radius, 0))
    end = value_copy(rl.geometry_point(centre.x.value + 25400, centre.y.value + radius, 0))
    if rl.segment_crosses_model(board[0][0], start, end, obstacle):
        return False
    start.y = start.y.value - 1
    end.y = end.y.value - 1
    return rl.segment_crosses_model(board[0][0], start, end, obstacle)

# p.12 / quad storage invariant: reject malformed or off-grid terrain in saves.
def test_geometry_state_rejects_malformed_terrain():
    board = value_copy(geometry_fixture())
    board.identify_units()
    board.terrain_geometry.append(geometry_box(7, 3, 0, 9, 7, 2))
    if not rl.valid_state_foundations(board):
        return False
    board.terrain_geometry[0].lower.x.value = rl.MAX_TERRAIN_X
    if rl.valid_state_foundations(board):
        return False
    board.terrain_geometry[0].lower = board.terrain_geometry[0].upper
    return not rl.valid_state_foundations(board)

# Geometry storage is bounded implementation infrastructure; match board dimensions.
def test_geometry_physical_bounds_match_quad_board():
    return rl.MAX_GEOMETRY_X == rl.BOARD_WIDTH * rl.MICROMETRES_PER_INCH + 1 and rl.MAX_GEOMETRY_Y == rl.BOARD_HEIGHT * rl.MICROMETRES_PER_INCH + 1 and (rl.MAX_ELEVATION == 30 * rl.MICROMETRES_PER_INCH + 1)

# p.14: an illegal deployment keeps the selected reserve; cancellation permits retry.
def test_geometry_deployment_cancel_retains_unit_and_owner():
    board = rl.new('Board')
    board.reserve_units.append(rl.make_infernus_squad())
    sequence = value_copy(rl.deploy(board))
    slot = rl.new('UnitID')
    sequence.select_unit(board, slot)
    edge = value_copy(board_position(43, 29))
    if sequence.can_deploy_at(board, edge) or board.units.size() != 0:
        return False
    sequence.skip(board)
    return board.reserve_units.size() == 1 and board.units.size() == 0 and (not board.current_decision_maker) and sequence.can_select_unit(board, slot)

# p.12: a trapped move can be cancelled with no position/history changes.
# This reproduces the engaged rigid-formation move that stalled seed 40000.
def test_geometry_trapped_move_has_cancel_action():
    board = value_copy(geometry_fixture())
    board[0][0].geometry.unsupported_footprint = True
    before = value_copy(rl.to_string(board[0]))
    slot = rl.new('UnitID')
    sequence = value_copy(rl.move(board, slot, 0))
    if not sequence.can_skip(board, slot):
        return False
    sequence.skip(board, slot)
    return sequence.is_done() and rl.to_string(board[0]) == before

# p.12: a model's full base must fit through a gap between enemy bases.
def test_geometry_full_base_clearance_through_gap():
    board = value_copy(geometry_fixture())
    obstacle = value_copy(board[0])
    obstacle.owned_by_player1 = True
    obstacle[0].position = board_position(8, 4)
    second = value_copy(obstacle[0])
    second.position.y = 6
    obstacle.models.append(second)
    board.units.append(obstacle)
    start = value_copy(board[0][0].geometry_position())
    end = value_copy(rl.geometry_point(11 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 0))
    policy = rl.new('MovementGeometryPolicy')
    if rl.model_segment_valid(board, board[0], board[0][0], start, end, policy):
        return False
    board[1][0].position.y = 3
    board[1][1].position.y = 7
    return rl.model_segment_valid(board, board[0], board[0][0], start, end, policy)

# p.14: coherency's five-inch vertical limit applies to every model pair.
def test_geometry_coherency_vertical_limit():
    board = value_copy(geometry_fixture())
    second = value_copy(board[0][0])
    second.position.x = 7
    second.geometry.elevation = 5
    board[0].models.append(second)
    if not board[0].is_coherent():
        return False
    board[0][1].geometry.elevation = 6
    return not board[0].is_coherent()

# Task-5 fixture: distinct whole-inch bases, owners and stable identities.
def timing_fixture():
    board = value_copy(geometry_fixture())
    other = value_copy(board[0])
    other.owned_by_player1 = True
    other[0].position = board_position(20, 5)
    board.units.append(other)
    board.identify_unit(board[0])
    board.identify_unit(board[1])
    board.command_points[0] = 3
    board.command_points[1] = 3
    board[0].can_shoot = True
    board[1].can_shoot = True
    return value_copy(board)

# p.54: a player's second stratagem on the same unit is forbidden, even
# when it is a different stratagem; the other player's record is independent.
def test_timing_per_player_unit_stratagem_limit():
    board = value_copy(timing_fixture())
    if not board.try_use_strat(False, rl.Stratagem.reroll(), board[0], 1):
        return False
    if board.can_target_strat(False, rl.Stratagem.overwatch(), board[0]):
        return False
    return board.can_target_strat(True, rl.Stratagem.overwatch(), board[0]) and board.command_points[0] == 2 and (board.command_points[1] == 3)

# pp.9/54: shock bans the controller's target, not the opposing payer's target.
def test_timing_shock_stratagem_target_ownership():
    board = value_copy(timing_fixture())
    board[0].battle_socked = True
    return not board.can_target_strat(False, rl.Stratagem.reroll(), board[0]) and board.can_target_strat(True, rl.Stratagem.reroll(), board[0])

# p.54: invalid cost, insufficient CP and repeat use have no partial effects.
def test_timing_stratagem_failure_is_atomic():
    board = value_copy(timing_fixture())
    before = value_copy(rl.to_string(board))
    if board.try_use_strat(False, rl.Stratagem.reroll(), board[0], -1) or board.try_use_strat(False, rl.Stratagem.reroll(), board[0], 4):
        return False
    return before == rl.to_string(board)

# p.54: overrides including free use retain phase and per-unit restrictions.
def test_timing_free_use_still_consumes_usage():
    board = value_copy(timing_fixture())
    board.command_points[0] = 0
    if not board.try_use_strat(False, rl.Stratagem.reroll(), board[0], 0):
        return False
    return board.command_points[0] == 0 and (not board.can_use_strat_with_cost(False, rl.Stratagem.reroll(), 0)) and (not board.can_target_strat_with_cost(False, rl.Stratagem.overwatch(), board[0], 0))

# pp.28–30/54: phase reset includes reserves and both payers, not turn flags.
def test_timing_phase_reset_includes_reserves():
    board = value_copy(timing_fixture())
    board.reserve_units.append(board[0])
    board.commit_stratagem(False, rl.Stratagem.reroll(), board[0])
    board.reserve_units[0].history.stratagem_targeted_by_player[1] = True
    board[0].has_moved = True
    board[1].has_fought = True
    board.begin_phase(rl.BattlePhase.shooting())
    return board.timing.phase == rl.BattlePhase.shooting() and board.can_target_strat(False, rl.Stratagem.reroll(), board[0]) and (not board.reserve_units[0].history.stratagem_targeted_by_player[1]) and board[0].has_moved and (not board[1].has_fought)

# pp.28–30: the turn owner's flags reset without erasing enemy turn choices.
def test_timing_turn_movement_flags_expire_for_both_armies():
    board = value_copy(timing_fixture())
    board[0].has_moved = True
    board[1].has_moved = True
    board[0].has_shoot = True
    board[1].has_shoot = True
    board.start_turn_history()
    return not board[0].has_moved and (not board[1].has_moved) and (not board[0].has_shoot) and board[1].has_shoot

# pp.9/54/56: accept CP reroll -> spend -> chance; restore caller afterward.
def test_timing_pair_reroll_owner_spend_and_restore():
    board = value_copy(timing_fixture())
    board.current_decision_maker = False
    dice_roll = value_copy(rl.rerollable_pair_dices_roll(board, False, False, True, True, rl.unit_id(1)))
    one = rl.new('Dice')
    assign(one, 1)
    dice_roll.roll_pair(board, one, one)
    if board.current_decision_maker != True or not dice_roll.can_keep_it(board, False):
        return False
    dice_roll.keep_it(board, False)
    if board.command_points[1] != 2 or not board[1].history.stratagem_targeted_by_player[1] or (not dice_roll.can_reroll_pair(board, one, one)):
        return False
    dice_roll.reroll_pair(board, one, one)
    return dice_roll.is_done() and (not board.current_decision_maker)

# p.56: a declined CP reroll changes no expenditure/history and restores owner.
def test_timing_declining_cp_reroll_preserves_state():
    board = value_copy(timing_fixture())
    board.current_decision_maker = True
    dice_roll = value_copy(rl.rerollable_dice_roll(board, False, False, True, False, rl.unit_id(0)))
    one = rl.new('Dice')
    assign(one, 1)
    dice_roll.roll(board, one)
    if board.current_decision_maker:
        return False
    dice_roll.keep_it(board, True)
    return dice_roll.is_done() and board.command_points[0] == 3 and (not board.has_used_strat(rl.Stratagem.reroll(), 0)) and board.current_decision_maker

# p.56: targetless/leadership compatibility cannot offer a CP reroll.
def test_timing_targetless_roll_cannot_spend_cp():
    board = value_copy(timing_fixture())
    dice_roll = value_copy(rl.rerollable_pair_dices_roll(board, False, False, True, False))
    one = rl.new('Dice')
    assign(one, 1)
    dice_roll.roll_pair(board, one, one)
    return dice_roll.is_done() and board.command_points[0] == 3

# p.30 and user's sequencing definition: current group first, then opponent.
def test_timing_current_player_then_opponent_effects():
    board = value_copy(timing_fixture())
    board.players_faction[0] = rl.Faction.insidious_infiltrators()
    board.players_faction[1] = rl.Faction.insidious_infiltrators()
    window = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.command_abilities()))
    if not board.timing.stage == rl.TimingStage.current_player_rules() or board.current_decision_maker:
        return False
    window.choose_timing_rule(board, rl.TimingRule.shadow_in_the_warp())
    window.use_shadow_in_the_warp(board, False)
    if not board.current_decision_maker or not board.timing.stage == rl.TimingStage.opposing_player_rules():
        return False
    window.choose_timing_rule(board, rl.TimingRule.shadow_in_the_warp())
    window.use_shadow_in_the_warp(board, False)
    return window.is_done() and (not board.timing.open) and (board.timing.stage == rl.TimingStage.closed()) and (not board.current_decision_maker)

# p.30 and user's sequencing definition: choose either available kind first.
def test_timing_owner_can_choose_effect_order():
    board = value_copy(timing_fixture())
    board.players_faction[0] = rl.Faction.strike_force_octavius()
    window = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.command_abilities()))
    if not window.can_choose_timing_rule(board, rl.TimingRule.oath_of_moment()) or not window.can_choose_timing_rule(board, rl.TimingRule.objective_stratagem()):
        return False
    window.choose_timing_rule(board, rl.TimingRule.objective_stratagem())
    window.skip(board)
    if window.can_choose_timing_rule(board, rl.TimingRule.objective_stratagem()):
        return False
    if not window.can_choose_timing_rule(board, rl.TimingRule.oath_of_moment()):
        return False
    window.choose_timing_rule(board, rl.TimingRule.oath_of_moment())
    window.skip(board)
    return window.is_done()

# p.57: Overwatch and Rapid Ingress are only offered to opponent at Move end.
def test_timing_overwatch_window_and_decline():
    board = value_copy(timing_fixture())
    if rl.timing_rule_available(board, rl.TimingWindow.movement_start(), True, rl.TimingRule.fire_overwatch()) or rl.timing_rule_available(board, rl.TimingWindow.movement_end(), False, rl.TimingRule.fire_overwatch()):
        return False
    before = value_copy(board.command_points[1])
    window = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.movement_end()))
    if not board.current_decision_maker or not window.can_choose_timing_rule(board, rl.TimingRule.fire_overwatch()):
        return False
    window.finish_timing_rules(board)
    return window.is_done() and board.command_points[1] == before and (not board.has_used_strat(rl.Stratagem.overwatch(), 1)) and (not board.current_decision_maker)

# p.57: engaged, shocked and TITANIC Overwatch sources are excluded.
def test_timing_overwatch_source_exclusions():
    board = value_copy(timing_fixture())
    source = value_copy(rl.unit_id(1))
    if not rl.overwatch_source_valid(board, True, source):
        return False
    board[1].battle_socked = True
    if rl.overwatch_source_valid(board, True, source):
        return False
    board[1].battle_socked = False
    board[1][0].position = board_position(6, 5)
    return not rl.overwatch_source_valid(board, True, source)

# p.57: first-round Rapid Ingress is prohibited; later reserve is eligible.
def test_timing_rapid_ingress_round_gate_and_payment():
    board = value_copy(timing_fixture())
    board.reserve_units.append(board[1])
    if rl.rapid_ingress_target_valid(board, True, rl.unit_id(0)):
        return False
    board.current_round = 1
    ingress = value_copy(rl.timing_rapid_ingress(board, True))
    ingress.select_ingress_unit(board, rl.unit_id(0))
    if board.command_points[1] != 2 or not board.reserve_units[0].history.stratagem_targeted_by_player[1]:
        return False
    ingress.skip(board)
    return ingress.is_done() and board.reserve_units.size() == 1 and board.has_used_strat(rl.Stratagem.rapid_ingress(), 1)

# p.14: both armies remove incoherent models one at a time without death hooks.
def test_timing_end_turn_coherency_mandatory_and_archived():
    board = value_copy(timing_fixture())
    far = value_copy(board[0][0])
    far.identity = 0
    far.position = board_position(40, 5)
    board[0].models.append(far)
    board.identify_unit(board[0])
    removed_identity = value_copy(board[0][1].identity)
    previous_target = value_copy(rl.unit_id(1))
    board.attack.target = previous_target
    window = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.turn_end()))
    if window.can_finish_timing_rules(board):
        return False
    window.choose_timing_rule(board, rl.TimingRule.regain_coherency())
    window.select_incoherent_unit(board, rl.unit_id(0))
    if board.attack.target.get() != 0:
        return False
    model = rl.new('ModelID')
    assign(model, 1)
    window.remove_incoherent_model(board, model)
    return window.is_done() and board[0].is_coherent() and (board[0].destroyed_models.value.size() == 1) and (board[0].destroyed_models.value[0].identity == removed_identity) and (board.attack.target.get() == 1) and (board.command_points[0] == 3)

# pp.28–30: empty windows complete without dummy decisions.
def test_timing_empty_start_end_windows_close():
    board = value_copy(timing_fixture())
    start = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.round_start()))
    finish = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.round_end()))
    return start.is_done() and finish.is_done() and (not board.timing.open) and (not board.current_decision_maker)

# p.30: core CP and shock precede Command abilities; decline restores owner.
def test_timing_command_phase_cp_before_ability():
    board = value_copy(timing_fixture())
    board.players_faction[0] = rl.Faction.strike_force_octavius()
    command = value_copy(rl.command_phase(board))
    return board.command_points[0] == 4 and board.command_points[1] == 4 and (board.timing.window == rl.TimingWindow.command_abilities()) and command.can_choose_timing_rule(board, rl.TimingRule.oath_of_moment())

# p.57: Heroic Intervention is at opponent Charge end, not individual charges.
def test_timing_heroic_intervention_boundary():
    board = value_copy(timing_fixture())
    board[0][0].position = board_position(10, 5)
    board[0].has_charged = True
    board[0].history.charge_move_phase = board.phase_serial.value + 1
    board[1].can_charge = True
    return rl.timing_rule_available(board, rl.TimingWindow.charge_end(), True, rl.TimingRule.heroic_intervention()) and (not rl.timing_rule_available(board, rl.TimingWindow.charge_start(), True, rl.TimingRule.heroic_intervention())) and (not rl.timing_rule_available(board, rl.TimingWindow.charge_end(), False, rl.TimingRule.heroic_intervention())) and (rl.Stratagem.heroic_intervention().cost() == 1)

# p.8: an opposing unit's move changes the active role, then restores it.
def test_timing_opponent_move_restores_roles():
    board = value_copy(timing_fixture())
    source = value_copy(rl.unit_id(1))
    movement = value_copy(rl.move(board, source, 0))
    if not board.timing.active_player or not board.current_decision_maker or board.current_player:
        return False
    movement.skip(board, source)
    return movement.is_done() and (not board.timing.active_player) and (not board.current_decision_maker) and (not board.current_player)

# p.8: shooting active role follows attacker even while defender decides.
def test_timing_opponent_attack_restores_roles():
    board = value_copy(timing_fixture())
    board[1][0].position.x = 15
    sequence = value_copy(rl.attack(board, rl.unit_id(1), rl.unit_id(0), False, True))
    if not board.timing.active_player or not board.current_decision_maker:
        return False
    slot = rl.new('BInt<0, MAX_WEAPONS>')
    assign(slot, 1)
    sequence.select_weapon(board, slot)
    sequence.skip(board)
    sequence.declare_target(board, rl.unit_id(1), rl.unit_id(0))
    sequence.choose_attack_target(board, rl.unit_id(0))
    if board.current_decision_maker:
        return False
    sequence.no_defensive_stratagem(board)
    if not board.current_decision_maker or not board.timing.active_player:
        return False
    sequence.no_offensive_stratagem(board)
    weapon = rl.new('AttackWeaponID')
    assign(weapon, 0)
    sequence.choose_attack_weapon(board, weapon)
    one = rl.new('Dice')
    assign(one, 1)
    sequence.quantity(board, one)
    sequence.keep_it(board, True)
    sequence.roll(board, one)
    sequence.keep_batch(board)
    return sequence.is_done() and (not board.timing.active_player) and (not board.current_decision_maker) and (not board.current_player)

# p.14 and supplied sequencing: opposing coherency is also mandatory,
# after the current player's removals have finished.
def test_timing_both_armies_regain_coherency_in_order():
    board = value_copy(timing_fixture())
    far = value_copy(board[0][0])
    far.identity = 0
    far.position = board_position(40, 5)
    board[0].models.append(far)
    board[1].models.append(far)
    board.identify_unit(board[0])
    board.identify_unit(board[1])
    window = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.turn_end()))
    window.choose_timing_rule(board, rl.TimingRule.regain_coherency())
    window.select_incoherent_unit(board, rl.unit_id(0))
    model = rl.new('ModelID')
    assign(model, 1)
    window.remove_incoherent_model(board, model)
    if not board.current_decision_maker or window.can_finish_timing_rules(board):
        return False
    window.choose_timing_rule(board, rl.TimingRule.regain_coherency())
    window.select_incoherent_unit(board, rl.unit_id(1))
    window.remove_incoherent_model(board, model)
    return window.is_done() and board[0].is_coherent() and board[1].is_coherent() and (not board.current_decision_maker)

# Existing faction fixture, not a core ability: its chosen target owns the
# shock decision and receives the shock result (generic roles pp.8–9/30).
def test_timing_neural_disruption_uses_chosen_target_context():
    board = value_copy(timing_fixture())
    board[0][0].abilities.append(rl.AbilityKind.neural_disruption())
    board[1][0].position = board_position(10, 5)
    board.players_faction[0] = rl.Faction.insidious_infiltrators()
    board.command_points[1] = 0
    sequence = value_copy(rl.neural_disruption(board))
    sequence.select_neural_disruption_target(board, rl.unit_id(0), rl.unit_id(1))
    one = rl.new('Dice')
    assign(one, 1)
    sequence.roll_pair(board, one, one)
    if not board[1].battle_socked or board[0].battle_socked or board.current_decision_maker:
        return False
    sequence.skip(board)
    return sequence.is_done()

# p.8: an opposing charger owns its scoped role through dice/reroll input.
def test_timing_opponent_charge_restores_roles():
    board = value_copy(timing_fixture())
    board[1][0].position.x = 13
    board[1].can_charge = True
    sequence = value_copy(rl.charge(board, rl.unit_id(1), rl.ChargeKind.ordinary()))
    if not board.timing.active_player or not board.current_decision_maker:
        return False
    one = rl.new('Dice')
    assign(one, 1)
    sequence.roll_pair(board, one, one)
    sequence.keep_it(board, True)
    sequence.cancel_charge(board)
    return sequence.is_done() and (not board.timing.active_player) and (not board.current_decision_maker)

# Rule 01.06, p.9. Success against at least one Ld means the lowest threshold.
def test_01_06_mixed_leadership():
    unit = value_copy(rl.make_infernus_squad())
    unit[1].profile = rl.Profile.beast_snagga_boy()
    return unit.get_leadership() == 6

# p.86: odd model counts cannot be exactly half; use the unrounded threshold.
def test_half_strength_odd_and_even_model_counts():
    unit = value_copy(rl.make_infernus_squad())
    unit.capture_starting_strength()
    unit.models.erase(4)
    unit.models.erase(3)
    if unit.is_at_or_below_half_strength() or unit.is_below_half_strenght():
        return False
    unit.models.erase(2)
    if not unit.is_at_or_below_half_strength() or not unit.is_below_half_strenght():
        return False
    unit.starting_strenght = 4
    return unit.is_at_or_below_half_strength() and (not unit.is_below_half_strenght())

# p.86: a lone model uses remaining wounds, including exact and odd boundaries.
def test_half_strength_single_model_wounds():
    unit = value_copy(rl.make_octavius())
    unit.capture_starting_strength()
    unit[0].suffered_wounds = 2
    if unit.is_at_or_below_half_strength():
        return False
    unit[0].suffered_wounds = 3
    if not unit.is_at_or_below_half_strength() or unit.is_below_half_strenght():
        return False
    unit[0].suffered_wounds = 4
    if not unit.is_below_half_strenght():
        return False
    unit[0].profile = rl.Profile.librarian_tantus()
    unit[0].suffered_wounds = 2
    if unit.is_at_or_below_half_strength():
        return False
    unit[0].suffered_wounds = 3
    return unit.is_at_or_below_half_strength() and unit.is_below_half_strenght()

# p.86: a surviving full-health leader uses combined initial strength.
# This fixture verifies the threshold only; task 6 attachment changes are deferred.
def test_half_strength_combined_count_survives_casualties():
    unit = value_copy(rl.make_octavius())
    unit.starting_strenght = 6
    return unit.is_at_or_below_half_strength() and unit.is_below_half_strenght()

# pp.19/86: retired/empty/uninitialized fixtures cannot require a shock roll.
def test_half_strength_empty_and_uninitialized_units():
    unit = rl.new('Unit')
    if unit.is_at_or_below_half_strength() or unit.is_below_half_strenght():
        return False
    assign(unit, rl.make_octavius())
    unit.starting_strenght = 0
    return not unit.is_at_or_below_half_strength() and (not unit.is_below_half_strenght())

# Rule 08.03, p.30. Opponent's shock is not cleared by our Command phase.
def test_08_03_opponent_shock_persists():
    board = rl.new('Board')
    unit = value_copy(rl.make_tantus())
    unit.owned_by_player1 = True
    unit.battle_socked = True
    board.units.append(unit)
    step = value_copy(rl.battle_shock_step(board))
    return board[0].battle_socked

# p.30: a live full-strength unit still rolls if already battle-shocked.
def test_command_shocked_full_strength_recovers_on_success():
    board = rl.new('Board')
    board.units.append(rl.make_infernus_squad())
    board[0].capture_starting_strength()
    board[0].battle_socked = True
    board.begin_phase(rl.BattlePhase.command())
    step = value_copy(rl.battle_shock_step(board))
    three = rl.new('Dice')
    assign(three, 3)
    if not step.can_roll_pair(board, three, three) or not board[0].battle_socked:
        return False
    step.roll_pair(board, three, three)
    return step.is_done() and (not board[0].battle_socked)

# pp.9/30: failure keeps existing shock and does not spend CP on a reroll.
def test_command_failed_recovery_preserves_shock():
    board = rl.new('Board')
    board.units.append(rl.make_tantus())
    board[0].capture_starting_strength()
    board[0].battle_socked = True
    board.command_points[0] = 2
    board.begin_phase(rl.BattlePhase.command())
    step = value_copy(rl.battle_shock_step(board))
    one = rl.new('Dice')
    assign(one, 1)
    if step.can_insane_bravery(board, True):
        return False
    step.roll_pair(board, one, one)
    return step.is_done() and board[0].battle_socked and (board.command_points[0] == 2)

# p.30: meeting both conditions causes exactly one roll, including exact half.
def test_command_exact_half_and_shocked_rolls_once():
    board = rl.new('Board')
    board.units.append(rl.make_octavius())
    board[0].capture_starting_strength()
    board[0][0].suffered_wounds = 3
    board[0].battle_socked = True
    step = value_copy(rl.battle_shock_step(board))
    three = rl.new('Dice')
    assign(three, 3)
    step.roll_pair(board, three, three)
    return step.is_done() and (not board[0].battle_socked)

# pp.30/86: multi-model exact half rolls; an odd count above half does not.
def test_command_model_count_eligibility():
    board = rl.new('Board')
    unit = value_copy(rl.make_infernus_squad())
    unit.capture_starting_strength()
    unit.models.resize(3)
    board.units.append(unit)
    no_roll = value_copy(rl.battle_shock_step(board))
    if not no_roll.is_done():
        return False
    board[0].starting_strenght = 6
    half_roll = value_copy(rl.battle_shock_step(board))
    one = rl.new('Dice')
    assign(one, 1)
    if not half_roll.can_roll_pair(board, one, one):
        return False
    half_roll.roll_pair(board, one, one)
    return half_roll.is_done() and board[0].battle_socked

# pp.19/30: no roll/indexing for retired units or healthy units above half.
def test_command_empty_and_healthy_units_are_skipped():
    board = rl.new('Board')
    board.units.append(rl.make_octavius())
    board[0].capture_starting_strength()
    board.units.append(rl.make_tantus())
    board[1].damage(0, 100)
    board[1].battle_socked = True
    step = value_copy(rl.battle_shock_step(board))
    return step.is_done() and (not board[0].battle_socked) and board[1].battle_socked

# pp.9/30: a successful roll outside the recovery step does not clear shock.
def test_shock_success_outside_command_does_not_recover():
    board = value_copy(timing_fixture())
    board[1].battle_socked = True
    step = value_copy(rl.battle_shock_test(board, board[1], False, False))
    three = rl.new('Dice')
    assign(three, 3)
    if not board.current_decision_maker:
        return False
    step.roll_pair(board, board[1], three, three)
    return step.is_done() and board[1].battle_socked and (not board.current_decision_maker)

# p.9: 2D6 reaches the easier Ld6 exactly, although another model has Ld7.
def test_shock_roll_uses_lowest_mixed_leadership():
    board = rl.new('Board')
    board.units.append(rl.make_infernus_squad())
    board[0][1].profile = rl.Profile.beast_snagga_boy()
    step = value_copy(rl.battle_shock_test(board, board[0], False, False))
    three = rl.new('Dice')
    assign(three, 3)
    step.roll_pair(board, board[0], three, three)
    if not step.is_done() or board[0].battle_socked:
        return False
    step = rl.battle_shock_test(board, board[0], False, False)
    two = rl.new('Dice')
    assign(two, 2)
    step.roll_pair(board, board[0], three, two)
    return step.is_done() and board[0].battle_socked

# p.56: Insane Bravery cannot be offered for an out-of-step faction shock roll.
def test_bravery_only_in_own_command_shock_step():
    board = value_copy(timing_fixture())
    board.begin_phase(rl.BattlePhase.command())
    outside = value_copy(rl.battle_shock_test(board, board[0], False, False))
    opposing = value_copy(rl.battle_shock_test(board, board[1], True, False))
    board.timing.phase = rl.BattlePhase.movement()
    wrong_phase = value_copy(rl.battle_shock_test(board, board[0], True, False))
    return not outside.can_insane_bravery(board, board[0], True) and (not opposing.can_insane_bravery(board, board[1], True)) and (not wrong_phase.can_insane_bravery(board, board[0], True))

# pp.54/56: declining Bravery preserves CP, once-per-battle flag and target use.
def test_bravery_decline_preserves_battle_and_phase_limits():
    board = value_copy(timing_fixture())
    board.begin_phase(rl.BattlePhase.command())
    step = value_copy(rl.battle_shock_test(board, board[0], True, False))
    step.insane_bravery(board, board[0], False)
    three = rl.new('Dice')
    assign(three, 3)
    step.roll_pair(board, board[0], three, three)
    return step.is_done() and board.command_points[0] == 3 and (not board.has_used_insane_bravery[0]) and (not board[0].history.stratagem_targeted_by_player[0])

# p.56: accepting Bravery is successful without dice; later phases cannot reuse.
def test_bravery_once_per_battle_survives_phase_and_turn_reset():
    board = value_copy(timing_fixture())
    board.begin_phase(rl.BattlePhase.command())
    step = value_copy(rl.battle_shock_test(board, board[0], True, False))
    step.insane_bravery(board, board[0], True)
    if not step.is_done() or board[0].battle_socked or board.command_points[0] != 2:
        return False
    board.begin_phase(rl.BattlePhase.movement())
    board.start_turn_history()
    board.begin_phase(rl.BattlePhase.command())
    again = value_copy(rl.battle_shock_test(board, board[0], True, False))
    three = rl.new('Dice')
    assign(three, 3)
    return board.has_used_insane_bravery[0] and (not again.can_insane_bravery(board, board[0], True)) and again.can_roll_pair(board, board[0], three, three)

# p.30: CP is granted before shock; Command abilities wait until shock resolves.
def test_command_cp_then_shock_then_abilities():
    board = value_copy(timing_fixture())
    board[0].battle_socked = True
    board.players_faction[0] = rl.Faction.strike_force_octavius()
    command = value_copy(rl.command_phase(board))
    three = rl.new('Dice')
    assign(three, 3)
    if board.command_points[0] != 4 or board.command_points[1] != 4 or command.can_choose_timing_rule(board, rl.TimingRule.oath_of_moment()):
        return False
    command.roll_pair(board, three, three)
    return not board[0].battle_socked and command.can_choose_timing_rule(board, rl.TimingRule.oath_of_moment()) and (board.current_decision_maker == board.current_player)

# Rule 01.07, p.9. Battle-shocked models contribute no OC.
def test_01_07_shock_removes_objective_control():
    board = rl.new('Board')
    unit = value_copy(rl.make_tantus())
    unit.move_to(rl.make_board_position(10, 10))
    unit.battle_socked = True
    board.units.append(unit)
    return board.get_objective_controller(10, 10) == -1


# p.9: every model inherits shock, OC '-', and the action start/completion ban.
# Full mission-action workflow remains task 15; these are its required gates.
def test_shock_model_control_and_action_restrictions():
    unit = value_copy(rl.make_infernus_squad())
    unit.history.action_started = True
    if unit.allows_action_start() or not unit.allows_action_completion():
        return False
    unit.battle_socked = True
    for i in range(unit.models.size()):
        if not unit.model_is_battle_shocked(i) or unit.model_objective_control(i) != 0:
            return False
    if unit.allows_action_start() or unit.allows_action_completion():
        return False
    unit.battle_socked = False
    return not unit.allows_action_start() and unit.allows_action_completion() and (not unit.model_is_battle_shocked(0)) and (unit.model_objective_control(0) == 1) and unit.history.action_started

# p.9: a shocked friendly unit cannot erase a healthy unit's contribution.
# This tests the shock exclusion, not task 8's unfinished aggregation formula.
def test_shock_control_exclusion_preserves_other_friendly_models():
    board = rl.new('Board')
    unit = value_copy(rl.make_tantus())
    unit[0].position = board_position(10, 10)
    board.units.append(unit)
    unit.battle_socked = True
    board.units.append(unit)
    return board.get_objective_controller(10, 10) == 0

# pp.54/56: all spending entrypoints observe battle-long Bravery usage.
def test_bravery_central_battle_limit_and_independent_players():
    board = value_copy(timing_fixture())
    board.commit_stratagem(False, rl.Stratagem.insane_bravery(), board[0])
    board.clear_phase_modifiers()
    if board.can_use_strat(False, rl.Stratagem.insane_bravery()) or board.can_target_strat_with_cost(False, rl.Stratagem.insane_bravery(), board[0], 0):
        return False
    if board.try_use_strat(False, rl.Stratagem.insane_bravery(), board[0], 0):
        return False
    return board.can_target_strat(True, rl.Stratagem.insane_bravery(), board[1]) and board.can_target_strat(False, rl.Stratagem.reroll(), board[0]) and (board.command_points[0] == 2)

# p.9: the existing Dark Pact consumer must use both Leadership dice.
# This does not claim new-edition faction effect/eligibility certification.
def test_leadership_consumer_uses_complete_pair_total():
    board = value_copy(timing_fixture())
    board.players_faction[0] = rl.Faction.zarkan_daemonkin()
    board.players_faction[1] = rl.Faction.zarkan_daemonkin()
    strats = value_copy(rl.use_attack_stratagems(board, rl.unit_id(0), rl.unit_id(1), False))
    strats.no_defensive_stratagem(board)
    strats.use_dark_pact(board)
    three = rl.new('Dice')
    assign(three, 3)
    strats.roll_pair(board, three, three)
    return strats.can_select_ability(board, True) and board[0][0].suffered_wounds == 0

# Save infrastructure must preserve battle-long Bravery usage (p.56) and reject
# pre-task-7 schemas; the book does not prescribe serialization/version numbers.
def test_bravery_battle_limit_save_round_trip():
    state = value_copy(rl.play())
    state.board.has_used_insane_bravery[0] = True
    restored = value_copy(rl.play())
    if not rl.set_state(restored, rl.to_string(state)):
        return False
    if not restored.board.has_used_insane_bravery[0] or restored.board.has_used_insane_bravery[1]:
        return False
    state.board.schema_version.value = 5
    return not rl.set_state(restored, rl.to_string(state)) and restored.board.has_used_insane_bravery[0]

# Rule 14.02, p.52. Two OC1 models beat one OC2 model only with an extra OC1.
def test_14_02_sum_objective_control():
    board = rl.new('Board')
    friendly = value_copy(rl.make_infernus_squad())
    friendly.models.erase(4)
    friendly.models.erase(3)
    friendly.move_to(rl.make_board_position(10, 10))
    friendly.owned_by_player1 = False
    enemy = value_copy(rl.make_beast_snagga_boyz())
    while enemy.models.size() > 1:
        enemy.models.erase(enemy.models.size() - 1)
    enemy.move_to(rl.make_board_position(10, 10))
    enemy.owned_by_player1 = True
    board.units.append(friendly)
    board.units.append(enemy)
    return board.get_objective_controller(10, 10) == 0

# Rule 14.02, p.52. An unsecured equal nonzero total is uncontrolled.
def test_14_02_tied_objective_uncontrolled():
    board = rl.new('Board')
    a = value_copy(rl.make_tantus())
    a.move_to(rl.make_board_position(10, 10))
    b = value_copy(a)
    b.owned_by_player1 = True
    board.units.append(a)
    board.units.append(b)
    return board.get_objective_controller(10, 10) == -1

# Rule 15.01, p.54. A 1CP stratagem is affordable with 1CP.
# Rule 15.01, p.54. Usage belongs to the player who used the stratagem.
# Rule 08.02, p.30. Core CP gain must not disappear at the arbitrary storage cap.
# Does not assert a general additional-CP-generation policy (external gate D12).
# Rule 09.06, p.33. D6=5 must provide the complete five-inch increment.

# Area fixture uses whole-inch boundaries and explicit categories (pp.46–47).
def terrain_area(x1, y1, x2, y2, dense):
    area = rl.new('TerrainArea')
    area.lower = rl.geometry_point(x1 * rl.MICROMETRES_PER_INCH, y1 * rl.MICROMETRES_PER_INCH, 0)
    area.upper = rl.geometry_point(x2 * rl.MICROMETRES_PER_INCH, y2 * rl.MICROMETRES_PER_INCH, 0)
    area.dense = dense
    area.exposed = not dense
    return value_copy(area)

# p.88: closest base/marker edges, not centres, with separate vertical limit.
def test_objective_marker_base_and_height_boundaries():
    board = rl.new('Board')
    model = value_copy(rl.make_octavius()[0])
    objective = rl.new('Objective')
    objective.position = board_position(10, 10)
    model.position = board_position(14, 10)
    model.geometry.elevation = 5
    if not board.model_in_objective_range(model, objective):
        return False
    model.geometry.elevation = 6
    if board.model_in_objective_range(model, objective):
        return False
    model.geometry.elevation = 0
    model.position.x = 15
    if board.model_in_objective_range(model, objective):
        return False
    # 40mm marker + 50mm base is 45mm: at 4in centres the edge gap is <3in.
    model.position.x = 14
    model.geometry.unsupported_footprint = True
    return not board.model_in_objective_range(model, objective)

# pp.52/88: the whole terrain area is the objective, without a marker's height cap.
def test_terrain_objective_uses_area_and_base_intersection():
    board = rl.new('Board')
    board.terrain_areas.append(terrain_area(9, 9, 15, 15, True))
    board.set_objective_position(0, board_position(10, 10))
    if not board.link_objective_terrain_areas():
        return False
    model = value_copy(rl.make_tantus()[0])
    model.position = board_position(15, 15)
    model.geometry.elevation = 10
    if not board.model_in_objective_range(model, board.objective_range_definition(0)):
        return False
    model.position = board_position(18, 10)
    return not board.model_in_objective_range(model, board.objective_range_definition(0))

# p.52: initial control is none, then snapshots change only at boundaries.
def test_objective_control_initial_and_boundary_snapshot():
    board = rl.new('Board')
    unit = value_copy(rl.make_tantus())
    unit[0].position = board_position(12, 15)
    board.units.append(unit)
    if board.get_objective_controller(0) != -1:
        return False
    board.update_objective_control(True)
    if board.get_objective_controller(0) != 0:
        return False
    board[0][0].position = board_position(2, 2)
    if board.get_objective_controller(0) != 0:
        return False
    board.update_objective_control(False)
    return board.get_objective_controller(0) == -1

# p.52: securing survives absence and ties, and expires on superior opponent OC.
def test_secured_objective_absence_tie_and_phase_loss():
    board = rl.new('Board')
    unit = value_copy(rl.make_tantus())
    unit[0].position = board_position(12, 15)
    board.units.append(unit)
    board.update_objective_control(True)
    board.grant_secured_objective(0, False)
    board[0][0].position = board_position(2, 2)
    board.update_objective_control(True)
    if board.get_objective_controller(0) != 0:
        return False
    unit.owned_by_player1 = True
    board.units.append(unit)
    board.update_objective_control(False)
    if board.get_objective_controller(0) != 0:
        return False
    board.update_objective_control(True)
    return board.get_objective_controller(0) == 1 and board.objectives[0].secured_by == rl.ObjectiveController.none()

# p.52: a secured tie keeps its owner; unsecure equal nonzero totals lose control.
def test_secured_objective_equal_nonzero_totals():
    board = rl.new('Board')
    unit = value_copy(rl.make_tantus())
    unit[0].position = board_position(12, 15)
    board.units.append(unit)
    board.update_objective_control(True)
    board.grant_secured_objective(0, False)
    unit.owned_by_player1 = True
    board.units.append(unit)
    board.update_objective_control(True)
    return board.get_objective_controller(0) == 0 and board.objectives[0].secured_by == rl.ObjectiveController.army_0()

# p.53: controlling unit requires own army control, range and positive OC.
def test_objective_controlling_unit_and_shock():
    board = rl.new('Board')
    unit = value_copy(rl.make_tantus())
    unit[0].position = board_position(12, 15)
    board.units.append(unit)
    board.update_objective_control(True)
    if not board.unit_controls_objective(board[0], 0):
        return False
    board[0].battle_socked = True
    if board.unit_controls_objective(board[0], 0):
        return False
    board.update_objective_control(True)
    return board.get_objective_controller(0) == -1 and (not board.unit_controls_objective(board[0], -1))

# pp.30/52: core control grants no points; explicit legacy mission scores each ID.
def test_mission_scoring_explicit_and_correct_for_both_players():
    board = rl.new('Board')
    board.objectives[0].controller = rl.ObjectiveController.army_0()
    board.objectives[1].controller = rl.ObjectiveController.army_1()
    board.objectives[2].controller = rl.ObjectiveController.army_0()
    board.objectives[3].controller = rl.ObjectiveController.army_1()
    rl.score(board)
    if board.score[0] != 0 or board.score[1] != 0:
        return False
    board.mission_scoring = rl.MissionScoringMode.legacy_four_markers()
    rl.score(board)
    board.current_player = True
    rl.score(board)
    return board.score[0] == 10 and board.score[1] == 10

# p.52: phase/turn hooks update control; start hooks must not do so.
def test_objective_phase_and_turn_control_hooks():
    board = rl.new('Board')
    unit = value_copy(rl.make_tantus())
    unit[0].position = board_position(12, 15)
    board.units.append(unit)
    start = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.movement_start()))
    if not start.is_done() or board.get_objective_controller(0) != -1:
        return False
    end = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.movement_end()))
    if not end.is_done() or board.get_objective_controller(0) != 0:
        return False
    board[0][0].position = board_position(2, 2)
    turn_end = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.turn_end()))
    return turn_end.is_done() and board.get_objective_controller(0) == -1

# Save/configuration infrastructure retains boundary/secured state (p.52),
# rejects malformed areas and dangling links, and preserves schema compatibility.
def test_objective_and_area_save_integrity():
    state = value_copy(rl.play())
    state.board.terrain_areas.append(terrain_area(9, 9, 15, 15, True))
    state.board.set_objective_position(0, board_position(10, 10))
    state.board.link_objective_terrain_areas()
    state.board.objectives[0].controller = rl.ObjectiveController.army_1()
    state.board.objectives[0].secured_by = rl.ObjectiveController.army_1()
    restored = value_copy(rl.play())
    if not rl.set_state(restored, rl.to_string(state)) or restored.board.get_objective_controller(0) != 1:
        return False
    state.board.objectives[0].area_id = 15
    if rl.set_state(restored, rl.to_string(state)):
        return False
    state.board.objectives[0].area_id = 0
    state.board.terrain_areas[0].upper = state.board.terrain_areas[0].lower
    return not rl.set_state(restored, rl.to_string(state)) and restored.board.objectives[0].secured_by == rl.ObjectiveController.army_1()

# pp.46/52 and user's scope: only valid categorized whole-quad areas are accepted.
def test_terrain_area_categories_and_transactional_links():
    board = rl.new('Board')
    area = value_copy(terrain_area(10, 10, 14, 20, False))
    area.light = True
    area.dense = True
    if not rl.valid_terrain_area(area):
        return False
    board.terrain_areas.append(area)
    if not board.link_objective_terrain_areas() or not board.objectives[0].terrain_objective:
        return False
    board.terrain_areas.append(area)
    if board.link_objective_terrain_areas():
        return False
    if board.objectives[0].area_id.value != 0:
        return False
    area.exposed = False
    area.light = False
    area.dense = False
    return not rl.valid_terrain_area(area)

# p.9 and supplied Within: a large base can intersect an area outside its centre.
def test_terrain_area_membership_uses_base_and_model_keywords():
    board = rl.new('Board')
    board.terrain_areas.append(terrain_area(10, 10, 15, 15, False))
    model = value_copy(rl.make_tantus()[0])
    model.position = board_position(9, 12)
    model.profile = rl.Profile.squighog_boyz()
    if not board.model_in_terrain_area(model, 0):
        return False
    model.position.x = 8
    if board.model_in_terrain_area(model, 0):
        return False
    model.keywords.clear()
    if rl.terrain_cover_model_kind(model):
        return False
    model.keywords.append(rl.Keyword.swarm())
    return rl.terrain_cover_model_kind(model)

# User's area-only approximation: crossing means partial, never physical blocking.
def test_area_crossing_partial_visibility_and_cover():
    board = value_copy(geometry_fixture())
    target = value_copy(rl.make_tantus())
    target[0].position = board_position(20, 5)
    board.terrain_areas.append(terrain_area(10, 4, 12, 6, True))
    if not rl.model_visible_to_model(board, board[0][0], target, target[0]) or not rl.model_partially_obscured(board, board[0][0], target[0]) or (not rl.unit_has_benefit_of_cover(board, board[0][0], target)):
        return False
    target[0].position.y = 15
    return rl.model_visible_to_model(board, board[0][0], target, target[0]) and (not rl.model_partially_obscured(board, board[0][0], target[0])) and (not rl.unit_has_benefit_of_cover(board, board[0][0], target))

# User's quad ray approximation includes tangent crossings and endpoints.
def test_area_crossing_boundary_and_endpoint():
    source = value_copy(rl.make_tantus()[0])
    target = value_copy(source)
    source.position = board_position(5, 5)
    target.position = board_position(20, 5)
    area = value_copy(terrain_area(10, 5, 12, 7, False))
    if not rl.sight_crosses_terrain_area(source, target, area):
        return False
    source.position.y = 4
    target.position.y = 4
    if rl.sight_crosses_terrain_area(source, target, area):
        return False
    target.position = board_position(10, 6)
    return rl.sight_crosses_terrain_area(source, target, area)

# p.50: all target models need cover, possibly from different conditions.
# Unit-level inherited Infantry cannot make a non-Infantry member eligible.
def test_cover_requires_each_model_and_preserves_model_keywords():
    board = value_copy(geometry_fixture())
    board[0][0].position = board_position(2, 5)
    target = value_copy(rl.make_infernus_squad())
    target.models.resize(2)
    target[0].position = board_position(18, 5)
    target[1].position = board_position(18, 10)
    target[1].profile = rl.Profile.squighog_boyz()
    board.terrain_areas.append(terrain_area(9, 4, 12, 6, False))
    if rl.unit_has_benefit_of_cover(board, board[0][0], target):
        return False
    board.terrain_areas.append(terrain_area(19, 10, 21, 12, False))
    if not rl.unit_has_benefit_of_cover(board, board[0][0], target):
        return False
    target[1].keywords.clear()
    return target.has_keyword(rl.Keyword.infantry()) and (not rl.unit_has_benefit_of_cover(board, board[0][0], target))

# p.50: a dense-area model is hidden until it fires; the previous turn matters.
def test_hidden_current_previous_turn_and_never_fired():
    board = value_copy(geometry_fixture())
    board.terrain_areas.append(terrain_area(4, 4, 6, 6, True))
    if not rl.model_is_hidden(board, board[0], board[0][0]):
        return False
    board.turn_serial = 10
    board.record_ranged_attacks(rl.unit_id(0))
    if rl.model_is_hidden(board, board[0], board[0][0]):
        return False
    board.start_turn_history()
    if rl.model_is_hidden(board, board[0], board[0][0]):
        return False
    board.start_turn_history()
    return rl.model_is_hidden(board, board[0], board[0][0])

# p.50: Hidden belongs to qualifying models in dense areas; light is insufficient.
def test_hidden_dense_category_and_individual_keyword():
    board = value_copy(geometry_fixture())
    area = value_copy(terrain_area(4, 4, 6, 6, False))
    area.light = True
    board.terrain_areas.append(area)
    if rl.model_is_hidden(board, board[0], board[0][0]):
        return False
    board.terrain_areas[0].dense = True
    board[0][0].keywords.clear()
    if rl.model_is_hidden(board, board[0], board[0][0]):
        return False
    board[0][0].keywords.append(rl.Keyword.beasts())
    return rl.model_is_hidden(board, board[0], board[0][0])

# p.50: base-to-base detection, default 15in, explicit supplied range overrides.
def test_hidden_detection_range_and_unit_visibility():
    board = value_copy(geometry_fixture())
    target = value_copy(rl.make_tantus())
    target[0].position = board_position(22, 5)
    board.terrain_areas.append(terrain_area(21, 4, 23, 6, True))
    if rl.model_visible_to_model(board, board[0][0], target, target[0]):
        return False
    if not rl.model_visible_to_model(board, board[0][0], target, target[0], 20):
        return False
    board[0][0].position.x = 6
    if not rl.model_visible_to_model(board, board[0][0], target, target[0]):
        return False
    if rl.model_visible_to_model(board, board[0][0], target, target[0], -1):
        return False
    board[0][0].position.x = 5
    visible = value_copy(target[0])
    visible.position = board_position(25, 5)
    target.models.append(visible)
    if not rl.model_can_see_unit(board, board[0][0], target) or not rl.unit_visible_to_unit(board, board[0], target):
        return False
    target.models.clear()
    return not rl.unit_visible_to_unit(board, board[0], target) and (not rl.unit_has_benefit_of_cover(board, board[0][0], target))

# p.50: BS worsens separately from hit modifiers/saves; p.82 Ignores Cover cancels.
def test_cover_changes_bs_not_hit_modifier_or_save():
    board = value_copy(attack_fixture())
    board.attack_info.target_has_cover = True
    base = value_copy(board.attack_info.source.skill())
    original_save = value_copy(board[1][0].profile.save())
    if rl.effective_attack_skill(board, board.attack_info) != base + 1 or board.attack_info.total_hit_modifier() != 0 or board[1][0].profile.save() != original_save:
        return False
    board.attack_info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.ignore_cover()))
    if rl.effective_attack_skill(board, board.attack_info) != base:
        return False
    board.attack_info.temporary_weapon_abilities.clear()
    board.attack_info.source = rl.Weapon.relic_weapon()
    return rl.effective_attack_skill(board, board.attack_info) == board.attack_info.source.skill()

# pp.18/50: natural six succeeds even at modified BS7; natural one always fails.
def test_cover_high_bs_natural_six_and_modified_threshold():
    six = rl.new('Dice')
    assign(six, 6)
    one = rl.new('Dice')
    assign(one, 1)
    three = rl.new('Dice')
    assign(three, 3)
    return rl.attack_hit_roll_succeeds(six, -1, 7) and (not rl.attack_hit_roll_succeeds(one, 10, 2)) and rl.attack_hit_roll_succeeds(three, 1, 4) and (not rl.attack_hit_roll_succeeds(three, 0, 4))

# p.50: native attack resolution uses covered BS and records even a missed shot.
def test_cover_attack_hit_transition_and_actual_shot_history():
    board = value_copy(attack_fixture())
    board.attack_info.target_has_cover = True
    board.turn_serial = 4
    attack = value_copy(rl.single_attack(board, board[1], board[0]))
    two = rl.new('Dice')
    assign(two, 2)
    attack.roll(board, board[1], board[0], two)
    if not attack.is_done() or board[0].history.last_ranged_attack_turn != 5:
        return False
    attack = rl.single_attack(board, board[1], board[0])
    three = rl.new('Dice')
    assign(three, 3)
    attack.roll(board, board[1], board[0], three)
    expected = value_copy(rl.CurrentStateDescription.wound_roll())
    return attack.can_roll(board, board[1], board[0], three) and board.current_state.value == expected.value

# p.50: selecting a unit but skipping its weapons does not break Hidden.
def test_skipped_shooting_does_not_record_ranged_attacks():
    board = value_copy(timing_fixture())
    board[0].can_shoot = True
    shooting = value_copy(rl.shooting_phase(board))
    shooting.select_target(board, rl.unit_id(0), rl.unit_id(1))
    shooting.choose_shooting_kind(board, rl.ShootingKind.normal())
    shooting.skip(board)
    return board[0].has_shoot and board[0].history.last_ranged_attack_turn == 0 and shooting.can_end_shooting_phase(board)

# pp.16/50/57: unit selectors, per-model weapons and Overwatch respect Hidden.
def test_hidden_target_rejected_by_shooting_and_overwatch():
    board = value_copy(timing_fixture())
    board[0].can_shoot = True
    board[1][0].position.x = 22
    board.terrain_areas.append(terrain_area(21, 4, 23, 6, True))
    shooting = value_copy(rl.shooting_phase(board))
    if shooting.can_select_target(board, rl.unit_id(0), rl.unit_id(1)):
        return False
    if rl.overwatch_target_valid(board, rl.unit_id(0), rl.unit_id(1)):
        return False
    board[1].history.last_ranged_attack_turn = board.turn_serial.value + 1
    return shooting.can_select_target(board, rl.unit_id(0), rl.unit_id(1)) and rl.overwatch_target_valid(board, rl.unit_id(0), rl.unit_id(1))

# Rules 02.04/04.03, pp.10/17: a fixed A characteristic supplies that many dice.
# The implementation checks `stat is Int` although raw_stat wraps a bounded Int.
def test_02_04_fixed_attack_characteristic():
    attacks = value_copy(rl.evaluate_random_stat(rl.raw_stat(4)))
    return attacks.is_done() and attacks.result.value == 4

# Rule 05.02, p.18. Existing strict > misses the exact double boundary.
def test_05_02_exact_double_strength():
    board = rl.new('Board')
    board.units.append(rl.make_infernus_squad())
    info = rl.new('AttackSequenceInfo')
    info.source = rl.Weapon.captain_storm_bolter()
    info.target_toughness = info.source.strenght() // 2
    return rl.required_wound_roll(board, info) == 2

# Rule 05.02, p.18. Existing strict < misses the exact half boundary.
def test_05_02_exact_half_strength():
    board = rl.new('Board')
    board.units.append(rl.make_infernus_squad())
    info = rl.new('AttackSequenceInfo')
    info.source = rl.Weapon.captain_storm_bolter()
    info.target_toughness = info.source.strenght() * 2
    return rl.required_wound_roll(board, info) == 6

# Test-only explicit characteristic/slot constructors retain finite domains.
def attack_test_die(value):
    result = rl.new('Dice')
    assign(result, value)
    return value_copy(result)

def attack_test_count(value):
    result = rl.new('CombatCounter')
    assign(result, value)
    return value_copy(result)

def attack_test_slot(value):
    result = rl.new('BInt<0, MAX_WEAPONS>')
    assign(result, value)
    return value_copy(result)

def attack_test_weapon(value):
    result = rl.new('AttackWeaponID')
    assign(result, value)
    return value_copy(result)

def attack_test_share(value):
    result = rl.new('AttackShareChoice')
    assign(result, value)
    return value_copy(result)

# Explicit generic fixture, not a supplied army datasheet: one bolter bearer
# and two enemy units for declaration/grouping boundary tests (pp.16–18).
def attack_declaration_fixture():
    board = value_copy(attack_fixture())
    board[0].models.resize(1)
    board[1].models.resize(1)
    board[0][0].position = board_position(5, 5)
    board[1][0].position = board_position(10, 5)
    board[0][0].weapons.clear()
    board[0][0].weapons.append(rl.Weapon.captain_storm_bolter())
    other = value_copy(board[1])
    other[0].identity = 0
    other.identity = 0
    other[0].position = board_position(10, 8)
    board.units.append(other)
    board.identify_units()
    return value_copy(board)

# p.16: all weapons and targets are declared before the first hit roll.
def test_attack_declarations_precede_rolls_and_allow_different_targets():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.append(rl.Weapon.librarian_storm_bolter())
    sequence = value_copy(rl.attack(board, rl.unit_id(0), rl.unit_id(1), False, False))
    sequence.select_weapon(board, attack_test_slot(0))
    sequence.select_weapon(board, attack_test_slot(1))
    if sequence.can_roll(board, attack_test_die(6)):
        return False
    sequence.skip(board)
    if sequence.can_declare_target(board, rl.unit_id(1), rl.unit_id(2)) or sequence.can_declare_target(board, rl.unit_id(0), rl.unit_id(0)):
        return False
    sequence.declare_target(board, rl.unit_id(0), rl.unit_id(1))
    if sequence.can_choose_attack_target(board, rl.unit_id(1)):
        return False
    sequence.declare_target(board, rl.unit_id(0), rl.unit_id(2))
    return sequence.declarations.size() == 2 and sequence.declarations[0].targeted[1] and sequence.declarations[1].targeted[2] and sequence.can_choose_attack_target(board, rl.unit_id(1)) and sequence.can_choose_attack_target(board, rl.unit_id(2)) and (not sequence.can_roll(board, attack_test_die(6)))

# pp.16–17: range/visibility belong to each bearer, not another nearby member.
def test_attack_declaration_per_model_range_and_engaged_target():
    board = value_copy(attack_declaration_fixture())
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if not rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False):
        return False
    board[1][0].position = board_position(40, 5)
    if rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False):
        return False
    board[1][0].position = board_position(8, 5)
    return not rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False) and rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), True)

# p.16: no mixing ranged/melee selections, duplicate slots or two main melee
# weapons; ending before the required melee selection is illegal.
def test_attack_weapon_selection_modes_duplicates_and_required_melee():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.append(rl.Weapon.relic_weapon())
    board[0][0].weapons.append(rl.Weapon.force_weapon())
    selected = rl.new('Bool[MAX_WEAPONS]')
    if rl.weapon_selection_valid(board, rl.unit_id(0), 0, 0, True, selected, False) or rl.weapon_selection_valid(board, rl.unit_id(0), 0, 1, False, selected, False):
        return False
    if rl.may_finish_weapon_selection(board, rl.unit_id(0), 0, True, False):
        return False
    selected[0] = True
    return not rl.weapon_selection_valid(board, rl.unit_id(0), 0, 0, False, selected, False) and (not rl.weapon_selection_valid(board, rl.unit_id(0), 0, 2, True, selected, True)) and rl.may_finish_weapon_selection(board, rl.unit_id(0), 0, True, True)

# p.17: split shares add to A and allocate at least one per selected target.
def test_attack_melee_split_budget_and_target_uniqueness():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.relic_weapon()
    board[1][0].position = board_position(8, 5)
    board[2][0].position = board_position(5, 8)
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    targets = value_copy(rl.declare_weapon_targets(board, weapon, rl.unit_id(0), True))
    targets.declare_target(board, rl.unit_id(0), rl.unit_id(1))
    if targets.can_assign_attacks(board, attack_test_share(7)):
        return False
    targets.assign_attacks(board, attack_test_share(2))
    if targets.can_declare_target(board, rl.unit_id(0), rl.unit_id(1)):
        return False
    targets.declare_target(board, rl.unit_id(0), rl.unit_id(2))
    if targets.can_assign_attacks(board, attack_test_share(3)):
        return False
    targets.assign_attacks(board, attack_test_share(4))
    return targets.is_done() and targets.weapon.shares[1] == 2 and (targets.weapon.shares[2] == 4)

# p.17: a sole eligible target must receive all remaining melee attacks,
# preventing a partial allocation from creating a selector with no choices.
def test_attack_melee_single_target_cannot_leave_unallocatable_share():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.relic_weapon()
    board[1][0].position = board_position(8, 5)
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    targets = value_copy(rl.declare_weapon_targets(board, weapon, rl.unit_id(0), True))
    targets.declare_target(board, rl.unit_id(0), rl.unit_id(1))
    return not targets.can_assign_attacks(board, attack_test_share(5)) and targets.can_assign_attacks(board, attack_test_share(6))

# p.17: mandatory coalescing gathers three A2 weapons, not one model at a time.
# Disable Rapid Fire distance in this fixture to demonstrate exactly six dice.
def test_attack_identical_weapons_gather_as_one_group():
    board = value_copy(attack_declaration_fixture())
    board[1][0].position.x = 22
    declarations = rl.new('DeclaredWeapons')
    for i in range(3):
        weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
        weapon.targeted[1] = True
        declarations.append(weapon)
    rl.configure_attack_info(board, 0, 1, False, False)
    group = value_copy(rl.gather_attack_group(board, declarations, rl.unit_id(0), rl.unit_id(1), attack_test_weapon(1), False, board.attack_info))
    return group.is_done() and group.count == 6 and declarations[0].resolved[1] and declarations[1].resolved[1] and declarations[2].resolved[1]

# p.17: differing cover/BS, D kinds, abilities and roll rules cannot coalesce.
def test_attack_group_identity_includes_characteristics_and_applicable_rules():
    board = value_copy(attack_declaration_fixture())
    left = value_copy(board.attack_info)
    right = value_copy(left)
    if not rl.attacks_are_identical(board, left, right):
        return False
    right.target_has_cover = True
    if rl.attacks_are_identical(board, left, right):
        return False
    right = value_copy(left)
    right.add_letal_hits()
    if rl.attacks_are_identical(board, left, right):
        return False
    right = value_copy(left)
    right.reroll1_hits = True
    return not rl.attacks_are_identical(board, left, right) and (not rl.same_damage_characteristic(rl.raw_stat(3), rl.dice_stat(3)))

# Supplied appendix 02.02.03: random A is rolled separately for each identical
# weapon at gathering, then combined; neither weapon rolls damage or hits yet.
def test_attack_random_attacks_per_weapon_before_group_hits():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.smite_witchfire()
    declarations = rl.new('DeclaredWeapons')
    for i in range(2):
        weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
        weapon.targeted[1] = True
        declarations.append(weapon)
    rl.configure_attack_info(board, 0, 1, False, False)
    group = value_copy(rl.gather_attack_group(board, declarations, rl.unit_id(0), rl.unit_id(1), attack_test_weapon(0), False, board.attack_info))
    group.quantity(board, declarations, attack_test_die(2))
    if group.is_done() or group.count != 2:
        return False
    group.quantity(board, declarations, attack_test_die(5))
    return group.is_done() and group.count == 7

# Supplied appendix 04.03.03: moved-out-of-range and destroyed targets allow
# selecting a new target; keep the originally declared melee share unchanged.
def test_attack_ineligible_target_can_be_redirected():
    board = value_copy(attack_declaration_fixture())
    declarations = rl.new('DeclaredWeapons')
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    weapon.targeted[1] = True
    weapon.shares[1] = 2
    declarations.append(weapon)
    board[1][0].position.x = 40
    correction = value_copy(rl.revalidate_attack_targets(board, declarations, rl.unit_id(0), False))
    if correction.can_retarget_weapon(board, declarations, rl.unit_id(0), rl.unit_id(1)):
        return False
    correction.retarget_weapon(board, declarations, rl.unit_id(0), rl.unit_id(2))
    return correction.is_done() and declarations[0].resolved[1] and declarations[0].targeted[2] and (declarations[0].shares[2] == 2) and (not declarations[0].resolved[2])

# pp.17/19: model compaction cannot transfer a declaration to another bearer.
def test_attack_source_identity_survives_compaction_and_rejects_casualty():
    board = value_copy(attack_declaration_fixture())
    other = value_copy(board[0][0])
    other.identity = 0
    board[0].models.append(other)
    board.identify_unit(board[0])
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 0))
    board[0].models.erase(0)
    if rl.declared_model_index(board, rl.unit_id(0), weapon) != 0:
        return False
    board[0].models.clear()
    return rl.declared_model_index(board, rl.unit_id(0), weapon) == -1 and (not rl.declaration_has_target(board, rl.unit_id(0), weapon, False))

# p.18 and supplied appendix 01.05.02: collect all original dice first; each
# original can be rerolled once and replacement dice cannot re-enter selection.
def test_attack_batch_collects_before_rerolls_and_prevents_second_reroll():
    board = value_copy(attack_declaration_fixture())
    board.current_decision_maker = True
    batch = value_copy(rl.collect_attack_dice(board, attack_test_count(2), True, False, False, False, rl.unit_id(0)))
    batch.roll(board, attack_test_die(1))
    if batch.can_select_reroll(board, attack_test_die(1)):
        return False
    batch.roll(board, attack_test_die(1))
    if board.current_decision_maker:
        return False
    batch.select_reroll(board, attack_test_die(1))
    batch.reroll(board, attack_test_die(6))
    if batch.can_select_reroll(board, attack_test_die(6)):
        return False
    batch.select_reroll(board, attack_test_die(1))
    batch.reroll(board, attack_test_die(6))
    return batch.is_done() and batch.pool.faces[5] == 2 and (batch.pool.total == 2) and board.current_decision_maker

# p.56: declining spends nothing; accepted batch CP reroll commits before
# replacement dice and cannot pay again in the same phase/for the same unit.
def test_attack_batch_command_reroll_cost_and_keep():
    board = value_copy(attack_declaration_fixture())
    board.command_points[0] = 2
    batch = value_copy(rl.collect_attack_dice(board, attack_test_count(2), False, False, True, False, rl.unit_id(0)))
    batch.roll(board, attack_test_die(2))
    batch.roll(board, attack_test_die(3))
    if board.command_points[0] != 2:
        return False
    batch.select_reroll(board, attack_test_die(2))
    if board.command_points[0] != 1 or not board.has_used_strat(rl.Stratagem.reroll(), 0):
        return False
    batch.reroll(board, attack_test_die(6))
    return batch.is_done() and batch.pool.faces[5] == 1 and (batch.pool.faces[2] == 1) and (not batch.can_select_reroll(board, attack_test_die(3)))

# pp.18/82/84: only critical original hits trigger Lethal, and Sustained
# generated hits roll wounds normally. No wounds resolve before all hit inputs.
def test_attack_critical_lethal_and_sustained_group_pipeline():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.add_letal_hits()
    board.attack_info.add_sustained_hits(2)
    group = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(2)))
    group.roll(board, board[1], board[0], attack_test_die(6))
    if group.generated_hits != 0 or group.generated_wounds != 0:
        return False
    group.roll(board, board[1], board[0], attack_test_die(3))
    group.use_lethal_hits(board, board[1], board[0], True)
    if group.generated_hits != 3 or group.generated_wounds != 1:
        return False
    group.roll(board, board[1], board[0], attack_test_die(1))
    group.roll(board, board[1], board[0], attack_test_die(1))
    if group.is_done():
        return False
    group.roll(board, board[1], board[0], attack_test_die(1))
    return group.is_done() and group.generated_wounds == 1

# p.18: natural critical wounds succeed even if modifiers require seven;
# ordinary hits/wounds do not become critical through positive modifiers.
def test_attack_natural_criticals_and_modifier_boundaries():
    board = value_copy(attack_declaration_fixture())
    info = value_copy(board.attack_info)
    if not rl.classify_attack_hit(board, info, attack_test_die(1), 10) == rl.AttackRollResult.failed() or not rl.classify_attack_hit(board, info, attack_test_die(6), -10) == rl.AttackRollResult.critical():
        return False
    if not rl.classify_attack_hit(board, info, attack_test_die(5), 1) == rl.AttackRollResult.success():
        return False
    return rl.classify_attack_wound(board, info, attack_test_die(6), 7) == rl.AttackRollResult.critical() and rl.classify_attack_wound(board, info, attack_test_die(1), 1) == rl.AttackRollResult.failed()

# p.57: six-only shots cannot use positive modifiers to turn a five into a hit.
def test_attack_snap_shooting_six_only_is_enforced():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.only_hits_on_6 = True
    return rl.classify_attack_hit(board, board.attack_info, attack_test_die(5), 1) == rl.AttackRollResult.failed() and rl.classify_attack_hit(board, board.attack_info, attack_test_die(6), -1) == rl.AttackRollResult.critical()

# Supplied appendix 02.02.01: bonuses lower the wound threshold, penalties
# increase it, and cumulative modifiers cap only after they are added.
def test_attack_wound_modifier_direction_and_cap():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.wound_roll_bonus = True
    board.attack_info.profile_wound_roll_bonus.append(board.attack_info.source_profile)
    if rl.required_wound_roll(board, board.attack_info) != 3:
        return False
    board.attack_info.wound_roll_malus = True
    if rl.required_wound_roll(board, board.attack_info) != 3:
        return False
    board.attack_info.profile_wound_roll_bonus.clear()
    return rl.required_wound_roll(board, board.attack_info) == 4

# pp.10/17/19: a fixed attack and damage actually remove wounds, proving that
# successful smoke completion no longer hides zero fixed characteristics.
def test_attack_fixed_damage_reaches_live_model():
    board = value_copy(attack_declaration_fixture())
    sequence = value_copy(rl.single_attack(board, board[1], board[0]))
    sequence.roll(board, board[1], board[0], attack_test_die(3))
    sequence.roll(board, board[1], board[0], attack_test_die(4))
    model = rl.new('ModelID')
    assign(model, 0)
    sequence.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    sequence.allocate_wound(board, board[1], board[0], model)
    return sequence.is_done() and board[1][0].suffered_wounds == 1

# Supplied appendix 02.02.01: operation order and only-final rounding; amounts
# use standard bounded numeric storage, separate from observation encoding.
def test_attack_modifier_order_final_rounding_and_zero_lock():
    modifiers = rl.new('RuleModifiers')
    rule = rl.new('RuleModifier')
    rule.operation = rl.ModifierOperation.subtract()
    rule.amount = 1
    modifiers.append(rule)
    rule.operation = rl.ModifierOperation.divide()
    rule.amount = 2
    modifiers.append(rule)
    rule.operation = rl.ModifierOperation.add()
    rule.amount = 1
    modifiers.append(rule)
    rule.operation = rl.ModifierOperation.multiply()
    rule.amount = 2
    modifiers.append(rule)
    if rl.apply_rule_modifiers(2, modifiers, False) != 2 or rl.apply_rule_modifiers(-2, modifiers, True) != -2:
        return False
    rule.operation = rl.ModifierOperation.replace()
    rule.amount = 0
    modifiers.append(rule)
    return rl.modified_characteristic(2, rl.ModifiedCharacteristic.strength(), modifiers, False) == 0

# Supplied appendix 02.02.01: characteristic, dice, charge and CP cost limits
# apply after cumulative arithmetic, without clamping stored CP balances.
def test_attack_modifier_characteristic_roll_and_cost_bounds():
    if rl.characteristic_limit(rl.ModifiedCharacteristic.ballistic_skill(), 7) != 6 or rl.characteristic_limit(rl.ModifiedCharacteristic.weapon_skill(), 1) != 2 or rl.characteristic_limit(rl.ModifiedCharacteristic.leadership(), 9) != 8 or (rl.characteristic_limit(rl.ModifiedCharacteristic.leadership(), 4) != 5):
        return False
    if rl.characteristic_limit(rl.ModifiedCharacteristic.save(), 1) != 2 or rl.characteristic_limit(rl.ModifiedCharacteristic.armour_penetration(), 2) != 0 or rl.characteristic_limit(rl.ModifiedCharacteristic.objective_control(), -1) != 0 or (rl.characteristic_limit(rl.ModifiedCharacteristic.detection_range(), 31) != 30):
        return False
    modifiers = rl.new('RuleModifiers')
    rule = rl.new('RuleModifier')
    rule.operation = rl.ModifierOperation.add()
    rule.amount = 4
    modifiers.append(rule)
    return rl.modified_dice_result(5, modifiers, True, False) == 6 and rl.modified_dice_result(6, modifiers, False, False) == 10 and (rl.modified_dice_result(11, modifiers, False, True) == 12) and (rl.modified_cp_cost(1, modifiers) == 2)

# p.79: unit keyword union activates ANTI; unmodified one still fails, and
# an ordinary noncritical wound does not inherit a critical ability trigger.
def test_attack_anti_uses_unit_keyword_and_natural_one_precedence():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.source = rl.Weapon.beastchoppa()
    board[1][0].keywords.append(rl.Keyword.monster())
    if not rl.classify_attack_wound(board, board.attack_info, attack_test_die(4), 6) == rl.AttackRollResult.critical():
        return False
    board.attack_info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.anti_monster(), 1))
    return rl.classify_attack_wound(board, board.attack_info, attack_test_die(1), 1) == rl.AttackRollResult.failed()

# pp.18–19: allocation groups precede all saves; every save input precedes
# per-attack allocation and fixed damage. This case asserts that boundary.
def test_attack_all_save_results_collected_before_damage():
    board = value_copy(attack_declaration_fixture())
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(2), attack_test_count(0)))
    model = rl.new('ModelID')
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    if board[1][0].suffered_wounds != 0 or board[1].empty():
        return False
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.allocate_wound(board, board[1], board[0], model)
    damage.allocate_wound(board, board[1], board[0], model)
    return damage.is_done() and board[1].empty()

# Supplied appendix 02.02.03: random D is rolled only after an actual damaging
# attack has a selected recipient, including critical save-bypassing wounds.
def test_attack_random_damage_waits_for_allocation():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.source = rl.Weapon.smite_witchfire()
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1)))
    if damage.can_quantity(board, board[1], board[0], attack_test_die(1)):
        return False
    model = rl.new('ModelID')
    damage.allocate_mortal(board, board[1], board[0], model)
    damage.quantity(board, board[1], board[0], attack_test_die(1))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# p.56 and supplied appendix 01.05.02: generated random A/D may reroll once;
# a kept characteristic neither spends CP nor requests a replacement result.
def test_attack_random_characteristic_command_reroll_once():
    board = value_copy(attack_declaration_fixture())
    board.command_points[0] = 2
    characteristic = value_copy(rl.evaluate_weapon_characteristic(board, rl.dice_stat(3), 2, False, rl.unit_id(0)))
    characteristic.quantity(board, attack_test_die(1))
    characteristic.keep_it(board, False)
    if board.command_points[0] != 1 or characteristic.can_reroll(board, attack_test_die(4)):
        return False
    characteristic.reroll(board, attack_test_die(3))
    return characteristic.is_done() and characteristic.result == 5 and (not characteristic.can_keep_it(board, False))

# p.17: finish all nonidentical groups against the selected unit before
# choosing another target, and consume each source model's weapon only once.
def test_attack_finishes_selected_target_before_next_and_each_weapon_once():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.append(rl.Weapon.librarian_storm_bolter())
    sequence = value_copy(rl.attack(board, rl.unit_id(0), rl.unit_id(1), False, False))
    sequence.select_weapon(board, attack_test_slot(0))
    sequence.select_weapon(board, attack_test_slot(1))
    sequence.skip(board)
    sequence.declare_target(board, rl.unit_id(0), rl.unit_id(1))
    sequence.declare_target(board, rl.unit_id(0), rl.unit_id(1))
    sequence.choose_attack_target(board, rl.unit_id(1))
    sequence.no_defensive_stratagem(board)
    sequence.no_offensive_stratagem(board)
    sequence.choose_attack_weapon(board, attack_test_weapon(0))
    # Captain bolter A2 + Rapid Fire2 at this range, all four miss.
    for i in range(4):
        sequence.roll(board, attack_test_die(1))
    if sequence.can_choose_attack_target(board, rl.unit_id(1)) or sequence.can_choose_attack_weapon(board, attack_test_weapon(0)) or (not sequence.can_choose_attack_weapon(board, attack_test_weapon(1))):
        return False
    sequence.choose_attack_weapon(board, attack_test_weapon(1))
    for i in range(4):
        sequence.roll(board, attack_test_die(1))
    return sequence.is_done() and sequence.declarations[0].made_attacks and sequence.declarations[1].made_attacks

# Test-only finite constructors for p.19 group and model selectors.
def allocation_test_group(value):
    result = rl.new('AllocationGroupID')
    assign(result, value)
    return value_copy(result)

def damage_test_model(value):
    result = rl.new('ModelID')
    assign(result, value)
    return value_copy(result)

# Mixed models are explicit core allocation fixtures, not attachment grants.
def damage_test_fixture():
    board = value_copy(attack_declaration_fixture())
    board[1].models.append(board[1][0])
    board[1][1].identity = 0
    board.identify_units()
    return value_copy(board)

# p.19: noncharacters combine by W/Sv/InSv, each character stays separate.
def test_damage_allocation_group_membership():
    board = value_copy(damage_test_fixture())
    captain = value_copy(rl.make_octavius())
    board[1].models.append(captain[0])
    board[1].models.append(captain[0])
    board.identify_units()
    groups = value_copy(rl.make_allocation_groups(board, board[1], board.attack_info))
    return groups.size() == 3 and groups[0].members.size() == 2 and groups[1].character and groups[2].character and (groups[1].members.size() == 1) and (groups[1].members[0].value != groups[2].members[0].value)

# p.19: wounded ordinary groups precede others; characters remain last, and
# wounded characters precede other characters. Duplicate/stale groups fail.
def test_damage_allocation_order_priority_and_duplicates():
    board = value_copy(damage_test_fixture())
    board[1][1].profile = rl.Profile.terminator_squad()
    board[1][1].suffered_wounds = 1
    captain = value_copy(rl.make_octavius())
    board[1].models.append(captain[0])
    board[1].models.append(captain[0])
    board[1][3].suffered_wounds = 1
    board.identify_units()
    groups = value_copy(rl.make_allocation_groups(board, board[1], board.attack_info))
    order = value_copy(rl.declare_allocation_order(board, groups, True))
    if order.can_choose_save_group(board, allocation_test_group(0)) or order.can_choose_save_group(board, allocation_test_group(2)):
        return False
    order.choose_save_group(board, allocation_test_group(1))
    if order.can_choose_save_group(board, allocation_test_group(1)):
        return False
    order.choose_save_group(board, allocation_test_group(0))
    if order.can_choose_save_group(board, allocation_test_group(2)):
        return False
    order.choose_save_group(board, allocation_test_group(3))
    order.choose_save_group(board, allocation_test_group(2))
    return order.is_done() and order.order.size() == 4

# p.19: select a wounded live member of the current group if possible.
def test_damage_wounded_member_priority_and_live_identity():
    board = value_copy(damage_test_fixture())
    board[1][1].suffered_wounds = 1
    groups = value_copy(rl.make_allocation_groups(board, board[1], board.attack_info))
    if rl.allocation_model_valid(board[1], groups[0], damage_test_model(0)):
        return False
    if not rl.allocation_model_valid(board[1], groups[0], damage_test_model(1)):
        return False
    board[1].remove_model(0)
    return rl.allocation_model_valid(board[1], groups[0], damage_test_model(0)) and (not rl.allocation_model_valid(board[1], groups[0], damage_test_model(1)))

# p.19: natural 1 fails; same result tests InSv before AP-adjusted Sv.
def test_damage_invulnerable_armour_ap_and_natural_one():
    group = rl.new('AllocationGroup')
    group.save = 2
    group.invulnerable = 4
    if rl.attack_save_succeeds(group, attack_test_die(1), 0) or not rl.attack_save_succeeds(group, attack_test_die(4), -5):
        return False
    group.invulnerable = 10
    group.save = 3
    return not rl.attack_save_succeeds(group, attack_test_die(3), -1) and rl.attack_save_succeeds(group, attack_test_die(4), -1) and rl.attack_save_succeeds(group, attack_test_die(6), 0)

# p.19: AP is nonpositive; old factories mixed signs and could improve saves.
def test_damage_all_weapon_ap_signs_are_consistent():
    weapon = rl.new('Weapon')
    for i in range(rl.max(weapon) + 1):
        weapon.value = i
        if weapon.penetration() > 0:
            return False
    return rl.Weapon.relic_weapon().penetration() == -2 and rl.Weapon.smite_witchfire().penetration() == -1

# pp.19/22–23: use the printed 1,1,3,4,5 saves. The explicit first group is
# wounded W3 models with two wounds remaining, not invented Geminae datasheets.
def test_damage_ascending_saves_change_current_group():
    board = value_copy(attack_declaration_fixture())
    term = value_copy(rl.make_terminator_squad())
    board[1].models.clear()
    board[1].models.append(term[0])
    board[1].models.append(term[0])
    board[1][0].suffered_wounds = 1
    board[1][1].suffered_wounds = 1
    infantry = value_copy(rl.make_infernus_squad())
    board[1].models.append(infantry[0])
    captain = value_copy(rl.make_octavius())
    board[1].models.append(captain[0])
    board.identify_units()
    board.attack_info.source = rl.Weapon.heavy_bolter()
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(5), attack_test_count(0)))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(1))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(2))
    damage.roll(board, board[1], board[0], attack_test_die(5))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.roll(board, board[1], board[0], attack_test_die(4))
    damage.roll(board, board[1], board[0], attack_test_die(3))
    if board[1].models.size() != 4:
        return False
    damage.roll(board, board[1], board[0], attack_test_die(1))
    for i in range(5):
        damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1].models.size() == 1 and board[1][0].is_character() and (board[1][0].suffered_wounds == 0) and (board[1].destroyed_models.value.size() == 3)

# p.19: D2 on a model with one remaining wound loses its excess; the next
# save is allocated to the next live model, not aggregated with the first.
def test_damage_normal_attacks_do_not_aggregate_or_spill():
    board = value_copy(damage_test_fixture())
    board[1][0].suffered_wounds = 1
    board.attack_info.source = rl.Weapon.heavy_bolter()
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(2), attack_test_count(0)))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.roll(board, board[1], board[0], attack_test_die(6))
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    if board[1].models.size() != 1 or board[1][0].suffered_wounds != 0:
        return False
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 0

# p.84: attacker's optional override applies only to a visible character
# group; defender still chooses that group's model and receives save choices.
def test_damage_precision_character_group_and_fallback():
    board = value_copy(damage_test_fixture())
    captain = value_copy(rl.make_octavius())
    board[1].models.append(captain[0])
    board[1][2].suffered_wounds = 5
    board.identify_units()
    board.attack_info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.precision()))
    board.attack_info.precision_visibility_known = True
    board.attack_info.precision_visible_targets[2] = True
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(2), attack_test_count(0)))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(1))
    if board.current_decision_maker or damage.can_choose_precision_group(board, board[1], board[0], allocation_test_group(0)):
        return False
    damage.choose_precision_group(board, board[1], board[0], allocation_test_group(1))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    if damage.can_allocate_wound(board, board[1], board[0], damage_test_model(0)):
        return False
    damage.allocate_wound(board, board[1], board[0], damage_test_model(2))
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1].models.size() == 2 and (board[1][0].suffered_wounds == 1)

# p.84: hidden/nonvisible characters do not expose the precision decision.
def test_damage_precision_hidden_character_not_selectable():
    board = value_copy(damage_test_fixture())
    captain = value_copy(rl.make_octavius())
    board[1].models.append(captain[0])
    board.identify_units()
    board.attack_info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.precision()))
    board.attack_info.precision_visibility_known = True
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(1), attack_test_count(0)))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(1))
    return not damage.can_choose_precision_group(board, board[1], board[0], allocation_test_group(1)) and damage.can_roll(board, board[1], board[0], attack_test_die(1))

# p.81: all normal D wounds can be prevented independently; no loss is
# committed before the prevention rolls finish, including damage beyond W.
def test_damage_feel_no_pain_normal_damage_each_wound():
    board = value_copy(damage_test_fixture())
    board[1][0].profile = rl.Profile.beast_snagga_boy()
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(1), rl.unit_id(0), True, True, 3, board[1][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    damage.roll(board, attack_test_die(6))
    damage.roll(board, attack_test_die(1))
    if board[1][0].suffered_wounds != 0:
        return False
    damage.roll(board, attack_test_die(6))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# p.24: mortal priority ignores save groups; wounded noncharacters first,
# unwounded noncharacters before wounded characters, then other characters.
def test_damage_mortal_recipient_priority():
    board = value_copy(damage_test_fixture())
    captain = value_copy(rl.make_octavius())
    board[1].models.append(captain[0])
    board[1][2].suffered_wounds = 1
    if rl.mortal_model_valid(board[1], damage_test_model(2)):
        return False
    board[1][1].suffered_wounds = 1
    return not rl.mortal_model_valid(board[1], damage_test_model(0)) and rl.mortal_model_valid(board[1], damage_test_model(1))

# pp.24/81: each mortal has its own FNP roll; prevention consumes a mortal,
# actual excess mortals spill after destruction of the previous recipient.
def test_damage_mortal_feel_no_pain_and_spill():
    board = value_copy(damage_test_fixture())
    board[1][0].profile = rl.Profile.beast_snagga_boy()
    board[1][1].profile = rl.Profile.beast_snagga_boy()
    mortals = value_copy(rl.resolve_mortal_wounds(board, rl.unit_id(1), rl.unit_id(0), True, attack_test_count(4)))
    for i in range(4):
        mortals.select_mortal_model(board, damage_test_model(0))
        if i == 0:
            mortals.roll(board, attack_test_die(6))
        else:
            mortals.roll(board, attack_test_die(1))
    return mortals.is_done() and board[1].models.size() == 1 and (board[1][0].suffered_wounds == 1)

# p.80: each critical Devastating Wound can damage one model only; a D3
# critical destroys a W2 model and loses its final mortal wound.
def test_damage_devastating_wounds_loses_per_attack_excess():
    board = value_copy(damage_test_fixture())
    board.attack_info.source = rl.Weapon.smite_focused_witchfire()
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1)))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    damage.quantity(board, board[1], board[0], attack_test_die(3))
    return damage.is_done() and board[1].models.size() == 1 and (board[1][0].suffered_wounds == 0)

# pp.24/80: a normal wound damages the first model before the critical mortal
# finishes it; mortals bypass saves rather than adding to normal damage.
def test_damage_normal_before_devastating_mortals():
    board = value_copy(damage_test_fixture())
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(1), attack_test_count(1)))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    if board[1][0].suffered_wounds != 1:
        return False
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1].models.size() == 1 and (board[1][0].suffered_wounds == 0)

# p.24: mixed monster/vehicle models qualify, mixed ordinary models do not.
def test_damage_hazard_large_model_multiplier():
    board = value_copy(damage_test_fixture())
    board[1][0].keywords.append(rl.Keyword.monster())
    board[1][1].keywords.append(rl.Keyword.vehicle())
    if rl.hazard_mortal_multiplier(board[1]) != 3:
        return False
    board[1][1].keywords.clear()
    return rl.hazard_mortal_multiplier(board[1]) == 1

# pp.24/81: all hazard dice precede allocation; both 1 and 2 fail and each
# inflicts one ordinary mortal for a non-MONSTER/VEHICLE unit.
def test_damage_hazard_batch_one_and_two_fail():
    board = value_copy(damage_test_fixture())
    count = rl.new('HazardousUses')
    assign(count, 3)
    hazards = value_copy(rl.resolve_hazards(board, rl.unit_id(1), count))
    hazards.roll(board, attack_test_die(1))
    hazards.roll(board, attack_test_die(2))
    if board[1][0].suffered_wounds != 0:
        return False
    hazards.roll(board, attack_test_die(3))
    hazards.select_mortal_model(board, damage_test_model(0))
    hazards.select_mortal_model(board, damage_test_model(0))
    return hazards.is_done() and board[1].models.size() == 1

# p.81: HAZARDOUS counts selected weapons even if all targets were skipped.
def test_damage_hazard_selected_but_skipped_weapon():
    board = value_copy(damage_test_fixture())
    board[0][0].weapons.clear()
    board[0][0].weapons.append(rl.Weapon.smite_focused_witchfire())
    sequence = value_copy(rl.attack(board, rl.unit_id(0), rl.unit_id(1), False, False))
    sequence.select_weapon(board, attack_test_slot(0))
    sequence.skip(board)
    sequence.skip_target(board)
    if not sequence.can_roll(board, attack_test_die(2)):
        return False
    sequence.roll(board, attack_test_die(2))
    sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[0][0].suffered_wounds == 1

# p.87: no triggered rule means immediate removal, not unconditional retention.
def test_damage_no_trigger_immediate_destruction():
    board = value_copy(damage_test_fixture())
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(1), rl.unit_id(0), True, True, 10, board[1][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    return damage.is_done() and board[1].models.size() == 1 and (board[1].destroyed_models.value.size() == 1)

# p.87: a real attack-caused trigger retains the model until the whole source
# activation finishes; the retained model cannot be allocated further damage.
def test_damage_triggered_attack_death_is_deferred_and_ineligible():
    board = value_copy(damage_test_fixture())
    board[1][0].has_deadly_demise = True
    board[1][0].deadly_demise = rl.raw_stat(1)
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(1), rl.unit_id(0), True, True, 10, board[1][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    if not damage.is_done() or board[1].models.size() != 2 or board[1][0].is_alive() or rl.mortal_model_valid(board[1], damage_test_model(0)):
        return False
    empty_jobs = rl.new('DamageJobs')
    cleanup = value_copy(rl.resolve_damage_jobs(board, empty_jobs, True, rl.unit_id(0)))
    cleanup.choose_destruction_unit(board, rl.unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.roll(board, attack_test_die(1))
    return cleanup.is_done() and board[1].models.size() == 1 and (board[1].destroyed_models.value.size() == 1)

# pp.80/87: non-attack destruction triggers before the next ordinary mortal;
# a failed Deadly Demise still removes/archives exactly once.
def test_damage_nonattack_trigger_interrupts_mortal_sequence():
    board = value_copy(damage_test_fixture())
    board[1][0].suffered_wounds = 1
    board[1][0].has_deadly_demise = True
    board[1][0].deadly_demise = rl.raw_stat(1)
    mortals = value_copy(rl.resolve_mortal_wounds(board, rl.unit_id(1), rl.unit_id(0), True, attack_test_count(2)))
    mortals.select_mortal_model(board, damage_test_model(0))
    if mortals.can_select_mortal_model(board, damage_test_model(1)):
        return False
    mortals.choose_destruction_unit(board, rl.unit_id(1))
    mortals.resolve_destruction_model(board, damage_test_model(0))
    mortals.roll(board, attack_test_die(1))
    mortals.select_mortal_model(board, damage_test_model(0))
    return mortals.is_done() and board[1].models.size() == 1 and (board[1][0].suffered_wounds == 1)

# p.87 and supplied Rules Sequencing: current player's pending triggers are
# chosen before opponent triggers, with each owner choosing their own order.
def test_damage_destruction_current_player_priority():
    board = value_copy(damage_test_fixture())
    board.current_player = True
    for i in range(2):
        board[i][0].state = rl.ModelState.pending_destruction()
        board[i][0].destruction_pending = True
    jobs = rl.new('DamageJobs')
    cleanup = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    if cleanup.can_choose_destruction_unit(board, rl.unit_id(0)):
        return False
    cleanup.choose_destruction_unit(board, rl.unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.choose_destruction_unit(board, rl.unit_id(0))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    return cleanup.is_done() and board[0].empty() and (board[1].models.size() == 1)

# p.83: MELTA range is snapshotted when selecting its target, not remeasured
# after declaration when a model/target changes its position.
def test_damage_melta_declaration_snapshot():
    board = value_copy(damage_test_fixture())
    board[0][0].weapons[0] = rl.Weapon.meltagun()
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    declaration = value_copy(rl.declare_weapon_targets(board, weapon, rl.unit_id(0), False))
    declaration.declare_target(board, rl.unit_id(0), rl.unit_id(1))
    bonus = value_copy(declaration.weapon.melta_bonus[1].value)
    board[1][0].position.x = 30
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration.weapon, board.attack_info))
    return bonus == weapon.weapon.get_rule_parameter(rl.WeaponRuleKind.melta()) and bonus > 0 and (info.melta_damage_bonus.value == bonus)

# pp.80/87: a successful demise damages nearby live units, then removes the
# physically retained corpse. This fixture has no embarked passengers (task 16).
def test_damage_deadly_demise_retains_model_through_nearby_damage():
    board = value_copy(damage_test_fixture())
    board[1][0].has_deadly_demise = True
    board[1][0].deadly_demise = rl.raw_stat(1)
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(1), rl.unit_id(0), True, True, 10, board[1][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    empty_jobs = rl.new('DamageJobs')
    cleanup = value_copy(rl.resolve_damage_jobs(board, empty_jobs, True, rl.unit_id(0)))
    cleanup.choose_destruction_unit(board, rl.unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.roll(board, attack_test_die(6))
    if board[1].models.size() != 2:
        return False
    cleanup.select_mortal_model(board, damage_test_model(0))
    cleanup.select_mortal_model(board, damage_test_model(1))
    if board[1].models.size() != 2:
        return False
    cleanup.select_mortal_model(board, damage_test_model(0))
    return cleanup.is_done() and board[0][0].suffered_wounds == 1 and (board[1].models.size() == 1) and (board[1][0].suffered_wounds == 1) and (board[2][0].suffered_wounds == 1)

# p.80: random demise amounts are determined separately for every nearby unit,
# not once reused for the entire explosion. Damage may itself destroy units.
def test_damage_deadly_demise_random_amount_per_unit():
    board = value_copy(damage_test_fixture())
    board[1][0].has_deadly_demise = True
    board[1][0].deadly_demise = rl.dice_stat(3)
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(1), rl.unit_id(0), True, True, 10, board[1][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    empty_jobs = rl.new('DamageJobs')
    cleanup = value_copy(rl.resolve_damage_jobs(board, empty_jobs, True, rl.unit_id(0)))
    cleanup.choose_destruction_unit(board, rl.unit_id(1))
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
    return cleanup.is_done() and board[0].empty() and board[1].empty() and (board[2][0].suffered_wounds == 1)

# pp.24/80/81: prevention is allowed for devastating mortals, but a failed
# prevention that destroys the recipient does not spill that critical's excess.
def test_damage_devastating_feel_no_pain_and_one_model_limit():
    board = value_copy(damage_test_fixture())
    board[1][0].profile = rl.Profile.beast_snagga_boy()
    board[1][1].profile = rl.Profile.beast_snagga_boy()
    board.attack_info.source = rl.Weapon.smite_focused_witchfire()
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1)))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    damage.quantity(board, board[1], board[0], attack_test_die(3))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    return damage.is_done() and board[1].models.size() == 1 and (board[1][0].suffered_wounds == 0)

# p.80's cap concerns models damaged, not wounds successfully prevented. A
# prevented first mortal does not force another unwounded model out of eligibility.
def test_damage_devastating_prevented_first_wound_allows_new_recipient():
    board = value_copy(damage_test_fixture())
    board[1][0].profile = rl.Profile.beast_snagga_boy()
    board[1][1].profile = rl.Profile.beast_snagga_boy()
    board.attack_info.source = rl.Weapon.smite_focused_witchfire()
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1)))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    damage.quantity(board, board[1], board[0], attack_test_die(3))
    damage.roll(board, board[1], board[0], attack_test_die(6))
    if not damage.can_select_mortal_model(board, board[1], board[0], damage_test_model(1)):
        return False
    damage.select_mortal_model(board, board[1], board[0], damage_test_model(1))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.roll(board, board[1], board[0], attack_test_die(6))
    return damage.is_done() and board[1][0].suffered_wounds == 0 and (board[1][1].suffered_wounds == 1)

# pp.24/56/81: a hazard batch allows one targeted CP reroll after originals,
# with replacement eligibility/cost separated from remaining failed hazards.
def test_damage_hazard_command_reroll_owner_cost_and_result():
    board = value_copy(damage_test_fixture())
    board.command_points[1] = 2
    count = rl.new('HazardousUses')
    assign(count, 2)
    hazards = value_copy(rl.resolve_hazards(board, rl.unit_id(1), count))
    hazards.roll(board, attack_test_die(1))
    hazards.roll(board, attack_test_die(2))
    if not board.current_decision_maker:
        return False
    hazards.select_reroll(board, attack_test_die(1))
    if board.command_points[1] != 1:
        return False
    hazards.reroll(board, attack_test_die(6))
    hazards.select_mortal_model(board, damage_test_model(0))
    return hazards.is_done() and board[1][0].suffered_wounds == 1 and (board.command_points[1] == 1)

# pp.24/81: three mortals for each failed all-large-unit hazard spill normally.
def test_damage_large_unit_hazard_three_mortals_spill():
    board = value_copy(damage_test_fixture())
    for i in range(2):
        board[1][i].keywords.append(rl.Keyword.vehicle())
    count = rl.new('HazardousUses')
    assign(count, 1)
    hazards = value_copy(rl.resolve_hazards(board, rl.unit_id(1), count))
    hazards.roll(board, attack_test_die(2))
    for i in range(3):
        hazards.select_mortal_model(board, damage_test_model(0))
    return hazards.is_done() and board[1].models.size() == 1 and (board[1][0].suffered_wounds == 1)

# p.87: existing feeder-tendrils hook is deferred with the character casualty;
# its legacy faction effect is retained, not asserted as new-edition faction data.
def test_damage_feeder_trigger_waits_until_activation_cleanup():
    board = value_copy(damage_test_fixture())
    board[0][0].abilities.append(rl.AbilityKind.feeder_tendrils())
    board[1][0].keywords.append(rl.Keyword.character())
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(1), rl.unit_id(0), True, True, 10, board[1][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    if board.command_points[0] != 0 or not board[1][0].destruction_pending:
        return False
    empty_jobs = rl.new('DamageJobs')
    cleanup = value_copy(rl.resolve_damage_jobs(board, empty_jobs, True, rl.unit_id(0)))
    cleanup.choose_destruction_unit(board, rl.unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    return cleanup.is_done() and board.command_points[0] == 1 and (board[1].destroyed_models.value.size() == 1)

# p.87: retained destroyed models contribute no OC and cannot supply active
# unit abilities; explicit on-destruction properties remain readable to hooks.
def test_damage_pending_model_oc_and_active_ability_exclusion():
    board = value_copy(damage_test_fixture())
    board[1][0].abilities.append(rl.AbilityKind.feeder_tendrils())
    board[1][0].state = rl.ModelState.pending_destruction()
    board[1][0].suffered_wounds = 2
    return board[1].model_objective_control(0) == 0 and (not board[1].has_ability(rl.AbilityKind.feeder_tendrils())) and (not board[1][0].is_alive())

# p.87: deferred trigger state, random demise and source identity survive saves;
# malformed provenance is rejected atomically rather than stranded forever.
def test_damage_pending_death_save_round_trip_and_source_guard():
    state = value_copy(rl.play())
    state.board = damage_test_fixture()
    state.board[1][0].state = rl.ModelState.pending_destruction()
    state.board[1][0].suffered_wounds = 2
    state.board[1][0].destruction_pending = True
    state.board[1][0].destroyed_by_attack = True
    state.board[1][0].destroying_unit_known = True
    state.board[1][0].destroying_unit = 0
    state.board[1][0].has_deadly_demise = True
    state.board[1][0].deadly_demise = rl.dice_stat(3)
    restored = value_copy(rl.play())
    if not rl.set_state(restored, rl.to_string(state)):
        return False
    demise = value_copy(restored.board[1][0].deadly_demise)
    if rl.is_variant(demise, "Dice"):
        demise = rl.variant(demise, "Dice")
        if demise.value != 3 or not restored.board[1][0].destruction_pending:
            return False
    else:
        return False
    before = value_copy(rl.to_string(restored))
    state.board[1][0].destroying_unit = 31
    if rl.set_state(restored, rl.to_string(state)) or rl.to_string(restored) != before:
        return False
    state.board[1][0].destroying_unit = 0
    state.board[1][0].destroying_unit_known = False
    return not rl.set_state(restored, rl.to_string(state)) and rl.to_string(restored) == before

# pp.12/33: explicit single-model board avoids unavailable faction/mission data.
def movement11_fixture():
    board = value_copy(geometry_fixture())
    board.phase_serial = 3
    board[0].can_charge = True
    board[0].can_shoot = True
    board.timing.phase = rl.BattlePhase.movement()
    board.identify_units()
    return value_copy(board)

# p.33: normal/advance require unengaged; Ordered Retreat requires unshocked.
def test_movement11_modes_and_shock_legality():
    board = value_copy(movement11_fixture())
    enemy = value_copy(board[0])
    enemy.identity = 0
    enemy[0].identity = 0
    enemy.owned_by_player1 = True
    enemy[0].position = board_position(8, 5)
    board.units.append(enemy)
    id = value_copy(rl.unit_id(0))
    if rl.battlefield_move_eligible(board, id, rl.MovementKind.normal()) or not rl.battlefield_move_eligible(board, id, rl.MovementKind.ordered_retreat()):
        return False
    board[0].battle_socked = True
    return not rl.battlefield_move_eligible(board, id, rl.MovementKind.ordered_retreat()) and rl.battlefield_move_eligible(board, id, rl.MovementKind.desperate_escape()) and rl.battlefield_move_eligible(board, id, rl.MovementKind.stationary())

# p.32: phase end requires explicit selection of every unit, including reserves.
def test_movement11_mandatory_selection_including_reserves():
    board = value_copy(movement11_fixture())
    board.reserve_units.append(board[0])
    if rl.movement_selection_complete(board, False):
        return False
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.stationary())
    if rl.movement_selection_complete(board, False):
        return False
    board.reserve_units[0].history.selected_move_phase = board.phase_serial.value + 1
    return rl.movement_selection_complete(board, False)

# p.33: stationary neither rotates nor records an actual move/charge restriction.
def test_movement11_stationary_has_no_move_event():
    board = value_copy(movement11_fixture())
    before = value_copy(board[0][0].position)
    selected = value_copy(rl.movement(board, rl.unit_id(0), False))
    selected.remain_stationary(board)
    return selected.is_done() and board[0][0].position.x == before.x and (board[0][0].position.y == before.y) and (board[0].history.last_move_phase == 0) and (board[0].history.selected_move_phase == board.phase_serial.value + 1) and (board[0].can_charge == True)

# pp.12/87: independently move mixed-M models, permitting intermediate
# incoherency but requiring coherent final placement and each own distance.
def test_movement11_independent_models_stage_then_commit():
    board = value_copy(movement11_fixture())
    fast = value_copy(board[0][0])
    fast.profile = rl.Profile.possessed()
    board[0].models.append(fast)
    board[0][1].position = board_position(7, 5)
    id = value_copy(rl.unit_id(0))
    sequence = value_copy(rl.move(board, id, 0))
    sequence.select_moving_model(board, id, damage_test_model(0))
    sequence.waypoint(board, id, board_position(11, 5))
    sequence.finish_model(board, id)
    if board[0][0].position.x != 5 or sequence.can_finish_move(board, id):
        return False
    sequence.select_moving_model(board, id, damage_test_model(1))
    if sequence.can_waypoint(board, id, board_position(17, 5)):
        return False
    sequence.waypoint(board, id, board_position(13, 5))
    sequence.finish_model(board, id)
    if sequence.can_select_moving_model(board, id, damage_test_model(1)):
        return False
    sequence.finish_move(board, id)
    return sequence.completed and board[0][0].position.x == 11 and (board[0][1].position.x == 13)

# p.12: all straight segments add up, including retracing; skip rolls back.
def test_movement11_waypoint_budget_and_atomic_cancel():
    board = value_copy(movement11_fixture())
    id = value_copy(rl.unit_id(0))
    before = value_copy(rl.to_string(board[0]))
    sequence = value_copy(rl.move(board, id, 0))
    sequence.select_moving_model(board, id, damage_test_model(0))
    sequence.waypoint(board, id, board_position(9, 5))
    if sequence.can_waypoint(board, id, board_position(5, 5)):
        return False
    sequence.finish_model(board, id)
    sequence.skip(board, id)
    return not sequence.completed and rl.to_string(board[0]) == before

# p.12: rotate circular fixtures freely; one degree choice changes no position.
def test_movement11_free_rotation_and_invalid_model_id():
    board = value_copy(movement11_fixture())
    id = value_copy(rl.unit_id(0))
    sequence = value_copy(rl.move(board, id, 0))
    if sequence.can_select_moving_model(board, id, damage_test_model(1)):
        return False
    sequence.select_moving_model(board, id, damage_test_model(0))
    rotation = rl.new('MovementRotation')
    assign(rotation, 90)
    sequence.rotate_model(board, id, rotation)
    sequence.finish_model(board, id)
    sequence.finish_move(board, id)
    return board[0][0].geometry.rotation.value == 90000 and board[0][0].position.x == 5 and (board[0][0].history.distance_moved_this_turn() == 0.0)

# p.33: Advance's full D6 allowance persists and forbids charge/action start.
def test_movement11_advance_roll_budget_and_flags():
    board = value_copy(movement11_fixture())
    board.command_points[0] = 0
    sequence = value_copy(rl.movement(board, rl.unit_id(0), False))
    sequence.advance(board, True)
    sequence.roll(board, attack_test_die(6))
    if not sequence.can_move_to(board, board_position(17, 5)) or sequence.can_move_to(board, board_position(18, 5)):
        return False
    sequence.move_to(board, board_position(17, 5))
    return sequence.is_done() and board[0].has_run and board[0].history.advanced_this_turn and (not board[0].can_charge) and (not board[0].allows_action_start())

# p.33: Ordered Retreat offers no hazards and cannot cross enemy bases.
def test_movement11_ordered_retreat_path_and_flags():
    board = value_copy(movement11_fixture())
    enemy = value_copy(board[0])
    enemy.owned_by_player1 = True
    enemy[0].position = board_position(7, 5)
    board.units.append(enemy)
    sequence = value_copy(rl.movement(board, rl.unit_id(0), False))
    sequence.ordered_retreat(board)
    if sequence.can_roll(board, attack_test_die(3)) or sequence.can_move_to(board, board_position(11, 5)):
        return False
    sequence.move_to(board, board_position(2, 5))
    return board[0].history.fell_back_this_turn and (not board[0].can_shoot) and (not board[0].can_charge) and (not board[0].allows_action_start())

# pp.24/33: Desperate Escape hazards are mortal wounds, allow FNP and can
# cross enemies; an unshocked surviving unit then rolls Battle-shock.
def test_movement11_desperate_escape_hazards_and_post_shock():
    board = value_copy(movement11_fixture())
    enemy = value_copy(board[0])
    enemy.owned_by_player1 = True
    enemy[0].position = board_position(7, 5)
    board.units.append(enemy)
    sequence = value_copy(rl.movement(board, rl.unit_id(0), False))
    sequence.desperate_escape(board)
    sequence.roll(board, attack_test_die(2))
    sequence.select_mortal_model(board, damage_test_model(0))
    if board[0][0].suffered_wounds != 1:
        return False
    sequence.move_to(board, board_position(11, 5))
    sequence.roll_pair(board, attack_test_die(1), attack_test_die(1))
    return sequence.is_done() and board[0].battle_socked and (board[0][0].position.x == 11)

# p.33: already shocked Desperate Escape does not offer a second shock roll.
def test_movement11_shocked_escape_no_extra_shock_roll():
    board = value_copy(movement11_fixture())
    board[0].battle_socked = True
    enemy = value_copy(board[0])
    enemy.owned_by_player1 = True
    enemy[0].position = board_position(7, 5)
    board.units.append(enemy)
    sequence = value_copy(rl.movement(board, rl.unit_id(0), False))
    sequence.desperate_escape(board)
    sequence.roll(board, attack_test_die(3))
    sequence.move_to(board, board_position(11, 5))
    return sequence.is_done() and board[0].battle_socked

# p.71/82: Take to the Skies costs 2 for all models; Hover is its exception.
def test_movement11_flying_budget_and_hover():
    board = value_copy(movement11_fixture())
    board[0][0].keywords.append(rl.Keyword.fly())
    if rl.model_move_budget(board[0][0], rl.MovementKind.normal(), 0, -1, True) != 4:
        return False
    board[0][0].abilities.append(rl.AbilityKind.hover())
    return rl.model_move_budget(board[0][0], rl.MovementKind.normal(), 0, -1, True) == 6

# p.71: only the flying models gain enemy traversal; mixed units keep the
# non-FLY member's ordinary collision rule, even when the unit takes skies.
def test_movement11_mixed_flying_per_model_traversal():
    board = value_copy(movement11_fixture())
    enemy = value_copy(board[0])
    enemy.owned_by_player1 = True
    enemy[0].position = board_position(7, 5)
    board.units.append(enemy)
    path = rl.new('ModelPath')
    path.model = 0
    if rl.waypoint_valid(board, board[0], path, board_position(9, 5), rl.MovementKind.normal(), 0, -1, True):
        return False
    board[0][0].keywords.append(rl.Keyword.fly())
    return rl.waypoint_valid(board, board[0], path, board_position(9, 5), rl.MovementKind.normal(), 0, -1, True)

# p.71: flying distance ignores vertical movement while grounded movement adds it.
def test_movement11_flying_vertical_distance():
    board = value_copy(movement11_fixture())
    board[0][0].keywords.append(rl.Keyword.fly())
    path = rl.new('ModelPath')
    path.model = 0
    path.append_point(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 3 * rl.MICROMETRES_PER_INCH))
    return rl.path_distance(board[0][0], path, True) == 0.0 and rl.path_distance(board[0][0], path, False) == float(3 * rl.MICROMETRES_PER_INCH)

# p.85: walker traversal cannot cross TITANIC, but can cross ordinary enemies.
def test_movement11_super_heavy_walker_traversal():
    board = value_copy(movement11_fixture())
    board[0][0].abilities.append(rl.AbilityKind.super_heavy_walker())
    enemy = value_copy(board[0])
    enemy[0].abilities.clear()
    enemy.owned_by_player1 = True
    enemy[0].position = board_position(8, 5)
    board.units.append(enemy)
    path = rl.new('ModelPath')
    path.model = 0
    if not rl.waypoint_valid(board, board[0], path, board_position(11, 5), rl.MovementKind.normal(), 0, -1, False):
        return False
    board[1][0].keywords.append(rl.Keyword.titanic())
    return not rl.waypoint_valid(board, board[0], path, board_position(11, 5), rl.MovementKind.normal(), 0, -1, False)

# p.85: temporary MOBILE ends with the move, and its end roll shocks on 1.
def test_movement11_walker_mobile_lifetime_and_shock():
    board = value_copy(movement11_fixture())
    board[0][0].abilities.append(rl.AbilityKind.super_heavy_walker())
    sequence = value_copy(rl.movement(board, rl.unit_id(0), False))
    sequence.normal_move(board)
    sequence.walker_mobile(board, True)
    if not board[0][0].has_keyword(rl.Keyword.mobile()):
        return False
    sequence.move_to(board, board_position(6, 5))
    if board[0][0].has_keyword(rl.Keyword.mobile()):
        return False
    sequence.roll(board, attack_test_die(1))
    return sequence.is_done() and board[0].battle_socked

# Supplied 02.02.03: determine entire unit's random M once on selection;
# characteristic determination cannot use Command Re-roll (p.56).
def test_movement11_random_movement_once_for_unit():
    board = value_copy(movement11_fixture())
    board[0][0].has_random_movement = True
    board[0][0].random_movement = rl.dice_stat(3)
    board.command_points[0] = 5
    sequence = value_copy(rl.movement(board, rl.unit_id(0), False))
    sequence.quantity(board, attack_test_die(2))
    if sequence.can_reroll(board, attack_test_die(3)):
        return False
    sequence.normal_move(board)
    if sequence.can_move_to(board, board_position(8, 5)):
        return False
    sequence.move_to(board, board_position(7, 5))
    return sequence.is_done() and board[0].movement_override.value == rl.MOVE_M_UNSET and (board.command_points[0] == 5)

# p.14: every base must fit the home zone; merely fitting the anchor fails.
def test_movement11_deployment_whole_base_boundary():
    board = value_copy(movement11_fixture())
    unit = value_copy(board[0])
    unit.owned_by_player1 = True
    board.units.clear()
    return rl.setup_at_valid(board, unit, board_position(5, 4), rl.MovementKind.normal(), False) and (not rl.setup_at_valid(board, unit, board_position(5, 5), rl.MovementKind.normal(), False))

# p.82: Infiltrators require every model and strict >8 from enemy zones/models.
def test_movement11_infiltrator_horizontal_clearance():
    board = value_copy(movement11_fixture())
    board[0].owned_by_player1 = True
    if rl.setup_at_valid(board, board[0], board_position(5, 17), rl.MovementKind.normal(), True):
        return False
    return rl.setup_at_valid(board, board[0], board_position(5, 16), rl.MovementKind.normal(), True)

# p.69: reserves start in round 2, wholly within the union of 6-inch edges;
# before round 3 the opposite deployment zone is excluded, even at the side.
def test_movement11_ingress_round_edge_and_opponent_zone():
    board = value_copy(movement11_fixture())
    unit = value_copy(board[0])
    board.units.clear()
    board.current_round = 1
    if not rl.setup_at_valid(board, unit, board_position(5, 10), rl.MovementKind.ingress(), False) or rl.setup_at_valid(board, unit, board_position(6, 10), rl.MovementKind.ingress(), False) or rl.setup_at_valid(board, unit, board_position(2, 2), rl.MovementKind.ingress(), False):
        return False
    board.current_round = 2
    return rl.setup_at_valid(board, unit, board_position(2, 2), rl.MovementKind.ingress(), False)

# p.69: no distant tail may escape edge-strip restrictions after an anchor fits.
def test_movement11_ingress_each_model_edge_strip():
    board = value_copy(movement11_fixture())
    board[0].models.append(board[0][0])
    board[0][0].position = board_position(5, 10)
    board[0][1].position = board_position(7, 10)
    candidate = value_copy(board[0])
    board.units.clear()
    return not rl.setup_rules_valid(board, candidate, rl.MovementKind.ingress(), False)

# pp.69/80: all-model Deep Strike bypasses edge/opponent-zone restrictions;
# mixed permissions do not. It never waives the strict enemy distance.
def test_movement11_deep_strike_all_models_and_distance():
    board = value_copy(movement11_fixture())
    candidate = value_copy(board[0])
    candidate[0].abilities.append(rl.AbilityKind.deep_strike())
    candidate[0].position = board_position(20, 20)
    if not rl.setup_rules_valid(board, candidate, rl.MovementKind.ingress(), False):
        return False
    candidate.models.append(candidate[0])
    candidate[1].position = board_position(22, 20)
    candidate[1].abilities.clear()
    if rl.setup_rules_valid(board, candidate, rl.MovementKind.ingress(), False):
        return False
    candidate[1].abilities.append(rl.AbilityKind.deep_strike())
    board[0].owned_by_player1 = True
    board[0][0].position = board_position(13, 20)
    return not rl.setup_rules_valid(board, candidate, rl.MovementKind.ingress(), False)

# p.69: arrival locks later moves and captures ingress/setup history.
def test_movement11_ingress_history_and_lock():
    board = value_copy(movement11_fixture())
    board.reserve_units.append(board[0])
    board.units.clear()
    rl.enter_from_reserves(board, rl.unit_id(0), board_position(5, 20), rl.MovementKind.ingress())
    return board.reserve_units.empty() and board[0].history.has_ingressed and board[0].history.ingress_locked and board[0].history.was_set_up_this_turn and (not rl.battlefield_move_eligible(board, rl.unit_id(0), rl.MovementKind.normal()))

# p.14: failed ingress/cancel retains the reserve and its previous selection.
def test_movement11_ingress_cancel_then_stationary():
    board = value_copy(movement11_fixture())
    board.reserve_units.append(board[0])
    board.units.clear()
    board.current_round = 0
    phase = value_copy(rl.movement_phase(board))
    phase.select_reserve_unit(board, rl.unit_id(0))
    if phase.can_place_at(board, board_position(5, 20)):
        return False
    phase.skip(board)
    phase.select_reserve_unit(board, rl.unit_id(0))
    phase.reserve_remain_stationary(board)
    phase.end_move(board)
    return phase.is_done() and board.reserve_units.size() == 1 and board.units.empty()

# p.68: repositioning keeps ongoing effects, advance/fall-back flags and stable
# identity while retiring, not compacting, the original battlefield slot.
def test_movement11_reposition_preserves_identity_and_restrictions():
    board = value_copy(movement11_fixture())
    board[0].battle_socked = True
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.advance())
    identity = value_copy(board[0].identity)
    if not rl.reposition_unit(board, rl.unit_id(0)) or not board[0].empty() or (not board[0].retired):
        return False
    rl.enter_from_reserves(board, rl.unit_id(0), board_position(5, 20), rl.MovementKind.ingress())
    return board.units.size() == 1 and board[0].identity == identity and board[0].history.advanced_this_turn and board[0].battle_socked and board[0].history.repositioned and (not board[0].allows_action_start())

# p.69: expire never-arrived reserves at end round 3, exempt repositioned ones,
# and preserve the destroyed roster rather than losing its archive.
def test_movement11_unused_reserve_deadline_and_exemption():
    board = value_copy(movement11_fixture())
    board[0].history.strategic_reserve = True
    board.reserve_units.append(board[0])
    board[0].history.repositioned = True
    board.reserve_units.append(board[0])
    board.current_round = 1
    rl.expire_unused_reserves(board)
    if board.reserve_units.size() != 2:
        return False
    board.current_round = 2
    rl.expire_unused_reserves(board)
    return board.reserve_units.size() == 1 and board.reserve_units[0].history.repositioned and (board.expired_reserves.value.size() == 1) and (board.expired_reserves.value[0].destroyed_models.value.size() == 1)

# p.68: exactly half of configured points is legal; unknown data and
# FORTIFICATIONS cannot be voluntarily placed in strategic reserves.
def test_movement11_strategic_reserve_points_and_fortification():
    board = value_copy(movement11_fixture())
    board.units.clear()
    unit = value_copy(rl.make_infernus_squad())
    board.reserve_units.append(unit)
    board.battle_points_limit = 1000
    board.reserve_units[0].points_known = True
    board.reserve_units[0].points = 500
    if not rl.strategic_reserve_valid(board, False, rl.unit_id(0)):
        return False
    board.reserve_units[0].points = 501
    if rl.strategic_reserve_valid(board, False, rl.unit_id(0)):
        return False
    board.reserve_units[0].points = 500
    board.reserve_units[0][0].keywords.append(rl.Keyword.fortification())
    return not rl.strategic_reserve_valid(board, False, rl.unit_id(0))

# User instruction: Scouts values are uniform, mismatches assert. Test its
# pure validation predicate without intentionally crashing the supported suite.
def test_movement11_scouts_uniform_value_guard():
    board = value_copy(movement11_fixture())
    board[0][0].scout_distances.append(movement11_scout_value(6))
    board[0].models.append(board[0][0])
    if rl.scouts_distance(board[0]) != 6:
        return False
    board[0][1].scout_distances[0] = movement11_scout_value(8)
    if rl.scouts_values_uniform(board[0]):
        return False
    board[0][1].scout_distances.clear()
    return rl.scouts_distance(board[0]) == 0

# p.84: scout setup from reserves must be wholly in own home zone; ordinary
# scout movement also finishes strictly more than 8 horizontally from enemies.
def test_movement11_scout_setup_and_move_distance():
    board = value_copy(movement11_fixture())
    candidate = value_copy(board[0])
    candidate.owned_by_player1 = True
    candidate[0].position = board_position(20, 4)
    if not rl.setup_rules_valid(board, candidate, rl.MovementKind.scout(), False):
        return False
    candidate[0].position = board_position(12, 5)
    return not rl.movement_finish_valid(board, candidate, rl.unit_id(1), rl.MovementKind.scout())

# p.70: closest target ignores Aircraft and permits tied nearest enemy choices.
def test_movement11_surge_closest_and_aircraft():
    board = value_copy(attack_declaration_fixture())
    if not rl.surge_target_valid(board, rl.unit_id(0), rl.unit_id(1)) or rl.surge_target_valid(board, rl.unit_id(0), rl.unit_id(2)):
        return False
    board[1][0].keywords.append(rl.Keyword.aircraft())
    return rl.surge_target_valid(board, rl.unit_id(0), rl.unit_id(2)) and (not rl.surge_target_valid(board, rl.unit_id(0), rl.unit_id(1)))

# p.70: a generic surge is never offered without an actual granting trigger.
def test_movement11_surge_requires_trigger_and_unshocked():
    board = value_copy(movement11_fixture())
    distance = rl.new('StatModifier')
    assign(distance, 3)
    absent = value_copy(rl.surge(board, rl.unit_id(0), distance, False))
    board[0].battle_socked = True
    shocked = value_copy(rl.surge(board, rl.unit_id(0), distance, True))
    return absent.is_done() and shocked.is_done()

# p.70: a reachable engaged endpoint outranks an endpoint that stays away;
# when out of reach, take the closest legal finite-grid endpoint.
def test_movement11_surge_approach_obligations():
    board = value_copy(attack_declaration_fixture())
    board.surge_target = 1
    candidate = value_copy(board[0])
    if rl.surge_goals_valid(board, board[0], candidate, rl.unit_id(0), 3):
        return False
    candidate[0].position = board_position(8, 5)
    if not rl.complete_move_valid(board, board[0], candidate, rl.unit_id(0), rl.MovementKind.surge(), 3):
        return False
    board[1][0].position = board_position(20, 5)
    board[2][0].position = board_position(30, 8)
    candidate[0].position = board_position(8, 5)
    return rl.surge_goals_valid(board, board[0], candidate, rl.unit_id(0), 3)

# p.87: retained dead models cannot supply engagement or coherency neighbours.
def test_movement11_pending_corpses_not_engagement_or_neighbours():
    board = value_copy(movement11_fixture())
    enemy = value_copy(board[0])
    enemy.owned_by_player1 = True
    enemy[0].position = board_position(8, 5)
    enemy[0].state = rl.ModelState.pending_destruction()
    board.units.append(enemy)
    board[0].models.append(board[0][0])
    board[0][1].position = board_position(8, 5)
    board[0][1].state = rl.ModelState.pending_destruction()
    return not board.is_in_melee(board[0]) and board[0].is_coherent()

# Finite source-data fixture constructor for Scouts distances (pp.78/84).
def movement11_scout_value(value):
    result = rl.new('FixedStat')
    assign(result, value)
    return value_copy(result)

# pp.12/14: five 40mm Terminators need a different coherent preset to fit
# the lower deployment zone. Probe and commit must use the same layout.
def test_movement11_setup_searches_valid_preset_and_commits_it():
    board = rl.new('Board')
    unit = value_copy(rl.make_terminator_squad())
    unit.owned_by_player1 = True
    board.reserve_units.append(unit)
    board.identify_units()
    position = value_copy(board_position(5, 1))
    if not rl.setup_at_valid(board, board.reserve_units[0], position, rl.MovementKind.normal(), False):
        return False
    rl.enter_from_reserves(board, rl.unit_id(0), position, rl.MovementKind.normal())
    return board.reserve_units.empty() and rl.unit_in_home_zone(board[0], True) and rl.unit_placement_valid(board, board[0], 0, True)

# p.70: completing a generic out-of-phase move also consumes the phase's
# surge eligibility; the caller need not be the Movement phase action.
def test_movement11_generic_move_blocks_later_surge():
    board = value_copy(attack_declaration_fixture())
    source = value_copy(rl.unit_id(0))
    moved = value_copy(rl.move(board, source, 0))
    moved.move_to(board, source, board_position(6, 5))
    distance = rl.new('StatModifier')
    assign(distance, 3)
    subsequent = value_copy(rl.surge(board, source, distance, True))
    return subsequent.is_done() and board[0].history.last_move_phase == board.phase_serial.value + 1

# p.87: do not strand a pending battlefield trigger by transferring its
# retained model into reserves. The rejected transfer preserves all state.
def test_movement11_reposition_pending_trigger_rejected_atomically():
    board = value_copy(damage_test_fixture())
    board[1][0].state = rl.ModelState.pending_destruction()
    board[1][0].destruction_pending = True
    before = value_copy(rl.to_string(board))
    return not rl.reposition_unit(board, rl.unit_id(1)) and rl.to_string(board) == before

# p.69: ingress is not a shooting/charge prohibition once its next-Charge
# move lock ends; fresh reserve factories must receive valid core gates.
def test_movement11_ingress_allows_shooting_and_later_charge():
    board = value_copy(movement11_fixture())
    reserve = value_copy(rl.make_infernus_squad())
    board.units.clear()
    board.reserve_units.append(reserve)
    rl.enter_from_reserves(board, rl.unit_id(0), board_position(2, 20), rl.MovementKind.ingress())
    return board[0].can_shoot and board[0].can_charge and board[0].history.ingress_locked

# p.68: a repositioned unit retains restrictions in the same turn, but those
# turn-long restrictions expire at its next turn even while still in reserves.
def test_movement11_reserve_new_turn_expires_movement_restrictions():
    board = value_copy(movement11_fixture())
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.advance())
    if not rl.reposition_unit(board, rl.unit_id(0)):
        return False
    board.start_turn_history()
    return not board.reserve_units[0].has_run and (not board.reserve_units[0].history.advanced_this_turn) and board.reserve_units[0].can_shoot and board.reserve_units[0].can_charge

# pp.12/14: one larger bearer plus ten smaller bases has a coherent lower-zone
# preset; conservative uniform spacing must not hide a legal mixed layout.
# This explicit geometry fixture does not grant new-edition attachment rights.
def test_movement11_mixed_base_preset_does_not_over_space():
    board = rl.new('Board')
    unit = value_copy(rl.make_beast_snagga_boyz())
    leader = value_copy(rl.make_beastboss_morgrim())
    unit.models.append(leader[0])
    unit.owned_by_player1 = True
    board.reserve_units.append(unit)
    board.identify_units()
    position = value_copy(board_position(5, 1))
    if not rl.setup_at_valid(board, board.reserve_units[0], position, rl.MovementKind.normal(), False):
        return False
    rl.enter_from_reserves(board, rl.unit_id(0), position, rl.MovementKind.normal())
    return board[0].is_coherent() and rl.unit_in_home_zone(board[0], True) and rl.unit_placement_valid(board, board[0], 0, True)

# pp.12/33/85: walker grants cannot revoke friendly traversal or Desperate
# Escape's independent permission to cross all enemy models, even TITANIC.
def test_movement11_walker_does_not_revoke_other_traversal_permissions():
    board = value_copy(movement11_fixture())
    board[0][0].abilities.append(rl.AbilityKind.super_heavy_walker())
    obstacle = value_copy(board[0])
    obstacle[0].keywords.append(rl.Keyword.titanic())
    obstacle[0].position = board_position(7, 5)
    board.units.append(obstacle)
    path = rl.new('ModelPath')
    path.model = 0
    if not rl.waypoint_valid(board, board[0], path, board_position(11, 5), rl.MovementKind.normal(), 0, -1, False):
        return False
    board[1].owned_by_player1 = True
    return rl.waypoint_valid(board, board[0], path, board_position(11, 5), rl.MovementKind.desperate_escape(), 0, -1, False)

# pp.12/14: the 90mm/75mm row fits between two deployed bases only when
# each adjacent pair gets its own whole-quad clearance (4,3,3 inches).
def test_movement11_mixed_row_fits_gap_between_deployed_models():
    board = rl.new('Board')
    blocker = value_copy(rl.make_infernus_squad())
    blocker.models.resize(1)
    blocker.owned_by_player1 = True
    board.units.append(blocker)
    board.units.append(blocker)
    board[0][0].position = board_position(12, 3)
    board[1][0].position = board_position(27, 3)
    unit = value_copy(rl.make_squighog_boyz())
    unit.owned_by_player1 = True
    board.reserve_units.append(unit)
    board.identify_units()
    position = value_copy(board_position(15, 2))
    if not rl.setup_at_valid(board, board.reserve_units[0], position, rl.MovementKind.normal(), False):
        return False
    rl.enter_from_reserves(board, rl.unit_id(0), position, rl.MovementKind.normal())
    return board[2][3].position.x == 25 and rl.unit_placement_valid(board, board[2], 2, True) and rl.unit_in_home_zone(board[2], True)

# User direction: destroy units with no legal supported deployment. A valid
# unit cannot take that action; rejected setup must not silently become reserves.
def test_movement11_unplaceable_unit_destroyed_and_archived():
    board = rl.new('Board')
    unit = value_copy(rl.make_infernus_squad())
    unit.models.resize(1)
    board.reserve_units.append(unit)
    board.identify_units()
    identity = value_copy(board.reserve_units[0].identity)
    sequence = value_copy(rl.deploy(board))
    sequence.select_unit(board, rl.unit_id(0))
    if sequence.can_destroy_unplaceable_unit(board):
        return False
    board.reserve_units[0][0].geometry.unsupported_footprint = True
    if not sequence.can_destroy_unplaceable_unit(board):
        return False
    sequence.destroy_unplaceable_unit(board)
    return board.reserve_units.empty() and board.expired_reserves.value.size() == 1 and (board.expired_reserves.value[0].identity == identity) and (board.expired_reserves.value[0].destroyed_models.value.size() == 1)

# Task-12 fixtures supply explicit rules, not invented faction datasheets (pp.78–85).
def shooting12_fixture():
    board = value_copy(attack_declaration_fixture())
    board.begin_phase(rl.BattlePhase.shooting())
    board[0].can_shoot = True
    board.command_points[0] = 3
    return value_copy(board)

# pp.34–35: modes depend on engagement and advance, not a single can_shoot flag.
def test_shooting12_mode_eligibility_and_advance_assault():
    board = value_copy(shooting12_fixture())
    if not rl.shooting_kind_valid(board, rl.unit_id(0), rl.ShootingKind.normal()) or rl.shooting_kind_valid(board, rl.unit_id(0), rl.ShootingKind.snap()):
        return False
    board[0].history.advanced_this_turn = True
    if rl.shooting_unit_valid(board, rl.unit_id(0)):
        return False
    board[0][0].additional_weapon_rules[0].append(rl.weapon_rule(rl.WeaponRuleKind.assault()))
    return rl.shooting_kind_valid(board, rl.unit_id(0), rl.ShootingKind.assault()) and (not rl.shooting_kind_valid(board, rl.unit_id(0), rl.ShootingKind.normal())) and (not rl.shooting_kind_valid(board, rl.unit_id(0), rl.ShootingKind.indirect()))

# pp.34/58/88: no ranged weapon still permits selecting; shooting locks action
# starts only until phase end, and the unit cannot select twice in that phase.
def test_shooting12_no_weapon_unit_selection_and_phase_action_lock():
    board = value_copy(shooting12_fixture())
    board[0][0].weapons.clear()
    phase = value_copy(rl.shooting_phase(board))
    phase.select_shooting_unit(board, rl.unit_id(0))
    phase.choose_shooting_kind(board, rl.ShootingKind.normal())
    phase.skip(board)
    if not board[0].has_shoot or board[0].allows_action_start() or phase.can_select_shooting_unit(board, rl.unit_id(0)):
        return False
    board.begin_phase(rl.BattlePhase.charge())
    return board[0].allows_action_start()

# pp.33–35/58/87: fallback/actions/retired units and the wrong owner cannot shoot.
def test_shooting12_source_restrictions():
    board = value_copy(shooting12_fixture())
    if rl.shooting_unit_valid(board, rl.unit_id(1)):
        return False
    board[0].history.fell_back_this_turn = True
    if rl.shooting_unit_valid(board, rl.unit_id(0)):
        return False
    board[0].history.fell_back_this_turn = False
    board[0].history.action_started = True
    if rl.shooting_unit_valid(board, rl.unit_id(0)):
        return False
    board[0].history.action_started = False
    board[0][0].state = rl.ModelState.pending_destruction()
    return not rl.shooting_unit_valid(board, rl.unit_id(0))

# pp.80/83: multiple pistols can be selected; ordinary models cannot mix the
# sidearm categories, while a Monster/Vehicle bearer can select both.
def test_shooting12_pistol_alias_exclusive_categories_and_vehicle_exception():
    board = value_copy(shooting12_fixture())
    board[0][0].weapons.append(rl.Weapon.bolt_pistol())
    board[0][0].weapons.append(rl.Weapon.captain_storm_bolter())
    board[0][0].additional_weapon_rules[2].append(rl.weapon_rule(rl.WeaponRuleKind.close_quarters()))
    sequence = value_copy(rl.attack(board, rl.unit_id(0), rl.unit_id(1), False, False))
    sequence.select_weapon(board, attack_test_slot(1))
    if sequence.can_select_weapon(board, attack_test_slot(0)) or not sequence.can_select_weapon(board, attack_test_slot(2)):
        return False
    sequence.select_weapon(board, attack_test_slot(2))
    if sequence.declarations.size() != 2:
        return False
    board[0][0].keywords.append(rl.Keyword.vehicle())
    return sequence.can_select_weapon(board, attack_test_slot(0))

# pp.35/62–63/88: engaged non-vehicles are prohibited; engaged vehicles are
# targets only in the firing player's Shooting phase, and Blast still fails.
def test_shooting12_engaged_target_vehicle_and_blast_gates():
    board = value_copy(shooting12_fixture())
    friendly = value_copy(board[0])
    friendly[0].position = board_position(11, 5)
    friendly.identity = 0
    friendly[0].identity = 0
    board.units.append(friendly)
    board.identify_units()
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False):
        return False
    board[1][0].keywords.append(rl.Keyword.vehicle())
    if not rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False):
        return False
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), weapon, board.attack_info))
    if info.engaged_hit_penalties != 1:
        return False
    weapon.selected_rules.append(rl.weapon_rule(rl.WeaponRuleKind.blast()))
    if rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False):
        return False
    weapon.selected_rules.clear()
    board.current_player = True
    return not rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False)

# p.35: engaged ordinary bearers use only sidearms against their engaged
# enemies; the Monster/Vehicle bearer has a penalty for other ranged attacks.
def test_shooting12_close_quarters_permissions_and_penalty_exception():
    board = value_copy(shooting12_fixture())
    board[1][0].position = board_position(7, 5)
    board[0].shooting_kind = rl.ShootingKind.close_quarters()
    board[0][0].additional_weapon_rules[0].append(rl.weapon_rule(rl.WeaponRuleKind.close_quarters()))
    if not rl.shooting_kind_valid(board, rl.unit_id(0), rl.ShootingKind.close_quarters()):
        return False
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if not rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False) or rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(2), False):
        return False
    board[0][0].keywords.append(rl.Keyword.monster())
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), weapon, board.attack_info))
    if info.engaged_hit_penalties != 0:
        return False
    weapon.selected_rules.clear()
    weapon.current_target_rules.clear()
    info = rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(2), weapon, board.attack_info)
    return rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(2), False) and info.engaged_hit_penalties == 1

# p.83 / supplied modifier appendix: Lone Operative uses bearer-to-target
# distance; a nearby unit-mate cannot give a distant bearer visibility.
def test_shooting12_lone_operative_per_bearer_and_custom_range():
    board = value_copy(shooting12_fixture())
    board[1][0].abilities.append(rl.AbilityKind.lone_operative())
    board[1][0].position = board_position(20, 5)
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False):
        return False
    nearby = value_copy(board[0][0])
    nearby.position = board_position(10, 5)
    board[0].models.append(nearby)
    if not rl.unit_visible_to_unit(board, board[0], board[1]) or rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False):
        return False
    board[1].lone_operative_range = 15
    return rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False)

# pp.35/50/82–83: indirect permits Hidden targets but still respects per-bearer
# Lone Operative. Cover is forced even when the target is ordinarily visible.
def test_shooting12_indirect_visibility_lone_operative_and_cover():
    board = value_copy(shooting12_fixture())
    board[1][0].position = board_position(27, 5)
    board.terrain_areas.append(terrain_area(26, 4, 28, 6, True))
    board[0][0].additional_weapon_rules[0].append(rl.weapon_rule(rl.WeaponRuleKind.indirect_fire()))
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False):
        return False
    board[0].shooting_kind = rl.ShootingKind.indirect()
    if not rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False):
        return False
    board.terrain_areas.clear()
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), weapon, board.attack_info))
    if not info.target_has_cover:
        return False
    board[1][0].abilities.append(rl.AbilityKind.lone_operative())
    return not rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False)

# p.35: indirect fails natural 1–5, or 1–3 when stationary and a friendly unit
# sees the target. Positive hit modifiers cannot bypass these natural-face gates.
def test_shooting12_indirect_unmodified_faces_and_stationary_tracking():
    board = value_copy(shooting12_fixture())
    board[0].shooting_kind = rl.ShootingKind.indirect()
    board[0][0].additional_weapon_rules[0].append(rl.weapon_rule(rl.WeaponRuleKind.indirect_fire()))
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    board[0].history.made_move_this_turn = True
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), weapon, board.attack_info))
    if not rl.classify_attack_hit(board, info, attack_test_die(5), 10) == rl.AttackRollResult.failed():
        return False
    board[0].history.made_move_this_turn = False
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.stationary())
    info = rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), weapon, board.attack_info)
    if not info.indirect_stationary_visible or not rl.classify_attack_hit(board, info, attack_test_die(3), 10) == rl.AttackRollResult.failed() or (not rl.classify_attack_hit(board, info, attack_test_die(4), 0) == rl.AttackRollResult.success()):
        return False
    board[0][0].history.was_set_up_this_turn = True
    return not rl.stationary_this_turn(board[0])

# pp.35/57: snap and indirect prohibit every hit reroll, including paid CP.
def test_shooting12_snap_hit_rerolls_forbidden_and_single_target():
    board = value_copy(shooting12_fixture())
    board.attack_info.only_hits_on_6 = True
    board.attack_info.reroll_hits = True
    dice = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(1)))
    dice.roll(board, board[1], board[0], attack_test_die(3))
    if not dice.is_done() or dice.generated_hits != 0 or board.command_points[0] != 3:
        return False
    board[0].shooting_kind = rl.ShootingKind.snap()
    board.attack_info.target_unit_id = 1
    board[0].snap_target = 1
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    return rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False) and (not rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(2), False))

# p.35: even an ordinary visible indirect target prohibits hit rerolls.
def test_shooting12_indirect_hit_rerolls_forbidden():
    board = value_copy(shooting12_fixture())
    board.attack_info.shooting_kind = rl.ShootingKind.indirect()
    board.attack_info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.indirect_fire()))
    board.attack_info.reroll_hits = True
    dice = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(1)))
    dice.roll(board, board[1], board[0], attack_test_die(5))
    return dice.is_done() and dice.generated_hits == 0 and (board.command_points[0] == 3)

# p.82: Heavy allows an actual <=3in move, but no setup, engagement, opponent
# turn, or larger movement by any live member, including another model.
def test_shooting12_heavy_complete_conditions():
    board = value_copy(shooting12_fixture())
    board.attack_info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.heavy()))
    board[0].has_moved = True
    board[0][0].history.reset_movement_distance()
    board[0][0].history.record_movement_segment(3, 0, 0)
    if rl.get_hit_roll_bonus(board) != 1:
        return False
    board[0][0].history.reset_movement_distance()
    board[0][0].history.record_movement_segment(3, 1, 0)
    if rl.get_hit_roll_bonus(board) != 0:
        return False
    board[0][0].history.reset_movement_distance()
    board[0].history.was_set_up_this_turn = True
    if rl.get_hit_roll_bonus(board) != 0:
        return False
    board[0].history.was_set_up_this_turn = False
    board.current_player = True
    return rl.get_hit_roll_bonus(board) == 0

# pp.79/84: Blast X and Rapid Fire snapshot target-selection count/range and
# ignore later casualties/reposition; pending corpses are not counted.
def test_shooting12_blast_and_rapid_fire_declaration_snapshots():
    board = value_copy(shooting12_fixture())
    model = value_copy(board[1][0])
    board[1].models.resize(11)
    for i in range(11):
        board[1][i] = model
    board[0][0].additional_weapon_rules[0].append(rl.weapon_rule(rl.WeaponRuleKind.blast(), 2))
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    rl.snapshot_weapon_target(board, rl.unit_id(0), weapon, rl.unit_id(1))
    before = value_copy(rl.gathering_extra_attacks(board, rl.unit_id(0), rl.unit_id(1), weapon))
    board[1].models.resize(1)
    board[1][0].position = board_position(30, 5)
    return before == 6 and rl.gathering_extra_attacks(board, rl.unit_id(0), rl.unit_id(1), weapon) == before

# p.79: Cleave adds X per five models only when a weapon's attacks all target
# one unit; a split must not receive that addition.
def test_shooting12_cleave_unsplit_and_split():
    board = value_copy(shooting12_fixture())
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    weapon.selected_rules.clear()
    weapon.selected_rules.append(rl.weapon_rule(rl.WeaponRuleKind.cleave(), 3))
    weapon.current_target_rules = weapon.selected_rules
    weapon.targeted[1] = True
    weapon.target_model_counts[1] = 12
    if rl.gathering_extra_attacks(board, rl.unit_id(0), rl.unit_id(1), weapon) != 6:
        return False
    weapon.targeted[2] = True
    return rl.gathering_extra_attacks(board, rl.unit_id(0), rl.unit_id(1), weapon) == 0

# p.83: One Shot is spent at Select Weapons, even when attacks are declined.
# The model archive retains slot usage rather than granting a revived weapon.
def test_shooting12_one_shot_selection_and_archive():
    board = value_copy(shooting12_fixture())
    board[0][0].additional_weapon_rules[0].append(rl.weapon_rule(rl.WeaponRuleKind.one_shot()))
    sequence = value_copy(rl.attack(board, rl.unit_id(0), rl.unit_id(1), False, False))
    sequence.select_weapon(board, attack_test_slot(0))
    if not board[0][0].used_once_per_battle_weapon[0]:
        return False
    sequence.skip(board)
    sequence.skip_target(board)
    board[0].remove_model(0)
    revived = value_copy(board[0].destroyed_models.value[0])
    board[0].models.append(revived)
    selected = rl.new('Bool[MAX_WEAPONS]')
    return not rl.weapon_selection_valid(board, rl.unit_id(0), 0, 0, False, selected, False)

# p.78: duplicate numeric abilities are alternatives, not max/sum; different
# ANTI keywords are the same duplicate family and require one selected instance.
def test_shooting12_duplicate_ability_choice_and_anti_family():
    board = value_copy(shooting12_fixture())
    rules = rl.new('WeaponAbilitySet')
    rules.append(rl.weapon_rule(rl.WeaponRuleKind.sustained_hit(), 1))
    rules.append(rl.weapon_rule(rl.WeaponRuleKind.sustained_hit(), 2))
    rules.append(rl.weapon_rule(rl.WeaponRuleKind.anti_monster(), 4))
    rules.append(rl.weapon_rule(rl.WeaponRuleKind.anti_vehichle(), 2))
    choice = value_copy(rl.choose_weapon_abilities(board, rules))
    index = rl.new('WeaponAbilityChoice')
    assign(index, 0)
    choice.choose_weapon_ability(board, index)
    assign(index, 2)
    choice.choose_weapon_ability(board, index)
    return choice.is_done() and choice.chosen.size() == 2 and (choice.chosen[0].parameter == 1) and (choice.chosen[1].kind == rl.WeaponRuleKind.anti_monster())

# pp.78–79: chosen conditional abilities apply to the unit keyword union only.
def test_shooting12_conditional_generic_anti_and_sustained():
    board = value_copy(shooting12_fixture())
    info = value_copy(board.attack_info)
    info.weapon_rules_known = True
    info.selected_weapon_rules.append(rl.conditional_weapon_rule(rl.WeaponRuleKind.anti(), 2, rl.Keyword.vehicle()))
    info.selected_weapon_rules.append(rl.conditional_weapon_rule(rl.WeaponRuleKind.sustained_hit(), 3, rl.Keyword.vehicle()))
    if info.has_weapon_rule(board, rl.WeaponRuleKind.sustained_hit()) or rl.critical_wound_threshold(board, info) != 6:
        return False
    board[1][0].keywords.append(rl.Keyword.vehicle())
    return info.has_weapon_rule(board, rl.WeaponRuleKind.sustained_hit()) and info.max_weapon_parameter(board, rl.WeaponRuleKind.sustained_hit()) == 3 and (rl.critical_wound_threshold(board, info) == 2)

# p.85: Twin-linked is an optional free wound reroll, never a second reroll.
def test_shooting12_twin_linked_wound_reroll():
    board = value_copy(shooting12_fixture())
    board.attack_info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.twin_linked()))
    board.attack_info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.devastating_wounds()))
    board.command_points[0] = 0
    dice = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(1)))
    dice.roll(board, board[1], board[0], attack_test_die(6))
    dice.roll(board, board[1], board[0], attack_test_die(1))
    if not dice.can_select_reroll(board, board[1], board[0], attack_test_die(1)):
        return False
    dice.select_reroll(board, board[1], board[0], attack_test_die(1))
    dice.reroll(board, board[1], board[0], attack_test_die(6))
    return dice.is_done() and dice.generated_critical_wounds == 1 and (board.command_points[0] == 0)

# p.82: decline automatic Lethal wounding to retain a critical wound opportunity.
def test_shooting12_lethal_hits_optional_decline():
    board = value_copy(shooting12_fixture())
    board.attack_info.add_letal_hits()
    board.attack_info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.devastating_wounds()))
    board.command_points[0] = 0
    dice = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(1)))
    dice.roll(board, board[1], board[0], attack_test_die(6))
    dice.use_lethal_hits(board, board[1], board[0], False)
    dice.roll(board, board[1], board[0], attack_test_die(6))
    return dice.is_done() and dice.generated_critical_wounds == 1 and (dice.generated_wounds == 0)

# User lifecycle instruction: preserve generated owning-field initialization;
# ability magnitudes/conditions are bounded and survive save round trips (p.78).
def test_shooting12_bounded_ability_metadata_round_trip():
    state = value_copy(rl.play())
    state.board = shooting12_fixture()
    state.board[0][0].additional_weapon_rules[0].append(rl.conditional_weapon_rule(rl.WeaponRuleKind.sustained_hit(), 2, rl.Keyword.vehicle()))
    restored = value_copy(rl.play())
    if not rl.set_state(restored, rl.to_string(state)):
        return False
    rule = value_copy(restored.board[0][0].additional_weapon_rules[0][0])
    return rule.parameter == 2 and rule.target_condition.size() == 1 and (rl.weapon_ability_condition_keyword(rule, 0) == rl.Keyword.vehicle()) and (restored.board[0][0].weapons.size() == 1)

# p.82: each original critical hit can independently use/decline Lethal Hits.
def test_shooting12_mixed_lethal_hits_choices():
    board = value_copy(shooting12_fixture())
    board.command_points[0] = 0
    board.attack_info.add_letal_hits()
    board.attack_info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.devastating_wounds()))
    dice = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(2)))
    dice.roll(board, board[1], board[0], attack_test_die(6))
    dice.roll(board, board[1], board[0], attack_test_die(6))
    dice.use_lethal_hits(board, board[1], board[0], True)
    dice.use_lethal_hits(board, board[1], board[0], False)
    dice.roll(board, board[1], board[0], attack_test_die(6))
    return dice.is_done() and dice.generated_wounds == 1 and (dice.generated_critical_wounds == 1)

# p.78: granting another duplicate cannot silently override/maximize the
# original choice; each target's original rules remain available separately.
def test_shooting12_new_grant_duplicate_choice_preserves_original():
    board = value_copy(shooting12_fixture())
    board[0][0].additional_weapon_rules[0].append(rl.weapon_rule(rl.WeaponRuleKind.sustained_hit(), 1))
    declarations = rl.new('DeclaredWeapons')
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    weapon.targeted[1] = True
    declarations.append(weapon)
    info = value_copy(board.attack_info)
    info.add_sustained_hits(2)
    sequence = value_copy(rl.prepare_target_weapon_abilities(board, declarations, rl.unit_id(0), rl.unit_id(1), info))
    first_sustained = rl.new('WeaponAbilityChoice')
    assign(first_sustained, 1)
    sequence.choose_weapon_ability(board, declarations, first_sustained)
    return sequence.is_done() and rl.chosen_weapon_parameter(board, rl.unit_id(1), declarations[0].current_target_rules, rl.WeaponRuleKind.sustained_hit()) == 1 and (declarations[0].selected_rules.size() == 2)

# pp.33/57/82: Advance/Fall Back/Lance effects expire before the opposing turn;
# already-selected shooting history is retained until its proper own turn reset.
def test_shooting12_opponent_turn_clears_movement_shooting_restrictions():
    board = value_copy(shooting12_fixture())
    board[0].has_run = True
    board[0].has_charged = True
    board[0].can_shoot = False
    board[0].history.fell_back_this_turn = True
    board[0].has_shoot = True
    board.current_player = True
    board.start_turn_history()
    return not board[0].has_run and (not board[0].has_charged) and board[0].can_shoot and (not board[0].history.fell_back_this_turn) and board[0].has_shoot

# p.81: every Extra Attacks weapon must be selected in the shared fight
# declaration engine; finishing after just the ordinary melee weapon is illegal.
def test_shooting12_extra_attacks_selection_is_mandatory():
    board = value_copy(shooting12_fixture())
    board[0][0].weapons[0] = rl.Weapon.relic_weapon()
    board[0][0].weapons.append(rl.Weapon.force_weapon())
    board[0][0].additional_weapon_rules[1].append(rl.weapon_rule(rl.WeaponRuleKind.extra_attacks()))
    declarations = rl.new('DeclaredWeapons')
    sequence = value_copy(rl.declare_model_weapons(board, declarations, rl.unit_id(0), damage_test_model(0), True))
    sequence.select_weapon(board, declarations, attack_test_slot(0))
    if sequence.can_skip(board, declarations):
        return False
    sequence.select_weapon(board, declarations, attack_test_slot(1))
    return sequence.can_skip(board, declarations)

# pp.9/87: a nearer retained corpse cannot extend a ranged weapon's reach.
def test_shooting12_range_ignores_nearer_retained_corpses():
    board = value_copy(shooting12_fixture())
    corpse = value_copy(board[1][0])
    corpse.position = board_position(10, 5)
    corpse.state = rl.ModelState.pending_destruction()
    board[1].models.append(corpse)
    board[1][0].position = board_position(35, 5)
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    return rl.live_distance_to_model(board[1], board[0][0]) > 24.0 and (not rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False))

# pp.57 / supplied appendix 04.03.03: a vanished Snap target can be replaced,
# retaining a single shared visible target for the remaining declarations.
def test_shooting12_snap_ineligible_target_replacement():
    board = value_copy(shooting12_fixture())
    board[0].shooting_kind = rl.ShootingKind.snap()
    board[0].snap_target = 1
    declarations = rl.new('DeclaredWeapons')
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    weapon.targeted[1] = True
    declarations.append(weapon)
    board[1].models.clear()
    correction = value_copy(rl.revalidate_attack_targets(board, declarations, rl.unit_id(0), False))
    if not correction.can_retarget_weapon(board, declarations, rl.unit_id(0), rl.unit_id(2)):
        return False
    correction.retarget_weapon(board, declarations, rl.unit_id(0), rl.unit_id(2))
    return correction.is_done() and board[0].snap_target.get() == 2 and declarations[0].targeted[2] and rl.declaration_target_valid(board, rl.unit_id(0), declarations[0], rl.unit_id(2), False)

# p.82 / modifier appendix: Lance's +1 and a -1 wound effect cancel before the cap.
def test_shooting12_lance_modifiers_cumulative_before_cap():
    board = value_copy(shooting12_fixture())
    board.attack_info.temporary_weapon_abilities.append(rl.weapon_rule(rl.WeaponRuleKind.lance()))
    board.attack_info.wound_roll_malus = True
    board[0].has_charged = True
    return rl.required_wound_roll(board, board.attack_info) == rl.base_wound_threshold(board.attack_info.source.strenght(), board.attack_info.target_toughness.value)

# p.78: INFANTRY/BEASTS is one OR condition, not two accumulating instances.
def test_shooting12_conditional_keyword_alternatives():
    board = value_copy(shooting12_fixture())
    info = value_copy(board.attack_info)
    info.weapon_rules_known = True
    info.selected_weapon_rules.append(rl.conditional_weapon_rule(rl.WeaponRuleKind.sustained_hit(), 2, rl.Keyword.monster(), rl.Keyword.beasts()))
    if info.has_weapon_rule(board, rl.WeaponRuleKind.sustained_hit()):
        return False
    board[1][0].keywords.append(rl.Keyword.beasts())
    return info.has_weapon_rule(board, rl.WeaponRuleKind.sustained_hit()) and info.max_weapon_parameter(board, rl.WeaponRuleKind.sustained_hit()) == 2

# pp.14/84: early anchor rejection is necessary-only; full layout checks remain
# required, and search staging must not move the original or consume weapon data.
def test_shooting12_deployment_prefilter_and_search_preserve_source():
    board = value_copy(shooting12_fixture())
    unit = value_copy(board[0])
    unit[0].additional_weapon_rules[0].append(rl.conditional_weapon_rule(rl.WeaponRuleKind.sustained_hit(), 1, rl.Keyword.monster(), rl.Keyword.vehicle()))
    original = value_copy(rl.to_string(unit))
    result = value_copy(rl.deployment_has_position(board, unit))
    unchanged = value_copy(rl.to_string(unit) == original)
    return result and unchanged and (not rl.setup_at_valid(board, unit, board_position(5, 5), rl.MovementKind.normal(), False)) and rl.setup_anchor_possible(unit, board_position(5, 5), rl.MovementKind.normal(), True)

# p.14 and appendix01.02.04: offboard status must not mask collisions in
# prospective deployment search; a fully blocked home zone is unplaceable.
def test_transport16_deployment_search_checks_offboard_geometry():
    board = rl.new('Board')
    unit = value_copy(rl.make_infernus_squad())
    unit.models.resize(1)
    unit.owned_by_player1 = True
    rl.mark_unit_offboard(unit, True)
    # Occupy every interior home-zone quad with a battlefield base. A stored
    # offboard flag would incorrectly make every overlap check return false.
    for home_row in range(4):
        for half_row in range(2):
            blockers = rl.new('Unit')
            for column in range(22 - half_row):
                blocker = rl.new('Model')
                blocker.profile = rl.Profile.infernus_squad()
                blocker.position = board_position(1 + half_row * 22 + column, home_row + 1)
                blockers.models.append(blocker)
            board.units.append(blockers)
    return not rl.deployment_has_position(board, unit) and unit.off_battlefield

# p.85: Torrent produces ordinary automatic hits, no hit dice or critical-hit
# Lethal/Sustained effects, even during Snap Shooting; wound rolls still occur.
def test_shooting12_torrent_automatic_hits_without_critical_effects():
    board = value_copy(shooting12_fixture())
    board.attack_info.source = rl.Weapon.pyreblaster()
    board.attack_info.only_hits_on_6 = True
    board.attack_info.add_letal_hits()
    board.attack_info.add_sustained_hits(2)
    board.command_points[0] = 0
    dice = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(2)))
    if dice.generated_hits != 2 or dice.generated_wounds != 0 or board.current_state.value != rl.CurrentStateDescription.wound_roll().value:
        return False
    dice.roll(board, board[1], board[0], attack_test_die(1))
    dice.roll(board, board[1], board[0], attack_test_die(1))
    return dice.is_done() and dice.generated_wounds == 0

# Supplied appendix 04.01.03: profiles are exclusive per weapon, not per unit.
def test_shooting12_physical_profiles_and_shared_one_shot():
    board = value_copy(shooting12_fixture())
    board[0][0].weapons.append(board[0][0].weapons[0])
    board[0][0].weapon_profile_groups[0] = 1
    board[0][0].weapon_profile_groups[1] = 1
    selected = rl.new('Bool[MAX_WEAPONS]')
    selected[0] = True
    if rl.weapon_selection_valid(board, rl.unit_id(0), 0, 1, False, selected, False):
        return False
    selected[0] = False
    if not rl.weapon_selection_valid(board, rl.unit_id(0), 0, 1, False, selected, False):
        return False
    rl.consume_one_shot_profile(board[0][0], 0)
    return board[0][0].used_once_per_battle_weapon[1] and (not rl.weapon_selection_valid(board, rl.unit_id(0), 0, 1, False, selected, False))

# Supplied appendix 04.01.03: Hunter target restrictions survive snapshots.
def test_shooting12_hunter_profile_target_keywords():
    board = value_copy(shooting12_fixture())
    board[0][0].hunter_profile_conditions[0] = rl.conditional_weapon_rule(rl.WeaponRuleKind.anti(), 0, rl.Keyword.monster())
    weapon = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False):
        return False
    board[1][0].keywords.append(rl.Keyword.monster())
    return rl.declaration_target_valid(board, rl.unit_id(0), weapon, rl.unit_id(1), False)

# Legacy datasheet fixtures encode paired plasma profiles of one weapon.
def test_shooting12_legacy_plasma_profile_groups():
    legionaries = value_copy(rl.make_legionaries())
    hellblasters = value_copy(rl.make_hellblaster_squad())
    return legionaries[0].weapon_profile_groups[0].value == 1 and legionaries[0].weapon_profile_groups[1].value == 1 and (legionaries[1].weapon_profile_groups[0].value == 0) and (hellblasters[0].weapon_profile_groups[1].value == 1) and (hellblasters[0].weapon_profile_groups[2].value == 1)

# pp.17/78/83: spelling aliases require one duplicate choice and cannot split
# identical attacks, while the selected instance retains its target condition.
def test_shooting12_sidearm_alias_duplicates_and_attack_grouping():
    board = value_copy(shooting12_fixture())
    rules = rl.new('WeaponAbilitySet')
    rules.append(rl.weapon_rule(rl.WeaponRuleKind.pistol()))
    rules.append(rl.conditional_weapon_rule(rl.WeaponRuleKind.close_quarters(), 0, rl.Keyword.vehicle()))
    choice = value_copy(rl.choose_weapon_abilities(board, rules))
    if choice.is_done():
        return False
    index = rl.new('WeaponAbilityChoice')
    assign(index, 1)
    choice.choose_weapon_ability(board, index)
    if not choice.is_done() or choice.chosen.size() != 1 or rl.chosen_weapon_has_rule(board, rl.unit_id(1), choice.chosen, rl.WeaponRuleKind.close_quarters()):
        return False
    board[1][0].keywords.append(rl.Keyword.vehicle())
    if not rl.chosen_weapon_has_rule(board, rl.unit_id(1), choice.chosen, rl.WeaponRuleKind.close_quarters()):
        return False
    left = value_copy(board.attack_info)
    left.weapon_rules_known = True
    left.selected_weapon_rules.append(rl.weapon_rule(rl.WeaponRuleKind.pistol()))
    right = value_copy(left)
    right.selected_weapon_rules.clear()
    right.selected_weapon_rules.append(rl.weapon_rule(rl.WeaponRuleKind.close_quarters()))
    if not rl.attacks_are_identical(board, left, right):
        return False
    right.selected_weapon_rules.clear()
    return not rl.attacks_are_identical(board, left, right)

# User-requested minimal coordinate choices, preserving the existing 44x30
# grid and x/y editor payload; zero-edge centres never fit a positive base.
def test_geometry_action_positions_enumerate_only_interior_quads():
    position = rl.new('BoardPosition')
    candidates = value_copy(rl.enumerate(position))
    valid = value_copy(candidates.size() == (rl.BOARD_WIDTH - 1) * (rl.BOARD_HEIGHT - 1))
    for i in range(candidates.size()):
        valid = valid and candidates[i].x.value == 1 + i // (rl.BOARD_HEIGHT - 1) and (candidates[i].y.value == 1 + i % (rl.BOARD_HEIGHT - 1))
    return valid

# User numeric-storage requirement: generated defaults retain the zero sentinel
# and bounded metadata is visible to the standard ML layout, not ignored Ints.
def test_storage_bounded_metadata_defaults_and_observation_layout():
    identity = rl.new('EntityIdentity')
    history = rl.new('UnitHistory')
    schema = rl.new('StateSchema')
    return identity.value == 0 and history.last_move_phase == 0 and (history.selected_move_phase == 0) and (history.last_ranged_attack_turn == 0) and (history.move_kind == rl.MovementKind.stationary()) and (not history.shot_this_phase) and (schema.value == rl.STATE_SCHEMA_VERSION) and (rl.size_as_observation_tensor(identity) == 1) and (rl.size_as_observation_tensor(history.last_move_phase) == 1)

# p.12 / user requirement: path positions stay in quads; two diagonal segments
# retain their exact float length across a save without a persisted float total.
def test_storage_integer_segments_preserve_diagonal_path_and_save():
    board = value_copy(geometry_fixture())
    path = value_copy(geometry_path(0, 6, 6, 0))
    path.append_point(rl.geometry_point(7 * rl.MICROMETRES_PER_INCH, 7 * rl.MICROMETRES_PER_INCH, 0))
    if path.points[0].x.value != 6 or path.points[0].y.value != 6:
        return False
    paths = rl.new('Vector<ModelPath>')
    paths.append(path)
    policy = rl.new('MovementGeometryPolicy')
    success = value_copy(rl.try_move_models(board, rl.unit_id(0), paths, 0, policy, True))
    history = value_copy(board[0][0].history)
    restored = rl.new('ModelHistory')
    parsed = value_copy(rl.from_string(restored, rl.to_string(history)))
    error = value_copy(restored.distance_moved_this_turn() - 2.0 * rl.sqrt(2.0))
    valid = value_copy(success and parsed and (restored.horizontal_segments.size() == 2) and (error < 1e-09) and (error > -1e-09))
    restored.record_movement_segment(1, 0, 0)
    valid = valid and restored.distance_moved_this_turn() > 3.0
    restored.reset_movement_distance()
    return valid and restored.distance_moved_this_turn() == 0.0 and restored.horizontal_segments.empty()

# Metadata/history upper bounds cannot be bypassed by a malformed saved value.
def test_storage_rejects_out_of_range_serials_and_movement_history():
    state = value_copy(rl.play())
    state.board = geometry_fixture()
    state.board.identify_units()
    invalid = value_copy(state)
    invalid.board.phase_serial.value = rl.MAX_PHASE_SERIAL
    valid = value_copy(not rl.set_state(state, rl.to_string(invalid)))
    invalid = value_copy(state)
    invalid.board[0][0].history.vertical_distance.value = rl.MAX_VERTICAL_DISTANCE
    valid = valid and (not rl.set_state(state, rl.to_string(invalid)))
    invalid = value_copy(state)
    invalid.board[0].history.last_ranged_attack_turn.value = rl.MAX_TURN_STAMP
    return valid and (not rl.set_state(state, rl.to_string(invalid))) and (state.board.phase_serial == 0)

# Core pp.36–37 fixture: one living circular-base model per army, 8 inches
# centre separation; IDs/permissions are explicit rather than default data.
def charge13_fixture():
    board = value_copy(geometry_fixture())
    enemy = value_copy(board[0])
    enemy.owned_by_player1 = True
    enemy[0].position = board_position(13, 5)
    board.units.append(enemy)
    board[0].can_charge = True
    board[1].can_charge = True
    board.command_points[0] = 3
    board.command_points[1] = 3
    board.identify_unit(board[0])
    board.identify_unit(board[1])
    return value_copy(board)

# p.36: select a friendly unit, not a target, before neutral chance input.
def test_charge13_declaration_precedes_targets():
    board = value_copy(charge13_fixture())
    phase = value_copy(rl.charge_phase(board))
    if not phase.can_select_charging_unit(board, rl.unit_id(0)) or phase.can_select_charging_unit(board, rl.unit_id(1)):
        return False
    phase.select_charging_unit(board, rl.unit_id(0))
    four = rl.new('Dice')
    assign(four, 4)
    return phase.can_roll_pair(board, four, four) and (not phase.can_select_charge_target(board, rl.unit_id(1))) and (not board[0].has_charged) and (board[0].history.declared_charge_phase == board.phase_serial.value + 1)

# p.36: engagement, Advance, Fall Back and once-per-phase declaration gates.
def test_charge13_source_prohibitions():
    board = value_copy(charge13_fixture())
    if not rl.charge_source_valid(board, rl.unit_id(0), False):
        return False
    board[0].history.advanced_this_turn = True
    if rl.charge_source_valid(board, rl.unit_id(0), False):
        return False
    board[0].history.advanced_this_turn = False
    board[0].history.fell_back_this_turn = True
    if rl.charge_source_valid(board, rl.unit_id(0), False):
        return False
    board[0].history.fell_back_this_turn = False
    board[1][0].position.x = 8
    return not rl.charge_source_valid(board, rl.unit_id(0), False) and (not rl.charge_source_valid(board, rl.unit_id(31), False))

# p.36: proximity is <=12 inches base to base, never centre/anchor only.
def test_charge13_twelve_inch_declaration_range():
    board = value_copy(charge13_fixture())
    board[1][0].position.x = 18
    if not rl.charge_source_valid(board, rl.unit_id(0), False):
        return False
    board[1][0].position.x = 19
    return not rl.charge_source_valid(board, rl.unit_id(0), False)

# p.36: failed double one leaves position/history distance untouched and
# cannot grant Fights First/Lance or be declared again in the same phase.
def test_charge13_failed_attempt_no_success_flags():
    board = value_copy(charge13_fixture())
    phase = value_copy(rl.charge_phase(board))
    phase.select_charging_unit(board, rl.unit_id(0))
    one = rl.new('Dice')
    assign(one, 1)
    phase.roll_pair(board, one, one)
    phase.keep_it(board, True)
    if phase.can_select_charge_target(board, rl.unit_id(1)):
        return False
    phase.cancel_charge(board)
    return not board[0].has_charged and board[0].history.charge_move_phase == 0 and (board[0][0].position.x == 5) and (board[0][0].history.distance_moved_this_turn() == 0.0) and (not phase.can_select_charging_unit(board, rl.unit_id(0))) and phase.can_end_charge(board)

# p.37: being able to reach engagement is insufficient if target is beyond
# the roll's full range. Selection is after the roll, not before.
def test_charge13_post_roll_full_target_range():
    board = value_copy(charge13_fixture())
    board[1][0].position.x = 14
    sequence = value_copy(rl.charge(board, rl.unit_id(0), rl.ChargeKind.ordinary()))
    three = rl.new('Dice')
    four = rl.new('Dice')
    assign(three, 3)
    assign(four, 4)
    sequence.roll_pair(board, three, four)
    sequence.keep_it(board, True)
    return not sequence.can_select_charge_target(board, rl.unit_id(1)) and (not sequence.can_finish_charge_targets(board)) and sequence.can_cancel_charge(board)

# pp.9/36/56: reroll both dice once; target range uses the replacement total.
def test_charge13_pair_reroll_replacement_targets():
    board = value_copy(charge13_fixture())
    sequence = value_copy(rl.charge(board, rl.unit_id(0), rl.ChargeKind.ordinary()))
    one = rl.new('Dice')
    four = rl.new('Dice')
    assign(one, 1)
    assign(four, 4)
    sequence.roll_pair(board, one, one)
    sequence.keep_it(board, False)
    sequence.reroll_pair(board, four, four)
    return board.command_points[0] == 2 and sequence.can_select_charge_target(board, rl.unit_id(1)) and (not sequence.can_reroll_pair(board, four, four))

# p.37: selecting the same enemy twice is illegal; multiple distinct targets
# remain selectable, and moving begins only after explicit finalization.
def test_charge13_multi_target_selection():
    board = value_copy(charge13_fixture())
    other = value_copy(board[1])
    other[0].position = board_position(13, 8)
    board.units.append(other)
    sequence = value_copy(rl.charge(board, rl.unit_id(0), rl.ChargeKind.ordinary()))
    six = rl.new('Dice')
    assign(six, 6)
    sequence.roll_pair(board, six, six)
    sequence.keep_it(board, True)
    sequence.select_charge_target(board, rl.unit_id(1))
    if sequence.can_select_charge_target(board, rl.unit_id(1)):
        return False
    sequence.select_charge_target(board, rl.unit_id(2))
    return sequence.target_count == 2 and sequence.can_finish_charge_targets(board) and (not sequence.can_charge_move_to(board, board_position(11, 5)))

# p.37: cancellation after target selection commits no staged positions.
def test_charge13_cancel_movement_is_atomic():
    board = value_copy(charge13_fixture())
    sequence = value_copy(rl.charge(board, rl.unit_id(0), rl.ChargeKind.ordinary()))
    four = rl.new('Dice')
    assign(four, 4)
    sequence.roll_pair(board, four, four)
    sequence.keep_it(board, True)
    sequence.select_charge_target(board, rl.unit_id(1))
    sequence.finish_charge_targets(board)
    model = rl.new('ModelID')
    assign(model, 0)
    sequence.select_charging_model(board, model)
    sequence.charge_waypoint(board, board_position(11, 5))
    sequence.finish_charge_model(board)
    sequence.cancel_charge(board)
    return sequence.is_done() and board[0][0].position.x == 5 and (not board[0].has_charged) and (board[0][0].history.distance_moved_this_turn() == 0.0) and (not rl.charge_source_valid(board, rl.unit_id(0), False))

# p.37: a completed move, even beyond M, grants charge-only history and the
# legacy Fights First consumer/Lance, and restores the caller's input context.
def test_charge13_success_uses_roll_not_m():
    board = value_copy(charge13_fixture())
    board[1][0].position.x = 14
    sequence = value_copy(rl.charge(board, rl.unit_id(0), rl.ChargeKind.ordinary()))
    four = rl.new('Dice')
    assign(four, 4)
    sequence.roll_pair(board, four, four)
    sequence.keep_it(board, True)
    sequence.select_charge_target(board, rl.unit_id(1))
    sequence.finish_charge_targets(board)
    if not sequence.can_charge_move_to(board, board_position(12, 5)):
        return False
    sequence.charge_move_to(board, board_position(12, 5))
    return sequence.is_done() and board[0].has_charged and (board[0].history.charge_move_phase == board.phase_serial.value + 1) and (board[0].history.declared_charge_phase == board.phase_serial.value + 1) and (board[0][0].history.distance_moved_this_turn() == 7.0) and (not rl.charge_source_valid(board, rl.unit_id(0), False))

# p.37: an engaged endpoint is illegal if a legal within-1 endpoint exists.
def test_charge13_within_one_obligation():
    board = value_copy(charge13_fixture())
    targets = rl.new('Bool[MAX_UNIT_COUNT]')
    targets[1] = True
    return not rl.charge_translate_valid(board, board[0], rl.unit_id(0), board_position(10, 5), targets, 8, False) and rl.charge_translate_valid(board, board[0], rl.unit_id(0), board_position(11, 5), targets, 8, False) and (board[0][0].position.x == 5)

# p.37: never incidentally engage an unselected enemy at the final endpoint.
def test_charge13_incidental_enemy_rejected():
    board = value_copy(charge13_fixture())
    other = value_copy(board[1])
    other[0].position = board_position(11, 7)
    board.units.append(other)
    targets = rl.new('Bool[MAX_UNIT_COUNT]')
    targets[1] = True
    return not rl.charge_translate_valid(board, board[0], rl.unit_id(0), board_position(11, 5), targets, 8, False)

# p.37: every selected target must be engaged by the complete final unit.
def test_charge13_all_selected_targets_engaged():
    board = value_copy(charge13_fixture())
    other = value_copy(board[1])
    other[0].position = board_position(13, 10)
    board.units.append(other)
    targets = rl.new('Bool[MAX_UNIT_COUNT]')
    targets[1] = True
    targets[2] = True
    return not rl.charge_translate_valid(board, board[0], rl.unit_id(0), board_position(11, 5), targets, 12, False)

# p.37: each model must become closer to the nearest base of some target,
# not merely closer to a distant model while moving away from the unit.
def test_charge13_closer_uses_nearest_target_base():
    board = value_copy(charge13_fixture())
    far = value_copy(board[1][0])
    far.position = board_position(5, 20)
    board[1].models.append(far)
    finish = value_copy(board[0][0])
    finish.position = board_position(4, 6)
    targets = rl.new('Bool[MAX_UNIT_COUNT]')
    targets[1] = True
    return not rl.charge_model_closer(board, board[0][0], finish, targets)

# pp.12/37: full base sweep and complete path distance cannot be bypassed by
# several individually short waypoints; failed probes leave shared state alone.
def test_charge13_waypoint_total_and_collision():
    board = value_copy(charge13_fixture())
    path = rl.new('ModelPath')
    path.model = 0
    if rl.charge_waypoint_valid(board, board[0], path, board_position(14, 5), 12, False):
        return False
    path.append_point(rl.geometry_point(8 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 0))
    path.append_point(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH, 5 * rl.MICROMETRES_PER_INCH, 0))
    return not rl.charge_waypoint_valid(board, board[0], path, board_position(8, 5), 8, False) and board[0][0].position.x == 5

# Appendix 02.02.01 and pp.57/71/82: ordered modifiers, 12/6 caps and
# whole-unit flight reduction; Hover exempts that reduction.
def test_charge13_modifiers_mode_caps_and_hover():
    board = value_copy(charge13_fixture())
    board[0].phase_modifiers.charge_roll.append(rl.rule_modifier(rl.ModifierOperation.add(), 20))
    if rl.charge_distance(board[0], 2, rl.ChargeKind.ordinary(), False) != 12 or rl.charge_distance(board[0], 2, rl.ChargeKind.into_the_fray(), False) != 6 or rl.charge_distance(board[0], 2, rl.ChargeKind.ordinary(), True) != 10:
        return False
    board[0][0].abilities.append(rl.AbilityKind.hover())
    return rl.charge_distance(board[0], 2, rl.ChargeKind.ordinary(), True) == 12

# p.71: traversal belongs only to FLY bearers when flight is chosen; grounded
# charge paths cannot cross enemies, and shared maximum distance remains capped.
def test_charge13_flying_traversal_only_when_chosen():
    board = value_copy(charge13_fixture())
    board[0][0].keywords.append(rl.Keyword.fly())
    path = rl.new('ModelPath')
    path.model = 0
    return rl.charge_waypoint_valid(board, board[0], path, board_position(14, 5), 10, True) and (not rl.charge_waypoint_valid(board, board[0], path, board_position(14, 5), 10, False))

# p.57: Leap to Defend requires actual movement this phase, not a declaration
# or a successful charge from an earlier phase. Fray permits non-chargers.
def test_charge13_heroic_target_modes():
    board = value_copy(charge13_fixture())
    board[1][0].position.x = 11
    board[1].has_charged = True
    if rl.charge_target_valid(board, rl.unit_id(0), rl.unit_id(1), 12, rl.ChargeKind.leap_to_defend()):
        return False
    board[1].history.charge_move_phase = board.phase_serial.value + 1
    if not rl.charge_target_valid(board, rl.unit_id(0), rl.unit_id(1), 12, rl.ChargeKind.leap_to_defend()) or not rl.charge_target_valid(board, rl.unit_id(0), rl.unit_id(1), 6, rl.ChargeKind.into_the_fray()):
        return False
    board[1][0].position.x = 13
    return not rl.charge_target_valid(board, rl.unit_id(0), rl.unit_id(1), 12, rl.ChargeKind.into_the_fray())

# p.57: Into the Fray costs one additional CP and is chosen before rolling;
# failed/cancelled charge retains the committed expenditure and targeting limit.
def test_charge13_heroic_fray_cost_before_roll():
    board = value_copy(charge13_fixture())
    board[1][0].position.x = 11
    board.current_player = True
    sequence = value_copy(rl.timing_heroic_intervention(board, False))
    sequence.select_intervening_unit(board, rl.unit_id(0))
    if sequence.can_choose_intervention_mode(board, rl.ChargeKind.leap_to_defend()):
        return False
    sequence.choose_intervention_mode(board, rl.ChargeKind.into_the_fray())
    if board.command_points[0] != 1 or not board.has_used_strat(rl.Stratagem.heroic_intervention(), 0):
        return False
    six = rl.new('Dice')
    assign(six, 6)
    sequence.roll_pair(board, six, six)
    sequence.cancel_charge(board)
    return sequence.is_done() and board.command_points[0] == 1 and (not board[0].has_charged) and (not rl.heroic_source_valid(board, False, rl.unit_id(0)))

# p.57: VEHICLE intervention sources require CHARACTER or WALKER, and
# insufficient CP cannot open an unusable mode decision.
def test_charge13_heroic_source_cost_and_vehicle():
    board = value_copy(charge13_fixture())
    board[1][0].position.x = 11
    board[0][0].keywords.append(rl.Keyword.vehicle())
    if rl.heroic_source_valid(board, False, rl.unit_id(0)):
        return False
    board[0][0].keywords.append(rl.Keyword.walker())
    if not rl.heroic_source_valid(board, False, rl.unit_id(0)):
        return False
    board.command_points[0] = 1
    return not rl.heroic_source_valid(board, False, rl.unit_id(0))

# pp.36–37/82: Lance uses only completed moves, and charge-only Fights First
# expires at either player's turn boundary; an old declaration is phase-local.
def test_charge13_success_expires_at_turn_boundary():
    board = value_copy(charge13_fixture())
    rl.record_charge_move(board, rl.unit_id(0))
    board[0].history.declared_charge_phase = board.phase_serial.value + 1
    board.start_turn_history()
    board.begin_phase(rl.BattlePhase.charge())
    return not board[0].has_charged and rl.charge_source_valid(board, rl.unit_id(0), False) and (board[0].history.charge_move_phase != board.phase_serial.value + 1)

# p.36 infrastructure: declaration and successful-move stamps are bounded
# save metadata; malformed stamps must not bypass once-per-phase eligibility.
def test_charge13_malformed_stamp_rejected():
    state = value_copy(rl.play())
    state.board.units.append(charge13_fixture()[0])
    state.board.identify_unit(state.board[0])
    state.board[0].history.declared_charge_phase.value = rl.MAX_PHASE_STAMP
    text = value_copy(rl.to_string(state))
    restored = value_copy(rl.play())
    return not rl.set_state(restored, text)

# pp.12/37: the same charge may engage several declared units when its final
# bases meet all targets and the per-model approach obligations.
def test_charge13_multiple_targets_success():
    board = value_copy(charge13_fixture())
    board[1][0].position.y = 4
    other = value_copy(board[1])
    other[0].position.y = 6
    board.units.append(other)
    targets = rl.new('Bool[MAX_UNIT_COUNT]')
    targets[1] = True
    targets[2] = True
    return rl.charge_translate_valid(board, board[0], rl.unit_id(0), board_position(11, 5), targets, 8, False)

# pp.12/37: independent paths can detour around an unselected enemy; accepted
# waypoints stage privately, and final charge history records the whole route.
def test_charge13_independent_detour_commits_whole_path():
    board = value_copy(charge13_fixture())
    board[1][0].position.x = 15
    obstacle = value_copy(board[1])
    obstacle[0].position.x = 9
    board.units.append(obstacle)
    sequence = value_copy(rl.charge(board, rl.unit_id(0), rl.ChargeKind.ordinary()))
    five = rl.new('Dice')
    assign(five, 5)
    sequence.roll_pair(board, five, five)
    sequence.keep_it(board, True)
    sequence.select_charge_target(board, rl.unit_id(1))
    sequence.finish_charge_targets(board)
    model = rl.new('ModelID')
    assign(model, 0)
    sequence.select_charging_model(board, model)
    sequence.charge_waypoint(board, board_position(8, 3))
    sequence.charge_waypoint(board, board_position(12, 3))
    sequence.charge_waypoint(board, board_position(13, 5))
    sequence.finish_charge_model(board)
    if board[0][0].position.x != 5 or not sequence.can_finish_charge_move(board):
        return False
    sequence.finish_charge_move(board)
    distance = value_copy(board[0][0].history.distance_moved_this_turn())
    return board[0].has_charged and board[0][0].position.x == 13 and (distance > 9.8) and (distance < 10.0) and (not board[0].is_engaged_with(board[2]))

# p.37: the within-1 obligation includes reachable detours, not only clear
# straight-line approaches; legality probing restores the staged endpoint.
def test_charge13_reachable_detour_goal_required():
    board = value_copy(charge13_fixture())
    board[1][0].position.x = 15
    obstacle = value_copy(board[1])
    obstacle[0].position.x = 9
    board.units.append(obstacle)
    candidate = value_copy(board[0])
    candidate[0].position.x = 12
    targets = rl.new('Bool[MAX_UNIT_COUNT]')
    targets[1] = True
    return not rl.charge_finish_valid(board, board[0], candidate, rl.unit_id(0), targets, 10, False) and candidate[0].position.x == 12 and (board[0][0].position.x == 5)

# pp.12/37: coherent placement alone is insufficient if a model moves away
# from every selected target; all live models have their own obligation.
def test_charge13_every_model_must_approach():
    board = value_copy(charge13_fixture())
    board[0][0].position = board_position(9, 5)
    extra = value_copy(board[0][0])
    extra.position = board_position(10, 7)
    board[0].models.append(extra)
    candidate = value_copy(board[0])
    candidate[0].position = board_position(11, 5)
    candidate[1].position = board_position(10, 8)
    targets = rl.new('Bool[MAX_UNIT_COUNT]')
    targets[1] = True
    return rl.charge_source_valid(board, rl.unit_id(0), False) and rl.charge_placement_valid(board, candidate, rl.unit_id(0), targets) and (not rl.charge_finish_valid(board, board[0], candidate, rl.unit_id(0), targets, 8, False))

# p.36: on-battlefield membership/eligibility is necessary even when a
# low-level constructor is invoked directly; invalid construction changes nothing.
def test_charge13_invalid_source_constructor_no_effect():
    board = value_copy(charge13_fixture())
    board[0].history.advanced_this_turn = True
    sequence = value_copy(rl.charge(board, rl.unit_id(0), rl.ChargeKind.ordinary()))
    return sequence.is_done() and board[0].history.declared_charge_phase == 0 and (not board[0].has_charged)

# p.36 infrastructure: cancellation consumes the declaration, but source,
# target and independent-path state survive a serialized pending charge.
def test_charge13_pending_path_round_trip():
    board = value_copy(charge13_fixture())
    sequence = value_copy(rl.charge(board, rl.unit_id(0), rl.ChargeKind.ordinary()))
    four = rl.new('Dice')
    assign(four, 4)
    sequence.roll_pair(board, four, four)
    sequence.keep_it(board, True)
    sequence.select_charge_target(board, rl.unit_id(1))
    sequence.finish_charge_targets(board)
    model = rl.new('ModelID')
    assign(model, 0)
    sequence.select_charging_model(board, model)
    sequence.charge_waypoint(board, board_position(11, 5))
    serialized = value_copy(rl.to_string(sequence))
    restored = rl.new('Charge')
    index = value_copy(0)
    if not rl.from_string(restored, serialized, index):
        return False
    restored.finish_charge_model(board)
    restored.finish_charge_move(board)
    return restored.is_done() and board[0].has_charged and (board[0][0].position.x == 11)

# p.85: Super-heavy Walker's Normal/Advance/Fall Back traversal exception
# cannot leak into charges merely because their paths share geometry helpers.
def test_charge13_super_heavy_walker_cannot_cross_enemy():
    board = value_copy(charge13_fixture())
    board[0][0].abilities.append(rl.AbilityKind.super_heavy_walker())
    path = rl.new('ModelPath')
    path.model = 0
    return not rl.charge_waypoint_valid(board, board[0], path, board_position(14, 5), 12, False)

# p.74: AIRCRAFT cannot charge; only FLYING units may select them, but
# every model can cross an Aircraft's base en route to another selected target.
def test_charge13_aircraft_source_target_and_traversal():
    board = value_copy(charge13_fixture())
    board[1][0].keywords.append(rl.Keyword.aircraft())
    if rl.charge_source_valid(board, rl.unit_id(1), True) or rl.charge_target_valid(board, rl.unit_id(0), rl.unit_id(1), 12, rl.ChargeKind.ordinary()):
        return False
    path = rl.new('ModelPath')
    path.model = 0
    if not rl.charge_waypoint_valid(board, board[0], path, board_position(14, 5), 12, False):
        return False
    board[0][0].keywords.append(rl.Keyword.fly())
    return rl.charge_target_valid(board, rl.unit_id(0), rl.unit_id(1), 12, rl.ChargeKind.ordinary())

# p.36 / appendix 02.02.01 storage: reject out-of-domain charge modifiers
# atomically rather than accepting corrupt bounded fields in a saved game.
def test_charge13_malformed_modifier_rejected():
    state = value_copy(rl.play())
    board = value_copy(charge13_fixture())
    state.board.units.append(board[0])
    state.board.identify_unit(state.board[0])
    state.board[0].phase_modifiers.charge_roll.append(rl.rule_modifier(rl.ModifierOperation.add(), 1))
    state.board[0].phase_modifiers.charge_roll[0].amount.value = rl.MAX_RULE_MODIFIER
    serialized = value_copy(rl.to_string(state))
    restored = value_copy(rl.play())
    return not rl.set_state(restored, serialized)

# pp.38–42 fixture: two single live models, friendly at (5,5), enemy at
# (8,5), with 1.74-inch base separation and neutral core faction fixtures.
def fight14_fixture():
    board = value_copy(charge13_fixture())
    board[1][0].position.x = 8
    board.begin_phase(rl.BattlePhase.fight())
    return value_copy(board)

# p.38: active player performs every optional Pile In before the opponent,
# and both movement stages precede mandatory attack selection.
def test_fight14_phase_wide_pile_in_order():
    board = value_copy(fight14_fixture())
    phase = value_copy(rl.fight_phase(board))
    if board.current_decision_maker or not phase.can_select_melee_unit(board, rl.unit_id(0)) or phase.can_select_melee_unit(board, rl.unit_id(1)):
        return False
    phase.finish_melee_step(board)
    if not board.current_decision_maker or not phase.can_select_melee_unit(board, rl.unit_id(1)):
        return False
    phase.finish_melee_step(board)
    return not board.current_decision_maker and phase.can_select_fighting_unit(board, rl.unit_id(0)) and (not phase.can_select_melee_unit(board, rl.unit_id(0)))

# pp.40/81: current player starts Fights First; every participating model
# needs the ability, while any completed charge grants it to the whole unit.
def test_fight14_first_requires_all_models_or_charge():
    board = value_copy(fight14_fixture())
    board[0][0].abilities.append(rl.AbilityKind.fight_first())
    ordinary = value_copy(board[0][0])
    ordinary.abilities.clear()
    ordinary.position.y = 7
    board[0].models.append(ordinary)
    if rl.fight_first_unit(board[0]):
        return False
    board[0].has_charged = True
    board[1][0].abilities.append(rl.AbilityKind.fight_first())
    sequence = value_copy(rl.fight_step(board, True))
    return rl.fight_first_unit(board[0]) and (not board.current_decision_maker) and sequence.can_select_fighting_unit(board, rl.unit_id(0)) and (not sequence.can_select_fighting_unit(board, rl.unit_id(1))) and (not sequence.can_pass_fight(board))

# p.40: when neither player has Fights First units, the current player
# moves the sequence into Remaining Combats and selects first.
def test_fight14_remaining_combats_current_player_starts():
    board = value_copy(fight14_fixture())
    sequence = value_copy(rl.fight_step(board, True))
    return not sequence.first and sequence.can_select_fighting_unit(board, rl.unit_id(0)) and (not sequence.can_pass_fight(board))

# p.40: legal passing transfers selection only when no unit of the required
# priority is available; an eligible normal unit cannot bypass enemy Fights First.
def test_fight14_priority_pass_and_owner_transfer():
    board = value_copy(fight14_fixture())
    board[1][0].abilities.append(rl.AbilityKind.fight_first())
    sequence = value_copy(rl.fight_step(board, True))
    if not sequence.can_pass_fight(board) or sequence.can_select_fighting_unit(board, rl.unit_id(0)):
        return False
    sequence.pass_fight(board)
    return board.current_decision_maker and (not sequence.can_pass_fight(board)) and sequence.can_select_fighting_unit(board, rl.unit_id(1))

# p.40: selecting consumes the fight immediately; an already selected unit
# cannot be chosen twice while nested weapon/attack decisions are unresolved.
def test_fight14_selection_consumes_once_before_attacks():
    board = value_copy(fight14_fixture())
    sequence = value_copy(rl.fight_step(board, True))
    sequence.select_fighting_unit(board, rl.unit_id(0))
    return board[0].has_fought and (not rl.fight_unit_eligible(board, rl.unit_id(0))) and sequence.can_choose_fight_kind(board, rl.FightKind.normal()) and (not sequence.can_choose_fight_kind(board, rl.FightKind.overrun()))

# p.40: a unit that was engaged at Fight-step start remains eligible after
# its opponent disappears; it selects Overrun and cannot select Normal.
def test_fight14_start_engagement_survives_enemy_loss():
    board = value_copy(fight14_fixture())
    rl.begin_fight_step(board)
    board[1].models.clear()
    return rl.fight_unit_eligible(board, rl.unit_id(0)) and rl.fight_kind_valid(board, rl.unit_id(0), rl.FightKind.overrun()) and (not rl.fight_kind_valid(board, rl.unit_id(0), rl.FightKind.normal()))

# p.40: newly engaged units become eligible and can choose Overrun even
# while currently engaged; newly eligible Fights First restores priority.
def test_fight14_new_engagement_restores_first_priority():
    board = value_copy(fight14_fixture())
    other = value_copy(board[1])
    other[0].position.x = 20
    other[0].abilities.append(rl.AbilityKind.fight_first())
    board.units.append(other)
    rl.begin_fight_step(board)
    if rl.fight_unit_eligible(board, rl.unit_id(2)):
        return False
    board[2][0].position = board_position(5, 7)
    rl.refresh_fight_eligibility(board)
    return rl.fight_unit_eligible(board, rl.unit_id(2)) and rl.player_can_fight(board, True, True) and rl.fight_kind_valid(board, rl.unit_id(2), rl.FightKind.overrun()) and (board[2].history.fight_eligible_phase == board.phase_serial.value + 1)

# pp.38/40: phase-wide Pile In is once per completed move; Overrun grants an
# additional one even when the phase-wide stamp is already present.
def test_fight14_overrun_additional_pile_in():
    board = value_copy(fight14_fixture())
    board[0].history.pile_in_phase = board.phase_serial.value + 1
    return not rl.melee_move_eligible(board, rl.unit_id(0), False, False) and rl.melee_move_eligible(board, rl.unit_id(0), False, True)

# pp.38/42: candidate formation is private until final constraints pass;
# cancellation leaves position/distance/once-per-step stamps untouched.
def test_fight14_pile_in_path_commit_and_cancel():
    board = value_copy(fight14_fixture())
    sequence = value_copy(rl.melee_move(board, rl.unit_id(0), False, False))
    sequence.select_melee_model(board, damage_test_model(0))
    sequence.choose_melee_approach(board, rl.unit_id(1))
    sequence.melee_waypoint(board, board_position(6, 5))
    sequence.finish_melee_model(board)
    if board[0][0].position.x != 5 or not sequence.can_finish_melee_move(board):
        return False
    sequence.finish_melee_move(board)
    if not sequence.completed or board[0][0].position.x != 6 or board[0].history.pile_in_phase != board.phase_serial.value + 1 or (board[0][0].history.distance_moved_this_turn() != 1.0):
        return False
    declined = value_copy(rl.melee_move(board, rl.unit_id(1), False, False))
    declined.cancel_melee_move(board)
    return declined.is_done() and board[1][0].position.x == 8 and (board[1].history.pile_in_phase == 0)

# p.38: a charged unengaged unit chooses targets within 5, then must finish
# engaged. No target outside 5 is accepted, even with a 3-inch path budget.
def test_fight14_unengaged_pile_targets_and_engaged_finish():
    board = value_copy(fight14_fixture())
    board[1][0].position.x = 11
    board[0].has_charged = True
    sequence = value_copy(rl.melee_move(board, rl.unit_id(0), False, False))
    if not sequence.can_select_melee_target(board, rl.unit_id(1)) or sequence.can_finish_melee_targets(board):
        return False
    sequence.select_melee_target(board, rl.unit_id(1))
    sequence.finish_melee_targets(board)
    if sequence.can_finish_melee_move(board):
        return False
    sequence.select_melee_model(board, damage_test_model(0))
    sequence.choose_melee_approach(board, rl.unit_id(1))
    sequence.melee_waypoint(board, board_position(8, 5))
    sequence.finish_melee_model(board)
    return sequence.can_finish_melee_move(board)

# pp.38/42: moved models must approach their own initial closest selected
# enemy; controller choices preserve exact closest-unit ties.
def test_fight14_closest_target_ties_and_wrong_target():
    board = value_copy(fight14_fixture())
    other = value_copy(board[1])
    other[0].position = board_position(5, 8)
    board.units.append(other)
    targets = rl.new('Bool[MAX_UNIT_COUNT]')
    targets[1] = True
    targets[2] = True
    if not rl.nearest_melee_target_valid(board, board[0][0], targets, rl.unit_id(1)) or not rl.nearest_melee_target_valid(board, board[0][0], targets, rl.unit_id(2)):
        return False
    board[2][0].position.y = 9
    return not rl.nearest_melee_target_valid(board, board[0][0], targets, rl.unit_id(2))

# pp.38/42: an initially engaged model must stay engaged with every original
# enemy unit, not only its chosen closest approach target.
def test_fight14_preserve_every_original_model_engagement():
    board = value_copy(fight14_fixture())
    other = value_copy(board[1])
    other[0].position = board_position(5, 8)
    board.units.append(other)
    candidate = value_copy(board[0])
    candidate[0].position = board_position(6, 4)
    targets = rl.new('Bool[MAX_UNIT_COUNT]')
    targets[1] = True
    targets[2] = True
    return not rl.melee_placement_valid(board, board[0], candidate, rl.unit_id(0), rl.MeleeMoveKind.pile_in(), targets, 0)

# pp.12/38/42: no enemy overlap and no path-budget reset across waypoints.
def test_fight14_waypoint_total_and_enemy_collision():
    board = value_copy(fight14_fixture())
    path = rl.new('ModelPath')
    path.model = 0
    if rl.melee_waypoint_valid(board, board[0], path, board_position(8, 5), rl.MeleeMoveKind.pile_in()):
        return False
    path.append_point(rl.geometry_point(5 * rl.MICROMETRES_PER_INCH, 7 * rl.MICROMETRES_PER_INCH, 0))
    return not rl.melee_waypoint_valid(board, board[0], path, board_position(5, 9), rl.MeleeMoveKind.pile_in())

# p.38: contact/overlap has zero base separation and is locked, including
# rotation. The current millimetre fixtures cannot express exact contact on
# whole quads, so this predicate boundary is not a valid placement fixture.
def test_fight14_contact_lock_predicate_and_dead_models():
    board = value_copy(fight14_fixture())
    board[1][0].position = board[0][0].position
    if not rl.melee_model_locked(board, board[0][0], board[0], rl.MeleeMoveKind.pile_in()):
        return False
    board[0][0].state = rl.ModelState.fight_on_death()
    return rl.melee_model_locked(board, board[0][0], board[0], rl.MeleeMoveKind.engaging())

# p.42: mandatory mode priority is ongoing, then nearby enemies, then objectives.
def test_fight14_consolidation_mode_priority():
    board = value_copy(fight14_fixture())
    if not rl.consolidation_kind(board, board[0]) == rl.MeleeMoveKind.ongoing():
        return False
    board[1][0].position.x = 9
    if not rl.consolidation_kind(board, board[0]) == rl.MeleeMoveKind.engaging():
        return False
    board[1][0].position.x = 15
    return rl.consolidation_kind(board, board[0]) == rl.MeleeMoveKind.objective()

# p.42: having been eligible earlier permits consolidation even after all
# enemies disappear; an unrelated unit cannot consolidate merely by choosing it.
def test_fight14_consolidation_uses_earlier_eligibility():
    board = value_copy(fight14_fixture())
    rl.begin_fight_step(board)
    board[1].models.clear()
    return rl.melee_move_eligible(board, rl.unit_id(0), True, False) and (not rl.melee_move_eligible(board, rl.unit_id(1), True, False))

# p.42: engaging consolidation must engage every selected enemy, but may
# incidentally engage another enemy; it will be offered a response fight.
def test_fight14_engaging_consolidation_all_targets_and_incidental():
    board = value_copy(fight14_fixture())
    board[1][0].position.x = 9
    other = value_copy(board[1])
    other[0].position = board_position(7, 7)
    board.units.append(other)
    candidate = value_copy(board[0])
    candidate[0].position.x = 7
    targets = rl.new('Bool[MAX_UNIT_COUNT]')
    targets[1] = True
    if not rl.melee_placement_valid(board, board[0], candidate, rl.unit_id(0), rl.MeleeMoveKind.engaging(), targets, 0):
        return False
    board[2][0].position.x = 15
    targets[2] = True
    return not rl.melee_placement_valid(board, board[0], candidate, rl.unit_id(0), rl.MeleeMoveKind.engaging(), targets, 0)

# p.42: objective selection is within 3 inches of any live base; a moved
# model must end in objective range when a coherent endpoint can do so.
def test_fight14_objective_consolidation_range():
    board = value_copy(fight14_fixture())
    board[1].models.clear()
    board.objectives[0].custom_position = True
    board.objectives[0].position = board_position(8, 5)
    board[0].history.fight_eligible_phase = board.phase_serial.value + 1
    if not rl.melee_objective_valid(board, board[0], 0):
        return False
    sequence = value_copy(rl.melee_move(board, rl.unit_id(0), True, False))
    sequence.choose_melee_objective(board, fight14_objective(0))
    if not sequence.can_finish_melee_move(board):
        return False
    sequence.finish_melee_move(board)
    return sequence.completed and board[0].history.consolidation_phase == board.phase_serial.value + 1 and (not rl.melee_move_eligible(board, rl.unit_id(0), True, False))

# pp.42/52: terrain objectives use their linked area, not marker distance.
def test_fight14_objective_terrain_area_distance():
    board = value_copy(fight14_fixture())
    board.terrain_areas.append(terrain_area(6, 4, 12, 6, False))
    board.objectives[0].terrain_objective = True
    board.objectives[0].area_id = 0
    board.objectives[0].custom_position = True
    board.objectives[0].position = board_position(12, 5)
    return rl.melee_objective_valid(board, board[0], 0) and rl.melee_objective_distance(board, board[0][0], 0) < 1.0

# p.42: consolidation response remains mandatory if an earlier response
# removes its enemy, so the unit may make an Overrun instead of disappearing.
def test_fight14_consolidation_response_survives_enemy_loss():
    board = value_copy(fight14_fixture())
    board[1].history.consolidation_fight_pending = board.phase_serial.value + 1
    board[0].models.clear()
    return rl.consolidation_response_valid(board, rl.unit_id(1)) and rl.has_consolidation_response(board, True) and rl.fight_kind_valid(board, rl.unit_id(1), rl.FightKind.overrun())

# p.74: only FLYING bearers can attack AIRCRAFT in melee; a mixed unit's
# keyword cannot grant that permission to its non-flying model.
def test_fight14_aircraft_melee_bearer_restriction():
    board = value_copy(fight14_fixture())
    board[1][0].keywords.append(rl.Keyword.aircraft())
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), True):
        return False
    board[0][0].keywords.append(rl.Keyword.fly())
    return rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), True)

# Supplied Fight on Death: no destruction triggers/removal when the enemy
# finishes attacking. Corpses stay ineligible as targets and ordinary attackers.
def test_fight14_retained_death_waits_for_own_unit():
    board = value_copy(fight14_fixture())
    board.attack_info.fight_on_death_roll = 1
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(1), True, True, 2, board[0][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 2, True)
    corpse = value_copy(board[0][0].identity)
    jobs = rl.new('DamageJobs')
    finished_enemy = value_copy(rl.resolve_damage_jobs(board, jobs, True, rl.unit_id(1)))
    return finished_enemy.is_done() and board[0].find_model(corpse) == 0 and board[0][0].destruction_pending and (not rl.destruction_ready(board[0][0], True, rl.unit_id(1))) and (not rl.has_live_attack_recipient(board[0])) and (not rl.attack_model_allowed(board, rl.unit_id(0), 0, True)) and rl.fight_unit_eligible(board, rl.unit_id(0))

# Supplied Fight on Death: source exception permits retained melee weapons
# and targets with the unit, and unit stratagem effects apply to them too.
def test_fight14_retained_attack_exception_and_stratagem():
    board = value_copy(fight14_fixture())
    board[0][0].suffered_wounds = board[0][0].profile.wounds()
    board[0][0].state = rl.ModelState.fight_on_death()
    board[0][0].destruction_pending = True
    board[0][0].destruction_fight_roll = 1
    sequence = value_copy(rl.attack(board, rl.unit_id(0), rl.unit_id(1), True, False))
    if not sequence.can_select_weapon(board, attack_test_slot(2)):
        return False
    sequence.select_weapon(board, attack_test_slot(2))
    sequence.skip(board)
    sequence.declare_target(board, rl.unit_id(0), rl.unit_id(1))
    sequence.assign_attacks(board, attack_test_share(3))
    sequence.choose_attack_target(board, rl.unit_id(1))
    return board.allow_destroyed_attack and sequence.can_no_defensive_stratagem(board) and board.can_target_strat(False, rl.Stratagem.reroll(), board[0])

# Supplied Fight on Death: phase-end fallback releases delayed triggers,
# resolves their model choice, then removes/archives each corpse exactly once.
def test_fight14_phase_end_retained_cleanup():
    board = value_copy(fight14_fixture())
    board.attack_info.fight_on_death_roll = 1
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(1), True, True, 2, board[0][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 2, True)
    cleanup = value_copy(rl.cleanup_phase_retained(board))
    cleanup.choose_destruction_unit(board, rl.unit_id(0))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    return cleanup.is_done() and board[0].models.empty() and (board[0].destroyed_models.value.size() == 1) and (not board.allow_destroyed_attack)

# Supplied Fight on Death / p.87: other death triggers remain pending too;
# Deadly Demise rolls only after the unit attacks or phase-end release.
def test_fight14_retained_demise_trigger_delayed():
    board = value_copy(fight14_fixture())
    board[0][0].has_deadly_demise = True
    board[0][0].deadly_demise = rl.raw_stat(1)
    board.attack_info.fight_on_death_roll = 1
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(1), True, True, 2, board[0][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 2, True)
    jobs = rl.new('DamageJobs')
    enemy_end = value_copy(rl.resolve_damage_jobs(board, jobs, True, rl.unit_id(1)))
    if not enemy_end.is_done():
        return False
    cleanup = value_copy(rl.cleanup_phase_retained(board))
    cleanup.choose_destruction_unit(board, rl.unit_id(0))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    if not cleanup.can_roll(board, attack_test_die(1)):
        return False
    cleanup.roll(board, attack_test_die(1))
    return cleanup.is_done() and board[0].models.empty()

# Supplied Fight on Death: failed legacy permission rolls skip corpse weapon
# selection but still release and archive it after the unit's activation.
def test_fight14_failed_legacy_grant_still_cleans_up():
    board = value_copy(fight14_fixture())
    board.attack_info.fight_on_death_roll = 4
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(1), True, True, 2, board[0][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 2, True)
    sequence = value_copy(rl.attack(board, rl.unit_id(0), rl.unit_id(1), True, False))
    sequence.roll(board, attack_test_die(1))
    sequence.choose_destruction_unit(board, rl.unit_id(0))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    return sequence.is_done() and board[0].models.empty() and (board[0].destroyed_models.value.size() == 1) and (not board.allow_destroyed_attack)

# pp.38–42 storage infrastructure: snapshots and once-per-step markers have
# bounded inferred ML layout; corrupted metadata cannot bypass save validation.
def test_fight14_malformed_phase_stamp_rejected():
    state = value_copy(rl.play())
    board = value_copy(fight14_fixture())
    state.board.units.append(board[0])
    state.board.identify_unit(state.board[0])
    state.board[0].history.consolidation_phase.value = rl.MAX_PHASE_STAMP
    text = value_copy(rl.to_string(state))
    restored = value_copy(rl.play())
    return not rl.set_state(restored, text)

# Four-slot objective selector matches the editor's finite numeric payload.
def fight14_objective(value):
    objective = rl.new('BInt<0, 4>')
    assign(objective, value)
    return value_copy(objective)

# Shared fixture activation misses all three ordinary melee attacks. It
# traverses declarations/grouping without manufacturing target damage.
def fight14_miss_attacks_attack(sequence, board, source, target):
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
    if sequence.can_keep_batch(board):
        sequence.keep_batch(board)

def fight14_miss_attacks_step(sequence, board, source, target):
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
    if sequence.can_keep_batch(board):
        sequence.keep_batch(board)

    if sequence.can_decline_counteroffensive(board):
        sequence.decline_counteroffensive(board)

def core15_miss_attacks(sequence, board, source, target):
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
    if sequence.can_keep_batch(board):
        sequence.keep_batch(board)

def fight14_miss_attacks_move(sequence, board, source, target):
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
    if sequence.can_keep_batch(board):
        sequence.keep_batch(board)

def fight14_miss_attacks(sequence, board, source, target):
    helpers = {"Attack": fight14_miss_attacks_attack,
               "FightStep": fight14_miss_attacks_step,
               "MeleeMoveStep": fight14_miss_attacks_move}
    helpers[type(sequence.native).__name__](sequence, board, source, target)

# p.40: completed activations alternate owners, and all eligible units must
# fight once. No optional end button can silently omit the second army.
def test_fight14_alternates_complete_unit_attacks():
    board = value_copy(fight14_fixture())
    sequence = value_copy(rl.fight_step(board, True))
    sequence.select_fighting_unit(board, rl.unit_id(0))
    sequence.choose_fight_kind(board, rl.FightKind.normal())
    fight14_miss_attacks(sequence, board, rl.unit_id(0), rl.unit_id(1))
    if not board.current_decision_maker or not sequence.can_select_fighting_unit(board, rl.unit_id(1)) or sequence.can_pass_fight(board):
        return False
    sequence.select_fighting_unit(board, rl.unit_id(1))
    sequence.choose_fight_kind(board, rl.FightKind.normal())
    fight14_miss_attacks(sequence, board, rl.unit_id(1), rl.unit_id(0))
    return sequence.is_done() and board[0].has_fought and board[1].has_fought and (not board.current_decision_maker)

# Supplied Fight on Death: retained models use the full declaration/group
# pipeline, then their own destruction effects run and they are archived once.
def test_fight14_retained_model_attacks_with_unit_then_removed():
    board = value_copy(fight14_fixture())
    board.attack_info.fight_on_death_roll = 1
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(1), True, True, 2, board[0][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 2, True)
    sequence = value_copy(rl.attack(board, rl.unit_id(0), rl.unit_id(1), True, False))
    fight14_miss_attacks(sequence, board, rl.unit_id(0), rl.unit_id(1))
    if board[0].models.size() != 1 or not board[0][0].destruction_released:
        return False
    sequence.choose_destruction_unit(board, rl.unit_id(0))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    return sequence.is_done() and board[0].models.empty() and (board[0].destroyed_models.value.size() == 1) and (not board.allow_destroyed_attack) and (board[1][0].suffered_wounds == 0)

# p.42: completing Engaging Consolidation immediately offers the newly
# engaged unfought enemy a mandatory response before any further moves.
def test_fight14_engaging_consolidation_forces_response():
    board = value_copy(fight14_fixture())
    board[1][0].position.x = 9
    board[0].history.fight_eligible_phase = board.phase_serial.value + 1
    board[0].has_fought = True
    sequence = value_copy(rl.melee_move_step(board, True))
    sequence.select_melee_unit(board, rl.unit_id(0))
    sequence.select_melee_target(board, rl.unit_id(1))
    sequence.finish_melee_targets(board)
    sequence.select_melee_model(board, damage_test_model(0))
    sequence.choose_melee_approach(board, rl.unit_id(1))
    sequence.melee_waypoint(board, board_position(7, 5))
    sequence.finish_melee_model(board)
    sequence.finish_melee_move(board)
    if not board.current_decision_maker or not sequence.can_select_consolidation_fighter(board, rl.unit_id(1)) or sequence.can_finish_melee_step(board):
        return False
    sequence.select_consolidation_fighter(board, rl.unit_id(1))
    sequence.choose_fight_kind(board, rl.FightKind.normal())
    fight14_miss_attacks(sequence, board, rl.unit_id(1), rl.unit_id(0))
    return not board.current_decision_maker and board[1].has_fought and sequence.can_finish_melee_step(board)

# Supplied Fight on Death: a unit already selected to fight cannot fight a
# second time; any newly retained casualties wait until phase-end release.
def test_fight14_already_fought_retained_unit_no_second_fight():
    board = value_copy(fight14_fixture())
    board[0].has_fought = True
    board.attack_info.fight_on_death_roll = 1
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(1), True, True, 2, board[0][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 2, True)
    return not rl.fight_unit_eligible(board, rl.unit_id(0)) and (not rl.destruction_ready(board[0][0], True, rl.unit_id(1)))

# pp.38/42: a moved model cannot skip engagement when a coherent reachable
# replacement exists, even if another model already engages the selected unit.
def test_fight14_moved_model_must_engage_if_possible():
    board = value_copy(fight14_fixture())
    board[1][0].position.x = 10
    other = value_copy(board[0][0])
    other.position.y = 7
    board[0].models.append(other)
    candidate = value_copy(board[0])
    candidate[0].position = board_position(6, 6)
    candidate[1].position = board_position(8, 7)
    targets = rl.new('Bool[MAX_UNIT_COUNT]')
    targets[1] = True
    approaches = rl.new('UnitID[MAX_UNIT_MODELS]')
    approaches[0] = rl.unit_id(1)
    approaches[1] = rl.unit_id(1)
    return rl.melee_placement_valid(board, board[0], candidate, rl.unit_id(0), rl.MeleeMoveKind.pile_in(), targets, 0) and (not rl.melee_finish_valid(board, board[0], candidate, rl.unit_id(0), rl.MeleeMoveKind.pile_in(), targets, approaches, 0)) and (candidate[0].position.x == 6)

# pp.38/42 storage: a pending per-model path and closest-target choice retain
# their bounded state across a save round trip; positions commit only at finish.
def test_fight14_pending_melee_path_round_trip():
    board = value_copy(fight14_fixture())
    sequence = value_copy(rl.melee_move(board, rl.unit_id(0), False, False))
    sequence.select_melee_model(board, damage_test_model(0))
    sequence.choose_melee_approach(board, rl.unit_id(1))
    sequence.melee_waypoint(board, board_position(6, 5))
    text = value_copy(rl.to_string(sequence))
    restored = rl.new('MeleeMove')
    index = value_copy(0)
    if not rl.from_string(restored, text, index):
        return False
    restored.finish_melee_model(board)
    restored.finish_melee_move(board)
    return restored.is_done() and restored.completed and (board[0][0].position.x == 6)

# pp.8/40: the selected unit owns the active/decision roles even while
# choosing its fight type, and both roles restore after an opposing activation.
# An invalid direct constructor cannot consume a fight or index a foreign slot.
def test_fight14_selected_opponent_roles_and_invalid_constructor():
    board = value_copy(fight14_fixture())
    invalid = value_copy(rl.selected_fight(board, rl.unit_id(31)))
    if not invalid.is_done() or board[0].has_fought or board.timing.active_player:
        return False
    sequence = value_copy(rl.selected_fight(board, rl.unit_id(1)))
    if not board.current_decision_maker or not board.timing.active_player or board.current_player:
        return False
    sequence.choose_fight_kind(board, rl.FightKind.normal())
    sequence.select_weapon(board, attack_test_slot(2))
    sequence.skip(board)
    sequence.declare_target(board, rl.unit_id(1), rl.unit_id(0))
    sequence.assign_attacks(board, attack_test_share(3))
    sequence.choose_attack_target(board, rl.unit_id(0))
    sequence.no_defensive_stratagem(board)
    sequence.no_offensive_stratagem(board)
    sequence.choose_attack_weapon(board, attack_test_weapon(0))
    for i in range(3):
        sequence.roll(board, attack_test_die(1))
    if sequence.can_keep_batch(board):
        sequence.keep_batch(board)
    return sequence.is_done() and (not board.current_decision_maker) and (not board.timing.active_player) and board[1].has_fought

# Task 15 fixtures use explicit core keywords, not guessed faction datasheets.
def core15_fixture():
    board = value_copy(charge13_fixture())
    board.begin_phase(rl.BattlePhase.shooting())
    board[0].can_shoot = True
    board[1].can_shoot = True
    board[0][0].keywords.append(rl.Keyword.grenades())
    return value_copy(board)

# p.56: all four added 1CP stratagems and Counteroffensive's 2CP cost.
def test_core15_printed_costs():
    return rl.Stratagem.explosives().cost() == 1 and rl.Stratagem.crushing_impact().cost() == 1 and (rl.Stratagem.epic_challenge().cost() == 1) and (rl.Stratagem.smokescreen().cost() == 1) and (rl.Stratagem.counteroffensive().cost() == 2)

# p.56: friendly source in own Shooting phase, not Advance/shock/engagement.
def test_core15_explosives_source_gates():
    board = value_copy(core15_fixture())
    if not rl.explosives_source_valid(board, rl.unit_id(0)) or rl.explosives_source_valid(board, rl.unit_id(1)):
        return False
    board[0].history.advanced_this_turn = True
    if rl.explosives_source_valid(board, rl.unit_id(0)):
        return False
    board[0].history.advanced_this_turn = False
    board[0].battle_socked = True
    if rl.explosives_source_valid(board, rl.unit_id(0)):
        return False
    board[0].battle_socked = False
    board.begin_phase(rl.BattlePhase.charge())
    return not rl.explosives_source_valid(board, rl.unit_id(0))

# p.56: an unengaged target in range of the actual keyword bearer is required.
def test_core15_explosives_bearer_range_and_enemy_engagement():
    board = value_copy(core15_fixture())
    board[1][0].position.x = 14
    if not rl.explosives_target_valid(board, rl.unit_id(0), damage_test_model(0), rl.unit_id(1)):
        return False
    board[1][0].position.x = 15
    if rl.explosives_source_valid(board, rl.unit_id(0)):
        return False
    board[1][0].position.x = 13
    friend = value_copy(board[0])
    friend[0].position.x = 11
    board.units.append(friend)
    return not rl.explosives_target_valid(board, rl.unit_id(0), damage_test_model(0), rl.unit_id(1)) and (not rl.explosives_model_valid(board, rl.unit_id(0), damage_test_model(1)))

# p.56: choose a keyword bearer, not another model in its mixed unit.
def test_core15_explosives_per_model_keyword():
    board = value_copy(core15_fixture())
    ordinary = value_copy(board[0][0])
    ordinary.keywords.clear()
    board[0].models.append(ordinary)
    return rl.explosives_model_valid(board, rl.unit_id(0), damage_test_model(0)) and (not rl.explosives_model_valid(board, rl.unit_id(0), damage_test_model(1)))

# pp.54/56: choose source, bearer, target; six neutral dice precede common
# mortal allocation. Selecting Explosives does not consume normal shooting.
def test_core15_explosives_six_dice_and_one_mortal():
    board = value_copy(core15_fixture())
    sequence = value_copy(rl.resolve_explosives(board, rl.unit_id(0)))
    if board.command_points[0] != 2 or board.moving_unit.get() != 0 or (not sequence.can_choose_explosives_model(board, damage_test_model(0))):
        return False
    sequence.choose_explosives_model(board, damage_test_model(0))
    sequence.choose_explosives_target(board, rl.unit_id(1))
    sequence.roll(board, attack_test_die(4))
    for i in range(5):
        sequence.roll(board, attack_test_die(1))
    if sequence.can_roll(board, attack_test_die(6)) or not sequence.can_select_mortal_model(board, damage_test_model(0)):
        return False
    sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[1][0].suffered_wounds == 1 and board[0].history.stratagem_targeted_by_player[0] and (not board[0].has_shoot) and rl.shooting_unit_valid(board, rl.unit_id(0)) and (not rl.explosives_source_valid(board, rl.unit_id(0)))

# pp.24/56/87: Explosives deaths use actual delayed destruction/archival,
# not low-level damage or a bespoke casualty deletion helper.
def test_core15_explosives_common_destruction():
    board = value_copy(core15_fixture())
    board[1][0].has_deadly_demise = True
    board[1][0].deadly_demise = rl.raw_stat(1)
    sequence = value_copy(rl.resolve_explosives(board, rl.unit_id(0)))
    sequence.choose_explosives_model(board, damage_test_model(0))
    sequence.choose_explosives_target(board, rl.unit_id(1))
    for i in range(6):
        sequence.roll(board, attack_test_die(4))
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.select_mortal_model(board, damage_test_model(0))
    if board[1].models.empty() or not sequence.can_choose_destruction_unit(board, rl.unit_id(1)):
        return False
    sequence.choose_destruction_unit(board, rl.unit_id(1))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    sequence.roll(board, attack_test_die(1))
    return sequence.is_done() and board[1].models.empty() and (board[1].destroyed_models.value.size() == 1)

# p.56: decline before a source is selected spends nothing; own Shooting
# phase exposes Explosives without requiring a normal ranged weapon.
def test_core15_explosives_shooting_phase_entry():
    board = value_copy(core15_fixture())
    board[0][0].weapons.clear()
    phase = value_copy(rl.shooting_phase(board))
    if not phase.can_use_explosives(board, rl.unit_id(0)):
        return False
    phase.end_shooting_phase(board)
    return phase.is_done() and board.command_points[0] == 3 and (not board.has_used_strat(rl.Stratagem.explosives(), 0))

# p.56: a successful own Charge-phase move and keyword are mandatory.
def test_core15_crushing_success_phase_and_keyword_gates():
    board = value_copy(fight14_fixture())
    board[0][0].keywords.append(rl.Keyword.monster())
    board[0].history.charge_move_phase = board.phase_serial.value + 1
    if rl.crushing_source_valid(board, rl.unit_id(0)):
        return False
    board.begin_phase(rl.BattlePhase.charge())
    if rl.crushing_source_valid(board, rl.unit_id(0)):
        return False
    rl.record_charge_move(board, rl.unit_id(0))
    if not rl.crushing_source_valid(board, rl.unit_id(0)):
        return False
    board.current_player = True
    return not rl.crushing_source_valid(board, rl.unit_id(0))

# p.56: model selection requires that bearer to engage the chosen enemy.
def test_core15_crushing_selected_model_engagement():
    board = value_copy(fight14_fixture())
    far = value_copy(board[0][0])
    far.position.x = 2
    board[0].models.append(far)
    return rl.crushing_model_valid(board, rl.unit_id(0), rl.unit_id(1), damage_test_model(0)) and (not rl.crushing_model_valid(board, rl.unit_id(0), rl.unit_id(1), damage_test_model(1))) and (not rl.crushing_target_valid(board, rl.unit_id(0), rl.unit_id(0)))

# p.56: T=4 generates four dice, ones wound the source, 5+ the enemy.
def test_core15_crushing_both_mortal_totals():
    board = value_copy(fight14_fixture())
    board.begin_phase(rl.BattlePhase.charge())
    board[0][0].keywords.append(rl.Keyword.vehicle())
    rl.record_charge_move(board, rl.unit_id(0))
    sequence = value_copy(rl.resolve_crushing_impact(board, rl.unit_id(0)))
    sequence.choose_impact_target(board, rl.unit_id(1))
    sequence.choose_impact_model(board, damage_test_model(0))
    sequence.roll(board, attack_test_die(1))
    sequence.roll(board, attack_test_die(5))
    sequence.roll(board, attack_test_die(2))
    sequence.roll(board, attack_test_die(4))
    if sequence.self_amount != 1 or sequence.enemy_amount != 1 or sequence.can_roll(board, attack_test_die(6)):
        return False
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[0][0].suffered_wounds == 1 and (board[1][0].suffered_wounds == 1) and (board.command_points[0] == 2)

# p.56: both self and enemy totals cap at six independently, not dice count.
def test_core15_crushing_six_cap_per_unit():
    board = value_copy(fight14_fixture())
    board.begin_phase(rl.BattlePhase.charge())
    board[0][0].keywords.append(rl.Keyword.monster())
    board[0][0].profile = rl.Profile.squighog_boyz()
    rl.record_charge_move(board, rl.unit_id(0))
    sequence = value_copy(rl.resolve_crushing_impact(board, rl.unit_id(0)))
    sequence.choose_impact_target(board, rl.unit_id(1))
    sequence.choose_impact_model(board, damage_test_model(0))
    for i in range(7):
        sequence.roll(board, attack_test_die(1))
    return sequence.total == 7 and sequence.self_amount == 6 and (sequence.enemy_amount == 0) and (not sequence.can_roll(board, attack_test_die(1)))

# pp.37/56: only a completed charge exposes immediate Crushing Impact;
# accepting it pays before the target/model/dice sequence.
def test_core15_crushing_after_real_charge_and_decline():
    board = value_copy(charge13_fixture())
    board.begin_phase(rl.BattlePhase.charge())
    board[0][0].keywords.append(rl.Keyword.monster())
    sequence = value_copy(rl.charge(board, rl.unit_id(0), rl.ChargeKind.ordinary()))
    sequence.roll_pair(board, attack_test_die(4), attack_test_die(4))
    sequence.keep_it(board, True)
    sequence.select_charge_target(board, rl.unit_id(1))
    sequence.finish_charge_targets(board)
    sequence.charge_move_to(board, board_position(11, 5))
    if not sequence.can_crushing_impact(board) or not sequence.can_decline_crushing_impact(board):
        return False
    sequence.decline_crushing_impact(board)
    return sequence.is_done() and board[0].has_charged and (board.command_points[0] == 3)

# p.56: Epic Challenge chooses one CHARACTER, at selection rather than per
# attack target; ordinary living models do not inherit its Precision grant.
def test_core15_epic_selected_character_only_melee():
    board = value_copy(fight14_fixture())
    board[0][0].keywords.append(rl.Keyword.character())
    ordinary = value_copy(board[0][0])
    ordinary.keywords.clear()
    board[0].models.append(ordinary)
    sequence = value_copy(rl.selected_fight(board, rl.unit_id(0)))
    if not sequence.can_epic_challenge(board) or sequence.can_choose_fight_kind(board, rl.FightKind.normal()):
        return False
    sequence.epic_challenge(board)
    if sequence.can_choose_epic_character(board, damage_test_model(1)):
        return False
    sequence.choose_epic_character(board, damage_test_model(0))
    melee = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 2))
    ranged = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    other = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 2))
    return board.command_points[0] == 2 and rl.declared_weapon_has_kind(melee, rl.WeaponRuleKind.precision()) and (not rl.declared_weapon_has_kind(ranged, rl.WeaponRuleKind.precision())) and (not rl.declared_weapon_has_kind(other, rl.WeaponRuleKind.precision()))

# pp.54/56: decline spends nothing; shock/used-unit restrictions remove it.
def test_core15_epic_decline_and_stratagem_limits():
    board = value_copy(fight14_fixture())
    board[0][0].keywords.append(rl.Keyword.character())
    sequence = value_copy(rl.selected_fight(board, rl.unit_id(0)))
    sequence.decline_epic_challenge(board)
    if board.command_points[0] != 3 or not sequence.can_choose_fight_kind(board, rl.FightKind.normal()):
        return False
    board[0].battle_socked = True
    return not rl.epic_source_valid(board, rl.unit_id(0))

# p.56: Precision expires at phase end, including retained model metadata.
def test_core15_epic_phase_expiry():
    board = value_copy(fight14_fixture())
    board[0][0].history.epic_challenge = True
    board.begin_phase(rl.BattlePhase.command())
    return not board[0][0].history.epic_challenge

# p.57: Smokescreen is only a start-of-opponent-Shooting window option.
def test_core15_smoke_window_target_and_expiry():
    board = value_copy(core15_fixture())
    board[1][0].keywords.append(rl.Keyword.smoke())
    if not rl.timing_rule_available(board, rl.TimingWindow.shooting_start(), True, rl.TimingRule.smokescreen()) or rl.timing_rule_available(board, rl.TimingWindow.shooting_end(), True, rl.TimingRule.smokescreen()) or rl.smoke_source_valid(board, False, rl.unit_id(0)):
        return False
    window = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.shooting_start()))
    window.choose_timing_rule(board, rl.TimingRule.smokescreen())
    window.smokescreen(board, rl.unit_id(1))
    if not window.is_done() or board.command_points[1] != 2 or (not board[1].phase_modifiers.smokescreen) or (not rl.smoke_cover_applies(board, board[0][0], rl.unit_id(1))):
        return False
    board.begin_phase(rl.BattlePhase.charge())
    return not board[1].phase_modifiers.smokescreen

# p.57 under circular-base approximation: an intervening smoke model grants
# cover to another target; moving it off the sight segment removes that cover.
def test_core15_smoke_intervening_base_cover():
    board = value_copy(core15_fixture())
    smoke = value_copy(board[1])
    smoke[0].position = board_position(9, 5)
    smoke.phase_modifiers.smokescreen = True
    board.units.append(smoke)
    if not rl.smoke_cover_applies(board, board[0][0], rl.unit_id(1)):
        return False
    board[2][0].position.y = 9
    return not rl.smoke_cover_applies(board, board[0][0], rl.unit_id(1))

# p.57: Smokescreen affects the actual per-bearer attack snapshot, never melee.
def test_core15_smoke_attack_cover_snapshot():
    board = value_copy(core15_fixture())
    board[1].phase_modifiers.smokescreen = True
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    info = rl.new('AttackSequenceInfo')
    ranged = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, info))
    melee = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 2))
    close = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), melee, info))
    return ranged.target_has_cover and (not close.target_has_cover)

# p.57: Counteroffensive needs two CP, opposing Fight phase and eligible unit.
def test_core15_counteroffensive_target_gates():
    board = value_copy(fight14_fixture())
    if not rl.counteroffensive_target_valid(board, True, rl.unit_id(1)) or rl.counteroffensive_target_valid(board, False, rl.unit_id(0)):
        return False
    board.command_points[1] = 1
    if rl.counteroffensive_available(board, True):
        return False
    board.command_points[1] = 2
    board[1].has_fought = True
    return not rl.counteroffensive_available(board, True)

# pp.40/57: after the current player's attacks, the opponent can grant Fights
# First to a remaining unit and must select it next, not a different friendly.
def test_core15_counteroffensive_forces_next_own_selection():
    board = value_copy(fight14_fixture())
    board[0].has_charged = True
    other = value_copy(board[1])
    other.identity = 0
    other[0].identity = 0
    other[0].position = board_position(7, 7)
    other[0].abilities.append(rl.AbilityKind.fight_first())
    board.units.append(other)
    if not rl.fight_unit_eligible(board, rl.unit_id(2)) or not rl.fight_first_unit(board[2]):
        return False
    sequence = value_copy(rl.fight_step(board, True))
    sequence.select_fighting_unit(board, rl.unit_id(0))
    sequence.choose_fight_kind(board, rl.FightKind.normal())
    core15_miss_attacks(sequence, board, rl.unit_id(0), rl.unit_id(1))
    if not sequence.can_counteroffensive(board, rl.unit_id(1)) or not board.current_decision_maker:
        return False
    sequence.counteroffensive(board, rl.unit_id(1))
    return board.command_points[1] == 1 and rl.fight_first_unit(board[1]) and sequence.can_select_fighting_unit(board, rl.unit_id(1)) and (not sequence.can_select_fighting_unit(board, rl.unit_id(2))) and (not sequence.can_pass_fight(board))

# p.57: declining Counteroffensive spends nothing and leaves normal alternation.
def test_core15_counteroffensive_decline():
    board = value_copy(fight14_fixture())
    sequence = value_copy(rl.fight_step(board, True))
    sequence.select_fighting_unit(board, rl.unit_id(0))
    sequence.choose_fight_kind(board, rl.FightKind.normal())
    core15_miss_attacks(sequence, board, rl.unit_id(0), rl.unit_id(1))
    sequence.decline_counteroffensive(board)
    return board.command_points[1] == 3 and sequence.can_select_fighting_unit(board, rl.unit_id(1)) and (not board[1].phase_modifiers.counteroffensive)

# p.58: battlefield, owner, live OC, shock/keywords and engagement gates.
def test_core15_action_start_membership_and_keywords():
    board = value_copy(core15_fixture())
    if not rl.action_start_valid(board, rl.unit_id(0), False) or rl.action_start_valid(board, rl.unit_id(0), True) or rl.action_start_valid(board, rl.unit_id(31), False):
        return False
    board[0][0].keywords.append(rl.Keyword.fortification())
    if rl.action_start_valid(board, rl.unit_id(0), False):
        return False
    board[0][0].keywords.clear()
    board[0][0].keywords.append(rl.Keyword.aircraft())
    return not rl.action_start_valid(board, rl.unit_id(0), False)

# p.58: start commits no CP, locks another start/charge and non-TITANIC shooting.
def test_core15_action_start_locks_and_completion():
    board = value_copy(core15_fixture())
    if not rl.begin_unit_action(board, rl.unit_id(0), False) or rl.begin_unit_action(board, rl.unit_id(0), False):
        return False
    if rl.shooting_unit_valid(board, rl.unit_id(0)) or rl.charge_source_valid(board, rl.unit_id(0), False):
        return False
    if not rl.complete_unit_action(board, rl.unit_id(0)) or rl.complete_unit_action(board, rl.unit_id(0)):
        return False
    return board[0].history.action_completed and board[0].history.action_started and (not board[0].history.action_pending) and (board.command_points[0] == 3)

# p.58: TITANIC bypasses engaged/action-start shooting bans, but not charge ban.
def test_core15_action_titanic_exceptions():
    board = value_copy(fight14_fixture())
    board[0].can_shoot = True
    board[0][0].keywords.append(rl.Keyword.titanic())
    board[0][0].keywords.append(rl.Keyword.vehicle())
    if not rl.begin_unit_action(board, rl.unit_id(0), False):
        return False
    return rl.shooting_kind_valid(board, rl.unit_id(0), rl.ShootingKind.close_quarters()) and (not rl.charge_source_valid(board, rl.unit_id(0), False))

# p.58: generic non-melee movement, even zero distance, fails pending action;
# Remain Stationary explicitly does not trigger movement (p.33).
def test_core15_action_move_interrupt_and_stationary_exception():
    board = value_copy(core15_fixture())
    rl.begin_unit_action(board, rl.unit_id(0), False)
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.stationary())
    if not rl.action_completion_valid(board, rl.unit_id(0)):
        return False
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.normal())
    return not rl.complete_unit_action(board, rl.unit_id(0)) and board[0].history.action_failed and (not board[0].history.action_completed)

# pp.9/58: Battle-shock at completion blocks the effect; earlier shock that
# has recovered does not permanently fail an otherwise uninterrupted action.
def test_core15_action_shock_completion_and_recovery():
    board = value_copy(core15_fixture())
    rl.begin_unit_action(board, rl.unit_id(0), False)
    board[0].battle_socked = True
    if rl.action_completion_valid(board, rl.unit_id(0)):
        return False
    board[0].battle_socked = False
    return rl.complete_unit_action(board, rl.unit_id(0))

# p.58: turn start unlocks a new start but keeps unfinished cross-turn actions.
def test_core15_action_cross_turn_pending_and_departure():
    board = value_copy(core15_fixture())
    rl.begin_unit_action(board, rl.unit_id(0), False)
    board.start_turn_history()
    if board[0].history.action_started or not board[0].history.action_pending or (not rl.action_completion_valid(board, rl.unit_id(0))):
        return False
    if not rl.reposition_unit(board, rl.unit_id(0)):
        return False
    return not rl.complete_unit_action(board, rl.unit_id(0)) and board.reserve_units[0].history.action_pending and board.reserve_units[0].history.action_failed

# pp.33/57–58: Advance alone does not prohibit Snap, but Fall Back and an
# action's general shooting ban still apply. TITANIC is explicitly excluded.
def test_core15_overwatch_printed_source_eligibility():
    board = value_copy(core15_fixture())
    board[1].history.advanced_this_turn = True
    if not rl.overwatch_source_valid(board, True, rl.unit_id(1)):
        return False
    board[1].history.fell_back_this_turn = True
    if rl.overwatch_source_valid(board, True, rl.unit_id(1)):
        return False
    board[1].history.fell_back_this_turn = False
    board[1].history.action_started = True
    if rl.overwatch_source_valid(board, True, rl.unit_id(1)):
        return False
    board[1].history.action_started = False
    board[1][0].keywords.append(rl.Keyword.titanic())
    return not rl.overwatch_source_valid(board, True, rl.unit_id(1))

# pp.34–35/57: all printed shooting types prohibit action starts until phase
# end; the restriction is independent of whether any weapon was selected.
def test_core15_all_shooting_phase_action_lock():
    board = value_copy(core15_fixture())
    board[0].history.shot_this_phase = True
    if rl.action_start_valid(board, rl.unit_id(0), False):
        return False
    board.begin_phase(rl.BattlePhase.charge())
    return rl.action_start_valid(board, rl.unit_id(0), False)

# pp.56/81: Explosives mortals allow the common per-wound Feel No Pain roll;
# the stratagem's six initial dice are not Command Re-roll eligible.
def test_core15_explosives_feel_no_pain():
    board = value_copy(core15_fixture())
    board[1][0].profile = rl.Profile.squighog_boyz()
    sequence = value_copy(rl.resolve_explosives(board, rl.unit_id(0)))
    sequence.choose_explosives_model(board, damage_test_model(0))
    sequence.choose_explosives_target(board, rl.unit_id(1))
    for i in range(6):
        sequence.roll(board, attack_test_die(1 + 3 * int(i == 0)))
    sequence.select_mortal_model(board, damage_test_model(0))
    if not sequence.can_roll(board, attack_test_die(5)):
        return False
    sequence.roll(board, attack_test_die(5))
    return sequence.is_done() and board[1][0].suffered_wounds == 0 and (board.command_points[1] == 3)

# p.56: simultaneous generated impact amounts both resolve even when source
# losses destroy the charger before the opposing losses are allocated.
def test_core15_crushing_source_death_does_not_cancel_enemy_mortals():
    board = value_copy(fight14_fixture())
    board.begin_phase(rl.BattlePhase.charge())
    board[0][0].keywords.append(rl.Keyword.vehicle())
    rl.record_charge_move(board, rl.unit_id(0))
    sequence = value_copy(rl.resolve_crushing_impact(board, rl.unit_id(0)))
    sequence.choose_impact_target(board, rl.unit_id(1))
    sequence.choose_impact_model(board, damage_test_model(0))
    sequence.roll(board, attack_test_die(1))
    sequence.roll(board, attack_test_die(1))
    sequence.roll(board, attack_test_die(5))
    sequence.roll(board, attack_test_die(5))
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.select_mortal_model(board, damage_test_model(0))
    if not board[0].models.empty() or not sequence.can_select_mortal_model(board, damage_test_model(0)):
        return False
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[1].models.empty() and (board[0].destroyed_models.value.size() == 1) and (board[1].destroyed_models.value.size() == 1)

# p.56: failed or cancelled charge declarations never expose Crushing Impact.
def test_core15_crushing_failed_charge_has_no_option():
    board = value_copy(charge13_fixture())
    board.begin_phase(rl.BattlePhase.charge())
    board[0][0].keywords.append(rl.Keyword.monster())
    sequence = value_copy(rl.charge(board, rl.unit_id(0), rl.ChargeKind.ordinary()))
    sequence.roll_pair(board, attack_test_die(1), attack_test_die(1))
    sequence.keep_it(board, True)
    sequence.cancel_charge(board)
    return sequence.is_done() and (not rl.crushing_source_valid(board, rl.unit_id(0))) and (board.command_points[0] == 3)

# p.58: Pile In/consolidation are explicitly exempt from action interruption.
def test_core15_action_pile_in_exempt_and_pending_round_trip():
    board = value_copy(fight14_fixture())
    board[0][0].keywords.append(rl.Keyword.titanic())
    if not rl.begin_unit_action(board, rl.unit_id(0), False):
        return False
    moving = value_copy(rl.melee_move(board, rl.unit_id(0), False, False))
    moving.select_melee_model(board, damage_test_model(0))
    moving.choose_melee_approach(board, rl.unit_id(1))
    moving.melee_waypoint(board, board_position(6, 5))
    moving.finish_melee_model(board)
    moving.finish_melee_move(board)
    text = value_copy(rl.to_string(board))
    restored = rl.new('Board')
    offset = value_copy(0)
    if not rl.from_string(restored, text, offset):
        return False
    return moving.completed and rl.action_completion_valid(restored, rl.unit_id(0)) and rl.complete_unit_action(restored, rl.unit_id(0)) and restored[0].history.action_completed

# p.58: the lower-level out-of-phase Move entry also fails pending actions,
# even when the ordinary Movement-phase record_move caller is absent.
def test_core15_action_direct_move_interrupt():
    board = value_copy(core15_fixture())
    rl.begin_unit_action(board, rl.unit_id(0), False)
    moving = value_copy(rl.move(board, rl.unit_id(0), 0))
    moving.move_to(board, rl.unit_id(0), board_position(6, 5))
    return moving.completed and board[0].history.action_failed and (not rl.complete_unit_action(board, rl.unit_id(0)))

# Supplied Fight on Death plus p.56: retained CHARACTER models remain valid
# Epic Challenge recipients when selected with their own unit.
def test_core15_epic_retained_character():
    board = value_copy(fight14_fixture())
    board[0][0].keywords.append(rl.Keyword.character())
    board[0][0].state = rl.ModelState.fight_on_death()
    board[0][0].suffered_wounds = 2
    board[0][0].destruction_pending = True
    sequence = value_copy(rl.selected_fight(board, rl.unit_id(0)))
    sequence.epic_challenge(board)
    return sequence.can_choose_epic_character(board, damage_test_model(0))

# p.58: one start per turn permits another action in a later turn while an
# earlier mission action is still pending. Complete each by its own turn stamp.
def test_core15_actions_overlap_across_turns_without_aliasing():
    board = value_copy(core15_fixture())
    rl.begin_unit_action(board, rl.unit_id(0), False)
    first = value_copy(board[0].history.action_records[0].started_turn)
    board.start_turn_history()
    if not rl.action_start_valid(board, rl.unit_id(0), False) or not rl.begin_unit_action(board, rl.unit_id(0), False):
        return False
    second = value_copy(board[0].history.action_records[1].started_turn)
    if first == second or not rl.complete_unit_action(board, rl.unit_id(0), first) or (not board[0].history.action_pending) or rl.complete_unit_action(board, rl.unit_id(0), first):
        return False
    return rl.complete_unit_action(board, rl.unit_id(0), second) and (not board[0].history.action_pending)

# p.58 bounded save infrastructure: zero/duplicate action handles and conflicting
# completion flags are rejected rather than redirecting a mission's effect.
def test_core15_malformed_action_history_rejected():
    board = value_copy(core15_fixture())
    rl.begin_unit_action(board, rl.unit_id(0), False)
    if not rl.valid_state_foundations(board):
        return False
    board[0].history.action_records[0].started_turn = 0
    if rl.valid_state_foundations(board):
        return False
    board[0].history.action_records[0].started_turn = 1
    board[0].history.action_records[0].completed = True
    return not rl.valid_state_foundations(board)

# Supplied appendix 01.02.04 / core pp.30/68: full-strength shocked reserves recover.
def test_offboard_command_shocked_reserve_recovers():
    board = rl.new('Board')
    board.reserve_units.append(rl.make_infernus_squad())
    board.reserve_units[0].capture_starting_strength()
    board.reserve_units[0].battle_socked = True
    step = value_copy(rl.battle_shock_step(board))
    three = rl.new('Dice')
    assign(three, 3)
    if not step.can_roll_pair(board, three, three):
        return False
    step.roll_pair(board, three, three)
    return step.is_done() and (not board.reserve_units[0].battle_socked)

# Supplied appendix 01.02.04 / core pp.30/86: exact half reserves also test.
def test_offboard_command_half_reserve_fails():
    board = rl.new('Board')
    board.reserve_units.append(rl.make_octavius())
    board.reserve_units[0].capture_starting_strength()
    board.reserve_units[0][0].suffered_wounds = 3
    step = value_copy(rl.battle_shock_step(board))
    one = rl.new('Dice')
    assign(one, 1)
    if not step.can_roll_pair(board, one, one):
        return False
    step.roll_pair(board, one, one)
    return step.is_done() and board.reserve_units[0].battle_socked

# Supplied appendix 01.02.04: our Command does not test healthy/foreign/empty reserves.
def test_offboard_command_skips_ineligible_reserves():
    board = rl.new('Board')
    board.reserve_units.append(rl.make_infernus_squad())
    board.reserve_units[0].capture_starting_strength()
    board.reserve_units.append(rl.make_tantus())
    board.reserve_units[1].owned_by_player1 = True
    board.reserve_units[1].battle_socked = True
    board.reserve_units.resize(3)
    step = value_copy(rl.battle_shock_step(board))
    return step.is_done() and board.reserve_units[1].battle_socked

# Supplied appendix 01.02.04: each battlefield/offboard unit tests exactly once.
def test_offboard_command_tests_battlefield_then_reserve():
    board = rl.new('Board')
    board.units.append(rl.make_infernus_squad())
    board[0].battle_socked = True
    board.reserve_units.append(rl.make_infernus_squad())
    board.reserve_units[0].battle_socked = True
    step = value_copy(rl.battle_shock_step(board))
    three = rl.new('Dice')
    assign(three, 3)
    step.roll_pair(board, three, three)
    if step.is_done() or board[0].battle_socked or (not board.reserve_units[0].battle_socked):
        return False
    step.roll_pair(board, three, three)
    return step.is_done() and (not board.reserve_units[0].battle_socked)

# 23.01 p.74: mandatory Aircraft reserves do not depend on optional points choices.
def test_aircraft16_mandatory_formations_reserves():
    board = rl.new('Board')
    board.reserve_units.append(rl.make_infernus_squad())
    board.reserve_units.append(rl.make_tantus())
    board.reserve_units[1][0].keywords.append(rl.Keyword.aircraft())
    board.reserve_units[1].owned_by_player1 = True
    rl.reserve_aircraft_for_formations(board)
    return not board.reserve_units[0].history.strategic_reserve and board.reserve_units[1].history.strategic_reserve and rl.deployment_complete(board, True)

# 23.02 p.74: Aircraft have no Stationary/Normal/Advance/Fall Back moves.
def test_aircraft16_only_ingress_move():
    board = value_copy(movement11_fixture())
    board[0][0].keywords.append(rl.Keyword.aircraft())
    return not rl.battlefield_move_eligible(board, rl.unit_id(0), rl.MovementKind.stationary()) and (not rl.battlefield_move_eligible(board, rl.unit_id(0), rl.MovementKind.normal())) and (not rl.battlefield_move_eligible(board, rl.unit_id(0), rl.MovementKind.advance())) and (not rl.battlefield_move_eligible(board, rl.unit_id(0), rl.MovementKind.ordered_retreat())) and rl.movement_selection_complete(board, False)

# 23.02 p.74: round-one deferral consumes selection, never a Stationary move.
def test_aircraft16_reserve_deferral_does_not_stall():
    board = rl.new('Board')
    board.reserve_units.append(rl.make_tantus())
    board.reserve_units[0][0].keywords.append(rl.Keyword.aircraft())
    phase = value_copy(rl.movement_phase(board))
    phase.select_reserve_unit(board, rl.unit_id(0))
    if phase.can_reserve_remain_stationary(board) or not phase.can_defer_aircraft_ingress(board) or phase.can_place_at(board, board_position(5, 5)):
        return False
    phase.defer_aircraft_ingress(board)
    if not phase.can_end_move(board):
        return False
    phase.end_move(board)
    return phase.is_done() and (not board.reserve_units[0].has_moved) and (not board.reserve_units[0].history.has_ingressed)

# 23.02 p.74: solely Aircraft engagement permits Normal and Advance.
def test_aircraft16_engagement_exception():
    board = value_copy(fight14_fixture())
    board[1][0].keywords.append(rl.Keyword.aircraft())
    if not board.is_in_melee(board[0]) or not rl.battlefield_move_eligible(board, rl.unit_id(0), rl.MovementKind.normal()) or (not rl.battlefield_move_eligible(board, rl.unit_id(0), rl.MovementKind.advance())):
        return False
    board[1][0].keywords.clear()
    return not rl.battlefield_move_eligible(board, rl.unit_id(0), rl.MovementKind.normal())

# 23.04 p.74: Aircraft source melee requires a FLYING target unit.
def test_aircraft16_melee_source_requires_flying_target():
    board = value_copy(fight14_fixture())
    board[0][0].keywords.append(rl.Keyword.aircraft())
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), True):
        return False
    board[1][0].keywords.append(rl.Keyword.fly())
    return rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), True)

# 23.02 p.74 / appendix 01.02.02: only opponent Aircraft depart; effects survive.
def test_aircraft16_opponent_turn_end_preserves_state():
    board = value_copy(fight14_fixture())
    board[0][0].keywords.append(rl.Keyword.aircraft())
    board[1][0].keywords.append(rl.Keyword.aircraft())
    board[1].battle_socked = True
    board[1].history.advanced_this_turn = True
    identity = value_copy(board[1].identity)
    rl.return_opponent_aircraft(board)
    return board.reserve_units.size() == 1 and board.reserve_units[0].identity == identity and board.reserve_units[0].battle_socked and board.reserve_units[0].history.advanced_this_turn and board.reserve_units[0].history.repositioned and board[1].empty() and board[1].retired and (not board[0].empty()) and rl.valid_state_foundations(board)

# pp.68–69/74: repeated ingress restores the same slot and all identities.
def test_aircraft16_repeated_ingress_reuses_slot():
    board = value_copy(movement11_fixture())
    board.current_round = 2
    board[0][0].keywords.append(rl.Keyword.aircraft())
    identity = value_copy(board[0].identity)
    for repetition in range(5):
        if not rl.reposition_unit(board, rl.unit_id(0)) or not rl.battlefield_entry_available(board, board.reserve_units[0]):
            return False
        rl.enter_from_reserves(board, rl.unit_id(0), board_position(5, 10), rl.MovementKind.ingress())
        if board.units.size() != 1 or board[0].identity != identity or board.reserve_units.size() != 0 or (not rl.valid_state_foundations(board)):
            return False
    return True

# pp.73–74: one grounded target suffices; either Aircraft unit excludes Plunging Fire.
def test_aircraft16_plunging_fire_exclusions_and_bounds():
    board = value_copy(shooting12_fixture())
    board[0][0].geometry.elevation = 3
    if not rl.plunging_fire_applies(board, rl.unit_id(0), 0, rl.unit_id(1), True) or rl.plunging_fire_applies(board, rl.unit_id(0), 0, rl.unit_id(1), False):
        return False
    board[0][0].keywords.append(rl.Keyword.aircraft())
    if rl.plunging_fire_applies(board, rl.unit_id(0), 0, rl.unit_id(1), True):
        return False
    board[0][0].keywords.clear()
    board[1][0].keywords.append(rl.Keyword.aircraft())
    if rl.plunging_fire_applies(board, rl.unit_id(0), 0, rl.unit_id(1), True):
        return False
    board[1][0].keywords.clear()
    for elevated_target in range(board[1].models.size()):
        board[1][elevated_target].geometry.elevation = 1
    return not rl.plunging_fire_applies(board, rl.unit_id(0), 0, rl.unit_id(1), True)

# Task16 metadata/movement regressions: core pp.64–65/68–69/73–74/84;
# supplied appendix01.02.02/01.02.04 and user no-nesting assumption.
# Explicit metadata fixtures do not assert any actual faction transport grant
# (datasheets task17); capacities/types belong to each carrier model (p.64).
def transport16_fixture():
    board = rl.new('Board')
    board.units.append(rl.make_octavius())
    board[0][0].position = board_position(10, 10)
    board[0][0].keywords.append(rl.Keyword.transport())
    board[0][0].keywords.append(rl.Keyword.vehicle())
    board[0][0].transport_permissions_known = True
    board[0][0].transport_capacity = 6
    board[0][0].permitted_passenger_keywords.append(rl.Keyword.infantry())
    board.units.append(rl.make_infernus_squad())
    board[1].models.resize(2)
    board[1][0].position = board_position(12, 10)
    board[1][1].position = board_position(12, 12)
    board[1].capture_starting_strength()
    board.identify_units()
    board.begin_phase(rl.BattlePhase.movement())
    rl.record_move(board, rl.unit_id(1), rl.MovementKind.normal())
    return value_copy(board)

# Bounded fixture constructor for supplied explicit values (pp.64/81/84);
# this encodes test metadata, not a claim about any faction datasheet.
def transport16_fixed_stat(number):
    value = rl.new('FixedStat')
    assign(value, number)
    return value_copy(value)

# p.64: whole-unit permission and exact per-model seats, including weighted models.
def test_transport16_capacity_permissions_and_seat_bounds():
    board = value_copy(transport16_fixture())
    if not rl.transport_can_carry(board, board[1], board[0], 0):
        return False
    board[0][0].transport_capacity = 1
    if rl.transport_can_carry(board, board[1], board[0], 0):
        return False
    board[0][0].transport_capacity = 3
    board[1][0].transport_space = 2
    if not rl.transport_can_carry(board, board[1], board[0], 0):
        return False
    board[0][0].forbidden_passenger_keywords.append(rl.Keyword.infantry())
    if rl.transport_can_carry(board, board[1], board[0], 0):
        return False
    board[0][0].forbidden_passenger_keywords.clear()
    board[0][0].transport_permissions_known = False
    return not rl.transport_can_carry(board, board[1], board[0], 0)

# p.64: only permitted moves, every base within3, no setup this turn.
def test_transport16_embark_move_and_setup_gates():
    board = value_copy(transport16_fixture())
    passenger = value_copy(rl.unit_id(1))
    carrier = value_copy(rl.unit_id(0))
    model = value_copy(damage_test_model(0))
    if not rl.embark_after_move_valid(board, passenger, carrier, model):
        return False
    board[1].history.was_set_up_this_turn = True
    if rl.embark_after_move_valid(board, passenger, carrier, model):
        return False
    board[1].history.was_set_up_this_turn = False
    board[1].history.move_kind = rl.MovementKind.stationary()
    if rl.embark_after_move_valid(board, passenger, carrier, model):
        return False
    board[1].history.move_kind = rl.MovementKind.advance()
    board[1][1].position = board_position(20, 20)
    return not rl.embark_after_move_valid(board, passenger, carrier, model)

# pp.58/64 and appendix01.02.02: embarking fails actions, preserves identity,
# shock/effects and weapon usage, and retires its slot without duplicating IDs.
def test_transport16_embark_preserves_identity_and_effects():
    board = value_copy(transport16_fixture())
    if not rl.begin_unit_action(board, rl.unit_id(1), False):
        return False
    board[1].battle_socked = True
    board[1][0].used_once_per_battle_weapon[0] = True
    identity = value_copy(board[1].identity)
    bearer = value_copy(board[1][0].identity)
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    return board[1].empty() and board[1].retired and (board.embarked_units.size() == 1) and (board.embarked_units[0].identity == identity) and (board.embarked_units[0][0].identity == bearer) and board.embarked_units[0].battle_socked and board.embarked_units[0][0].used_once_per_battle_weapon[0] and board.embarked_units[0].history.action_failed and (rl.passenger_space_used(board, board[0][0].identity) == 2) and rl.valid_state_foundations(board)

# p.64: carrier MODEL identities survive compaction within a multi-model unit.
def test_transport16_carrier_identity_survives_model_compaction():
    board = value_copy(transport16_fixture())
    second_carrier = value_copy(board[0][0])
    second_carrier.identity = 0
    second_carrier.position = board_position(10, 12)
    board[0].models.append(second_carrier)
    board.identify_units()
    carrier_identity = value_copy(board[0][1].identity)
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(1))
    board[0].remove_model(0)
    location = value_copy(rl.find_passenger_carrier(board, carrier_identity))
    return location.found and location.model.get() == 0 and (board.embarked_units[0].embarked_transport == carrier_identity) and rl.valid_state_foundations(board)

# Supplied appendix01.02.04: passengers have no foreign visibility/ranges,
# but retain self visibility/own ability range. Their old bases block no setup.
def test_transport16_offboard_visibility_distance_and_collision():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    return not rl.unit_visible_to_unit(board, board[0], board.embarked_units[0]) and (not rl.unit_visible_to_unit(board, board.embarked_units[0], board[0])) and rl.unit_visible_to_unit(board, board.embarked_units[0], board.embarked_units[0]) and (board.embarked_units[0][0].distance(board[0][0]) > 100.0) and (board.embarked_units[0][0].distance(board.embarked_units[0][0]) == 0.0)

# Appendix01.02.04 / p.30: embarked units test and recover in Command.
def test_transport16_embarked_command_recovery():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    board.embarked_units[0].battle_socked = True
    board.begin_phase(rl.BattlePhase.command())
    step = value_copy(rl.battle_shock_step(board))
    three = rl.new('Dice')
    assign(three, 3)
    step.roll_pair(board, three, three)
    return step.is_done() and (not board.embarked_units[0].battle_socked)

# Appendix01.02.02: phase effects expire offboard; shock/turn restrictions
# survive phase changes and One Shot survives both phase and turn resets.
def test_transport16_offboard_expiry_uses_original_duration():
    board = value_copy(transport16_fixture())
    board[1].battle_socked = True
    board[1].phase_modifiers.smokescreen = True
    board[1][0].used_once_per_battle_weapon[0] = True
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    board.embarked_units[0].history.deck_shooting_locked = True
    board.begin_phase(rl.BattlePhase.shooting())
    if board.embarked_units[0].phase_modifiers.smokescreen or not board.embarked_units[0].history.deck_shooting_locked or (not board.embarked_units[0].battle_socked):
        return False
    board.start_turn_history()
    return not board.embarked_units[0].history.deck_shooting_locked and board.embarked_units[0].battle_socked and board.embarked_units[0][0].used_once_per_battle_weapon[0]

# p.65: same-phase embark/Advance/Fall Back forbid exit; reserved carrier does too.
def test_transport16_disembark_phase_and_carrier_gates():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    if rl.passenger_can_disembark(board, rl.unit_id(0)):
        return False
    board.begin_phase(rl.BattlePhase.movement())
    if not rl.passenger_can_disembark(board, rl.unit_id(0)):
        return False
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.advance())
    if rl.passenger_can_disembark(board, rl.unit_id(0)):
        return False
    if not rl.reposition_unit(board, rl.unit_id(0)):
        return False
    return not rl.passenger_can_disembark(board, rl.unit_id(0)) and board.embarked_units.size() == 1

# p.65: wholly within tests the farthest base point, not minimal base distance.
def test_transport16_wholly_within_full_base_boundary():
    board = value_copy(transport16_fixture())
    board[1][0].profile = board[0][0].profile
    board[1][0].position = board_position(13, 10)
    if not rl.passenger_wholly_within(board[1][0], board[0][0], 3):
        return False
    board[1][0].position = board_position(14, 10)
    return board[1][0].distance(board[0][0]) < 3.0 and (not rl.passenger_wholly_within(board[1][0], board[0][0], 3))

# p.65: mandatory modes choose Rapid after Normal, otherwise Tactical if legal.
def test_transport16_mode_priority_and_exact_grid_search():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    board.begin_phase(rl.BattlePhase.movement())
    carrier = value_copy(rl.find_passenger_carrier(board, board.embarked_units[0].embarked_transport))
    if not rl.required_disembark_mode(board, board.embarked_units[0], carrier) == rl.DisembarkMode.tactical():
        return False
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.normal())
    return rl.required_disembark_mode(board, board.embarked_units[0], carrier) == rl.DisembarkMode.rapid() and rl.transport_has_setup(board, board.embarked_units[0], carrier, rl.DisembarkMode.rapid(), -1)

# p.65: Rapid copies actual carrier ingress restrictions, not passenger Deep Strike.
def test_transport16_rapid_inherits_carrier_ingress_rules():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    board.begin_phase(rl.BattlePhase.movement())
    board[0].history.ingress_turn = board.turn_serial.value + 1
    board[0].history.ingress_used_deep_strike = False
    carrier = value_copy(rl.find_passenger_carrier(board, board.embarked_units[0].embarked_transport))
    candidate = value_copy(board.embarked_units[0])
    rl.mark_unit_offboard(candidate, False)
    candidate[0].abilities.append(rl.AbilityKind.deep_strike())
    candidate[1].abilities.append(rl.AbilityKind.deep_strike())
    candidate[0].position = board_position(12, 10)
    candidate[1].position = board_position(12, 12)
    if rl.transport_setup_valid(board, candidate, carrier, rl.DisembarkMode.rapid(), -1):
        return False
    board[0].history.ingress_used_deep_strike = True
    return rl.transport_setup_valid(board, candidate, carrier, rl.DisembarkMode.rapid(), -1)

# p.65: Tactical requires Normal/Advance afterwards; Stationary is forbidden.
def test_transport16_tactical_requires_followup_move():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    board.begin_phase(rl.BattlePhase.movement())
    sequence = value_copy(rl.disembark(board, rl.unit_id(0)))
    sequence.confirm_disembark_mode(board, rl.DisembarkMode.tactical())
    sequence.use_legal_disembark_setup(board)
    if sequence.can_remain_stationary(board) or not sequence.can_normal_move(board) or (not sequence.can_advance(board, True)):
        return False
    sequence.normal_move(board)
    sequence.finish_move(board)
    return sequence.is_done() and board.embarked_units.size() == 0 and board[1].history.disembarked_this_turn and (board[1].history.move_kind == rl.MovementKind.normal()) and rl.valid_state_foundations(board)

# p.65: Rapid completes setup, forbids charge, and preserves original slot.
def test_transport16_rapid_action_reuses_passenger_slot():
    board = value_copy(transport16_fixture())
    identity = value_copy(board[1].identity)
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    board.begin_phase(rl.BattlePhase.movement())
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.normal())
    sequence = value_copy(rl.disembark(board, rl.unit_id(0)))
    if sequence.can_confirm_disembark_mode(board, rl.DisembarkMode.combat()):
        return False
    sequence.confirm_disembark_mode(board, rl.DisembarkMode.rapid())
    sequence.use_legal_disembark_setup(board)
    return sequence.is_done() and board[1].identity == identity and (not board[1].can_charge) and board[1].history.was_set_up_this_turn and (not board[1].off_battlefield) and (board.units.size() == 2) and rl.valid_state_foundations(board)

# p.68: passengers add to reserve points and share carrier deadline.
def test_transport16_reserve_points_include_passengers():
    board = value_copy(transport16_fixture())
    board.battle_points_limit = 400
    board[0].points_known = True
    board[0].points = 100
    board[1].points_known = True
    board[1].points = 101
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    if not rl.reposition_unit(board, rl.unit_id(0)):
        return False
    board.reserve_units[0].history.strategic_reserve = False
    if rl.strategic_reserve_valid(board, False, rl.unit_id(0)):
        return False
    board.embarked_units[0].points = 100
    if not rl.strategic_reserve_valid(board, False, rl.unit_id(0)):
        return False
    board.embarked_units[0].points_known = False
    return not rl.strategic_reserve_valid(board, False, rl.unit_id(0))

# p.68–69: undeployed reserved passengers perish with their carrier, without ingress.
def test_transport16_passengers_share_reserve_deadline():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    if not rl.reposition_unit(board, rl.unit_id(0)):
        return False
    board.reserve_units[0].history.repositioned = False
    board.current_round = 2
    rl.expire_unused_reserves(board)
    return board.reserve_units.empty() and board.embarked_units.empty() and (board.expired_reserves.value.size() == 2)

# p.84: Dedicated Transport Scouts require every passenger and uniform values.
def test_transport16_dedicated_transport_scouts_permission():
    board = value_copy(transport16_fixture())
    board[0][0].keywords.append(rl.Keyword.dedicated_transport())
    board[0][0].position = board_position(10, 26)
    board[1][0].position = board_position(12, 26)
    board[1][1].position = board_position(12, 28)
    board[1][0].scout_distances.append(transport16_fixed_stat(6))
    board[1][1].scout_distances.append(transport16_fixed_stat(6))
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    if rl.transport_scouts_distance(board, board[0]) != 6:
        return False
    board.embarked_units[0][1].scout_distances.clear()
    return rl.transport_scouts_distance(board, board[0]) == 0

# Save infrastructure p.64: dangling/overfilled/foreign passenger links are rejected.
def test_transport16_invalid_passenger_links_rejected():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    board[0][0].transport_capacity = 1
    if rl.valid_state_foundations(board):
        return False
    board[0][0].transport_capacity = 6
    board.embarked_units[0].owned_by_player1 = True
    if rl.valid_state_foundations(board):
        return False
    board.embarked_units[0].owned_by_player1 = False
    board.embarked_units[0].embarked_transport = 16000
    return not rl.valid_state_foundations(board)

# p.64: qualifying out-of-phase moves can embark too, with source-controller
# decisions, caller restoration, and no prebattle Scouts embark exception.
def test_transport16_out_of_phase_embark_owner_and_prebattle_gate():
    board = value_copy(transport16_fixture())
    board.current_player = True
    board.current_decision_maker = True
    board.timing.phase = rl.BattlePhase.shooting()
    if not rl.has_embark_choice(board, rl.unit_id(1)):
        return False
    sequence = value_copy(rl.post_move_embark(board, rl.unit_id(1)))
    if board.current_decision_maker or not sequence.can_choose_embark_transport(board, rl.unit_id(0)):
        return False
    sequence.decline_embark(board)
    if not sequence.is_done() or not board.current_decision_maker:
        return False
    board.prebattle_scouts = True
    return not rl.has_embark_choice(board, rl.unit_id(1))

# p.64: prebattle formation choices are whole-unit decisions and preserve IDs.
def test_transport16_formation_action_starts_embarked():
    board = value_copy(transport16_fixture())
    board.reserve_units.append(board[0])
    board.reserve_units.append(board[1])
    board.units.clear()
    board.timing.phase = rl.BattlePhase.none()
    board.identify_units()
    identity = value_copy(board.reserve_units[1].identity)
    sequence = value_copy(rl.declare_transport_passengers(board))
    sequence.choose_formation_passenger(board, rl.unit_id(1))
    sequence.choose_formation_transport(board, rl.unit_id(0))
    sequence.choose_formation_carrier_model(board, damage_test_model(0))
    sequence.finish_transport_formations(board)
    return sequence.is_done() and board.embarked_units.size() == 1 and (board.embarked_units[0].identity == identity) and (board.reserve_units.size() == 1) and rl.valid_state_foundations(board)

# p.65: Combat becomes compulsory when enemy engagement blocks all Tactical
# placements; only enemies actually engaged with the carrier are allowed.
def test_transport16_combat_priority_and_enemy_permissions():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    enemies = value_copy(rl.make_infernus_squad())
    enemies.models.resize(4)
    enemies.owned_by_player1 = True
    enemies[0].position = board_position(7, 10)
    enemies[1].position = board_position(13, 10)
    enemies[2].position = board_position(10, 7)
    enemies[3].position = board_position(10, 13)
    board.units.append(enemies)
    board.identify_units()
    board.begin_phase(rl.BattlePhase.movement())
    carrier = value_copy(rl.find_passenger_carrier(board, board.embarked_units[0].embarked_transport))
    if not rl.required_disembark_mode(board, board.embarked_units[0], carrier) == rl.DisembarkMode.combat():
        return False
    sequence = value_copy(rl.disembark(board, rl.unit_id(0)))
    sequence.confirm_disembark_mode(board, rl.DisembarkMode.combat())
    sequence.roll(board, attack_test_die(3))
    sequence.roll(board, attack_test_die(3))
    sequence.use_legal_disembark_setup(board)
    return sequence.is_done() and board[1].battle_socked and (not board[1].can_charge) and board.is_in_melee(board[1]) and rl.valid_state_foundations(board)

# p.64 datasheet permissions must reject forbidden transport passengers before
# the user-directed no-nested-transports assertion can fire during enumeration.
def test_transport16_type_rejection_precedes_nesting_assertion():
    board = value_copy(transport16_fixture())
    outer = value_copy(board[0])
    outer.identity = 0
    outer[0].identity = 0
    outer[0].position = board_position(10, 15)
    outer[0].forbidden_passenger_keywords.append(rl.Keyword.transport())
    board.units.append(outer)
    board.identify_units()
    return not rl.transport_can_carry(board, board[0], board[2], 0) and rl.valid_state_foundations(board)
# pp.73–74: TOWERING range is inclusive12 and skill improvements coexist
# with cover; Aircraft exclusions are checked before grouping attack profiles.
def test_aircraft16_towering_plunging_range_and_skill():
    board = value_copy(shooting12_fixture())
    board[0][0].position = board_position(5, 5)
    board[1][0].position = board_position(17, 5)
    board[0][0].keywords.append(rl.Keyword.towering())
    if not rl.plunging_fire_applies(board, rl.unit_id(0), 0, rl.unit_id(1), True):
        return False
    board[1][0].position = board_position(20, 5)
    if rl.plunging_fire_applies(board, rl.unit_id(0), 0, rl.unit_id(1), True):
        return False
    info = rl.new('AttackSequenceInfo')
    info.source = rl.Weapon.captain_storm_bolter()
    info.plunging_fire = True
    improved = value_copy(rl.effective_attack_skill(board, info))
    info.target_has_cover = True
    return improved == rl.max(2, info.source.skill() - 1) and rl.effective_attack_skill(board, info) == info.source.skill()

# Emergency lifecycle regressions: hazards/setup before carrier demise/removal
# (core pp.64–65/80/87; supplied offboard appendix01.02.04).
# p.65: emergency precedes carrier Deadly Demise, including hazard choices.
def test_transport16_emergency_before_deadly_demise():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    board[0][0].has_deadly_demise = True
    board[0][0].deadly_demise = transport16_fixed_stat(1)
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(0), False, False, 6, board[0][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 6, False)
    jobs = rl.new('DamageJobs')
    sequence = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    sequence.choose_destruction_unit(board, rl.unit_id(0))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    if not sequence.can_choose_emergency_passenger(board, rl.unit_id(0)):
        return False
    sequence.choose_emergency_passenger(board, rl.unit_id(0))
    three = rl.new('Dice')
    assign(three, 3)
    sequence.roll(board, three)
    if board.embarked_units.size() != 0 or not board[1].off_battlefield:
        return False
    sequence.roll(board, three)
    one = rl.new('Dice')
    assign(one, 1)
    if board[1].off_battlefield or not board[1].battle_socked or board[1].can_charge or (not sequence.can_roll(board, one)):
        return False
    sequence.roll(board, one)
    return sequence.is_done() and board[0].empty() and (board[1].models.size() == 2) and rl.valid_state_foundations(board)

# p.64–65: even a carrier without Deadly Demise is retained for emergency exit.
def test_transport16_emergency_retains_plain_carrier():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(0), False, False, 6, board[0][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 6, False)
    return board[0][0].destruction_pending and rl.carrier_has_passengers(board, board[0][0].identity)

# p.65: no legal supported placement destroys passengers instead of stalling.
def test_transport16_emergency_unplaceable_models_destroyed():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    board.terrain_geometry.append(geometry_box(0, 0, 0, rl.BOARD_WIDTH, rl.BOARD_HEIGHT, 20))
    carrier = value_copy(rl.find_passenger_carrier(board, board.embarked_units[0].embarked_transport))
    original = value_copy(board.embarked_units[0])
    candidate = rl.new('Unit')
    rl.arrange_emergency_survivors(board, original, candidate, carrier, -1)
    return candidate.empty()

# p.65: hazards allocate before placing passengers; one failed infantry roll
# inflicts one mortal, then survivors are shocked with the charge ban.
def test_transport16_emergency_hazard_damage_before_setup():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(0), False, False, 6, board[0][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 6, False)
    jobs = rl.new('DamageJobs')
    sequence = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    sequence.choose_destruction_unit(board, rl.unit_id(0))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    sequence.choose_emergency_passenger(board, rl.unit_id(0))
    sequence.roll(board, attack_test_die(1))
    sequence.roll(board, attack_test_die(3))
    if not board[1].off_battlefield or not sequence.can_select_mortal_model(board, damage_test_model(0)):
        return False
    sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and (not board[1].off_battlefield) and (board[1][0].suffered_wounds == 1) and board[1].battle_socked and (not board[1].can_charge) and rl.valid_state_foundations(board)

# p.65: actual emergency resolution archives every unplaceable survivor and
# completes the carrier's removal, rather than hanging at a setup choice.
def test_transport16_emergency_unplaceable_resolution_archives():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    board.terrain_geometry.append(geometry_box(0, 0, 0, rl.BOARD_WIDTH, rl.BOARD_HEIGHT, 20))
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(0), False, False, 6, board[0][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 6, False)
    jobs = rl.new('DamageJobs')
    sequence = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    sequence.choose_destruction_unit(board, rl.unit_id(0))
    sequence.resolve_destruction_model(board, damage_test_model(0))
    sequence.choose_emergency_passenger(board, rl.unit_id(0))
    sequence.roll(board, attack_test_die(3))
    sequence.roll(board, attack_test_die(3))
    return sequence.is_done() and board[0].empty() and board[1].empty() and (board[1].destroyed_models.value.size() == 2) and board.embarked_units.empty() and rl.valid_state_foundations(board)

# Firing Deck regressions: per-model X, weapon attribution and passenger
# turn-long shooting restrictions (24.14 p.81).
# p.81: Firing Deck counts chosen models per carrier and excludes already-shot units.
def test_transport16_firing_deck_model_limits():
    board = value_copy(transport16_fixture())
    board[0][0].firing_deck = 1
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    selected = rl.new('DeckSelections')
    if not rl.deck_passenger_valid(board, rl.unit_id(0), damage_test_model(0), rl.unit_id(0), damage_test_model(0), selected):
        return False
    choice = rl.new('DeckSelection')
    choice.carrier = board[0][0].identity
    choice.passenger_model = board.embarked_units[0][0].identity
    selected.append(choice)
    if rl.deck_passenger_valid(board, rl.unit_id(0), damage_test_model(0), rl.unit_id(0), damage_test_model(1), selected):
        return False
    selected.clear()
    board.embarked_units[0].history.shot_this_phase = True
    return not rl.deck_passenger_valid(board, rl.unit_id(0), damage_test_model(0), rl.unit_id(0), damage_test_model(0), selected)

# p.81: ONE SHOT is excluded, weapons are attributed to the carrier, and
# physical passenger/carrier weapon slots and One Shot usage stay untouched.
def test_transport16_firing_deck_weapon_provenance():
    board = value_copy(transport16_fixture())
    board[0][0].firing_deck = 1
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    declarations = rl.new('DeclaredWeapons')
    if not rl.deck_weapon_valid(board, rl.unit_id(0), damage_test_model(0), rl.unit_id(0), damage_test_model(0), 0, declarations):
        return False
    weapon = value_copy(rl.make_deck_declaration(board, rl.unit_id(0), damage_test_model(0), rl.unit_id(0), damage_test_model(0), 0))
    if weapon.model_identity != board[0][0].identity or weapon.weapon.value != board.embarked_units[0][0].weapons[0].value:
        return False
    board.embarked_units[0][0].additional_weapon_rules[0].append(rl.weapon_rule(rl.WeaponRuleKind.one_shot()))
    return not rl.deck_weapon_valid(board, rl.unit_id(0), damage_test_model(0), rl.unit_id(0), damage_test_model(0), 0, declarations) and (not board.embarked_units[0][0].used_once_per_battle_weapon[0])

# p.81: even unselected passengers are locked until turn end, including after exit.
def test_transport16_firing_deck_locks_all_passengers():
    board = value_copy(transport16_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    rl.lock_deck_passengers(board, board[0][0].identity)
    slot = value_copy(rl.stage_disembarking_passenger(board, rl.unit_id(0)))
    rl.finish_disembark(board, slot, rl.DisembarkMode.rapid())
    if rl.shooting_unit_valid(board, slot) or not board[slot].history.deck_shooting_locked:
        return False
    board.begin_phase(rl.BattlePhase.fight())
    if not board[slot].history.deck_shooting_locked:
        return False
    board.start_turn_history()
    return not board[slot].history.deck_shooting_locked

# p.81: deck selection appends temporary declarations through explicit
# passenger/model/weapon decisions and consumes X without consuming One Shot.
def test_transport16_firing_deck_action_selection():
    board = value_copy(transport16_fixture())
    board[0][0].firing_deck = 1
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    declarations = rl.new('DeclaredWeapons')
    sequence = value_copy(rl.select_firing_deck(board, declarations, rl.unit_id(0)))
    sequence.select_firing_deck_passenger(board, declarations, rl.unit_id(0))
    sequence.select_firing_deck_model(board, declarations, damage_test_model(0))
    slot = rl.new('BInt<0, MAX_WEAPONS>')
    assign(slot, 0)
    sequence.select_firing_deck_weapon(board, declarations, slot)
    sequence.finish_firing_deck(board, declarations)
    return sequence.is_done() and declarations.size() == 1 and (declarations[0].model_identity == board[0][0].identity) and board.embarked_units[0].history.deck_shooting_locked and (not board.embarked_units[0][0].used_once_per_battle_weapon[0])

# Appendix02.02.01/02.02.03: fixed A uses bearer/profile arithmetic before
# declaration and random A/D preserve their original dice until after re-rolls.
def test_orks17c2b2_modified_melee_shares():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.choppa()
    board[0][0].characteristic_modifiers.append(rl.weapon_characteristic_modifier(rl.ModifiedCharacteristic.attacks(), rl.ModifierOperation.add(), 2, 0))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    count = value_copy(rl.declaration_fixed_attacks(board, rl.unit_id(0), declaration, 0))
    return count == 5

# Core increments enter addition before division, including random results.
def test_orks17c2b2_random_arithmetic_after_reroll():
    board = value_copy(attack_declaration_fixture())
    board.command_points[0] = 2
    modifiers = rl.new('RuleModifiers')
    modifiers.append(rl.rule_modifier(rl.ModifierOperation.multiply(), 2))
    modifiers.append(rl.rule_modifier(rl.ModifierOperation.divide(), 2))
    characteristic = value_copy(rl.evaluate_weapon_characteristic(board, rl.dice_stat(6), 3, False, rl.unit_id(0), modifiers, rl.ModifiedCharacteristic.damage()))
    characteristic.quantity(board, attack_test_die(1))
    characteristic.keep_it(board, False)
    characteristic.reroll(board, attack_test_die(4))
    return characteristic.is_done() and characteristic.result.value == 6 and (board.command_points[0] == 1)

# Fixed D differences disappear when cumulative operations give the same D.
def test_orks17c2b2_effective_fixed_damage_grouping():
    left = rl.new('AttackSequenceInfo')
    right = rl.new('AttackSequenceInfo')
    left.source = rl.Weapon.librarian_storm_bolter()
    right.source = left.source
    left.damage_modifiers.append(rl.rule_modifier(rl.ModifierOperation.add(), 2))
    if rl.same_effective_damage(left, right):
        return False
    right.damage_modifiers.append(rl.rule_modifier(rl.ModifierOperation.multiply(), 3))
    return rl.same_effective_damage(left, right)

# Comparing only one die face is insufficient for random D group identity.
def test_orks17c2b2_random_damage_grouping_all_faces():
    left = rl.new('AttackSequenceInfo')
    right = rl.new('AttackSequenceInfo')
    left.source = rl.Weapon.smite_witchfire()
    right.source = left.source
    left.damage_modifiers.append(rl.rule_modifier(rl.ModifierOperation.multiply(), 2))
    right.damage_modifiers.append(rl.rule_modifier(rl.ModifierOperation.add(), 1))
    return not rl.same_effective_damage(left, right)

# A zero replacement is locked against later additions by appendix02.02.01.
def test_orks17c2b2_zero_damage_replacement_locked():
    board = value_copy(attack_declaration_fixture())
    modifiers = rl.new('RuleModifiers')
    modifiers.append(rl.rule_modifier(rl.ModifierOperation.replace(), 0))
    characteristic = value_copy(rl.evaluate_weapon_characteristic(board, rl.raw_stat(2), 4, False, rl.unit_id(0), modifiers, rl.ModifiedCharacteristic.damage()))
    return characteristic.is_done() and characteristic.result.value == 0

# Scoped D is captured from the actual selected bearer, including Firing Deck.
def test_orks17c2b2_damage_snapshot_scope():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.append(rl.Weapon.librarian_storm_bolter())
    board[0][0].characteristic_modifiers.append(rl.weapon_characteristic_modifier(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.add(), 2, 0))
    first = value_copy(orks17c2b_info(board, 0))
    second = value_copy(orks17c2b_info(board, 1))
    return first.damage_modifiers.size() == 1 and second.damage_modifiers.empty()

# p.17: the actual share selector exposes modified A and gathering must not
# apply it a second time to each split share.
def test_orks17c2b2_melee_share_selector_and_gathering():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.choppa()
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.attacks(), rl.ModifierOperation.multiply(), 2))
    board[1][0].position = board[0][0].position
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    targets = value_copy(rl.declare_weapon_targets(board, declaration, rl.unit_id(0), True))
    targets.declare_target(board, rl.unit_id(0), rl.unit_id(1))
    share = rl.new('AttackShareChoice')
    assign(share, 6)
    targets.assign_attacks(board, share)
    gathered = value_copy(rl.gather_weapon_count(board, rl.unit_id(0), rl.unit_id(1), targets.weapon, True))
    return targets.is_done() and gathered.is_done() and (gathered.result.value == 6)

# Random ranged A is modified per weapon at gathering, not at declaration.
def test_orks17c2b2_random_attacks_gathering():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.smite_witchfire()
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.attacks(), rl.ModifierOperation.multiply(), 2))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    gathered = value_copy(rl.gather_weapon_count(board, rl.unit_id(0), rl.unit_id(1), declaration, False))
    gathered.quantity(board, attack_test_die(3))
    return gathered.is_done() and gathered.result.value == 6

# D modifiers are consumed by actual allocated damage, not just group labels.
def test_orks17c2b2_allocated_damage_uses_modifier():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.damage_modifiers.append(rl.rule_modifier(rl.ModifierOperation.replace(), 0))
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1)))
    model = rl.new('ModelID')
    damage.allocate_mortal(board, board[1], board[0], model)
    return damage.is_done() and board[1][0].suffered_wounds == 0

# Appendix02.02.01: replacing A by zero permits no melee share and must not
# strand the declaration at an input boundary with no legal choices.
def test_orks17c2b2_zero_melee_attacks_no_selector():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.choppa()
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.attacks(), rl.ModifierOperation.replace(), 0))
    board[1][0].position = board[0][0].position
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    targets = value_copy(rl.declare_weapon_targets(board, declaration, rl.unit_id(0), True))
    return targets.is_done()

# p.17: a multiplied A is split once; both targets keep their declared share.
def test_orks17c2b2_modified_melee_split_not_multiplied_twice():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.choppa()
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.attacks(), rl.ModifierOperation.multiply(), 2))
    board[1][0].position = board[0][0].position
    board[2][0].position = board[0][0].position
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    targets = value_copy(rl.declare_weapon_targets(board, declaration, rl.unit_id(0), True))
    targets.declare_target(board, rl.unit_id(0), rl.unit_id(1))
    targets.assign_attacks(board, attack_test_share(3))
    targets.declare_target(board, rl.unit_id(0), rl.unit_id(2))
    targets.assign_attacks(board, attack_test_share(3))
    first = value_copy(rl.gather_weapon_count(board, rl.unit_id(0), rl.unit_id(1), targets.weapon, True))
    second = value_copy(rl.gather_weapon_count(board, rl.unit_id(0), rl.unit_id(2), targets.weapon, True))
    return targets.is_done() and first.result.value == 3 and (second.result.value == 3)

# Appendix02.02.03: actual random D still waits for allocation and then
# applies operations to the selected original die before inflicting damage.
def test_orks17c2b2_random_allocated_damage_uses_modifier():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.source = rl.Weapon.smite_witchfire()
    board.attack_info.damage_modifiers.append(rl.rule_modifier(rl.ModifierOperation.subtract(), 1))
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1)))
    if damage.can_quantity(board, board[1], board[0], attack_test_die(2)):
        return False
    model = rl.new('ModelID')
    damage.allocate_mortal(board, board[1], board[0], model)
    damage.quantity(board, board[1], board[0], attack_test_die(2))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Named selectors use audited identities, not uncertified legacy stats. This
# fixture deliberately tags generic profiles for selector/consumer regressions.
def named17c2c_fixture():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.clear()
    for slot in range(4):
        board[0][0].weapons.append(rl.Weapon.captain_storm_bolter())
    rl.set_named_weapon_profile(board[0][0], 0, rl.NamedWeaponProfile.kustom_shoota_aimed())
    rl.set_named_weapon_profile(board[0][0], 1, rl.NamedWeaponProfile.kustom_shoota_point_blank())
    rl.set_named_weapon_profile(board[0][0], 2, rl.NamedWeaponProfile.kustom_shoota_aimed())
    rl.set_named_weapon_profile(board[0][0], 3, rl.NamedWeaponProfile.slugga())
    board[0][0].weapon_profile_groups[0] = 1
    board[0][0].weapon_profile_groups[1] = 1
    board[0][0].weapon_profile_groups[2] = 2
    rl.set_model_datasheet(board[0][0], rl.OrksDatasheet.big_mek_in_mega_armour())
    return value_copy(board)

# Appendix04.01.03: all alternate profiles and copies share the named family.
def test_named17c2c_family_grant_all_profiles_and_copies():
    board = value_copy(named17c2c_fixture())
    board[0][0].characteristic_modifiers.append(rl.named_weapon_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, rl.NamedWeapon.kustom_shoota()))
    first = value_copy(orks17c2b_info(board, 0))
    alternate = value_copy(orks17c2b_info(board, 1))
    copy = value_copy(orks17c2b_info(board, 2))
    unrelated = value_copy(orks17c2b_info(board, 3))
    return first.attack_strength() == 6 and alternate.attack_strength() == 6 and (copy.attack_strength() == 6) and (unrelated.attack_strength() == 4)

# A named profile restriction excludes a different profile of the same family.
def test_named17c2c_profile_grant_excludes_alternate():
    board = value_copy(named17c2c_fixture())
    board[0][0].characteristic_modifiers.append(rl.named_profile_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, rl.NamedWeaponProfile.kustom_shoota_aimed()))
    first = value_copy(orks17c2b_info(board, 0))
    alternate = value_copy(orks17c2b_info(board, 1))
    copy = value_copy(orks17c2b_info(board, 2))
    return first.attack_strength() == 6 and alternate.attack_strength() == 4 and (copy.attack_strength() == 6)

# A physical-instance grant includes its alternate but excludes a second copy.
def test_named17c2c_physical_grant_distinguishes_copy():
    board = value_copy(named17c2c_fixture())
    board[0][0].characteristic_modifiers.append(rl.physical_weapon_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, 0))
    first = value_copy(orks17c2b_info(board, 0))
    alternate = value_copy(orks17c2b_info(board, 1))
    copy = value_copy(orks17c2b_info(board, 2))
    return first.attack_strength() == 6 and alternate.attack_strength() == 6 and (copy.attack_strength() == 4)

# Group0 means an independent slot, never every other zero-group slot.
def test_named17c2c_zero_group_selects_only_its_slot():
    board = value_copy(named17c2c_fixture())
    board[0][0].weapon_profile_groups[0] = 0
    board[0][0].weapon_profile_groups[1] = 0
    board[0][0].characteristic_modifiers.append(rl.physical_weapon_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, 0))
    first = value_copy(orks17c2b_info(board, 0))
    alternate = value_copy(orks17c2b_info(board, 1))
    return first.attack_strength() == 6 and alternate.attack_strength() == 4

# Slot/family/profile predicates are conjunctive, not alternatives.
def test_named17c2c_conjunctive_selectors():
    board = value_copy(named17c2c_fixture())
    grant = value_copy(rl.named_weapon_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, rl.NamedWeapon.kustom_shoota()))
    grant.weapon_scope = 1
    grant.physical_scope = True
    grant.profile_name = rl.NamedWeaponProfile.kustom_shoota_point_blank().value
    board[0][0].characteristic_modifiers.append(grant)
    first = value_copy(orks17c2b_info(board, 0))
    alternate = value_copy(orks17c2b_info(board, 1))
    copy = value_copy(orks17c2b_info(board, 2))
    return first.attack_strength() == 4 and alternate.attack_strength() == 6 and (copy.attack_strength() == 4)

# Unknown identity does not accidentally grant a named bonus to legacy models.
def test_named17c2c_unknown_weapon_never_matches_name():
    board = value_copy(attack_declaration_fixture())
    board[0][0].characteristic_modifiers.append(rl.named_weapon_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, rl.NamedWeapon.kustom_shoota()))
    info = value_copy(orks17c2b_info(board, 0))
    return info.attack_strength() == 4 and (not rl.model_matches_datasheet(board[0][0], rl.OrksDatasheet.unknown()))

# Actual targeting consumes named Range, not only attack-context snapshots.
def test_named17c2c_named_range_target_legality():
    board = value_copy(named17c2c_fixture())
    board[1][0].position = board_position(35, 5)
    old = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    if rl.declaration_target_valid(board, rl.unit_id(0), old, rl.unit_id(1), False):
        return False
    board[0][0].characteristic_modifiers.append(rl.named_weapon_modifier(rl.ModifiedCharacteristic.range(), rl.ModifierOperation.add(), 10, rl.NamedWeapon.kustom_shoota()))
    return rl.declaration_target_valid(board, rl.unit_id(0), old, rl.unit_id(1), False)

# Named A/D reach the previous batch's real gathering and allocated snapshots.
def test_named17c2c_named_attacks_and_damage_consumers():
    board = value_copy(named17c2c_fixture())
    board[0][0].characteristic_modifiers.append(rl.named_weapon_modifier(rl.ModifiedCharacteristic.attacks(), rl.ModifierOperation.add(), 2, rl.NamedWeapon.kustom_shoota()))
    board[0][0].characteristic_modifiers.append(rl.named_profile_modifier(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.add(), 1, rl.NamedWeaponProfile.kustom_shoota_aimed()))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    count = value_copy(rl.gather_weapon_count(board, rl.unit_id(0), rl.unit_id(1), declaration, False))
    info = value_copy(orks17c2b_info(board, 0))
    return count.is_done() and count.result.value == 4 and (info.damage_modifiers.size() == 1)

# Appendix02.05.01: mixed unit identity is a union, model identity stays local.
def test_named17c2c_unit_and_model_datasheet_scope():
    unit = value_copy(rl.make_infernus_squad())
    rl.set_model_datasheet(unit[0], rl.OrksDatasheet.boyz())
    rl.set_model_datasheet(unit[1], rl.OrksDatasheet.big_mek_with_shokk_attack_gun())
    return rl.unit_matches_datasheet(unit, rl.OrksDatasheet.boyz()) and rl.unit_matches_datasheet(unit, rl.OrksDatasheet.big_mek_with_shokk_attack_gun()) and (not rl.model_matches_datasheet(unit[0], rl.OrksDatasheet.big_mek_with_shokk_attack_gun())) and (not rl.unit_matches_datasheet(unit, rl.OrksDatasheet.unknown()))

# Datasheet-filtered model grants must not buff unrelated attached constituents.
def test_named17c2c_datasheet_model_grant_is_local():
    unit = value_copy(rl.make_infernus_squad())
    rl.set_model_datasheet(unit[0], rl.OrksDatasheet.boyz())
    grant = value_copy(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 2))
    rl.grant_datasheet_characteristic(unit, rl.OrksDatasheet.boyz(), grant)
    return unit[0].effective_toughness() == 6 and unit[1].effective_toughness() == 4

# Named rule grants reach actual selected declarations (p.78/04.01.03).
def test_named17c2c_named_weapon_rule_consumers():
    board = value_copy(named17c2c_fixture())
    rl.grant_named_weapon_rule(board[0][0], rl.NamedWeapon.kustom_shoota(), rl.weapon_rule(rl.WeaponRuleKind.precision()))
    first = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    alternate = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 1))
    unrelated = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 3))
    return rl.declared_weapon_has_kind(first, rl.WeaponRuleKind.precision()) and rl.declared_weapon_has_kind(alternate, rl.WeaponRuleKind.precision()) and (not rl.declared_weapon_has_kind(unrelated, rl.WeaponRuleKind.precision()))

# Profile and physical rule grants remain narrower than a family grant.
def test_named17c2c_profile_and_physical_rules():
    board = value_copy(named17c2c_fixture())
    rl.grant_named_profile_rule(board[0][0], rl.NamedWeaponProfile.kustom_shoota_point_blank(), rl.weapon_rule(rl.WeaponRuleKind.ignore_cover()))
    rl.grant_physical_weapon_rule(board[0][0], 0, rl.weapon_rule(rl.WeaponRuleKind.precision()))
    first = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    alternate = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 1))
    copy = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 2))
    return not rl.declared_weapon_has_kind(first, rl.WeaponRuleKind.ignore_cover()) and rl.declared_weapon_has_kind(alternate, rl.WeaponRuleKind.ignore_cover()) and rl.declared_weapon_has_kind(alternate, rl.WeaponRuleKind.precision()) and (not rl.declared_weapon_has_kind(copy, rl.WeaponRuleKind.precision()))

# Identity and name predicates must survive archives and text saves.
def test_named17c2c_archive_keeps_datasheet_and_weapon_identity():
    board = value_copy(named17c2c_fixture())
    board[0].remove_model(0)
    archived = board[0].destroyed_models.value[0]
    return rl.model_matches_datasheet(archived, rl.OrksDatasheet.big_mek_in_mega_armour()) and archived.weapon_names[0].value == rl.NamedWeapon.kustom_shoota().value and rl.valid_model_numeric_history(archived)

# Reject conflicting profile/family tags instead of accepting a false selector.
def test_named17c2c_invalid_family_profile_metadata_rejected():
    board = value_copy(named17c2c_fixture())
    board[0][0].weapon_names[0] = rl.NamedWeapon.slugga().value
    return not rl.valid_model_numeric_history(board[0][0])

# Grouped alternate profiles must share their printed physical family.
def test_named17c2c_invalid_group_family_rejected():
    board = value_copy(named17c2c_fixture())
    board[0][0].weapon_profile_groups[3] = 1
    return not rl.valid_model_numeric_history(board[0][0])

# Raw values can bypass bounded assignment on restore; reject both catalogs.
def test_named17c2c_invalid_catalog_codes_rejected():
    board = value_copy(named17c2c_fixture())
    board[0][0].datasheet.value = rl.MAX_DATASHEETCODE
    if rl.valid_model_numeric_history(board[0][0]):
        return False
    board[0][0].datasheet = 0
    board[0][0].weapon_profile_names[0].value = -1
    return not rl.valid_model_numeric_history(board[0][0])

# Named or physical selectors cannot be attached to a model-only statistic.
def test_named17c2c_invalid_named_grant_metadata_rejected():
    grant = value_copy(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 1))
    grant.weapon_name = rl.NamedWeapon.slugga().value
    grants = rl.new('CharacteristicModifiers')
    grants.append(grant)
    return not rl.valid_characteristic_modifiers(grants)

# A physical selector must specify an owned representative slot.
def test_named17c2c_invalid_physical_scope_rejected():
    grant = value_copy(rl.characteristic_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 1))
    grant.physical_scope = True
    grants = rl.new('CharacteristicModifiers')
    grants.append(grant)
    return not rl.valid_characteristic_modifiers(grants)

# Firing Deck keeps the passenger profile identity, while numerical grants
# belong to the carrier (p.81). A coincident carrier slot grant is excluded.
def test_named17c2c_borrowed_named_grant_uses_passenger_identity():
    board = value_copy(named17c2c_fixture())
    passenger = value_copy(board[0])
    board.embarked_units.append(passenger)
    board[0][0].characteristic_modifiers.append(rl.named_weapon_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, rl.NamedWeapon.kustom_shoota()))
    board[0][0].characteristic_modifiers.append(rl.physical_weapon_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 10, 0))
    board.embarked_units[0][0].characteristic_modifiers.append(rl.named_weapon_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 20, rl.NamedWeapon.kustom_shoota()))
    declaration = value_copy(rl.make_deck_declaration(board, rl.unit_id(0), damage_test_model(0), rl.unit_id(0), damage_test_model(0), 1))
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    return info.attack_strength() == 6 and declaration.weapon_name.value == rl.NamedWeapon.kustom_shoota().value and (declaration.profile_name.value == rl.NamedWeaponProfile.kustom_shoota_point_blank().value)

# A carrier's equipped name is not the identity of a borrowed weapon.
def test_named17c2c_borrowed_unrelated_name_does_not_match():
    board = value_copy(named17c2c_fixture())
    board.embarked_units.append(board[0])
    board[0][0].characteristic_modifiers.append(rl.named_weapon_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, rl.NamedWeapon.kustom_shoota()))
    declaration = value_copy(rl.make_deck_declaration(board, rl.unit_id(0), damage_test_model(0), rl.unit_id(0), damage_test_model(0), 3))
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    return info.attack_strength() == 4

# Declarations retain their selected profile's name despite later metadata
# changes; currently source effects still use the live bearer (pp.16–17).
def test_named17c2c_declaration_identity_is_snapshot():
    board = value_copy(named17c2c_fixture())
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    board[0][0].weapon_profile_groups[0] = 0
    board[0][0].weapon_profile_groups[1] = 0
    rl.set_named_weapon_profile(board[0][0], 0, rl.NamedWeaponProfile.slugga())
    board[0][0].characteristic_modifiers.append(rl.named_weapon_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, rl.NamedWeapon.kustom_shoota()))
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    return info.attack_strength() == 6

# Real Game saves preserve catalog codes, physical scope and effective queries.
def test_named17c2c_saved_name_and_grant_round_trip():
    state = value_copy(rl.play())
    state.board = named17c2c_fixture()
    state.board[0][0].characteristic_modifiers.append(rl.named_weapon_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, rl.NamedWeapon.kustom_shoota()))
    restored = value_copy(rl.play())
    if not rl.set_state(restored, rl.to_string(state)):
        return False
    info = value_copy(orks17c2b_info(restored.board, 1))
    return rl.model_matches_datasheet(restored.board[0][0], rl.OrksDatasheet.big_mek_in_mega_armour()) and info.attack_strength() == 6

# Catalog enums are used transiently; stored codes have exactly their domain.
def test_named17c2c_catalog_bounds_and_profile_family():
    datasheet = rl.new('OrksDatasheet')
    weapon = rl.new('NamedWeapon')
    profile = rl.new('NamedWeaponProfile')
    family = value_copy(rl.named_profile_weapon(rl.NamedWeaponProfile.kustom_shoota_point_blank()))
    return rl.max(datasheet) + 1 == rl.MAX_DATASHEETCODE and rl.max(weapon) + 1 == rl.MAX_WEAPONNAMECODE and (rl.max(profile) + 1 == rl.MAX_WEAPONPROFILECODE) and (family.value == rl.NamedWeapon.kustom_shoota().value)

# Squighog Boyz Stikka is printed once in each attack table. Same-name
# ranged/melee profiles require distinct identity (datasheet/04.01.03):
# https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
def test_named17c2c_same_printed_name_distinct_attack_profiles():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.append(rl.Weapon.choppa())
    rl.set_named_weapon_profile(board[0][0], 0, rl.NamedWeaponProfile.stikka_ranged())
    rl.set_named_weapon_profile(board[0][0], 1, rl.NamedWeaponProfile.stikka_melee())
    board[0][0].characteristic_modifiers.append(rl.named_profile_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 2, rl.NamedWeaponProfile.stikka_melee()))
    ranged = value_copy(orks17c2b_info(board, 0))
    melee = value_copy(orks17c2b_info(board, 1))
    return ranged.attack_strength() == 4 and melee.attack_strength() == 7 and (board[0][0].weapon_names[0] == board[0][0].weapon_names[1]) and rl.valid_model_numeric_history(board[0][0])

# Restore validation rejects a melee tag attached to an actual ranged profile.
def test_named17c2c_profile_attack_kind_metadata_rejected():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapon_names[0] = rl.NamedWeapon.stikka().value
    board[0][0].weapon_profile_names[0] = rl.NamedWeaponProfile.stikka_melee().value
    return not rl.valid_model_numeric_history(board[0][0])

# Core24.39 Damaged X: equal-or-less remaining wounds; no implicit grants.
def test_damaged17c3_threshold_boundary_and_disabled():
    model = value_copy(rl.make_infernus_squad()[0])
    model.damaged_threshold = 1
    model.suffered_wounds = 1
    if model.is_damaged():
        return False
    model.has_damaged = True
    if not model.is_damaged():
        return False
    model.suffered_wounds = 0
    return not model.is_damaged()

# Every new group refreshes bearer status; wounds on another model do not leak.
def test_damaged17c3_bearer_scope_and_group_refresh():
    board = value_copy(attack_declaration_fixture())
    other = value_copy(board[0][0])
    other.identity = 0
    board[0].models.append(other)
    board.identify_units()
    board[0][0].has_damaged = True
    board[0][0].damaged_threshold = 1
    initial = value_copy(orks17c2b_info(board, 0))
    board[0][0].suffered_wounds = 1
    damaged = value_copy(orks17c2b_info(board, 0))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 0))
    healthy = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    return not initial.damaged_hit_penalty and damaged.damaged_hit_penalty and (not healthy.damaged_hit_penalty)

# Damaged subtracts before the +/-1 cap, rather than afterwards (02.02.01).
def test_damaged17c3_combined_modifiers_before_cap():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.damaged_hit_penalty = True
    board.attack_info.hit_roll_bonus = True
    board.attack_info.profile_hit_roll_bonus.append(board.attack_info.source_profile)
    if rl.get_hit_roll_bonus(board) != 1:
        return False
    board.attack_info.profile_hit_roll_bonus.clear()
    if rl.get_hit_roll_bonus(board) != 0:
        return False
    board.attack_info.hit_roll_bonus = False
    board.attack_info.hit_roll_malus = True
    return rl.get_hit_roll_bonus(board) == -1

# Actual hit classification uses Damaged while natural6 remains critical (p.18).
def test_damaged17c3_actual_hit_threshold_and_critical():
    board = value_copy(attack_declaration_fixture())
    board[0][0].has_damaged = True
    board[0][0].damaged_threshold = 1
    board[0][0].suffered_wounds = 1
    board.attack_info = orks17c2b_info(board, 0)
    return rl.classify_attack_hit(board, board.attack_info, attack_test_die(2), rl.get_hit_roll_bonus(board)) == rl.AttackRollResult.failed() and rl.classify_attack_hit(board, board.attack_info, attack_test_die(3), rl.get_hit_roll_bonus(board)) == rl.AttackRollResult.success() and (rl.classify_attack_hit(board, board.attack_info, attack_test_die(6), rl.get_hit_roll_bonus(board)) == rl.AttackRollResult.critical())

# Grouping distinguishes modified hit rolls of otherwise identical bearers.
def test_damaged17c3_grouping_splits_damaged_and_healthy():
    board = value_copy(attack_declaration_fixture())
    healthy = value_copy(orks17c2b_info(board, 0))
    damaged = value_copy(healthy)
    damaged.damaged_hit_penalty = True
    return not rl.attacks_are_identical(board, healthy, damaged)

# A retained destroyed model remains Damaged while authorised to fight.
def test_damaged17c3_retained_fight_on_death_is_damaged():
    model = value_copy(rl.make_infernus_squad()[0])
    model.has_damaged = True
    model.damaged_threshold = 1
    model.suffered_wounds = model.profile.wounds()
    model.state = rl.ModelState.fight_on_death()
    return model.is_damaged()

# Firing Deck uses the carrier's Damaged status, not the passenger's (p.81).
def test_damaged17c3_firing_deck_uses_carrier_status():
    board = value_copy(attack_declaration_fixture())
    board.embarked_units.append(board[0])
    board.embarked_units[0][0].has_damaged = True
    board.embarked_units[0][0].damaged_threshold = 1
    board.embarked_units[0][0].suffered_wounds = 1
    declaration = value_copy(rl.make_deck_declaration(board, rl.unit_id(0), damage_test_model(0), rl.unit_id(0), damage_test_model(0), 0))
    healthy = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    board[0][0].has_damaged = True
    board[0][0].damaged_threshold = 1
    board[0][0].suffered_wounds = 1
    damaged = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    return not healthy.damaged_hit_penalty and damaged.damaged_hit_penalty

# Restore gates reject raw out-of-domain storage without inventing an X>0 rule.
def test_damaged17c3_invalid_threshold_metadata():
    model = value_copy(rl.make_infernus_squad()[0])
    model.has_damaged = True
    if not rl.valid_model_numeric_history(model):
        return False
    model.damaged_threshold.value = -1
    if rl.valid_model_numeric_history(model):
        return False
    model.damaged_threshold.value = rl.MAX_WOUNDS
    return not rl.valid_model_numeric_history(model)

# Game serialization preserves both supplied threshold and gathered hit state.
def test_damaged17c3_saved_threshold_and_group_round_trip():
    state = value_copy(rl.play())
    state.board = attack_declaration_fixture()
    state.board[0][0].has_damaged = True
    state.board[0][0].damaged_threshold = 1
    state.board[0][0].suffered_wounds = 1
    state.board.attack_info = orks17c2b_info(state.board, 0)
    restored = value_copy(rl.play())
    return rl.set_state(restored, rl.to_string(state)) and restored.board[0][0].is_damaged() and restored.board.attack_info.damaged_hit_penalty and (rl.get_hit_roll_bonus(restored.board) == -1)

# Healing above X removes the penalty at the next group, overriding stale context.
def test_damaged17c3_healing_refresh_and_melee_consumer():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.choppa()
    board[0][0].has_damaged = True
    board[0][0].damaged_threshold = 1
    board[0][0].suffered_wounds = 1
    board.attack_info = orks17c2b_info(board, 0)
    if not board.attack_info.damaged_hit_penalty or rl.get_hit_roll_bonus(board) != -1:
        return False
    board[0][0].suffered_wounds = 0
    board.attack_info = orks17c2b_info(board, 0)
    return not board.attack_info.damaged_hit_penalty and rl.get_hit_roll_bonus(board) == 0

# The actual hit/wound coroutine consumes the penalty; a nominal hit at BS2
# becomes a miss and no wound-roll selector is offered (core24.39/p.18).
def test_damaged17c3_hit_batch_consumes_penalty():
    board = value_copy(attack_declaration_fixture())
    board[0][0].has_damaged = True
    board[0][0].damaged_threshold = 1
    board[0][0].suffered_wounds = 1
    board.attack_info = orks17c2b_info(board, 0)
    batch = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(1)))
    batch.roll(board, board[1], board[0], attack_test_die(2))
    return batch.is_done() and batch.generated_hits.value == 0

# Torrent still makes no hit roll; Damaged cannot reduce automatic hits (p.85).
def test_damaged17c3_torrent_keeps_automatic_hits():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.pyreblaster()
    board[0][0].has_damaged = True
    board[0][0].damaged_threshold = 1
    board[0][0].suffered_wounds = 1
    board.attack_info = orks17c2b_info(board, 0)
    batch = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(1)))
    if board.current_state.value != rl.CurrentStateDescription.wound_roll().value or batch.generated_hits.value != 1:
        return False
    batch.roll(board, board[1], board[0], attack_test_die(4))
    return batch.is_done() and batch.generated_wounds.value == 1

# Incoming reductions use the allocated recipient and printed arithmetic
# (p.19, appendix02.02.01; Battlewagon Mobile Fortress/Deff Dread Dread 'Ard).
def incoming17c4a_grant(kind, operation, amount, scope):
    return value_copy(rl.incoming_attack_modifier(kind, operation, amount, scope))

# Ranged-only defenses do not protect melee or change the bearer's own weapons.
def test_incoming17c4a_scope_and_bearer_separation():
    board = value_copy(attack_declaration_fixture())
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.subtract(), 1, rl.IncomingAttackScope.ranged()))
    empty = rl.new('RuleModifiers')
    ranged = value_copy(rl.combined_incoming_modifiers(empty, board[1][0].incoming_attack_modifiers, rl.ModifiedCharacteristic.damage(), False))
    melee = value_copy(rl.combined_incoming_modifiers(empty, board[1][0].incoming_attack_modifiers, rl.ModifiedCharacteristic.damage(), True))
    return rl.modified_characteristic(3, rl.ModifiedCharacteristic.damage(), ranged, False) == 2 and melee.size() == 0 and (board[1][0].characteristic_modifiers.size() == 0)

# Outgoing multiplication and incoming subtraction combine before the floor.
def test_incoming17c4a_order_floor_and_zero_lock():
    outgoing = rl.new('RuleModifiers')
    outgoing.append(rl.rule_modifier(rl.ModifierOperation.multiply(), 2))
    incoming = rl.new('IncomingAttackModifiers')
    incoming.append(incoming17c4a_grant(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.subtract(), 3, rl.IncomingAttackScope.any_attack()))
    combined = value_copy(rl.combined_incoming_modifiers(outgoing, incoming, rl.ModifiedCharacteristic.damage(), False))
    if rl.modified_characteristic(2, rl.ModifiedCharacteristic.damage(), combined, False) != 1:
        return False
    outgoing.append(rl.rule_modifier(rl.ModifierOperation.replace(), 0))
    combined = rl.combined_incoming_modifiers(outgoing, incoming, rl.ModifiedCharacteristic.damage(), False)
    return rl.modified_characteristic(2, rl.ModifiedCharacteristic.damage(), combined, False) == 0

# AP worsening caps at zero and does not modify InSv or natural-one failure.
def test_incoming17c4a_ap_save_and_invulnerable():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.source = rl.Weapon.choppa()
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(rl.ModifiedCharacteristic.armour_penetration(), rl.ModifierOperation.add(), 2, rl.IncomingAttackScope.any_attack()))
    if board.attack_info.attack_penetration(board[1][0]) != 0:
        return False
    group = rl.new('AllocationGroup')
    group.save = 3
    group.invulnerable = 4
    return rl.attack_save_succeeds(group, attack_test_die(3), 0) and rl.attack_save_succeeds(group, attack_test_die(4), -6) and (not rl.attack_save_succeeds(group, attack_test_die(1), 0))

# Actual Devastating damage consumes incoming D once before wound loss.
def test_incoming17c4a_devastating_actual_consumer():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.damage_modifiers.append(rl.rule_modifier(rl.ModifierOperation.replace(), 2))
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.subtract(), 1, rl.IncomingAttackScope.any_attack()))
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1)))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Random D is still rolled only after allocation; reductions precede its floor.
def test_incoming17c4a_random_damage_after_allocation():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.source = rl.Weapon.smite_witchfire()
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.subtract(), 1, rl.IncomingAttackScope.ranged()))
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1)))
    if damage.can_quantity(board, board[1], board[0], attack_test_die(2)):
        return False
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    damage.quantity(board, board[1], board[0], attack_test_die(2))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Equal outgoing D can differ after a recipient operation; do not group them.
def test_incoming17c4a_group_identity_before_rounding():
    board = value_copy(attack_declaration_fixture())
    left = value_copy(board.attack_info)
    right = value_copy(left)
    left.damage_modifiers.append(rl.rule_modifier(rl.ModifierOperation.replace(), 3))
    left.damage_modifiers.append(rl.rule_modifier(rl.ModifierOperation.divide(), 2))
    right.damage_modifiers.append(rl.rule_modifier(rl.ModifierOperation.replace(), 2))
    if not rl.same_effective_damage(left, right):
        return False
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.multiply(), 2, rl.IncomingAttackScope.any_attack()))
    return not rl.same_effective_damage(left, right, board[1][0]) and (not rl.attacks_are_identical(board, left, right))

# AP/D defenses do not change the printed W/Sv/InSv allocation groups (p.19).
def test_incoming17c4a_mixed_recipients_keep_printed_groups():
    board = value_copy(attack_declaration_fixture())
    other = value_copy(board[1][0])
    other.identity = 0
    other.incoming_attack_modifiers.append(incoming17c4a_grant(rl.ModifiedCharacteristic.armour_penetration(), rl.ModifierOperation.add(), 2, rl.IncomingAttackScope.any_attack()))
    board[1].models.append(other)
    board.identify_units()
    groups = value_copy(rl.make_allocation_groups(board, board[1], board.attack_info))
    return groups.size() == 1 and groups[0].members.size() == 2

# Invalid loaded kind, scope and zero divisor are rejected before arithmetic.
def test_incoming17c4a_restore_validation():
    board = value_copy(attack_declaration_fixture())
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.subtract(), 1, rl.IncomingAttackScope.any_attack()))
    if not rl.valid_model_numeric_history(board[1][0]):
        return False
    board[1][0].incoming_attack_modifiers[0].scope.value = 3
    if rl.valid_model_numeric_history(board[1][0]):
        return False
    board[1][0].incoming_attack_modifiers[0].scope = rl.IncomingAttackScope.any_attack()
    board[1][0].incoming_attack_modifiers[0].characteristic = rl.ModifiedCharacteristic.strength()
    if rl.valid_model_numeric_history(board[1][0]):
        return False
    board[1][0].incoming_attack_modifiers[0].characteristic = rl.ModifiedCharacteristic.damage()
    board[1][0].incoming_attack_modifiers[0].modifier = rl.rule_modifier(rl.ModifierOperation.divide(), 0)
    return not rl.valid_model_numeric_history(board[1][0])

# Ordinary failed saves apply the reduction to this attack, without spilling (p.19).
def test_incoming17c4a_normal_damage_consumer():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.source = rl.Weapon.heavy_bolter()
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.subtract(), 1, rl.IncomingAttackScope.ranged()))
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(1), attack_test_count(0)))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.roll(board, board[1], board[0], attack_test_die(1))
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Live allocated AP is used by the actual save, rather than the unprotected group (p.19).
def test_incoming17c4a_normal_save_consumer():
    board = value_copy(attack_declaration_fixture())
    board.attack_info.source = rl.Weapon.heavy_bolter()
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(rl.ModifiedCharacteristic.armour_penetration(), rl.ModifierOperation.add(), 1, rl.IncomingAttackScope.ranged()))
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(1), attack_test_count(0)))
    damage.choose_save_group(board, board[1], board[0], allocation_test_group(0))
    damage.roll(board, board[1], board[0], attack_test_die(3))
    damage.allocate_wound(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 0

# Non-attack mortal wound jobs bypass incoming weapon-D arithmetic (p.24).
def test_incoming17c4a_nonattack_mortals_unmodified():
    board = value_copy(attack_declaration_fixture())
    board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.replace(), 0, rl.IncomingAttackScope.any_attack()))
    damage = value_copy(rl.resolve_mortal_wounds(board, rl.unit_id(1), rl.unit_id(0), False, attack_test_count(1)))
    damage.select_mortal_model(board, damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Saves preserve incoming metadata, independent of generated lifecycle (infrastructure).
def test_incoming17c4a_saved_metadata_round_trip():
    state = value_copy(rl.play())
    state.board = attack_declaration_fixture()
    state.board[1][0].incoming_attack_modifiers.append(incoming17c4a_grant(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.subtract(), 1, rl.IncomingAttackScope.ranged()))
    restored = value_copy(rl.play())
    return rl.set_state(restored, rl.to_string(state)) and restored.board[1][0].incoming_attack_modifiers.size() == 1 and (restored.board[1][0].incoming_attack_modifiers[0].modifier.signed_amount() == 1) and rl.valid_model_numeric_history(restored.board[1][0])

# All67 source loadouts, including Kill Tank options, require at most13 stored
# profiles; declarations include32 Firing Deck selections (p.81/Orks sources).
def test_physical17d_capacity_and_last_slot():
    # Capacity is model storage; actual final-slot legality is also checked
    # in the profile-selection regression below, using its live board.
    unit = value_copy(rl.make_infernus_squad())
    unit.models.resize(1)
    unit[0].weapons.clear()
    for slot in range(rl.MAX_WEAPONS):
        unit[0].weapons.append(rl.Weapon.bolt_pistol())
    selector = rl.new('BInt<0, MAX_WEAPONS>')
    choices = value_copy(rl.enumerate(selector))
    valid = value_copy(rl.MAX_WEAPONS == 13 and rl.MAX_WEAPON_SCOPES == 14 and (rl.MAX_SELECTED_WEAPONS == rl.MAX_UNIT_MODELS * rl.MAX_WEAPONS + rl.MAX_DECK_SELECTIONS) and (unit[0].weapons.size() == 13) and (choices.size() == 13) and (choices[12].value == 12))
    return valid

# Nazdreg allows its three separate ranged profiles; ordinary copies still
# choose one profile (source UNIT COMPOSITION; appendix04.01.03).
def test_physical17d_nazdreg_scoped_profile_exception():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.clear()
    for slot in range(5):
        board[0][0].weapons.append(rl.Weapon.captain_storm_bolter())
        board[0][0].weapon_profile_groups[slot] = 1 + int(slot >= 3)
    selected = rl.new('Bool[MAX_WEAPONS]')
    selected[0] = True
    selected[3] = True
    if rl.weapon_selection_valid(board, rl.unit_id(0), 0, 1, False, selected, False):
        return False
    rl.permit_simultaneous_ranged_profiles(board[0][0], 1)
    permitted = value_copy(rl.weapon_selection_valid(board, rl.unit_id(0), 0, 1, False, selected, False) and rl.weapon_selection_valid(board, rl.unit_id(0), 0, 2, False, selected, False) and (not rl.weapon_selection_valid(board, rl.unit_id(0), 0, 4, False, selected, False)))
    while board[0][0].weapons.size() < rl.MAX_WEAPONS:
        board[0][0].weapons.append(rl.Weapon.captain_storm_bolter())
    last_slot = value_copy(rl.weapon_selection_valid(board, rl.unit_id(0), 0, 12, False, selected, False))
    outside = value_copy(rl.weapon_selection_valid(board, rl.unit_id(0), 0, 13, False, selected, False))
    return permitted and last_slot and (not outside)

# One Shot usage still belongs to a physical copy, independently of its name.
def test_physical17d_one_shot_copies_independent():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.clear()
    for slot in range(4):
        board[0][0].weapons.append(rl.Weapon.bolt_pistol())
        board[0][0].weapon_profile_groups[slot] = 1 + slot // 2
    rl.consume_one_shot_profile(board[0][0], 0)
    return board[0][0].used_once_per_battle_weapon[0] and board[0][0].used_once_per_battle_weapon[1] and (not board[0][0].used_once_per_battle_weapon[2]) and (not board[0][0].used_once_per_battle_weapon[3])

# Hazardous is rolled per selected physical weapon, not per simultaneous
# profile; independent copies and borrowed owners stay separate (p.81).
def test_physical17d_hazardous_physical_identity():
    board = value_copy(attack_declaration_fixture())
    board.identify_units()
    board[0][0].weapon_profile_groups[0] = 1
    first = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    first.selected_rules.append(rl.weapon_rule(rl.WeaponRuleKind.hazardous()))
    second = value_copy(first)
    second.slot = 1
    third = value_copy(second)
    third.weapon_owner = board[1][0].identity
    declarations = rl.new('DeclaredWeapons')
    declarations.append(first)
    declarations.append(second)
    declarations.append(third)
    return rl.declared_hazardous_uses(declarations) == 2 and rl.same_declared_physical_weapon(first, second) and (not rl.same_declared_physical_weapon(second, third))

# Metadata cannot permit a nonexistent/Melee/ungrouped simultaneous profile.
def test_physical17d_profile_permission_restore_guard():
    board = value_copy(attack_declaration_fixture())
    board[0][0].simultaneous_ranged_profiles[12] = True
    if rl.valid_named_model_identity(board[0][0]):
        return False
    board[0][0].simultaneous_ranged_profiles[12] = False
    board[0][0].simultaneous_ranged_profiles[0] = True
    return not rl.valid_named_model_identity(board[0][0])

# D3 inputs are actual faces1..3; intrinsic constants survive until modifiers.
def test_compound17d_d3_sum_and_intrinsic_constant():
    expression = value_copy(rl.compound_stat(2, 3, 2))
    sequence = value_copy(rl.evaluate_random_stat(expression))
    if sequence.can_quantity(attack_test_die(4)):
        return False
    sequence.quantity(attack_test_die(2))
    if sequence.is_done():
        return False
    sequence.quantity(attack_test_die(3))
    return sequence.is_done() and sequence.result.value == 7

# Stompa3D6+3 A is generated individually at gathering (02.02.03/source row).
def test_compound17d_actual_stompa_attacks_gathering():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons[0] = rl.Weapon.stompa_supa_gatler_point_blank()
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    gathering = value_copy(rl.gather_weapon_count(board, rl.unit_id(0), rl.unit_id(1), declaration, False))
    gathering.quantity(board, attack_test_die(1))
    gathering.quantity(board, attack_test_die(6))
    gathering.quantity(board, attack_test_die(2))
    return gathering.is_done() and gathering.result.value == 12

# Re-roll all original dice once, retain the intrinsic +3, then multiply
# (01.05.02/02.02.03). One CP pays for the whole summed roll.
def test_compound17d_whole_roll_reroll_before_modifiers():
    board = value_copy(attack_declaration_fixture())
    board.command_points[0] = 1
    modifiers = rl.new('RuleModifiers')
    modifiers.append(rl.rule_modifier(rl.ModifierOperation.multiply(), 2))
    sequence = value_copy(rl.evaluate_weapon_characteristic(board, rl.compound_stat(3, 6, 3), 0, False, rl.unit_id(0), modifiers, rl.ModifiedCharacteristic.damage()))
    sequence.quantity(board, attack_test_die(1))
    sequence.quantity(board, attack_test_die(1))
    sequence.quantity(board, attack_test_die(1))
    sequence.keep_it(board, False)
    sequence.reroll(board, attack_test_die(6))
    sequence.reroll(board, attack_test_die(6))
    if sequence.is_done():
        return False
    sequence.reroll(board, attack_test_die(6))
    return sequence.is_done() and sequence.result.value == 42 and (board.command_points[0] == 0)

# Actual allocated D6+2 includes intrinsic +2 before incoming reductions.
def test_compound17d_allocated_stompa_damage():
    board = value_copy(attack_declaration_fixture())
    board[1][0].profile = rl.Profile.captain_octavius()
    board.attack_info.source = rl.Weapon.stompa_deffkannon_and_supa_rokkits()
    board[1][0].incoming_attack_modifiers.append(rl.incoming_attack_modifier(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.subtract(), 1, rl.IncomingAttackScope.ranged()))
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1)))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    damage.quantity(board, board[1], board[0], attack_test_die(2))
    return damage.is_done() and board[1][0].suffered_wounds == 3

# Random movement still determines one entire unit's M (02.02.03), while
# compound dice do not grant a Command Re-roll for movement characteristics.
def test_compound17d_unit_random_movement():
    board = value_copy(movement11_fixture())
    board[0][0].has_random_movement = True
    board[0][0].random_movement = rl.compound_stat(2, 3, 6)
    sequence = value_copy(rl.movement(board, rl.unit_id(0), False))
    sequence.quantity(board, attack_test_die(2))
    sequence.quantity(board, attack_test_die(3))
    return board[0].movement_override.value == 12 and sequence.can_normal_move(board)

# Different original shapes do not group just because replacement D is equal;
# equivalent1D6 forms do (p.17/01.05.02/02.02.03).
def test_compound17d_random_shape_group_identity():
    return rl.same_damage_characteristic(rl.dice_stat(6), rl.compound_stat(1, 6, 0)) and (not rl.same_damage_characteristic(rl.compound_stat(2, 3, 0), rl.compound_stat(1, 6, 0))) and (not rl.same_damage_characteristic(rl.compound_stat(1, 6, 2), rl.compound_stat(1, 6, 3)))

# Stored compound movement/demise survives save round trips with bounds intact.
def test_compound17d_saved_expressions():
    state = value_copy(rl.play())
    state.board = attack_declaration_fixture()
    state.board[0][0].has_random_movement = True
    state.board[0][0].random_movement = rl.compound_stat(1, 6, 6)
    state.board[0][0].has_deadly_demise = True
    state.board[0][0].deadly_demise = rl.compound_stat(2, 6, 0)
    restored = value_copy(rl.play())
    return rl.set_state(restored, rl.to_string(state)) and rl.stat_dice_count(restored.board[0][0].deadly_demise) == 2 and (rl.stat_intrinsic_constant(restored.board[0][0].random_movement) == 6)

# Typed source fixtures exercise infrastructure, not install uncertified Orks abilities.
def source17e_instance(board, unit, rule):
    board.identify_units()
    instance = rl.new('SourceInstance')
    instance.rule = rule
    instance.name.value = rl.s('Source fixture')
    instance.source_unit = board[unit].identity
    instance.source_model = board[unit][0].identity
    instance.owner = board[unit].owned_by_player1
    instance.trigger = rl.SourceEventKind.timing_window()
    instance.window = rl.TimingWindow.movement_start()
    instance.optional = True
    instance.grant = rl.characteristic_modifier(rl.ModifiedCharacteristic.movement(), rl.ModifierOperation.add(), 2)
    return value_copy(instance)

def source17e_id(value):
    result = rl.new('SourceEventID')
    assign(result, value)
    return value_copy(result)

def source17e_trigger(board, kind, unit):
    result = value_copy(rl.source_event(kind, board[unit].identity, rl.invalid_entity_identity(), rl.invalid_entity_identity()))
    result.window = rl.TimingWindow.movement_start()
    result.movement = rl.MovementKind.normal()
    return value_copy(result)

# Source instances share the user's current-player/opponent order with legacy
# timing choices, rather than dispatching all sources before both players.
def test_sources17e_timing_controller_order():
    board = value_copy(attack_declaration_fixture())
    own = value_copy(source17e_instance(board, 0, 1))
    enemy = value_copy(source17e_instance(board, 1, 2))
    rl.register_source_instance(board, own)
    rl.register_source_instance(board, enemy)
    sequence = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.movement_start()))
    if sequence.can_choose_window_source(board, source17e_id(1)):
        return False
    sequence.choose_window_source(board, source17e_id(0))
    if not board.current_decision_maker or board[0][0].effective_movement(6) != 8:
        return False
    sequence.choose_window_source(board, source17e_id(1))
    return sequence.is_done() and (not board.current_decision_maker) and (board[1][0].effective_movement(6) == 8)

# Passing optional effects spends nothing; mandatory source instances cannot
# be skipped even when their only choice is a singleton (source/user sequencing).
def test_sources17e_optional_decline_and_mandatory():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    rl.register_source_instance(board, instance)
    declined = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    declined.finish_source_events(board)
    if not declined.is_done() or board.source_uses.size() != 0 or board.source_effects.size() != 0:
        return False
    board.source_instances[0].optional = False
    required = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    if required.can_finish_source_events(board):
        return False
    required.choose_source_event(board, source17e_id(0))
    return required.is_done() and board.source_effects.size() == 1

# Duplicate per-army sources share usage, while players remain independent.
def test_sources17e_shared_army_limit_rechecks_pending():
    board = value_copy(attack_declaration_fixture())
    first = value_copy(source17e_instance(board, 0, 1))
    first.limits.phase = 1
    second = value_copy(first)
    rl.register_source_instance(board, first)
    rl.register_source_instance(board, second)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(1))
    return sequence.is_done() and board.source_effects.size() == 1 and (not rl.source_usage_available(board, first)) and (not rl.source_usage_available(board, second))

# Simultaneous phase/turn/round/battle limits are all enforced; new intervals
# reset only their own counts, never the battle total (sourced Orks limits).
def test_sources17e_combined_interval_limits():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.limits.phase = 2
    instance.limits.turn = 3
    instance.limits.round = 4
    instance.limits.battle = 5
    rl.commit_source_usage(board, instance)
    rl.commit_source_usage(board, instance)
    if rl.source_usage_available(board, instance):
        return False
    board.begin_phase(rl.BattlePhase.movement())
    rl.commit_source_usage(board, instance)
    if rl.source_usage_available(board, instance):
        return False
    board.start_turn_history()
    rl.commit_source_usage(board, instance)
    if rl.source_usage_available(board, instance):
        return False
    board.current_round = 1
    board.begin_phase(rl.BattlePhase.shooting())
    rl.commit_source_usage(board, instance)
    board.start_turn_history()
    board.begin_phase(rl.BattlePhase.fight())
    board.current_round = 2
    return not rl.source_usage_available(board, instance) and board.source_uses[0].battle_uses.value == 5

# Equal grant values from different sources keep independent expiry handles.
def test_sources17e_overlapping_grants_expire_independently():
    board = value_copy(attack_declaration_fixture())
    first = value_copy(source17e_instance(board, 0, 1))
    second = value_copy(source17e_instance(board, 0, 2))
    second.duration = rl.SourceDuration.next_own_turn()
    rl.register_source_instance(board, first)
    rl.register_source_instance(board, second)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(0))
    sequence.choose_source_event(board, source17e_id(1))
    if board[0][0].effective_movement(6) != 10:
        return False
    board.begin_phase(rl.BattlePhase.shooting())
    return board.source_effects.size() == 1 and board[0][0].effective_movement(6) == 8 and rl.valid_source_grant(board.source_instances[0].grant) and rl.valid_source_grant(board.source_instances[1].grant)

# Next-own-turn effects survive the opponent's turn; duration belongs to the
# granting player's next turn, not the recipient's owner (01.02.02).
def test_sources17e_next_own_turn_duration():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.duration = rl.SourceDuration.next_own_turn()
    rl.register_source_instance(board, instance)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(0))
    board.current_player = True
    board.start_turn_history()
    if board[0][0].effective_movement(6) != 8:
        return False
    board.current_player = False
    board.start_turn_history()
    return board.source_effects.size() == 0 and board[0][0].effective_movement(6) == 6

# Reserve/passenger transfers retain duration, and expiry reaches both banks
# (01.02.02); no physical range is measured in this fixture.
def test_sources17e_expiry_in_reserve_and_passenger_banks():
    board = value_copy(attack_declaration_fixture())
    own = value_copy(source17e_instance(board, 0, 1))
    enemy = value_copy(source17e_instance(board, 1, 2))
    rl.register_source_instance(board, own)
    rl.register_source_instance(board, enemy)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(0))
    sequence.choose_source_event(board, source17e_id(1))
    board.embarked_units.append(board[1])
    board.units.erase(1)
    board.reserve_units.append(board[0])
    board.units.erase(0)
    board.begin_phase(rl.BattlePhase.shooting())
    return board.source_effects.size() == 0 and board.reserve_units[0][0].effective_movement(6) == 6 and (board.embarked_units[0][0].effective_movement(6) == 6)

# Sources follow model identity after compaction; model grants do not affect
# another constituent merely because it shares the unit (pp.66/87).
def test_sources17e_model_scope_and_stable_source():
    board = value_copy(attack_declaration_fixture())
    other = value_copy(board[0][0])
    other.identity = 0
    board[0].models.append(other)
    board.identify_units()
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.source_model = board[0][1].identity
    instance.recipient = rl.SourceTarget.source_model()
    rl.register_source_instance(board, instance)
    board[0].models.erase(0)
    relocated = value_copy(board[0])
    relocated.identity = 0
    board[0].models.clear()
    board[0].retired = True
    board.identify_unit(relocated)
    board.units.append(relocated)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(0))
    return sequence.is_done() and board[3][0].identity == instance.source_model and (board[3][0].effective_movement(6) == 8)

# Offboard own rules require explicit permission, and external range triggers
# stay unavailable even when that permission exists (01.02.04).
def test_sources17e_offboard_permission_and_range():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.trigger = rl.SourceEventKind.move_end()
    rl.register_source_instance(board, instance)
    event = value_copy(source17e_trigger(board, rl.SourceEventKind.move_end(), 0))
    board.reserve_units.append(board[0])
    board.units.erase(0)
    if rl.source_event_available(board, instance, event):
        return False
    instance.offboard_allowed = True
    if not rl.source_event_available(board, instance, event):
        return False
    instance.subject = rl.SourceSubject.any_unit()
    instance.trigger_range = 6
    event.unit = board[0].identity
    return not rl.source_event_available(board, instance, event)

# The real attack selection hook resolves its source before weapon choices.
def test_sources17e_actual_attack_selection_hook():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.trigger = rl.SourceEventKind.attack_selection()
    instance.grant = rl.characteristic_modifier(rl.ModifiedCharacteristic.attacks(), rl.ModifierOperation.add(), 2)
    rl.register_source_instance(board, instance)
    sequence = value_copy(rl.attack(board, rl.unit_id(0), rl.unit_id(1), False, False))
    if sequence.can_select_weapon(board, attack_test_slot(0)):
        return False
    sequence.choose_source_event(board, source17e_id(0))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    return rl.declaration_fixed_attacks(board, rl.unit_id(0), declaration, 0) == 4 and sequence.can_select_weapon(board, attack_test_slot(0))

# Source-only destruction hooks retain their victim and resolve at the printed
# release point; unrelated deaths can trigger an eligible observer (p.87).
def test_sources17e_actual_destruction_observer_hook():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.trigger = rl.SourceEventKind.model_destroyed()
    instance.subject = rl.SourceSubject.enemy_unit()
    instance.grant = rl.characteristic_modifier(rl.ModifiedCharacteristic.strength(), rl.ModifierOperation.add(), 1)
    rl.register_source_instance(board, instance)
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(1), rl.unit_id(0), True, True, 2, board[1][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    if board[1][0].state.value != rl.ModelState.pending_destruction().value:
        return False
    empty = rl.new('DamageJobs')
    cleanup = value_copy(rl.resolve_damage_jobs(board, empty, True, rl.unit_id(0)))
    cleanup.choose_destruction_unit(board, rl.unit_id(1))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.choose_source_event(board, source17e_id(0))
    modifiers = value_copy(rl.model_weapon_modifiers(board[0][0], 0, rl.ModifiedCharacteristic.strength(), False))
    return cleanup.is_done() and board[1].models.size() == 0 and (rl.modified_characteristic(4, rl.ModifiedCharacteristic.strength(), modifiers, False) == 5)

# Expired weapon-rule snapshots do not resurrect a grant after phase cleanup.
def test_sources17e_weapon_rule_snapshot_expiry():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.grant = rl.source_weapon_grant(rl.weapon_rule(rl.WeaponRuleKind.heavy()))
    rl.register_source_instance(board, instance)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(0))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    if not info.has_weapon_rule(board, rl.WeaponRuleKind.heavy()):
        return False
    board.begin_phase(rl.BattlePhase.shooting())
    return not info.has_weapon_rule(board, rl.WeaponRuleKind.heavy())

# Passive auras update when either unit moves, and drop immediately with the
# source; offboard recipients do not receive range-based effects (01.02.04).
def test_sources17e_live_aura_range_and_source():
    board = value_copy(attack_declaration_fixture())
    board[1].owned_by_player1 = False
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.aura = True
    instance.optional = False
    instance.recipient = rl.SourceTarget.event_unit()
    instance.subject = rl.SourceSubject.friendly_unit()
    instance.duration = rl.SourceDuration.battle()
    instance.trigger_range = 6
    rl.register_source_instance(board, instance)
    if board[1][0].effective_movement(6) != 8:
        return False
    board[1][0].position.x = 20
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    if board[1][0].effective_movement(6) != 6:
        return False
    board[1][0].position.x = 10
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    if board[1][0].effective_movement(6) != 8:
        return False
    board[0][0].suffered_wounds = 2
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return board.source_effects.size() == 0 and board[1][0].effective_movement(6) == 6

# Overlapping auras never erase another source's equal-valued arithmetic grant.
def test_sources17e_aura_overlap_and_disable():
    board = value_copy(attack_declaration_fixture())
    board[1].owned_by_player1 = False
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.aura = True
    instance.optional = False
    instance.recipient = rl.SourceTarget.event_unit()
    instance.subject = rl.SourceSubject.friendly_unit()
    instance.duration = rl.SourceDuration.battle()
    instance.trigger_range = 6
    rl.register_source_instance(board, instance)
    instance = source17e_instance(board, 1, 2)
    instance.aura = True
    instance.optional = False
    instance.recipient = rl.SourceTarget.event_unit()
    instance.subject = rl.SourceSubject.friendly_unit()
    instance.duration = rl.SourceDuration.battle()
    instance.trigger_range = 6
    rl.register_source_instance(board, instance)
    if board[0][0].effective_movement(6) != 10:
        return False
    board.source_instances[0].disabled = True
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return board[0][0].effective_movement(6) == 8 and board[1][0].effective_movement(6) == 8

# Unit grants reach a newly returned constituent once, without duplicating
# the surviving member's original grant (p.88/01.02.02).
def test_sources17e_returned_constituent_refresh():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.duration = rl.SourceDuration.battle()
    rl.register_source_instance(board, instance)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(0))
    returned = value_copy(board[0][0])
    returned.identity = 0
    returned.characteristic_modifiers.clear()
    board[0].models.append(returned)
    board.identify_unit(board[0])
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return board[0][0].characteristic_modifiers.size() == 1 and board[0][1].characteristic_modifiers.size() == 1 and (board[0][1].effective_movement(6) == 8)

# Source/effect/usage identities survive full-game serialization and invalid
# source references are rejected by the save gate (bounded infrastructure).
def test_sources17e_saved_records_and_invalid_reference():
    state = value_copy(rl.play())
    state.board = attack_declaration_fixture()
    instance = value_copy(source17e_instance(state.board, 0, 1))
    instance.limits.battle = 2
    rl.register_source_instance(state.board, instance)
    sequence = value_copy(rl.resolve_source_event(state.board, source17e_trigger(state.board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(state.board, source17e_id(0))
    restored = value_copy(rl.play())
    if not rl.set_state(restored, rl.to_string(state)) or restored.board.source_effects.size() != 1 or restored.board.source_uses[0].battle_uses.value != 1 or (restored.board[0][0].effective_movement(6) != 8):
        return False
    restored.board.source_effects[0].source.value = 63
    return not rl.valid_source_foundations(restored.board)

# Model/unit limits key the printed subject rather than flattening everything
# into one per-army counter (Orks source restriction wording).
def test_sources17e_unit_model_and_player_use_keys():
    board = value_copy(attack_declaration_fixture())
    first = value_copy(source17e_instance(board, 0, 1))
    first.use_scope = rl.SourceUseScope.unit()
    first.limits.battle = 1
    second = value_copy(source17e_instance(board, 1, 1))
    second.use_scope = rl.SourceUseScope.unit()
    second.limits.battle = 1
    rl.commit_source_usage(board, first)
    if rl.source_usage_available(board, first) or not rl.source_usage_available(board, second):
        return False
    first.use_scope = rl.SourceUseScope.model()
    return rl.source_usage_available(board, first) and board.source_uses.size() == 1

# Source-installed incoming D reaches the actual allocated damage consumer.
def test_sources17e_incoming_damage_grant_consumer():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.recipient = rl.SourceTarget.target_unit()
    instance.grant = rl.incoming_attack_modifier(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.subtract(), 1, rl.IncomingAttackScope.ranged())
    rl.register_source_instance(board, instance)
    event = value_copy(source17e_trigger(board, rl.SourceEventKind.timing_window(), 0))
    event.target = board[1].identity
    trigger = value_copy(rl.resolve_source_event(board, event))
    trigger.choose_source_event(board, source17e_id(0))
    board.attack_info.damage_modifiers.append(rl.rule_modifier(rl.ModifierOperation.replace(), 2))
    damage = value_copy(rl.resolve_attack_damage(board, board[1], board[0], attack_test_count(0), attack_test_count(1)))
    damage.allocate_mortal(board, board[1], board[0], damage_test_model(0))
    return damage.is_done() and board[1][0].suffered_wounds == 1

# Named/physical source weapon rules retain17.C2c conjunctive scope and do
# not become bearer-wide merely because a generic event installed them.
def test_sources17e_named_physical_weapon_rule_scope():
    board = value_copy(named17c2c_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    grant = value_copy(rl.source_weapon_grant(rl.weapon_rule(rl.WeaponRuleKind.precision())))
    grant.weapon_scope = 1
    grant.physical_scope = True
    grant.weapon_name = board[0][0].weapon_names[0]
    instance.grant = grant
    rl.register_source_instance(board, instance)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(0))
    return rl.model_weapon_has_rule(board[0][0], 0, rl.WeaponRuleKind.precision()) and rl.model_weapon_has_rule(board[0][0], 1, rl.WeaponRuleKind.precision()) and (not rl.model_weapon_has_rule(board[0][0], 2, rl.WeaponRuleKind.precision()))

# Live aura eligibility rechecks compound target keywords, not only geometry.
def test_sources17e_aura_keyword_condition_refresh():
    board = value_copy(attack_declaration_fixture())
    board[1].owned_by_player1 = False
    board[1][0].keywords.append(rl.Keyword.vehicle())
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.aura = True
    instance.optional = False
    instance.recipient = rl.SourceTarget.event_unit()
    instance.subject = rl.SourceSubject.friendly_unit()
    instance.duration = rl.SourceDuration.battle()
    instance.trigger_range = 6
    rl.append_keyword_condition(instance.recipient_condition, rl.KeywordClause.all(), rl.Keyword.vehicle())
    rl.register_source_instance(board, instance)
    if board[0][0].effective_movement(6) != 6 or board[1][0].effective_movement(6) != 8:
        return False
    board[1][0].keywords.pop()
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return board[1][0].effective_movement(6) == 6

# Actual move-start/end events preserve independent source handles and expose
# choices around the movement endpoint rather than inventing phase triggers.
def test_sources17e_actual_move_start_end_hooks():
    board = value_copy(movement11_fixture())
    start = value_copy(source17e_instance(board, 0, 1))
    start.trigger = rl.SourceEventKind.move_start()
    end = value_copy(source17e_instance(board, 0, 2))
    end.trigger = rl.SourceEventKind.move_end()
    rl.register_source_instance(board, start)
    rl.register_source_instance(board, end)
    sequence = value_copy(rl.move(board, rl.unit_id(0), 0))
    sequence.choose_movement_source(board, rl.unit_id(0), source17e_id(0))
    sequence.move_to(board, rl.unit_id(0), board_position(7, 5))
    sequence.choose_movement_source(board, rl.unit_id(0), source17e_id(0))
    return sequence.is_done() and board[0][0].effective_movement(6) == 10

# Expired grants also leave casualty archives, so revival cannot resurrect a
# former phase effect (p.88/01.02.02).
def test_sources17e_archived_grant_expiry():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    rl.register_source_instance(board, instance)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(0))
    board[0].remove_model(0)
    board.begin_phase(rl.BattlePhase.shooting())
    return board[0].destroyed_models.value[0].characteristic_modifiers.size() == 0 and board.source_effects.size() == 0

# Phase effects expire after that phase's end effects/mission work, before the
# following turn-end window (01.02.02; core pp.28–30).
def test_sources17e_phase_end_expiry_before_turn_end():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    rl.register_source_instance(board, instance)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(0))
    end = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.movement_end()))
    return end.is_done() and board.source_effects.size() == 0 and (board[0][0].effective_movement(6) == 6)

# Shock-end sources resolve after the two original dice and before the caller
# regains its decision owner (p.9/30/source event infrastructure).
def test_sources17e_actual_shock_end_hook():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 1))
    instance.trigger = rl.SourceEventKind.shock_end()
    rl.register_source_instance(board, instance)
    sequence = value_copy(rl.battle_shock_test(board, board[0], False, False))
    sequence.roll_pair(board, board[0], attack_test_die(6), attack_test_die(6))
    sequence.choose_source_event(board, board[0], source17e_id(0))
    return sequence.is_done() and board[0][0].effective_movement(6) == 8

# Saved effect-key corruption cannot turn an unrelated manual modifier into a
# persisting source grant (source ownership/expiry infrastructure).
def test_sources17e_forged_modifier_handle_rejected():
    board = value_copy(attack_declaration_fixture())
    board.identify_units()
    modifier = value_copy(rl.characteristic_modifier(rl.ModifiedCharacteristic.movement(), rl.ModifierOperation.add(), 2))
    modifier.source_effect = 1
    board[0][0].characteristic_modifiers.append(modifier)
    return not rl.valid_source_foundations(board)

# Actual2D6 Deadly Demise rolls two fresh dice per nearby unit, then resolves
# each mortal job while retaining the exploding model (core p.80/Stompa).
def test_compound17d_actual_two_dice_deadly_demise():
    board = value_copy(damage_test_fixture())
    board[1][0].has_deadly_demise = True
    board[1][0].deadly_demise = rl.compound_stat(2, 6, 0)
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(1), rl.unit_id(0), True, True, 10, board[1][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    empty = rl.new('DamageJobs')
    cleanup = value_copy(rl.resolve_damage_jobs(board, empty, True, rl.unit_id(0)))
    cleanup.choose_destruction_unit(board, rl.unit_id(1))
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
    return cleanup.is_done() and board[0].models.size() == 0 and (board[1].models.size() == 0) and (board[2].models.size() == 0)

# Appendix02.02.02 permits every subset, including beneficial operations;
# this is a generic core fixture, not an excluded Forge World unit.
def test_ignore17c4b_every_subset_before_arithmetic():
    board = value_copy(attack_declaration_fixture())
    choices = rl.new('AttackModifierChoices')
    choices.append(rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.add(), 2), rl.ModifierOrigin.characteristic()))
    choices.append(rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.add(), -2), rl.ModifierOrigin.characteristic()))
    choices.append(rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.multiply(), 2), rl.ModifierOrigin.characteristic()))
    valid = value_copy(True)
    for pattern in range(8):
        selected = value_copy(rl.choose_attack_modifiers(board, choices, False, rl.ModifierSelectionKind.ballistic_skill(), True))
        expected = rl.new('SelectedAttackModifiers')
        divisor = value_copy(1)
        for choice_index in range(3):
            keep = value_copy(pattern // divisor % 2 == 1)
            divisor = divisor * 2
            selected.apply_attack_modifier(board, keep)
            if keep:
                expected.append(choices[choice_index].modifier)
        valid = valid and selected.is_done() and (rl.apply_rule_modifiers(4, selected.result, False) == rl.apply_rule_modifiers(4, expected, False))
    return valid

# No permission means the complete list applies without a new decision;
# empty lists never stall or change the caller's controller (02.02.02).
def test_ignore17c4b_unpermitted_and_empty_skip_choices():
    board = value_copy(attack_declaration_fixture())
    board.current_decision_maker = True
    choices = rl.new('AttackModifierChoices')
    choices.append(rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.add(), -1), rl.ModifierOrigin.hit_penalty()))
    denied = value_copy(rl.choose_attack_modifiers(board, choices, False, rl.ModifierSelectionKind.hit_roll(), False))
    empty = rl.new('AttackModifierChoices')
    none = value_copy(rl.choose_attack_modifiers(board, empty, False, rl.ModifierSelectionKind.hit_roll(), True))
    return denied.is_done() and none.is_done() and (denied.result.size() == 1) and (none.result.size() == 0) and board.current_decision_maker

# Optional choice belongs to the affected attacker, not the turn owner or
# incoming source, and must restore nested caller/UI roles (02.02.02).
def test_ignore17c4b_controller_and_context_restored():
    board = value_copy(attack_declaration_fixture())
    board.current_player = False
    board.current_decision_maker = False
    board.pending_modifier_kind = rl.ModifierSelectionKind.weapon_skill()
    board.pending_modifier_choice = rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.add(), 3), rl.ModifierOrigin.characteristic())
    choices = rl.new('AttackModifierChoices')
    choices.append(rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.add(), -1), rl.ModifierOrigin.damaged()))
    sequence = value_copy(rl.choose_attack_modifiers(board, choices, True, rl.ModifierSelectionKind.hit_roll(), True))
    valid = value_copy(board.current_decision_maker and board.pending_modifier_kind.value == rl.ModifierSelectionKind.hit_roll().value and sequence.can_apply_attack_modifier(board, False))
    sequence.apply_attack_modifier(board, False)
    return valid and sequence.is_done() and (not board.current_decision_maker) and (board.pending_modifier_kind.value == rl.ModifierSelectionKind.weapon_skill().value) and (board.pending_modifier_choice.modifier.amount == 3) and (board.command_points[1] == 0)

# Keeping only a detrimental contribution must remain possible; sign filtering
# would incorrectly force the beneficial one (02.02.02/02.02.01).
def test_ignore17c4b_can_ignore_beneficial_hit_bonus():
    board = value_copy(attack_declaration_fixture())
    choices = rl.new('AttackModifierChoices')
    choices.append(rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.add(), 1), rl.ModifierOrigin.heavy()))
    choices.append(rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.add(), -1), rl.ModifierOrigin.damaged()))
    sequence = value_copy(rl.choose_attack_modifiers(board, choices, False, rl.ModifierSelectionKind.hit_roll(), True))
    sequence.apply_attack_modifier(board, False)
    sequence.apply_attack_modifier(board, True)
    return sequence.is_done() and rl.selected_hit_bonus(sequence.result) == -1

# Cover/Plunging Fire remain separate BS choices. Operation order/floors apply
# after filtering, never to an already rounded all-applied BS (pp.50/73;02.02.02).
def test_ignore17c4b_cover_plunging_and_skill_operation_order():
    board = value_copy(attack_declaration_fixture())
    info = value_copy(orks17c2b_info(board, 0))
    info.source = rl.Weapon.slugga()
    info.target_has_cover = True
    info.plunging_fire = True
    info.skill_modifiers.append(rl.rule_modifier(rl.ModifierOperation.divide(), 2))
    options = value_copy(rl.attack_skill_choices(board, info))
    sequence = value_copy(rl.choose_attack_modifiers(board, options, False, rl.ModifierSelectionKind.ballistic_skill(), True))
    sequence.apply_attack_modifier(board, True)
    sequence.apply_attack_modifier(board, False)
    sequence.apply_attack_modifier(board, True)
    return options.size() == 3 and options[1].origin.value == rl.ModifierOrigin.plunging_fire().value and (options[2].origin.value == rl.ModifierOrigin.cover().value) and (rl.selected_attack_skill(info, sequence.result) == (info.source.skill() + 2) // 2)

# Ignores Cover removes cover before optional choices; it never removes
# other modifiers or lets an absent '-' skill be modified (pp.82/85;02.02.01).
def test_ignore17c4b_ignore_cover_and_torrent_special_skill():
    board = value_copy(attack_declaration_fixture())
    info = value_copy(orks17c2b_info(board, 0))
    info.target_has_cover = True
    info.selected_weapon_rules.append(rl.weapon_rule(rl.WeaponRuleKind.ignore_cover()))
    choices = value_copy(rl.attack_skill_choices(board, info))
    info.source = rl.Weapon.stompa_supa_gatler_point_blank()
    selected = rl.new('SelectedAttackModifiers')
    selected.append(rl.rule_modifier(rl.ModifierOperation.add(), 4))
    return choices.size() == 0 and rl.selected_attack_skill(info, selected) == 0

# Heavy, Damaged, ordinary flags and both engagement contributions must be
# independently available before the +/-1 sum cap (pp.18/35/63/82;02.02.02).
def test_ignore17c4b_hit_core_provenance_and_cap():
    board = value_copy(attack_declaration_fixture())
    info = value_copy(orks17c2b_info(board, 0))
    info.hit_roll_bonus = True
    info.hit_roll_malus = True
    info.damaged_hit_penalty = True
    info.heavy_bonus = True
    info.engaged_hit_penalties = 2
    info.selected_weapon_rules.append(rl.weapon_rule(rl.WeaponRuleKind.heavy()))
    choices = value_copy(rl.attack_hit_choices(board, info))
    sequence = value_copy(rl.choose_attack_modifiers(board, choices, False, rl.ModifierSelectionKind.hit_roll(), True))
    for modifier_index in range(choices.size()):
        sequence.apply_attack_modifier(board, not choices[modifier_index].modifier.negative)
    return choices.size() == 6 and choices[2].origin.value == rl.ModifierOrigin.damaged().value and (choices[3].origin.value == rl.ModifierOrigin.heavy().value) and (choices[4].origin.value == rl.ModifierOrigin.engaged_source().value) and (choices[5].origin.value == rl.ModifierOrigin.engaged_target().value) and (rl.selected_hit_bonus(sequence.result) == 1)

# Permission applies to one bearer and declared attack kind, with separate
# characteristic and roll categories (02.02.02; model/unit scope02.05.01).
def test_ignore17c4b_permission_bearer_scope_and_kinds():
    board = value_copy(attack_declaration_fixture())
    board[0][0].weapons.append(rl.Weapon.relic_weapon())
    board[0][0].attack_modifier_permissions.append(rl.attack_modifier_permission(True, False, rl.IncomingAttackScope.ranged()))
    ranged = value_copy(orks17c2b_info(board, 0))
    melee = value_copy(orks17c2b_info(board, 1))
    other = value_copy(rl.declared_attack_info(board, rl.unit_id(1), rl.unit_id(0), rl.make_declared_weapon(board, rl.unit_id(1), 0, 0), board.attack_info))
    return ranged.may_ignore_skill_modifiers and (not ranged.may_ignore_hit_modifiers) and (not melee.may_ignore_skill_modifiers) and (not other.may_ignore_skill_modifiers)

# Equal current BS can have different optional subsets; permission mismatches
# and canceling hit contributions must split groups (p.17/02.02.02).
def test_ignore17c4b_grouping_preserves_available_subsets():
    board = value_copy(attack_declaration_fixture())
    left = value_copy(orks17c2b_info(board, 0))
    right = value_copy(left)
    left.may_ignore_skill_modifiers = True
    if rl.attacks_are_identical(board, left, right):
        return False
    right.may_ignore_skill_modifiers = True
    left.skill_modifiers.append(rl.rule_modifier(rl.ModifierOperation.add(), 1))
    left.skill_modifiers.append(rl.rule_modifier(rl.ModifierOperation.add(), -1))
    if rl.attacks_are_identical(board, left, right):
        return False
    left.skill_modifiers.clear()
    left.may_ignore_hit_modifiers = True
    right.may_ignore_hit_modifiers = True
    left.hit_roll_bonus = True
    left.hit_roll_malus = True
    return not rl.attacks_are_identical(board, left, right)

# With no permission, equivalent effective profiles retain existing batching
# even if their unfiltered records differ (p.17;02.02.01).
def test_ignore17c4b_no_permission_keeps_equivalent_grouping():
    board = value_copy(attack_declaration_fixture())
    left = value_copy(orks17c2b_info(board, 0))
    right = value_copy(left)
    left.skill_modifiers.append(rl.rule_modifier(rl.ModifierOperation.add(), 1))
    left.skill_modifiers.append(rl.rule_modifier(rl.ModifierOperation.add(), -1))
    return rl.attacks_are_identical(board, left, right)

# Original natural one/six, Snap Shooting and Indirect's unmodified floor
# survive selected subsets; these are gates, not modifiers (pp.18/35/57).
def test_ignore17c4b_natural_and_unmodified_hit_gates():
    board = value_copy(attack_declaration_fixture())
    info = value_copy(orks17c2b_info(board, 0))
    valid = value_copy(rl.classify_attack_hit(board, info, attack_test_die(1), 1, 2) == rl.AttackRollResult.failed() and rl.classify_attack_hit(board, info, attack_test_die(6), -1, 6) == rl.AttackRollResult.critical())
    info.only_hits_on_6 = True
    valid = valid and rl.classify_attack_hit(board, info, attack_test_die(5), 1, 2) == rl.AttackRollResult.failed()
    info.only_hits_on_6 = False
    info.shooting_kind = rl.ShootingKind.indirect()
    info.indirect_stationary_visible = False
    info.selected_weapon_rules.append(rl.weapon_rule(rl.WeaponRuleKind.indirect_fire()))
    return valid and rl.classify_attack_hit(board, info, attack_test_die(5), 1, 2) == rl.AttackRollResult.failed()

# Real hit batches must allow distinct choices for identical original faces;
# two attacks do not have to keep the same subset (02.02.02/p.18).
def test_ignore17c4b_actual_batch_per_attack_skill_and_hit():
    board = value_copy(attack_declaration_fixture())
    board.command_points[0] = 0
    board[0][0].attack_modifier_permissions.append(rl.attack_modifier_permission(True, True, rl.IncomingAttackScope.any_attack()))
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.ballistic_skill(), rl.ModifierOperation.add(), 1))
    board.attack_info = orks17c2b_info(board, 0)
    board.attack_info.hit_roll_malus = True
    sequence = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(2)))
    sequence.roll(board, board[1], board[0], attack_test_die(2))
    sequence.roll(board, board[1], board[0], attack_test_die(2))
    offered = value_copy(sequence.can_apply_attack_modifier(board, board[1], board[0], False))
    sequence.apply_attack_modifier(board, board[1], board[0], False)
    sequence.apply_attack_modifier(board, board[1], board[0], False)
    sequence.apply_attack_modifier(board, board[1], board[0], True)
    sequence.apply_attack_modifier(board, board[1], board[0], True)
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    return offered and sequence.is_done() and (sequence.generated_hits == 1) and (sequence.generated_wounds == 0) and (board.current_decision_maker == False)

# The hit chooser follows completed replacement dice, not an original failure;
# rerolls remain once per original die (02.02.01/01.05.02/02.02.02).
def test_ignore17c4b_actual_reroll_then_select_modifiers():
    board = value_copy(attack_declaration_fixture())
    board.command_points[0] = 0
    board[0][0].attack_modifier_permissions.append(rl.attack_modifier_permission(False, True, rl.IncomingAttackScope.any_attack()))
    board.attack_info = orks17c2b_info(board, 0)
    board.attack_info.hit_roll_malus = True
    board.attack_info.reroll_hits = True
    sequence = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(1)))
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    delayed = value_copy(not sequence.can_apply_attack_modifier(board, board[1], board[0], False))
    sequence.select_reroll(board, board[1], board[0], attack_test_die(1))
    sequence.reroll(board, board[1], board[0], attack_test_die(2))
    sequence.apply_attack_modifier(board, board[1], board[0], False)
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    return delayed and sequence.is_done() and (sequence.generated_hits == 1)

# Natural criticals skip meaningless ignoring decisions while preserving
# Sustained/Lethal and the old batch counts (pp.18/82/84).
def test_ignore17c4b_actual_natural_criticals_without_choices():
    board = value_copy(attack_declaration_fixture())
    board.command_points[0] = 0
    board[0][0].attack_modifier_permissions.append(rl.attack_modifier_permission(True, True, rl.IncomingAttackScope.any_attack()))
    board.attack_info = orks17c2b_info(board, 0)
    board.attack_info.hit_roll_malus = True
    sequence = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(2)))
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    sequence.roll(board, board[1], board[0], attack_test_die(6))
    no_choice = value_copy(not sequence.can_apply_attack_modifier(board, board[1], board[0], False))
    sequence.roll(board, board[1], board[0], attack_test_die(1))
    return no_choice and sequence.is_done() and (sequence.generated_hits == 1)

# Opposing out-of-phase attacks use their own controller for ignoring and
# restore the nested caller after dice resolution (02.02.02/user sequencing).
def test_ignore17c4b_actual_opponent_controller():
    board = value_copy(attack_declaration_fixture())
    board.command_points[1] = 0
    board[1][0].attack_modifier_permissions.append(rl.attack_modifier_permission(False, True, rl.IncomingAttackScope.any_attack()))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(1), 0, 0))
    board.attack_info = rl.declared_attack_info(board, rl.unit_id(1), rl.unit_id(0), declaration, board.attack_info)
    board.attack_info.hit_roll_malus = True
    board.current_decision_maker = False
    sequence = value_copy(rl.resolve_attack_dice(board, board[0], board[1], attack_test_count(1)))
    sequence.roll(board, board[0], board[1], attack_test_die(5))
    correct_owner = value_copy(board.current_decision_maker)
    sequence.apply_attack_modifier(board, board[0], board[1], False)
    sequence.roll(board, board[0], board[1], attack_test_die(1))
    return correct_owner and sequence.is_done() and (not board.current_decision_maker)

# Firing Deck attacks use the carrier's permission, not the passenger's;
# stable physical/borrowed identity remains separate (p.81/02.02.02).
def test_ignore17c4b_borrowed_carrier_permissions():
    board = value_copy(attack_declaration_fixture())
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    declaration.borrowed_weapon = True
    board[0][0].attack_modifier_permissions.append(rl.attack_modifier_permission(False, True, rl.IncomingAttackScope.ranged()))
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    return info.may_ignore_hit_modifiers and (not info.may_ignore_skill_modifiers)

# Source-owned permissions share expiry, overlaps, returned members and saved
# recipient integrity with numerical grants (01.02.02/02.02.02).
def test_ignore17c4b_source_permission_expiry_and_overlap():
    board = value_copy(attack_declaration_fixture())
    first = value_copy(source17e_instance(board, 0, 31))
    first.grant = rl.source_attack_modifier_grant(rl.attack_modifier_permission(True, True, rl.IncomingAttackScope.any_attack()))
    rl.register_source_instance(board, first)
    second = value_copy(first)
    second.rule = 32
    second.duration = rl.SourceDuration.turn()
    rl.register_source_instance(board, second)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(0))
    sequence.choose_source_event(board, source17e_id(1))
    board.begin_phase(rl.BattlePhase.shooting())
    still_allowed = value_copy(rl.attack_permission_available(board, board[0][0], False, True) and board[0][0].attack_modifier_permissions.size() == 1)
    rl.refresh_source_effects(board, rl.TimingWindow.turn_end())
    return still_allowed and (not rl.attack_permission_available(board, board[0][0], False, True)) and rl.valid_source_foundations(board)

# Offboard/archive cleanup cannot revive an expired ignore permission
# (01.02.02/01.02.04/p.88); prototypes stay untagged.
def test_ignore17c4b_source_permission_offboard_archive_cleanup():
    board = value_copy(attack_declaration_fixture())
    instance = value_copy(source17e_instance(board, 0, 33))
    instance.grant = rl.source_attack_modifier_grant(rl.attack_modifier_permission(True, False, rl.IncomingAttackScope.ranged()))
    rl.register_source_instance(board, instance)
    sequence = value_copy(rl.resolve_source_event(board, source17e_trigger(board, rl.SourceEventKind.timing_window(), 0)))
    sequence.choose_source_event(board, source17e_id(0))
    copy = value_copy(board[0])
    copy.identity = 0
    copy[0].identity = 0
    copy.retired = False
    board[0].remove_model(0)
    board.reserve_units.append(copy)
    board.begin_phase(rl.BattlePhase.shooting())
    return board[0].destroyed_models.value[0].attack_modifier_permissions.size() == 0 and board.reserve_units[0][0].attack_modifier_permissions.size() == 0

# Invalid permissions/choice origins and forged lifetime handles must fail
# restore checks instead of authorizing an arbitrary new source (02.02.02).
def test_ignore17c4b_invalid_permission_and_forged_handle():
    board = value_copy(attack_declaration_fixture())
    permission = value_copy(rl.attack_modifier_permission(True, False, rl.IncomingAttackScope.ranged()))
    permission.scope.value = 9
    board[0][0].attack_modifier_permissions.append(permission)
    scope_rejected = value_copy(not rl.valid_model_numeric_history(board[0][0]))
    board[0][0].attack_modifier_permissions.clear()
    permission.scope.value = rl.IncomingAttackScope.ranged().value
    permission.source_effect = 8
    board[0][0].attack_modifier_permissions.append(permission)
    handle_rejected = value_copy(not rl.valid_source_foundations(board))
    board.pending_modifier_choice.origin.value = 99
    return scope_rejected and handle_rejected and (not rl.valid_state_foundations(board))

# The pending choice and ordinary permission list survive a complete Game
# save/restore; new schemas protect changed layouts (infrastructure/02.02.02).
def test_ignore17c4b_saved_permission_and_pending_label():
    state = value_copy(rl.play())
    state.board = attack_declaration_fixture()
    state.board[0][0].attack_modifier_permissions.append(rl.attack_modifier_permission(True, True, rl.IncomingAttackScope.any_attack()))
    state.board.pending_modifier_kind = rl.ModifierSelectionKind.hit_roll()
    state.board.pending_modifier_choice = rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.add(), -1), rl.ModifierOrigin.heavy())
    restored = value_copy(rl.play())
    return rl.set_state(restored, rl.to_string(state)) and restored.board[0][0].attack_modifier_permissions.size() == 1 and (rl.modifier_choice_label(restored.board) == rl.modifier_choice_label(state.board)) and (restored.board.schema_version.value == rl.STATE_SCHEMA_VERSION)

# Core modifiers fit alongside every supported authored skill record;18 is
# a collection bound, while each Apply/Ignore payload still enumerates2 (02.02.02).
def test_ignore17c4b_full_skill_list_plus_core_capacity():
    board = value_copy(attack_declaration_fixture())
    info = value_copy(orks17c2b_info(board, 0))
    for modifier_index in range(16):
        info.skill_modifiers.append(rl.rule_modifier(rl.ModifierOperation.add(), 1))
    info.plunging_fire = True
    info.target_has_cover = True
    options = value_copy(rl.attack_skill_choices(board, info))
    sequence = value_copy(rl.choose_attack_modifiers(board, options, False, rl.ModifierSelectionKind.ballistic_skill(), True))
    for selected_index in range(18):
        sequence.apply_attack_modifier(board, False)
    return options.size() == 18 and sequence.is_done() and (sequence.result.size() == 0) and (rl.selected_attack_skill(info, sequence.result) == info.source.skill())


# A suspended chooser round-trips its index/result, not just the Board label;
# ctx ownership remains the caller's after restore (02.02.02 infrastructure).
def test_ignore17c4b_pending_frame_round_trip():
    board = value_copy(attack_declaration_fixture())
    choices = rl.new('AttackModifierChoices')
    choices.append(rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.add(), 2), rl.ModifierOrigin.characteristic()))
    choices.append(rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.add(), -1), rl.ModifierOrigin.cover()))
    sequence = value_copy(rl.choose_attack_modifiers(board, choices, False, rl.ModifierSelectionKind.ballistic_skill(), True))
    sequence.apply_attack_modifier(board, True)
    restored = value_copy(rl.choose_attack_modifiers(board, choices, False, rl.ModifierSelectionKind.ballistic_skill(), True))
    parsed = value_copy(rl.from_string(restored, rl.to_string(sequence)))
    restored.apply_attack_modifier(board, False)
    return parsed and restored.is_done() and (restored.result.size() == 1) and (restored.result[0].signed_amount() == 2)

# Roll arithmetic measures retained operations against the original die before
# applying the hit cap, including non-additive operations (02.02.01/02.02.02).
def test_ignore17c4b_nonadditive_roll_arithmetic():
    modifiers = rl.new('SelectedAttackModifiers')
    modifiers.append(rl.rule_modifier(rl.ModifierOperation.multiply(), 2))
    doubled = value_copy(rl.selected_hit_bonus(4, modifiers))
    modifiers.clear()
    modifiers.append(rl.rule_modifier(rl.ModifierOperation.replace(), 1))
    return doubled == 1 and rl.selected_hit_bonus(4, modifiers) == -1

# Current Army Rules fixtures, not replacement Orks datasheets. Profile data
# intentionally remains the small existing core combat fixture (Orks17.F).
def orks17f_fixture():
    board = value_copy(attack_declaration_fixture())
    board.armies[0].faction = rl.ArmyFaction.orks()
    board.armies[1].faction = rl.ArmyFaction.orks()
    board[0][0].keywords.append(rl.Keyword.orks())
    board[1][0].keywords.append(rl.Keyword.orks())
    board[0][0].has_waaagh = True
    board[1][0].has_waaagh = True
    board.identify_units()
    board.start_turn_history()
    return value_copy(board)

# Zero-key is an explicit intrinsic fixture grant; actual passives register
# stable model sources. No datasheet grants are inferred (Orks Waaagh!).
def orks17f_intrinsic_riled(model):
    key = rl.new('SourceEffectKey')
    model.riled_source_effects.append(key)

# Snapshot charge permission when selected to Advance, as Army Rules says;
# movement history persists it separately from subsequently changing buffs.
def orks17f_select_advance(board, source):
    board[source].history.advance_allows_charge = rl.unit_is_riled_up(board[source])
    rl.record_move(board, source, rl.MovementKind.advance())

# Only live ORKS units with explicit Waaagh! get the Advance re-roll.
def test_orks17f_waaagh_eligibility():
    board = value_copy(orks17f_fixture())
    valid = value_copy(rl.unit_has_waaagh(board[0]))
    board[0][0].has_waaagh = False
    absent = value_copy(not rl.unit_has_waaagh(board[0]))
    board[0][0].has_waaagh = True
    board[0][0].keywords.clear()
    foreign = value_copy(not rl.unit_has_waaagh(board[0]))
    board[0][0].keywords.append(rl.Keyword.orks())
    board[0][0].state = rl.ModelState.pending_destruction()
    return valid and absent and foreign and (not rl.unit_has_waaagh(board[0]))

# Riled supplies a5+ InSv where absent, keeps a better printed save and uses
# shared subsequent arithmetic rather than replacing a better choice.
def test_orks17f_riled_invulnerable_save():
    board = value_copy(orks17f_fixture())
    orks17f_intrinsic_riled(board[0][0])
    absent = value_copy(board[0][0].effective_invulnerable_save() == 5)
    board[0][0].profile = rl.Profile.captain_octavius()
    better = value_copy(board[0][0].effective_invulnerable_save() == 4)
    board[0][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.invulnerable_save(), rl.ModifierOperation.add(), -1))
    return absent and better and (board[0][0].effective_invulnerable_save() == 3)

# No inherited10th-edition +A/+S is introduced. Ranged Assault is per bearer,
# while melee and unrelated units retain their existing rules (Orks Waaagh!).
def test_orks17f_riled_assault_only_ranged():
    board = value_copy(orks17f_fixture())
    orks17f_intrinsic_riled(board[0][0])
    ranged = value_copy(rl.model_weapon_has_rule(board[0][0], 0, rl.WeaponRuleKind.assault()))
    foreign = value_copy(not rl.model_weapon_has_rule(board[1][0], 0, rl.WeaponRuleKind.assault()))
    board[0][0].weapons.append(rl.Weapon.choppa())
    melee = value_copy(not rl.model_weapon_has_rule(board[0][0], 1, rl.WeaponRuleKind.assault()))
    modifiers = value_copy(rl.model_weapon_modifiers(board[0][0], 1, rl.ModifiedCharacteristic.attacks(), False))
    return ranged and foreign and melee and (modifiers.size() == 0)

# Actual Assault mode and target legality consume the granted rule (pp.34–35;
# Orks Waaagh!). Riled does not permit shooting after Fall Back or engagement.
def test_orks17f_assault_shooting_consumers():
    board = value_copy(orks17f_fixture())
    orks17f_intrinsic_riled(board[0][0])
    orks17f_select_advance(board, rl.unit_id(0))
    board.begin_phase(rl.BattlePhase.shooting())
    board[0].shooting_kind = rl.ShootingKind.assault()
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    valid = value_copy(rl.shooting_kind_valid(board, rl.unit_id(0), rl.ShootingKind.assault()) and rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), False))
    board[0].history.fell_back_this_turn = True
    return valid and (not rl.shooting_unit_valid(board, rl.unit_id(0)))

# Charge permission belongs to this selected Advance even after riled expiry.
# Granting riled after an ordinary Advance cannot retroactively waive it.
def test_orks17f_advance_charge_snapshot():
    board = value_copy(orks17f_fixture())
    orks17f_intrinsic_riled(board[0][0])
    orks17f_select_advance(board, rl.unit_id(0))
    board[0][0].riled_source_effects.clear()
    retained = value_copy(rl.charge_source_valid(board, rl.unit_id(0), False))
    board.start_turn_history()
    orks17f_select_advance(board, rl.unit_id(0))
    orks17f_intrinsic_riled(board[0][0])
    return retained and (not rl.charge_source_valid(board, rl.unit_id(0), False))

# Other charge restrictions remain even for riled units (pp.33/65/74).
def test_orks17f_charge_restrictions_and_reset():
    board = value_copy(orks17f_fixture())
    orks17f_intrinsic_riled(board[0][0])
    orks17f_select_advance(board, rl.unit_id(0))
    board[0].history.fell_back_this_turn = True
    fallback = value_copy(not rl.charge_source_valid(board, rl.unit_id(0), False))
    board[0].history.fell_back_this_turn = False
    board[0].can_charge = False
    unrelated = value_copy(not rl.charge_source_valid(board, rl.unit_id(0), False))
    board.start_turn_history()
    return fallback and unrelated and (not board[0].history.advance_allows_charge) and (not board[0].history.advanced_this_turn)

# Waaagh! free re-roll enters the real Advance roll, without CP expenditure.
# This test stops at movement input; placement legality remains core fixtures.
def test_orks17f_actual_advance_reroll():
    board = value_copy(orks17f_fixture())
    board.begin_phase(rl.BattlePhase.movement())
    sequence = value_copy(rl.movement(board, rl.unit_id(0), False))
    sequence.advance(board, True)
    die = rl.new('Dice')
    assign(die, 2)
    sequence.roll(board, die)
    valid = value_copy(sequence.can_keep_it(board, False))
    sequence.keep_it(board, False)
    assign(die, 5)
    sequence.reroll(board, die)
    return valid and board.command_points[0] == 0 and (board.current_roll.result.value == 5)

# Command-start choice is available to both armies, with current player first.
# Declining War Cry spends no battle use and restores decision ownership.
def test_orks17f_war_cry_decline_and_controller_order():
    board = value_copy(orks17f_fixture())
    board.begin_phase(rl.BattlePhase.command())
    sequence = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.command_start()))
    rule = value_copy(rl.OrksTimingRule.war_cry())
    first = value_copy(not board.current_decision_maker and sequence.can_choose_orks_timing_rule(board, rule))
    sequence.finish_timing_rules(board)
    second = value_copy(board.current_decision_maker and sequence.can_choose_orks_timing_rule(board, rule))
    sequence.finish_timing_rules(board)
    return first and second and sequence.is_done() and (not board.armies[0].war_cry_used) and (not board.armies[1].war_cry_used) and (not board.current_decision_maker)

# Either Command start may call it once per army; the opponent never receives
# the other army's grant. Applying it spends no CP (Orks War Cry).
def test_orks17f_war_cry_both_armies_and_once():
    board = value_copy(orks17f_fixture())
    board.begin_phase(rl.BattlePhase.command())
    sequence = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.command_start()))
    sequence.choose_orks_timing_rule(board, rl.OrksTimingRule.war_cry())
    isolated = value_copy(rl.unit_is_riled_up(board[0]) and (not rl.unit_is_riled_up(board[1])) and board.armies[0].war_cry_used)
    sequence.choose_orks_timing_rule(board, rl.OrksTimingRule.war_cry())
    resolved = rl.new('Bool[2]')
    return isolated and sequence.is_done() and rl.unit_is_riled_up(board[1]) and board.armies[1].war_cry_used and (not rl.orks_timing_rule_available(board, rl.TimingWindow.command_start(), False, rl.OrksTimingRule.war_cry(), resolved)) and (board.command_points[0] == 0) and (board.command_points[1] == 0)

# Printed start window excludes Command abilities/end/round; configured
# non-Orks armies cannot activate a stray fixture's Waaagh! data.
def test_orks17f_war_cry_wrong_window_and_faction():
    board = value_copy(orks17f_fixture())
    resolved = rl.new('Bool[2]')
    absent = value_copy(not rl.orks_timing_rule_available(board, rl.TimingWindow.command_abilities(), False, rl.OrksTimingRule.war_cry(), resolved) and (not rl.orks_timing_rule_available(board, rl.TimingWindow.round_start(), False, rl.OrksTimingRule.war_cry(), resolved)))
    board.armies[0].faction = rl.ArmyFaction.space_marines()
    return absent and (not rl.war_cry_available(board, False))

# End of NEXT turn is distinct from end of activation turn and next start.
# Activation in either player's turn has the same two-turn interval.
def test_orks17f_war_cry_end_next_turn():
    board = value_copy(orks17f_fixture())
    board.open_timing_window(rl.TimingWindow.command_start())
    rl.call_war_cry(board, False)
    board.close_timing_window()
    rl.refresh_source_effects(board, rl.TimingWindow.turn_end())
    own_end = value_copy(rl.unit_is_riled_up(board[0]))
    board.current_player = True
    board.start_turn_history()
    next_start = value_copy(rl.unit_is_riled_up(board[0]))
    rl.refresh_source_effects(board, rl.TimingWindow.turn_end())
    return own_end and next_start and (not rl.unit_is_riled_up(board[0])) and board.source_effects.empty() and board.armies[0].war_cry_used

# Offboard army units receive War Cry without illegal range/visibility tests;
# a missing Waaagh! ability is not granted by faction membership alone.
def test_orks17f_war_cry_reserves_and_passengers():
    board = value_copy(orks17f_fixture())
    reserved = rl.new('Unit')
    assign(reserved, board[0])
    reserved.identity = rl.invalid_entity_identity()
    reserved[0].identity = rl.invalid_entity_identity()
    board.identify_unit(reserved)
    rl.mark_unit_offboard(reserved, True)
    board.reserve_units.append(reserved)
    embarked = rl.new('Unit')
    assign(embarked, reserved)
    embarked.identity = rl.invalid_entity_identity()
    embarked[0].identity = rl.invalid_entity_identity()
    board.identify_unit(embarked)
    board.embarked_units.append(embarked)
    board[1][0].has_waaagh = False
    board.open_timing_window(rl.TimingWindow.command_start())
    rl.call_war_cry(board, False)
    board.close_timing_window()
    return rl.unit_is_riled_up(board[0]) and rl.unit_is_riled_up(board.reserve_units[0]) and rl.unit_is_riled_up(board.embarked_units[0]) and (not rl.unit_is_riled_up(board[1])) and (board.source_effects.size() == 3)

# A retained/destroyed source cannot cancel the accepted army-wide War Cry.
# Archived grants are nevertheless cleaned up at their printed expiry.
def test_orks17f_war_cry_source_death_archive_cleanup():
    board = value_copy(orks17f_fixture())
    board.open_timing_window(rl.TimingWindow.command_start())
    rl.call_war_cry(board, False)
    board.close_timing_window()
    board[0][0].state = rl.ModelState.pending_destruction()
    board[0].remove_model(0)
    board.current_player = True
    board.start_turn_history()
    persisted = value_copy(board[0].destroyed_models.value[0].is_riled_up())
    rl.refresh_source_effects(board, rl.TimingWindow.turn_end())
    return persisted and (not board[0].destroyed_models.value[0].is_riled_up())

# Overlapping permanent and War Cry copies retain independent handles; only
# live-model permanent sources end on source death (Stompa Effigy/Super Runts).
def test_orks17f_permanent_and_war_cry_overlap():
    board = value_copy(orks17f_fixture())
    board[0][0].grants_unit_riled_up = True
    rl.register_orks_passive_rules(board)
    rl.register_orks_passive_rules(board)
    single = value_copy(board.source_instances.size() == 1 and board[0][0].riled_source_effects.size() == 1)
    board.open_timing_window(rl.TimingWindow.command_start())
    rl.call_war_cry(board, False)
    board.close_timing_window()
    overlap = value_copy(board[0][0].riled_source_effects.size() == 2)
    board.current_player = True
    board.start_turn_history()
    rl.refresh_source_effects(board, rl.TimingWindow.turn_end())
    return single and overlap and (board[0][0].riled_source_effects.size() == 1) and rl.unit_is_riled_up(board[0])

# Own-unit passives work in reserves/embarked banks; they are not external
# auras and require no range to an offboard unit (appendix01.02.04).
def test_orks17f_permanent_offboard_bank_transfer():
    board = value_copy(orks17f_fixture())
    board[0][0].grants_unit_riled_up = True
    rl.mark_unit_offboard(board[0], True)
    board.reserve_units.append(board[0])
    board.units.erase(0)
    rl.register_orks_passive_rules(board)
    reserved = value_copy(rl.unit_is_riled_up(board.reserve_units[0]))
    board.embarked_units.append(board.reserve_units[0])
    board.reserve_units.erase(0)
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return reserved and rl.unit_is_riled_up(board.embarked_units[0]) and (board.source_effects.size() == 1)

# Permanent source follows a transferred model's current unit, while overlap
# keys from other sources are retained. Attachment integration remains17.G.
def test_orks17f_permanent_source_transfer():
    board = value_copy(orks17f_fixture())
    board[0].models.append(board[0][0])
    board[0][1].identity = rl.invalid_entity_identity()
    board.identify_unit(board[0])
    board[0][0].grants_unit_riled_up = True
    rl.register_orks_passive_rules(board)
    target = rl.new('Unit')
    target.owned_by_player1 = False
    target.models.append(board[0][0])
    board[0].models.erase(0)
    board.identify_unit(target)
    board.units.append(target)
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return not rl.unit_is_riled_up(board[0]) and rl.unit_is_riled_up(board.units.back()) and (board.source_effects.size() == 1)

# A model death stops the source-bound passive for its surviving unit; Fight
# on Death retention is not active ability permission (destruction p.87).
def test_orks17f_permanent_source_death():
    board = value_copy(orks17f_fixture())
    board[0].models.append(board[0][0])
    board[0][1].identity = rl.invalid_entity_identity()
    board.identify_unit(board[0])
    board[0][0].grants_unit_riled_up = True
    rl.register_orks_passive_rules(board)
    board[0][0].state = rl.ModelState.pending_destruction()
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return not rl.unit_is_riled_up(board[0]) and (not board[0][0].is_riled_up()) and board.source_effects.empty()

# Da Boss requires exactly the selected live Warlord's explicit ability, not
# an arbitrary living boss. Mandatory round-start1CP is separate from Core CP.
def test_orks17f_da_boss_mandatory_once_per_window():
    board = value_copy(orks17f_fixture())
    board[0][0].has_da_boss = True
    board.armies[0].warlord = board[0][0].identity
    board[0][0].keywords.append(rl.Keyword.character())
    board[0][0].keywords.append(rl.Keyword.warlord())
    sequence = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.round_start()))
    mandatory = value_copy(not sequence.can_finish_timing_rules(board))
    sequence.choose_orks_timing_rule(board, rl.OrksTimingRule.da_boss())
    return mandatory and sequence.is_done() and (board.command_points[0] == 1) and (board.command_points[1] == 0) and (not board.current_decision_maker)

# Both players receive their own mandatory1CP in controller order. Neither
# gains it from a different player's Warlord (Orks Army Rules / Da Boss).
def test_orks17f_da_boss_both_players():
    board = value_copy(orks17f_fixture())
    board[0][0].has_da_boss = True
    board[1][0].has_da_boss = True
    board.armies[0].warlord = board[0][0].identity
    board[0][0].keywords.append(rl.Keyword.character())
    board[0][0].keywords.append(rl.Keyword.warlord())
    board.armies[1].warlord = board[1][0].identity
    board[1][0].keywords.append(rl.Keyword.character())
    board[1][0].keywords.append(rl.Keyword.warlord())
    sequence = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.round_start()))
    sequence.choose_orks_timing_rule(board, rl.OrksTimingRule.da_boss())
    opponent = value_copy(board.current_decision_maker and (not sequence.can_finish_timing_rules(board)))
    sequence.choose_orks_timing_rule(board, rl.OrksTimingRule.da_boss())
    return opponent and sequence.is_done() and (board.command_points[0] == 1) and (board.command_points[1] == 1)

# Missing, foreign or destroyed Warlord never substitutes another model;
# selected reserve Warlord can use its own rule (appendix01.02.04).
def test_orks17f_da_boss_identity_life_and_offboard():
    board = value_copy(orks17f_fixture())
    board[0][0].has_da_boss = True
    unset = value_copy(not rl.da_boss_available(board, False))
    board.armies[0].warlord = board[1][0].identity
    foreign = value_copy(not rl.da_boss_available(board, False) and (not rl.valid_orks_army_state(board)))
    board.armies[0].warlord = board[0][0].identity
    board[0][0].keywords.append(rl.Keyword.character())
    board[0][0].keywords.append(rl.Keyword.warlord())
    rl.mark_unit_offboard(board[0], True)
    board.reserve_units.append(board[0])
    board.units.erase(0)
    offboard = value_copy(rl.da_boss_available(board, False))
    board.reserve_units[0][0].state = rl.ModelState.pending_destruction()
    return unset and foreign and offboard and (not rl.da_boss_available(board, False))

# Supplied11th-edition Da Boss lacks the legacy extra-CP ceiling. Existing
# CP is preserved and literal gain is not silently blocked by that old flag.
def test_orks17f_da_boss_literal_cp_gain():
    board = value_copy(orks17f_fixture())
    board[0][0].has_da_boss = True
    board.armies[0].warlord = board[0][0].identity
    board[0][0].keywords.append(rl.Keyword.character())
    board[0][0].keywords.append(rl.Keyword.warlord())
    board.obtained_extra_cp_this_round[0] = True
    board.command_points[0] = 7
    sequence = value_copy(rl.resolve_timing_window(board, rl.TimingWindow.round_start()))
    sequence.choose_orks_timing_rule(board, rl.OrksTimingRule.da_boss())
    return sequence.is_done() and board.command_points[0] == 8

# Matching Game saves retain army usage, stable Warlord and pending riled
# effects. Bad keys/source metadata are rejected before effective consumers.
def test_orks17f_saved_state_and_forged_handles():
    game = value_copy(rl.play())
    game.board = orks17f_fixture()
    game.board.armies[0].warlord = game.board[0][0].identity
    game.board[0][0].keywords.append(rl.Keyword.character())
    game.board[0][0].keywords.append(rl.Keyword.warlord())
    game.board.open_timing_window(rl.TimingWindow.command_start())
    rl.call_war_cry(game.board, False)
    game.board.close_timing_window()
    saved = value_copy(rl.to_string(game))
    restored = value_copy(rl.play())
    accepted = value_copy(rl.set_state(restored, saved))
    retained = value_copy(accepted and restored.board.armies[0].war_cry_used and restored.board[0][0].is_riled_up() and (restored.board.armies[0].warlord == game.board.armies[0].warlord))
    restored.board[0][0].riled_source_effects[0].value = 999
    return retained and (not rl.valid_state_foundations(restored.board))

# Stale selected Assault snapshots cannot outlive their riled effect (p.78;
# appendix01.02.02). This also tests the actual declaration-rule consumer.
def test_orks17f_assault_snapshot_expiry():
    board = value_copy(orks17f_fixture())
    board.open_timing_window(rl.TimingWindow.command_start())
    rl.call_war_cry(board, False)
    board.close_timing_window()
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    before = value_copy(rl.chosen_weapon_has_rule(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.assault()))
    board.current_player = True
    board.start_turn_history()
    rl.refresh_source_effects(board, rl.TimingWindow.turn_end())
    return before and (not rl.chosen_weapon_has_rule(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.assault())) and (not rl.model_weapon_has_rule(board[0][0], 0, rl.WeaponRuleKind.assault()))

# User-supplied Warlord definition: an Orks Character unit, then a Character
# model. Other player/non-faction/non-Character candidates remain illegal.
def orks17f_warlord_fixture():
    board = value_copy(orks17f_fixture())
    board[0][0].keywords.append(rl.Keyword.character())
    board[1][0].keywords.append(rl.Keyword.character())
    rl.mark_unit_offboard(board[0], True)
    rl.mark_unit_offboard(board[1], True)
    board.reserve_units.append(board[0])
    board.reserve_units.append(board[1])
    board.units.clear()
    return value_copy(board)

# Real two-step selector rejects foreign/spare indices, grants WARLORD and
# restores the previous decision owner/context (user Warlord definition).
def test_orks17f_actual_warlord_selection():
    board = value_copy(orks17f_warlord_fixture())
    board.current_decision_maker = True
    board.selected_warlord_unit = 1
    sequence = value_copy(rl.select_orks_warlord(board, False))
    unit = rl.new('UnitID')
    assign(unit, 1)
    foreign = value_copy(not sequence.can_choose_warlord_unit(board, unit))
    assign(unit, 31)
    spare = value_copy(not sequence.can_choose_warlord_unit(board, unit))
    assign(unit, 0)
    sequence.choose_warlord_unit(board, unit)
    model = rl.new('ModelID')
    assign(model, 31)
    spare_model = value_copy(not sequence.can_choose_warlord_model(board, model))
    assign(model, 0)
    sequence.choose_warlord_model(board, model)
    return foreign and spare and spare_model and sequence.is_done() and board.reserve_units[0][0].has_keyword(rl.Keyword.warlord()) and (board.armies[0].warlord == board.reserve_units[0][0].identity) and board.current_decision_maker and (board.selected_warlord_unit.get() == 1) and rl.valid_state_foundations(board)

# Forced named model takes precedence over an ordinary alternative; if several
# units require a Warlord, select one eligible required unit (user definition).
def test_orks17f_required_warlord_and_model():
    board = value_copy(orks17f_warlord_fixture())
    board.reserve_units[0].models.append(board.reserve_units[0][0])
    board.reserve_units[0][1].identity = rl.invalid_entity_identity()
    board.identify_unit(board.reserve_units[0])
    board.reserve_units[0][1].must_be_warlord = True
    model = rl.new('ModelID')
    ordinary = value_copy(not rl.orks_warlord_model_valid(board, False, rl.unit_id(0), model))
    assign(model, 1)
    return ordinary and rl.orks_warlord_model_valid(board, False, rl.unit_id(0), model) and (not rl.orks_warlord_unit_valid(board, False, rl.unit_id(1)))

# Prohibition overrides required status and excludes that model from both
# optional and forced eligibility (user Warlord definition).
def test_orks17f_cannot_warlord_overrides_required():
    board = value_copy(orks17f_warlord_fixture())
    board.reserve_units[0].models.append(board.reserve_units[0][0])
    board.reserve_units[0][1].identity = rl.invalid_entity_identity()
    board.identify_unit(board.reserve_units[0])
    board.reserve_units[0][0].must_be_warlord = True
    board.reserve_units[0][0].cannot_be_warlord = True
    model = rl.new('ModelID')
    prohibited = value_copy(not rl.orks_warlord_model_valid(board, False, rl.unit_id(0), model))
    assign(model, 1)
    return prohibited and rl.orks_warlord_model_valid(board, False, rl.unit_id(0), model)

# A required unit can supply any eligible Character; the unit's faction union
# and model's Character status are checked independently (user definition).
def test_orks17f_warlord_unit_and_character_conditions():
    board = value_copy(orks17f_warlord_fixture())
    board.reserve_units[0].must_supply_warlord = True
    model = rl.new('ModelID')
    required = value_copy(rl.orks_warlord_model_valid(board, False, rl.unit_id(0), model))
    board.reserve_units[0][0].keywords.clear()
    board.reserve_units[0][0].keywords.append(rl.Keyword.orks())
    non_character = value_copy(not rl.orks_warlord_unit_valid(board, False, rl.unit_id(0)))
    board.reserve_units[0][0].keywords.clear()
    board.reserve_units[0][0].keywords.append(rl.Keyword.character())
    return required and non_character and (not rl.orks_warlord_unit_valid(board, False, rl.unit_id(0)))

# Two required units still allow exactly one Warlord; unit/model prohibitions
# must not be inferred from a datasheet name (user definition).
def test_orks17f_multiple_required_units():
    board = value_copy(orks17f_warlord_fixture())
    board.reserve_units[1].owned_by_player1 = False
    board.reserve_units[0].must_supply_warlord = True
    board.reserve_units[1].must_supply_warlord = True
    sequence = value_copy(rl.select_orks_warlord(board, False))
    choices = value_copy(sequence.can_choose_warlord_unit(board, rl.unit_id(0)) and sequence.can_choose_warlord_unit(board, rl.unit_id(1)))
    sequence.choose_warlord_unit(board, rl.unit_id(1))
    model = rl.new('ModelID')
    sequence.choose_warlord_model(board, model)
    return choices and sequence.is_done() and (not board.reserve_units[0][0].has_keyword(rl.Keyword.warlord())) and board.reserve_units[1][0].has_keyword(rl.Keyword.warlord())

# Firing Deck's borrowed profile receives the carrier's riled Assault without
# modifying the passenger's equipped gun (p.81 / Orks Waaagh!).
def test_orks17f_borrowed_carrier_assault():
    board = value_copy(orks17f_fixture())
    passenger = rl.new('Unit')
    assign(passenger, board[1])
    passenger.owned_by_player1 = False
    passenger.embarked_transport = board[0][0].identity
    rl.mark_unit_offboard(passenger, True)
    board.embarked_units.append(passenger)
    board[1].models.clear()
    board[1].retired = True
    board[0][0].firing_deck = 1
    board[0][0].weapons.clear()
    orks17f_intrinsic_riled(board[0][0])
    model = rl.new('ModelID')
    declaration = value_copy(rl.make_deck_declaration(board, rl.unit_id(0), model, rl.unit_id(0), model, 0))
    return rl.carrier_has_ranged_rule(board, rl.unit_id(0), rl.WeaponRuleKind.assault()) and rl.chosen_weapon_has_rule(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.assault()) and (not rl.model_weapon_has_rule(board.embarked_units[0][0], 0, rl.WeaponRuleKind.assault()))

# P66/source-list fixtures use existing circle/profiles only as test data.
# Named attachment metadata does not claim complete current Orks datasheets.
def attachment17g_fixture():
    board = rl.new('Board')
    bodyguard = value_copy(rl.make_infernus_squad())
    for model in range(bodyguard.models.size()):
        bodyguard[model].abilities.clear()
    rl.configure_orks_attachment(bodyguard, rl.OrksDatasheet.boyz())
    board.reserve_units.append(bodyguard)
    leader = value_copy(rl.make_tantus())
    leader[0].abilities.clear()
    rl.configure_orks_attachment(leader, rl.OrksDatasheet.warboss())
    board.reserve_units.append(leader)
    support = value_copy(rl.make_octavius())
    support[0].abilities.clear()
    rl.configure_orks_attachment(support, rl.OrksDatasheet.painboy())
    board.reserve_units.append(support)
    board.identify_units()
    return value_copy(board)

# Move an already formed fixture to the battlefield; this is not a setup
# permission or a substitute for the later datasheet/geometry adapters.
def attachment17g_battlefield(board):
    while not board.reserve_units.empty():
        rl.mark_unit_offboard(board.reserve_units[0], False)
        board.units.append(board.reserve_units[0])
        board.reserve_units.erase(0)
    for unit in range(board.units.size()):
        for model in range(board[unit].models.size()):
            board[unit][model].position = board_position(5 + model % 4 * 2 + unit * 15, 5 + model // 4 * 2)
        board[unit].capture_starting_strength()
        board[unit].can_shoot = True
        board[unit].can_charge = True

# Typed per-component source helper: effects apply to the attached unit while
# its original Leader component confers them (pp.66–67/19.04).
def attachment17g_source(board, component, rule):
    source = rl.new('SourceInstance')
    source.source_unit = component
    source.rule = rule
    source.name.value = rl.s('Attachment lifetime fixture')
    source.owner = False
    source.own_unit_passive = True
    source.offboard_allowed = True
    source.requires_live_source = True
    source.duration = rl.SourceDuration.battle()
    source.grant = rl.source_characteristic_grant(rl.characteristic_modifier(rl.ModifiedCharacteristic.movement(), rl.ModifierOperation.add(), 2))
    return value_copy(source)

# Main damage entry snapshots a real attacking unit rather than using low-level
# storage damage as a substitute for p67 timing (damage/destruction pp.19/87).
def attachment17g_job(target, attacker, from_attack):
    return value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(target), rl.unit_id(attacker), True, from_attack, 1, rl.invalid_entity_identity()))

# All17 included Leader/Support rows, including the six-entry Big Mek maximum.
# Lists are independently checked against the retrieved attachment cards.
def test_attachment17g_included_permission_role_counts():
    leaders = value_copy(0)
    supports = value_copy(0)
    tag = rl.new('OrksDatasheet')
    for code in range(rl.MAX_DATASHEETCODE):
        tag.value = code
        unit = rl.new('Unit')
        rl.configure_orks_attachment(unit, tag)
        if unit.attachment_role.value == rl.AttachmentRole.leader().value:
            leaders = leaders + 1
        if unit.attachment_role.value == rl.AttachmentRole.support().value:
            supports = supports + 1
    return leaders == 10 and supports == 7

# Explicit examples distinguish related cards: only Mega Armour/Nazdreg lead
# Meganobz, while Shokk Attack Gun lacks Big Mek's Flash Gitz/Breaka permissions.
def test_attachment17g_exact_permission_lists():
    mek = rl.new('Unit')
    rl.configure_orks_attachment(mek, rl.OrksDatasheet.big_mek())
    big = value_copy(mek.permitted_bodyguards.size() == 6 and mek.permitted_bodyguards[2].value == rl.OrksDatasheet.flash_gitz().value and (mek.permitted_bodyguards[5].value == rl.OrksDatasheet.tankbustas().value))
    rl.configure_orks_attachment(mek, rl.OrksDatasheet.big_mek_with_shokk_attack_gun())
    shokk = value_copy(mek.permitted_bodyguards.size() == 4 and mek.permitted_bodyguards[1].value == rl.OrksDatasheet.mek_gunz().value and (mek.permitted_bodyguards[2].value == rl.OrksDatasheet.nobz().value))
    rl.configure_orks_attachment(mek, rl.OrksDatasheet.nazdreg())
    return big and shokk and (mek.permitted_bodyguards.size() == 1) and (mek.permitted_bodyguards[0].value == rl.OrksDatasheet.meganobz().value)

# No excluded Forge World/Legends source receives an attachment implementation.
def test_attachment17g_excluded_and_unknown_unavailable():
    unit = rl.new('Unit')
    rl.configure_orks_attachment(unit, rl.OrksDatasheet.warboss_on_warbike())
    legends = value_copy(unit.attachment_role.value == 0 and unit.permitted_bodyguards.empty())
    rl.configure_orks_attachment(unit, rl.OrksDatasheet.gargantuan_squiggoth())
    forge = value_copy(unit.attachment_role.value == 0 and unit.permitted_bodyguards.empty())
    rl.configure_orks_attachment(unit, rl.OrksDatasheet.unknown())
    return legends and forge and unit.permitted_bodyguards.empty() and (unit.attachment_role.value == 0)

# P66 permits one role of each kind; identity/whole-model history is preserved.
def test_attachment17g_leader_and_support_slots():
    board = value_copy(attachment17g_fixture())
    leader = value_copy(board.reserve_units[1].identity)
    support = value_copy(board.reserve_units[2].identity)
    model = value_copy(board.reserve_units[1][0].identity)
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    leader_only = value_copy(board.reserve_units[0].attached_units.size() == 1 and (not rl.attachment_role_available(board.reserve_units[0], rl.AttachmentRole.leader())))
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    combined = board.reserve_units[0]
    return leader_only and combined.models.size() == 7 and (combined.attached_units.size() == 2) and (combined.attached_units[0].identity == leader) and (combined.attached_units[1].identity == support) and (combined[5].identity == model) and (combined[5].original_unit == leader) and (combined.starting_strenght == 7) and (combined.bodyguard_starting_strength == 5) and rl.valid_state_foundations(board)

# Support-first has the same role budgets, not a blanket one-character limit.
def test_attachment17g_support_then_leader():
    board = value_copy(attachment17g_fixture())
    rl.attach_reserved_unit(board, rl.unit_id(2), rl.unit_id(0), False)
    support_only = value_copy(not rl.attachment_role_available(board.reserve_units[0], rl.AttachmentRole.support()) and rl.attachment_role_available(board.reserve_units[0], rl.AttachmentRole.leader()))
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    return support_only and board.reserve_units[0].attached_units.size() == 2 and (board.reserve_units[0].starting_strenght == 7)

# Foreign, self, spare, wrong bodyguard, already-attached and in-battle choices
# are rejected without mutating state (p66/Godot bounded selectors).
def test_attachment17g_legality_rejects_invalid_and_atomic():
    board = value_copy(attachment17g_fixture())
    before = value_copy(rl.to_string(board))
    rejected = value_copy(not rl.attachment_valid(board, rl.unit_id(1), rl.unit_id(1), False) and (not rl.attachment_valid(board, rl.unit_id(31), rl.unit_id(0), False)) and (not rl.attachment_valid(board, rl.unit_id(1), rl.unit_id(31), False)) and (not rl.attachment_valid(board, rl.unit_id(1), rl.unit_id(0), True)) and (not rl.attachment_valid(board, rl.unit_id(1), rl.unit_id(2), False)))
    unchanged = value_copy(rl.to_string(board) == before)
    board.reserve_units[0].roster_datasheet = rl.OrksDatasheet.gretchin().value
    wrong = value_copy(not rl.attachment_valid(board, rl.unit_id(1), rl.unit_id(0), False))
    board.reserve_units[0].roster_datasheet = rl.OrksDatasheet.boyz().value
    board.start_turn_history()
    return rejected and unchanged and wrong and (not rl.attachment_valid(board, rl.unit_id(1), rl.unit_id(0), False))

# Generic p66 transfer supports multi-model leaders instead of asserting size1.
# Source components retain their own count within the combined starting strength.
def test_attachment17g_multi_model_leader():
    board = value_copy(attachment17g_fixture())
    board.reserve_units[1].models.append(board.reserve_units[1][0])
    board.reserve_units[1][1].identity = rl.invalid_entity_identity()
    board.identify_unit(board.reserve_units[1])
    second = value_copy(board.reserve_units[1][1].identity)
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    return board.reserve_units[0].models.size() == 7 and board.reserve_units[0].attached_units[0].starting_strength == 2 and (board.reserve_units[0][6].identity == second) and rl.valid_state_foundations(board)

# Duplicate Leaders/Supports cannot consume an existing role; empty/dead
# prebattle sources and overflow also cannot produce a valid action (p66).
def test_attachment17g_duplicate_role_and_capacity():
    board = value_copy(attachment17g_fixture())
    rl.configure_orks_attachment(board.reserve_units[2], rl.OrksDatasheet.warboss())
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    duplicate = value_copy(not rl.attachment_valid(board, rl.unit_id(1), rl.unit_id(0), False))
    bounded = value_copy(attachment17g_fixture())
    bounded.reserve_units[0].models.resize(32)
    for offset in range(27):
        model = value_copy(offset + 5)
        bounded.reserve_units[0][model] = bounded.reserve_units[0][0]
        bounded.reserve_units[0][model].identity = rl.invalid_entity_identity()
    bounded.identify_unit(bounded.reserve_units[0])
    return duplicate and (not rl.attachment_valid(bounded, rl.unit_id(1), rl.unit_id(0), False))

# Attaching an earlier reserve slot safely commits to the later target before
# erasure/compaction; persistent model/source references do not shift (p66/88).
def test_attachment17g_source_before_target_compaction():
    board = value_copy(attachment17g_fixture())
    bodyguard = rl.new('Unit')
    assign(bodyguard, board.reserve_units[0])
    board.reserve_units[0] = board.reserve_units[1]
    board.reserve_units[1] = bodyguard
    target = value_copy(board.reserve_units[1].identity)
    rl.attach_reserved_unit(board, rl.unit_id(0), rl.unit_id(1), False)
    return board.reserve_units[0].identity == target and board.reserve_units[0].models.size() == 6 and (board.reserve_units[0].attached_units.size() == 1)

# Actual prebattle frame owns choices and restores its caller. Passing one
# player cannot let that player re-enter or prevent the other from attaching.
def test_attachment17g_frame_owner_and_passes():
    board = value_copy(attachment17g_fixture())
    board.current_decision_maker = True
    sequence = value_copy(rl.attach_leaders(board))
    first = value_copy(not board.current_decision_maker and sequence.can_attach_unit(board, rl.unit_id(1), rl.unit_id(0)))
    sequence.done_attaching(board)
    second = value_copy(board.current_decision_maker and (not sequence.can_attach_unit(board, rl.unit_id(1), rl.unit_id(0))))
    sequence.done_attaching(board)
    return first and second and sequence.is_done() and board.current_decision_maker

# p67 unit keyword union does not copy Leader keywords into bodyguard models.
def test_attachment17g_keyword_union_not_model_spread():
    board = value_copy(attachment17g_fixture())
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    return board.reserve_units[0].has_keyword(rl.Keyword.psyker()) and (not board.reserve_units[0][0].has_keyword(rl.Keyword.psyker())) and board.reserve_units[0][5].has_keyword(rl.Keyword.psyker())

# Bodyguard T outranks even a tougher Leader; when bodyguards are physically
# removed, remaining Leaders/Supports supply the maximum (p66/05.02.01).
def test_attachment17g_bodyguard_toughness_then_remaining():
    board = value_copy(attachment17g_fixture())
    board.reserve_units[1][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.add(), 6))
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    bodyguard_t = value_copy(board[0][0].effective_toughness())
    before = value_copy(board[0].get_unit_toughtness() == bodyguard_t)
    for casualty in range(5):
        board[0].remove_model(0)
    return before and board[0].get_unit_toughtness() == board[0][0].effective_toughness() and (board[0].get_unit_toughtness() > bodyguard_t) and (board[0].attached_units.size() == 1)

# Dead bodyguards do not split Leaders and Support or restore individual counts.
# Half-strength remains against the combined initial7 models (pp66/86).
def test_attachment17g_bodyguard_death_keeps_combined_unit():
    board = value_copy(attachment17g_fixture())
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    for casualty in range(5):
        board[0].remove_model(0)
    return board.units.size() == 1 and board[0].models.size() == 2 and (board[0].starting_strenght == 7) and (board[0].attached_units.size() == 2) and board[0].is_at_or_below_half_strength() and rl.component_started_leading(board[0], board[0][0].original_unit) and rl.component_started_leading(board[0], board[0][1].original_unit)

# A typed unit ability spreads through the attached unit until its component's
# last member dies; a raw model-only modifier never spreads (p67/19.04).
def test_attachment17g_scoped_unit_ability_and_model_modifier():
    board = value_copy(attachment17g_fixture())
    board.reserve_units[1].unit_abilities.append(rl.AbilityKind.deep_strike())
    board.reserve_units[1][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.movement(), rl.ModifierOperation.add(), 3))
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    granted = value_copy(board.reserve_units[0].all_have_ability(rl.AbilityKind.deep_strike()) and (not board.reserve_units[0][0].has_ability(rl.AbilityKind.deep_strike())) and (board.reserve_units[0][0].effective_movement(6) == 6) and (board.reserve_units[0][5].effective_movement(6) == 9))
    board.reserve_units[0].remove_model(5)
    return granted and (not board.reserve_units[0].has_ability(rl.AbilityKind.deep_strike()))

# p67 component rules depend on the LAST member, not their first bearer.
def test_attachment17g_multi_model_component_lifetime():
    board = value_copy(attachment17g_fixture())
    board.reserve_units[1].unit_abilities.append(rl.AbilityKind.stealth())
    board.reserve_units[1].models.append(board.reserve_units[1][0])
    board.reserve_units[1][1].identity = rl.invalid_entity_identity()
    board.identify_unit(board.reserve_units[1])
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    board.reserve_units[0].remove_model(5)
    survivor = value_copy(board.reserve_units[0].has_ability(rl.AbilityKind.stealth()))
    board.reserve_units[0].remove_model(5)
    return survivor and (not board.reserve_units[0].has_ability(rl.AbilityKind.stealth()))

# Bodyguard-scoped rules end with the bodyguard component rather than with the
# attached unit's last Leader, and start again on a later validated revival.
def test_attachment17g_bodyguard_rule_lifetime_and_revival():
    board = value_copy(attachment17g_fixture())
    board.reserve_units[0].unit_abilities.append(rl.AbilityKind.stealth())
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    for casualty in range(5):
        board[0].remove_model(0)
    gone = value_copy(not board[0].has_ability(rl.AbilityKind.stealth()))
    returned = rl.new('Model')
    assign(returned, board[0].destroyed_models.value[0])
    board[0].destroyed_models.value.erase(0)
    rl.restore_attachment_provenance(board[0], returned)
    board[0].models.append(returned)
    return gone and board[0].has_ability(rl.AbilityKind.stealth()) and (board[0].starting_strenght == 6) and rl.valid_state_foundations(board)

# Unit-only source identities resolve absorbed components instead of pointing
# at a removed reserve slot (pp66–67). Usage belongs to the current attached unit.
def test_attachment17g_component_source_resolution():
    board = value_copy(attachment17g_fixture())
    component = value_copy(board.reserve_units[1].identity)
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    source = value_copy(attachment17g_source(board, component, 200))
    source.requires_leading = True
    rl.register_source_instance(board, source)
    location = value_copy(rl.locate_source(board, component, rl.invalid_entity_identity()))
    return location.found and location.bank.value == rl.SourceBank.reserves().value and (location.unit.value == 0) and rl.source_alive(board, source) and (board.reserve_units[0][0].effective_movement(6) == 8) and rl.valid_source_foundations(board)

# p67 leading permission persists after bodyguards die; an unattached Leader
# cannot use a rule with that condition merely because it has Leader metadata.
def test_attachment17g_while_leading_after_bodyguard_death():
    board = value_copy(attachment17g_fixture())
    component = value_copy(board.reserve_units[1].identity)
    source = value_copy(attachment17g_source(board, component, 201))
    source.requires_leading = True
    rl.register_source_instance(board, source)
    death_rule = value_copy(source)
    death_rule.own_unit_passive = False
    death_rule.trigger = rl.SourceEventKind.unit_destroyed()
    death_event = value_copy(rl.source_event(rl.SourceEventKind.unit_destroyed(), component, rl.invalid_entity_identity(), rl.invalid_entity_identity()))
    solo = value_copy(not rl.source_alive(board, source) and board.reserve_units[0][0].effective_movement(6) == 6 and (not rl.source_event_available(board, death_rule, death_event)))
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    for casualty in range(5):
        board[0].remove_model(0)
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    death_event.unit = board[0].identity
    return solo and rl.source_alive(board, source) and (board[0][0].effective_movement(6) == 8) and rl.source_event_available(board, death_rule, death_event)

# P67 registered source grants stay active through attack-caused source death,
# then expire before that attacker's destruction callbacks/removal.
def test_attachment17g_attack_deferred_source_grant():
    board = value_copy(attachment17g_fixture())
    component = value_copy(board.reserve_units[1].identity)
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    board[1].owned_by_player1 = True
    source = value_copy(attachment17g_source(board, component, 202))
    rl.register_source_instance(board, source)
    model = rl.new('ModelID')
    assign(model, 5)
    rl.commit_wound_loss(board, attachment17g_job(0, 1, True), model, board[0][5].profile.wounds(), False)
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    retained = value_copy(not rl.source_alive(board, source) and rl.source_confers_rules(board, source) and (board[0][0].effective_movement(6) == 8) and board[0][5].attachment_abilities_retained)
    rl.release_attachment_rules(board, rl.unit_id(1))
    return retained and (not rl.source_confers_rules(board, source)) and (board[0][0].effective_movement(6) == 6) and (not board[0][5].attachment_abilities_retained)

# Non-attack destruction has no attacking-unit interval; the grant ends now.
def test_attachment17g_non_attack_source_expires_immediately():
    board = value_copy(attachment17g_fixture())
    component = value_copy(board.reserve_units[1].identity)
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    board[1].owned_by_player1 = True
    source = value_copy(attachment17g_source(board, component, 203))
    rl.register_source_instance(board, source)
    model = rl.new('ModelID')
    assign(model, 5)
    rl.commit_wound_loss(board, attachment17g_job(0, 1, False), model, board[0][5].profile.wounds(), False)
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return board[0].models.size() == 5 and (not rl.source_confers_rules(board, source)) and (board[0][0].effective_movement(6) == 6) and board.source_effects.empty()

# A unit-source grant returns when its original archived component member is
# revived; original wargear/physical usage/start counts are preserved (p67/88).
def test_attachment17g_source_revival_restores_lifetime():
    board = value_copy(attachment17g_fixture())
    component = value_copy(board.reserve_units[1].identity)
    board.reserve_units[1][0].used_once_per_battle_weapon[0] = True
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    source = value_copy(attachment17g_source(board, component, 204))
    source.requires_leading = True
    rl.register_source_instance(board, source)
    board[0].remove_model(5)
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    expired = value_copy(board[0][0].effective_movement(6) == 6)
    returned = rl.new('Model')
    assign(returned, board[0].destroyed_models.value[0])
    board[0].destroyed_models.value.erase(0)
    rl.restore_attachment_provenance(board[0], returned)
    board[0].models.append(returned)
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return expired and rl.source_confers_rules(board, source) and (board[0][0].effective_movement(6) == 8) and board[0][5].used_once_per_battle_weapon[0] and (board[0].starting_strenght == 6) and rl.valid_state_foundations(board)

# Painboss's own keyword/M changes do not alter other models or become a unit-
# wide characteristic grant (Runnin' wiv da Herd; Painboss source card).
def test_attachment17g_painboss_mounted_bearer_only():
    board = value_copy(attachment17g_fixture())
    rl.configure_orks_attachment(board.reserve_units[0], rl.OrksDatasheet.squighog_boyz())
    board.reserve_units[0][0].keywords.append(rl.Keyword.mounted())
    rl.configure_orks_attachment(board.reserve_units[2], rl.OrksDatasheet.painboss())
    rl.attach_reserved_unit(board, rl.unit_id(2), rl.unit_id(0), False)
    return not board.reserve_units[0][5].has_keyword(rl.Keyword.infantry()) and board.reserve_units[0][5].has_keyword(rl.Keyword.mobile()) and board.reserve_units[0][5].has_keyword(rl.Keyword.mounted()) and (board.reserve_units[0][5].effective_movement(6) == 10) and board.reserve_units[0][1].has_keyword(rl.Keyword.infantry()) and (not board.reserve_units[0][1].has_keyword(rl.Keyword.mobile())) and (board.reserve_units[0][1].effective_movement(6) == 6)

# The+4 M is an addition before division/rounding, and infantry attachment does
# not activate it (Painboss card; appendix02.02.01).
def test_attachment17g_painboss_arithmetic_and_infantry():
    board = value_copy(attachment17g_fixture())
    rl.configure_orks_attachment(board.reserve_units[0], rl.OrksDatasheet.beast_snagga_boyz())
    rl.configure_orks_attachment(board.reserve_units[2], rl.OrksDatasheet.painboss())
    board.reserve_units[2][0].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.movement(), rl.ModifierOperation.divide(), 2))
    rl.attach_reserved_unit(board, rl.unit_id(2), rl.unit_id(0), False)
    infantry = value_copy(board.reserve_units[0][5].effective_movement(6) == 3 and board.reserve_units[0][5].has_keyword(rl.Keyword.infantry()))
    board.reserve_units[0][5].painboss_mounted_attachment = True
    return infantry and board.reserve_units[0][5].effective_movement(6) == 5

# Restore integrity rejects wrong component roles, strengths, origins and
# duplicate role slots rather than letting forged metadata change combat.
def test_attachment17g_invalid_component_metadata():
    board = value_copy(attachment17g_fixture())
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    board.reserve_units[0].attached_units[0].role.value = 0
    role = value_copy(not rl.valid_attachment_state(board.reserve_units[0]))
    board.reserve_units[0].attached_units[0].role = rl.AttachmentRole.leader()
    board.reserve_units[0].starting_strenght = 5
    strength = value_copy(not rl.valid_attachment_state(board.reserve_units[0]))
    board.reserve_units[0].starting_strenght = 6
    board.reserve_units[0][5].original_unit = 999
    return role and strength and (not rl.valid_attachment_state(board.reserve_units[0]))

# Matching Game saves retain bounded components and all original member IDs.
def test_attachment17g_saved_components_round_trip():
    game = value_copy(rl.play())
    game.board = attachment17g_fixture()
    rl.attach_reserved_unit(game.board, rl.unit_id(1), rl.unit_id(0), False)
    rl.attach_reserved_unit(game.board, rl.unit_id(1), rl.unit_id(0), False)
    restored = value_copy(rl.play())
    return rl.set_state(restored, rl.to_string(game)) and restored.board.reserve_units[0].attached_units.size() == 2 and (restored.board.reserve_units[0].starting_strenght == 7) and rl.valid_state_foundations(restored.board)

# Lone Operative protection does not return just because bodyguards died;
# the source remains part of the same attached unit (p83/19.01.01).
def test_attachment17g_lone_operative_stays_attached():
    board = value_copy(attachment17g_fixture())
    board.reserve_units[1][0].abilities.append(rl.AbilityKind.lone_operative())
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    for casualty in range(5):
        board.reserve_units[0].remove_model(0)
    return not board.reserve_units[0].is_lone_operative() and board.reserve_units[0].has_ability(rl.AbilityKind.lone_operative())

# Whole-unit effects wait for every component, including an archived bearer;
# p66 does not treat a Leader/bodyguard component death as unit destruction.
def test_attachment17g_whole_unit_destruction_waits():
    board = value_copy(attachment17g_fixture())
    component = value_copy(board.reserve_units[1].identity)
    bearer = value_copy(board.reserve_units[1][0].identity)
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    source = value_copy(attachment17g_source(board, component, 205))
    source.source_model = bearer
    source.own_unit_passive = False
    source.requires_live_source = False
    source.trigger = rl.SourceEventKind.unit_destroyed()
    source.limits.battle = 1
    source.use_scope = rl.SourceUseScope.unit()
    rl.register_source_instance(board, source)
    model = rl.new('ModelID')
    assign(model, 5)
    rl.commit_wound_loss(board, attachment17g_job(0, 0, False), model, board[0][5].profile.wounds(), False)
    leader_death = value_copy(not board[0].unit_destruction_event_issued and board[0].models.size() == 6)
    assign(model, 0)
    for casualty in range(5):
        rl.commit_wound_loss(board, attachment17g_job(0, 0, False), model, board[0][0].profile.wounds(), False)
    bodyguard_death = value_copy(not board[0].unit_destruction_event_issued and board[0].models.size() == 1)
    rl.commit_wound_loss(board, attachment17g_job(0, 0, False), model, board[0][0].profile.wounds(), False)
    last = value_copy(board[0][0].destroyed_whole_unit and board[0].unit_destruction_event_issued and (rl.live_attachment_strength(board[0]) == 0))
    jobs = rl.new('DamageJobs')
    cleanup = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    cleanup.choose_destruction_unit(board, rl.unit_id(0))
    cleanup.resolve_destruction_model(board, model)
    cleanup.choose_source_event(board, source17e_id(0))
    return leader_death and bodyguard_death and last and cleanup.is_done() and board[0].models.empty() and (board[0].destroyed_models.value.size() == 7) and (board.source_uses.size() == 1) and (board.source_uses[0].subject == board[0].identity) and (board.source_uses[0].battle_uses == 1) and rl.valid_state_foundations(board)

# Simultaneous model/unit destruction hooks share controller groups (user
# sequencing rule); the active player's hooks precede the opponent's.
def test_attachment17g_merged_death_event_ownership():
    board = value_copy(attachment17g_fixture())
    component = value_copy(board.reserve_units[1].identity)
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    board[1].owned_by_player1 = True
    own = value_copy(attachment17g_source(board, component, 206))
    own.own_unit_passive = False
    own.requires_live_source = False
    own.trigger = rl.SourceEventKind.unit_destroyed()
    own.limits.battle = 1
    rl.register_source_instance(board, own)
    opponent = value_copy(attachment17g_source(board, board[1].identity, 207))
    opponent.owner = True
    opponent.own_unit_passive = False
    opponent.requires_live_source = False
    opponent.trigger = rl.SourceEventKind.model_destroyed()
    opponent.subject = rl.SourceSubject.enemy_unit()
    opponent.limits.battle = 1
    rl.register_source_instance(board, opponent)
    board.current_decision_maker = True
    event = value_copy(rl.source_event(rl.SourceEventKind.model_destroyed(), board[0].identity, board[1].identity, board[0][5].identity))
    sequence = value_copy(rl.resolve_source_event(board, event, True))
    first = value_copy(not board.current_decision_maker and sequence.can_choose_source_event(board, source17e_id(1)) and (not sequence.can_choose_source_event(board, source17e_id(0))))
    sequence.choose_source_event(board, source17e_id(1))
    second = value_copy(board.current_decision_maker and sequence.can_choose_source_event(board, source17e_id(0)))
    sequence.choose_source_event(board, source17e_id(0))
    return first and second and sequence.is_done() and board.current_decision_maker and (board.source_uses.size() == 2)

# A specific bearer can confer a unit grant independently of surviving peers;
# the final attack cleanup expires it and archives the exact destroyed model.
def test_attachment17g_bearer_cleanup_after_all_attacks():
    board = value_copy(attachment17g_fixture())
    component = value_copy(board.reserve_units[1].identity)
    bearer = value_copy(board.reserve_units[1][0].identity)
    board.reserve_units[1].models.append(board.reserve_units[1][0])
    board.reserve_units[1][1].identity = rl.invalid_entity_identity()
    board.identify_unit(board.reserve_units[1])
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    source = value_copy(attachment17g_source(board, component, 208))
    source.source_model = bearer
    rl.register_source_instance(board, source)
    model = rl.new('ModelID')
    assign(model, 5)
    rl.commit_wound_loss(board, attachment17g_job(0, 1, True), model, board[0][5].profile.wounds(), False)
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    rl.release_attachment_rules(board, rl.unit_id(0))
    retained = value_copy(board[0][5].attachment_abilities_retained and board[0][0].effective_movement(6) == 8 and (rl.live_attachment_strength(board[0]) == 6))
    jobs = rl.new('DamageJobs')
    cleanup = value_copy(rl.resolve_damage_jobs(board, jobs, True, rl.unit_id(1)))
    expired = value_copy(board[0][0].effective_movement(6) == 6)
    cleanup.choose_destruction_unit(board, rl.unit_id(0))
    cleanup.resolve_destruction_model(board, model)
    return retained and expired and cleanup.is_done() and (board[0].models.size() == 6) and (board[0].destroyed_models.value[0].identity == bearer) and (not board[0].destroyed_models.value[0].attachment_abilities_retained) and rl.valid_state_foundations(board)

# Single-model activation never borrows p67's retained unit-rule permission.
def test_attachment17g_model_rule_not_retained_activation():
    board = value_copy(attachment17g_fixture())
    component = value_copy(board.reserve_units[1].identity)
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    source = value_copy(attachment17g_source(board, component, 209))
    source.source_model = board[0][5].identity
    source.own_unit_passive = False
    source.trigger = rl.SourceEventKind.attack_targeted()
    rl.register_source_instance(board, source)
    model = rl.new('ModelID')
    assign(model, 5)
    rl.commit_wound_loss(board, attachment17g_job(0, 1, True), model, board[0][5].profile.wounds(), False)
    event = value_copy(rl.source_event(rl.SourceEventKind.attack_targeted(), board[0].identity, board[1].identity, rl.invalid_entity_identity()))
    unit_rule = value_copy(rl.source_event_available(board, source, event))
    source.model_specific_rule = True
    return unit_rule and (not rl.source_event_available(board, source, event)) and (not rl.source_confers_rules(board, source))

# The last bodyguard retains typed unit abilities through all attacks, while
# destroyed retained models never inflate current half-strength (p67/86).
def test_attachment17g_bodyguard_attack_lifetime_and_half():
    board = value_copy(attachment17g_fixture())
    board.reserve_units[0].unit_abilities.append(rl.AbilityKind.stealth())
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    for casualty in range(4):
        board[0].remove_model(0)
    model = rl.new('ModelID')
    rl.commit_wound_loss(board, attachment17g_job(0, 1, True), model, board[0][0].profile.wounds(), False)
    retained = value_copy(board[0].has_ability(rl.AbilityKind.stealth()) and board[0].all_have_ability(rl.AbilityKind.stealth()) and board[0].is_at_or_below_half_strength() and (rl.live_attachment_strength(board[0]) == 1))
    rl.release_attachment_rules(board, rl.unit_id(1))
    return retained and (not board[0].has_ability(rl.AbilityKind.stealth())) and (board[0].starting_strenght == 6)

# Real declarations consume bodyguard T, and refresh to remaining Leader T
# when every physical bodyguard is gone (p66/19.02; declaration p17).
def test_attachment17g_actual_declaration_toughness():
    board = value_copy(attachment17g_fixture())
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    board[0][5].characteristic_modifiers.append(rl.characteristic_modifier(rl.ModifiedCharacteristic.toughness(), rl.ModifierOperation.replace(), 9))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(1), 0, 0))
    first = value_copy(rl.declared_attack_info(board, rl.unit_id(1), rl.unit_id(0), declaration, board.attack_info))
    for casualty in range(5):
        board[0].remove_model(0)
    last = value_copy(rl.declared_attack_info(board, rl.unit_id(1), rl.unit_id(0), declaration, board.attack_info))
    return first.target_toughness == 4 and last.target_toughness == 9

# Warlord and physical One Shot identities survive formation, death and saves
# without reselecting the model (user Warlord definition; p67/88).
def test_attachment17g_warlord_and_usage_identity():
    game = value_copy(rl.play())
    game.board = attachment17g_fixture()
    bearer = value_copy(game.board.reserve_units[1][0].identity)
    game.board.armies[0].warlord = bearer
    game.board.reserve_units[1][0].keywords.append(rl.Keyword.warlord())
    game.board.reserve_units[1][0].used_once_per_battle_weapon[0] = True
    rl.attach_reserved_unit(game.board, rl.unit_id(1), rl.unit_id(0), False)
    formed = value_copy(game.board.reserve_units[0][5].has_keyword(rl.Keyword.warlord()) and game.board.reserve_units[0][5].identity == bearer)
    game.board.reserve_units[0].remove_model(5)
    restored = value_copy(rl.play())
    saved = value_copy(rl.set_state(restored, rl.to_string(game)))
    return formed and saved and (restored.board.armies[0].warlord == bearer) and restored.board.reserve_units[0].destroyed_models.value[0].used_once_per_battle_weapon[0] and (restored.board.reserve_units[0].destroyed_models.value[0].identity == bearer)

# Formation allows the bounded32-model boundary but rejects empty/dead source
# fixtures and duplicate Support roles (p66; implementation capacity32).
def test_attachment17g_capacity_boundary_and_dead_source():
    board = value_copy(attachment17g_fixture())
    board.reserve_units[0].models.resize(30)
    for offset in range(25):
        model = value_copy(offset + 5)
        board.reserve_units[0][model] = board.reserve_units[0][0]
        board.reserve_units[0][model].identity = rl.invalid_entity_identity()
    board.identify_unit(board.reserve_units[0])
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    boundary = value_copy(board.reserve_units[0].models.size() == 32 and rl.valid_state_foundations(board))
    invalid = value_copy(attachment17g_fixture())
    invalid.reserve_units[1][0].suffered_wounds = invalid.reserve_units[1][0].profile.wounds()
    dead = value_copy(not rl.attachment_valid(invalid, rl.unit_id(1), rl.unit_id(0), False))
    invalid.reserve_units[1].models.clear()
    empty = value_copy(not rl.attachment_valid(invalid, rl.unit_id(1), rl.unit_id(0), False))
    rl.configure_orks_attachment(invalid.reserve_units[1], rl.OrksDatasheet.painboy())
    invalid.reserve_units[1].models.append(invalid.reserve_units[2][0])
    invalid.reserve_units[1][0].identity = rl.invalid_entity_identity()
    invalid.reserve_units[1][0].original_unit = rl.invalid_entity_identity()
    invalid.identify_unit(invalid.reserve_units[1])
    rl.attach_reserved_unit(invalid, rl.unit_id(2), rl.unit_id(0), False)
    return boundary and dead and empty and (not rl.attachment_valid(invalid, rl.unit_id(1), rl.unit_id(0), False))

# Current HTML profile tables, including their separately printed InSv boxes.
# Sources: Beastboss, Beast-Snagga-Boyz, Squighog-Boyz Orks card URLs.
def orks17h1_profile_values(profile, expected_movement, expected_toughness, expected_save, expected_invulnerable, expected_wounds, expected_leadership, expected_control, expected_fnp):
    return value_copy(profile.movement() == expected_movement and profile.thoughness() == expected_toughness and (profile.save() == expected_save) and (profile.invuln_save() == expected_invulnerable) and (profile.wounds() == expected_wounds) and (profile.leadership() == expected_leadership) and (profile.control() == expected_control) and (profile.feel_no_pain() == expected_fnp))

# Whole printed weapon row: fixed A and D resolve without hidden chance input.
def orks17h1_weapon_values(weapon, expected_range_value, expected_attacks, expected_skill, expected_strength, expected_ap, expected_damage):
    generated = value_copy(rl.evaluate_random_stat(weapon.attacks()))
    inflicted = value_copy(rl.evaluate_random_stat(weapon.damage()))
    return value_copy(weapon.range() == expected_range_value and generated.is_done() and (generated.result == expected_attacks) and (weapon.skill() == expected_skill) and (weapon.strenght() == expected_strength) and (weapon.penetration() == expected_ap) and inflicted.is_done() and (inflicted.result == expected_damage))

# Small declaration fixture with real current Snagga loadout metadata; geometry
# is a circle fixture, not production roster integration or missing abilities.
def orks17h1_attack_board():
    board = rl.new('Board')
    board.units.append(rl.make_orks_beast_snagga_boyz(1, 9, 1))
    target = value_copy(rl.make_infernus_squad())
    target.models.resize(1)
    target.owned_by_player1 = True
    target[0].position = board_position(4, 3)
    board.units.append(target)
    for model in range(board[0].models.size()):
        board[0][model].position = board_position(2 + model % 3 * 2, 5 + model // 3 * 2)
    board.identify_units()
    board.capture_starting_strengths()
    for unit in range(board.units.size()):
        board[unit].capture_starting_strength()
        board[unit].can_shoot = True
        board[unit].can_charge = True
    return value_copy(board)

# Beastboss now has T6,5+ InSv,6+ FNP, and one combined melee weapon.
def test_orks17h1_beastboss_profile():
    unit = value_copy(rl.make_orks_beastboss())
    return unit.models.size() == 1 and orks17h1_profile_values(unit[0].profile, 6, 6, 4, 5, 6, 6, 1, 6) and (unit[0].profile.base_size() == 50.0) and (rl.profile_base_width(unit[0].profile) == 50.0)

# Boy1W/Nob3W share6+ InSv; the old FNP6 is absent on both profiles.
def test_orks17h1_snagga_profiles():
    unit = value_copy(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    return orks17h1_profile_values(unit[0].profile, 6, 5, 5, 6, 3, 7, 2, 10) and orks17h1_profile_values(unit[1].profile, 6, 5, 5, 6, 1, 7, 2, 10) and (unit[0].profile.base_size() == 32.0) and (unit[1].profile.base_size() == 32.0)

# Both mounted types are T6,6+ InSv with no FNP; Nob has4W, Boy3W.
def test_orks17h1_squighog_profiles():
    unit = value_copy(rl.make_orks_squighog_boyz(1, 3))
    return orks17h1_profile_values(unit[0].profile, 10, 6, 4, 6, 4, 7, 2, 10) and orks17h1_profile_values(unit[1].profile, 10, 6, 4, 6, 3, 7, 2, 10)

# User-authorized long-axis circle proxies preserve original oval metadata.
def test_orks17h1_squighog_circle_proxies_preserve_ovals():
    unit = value_copy(rl.make_orks_squighog_boyz(1, 3))
    unit[0].position = board_position(5, 5)
    board = rl.new('Board')
    return unit[0].profile.base_size() == 90.0 and rl.profile_base_width(unit[0].profile) == 52.0 and (unit[1].profile.base_size() == 75.0) and (rl.profile_base_width(unit[1].profile) == 42.0) and rl.profile_has_oval_base(unit[0].profile) and rl.profile_has_oval_base(unit[1].profile) and (not unit[0].geometry.unsupported_footprint) and (not unit[1].geometry.unsupported_footprint) and rl.model_placement_valid(board, unit[0]) and rl.setup_at_valid(board, unit, board_position(5, 27), rl.MovementKind.normal(), False)

# Literal ranges include intermediate counts; price tiers add no count rule.
def test_orks17h1_snagga_composition_bounds():
    return rl.orks_snagga_composition_valid(1, 9, 0) and rl.orks_snagga_composition_valid(2, 18, 2) and rl.orks_snagga_composition_valid(2, 11, 1) and (not rl.orks_snagga_composition_valid(0, 9, 0)) and (not rl.orks_snagga_composition_valid(3, 9, 0)) and (not rl.orks_snagga_composition_valid(1, 8, 0)) and (not rl.orks_snagga_composition_valid(1, 19, 0))

# Optional quota is one additional Thump Gun per ten total models.
def test_orks17h1_thump_gun_quota():
    return rl.orks_snagga_composition_valid(1, 9, 1) and (not rl.orks_snagga_composition_valid(1, 9, 2)) and rl.orks_snagga_composition_valid(1, 18, 1) and (not rl.orks_snagga_composition_valid(1, 18, 2)) and rl.orks_snagga_composition_valid(2, 18, 2) and (not rl.orks_snagga_composition_valid(2, 18, 3)) and (not rl.orks_snagga_composition_valid(1, 9, -1))

# Printed independent1–2/3–6 ranges are preserved without prices.
def test_orks17h1_squighog_composition_bounds():
    return rl.orks_squighog_composition_valid(1, 3) and rl.orks_squighog_composition_valid(2, 6) and rl.orks_squighog_composition_valid(2, 5) and (not rl.orks_squighog_composition_valid(0, 3)) and (not rl.orks_squighog_composition_valid(3, 3)) and (not rl.orks_squighog_composition_valid(1, 2)) and (not rl.orks_squighog_composition_valid(1, 7))

# Minimum/maximal legal source composition produces bounded starting counts.
def test_orks17h1_factories_capture_composition():
    small = value_copy(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    large = value_copy(rl.make_orks_beast_snagga_boyz(2, 18, 2))
    mounted = value_copy(rl.make_orks_squighog_boyz(2, 6))
    return small.models.size() == 10 and small.starting_strenght == 10 and (large.models.size() == 20) and (large.starting_strenght == 20) and (mounted.models.size() == 8) and (mounted.starting_strenght == 8) and (large[1].profile == rl.Profile.orks_beast_snagga_nob()) and (large[2].profile == rl.Profile.orks_beast_snagga_boy())

# No inherited Morgrim/Beastboss/monster-hunter identity or old ability grants.
def test_orks17h1_beastboss_keywords_and_army_metadata():
    unit = value_copy(rl.make_orks_beastboss())
    return unit[0].has_keyword(rl.Keyword.orks()) and unit[0].has_keyword(rl.Keyword.infantry()) and unit[0].has_keyword(rl.Keyword.beast_snagga()) and unit[0].has_keyword(rl.Keyword.character()) and unit[0].has_keyword(rl.Keyword.warboss()) and (not unit[0].has_keyword(rl.Keyword.beastboss())) and unit[0].has_da_boss and rl.unit_has_waaagh(unit) and unit.has_ability(rl.AbilityKind.dodge_dis()) and unit.has_ability(rl.AbilityKind.keep_huntin()) and rl.unit_matches_datasheet(unit, rl.OrksDatasheet.beastboss()) and (unit.attachment_role.value == rl.AttachmentRole.leader().value)

# Battleline/Beast Snagga/Mob/Orks are actual keywords on every member.
def test_orks17h1_snagga_keywords_and_metadata():
    unit = value_copy(rl.make_orks_beast_snagga_boyz(2, 18, 0))
    valid = value_copy(unit.attachment_role.value == rl.AttachmentRole.bodyguard().value and rl.unit_has_waaagh(unit))
    for model in range(unit.models.size()):
        valid = valid and unit[model].has_keyword(rl.Keyword.battleline()) and unit[model].has_keyword(rl.Keyword.infantry()) and unit[model].has_keyword(rl.Keyword.beast_snagga()) and unit[model].has_keyword(rl.Keyword.mob()) and unit[model].has_keyword(rl.Keyword.orks()) and (not unit[model].has_keyword(rl.Keyword.monster_hunters())) and unit[model].has_ability(rl.AbilityKind.mobbed()) and rl.model_matches_datasheet(unit[model], rl.OrksDatasheet.beast_snagga_boyz())
    return valid

# Explosives/Mobile are included, with no inherited infantry/squighog keyword.
def test_orks17h1_squighog_keywords_and_metadata():
    unit = value_copy(rl.make_orks_squighog_boyz(2, 6))
    valid = value_copy(rl.unit_has_waaagh(unit))
    for model in range(unit.models.size()):
        valid = valid and unit[model].has_keyword(rl.Keyword.mounted()) and unit[model].has_keyword(rl.Keyword.beast_snagga()) and unit[model].has_keyword(rl.Keyword.explosives()) and unit[model].has_keyword(rl.Keyword.mobile()) and unit[model].has_keyword(rl.Keyword.orks()) and (not unit[model].has_keyword(rl.Keyword.infantry())) and (not unit[model].has_keyword(rl.Keyword.squighog_boyz())) and unit[model].has_ability(rl.AbilityKind.bomb_squig()) and unit[model].has_ability(rl.AbilityKind.brutal_impact())
    return valid

# Beastboss has exactly two weapons, one combined six-attack melee profile.
def test_orks17h1_beastboss_equipment():
    unit = value_copy(rl.make_orks_beastboss())
    return unit[0].weapons.size() == 2 and rl.equipped_named_weapon(unit[0], 0).value == rl.NamedWeapon.shoota().value and (rl.equipped_named_weapon(unit[0], 1).value == rl.NamedWeapon.beast_snagga_klaw_and_beastchoppa().value) and orks17h1_weapon_values(unit[0].weapons[0], 18, 2, 4, 4, 0, 1) and orks17h1_weapon_values(unit[0].weapons[1], 0, 6, 2, 12, -2, 2)

# Thump Gun augments the Boy's default equipment; a Nob never receives it.
def test_orks17h1_thump_adds_without_replacing():
    unit = value_copy(rl.make_orks_beast_snagga_boyz(2, 18, 2))
    return unit[0].weapons.size() == 2 and unit[1].weapons.size() == 2 and (unit[2].weapons.size() == 4) and (unit[3].weapons.size() == 4) and (unit[4].weapons.size() == 3) and (rl.equipped_named_weapon(unit[2], 0).value == rl.NamedWeapon.slugga().value) and (rl.equipped_named_weapon(unit[2], 1).value == rl.NamedWeapon.choppa().value) and (rl.equipped_named_weapon(unit[2], 3).value == rl.NamedWeapon.thump_gun().value)

# Every current Snagga row is fixed-A, including Thump Gun's3 (not D3/Blast).
def test_orks17h1_snagga_weapon_table():
    return orks17h1_weapon_values(rl.Weapon.orks_slugga(), 12, 1, 5, 4, 0, 1) and orks17h1_weapon_values(rl.Weapon.orks_thump_gun(), 18, 3, 5, 6, 0, 2) and (not rl.Weapon.orks_thump_gun().has_rule(rl.WeaponRuleKind.blast())) and orks17h1_weapon_values(rl.Weapon.orks_choppa_standard(), 0, 3, 3, 5, -1, 1) and orks17h1_weapon_values(rl.Weapon.orks_choppa_hunter(), 0, 3, 3, 6, -2, 1) and orks17h1_weapon_values(rl.Weapon.orks_power_snappa(), 0, 3, 3, 8, -2, 2)

# Profile alternatives share one physical Choppa; reject selecting both.
def test_orks17h1_choppa_physical_profile_selection():
    board = value_copy(orks17h1_attack_board())
    selected = rl.new('Bool[MAX_WEAPONS]')
    first = value_copy(rl.weapon_selection_valid(board, rl.unit_id(0), 1, 1, True, selected, False))
    selected[1] = True
    return first and (not rl.weapon_selection_valid(board, rl.unit_id(0), 1, 2, True, selected, False)) and (board[0][1].weapon_profile_groups[1].value == 1) and (board[0][1].weapon_profile_groups[2].value == 1) and (rl.equipped_named_profile(board[0][1], 2).value == rl.NamedWeaponProfile.choppa_hunter().value)

# Hunter may target either Monster or Vehicle, never an ordinary infantry unit.
def test_orks17h1_hunter_actual_target_legality():
    board = value_copy(orks17h1_attack_board())
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 2))
    excluded = value_copy(not rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), True))
    board[1][0].keywords.append(rl.Keyword.monster())
    monster = value_copy(rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), True))
    board[1][0].keywords.clear()
    board[1][0].keywords.append(rl.Keyword.vehicle())
    return excluded and monster and rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), True)

# Whole-unit excluded keywords govern actual Lethal Hits, not allocated models.
def test_orks17h1_lethal_hits_target_exclusion():
    board = value_copy(orks17h1_attack_board())
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 0))
    ordinary = value_copy(rl.chosen_weapon_has_rule(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.letal_hits()))
    board[1][0].keywords.append(rl.Keyword.monster())
    monster = value_copy(not rl.chosen_weapon_has_rule(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.letal_hits()))
    board[1][0].keywords.clear()
    board[1][0].keywords.append(rl.Keyword.vehicle())
    return ordinary and monster and (not rl.chosen_weapon_has_rule(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.letal_hits()))

# Combined Beastboss Sustained Hits2 uses the same positive ANY condition.
def test_orks17h1_beastboss_conditional_sustained():
    board = value_copy(orks17h1_attack_board())
    board[0] = rl.make_orks_beastboss()
    board.identify_units()
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 1))
    ordinary = value_copy(not rl.chosen_weapon_has_rule(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.sustained_hit()))
    board[1][0].keywords.append(rl.Keyword.vehicle())
    return ordinary and rl.chosen_weapon_has_rule(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.sustained_hit()) and (rl.chosen_weapon_parameter(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.sustained_hit()) == 2)

# The new anti-Monster/Vehicle4+ reaches the critical-wound consumer.
def test_orks17h1_thump_actual_anti_consumer():
    board = value_copy(orks17h1_attack_board())
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 3))
    ordinary = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    ordinary_threshold = value_copy(rl.critical_wound_threshold(board, ordinary))
    board[1][0].keywords.append(rl.Keyword.monster())
    monster = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    return ordinary_threshold == 6 and rl.critical_wound_threshold(board, monster) == 4 and (rl.declaration_fixed_attacks(board, rl.unit_id(0), declaration, 0) == 3)

# Full mounted weapon rows have the printed S7/Cleave2 Big Choppa and no Lance.
def test_orks17h1_squighog_weapon_table():
    return orks17h1_weapon_values(rl.Weapon.orks_saddlegit_shiv(), 9, 1, 4, 3, 0, 1) and orks17h1_weapon_values(rl.Weapon.orks_stikka_ranged(), 9, 1, 5, 5, -1, 2) and orks17h1_weapon_values(rl.Weapon.orks_big_choppa(), 0, 4, 3, 7, -1, 2) and (rl.Weapon.orks_big_choppa().get_rule_parameter(rl.WeaponRuleKind.cleave()) == 2) and orks17h1_weapon_values(rl.Weapon.orks_squig_jaws(), 0, 3, 4, 6, -1, 2) and rl.Weapon.orks_squig_jaws().has_rule(rl.WeaponRuleKind.extra_attacks()) and orks17h1_weapon_values(rl.Weapon.orks_stikka_melee(), 0, 3, 3, 5, -1, 2) and (not rl.Weapon.orks_stikka_melee().has_rule(rl.WeaponRuleKind.lance()))

# Mounted models retain all equipment, including melee Stikka absent before.
def test_orks17h1_squighog_equipment_and_profiles():
    unit = value_copy(rl.make_orks_squighog_boyz(1, 3))
    return unit[0].weapons.size() == 3 and unit[1].weapons.size() == 4 and (rl.equipped_named_weapon(unit[0], 0).value == rl.NamedWeapon.slugga().value) and (rl.equipped_named_weapon(unit[0], 1).value == rl.NamedWeapon.big_choppa().value) and (rl.equipped_named_weapon(unit[0], 2).value == rl.NamedWeapon.squig_s_jaws().value) and (rl.equipped_named_weapon(unit[1], 0).value == rl.NamedWeapon.saddlegit_s_shiv().value) and (rl.equipped_named_profile(unit[1], 1).value == rl.NamedWeaponProfile.stikka_ranged().value) and (rl.equipped_named_profile(unit[1], 2).value == rl.NamedWeaponProfile.stikka_melee().value) and (unit[1].weapon_profile_groups[1] == unit[1].weapon_profile_groups[2])

# Each copy has fresh owning storage and per-model physical profile selection.
def test_orks17h1_equipment_copies_are_independent():
    unit = value_copy(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    unit[1].used_once_per_battle_weapon[1] = True
    unit[1].weapons.clear()
    return unit[2].weapons.size() == 3 and (not unit[2].used_once_per_battle_weapon[1])

# Real current data passes the new attachment permission and bodyguard T path.
def test_orks17h1_current_beastboss_attachment():
    board = rl.new('Board')
    board.reserve_units.append(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    board.reserve_units.append(rl.make_orks_beastboss())
    board.identify_units()
    permitted = value_copy(rl.attachment_valid(board, rl.unit_id(1), rl.unit_id(0), False))
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    return permitted and board[0].models.size() == 11 and (board[0].starting_strenght == 11) and (board[0].get_unit_toughtness() == 5) and (board[0][10].effective_toughness() == 6) and rl.unit_has_waaagh(board[0]) and rl.valid_state_foundations(board)

# Source data survives a Game save with mixed profiles, names and optional guns.
def test_orks17h1_current_data_saved_round_trip():
    game = value_copy(rl.play())
    game.board.reserve_units.append(rl.make_orks_beastboss())
    game.board.reserve_units.append(rl.make_orks_beast_snagga_boyz(2, 18, 2))
    game.board.reserve_units.append(rl.make_orks_squighog_boyz(2, 6))
    game.board.identify_units()
    restored = value_copy(rl.play())
    return rl.set_state(restored, rl.to_string(game)) and restored.board.reserve_units[1].models.size() == 20 and (restored.board.reserve_units[1][2].weapons.size() == 4) and (rl.equipped_named_profile(restored.board.reserve_units[1][2], 2).value == rl.NamedWeaponProfile.choppa_hunter().value) and (not restored.board.reserve_units[2][0].geometry.unsupported_footprint) and (rl.profile_base_width(restored.board.reserve_units[2][0].profile) == 52.0) and rl.valid_state_foundations(restored.board)

# This subtask supplies exact data; no incomplete card/legacy roster is promoted.
def test_orks17h1_data_stage_has_no_unsourced_special_grants():
    boss = value_copy(rl.make_orks_beastboss())
    snagga = value_copy(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    hog = value_copy(rl.make_orks_squighog_boyz(1, 3))
    return boss.unit_abilities.empty() and snagga.unit_abilities.empty() and hog.unit_abilities.empty() and (not boss[0].grants_unit_riled_up) and (not hog[0].has_random_movement) and (not hog[0].has_deadly_demise)


# Current source fixture: circle-proxy Squighogs, real Beastboss/Snagga data,
# one enemy6W/no-FNP Character. Printed sources are the three Orks card URLs.
def orks17h23_fixture():
    board = rl.new('Board')
    board.units.append(rl.make_orks_beastboss())
    board.units.append(rl.make_orks_squighog_boyz(1, 3))
    board.units.append(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    enemy = value_copy(rl.make_octavius())
    enemy.owned_by_player1 = True
    enemy[0].position = board_position(15, 14)
    board.units.append(enemy)
    board[0][0].position = board_position(5, 5)
    for hog_index in range(board[1].models.size()):
        board[1][hog_index].position = board_position(5 + hog_index % 2 * 4, 14 + hog_index // 2 * 4)
    for boy_index in range(board[2].models.size()):
        board[2][boy_index].position = board_position(10 + boy_index % 3 * 2, 4 + boy_index // 3 * 2)
    board.identify_units()
    board.capture_starting_strengths()
    board.begin_phase(rl.BattlePhase.movement())
    rl.register_orks_unit_rules(board)
    return value_copy(board)

# Actual movement event snapshot; bounded action IDs remain independent.
def orks17h23_move_event(board, source, at_end, kind):
    event = value_copy(rl.source_event(rl.SourceEventKind.move_start(), board[source].identity, rl.invalid_entity_identity(), rl.invalid_entity_identity()))
    if at_end:
        event.kind = rl.SourceEventKind.move_end()
    event.movement = kind
    return value_copy(event)

# Resolve a stable printed source handle without relying on registration order.
def orks17h23_source(board, rule, source, at_end):
    result = rl.new('SourceInstanceID')
    kind = value_copy(rl.SourceEventKind.move_start())
    if at_end:
        kind = rl.SourceEventKind.move_end()
    for index in range(board.source_instances.size()):
        if board.source_instances[index].rule.value == rule and board.source_instances[index].source_unit == board[source].identity and (board.source_instances[index].trigger.value == kind.value):
            assign(result, index)
    return value_copy(result)

# Repeated registration and bank changes preserve exactly two Keep windows
# and one unit Bomb token; no token/ability is inferred from a legacy factory.
def test_orks17h23_registration_is_idempotent():
    board = value_copy(orks17h23_fixture())
    rl.register_orks_unit_rules(board)
    original = value_copy(board.source_instances.size() == 3)
    board.reserve_units.append(board[1])
    board.units[1].models.clear()
    rl.register_orks_unit_rules(board)
    return original and board.source_instances.size() == 3 and rl.valid_source_foundations(board)

# Keep Huntin': move start/end only, own Movement phase, never opposing turn.
def test_orks17h23_keep_windows_and_phase():
    board = value_copy(orks17h23_fixture())
    start = value_copy(rl.collect_source_events(board, orks17h23_move_event(board, 0, False, rl.MovementKind.advance())))
    end = value_copy(rl.collect_source_events(board, orks17h23_move_event(board, 0, True, rl.MovementKind.ordered_retreat())))
    board.current_player = True
    opponent = value_copy(rl.collect_source_events(board, orks17h23_move_event(board, 0, False, rl.MovementKind.normal())))
    board.current_player = False
    board.begin_phase(rl.BattlePhase.shooting())
    outside = value_copy(rl.collect_source_events(board, orks17h23_move_event(board, 0, False, rl.MovementKind.normal())))
    return start.size() == 1 and end.size() == 1 and opponent.empty() and outside.empty()

# Range is base-to-base and self selection is legal; friendly Beast Snagga
# is required. Spare IDs and offboard/non-Beast-Snagga/enemy units are illegal.
def test_orks17h23_keep_target_boundaries():
    board = value_copy(orks17h23_fixture())
    handle = value_copy(orks17h23_source(board, rl.ORKS_KEEP_HUNTIN_RULE, 0, False))
    instance = board.source_instances[handle.value]
    near = value_copy(rl.orks_move_target_valid(board, instance, rl.unit_id(0)) and rl.orks_move_target_valid(board, instance, rl.unit_id(2)))
    board[2][0].position = board_position(13, 5)
    for offset in range(board[2].models.size() - 1):
        index = value_copy(offset + 1)
        board[2][index].position = board_position(20, 5 + index)
    far = value_copy(not rl.orks_move_target_valid(board, instance, rl.unit_id(2)))
    board[2].off_battlefield = True
    return near and far and (not rl.orks_move_target_valid(board, instance, rl.unit_id(2))) and (not rl.orks_move_target_valid(board, instance, rl.unit_id(3))) and (not rl.orks_move_target_valid(board, instance, rl.unit_id(31)))

# A decline consumes neither the shared use counter nor shock/riled changes.
def test_orks17h23_keep_decline_spends_nothing():
    board = value_copy(orks17h23_fixture())
    board[0].battle_socked = True
    board.current_decision_maker = True
    sequence = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 0, False, rl.MovementKind.normal())))
    sequence.finish_source_events(board)
    return sequence.is_done() and board.current_decision_maker and board.source_uses.empty() and board[0].battle_socked and (not rl.unit_is_riled_up(board[0]))

# Accepted target clears shock/riles immediately and exhausts the end window.
def test_orks17h23_keep_accept_and_shared_windows():
    board = value_copy(orks17h23_fixture())
    board[2].battle_socked = True
    sequence = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 0, False, rl.MovementKind.normal())))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_keep_huntin_target(board, rl.unit_id(2))
    ending = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 0, True, rl.MovementKind.normal())))
    return sequence.is_done() and ending.is_done() and (not board[2].battle_socked) and rl.unit_is_riled_up(board[2]) and (board.source_uses.size() == 1) and (board.source_uses[0].round_uses.value == 1) and (not board.current_decision_maker)

# Duplicate bosses share the army limit, opposing armies do not; next round
# restores usage. This also specifies the future Squigosaur adapter's rule code.
def test_orks17h23_keep_shared_army_round():
    board = value_copy(orks17h23_fixture())
    duplicate = value_copy(rl.make_orks_beastboss())
    duplicate[0].position = board_position(5, 9)
    board.units.append(duplicate)
    opposing = value_copy(duplicate)
    opposing.owned_by_player1 = True
    board.units.append(opposing)
    board.identify_units()
    rl.register_orks_unit_rules(board)
    first = value_copy(orks17h23_source(board, rl.ORKS_KEEP_HUNTIN_RULE, 0, False))
    second = value_copy(orks17h23_source(board, rl.ORKS_KEEP_HUNTIN_RULE, 4, False))
    enemy = value_copy(orks17h23_source(board, rl.ORKS_KEEP_HUNTIN_RULE, 5, False))
    rl.commit_source_usage(board, board.source_instances[first.value])
    shared = value_copy(not rl.source_usage_available(board, board.source_instances[second.value]) and rl.source_usage_available(board, board.source_instances[enemy.value]))
    board.current_round = board.current_round + 1
    return shared and rl.source_usage_available(board, board.source_instances[second.value])

# Persist until the next own turn even if the boss dies or target embarks;
# the opponent's turn must not end the accepted effect (appendix01.02.02).
def test_orks17h23_keep_duration_offboard_and_source_death():
    board = value_copy(orks17h23_fixture())
    sequence = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 0, False, rl.MovementKind.normal())))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_keep_huntin_target(board, rl.unit_id(2))
    board[0][0].suffered_wounds = 6
    board.reserve_units.append(board[2])
    board.reserve_units.back().off_battlefield = True
    board[2].models.clear()
    board.current_player = True
    board.start_turn_history()
    retained = value_copy(rl.unit_is_riled_up(board.reserve_units.back()))
    board.current_player = False
    board.start_turn_history()
    return retained and (not rl.unit_is_riled_up(board.reserve_units.back())) and board.source_effects.empty()

# Actual move start/end integrations; the end hook appears only after a
# completed move, and completing a start source removes its end opportunity.
def test_orks17h23_keep_actual_move_hooks():
    board = value_copy(orks17h23_fixture())
    sequence = value_copy(rl.move(board, rl.unit_id(0), 0))
    sequence.finish_source_events(board, rl.unit_id(0))
    sequence.move_to(board, rl.unit_id(0), board_position(6, 5))
    sequence.choose_movement_source(board, rl.unit_id(0), source17e_id(0))
    sequence.choose_keep_huntin_target(board, rl.unit_id(0), rl.unit_id(0))
    return sequence.is_done() and sequence.completed and rl.unit_is_riled_up(board[0]) and (board[0][0].position.x.value == 6)

# Dodge Dis! combines with other +1/-1 terms before the cumulative hit cap;
# cancelling its contribution must not remove the other contribution.
def test_orks17h23_dodge_hit_pipeline_and_individual_choices():
    board = value_copy(orks17h23_fixture())
    rl.configure_attack_info(board, 0, 3, False, False)
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(3), declaration, board.attack_info))
    info.hit_roll_bonus = True
    info.hit_roll_malus = True
    board.attack_info = info
    options = value_copy(rl.attack_hit_choices(board, info))
    result = value_copy(rl.resolve_attack_dice(board, board[3], board[0], attack_test_count(1)))
    result.roll(board, board[3], board[0], attack_test_die(3))
    result.roll(board, board[3], board[0], attack_test_die(1))
    return info.dodge_dis_hit_bonus and info.total_hit_modifier() == 1 and (rl.get_hit_roll_bonus(board) == 1) and (options.size() == 3) and result.is_done() and (result.generated_wounds == 0)

# Attached unit attacks all receive Dodge Dis! until the boss's conferral
# ends; unsupported old factories have no new grants (core pp66-67).
def test_orks17h23_dodge_attached_component_lifetime():
    board = rl.new('Board')
    board.reserve_units.append(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    board.reserve_units.append(rl.make_orks_beastboss())
    board.identify_units()
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    board.units.append(board.reserve_units[0])
    target = value_copy(rl.make_octavius())
    target.owned_by_player1 = True
    board.units.append(target)
    rl.configure_attack_info(board, 0, 1, False, True)
    live = value_copy(board.attack_info.dodge_dis_hit_bonus)
    board[0][10].suffered_wounds = 6
    board[0][10].state = rl.ModelState.pending_destruction()
    board[0][10].attachment_abilities_retained = True
    rl.configure_attack_info(board, 0, 1, False, True)
    retained = value_copy(board.attack_info.dodge_dis_hit_bonus)
    board[0][10].attachment_abilities_retained = False
    rl.configure_attack_info(board, 0, 1, False, True)
    return live and retained and (not board.attack_info.dodge_dis_hit_bonus) and (not rl.make_beastboss_morgrim().has_ability(rl.AbilityKind.dodge_dis()))

# Bomb Squig: only completed Normal-move end in own Movement phase.
def test_orks17h23_bomb_timing_gates():
    board = value_copy(orks17h23_fixture())
    start = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, False, rl.MovementKind.normal())))
    advanced = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, True, rl.MovementKind.advance())))
    retreat = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, True, rl.MovementKind.ordered_retreat())))
    board.current_player = True
    opponent = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, True, rl.MovementKind.normal())))
    board.current_player = False
    normal = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, True, rl.MovementKind.normal())))
    return start.is_done() and advanced.is_done() and retreat.is_done() and opponent.is_done() and normal.can_choose_movement_source(board, source17e_id(0))

# Bomb selects one live visible enemy within12 base inches; area crossing
# only partially obscures under the user's visibility abstraction.
def test_orks17h23_bomb_target_boundaries_and_visibility():
    board = value_copy(orks17h23_fixture())
    handle = value_copy(orks17h23_source(board, rl.ORKS_BOMB_SQUIG_RULE, 1, True))
    instance = board.source_instances[handle.value]
    board.terrain_areas.append(terrain_area(11, 13, 12, 15, False))
    visible = value_copy(rl.orks_move_target_valid(board, instance, rl.unit_id(3)) and (not rl.orks_move_target_valid(board, instance, rl.unit_id(1))) and (not rl.orks_move_target_valid(board, instance, rl.unit_id(2))))
    board[3][0].position = board_position(25, 14)
    distant = value_copy(not rl.orks_move_target_valid(board, instance, rl.unit_id(3)))
    board[3][0].position = board_position(15, 14)
    board[3].off_battlefield = True
    return visible and distant and (not rl.orks_move_target_valid(board, instance, rl.unit_id(3))) and (not rl.orks_move_target_valid(board, instance, rl.unit_id(31)))

# No legal target or declining the ability consumes nothing.
def test_orks17h23_bomb_decline_or_no_target_preserves_token():
    board = value_copy(orks17h23_fixture())
    sequence = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, True, rl.MovementKind.normal())))
    sequence.finish_source_events(board)
    board[3].off_battlefield = True
    unavailable = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, True, rl.MovementKind.normal())))
    return sequence.is_done() and unavailable.is_done() and board.source_uses.empty()

# Spend the token at acceptance, even on a failed1/2; no Command re-roll or
# extra CP cost is invented, and subsequent rounds cannot restore the token.
def test_orks17h23_bomb_failure_spends_token():
    board = value_copy(orks17h23_fixture())
    sequence = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, True, rl.MovementKind.normal())))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_bomb_squig_target(board, rl.unit_id(3))
    spent_before_roll = value_copy(board.source_uses.size() == 1 and board.source_uses[0].battle_uses.value == 1)
    sequence.roll(board, attack_test_die(2))
    board.current_round = board.current_round + 1
    repeat = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, True, rl.MovementKind.normal())))
    return spent_before_roll and sequence.is_done() and repeat.is_done() and (board[3][0].suffered_wounds == 0) and (board.command_points[0] == 0)

# On3+ use explicit D3 chance, then enemy-owned mortal allocation with no save.
def test_orks17h23_bomb_success_actual_mortal_allocation():
    board = value_copy(orks17h23_fixture())
    board.current_decision_maker = True
    sequence = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, True, rl.MovementKind.normal())))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_bomb_squig_target(board, rl.unit_id(3))
    sequence.roll(board, attack_test_die(3))
    bounded = value_copy(not sequence.can_quantity(board, attack_test_die(4)))
    sequence.quantity(board, attack_test_die(3))
    opponent = value_copy(board.current_decision_maker)
    for index in range(3):
        sequence.select_mortal_model(board, damage_test_model(0))
    return bounded and opponent and sequence.is_done() and board.current_decision_maker and (board[3][0].suffered_wounds == 3) and board.source_effects.empty()

# Ordinary FNP is offered for every generated mortal; preventing one does not
# restore the token or change the other mortals (core pp24/81).
def test_orks17h23_bomb_uses_feel_no_pain():
    board = value_copy(orks17h23_fixture())
    board[3][0].profile = rl.Profile.orks_beastboss()
    sequence = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, True, rl.MovementKind.normal())))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_bomb_squig_target(board, rl.unit_id(3))
    sequence.roll(board, attack_test_die(6))
    sequence.quantity(board, attack_test_die(2))
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.roll(board, attack_test_die(6))
    sequence.select_mortal_model(board, damage_test_model(0))
    sequence.roll(board, attack_test_die(1))
    return sequence.is_done() and board[3][0].suffered_wounds == 1 and (board.source_uses[0].battle_uses.value == 1)

# Two units retain independent tokens; repeated registration preserves spent
# unit usage after a bank transfer (source unit/battle scope).
def test_orks17h23_bomb_per_unit_usage():
    board = value_copy(orks17h23_fixture())
    duplicate = value_copy(rl.make_orks_squighog_boyz(1, 3))
    board.units.append(duplicate)
    board.identify_units()
    rl.register_orks_unit_rules(board)
    first = value_copy(orks17h23_source(board, rl.ORKS_BOMB_SQUIG_RULE, 1, True))
    second = value_copy(orks17h23_source(board, rl.ORKS_BOMB_SQUIG_RULE, 4, True))
    rl.commit_source_usage(board, board.source_instances[first.value])
    rl.register_orks_unit_rules(board)
    return not rl.source_usage_available(board, board.source_instances[first.value]) and rl.source_usage_available(board, board.source_instances[second.value]) and (board.source_uses.size() == 1)

# End-of-Normal-move hook is offered before ordinary embarkation; skipping
# the move cannot offer the end ability.
def test_orks17h23_bomb_actual_move_and_skip():
    board = value_copy(orks17h23_fixture())
    skipped = value_copy(rl.move(board, rl.unit_id(1), 0))
    skipped.skip(board, rl.unit_id(1))
    no_end = value_copy(skipped.is_done() and board.source_uses.empty())
    moved = value_copy(rl.move(board, rl.unit_id(1), 0))
    moved.finish_move(board, rl.unit_id(1))
    moved.choose_movement_source(board, rl.unit_id(1), source17e_id(0))
    moved.choose_bomb_squig_target(board, rl.unit_id(1), rl.unit_id(3))
    moved.roll(board, rl.unit_id(1), attack_test_die(1))
    return no_end and moved.is_done() and moved.completed and (board.source_uses[0].battle_uses.value == 1)

# Mobbed requires engaged enemy Monster OR Vehicle; allies, infantry, reserve
# units and destroyed targets are excluded. No declared-target restriction.
def test_orks17h23_mobbed_target_gates():
    board = value_copy(orks17h23_fixture())
    board[2].has_charged = True
    board[3][0].position = board_position(10, 3)
    infantry = value_copy(not rl.orks_mobbed_target_valid(board, rl.unit_id(2), rl.unit_id(3)))
    board[3][0].keywords.append(rl.Keyword.vehicle())
    vehicle = value_copy(rl.orks_mobbed_target_valid(board, rl.unit_id(2), rl.unit_id(3)))
    board[3][0].keywords.clear()
    board[3][0].keywords.append(rl.Keyword.monster())
    monster = value_copy(rl.orks_mobbed_target_valid(board, rl.unit_id(2), rl.unit_id(3)))
    board[3].off_battlefield = True
    return infantry and vehicle and monster and (not rl.orks_mobbed_target_valid(board, rl.unit_id(2), rl.unit_id(3))) and (not rl.orks_mobbed_target_valid(board, rl.unit_id(2), rl.unit_id(2)))

# Exactly13 live combined members changes the penalty; corpses and starting
# strength cannot satisfy the threshold (Mobbed; core p66).
def test_orks17h23_mobbed_strength_threshold():
    unit = value_copy(rl.make_orks_beast_snagga_boyz(1, 12, 0))
    large = value_copy(rl.orks_mobbed_penalty(unit) == 2)
    unit[0].suffered_wounds = 3
    unit[0].state = rl.ModelState.pending_destruction()
    return large and unit.starting_strenght == 13 and (rl.orks_mobbed_penalty(unit) == 1)

# A penalty changes a printed Leadership boundary; the opposing player owns
# the shock roll, without Insane Bravery or Command Re-roll outside Command.
def test_orks17h23_mobbed_actual_shock_penalty():
    board = value_copy(orks17h23_fixture())
    board[2].has_charged = True
    board[3][0].position = board_position(10, 3)
    board[3][0].keywords.append(rl.Keyword.vehicle())
    sequence = value_copy(rl.resolve_orks_mobbed(board, rl.unit_id(2)))
    sequence.choose_mobbed_target(board, rl.unit_id(3))
    owner = value_copy(board.current_decision_maker and (not sequence.can_insane_bravery(board, True)))
    sequence.roll_pair(board, attack_test_die(3), attack_test_die(3))
    return owner and sequence.is_done() and board[3].battle_socked and (not board.current_decision_maker)

# Every eligible enemy must roll once; the charging player chooses their order.
def test_orks17h23_mobbed_multiple_enemies_once_each():
    board = value_copy(orks17h23_fixture())
    board[2].has_charged = True
    board[3][0].position = board_position(10, 3)
    board[3][0].keywords.append(rl.Keyword.vehicle())
    second = value_copy(board[3])
    second.identity = rl.invalid_entity_identity()
    second[0].identity = rl.invalid_entity_identity()
    second[0].original_unit = rl.invalid_entity_identity()
    second[0].position = board_position(12, 3)
    board.units.append(second)
    board.identify_units()
    sequence = value_copy(rl.resolve_orks_mobbed(board, rl.unit_id(2)))
    sequence.choose_mobbed_target(board, rl.unit_id(4))
    sequence.roll_pair(board, attack_test_die(1), attack_test_die(1))
    once = value_copy(not sequence.can_choose_mobbed_target(board, rl.unit_id(4)))
    sequence.choose_mobbed_target(board, rl.unit_id(3))
    sequence.roll_pair(board, attack_test_die(6), attack_test_die(6))
    return once and sequence.is_done() and board[4].battle_socked and (not board[3].battle_socked)

# Brutal Impact is not restricted to melee: every ranged/melee/Jaws attack
# after a completed charge gains+1D; merely declaring a charge grants nothing.
def test_orks17h23_brutal_all_profiles_and_charge_gate():
    board = value_copy(orks17h23_fixture())
    ranged = value_copy(rl.make_declared_weapon(board, rl.unit_id(1), 1, 0))
    melee = value_copy(rl.make_declared_weapon(board, rl.unit_id(1), 1, 2))
    jaws = value_copy(rl.make_declared_weapon(board, rl.unit_id(1), 1, 3))
    before = value_copy(rl.declaration_modifiers(board, rl.unit_id(1), ranged, rl.ModifiedCharacteristic.damage()).empty())
    rl.record_charge_move(board, rl.unit_id(1))
    ranged_info = value_copy(rl.declared_attack_info(board, rl.unit_id(1), rl.unit_id(3), ranged, board.attack_info))
    melee_info = value_copy(rl.declared_attack_info(board, rl.unit_id(1), rl.unit_id(3), melee, board.attack_info))
    jaw_info = value_copy(rl.declared_attack_info(board, rl.unit_id(1), rl.unit_id(3), jaws, board.attack_info))
    return before and rl.modified_characteristic(1, rl.ModifiedCharacteristic.damage(), ranged_info.damage_modifiers, False) == 2 and (rl.modified_characteristic(2, rl.ModifiedCharacteristic.damage(), melee_info.damage_modifiers, False) == 3) and (rl.modified_characteristic(2, rl.ModifiedCharacteristic.damage(), jaw_info.damage_modifiers, False) == 3)

# Source+1D belongs in addition before division/subtraction, and the same-turn
# permission expires before the opponent turn (appendix02.02.01).
def test_orks17h23_brutal_arithmetic_and_turn_expiry():
    board = value_copy(orks17h23_fixture())
    board[1].has_charged = True
    divided = value_copy(rl.characteristic_modifier(rl.ModifiedCharacteristic.damage(), rl.ModifierOperation.divide(), 2))
    board[1][1].characteristic_modifiers.append(divided)
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(1), 1, 2))
    modifiers = value_copy(rl.declaration_modifiers(board, rl.unit_id(1), declaration, rl.ModifiedCharacteristic.damage()))
    rounded = value_copy(rl.modified_characteristic(2, rl.ModifiedCharacteristic.damage(), modifiers, False) == 2)
    board.current_player = True
    board.start_turn_history()
    expired = value_copy(rl.declaration_modifiers(board, rl.unit_id(1), declaration, rl.ModifiedCharacteristic.damage()))
    return rounded and rl.modified_characteristic(2, rl.ModifiedCharacteristic.damage(), expired, False) == 1 and (not board[1].has_charged)

# Long-axis circles preserve original axes while allowing placement/movement.
# Shape metadata is immutable; stored positions remain whole quads.
def test_orks17h23_oval_proxy_edge_overlap_and_rotation():
    board = rl.new('Board')
    unit = value_copy(rl.make_orks_squighog_boyz(1, 3))
    unit[0].position = board_position(1, 5)
    edge = value_copy(not rl.model_placement_valid(board, unit[0]))
    unit[0].position = board_position(3, 5)
    unit[1].position = board_position(6, 5)
    overlap = value_copy(rl.model_bases_overlap(unit[0], unit[1]))
    unit[1].position = board_position(7, 5)
    separate = value_copy(not rl.model_bases_overlap(unit[0], unit[1]))
    original = value_copy(unit[0].distance(unit[1]))
    unit[0].geometry.rotation = 90000
    return edge and overlap and separate and (unit[0].distance(unit[1]) == original) and rl.profile_has_oval_base(unit[0].profile) and (rl.profile_base_width(unit[0].profile) == 52.0)

# Saved partial targeted source choice restores usage/owner/continuation.
def test_orks17h23_targeted_source_frame_round_trip():
    board = value_copy(orks17h23_fixture())
    sequence = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 0, False, rl.MovementKind.normal())))
    sequence.choose_movement_source(board, source17e_id(0))
    restored = value_copy(sequence)
    parsed = value_copy(rl.from_string(restored, rl.to_string(sequence)))
    restored.choose_keep_huntin_target(board, rl.unit_id(2))
    return parsed and restored.is_done() and rl.unit_is_riled_up(board[2]) and (board.source_uses.size() == 1) and rl.valid_state_foundations(board)


# Actual charge completion suspends for mandatory Mobbed, rather than applying
# it to a failed/declaration-only attempt. A one-model fixture isolates timing.
def test_orks17h23_mobbed_actual_charge_hook():
    board = value_copy(charge13_fixture())
    board.begin_phase(rl.BattlePhase.charge())
    board[0][0].abilities.append(rl.AbilityKind.mobbed())
    board[1][0].keywords.append(rl.Keyword.vehicle())
    sequence = value_copy(rl.charge(board, rl.unit_id(0), rl.ChargeKind.ordinary()))
    sequence.roll_pair(board, attack_test_die(4), attack_test_die(4))
    sequence.keep_it(board, True)
    sequence.select_charge_target(board, rl.unit_id(1))
    sequence.finish_charge_targets(board)
    sequence.charge_move_to(board, board_position(11, 5))
    mandatory = value_copy(not sequence.is_done() and board[0].has_charged and sequence.can_resolve_mobbed(board))
    sequence.resolve_mobbed(board)
    sequence.choose_mobbed_target(board, rl.unit_id(1))
    sequence.roll_pair(board, attack_test_die(1), attack_test_die(1))
    if sequence.can_decline_crushing_impact(board):
        sequence.decline_crushing_impact(board)
    return mandatory and sequence.is_done() and board[1].battle_socked

# Bomb casualties use ordinary source-known destruction handling and spill
# remaining mortals into a new recipient (core pp24/87).
def test_orks17h23_bomb_destruction_spills():
    board = value_copy(orks17h23_fixture())
    board[3] = rl.make_infernus_squad()
    board[3].models.resize(2)
    board[3].owned_by_player1 = True
    for index in range(2):
        board[3][index].position = board_position(15 + index * 2, 14)
    board.identify_units()
    sequence = value_copy(rl.resolve_movement_sources(board, orks17h23_move_event(board, 1, True, rl.MovementKind.normal())))
    sequence.choose_movement_source(board, source17e_id(0))
    sequence.choose_bomb_squig_target(board, rl.unit_id(3))
    sequence.roll(board, attack_test_die(3))
    sequence.quantity(board, attack_test_die(3))
    for index in range(3):
        sequence.select_mortal_model(board, damage_test_model(0))
    return sequence.is_done() and board[3].models.size() == 1 and (board[3].destroyed_models.value.size() == 1) and (board[3][0].suffered_wounds == 1)

# Oval circle proxies use the same final-placement and rigid movement engine,
# keeping both source axes and rejecting a proxy crossing the board edge.
def test_orks17h23_oval_proxy_actual_movement():
    board = value_copy(orks17h23_fixture())
    sequence = value_copy(rl.move(board, rl.unit_id(1), 0))
    edge = value_copy(not sequence.can_move_to(board, rl.unit_id(1), board_position(1, 14)))
    sequence.move_to(board, rl.unit_id(1), board_position(6, 14))
    sequence.finish_source_events(board, rl.unit_id(1))
    return edge and sequence.is_done() and sequence.completed and (board[1][0].position.x.value == 6) and rl.profile_has_oval_base(board[1][0].profile) and (rl.profile_base_width(board[1][0].profile) == 52.0)


# At13 live models Mobbed's-2 turns a7 into5, failing Ld6; at12 its-1
# turns the same7 into6 and passes. Test the real shock consumer, not only metadata.
def test_orks17h23_mobbed_minus_two_boundary():
    large = value_copy(orks17h23_fixture())
    large[2] = rl.make_orks_beast_snagga_boyz(1, 12, 0)
    large.identify_units()
    large[2].has_charged = True
    large[2][0].position = board_position(10, 4)
    large[3][0].position = board_position(10, 3)
    large[3][0].keywords.append(rl.Keyword.vehicle())
    sequence = value_copy(rl.resolve_orks_mobbed(large, rl.unit_id(2)))
    sequence.choose_mobbed_target(large, rl.unit_id(3))
    sequence.roll_pair(large, attack_test_die(3), attack_test_die(4))
    small = value_copy(orks17h23_fixture())
    small[2].has_charged = True
    small[3][0].position = board_position(10, 3)
    small[3][0].keywords.append(rl.Keyword.vehicle())
    smaller = value_copy(rl.resolve_orks_mobbed(small, rl.unit_id(2)))
    smaller.choose_mobbed_target(small, rl.unit_id(3))
    smaller.roll_pair(small, attack_test_die(3), attack_test_die(4))
    return sequence.is_done() and smaller.is_done() and large[3].battle_socked and (not small[3].battle_socked)

# Spending a Bomb token survives a saved Board and transfers to reserves;
# a duplicate registration never restores the printed per-unit-battle limit.
def test_orks17h23_bomb_saved_usage_and_offboard_transfer():
    game = value_copy(rl.play())
    game.board = orks17h23_fixture()
    handle = value_copy(orks17h23_source(game.board, rl.ORKS_BOMB_SQUIG_RULE, 1, True))
    rl.commit_source_usage(game.board, game.board.source_instances[handle.value])
    saved = value_copy(rl.play())
    parsed = value_copy(rl.set_state(saved, rl.to_string(game)))
    saved.board.reserve_units.append(saved.board[1])
    saved.board.reserve_units.back().off_battlefield = True
    saved.board[1].models.clear()
    rl.register_orks_unit_rules(saved.board)
    return parsed and (not rl.source_usage_available(saved.board, saved.board.source_instances[handle.value])) and (saved.board.source_uses[0].battle_uses.value == 1)

# Current starter selection exercises production Warlord/formation flow,
# rather than the historical core-rule factory (Orks three current cards).
def orks17h4_configured_game():
    game = value_copy(rl.play())
    game.pick_morgrim_butcha()
    game.choose_orks_detachment(rl.OrksDetachment.war_horde())
    game.finish_detachment_selection()
    if game.can_finish_orks_options():
        game.finish_orks_options()
    game.choose_warlord_unit(rl.unit_id(0))
    game.choose_warlord_model(damage_test_model(0))
    game.pick_morgrim_butcha()
    game.finish_detachment_selection()
    if game.can_finish_orks_options():
        game.finish_orks_options()
    game.choose_warlord_unit(rl.unit_id(4))
    game.choose_warlord_model(damage_test_model(0))
    return value_copy(game)

# Source-backed starter has25 models in four units per army; no points/DP.
def test_orks17h4_public_current_roster_profiles():
    game = value_copy(rl.play())
    game.pick_morgrim_butcha()
    reserves = game.board.reserve_units
    return reserves.size() == 4 and reserves[0][0].profile == rl.Profile.orks_beastboss() and (reserves[1].models.size() == 4) and (reserves[2].models.size() == 10) and (reserves[3].models.size() == 10) and (reserves[1][0].profile == rl.Profile.orks_nob_on_smasha_squig()) and (reserves[2][0].profile == rl.Profile.orks_beast_snagga_nob()) and (reserves[2][1].weapons.size() == 4) and (game.board.armies[0].reserve_budget == rl.ReserveBudgetMode.point_free())

# Each player's actual selection owns all its units; only their CHARACTER
# can be selected, using the user-supplied Warlord definition (17.F).
def test_orks17h4_both_rosters_and_warlords():
    game = value_copy(orks17h4_configured_game())
    correct = value_copy(game.board.reserve_units.size() == 8)
    for index in range(8):
        correct = correct and game.board.reserve_units[index].owned_by_player1 == (index >= 4)
    return correct and game.board.armies[0].warlord == game.board.reserve_units[0][0].identity and (game.board.armies[1].warlord == game.board.reserve_units[4][0].identity) and (not game.can_choose_warlord_unit(rl.unit_id(0))) and game.can_attach_unit(rl.unit_id(0), rl.unit_id(2)) and (not game.can_attach_unit(rl.unit_id(0), rl.unit_id(6)))

# Warlord is mandatory before opponent selection and survives a pending save.
def test_orks17h4_pending_warlord_save_and_handoff():
    game = value_copy(rl.play())
    game.pick_morgrim_butcha()
    game.finish_detachment_selection()
    if game.can_finish_orks_options():
        game.finish_orks_options()
    pending = value_copy(rl.get_current_player(game) == 0 and (not game.can_pick_morgrim_butcha()) and (not game.can_choose_warlord_unit(rl.unit_id(1))))
    game.choose_warlord_unit(rl.unit_id(0))
    restored = value_copy(rl.play())
    parsed = value_copy(rl.set_state(restored, rl.to_string(game)))
    restored.choose_warlord_model(damage_test_model(0))
    return pending and parsed and (rl.get_current_player(restored) == 1) and restored.can_pick_morgrim_butcha() and (restored.board.armies[0].warlord == restored.board.reserve_units[0][0].identity)

# Real formation selection transfers the Beastboss into its Snagga bodyguard;
# permanent Warlord identity survives reserve-slot compaction (pp66–67).
def test_orks17h4_actual_attachment_preserves_warlord():
    game = value_copy(orks17h4_configured_game())
    identity = value_copy(game.board.armies[0].warlord)
    game.attach_unit(rl.unit_id(0), rl.unit_id(2))
    combined = game.board.reserve_units[1]
    return combined.models.size() == 11 and combined[10].identity == identity and (combined[10].profile == rl.Profile.orks_beastboss()) and combined.has_ability(rl.AbilityKind.dodge_dis()) and (game.board.armies[0].warlord == identity) and rl.valid_state_foundations(game.board)

# Both owners use source-first reserve IDs, including after first army merge.
def test_orks17h4_both_actual_attachments_and_save():
    game = value_copy(orks17h4_configured_game())
    game.attach_unit(rl.unit_id(0), rl.unit_id(2))
    opponent = value_copy(game.can_attach_unit(rl.unit_id(3), rl.unit_id(5)) and rl.get_current_player(game) == 1)
    game.attach_unit(rl.unit_id(3), rl.unit_id(5))
    restored = value_copy(rl.play())
    parsed = value_copy(rl.set_state(restored, rl.to_string(game)))
    return opponent and parsed and (restored.board.reserve_units.size() == 6) and (restored.board.reserve_units[1].models.size() == 11) and (restored.board.reserve_units[4].models.size() == 11) and restored.board.reserve_units[4].owned_by_player1 and rl.valid_state_foundations(restored.board)

# Source registration occurs after actual formation choices, on the surviving
# combined identities; printed abilities are available in the public battle.
def test_orks17h4_actual_formation_registers_current_sources():
    game = value_copy(orks17h4_configured_game())
    game.attach_unit(rl.unit_id(0), rl.unit_id(2))
    game.done_attaching()
    game.done_attaching()
    return game.board.source_instances.size() >= 6 and game.board.reserve_units[1].has_ability(rl.AbilityKind.mobbed()) and game.board.reserve_units[1].has_ability(rl.AbilityKind.keep_huntin()) and game.board.reserve_units[0].has_ability(rl.AbilityKind.bomb_squig()) and rl.valid_state_foundations(game.board)

# No old Orks random movement/Demise/equipment is introduced by public picks.
def test_orks17h4_current_roster_no_legacy_grants():
    units = rl.new('UnitVector')
    roster = value_copy(rl.make_orks_starter_roster(units, True))
    clean = value_copy(roster == rl.Faction.morgrim_butchas())
    for unit_index in range(units.size()):
        for model_index in range(units[unit_index].models.size()):
            clean = clean and units[unit_index].unit_abilities.empty() and (units[unit_index].owned_by_player1 == True)
    return clean and units[1][0].weapons[1].value == rl.Weapon.orks_big_choppa().value and (units[2][1].weapons[3].value == rl.Weapon.orks_thump_gun().value)

# War Horde fixture selects the actual package for source's owner. Source:
# https://wahapedia.ru/wh40k11ed/factions/orks/#Get-Stuck-In
def orks17i1_fixture():
    board = value_copy(orks17h23_fixture())
    board.armies[0].faction = rl.ArmyFaction.orks()
    selected = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.war_horde()))
    assert selected, "fixture must select War Horde"
    return value_copy(board)

# Get Stuck In applies to every friendly ORKS melee weapon, including Jaws.
def test_orks17i1_melee_main_extra_and_ranged_gate():
    board = value_copy(orks17i1_fixture())
    main = value_copy(rl.model_weapon_rules(board, rl.unit_id(1), 1, 2))
    jaws = value_copy(rl.model_weapon_rules(board, rl.unit_id(1), 1, 3))
    ranged = value_copy(rl.model_weapon_rules(board, rl.unit_id(1), 1, 1))
    return rl.chosen_weapon_parameter(board, rl.unit_id(3), main, rl.WeaponRuleKind.sustained_hit()) == 1 and rl.chosen_weapon_parameter(board, rl.unit_id(3), jaws, rl.WeaponRuleKind.sustained_hit()) == 1 and (not rl.chosen_weapon_has_rule(board, rl.unit_id(3), ranged, rl.WeaponRuleKind.sustained_hit())) and rl.available_weapon_has_rule(board, rl.unit_id(1), 1, 3, rl.WeaponRuleKind.sustained_hit())

# Merely belonging to Orks, or selecting another package, grants no passive.
def test_orks17i1_requires_selected_war_horde():
    board = value_copy(orks17i1_fixture())
    board.armies[0].detachments.clear()
    absent = value_copy(not rl.war_horde_melee_rule_applies(board, rl.unit_id(2), rl.Weapon.orks_choppa_standard()))
    other = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.da_big_hunt()))
    return absent and other and (not rl.war_horde_melee_rule_applies(board, rl.unit_id(2), rl.Weapon.orks_choppa_standard()))

# Unit/army keywords are both required; opponent selection does not leak.
def test_orks17i1_faction_keyword_and_opponent_gate():
    board = value_copy(orks17i1_fixture())
    opponent = value_copy(not rl.war_horde_melee_rule_applies(board, rl.unit_id(3), rl.Weapon.orks_choppa_standard()))
    for index in range(board[2].models.size()):
        board[2][index].keywords.clear()
    keyword = value_copy(not rl.war_horde_melee_rule_applies(board, rl.unit_id(2), rl.Weapon.orks_choppa_standard()))
    board.armies[0].faction = rl.ArmyFaction.space_marines()
    return opponent and keyword and (not rl.war_horde_melee_rule_applies(board, rl.unit_id(1), rl.Weapon.orks_choppa_standard()))

# Friendly is source owner, independent of whose turn/decision it currently is.
def test_orks17i1_owner_not_active_player():
    board = value_copy(orks17i1_fixture())
    board.current_player = True
    board.current_decision_maker = True
    friendly = value_copy(rl.war_horde_melee_rule_applies(board, rl.unit_id(1), rl.Weapon.orks_big_choppa()))
    board[1].owned_by_player1 = True
    unavailable = value_copy(not rl.war_horde_melee_rule_applies(board, rl.unit_id(1), rl.Weapon.orks_big_choppa()))
    board.armies[1].faction = rl.ArmyFaction.orks()
    selected = value_copy(board.armies[1].record_detachment(rl.OrksDetachment.war_horde()))
    return friendly and unavailable and selected and rl.war_horde_melee_rule_applies(board, rl.unit_id(1), rl.Weapon.orks_big_choppa())

# This is a unit-keyword rule, not an individual bearer-keyword requirement.
def test_orks17i1_unit_keyword_union_and_three_packages():
    board = value_copy(orks17i1_fixture())
    board[2][1].keywords.clear()
    second = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.da_big_hunt()))
    third = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.green_tide()))
    rules = value_copy(rl.model_weapon_rules(board, rl.unit_id(2), 1, 1))
    return second and third and (not board[2][1].has_keyword(rl.Keyword.orks())) and (rl.chosen_weapon_parameter(board, rl.unit_id(3), rules, rl.WeaponRuleKind.sustained_hit()) == 1) and (board.armies[0].detachments.size() == 3)

# A critical hit really produces one ordinary extra hit which rolls to wound;
# a non-critical does not. Get Stuck In is not a Lethal Hits grant (p84).
def test_orks17i1_actual_critical_hit_consumer():
    board = value_copy(orks17i1_fixture())
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(1), 1, 2))
    board.attack_info = rl.declared_attack_info(board, rl.unit_id(1), rl.unit_id(3), declaration, board.attack_info)
    dice = value_copy(rl.resolve_attack_dice(board, board[3], board[1], attack_test_count(1)))
    dice.roll(board, board[3], board[1], attack_test_die(6))
    extra = value_copy(dice.generated_hits == 2 and dice.generated_wounds == 0)
    dice.roll(board, board[3], board[1], attack_test_die(1))
    dice.roll(board, board[3], board[1], attack_test_die(1))
    return extra and dice.is_done() and (dice.generated_wounds == 0)

# Beastboss conditional2 and detachment1 remain alternatives chosen BEFORE
# targets; the controlling player may choose1, never a summed3 (p78).
def test_orks17i1_beastboss_duplicate_choose_one_and_save():
    board = value_copy(orks17i1_fixture())
    rules = value_copy(rl.model_weapon_rules(board, rl.unit_id(0), 0, 1))
    selection = value_copy(rl.choose_weapon_abilities(board, rules))
    index = rl.new('WeaponAbilityChoice')
    assign(index, rules.size() - 1)
    legal = value_copy(selection.can_choose_weapon_ability(board, index))
    restored = value_copy(selection)
    parsed = value_copy(rl.from_string(restored, rl.to_string(selection)))
    restored.choose_weapon_ability(board, index)
    board[3][0].keywords.append(rl.Keyword.vehicle())
    return legal and parsed and restored.is_done() and (rl.chosen_weapon_parameter(board, rl.unit_id(3), restored.chosen, rl.WeaponRuleKind.sustained_hit()) == 1)

# Selecting the intrinsic2 retains its Monster/Vehicle condition; declining
# the unconditional1 cannot silently fall back to it against ordinary targets.
def test_orks17i1_beastboss_duplicate_choose_two_condition():
    board = value_copy(orks17i1_fixture())
    rules = value_copy(rl.model_weapon_rules(board, rl.unit_id(0), 0, 1))
    selection = value_copy(rl.choose_weapon_abilities(board, rules))
    index = rl.new('WeaponAbilityChoice')
    assign(index, 0)
    selection.choose_weapon_ability(board, index)
    ordinary = value_copy(rl.chosen_weapon_parameter(board, rl.unit_id(3), selection.chosen, rl.WeaponRuleKind.sustained_hit()) == 0)
    board[3][0].keywords.append(rl.Keyword.monster())
    return selection.is_done() and ordinary and (rl.chosen_weapon_parameter(board, rl.unit_id(3), selection.chosen, rl.WeaponRuleKind.sustained_hit()) == 2)

# Actual Select Weapons forwards the duplicate choice into saved declarations.
# This regression prevents a helper-only passive which real combat never uses.
def test_orks17i1_actual_weapon_selection_and_snapshot():
    board = value_copy(orks17i1_fixture())
    declarations = rl.new('DeclaredWeapons')
    sequence = value_copy(rl.declare_model_weapons(board, declarations, rl.unit_id(0), damage_test_model(0), True))
    sequence.select_weapon(board, declarations, attack_test_slot(1))
    waiting = value_copy(declarations.size() == 1 and (not sequence.is_done()))
    index = rl.new('WeaponAbilityChoice')
    assign(index, 1)
    sequence.choose_weapon_ability(board, declarations, index)
    sequence.skip(board, declarations)
    return waiting and sequence.is_done() and (declarations[0].selected_rules.size() == 1) and (declarations[0].current_target_rules[0].parameter == 1)

# Chosen rules remain serialized declaration snapshots; loading a current
# army retains both package configuration and its actual melee passive.
def test_orks17i1_board_and_declaration_save():
    game = value_copy(rl.play())
    game.board = orks17i1_fixture()
    game.board.attack.declarations.append(rl.make_declared_weapon(game.board, rl.unit_id(1), 1, 3))
    restored = value_copy(rl.play())
    parsed = value_copy(rl.set_state(restored, rl.to_string(game)))
    return parsed and restored.board.armies[0].has_detachment(rl.OrksDetachment.war_horde()) and (rl.chosen_weapon_parameter(restored.board, rl.unit_id(3), restored.board.attack.declarations[0].selected_rules, rl.WeaponRuleKind.sustained_hit()) == 1) and rl.valid_state_foundations(restored.board)

# Controlled source fixtures for all ordinary detachments. Tags added below
# exercise future-card consumers; these are NOT production datasheet profiles.
# Source: Orks ordinary Detachments, user enhancement/geometry policies.
def orks17all_fixture(package):
    board = value_copy(orks17h1_attack_board())
    board[0].models.resize(1)
    board[0][0].position = board_position(5, 5)
    board[1][0].position = board_position(12, 5)
    board[0].capture_starting_strength()
    board[1][0].keywords.append(rl.Keyword.orks())
    board.armies[0].faction = rl.ArmyFaction.orks()
    board.armies[1].faction = rl.ArmyFaction.orks()
    selected = value_copy(board.armies[0].record_detachment(package))
    opposing = value_copy(board.armies[1].record_detachment(package))
    board.command_points[0] = 10
    board.command_points[1] = 10
    board.begin_phase(rl.BattlePhase.shooting())
    rl.configure_attack_info(board, 0, 1, False, False)
    return value_copy(board)

# Make a reserve roster with distinct identities for isolated enhancement
# quota tests. Final army copy legality is exercised separately below.
def orks17all_option_board(count, package, characters):
    board = rl.new('Board')
    board.armies[0].faction = rl.ArmyFaction.orks()
    selected = value_copy(board.armies[0].record_detachment(package))
    for index in range(count):
        unit = value_copy(rl.make_orks_beastboss())
        if not characters:
            unit[0].keywords.clear()
            unit[0].keywords.append(rl.Keyword.orks())
            unit[0].keywords.append(rl.Keyword.infantry())
            unit[0].datasheet = rl.OrksDatasheet.boyz().value
        board.reserve_units.append(unit)
    board.identify_units()
    return value_copy(board)

# Counterpart fixture metadata is literal, never inferred from a weapon name.
def orks17all_tag(unit, tag):
    unit.roster_datasheet = tag.value
    for member in range(unit.models.size()):
        unit[member].datasheet = tag.value

# User four-count policy includes each unique Upgrade once, however many
# eligible models are in the original upgraded unit.
def test_orks17all_four_enhancement_limit():
    board = value_copy(orks17all_option_board(5, rl.OrksDetachment.war_horde(), True))
    rl.apply_orks_option(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.headwoppas_killchoppa(), False)
    rl.apply_orks_option(board, rl.unit_id(1), damage_test_model(0), rl.OrksEnhancement.da_boss_is_watchin(), False)
    rl.apply_orks_option(board, rl.unit_id(2), damage_test_model(0), rl.OrksEnhancement.kunnin_but_brutal(), False)
    rl.apply_orks_option(board, rl.unit_id(3), damage_test_model(0), rl.OrksEnhancement.follow_me_ladz(), False)
    package = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.dread_mob()))
    board.reserve_units[4][0].keywords.append(rl.Keyword.big_mek())
    return not rl.orks_option_selection_valid(board, rl.unit_id(4), damage_test_model(0), rl.OrksEnhancement.cybork_boosta(), False) and (not rl.orks_any_option_available(board, False))

# An ordinary enhancement cannot repeat or share a unit with another choice.
def test_orks17all_ordinary_unique_and_one_per_unit():
    board = value_copy(orks17all_option_board(2, rl.OrksDetachment.war_horde(), True))
    rl.apply_orks_option(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.headwoppas_killchoppa(), False)
    return not rl.orks_option_selection_valid(board, rl.unit_id(1), damage_test_model(0), rl.OrksEnhancement.headwoppas_killchoppa(), False) and (not rl.orks_option_selection_valid(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.follow_me_ladz(), False)) and rl.orks_option_selection_valid(board, rl.unit_id(1), damage_test_model(0), rl.OrksEnhancement.follow_me_ladz(), False)

# Upgrade copies2/3 consume no extra count, but a fourth is prohibited.
def test_orks17all_upgrade_three_copies_non_character():
    board = value_copy(orks17all_option_board(4, rl.OrksDetachment.green_tide(), False))
    for index in range(3):
        rl.apply_orks_option(board, rl.unit_id(index), damage_test_model(0), rl.OrksEnhancement.ardboyz(), False)
    return not rl.orks_option_selection_valid(board, rl.unit_id(3), damage_test_model(0), rl.OrksEnhancement.ardboyz(), False) and (not rl.orks_option_selection_valid(board, rl.unit_id(3), damage_test_model(0), rl.OrksEnhancement.ferocious_show_off(), False))

# With four counted choices already taken, a second/third existing Upgrade
# remains permitted. Ordinary options still require a Character.
def test_orks17all_duplicate_upgrade_excluded_from_four_total():
    board = value_copy(orks17all_option_board(6, rl.OrksDetachment.green_tide(), False))
    second = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.war_horde()))
    rl.apply_orks_option(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.ardboyz(), False)
    for index in range(3):
        board.reserve_units[index + 1][0].keywords.append(rl.Keyword.character())
    rl.apply_orks_option(board, rl.unit_id(1), damage_test_model(0), rl.OrksEnhancement.headwoppas_killchoppa(), False)
    rl.apply_orks_option(board, rl.unit_id(2), damage_test_model(0), rl.OrksEnhancement.da_boss_is_watchin(), False)
    rl.apply_orks_option(board, rl.unit_id(3), damage_test_model(0), rl.OrksEnhancement.follow_me_ladz(), False)
    permitted = value_copy(rl.orks_option_selection_valid(board, rl.unit_id(4), damage_test_model(0), rl.OrksEnhancement.ardboyz(), False))
    rl.apply_orks_option(board, rl.unit_id(4), damage_test_model(0), rl.OrksEnhancement.ardboyz(), False)
    return permitted and rl.orks_option_selection_valid(board, rl.unit_id(5), damage_test_model(0), rl.OrksEnhancement.ardboyz(), False)

# Neither an Epic bearer nor a unit containing another Epic model can take
# an ordinary option or an Upgrade (explicit user authority).
def test_orks17all_epic_hero_and_containing_unit_excluded():
    board = value_copy(orks17all_option_board(2, rl.OrksDetachment.green_tide(), True))
    second = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.war_horde()))
    board.reserve_units[0][0].keywords.append(rl.Keyword.epic_hero())
    orks17all_tag(board.reserve_units[0], rl.OrksDatasheet.boyz())
    extra = value_copy(board.reserve_units[1][0])
    extra.identity = 0
    extra.keywords.append(rl.Keyword.epic_hero())
    board.reserve_units[1].models.append(extra)
    board.identify_units()
    return not rl.orks_option_selection_valid(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.ardboyz(), False) and (not rl.orks_option_selection_valid(board, rl.unit_id(1), damage_test_model(0), rl.OrksEnhancement.follow_me_ladz(), False))

# Attachment cannot circumvent the Epic exclusion or merge two enhanced units.
def test_orks17all_attachment_enhancement_guard():
    board = value_copy(orks17all_option_board(3, rl.OrksDetachment.war_horde(), True))
    rl.apply_orks_option(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.follow_me_ladz(), False)
    clean = value_copy(rl.orks_enhancement_attachment_valid(board.reserve_units[0], board.reserve_units[1]))
    board.reserve_units[1][0].keywords.append(rl.Keyword.epic_hero())
    epic = value_copy(not rl.orks_enhancement_attachment_valid(board.reserve_units[0], board.reserve_units[1]))
    rl.apply_orks_option(board, rl.unit_id(2), damage_test_model(0), rl.OrksEnhancement.headwoppas_killchoppa(), False)
    # These are different original roster units, so both existing selections
    # survive attachment. The Epic Hero exclusion remains a final-unit check.
    return clean and epic and rl.orks_enhancement_attachment_valid(board.reserve_units[0], board.reserve_units[2])

# Sources require their selected package, owner and actual model; spare IDs
# must be safely rejected during finite candidate enumeration.
def test_orks17all_option_package_owner_and_spare_gates():
    board = value_copy(orks17all_option_board(1, rl.OrksDetachment.green_tide(), True))
    return not rl.orks_option_selection_valid(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.follow_me_ladz(), False) and (not rl.orks_option_selection_valid(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.ferocious_show_off(), True)) and (not rl.orks_option_selection_valid(board, rl.unit_id(31), damage_test_model(0), rl.OrksEnhancement.ferocious_show_off(), False)) and (not rl.orks_option_selection_valid(board, rl.unit_id(0), damage_test_model(31), rl.OrksEnhancement.ferocious_show_off(), False))

# Follow Me Ladz applies to the bearer/unit through keyed effective M, and
# expires when its live source ceases to confer (p67/passive source lifetime).
def test_orks17all_follow_me_ladz_effective_movement():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.war_horde()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.follow_me_ladz()
    before = value_copy(board[0][0].effective_movement(board[0][0].profile.movement()))
    rl.register_orks_option_passives(board)
    increased = value_copy(board[0][0].effective_movement(board[0][0].profile.movement()) == before + 2)
    board[0][0].suffered_wounds = board[0][0].profile.wounds()
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return increased and board.source_effects.empty()

# Headwoppa and Brutal But Kunnin modify effective melee AP/D only, not the
# ranged profile, and Headwoppa requires an actual completed charge.
def test_orks17all_headwoppa_charge_melee_gate():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.war_horde()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.headwoppas_killchoppa()
    uncharged = value_copy(orks17c2b_info(board, 1).attack_penetration())
    board[0].has_charged = True
    return orks17c2b_info(board, 1).attack_penetration() == uncharged - 1 and orks17c2b_info(board, 0).attack_penetration() == board[0][0].weapons[0].penetration()

# D addition enters the ordered outgoing characteristic pipeline.
def test_orks17all_brutal_but_kunnin_melee_damage():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.brute_bosses()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.brutal_but_kunnin()
    melee = value_copy(orks17c2b_info(board, 1))
    ranged = value_copy(orks17c2b_info(board, 0))
    return rl.modified_characteristic(1, rl.ModifiedCharacteristic.damage(), melee.damage_modifiers, False) == 2 and rl.modified_characteristic(1, rl.ModifiedCharacteristic.damage(), ranged.damage_modifiers, False) == 1

# Cybork and It Came From Da Drops enter characteristic additions before
# division/rounding; unrelated characteristics stay at their sourced values.
def test_orks17all_cybork_and_drops_characteristics():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.dread_mob()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.cybork_boosta()
    faster = value_copy(board[0][0].effective_movement(6) == 8)
    board[0][0].orks_enhancement = rl.OrksEnhancement.it_came_from_da_drops()
    return faster and board[0][0].effective_toughness() == board[0][0].profile.thoughness() + 1

# Ardboyz's explicit4+ save replaces the printed characteristic; its source
# component remains distinct from later attached Leaders (Green Tide card).
def test_orks17all_ardboyz_save_replacement():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.green_tide()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.ardboyz()
    board[0][0].orks_upgrade_origin = board[0].identity
    rl.register_orks_option_passives(board)
    return board[0][0].effective_save() == 4

# Green Tide's Boyz Sustained is independent of charged infantry Lethal, and
# the latter keeps its NONE Monster/Vehicle target condition.
def test_orks17all_green_tide_sustained_and_lethal_targets():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.green_tide()))
    orks17all_tag(board[0], rl.OrksDatasheet.boyz())
    board[0].has_charged = True
    rules = value_copy(rl.model_weapon_rules(board, rl.unit_id(0), 0, 1))
    infantry = value_copy(rl.chosen_weapon_parameter(board, rl.unit_id(1), rules, rl.WeaponRuleKind.sustained_hit()) == 1 and rl.chosen_weapon_has_rule(board, rl.unit_id(1), rules, rl.WeaponRuleKind.letal_hits()))
    board[1][0].keywords.append(rl.Keyword.vehicle())
    return infantry and (not rl.chosen_weapon_has_rule(board, rl.unit_id(1), rules, rl.WeaponRuleKind.letal_hits()))

# Bully Boyz adds Sustained only to its named Nob/Meganob group, in melee.
def test_orks17all_bully_boyz_named_melee_group():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.bully_boyz()))
    absent = value_copy(not rl.available_weapon_has_rule(board, rl.unit_id(0), 0, 1, rl.WeaponRuleKind.sustained_hit()))
    orks17all_tag(board[0], rl.OrksDatasheet.nobz())
    return absent and rl.available_weapon_has_rule(board, rl.unit_id(0), 0, 1, rl.WeaponRuleKind.sustained_hit()) and (not rl.available_weapon_has_rule(board, rl.unit_id(0), 0, 0, rl.WeaponRuleKind.sustained_hit()))

# Shoota's Assault permission reaches actual shooting-mode and weapon gates;
# riled+3 Range is gathered through the declaration characteristic pipeline.
def test_orks17all_shoota_assault_and_riled_range():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.shoota_boyz()))
    board[0].history.advanced_this_turn = True
    board[0].has_run = True
    assault = value_copy(rl.shooting_kind_valid(board, rl.unit_id(0), rl.ShootingKind.assault()))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    normal = value_copy(rl.declaration_weapon_range(board, rl.unit_id(0), declaration))
    orks17f_intrinsic_riled(board[0][0])
    return assault and rl.declaration_weapon_range(board, rl.unit_id(0), declaration) == normal + 3

# Throat-slittas preserves its no-Monster/Vehicle restriction independently
# of Green Tide; ranged attacks cannot gain this melee Lethal source.
def test_orks17all_throat_slittas_target_exclusion():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.taktikal_brigade()))
    # The actual Slugga already has Lethal Hits; use a neutral ranged weapon
    # to test that the Upgrade itself confers nothing on ranged attacks.
    board[0][0].weapons[0] = rl.Weapon.bolt_rifle()
    board[0][0].orks_enhancement = rl.OrksEnhancement.throat_slittas()
    melee = value_copy(rl.model_weapon_rules(board, rl.unit_id(0), 0, 1))
    allowed = value_copy(rl.chosen_weapon_has_rule(board, rl.unit_id(1), melee, rl.WeaponRuleKind.letal_hits()))
    board[1][0].keywords.append(rl.Keyword.monster())
    return allowed and (not rl.chosen_weapon_has_rule(board, rl.unit_id(1), melee, rl.WeaponRuleKind.letal_hits())) and (not rl.available_weapon_has_rule(board, rl.unit_id(0), 0, 0, rl.WeaponRuleKind.letal_hits()))

# Tellyporta excludes an attached unit with Vehicle membership, rather than
# just checking its infantry bearer (Bully Boyz source card).
def test_orks17all_tellyporta_vehicle_exclusion():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.bully_boyz()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.tellyporta_boss()
    granted = value_copy(board[0].all_have_ability(rl.AbilityKind.deep_strike()))
    board[0][0].keywords.append(rl.Keyword.vehicle())
    return granted and (not board[0].all_have_ability(rl.AbilityKind.deep_strike()))

# Minefield Scouts6 requires not embarked, and every duplicate stays uniform
# under the user's static-value policy (Runt Swarm source upgrade).
def test_orks17all_minefield_scouts_and_embarked_gate():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.runt_swarm()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.minefield_detail()
    on_foot = value_copy(rl.scouts_distance(board[0]) == 6)
    board[0].embarked_transport = board[1][0].identity
    return on_foot and rl.scouts_distance(board[0]) == 0

# Runt and Taktikal waivers affect their selected movement only; fallback
# charge/shooting permissions survive subsequent source loss.
def test_orks17all_fallback_permissions_snapshot():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.taktikal_brigade()))
    orks17all_tag(board[0], rl.OrksDatasheet.boyz())
    board[0][0].orks_enhancement = rl.OrksEnhancement.kunnin_but_brutal()
    rl.capture_orks_selected_move(board, rl.unit_id(0), rl.MovementKind.ordered_retreat())
    board[0][0].orks_enhancement = rl.OrksEnhancement.none()
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.ordered_retreat())
    return board[0].can_shoot and board[0].can_charge and board[0].history.fallback_allows_charge and board[0].history.fallback_allows_shooting

# Runt's Action permission is only an Advance/Fall Back waiver; being
# shocked/starting a second action/after-shooting remain prohibitions.
def test_orks17all_runt_action_waiver_preserves_other_gates():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.runt_swarm()))
    orks17all_tag(board[0], rl.OrksDatasheet.gretchin())
    rl.capture_orks_selected_move(board, rl.unit_id(0), rl.MovementKind.advance())
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.advance())
    allowed = value_copy(board[0].allows_action_start())
    board[0].battle_socked = True
    return allowed and (not board[0].allows_action_start())

# Da Big Hunt AP applies versus actual Monster/Vehicle union only; a
# friendly source in another selected package cannot borrow the benefit.
def test_orks17all_hunt_ap_target_condition():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.da_big_hunt()))
    ordinary = value_copy(orks17c2b_info(board, 0).attack_penetration())
    board[1][0].keywords.append(rl.Keyword.vehicle())
    return orks17c2b_info(board, 0).attack_penetration() == ordinary - 1

# Unpredictable Genius rolls only for a single declared target; targeting
# several enemies is legal and does not satisfy its conditional trigger.
def test_orks17all_madcap_single_target_condition():
    declarations = rl.new('DeclaredWeapons')
    first = rl.new('DeclaredWeapon')
    first.targeted[1] = True
    declarations.append(first)
    same = rl.new('DeclaredWeapon')
    same.targeted[1] = True
    declarations.append(same)
    single = value_copy(rl.orks_single_declared_target(declarations) == 1)
    declarations[1].targeted[2] = True
    return single and rl.orks_single_declared_target(declarations) == -1

# Try Dat Button table additions accumulate for distinct faces1/2, even
# though those faces belong to the same band. S/AP use their ordered consumers.
def test_orks17all_button_cumulative_characteristics():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.dread_mob()))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    base = value_copy(rl.declaration_fixed_attacks(board, rl.unit_id(0), declaration, 0))
    rl.apply_orks_button(board, rl.unit_id(0), attack_test_die(1))
    rl.apply_orks_button(board, rl.unit_id(0), attack_test_die(2))
    rl.apply_orks_button(board, rl.unit_id(0), attack_test_die(3))
    rl.apply_orks_button(board, rl.unit_id(0), attack_test_die(5))
    info = value_copy(orks17c2b_info(board, 0))
    return rl.declaration_fixed_attacks(board, rl.unit_id(0), declaration, 0) == base + 2 and info.attack_strength() == board[0][0].weapons[0].strenght() + 2 and (info.attack_penetration() == board[0][0].weapons[0].penetration() - 1)

# Speed Freeks receive real Assault and charge waivers on selected Advance,
# keeping normal action restrictions when not Gretchin/Mind On Mission.
def test_orks17all_kult_advance_assault_and_charge():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.kult_of_speed()))
    board[0][0].keywords.append(rl.Keyword.speed_freeks())
    board[0].history.advance_allows_charge = rl.orks_move_charge_permission(board, board[0], rl.MovementKind.advance())
    rl.capture_orks_selected_move(board, rl.unit_id(0), rl.MovementKind.advance())
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.advance())
    return board[0].can_charge and rl.shooting_kind_valid(board, rl.unit_id(0), rl.ShootingKind.assault()) and (not board[0].allows_action_start())

# Flyboyz riled Aircraft/Deffkoptas contribute a hit term before the+/-1 cap.
def test_orks17all_flyboyz_riled_hit_modifier():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.flyboyz()))
    orks17all_tag(board[0], rl.OrksDatasheet.deffkoptas())
    orks17f_intrinsic_riled(board[0][0])
    info = value_copy(orks17c2b_info(board, 0))
    return info.orks_hit_modifiers.size() == 1 and info.total_hit_modifier() == 1

# Brute Warboss3+/riled2+ has no CP cost, closes after selecting its unit to
# fight, and remains distinct from paid4+ permissions.
def test_orks17all_brute_death_thresholds():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.brute_bosses()))
    board[0][0].keywords.append(rl.Keyword.warboss())
    normal = value_copy(rl.orks_fight_death_threshold(board, board[0], board[0][0]) == 3)
    orks17f_intrinsic_riled(board[0][0])
    riled = value_copy(rl.orks_fight_death_threshold(board, board[0], board[0][0]) == 2)
    board[0].has_fought = True
    return normal and riled and (rl.orks_fight_death_threshold(board, board[0], board[0][0]) == 0)

# Wurrband uses actual living unit models, with one extra S per full5; no
# psychic ability is granted to non-Psyker or foreign-faction models.
def test_orks17all_wurrband_psychic_weapon_strength():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.wurrband()))
    board[0][0].keywords.append(rl.Keyword.psyker())
    board[0][0].weapons[0] = rl.Weapon.orks_eadbanger()
    info = value_copy(orks17c2b_info(board, 0))
    return info.attack_strength() == 7

# Explicit source metadata changes muster copy limits after force disposition:
# Gretchin≤6 under Runt,≤3 otherwise. Replacement units are not re-mustered.
def test_orks17all_roster_three_and_six_copy_limits():
    board = value_copy(orks17all_option_board(4, rl.OrksDetachment.runt_swarm(), False))
    for slot in range(board.reserve_units.size()):
        orks17all_tag(board.reserve_units[slot], rl.OrksDatasheet.gretchin())
    limited = value_copy(not rl.orks_muster_copies_valid(board))
    rl.register_orks_force_dispositions(board)
    return limited and rl.orks_muster_copies_valid(board) and board.reserve_units[0].has_keyword(rl.Keyword.battleline())

# Literal card actor fixtures keep applicability separate from expected effect.
# They use controlled stats and tags, not fabricated production datasheets.
def orks17all_selected_card_fixture(card, melee):
    board = value_copy(orks17all_fixture(card.orks_detachment()))
    if melee:
        board.begin_phase(rl.BattlePhase.fight())
    if card == rl.Stratagem.orks_mow_em_down():
        board[0][0].keywords.append(rl.Keyword.vehicle())
        board[0].has_charged = True
    if card == rl.Stratagem.orks_unbridled_carnage():
        orks17all_tag(board[0], rl.OrksDatasheet.boyz())
        board[0].has_charged = True
    if card == rl.Stratagem.orks_armed_to_da_teef():
        orks17all_tag(board[0], rl.OrksDatasheet.nobz())
    if card == rl.Stratagem.orks_drive_by_bustin():
        board[0][0].keywords.append(rl.Keyword.transport())
    if card == rl.Stratagem.orks_vindictive_artillerists():
        orks17all_tag(board[0], rl.OrksDatasheet.mek_gunz())
        # Isolate the card's three choices from the fixture Slugga's printed
        # Lethal Hits, which correctly survives the Sustained-only choice.
        board[0][0].weapons[0] = rl.Weapon.bolt_rifle()
    if card == rl.Stratagem.orks_dakkastorm():
        board[0][0].keywords.append(rl.Keyword.speed_freeks())
    if card == rl.Stratagem.orks_long_uncontrolled_bursts():
        orks17all_tag(board[0], rl.OrksDatasheet.deffkoptas())
    return value_copy(board)

# Real paid selection, source installation and declaration consumer for the
# ranged/melee weapon-ability cards. Costs and same-unit reuse are checked.
def orks17all_selected_ability(card, melee, expected, magnitude):
    board = value_copy(orks17all_selected_card_fixture(card, melee))
    sequence = value_copy(rl.orks_attack_selection(board, rl.unit_id(0), melee))
    sequence.choose_orks_attack_stratagem(board, card)
    slot = value_copy(int(melee))
    rules = value_copy(rl.model_weapon_rules(board, rl.unit_id(0), 0, slot))
    return value_copy(sequence.is_done() and board.command_points[0] == 9 and rl.chosen_weapon_has_rule(board, rl.unit_id(1), rules, expected) and (rl.chosen_weapon_parameter(board, rl.unit_id(1), rules, expected) == magnitude) and (not board.can_target_strat(False, card, board[0])))

# War Horde's optional melee Lethal is a sourced ability, not a hit modifier.
def test_orks17all_hit_em_harder_paid_ability():
    return orks17all_selected_ability(rl.Stratagem.orks_hit_em_harder(), True, rl.WeaponRuleKind.letal_hits(), 0)

# Vehicle charged melee Cleave1 excludes Walkers at actual selection.
def test_orks17all_mow_em_down_paid_cleave():
    return orks17all_selected_ability(rl.Stratagem.orks_mow_em_down(), True, rl.WeaponRuleKind.cleave(), 1)

# Close-range Dakka grants Rapid1 when absent.
def test_orks17all_close_range_dakka_paid_rapid():
    return orks17all_selected_ability(rl.Stratagem.orks_close_range_dakka(), False, rl.WeaponRuleKind.rapid_fire(), 1)

# Existing Rapid magnitude is improved, not treated as another competing
# instance, and its intrinsic value returns after this source expires.
def test_orks17all_close_range_existing_rapid_and_expiry():
    board = value_copy(orks17all_selected_card_fixture(rl.Stratagem.orks_close_range_dakka(), False))
    board[0][0].additional_weapon_rules[0].append(rl.weapon_rule(rl.WeaponRuleKind.rapid_fire(), 2))
    sequence = value_copy(rl.orks_attack_selection(board, rl.unit_id(0), False))
    sequence.choose_orks_attack_stratagem(board, rl.Stratagem.orks_close_range_dakka())
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    enhanced = value_copy(rl.chosen_weapon_parameter(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.rapid_fire()) == 3)
    board.begin_phase(rl.BattlePhase.charge())
    return enhanced and rl.chosen_weapon_parameter(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.rapid_fire()) == 2

# Shoota Never Enough Dakka uses ordinary duplicate Sustained selection.
def test_orks17all_never_enough_dakka_paid_sustained():
    return orks17all_selected_ability(rl.Stratagem.orks_never_enough_dakka(), False, rl.WeaponRuleKind.sustained_hit(), 1)

# Kult's card affects ranged attacks only and spends its own source cost.
def test_orks17all_dakkastorm_paid_sustained():
    return orks17all_selected_ability(rl.Stratagem.orks_dakkastorm(), False, rl.WeaponRuleKind.sustained_hit(), 1)

# Green Tide Unbridled A+1 is a melee addition after charging; ranged A stays
# unchanged, rather than being increased by the unit-wide grant.
def test_orks17all_unbridled_carnage_melee_only_attacks():
    board = value_copy(orks17all_selected_card_fixture(rl.Stratagem.orks_unbridled_carnage(), True))
    before = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 1))
    attacks = value_copy(rl.declaration_fixed_attacks(board, rl.unit_id(0), before, 0))
    sequence = value_copy(rl.orks_attack_selection(board, rl.unit_id(0), True))
    sequence.choose_orks_attack_stratagem(board, rl.Stratagem.orks_unbridled_carnage())
    ranged = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    return sequence.is_done() and rl.declaration_fixed_attacks(board, rl.unit_id(0), before, 0) == attacks + 1 and (rl.declaration_fixed_attacks(board, rl.unit_id(0), ranged, 0) == 1)

# Armed rerolls1 when not riled, all hits when riled; neither path sums hit
# modifiers or permits a second reroll of a single die.
def test_orks17all_armed_to_da_teef_riled_rerolls():
    board = value_copy(orks17all_selected_card_fixture(rl.Stratagem.orks_armed_to_da_teef(), False))
    sequence = value_copy(rl.orks_attack_selection(board, rl.unit_id(0), False))
    sequence.choose_orks_attack_stratagem(board, rl.Stratagem.orks_armed_to_da_teef())
    normal = value_copy(orks17c2b_info(board, 0))
    orks17f_intrinsic_riled(board[0][0])
    riled = value_copy(orks17c2b_info(board, 0))
    return normal.reroll1_hits and (not normal.reroll_hits) and riled.reroll1_hits and riled.reroll_hits

# Kustom+1 wound is conditional on the actual target not being M/V.
def test_orks17all_kustom_dakka_non_vehicle_wound_bonus():
    board = value_copy(orks17all_selected_card_fixture(rl.Stratagem.orks_kustom_dakka(), False))
    sequence = value_copy(rl.orks_attack_selection(board, rl.unit_id(0), False))
    sequence.choose_orks_attack_stratagem(board, rl.Stratagem.orks_kustom_dakka())
    infantry = value_copy(orks17c2b_info(board, 0).total_wound_modifier() == 1)
    board[1][0].keywords.append(rl.Keyword.vehicle())
    return infantry and orks17c2b_info(board, 0).total_wound_modifier() == 0

# Glowin+1AP requires within9in; distant targets are not upgraded.
def test_orks17all_glowin_dakka_range_condition():
    board = value_copy(orks17all_selected_card_fixture(rl.Stratagem.orks_glowin_dakka(), False))
    sequence = value_copy(rl.orks_attack_selection(board, rl.unit_id(0), False))
    sequence.choose_orks_attack_stratagem(board, rl.Stratagem.orks_glowin_dakka())
    nearby = value_copy(orks17c2b_info(board, 0).attack_penetration() == -1)
    board[1][0].position = board_position(30, 5)
    return nearby and orks17c2b_info(board, 0).attack_penetration() == 0

# Long Uncontrolled Bursts gives full hit rerolls only against FLY.
def test_orks17all_long_bursts_actual_fly_target():
    board = value_copy(orks17all_selected_card_fixture(rl.Stratagem.orks_long_uncontrolled_bursts(), False))
    sequence = value_copy(rl.orks_attack_selection(board, rl.unit_id(0), False))
    sequence.choose_orks_attack_stratagem(board, rl.Stratagem.orks_long_uncontrolled_bursts())
    grounded = value_copy(not orks17c2b_info(board, 0).reroll_hits)
    board[1][0].keywords.append(rl.Keyword.fly())
    return grounded and orks17c2b_info(board, 0).reroll_hits

# Vindictive's three actual choices retain their complete sourced combinations.
def test_orks17all_vindictive_three_modes_and_hazards():
    all_good = value_copy(True)
    for index in range(3):
        board = value_copy(orks17all_selected_card_fixture(rl.Stratagem.orks_vindictive_artillerists(), False))
        sequence = value_copy(rl.orks_attack_selection(board, rl.unit_id(0), False))
        sequence.choose_orks_attack_stratagem(board, rl.Stratagem.orks_vindictive_artillerists())
        mode = rl.new('OrksArtilleristMode')
        mode.value = index
        sequence.choose_artillerist_mode(board, mode)
        rules = value_copy(rl.model_weapon_rules(board, rl.unit_id(0), 0, 0))
        all_good = all_good and sequence.is_done() and (rl.chosen_weapon_has_rule(board, rl.unit_id(1), rules, rl.WeaponRuleKind.letal_hits()) == (index != 1)) and (rl.chosen_weapon_has_rule(board, rl.unit_id(1), rules, rl.WeaponRuleKind.sustained_hit()) == (index != 0)) and (rl.chosen_weapon_has_rule(board, rl.unit_id(1), rules, rl.WeaponRuleKind.hazardous()) == (index == 2))
    return all_good

# Supa-glowy's two tests are independent of ordinary Hazardous; selected
# alternate profiles of the same physical weapon do not double either count.
def test_orks17all_supa_glowy_independent_hazard_counts():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.shoota_boyz()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.supa_glowy_fing()
    board[0][0].additional_weapon_rules[0].append(rl.weapon_rule(rl.WeaponRuleKind.hazardous()))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    declarations = rl.new('DeclaredWeapons')
    declarations.append(declaration)
    declarations.append(declaration)
    return rl.chosen_weapon_parameter(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.anti()) == 4 and rl.chosen_weapon_has_rule(board, rl.unit_id(1), declaration.selected_rules, rl.WeaponRuleKind.devastating_wounds()) and (rl.declared_hazardous_uses(declarations) == 3)

# A physical Supa-only weapon has two tests; an ordinary-only weapon has one.
def test_orks17all_hazard_types_not_interchangeable():
    declarations = rl.new('DeclaredWeapons')
    supa = rl.new('DeclaredWeapon')
    supa.slot = 0
    supa.selected_rules.append(rl.weapon_rule(rl.WeaponRuleKind.supa_hazardous()))
    declarations.append(supa)
    ordinary = rl.new('DeclaredWeapon')
    ordinary.slot = 1
    ordinary.selected_rules.append(rl.weapon_rule(rl.WeaponRuleKind.hazardous()))
    declarations.append(ordinary)
    return rl.declared_hazardous_uses(declarations) == 3 and rl.MAX_HAZARDOUS_USES > 448 * 3

# Speediest uses natural1/2/3 failures even under a large hit bonus; natural6
# retains the ordinary critical outcome.
def test_orks17all_speediest_natural_faces():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.kult_of_speed()))
    board[1][0].keywords.append(rl.Keyword.speed_freeks())
    sequence = value_copy(rl.orks_attack_targeted(board, rl.unit_id(0), rl.unit_id(1), False))
    sequence.choose_orks_defence_stratagem(board, rl.Stratagem.orks_speediest_freeks())
    info = value_copy(orks17c2b_info(board, 0))
    return rl.classify_attack_hit(board, info, attack_test_die(3), 10, 2) == rl.AttackRollResult.failed() and rl.classify_attack_hit(board, info, attack_test_die(4), 0, 2) == rl.AttackRollResult.success() and (rl.classify_attack_hit(board, info, attack_test_die(6), 0, 6) == rl.AttackRollResult.critical())

# Hulking's optional extra1CP is committed atomically with its base cost;
# choosing all ranged attacks grants protection even when S<=T.
def test_orks17all_hulking_surcharge_and_all_attack_protection():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.bully_boyz()))
    orks17all_tag(board[1], rl.OrksDatasheet.nobz())
    sequence = value_copy(rl.orks_attack_targeted(board, rl.unit_id(0), rl.unit_id(1), False))
    sequence.choose_orks_defence_stratagem(board, rl.Stratagem.orks_hulking_brutes())
    unspent = value_copy(board.command_points[1] == 10)
    sequence.choose_hulking_protection(board, True)
    return unspent and sequence.is_done() and (board.command_points[1] == 8) and (orks17c2b_info(board, 0).total_wound_modifier() == -1)

# At1CP, the stronger option is illegal but the base option remains usable.
def test_orks17all_hulking_unaffordable_surcharge_no_partial_spend():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.bully_boyz()))
    orks17all_tag(board[1], rl.OrksDatasheet.nobz())
    board.command_points[1] = 1
    sequence = value_copy(rl.orks_attack_targeted(board, rl.unit_id(0), rl.unit_id(1), False))
    sequence.choose_orks_defence_stratagem(board, rl.Stratagem.orks_hulking_brutes())
    unaffordable = value_copy(not sequence.can_choose_hulking_protection(board, True) and board.command_points[1] == 1)
    sequence.choose_hulking_protection(board, False)
    return unaffordable and board.command_points[1] == 0

# Defensive4+ retains its source-owner snapshot and the riled+1 captured at
# destruction; choosing one's own fight beforehand closes the card permission.
def test_orks17all_paid_fight_on_death_thresholds():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.war_horde()))
    board.begin_phase(rl.BattlePhase.fight())
    sequence = value_copy(rl.orks_attack_targeted(board, rl.unit_id(0), rl.unit_id(1), True))
    sequence.choose_orks_defence_stratagem(board, rl.Stratagem.orks_orks_is_never_beaten())
    ordinary = value_copy(rl.orks_fight_death_threshold(board, board[1], board[1][0]) == 4)
    orks17f_intrinsic_riled(board[1][0])
    return ordinary and rl.orks_fight_death_threshold(board, board[1], board[1][0]) == 3

# Actual damage rolls its faction permission NOW, retains a successful corpse,
# and does not require rolling that same permission on the later selection.
def test_orks17all_actual_fight_on_death_damage_retention():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.war_horde()))
    board.begin_phase(rl.BattlePhase.fight())
    defence = value_copy(rl.orks_attack_targeted(board, rl.unit_id(0), rl.unit_id(1), True))
    defence.choose_orks_defence_stratagem(board, rl.Stratagem.orks_orks_is_never_beaten())
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(1), rl.unit_id(0), True, True, board[1][0].wounds_left(), board[1][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(0)))
    damage.roll(board, attack_test_die(4))
    return damage.is_done() and board[1].models.size() == 1 and (board[1][0].state == rl.ModelState.fight_on_death()) and board[1][0].destruction_pending and (board[1][0].destruction_fight_roll == 1)

# Crazed Rampage's Deff Dread+3 is not replaced by ordinary riled+1.
def test_orks17all_crazed_deff_dread_threshold():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.dread_mob()))
    board.begin_phase(rl.BattlePhase.fight())
    board[1][0].keywords.append(rl.Keyword.walker())
    orks17all_tag(board[1], rl.OrksDatasheet.deff_dread())
    sequence = value_copy(rl.orks_attack_targeted(board, rl.unit_id(0), rl.unit_id(1), True))
    sequence.choose_orks_defence_stratagem(board, rl.Stratagem.orks_crazed_rampage())
    return rl.orks_fight_death_threshold(board, board[1], board[1][0]) == 1 and board.command_points[1] == 9

# A retained all-dead unit can still receive its paid selection grant while
# it attacks; ordinary corpses receive no permission by being archived.
def test_orks17all_retained_unit_stratagem_installation():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.war_horde()))
    board.begin_phase(rl.BattlePhase.fight())
    board[0][0].state = rl.ModelState.fight_on_death()
    board[0][0].suffered_wounds = board[0][0].profile.wounds()
    sequence = value_copy(rl.orks_attack_selection(board, rl.unit_id(0), True))
    sequence.choose_orks_attack_stratagem(board, rl.Stratagem.orks_hit_em_harder())
    return sequence.is_done() and rl.unit_orks_effect(board, board[0], rl.OrksEffectKind.melee_lethal()) == 1 and rl.valid_source_foundations(board)

# Movement card selection spends before granting ordered M or advance dice
# modifiers, and a failed/absent selection leaves CP/history unchanged.
def test_orks17all_fungus_fuel_effective_movement():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.war_horde()))
    board.begin_phase(rl.BattlePhase.movement())
    board[0][0].keywords.append(rl.Keyword.mounted())
    sequence = value_copy(rl.orks_move_selection(board, rl.unit_id(0), False))
    sequence.choose_orks_move_stratagem(board, rl.Stratagem.orks_fungus_fuel_injection())
    return sequence.is_done() and board.command_points[0] == 9 and (board[0][0].effective_movement(6) == 8)

# 'Ere We Go changes the Advance roll bonus, not M, and excludes other units.
def test_orks17all_ere_we_go_advance_bonus():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.green_tide()))
    board.begin_phase(rl.BattlePhase.movement())
    sequence = value_copy(rl.orks_move_selection(board, rl.unit_id(0), False))
    sequence.choose_orks_move_stratagem(board, rl.Stratagem.orks_ere_we_go())
    return sequence.is_done() and rl.unit_orks_effect(board, board[0], rl.OrksEffectKind.advance_plus_two()) == 1 and (board[0][0].effective_movement(6) == 6)

# Mobile is a real sourced keyword, expires after its phase and does not add
# physical terrain features excluded by the user's area-only instruction.
def test_orks17all_stomping_mobile_and_expiry():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.dread_mob()))
    board.begin_phase(rl.BattlePhase.charge())
    board[0][0].keywords.append(rl.Keyword.walker())
    sequence = value_copy(rl.orks_move_selection(board, rl.unit_id(0), True))
    sequence.choose_orks_move_stratagem(board, rl.Stratagem.orks_stomping_juggernaut())
    granted = value_copy(sequence.is_done() and board[0][0].has_keyword(rl.Keyword.mobile()))
    board.begin_phase(rl.BattlePhase.fight())
    return granted and (not board[0][0].has_keyword(rl.Keyword.mobile()))

# Mind On Mission affects only selected Advance/Fall Back, does not waive
# shock or after-shooting restrictions, and is not a new move type.
def test_orks17all_mind_on_mission_action_permission():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.taktikal_brigade()))
    board.begin_phase(rl.BattlePhase.movement())
    orks17all_tag(board[0], rl.OrksDatasheet.kommandos())
    sequence = value_copy(rl.orks_move_mode(board, rl.unit_id(0), rl.MovementKind.advance()))
    sequence.mind_on_mission(board)
    rl.capture_orks_selected_move(board, rl.unit_id(0), rl.MovementKind.advance())
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.advance())
    return sequence.is_done() and board[0].allows_action_start() and (board.command_points[0] == 9)

# Wimp-kickaz forces escaping and applies cumulative-1 only while its own
# engaged source is riled, without affecting ordinary Advance rolls.
def test_orks17all_wimp_escape_and_riled_penalty():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.bully_boyz()))
    board[1][0].position = board_position(7, 5)
    board[1][0].orks_enhancement = rl.OrksEnhancement.wimp_kickaz()
    forced = value_copy(rl.orks_forces_escape(board, board[0]) and rl.orks_escape_penalty(board, board[0]) == 0)
    orks17f_intrinsic_riled(board[1][0])
    return forced and rl.orks_escape_penalty(board, board[0]) == 1

# Hunt's accepted unit forces Desperate Escape and counts ALL engaged Snagga
# units for its extra3 rolls against M/V (not just the unit that paid).
def test_orks17all_hunt_escape_all_engaged_snaggas():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.da_big_hunt()))
    board.begin_phase(rl.BattlePhase.movement())
    board[1][0].position = board_position(7, 5)
    board[1][0].keywords.append(rl.Keyword.beast_snagga())
    board[0][0].keywords.append(rl.Keyword.vehicle())
    reaction = value_copy(rl.orks_fallback_selection(board, rl.unit_id(0)))
    reaction.choose_hunting_escape_unit(board, rl.unit_id(1))
    return reaction.is_done() and rl.orks_forces_escape(board, board[0]) and (rl.orks_extra_escape_hazards(board, board[0]) == 3) and (board.command_points[1] == 9)

# An explicit reactive six-inch maximum is not a modified M; Follow Me Ladz
# cannot expand it to8, and roles/limits return to the caller after declining.
def test_orks17all_reactive_distance_not_m_characteristic():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.war_horde()))
    board[1][0].position = board_position(30, 5)
    board[0][0].orks_enhancement = rl.OrksEnhancement.follow_me_ladz()
    rl.register_orks_option_passives(board)
    six = rl.new('StatModifier')
    assign(six, 6)
    sequence = value_copy(rl.orks_reactive_move(board, rl.unit_id(0), six, False))
    exact = value_copy(sequence.can_move_to(board, board_position(11, 5)) and (not sequence.can_move_to(board, board_position(12, 5))))
    sequence.skip(board)
    return exact and sequence.is_done() and (board[0].movement_distance_limit == 0) and (board.current_decision_maker == False)

# Grove shielding pays for the separate Gretchin target, leaving the protected
# infantry's own stratagem-target allowance available (Runt Swarm/Grot Shields).
def orks17all_grot_fixture():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.runt_swarm()))
    grots = value_copy(board[1])
    grots.identity = 0
    grots[0].identity = 0
    grots[0].original_unit = 0
    grots[0].position = board_position(12, 7)
    orks17all_tag(grots, rl.OrksDatasheet.gretchin())
    board.units.append(grots)
    board.identify_units()
    shield = value_copy(rl.orks_attack_targeted(board, rl.unit_id(0), rl.unit_id(1), False))
    shield.choose_grot_shield_unit(board, rl.unit_id(2))
    return value_copy(board)

def test_orks17all_grot_shield_separate_cp_target():
    board = value_copy(orks17all_grot_fixture())
    return board.command_points[1] == 9 and board[2].history.stratagem_targeted_by_player[1] and (not board[1].history.stratagem_targeted_by_player[1]) and (rl.orks_grot_shield(board, board[1]) == 2)

# An original Lethal critical is cancelled, its separately generated Sustained
# hit survives, and the shield suffers1 actual mortal via ordinary allocation.
def test_orks17all_grot_shield_original_lethal_and_sustained():
    board = value_copy(orks17all_grot_fixture())
    board.command_points[0] = 0
    board.attack_info.source = rl.Weapon.orks_slugga()
    board.attack_info.add_letal_hits()
    board.attack_info.add_sustained_hits(1)
    rl.begin_orks_attack(board)
    dice = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(1)))
    dice.roll(board, board[1], board[0], attack_test_die(6))
    dice.use_lethal_hits(board, board[1], board[0], True)
    dice.select_mortal_model(board, board[1], board[0], damage_test_model(0))
    intercepted = value_copy(board[2][0].suffered_wounds == 1 and board[1][0].suffered_wounds == 0 and (dice.generated_hits == 1) and (dice.generated_wounds == 0))
    dice.roll(board, board[1], board[0], attack_test_die(1))
    return intercepted and dice.is_done() and (dice.generated_wounds == 0)

# Torrent has no successful HIT ROLL and therefore is not intercepted.
def test_orks17all_grot_shield_does_not_intercept_torrent():
    board = value_copy(orks17all_grot_fixture())
    board.command_points[0] = 0
    board.attack_info.source = rl.Weapon.pyreblaster()
    dice = value_copy(rl.resolve_attack_dice(board, board[1], board[0], attack_test_count(1)))
    dice.roll(board, board[1], board[0], attack_test_die(1))
    return dice.is_done() and board[2][0].suffered_wounds == 0 and (dice.generated_hits == 1)

# Post-attack reactions distinguish hits from real wounds after prevention;
# selecting a target alone does not trigger Gun-crazy or Goaded.
def test_orks17all_post_attack_ledger_actual_hits_and_wounds():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.wreckas()))
    orks17all_tag(board[1], rl.OrksDatasheet.flash_gitz())
    rl.begin_orks_attack(board)
    no_hit = value_copy(not rl.orks_post_attack_card_valid(board, rl.unit_id(0), rl.unit_id(1), rl.Stratagem.orks_gun_crazy_show_offs(), False))
    rl.record_orks_hits(board, rl.unit_id(1), 1)
    hit = value_copy(rl.orks_post_attack_card_valid(board, rl.unit_id(0), rl.unit_id(1), rl.Stratagem.orks_gun_crazy_show_offs(), False))
    other = value_copy(board.armies[1].record_detachment(rl.OrksDetachment.da_big_hunt()))
    board[1][0].keywords.append(rl.Keyword.beast_snagga())
    not_wounded = value_copy(not rl.orks_post_attack_card_valid(board, rl.unit_id(0), rl.unit_id(1), rl.Stratagem.orks_goaded_into_action(), False))
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(1), rl.unit_id(0), True, True, 1, board[1][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 1, False)
    return no_hit and hit and not_wounded and rl.orks_post_attack_card_valid(board, rl.unit_id(0), rl.unit_id(1), rl.Stratagem.orks_goaded_into_action(), False)

# Grab It permanently records this turn's no-charge permission alongside its
# objective-constrained normal move, rather than merely changing UI choices.
def test_orks17all_grab_it_charge_lock_expiry():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.wreckas()))
    rl.grant_orks_effect(board, rl.unit_id(0), rl.unit_id(0), 300 + rl.Stratagem.orks_grab_it().value, rl.OrksEffectKind.no_charge(), 1, rl.SourceDuration.turn(), rl.invalid_entity_identity())
    board.begin_phase(rl.BattlePhase.charge())
    blocked = value_copy(not rl.charge_source_valid(board, rl.unit_id(0), False))
    board.turn_serial = board.turn_serial + 1
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return blocked and rl.unit_orks_effect(board, board[0], rl.OrksEffectKind.no_charge()) == 0

# New Infested units receive new unit/model identities and fresh usage/wounds;
# the original destroyed archive is retained, not revived or overwritten.
def test_orks17all_infested_new_unit_identity_and_template():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.runt_swarm()))
    orks17all_tag(board[1], rl.OrksDatasheet.gretchin())
    board[1].capture_starting_strength()
    original_unit = value_copy(board[1].identity)
    original_model = value_copy(board[1][0].identity)
    board[1][0].used_once_per_battle_weapon[0] = True
    board[1][0].suffered_wounds = board[1][0].profile.wounds()
    board[1].remove_model(0)
    rl.create_orks_replacement(board, rl.unit_id(1))
    replacement = board.reserve_units[0]
    return board[1].identity == original_unit and board[1].destroyed_models.value[0].identity == original_model and (replacement.identity != original_unit) and (replacement[0].identity != original_model) and (replacement[0].suffered_wounds == 0) and (not replacement[0].used_once_per_battle_weapon[0]) and replacement.is_generated_replacement and replacement.off_battlefield and replacement.history.strategic_reserve

# Actual unit death has the current activation serial. An earlier attack's
# casualty cannot spend Infested during a later enemy activation.
def test_orks17all_infested_current_activation_gate():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.runt_swarm()))
    orks17all_tag(board[1], rl.OrksDatasheet.gretchin())
    board[1].capture_starting_strength()
    rl.begin_orks_attack(board)
    job = value_copy(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(1), rl.unit_id(0), True, True, 2, board[1][0].identity))
    rl.commit_wound_loss(board, job, damage_test_model(0), 2, False)
    current = value_copy(rl.orks_post_attack_card_valid(board, rl.unit_id(0), rl.unit_id(1), rl.Stratagem.orks_infested_war_zone(), False))
    rl.begin_orks_attack(board)
    return current and (not rl.orks_post_attack_card_valid(board, rl.unit_id(0), rl.unit_id(1), rl.Stratagem.orks_infested_war_zone(), False))

# Heal3 restores wounds individually before any non-Character revival.
def test_orks17all_heal_wounded_model_before_revival():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.kult_of_speed()))
    board[0][0].suffered_wounds = 1
    count = rl.new('BInt<0, 4>')
    assign(count, 3)
    healing = value_copy(rl.heal_orks_unit(board, rl.unit_id(0), count))
    healing.choose_healed_model(board, damage_test_model(0))
    return healing.is_done() and board[0][0].suffered_wounds == 0 and (board[0].models.size() == 1)

# Revival retains identity/equipment/One Shot, uses phase-start coherency and
# returns1W instead of creating a duplicate original model.
def test_orks17all_heal_revives_original_identity_and_usage():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.kult_of_speed()))
    extra = value_copy(board[0][0])
    extra.identity = 0
    extra.position = board_position(5, 7)
    extra.used_once_per_battle_weapon[0] = True
    board[0].models.append(extra)
    board.identify_units()
    board[0].capture_starting_strength()
    board.begin_phase(rl.BattlePhase.movement())
    identity = value_copy(board[0][1].identity)
    board[0][1].suffered_wounds = board[0][1].profile.wounds()
    board[0].remove_model(1)
    count = rl.new('BInt<0, 4>')
    assign(count, 1)
    healing = value_copy(rl.heal_orks_unit(board, rl.unit_id(0), count))
    healing.choose_healed_casualty(board, damage_test_model(0))
    healing.place_returned_model(board, board_position(5, 7))
    return healing.is_done() and board[0].models.size() == 2 and (board[0][1].identity == identity) and (board[0][1].wounds_left() == 1) and board[0][1].used_once_per_battle_weapon[0] and board[0].destroyed_models.value.empty()

# Unit healing never returns a Character just because other models are full.
def test_orks17all_healing_excludes_character_casualties():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.kult_of_speed()))
    extra = value_copy(board[0][0])
    extra.identity = 0
    extra.keywords.append(rl.Keyword.character())
    extra.position = board_position(5, 7)
    board[0].models.append(extra)
    board.identify_units()
    board[0].capture_starting_strength()
    board.begin_phase(rl.BattlePhase.movement())
    board[0].remove_model(1)
    return not rl.orks_heal_archive_valid(board, rl.unit_id(0), damage_test_model(0))

# A first returned model cannot anchor another return if it was absent at
# phase start; illegal new enemy engagements remain rejected.
def test_orks17all_return_phase_start_and_new_engagement_gates():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.kult_of_speed()))
    returned = value_copy(board[0][0])
    old = value_copy(rl.orks_return_position_valid(board, rl.unit_id(0), returned, board_position(5, 7), False))
    board[0].history.phase_start_members.clear()
    absent = value_copy(not rl.orks_return_position_valid(board, rl.unit_id(0), returned, board_position(5, 7), False))
    board[1][0].position = board_position(7, 7)
    return old and absent and (not rl.orks_return_position_valid(board, rl.unit_id(0), returned, board_position(5, 7), False))

# A psychic1 shocks but still grants Fights First; its level is spent, and a
# second same-phase use is unavailable (Wurrband/22.03.01).
def test_orks17all_visions_psychic_one_still_grants_effect():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.wurrband()))
    board[0][0].keywords.append(rl.Keyword.psyker())
    board[0].psyker_level = 1
    board.begin_phase(rl.BattlePhase.fight())
    psychic = value_copy(rl.use_orks_psychic(board, rl.unit_id(0), True))
    psychic.roll(board, attack_test_die(1))
    return psychic.is_done() and board[0].battle_socked and rl.fight_first_unit(board[0]) and (board[0].orks_psychic_usage.spent == 1) and (not rl.orks_psychic_available(board, rl.unit_id(0), True))

# Warphead's once-per-ability phase restriction is separate from its level2
# round budget. A new round restores budget; a phase alone does not.
def test_orks17all_warphead_psychic_round_budget():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.wurrband()))
    board[0][0].keywords.append(rl.Keyword.psyker())
    board[0][0].orks_enhancement = rl.OrksEnhancement.warphead()
    board[0].orks_psychic_usage.round_stamp = board.current_round.value + 1
    board[0].orks_psychic_usage.spent = 2
    spent = value_copy(not rl.orks_psychic_available(board, rl.unit_id(0), False))
    board.begin_phase(rl.BattlePhase.fight())
    still_spent = value_copy(not rl.orks_psychic_available(board, rl.unit_id(0), True))
    board.current_round = board.current_round + 1
    return spent and still_spent and rl.orks_psychic_available(board, rl.unit_id(0), True)

# Roar uses the enemy's normal shock rules after the psychic roll, excludes
# M/V, and consumes its own level even if the caster rolls a1.
def test_orks17all_roar_psychic_one_and_enemy_shock():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.wurrband()))
    board[0][0].keywords.append(rl.Keyword.psyker())
    board[0].psyker_level = 1
    board.begin_phase(rl.BattlePhase.movement())
    psychic = value_copy(rl.use_orks_psychic(board, rl.unit_id(0), False))
    psychic.roll(board, attack_test_die(1))
    psychic.choose_roar_target(board, rl.unit_id(1))
    psychic.roll_pair(board, attack_test_die(1), attack_test_die(1))
    return psychic.is_done() and board[0].battle_socked and board[1].battle_socked and (board.current_decision_maker == False)

# Named plasma/slot lookalikes cannot acquire Snazzgun or Shokk-only upgrades.
def test_orks17all_supa_snazz_named_weapon_gate():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.wreckas()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.supa_snazz_dakka()
    absent = value_copy(not rl.available_weapon_has_rule(board, rl.unit_id(0), 0, 0, rl.WeaponRuleKind.rapid_fire()))
    board[0][0].weapon_names[0] = rl.NamedWeapon.snazzgun().value
    rules = value_copy(rl.model_weapon_rules(board, rl.unit_id(0), 0, 0))
    return absent and rl.chosen_weapon_parameter(board, rl.unit_id(1), rules, rl.WeaponRuleKind.rapid_fire()) == 1

# Targetin' Squigs adds3 Range to the unit, excluding Torrent on the actual
# selected weapon (the named source card, not every numbered slot).
def test_orks17all_targetin_squigs_torrent_exclusion():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.shoota_boyz()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.targetin_squigs()
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    ordinary = value_copy(rl.declaration_weapon_range(board, rl.unit_id(0), declaration) == 15)
    board[0][0].additional_weapon_rules[0].append(rl.weapon_rule(rl.WeaponRuleKind.torrent()))
    torrent = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    return ordinary and rl.declaration_weapon_range(board, rl.unit_id(0), torrent) == 12

# Ferocious uses current LIVE strength11+, not starting strength or corpses.
def test_orks17all_ferocious_live_eleven_boundary():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.green_tide()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.ferocious_show_off()
    bearer = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 1))
    small = value_copy(rl.declaration_fixed_attacks(board, rl.unit_id(0), bearer, 0))
    additional = value_copy(board[0][0])
    additional.identity = 0
    additional.orks_enhancement = rl.OrksEnhancement.none()
    for index in range(10):
        board[0].models.append(additional)
    board.identify_units()
    large = value_copy(rl.declaration_fixed_attacks(board, rl.unit_id(0), bearer, 0) == small + 1)
    board[0].remove_model(10)
    return large and rl.declaration_fixed_attacks(board, rl.unit_id(0), bearer, 0) == small

# Proper Killy applies to its bearer, not every member of the unit.
def test_orks17all_proper_killy_bearer_reroll_scope():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.brute_bosses()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.proper_killy()
    extra = value_copy(board[0][0])
    extra.identity = 0
    extra.orks_enhancement = rl.OrksEnhancement.none()
    board[0].models.append(extra)
    board.identify_units()
    bearer = value_copy(orks17c2b_info(board, 0))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 0))
    other = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    return bearer.reroll1_hits and (not other.reroll1_hits)

# Da Boss is Watchin' riles its own unit and consumes its army/battle token,
# while the effect survives source death until the next own turn.
def test_orks17all_watchin_once_army_next_own_turn():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.war_horde()))
    board.begin_phase(rl.BattlePhase.movement())
    board[0][0].orks_enhancement = rl.OrksEnhancement.da_boss_is_watchin()
    sequence = value_copy(rl.orks_movement_abilities(board, rl.unit_id(0)))
    sequence.choose_orks_movement_ability(board, rl.OrksDetachmentAbility.da_boss_is_watchin())
    accepted = value_copy(sequence.is_done() and rl.unit_is_riled_up(board[0]) and (not rl.orks_movement_ability_available(board, rl.unit_id(0))))
    board.turn_serial = board.turn_serial + 1
    board.current_player = True
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    opponent_turn = value_copy(rl.unit_is_riled_up(board[0]))
    board.turn_serial = board.turn_serial + 1
    board.current_player = False
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return accepted and opponent_turn and (not rl.unit_is_riled_up(board[0]))

# Reserve/passenger own abilities do not measure external range. Watchin'
# installs a real persistent effect in the reserve bank with the same token.
def test_orks17all_offboard_watchin_own_unit():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.war_horde()))
    board.begin_phase(rl.BattlePhase.movement())
    board[0][0].orks_enhancement = rl.OrksEnhancement.da_boss_is_watchin()
    moved = value_copy(rl.reposition_unit(board, rl.unit_id(0)))
    before = value_copy(rl.orks_offboard_support_valid(board, rl.SourceBank.reserves(), rl.unit_id(0), False, False))
    sequence = value_copy(rl.choose_orks_offboard_support(board, False, False))
    sequence.choose_orks_support_bank(board, rl.SourceBank.reserves())
    sequence.choose_orks_offboard_unit(board, rl.unit_id(0))
    return moved and before and sequence.is_done() and rl.unit_is_riled_up(board.reserve_units[0]) and (not rl.orks_offboard_support_valid(board, rl.SourceBank.reserves(), rl.unit_id(0), False, False))

# Visions can be used on its own offboard unit, but this never provides
# visibility/range to enemy units for Roar or an attack.
def test_orks17all_offboard_visions_no_external_visibility():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.wurrband()))
    board[0][0].keywords.append(rl.Keyword.psyker())
    board[0].psyker_level = 1
    moved = value_copy(rl.reposition_unit(board, rl.unit_id(0)))
    board.begin_phase(rl.BattlePhase.fight())
    sequence = value_copy(rl.choose_orks_offboard_support(board, False, True))
    sequence.choose_orks_support_bank(board, rl.SourceBank.reserves())
    sequence.choose_orks_offboard_unit(board, rl.unit_id(0))
    sequence.roll(board, attack_test_die(1))
    return moved and sequence.is_done() and board.reserve_units[0].battle_socked and rl.fight_first_unit(board.reserve_units[0]) and (not rl.unit_visible_to_unit(board, board.reserve_units[0], board[1]))

# Offboard Dread Power pays for the real reserve unit, and its phase target
# history/persisting riled effect remain present on that unit.
def test_orks17all_offboard_dread_power_paid_target():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.dread_mob()))
    board.begin_phase(rl.BattlePhase.movement())
    board[0][0].keywords.append(rl.Keyword.walker())
    moved = value_copy(rl.reposition_unit(board, rl.unit_id(0)))
    sequence = value_copy(rl.choose_orks_offboard_dread_power(board, False))
    sequence.choose_orks_dread_bank(board, rl.SourceBank.reserves())
    sequence.choose_offboard_dread_unit(board, rl.unit_id(0))
    return moved and sequence.is_done() and (board.command_points[0] == 9) and board.reserve_units[0].history.stratagem_targeted_by_player[0] and rl.unit_is_riled_up(board.reserve_units[0])

# Source attacks are grouped separately when Speediest's unmodified-face
# failures differ, even if their final hit modifiers match (p17).
def test_orks17all_grouping_preserves_natural_face_gates():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.kult_of_speed()))
    first = value_copy(orks17c2b_info(board, 0))
    second = value_copy(first)
    second.orks_fail_hits_three = True
    return not rl.attacks_are_identical(board, first, second)

# Unpredictable6 changes effective target T until this activation ends, then
# removes only its own key rather than every matching Toughness modifier.
def test_orks17all_madcap_toughness_scoped_expiry():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.madcap_meks()))
    board[0][0].keywords.append(rl.Keyword.big_mek())
    initial = value_copy(board[1].get_unit_toughtness())
    table = value_copy(rl.orks_unpredictable_genius(board, rl.unit_id(0), rl.unit_id(1)))
    table.roll(board, attack_test_die(6))
    changed = value_copy(board[1].get_unit_toughtness() == initial - 1)
    rl.remove_orks_scoped_effect(board, table.effect)
    return table.is_done() and changed and (board[1].get_unit_toughtness() == initial)

# Lifted adds FLY and removes cover only for the scoped activation; it does
# not permanently write the target's intrinsic keywords.
def test_orks17all_madcap_lifted_keyword_and_cover():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.madcap_meks()))
    board[0][0].keywords.append(rl.Keyword.big_mek())
    table = value_copy(rl.orks_unpredictable_genius(board, rl.unit_id(0), rl.unit_id(1)))
    table.roll(board, attack_test_die(5))
    lifted = value_copy(board[1].has_keyword(rl.Keyword.fly()))
    rl.remove_orks_scoped_effect(board, table.effect)
    return lifted and (not board[1].has_keyword(rl.Keyword.fly()))

# Madcap1's granted4+ keeps a better original save; it expires after shooting.
def test_orks17all_madcap_invulnerable_grant_and_expiry():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.madcap_meks()))
    board[0][0].keywords.append(rl.Keyword.big_mek())
    initial = value_copy(board[1][0].effective_invulnerable_save())
    table = value_copy(rl.orks_unpredictable_genius(board, rl.unit_id(0), rl.unit_id(1)))
    table.roll(board, attack_test_die(1))
    granted = value_copy(board[1][0].effective_invulnerable_save() == 4)
    rl.remove_orks_scoped_effect(board, table.effect)
    return granted and board[1][0].effective_invulnerable_save() == initial

# Temperamental's named-weapon Sustained2 belongs only to its bearer, not
# a second model with a coincidentally matching weapon slot/name.
def test_orks17all_shokka_bearer_only_sustained():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.madcap_meks()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.temperamental_shokka()
    board[0][0].weapon_names[0] = rl.NamedWeapon.shokk_attack_gun().value
    other = value_copy(board[0][0])
    other.identity = 0
    other.orks_enhancement = rl.OrksEnhancement.none()
    board[0].models.append(other)
    board.identify_units()
    selection = value_copy(rl.orks_shokka_selection(board, rl.unit_id(0)))
    selection.temperamental_shokka(board)
    selection.roll(board, attack_test_die(6))
    first = value_copy(rl.model_weapon_rules(board, rl.unit_id(0), 0, 0))
    second = value_copy(rl.model_weapon_rules(board, rl.unit_id(0), 1, 0))
    return selection.is_done() and rl.chosen_weapon_parameter(board, rl.unit_id(1), first, rl.WeaponRuleKind.sustained_hit()) == 2 and (not rl.chosen_weapon_has_rule(board, rl.unit_id(1), second, rl.WeaponRuleKind.sustained_hit()))

# An intentional1 result grants Torrent and destroys that exact bearer AFTER
# shooting, compacting indices without killing the following model instead.
def test_orks17all_shokka_destroy_after_shot_identity():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.madcap_meks()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.temperamental_shokka()
    board[0][0].weapon_names[0] = rl.NamedWeapon.shokk_attack_gun().value
    doomed = value_copy(board[0][0].identity)
    other = value_copy(board[0][0])
    other.identity = 0
    other.orks_enhancement = rl.OrksEnhancement.none()
    other.position = board_position(5, 7)
    board[0].models.append(other)
    board.identify_units()
    survivor = value_copy(board[0][1].identity)
    selection = value_copy(rl.orks_shokka_selection(board, rl.unit_id(0)))
    selection.temperamental_shokka(board)
    selection.roll(board, attack_test_die(1))
    torrent = value_copy(rl.available_weapon_has_rule(board, rl.unit_id(0), 0, 0, rl.WeaponRuleKind.torrent()))
    end = value_copy(rl.orks_shooting_option_end(board, rl.unit_id(0)))
    return torrent and end.is_done() and (board[0].models.size() == 1) and (board[0][0].identity == survivor) and (board[0].destroyed_models.value[0].identity == doomed)

# Smoky uses intentional circular-base line crossing for partial obscuration;
# it never blocks visibility under the user's supplied approximation.
def test_orks17all_smoky_circle_crossing_and_visibility():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.kult_of_speed()))
    blocker = value_copy(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    blocker.models.resize(1)
    blocker[0].position = board_position(8, 5)
    blocker[0].orks_enhancement = rl.OrksEnhancement.smoky_gubbinz()
    board.units.append(blocker)
    board.identify_units()
    obscured = value_copy(rl.orks_smoky_cover(board, board[0][0], board[1]))
    visible = value_copy(rl.unit_visible_to_unit(board, board[0], board[1]))
    board[2][0].position = board_position(8, 10)
    return obscured and visible and (not rl.orks_smoky_cover(board, board[0][0], board[1]))

# Blitz Wagon and Competitive Streak use normal charge rerolls; unrelated
# ordinary units cannot receive this option by sharing their army package.
def test_orks17all_blitz_and_competitive_charge_rerolls():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.blitz_brigade()))
    absent = value_copy(not rl.orks_charge_reroll(board, board[0]))
    board[0][0].keywords.append(rl.Keyword.wagon())
    wagon = value_copy(rl.orks_charge_reroll(board, board[0]))
    board[1][0].orks_enhancement = rl.OrksEnhancement.competitive_streak()
    return absent and wagon and rl.orks_charge_reroll(board, board[1])

# Impulsive lets its Aircraft ingress in round1 while the ordinary Aircraft
# still waits for round2. This is not a price/reserve-limit exception.
def test_orks17all_impulsive_first_round_ingress_gate():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.flyboyz()))
    board.begin_phase(rl.BattlePhase.movement())
    board[0][0].keywords.append(rl.Keyword.aircraft())
    ordinary = value_copy(not rl.orks_ingress_round_allowed(board, board[0]))
    board[0][0].orks_enhancement = rl.OrksEnhancement.impulsive_recon()
    fast = value_copy(rl.orks_ingress_round_allowed(board, board[0]))
    board[0].history.has_ingressed = True
    return ordinary and fast and (not rl.orks_ingress_round_allowed(board, board[0]))

# Flyboss riles nearby Aircraft/Deffkoptas after actual ingress, excluding
# ordinary infantry and enemy units regardless of their flying keywords.
def test_orks17all_flyboss_ingress_recipient_gate():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.flyboyz()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.flyboss()
    board[0][0].keywords.append(rl.Keyword.aircraft())
    friendly = value_copy(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    friendly.models.resize(1)
    friendly[0].position = board_position(8, 5)
    orks17all_tag(friendly, rl.OrksDatasheet.deffkoptas())
    board.units.append(friendly)
    board.identify_units()
    rl.orks_flyboss_ingress(board, rl.unit_id(0))
    return rl.unit_is_riled_up(board[0]) and rl.unit_is_riled_up(board[2]) and (not rl.unit_is_riled_up(board[1]))

# A phase start clears stale battlefield revival anchors in both offboard
# banks; an arriving unit cannot claim it started the phase on the board.
def test_orks17all_offboard_phase_start_snapshots_clear():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.kult_of_speed()))
    before = value_copy(not board[0].history.phase_start_members.empty())
    moved = value_copy(rl.reposition_unit(board, rl.unit_id(0)))
    board.begin_phase(rl.BattlePhase.movement())
    return before and moved and board.reserve_units[0].history.phase_start_members.empty() and board.reserve_units[0].history.phase_start_engagements.empty()

# Named enhancement weapons use their exact printed characteristic/rule
# profiles, with D3 interpreted as fixed3 only where the card prints3.
def test_orks17all_named_enhancement_weapon_profiles():
    return orks17h1_weapon_values(rl.Weapon.orks_da_gobshot_thunderbuss(), 24, 6, 4, 7, -2, 2) and orks17h1_weapon_values(rl.Weapon.orks_da_krunch(), 24, 3, 4, 5, -1, 1) and orks17h1_weapon_values(rl.Weapon.orks_eadbanger(), 24, 2, 4, 6, -3, 3) and (rl.Weapon.orks_da_gobshot_thunderbuss().get_rule_parameter(rl.WeaponRuleKind.rapid_fire()) == 6) and (rl.Weapon.orks_da_krunch().get_rule_parameter(rl.WeaponRuleKind.blast()) == 3) and rl.Weapon.orks_eadbanger().has_rule(rl.WeaponRuleKind.precision())

# Retained models keep riled status for their authorised attacks; ordinary
# pending corpses cannot substitute for an active riled unit.
def test_orks17all_retained_riled_attack_status():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.bully_boyz()))
    orks17f_intrinsic_riled(board[0][0])
    board[0][0].suffered_wounds = board[0][0].profile.wounds()
    board[0][0].state = rl.ModelState.fight_on_death()
    retained = value_copy(rl.unit_is_riled_up(board[0]))
    board[0][0].state = rl.ModelState.pending_destruction()
    return retained and (not rl.unit_is_riled_up(board[0]))

# Board/source/declaration history round trips include schema32 and the new
# keyed fields. Incorrect enum values are rejected before any load commits.
def test_orks17all_detachment_state_save_and_invalid_enum():
    game = value_copy(rl.play())
    game.board = orks17all_fixture(rl.OrksDetachment.shoota_boyz())
    rl.grant_orks_effect(game.board, rl.unit_id(0), rl.unit_id(0), 300 + rl.Stratagem.orks_never_enough_dakka().value, rl.OrksEffectKind.ranged_sustained(), 1, rl.SourceDuration.phase(), rl.invalid_entity_identity())
    restored = value_copy(rl.play())
    good = value_copy(rl.set_state(restored, rl.to_string(game)) and rl.unit_orks_effect(restored.board, restored.board[0], rl.OrksEffectKind.ranged_sustained()) == 1)
    game.board[0][0].orks_enhancement.value = 99
    return good and (not rl.set_state(restored, rl.to_string(game))) and (restored.board[0][0].orks_enhancement.value == 0)

# Minimal explicit transport metadata validates cargo consumers without
# inventing Battlewagon/Morkanaut profiles or source base/hull sizes.
def orks17all_transport_fixture():
    board = value_copy(transport16_fixture())
    board.armies[0].faction = rl.ArmyFaction.orks()
    package = value_copy(board.armies[0].record_detachment(rl.OrksDetachment.blitz_brigade()))
    board[0][0].keywords.append(rl.Keyword.orks())
    board[0][0].keywords.append(rl.Keyword.wagon())
    for member in range(board[1].models.size()):
        board[1][member].keywords.append(rl.Keyword.orks())
    board.command_points[0] = 10
    return value_copy(board)

# Blitzboss retains a BETTER native save, grants+2 M only while this bearer
# is cargo, and removes both keyed grants after disembark/death.
def test_orks17all_blitzboss_cargo_lifetime_and_better_save():
    board = value_copy(orks17all_transport_fixture())
    board[1][0].orks_enhancement = rl.OrksEnhancement.blitzboss()
    original_inv = value_copy(board[0][0].effective_invulnerable_save())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    cargo = value_copy(board[0][0].effective_movement(6) == 8 and board[0][0].effective_invulnerable_save() == rl.min(5, original_inv))
    board.embarked_units[0].embarked_transport = 0
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return cargo and board[0][0].effective_movement(6) == 6 and (board[0][0].effective_invulnerable_save() == original_inv)

# Targetin' Gizmos requires an actual Big Mek in this carrier; riled changes
# only the Sustained addition, and empty cargo ends both permissions.
def test_orks17all_targetin_gizmos_actual_cargo_and_riled():
    board = value_copy(orks17all_transport_fixture())
    board[0][0].orks_enhancement = rl.OrksEnhancement.targetin_gizmos()
    board[1][0].keywords.append(rl.Keyword.big_mek())
    empty = value_copy(not rl.available_weapon_has_rule(board, rl.unit_id(0), 0, 0, rl.WeaponRuleKind.ignore_cover()))
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    cover = value_copy(rl.available_weapon_has_rule(board, rl.unit_id(0), 0, 0, rl.WeaponRuleKind.ignore_cover()))
    orks17f_intrinsic_riled(board[0][0])
    sustained = value_copy(rl.available_weapon_has_rule(board, rl.unit_id(0), 0, 0, rl.WeaponRuleKind.sustained_hit()))
    board.embarked_units[0].embarked_transport = 0
    return empty and cover and sustained and (not rl.available_weapon_has_rule(board, rl.unit_id(0), 0, 0, rl.WeaponRuleKind.ignore_cover()))

# Boss Boomer borrows the actual Warboss's ability and its distinct shared
# army-round counter, rather than treating its text as Keep Huntin'.
def test_orks17all_boss_boomer_borrowed_ability_dependency():
    board = value_copy(orks17all_transport_fixture())
    board[0][0].orks_enhancement = rl.OrksEnhancement.boss_boomer()
    board[1][0].keywords.append(rl.Keyword.warboss())
    board[1][0].abilities.append(rl.AbilityKind.intimidating_motivation())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    borrowed = value_copy(board[0][0].has_ability(rl.AbilityKind.intimidating_motivation()))
    sources = value_copy(rl.collect_source_events(board, orks17h23_move_event(board, 0, False, rl.MovementKind.normal())))
    registered = value_copy(sources.size() == 1 and board.source_instances[sources[0].source.value].rule.value == rl.ORKS_INTIMIDATING_RULE)
    board.embarked_units[0].embarked_transport = 0
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    ceased = value_copy(rl.collect_source_events(board, orks17h23_move_event(board, 0, False, rl.MovementKind.normal())).empty())
    return borrowed and registered and ceased and (not board[0][0].has_ability(rl.AbilityKind.intimidating_motivation()))

# Readied triggers only after WAGON Normal completion; its passengers get
# Assault setup with charging permitted, rather than ordinary Rapid lock.
def test_orks17all_readied_assault_disembark_permission():
    board = value_copy(orks17all_transport_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    rl.record_move(board, rl.unit_id(0), rl.MovementKind.normal())
    card = value_copy(rl.orks_wagon_move_end(board, rl.unit_id(0)))
    card.readied_brawlers(board)
    carrier = value_copy(rl.find_passenger_carrier(board, board.embarked_units[0].embarked_transport))
    return card.is_done() and board.command_points[0] == 9 and (rl.required_disembark_mode(board, board.embarked_units[0], carrier) == rl.DisembarkMode.assault())

# Keep It Runnin' is a whole-unit6in exception, allows an already-selected
# unit, and respects actual carrier capacity rather than normal after-move3in.
def test_orks17all_keep_running_six_inch_whole_unit_embark():
    board = value_copy(orks17all_transport_fixture())
    board.begin_phase(rl.BattlePhase.fight())
    board[1][0].position = board_position(14, 10)
    board[1][1].position = board_position(14, 12)
    board[1].history.fight_eligible_phase = board.phase_serial.value + 1
    eligible = value_copy(rl.orks_end_card_valid(board, rl.unit_id(1), rl.Stratagem.orks_keep_it_runnin(), False, rl.TimingWindow.fight_end()))
    card = value_copy(rl.orks_package_window(board, rl.unit_id(1), False, rl.TimingWindow.fight_end()))
    card.choose_orks_window_stratagem(board, rl.Stratagem.orks_keep_it_runnin())
    card.choose_fight_end_transport(board, rl.unit_id(0))
    card.choose_fight_end_carrier_model(board, damage_test_model(0))
    return eligible and card.is_done() and board[1].retired and (board.embarked_units.size() == 1) and (board.embarked_units[0].models.size() == 2)

# Wurrband transport contributors are actual models, not their weighted
# transport-space usage (one carrier's psychic weapon strength).
def test_orks17all_psychic_passenger_count_not_seats():
    board = value_copy(orks17all_transport_fixture())
    board[1][0].transport_space = 3
    board[1][1].transport_space = 2
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    return rl.embarked_models_for_psyker(board, board[0][0].identity) == 2 and rl.passenger_space_used(board, board[0][0].identity) == 5

# Dreadherder measures from its bearer, grants a turn-long reroll to the
# selected Walker and does not require that bearer to shoot first.
def test_orks17all_dreadherder_before_other_units_shoot():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.dread_mob()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.dreadherder()
    walker = value_copy(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    walker.models.resize(1)
    walker[0].keywords.append(rl.Keyword.walker())
    walker[0].position = board_position(7, 5)
    board.units.append(walker)
    board.identify_units()
    available = value_copy(rl.orks_dreadherder_available(board, rl.unit_id(0)))
    selection = value_copy(rl.orks_dreadherder_shooting(board, rl.unit_id(0)))
    selection.choose_dreadherder_target(board, rl.unit_id(2))
    granted = value_copy(rl.unit_orks_effect(board, board[2], rl.OrksEffectKind.reroll_hits_ones()) == 1)
    board.begin_phase(rl.BattlePhase.fight())
    return available and granted and (not board[0].has_shoot) and (rl.unit_orks_effect(board, board[2], rl.OrksEffectKind.reroll_hits_ones()) == 1)

# A successful Surly returns its original identity with3W at a nearest legal
# quad. Its once-per-army token prevents another source/attempt this battle.
def test_orks17all_surly_original_identity_three_wounds():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.brute_bosses()))
    boss = value_copy(rl.make_octavius())
    boss.owned_by_player1 = True
    boss[0].position = board_position(12, 5)
    boss[0].keywords.append(rl.Keyword.orks())
    boss[0].keywords.append(rl.Keyword.warboss())
    boss[0].orks_enhancement = rl.OrksEnhancement.surly_as_a_squiggoth()
    board[1] = boss
    board.identify_units()
    identity = value_copy(board[1][0].identity)
    board[1][0].suffered_wounds = board[1][0].profile.wounds()
    board[1][0].destroyed_phase = board.phase_serial.value + 1
    board[1].remove_model(0)
    revival = value_copy(rl.resolve_orks_surly(board, rl.unit_id(1), True))
    revival.choose_surly_casualty(board, damage_test_model(0))
    revival.roll(board, attack_test_die(2))
    revival.place_surly_model(board, board_position(12, 5))
    return revival.is_done() and board[1][0].identity == identity and (board[1][0].wounds_left() == 3) and board[1].destroyed_models.value.empty() and (not rl.source_usage_available(board, rl.orks_option_usage(board[1], board[1][0], rl.OrksEnhancement.surly_as_a_squiggoth())))

# Returned passengers need a real available seat; no-trigger destruction on
# lack of seats cannot start another death explosion/recursion (01.02.03).
def test_orks17all_offboard_return_capacity_gate():
    board = value_copy(orks17all_transport_fixture())
    rl.embark_battlefield_unit(board, rl.unit_id(1), rl.unit_id(0), damage_test_model(0))
    returned = value_copy(board.embarked_units[0][0])
    board.embarked_units[0].remove_model(0)
    available = value_copy(rl.orks_offboard_return_capacity(board, board.embarked_units[0], returned))
    board[0][0].transport_capacity = 1
    return available and (not rl.orks_offboard_return_capacity(board, board.embarked_units[0], returned))

# At a full source arena, a disabled/dead unreferenced slot can be reused only
# with a new generation; a frozen pending event must never activate the new
# occupant even when owner/rule/type happen to match (identity infrastructure).
def test_orks17all_source_arena_reuse_rejects_stale_generation():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.war_horde()))
    instance = rl.new('SourceInstance')
    instance.rule = 470
    instance.owner = False
    instance.source_unit = board[0].identity
    instance.window = rl.TimingWindow.command_start()
    instance.optional = True
    instance.grant = rl.riled_up_grant()
    for slot in range(rl.MAX_SOURCE_INSTANCES):
        handle = value_copy(rl.register_source_instance(board, instance))
    event = rl.new('SourceEvent')
    event.kind = rl.SourceEventKind.timing_window()
    event.window = rl.TimingWindow.command_start()
    frozen = value_copy(rl.collect_source_events(board, event))
    old_generation = value_copy(board.source_instances[0].generation)
    board.source_instances[0].disabled = True
    reused = value_copy(rl.register_source_instance(board, instance))
    choice = rl.new('SourceEventID')
    assign(choice, 0)
    return frozen.size() == rl.MAX_SOURCE_INSTANCES and reused.value == 0 and (board.source_instances[0].generation != old_generation) and (not rl.pending_source_valid(board, frozen, choice, False)) and rl.valid_source_foundations(board)

# Slot recycling protects every ordinary reserve/passenger return slot. It
# applies only to NEW replacements, never compacts or redirects ordinary units.
def test_orks17all_replacement_slot_reservation_protection():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.runt_swarm()))
    while board.units.size() < rl.MAX_UNIT_COUNT:
        empty = rl.new('Unit')
        empty.retired = True
        board.units.append(empty)
    reserved = value_copy(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    reserved.models.resize(1)
    reserved.has_return_slot = True
    reserved.return_slot = 2
    board.reserve_units.append(reserved)
    return rl.orks_replacement_slot(board) == 3 and rl.battlefield_entry_available(board, board.reserve_units[0])

# A live Surly end-phase archive cannot be evicted by a replacement arriving
# into a full arena before its mandatory revival chance (source lifecycle).
def test_orks17all_replacement_slot_pending_surly_protection():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.brute_bosses()))
    boss = value_copy(rl.make_octavius())
    boss[0].orks_enhancement = rl.OrksEnhancement.surly_as_a_squiggoth()
    board.units.append(boss)
    board.identify_units()
    board[2][0].destroyed_phase = board.phase_serial.value + 1
    board[2].remove_model(0)
    while board.units.size() < rl.MAX_UNIT_COUNT:
        empty = rl.new('Unit')
        empty.retired = True
        board.units.append(empty)
    return rl.orks_replacement_slot(board) == 3

# The largest native permission list still has room for exactly one card-
# added bodyguard. Re-applying the same permission does not append a duplicate.
def test_orks17all_extra_leader_permission_seven_slot_envelope():
    board = value_copy(orks17all_option_board(1, rl.OrksDetachment.taktikal_brigade(), True))
    orks17all_tag(board.reserve_units[0], rl.OrksDatasheet.big_mek())
    rl.configure_orks_attachment(board.reserve_units[0], rl.OrksDatasheet.big_mek())
    original = value_copy(board.reserve_units[0].permitted_bodyguards.size())
    rl.apply_orks_option(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.kill_kommanda(), False)
    added = value_copy(board.reserve_units[0].permitted_bodyguards.size() == original + 1)
    rl.orks_extra_bodyguard_permission(board.reserve_units[0], rl.OrksDatasheet.kommandos())
    return added and board.reserve_units[0].permitted_bodyguards.size() == original + 1 and (rl.MAX_BODYGUARD_TYPES == 7)

# Kill Kommanda's attached bearer gets Stealth/Infiltrators; bodyguard death
# ends that conditional active conferral, including a still-archived component.
def test_orks17all_kill_kommanda_bearer_attachment_condition():
    board = value_copy(orks17all_option_board(2, rl.OrksDetachment.taktikal_brigade(), True))
    orks17all_tag(board.reserve_units[0], rl.OrksDatasheet.big_mek())
    rl.configure_orks_attachment(board.reserve_units[0], rl.OrksDatasheet.big_mek())
    rl.apply_orks_option(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.kill_kommanda(), False)
    orks17all_tag(board.reserve_units[1], rl.OrksDatasheet.kommandos())
    board.reserve_units[1].attachment_role = rl.AttachmentRole.bodyguard()
    bearer = value_copy(board.reserve_units[0][0].identity)
    rl.attach_reserved_unit(board, rl.unit_id(0), rl.unit_id(1), False)
    index = value_copy(board.reserve_units[0].find_model(bearer))
    attached = value_copy(rl.orks_model_grants_ability(board.reserve_units[0], board.reserve_units[0][index], rl.AbilityKind.stealth()))
    bodyguard = value_copy(1 - index)
    board.reserve_units[0].remove_model(bodyguard)
    return attached and (not rl.orks_model_grants_ability(board.reserve_units[0], board.reserve_units[0][0], rl.AbilityKind.stealth()))

# Source-marker ownership follows which player selected Wreckas. The target's
# objective can qualify even when the shooter was not within an objective.
def test_orks17all_wrecka_target_objective_reroll():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.wreckas()))
    orks17all_tag(board[0], rl.OrksDatasheet.flash_gitz())
    board.mission_scoring = rl.MissionScoringMode.legacy_four_markers()
    location = value_copy(board.get_objectives_locations()[0])
    board[1][0].position = location
    return orks17c2b_info(board, 0).reroll1_hits

# Flyboss can make an otherwise non-Character Aircraft eligible for Warlord
# selection, but it remains an Upgrade and cannot be combined with another.
def test_orks17all_flyboss_character_upgrade_muster():
    board = value_copy(orks17all_option_board(1, rl.OrksDetachment.flyboyz(), False))
    board.reserve_units[0][0].keywords.append(rl.Keyword.aircraft())
    rl.apply_orks_option(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.flyboss(), False)
    return board.reserve_units[0].has_keyword(rl.Keyword.character()) and board.reserve_units[0][0].has_keyword(rl.Keyword.character()) and (not rl.orks_option_selection_valid(board, rl.unit_id(0), damage_test_model(0), rl.OrksEnhancement.impulsive_recon(), False))

# Optional declines do not consume army tokens, CP or phase-target history.
def test_orks17all_optional_declines_leave_usage_unspent():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.war_horde()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.da_boss_is_watchin()
    board.begin_phase(rl.BattlePhase.movement())
    ability = value_copy(rl.orks_movement_abilities(board, rl.unit_id(0)))
    ability.finish_orks_movement_abilities(board)
    return ability.is_done() and board.source_uses.empty() and (board.command_points[0] == 10) and rl.orks_movement_ability_available(board, rl.unit_id(0))

# A source effect installed in reserves keeps its duration and is removed at
# the next OWN turn, not merely because the opposing turn starts.
def test_orks17all_offboard_effect_boundary_and_save():
    game = value_copy(rl.play())
    game.board = orks17all_fixture(rl.OrksDetachment.war_horde())
    game.board.begin_phase(rl.BattlePhase.movement())
    game.board[0][0].orks_enhancement = rl.OrksEnhancement.da_boss_is_watchin()
    moved = value_copy(rl.reposition_unit(game.board, rl.unit_id(0)))
    ability = value_copy(rl.choose_orks_offboard_support(game.board, False, False))
    ability.choose_orks_support_bank(game.board, rl.SourceBank.reserves())
    ability.choose_orks_offboard_unit(game.board, rl.unit_id(0))
    restored = value_copy(rl.play())
    saved = value_copy(rl.set_state(restored, rl.to_string(game)))
    restored.board.current_player = True
    restored.board.turn_serial = restored.board.turn_serial + 1
    rl.refresh_source_effects(restored.board, rl.TimingWindow.none())
    persists = value_copy(rl.unit_is_riled_up(restored.board.reserve_units[0]))
    restored.board.current_player = False
    restored.board.turn_serial = restored.board.turn_serial + 1
    rl.refresh_source_effects(restored.board, rl.TimingWindow.none())
    return moved and saved and persists and (not rl.unit_is_riled_up(restored.board.reserve_units[0]))


# Flyin' Headbutt replaces demise and must apply its8 rolled mortals BEFORE
# removing the destroyed Aircraft; this guards the work stack's LIFO order.
def test_orks17all_headbutt_mortals_before_aircraft_removal():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.flyboyz()))
    board[0][0].keywords.append(rl.Keyword.aircraft())
    board[0][0].has_deadly_demise = True
    board[0][0].deadly_demise = rl.raw_stat(6)
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(1), True, True, 30, board[0][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(1)))
    empty = rl.new('DamageJobs')
    cleanup = value_copy(rl.resolve_damage_jobs(board, empty, True, rl.unit_id(1)))
    cleanup.choose_destruction_unit(board, rl.unit_id(0))
    cleanup.resolve_destruction_model(board, damage_test_model(0))
    cleanup.flyin_headbutt(board)
    cleanup.choose_headbutt_target(board, rl.unit_id(1))
    cleanup.roll(board, attack_test_die(4))
    for face in range(7):
        cleanup.roll(board, attack_test_die(1))
    retained = value_copy(board[0].models.size() == 1 and cleanup.can_select_mortal_model(board, damage_test_model(0)))
    cleanup.select_mortal_model(board, damage_test_model(0))
    return retained and cleanup.is_done() and (board[0].models.size() == 0) and (board[1][0].suffered_wounds == 1) and (board.command_points[0] == 9)

# Impulsive's first-own-Movement exception does not authorize another phase
# or the opponent's turn. Normal round2 ingress remains unaffected.
def test_orks17all_impulsive_own_movement_only():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.flyboyz()))
    board[0][0].keywords.append(rl.Keyword.aircraft())
    board[0][0].orks_enhancement = rl.OrksEnhancement.impulsive_recon()
    wrong_phase = value_copy(not rl.orks_ingress_round_allowed(board, board[0]))
    board.begin_phase(rl.BattlePhase.movement())
    own = value_copy(rl.orks_ingress_round_allowed(board, board[0]))
    board.current_player = True
    return wrong_phase and own and (not rl.orks_ingress_round_allowed(board, board[0]))

# Dread Power spends CP on the selected Walker and keeps its riled effect
# through the opposing turn until the start of its next own turn.
def test_orks17all_dread_power_battlefield_duration():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.dread_mob()))
    board[0][0].keywords.append(rl.Keyword.walker())
    board.begin_phase(rl.BattlePhase.movement())
    valid = value_copy(rl.orks_support_card_valid(board, rl.unit_id(0), rl.Stratagem.orks_dread_power(), False, rl.TimingWindow.none()))
    card = value_copy(rl.use_orks_support_card(board, rl.unit_id(0), rl.Stratagem.orks_dread_power()))
    board.current_player = True
    board.turn_serial = board.turn_serial + 1
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    persists = value_copy(rl.unit_is_riled_up(board[0]))
    board.current_player = False
    board.turn_serial = board.turn_serial + 1
    rl.refresh_source_effects(board, rl.TimingWindow.none())
    return valid and card.is_done() and (board.command_points[0] == 9) and persists and (not rl.unit_is_riled_up(board[0]))

# Mob Mentality pays on13+-model infantry; its separate visible nearby ORKS
# beneficiary auto-passes the command shock roll without a chance decision.
def test_orks17all_mob_mentality_separate_beneficiary():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.green_tide()))
    mob = value_copy(rl.make_orks_beast_snagga_boyz(1, 12, 0))
    mob.owned_by_player1 = False
    board[0] = mob
    board[1].owned_by_player1 = False
    board.identify_units()
    for index in range(board[0].models.size()):
        board[0][index].position = board_position(5 + index % 4, 5 + index // 4)
    board.begin_phase(rl.BattlePhase.command())
    valid = value_copy(rl.orks_support_card_valid(board, rl.unit_id(0), rl.Stratagem.orks_mob_mentality(), False, rl.TimingWindow.command_start()))
    card = value_copy(rl.use_orks_support_card(board, rl.unit_id(0), rl.Stratagem.orks_mob_mentality()))
    card.choose_mob_mentality_target(board, rl.unit_id(1))
    board[1].battle_socked = True
    penalty = rl.new('LinearlyDistributedInt<0, 8>')
    shock = value_copy(rl.battle_shock_test(board, board[1], True, True, penalty))
    return valid and card.is_done() and shock.is_done() and (not board[1].battle_socked) and (board.command_points[0] == 9) and board[0].history.used_stratagem_this_phase

# Delicious heals each distinct chosen nearby infantry by3, with one buggy
# payment; another selection of an already healed unit is illegal.
def test_orks17all_delicious_distinct_units_one_payment():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.kult_of_speed()))
    orks17all_tag(board[0], rl.OrksDatasheet.rukkatrukk_squigbuggies())
    board[1].owned_by_player1 = False
    board[1][0].position = board_position(7, 5)
    board[1][0].suffered_wounds = 1
    board.begin_phase(rl.BattlePhase.movement())
    card = value_copy(rl.use_orks_support_card(board, rl.unit_id(0), rl.Stratagem.orks_delicious_eating_squigs()))
    card.choose_squig_healing_unit(board, rl.unit_id(1))
    card.choose_healed_model(board, damage_test_model(0))
    no_repeat = value_copy(not card.can_choose_squig_healing_unit(board, rl.unit_id(1)))
    card.finish_eating_squigs(board)
    return no_repeat and card.is_done() and (board[1][0].suffered_wounds == 0) and (board.command_points[0] == 9)

# A dead offboard Surly returns to its original reserve unit with3W and its
# original identity. No battlefield measurement/setup choice is generated.
def test_orks17all_offboard_surly_original_return():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.brute_bosses()))
    board[0][0].orks_enhancement = rl.OrksEnhancement.surly_as_a_squiggoth()
    identity = value_copy(board[0][0].identity)
    moved = value_copy(rl.reposition_unit(board, rl.unit_id(0)))
    board.reserve_units[0][0].suffered_wounds = board.reserve_units[0][0].profile.wounds()
    board.reserve_units[0][0].destroyed_phase = board.phase_serial.value + 1
    board.reserve_units[0].remove_model(0)
    revival = value_copy(rl.resolve_orks_offboard_surly(board, board.reserve_units[0], damage_test_model(0)))
    revival.roll(board, board.reserve_units[0], attack_test_die(2))
    return moved and revival.is_done() and (board.reserve_units[0][0].identity == identity) and (board.reserve_units[0][0].wounds_left() == 3) and board.reserve_units[0][0].off_battlefield

# Invalid Dreadherder entry must preserve its caller's decision owner.
def test_orks17all_dreadherder_invalid_owner_restoration():
    board = value_copy(orks17all_fixture(rl.OrksDetachment.dread_mob()))
    board.current_decision_maker = True
    board.begin_phase(rl.BattlePhase.movement())
    board.current_decision_maker = True
    selection = value_copy(rl.orks_dreadherder_shooting(board, rl.unit_id(0)))
    return selection.is_done() and board.current_decision_maker


#12 current version1.2 Orks card adapters. Each test cites its source card;
# helper fixtures exercise actual declarations, rather than old army profiles.
def orks17p1_fixture(source):
    board = value_copy(orks17h1_attack_board())
    board[0] = source
    for index in range(board[0].models.size()):
        board[0][index].position = board_position(5 + index % 4 * 2, 5 + index // 4 * 2)
    board[1][0].position = board_position(9, 5)
    board.identify_units()
    board.capture_starting_strengths()
    board.begin_phase(rl.BattlePhase.shooting())
    rl.configure_attack_info(board, 0, 1, False, False)
    return value_copy(board)

# Boyz: reusable literal-count fixture permits independently checked swaps.
def orks17p1_boy_equipment(nobs, boys):
    equipment = rl.new('OrksBoyzLoadouts')
    for index in range(nobs + boys):
        item = rl.new('OrksBoyzLoadout')
        item.nob = index < nobs
        equipment.append(item)
    return value_copy(equipment)

# Nobz: independent per-five equipment quotas, no point-tier restriction.
def orks17p1_nob_equipment(count):
    equipment = rl.new('OrksNobLoadouts')
    for index in range(count):
        equipment.append(rl.OrksNobLoadout.standard())
    return value_copy(equipment)

# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz: printed profile/InSv/FNP/base.
def test_orks17p1_boy_profile():
    return orks17h1_profile_values(rl.Profile.orks_boy(), 6, 5, 5, 10, 1, 7, 2, 10) and rl.Profile.orks_boy().base_size() == 32.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz: printed profile/InSv/FNP/base.
def test_orks17p1_boyz_nob_profile():
    return orks17h1_profile_values(rl.Profile.orks_boyz_nob(), 6, 5, 5, 10, 3, 7, 2, 10) and rl.Profile.orks_boyz_nob().base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz: printed profile/InSv/FNP/base.
def test_orks17p1_nob_profile():
    return orks17h1_profile_values(rl.Profile.orks_nob(), 6, 5, 4, 10, 3, 7, 1, 10) and rl.Profile.orks_nob().base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss: printed profile/InSv/FNP/base.
def test_orks17p1_warboss_profile():
    return orks17h1_profile_values(rl.Profile.orks_warboss(), 6, 6, 4, 5, 6, 6, 1, 10) and rl.Profile.orks_warboss().base_size() == 50.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Bigboss: printed profile/InSv/FNP/base.
def test_orks17p1_bigboss_profile():
    return orks17h1_profile_values(rl.Profile.orks_bigboss(), 6, 5, 4, 10, 5, 7, 1, 10) and rl.Profile.orks_bigboss().base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Bannernob: printed profile/InSv/FNP/base.
def test_orks17p1_bannernob_profile():
    return orks17h1_profile_values(rl.Profile.orks_bannernob(), 6, 5, 4, 5, 4, 7, 3, 10) and rl.Profile.orks_bannernob().base_size() == 40.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Stormboyz: printed profile/InSv/FNP/base.
def test_orks17p1_stormboy_profile():
    return orks17h1_profile_values(rl.Profile.orks_stormboy(), 12, 5, 5, 10, 1, 7, 1, 10) and rl.Profile.orks_stormboy().base_size() == 32.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Stormboyz: printed profile/InSv/FNP/base.
def test_orks17p1_stormboy_nob_profile():
    return orks17h1_profile_values(rl.Profile.orks_stormboy_nob(), 12, 5, 5, 10, 3, 7, 1, 10) and rl.Profile.orks_stormboy_nob().base_size() == 32.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers: printed profile/InSv/FNP/base.
def test_orks17p1_warbiker_profile():
    return orks17h1_profile_values(rl.Profile.orks_warbiker(), 12, 6, 4, 6, 3, 7, 2, 10) and rl.Profile.orks_warbiker().base_size() == 75.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers: printed profile/InSv/FNP/base.
def test_orks17p1_biker_nob_profile():
    return orks17h1_profile_values(rl.Profile.orks_biker_nob(), 12, 6, 4, 6, 4, 7, 2, 10) and rl.Profile.orks_biker_nob().base_size() == 75.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread: printed profile/InSv/FNP/base.
def test_orks17p1_deff_dread_profile():
    return orks17h1_profile_values(rl.Profile.orks_deff_dread(), 8, 9, 2, 6, 8, 7, 3, 10) and rl.Profile.orks_deff_dread().base_size() == 60.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans: printed profile/InSv/FNP/base.
def test_orks17p1_killa_kan_profile():
    return orks17h1_profile_values(rl.Profile.orks_killa_kan(), 8, 7, 3, 6, 5, 8, 2, 10) and rl.Profile.orks_killa_kan().base_size() == 60.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-Dakkarig: printed profile/InSv/FNP/base.
def test_orks17p1_big_mek_dakkarig_profile():
    return orks17h1_profile_values(rl.Profile.orks_big_mek_dakkarig(), 8, 8, 3, 5, 11, 7, 3, 10) and rl.Profile.orks_big_mek_dakkarig().base_size() == 90.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur: printed profile/InSv/FNP/base.
def test_orks17p1_beastboss_on_squigosaur_profile():
    return orks17h1_profile_values(rl.Profile.orks_beastboss_on_squigosaur(), 10, 9, 3, 5, 10, 6, 3, 5) and rl.Profile.orks_beastboss_on_squigosaur().base_size() == 80.0

# https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad: printed profile/InSv/FNP/base.
def test_orks17p1_mozrog_skragbad_profile():
    return orks17h1_profile_values(rl.Profile.orks_mozrog_skragbad(), 10, 9, 3, 4, 10, 6, 3, 5) and rl.Profile.orks_mozrog_skragbad().base_size() == 80.0

# Boyz: literal1–2 Nobs/9–18 Boys, including intermediate compositions.
def test_orks17p1_boy_count_boundaries():
    small = value_copy(orks17p1_boy_equipment(1, 9))
    large = value_copy(orks17p1_boy_equipment(2, 18))
    intermediate = value_copy(orks17p1_boy_equipment(2, 11))
    invalid = value_copy(orks17p1_boy_equipment(1, 8))
    return rl.orks_boyz_loadout_valid(small) and rl.orks_boyz_loadout_valid(large) and rl.orks_boyz_loadout_valid(intermediate) and (not rl.orks_boyz_loadout_valid(invalid)) and (rl.make_orks_boyz(large).models.size() == 20)

# Boyz: all three different replacements coexist at ten models.
def test_orks17p1_boy_independent_specials():
    equipment = value_copy(orks17p1_boy_equipment(1, 9))
    equipment[1].boy_gun = rl.OrksBoyGunChoice.big_shoota()
    equipment[2].boy_gun = rl.OrksBoyGunChoice.rokkit_launcha()
    equipment[3].boy_gun = rl.OrksBoyGunChoice.burna()
    valid = value_copy(rl.orks_boyz_loadout_valid(equipment))
    unit = value_copy(rl.make_orks_boyz(equipment))
    equipment[4].boy_gun = rl.OrksBoyGunChoice.burna()
    return valid and (not rl.orks_boyz_loadout_valid(equipment)) and (unit[1].weapons.size() == 3) and (unit[2].weapons.size() == 4) and (unit[3].weapons.size() == 3) and (unit[2].weapon_profile_groups[2] == unit[2].weapon_profile_groups[3])

# Boyz: per-ten TOTAL models means nineteen permits one, twenty permits two.
def test_orks17p1_boy_twenty_quota():
    equipment = value_copy(orks17p1_boy_equipment(2, 18))
    equipment[2].boy_gun = rl.OrksBoyGunChoice.big_shoota()
    equipment[3].boy_gun = rl.OrksBoyGunChoice.big_shoota()
    valid = value_copy(rl.orks_boyz_loadout_valid(equipment))
    equipment.erase(19)
    return valid and (not rl.orks_boyz_loadout_valid(equipment))

# Boyz: Big Choppa removes both Nob weapons; other swaps retain a gun.
def test_orks17p1_mixed_nob_weapons():
    equipment = value_copy(orks17p1_boy_equipment(2, 9))
    equipment[0].melee = rl.OrksNobMeleeChoice.big_choppa()
    equipment[0].nob_gun = rl.OrksNobGunChoice.none()
    equipment[1].melee = rl.OrksNobMeleeChoice.power_klaw()
    equipment[1].nob_gun = rl.OrksNobGunChoice.kombi_rokkit()
    valid = value_copy(rl.orks_boyz_loadout_valid(equipment))
    unit = value_copy(rl.make_orks_boyz(equipment))
    equipment[0].nob_gun = rl.OrksNobGunChoice.kustom_shoota()
    return valid and unit[0].weapons.size() == 1 and (unit[1].weapons.size() == 3) and (unit[1].weapons[0].value == rl.Weapon.orks_power_klaw().value) and (not rl.orks_boyz_loadout_valid(equipment))

# Nobz: independent Paired/heavy quotas per-five, all replacements exclusive.
def test_orks17p1_nob_independent_replacements():
    equipment = value_copy(orks17p1_nob_equipment(5))
    equipment[0] = rl.OrksNobLoadout.paired_krumpas()
    equipment[1] = rl.OrksNobLoadout.big_skorcha()
    equipment[2] = rl.OrksNobLoadout.kustom_big_shoota()
    equipment[3] = rl.OrksNobLoadout.big_choppa()
    equipment[4] = rl.OrksNobLoadout.kombi_rokkit()
    valid = value_copy(rl.orks_nobz_loadout_valid(equipment))
    unit = value_copy(rl.make_orks_nobz(equipment))
    return valid and unit[0].paired_krumpas and (unit[0].weapons.size() == 1) and (unit[1].weapons[0].value == rl.Weapon.orks_kustom_choppa().value) and (unit[2].weapons.size() == 2) and (unit[3].weapons.size() == 1) and (unit[4].weapons.size() == 3)

# Nobz: every restricted replacement rejects its second copy below ten.
def test_orks17p1_nob_quota_boundaries():
    valid = value_copy(True)
    for kind in range(4):
        equipment = value_copy(orks17p1_nob_equipment(10))
        choice = rl.new('OrksNobLoadout')
        choice.value = kind + 2
        equipment[0] = choice
        equipment[1] = choice
        valid = valid and rl.orks_nobz_loadout_valid(equipment)
        equipment.erase(9)
        valid = valid and (not rl.orks_nobz_loadout_valid(equipment))
    too_small = value_copy(orks17p1_nob_equipment(4))
    too_big = value_copy(orks17p1_nob_equipment(11))
    return valid and (not rl.orks_nobz_loadout_valid(too_small)) and (not rl.orks_nobz_loadout_valid(too_big))

# Deff-Dread: twenty independent permitted arm combinations, fixed Klaws retained.
def test_orks17p1_dread_all_arm_combinations():
    valid = value_copy(True)
    for first_index in range(5):
        for second_index in range(5):
            if first_index != 1:
                first = rl.new('OrksDreadArmChoice')
                first.value = first_index
                second = rl.new('OrksDreadArmChoice')
                second.value = second_index
                unit = value_copy(rl.make_orks_deff_dread(first, second))
                valid = valid and unit[0].weapons[0].value == rl.Weapon.orks_dread_klaws().value and (unit[0].weapon_profile_groups[1].value == 1) and (unit[0].weapon_profile_groups[unit[0].weapons.size() - 1].value == 2)
    return valid

# Deff-Dread: two Extra Klaws are distinct physical mandatory melee weapons.
def test_orks17p1_dread_two_extra_klaws():
    board = value_copy(orks17p1_fixture(rl.make_orks_deff_dread(rl.OrksDreadArmChoice.extra_klaw(), rl.OrksDreadArmChoice.extra_klaw())))
    selected = rl.new('Bool[MAX_WEAPONS]')
    selected[1] = True
    other = value_copy(rl.weapon_selection_valid(board, rl.unit_id(0), 0, 2, True, selected, False))
    return other and board[0][0].weapons.size() == 3 and (board[0][0].weapon_profile_groups[1] != board[0][0].weapon_profile_groups[2]) and board[0][0].weapons[2].has_rule(rl.WeaponRuleKind.extra_attacks())

# Deff-Dread: Dread 'Ard affects incoming attack D, never non-attack mortal jobs.
def test_orks17p1_dread_incoming_damage():
    unit = value_copy(rl.make_orks_deff_dread())
    modifiers = rl.new('RuleModifiers')
    incoming = value_copy(rl.combined_incoming_modifiers(modifiers, unit[0].incoming_attack_modifiers, rl.ModifiedCharacteristic.damage(), True))
    return rl.modified_characteristic(3, rl.ModifiedCharacteristic.damage(), incoming, False) == 2 and rl.modified_characteristic(1, rl.ModifiedCharacteristic.damage(), incoming, False) == 1 and unit[0].has_deadly_demise and (rl.stat_dice_count(unit[0].deadly_demise) == 0)

# Stormboyz/Warbikers/Kans: endpoints and printed keyword/Deep Strike metadata.
def test_orks17p1_mobile_unit_compositions():
    storm = value_copy(rl.make_orks_stormboyz(9, True))
    bikes = value_copy(rl.make_orks_warbikers(5))
    kans = value_copy(rl.make_orks_killa_kans(6))
    return storm.models.size() == 10 and storm[0].weapons[1].value == rl.Weapon.orks_power_klaw().value and storm.has_ability(rl.AbilityKind.deep_strike()) and storm.has_keyword(rl.Keyword.fly()) and (bikes.models.size() == 6) and bikes.has_keyword(rl.Keyword.speed_freeks()) and (kans.models.size() == 6) and kans.has_keyword(rl.Keyword.grots()) and (not kans.has_keyword(rl.Keyword.gretchin()))

# Warbikers: documented circular proxy preserves both source axes.
def test_orks17p1_biker_circle_proxy():
    unit = value_copy(rl.make_orks_warbikers(2))
    return rl.profile_has_oval_base(unit[0].profile) and rl.profile_base_width(unit[0].profile) == 42.0 and (unit[0].profile.base_size() == 75.0) and (not unit[0].geometry.unsupported_footprint) and (unit[1].weapons.size() == 2) and (unit[0].weapon_profile_groups[0] == unit[0].weapon_profile_groups[1])

# Killa-Kans: all three gun profiles are alternatives of one physical weapon.
def test_orks17p1_kan_profile_exclusion():
    board = value_copy(orks17p1_fixture(rl.make_orks_killa_kans(3)))
    selected = rl.new('Bool[MAX_WEAPONS]')
    first = value_copy(rl.weapon_selection_valid(board, rl.unit_id(0), 0, 0, False, selected, False))
    selected[0] = True
    return first and (not rl.weapon_selection_valid(board, rl.unit_id(0), 0, 1, False, selected, False)) and (not rl.weapon_selection_valid(board, rl.unit_id(0), 0, 2, False, selected, False))

# Warboss/Bannernob/Bigboss: real Leader/Support roles and Da Boss only on Warboss.
def test_orks17p1_boss_attachment_metadata():
    leader = value_copy(rl.make_orks_warboss())
    support = value_copy(rl.make_orks_bigboss())
    banner = value_copy(rl.make_orks_bannernob())
    return leader.attachment_role.value == rl.AttachmentRole.leader().value and leader[0].has_da_boss and (support.attachment_role.value == rl.AttachmentRole.support().value) and (not support[0].has_da_boss) and (banner.attachment_role.value == rl.AttachmentRole.support().value) and support[0].weapons[1].has_rule(rl.WeaponRuleKind.precision())

# Mozrog/Dakkarig/Squigosaur: no invented Leader or Da Boss metadata.
def test_orks17p1_monster_and_mek_metadata():
    mozrog = value_copy(rl.make_orks_mozrog_skragbad())
    mek = value_copy(rl.make_orks_big_mek_dakkarig())
    squigo = value_copy(rl.make_orks_beastboss_on_squigosaur(True))
    return mozrog.has_keyword(rl.Keyword.epic_hero()) and (not mozrog.has_keyword(rl.Keyword.warboss())) and (not mozrog[0].has_da_boss) and (not mek[0].has_da_boss) and mek.has_keyword(rl.Keyword.big_mek()) and squigo[0].has_da_boss and (squigo[0].weapons.size() == 5) and (squigo.attachment_role.value != rl.AttachmentRole.leader().value)

# Ammo Runts: own Shooting only; battle-shock does not forbid free use.
def test_orks17p1_ammo_timing_and_owner():
    board = value_copy(orks17p1_fixture(rl.make_orks_boyz(1, 9)))
    board[0].battle_socked = True
    own = value_copy(rl.orks_ammo_available(board, rl.unit_id(0), False))
    board.current_player = True
    opponent = value_copy(not rl.orks_ammo_available(board, rl.unit_id(0), False))
    board.current_player = False
    board.begin_phase(rl.BattlePhase.fight())
    return own and opponent and (not rl.orks_ammo_available(board, rl.unit_id(0), False)) and (not rl.orks_ammo_available(board, rl.unit_id(1), False))

# Ammo Runts: decline preserves token and caller owner, commit spends once.
def test_orks17p1_ammo_selection_and_limit():
    board = value_copy(orks17p1_fixture(rl.make_orks_boyz(1, 9)))
    board.current_decision_maker = True
    choice = value_copy(rl.orks_datasheet_selection(board, rl.unit_id(0)))
    choice.use_ammo_runts(board, False)
    kept = value_copy(choice.is_done() and board.current_decision_maker == True and rl.orks_ammo_available(board, rl.unit_id(0), False))
    accepted = value_copy(rl.orks_datasheet_selection(board, rl.unit_id(0)))
    accepted.use_ammo_runts(board, True)
    return kept and accepted.is_done() and (board.current_decision_maker == True) and (not rl.orks_ammo_available(board, rl.unit_id(0), False)) and (rl.unit_orks_effect(board, board[0], rl.OrksEffectKind.ammo_runts_hit()) == 1) and rl.valid_state_foundations(board)

# Ammo Runts: every member's ranged attack benefits; melee never does.
def test_orks17p1_ammo_ranged_scope():
    board = value_copy(orks17p1_fixture(rl.make_orks_nobz(5)))
    rl.commit_orks_ammo(board, rl.unit_id(0), False)
    ranged = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 4, 1))
    gun = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), ranged, board.attack_info))
    melee = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 4, 0))
    chop = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), melee, board.attack_info))
    return gun.total_hit_modifier() == 1 and chop.total_hit_modifier() == 0 and (rl.attack_hit_choices(board, gun).size() == 1)

# Boss Ammo Runt: bearer-only when attached, separate token from Boyz Ammo.
def test_orks17p1_attached_ammo_tokens_and_scope():
    board = rl.new('Board')
    board.reserve_units.append(rl.make_orks_boyz(1, 9))
    board.reserve_units.append(rl.make_orks_warboss())
    board.identify_units()
    rl.attach_reserved_unit(board, rl.unit_id(1), rl.unit_id(0), False)
    attachment17g_battlefield(board)
    board.begin_phase(rl.BattlePhase.shooting())
    rl.configure_attack_info(board, 0, 0, False, False)
    rl.commit_orks_ammo(board, rl.unit_id(0), False)
    rl.commit_orks_ammo(board, rl.unit_id(0), True)
    return rl.unit_orks_effect(board, board[0], rl.OrksEffectKind.ammo_runts_hit()) == 1 and rl.model_orks_effect(board, board[0][10], rl.OrksEffectKind.boss_ammo_hit()) == 1 and (rl.model_orks_effect(board, board[0][1], rl.OrksEffectKind.boss_ammo_hit()) == 0) and (not rl.orks_ammo_available(board, rl.unit_id(0), True)) and rl.valid_state_foundations(board)

# Ammo Runts: phase effect expires while battle usage remains spent.
def test_orks17p1_ammo_expiry_not_refresh():
    board = value_copy(orks17p1_fixture(rl.make_orks_nobz(5)))
    rl.commit_orks_ammo(board, rl.unit_id(0), False)
    board.begin_phase(rl.BattlePhase.charge())
    expired = value_copy(rl.unit_orks_effect(board, board[0], rl.OrksEffectKind.ammo_runts_hit()) == 0)
    board.begin_phase(rl.BattlePhase.shooting())
    return expired and (not rl.orks_ammo_available(board, rl.unit_id(0), False))

# Boyz/Tide of Muscle: charged melee gains Lethal even versus Monster.
def test_orks17p1_tide_charge_and_profile_scope():
    board = value_copy(orks17p1_fixture(rl.make_orks_boyz(1, 9)))
    before = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 0))
    board[0].has_charged = True
    board[1][0].keywords.append(rl.Keyword.monster())
    melee = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 0))
    ranged = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 2))
    return not rl.declared_weapon_has_kind(before, rl.WeaponRuleKind.letal_hits()) and rl.chosen_weapon_has_rule(board, rl.unit_id(1), melee.selected_rules, rl.WeaponRuleKind.letal_hits()) and (not rl.chosen_weapon_has_rule(board, rl.unit_id(1), ranged.selected_rules, rl.WeaponRuleKind.letal_hits()))

# Boyz/Never Too Busy: engagement alone waived; shock remains forbidden.
def test_orks17p1_boy_action_engagement_waiver():
    board = value_copy(orks17p1_fixture(rl.make_orks_boyz(1, 9)))
    board[1][0].position = board_position(6, 5)
    allowed = value_copy(board.is_in_melee(board[0]) and rl.action_start_valid(board, rl.unit_id(0), False))
    board[0].battle_socked = True
    return allowed and (not rl.action_start_valid(board, rl.unit_id(0), False))

# Nobz/Paired Krumpas: only the bearer's Kustom Krumpa receives both rerolls.
def test_orks17p1_paired_krumpas_bearer_and_weapon():
    equipment = value_copy(orks17p1_nob_equipment(5))
    equipment[0] = rl.OrksNobLoadout.paired_krumpas()
    board = value_copy(orks17p1_fixture(rl.make_orks_nobz(equipment)))
    paired = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    ordinary = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 0))
    yes = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), paired, board.attack_info))
    no = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), ordinary, board.attack_info))
    return yes.reroll_hits and yes.reroll_wounds and (not no.reroll_hits) and (not no.reroll_wounds)

# Warboss/Might Is Right: charge buffs only own melee+3A/+2S.
def test_orks17p1_warboss_charge_statistics():
    board = value_copy(orks17p1_fixture(rl.make_orks_warboss()))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    before = value_copy(rl.declaration_fixed_attacks(board, rl.unit_id(0), declaration, 0))
    board[0].has_charged = True
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    gun = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 1))
    return before == 6 and rl.declaration_fixed_attacks(board, rl.unit_id(0), declaration, 0) == 9 and (info.attack_strength() == 9) and (rl.declaration_fixed_attacks(board, rl.unit_id(0), gun, 0) == 4)

# Bigboss/Sumfin’: melee only, conferring source needed, corpse retention p67.
def test_orks17p1_bigboss_hit_source_loss():
    board = value_copy(orks17p1_fixture(rl.make_orks_bigboss()))
    melee = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 1))
    gun = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    yes = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), melee, board.attack_info))
    no = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), gun, board.attack_info))
    board[0][0].state = rl.ModelState.pending_destruction()
    return yes.total_hit_modifier() == 1 and no.total_hit_modifier() == 0 and (not board[0].has_ability(rl.AbilityKind.sumfin_to_prove()))

# Bannernob: addition precedes division/rounding, twelve/Into the Fray caps.
def test_orks17p1_banner_order_and_caps():
    unit = value_copy(rl.make_orks_bannernob())
    unit.phase_modifiers.charge_roll.append(rl.rule_modifier(rl.ModifierOperation.divide(), 2))
    rounded = value_copy(rl.charge_distance(unit, 4, rl.ChargeKind.ordinary(), False) == 3)
    unit.phase_modifiers.charge_roll.clear()
    return rounded and rl.charge_distance(unit, 12, rl.ChargeKind.ordinary(), False) == 12 and (rl.charge_distance(unit, 6, rl.ChargeKind.into_the_fray(), False) == 6)

# Appendix02.02.02: every offered contribution can be kept, including all34.
def test_orks17p1_modifier_full_capacity_and_origin():
    board = value_copy(orks17p1_fixture(rl.make_orks_bigboss()))
    choices = rl.new('AttackModifierChoices')
    for index in range(34):
        choices.append(rl.attack_modifier_choice(rl.rule_modifier(rl.ModifierOperation.add(), 1), rl.ModifierOrigin.orks_datasheet()))
    sequence = value_copy(rl.choose_attack_modifiers(board, choices, False, rl.ModifierSelectionKind.hit_roll(), True))
    for index in range(34):
        sequence.apply_attack_modifier(board, True)
    return sequence.is_done() and sequence.result.size() == 34 and (rl.selected_hit_bonus(sequence.result) == 1)

# Stormboyz/Rokkit Charge: optional pre-declaration+1A/S/Hazardous and expiry.
def test_orks17p1_rokkit_selection_and_hazardous():
    board = value_copy(orks17p1_fixture(rl.make_orks_stormboyz(4, False)))
    board.begin_phase(rl.BattlePhase.fight())
    board[0].has_charged = True
    choice = value_copy(rl.orks_rokkit_selection(board, rl.unit_id(0)))
    choice.use_rokkit_charge(board, True)
    melee = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 1))
    info = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), melee, board.attack_info))
    yes = value_copy(choice.is_done() and rl.declaration_fixed_attacks(board, rl.unit_id(0), melee, 0) == 4 and (info.attack_strength() == 6) and rl.declared_weapon_has_kind(melee, rl.WeaponRuleKind.hazardous()))
    board.begin_phase(rl.BattlePhase.shooting())
    return yes and rl.unit_orks_effect(board, board[0], rl.OrksEffectKind.rokkit_charge()) == 0

# Stormboyz: declining and a non-charging fight grant nothing.
def test_orks17p1_rokkit_decline_and_no_charge():
    board = value_copy(orks17p1_fixture(rl.make_orks_stormboyz(4, True)))
    board.begin_phase(rl.BattlePhase.fight())
    absent = value_copy(rl.orks_rokkit_selection(board, rl.unit_id(0)))
    board[0].has_charged = True
    choice = value_copy(rl.orks_rokkit_selection(board, rl.unit_id(0)))
    choice.use_rokkit_charge(board, False)
    return absent.is_done() and choice.is_done() and (rl.unit_orks_effect(board, board[0], rl.OrksEffectKind.rokkit_charge()) == 0)

# Warbikers/High Speed Carnage: charge+1S/D melee, not gun/uncharged.
def test_orks17p1_biker_charge_melee_damage():
    board = value_copy(orks17p1_fixture(rl.make_orks_warbikers(2)))
    board[0].has_charged = True
    melee = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 1))
    gun = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 1, 0))
    chop = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), melee, board.attack_info))
    ranged = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), gun, board.attack_info))
    return chop.attack_strength() == 6 and rl.modified_characteristic(1, rl.ModifiedCharacteristic.damage(), chop.damage_modifiers, False) == 2 and (ranged.attack_strength() == gun.weapon.strenght()) and (ranged.damage_modifiers.size() == 0)

# Nobz/Get Out da Way: only Charge traverses enemy Infantry, not Monster/Vehicle.
def test_orks17p1_nob_charge_traversal():
    board = value_copy(orks17p1_fixture(rl.make_orks_nobz(5)))
    board[0].models.resize(1)
    board[1][0].position = board_position(7, 5)
    path = rl.new('ModelPath')
    infantry = value_copy(rl.charge_waypoint_valid(board, board[0], path, board_position(9, 5), 6, False))
    board[1][0].keywords.append(rl.Keyword.vehicle())
    vehicle = value_copy(not rl.charge_waypoint_valid(board, board[0], path, board_position(9, 5), 6, False))
    board[0][0].keywords.append(rl.Keyword.fly())
    return infantry and vehicle and rl.charge_waypoint_valid(board, board[0], path, board_position(9, 5), 6, True)

# Killa-Kans/Spiteful Power Trip: every live target model's T matters.
def test_orks17p1_kans_mixed_toughness_and_dead_model():
    board = value_copy(orks17p1_fixture(rl.make_orks_killa_kans(3)))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    ordinary = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    high = value_copy(rl.make_orks_beastboss_on_squigosaur(False))
    board[1].models.append(high[0])
    board.identify_units()
    mixed = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    board[1][1].state = rl.ModelState.pending_destruction()
    dead = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), declaration, board.attack_info))
    return ordinary.total_hit_modifier() == 1 and mixed.total_hit_modifier() == 0 and (dead.total_hit_modifier() == 1)

# Dakkarig/Blitz Dem Gitz: declared non-Monster/Vehicle only, own Shooting.
def test_orks17p1_blitz_target_and_gathering():
    board = value_copy(orks17p1_fixture(rl.make_orks_big_mek_dakkarig()))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    declaration.targeted[1] = True
    gathered = value_copy(rl.gather_weapon_count(board, rl.unit_id(0), rl.unit_id(1), declaration, False))
    extra = value_copy(gathered.is_done() and gathered.result == 14)
    board[1][0].keywords.append(rl.Keyword.vehicle())
    vehicle = value_copy(rl.gather_weapon_count(board, rl.unit_id(0), rl.unit_id(1), declaration, False))
    board[1][0].keywords.clear()
    board.current_player = True
    other_turn = value_copy(rl.gather_weapon_count(board, rl.unit_id(0), rl.unit_id(1), declaration, False))
    return extra and vehicle.result == 8 and (other_turn.result == 8)

# Dakkarig/Even More Dakka: riled ranged Sustained1, no melee grant.
def test_orks17p1_dakkarig_riled_profile_scope():
    board = value_copy(orks17p1_fixture(rl.make_orks_big_mek_dakkarig()))
    before = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    orks17f_intrinsic_riled(board[0][0])
    gun = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    feet = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 2))
    return not rl.declared_weapon_has_kind(before, rl.WeaponRuleKind.sustained_hit()) and rl.declared_weapon_has_kind(gun, rl.WeaponRuleKind.sustained_hit()) and (not rl.declared_weapon_has_kind(feet, rl.WeaponRuleKind.sustained_hit()))

# Squigosaur/Mozrog: Hunter target restrictions and D6+1 intrinsic expression.
def test_orks17p1_monster_hunters_and_random_damage():
    board = value_copy(orks17p1_fixture(rl.make_orks_mozrog_skragbad()))
    declaration = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 3))
    board[1][0].position = board_position(7, 5)
    ordinary = value_copy(not rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), True))
    board[1][0].keywords.append(rl.Keyword.monster())
    allowed = value_copy(rl.declaration_target_valid(board, rl.unit_id(0), declaration, rl.unit_id(1), True))
    return ordinary and allowed and (rl.stat_dice_count(declaration.weapon.damage()) == 1) and (rl.stat_dice_sides(declaration.weapon.damage()) == 6) and (rl.stat_intrinsic_constant(declaration.weapon.damage()) == 1)

# Stampede aura: self qualifies, identical auras never stack; enemy/offboard don't.
def test_orks17p1_stampede_aura_sources():
    board = value_copy(orks17p1_fixture(rl.make_orks_beastboss_on_squigosaur(False)))
    other = value_copy(rl.make_orks_beastboss_on_squigosaur(False))
    other[0].position = board_position(8, 5)
    board.units.append(other)
    board.identify_units()
    own = value_copy(rl.orks_stampede_charge_bonus(board, board[0]) == 1 and rl.charge_distance(board, board[0], 5, rl.ChargeKind.ordinary(), False) == 6)
    board[0].off_battlefield = True
    return own and rl.orks_stampede_charge_bonus(board, board[0]) == 0

# Conditional Lone Operative: nearby Snagga, excluding MONSTER CHARACTER union.
def test_orks17p1_snagga_following_live_and_distance():
    board = value_copy(orks17p1_fixture(rl.make_orks_mozrog_skragbad()))
    before = value_copy(not rl.orks_lone_operative(board, board[0]))
    snagga = value_copy(rl.make_orks_beast_snagga_boyz(1, 9, 0))
    snagga.models.resize(1)
    snagga[0].position = board_position(8, 5)
    board.units.append(snagga)
    board.identify_units()
    near = value_copy(rl.orks_lone_operative(board, board[0]))
    board[2][0].position = board_position(12, 5)
    far = value_copy(not rl.orks_lone_operative(board, board[0]))
    board[2][0].position = board_position(8, 5)
    board[2].off_battlefield = True
    return before and near and far and (not rl.orks_lone_operative(board, board[0]))

# Mozrog/Da Bigger Dey Iz: unit-wide melee wound rerolls only vs Mon/Vehicle.
def test_orks17p1_mozrog_wound_rerolls_scope():
    board = value_copy(orks17p1_fixture(rl.make_orks_mozrog_skragbad()))
    melee = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 2))
    before = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), melee, board.attack_info))
    board[1][0].keywords.append(rl.Keyword.vehicle())
    yes = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), melee, board.attack_info))
    ranged = value_copy(rl.make_declared_weapon(board, rl.unit_id(0), 0, 0))
    no = value_copy(rl.declared_attack_info(board, rl.unit_id(0), rl.unit_id(1), ranged, board.attack_info))
    return not before.reroll_wounds and yes.reroll_wounds and (not no.reroll_wounds)

# Mozrog/One Last Kill: printed2+ in Fight before its unit has fought.
def test_orks17p1_mozrog_death_timing_threshold():
    board = value_copy(orks17p1_fixture(rl.make_orks_mozrog_skragbad()))
    shooting = value_copy(rl.orks_fight_death_threshold(board, board[0], board[0][0]) == 0)
    board.begin_phase(rl.BattlePhase.fight())
    fight = value_copy(rl.orks_fight_death_threshold(board, board[0], board[0][0]) == 2)
    board[0].has_fought = True
    return shooting and fight and (rl.orks_fight_death_threshold(board, board[0], board[0][0]) == 0)

# All twelve adapters survive actual Game serialization with physical groups.
def test_orks17p1_all_unit_saved_round_trip():
    state = value_copy(rl.play())
    state.board.reserve_units.append(rl.make_orks_boyz(1, 9))
    state.board.reserve_units.append(rl.make_orks_nobz(5))
    state.board.reserve_units.append(rl.make_orks_warboss())
    state.board.reserve_units.append(rl.make_orks_bigboss())
    state.board.reserve_units.append(rl.make_orks_bannernob())
    state.board.reserve_units.append(rl.make_orks_stormboyz(4, True))
    state.board.reserve_units.append(rl.make_orks_warbikers(2))
    state.board.reserve_units.append(rl.make_orks_deff_dread())
    state.board.reserve_units.append(rl.make_orks_killa_kans(3))
    state.board.reserve_units.append(rl.make_orks_big_mek_dakkarig())
    state.board.reserve_units.append(rl.make_orks_beastboss_on_squigosaur(True))
    state.board.reserve_units.append(rl.make_orks_mozrog_skragbad())
    state.board.identify_units()
    restored = value_copy(rl.play())
    saved = value_copy(rl.set_state(restored, rl.to_string(state)))
    return saved and restored.board.reserve_units.size() == 12 and (restored.board.reserve_units[6][0].weapon_profile_groups[0] == restored.board.reserve_units[6][0].weapon_profile_groups[1]) and (restored.board.reserve_units[11][0].profile == rl.Profile.orks_mozrog_skragbad()) and rl.valid_state_foundations(restored.board)

# Mozrog: FNP is resolved first, then2+ at destruction; retained fighter has
# already passed its permission roll and does not roll that permission again.
def test_orks17p1_mozrog_actual_death_success():
    board = value_copy(orks17p1_fixture(rl.make_orks_mozrog_skragbad()))
    board.begin_phase(rl.BattlePhase.fight())
    board[0][0].suffered_wounds = 9
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(1), True, True, 1, board[0][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(1)))
    damage.roll(board, attack_test_die(1))
    damage.roll(board, attack_test_die(2))
    return damage.is_done() and board[0][0].state == rl.ModelState.fight_on_death() and (board[0][0].destruction_fight_roll == 1) and board[0][0].destruction_pending

# Mozrog: saving the wound means no destroy-time permission roll.
def test_orks17p1_mozrog_fnp_prevents_death():
    board = value_copy(orks17p1_fixture(rl.make_orks_mozrog_skragbad()))
    board.begin_phase(rl.BattlePhase.fight())
    board[0][0].suffered_wounds = 9
    jobs = rl.new('DamageJobs')
    jobs.append(rl.damage_job(rl.DamageKind.normal(), rl.unit_id(0), rl.unit_id(1), True, True, 1, board[0][0].identity))
    damage = value_copy(rl.resolve_damage_jobs(board, jobs, False, rl.unit_id(1)))
    damage.roll(board, attack_test_die(5))
    return damage.is_done() and board[0][0].is_alive() and (not board[0][0].destruction_pending)

# Actual Attack delegates the new decision before weapon declaration; refusing
# a free token restores source ownership and leaves ordinary weapon inputs.
def test_orks17p1_attack_forwards_ammo_selection():
    board = value_copy(orks17p1_fixture(rl.make_orks_warboss()))
    board.current_decision_maker = True
    sequence = value_copy(rl.attack(board, rl.unit_id(0), rl.unit_id(1), False, False))
    offered = value_copy(sequence.can_use_boss_ammo_runt(board, True))
    sequence.use_boss_ammo_runt(board, False)
    return offered and (not sequence.is_done()) and rl.orks_ammo_available(board, rl.unit_id(0), True) and (board.current_decision_maker == False)

# Ammo effect and original battle usage survive the real save codec.
def test_orks17p1_ammo_saved_provenance():
    state = value_copy(rl.play())
    state.board = orks17p1_fixture(rl.make_orks_nobz(5))
    rl.commit_orks_ammo(state.board, rl.unit_id(0), False)
    restored = value_copy(rl.play())
    saved = value_copy(rl.set_state(restored, rl.to_string(state)))
    return saved and rl.unit_orks_effect(restored.board, restored.board[0], rl.OrksEffectKind.ammo_runts_hit()) == 1 and (not rl.orks_ammo_available(restored.board, rl.unit_id(0), False)) and rl.valid_state_foundations(restored.board)


# Stormboyz: actual selected-fight frame offers the choice before FightKind.
def test_orks17p1_selected_fight_forwards_rokkit():
    board = value_copy(orks17p1_fixture(rl.make_orks_stormboyz(4, True)))
    board.begin_phase(rl.BattlePhase.fight())
    board[0].has_charged = True
    board[0].history.fight_eligible_phase = board.phase_serial.value + 1
    sequence = value_copy(rl.selected_fight(board, rl.unit_id(0)))
    offered = value_copy(sequence.can_use_rokkit_charge(board, True))
    sequence.use_rokkit_charge(board, True)
    return offered and (not sequence.is_done()) and (rl.unit_orks_effect(board, board[0], rl.OrksEffectKind.rokkit_charge()) == 1)
