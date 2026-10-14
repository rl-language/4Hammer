import board

using WeaponAbilitySet = CheckedVector<WeaponRule, 32>
using WeaponAbilityChoice = BInt<0, 32>

# All ANTI variants share one family (p.78); PISTOL and CLOSE-QUARTERS
# are identical for all rules purposes, including duplicate choices (p.83).
fun same_weapon_ability(WeaponRuleKind left, WeaponRuleKind right) -> Bool:
    let left_anti = left == WeaponRuleKind::anti or left == WeaponRuleKind::anti_monster or left == WeaponRuleKind::anti_vehichle or left == WeaponRuleKind::anti_psychic
    let right_anti = right == WeaponRuleKind::anti or right == WeaponRuleKind::anti_monster or right == WeaponRuleKind::anti_vehichle or right == WeaponRuleKind::anti_psychic
    let left_sidearm = left == WeaponRuleKind::pistol or left == WeaponRuleKind::close_quarters
    let right_sidearm = right == WeaponRuleKind::pistol or right == WeaponRuleKind::close_quarters
    return left == right or (left_anti and right_anti) or (left_sidearm and right_sidearm)

# Bounded rule snapshots allow fixtures/future data without inventing profiles (p.78).
fun model_weapon_rules(Board board, UnitID source, Int model, Int slot) -> WeaponAbilitySet:
    let result : WeaponAbilitySet
    let intrinsic = board[source][model].weapons[slot].rules()
    for i in range(intrinsic.size()):
        result.append(intrinsic[i])
    for i in range(board[source][model].additional_weapon_rules[slot].size()):
        result.append(board[source][model].additional_weapon_rules[slot][i])
    append_riled_assault_rules(board[source][model], board[source][model].weapons[slot], result)
    # War Horde/Get Stuck In supplies a distinct Sustained Hits1 instance;
    # select duplicate instances through the existing p78 ability choice.
    if war_horde_melee_rule_applies(board, source, board[source][model].weapons[slot]):
        result.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    let granted = board[source].get_temporary_weapon_rules()
    for i in range(granted.size()):
        result.append(granted[i])
    append_orks_package_weapon_rules(board, source, model, slot, result)
    append_orks_datasheet_weapon_rules(board, source, board[source][model].weapons[slot], result)
    return result

# Selection/eligibility uses ability presence before the target is declared (p.78).
fun model_weapon_has_rule(Model model, Int slot, WeaponRuleKind kind) -> Bool:
    if kind == WeaponRuleKind::assault and model.weapons[slot].range() > 0 and model.is_riled_up():
        return true
    if model.weapons[slot].has_rule(kind):
        return true
    for i in range(model.additional_weapon_rules[slot].size()):
        if model.additional_weapon_rules[slot][i].kind == kind:
            return true
    return false

# Selected rules are immutable through resolution; applicability is target-specific (p.78).
fun chosen_weapon_has_rule(Board board, UnitID target, WeaponAbilitySet rules, WeaponRuleKind kind) -> Bool:
    for i in range(rules.size()):
        if rules[i].kind == kind and source_grant_active(board, rules[i].source_effect) and board[target].weapon_rule_applies(rules[i]):
            return true
    return false

# Numeric abilities select one instance, never sum/max duplicate instances (p.78).
fun chosen_weapon_parameter(Board board, UnitID target, WeaponAbilitySet rules, WeaponRuleKind kind) -> Int:
    for i in range(rules.size()):
        if rules[i].kind == kind and source_grant_active(board, rules[i].source_effect) and board[target].weapon_rule_applies(rules[i]):
            return effective_weapon_ability_parameter(board, rules[i])
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

# A single or slash-separated keyword condition is ANY, not an implicit
# conjunction (p.78; appendix02.05.01). More complex data uses the predicate
# overload, without making a new freely selectable rule-grant action.
fun conditional_weapon_rule(WeaponRuleKind kind, Int amount, Keyword target_keyword) -> WeaponRule:
    let predicate : KeywordPredicate
    let added = append_keyword_condition(predicate, KeywordClause::any, target_keyword)
    assert(added, "invalid weapon keyword condition")
    return conditional_weapon_rule(kind, amount, predicate)

# Preserve the supplied ALL/ANY/NONE predicate in the selected rule snapshot
# until the target is known (p.78; appendix02.05.01).
fun conditional_weapon_rule(WeaponRuleKind kind, Int amount, KeywordPredicate predicate) -> WeaponRule:
    let keyword : Keyword
    assert(predicate.valid(max(keyword)), "invalid weapon keyword predicate")
    let result = weapon_rule(kind, amount)
    result.target_condition = predicate
    return result

# Editor bridge for fixed-array conditions; preserve each term's conjunction
# or exclusion in the label rather than presenting every term as OR.
fun weapon_ability_condition_count(WeaponRule rule) -> Int:
    return rule.target_condition.size()

# Keyword enum keeps source condition labels readable in Godot (appendix02.05.01).
fun weapon_ability_condition_keyword(WeaponRule rule, Int entry) -> Keyword:
    let keyword : Keyword
    assert(rule.target_condition.valid(max(keyword)) and entry >= 0 and entry < rule.target_condition.size(), "invalid keyword condition entry")
    keyword.value = rule.target_condition.keywords[entry].value
    return keyword

# Expose the corresponding logical clause, not a raw numeric condition code.
# This is editor metadata for the appendix02.05.01 condition.
fun weapon_ability_condition_clause(WeaponRule rule, Int entry) -> KeywordClause:
    assert(entry >= 0 and entry < rule.target_condition.size() and entry < MAX_KEYWORD_TERMS, "invalid keyword clause entry")
    return rule.target_condition.clause(entry)

# Unit-granted abilities affect every equipped weapon as well (p.78).
fun available_weapon_has_rule(Board board, UnitID source, Int model, Int slot, WeaponRuleKind kind) -> Bool:
    let rules = model_weapon_rules(board, source, model, slot)
    let present = false
    for entry in range(rules.size()):
        present = present or rules[entry].kind == kind and source_grant_active(board, rules[entry].source_effect)
    return present

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

# Slash-separated alternatives share one ANY clause (appendix02.05.01; p.78).
fun conditional_weapon_rule(WeaponRuleKind kind, Int amount, Keyword first, Keyword second) -> WeaponRule:
    let result = conditional_weapon_rule(kind, amount, first)
    let added = append_keyword_condition(result.target_condition, KeywordClause::any, second)
    assert(added, "invalid alternative weapon keyword condition")
    return result

# Fixture/datasheet loading infrastructure: Godot's generated bindings do not
# expose fixed arrays of owning vectors. Validate selectors before appending
# explicit per-slot rule data (p.78); this is not a freely granted game action.
fun grant_model_weapon_rule(Board board, UnitID source, ModelID model, BInt<0, MAX_WEAPONS> slot, WeaponRule rule):
    assert(source.get() < board.units.size() and model.get() < board[source].models.size() and slot.value < board[source][model].weapons.size(), "invalid weapon-rule data slot")
    board[source][model].additional_weapon_rules[slot.value].append(rule)

# p.83 and supplied appendix 04.01.03: One Shot belongs to the physical
# weapon; changing its selected profile cannot restore a spent weapon.
fun consume_one_shot_profile(Model model, Int slot):
    let group = model.weapon_profile_groups[slot].value
    for i in range(model.weapons.size()):
        if i == slot or (group != 0 and model.weapon_profile_groups[i].value == group):
            model.used_once_per_battle_weapon[i] = true


# Each riled source supplies ranged Assault with its own expiry key, so a
# declaration snapshot cannot revive an expired grant (Orks Waaagh!/01.02.02).
fun append_riled_assault_rules(Model model, Weapon weapon, WeaponAbilitySet rules):
    if weapon.range() == 0:
        return
    for riled_index in range(model.riled_source_effects.size()):
        let granted = weapon_rule(WeaponRuleKind::assault)
        granted.source_effect = model.riled_source_effects[riled_index]
        rules.append(granted)


# Get Stuck In is an army detachment rule, not a bearer aura or temporary
# source: friendly ORKS units' melee attacks have Sustained Hits1. Selections
# are fixed before battle; snapshots still select one duplicate instance (p78).
# https://wahapedia.ru/wh40k11ed/factions/orks/#Get-Stuck-In
fun war_horde_melee_rule_applies(Board board, UnitID source, Weapon weapon) -> Bool:
    if source.get() < 0 or source.get() >= board.units.size() or weapon.range() != 0:
        return false
    ref unit = board[source]
    ref army = board.armies[int(unit.owned_by_player1)]
    return army.faction == ArmyFaction::orks and army.has_detachment(OrksDetachment::war_horde) and unit.has_keyword(Keyword::orks)


# A phase-limited numeric improvement expires without deleting its intrinsic
# ability instance (Close-range Dakka/Mow 'Em Down; appendix01.02.02).
fun effective_weapon_ability_parameter(Board board, WeaponRule rule) -> Int:
    let parameter = rule.parameter.value
    if rule.parameter_increment_source.value > 0 and !source_grant_active(board, rule.parameter_increment_source):
        parameter = parameter - rule.parameter_increment_amount.value
    return max(0, parameter)
