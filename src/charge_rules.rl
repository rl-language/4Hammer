import movement_rules

# One enum chooses Heroic's pre-roll mode without ambiguous editor selectors
# (p.57). Ordinary charges use the same movement kernel (pp.36–37).
enum ChargeKind:
    ordinary
    leap_to_defend
    into_the_fray

    fun equal(ChargeKind other) -> Bool:
        return self.value == other.value

using ChargeDistance = LinearlyDistributedInt<0, 13>

# Declaration and successful movement are different events: a failed attempt
# consumes this phase's declaration but grants neither Lance nor Fights First
# (pp.36–37/82). This also excludes offboard/retained casualties and engagement.
fun charge_source_valid(Board board, UnitID source, Bool player) -> Bool:
    if source.get() < board.units.size() and unit_orks_effect(board, board[source], OrksEffectKind::no_charge) > 0:
        return false
    if source.get() >= board.units.size():
        return false
    ref unit = board[source]
    # Orks Waaagh! waives only this selected Advance; the saved permission
    # preserves all other restrictions (Orks faction Army Rules / Waaagh!).
    if unit.off_battlefield or unit.owned_by_player1 != player or unit.has_keyword(Keyword::aircraft) or !has_live_model(unit) or !unit.can_charge or board.is_in_melee(unit) or ((unit.has_run or unit.history.advanced_this_turn) and !unit.history.advance_allows_charge) or (unit.history.fell_back_this_turn and !unit.history.fallback_allows_charge) or unit.history.action_started or unit.history.ingress_locked or unit.history.declared_charge_phase == board.phase_serial.value + 1:
        return false
    for i in range(board.units.size()):
        if board[i].owned_by_player1 != player and has_live_model(board[i]) and live_unit_distance(unit, board[i]) <= 12.0:
            return true
    return false

# Post-roll targets must be within the full maximum distance, not merely
# reachable engagement range (p.37). Heroic modes add their own limits (p.57).
fun charge_target_valid(Board board, UnitID source, UnitID target, Int maximum, ChargeKind kind) -> Bool:
    if source.get() >= board.units.size() or target.get() >= board.units.size() or !has_live_model(board[source]) or !has_live_model(board[target]) or board[source].owned_by_player1 == board[target].owned_by_player1:
        return false
    # Only FLYING units may declare AIRCRAFT as a target (p.74).
    if board[target].has_keyword(Keyword::aircraft) and !board[source].has_keyword(Keyword::fly):
        return false
    let distance = live_unit_distance(board[source], board[target])
    if distance > 12.0 or distance > float(maximum):
        return false
    if kind == ChargeKind::leap_to_defend:
        return board[target].history.charge_move_phase == board.phase_serial.value + 1
    if kind == ChargeKind::into_the_fray:
        return distance <= 6.0
    return true

# Re-roll first, then ordered modifiers and the appendix's 12 cap, followed
# by Into the Fray's 6 cap (p.57). Flight reduces the move, not the dice roll
# (p.71); HOVER removes that reduction for the whole unit (p.82).
fun charge_distance(Unit unit, Int roll, ChargeKind kind, Bool skies) -> Int:
    return charge_distance_with_sources(unit, roll, kind, skies, 0)

# Banner+1 and distinct Stampede+1 combine before ordered modifiers and caps.
# Source: Orks/Bannernob; Beastboss-on-Squigosaur Thundering Stampede (Aura).
fun charge_distance(Board board, Unit unit, Int roll, ChargeKind kind, Bool skies) -> Int:
    return charge_distance_with_sources(unit, roll, kind, skies, orks_stampede_charge_bonus(board, unit))

# The banner follows live combined membership; an aura is queried on the
# battlefield only. Both join addition before division/rounding (02.02.01).
fun charge_distance_with_sources(Unit unit, Int roll, ChargeKind kind, Bool skies, Int aura_bonus) -> Int:
    let addition = aura_bonus + int(unit.has_ability(AbilityKind::waaagh_banner))
    let maximum = modified_dice_result(roll, unit.phase_modifiers.charge_roll, false, true, addition)
    if kind == ChargeKind::into_the_fray:
        maximum = min(6, maximum)
    if skies and !unit.has_ability(AbilityKind::hover):
        maximum = max(0, maximum - 2)
    return maximum

# Super-heavy Walker permits enemy traversal only in Normal/Advance/Fall Back
# moves (p.85), never in charges. Only chosen flying bearers may cross enemy
# models/terrain during a charge (p.71).
fun charge_policy(Model model, Bool skies) -> MovementGeometryPolicy:
    let policy : MovementGeometryPolicy
    if skies and model.has_keyword(Keyword::fly):
        policy.traverse_enemies = true
        policy.traverse_terrain = true
        policy.free_vertical_movement = true
    return policy

# Charge distance replaces M for every model. Sweep all waypoints using the
# existing full-base collision checks; only flying bearers get traversal and
# horizontal-only costs when the unit takes to the skies (pp.12/37/71).
fun charge_waypoint_valid(Board board, Unit original, ModelPath path, BoardPosition position, Int maximum, Bool skies) -> Bool:
    if path.model.get() >= original.models.size() or !original[path.model].is_alive() or path.points.size() >= 16:
        return false
    ref model = original[path.model]
    let start = model.geometry_position()
    if !path.points.empty():
        start = path.points.back().as_geometry_point()
    let finish = geometry_point(position.x.value * MICROMETRES_PER_INCH, position.y.value * MICROMETRES_PER_INCH, start.z.value)
    let distance = segment_length(start, finish)
    if skies and model.has_keyword(Keyword::fly):
        distance = horizontal_length(start, finish)
    let policy = charge_policy(model, skies)
    # Nobz/Get Out da Way! affects this unit's CHARGE traversal only. A
    # traversable target cannot waive final overlap/engagement restrictions.
    # https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
    if original.has_ability(AbilityKind::get_out_da_way) and !policy.traverse_enemies:
        policy.traverse_enemies = true
        policy.exclude_monster_vehicle = true
    return path_distance(model, path, skies) + distance <= float(maximum * MICROMETRES_PER_INCH) and model_segment_valid(board, original, model, start, finish, policy)

# All targets must be engaged and every unselected enemy must be unengaged
# after moving; intermediate engagement is permitted (p.37). Validate the
# complete coherent formation and every footprint before any commit (p.12).
fun charge_placement_valid(Board board, Unit candidate, UnitID source, Bool[MAX_UNIT_COUNT] targets) -> Bool:
    if !unit_placement_valid(board, candidate, source.get(), false):
        return false
    let selected = false
    for i in range(board.units.size()):
        if targets[i]:
            selected = true
            if !has_live_model(board[i]) or board[i].owned_by_player1 == candidate.owned_by_player1 or !candidate.is_engaged_with(board[i]):
                return false
        else if board[i].owned_by_player1 != candidate.owned_by_player1 and candidate.is_engaged_with(board[i]):
            return false
    return selected

# p.37: each bearer must become closer to at least one selected target, not
# necessarily the target closest to the unit's first model.
fun charge_model_closer(Board board, Model start, Model finish, Bool[MAX_UNIT_COUNT] targets) -> Bool:
    for i in range(board.units.size()):
        if targets[i]:
            let before = 1000000000.0
            let after = 1000000000.0
            for j in range(board[i].models.size()):
                if board[i][j].is_alive():
                    if start.distance(board[i][j]) < before:
                        before = start.distance(board[i][j])
                    if finish.distance(board[i][j]) < after:
                        after = finish.distance(board[i][j])
            if after < before:
                return true
    return false

# Nested endpoint obligations are categorical: within 1 inch if possible,
# otherwise engaged if possible (p.37). Ordinary range is 3D; engagement is
# separately 2 inches horizontal/5 vertical (p.14).
fun charge_model_goal(Board board, Model model, Bool[MAX_UNIT_COUNT] targets) -> Int:
    let goal = 0
    for i in range(board.units.size()):
        if targets[i]:
            for j in range(board[i].models.size()):
                if board[i][j].is_alive():
                    if model.distance(board[i][j]) <= 1.0:
                        return 2
                    if model.is_engaged_with(board[i][j]):
                        goal = 1
    return goal

# Test a replacement endpoint with every other chosen model fixed. The
# finite quad representation follows the task-11 surge approach; this is not
# a simultaneous rearrangement optimizer (pp.12/37, preserved-grid policy).
fun charge_endpoint_better(Board board, Unit original, Unit candidate, UnitID source, ModelID model, BoardPosition position, Bool[MAX_UNIT_COUNT] targets, Int goal) -> Bool:
    candidate[model].position = position
    return charge_model_goal(board, candidate[model], targets) > goal and charge_model_closer(board, original[model], candidate[model], targets) and charge_placement_valid(board, candidate, source, targets)

# Search reachable whole-grid endpoints, including routes around enemy bases.
# Float shortest-path arrays are calculation locals, never persisted game
# data. Try direct reachable endpoints first; Dijkstra handles detours only
# when necessary (pp.12/37). Other final bases remain fixed as above.
fun charge_better_endpoint_exists(Board board, Unit original, Unit candidate, UnitID source, ModelID model, Bool[MAX_UNIT_COUNT] targets, Int maximum, Bool skies, Int goal) -> Bool:
    let original_position = candidate[model].position
    let result = charge_endpoint_search(board, original, candidate, source, model, targets, maximum, skies, goal)
    candidate[model].position = original_position
    return result

# Borrowed staging avoids owning-copy cleanup in the graph's early returns;
# caller restores its endpoint before continuing (pp.12/37).
fun charge_endpoint_search(Board board, Unit original, Unit candidate, UnitID source, ModelID model, Bool[MAX_UNIT_COUNT] targets, Int maximum, Bool skies, Int goal) -> Bool:
    let distances : Float[1320]
    let possible : Bool[1320]
    let any_possible = false
    let visited : Bool[1320]
    let moving = original[model].geometry_position()
    let policy = charge_policy(original[model], skies)
    let limit = float(maximum * MICROMETRES_PER_INCH)
    for i in range(1320):
        distances[i] = 1000000000.0
        let position = make_board_position(i / BOARD_HEIGHT, i % BOARD_HEIGHT)
        let endpoint = geometry_point(position.x.value * MICROMETRES_PER_INCH, position.y.value * MICROMETRES_PER_INCH, moving.z.value)
        let distance = horizontal_length(moving, endpoint)
        if distance <= limit:
            possible[i] = charge_endpoint_better(board, original, candidate, source, model, position, targets, goal)
            any_possible = any_possible or possible[i]
            if model_segment_valid(board, original, original[model], moving, endpoint, policy):
                distances[i] = distance
                if possible[i]:
                    return true
    if !any_possible:
        return false
    let origin = original[model].position.x.value * BOARD_HEIGHT + original[model].position.y.value
    distances[origin] = 0.0
    for iteration in range(1320):
        let next = -1
        let nearest = 1000000000.0
        for i in range(1320):
            if !visited[i] and distances[i] <= limit and distances[i] < nearest:
                next = i
                nearest = distances[i]
        if next < 0:
            break
        visited[next] = true
        let position = make_board_position(next / BOARD_HEIGHT, next % BOARD_HEIGHT)
        if possible[next]:
            return true
        let start = geometry_point(position.x.value * MICROMETRES_PER_INCH, position.y.value * MICROMETRES_PER_INCH, moving.z.value)
        for i in range(1320):
            if !visited[i]:
                let finish = geometry_point((i / BOARD_HEIGHT) * MICROMETRES_PER_INCH, (i % BOARD_HEIGHT) * MICROMETRES_PER_INCH, moving.z.value)
                let distance = nearest + horizontal_length(start, finish)
                if distance <= limit and distance < distances[i] and model_segment_valid(board, original, original[model], start, finish, policy):
                    distances[i] = distance
    return false

# Final validation first checks cheap obligations; expensive reachability is
# needed only for models that did not already reach the strongest goal (p.37).
fun charge_finish_valid(Board board, Unit original, Unit candidate, UnitID source, Bool[MAX_UNIT_COUNT] targets, Int maximum, Bool skies) -> Bool:
    if !charge_placement_valid(board, candidate, source, targets):
        return false
    for i in range(candidate.models.size()):
        if candidate[i].is_alive():
            if !charge_model_closer(board, original[i], candidate[i], targets):
                return false
            let goal = charge_model_goal(board, candidate[i], targets)
            let model : ModelID
            model = i
            if goal < 2 and charge_better_endpoint_exists(board, original, candidate, source, model, targets, maximum, skies, goal):
                return false
    return true

# Rigid formation movement remains an optional editor convenience, checked
# against exactly the same per-model costs and final constraints (pp.12/37).
fun charge_translate_candidate(Board board, Unit original, Unit candidate, UnitID source, BoardPosition position, Bool[MAX_UNIT_COUNT] targets, Int maximum, Bool skies) -> Bool:
    let dx = position.x.value - original[0].position.x.value
    let dy = position.y.value - original[0].position.y.value
    for i in range(original.models.size()):
        if original[i].is_alive():
            let x = original[i].position.x.value + dx
            let y = original[i].position.y.value + dy
            if x < 0 or x >= BOARD_WIDTH or y < 0 or y >= BOARD_HEIGHT:
                return false
            let endpoint = make_board_position(x, y)
            let path : ModelPath
            path.model = i
            if !charge_waypoint_valid(board, original, path, endpoint, maximum, skies):
                return false
            candidate[i].position = endpoint
            record_geometry_movement(candidate[i].history, original[i].geometry_position(), candidate[i].geometry_position(), skies and original[i].has_keyword(Keyword::fly))
    return charge_finish_valid(board, original, candidate, source, targets, maximum, skies)

# Single-exit owning staging keeps repeated legality enumeration leak-free;
# invalid charge proposals never change battlefield positions/history (p.37).
fun charge_translate_valid(Board board, Unit original, UnitID source, BoardPosition position, Bool[MAX_UNIT_COUNT] targets, Int maximum, Bool skies) -> Bool:
    let candidate = original
    let valid = charge_translate_candidate(board, original, candidate, source, position, targets, maximum, skies)
    return valid

# Only a completed charge move grants Fights First and Lance. Phase stamps
# also distinguish successful charges this phase for Leap to Defend (pp.37/57/82).
fun record_charge_move(Board board, UnitID source):
    # p.58: any charge move interrupts a pending action, even out of phase.
    board[source].interrupt_actions()
    board[source].has_charged = true
    board[source].has_moved = true
    board[source].history.made_move_this_turn = true
    board[source].history.last_move_phase = board.phase_serial.value + 1
    board[source].history.charge_move_phase = board.phase_serial.value + 1
