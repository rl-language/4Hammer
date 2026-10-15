import vector2d
import state_types

# Physical calculations use micrometres for millimetre bases and inch limits;
# game positions/path endpoints stay on the existing whole-inch quad grid.
# GeometryPoint is a calculation value, not a new player coordinate domain.
# These precision/capacity choices are implementation limits, not game limits.
const MICROMETRES_PER_INCH = 25400
const MAX_ELEVATION = 762001
const MAX_GEOMETRY_X = 1117601
const MAX_GEOMETRY_Y = 762001
using GeometryX = LinearlyDistributedInt<0, MAX_GEOMETRY_X>
using GeometryY = LinearlyDistributedInt<0, MAX_GEOMETRY_Y>
using Elevation = LinearlyDistributedInt<0, MAX_ELEVATION>
using GridElevation = LinearlyDistributedInt<0, 31>
using Rotation = LinearlyDistributedInt<0, 360000>

cls GeometryPoint:
    GeometryX x
    GeometryY y
    Elevation z

# Terrain corners include the board edges; these are the smallest whole-quad
# storage domains for 44x30 extents, not physical-precision action inputs.
const MAX_TERRAIN_X = 45
const MAX_TERRAIN_Y = 31
using TerrainCoordinateX = LinearlyDistributedInt<0, MAX_TERRAIN_X>
using TerrainCoordinateY = LinearlyDistributedInt<0, MAX_TERRAIN_Y>

cls StoredTerrainPoint:
    TerrainCoordinateX x
    TerrainCoordinateY y
    GridElevation z

    # Existing configuration helpers accept calculation geometry, but only
    # whole-quad corners can be persisted (user requirement; terrain pp.46–48).
    fun assign(GeometryPoint point):
        assert(geometry_point_on_grid(point), "terrain corners must be whole quads")
        self.x = point.x.value / MICROMETRES_PER_INCH
        self.y = point.y.value / MICROMETRES_PER_INCH
        self.z = point.z.value / MICROMETRES_PER_INCH

# Integer terrain corners are on-grid by representation; validate raw parsed
# bounds before accepting saved geometry (p.12 / user storage requirement).
fun geometry_point_on_grid(StoredTerrainPoint point) -> Bool:
    return point.x.value >= 0 and point.x.value < MAX_TERRAIN_X and point.y.value >= 0 and point.y.value < MAX_TERRAIN_Y and point.z.value >= 0 and point.z.value <= BOARD_HEIGHT

cls ModelGeometry:
    # Explicit user-provided Use-model circular hull proxy;0 uses source base.
    LinearlyDistributedInt<0, 1001> proxy_diameter_mm
    GridElevation elevation
    Rotation rotation
    # Ovals use explicit source long-axis circle proxies by user policy.
    # Unknown hull/multipart dimensions remain unsupported.
    Bool unsupported_footprint

# User-approved task-8 abstraction: areas only, with category flags for mixed
# areas (pp.46–47). No physical features/openings or continuous positions.
cls TerrainArea:
    StoredTerrainPoint lower
    StoredTerrainPoint upper
    Bool exposed
    Bool light
    Bool dense

using TerrainAreaVector = CheckedVector<TerrainArea, 16>

cls TerrainGeometry:
    StoredTerrainPoint lower
    StoredTerrainPoint upper
    Bool blocks_movement

using TerrainGeometryVector = CheckedVector<TerrainGeometry, 16>

# Inclusive, separate horizontal/vertical limits for engagement/coherency
# (pp.14–15). Calculation precision does not change the quad coordinate domain.
fun within_geometry_limits(Float horizontal, Int vertical, Int horizontal_inches, Int vertical_inches) -> Bool:
    return horizontal <= float(horizontal_inches * MICROMETRES_PER_INCH) and vertical <= vertical_inches * MICROMETRES_PER_INCH

# Construct a checked physical point rather than silently clamp unsupported
# geometry; the base may not cross the battlefield edge (p.12).
fun geometry_point(Int x, Int y, Int z) -> GeometryPoint:
    assert(x >= 0 and x <= BOARD_WIDTH * MICROMETRES_PER_INCH, "geometry x out of bounds")
    assert(y >= 0 and y <= BOARD_HEIGHT * MICROMETRES_PER_INCH, "geometry y out of bounds")
    assert(z >= 0 and z < MAX_ELEVATION, "geometry elevation out of bounds")
    let result : GeometryPoint
    result.x = x
    result.y = y
    result.z = z
    return result

# Horizontal movement uses the same base point before/after each segment;
# ascent/descent is added separately, not measured as a diagonal (pp.12/48).
fun horizontal_length(GeometryPoint start, GeometryPoint end) -> Float:
    let dx = float(end.x.value - start.x.value)
    let dy = float(end.y.value - start.y.value)
    return sqrt(dx * dx + dy * dy)

# Accumulate every straight segment, including vertical ascent/descent (pp.12/48).
fun segment_length(GeometryPoint start, GeometryPoint end) -> Float:
    return horizontal_length(start, end) + float(abs(end.z.value - start.z.value))

# Keep all collision tests in squared micrometres so exact tangency is not
# mistaken for overlap; bases must fit through the path (p.12).
fun point_segment_distance_squared(Float px, Float py, Float ax, Float ay, Float bx, Float by) -> Float:
    let dx = bx - ax
    let dy = by - ay
    let length_squared = dx * dx + dy * dy
    let t = 0.0
    if length_squared > 0.0:
        t = ((px - ax) * dx + (py - ay) * dy) / length_squared
    if t < 0.0:
        t = 0.0
    if t > 1.0:
        t = 1.0
    let x = px - ax - t * dx
    let y = py - ay - t * dy
    return x * x + y * y

# Intersect complete segments, including collinear overlaps; checking just
# movement endpoints can miss crossing an enemy base/wall (p.12).
fun segments_intersect(Float ax, Float ay, Float bx, Float by, Float cx, Float cy, Float dx, Float dy) -> Bool:
    let ab_c = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    let ab_d = (bx - ax) * (dy - ay) - (by - ay) * (dx - ax)
    let cd_a = (dx - cx) * (ay - cy) - (dy - cy) * (ax - cx)
    let cd_b = (dx - cx) * (by - cy) - (dy - cy) * (bx - cx)
    if ab_c * ab_d > 0.0 or cd_a * cd_b > 0.0:
        return false
    if ax < cx and ax < dx and bx < cx and bx < dx:
        return false
    if ax > cx and ax > dx and bx > cx and bx > dx:
        return false
    if ay < cy and ay < dy and by < cy and by < dy:
        return false
    if ay > cy and ay > dy and by > cy and by > dy:
        return false
    return true


# Measure clearance from a swept circular base to each rectangular terrain
# edge, including corners instead of a conservative expanded box (p.12).
fun segment_segment_distance_squared(Float ax, Float ay, Float bx, Float by, Float cx, Float cy, Float dx, Float dy) -> Float:
    if segments_intersect(ax, ay, bx, by, cx, cy, dx, dy):
        return 0.0
    let result = point_segment_distance_squared(ax, ay, cx, cy, dx, dy)
    let distance = point_segment_distance_squared(bx, by, cx, cy, dx, dy)
    if distance < result:
        result = distance
    distance = point_segment_distance_squared(cx, cy, ax, ay, bx, by)
    if distance < result:
        result = distance
    distance = point_segment_distance_squared(dx, dy, ax, ay, bx, by)
    if distance < result:
        result = distance
    return result

# Reject malformed terrain extents before applying placement/path constraints
# (p.12). Category/traversal permissions are supplied by tasks 8/11.
fun valid_terrain_geometry(TerrainGeometry terrain) -> Bool:
    return geometry_point_on_grid(terrain.lower) and geometry_point_on_grid(terrain.upper) and (terrain.lower.x.value * MICROMETRES_PER_INCH) < (terrain.upper.x.value * MICROMETRES_PER_INCH) and (terrain.lower.y.value * MICROMETRES_PER_INCH) < (terrain.upper.y.value * MICROMETRES_PER_INCH) and (terrain.lower.z.value * MICROMETRES_PER_INCH) < (terrain.upper.z.value * MICROMETRES_PER_INCH)

# Distance from the complete movement segment to a rectangular feature's
# footprint; endpoint-only checks allow models to pass through walls (p.12).
fun segment_terrain_distance_squared(Float ax, Float ay, Float bx, Float by, TerrainGeometry terrain) -> Float:
    let left = float((terrain.lower.x.value * MICROMETRES_PER_INCH))
    let right = float((terrain.upper.x.value * MICROMETRES_PER_INCH))
    let bottom = float((terrain.lower.y.value * MICROMETRES_PER_INCH))
    let top = float((terrain.upper.y.value * MICROMETRES_PER_INCH))
    if ax >= left and ax <= right and ay >= bottom and ay <= top:
        return 0.0
    if bx >= left and bx <= right and by >= bottom and by <= top:
        return 0.0
    let result = segment_segment_distance_squared(ax, ay, bx, by, left, bottom, right, bottom)
    let distance = segment_segment_distance_squared(ax, ay, bx, by, right, bottom, right, top)
    if distance < result:
        result = distance
    distance = segment_segment_distance_squared(ax, ay, bx, by, right, top, left, top)
    if distance < result:
        result = distance
    distance = segment_segment_distance_squared(ax, ay, bx, by, left, top, left, bottom)
    if distance < result:
        result = distance
    return result

# Preserve the user's quad-based game: finer units are for measurement only.
# All stored terrain corners and movement destinations must use whole-inch cells.
fun geometry_point_on_grid(GeometryPoint point) -> Bool:
    return point.x.value % MICROMETRES_PER_INCH == 0 and point.y.value % MICROMETRES_PER_INCH == 0 and point.z.value % MICROMETRES_PER_INCH == 0

# Terrain areas are agreed horizontal boundaries, distinct from physical solids
# (pp.46–47). Rectangular whole-quad areas are the currently supported shape.
fun valid_terrain_area(TerrainArea area) -> Bool:
    return geometry_point_on_grid(area.lower) and geometry_point_on_grid(area.upper) and (area.lower.z.value * MICROMETRES_PER_INCH) == 0 and (area.upper.z.value * MICROMETRES_PER_INCH) == 0 and (area.lower.x.value * MICROMETRES_PER_INCH) < (area.upper.x.value * MICROMETRES_PER_INCH) and (area.lower.y.value * MICROMETRES_PER_INCH) < (area.upper.y.value * MICROMETRES_PER_INCH) and (area.exposed or area.light or area.dense)

# Closest-part area distance tests base intersection (p.9; user's Within
# definition), rather than testing only a model's centre.
fun point_area_distance_squared(Float x, Float y, TerrainArea area) -> Float:
    let dx = 0.0
    let dy = 0.0
    if x < float((area.lower.x.value * MICROMETRES_PER_INCH)):
        dx = float((area.lower.x.value * MICROMETRES_PER_INCH)) - x
    else if x > float((area.upper.x.value * MICROMETRES_PER_INCH)):
        dx = x - float((area.upper.x.value * MICROMETRES_PER_INCH))
    if y < float((area.lower.y.value * MICROMETRES_PER_INCH)):
        dy = float((area.lower.y.value * MICROMETRES_PER_INCH)) - y
    else if y > float((area.upper.y.value * MICROMETRES_PER_INCH)):
        dy = y - float((area.upper.y.value * MICROMETRES_PER_INCH))
    return dx * dx + dy * dy

# Objective/terrain points are associated with areas by their agreed boundary
# (pp.46/52); category flags do not manufacture a physical blocking feature.
fun point_in_terrain_area(BoardPosition point, TerrainArea area) -> Bool:
    return point_area_distance_squared(float(point.x.value * MICROMETRES_PER_INCH), float(point.y.value * MICROMETRES_PER_INCH), area) == 0.0

# Persist only bounded integer grid displacement; geometry/distance values
# remain local calculations (user requirement; movement p.12 / Heavy p.82).
fun record_geometry_movement(ModelHistory history, GeometryPoint start, GeometryPoint end, Bool free_vertical):
    assert(geometry_point_on_grid(start) and geometry_point_on_grid(end), "movement history requires whole quads")
    let dz = 0
    if !free_vertical:
        dz = (end.z.value - start.z.value) / MICROMETRES_PER_INCH
    history.record_movement_segment((end.x.value - start.x.value) / MICROMETRES_PER_INCH, (end.y.value - start.y.value) / MICROMETRES_PER_INCH, dz)

# Actual saved path positions use whole-inch quad values; precision geometry
# is reconstructed only for calculations (user requirement; movement p.12).
cls StoredGridPoint:
    CoordinateX x
    CoordinateY y
    GridElevation z

    # Validate externally parsed raw values before reconstructing geometry.
    fun valid() -> Bool:
        return self.x.value >= 0 and self.x.value < BOARD_WIDTH and self.y.value >= 0 and self.y.value < BOARD_HEIGHT and self.z.value >= 0 and self.z.value <= BOARD_HEIGHT

    # Reconstruct a calculation value without enlarging the stored domains.
    fun as_geometry_point() -> GeometryPoint:
        return geometry_point(self.x.value * MICROMETRES_PER_INCH, self.y.value * MICROMETRES_PER_INCH, self.z.value * MICROMETRES_PER_INCH)

# Reject non-grid path data rather than quantize it (user's quad constraint).
fun stored_grid_point(GeometryPoint point) -> StoredGridPoint:
    assert(geometry_point_on_grid(point) and point.x.value < BOARD_WIDTH * MICROMETRES_PER_INCH and point.y.value < BOARD_HEIGHT * MICROMETRES_PER_INCH, "stored path point outside quad domain")
    let result : StoredGridPoint
    result.x = point.x.value / MICROMETRES_PER_INCH
    result.y = point.y.value / MICROMETRES_PER_INCH
    result.z = point.z.value / MICROMETRES_PER_INCH
    return result
