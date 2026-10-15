import board

cls ModelPath:
    ModelID model
    CheckedVector<StoredGridPoint, 16> points
    Rotation final_rotation

    # Store accepted path inputs as small bounded grid coordinates (p.12).
    fun append_point(GeometryPoint point):
        self.points.append(stored_grid_point(point))

cls MovementGeometryPolicy:
    Bool traverse_enemies
    Bool traverse_terrain
    Bool free_vertical_movement
    # Super-heavy Walker crosses non-TITANIC models only (p.85).
    Bool exclude_titanic
    # Nobz charge traversal excludes MONSTER/VEHICLE models individually.
    Bool exclude_monster_vehicle

# Check the entire circular footprint, not just its centre, against battlefield
# edges. Unsupported footprints cannot silently become circular bases (p.12).
fun model_inside_battlefield(Model model, GeometryPoint point) -> Bool:
    if model.geometry.unsupported_footprint:
        return false
    let radius = model.base_radius_micrometres()
    return float(point.x.value) >= radius and float(point.y.value) >= radius and float(point.x.value) + radius <= float(BOARD_WIDTH * MICROMETRES_PER_INCH) and float(point.y.value) + radius <= float(BOARD_HEIGHT * MICROMETRES_PER_INCH)

# Coplanar circular bases may touch but cannot overlap; different support
# levels are distinct. Physical body/hull solids require supplied data (p.12).
fun model_bases_overlap(Model a, Model b) -> Bool:
    if a.off_battlefield or b.off_battlefield:
        return false
    if a.geometry.unsupported_footprint or b.geometry.unsupported_footprint:
        return true
    if a.geometry.elevation != b.geometry.elevation:
        return false
    let a_point = a.geometry_position()
    let b_point = b.geometry_position()
    let dx = float(a_point.x.value - b_point.x.value)
    let dy = float(a_point.y.value - b_point.y.value)
    let radii = a.base_radius_micrometres() + b.base_radius_micrometres()
    return dx * dx + dy * dy < radii * radii

# An elevated base must fit entirely on a supporting surface, not overhang
# it. Terrain keyword permissions remain with tasks 8/11 (pp.12/48).
fun model_supported_by_terrain(Model model, GeometryPoint point, TerrainGeometry terrain) -> Bool:
    let radius = model.base_radius_micrometres()
    return point.z.value == (terrain.upper.z.value * MICROMETRES_PER_INCH) and float(point.x.value) - radius >= float((terrain.lower.x.value * MICROMETRES_PER_INCH)) and float(point.x.value) + radius <= float((terrain.upper.x.value * MICROMETRES_PER_INCH)) and float(point.y.value) - radius >= float((terrain.lower.y.value * MICROMETRES_PER_INCH)) and float(point.y.value) + radius <= float((terrain.upper.y.value * MICROMETRES_PER_INCH))

# Validate stable placement and no base partway through a solid terrain volume.
# Geometry boxes describe actual surfaces, not abstract terrain areas (pp.12/48).
fun model_placement_valid(Board board, Model model) -> Bool:
    let point = model.geometry_position()
    if !model_inside_battlefield(model, point):
        return false
    let supported = point.z == 0
    let i = 0
    while i < board.terrain_geometry.size():
        ref terrain = board.terrain_geometry[i]
        if !valid_terrain_geometry(terrain):
            return false
        if model_supported_by_terrain(model, point, terrain):
            supported = true
        if point.z.value >= (terrain.lower.z.value * MICROMETRES_PER_INCH) and point.z.value < (terrain.upper.z.value * MICROMETRES_PER_INCH):
            let distance = segment_terrain_distance_squared(float(point.x.value), float(point.y.value), float(point.x.value), float(point.y.value), terrain)
            let radius = model.base_radius_micrometres()
            if distance < radius * radius:
                return false
        i = i + 1
    return supported

# End a move/setup only if every model fits, no bases overlap, and the complete
# unit is coherent. Setup additionally requires unengaged placement (pp.12/14).
fun unit_placement_valid(Board board, Unit candidate, Int ignored_slot, Bool require_unengaged) -> Bool:
    if candidate.empty() or !candidate.is_coherent():
        return false
    let i = 0
    while i < candidate.models.size():
        if !model_placement_valid(board, candidate[i]):
            return false
        let j = i + 1
        while j < candidate.models.size():
            if model_bases_overlap(candidate[i], candidate[j]):
                return false
            j = j + 1
        j = 0
        while j < board.units.size():
            if j != ignored_slot and !board[j].off_battlefield:
                let k = 0
                while k < board[j].models.size():
                    if model_bases_overlap(candidate[i], board[j][k]):
                        return false
                    if require_unengaged and candidate.owned_by_player1 != board[j].owned_by_player1 and candidate[i].is_engaged_with(board[j][k]):
                        return false
                    k = k + 1
            j = j + 1
        i = i + 1
    return true

# Sweep a circular base against an enemy base. Height changes must not skip a
# collision at the point where the two base planes meet (p.12).
fun segment_crosses_model(Model moving, GeometryPoint start, GeometryPoint end, Model obstacle) -> Bool:
    if obstacle.geometry.unsupported_footprint:
        return true
    let ax = float(start.x.value)
    let ay = float(start.y.value)
    let bx = float(end.x.value)
    let by = float(end.y.value)
    if start.z != end.z:
        let t = float(obstacle.geometry.elevation.value * MICROMETRES_PER_INCH - start.z.value) / float(end.z.value - start.z.value)
        if t < 0.0 or t > 1.0:
            return false
        ax = ax + (bx - ax) * t
        ay = ay + (by - ay) * t
        bx = ax
        by = ay
    else if start.z.value != obstacle.geometry.elevation.value * MICROMETRES_PER_INCH:
        return false
    let point = obstacle.geometry_position()
    let radii = moving.base_radius_micrometres() + obstacle.base_radius_micrometres()
    return point_segment_distance_squared(float(point.x.value), float(point.y.value), ax, ay, bx, by) < radii * radii

# Check the terrain-intersecting height interval of the full segment. A path
# along a roof is allowed; a path through the volume below it is not (p.12).
fun segment_crosses_terrain(Model moving, GeometryPoint start, GeometryPoint end, TerrainGeometry terrain) -> Bool:
    let first = 0.0
    let last = 1.0
    if start.z == end.z:
        if start.z.value < (terrain.lower.z.value * MICROMETRES_PER_INCH) or start.z.value >= (terrain.upper.z.value * MICROMETRES_PER_INCH):
            return false
    else:
        let lower = float((terrain.lower.z.value * MICROMETRES_PER_INCH) - start.z.value) / float(end.z.value - start.z.value)
        let upper = float((terrain.upper.z.value * MICROMETRES_PER_INCH) - start.z.value) / float(end.z.value - start.z.value)
        if lower > upper:
            let swap = lower
            lower = upper
            upper = swap
        if lower > first:
            first = lower
        if upper < last:
            last = upper
        if first > last or last < 0.0 or first > 1.0:
            return false
        # The upper surface is excluded from the solid volume (p.48).
        # A segment touching only that roof must not count as entering terrain.
        if first == last and float(start.z.value) + float(end.z.value - start.z.value) * first >= float((terrain.upper.z.value * MICROMETRES_PER_INCH)):
            return false
    let ax = float(start.x.value)
    let ay = float(start.y.value)
    let dx = float(end.x.value - start.x.value)
    let dy = float(end.y.value - start.y.value)
    let radius = moving.base_radius_micrometres()
    return segment_terrain_distance_squared(ax + dx * first, ay + dy * first, ax + dx * last, ay + dy * last, terrain) < radius * radius

# Ascending/descending must stay within half an inch horizontally of a
# terrain feature. Both endpoints in its convex neighbourhood cover the
# whole straight segment; FLYING exceptions are supplied by callers (p.48).
fun vertical_segment_near_terrain(Board board, Model model, GeometryPoint start, GeometryPoint end) -> Bool:
    let i = 0
    let range = model.base_radius_micrometres() + float(MICROMETRES_PER_INCH) / 2.0
    while i < board.terrain_geometry.size():
        ref terrain = board.terrain_geometry[i]
        if segment_terrain_distance_squared(float(start.x.value), float(start.y.value), float(start.x.value), float(start.y.value), terrain) <= range * range and segment_terrain_distance_squared(float(end.x.value), float(end.y.value), float(end.x.value), float(end.y.value), terrain) <= range * range:
            return true
        i = i + 1
    return false

# M- permits setup but no other movement (core p10/P10-06). This also
# freezes the model in charge/surge/pile-in paths, not just its normal M budget.
fun model_can_move(Model model) -> Bool:
    return model.profile.movement() > 0 or model.has_random_movement

# Whole-unit selection requires an actual movable member; mixed units retain
# their immobile models in place. Core p10, not an invented Fortification rule.
fun unit_has_movable_model(Unit unit) -> Bool:
    for member_index in range(unit.models.size()):
        if unit[member_index].is_alive() and model_can_move(unit[member_index]):
            return true
    return false

# Friendly traversal is permitted, enemy traversal is not unless a move's
# sourced exception supplies it. AIRCRAFT may be traversed in every move
# (p.74); final base overlaps remain forbidden. All other segments check full
# base clearance (p.12).
fun model_segment_valid(Board board, Unit unit, Model model, GeometryPoint start, GeometryPoint end, MovementGeometryPolicy policy) -> Bool:
    if !model_can_move(model) and (start.x != end.x or start.y != end.y or start.z != end.z):
        return false
    if !geometry_point_on_grid(start) or !geometry_point_on_grid(end) or !model_inside_battlefield(model, start) or !model_inside_battlefield(model, end):
        return false
    if start.z != end.z and !policy.free_vertical_movement and !vertical_segment_near_terrain(board, model, start, end):
        return false
    let i = 0
    while i < board.units.size():
        if !board[i].off_battlefield and board[i].owned_by_player1 != unit.owned_by_player1 and (!policy.traverse_enemies or policy.exclude_titanic or policy.exclude_monster_vehicle):
            let j = 0
            while j < board[i].models.size():
                let blocks = !policy.traverse_enemies or (policy.exclude_titanic and board[i][j].has_keyword(Keyword::titanic)) or (policy.exclude_monster_vehicle and (board[i][j].has_keyword(Keyword::monster) or board[i][j].has_keyword(Keyword::vehicle)))
                if !board[i][j].has_keyword(Keyword::aircraft) and blocks and segment_crosses_model(model, start, end, board[i][j]):
                    return false
                j = j + 1
        i = i + 1
    i = 0
    while i < board.terrain_geometry.size():
        ref terrain = board.terrain_geometry[i]
        if !valid_terrain_geometry(terrain):
            return false
        if terrain.blocks_movement and !policy.traverse_terrain and segment_crosses_terrain(model, start, end, terrain):
            return false
        i = i + 1
    return true

# Stage individual paths in a candidate, then commit only after every path,
# per-model M budget and final-placement condition passes. Failure leaves all
# positions/history unchanged, including earlier valid paths (pp.12/87).
fun try_move_models(Board board, UnitID slot, Vector<ModelPath> paths, Int extra_distance, MovementGeometryPolicy policy, Bool require_unengaged) -> Bool:
    if slot.get() >= board.units.size():
        return false
    let candidate = board[slot]
    let valid = validate_movement_candidate(board, slot, candidate, paths, extra_distance, policy, require_unengaged)
    if valid:
        board[slot] = candidate
    return valid

# Validate the staged unit without owning copies on early-return paths;
# failed movement is discarded by try_move_models (pp.12/87).
fun validate_movement_candidate(Board board, UnitID slot, Unit candidate, Vector<ModelPath> paths, Int extra_distance, MovementGeometryPolicy policy, Bool require_unengaged) -> Bool:
    if slot.get() >= board.units.size() or board[slot].empty() or extra_distance < 0:
        return false
    let seen : Bool[MAX_UNIT_MODELS]
    let i = 0
    while i < paths.size():
        ref path = paths[i]
        let index = path.model.get()
        if index >= candidate.models.size() or seen[index]:
            return false
        seen[index] = true
        ref model = candidate[index]
        let start = model.geometry_position()
        let distance = 0.0
        let j = 0
        while j < path.points.size():
            if !path.points[j].valid():
                return false
            let end = path.points[j].as_geometry_point()
            if !model_segment_valid(board, candidate, model, start, end, policy):
                return false
            distance = distance + segment_length(start, end)
            record_geometry_movement(model.history, start, end, false)
            start = end
            j = j + 1
        if distance > float((model.effective_movement(model.profile.movement()) + extra_distance) * MICROMETRES_PER_INCH):
            return false
        model.set_geometry_position(start)
        model.geometry.rotation = path.final_rotation
        i = i + 1
    if !unit_placement_valid(board, candidate, slot.get(), require_unengaged):
        return false
    candidate.history.last_move_phase = board.phase_serial.value + 1
    return true

# Within is any part of any base; Wholly Within is every point of every base
# (user-supplied definitions). These helpers use a point-centred 3D range, not
# engagement's distinct horizontal/vertical limits (core pp.9/14).
fun model_within_point(Model model, GeometryPoint point, Int inches, Bool wholly) -> Bool:
    if model.geometry.unsupported_footprint or inches < 0:
        return false
    let location = model.geometry_position()
    let horizontal = horizontal_length(location, point)
    let radius = model.base_radius_micrometres()
    if wholly:
        horizontal = horizontal + radius
    else:
        horizontal = horizontal - radius
        if horizontal < 0.0:
            horizontal = 0.0
    let vertical = float(location.z.value - point.z.value)
    let limit = float(inches * MICROMETRES_PER_INCH)
    return horizontal * horizontal + vertical * vertical <= limit * limit

# Quantify over all bases for Wholly Within and any base for Within; never
# substitute the first model's centre for the user's unit definition (p.9).
fun unit_within_point(Unit unit, GeometryPoint point, Int inches, Bool wholly) -> Bool:
    if unit.empty():
        return false
    let i = 0
    while i < unit.models.size():
        let within = model_within_point(unit[i], point, inches, wholly)
        if wholly and !within:
            return false
        if !wholly and within:
            return true
        i = i + 1
    return wholly

# Keep the existing one-BoardPosition editor action usable while validating
# each member's path and M separately. Independent model paths use try_move_models
# directly; task 11 owns their public decision workflow (pp.12/87).
fun try_translate_unit(Board board, UnitID slot, BoardPosition target, Int extra_distance) -> Bool:
    if slot.get() >= board.units.size() or board[slot].empty():
        return false
    ref unit = board[slot]
    let origin = unit[0].geometry_position()
    let dx = target.x.value * MICROMETRES_PER_INCH - origin.x.value
    let dy = target.y.value * MICROMETRES_PER_INCH - origin.y.value
    let paths : Vector<ModelPath>
    let valid = true
    let i = 0
    while i < unit.models.size():
        let start = unit[i].geometry_position()
        let x = start.x.value + dx
        let y = start.y.value + dy
        if x < 0 or x > BOARD_WIDTH * MICROMETRES_PER_INCH or y < 0 or y > BOARD_HEIGHT * MICROMETRES_PER_INCH:
            valid = false
            break
        let path : ModelPath
        path.model = i
        path.final_rotation = unit[i].geometry.rotation
        path.append_point(geometry_point(x, y, start.z.value))
        paths.append(path)
        i = i + 1
    let policy : MovementGeometryPolicy
    if valid:
        valid = try_move_models(board, slot, paths, extra_distance, policy, true)
    return valid

# Legality must not mutate the shared board while action enumeration probes
# every candidate; commit the same validated translation only on apply (p.12).
fun can_translate_unit(Board board, UnitID slot, BoardPosition target, Int extra_distance) -> Bool:
    let copy = board
    return try_translate_unit(copy, slot, target, extra_distance)

# Validate a complete setup candidate before removing it from reserves; failed
# setup leaves the original location and provenance unchanged (p.14).
fun setup_candidate_valid(Board board, Unit source, BoardPosition anchor) -> Bool:
    let candidate = source
    return candidate.try_arrange_at(anchor) and unit_placement_valid(board, candidate, -1, true)
