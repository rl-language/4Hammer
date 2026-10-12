import shooting_rules

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
    WeaponRule hunter_condition
    WeaponAbilitySet selected_rules
    WeaponAbilitySet current_target_rules
    Bool made_attacks
    CombatCounter[MAX_UNIT_COUNT] target_model_counts
    Bool[MAX_UNIT_COUNT] half_range
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
    result.hunter_condition = board[source][model].hunter_profile_conditions[slot]
    result.selected_rules = model_weapon_rules(board, source, model, slot)
    result.current_target_rules = result.selected_rules
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
    return declaration_target_valid(board, source, weapon, target, melee, false)

# Replacement targets use the supplied appendix 04.03.03; Snap Shooting still
# selects one shared visible unit for the remaining weapons (p.57).
fun declaration_target_valid(Board board, UnitID source, DeclaredWeapon weapon, UnitID target, Bool melee, Bool allow_snap_replacement) -> Bool:
    if source.get() >= board.units.size() or target.get() >= board.units.size() or board[source].empty() or !has_live_attack_recipient(board[target]):
        return false
    if board[source].owned_by_player1 == board[target].owned_by_player1:
        return false
    # Supplied appendix 04.01.03: Hunter restrictions also apply to replacement targets.
    if !board[target].weapon_rule_applies(weapon.hunter_condition):
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
    if board[source].shooting_kind == ShootingKind::snap and !allow_snap_replacement:
        if target.get() != board[source].snap_target.get():
            return false
    return ranged_target_valid(board, source, board[source][model], weapon.weapon, weapon.selected_rules, target)

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
    # Appendix 04.01.03: choose one profile per physical weapon per model.
    let group = board[source][model].weapon_profile_groups[slot].value
    for i in range(board[source][model].weapons.size()):
        if group != 0 and board[source][model].weapon_profile_groups[i].value == group and selected[i]:
            return false
    ref weapon = board[source][model].weapons[slot]
    if board[source][model].used_once_per_battle_weapon[slot]:
        return false
    if melee:
        return weapon.range() == 0 and (!main_selected or model_weapon_has_rule(board[source][model], slot, WeaponRuleKind::extra_attacks))
    if weapon.range() <= 0 or (model_weapon_has_rule(board[source][model], slot, WeaponRuleKind::one_shot) and board[source][model].used_once_per_battle_weapon[slot]):
        return false
    if board[source].shooting_kind == ShootingKind::assault or (board[source].shooting_kind == ShootingKind::normal and board[source].has_run):
        if !available_weapon_has_rule(board, source, model, slot, WeaponRuleKind::assault):
            return false
    if board[source].shooting_kind == ShootingKind::close_quarters and !monster_vehicle_model(board[source][model]) and !(model_weapon_has_rule(board[source][model], slot, WeaponRuleKind::pistol) or model_weapon_has_rule(board[source][model], slot, WeaponRuleKind::close_quarters)):
        return false
    if !monster_vehicle_model(board[source][model]) and !(board[source].shooting_kind == ShootingKind::close_quarters):
        for i in range(MAX_WEAPONS):
            if selected[i] and model_weapon_close_quarters(board[source][model], i) != model_weapon_close_quarters(board[source][model], slot):
                return false
    return true

# Models with melee weapons must select one ordinary weapon (p.16), including
# models currently unable to reach a target. No-ranged-weapon/optional shooting
# choices can end without making attacks; Extra Attacks are additional.
fun may_finish_weapon_selection(Board board, UnitID source, Int model, Bool melee, Bool main_selected) -> Bool:
    if !melee or main_selected:
        return true
    for i in range(board[source][model].weapons.size()):
        if board[source][model].weapons[i].range() == 0 and !model_weapon_has_rule(board[source][model], i, WeaponRuleKind::extra_attacks):
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
    if !(left.shooting_kind == right.shooting_kind) or left.indirect_stationary_visible != right.indirect_stationary_visible or left.heavy_bonus != right.heavy_bonus or left.engaged_hit_penalties != right.engaged_hit_penalties:
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

# Selected weapon rules retain keyword restrictions until the target is known (p.78).
fun declared_weapon_has_kind(DeclaredWeapon declaration, WeaponRuleKind kind) -> Bool:
    for i in range(declaration.selected_rules.size()):
        if declaration.selected_rules[i].kind == kind:
            return true
    return false

# Declaration-time count ignores corpses kept for triggers (pp.79/87).
fun live_model_count(Unit unit) -> Int:
    let count = 0
    for i in range(unit.models.size()):
        count = count + int(unit[i].is_alive())
    return count

# Freeze bonuses when each (including replacement) target is selected; the
# supplied retarget rule does not defer this snapshot until casualties (pp.79/83–84).
fun snapshot_weapon_target(Board board, UnitID source, DeclaredWeapon weapon, UnitID target):
    weapon.target_model_counts[target.get()] = live_model_count(board[target])
    weapon.half_range[target.get()] = live_distance_to_model(board[target], board[source][declared_model_index(board, source, weapon)]) <= float(weapon.weapon.range()) / 2.0
    weapon.melta_bonus[target.get()] = 0
    if weapon.half_range[target.get()] and chosen_weapon_has_rule(board, target, weapon.selected_rules, WeaponRuleKind::melta):
        weapon.melta_bonus[target.get()] = chosen_weapon_parameter(board, target, weapon.selected_rules, WeaponRuleKind::melta)

# Every Extra Attacks weapon is mandatory in addition to the ordinary melee
# choice (pp.16/81); the shared declaration engine also serves fighting (task 14).
fun may_finish_all_weapon_selection(Board board, UnitID source, Int model, Bool melee, Bool[MAX_WEAPONS] selected, Bool main_selected) -> Bool:
    if !may_finish_weapon_selection(board, source, model, melee, main_selected):
        return false
    if melee:
        for i in range(board[source][model].weapons.size()):
            if board[source][model].weapons[i].range() == 0 and model_weapon_has_rule(board[source][model], i, WeaponRuleKind::extra_attacks) and !selected[i]:
                return false
    return true

# A replacement selector must have a viable value; permit one newly selected
# Snap target per revalidation boundary, then reuse it for all weapons (p.57;
# supplied Target No Longer Eligible or Viable 04.03.03).
fun declaration_has_replacement_target(Board board, UnitID source, DeclaredWeapon weapon, Bool melee, Bool allow_snap_replacement) -> Bool:
    let target : UnitID
    for i in range(board.units.size()):
        target = i
        if declaration_target_valid(board, source, weapon, target, melee, allow_snap_replacement):
            return true
    return false
