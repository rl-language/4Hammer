import source_effects

# New units use battle-start models, fresh identities and cleared histories;
# returning destroyed models instead retain their identities (01.02.10/p88).
# Faction callbacks reset only their own extension data; registration is caller policy.
fun make_replacement_unit(Board board, Unit original) -> Unit:
    let replacement = original
    replacement.identity = allocate_entity_identity(board)
    replacement.models = original.battle_start_models.value
    replacement.destroyed_models.value.clear()
    replacement.movement_distance_limit = 0
    replacement.has_moved = false
    replacement.has_run = false
    replacement.has_charged = false
    replacement.has_shoot = false
    replacement.has_fought = false
    replacement.can_shoot = true
    replacement.can_charge = true
    replacement.battle_socked = false
    replacement.retired = false
    replacement.is_generated_replacement = true
    replacement.has_return_slot = false
    replacement.off_battlefield = true
    replacement.embarked_transport = 0
    replacement.unit_destruction_event_issued = false
    let history : UnitHistory
    replacement.history = history
    replacement.history.strategic_reserve = true
    let phase : PhaseModifiers
    replacement.phase_modifiers = phase
    prepare_faction_replacement_unit(replacement)
    let old_components : CheckedVector<EntityIdentity, 2>
    for component in range(replacement.attached_units.size()):
        old_components.append(replacement.attached_units[component].identity)
        replacement.attached_units[component].identity = allocate_entity_identity(board)
    for member in range(replacement.models.size()):
        ref model = replacement[member]
        model.identity = allocate_entity_identity(board)
        let origin = replacement.identity
        for component in range(old_components.size()):
            if model.original_unit == old_components[component]:
                origin = replacement.attached_units[component].identity
        model.original_unit = origin
        prepare_faction_replacement_model(model, replacement.identity)
        model.suffered_wounds = 0
        model.state = ModelState::normal
        model.off_battlefield = true
        model.destruction_pending = false
        model.destroyed_whole_unit = false
        model.destroyed_by_attack = false
        model.destruction_released = false
        model.destruction_attack_suppressed = false
        model.attachment_abilities_retained = false
        model.destroying_unit_known = false
        model.destroying_unit_identity = 0
        let keyword = model.keywords.size()
        while keyword > 0:
            keyword = keyword - 1
            if model.keywords[keyword] == Keyword::warlord:
                model.keywords.erase(keyword)
        strip_temporary_model_grants(model)
    replacement.battle_start_models.value = replacement.models
    return replacement

# Recycle only unreferenced retired slots; pending faction returns reserve
# their original slot, independently of new-unit eligibility (p88/01.02.10).
fun replacement_slot(Board board) -> Int:
    if board.units.has_capacity():
        return board.units.size()
    for slot in range(board.units.size()):
        if !board[slot].models.empty() or !board[slot].retired:
            continue
        let reserved = false
        for reserve in range(board.reserve_units.size()):
            reserved = reserved or (board.reserve_units[reserve].has_return_slot and board.reserve_units[reserve].return_slot.get() == slot)
        for passenger in range(board.embarked_units.size()):
            reserved = reserved or (board.embarked_units[passenger].has_return_slot and board.embarked_units[passenger].return_slot.get() == slot)
        for unit in range(board.units.size()):
            for model in range(board[unit].models.size()):
                reserved = reserved or (board[unit][model].destruction_pending and board[unit][model].destroying_unit_known and board[unit][model].destroying_unit.get() == slot)
        let archive : ModelID
        for casualty in range(board[slot].destroyed_models.value.size()):
            archive = casualty
            reserved = reserved or faction_casualty_has_pending_return(board, board[slot], archive)
        if !reserved:
            return slot
    return -1
