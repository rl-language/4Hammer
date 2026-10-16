import movement_rules

# Transport type/capacity are datasheet permissions on each model (18.01 p.64).
# Explicit known metadata prevents legacy fixtures from inventing permissions.
fun passenger_model_permitted(Model carrier, Model passenger) -> Bool:
    if !carrier.transport_permissions_known or carrier.transport_capacity.value == 0 or !carrier.has_keyword(Keyword::transport):
        return false
    if !passenger_requirements_match(carrier, passenger):
        return false
    let permitted = carrier.permitted_passenger_keywords.empty()
    for permission in range(carrier.permitted_passenger_keywords.size()):
        permitted = permitted or passenger.has_keyword(carrier.permitted_passenger_keywords[permission])
    for exclusion in range(carrier.forbidden_passenger_keywords.size()):
        if passenger.has_keyword(carrier.forbidden_passenger_keywords[exclusion]):
            permitted = false
    return permitted

# Stable carrier identity survives model compaction/reserve round trips;
# passenger membership belongs to a TRANSPORT model, not its unit (p.64).
# Gretchin Downtrodden rounds pairs once per passenger unit (Orks/Gretchin);
# attached Characters retain ordinary seats. Core pp69-70 still limits cargo.
fun passenger_space_used(Board board, EntityIdentity carrier) -> Int:
    let occupied = 0
    for passenger_index in range(board.embarked_units.size()):
        if board.embarked_units[passenger_index].embarked_transport == carrier:
            occupied = occupied + passenger_space(board.embarked_units[passenger_index])
    return occupied

# Entire friendly units embark; no partial unit can exceed per-model capacity
# or evade datasheet passenger permissions (18.01–18.02 p.64).
fun transport_can_carry(Board board, Unit passenger, Unit carrier_unit, Int carrier_model) -> Bool:
    if passenger.empty() or carrier_model < 0 or carrier_model >= carrier_unit.models.size() or passenger.owned_by_player1 != carrier_unit.owned_by_player1 or passenger.identity == carrier_unit.identity or !carrier_unit[carrier_model].is_alive() or !board.embarked_units.has_capacity():
        return false
    let required = passenger_space_used(board, carrier_unit[carrier_model].identity) + passenger_space(passenger)
    for model_index in range(passenger.models.size()):
        if !passenger_model_permitted(carrier_unit[carrier_model], passenger[model_index]):
            return false
    if required > carrier_unit[carrier_model].transport_capacity.value:
        return false
    # User directs us to assume a transport never embarks into another
    # transport. Assert only after ordinary datasheet/capacity rejection, so
    # enumerating forbidden passenger types remains safe (18.01 p.64).
    for checked_passenger in range(passenger.models.size()):
        assert(!passenger[checked_passenger].has_keyword(Keyword::transport), "nested transports are excluded by the user assumption")
    return true

# Post-move embarkation requires every base within3in, a permitted actual
# move this phase, and no setup this turn (18.02 p.64). Stationary is excluded.
fun embark_after_move_valid(Board board, UnitID passenger, UnitID carrier, ModelID model) -> Bool:
    if passenger.get() >= board.units.size() or carrier.get() >= board.units.size() or board.prebattle_scouts or board.timing.phase == BattlePhase::none or board[passenger].off_battlefield or board[carrier].off_battlefield or board[passenger].history.was_set_up_this_turn or board[passenger].history.last_move_phase != board.phase_serial.value + 1:
        return false
    if !transport_can_carry(board, board[passenger], board[carrier], model.get()):
        return false
    let kind = board[passenger].history.move_kind
    if !(kind == MovementKind::normal or kind == MovementKind::advance or kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape):
        return false
    for member in range(board[passenger].models.size()):
        if board[passenger][member].history.was_set_up_this_turn or board[passenger][member].distance(board[carrier][model]) > 3.0:
            return false
    return true

# Offboard flag is transient damage/setup infrastructure; the passenger bank
# itself prevents ordinary battlefield selection and geometry (appendix01.02.04).
fun mark_unit_offboard(Unit unit, Bool offboard):
    unit.off_battlefield = offboard
    for offboard_model in range(unit.models.size()):
        unit[offboard_model].off_battlefield = offboard

# Transfer preserves histories, One Shot usage and durations. Leaving play
# interrupts mission actions (p.58; transport p.64; appendix01.02.02).
fun embark_battlefield_unit(Board board, UnitID passenger, UnitID carrier, ModelID model):
    assert(embark_after_move_valid(board, passenger, carrier, model), "illegal embarkation")
    transfer_embarked_unit(board, passenger, board[carrier][model].identity)

# Common whole-unit bank transfer for normal embarkation and an explicit
# faction exception (Keep It Runnin'). Each caller validates its own window,
# range/capacity; p64 and appendix01.02.02 require histories to survive.
fun transfer_embarked_unit(Board board, UnitID passenger, EntityIdentity carrier):
    assert(board.embarked_units.has_capacity(), "passenger bank capacity exceeded")
    board[passenger].interrupt_actions()
    board[passenger].embarked_transport = carrier
    board[passenger].history.embarked_phase = board.phase_serial.value + 1
    board[passenger].has_return_slot = true
    board[passenger].return_slot = passenger
    mark_unit_offboard(board[passenger], true)
    board.embarked_units.append(board[passenger])
    board[passenger].models.clear()
    board[passenger].destroyed_models.value.clear()
    board[passenger].attached_units.clear()
    board[passenger].identity = 0
    board[passenger].embarked_transport = 0
    board[passenger].retired = true
    register_faction_cargo_passives(board)

# Prebattle passengers use the same whole-unit permission checks without a
# battlefield move/range requirement (18.01 p.64). Resolve carrier before erase.
fun embark_formation_unit(Board board, UnitID passenger, UnitID carrier, ModelID model):
    assert(passenger.get() < board.reserve_units.size() and carrier.get() < board.reserve_units.size(), "invalid formation unit")
    assert(transport_can_carry(board, board.reserve_units[passenger.get()], board.reserve_units[carrier.get()], model.get()), "illegal formation embarkation")
    board.reserve_units[passenger.get()].embarked_transport = board.reserve_units[carrier.get()][model].identity
    mark_unit_offboard(board.reserve_units[passenger.get()], true)
    board.embarked_units.append(board.reserve_units[passenger.get()])
    board.reserve_units.erase(passenger.get())
    register_faction_cargo_passives(board)

# Circle fixtures use farthest passenger-base point to nearest carrier-base
# point, preserving 3D range and whole-inch stored coordinates (18.04 p.65;
# supplied Wholly Within). Minimal base-to-base range would be insufficient.
fun passenger_wholly_within(Model passenger, Model carrier, Int inches) -> Bool:
    let horizontal = horizontal_length(passenger.geometry_position(), carrier.geometry_position()) + passenger.base_radius_micrometres() - carrier.base_radius_micrometres()
    if horizontal < 0.0:
        horizontal = 0.0
    let vertical = float(passenger.geometry_position().z.value - carrier.geometry_position().z.value)
    let distance = float(inches * MICROMETRES_PER_INCH)
    return horizontal * horizontal + vertical * vertical <= distance * distance

# Resolve carrier models by persistent identity, rather than compacted indices
# (18.01 p.64). Reserve carriers deliberately cannot disembark passengers.
cls CarrierLocation:
    Bool found
    Bool reserve
    UnitID unit
    ModelID model

# A passenger's carrier can be on the battlefield or in strategic reserves
# (18.01/20.01 pp.64/68); it is never independently selected to ingress.
fun find_passenger_carrier(Board board, EntityIdentity identity) -> CarrierLocation:
    let result : CarrierLocation
    if identity.value > 0:
        for battlefield_carrier in range(board.units.size()):
            let battlefield_model = board[battlefield_carrier].find_model(identity)
            if battlefield_model >= 0:
                result.found = true
                result.unit = battlefield_carrier
                result.model = battlefield_model
        for reserve_carrier in range(board.reserve_units.size()):
            let reserve_model = board.reserve_units[reserve_carrier].find_model(identity)
            if reserve_model >= 0:
                result.found = true
                result.reserve = true
                result.unit = reserve_carrier
                result.model = reserve_model
    return result

# The explicit predicate supports search and final setup with the same kernel
# (18.04–18.05 p.65), without using stale passenger-bank coordinates.
fun transport_model_position_valid(Board board, Unit candidate, Int member, Model carrier, DisembarkMode mode, Int ignored_slot, Int placed) -> Bool:
    ref passenger = candidate[member]
    let inches = 3
    if mode == DisembarkMode::combat or mode == DisembarkMode::emergency:
        inches = 6
    if !passenger_wholly_within(passenger, carrier, inches) or !model_placement_valid(board, passenger):
        return false
    for occupied in range(placed):
        if occupied != member and model_bases_overlap(passenger, candidate[occupied]):
            return false
    for other_unit in range(board.units.size()):
        if other_unit != ignored_slot and !board[other_unit].off_battlefield:
            for other_model in range(board[other_unit].models.size()):
                if model_bases_overlap(passenger, board[other_unit][other_model]):
                    return false
                if board[other_unit].owned_by_player1 != candidate.owned_by_player1 and board[other_unit][other_model].is_alive() and passenger.is_engaged_with(board[other_unit][other_model]):
                    if !(mode == DisembarkMode::combat):
                        return false
                    if !carrier.is_engaged_with(board[other_unit][other_model]):
                        # The allowance is enemy-unit membership, not the same
                        # enemy model being engaged with the carrier (p.65).
                        let carrier_engaged = false
                        for engaged_model in range(board[other_unit].models.size()):
                            carrier_engaged = carrier_engaged or (board[other_unit][engaged_model].is_alive() and carrier.is_engaged_with(board[other_unit][engaged_model]))
                        if !carrier_engaged:
                            return false
    return true

# General coherence and each model's setup constraints are checked only on
# complete formations (pp.14/65). Rapid copies the carrier's actual ingress
# restrictions, never the passenger's own Deep Strike permission.
fun transport_setup_valid(Board board, Unit candidate, CarrierLocation location, DisembarkMode mode, Int ignored_slot) -> Bool:
    if !location.found or location.reserve or candidate.empty() or !candidate.is_coherent():
        return false
    ref carrier = board[location.unit][location.model]
    for passenger_index in range(candidate.models.size()):
        if !transport_model_position_valid(board, candidate, passenger_index, carrier, mode, ignored_slot, candidate.models.size()):
            return false
    if mode == DisembarkMode::rapid and board[location.unit].history.ingress_turn == board.turn_serial.value + 1:
        if !separated_from_enemies(board, candidate, ignored_slot, 8):
            return false
        if !board[location.unit].history.ingress_used_deep_strike:
            for ingress_model in range(candidate.models.size()):
                if !model_in_edge_strip(candidate[ingress_model]) or (board.current_round < 2 and model_distance_to_home_zone(candidate[ingress_model], !candidate.owned_by_player1) == 0.0):
                    return false
    return true

# Exact finite grid search tests existence, so Tactical is not falsely denied
# because one rectangular preset fails (18.04 p.65). This ordinary function
# recursion does not create recursive action frames. Same-size models may be
# ordered lexically because their placement permissions are identical here.
fun search_transport_setup(Board board, Unit candidate, CarrierLocation location, DisembarkMode mode, Int ignored_slot, Int depth) -> Bool:
    if depth == candidate.models.size():
        return transport_setup_valid(board, candidate, location, mode, ignored_slot)
    ref carrier = board[location.unit][location.model]
    let old_position = candidate[depth].position
    let old_elevation = candidate[depth].geometry.elevation
    let result = false
    let radius = 6
    if mode == DisembarkMode::rapid or mode == DisembarkMode::tactical:
        radius = 3
    let reach = radius + int(carrier.base_radius_micrometres() / float(MICROMETRES_PER_INCH)) + 1
    for height in range(board.terrain_geometry.size() + 1):
        if result:
            break
        let elevation = 0
        if height > 0:
            elevation = board.terrain_geometry[height - 1].upper.z.value
        if abs(elevation - carrier.geometry.elevation.value) > radius:
            continue
        candidate[depth].geometry.elevation = elevation
        for grid_y in range(min(BOARD_HEIGHT, carrier.position.y.value + reach + 1)):
            if grid_y < max(1, carrier.position.y.value - reach):
                continue
            if result:
                break
            for grid_x in range(min(BOARD_WIDTH, carrier.position.x.value + reach + 1)):
                if grid_x < max(1, carrier.position.x.value - reach):
                    continue
                if result:
                    break
                # Equal footprints have identical spatial constraints; avoid
                # equivalent permutations without restricting heterogeneous bases.
                if depth > 0 and candidate[depth].base_radius_micrometres() == candidate[depth - 1].base_radius_micrometres() and candidate[depth].geometry.elevation == candidate[depth - 1].geometry.elevation:
                    if grid_y * BOARD_WIDTH + grid_x <= candidate[depth - 1].position.y.value * BOARD_WIDTH + candidate[depth - 1].position.x.value:
                        continue
                candidate[depth].position = make_board_position(grid_x, grid_y)
                if transport_model_position_valid(board, candidate, depth, carrier, mode, ignored_slot, depth) and search_transport_setup(board, candidate, location, mode, ignored_slot, depth + 1):
                    result = true
    if !result:
        candidate[depth].position = old_position
        candidate[depth].geometry.elevation = old_elevation
    return result

# Owning candidate staging has one exit for sanitizer-safe cleanup. All
# arithmetic is temporary; persisted positions stay bounded quads (p.65).
fun transport_has_setup(Board board, Unit passenger, CarrierLocation carrier, DisembarkMode mode, Int ignored_slot) -> Bool:
    let candidate = passenger
    mark_unit_offboard(candidate, false)
    let result = false
    if carrier.found and !carrier.reserve:
        result = search_transport_setup(board, candidate, carrier, mode, ignored_slot, 0)
    return result

# Same-phase embark and carrier Advance/Fall Back prohibit ordinary exit;
# the active player's Movement phase is required (18.03–18.04 pp.64–65).
fun passenger_can_disembark(Board board, UnitID passenger) -> Bool:
    if passenger.get() >= board.embarked_units.size() or !(board.timing.phase == BattlePhase::movement) or board.embarked_units[passenger.get()].owned_by_player1 != board.current_player or board.embarked_units[passenger.get()].history.embarked_phase == board.phase_serial.value + 1:
        return false
    let location = find_passenger_carrier(board, board.embarked_units[passenger.get()].embarked_transport)
    if !location.found or location.reserve or !board[location.unit][location.model].is_alive():
        return false
    ref carrier_unit = board[location.unit]
    return carrier_unit.history.selected_move_phase != board.phase_serial.value + 1 or !(carrier_unit.history.move_kind == MovementKind::advance or carrier_unit.history.move_kind == MovementKind::ordered_retreat or carrier_unit.history.move_kind == MovementKind::desperate_escape)

# Rapid has priority after Normal/Ingress; otherwise Tactical is compulsory
# if a legal grid formation exists, then Combat (18.04 p.65).
fun required_disembark_mode(Board board, Unit passenger, CarrierLocation carrier) -> DisembarkMode:
    assert(carrier.found and !carrier.reserve, "disembark requires battlefield carrier")
    ref carrier_unit = board[carrier.unit]
    if carrier_unit.history.selected_move_phase == board.phase_serial.value + 1 and (carrier_unit.history.move_kind == MovementKind::normal or carrier_unit.history.move_kind == MovementKind::ingress):
        if faction_assault_disembark(board, carrier_unit):
            return DisembarkMode::assault
        return DisembarkMode::rapid
    if (carrier_unit.history.selected_move_phase != board.phase_serial.value + 1 or carrier_unit.history.move_kind == MovementKind::stationary) and transport_has_setup(board, passenger, carrier, DisembarkMode::tactical, -1):
        return DisembarkMode::tactical
    return DisembarkMode::combat

# Transfer into a reserved stable slot, temporarily offboard during hazard
# damage. Its identity/history survives both the bank and resolver (p.65).
fun stage_disembarking_passenger(Board board, UnitID passenger) -> UnitID:
    assert(passenger.get() < board.embarked_units.size(), "invalid passenger")
    assert(battlefield_entry_available(board, board.embarked_units[passenger.get()]), "no passenger battlefield slot")
    let destination = board.units.size()
    if board.embarked_units[passenger.get()].has_return_slot:
        destination = board.embarked_units[passenger.get()].return_slot.get()
        board[destination] = board.embarked_units[passenger.get()]
    else:
        board.units.append(board.embarked_units[passenger.get()])
    board[destination].has_return_slot = false
    board.embarked_units.erase(passenger.get())
    let result : UnitID
    result = destination
    return result

# Successful exit counts as setup and interrupts actions; no transfer clears
# persisting effects. Mode-specific restrictions last until turn end (p.65,
# action p.58, supplied appendix01.02.02).
fun finish_disembark(Board board, UnitID passenger, DisembarkMode mode):
    mark_unit_offboard(board[passenger], false)
    board[passenger].embarked_transport = 0
    refresh_source_effects(board, TimingWindow::none)
    board[passenger].interrupt_actions()
    board[passenger].mark_set_up()
    board[passenger].history.disembarked_this_turn = true
    board[passenger].history.made_move_this_turn = true
    board[passenger].history.last_move_phase = board.phase_serial.value + 1
    board[passenger].history.move_kind = MovementKind::disembark
    if mode == DisembarkMode::emergency:
        board[passenger].history.move_kind = MovementKind::emergency_disembark
    board[passenger].history.tactical_move_required = mode == DisembarkMode::tactical
    if !(mode == DisembarkMode::tactical):
        board[passenger].can_charge = mode == DisembarkMode::assault
        board[passenger].history.selected_move_phase = board.phase_serial.value + 1
    if mode == DisembarkMode::combat or mode == DisembarkMode::emergency:
        board[passenger].battle_socked = true

# Cheap carrier presence gates keep legacy armies' action sequence unchanged
# while actual permissions remain unavailable (18.01 p.64, datasheets task17).
fun has_formation_transport(Board board, Bool player) -> Bool:
    let found = false
    for formation_unit in range(board.reserve_units.size()):
        if board.reserve_units[formation_unit].owned_by_player1 == player:
            for formation_model in range(board.reserve_units[formation_unit].models.size()):
                found = found or (board.reserve_units[formation_unit][formation_model].transport_permissions_known and board.reserve_units[formation_unit][formation_model].transport_capacity.value > 0)
    return found

# A post-move decision is exposed only when some legal carrier exists (p.64).
fun has_embark_choice(Board board, UnitID passenger) -> Bool:
    let carrier : UnitID
    let model : ModelID
    let found = false
    for unit_index in range(board.units.size()):
        carrier = unit_index
        for model_index in range(board[unit_index].models.size()):
            model = model_index
            found = found or embark_after_move_valid(board, passenger, carrier, model)
    return found

# Ordinary exit cannot commit a mode with no legal supported setup (pp.14/65).
# Emergency instead resolves individual placement failures after hazards.
fun ordinary_disembark_valid(Board board, UnitID passenger) -> Bool:
    let valid = false
    if passenger_can_disembark(board, passenger) and battlefield_entry_available(board, board.embarked_units[passenger.get()]):
        let carrier = find_passenger_carrier(board, board.embarked_units[passenger.get()].embarked_transport)
        let mode = required_disembark_mode(board, board.embarked_units[passenger.get()], carrier)
        valid = transport_has_setup(board, board.embarked_units[passenger.get()], carrier, mode, -1)
    return valid

# Rectangular presets remain convenience choices; validate exactly the same
# full-base/coherency/ingress conditions as independent model setup (p.65).
fun arrange_transport_candidate(Board board, Unit candidate, CarrierLocation carrier, DisembarkMode mode, Int ignored_slot, BoardPosition position) -> Bool:
    let valid = false
    for columns in range(candidate.models.size() + 1):
        if columns > 0 and !valid and candidate.arrange_candidate_columns(position, columns):
            valid = transport_setup_valid(board, candidate, carrier, mode, ignored_slot)
    return valid

# Owning-copy precondition has one exit so enumeration releases storage (p.65).
fun transport_preset_valid(Board board, Unit passenger, CarrierLocation carrier, DisembarkMode mode, Int ignored_slot, BoardPosition position) -> Bool:
    let candidate = passenger
    mark_unit_offboard(candidate, false)
    let valid = arrange_transport_candidate(board, candidate, carrier, mode, ignored_slot, position)
    return valid

# Independent model choices cannot finish until every passenger was placed
# (Set Up pp.14/65). Selection metadata uses a fixed Bool array.
fun all_models_selected(Unit unit, Bool[MAX_UNIT_MODELS] selected) -> Bool:
    let complete = true
    for selection_index in range(unit.models.size()):
        complete = complete and selected[selection_index]
    return complete

# A staged input is range/terrain/enemy legal before acceptance; unit coherence
# and other staged bases are checked at final commit (18.04 p.65).
fun disembark_model_input_valid(Board board, Unit unit, CarrierLocation carrier, DisembarkMode mode, Int ignored, ModelID model, BoardPosition point) -> Bool:
    let candidate = unit
    candidate[model].position = point
    let valid = transport_model_position_valid(board, candidate, model.get(), board[carrier.unit][carrier.model], mode, ignored, 0)
    return valid

# Emergency placement must keep every model that can be set up. Search the
# largest coherent subset when the whole unit cannot fit, so a bad preset or
# model order cannot destroy an otherwise placeable unit (18.05 p.65).
fun search_emergency_subset(Board board, Unit original, Unit candidate, CarrierLocation carrier, Int ignored, Int desired, Int next, Int selected) -> Bool:
    if selected == desired:
        return search_transport_setup(board, candidate, carrier, DisembarkMode::emergency, ignored, 0)
    if original.models.size() - next < desired - selected:
        return false
    let result = false
    let original_index = next
    while original_index < original.models.size() and !result:
        candidate.models.append(original[original_index])
        candidate.models.back().off_battlefield = false
        result = search_emergency_subset(board, original, candidate, carrier, ignored, desired, original_index + 1, selected + 1)
        if !result:
            candidate.models.pop()
        original_index = original_index + 1
    return result

# The closest possible endpoint is evaluated with other final bases fixed,
# matching the existing quad movement convention (18.05 p.65). Repeated strict
# improvements terminate on this finite grid; no Float is persisted.
fun move_emergency_models_closer(Board board, Unit candidate, CarrierLocation carrier, Int ignored):
    let improved = true
    while improved:
        improved = false
        for emergency_model in range(candidate.models.size()):
            let closest = candidate[emergency_model].distance(board[carrier.unit][carrier.model])
            let best = candidate[emergency_model].position
            let best_elevation = candidate[emergency_model].geometry.elevation
            for surface in range(board.terrain_geometry.size() + 1):
                let height = 0
                if surface > 0:
                    height = board.terrain_geometry[surface - 1].upper.z.value
                candidate[emergency_model].geometry.elevation = height
                for close_y in range(BOARD_HEIGHT):
                    if close_y == 0:
                        continue
                    for close_x in range(BOARD_WIDTH):
                        if close_x == 0:
                            continue
                        candidate[emergency_model].position = make_board_position(close_x, close_y)
                        let distance = candidate[emergency_model].distance(board[carrier.unit][carrier.model])
                        if distance < closest and transport_setup_valid(board, candidate, carrier, DisembarkMode::emergency, ignored):
                            closest = distance
                            best = candidate[emergency_model].position
                            best_elevation = candidate[emergency_model].geometry.elevation
                            improved = true
            candidate[emergency_model].position = best
            candidate[emergency_model].geometry.elevation = best_elevation

# Candidate ownership has one exit. Whole-unit feasibility is tried before
# descending survivor counts; zero survivors explicitly means destruction,
# never an unfinishable placement action (18.05 p.65; user setup policy).
fun arrange_emergency_survivors(Board board, Unit original, Unit candidate, CarrierLocation carrier, Int ignored):
    candidate = original
    mark_unit_offboard(candidate, false)
    let desired = original.models.size()
    let found = false
    while desired > 0 and !found:
        candidate.models.clear()
        found = search_emergency_subset(board, original, candidate, carrier, ignored, desired, 0, 0)
        if !found:
            desired = desired - 1
    if !found:
        candidate.models.clear()
    else:
        move_emergency_models_closer(board, candidate, carrier, ignored)

# Destruction retention also applies to a carrier whose only trigger is its
# required emergency exit (18.03 pp.64–65), before removal/Deadly Demise.
fun carrier_has_passengers(Board board, EntityIdentity carrier) -> Bool:
    let has_passengers = false
    for bank_index in range(board.embarked_units.size()):
        has_passengers = has_passengers or board.embarked_units[bank_index].embarked_transport == carrier
    return has_passengers

# Reserved carrier passengers count toward the same 50% army points cap;
# costs must be supplied for every counted unit (20.01 p.68).
fun passenger_reserve_points(Board board, Unit carrier) -> Int:
    let points = 0
    for counted_passenger in range(board.embarked_units.size()):
        if carrier.find_model(board.embarked_units[counted_passenger].embarked_transport) >= 0:
            if !board.embarked_units[counted_passenger].points_known:
                return -1
            points = points + board.embarked_units[counted_passenger].points.value
    return points

# Never-arrived passengers share their carrier's round-three destruction;
# they cannot independently ingress or survive its reserve expiry (p.68–69).
fun expire_carrier_passengers(Board board, Unit carrier):
    let passenger_index = board.embarked_units.size() - 1
    while passenger_index >= 0:
        if carrier.find_model(board.embarked_units[passenger_index].embarked_transport) >= 0:
            while !board.embarked_units[passenger_index].models.empty():
                board.embarked_units[passenger_index].remove_model(board.embarked_units[passenger_index].models.size() - 1)
            board.embarked_units[passenger_index].embarked_transport = 0
            board.expired_reserves.value.append(board.embarked_units[passenger_index])
            board.embarked_units.erase(passenger_index)
        passenger_index = passenger_index - 1

# A dedicated transport wholly in its deployment zone inherits Scouts only
# when every embarked model has it (24.31 p.84). User requires uniform values;
# no unsupported mixture is resolved by guessing a minimum/maximum.
fun transport_scouts_distance(Board board, Unit unit) -> Int:
    let own_distance = scouts_distance(unit)
    if own_distance > 0:
        return own_distance
    if !unit.has_keyword(Keyword::dedicated_transport) or !unit_in_home_zone(unit, unit.owned_by_player1):
        return 0
    let shared = 0
    let found_passenger = false
    let eligible = true
    for scouting_passenger in range(board.embarked_units.size()):
        if unit.find_model(board.embarked_units[scouting_passenger].embarked_transport) >= 0:
            found_passenger = true
            let distance = scouts_distance(board.embarked_units[scouting_passenger])
            eligible = eligible and distance > 0
            if shared > 0 and distance > 0:
                assert(shared == distance, "Scouts values must all be identical")
            if distance > 0:
                shared = distance
    if !found_passenger or !eligible:
        return 0
    return shared

# Save-load validation rejects dangling/foreign carrier links and overfilled
# models before such state can strand an action (capacity p.64). This is
# implementation infrastructure, not an extra tabletop rule.
fun valid_passenger_links(Board board) -> Bool:
    let return_slots : Bool[MAX_UNIT_COUNT]
    for reserved_slot in range(board.reserve_units.size()):
        if board.reserve_units[reserved_slot].has_return_slot:
            let return_index = board.reserve_units[reserved_slot].return_slot.get()
            if return_index >= board.units.size() or !board[return_index].retired or !board[return_index].empty() or return_slots[return_index]:
                return false
            return_slots[return_index] = true
    for validated_passenger in range(board.embarked_units.size()):
        ref passenger = board.embarked_units[validated_passenger]
        if !passenger.off_battlefield or passenger.embarked_transport.value <= 0 or passenger.embarked_transport.value >= MAX_IDENTITY_SEQUENCE:
            return false
        if passenger.has_return_slot:
            let passenger_slot = passenger.return_slot.get()
            if passenger_slot >= board.units.size() or !board[passenger_slot].retired or !board[passenger_slot].empty() or return_slots[passenger_slot]:
                return false
            return_slots[passenger_slot] = true
        let location = find_passenger_carrier(board, passenger.embarked_transport)
        if !location.found:
            return false
        if location.reserve:
            if !valid_passenger_against_carrier(board, passenger, board.reserve_units[location.unit.get()][location.model], board.reserve_units[location.unit.get()].owned_by_player1):
                return false
        else:
            if !valid_passenger_against_carrier(board, passenger, board[location.unit][location.model], board[location.unit].owned_by_player1):
                return false
    return true

# Borrowed model/unit parameters keep early save-validation rejection free of
# owning-local cleanup hazards (capacity p.64; sanitizer infrastructure).
fun valid_passenger_against_carrier(Board board, Unit passenger, Model carrier, Bool owner) -> Bool:
    if owner != passenger.owned_by_player1 or passenger_space_used(board, carrier.identity) > carrier.transport_capacity.value:
        return false
    for validated_model in range(passenger.models.size()):
        if !passenger[validated_model].off_battlefield or !passenger_model_permitted(carrier, passenger[validated_model]):
            return false
    return true

# Reviving an embarked model returns it to that unit if capacity permits;
# lack of capacity destroys it with NO further triggers (01.02.03). A reserve
# return is offboard too: never use last battlefield coordinates for placement.
fun returned_passenger_permitted(Board board, Unit unit, Model model) -> Bool:
    if unit.embarked_transport.value == 0:
        return true
    let carrier = find_passenger_carrier(board, unit.embarked_transport)
    if !carrier.found:
        return false
    let bank = SourceBank::battlefield
    if carrier.reserve:
        bank = SourceBank::reserves
    ref transport = source_bank_unit(board, bank, carrier.unit.get())[carrier.model]
    if !unit.models.has_capacity():
        return false
    let candidate : Unit
    candidate = unit
    candidate.models.append(model)
    return passenger_model_permitted(transport, model) and passenger_space_used(board, unit.embarked_transport) - passenger_space(unit) + passenger_space(candidate) <= transport.transport_capacity.value

# ALL required keywords and explicit datasheet exclusions augment the existing
# ANY/excluded keyword lists. Metadata comes from the carrier card (core p64).
fun passenger_requirements_match(Model carrier, Model passenger) -> Bool:
    for required in range(carrier.required_passenger_keywords.size()):
        if !passenger.has_keyword(carrier.required_passenger_keywords[required]):
            return false
    for forbidden in range(carrier.forbidden_passenger_datasheets.size()):
        if carrier.forbidden_passenger_datasheets[forbidden] == passenger.datasheet:
            return false
    return true

# Datasheet constructors encode their explicit named exclusions (core p64).
fun forbid_passenger_datasheet(Model carrier, Int code):
    assert(code > 0 and code < MAX_DATASHEETCODE, "invalid excluded passenger datasheet")
    let datasheet : DatasheetCode
    datasheet = code
    carrier.forbidden_passenger_datasheets.append(datasheet)

# Seat weights are data. Half-seat models are rounded up once per whole unit,
# while ordinary members retain their full weight (core p64; card exceptions).
fun passenger_space(Unit unit) -> Int:
    let ordinary = 0
    let half_seats = 0
    for member in range(unit.models.size()):
        if unit[member].transport_space_divisor.value == 2:
            half_seats = half_seats + unit[member].transport_space.value
        else:
            ordinary = ordinary + max(unit[member].transport_space.value, 2 * int(unit[member].has_keyword(Keyword::mega_armour) or unit[member].has_keyword(Keyword::jump_pack)))
    return ordinary + (half_seats + 1) / 2

# A card-granted embarkation can supply its own whole-unit range without
# copying ordinary after-move timing restrictions (transport core p64).
fun transport_within_embark_range(Board board, UnitID passenger, UnitID carrier, ModelID model, Int inches) -> Bool:
    if carrier.get() >= board.units.size() or board[carrier].off_battlefield or model.get() >= board[carrier].models.size() or !transport_can_carry(board, board[passenger], board[carrier], model.get()):
        return false
    for member in range(board[passenger].models.size()):
        if board[passenger][member].is_alive() and !passenger_wholly_within(board[passenger][member], board[carrier][model], inches):
            return false
    return true
