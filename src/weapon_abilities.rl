import board

using WeaponAbilitySet = CheckedVector<WeaponRule, 32>
using WeaponAbilityChoice = BInt<0, 32>

# All ANTI variants are duplicates of ANTI, even with different keywords (p.78).
fun same_weapon_ability(WeaponRuleKind left, WeaponRuleKind right) -> Bool:
    let left_anti = left == WeaponRuleKind::anti or left == WeaponRuleKind::anti_monster or left == WeaponRuleKind::anti_vehichle or left == WeaponRuleKind::anti_psychic
    let right_anti = right == WeaponRuleKind::anti or right == WeaponRuleKind::anti_monster or right == WeaponRuleKind::anti_vehichle or right == WeaponRuleKind::anti_psychic
    return left == right or (left_anti and right_anti)

# Bounded rule snapshots allow fixtures/future data without inventing profiles (p.78).
fun model_weapon_rules(Board board, UnitID source, Int model, Int slot) -> WeaponAbilitySet:
    let result : WeaponAbilitySet
    let intrinsic = board[source][model].weapons[slot].rules()
    for i in range(intrinsic.size()):
        result.append(intrinsic[i])
    for i in range(board[source][model].additional_weapon_rules[slot].size()):
        result.append(board[source][model].additional_weapon_rules[slot][i])
    let granted = board[source].get_temporary_weapon_rules()
    for i in range(granted.size()):
        result.append(granted[i])
    return result

# Selection/eligibility uses ability presence before the target is declared (p.78).
fun model_weapon_has_rule(Model model, Int slot, WeaponRuleKind kind) -> Bool:
    if model.weapons[slot].has_rule(kind):
        return true
    for i in range(model.additional_weapon_rules[slot].size()):
        if model.additional_weapon_rules[slot][i].kind == kind:
            return true
    return false

# Selected rules are immutable through resolution; applicability is target-specific (p.78).
fun chosen_weapon_has_rule(Board board, UnitID target, WeaponAbilitySet rules, WeaponRuleKind kind) -> Bool:
    let keyword : Keyword
    for i in range(rules.size()):
        keyword.value = rules[i].target_keyword.value
        if rules[i].kind == kind and board[target].weapon_rule_applies(rules[i]):
            return true
    return false

# Numeric abilities select one instance, never sum/max duplicate instances (p.78).
fun chosen_weapon_parameter(Board board, UnitID target, WeaponAbilitySet rules, WeaponRuleKind kind) -> Int:
    let keyword : Keyword
    for i in range(rules.size()):
        keyword.value = rules[i].target_keyword.value
        if rules[i].kind == kind and board[target].weapon_rule_applies(rules[i]):
            return rules[i].parameter.value
    return 0

# Find the next undecided ability; each choice removes the entire duplicate family (p.78).
fun next_weapon_ability(WeaponAbilitySet rules, Bool[32] decided) -> Int:
    for i in range(rules.size()):
        if !decided[i]:
            return i
    return -1

# Select duplicate instances at Select Weapons as printed, before targets (p.78).
act choose_weapon_abilities(ctx Board board, frm WeaponAbilitySet available) -> ChooseWeaponAbilities:
    board.pending_weapon_abilities = available
    frm chosen : WeaponAbilitySet
    frm decided : Bool[32]
    while next_weapon_ability(available, decided) >= 0:
        frm first : WeaponAbilityChoice
        first = next_weapon_ability(available, decided)
        let duplicates = 0
        for i in range(available.size()):
            if !decided[i] and same_weapon_ability(available[first.value].kind, available[i].kind):
                duplicates = duplicates + 1
        frm selected : WeaponAbilityChoice
        selected = first
        if duplicates > 1:
            act choose_weapon_ability(WeaponAbilityChoice instance) {instance.value < available.size(), !decided[instance.value], same_weapon_ability(available[first.value].kind, available[instance.value].kind)}
            selected = instance
        chosen.append(available[selected.value])
        for i in range(available.size()):
            if same_weapon_ability(available[first.value].kind, available[i].kind):
                decided[i] = true

# Both spelling aliases and explicit per-slot grants are close-quarters (pp.80/83).
fun model_weapon_close_quarters(Model model, Int slot) -> Bool:
    return model_weapon_has_rule(model, slot, WeaponRuleKind::pistol) or model_weapon_has_rule(model, slot, WeaponRuleKind::close_quarters)

# Keyword conditions are explicit source data, not inferred faction permissions (p.78).
fun conditional_weapon_rule(WeaponRuleKind kind, Int amount, Keyword target_keyword) -> WeaponRule:
    let result = weapon_rule(kind, amount)
    result.target_restricted = true
    result.target_keyword = target_keyword.value
    return result

# Editor-facing keyword enum for readable conditional-ability buttons (p.78).
fun weapon_ability_target_keyword(WeaponRule rule) -> Keyword:
    let keyword : Keyword
    keyword.value = rule.target_keyword.value
    return keyword

# Unit-granted abilities affect every equipped weapon as well (p.78).
fun available_weapon_has_rule(Board board, UnitID source, Int model, Int slot, WeaponRuleKind kind) -> Bool:
    return model_weapon_has_rule(board[source][model], slot, kind) or board[source].has_temporary_wepon_rule(kind)

# Retained corpses do not make a unit closer for range or detection (pp.9/87).
# Physical death hooks use their explicit retained model geometry instead.
fun live_distance_to_model(Unit unit, Model observer) -> Float:
    let shortest = 1000000.0
    for i in range(unit.models.size()):
        if unit[i].is_alive():
            let separation = observer.distance(unit[i])
            if separation < shortest:
                shortest = separation
    return shortest

# Alternative target keywords within one ability are OR conditions (p.78).
fun conditional_weapon_rule(WeaponRuleKind kind, Int amount, Keyword first, Keyword second) -> WeaponRule:
    let result = conditional_weapon_rule(kind, amount, first)
    let extra : LinearlyDistributedInt<0, 128>
    extra = second.value
    result.other_target_keywords[0] = extra
    result.other_target_count = 1
    return result

# Editor label for additional alternatives in a bounded keyword condition (p.78).
fun weapon_ability_other_target_keyword(WeaponRule rule, Int index) -> Keyword:
    let keyword : Keyword
    assert(index >= 0 and index < rule.other_target_count.value and index < 8, "invalid keyword alternative")
    keyword.value = rule.other_target_keywords[index].value
    return keyword

# Fixture/datasheet loading infrastructure: Godot's generated bindings do not
# expose fixed arrays of owning vectors. Validate selectors before appending
# explicit per-slot rule data (p.78); this is not a freely granted game action.
fun grant_model_weapon_rule(Board board, UnitID source, ModelID model, BInt<0, MAX_WEAPONS> slot, WeaponRule rule):
    assert(source.get() < board.units.size() and model.get() < board[source].models.size() and slot.value < board[source][model].weapons.size(), "invalid weapon-rule data slot")
    board[source][model].additional_weapon_rules[slot.value].append(rule)

# Editor bridge for the bounded fixed-array keyword alternatives (p.78).
fun weapon_ability_other_target_count(WeaponRule rule) -> Int:
    return rule.other_target_count.value
