import transport_rules

# Returning Models01.02.03 forbids a new engagement and requires coherency
# with phase-start members; explicit nearest-unengaged returns waive only
# that anchor restriction. Quads and intentional circular proxies remain.
fun return_position_valid(Board board, UnitID target, Model returned, BoardPosition position, ReturnPlacementPolicy policy) -> Bool:
    let candidate : Model
    candidate = returned
    candidate.position = position
    candidate.off_battlefield = false
    candidate.state = ModelState::normal
    if !model_placement_valid(board, candidate):
        return false
    let phase_start_only = policy.value == ReturnPlacementPolicy::phase_start.value
    let coherent = 0
    for unit_index in range(board.units.size()):
        ref unit = board.units[unit_index]
        for member in range(unit.models.size()):
            ref other = unit[member]
            if other.off_battlefield or !fight_model_present(other):
                continue
            if model_bases_overlap(candidate, other):
                return false
            if unit_index == target.get() and other.is_alive():
                let phase_start = !phase_start_only
                for original in range(board[target].history.phase_start_members.size()):
                    phase_start = phase_start or board[target].history.phase_start_members[original] == other.identity
                if phase_start and candidate.is_engaged_with(other):
                    coherent = coherent + 1
            if unit.owned_by_player1 != board[target].owned_by_player1 and candidate.is_engaged_with(other):
                if !phase_start_only:
                    return false
                let already_engaged = false
                for enemy in range(board[target].history.phase_start_engagements.size()):
                    already_engaged = already_engaged or board[target].history.phase_start_engagements[enemy] == unit.identity
                if !already_engaged:
                    return false
    if live_attachment_strength(board[target]) > 0:
        return coherent >= 1 + int(live_attachment_strength(board[target]) + 1 >= 7)
    return true

# Setup searches the finite supported grid for a legal return before asking
# the controller for a position; unavailable placement cannot deadlock a frame.
fun return_has_position(Board board, UnitID target, Model returned, ReturnPlacementPolicy policy) -> Bool:
    let position : BoardPosition
    for x in range(BOARD_WIDTH):
        for y in range(BOARD_HEIGHT):
            position.x = x
            position.y = y
            if return_position_valid(board, target, returned, position, policy):
                return true
    return false

# A returned Surly model must choose a nearest legal whole-quad location.
# Compare squared centre distances; equal circular bases cancel from the
# nearest-location comparison. Exact continuous/oval geometry stays deferred.
fun return_position_allowed(Board board, UnitID source, Model model, BoardPosition position, ReturnPlacementPolicy policy) -> Bool:
    if !return_position_valid(board, source, model, position, policy):
        return false
    if policy.value == ReturnPlacementPolicy::phase_start.value:
        return true
    let chosen = (position.x.value - model.position.x.value) * (position.x.value - model.position.x.value) + (position.y.value - model.position.y.value) * (position.y.value - model.position.y.value)
    let alternative : BoardPosition
    for x in range(BOARD_WIDTH):
        for y in range(BOARD_HEIGHT):
            let other = (x - model.position.x.value) * (x - model.position.x.value) + (y - model.position.y.value) * (y - model.position.y.value)
            if other < chosen:
                alternative.x = x
                alternative.y = y
                if return_position_valid(board, source, model, alternative, policy):
                    return false
    return true

# Archive selection preserves physical weapon usage and original identity.
# Heal a wounded living model before reviving a non-Character (02.02.04).
fun has_wounded_model(Unit unit) -> Bool:
    for member in range(unit.models.size()):
        if unit[member].is_alive() and unit[member].suffered_wounds > 0:
            return true
    return false

# Healing02.02.04 restores living wounds before non-Character casualties.
# Location changes placement requirements, not the healing procedure01.02.04.
fun healing_archive_valid(Board board, Unit unit, SourceBank bank, ModelID archive) -> Bool:
    if archive.get() >= unit.destroyed_models.value.size() or has_wounded_model(unit) or !unit.models.has_capacity() or unit.destroyed_models.value[archive.get()].is_character():
        return false
    let target = board.find_unit(unit.identity)
    return bank.value != SourceBank::battlefield.value or (target >= 0 and return_has_position(board, unit_id(target), unit.destroyed_models.value[archive.get()], ReturnPlacementPolicy::phase_start))

# Reset death-only fields on revival, preserving identity, original wargear,
# use history and persisting effects (appendix01.02.03/01.02.02; core p88).
fun prepare_returned_model(Model model, Bool offboard, Int restored_wounds):
    model.suffered_wounds = max(0, model.profile.wounds() - restored_wounds)
    model.state = ModelState::normal
    model.off_battlefield = offboard
    model.destruction_pending = false
    model.attachment_abilities_retained = false
    model.destroyed_whole_unit = false
    model.destruction_released = false
    model.destruction_attack_suppressed = false
    model.destroyed_by_attack = false
    model.destroying_unit_known = false
    model.destroying_unit_identity = 0

# One placement/reset/transfer path for original casualties (01.02.03).
# Failed passenger capacity or unavailable geometry creates no new death event.
act return_model(ctx Board board, ctx Unit unit, frm SourceBank bank, frm UnitID source, frm ModelID archive, frm ReturnPlacementPolicy policy, frm FixedStat restored_wounds) -> ModelReturn:
    frm returned : Model
    returned = unit.destroyed_models.value[archive.get()]
    frm placed = unit.models.has_capacity()
    if placed and bank.value == SourceBank::battlefield.value:
        placed = return_has_position(board, source, returned, policy)
        if placed:
            act place_returned_model(BoardPosition position) {return_position_allowed(board, source, returned, position, policy)}
            returned.position = position
    else:
        if placed:
            placed = returned_passenger_permitted(board, unit, returned)
    if placed:
        prepare_returned_model(returned, bank.value != SourceBank::battlefield.value, restored_wounds.value)
        restore_attachment_provenance(unit, returned)
        unit.models.append(returned)
        unit.retired = false
        unit.destroyed_models.value.erase(archive.get())
        refresh_source_effects(board, TimingWindow::none)

# Literal wound amounts are bounded before entering the stored continuation.
# This is representation infrastructure for01.02.03, not a new rule.
fun return_model(Board board, Unit unit, SourceBank bank, UnitID source, ModelID archive, ReturnPlacementPolicy policy, Int restored_wounds) -> ModelReturn:
    let amount : FixedStat
    amount = restored_wounds
    return return_model(board, unit, bank, source, archive, policy, amount)

# Healing02.02.04 spends one wound at a time, retains original identities and
# wargear, and applies the same priority/return rules in every storage bank.
act heal_unit(ctx Board board, ctx Unit unit, frm SourceBank bank, frm FixedStat count) -> UnitHealing:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = unit.owned_by_player1
    while count.value > 0:
        if has_wounded_model(unit):
            act choose_healed_model(ModelID wounded) {wounded.get() < unit.models.size(), unit[wounded].is_alive(), unit[wounded].suffered_wounds > 0}
            unit[wounded].suffered_wounds = unit[wounded].suffered_wounds - 1
        else:
            frm available = false
            let archive : ModelID
            for index in range(unit.destroyed_models.value.size()):
                archive = index
                available = available or healing_archive_valid(board, unit, bank, archive)
            if !available:
                break
            act choose_healed_casualty(frm ModelID casualty) {healing_archive_valid(board, unit, bank, casualty)}
            frm target : UnitID
            if bank.value == SourceBank::battlefield.value:
                target = board.find_unit(unit.identity)
            board.shared_actions.return_model = return_model(board, unit, bank, target, casualty, ReturnPlacementPolicy::phase_start, 1)
            subaction*(board, unit) board.shared_actions.return_model
        count = count - 1
    board.current_decision_maker = previous_owner
