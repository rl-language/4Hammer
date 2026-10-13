import board
import source_effects

# Optional ignoring follows the affected bearer's controller, with explicit
# ranged/melee and WS/BS versus hit-roll scope (appendix02.02.02).
fun attack_permission_available(Board board, Model model, Bool melee, Bool skill) -> Bool:
    assert(valid_attack_modifier_permissions(model.attack_modifier_permissions), "invalid ignore-modifier permissions")
    let allowed = false
    for permission_index in range(model.attack_modifier_permissions.size()):
        ref permission = model.attack_modifier_permissions[permission_index]
        let scoped = permission.scope.value == IncomingAttackScope::any_attack.value or (melee and permission.scope.value == IncomingAttackScope::melee.value) or (!melee and permission.scope.value == IncomingAttackScope::ranged.value)
        allowed = allowed or (scoped and source_grant_active(board, permission.source_effect) and ((skill and permission.skill) or (!skill and permission.hit_roll)))
    return allowed

# Keep raw operation/provenance until the optional choice; numerical sign
# alone does not identify whether a modifier is beneficial (02.02.02).
fun attack_modifier_choice(RuleModifier modifier, ModifierOrigin origin) -> AttackModifierChoice:
    let choice : AttackModifierChoice
    choice.modifier = modifier
    choice.origin = origin
    return choice

# Cover and Plunging Fire are separate BS operations, before rounding/floors;
# Ignores Cover removes its own contribution before offering choices (pp.50/73/82).
fun attack_skill_choices(Board board, AttackSequenceInfo info) -> AttackModifierChoices:
    let choices : AttackModifierChoices
    for modifier_index in range(info.skill_modifiers.size()):
        choices.append(attack_modifier_choice(info.skill_modifiers[modifier_index], ModifierOrigin::characteristic))
    if info.source.range() > 0 and info.plunging_fire:
        choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, -1), ModifierOrigin::plunging_fire))
    if info.source.range() > 0 and info.target_has_cover and !attack_ignores_cover(board, info):
        choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, 1), ModifierOrigin::cover))
    return choices

# Hit contributions remain individual: Heavy, Damaged and the two engagement
# penalties may be ignored independently before the cumulative cap (pp.18/35/63/82;
# Damaged24.39; appendix02.02.02). They never become BS/WS modifications.
fun attack_hit_choices(Board board, AttackSequenceInfo info) -> AttackModifierChoices:
    let choices : AttackModifierChoices
    if info.hit_roll_bonus:
        choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, 1), ModifierOrigin::hit_bonus))
    if info.hit_roll_malus:
        choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, -1), ModifierOrigin::hit_penalty))
    for profile_index in range(info.profile_hit_roll_bonus.size()):
        if info.profile_hit_roll_bonus[profile_index] == info.source_profile:
            choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, 1), ModifierOrigin::profile_hit_bonus))
            break
    if info.damaged_hit_penalty:
        choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, -1), ModifierOrigin::damaged))
    if info.has_weapon_rule(board, WeaponRuleKind::heavy) and (info.heavy_bonus or (!info.weapon_rules_known and heavy_unit_eligible(board, info.source_unit_id))):
        choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, 1), ModifierOrigin::heavy))
    if info.engaged_hit_penalties.value > 0:
        choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, -1), ModifierOrigin::engaged_source))
    if info.engaged_hit_penalties.value > 1:
        choices.append(attack_modifier_choice(rule_modifier(ModifierOperation::add, -1), ModifierOrigin::engaged_target))
    return choices

# Grouping cannot collapse equal final sums with different available subsets
# (p.17/02.02.02). Conservative provenance equality keeps each choice meaningful.
fun same_attack_modifier_choices(AttackModifierChoices left, AttackModifierChoices right) -> Bool:
    if left.size() != right.size():
        return false
    for choice_index in range(left.size()):
        if left[choice_index].origin.value != right[choice_index].origin.value or left[choice_index].modifier.operation.value != right[choice_index].modifier.operation.value or left[choice_index].modifier.amount != right[choice_index].modifier.amount or left[choice_index].modifier.negative != right[choice_index].modifier.negative:
            return false
    return true

# Frame/UI integrity rejects invalid provenance and operation metadata before
# action suspension or save restoration (02.02.02 infrastructure).
fun valid_attack_modifier_choice(AttackModifierChoice choice) -> Bool:
    let one : RuleModifiers
    one.append(choice.modifier)
    return choice.origin.value >= 0 and choice.origin.value <= ModifierOrigin::plunging_fire.value and valid_rule_modifiers(one)

# Sequential two-choice inputs represent every subset of the original list,
# without an exponential action payload. Declining/applying spends no CP or
# source usage (02.02.02); restore the caller's ownership and UI context.
act choose_attack_modifiers(ctx Board board, frm AttackModifierChoices choices, frm Bool player, frm ModifierSelectionKind kind, frm Bool permitted) -> ChooseAttackModifiers:
    frm result : SelectedAttackModifiers
    frm index : LinearlyDistributedInt<0, 19>
    frm previous_owner = board.current_decision_maker
    frm previous_choice = board.pending_modifier_choice
    frm previous_kind = board.pending_modifier_kind
    while index.value < choices.size():
        assert(valid_attack_modifier_choice(choices[index.value]), "invalid modifier selection")
        frm keep = true
        if permitted:
            board.current_decision_maker = player
            board.pending_modifier_choice = choices[index.value]
            board.pending_modifier_kind = kind
            act apply_attack_modifier(Bool apply_it)
            keep = apply_it
        if keep:
            result.append(choices[index.value].modifier)
        index = index + 1
    board.pending_modifier_choice = previous_choice
    board.pending_modifier_kind = previous_kind
    board.current_decision_maker = previous_owner

# Selected operations still use appendix02.02.01 arithmetic, special skill
# locking and characteristic limits; permission does not override Torrent '-'.
fun selected_attack_skill(AttackSequenceInfo info, SelectedAttackModifiers modifiers) -> Int:
    let kind = ModifiedCharacteristic::weapon_skill
    if info.source.range() > 0:
        kind = ModifiedCharacteristic::ballistic_skill
    return modified_characteristic(info.source.skill(), kind, modifiers, info.source.skill() == 0)

# Natural dice remain unchanged; only the retained hit modifier sum is capped
# (p.18/appendix02.02.01), after all permitted individual choices.
fun selected_hit_bonus(Int original, SelectedAttackModifiers modifiers) -> Int:
    return min(1, max(-1, apply_rule_modifiers(original, modifiers, false) - original))

# Core hit contributions are additive; callers comparing their sum may use
# zero, while actual dice supply their original face before the cap (02.02.01).
fun selected_hit_bonus(SelectedAttackModifiers modifiers) -> Int:
    return selected_hit_bonus(0, modifiers)

# Explicit core provenance and signed operation make the one-Bool editor
# control understandable; this label is binding infrastructure for02.02.02.
fun modifier_choice_label(Board board) -> String:
    let label = to_string(board.pending_modifier_kind)
    label.append(" / "s)
    label.append(to_string(board.pending_modifier_choice.origin))
    label.append(" / "s)
    label.append(to_string(board.pending_modifier_choice.modifier.operation))
    label.append(" "s)
    label.append(to_string(board.pending_modifier_choice.modifier.signed_amount()))
    return label
