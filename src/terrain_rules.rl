import weapon_abilities
import modifiers

# Cover/Hidden area eligibility belongs to each model, not inherited keywords
# from its unit (pp.50/67/87). Other models may still gain intervening cover.
fun terrain_cover_model_kind(Model model) -> Bool:
    return model.has_keyword(Keyword::infantry) or model.has_keyword(Keyword::beasts) or model.has_keyword(Keyword::swarm)

# Hidden requires a dense area and no ranged attacks in this or the previous
# turn (p.50). Negative history means never fired, not an actual previous turn.
fun model_is_hidden(Board board, Unit unit, Model model) -> Bool:
    if unit_orks_effect(board, unit, OrksEffectKind::burna_mark) > 0:
        return false
    if !terrain_cover_model_kind(model):
        return false
    if unit.history.last_ranged_attack_turn > 0 and unit.history.last_ranged_attack_turn >= board.turn_serial.value:
        return false
    for i in range(board.terrain_areas.size()):
        if board.terrain_areas[i].dense and board.model_in_terrain_area(model, i):
            return true
    return false

# The user explicitly assumes physical visibility instead of body/feature LOS.
# Hidden still restricts enemy detection to 15in by default (p.50); supplied
# rules may call the override with their actual range, without invented data.
fun model_visible_to_model(Board board, Model observer, Unit target_unit, Model target, Int detection_range) -> Bool:
    # Appendix01.02.04 forbids foreign visibility to/from either offboard bank.
    if observer.identity.value > 0 and target.identity == observer.identity:
        return true
    if model_is_offboard(board, observer) or model_is_offboard(board, target):
        return false
    # User-supplied appendix 02.02.01 clamps modified detection to 9–30in.
    let lone_range = 12
    if target_unit.lone_operative_range.value > 0:
        lone_range = characteristic_limit(ModifiedCharacteristic::detection_range, target_unit.lone_operative_range.value)
    return (!orks_lone_operative(board, target_unit) or observer.distance(target) <= float(lone_range)) and detection_range >= 0 and (!model_is_hidden(board, target_unit, target) or observer.distance(target) <= float(characteristic_limit(ModifiedCharacteristic::detection_range, detection_range + 3 * unit_orks_effect(board, target_unit, OrksEffectKind::found_detection) - 3 * int(unit_has_orks_enhancement(target_unit, OrksEnhancement::extra_sneaky)))))

# Printed default detection is inclusive 15in; this is not model-silhouette LOS.
fun model_visible_to_model(Board board, Model observer, Unit target_unit, Model target) -> Bool:
    return model_visible_to_model(board, observer, target_unit, target, 15)

# A unit is visible to a model if any member is visible (p.25). The body's
# geometric occlusion is replaced by the user-approved area-only abstraction.
fun model_can_see_unit(Board board, Model observer, Unit target) -> Bool:
    for i in range(target.models.size()):
        if observer.is_alive() and target[i].is_alive() and model_visible_to_model(board, observer, target, target[i]):
            return true
    return false

# Unit-level selector eligibility must not invent visibility for an empty unit
# (pp.16/25). Weapon declarations still check each firing model (task 9/12).
fun unit_visible_to_unit(Board board, Unit source, Unit target) -> Bool:
    if source.identity.value > 0 and source.identity == target.identity:
        return !source.empty()
    for i in range(source.models.size()):
        if model_can_see_unit(board, source[i], target):
            return true
    return false

# User-approved approximation: a centre sight segment crossing a rectangular
# terrain area gives partial visibility, including tangent/endpoint crossings.
# It never creates complete physical occlusion; exact p.50 Solid/Obscuring and
# physical feature/silhouette geometry are explicitly deferred by the user.
fun sight_crosses_terrain_area(Model observer, Model target, TerrainArea area) -> Bool:
    let ax = float(observer.position.x.value * MICROMETRES_PER_INCH)
    let ay = float(observer.position.y.value * MICROMETRES_PER_INCH)
    let bx = float(target.position.x.value * MICROMETRES_PER_INCH)
    let by = float(target.position.y.value * MICROMETRES_PER_INCH)
    if point_area_distance_squared(ax, ay, area) == 0.0 or point_area_distance_squared(bx, by, area) == 0.0:
        return true
    let left = float((area.lower.x.value * MICROMETRES_PER_INCH))
    let right = float((area.upper.x.value * MICROMETRES_PER_INCH))
    let bottom = float((area.lower.y.value * MICROMETRES_PER_INCH))
    let top = float((area.upper.y.value * MICROMETRES_PER_INCH))
    return segments_intersect(ax, ay, bx, by, left, bottom, right, bottom) or segments_intersect(ax, ay, bx, by, right, bottom, right, top) or segments_intersect(ax, ay, bx, by, right, top, left, top) or segments_intersect(ax, ay, bx, by, left, top, left, bottom)

# Intervening areas confer partial obscuration under the user's approximation,
# never blocked physical visibility. Hiding is checked independently (p.50).
fun model_partially_obscured(Board board, Model observer, Model target) -> Bool:
    for i in range(board.terrain_areas.size()):
        if sight_crosses_terrain_area(observer, target, board.terrain_areas[i]):
            return true
    return orks_ramshackle_obscures(board, observer, target)

# Every target model needs at least one cover condition (p.50), possibly a
# different condition per model. Other keywords cannot borrow Infantry cover.
fun unit_has_benefit_of_cover(Board board, Model observer, Unit target) -> Bool:
    if target.empty():
        return false
    if orks_wobbled_observer(board, observer):
        return true
    for i in range(target.models.size()):
        let covered = model_partially_obscured(board, observer, target[i])
        if terrain_cover_model_kind(target[i]):
            for j in range(board.terrain_areas.size()):
                covered = covered or board.model_in_terrain_area(target[i], j)
        if !covered:
            return false
    return true

# Ignores Cover is a presence-only ability (p.82), with no numeric parameter.
# Legacy parameter lookups cannot detect parameterless weapon rules. Check
# intrinsic, unit-granted and attack-granted rules without inventing a value.
fun attack_ignores_cover(Board board, AttackSequenceInfo info) -> Bool:
    return info.has_weapon_rule(board, WeaponRuleKind::ignore_cover)

# Cover worsens ranged BS by one (p.50), not saves or hit-roll modifiers.
# Torrent/no-hit-roll and melee skill remain unchanged; Ignores Cover cancels
# cover (p.82). Other supplied cover grants may set target_has_cover directly.
fun effective_attack_skill(Board board, AttackSequenceInfo info) -> Int:
    let extra = 0
    if info.source.range() > 0 and info.plunging_fire:
        extra = extra - 1
    if info.source.range() > 0 and info.target_has_cover and !attack_ignores_cover(board, info):
        extra = extra + 1
    let kind = ModifiedCharacteristic::weapon_skill
    if info.source.range() > 0:
        kind = ModifiedCharacteristic::ballistic_skill
    return modified_characteristic(info.source.skill(), kind, info.skill_modifiers, info.source.skill() == 0, extra)

# A natural 1 fails and a natural 6 hits regardless of changed BS/modifiers
# (p.18). This matters when cover worsens a 6+ BS beyond six; broader hit and
# critical/declaration logic remains task 9.
fun attack_hit_roll_succeeds(Dice roll, Int modifier, Int skill) -> Bool:
    if roll == 1:
        return false
    if roll == 6:
        return true
    return roll.value + modifier >= skill

# Plunging Fire needs a visible target with at least one ground-level model,
# and either existing supported elevation >=3in or a TOWERING bearer within
# 12in (22.05 p.73). No new terrain features/body geometry are introduced.
# Aircraft units on either side exclude the effect entirely (23.03 p.74).
fun plunging_fire_applies(Board board, UnitID source, Int model, UnitID target, Bool ranged) -> Bool:
    if !ranged or source.get() >= board.units.size() or target.get() >= board.units.size() or model < 0 or model >= board[source].models.size() or board[source].has_keyword(Keyword::aircraft) or board[target].has_keyword(Keyword::aircraft):
        return false
    if !model_can_see_unit(board, board[source][model], board[target]):
        return false
    let grounded = false
    for ground_index in range(board[target].models.size()):
        grounded = grounded or (board[target][ground_index].is_alive() and board[target][ground_index].geometry.elevation.value == 0)
    return grounded and (board[source][model].geometry.elevation.value >= 3 or (board[source][model].has_keyword(Keyword::towering) and board[target].distance(board[source][model]) <= 12.0))

# Offboard membership is identity-based even when a fixture has not marked
# its copied models. No battlefield visibility can leak from stale positions
# in reserves/passengers (appendix01.02.04; core pp.64/68).
fun model_is_offboard(Board board, Model model) -> Bool:
    if model.off_battlefield:
        return true
    let offboard = false
    if model.identity.value > 0:
        for reserve_unit in range(board.reserve_units.size()):
            offboard = offboard or board.reserve_units[reserve_unit].find_model(model.identity) >= 0
        for embarked_unit in range(board.embarked_units.size()):
            offboard = offboard or board.embarked_units[embarked_unit].find_model(model.identity) >= 0
    return offboard
