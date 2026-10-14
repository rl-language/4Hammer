import attack_dice
import movement_rules

# PISTOL and CLOSE-QUARTERS are identical (pp.80/83).
fun close_quarters_weapon(Weapon weapon) -> Bool:
    return weapon.has_rule(WeaponRuleKind::pistol) or weapon.has_rule(WeaponRuleKind::close_quarters)

# Unit eligibility is based on live bearers, not retained casualties (pp.34–35/87).
fun unit_has_ranged_rule(Unit unit, WeaponRuleKind kind) -> Bool:
    for i in range(unit.models.size()):
        if unit[i].is_alive():
            for j in range(unit[i].weapons.size()):
                if unit[i].weapons[j].range() > 0 and (model_weapon_has_rule(unit[i], j, kind) or unit.has_temporary_wepon_rule(kind)):
                    return true
    return false

# A mixed unit's Monster/Vehicle qualification is unit-wide; per-model weapon
# permission and penalties are assessed separately (pp.35/62–63).
fun monster_vehicle_model(Model model) -> Bool:
    return model.has_keyword(Keyword::monster) or model.has_keyword(Keyword::vehicle)

# Modes are selected before weapons; snap eligibility comes from its granting
# rule and is not a freely selectable Shooting-phase type (pp.34–35/57).
fun shooting_kind_valid(Board board, UnitID source, ShootingKind kind) -> Bool:
    if source.get() >= board.units.size() or !has_shooting_model(board[source]) or !board[source].can_shoot or (board[source].history.fell_back_this_turn and !board[source].history.fallback_allows_shooting) or (board[source].history.action_started and !board[source].has_keyword(Keyword::titanic)):
        return false
    let engaged = board.is_in_melee(board[source])
    let advanced = board[source].history.advanced_this_turn or board[source].has_run
    if kind == ShootingKind::normal:
        return !engaged and !advanced
    if kind == ShootingKind::assault:
        return !engaged and advanced and carrier_has_ranged_rule(board, source, WeaponRuleKind::assault)
    if kind == ShootingKind::close_quarters:
        return engaged and !advanced and (board[source].has_keyword(Keyword::monster) or board[source].has_keyword(Keyword::vehicle) or carrier_has_ranged_rule(board, source, WeaponRuleKind::pistol) or carrier_has_ranged_rule(board, source, WeaponRuleKind::close_quarters))
    if kind == ShootingKind::indirect:
        return !engaged and !advanced and carrier_has_ranged_rule(board, source, WeaponRuleKind::indirect_fire)
    return false

# Battlefield membership is represented by a nonempty live unit slot (pp.34/87).
fun has_shooting_model(Unit unit) -> Bool:
    if unit.off_battlefield or unit.history.deck_shooting_locked:
        return false
    for i in range(unit.models.size()):
        if unit[i].is_alive():
            return true
    return false

# A unit with no ranged weapon may still select normal shooting (p.88).
fun shooting_unit_valid(Board board, UnitID source) -> Bool:
    if source.get() >= board.units.size() or board[source].owned_by_player1 != board.current_player or board[source].has_shoot:
        return false
    return shooting_kind_valid(board, source, ShootingKind::normal) or shooting_kind_valid(board, source, ShootingKind::assault) or shooting_kind_valid(board, source, ShootingKind::close_quarters) or shooting_kind_valid(board, source, ShootingKind::indirect)

# Heavy is a <=3-inch movement threshold, not stationary, and applies only
# in the bearer's own Shooting phase with no setup/engagement (p.82).
fun heavy_unit_eligible(Board board, UnitID source) -> Bool:
    if !(board.timing.phase == BattlePhase::shooting) or board[source].owned_by_player1 != board.current_player or board.is_in_melee(board[source]) or board[source].history.was_set_up_this_turn:
        return false
    for i in range(board[source].models.size()):
        if board[source][i].is_alive() and (board[source][i].history.was_set_up_this_turn or board[source][i].history.distance_moved_this_turn() > 3.0):
            return false
    return true

# Indirect's improved 4+ gate needs actual stationary status this turn and
# visibility to any friendly live unit, not only to the firing bearer (p.35).
fun friendly_unit_sees_target(Board board, UnitID source, UnitID target) -> Bool:
    for i in range(board.units.size()):
        if board[i].owned_by_player1 == board[source].owned_by_player1 and unit_visible_to_unit(board, board[i], board[target]):
            return true
    return false

# Ordinary engaged targets are prohibited; the own-Shooting-phase Monster/
# Vehicle exception does not lift BLAST's prohibition (pp.35/62–63/88).
# Compatibility fixture entry retains the raw profile range; declarations
# pass their bearer/slot's effective range (p.16; appendix02.02.01).
fun ranged_target_valid(Board board, UnitID source, Model bearer, Weapon weapon, WeaponAbilitySet rules, UnitID target) -> Bool:
    return ranged_target_valid(board, source, bearer, weapon, rules, target, weapon.range())

# Effective Range participates in ordinary and replacement eligibility (p.16/04.03.03).
fun ranged_target_valid(Board board, UnitID source, Model bearer, Weapon weapon, WeaponAbilitySet rules, UnitID target, Int maximum) -> Bool:
    if target.get() >= board.units.size() or !has_shooting_model(board[target]) or board[source].owned_by_player1 == board[target].owned_by_player1 or live_distance_to_model(board[target], bearer) > float(maximum):
        return false
    let kind = board[source].shooting_kind
    let engaged = board.is_in_melee(board[target])
    let mutually_engaged = board[source].is_engaged_with(board[target])
    if engaged:
        if chosen_weapon_has_rule(board, target, rules, WeaponRuleKind::blast):
            return false
        if !(kind == ShootingKind::close_quarters and mutually_engaged) and (!(board.timing.phase == BattlePhase::shooting) or board.current_player != board[source].owned_by_player1 or (!board[target].has_keyword(Keyword::monster) and !board[target].has_keyword(Keyword::vehicle))):
            return false
    if kind == ShootingKind::assault and !chosen_weapon_has_rule(board, target, rules, WeaponRuleKind::assault):
        return false
    if kind == ShootingKind::close_quarters and !monster_vehicle_model(bearer) and !(chosen_weapon_has_rule(board, target, rules, WeaponRuleKind::pistol) or chosen_weapon_has_rule(board, target, rules, WeaponRuleKind::close_quarters)):
        return false
    if kind == ShootingKind::close_quarters and !monster_vehicle_model(bearer) and !mutually_engaged:
        return false
    if kind == ShootingKind::snap:
        if live_unit_distance(board[source], board[target]) > 24.0 or !unit_visible_to_unit(board, board[source], board[target]):
            return false
    if kind == ShootingKind::indirect and chosen_weapon_has_rule(board, target, rules, WeaponRuleKind::indirect_fire):
        # Lone Operative restricts indirect targeting by each bearer (p.83).
        let lone_range = 12
        if board[target].lone_operative_range.value > 0:
            lone_range = characteristic_limit(ModifiedCharacteristic::detection_range, board[target].lone_operative_range.value)
        return !orks_lone_operative(board, board[target]) or live_distance_to_model(board[target], bearer) <= float(lone_range)
    return model_can_see_unit(board, bearer, board[target])

# Selecting Remain Stationary is distinct from a zero-distance normal move;
# any other recorded movement or setup this turn prevents the indirect bonus (p.35).
fun stationary_this_turn(Unit unit) -> Bool:
    if unit.history.made_move_this_turn or unit.history.was_set_up_this_turn or unit.history.advanced_this_turn or unit.history.fell_back_this_turn:
        return false
    for i in range(unit.models.size()):
        if unit[i].is_alive() and (unit[i].history.distance_moved_this_turn() > 0.0 or unit[i].history.was_set_up_this_turn):
            return false
    return true
