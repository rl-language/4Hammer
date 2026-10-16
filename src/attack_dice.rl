import terrain_rules
import modifiers

# A batch stores counts of each unmodified D6 face, rather than an exponential
# multi-die action domain (p.18 simultaneous rolls). Counts remain bounded for
# inferred ML layout; accepting each result is input collection, not resolution.
cls AttackDicePool:
    CombatCounter[6] faces
    CombatCounter total

    # Every accepted input represents one die; reject unsupported batch sizes
    # instead of silently clamping the count (p.18).
    fun add(Dice face):
        assert(self.total.value + 1 < MAX_COMBAT_COUNTER, "attack dice capacity exceeded")
        self.faces[face.value - 1] = self.faces[face.value - 1] + 1
        self.total = self.total + 1

    # A replacement changes the distribution, not the number of attack dice
    # (re-roll p.56). Callers separately retain original reroll eligibility.
    fun replace(Dice old_face, Dice new_face):
        assert(self.faces[old_face.value - 1] > 0, "missing die to reroll")
        self.faces[old_face.value - 1] = self.faces[old_face.value - 1] - 1
        self.faces[new_face.value - 1] = self.faces[new_face.value - 1] + 1

enum AttackRollResult:
    failed
    success
    critical

    # Implementation comparison for critical/success/failure branches (p.18).
    fun equal(AttackRollResult other) -> Bool:
        return self.value == other.value

# A natural 1 fails before critical/threshold checks, and natural 6 is critical
# (p.18). Existing Snap Shooting's explicit six-only gate is p.57; the rest of
# that stratagem remains task 15. Cover changes BS independently of modifiers.
fun classify_attack_hit(Board board, AttackSequenceInfo info, Dice roll, Int modifier, Int skill) -> AttackRollResult:
    if roll == 1 or (info.fail_hits_up_to_three and roll.value <= 3):
        return AttackRollResult::failed
    if roll == 6:
        return AttackRollResult::critical
    if info.shooting_kind == ShootingKind::indirect and info.has_weapon_rule(board, WeaponRuleKind::indirect_fire) and roll.value < (6 - 2 * int(info.indirect_stationary_visible)):
        return AttackRollResult::failed
    if info.only_hits_on_6:
        return AttackRollResult::failed
    if roll.value + modifier >= skill:
        return AttackRollResult::success
    return AttackRollResult::failed

# Compatibility/classification without an ignore permission keeps all
# applicable skill modifiers; the selected overload preserves natural dice (p.18).
fun classify_attack_hit(Board board, AttackSequenceInfo info, Dice roll, Int modifier) -> AttackRollResult:
    return classify_attack_hit(board, info, roll, modifier, effective_attack_skill(board, info))

# Exact double/half boundaries use multiplication, with no integer-halving
# rounding (p.18). This helper applies no app-only modifier policy.
fun base_wound_threshold(Int strength, Int toughness) -> Int:
    if strength >= toughness * 2:
        return 2
    if strength > toughness:
        return 3
    if strength == toughness:
        return 4
    if strength * 2 <= toughness:
        return 6
    return 5

# ANTI uses the target unit's keyword union and unmodified result (p.79),
# while the mandatory natural-one failure still comes first (p.18).
# Multiple ANTI thresholds use the lowest positive value; unlike Sustained
# Hits magnitude, a higher threshold is not the stronger permission (p.79).
# Every grant path must honour its target predicate (appendix02.05.01).
fun best_anti_parameter(Board board, AttackSequenceInfo info, WeaponRuleKind kind) -> Int:
    let threshold = 7
    let intrinsic = info.source.rules()
    if info.weapon_rules_known:
        intrinsic.clear()
        for i in range(info.selected_weapon_rules.size()):
            intrinsic.append(info.selected_weapon_rules[i])
    let granted = board[info.source_unit_id].get_temporary_weapon_rules()
    if info.weapon_rules_known:
        granted.clear()
    for i in range(intrinsic.size()):
        if intrinsic[i].kind == kind and intrinsic[i].parameter > 0 and info.rule_applies(board, intrinsic[i]):
            threshold = min(threshold, intrinsic[i].parameter.value)
    for i in range(granted.size()):
        if granted[i].kind == kind and granted[i].parameter > 0 and info.rule_applies(board, granted[i]):
            threshold = min(threshold, granted[i].parameter.value)
    for i in range(info.temporary_weapon_abilities.size()):
        if info.temporary_weapon_abilities[i].kind == kind and info.temporary_weapon_abilities[i].parameter > 0 and info.rule_applies(board, info.temporary_weapon_abilities[i]):
            threshold = min(threshold, info.temporary_weapon_abilities[i].parameter.value)
    return threshold

# Natural six is critical; applicable ANTI thresholds can improve it by
# target unit keyword without modifying the die (pp.18/79).
fun critical_wound_threshold(Board board, AttackSequenceInfo info) -> Int:
    let threshold = 6
    if board[info.target_unit_id].has_keyword(Keyword::monster):
        let anti = best_anti_parameter(board, info, WeaponRuleKind::anti_monster)
        if anti > 0:
            threshold = min(threshold, anti)
    if board[info.target_unit_id].has_keyword(Keyword::vehicle):
        let anti = best_anti_parameter(board, info, WeaponRuleKind::anti_vehichle)
        if anti > 0:
            threshold = min(threshold, anti)
    if board[info.target_unit_id].has_keyword(Keyword::psyker):
        let anti = best_anti_parameter(board, info, WeaponRuleKind::anti_psychic)
        if anti > 0:
            threshold = min(threshold, anti)
    if info.has_weapon_rule(board, WeaponRuleKind::anti):
        let generic = info.max_weapon_parameter(board, WeaponRuleKind::anti)
        if generic > 0:
            threshold = min(threshold, generic)
    return threshold

# Reject an unsupported number of generated hits/wounds rather than silently
# losing attacks through bounded arithmetic (pp.17–18). Capacity is configured
# simulation infrastructure, not a limit imposed by the tabletop rulebook.
fun add_attack_count(CombatCounter count, Int increment):
    assert(increment >= 0 and count.value + increment < MAX_COMBAT_COUNTER, "generated attack capacity exceeded")
    count = count + increment

# Natural criticals succeed regardless of characteristic/roll penalties
# (p.18); ANTI changes their unmodified threshold (p.79).
fun classify_attack_wound(Board board, AttackSequenceInfo info, Dice roll, Int required) -> AttackRollResult:
    if roll == 1:
        return AttackRollResult::failed
    if roll.value >= critical_wound_threshold(board, info):
        return AttackRollResult::critical
    if roll.value >= required:
        return AttackRollResult::success
    return AttackRollResult::failed

# D must match to group attacks, including whether it is fixed or random
# (p.17). Do not mistake two different kinds with equal stored numbers.
fun same_damage_characteristic(Stat left, Stat right) -> Bool:
    if left is FixedStat:
        if right is FixedStat:
            return left.value == right.value
    if stat_dice_count(left) > 0 and stat_dice_count(right) > 0:
        return stat_dice_count(left) == stat_dice_count(right) and stat_dice_sides(left) == stat_dice_sides(right) and stat_intrinsic_constant(left) == stat_intrinsic_constant(right)
    return false
