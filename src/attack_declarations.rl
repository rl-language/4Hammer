import attack_dice

# Each model can select at most its eight weapon slots (p.16). Targets are
# indexed by the unchanged UnitID domain, so melee shares have bounded storage
# without expanding every declaration into a separate unbounded record.
const MAX_SELECTED_WEAPONS = 256
const MAX_SELECTED_WEAPONS_PLUS1 = 257
using AttackWeaponID = BInt<0, MAX_SELECTED_WEAPONS>
using AttackShare = LinearlyDistributedInt<0, MAX_CHARACTERISTIC>
using AttackShareChoice = BInt<1, MAX_CHARACTERISTIC>

cls DeclaredWeapon:
    ModelID model
    EntityIdentity model_identity
    BInt<0, MAX_WEAPONS> slot
    Weapon weapon
    Bool made_attacks
    Bool[MAX_UNIT_COUNT] targeted
    Bool[MAX_UNIT_COUNT] resolved
    AttackShare[MAX_UNIT_COUNT] shares
    LinearlyDistributedInt<0, MAX_STAT_MODIFIER>[MAX_UNIT_COUNT] melta_bonus

using DeclaredWeapons = CheckedVector<DeclaredWeapon, MAX_SELECTED_WEAPONS>

# Snapshot the selected slot/weapon before any attack resolution (p.16).
fun make_declared_weapon(Board board, UnitID source, Int model, Int slot) -> DeclaredWeapon:
    let result : DeclaredWeapon
    result.model = model
    result.model_identity = board[source][model].identity
    result.slot = slot
    result.weapon = board[source][model].weapons[slot]
    return result

# Explicit termination is permitted only after all target shares are resolved
# or declined (p.17); no damage stage can silently erase another target.
fun has_unresolved_attacks(DeclaredWeapons declarations) -> Bool:
    let target : UnitID
    for i in range(MAX_UNIT_COUNT):
        target = i
        if target_has_unresolved_weapons(declarations, target):
            return true
    return false

# Resolve source models by stable identity after any intervening casualties
# (pp.17/19). Unassigned fixture IDs use their original slot; normal activations
# assign identities before declaring, so compacted models cannot be retargeted.
fun declared_model_index(Board board, UnitID source, DeclaredWeapon declaration) -> Int:
    if declaration.model_identity.value >= 0:
        for i in range(board[source].models.size()):
            if board[source][i].identity == declaration.model_identity:
                return i
        return -1
    if declaration.model.get() < board[source].models.size():
        return declaration.model.get()
    return -1

# Destroyed models retained for a later trigger are not viable attack targets
# (pp.19/87). Their removal/lifetime policy remains task 10, but offering a
# group with no legal recipient would stall the current declaration pipeline.
fun has_live_attack_recipient(Unit target) -> Bool:
    for i in range(target.models.size()):
        if target[i].state == ModelState::normal and target[i].wounds_left() > 0:
            return true
    return false

# Each firing model checks its own weapon range/visibility; melee checks an
# engaged enemy model, not a range-zero distance test (p.16). Full shooting
# modes/keyword exceptions remain task 12; this is the ordinary target rule.
fun declaration_target_valid(Board board, UnitID source, DeclaredWeapon weapon, UnitID target, Bool melee) -> Bool:
    if source.get() >= board.units.size() or target.get() >= board.units.size() or board[source].empty() or !has_live_attack_recipient(board[target]):
        return false
    if board[source].owned_by_player1 == board[target].owned_by_player1:
        return false
    let model = declared_model_index(board, source, weapon)
    if model < 0:
        return false
    if board[source][model].state == ModelState::fight_on_death or board[source][model].wounds_left() <= 0:
        return false
    if melee:
        for i in range(board[target].models.size()):
            if board[source][model].is_engaged_with(board[target][i]):
                return true
        return false
    return !board.is_in_melee(board[target]) and board[target].distance(board[source][model]) <= float(weapon.weapon.range()) and model_can_see_unit(board, board[source][model], board[target])

# A targetless weapon makes no attacks (p.16); distinguish this from offering
# a selector with no legal values, which would stall native/editor play.
fun declaration_has_target(Board board, UnitID source, DeclaredWeapon weapon, Bool melee) -> Bool:
    let target : UnitID
    for i in range(board.units.size()):
        target = i
        if declaration_target_valid(board, source, weapon, target, melee):
            return true
    return false

# A partial melee share is legal only when another unselected eligible target
# can receive the remainder (p.17); otherwise require the full remaining A.
fun has_another_declaration_target(Board board, UnitID source, DeclaredWeapon weapon, Bool melee) -> Bool:
    let target : UnitID
    for i in range(board.units.size()):
        target = i
        if !weapon.targeted[i] and declaration_target_valid(board, source, weapon, target, melee):
            return true
    return false

# A selected ordinary melee weapon is unique; Extra Attacks weapons are
# additional (pp.16/80). Ranged sidearm/mode changes remain task 12.
fun weapon_selection_valid(Board board, UnitID source, Int model, Int slot, Bool melee, Bool[MAX_WEAPONS] selected, Bool main_selected) -> Bool:
    if slot < 0 or slot >= board[source][model].weapons.size() or selected[slot]:
        return false
    ref weapon = board[source][model].weapons[slot]
    if melee:
        return weapon.range() == 0 and (!main_selected or weapon.has_rule(WeaponRuleKind::extra_attacks))
    return weapon.range() > 0 and (!board[source].has_run or weapon.has_rule(WeaponRuleKind::assault))

# Models with melee weapons must select one ordinary weapon (p.16), including
# models currently unable to reach a target. No-ranged-weapon/optional shooting
# choices can end without making attacks; Extra Attacks are additional.
fun may_finish_weapon_selection(Board board, UnitID source, Int model, Bool melee, Bool main_selected) -> Bool:
    if !melee or main_selected:
        return true
    for i in range(board[source][model].weapons.size()):
        if board[source][model].weapons[i].range() == 0 and !board[source][model].weapons[i].has_rule(WeaponRuleKind::extra_attacks):
            return false
    return true

# Resolution stays on the chosen target until every weapon against it has
# been resolved (p.17). This predicate ignores finished/declined entries.
fun target_has_unresolved_weapons(DeclaredWeapons declarations, UnitID target) -> Bool:
    for i in range(declarations.size()):
        if declarations[i].targeted[target.get()] and !declarations[i].resolved[target.get()]:
            return true
    return false

# Group identity excludes weapon name/A, but includes BS/WS/S/AP/D and all
# applicable weapon rules, effective roll modifiers/rerolls, cover and target
# defenses (p.17). Profile identity alone is not an attack characteristic.
fun attacks_are_identical(Board board, AttackSequenceInfo left, AttackSequenceInfo right) -> Bool:
    if effective_attack_skill(board, left) != effective_attack_skill(board, right) or left.source.strenght() != right.source.strenght() or left.source.penetration() != right.source.penetration() or !same_damage_characteristic(left.source.damage(), right.source.damage()):
        return false
    if left.total_hit_modifier() != right.total_hit_modifier() or left.total_wound_modifier() != right.total_wound_modifier():
        return false
    if left.melta_damage_bonus != right.melta_damage_bonus or left.penetration_bonus != right.penetration_bonus or left.only_hits_on_6 != right.only_hits_on_6 or left.reroll_hits != right.reroll_hits or left.reroll1_hits != right.reroll1_hits or left.reroll_wounds != right.reroll_wounds or left.reroll1_wounds != right.reroll1_wounds:
        return false
    if left.target_toughness != right.target_toughness or left.greater_strenght_wound_protection != right.greater_strenght_wound_protection or left.fight_on_death != right.fight_on_death or left.fight_on_death_roll != right.fight_on_death_roll:
        return false
    if critical_wound_threshold(board, left) != critical_wound_threshold(board, right):
        return false
    let kind : WeaponRuleKind
    for i in range(max(kind) + 1):
        kind.value = i
        if left.has_weapon_rule(board, kind) != right.has_weapon_rule(board, kind) or left.max_weapon_parameter(board, kind) != right.max_weapon_parameter(board, kind):
            return false
    return true
