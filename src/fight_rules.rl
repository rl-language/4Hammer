import charge_rules

# Phase-wide movement and fight types have separate finite choices (pp.38–42).
enum MeleeMoveKind:
    pile_in
    ongoing
    engaging
    objective

    fun equal(MeleeMoveKind other) -> Bool:
        return self.value == other.value

enum FightKind:
    normal
    overrun

    fun equal(FightKind other) -> Bool:
        return self.value == other.value

# The supplied Fight on Death appendix authorises retained models to attack
# with their own unit, not as immediate retaliations. They are not live targets.
fun fight_model_present(Model model) -> Bool:
    return model.is_alive() or model.state == ModelState::fight_on_death

# Eligibility includes retained fighters' current engagement, but never
# engagement solely with a destroyed target (p.40; supplied Fight on Death).
fun fight_engaged(Board board, Unit unit) -> Bool:
    for i in range(unit.models.size()):
        if fight_model_present(unit[i]):
            for u in range(board.units.size()):
                if board[u].owned_by_player1 != unit.owned_by_player1:
                    for j in range(board[u].models.size()):
                        if board[u][j].is_alive() and unit[i].is_engaged_with(board[u][j]):
                            return true
    return false

# Fights First requires every participating model to have it, or the unit
# to have completed a charge this turn (pp.37/40/81). Retained fighters keep
# the ability for their explicitly authorised unit attack.
fun fight_first_unit(Unit unit) -> Bool:
    if unit.has_charged or unit.phase_modifiers.counteroffensive:
        return true
    let present = false
    for i in range(unit.models.size()):
        if fight_model_present(unit[i]):
            present = true
            let psychic_first = false
            for effect in range(unit[i].orks_effects.size()):
                psychic_first = psychic_first or unit[i].orks_effects[effect].kind.value == OrksEffectKind::fights_first.value
            if !unit[i].has_ability(AbilityKind::fight_first) and !psychic_first:
                return false
    return present

# Fight-step eligibility is dynamic, with a snapshot of start engagement
# and explicit consolidation responses (pp.40/42). Selecting consumes the
# phase's fight even if no attacks remain after optional Overrun movement.
fun fight_unit_eligible(Board board, UnitID source) -> Bool:
    if source.get() >= board.units.size() or board[source].off_battlefield or board[source].has_fought:
        return false
    let present = false
    for i in range(board[source].models.size()):
        present = present or fight_model_present(board[source][i])
    return present and (fight_engaged(board, board[source]) or board[source].has_charged or board[source].history.engaged_fight_start_phase == board.phase_serial.value + 1 or board[source].history.consolidation_fight_pending == board.phase_serial.value + 1)

# Record all newly eligible units, not just the next chosen unit: eligibility
# at any moment authorises consolidation later in the phase (pp.40/42).
fun refresh_fight_eligibility(Board board):
    for i in range(board.units.size()):
        let source : UnitID
        source = i
        if fight_unit_eligible(board, source):
            board[source].history.fight_eligible_phase = board.phase_serial.value + 1

# Snapshot exactly after the phase-wide Pile In step (p.40), not before it.
fun begin_fight_step(Board board):
    for i in range(board.units.size()):
        board[i].history.engaged_fight_start_phase = 0
        if fight_engaged(board, board[i]):
            board[i].history.engaged_fight_start_phase = board.phase_serial.value + 1
    refresh_fight_eligibility(board)

# Players cannot voluntarily pass while they have an eligible unit of the
# required priority; missing choices transfer to the other player (p.40).
fun player_can_fight(Board board, Bool player, Bool first) -> Bool:
    for i in range(board.units.size()):
        let source : UnitID
        source = i
        if board[i].owned_by_player1 == player and fight_unit_eligible(board, source) and (!first or fight_first_unit(board[i])):
            return true
    return false

# Overrun is available while unengaged, or when engagement arose after the
# Fight-step snapshot. Normal fights require current engagement (p.40).
fun fight_kind_valid(Board board, UnitID source, FightKind kind) -> Bool:
    if source.get() >= board.units.size():
        return false
    let engaged = fight_engaged(board, board[source])
    if kind == FightKind::normal:
        return engaged
    return !engaged or board[source].history.engaged_fight_start_phase != board.phase_serial.value + 1

# Dead retained bases do not move. Non-FLYING units ignore AIRCRAFT while
# choosing pile-in/consolidation enemies and closest targets (pp.38/42/74).
fun melee_enemy_valid(Board board, Unit original, Int target) -> Bool:
    return target >= 0 and target < board.units.size() and board[target].owned_by_player1 != original.owned_by_player1 and has_live_model(board[target]) and (!board[target].has_keyword(Keyword::aircraft) or original.has_keyword(Keyword::fly))

# Optional phase-wide movement is at most once per step. Overrun provides an
# additional Pile In regardless of the earlier pile-in stamp (pp.38/40/42).
fun melee_move_eligible(Board board, UnitID source, Bool consolidate, Bool overrun) -> Bool:
    if source.get() >= board.units.size() or !has_live_model(board[source]):
        return false
    if consolidate:
        return board[source].history.consolidation_phase != board.phase_serial.value + 1 and board[source].history.fight_eligible_phase == board.phase_serial.value + 1
    return (overrun or board[source].history.pile_in_phase != board.phase_serial.value + 1) and (overrun or board.is_in_melee(board[source]) or board[source].has_charged)

# Pile In and ongoing consolidation select every currently engaged enemy;
# unengaged Pile In/engaging consolidation choose one or more within 5/3 (pp.38/42).
fun melee_target_valid(Board board, Unit original, UnitID target, MeleeMoveKind kind) -> Bool:
    if !melee_enemy_valid(board, original, target.get()):
        return false
    if kind == MeleeMoveKind::pile_in:
        return live_unit_distance(original, board[target]) <= 5.0
    return kind == MeleeMoveKind::engaging and live_unit_distance(original, board[target]) <= 3.0

# Objective distance uses the same circular marker/terrain-area definition
# as objective range, not unit anchors (pp.42/52/88). Floats are local results.
fun melee_objective_distance(Board board, Model model, Int objective) -> Float:
    let definition = board.objective_range_definition(objective)
    let point = model.geometry_position()
    if definition.terrain_objective:
        if definition.area_id.value >= board.terrain_areas.size():
            return 1000000000.0
        return movement_float_max(0.0, sqrt(point_area_distance_squared(float(point.x.value), float(point.y.value), board.terrain_areas[definition.area_id.value])) - model.base_radius_micrometres()) / float(MICROMETRES_PER_INCH)
    let dx = float((model.position.x.value - definition.position.x.value) * MICROMETRES_PER_INCH)
    let dy = float((model.position.y.value - definition.position.y.value) * MICROMETRES_PER_INCH)
    let horizontal = movement_float_max(0.0, sqrt(dx * dx + dy * dy) - model.base_radius_micrometres() - 20000.0)
    let vertical = float(point.z.value)
    return sqrt(horizontal * horizontal + vertical * vertical) / float(MICROMETRES_PER_INCH)

# Objective consolidation is allowed only after mandatory enemy modes are
# excluded and the chosen objective is within 3 inches of a live base (p.42).
fun melee_objective_valid(Board board, Unit original, Int objective) -> Bool:
    if objective < 0 or objective >= 4:
        return false
    for i in range(original.models.size()):
        if original[i].is_alive() and melee_objective_distance(board, original[i], objective) <= 3.0:
            return true
    return false

# Engaged -> ongoing; otherwise enemy within 3 -> engaging; otherwise an
# objective within 3 -> objective. No optional switch between these modes (p.42).
fun consolidation_kind(Board board, Unit original) -> MeleeMoveKind:
    for i in range(board.units.size()):
        if melee_enemy_valid(board, original, i) and original.is_engaged_with(board[i]):
            return MeleeMoveKind::ongoing
    for i in range(board.units.size()):
        if melee_enemy_valid(board, original, i) and live_unit_distance(original, board[i]) <= 3.0:
            return MeleeMoveKind::engaging
    return MeleeMoveKind::objective

# Models choose among exact closest-target ties. The initial nearest base
# determines the target, rather than the unit's first model (pp.38/42; user's
# supplied Closest definition). Rigid convenience movement defaults to first tie.
fun nearest_melee_target_valid(Board board, Model model, Bool[MAX_UNIT_COUNT] targets, UnitID target) -> Bool:
    if target.get() >= board.units.size() or !targets[target.get()]:
        return false
    let closest = 1000000000.0
    let chosen = 1000000000.0
    for i in range(board.units.size()):
        if targets[i]:
            for j in range(board[i].models.size()):
                if board[i][j].is_alive():
                    let distance = model.distance(board[i][j])
                    if distance < closest:
                        closest = distance
                    if i == target.get() and distance < chosen:
                        chosen = distance
    return chosen <= closest + 0.000001

# Every live member supplies its own closest base distance (pp.38/42).
fun melee_model_distance(Model model, Unit target) -> Float:
    let closest_range = 1000000000.0
    for i in range(target.models.size()):
        if target[i].is_alive() and model.distance(target[i]) < closest_range:
            closest_range = model.distance(target[i])
    return closest_range

# Models already in base contact cannot change position/rotation during Pile
# In or ongoing consolidation (pp.38/42); retained corpses also stay put.
fun melee_model_locked(Board board, Model model, Unit original, MeleeMoveKind kind) -> Bool:
    if !model.is_alive() or !model_can_move(model):
        return true
    if kind == MeleeMoveKind::pile_in or kind == MeleeMoveKind::ongoing:
        for i in range(board.units.size()):
            if melee_enemy_valid(board, original, i) and melee_model_distance(model, board[i]) <= 0.000001:
                return true
    return false

# Final footprints/coherency apply to the entire staged formation. Pile In
# must end engaged; ongoing/pile-in preserve every model's original enemy
# engagements. Engaging consolidation reaches every chosen enemy; incidental
# new enemies are allowed and trigger their response fights (pp.38/42).
fun melee_placement_valid(Board board, Unit original, Unit candidate, UnitID source, MeleeMoveKind kind, Bool[MAX_UNIT_COUNT] targets, Int objective) -> Bool:
    if !unit_placement_valid(board, candidate, source.get(), false):
        return false
    if kind == MeleeMoveKind::pile_in and !board.is_in_melee(candidate):
        return false
    let within = false
    for i in range(candidate.models.size()):
        if candidate[i].is_alive():
            within = within or board.model_in_objective_range(candidate[i], board.objective_range_definition(objective))
            if kind == MeleeMoveKind::pile_in or kind == MeleeMoveKind::ongoing:
                for u in range(board.units.size()):
                    if melee_enemy_valid(board, original, u):
                        let before = false
                        let after = false
                        for j in range(board[u].models.size()):
                            if board[u][j].is_alive():
                                before = before or original[i].is_engaged_with(board[u][j])
                                after = after or candidate[i].is_engaged_with(board[u][j])
                        if before and !after:
                            return false
    if kind == MeleeMoveKind::objective:
        return within
    let selected = false
    for i in range(board.units.size()):
        if targets[i]:
            selected = true
            if kind == MeleeMoveKind::engaging and !candidate.is_engaged_with(board[i]):
                return false
    return selected

# Only moved models have an approach obligation. Objective range and enemy
# engagement are required if a legal reachable endpoint exists (pp.38/42).
fun melee_model_goal(Board board, Model model, MeleeMoveKind kind, UnitID approach, Int objective) -> Bool:
    if kind == MeleeMoveKind::objective:
        return board.model_in_objective_range(model, board.objective_range_definition(objective))
    for j in range(board[approach].models.size()):
        if board[approach][j].is_alive() and model.is_engaged_with(board[approach][j]):
            return true
    return false

# Infrastructure: detect whole-grid movement/rotation without persisted float
# displacement. A rotation still counts as moving for the approach rules (p.12).
fun melee_model_moved(Model original, Model candidate) -> Bool:
    return original.position.x != candidate.position.x or original.position.y != candidate.position.y or original.geometry.rotation != candidate.geometry.rotation or original.geometry.elevation != candidate.geometry.elevation

# Each moved model must approach its chosen initial closest target (ties
# selected by its controller), or its objective when range cannot be reached (pp.38/42).
fun melee_model_approaches(Board board, Model original, Model candidate, MeleeMoveKind kind, UnitID approach, Int objective) -> Bool:
    if kind == MeleeMoveKind::objective:
        return melee_objective_distance(board, candidate, objective) < melee_objective_distance(board, original, objective) or board.model_in_objective_range(candidate, board.objective_range_definition(objective))
    return melee_model_distance(candidate, board[approach]) < melee_model_distance(original, board[approach])

# Endpoint search holds other final models fixed, preserving the existing
# finite-grid movement abstraction. Try direct routes, then whole-grid shortest
# detours with a 3-inch limit (pp.12/38/42); Float arrays are calculation locals.
fun melee_better_endpoint(Board board, Unit original, Unit candidate, UnitID source, ModelID model, MeleeMoveKind kind, Bool[MAX_UNIT_COUNT] targets, UnitID approach, Int objective) -> Bool:
    let saved = candidate[model].position
    let possible = melee_endpoint_search(board, original, candidate, source, model, kind, targets, approach, objective)
    candidate[model].position = saved
    return possible

# Borrowed candidate is restored by the owning caller; no owning early-return
# staging can leak during repeated action legality checks (pp.38/42).
fun melee_endpoint_search(Board board, Unit original, Unit candidate, UnitID source, ModelID model, MeleeMoveKind kind, Bool[MAX_UNIT_COUNT] targets, UnitID approach, Int objective) -> Bool:
    let distances : Float[1320]
    let potential : Bool[1320]
    let visited : Bool[1320]
    let any = false
    let start = original[model].geometry_position()
    let policy : MovementGeometryPolicy
    let limit = float(3 * MICROMETRES_PER_INCH)
    for i in range(1320):
        distances[i] = 1000000000.0
        let position = make_board_position(i / BOARD_HEIGHT, i % BOARD_HEIGHT)
        let end = geometry_point(position.x.value * MICROMETRES_PER_INCH, position.y.value * MICROMETRES_PER_INCH, start.z.value)
        let distance = horizontal_length(start, end)
        if distance <= limit:
            candidate[model].position = position
            potential[i] = melee_model_goal(board, candidate[model], kind, approach, objective) and melee_model_approaches(board, original[model], candidate[model], kind, approach, objective) and melee_placement_valid(board, original, candidate, source, kind, targets, objective)
            any = any or potential[i]
            if model_segment_valid(board, original, original[model], start, end, policy):
                distances[i] = distance
                if potential[i]:
                    return true
    if !any:
        return false
    for iteration in range(1320):
        let next = -1
        let nearest = 1000000000.0
        for i in range(1320):
            if !visited[i] and distances[i] <= limit and distances[i] < nearest:
                nearest = distances[i]
                next = i
        if next < 0:
            break
        visited[next] = true
        if potential[next]:
            return true
        let point = geometry_point((next / BOARD_HEIGHT) * MICROMETRES_PER_INCH, (next % BOARD_HEIGHT) * MICROMETRES_PER_INCH, start.z.value)
        for i in range(1320):
            if !visited[i]:
                let end = geometry_point((i / BOARD_HEIGHT) * MICROMETRES_PER_INCH, (i % BOARD_HEIGHT) * MICROMETRES_PER_INCH, start.z.value)
                let distance = nearest + horizontal_length(point, end)
                if distance <= limit and distance < distances[i] and model_segment_valid(board, original, original[model], point, end, policy):
                    distances[i] = distance
    return false

# Validate before committing; untouched models need not move, and every
# moved model preserves its own original engagements/approach (pp.38/42).
fun melee_finish_valid(Board board, Unit original, Unit candidate, UnitID source, MeleeMoveKind kind, Bool[MAX_UNIT_COUNT] targets, UnitID[MAX_UNIT_MODELS] approaches, Int objective) -> Bool:
    if !melee_placement_valid(board, original, candidate, source, kind, targets, objective):
        return false
    for i in range(candidate.models.size()):
        if melee_model_moved(original[i], candidate[i]):
            if melee_model_locked(board, original[i], original, kind):
                return false
            if !(kind == MeleeMoveKind::objective) and !nearest_melee_target_valid(board, original[i], targets, approaches[i]):
                return false
            if !melee_model_approaches(board, original[i], candidate[i], kind, approaches[i], objective):
                return false
            let model : ModelID
            model = i
            if !melee_model_goal(board, candidate[i], kind, approaches[i], objective) and melee_better_endpoint(board, original, candidate, source, model, kind, targets, approaches[i], objective):
                return false
    return true

# All segments consume the same 3-inch total. No Take to the Skies or
# Super-heavy Walker charge/normal exceptions apply in these moves (pp.38/42/71/85).
fun melee_waypoint_valid(Board board, Unit original, ModelPath path, BoardPosition position, MeleeMoveKind kind) -> Bool:
    if path.model.get() >= original.models.size() or path.points.size() >= 16 or melee_model_locked(board, original[path.model], original, kind):
        return false
    let start = original[path.model].geometry_position()
    if !path.points.empty():
        start = path.points.back().as_geometry_point()
    let end = geometry_point(position.x.value * MICROMETRES_PER_INCH, position.y.value * MICROMETRES_PER_INCH, start.z.value)
    let policy : MovementGeometryPolicy
    return path_distance(original[path.model], path, false) + segment_length(start, end) <= float(3 * MICROMETRES_PER_INCH) and model_segment_valid(board, original, original[path.model], start, end, policy)

# Release retained fighters only after their unit has attacked, or phase end;
# destruction effects then resolve before removal (supplied Fight on Death).
fun release_retained_fighters(Board board, UnitID source):
    for i in range(board[source].models.size()):
        if board[source][i].state == ModelState::fight_on_death:
            board[source][i].state = ModelState::pending_destruction
            board[source][i].destruction_released = true

# Phase end is the fallback for units that cannot/will not attack again. The
# common destruction engine retains trigger ordering and exact-once archives.
fun release_phase_retained_fighters(Board board):
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for slot in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, slot)
            for member in range(unit.models.size()):
                if unit[member].state == ModelState::fight_on_death:
                    unit[member].state = ModelState::pending_destruction
                    unit[member].destruction_released = true

# Engaging consolidation obliges each newly engaged unfought enemy to be
# selected once; the pending stamp persists if earlier response attacks kill
# its former foe (p.42). All-dead units without retained fighters are excluded.
fun consolidation_response_valid(Board board, UnitID source) -> Bool:
    return source.get() < board.units.size() and board[source].history.consolidation_fight_pending == board.phase_serial.value + 1 and fight_unit_eligible(board, source)

# Avoid a mandatory selector with no legal unit (p.42).
fun has_consolidation_response(Board board, Bool player) -> Bool:
    for i in range(board.units.size()):
        let source : UnitID
        source = i
        if board[i].owned_by_player1 == player and consolidation_response_valid(board, source):
            return true
    return false
