import movement_geometry

# The legacy mission has 5-inch home zones; check the whole base, not the
# anchor. Actual mission shapes remain supplied-data task 17 (setup pp.14/82).
fun model_in_home_zone(Model model, Bool player) -> Bool:
    let radius = model.base_radius_micrometres()
    if player:
        return float(model.position.y.value * MICROMETRES_PER_INCH) + radius <= float(5 * MICROMETRES_PER_INCH)
    return float(model.position.y.value * MICROMETRES_PER_INCH) - radius >= float((BOARD_HEIGHT - 5) * MICROMETRES_PER_INCH)

# Any part touching the opposing deployment zone counts as within (user's
# definition); horizontal base clearance drives ingress/infiltrators (pp.69/82).
fun model_distance_to_home_zone(Model model, Bool player) -> Float:
    if player:
        return movement_float_max(0.0, float((model.position.y.value - 5) * MICROMETRES_PER_INCH) - model.base_radius_micrometres())
    return movement_float_max(0.0, float((BOARD_HEIGHT - 5 - model.position.y.value) * MICROMETRES_PER_INCH) - model.base_radius_micrometres())

# Wholly Within quantifies every live base; no anchor-only shortcut (pp.14/84).
fun unit_in_home_zone(Unit unit, Bool player) -> Bool:
    if unit.empty():
        return false
    for i in range(unit.models.size()):
        if !model_in_home_zone(unit[i], player):
            return false
    return true

# Setup/scout/ingress separation uses horizontal base-to-base distance with
# strict >8, including models whose vertical positions differ (pp.69/82/84).
fun separated_from_enemies(Board board, Unit candidate, Int ignored, Int inches) -> Bool:
    for u in range(board.units.size()):
        if u != ignored and board[u].owned_by_player1 != candidate.owned_by_player1:
            for i in range(candidate.models.size()):
                for j in range(board[u].models.size()):
                    if board[u][j].is_alive() and candidate[i].horizontal_distance_micrometres(board[u][j]) <= float(inches * MICROMETRES_PER_INCH):
                        return false
    return true

# Every base must fit wholly in the union of the four 6-inch edge strips.
# Circular fixtures fit the union iff their farthest corner-inward extent
# does not enter the central open rectangle (ingress p.69).
fun model_in_edge_strip(Model model) -> Bool:
    let x = float(model.position.x.value * MICROMETRES_PER_INCH)
    let y = float(model.position.y.value * MICROMETRES_PER_INCH)
    let radius = model.base_radius_micrometres()
    let left = float(6 * MICROMETRES_PER_INCH)
    let right = float((BOARD_WIDTH - 6) * MICROMETRES_PER_INCH)
    let top = float((BOARD_HEIGHT - 6) * MICROMETRES_PER_INCH)
    let dx = movement_float_max(movement_float_max(left - x, 0.0), x - right)
    let dy = movement_float_max(movement_float_max(left - y, 0.0), y - top)
    return dx * dx + dy * dy >= radius * radius

# Validate every setup model after preset arrangement and general legality.
# Deployment, Scouts and ordinary/Deep Strike ingress have distinct limits
# (pp.14/69/80/82/84); round storage is zero-based.
fun setup_rules_valid(Board board, Unit candidate, MovementKind kind, Bool infiltrates) -> Bool:
    if !unit_placement_valid(board, candidate, -1, true):
        return false
    if kind == MovementKind::scout:
        return unit_in_home_zone(candidate, candidate.owned_by_player1)
    if kind == MovementKind::ingress:
        if !separated_from_enemies(board, candidate, -1, 8):
            return false
        if candidate.all_have_ability(AbilityKind::deep_strike):
            return true
        for i in range(candidate.models.size()):
            if !model_in_edge_strip(candidate[i]) or (board.current_round < 2 and model_distance_to_home_zone(candidate[i], !candidate.owned_by_player1) == 0.0):
                return false
        return true
    if infiltrates:
        if !separated_from_enemies(board, candidate, -1, 8):
            return false
        for i in range(candidate.models.size()):
            if model_distance_to_home_zone(candidate[i], !candidate.owned_by_player1) <= float(8 * MICROMETRES_PER_INCH):
                return false
        return true
    return unit_in_home_zone(candidate, candidate.owned_by_player1)

# Single-exit staging avoids owning-local cleanup omissions; reject invalid
# formation setup before removing the original reserve entry (p.14).
fun setup_at_valid(Board board, Unit unit, BoardPosition anchor, MovementKind kind, Bool infiltrates) -> Bool:
    if !setup_anchor_possible(unit, anchor, kind, infiltrates):
        return false
    return staged_setup_at_valid(board, unit, anchor, kind, infiltrates)

# Infrastructure: keep owning-copy cleanup outside conditional/loop control
# flow; all placement rules are still evaluated by the common kernel (p.14).
fun staged_setup_at_valid(Board board, Unit unit, BoardPosition anchor, MovementKind kind, Bool infiltrates) -> Bool:
    let candidate : Unit
    candidate = unit
    mark_unit_offboard(candidate, false)
    let valid = arrange_setup_candidate(board, candidate, anchor, kind, infiltrates)
    return valid

# The first preset model is centred on the anchor. Its base must fit on the
# board and, for ordinary deployment/Scouts, wholly in its home zone (pp.14/84).
# No sufficient-placement shortcut is introduced; full validation follows.
fun setup_anchor_possible(Unit unit, BoardPosition anchor, MovementKind kind, Bool infiltrates) -> Bool:
    if unit.empty() or unit[0].geometry.unsupported_footprint:
        return false
    let radius = unit[0].base_radius_micrometres()
    let x = float(anchor.x.value * MICROMETRES_PER_INCH)
    let y = float(anchor.y.value * MICROMETRES_PER_INCH)
    if unit[0].is_alive() and (x < radius or y < radius or x + radius > float(BOARD_WIDTH * MICROMETRES_PER_INCH) or y + radius > float(BOARD_HEIGHT * MICROMETRES_PER_INCH)):
        return false
    if kind == MovementKind::scout or (kind == MovementKind::normal and !infiltrates):
        if unit.owned_by_player1:
            return y + radius <= float(5 * MICROMETRES_PER_INCH)
        return y - radius >= float((BOARD_HEIGHT - 5) * MICROMETRES_PER_INCH)
    return true

# No pending corpse can move; ingress locks all further move types until the
# next Charge phase (pp.69/87). Selection and actual movement are distinct.
fun battlefield_move_eligible(Board board, UnitID id, MovementKind kind) -> Bool:
    if id.get() >= board.units.size() or board[id].off_battlefield or board[id].history.ingress_locked or !has_live_model(board[id]) or board[id].has_keyword(Keyword::aircraft):
        return false
    if board[id].history.tactical_move_required and !(kind == MovementKind::normal or kind == MovementKind::advance):
        return false
    if kind == MovementKind::stationary:
        return true
    if !unit_has_movable_model(board[id]):
        return false
    if kind == MovementKind::pulse_jet:
        return !board.is_in_melee(board[id]) and faction_special_move_available(board, board[id], kind)
    if kind == MovementKind::ordered_retreat:
        return board.is_in_melee(board[id]) and !board[id].battle_socked and !faction_forces_escape(board, board[id])
    if kind == MovementKind::desperate_escape:
        return board.is_in_melee(board[id])
    if kind == MovementKind::normal or kind == MovementKind::advance:
        # p.74: Aircraft-only engagement does not block these two move types.
        for enemy in range(board.units.size()):
            if board[enemy].owned_by_player1 != board[id].owned_by_player1 and !board[enemy].has_keyword(Keyword::aircraft) and board[id].is_engaged_with(board[enemy]):
                return false
        return true
    return !board.is_in_melee(board[id])

# Infrastructure helper exposes live membership without importing combat's
# generated frames into the movement module (destroyed models p.87).
fun has_live_model(Unit unit) -> Bool:
    for i in range(unit.models.size()):
        if unit[i].is_alive():
            return true
    return false

# Record selected type and turn-long restrictions only after a successful
# move. Repositioning/ingress must not erase advance/fall-back flags (pp.33/68).
fun record_move(Board board, UnitID id, MovementKind kind):
    board[id].history.selected_move_phase = board.phase_serial.value + 1
    board[id].history.move_kind = kind
    board[id].has_moved = true
    board[id].history.tactical_move_required = false
    if !(kind == MovementKind::stationary):
        # p.58 exempts only Pile In/consolidation, not these battlefield moves.
        board[id].interrupt_actions()
        board[id].history.last_move_phase = board.phase_serial.value + 1
        board[id].history.made_move_this_turn = true
    faction_record_move_effects(board, id, kind)
    if kind == MovementKind::advance:
        board[id].history.advanced_this_turn = true
        board[id].has_run = true
        # Only this Advance restriction is waived; transport/action/fall-back
        # restrictions still apply (Orks Waaagh! and core pp.33/65).
        if !board[id].history.advance_allows_charge:
            board[id].can_charge = false
    if kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape:
        board[id].history.fell_back_this_turn = true
        board[id].can_shoot = board[id].history.fallback_allows_shooting
        board[id].can_charge = board[id].history.fallback_allows_charge

# Ingress is selected once per phase and locks later moves; no history reset
# is allowed when a repositioned unit returns the same turn (pp.68–69).
fun enter_from_reserves(Board board, UnitID reserve, BoardPosition position, MovementKind kind):
    assert(battlefield_entry_available(board, board.reserve_units[reserve.get()]), "battlefield unit capacity exceeded or retired return slot occupied")
    let candidate : Unit
    candidate = board.reserve_units[reserve.get()]
    mark_unit_offboard(candidate, false)
    let infiltrates = candidate.all_have_ability(AbilityKind::infiltrators)
    let valid = arrange_setup_candidate(board, candidate, position, kind, infiltrates)
    assert(valid, "setup candidate must satisfy every placement condition")
    let destination = board.units.size()
    if candidate.is_generated_replacement and !candidate.has_return_slot and !board.units.has_capacity():
        let reusable = faction_replacement_slot(board)
        assert(reusable >= 0, "replacement has no safe battlefield slot")
        board.expired_reserves.value.append(board[reusable])
        candidate.has_return_slot = true
        candidate.return_slot = reusable
    if candidate.has_return_slot:
        destination = candidate.return_slot.get()
        board[destination] = candidate
    else:
        board.units.append(candidate)
    board[destination].has_return_slot = false
    board[destination].mark_set_up()
    # Arrival itself does not prohibit shooting/charging. Preserve surviving
    # same-turn Advance/Fall Back restrictions explicitly (pp.33/68–69).
    board[destination].can_shoot = (!candidate.history.fell_back_this_turn or candidate.history.fallback_allows_shooting) and !candidate.history.deck_shooting_locked
    board[destination].can_charge = (!candidate.history.advanced_this_turn or candidate.history.advance_allows_charge) and (!candidate.history.fell_back_this_turn or candidate.history.fallback_allows_charge)
    if kind == MovementKind::ingress:
        board[destination].history.ingress_turn = board.turn_serial.value + 1
        board[destination].history.ingress_used_deep_strike = candidate.all_have_ability(AbilityKind::deep_strike)
        board[destination].history.has_ingressed = true
        board[destination].history.ingress_locked = true
        board[destination].history.selected_move_phase = board.phase_serial.value + 1
        board[destination].history.move_kind = kind
        board[destination].has_moved = true
        # Flyboss triggers on every actual reserve ingress, including alternate
        # ingress callers; prebattle deployment/redeployment is not ingress.
        let arrival : UnitID
        arrival = destination
        faction_after_reserve_arrival(board, arrival)
    board.reserve_units.erase(reserve.get())

# Repositioning preserves effects/history and retires the battlefield slot
# rather than compacting existing targets (pp.68/87). Caller supplies a rule.
fun reposition_unit(Board board, UnitID id) -> Bool:
    if id.get() >= board.units.size() or !has_live_model(board[id]) or !board.reserve_units.has_capacity():
        return false
    # Pending battlefield death hooks cannot be moved outside their resolver.
    # Full off-table reactive effects await supplied faction/transport rules.
    for i in range(board[id].models.size()):
        if board[id][i].destruction_pending:
            return false
    # p.58: leaving the battlefield permanently fails this pending action.
    board[id].interrupt_actions()
    board[id].history.repositioned = true
    board[id].history.strategic_reserve = true
    board[id].has_return_slot = true
    board[id].return_slot = id
    board.reserve_units.append(board[id])
    mark_unit_offboard(board.reserve_units.back(), true)
    board[id].models.clear()
    board[id].destroyed_models.value.clear()
    board[id].attached_units.clear()
    board[id].identity = 0
    board[id].retired = true
    return true

# The round-3 deadline excludes repositioned units; passengers require task
# 16's transport model. Reserve destruction is not battlefield death (p.69).
fun expire_unused_reserves(Board board):
    if board.current_round != 2:
        return
    let i = board.reserve_units.size() - 1
    while i >= 0:
        if board.reserve_units[i].history.strategic_reserve and !board.reserve_units[i].history.has_ingressed and !board.reserve_units[i].history.repositioned:
            expire_carrier_passengers(board, board.reserve_units[i])
            while !board.reserve_units[i].models.empty():
                board.reserve_units[i].remove_model(board.reserve_units[i].models.size() - 1)
            board.expired_reserves.value.append(board.reserve_units[i])
            board.reserve_units.erase(i)
        i = i - 1

# The user explicitly excludes points in public play; only that configuration
# omits the p.68 percentage. Other permissions remain, and point-aware fixtures
# still require known army/passenger costs rather than an invented substitute.
fun strategic_reserve_valid(Board board, Bool player, UnitID id) -> Bool:
    if id.get() >= board.reserve_units.size():
        return false
    ref unit = board.reserve_units[id.get()]
    if unit.owned_by_player1 != player or unit.history.strategic_reserve or unit.has_keyword(Keyword::fortification):
        return false
    if board.armies[int(player)].reserve_budget == ReserveBudgetMode::point_free:
        return true
    if board.battle_points_limit == 0 or !unit.points_known:
        return false
    let passenger_points = passenger_reserve_points(board, unit)
    if passenger_points < 0:
        return false
    let points = unit.points.value + passenger_points
    for i in range(board.reserve_units.size()):
        if board.reserve_units[i].owned_by_player1 == player and board.reserve_units[i].history.strategic_reserve:
            if !board.reserve_units[i].points_known:
                return false
            let reserved_passenger_points = passenger_reserve_points(board, board.reserve_units[i])
            if reserved_passenger_points < 0:
                return false
            points = points + board.reserve_units[i].points.value + reserved_passenger_points
    return 2 * points <= board.battle_points_limit.value

# User instruction: assume a uniform Scouts value and assert mismatches,
# rather than synthesize mixed/duplicate selection. Current model metadata
# is runtime data; constant datasheets must validate this statically (p.84).
fun scouts_values_uniform(Unit unit) -> Bool:
    if unit.empty() or unit[0].scout_distances.empty():
        return false
    let value = unit[0].scout_distances[0].value
    for i in range(unit.models.size()):
        if unit[i].scout_distances.empty():
            return false
        for j in range(unit[i].scout_distances.size()):
            if unit[i].scout_distances[j].value != value:
                return false
    return true

# All models need Scouts; unsupported mixed values fail explicitly under
# the user's uniform-value restriction, not an invented p.78 interpretation.
fun scouts_distance(Unit unit) -> Int:
    if unit.empty():
        return 0
    let override = faction_scouts_override(unit)
    if override >= 0:
        return override
    for i in range(unit.models.size()):
        if unit[i].scout_distances.empty():
            return 0
    assert(scouts_values_uniform(unit), "Scouts values must all be identical")
    return unit[0].scout_distances[0].value

# Orks index PULSE JET MOVE grants traverse-all/horizontal costs, independent ofFLY.
# Flying traversal belongs only to flying models when Take to the Skies was
# chosen; ordinary/desperate permissions still apply to all models (pp.33/71).
fun movement_policy(Unit unit, Model model, MovementKind kind, Bool skies) -> MovementGeometryPolicy:
    let policy : MovementGeometryPolicy
    policy.traverse_enemies = kind == MovementKind::desperate_escape
    # Big Mek Shokk-boosta crosses all models, without granting terrain/FLY.
    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
    faction_prepare_movement_policy(unit, kind, policy)
    if unit.has_ability(AbilityKind::super_heavy_walker) and (kind == MovementKind::normal or kind == MovementKind::advance or kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape):
        policy.traverse_enemies = true
        policy.exclude_titanic = !(kind == MovementKind::desperate_escape)
    if skies and model.has_keyword(Keyword::fly):
        policy.traverse_enemies = true
        policy.traverse_terrain = true
        policy.free_vertical_movement = true
        policy.exclude_titanic = false
    faction_finish_movement_policy(kind, policy)
    return policy

# Orks index Special Move Types/PULSE JET MOVE has its own D6+18 budget.
# Per-model distance, optional fixed scout/surge limit and FLY -2 exception
# (pp.33/71/82/84/87). Random unit M is already rolled by the caller.
fun model_move_budget(Model model, MovementKind kind, Int extra, Int override_m, Bool skies) -> Int:
    let budget = model.profile.movement()
    if override_m > 0:
        budget = override_m - 1
    if kind == MovementKind::scout or kind == MovementKind::surge or kind == MovementKind::pulse_jet:
        return max(0, extra)
    budget = model.effective_movement(budget) + extra
    if skies and !model.has_ability(AbilityKind::hover):
        budget = budget - 2
    return max(0, budget)

# A path may contain several segments but its entire spent distance persists.
# Placement/coherency is checked after the whole unit finishes (pp.12/87).
fun path_distance(Model model, ModelPath path, Bool skies) -> Float:
    let start = model.geometry_position()
    let distance = 0.0
    for i in range(path.points.size()):
        if skies:
            distance = distance + horizontal_length(start, path.points[i].as_geometry_point())
        else:
            distance = distance + segment_length(start, path.points[i].as_geometry_point())
        start = path.points[i].as_geometry_point()
    return distance

# Probe a waypoint against the original model's whole path, without mutating
# shared state or requiring intermediate unit coherency (p.12).
fun waypoint_valid(Board board, Unit original, ModelPath path, BoardPosition position, MovementKind kind, Int extra, Int override_m, Bool skies) -> Bool:
    if path.model.get() >= original.models.size() or path.points.size() >= 16 or !original[path.model].is_alive():
        return false
    ref model = original[path.model]
    let start = model.geometry_position()
    if path.points.size() > 0:
        start = path.points.back().as_geometry_point()
    let finish = geometry_point(position.x.value * MICROMETRES_PER_INCH, position.y.value * MICROMETRES_PER_INCH, start.z.value)
    let policy = movement_policy(original, model, kind, skies)
    let segment = segment_length(start, finish)
    if skies and model.has_keyword(Keyword::fly) or kind == MovementKind::pulse_jet:
        segment = horizontal_length(start, finish)
    # HOVER exempts the unit's maximum distance, not just its bearer (p.82).
    let skies_penalty = skies and !original.has_ability(AbilityKind::hover)
    let budget = model_move_budget(model, kind, extra, override_m, skies_penalty)
    if original.movement_distance_limit.value > 0:
        budget = max(0, original.movement_distance_limit.value - 1 - 2 * int(skies_penalty))
    if path_distance(model, path, skies and model.has_keyword(Keyword::fly) or kind == MovementKind::pulse_jet) + segment > float(budget * MICROMETRES_PER_INCH):
        return false
    return model_segment_valid(board, original, model, start, finish, policy)

# Final after-moving constraints apply to every base. Scout distance uses
# strict >8; ordinary/Fall Back finishes unengaged (pp.12/33/84).
fun movement_finish_valid(Board board, Unit candidate, UnitID slot, MovementKind kind) -> Bool:
    if !unit_placement_valid(board, candidate, slot.get(), true):
        return false
    if board.move_requires_objective and slot.get() == board.constrained_mover.get() and !unit_in_any_objective_range(board, candidate):
        return false
    if kind == MovementKind::scout:
        return separated_from_enemies(board, candidate, slot.get(), 8)
    return true

# Preserve a rigid preset as an editor convenience alongside independent
# paths; validate every member's budget/traversal and final conditions (p.12).
fun translate_move_candidate(Board board, Unit original, Unit candidate, UnitID slot, BoardPosition position, MovementKind kind, Int extra, Int override_m, Bool skies) -> Bool:
    let dx = position.x.value - original[0].position.x.value
    let dy = position.y.value - original[0].position.y.value
    for i in range(original.models.size()):
        if !original[i].is_alive():
            continue
        let x = original[i].position.x.value + dx
        let y = original[i].position.y.value + dy
        if x < 0 or x >= BOARD_WIDTH or y < 0 or y >= BOARD_HEIGHT:
            return false
        let point = make_board_position(x, y)
        let path : ModelPath
        path.model = i
        if !waypoint_valid(board, original, path, point, kind, extra, override_m, skies):
            return false
        candidate[i].position = point
        record_geometry_movement(candidate[i].history, original[i].geometry_position(), candidate[i].geometry_position(), false)
    return complete_move_valid(board, original, candidate, slot, kind, extra)

# Candidate owning copy has one exit so repeated action enumeration remains
# leak-free; illegal formation translations leave the board unchanged (p.12).
fun rigid_move_valid(Board board, Unit original, UnitID slot, BoardPosition position, MovementKind kind, Int extra, Int override_m, Bool skies) -> Bool:
    if original.empty() or slot.get() >= board.units.size():
        return false
    let candidate = original
    let valid = translate_move_candidate(board, original, candidate, slot, position, kind, extra, override_m, skies)
    return valid

# Enforce selection of every eligible friendly battlefield/reserve unit once
# per phase, including the remain-stationary choice (p.32).
fun movement_selection_complete(Board board, Bool player) -> Bool:
    for i in range(board.units.size()):
        if board[i].owned_by_player1 == player and !board[i].has_keyword(Keyword::aircraft) and has_live_model(board[i]) and board[i].history.selected_move_phase != board.phase_serial.value + 1:
            return false
    for i in range(board.reserve_units.size()):
        if board.reserve_units[i].owned_by_player1 == player and has_live_model(board.reserve_units[i]) and board.reserve_units[i].history.selected_move_phase != board.phase_serial.value + 1:
            return false
    return true

# All non-reserved units must deploy; unknown roster costs cannot turn an
# unfinished deployment into unbounded strategic reserves (pp.14/68).
fun deployment_complete(Board board, Bool player) -> Bool:
    for i in range(board.reserve_units.size()):
        if board.reserve_units[i].owned_by_player1 == player and !board.reserve_units[i].history.strategic_reserve:
            return false
    return true

# Scalar arithmetic infrastructure for exact circular-base boundary checks
# (pp.14/69); no owning temporary or suspension is involved.
fun movement_float_max(Float a, Float b) -> Float:
    if a > b:
        return a
    return b

# Aircraft do not provide surge targets. Tie choices stay with the controller
# and use nearest live circular bases, not unit anchors (pp.70/74; supplied
# Closest Model/Unit definition).
fun surge_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    if source.get() >= board.units.size() or target.get() >= board.units.size() or !has_live_model(board[target]) or board[source].owned_by_player1 == board[target].owned_by_player1 or board[target].has_keyword(Keyword::aircraft):
        return false
    let distance = live_unit_distance(board[source], board[target])
    for i in range(board.units.size()):
        if board[i].owned_by_player1 != board[source].owned_by_player1 and has_live_model(board[i]) and !board[i].has_keyword(Keyword::aircraft) and live_unit_distance(board[source], board[i]) < distance:
            return false
    return true

# Dead retained models are not members for closest-unit selection (pp.70/87).
fun live_unit_distance(Unit a, Unit b) -> Float:
    let closest = 1000000000.0
    for i in range(a.models.size()):
        for j in range(b.models.size()):
            if a[i].is_alive() and b[j].is_alive() and a[i].distance(b[j]) < closest:
                closest = a[i].distance(b[j])
    return closest

# Surge ends engaged if possible, otherwise as close as possible; zero score
# expresses the engagement obligation, not centre-distance zero (p.70).
fun surge_model_score(Model model, Unit target) -> Float:
    let score = 1000000000.0
    for i in range(target.models.size()):
        if target[i].is_alive():
            if model.is_engaged_with(target[i]):
                return 0.0
            if model.distance(target[i]) < score:
                score = model.distance(target[i])
    return score

# Every final model must be legal and no model may engage another unit.
# Candidate owning state has one exit for sanitizer-safe probes (pp.12/70).
fun surge_position_score(Board board, Unit final_unit, UnitID source, ModelID model, BoardPosition position, UnitID target) -> Float:
    let candidate = final_unit
    candidate[model].position = position
    let score = 1000000000.0
    let valid = unit_placement_valid(board, candidate, source.get(), false)
    for i in range(board.units.size()):
        if i != target.get() and board[i].owned_by_player1 != candidate.owned_by_player1 and candidate.is_engaged_with(board[i]):
            valid = false
    if valid:
        score = surge_model_score(candidate[model], board[target])
    return score

# Shortest routes over the retained whole-inch waypoint domain form a finite
# visibility graph. Straight edges account for base clearance and real length;
# using only adjacent squares would overcharge non-45-degree paths (pp.12/70).
# Other final models stay fixed while checking this model's possible endpoints.
fun best_surge_score(Board board, Unit original, Unit final_unit, UnitID source, ModelID model, UnitID target, Int budget) -> Float:
    let distances : Float[1320]
    let visited : Bool[1320]
    for i in range(1320):
        distances[i] = 1000000000.0
    ref moving = original[model]
    let origin = moving.position.x.value * BOARD_HEIGHT + moving.position.y.value
    distances[origin] = 0.0
    let best = 1000000000.0
    let policy : MovementGeometryPolicy
    let maximum = float(budget * MICROMETRES_PER_INCH)
    for iteration in range(1320):
        let next = -1
        let nearest = 1000000000.0
        for i in range(1320):
            if !visited[i] and distances[i] <= maximum and distances[i] < nearest:
                nearest = distances[i]
                next = i
        if next < 0:
            break
        visited[next] = true
        let position = make_board_position(next / BOARD_HEIGHT, next % BOARD_HEIGHT)
        let score = surge_position_score(board, final_unit, source, model, position, target)
        if score < best:
            best = score
        if best == 0.0:
            break
        let start = geometry_point(position.x.value * MICROMETRES_PER_INCH, position.y.value * MICROMETRES_PER_INCH, moving.geometry_position().z.value)
        for i in range(1320):
            if !visited[i]:
                let finish = geometry_point((i / BOARD_HEIGHT) * MICROMETRES_PER_INCH, (i % BOARD_HEIGHT) * MICROMETRES_PER_INCH, start.z.value)
                let distance = nearest + segment_length(start, finish)
                if distance <= maximum and distance < distances[i] and model_segment_valid(board, original, moving, start, finish, policy):
                    distances[i] = distance
    return best

# Check each final model against legal reachable endpoints given the other
# models' chosen final positions; no closer legal replacement can be skipped.
# This finite-grid obligation preserves coherence and no incidental engagement
# (pp.12/70); simultaneous multi-model rearrangement optimization is not used.
fun surge_goals_valid(Board board, Unit original, Unit final_unit, UnitID source, Int budget) -> Bool:
    for i in range(final_unit.models.size()):
        if final_unit[i].is_alive():
            let model : ModelID
            model = i
            let score = surge_model_score(final_unit[i], board[board.surge_target])
            if score > 0.0 and score > best_surge_score(board, original, final_unit, source, model, board.surge_target, budget) + 0.000001:
                return false
    return true

# General final-placement validation first, then surge's chosen target and
# per-model approach obligation (pp.12/70). Other moves use ordinary checks.
fun complete_move_valid(Board board, Unit original, Unit candidate, UnitID slot, MovementKind kind, Int extra) -> Bool:
    if kind == MovementKind::surge:
        if !unit_placement_valid(board, candidate, slot.get(), false):
            return false
        for i in range(board.units.size()):
            if i != board.surge_target.get() and board[i].owned_by_player1 != candidate.owned_by_player1 and candidate.is_engaged_with(board[i]):
                return false
        return surge_goals_valid(board, original, candidate, slot, extra)
    return movement_finish_valid(board, candidate, slot, kind)

# A triggered surge cannot suspend at a target decision if no non-Aircraft
# enemy exists; the move cannot be made without its required target (pp.33/70).
fun has_surge_target(Board board, UnitID source) -> Bool:
    for i in range(board.units.size()):
        let target : UnitID
        target = i
        if surge_target_valid(board, source, target):
            return true
    return false

# Search coherent whole-quad presets against the complete setup rule, not
# battlefield bounds alone. A legal alternative must not be hidden behind
# the first coherent preset; callers commit this exact candidate (pp.12/14).
fun arrange_setup_candidate(Board board, Unit candidate, BoardPosition anchor, MovementKind kind, Bool infiltrates) -> Bool:
    let valid = false
    let columns = 1
    while columns <= candidate.models.size() and !valid:
        if candidate.arrange_candidate_columns(anchor, columns):
            valid = setup_rules_valid(board, candidate, kind, infiltrates)
        columns = columns + 1
    return valid

# User direction: destroy deployment units that cannot be placed, rather
# than restarting placement or manufacturing strategic-reserve permission.
# Search the supported whole-grid presets, including every-base restrictions.
fun deployment_has_position(Board board, Unit unit) -> Bool:
    let candidate : Unit
    candidate = unit
    # Search the prospective battlefield geometry, just as setup_at_valid does
    # (p.14; offboard visibility/distance appendix 01.02.04).
    mark_unit_offboard(candidate, false)
    let valid = deployment_candidate_has_position(board, unit, candidate)
    return valid

# Search reuses caller-owned staging without constructing an owning loop local;
# this changes copy cost, not every-base placement legality (pp.14/84).
fun deployment_candidate_has_position(Board board, Unit unit, Unit candidate) -> Bool:
    let infiltrates = unit.all_have_ability(AbilityKind::infiltrators)
    let valid = false
    let x = 0
    while x < BOARD_WIDTH and !valid:
        let y = 0
        while y < BOARD_HEIGHT and !valid:
            let anchor = make_board_position(x, y)
            if setup_anchor_possible(unit, anchor, MovementKind::normal, infiltrates):
                valid = arrange_setup_candidate(board, candidate, anchor, MovementKind::normal, infiltrates)
            y = y + 1
        x = x + 1
    return valid

# User-directed setup failure destruction; preserve identities and casualties
# in the off-table archive. No battlefield death position is fabricated.
fun destroy_unplaceable_reserve(Board board, UnitID id):
    assert(id.get() < board.reserve_units.size(), "invalid undeployable reserve")
    expire_carrier_passengers(board, board.reserve_units[id.get()])
    while !board.reserve_units[id.get()].models.empty():
        board.reserve_units[id.get()].remove_model(board.reserve_units[id.get()].models.size() - 1)
    board.expired_reserves.value.append(board.reserve_units[id.get()])
    board.reserve_units.erase(id.get())

# Replay accepted waypoints into bounded segment history, preserving exact
# diagonal lengths without a stored float total (p.12 / user requirement).
fun record_path_movement(ModelHistory history, Model original, ModelPath path, Bool skies):
    let start = original.geometry_position()
    for i in range(path.points.size()):
        record_geometry_movement(history, start, path.points[i].as_geometry_point(), skies and original.has_keyword(Keyword::fly))
        start = path.points[i].as_geometry_point()

# All Aircraft must reserve during formations, irrespective of voluntary
# player choices (23.01 p.74). No unknown points are invented by this rule.
fun reserve_aircraft_for_formations(Board board):
    for aircraft_index in range(board.reserve_units.size()):
        if board.reserve_units[aircraft_index].has_keyword(Keyword::aircraft):
            board.reserve_units[aircraft_index].history.strategic_reserve = true

# The opponent's turn end returns surviving Aircraft to reserves (23.02 p.74).
# Repositioning retains identity and persisting effects (appendix 01.02.02).
fun return_opponent_aircraft(Board board):
    for aircraft_slot in range(board.units.size()):
        if board[aircraft_slot].owned_by_player1 != board.current_player and board[aircraft_slot].has_keyword(Keyword::aircraft) and has_live_model(board[aircraft_slot]):
            let aircraft_id : UnitID
            aircraft_id = aircraft_slot
            assert(reposition_unit(board, aircraft_id), "Aircraft return requires reserve capacity and completed destruction cleanup")


# Restore the same retired slot on reserve return; repeated Aircraft ingress
# must not allocate unbounded unit slots or redirect persistent handles (p.74).
fun battlefield_entry_available(Board board, Unit unit) -> Bool:
    if unit.has_return_slot:
        return unit.return_slot.get() < board.units.size() and board[unit.return_slot].retired and board[unit.return_slot].empty()
    return board.units.has_capacity() or (unit.is_generated_replacement and faction_replacement_slot(board) >= 0)
