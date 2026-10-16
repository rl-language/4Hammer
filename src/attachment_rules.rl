import board

# Last component members confer unit rules through the attacking unit's full
# attack sequence (p.67), without making those corpses live recipients (p.87).
fun model_confers_attached_abilities(Model model) -> Bool:
    return model.is_alive() or model.attachment_abilities_retained

# Resolve the original unit's members, rather than treating an alive Leader
# as proof that its destroyed bodyguard source remains active (pp.66–67).
fun component_source_active(Unit unit, EntityIdentity component) -> Bool:
    let active = false
    for model in range(unit.models.size()):
        active = active or (unit[model].original_unit == component and model_confers_attached_abilities(unit[model]))
    return active

# Component keywords remain model-local; declared unit-scope abilities are
# separate source metadata, never copied into each model (p.67/19.04).
fun scoped_unit_ability(Unit unit, AbilityKind kind) -> Bool:
    let active = false
    if component_source_active(unit, unit.identity):
        for ability in range(unit.unit_abilities.size()):
            active = active or unit.unit_abilities[ability] == kind
    for component in range(unit.attached_units.size()):
        if component_source_active(unit, unit.attached_units[component].identity):
            for ability in range(unit.attached_units[component].abilities.size()):
                active = active or unit.attached_units[component].abilities[ability] == kind
    return active

# Capture unit-wide Waaagh! provenance before concatenating components; the
# source's last-member lifetime still applies (pp.66–67; Orks Army Rules).

# Leaders/Supports that started attached retain 'while leading' permission
# after bodyguard destruction, including after revival (p.67/19.04.01).
fun component_started_leading(Unit unit, EntityIdentity component) -> Bool:
    let started = false
    for index in range(unit.attached_units.size()):
        started = started or unit.attached_units[index].identity == component
    return started

# Read the actual source-unit role, not the Character keyword or single-model
# size. A bodyguard has one slot for each role (p.66/19.01).
fun attachment_role_available(Unit bodyguard, AttachmentRole role) -> Bool:
    if role.value <= AttachmentRole::bodyguard.value or role.value > AttachmentRole::support.value or bodyguard.attachment_role.value != AttachmentRole::bodyguard.value:
        return false
    let available = bodyguard.attached_units.has_capacity()
    for component in range(bodyguard.attached_units.size()):
        available = available and bodyguard.attached_units[component].role.value != role.value
    return available

# Prebattle UnitIDs address reserves. Permissions are exact bodyguard datasheet
# identities, never a keyword OR inferred from a legacy factory (p.66/app lists).
fun attachment_valid(Board board, UnitID source, UnitID target, Bool player) -> Bool:
    if board.timing.phase.value != BattlePhase::none.value or board.turn_serial.value != 0:
        return false
    if source.get() < 0 or target.get() < 0 or source.get() >= board.reserve_units.size() or target.get() >= board.reserve_units.size() or source.get() == target.get():
        return false
    ref leader = board.reserve_units[source.get()]
    ref bodyguard = board.reserve_units[target.get()]
    if leader.owned_by_player1 != player or bodyguard.owned_by_player1 != player or !leader.attached_units.empty() or leader.models.empty() or bodyguard.models.empty() or leader.retired or bodyguard.retired or !attachment_role_available(bodyguard, leader.attachment_role) or leader.models.size() + bodyguard.models.size() > MAX_UNIT_MODELS:
        return false
    if !faction_enhancement_attachment_valid(leader, bodyguard):
        return false
    if leader.identity.value <= 0 or bodyguard.identity.value <= 0:
        return false
    for member in range(leader.models.size()):
        if !leader[member].is_alive() or leader[member].original_unit != leader.identity:
            return false
    for member in range(bodyguard.models.size()):
        if !bodyguard[member].is_alive():
            return false
    let permitted = false
    for permission in range(leader.permitted_bodyguards.size()):
        permitted = permitted or (leader.permitted_bodyguards[permission].value > 0 and leader.permitted_bodyguards[permission] == bodyguard.roster_datasheet)
    return permitted and leader.destroyed_models.value.empty() and bodyguard.destroyed_models.value.empty()

# Commit after checking all capacity/identity/permission constraints, then erase
# the consumed reserve slot once. No position or numeric history is rewritten.
fun attach_reserved_unit(Board board, UnitID source, UnitID target, Bool player):
    assert(attachment_valid(board, source, target, player), "attachment is not permitted")
    board.reserve_units[source.get()].attach_to(board.reserve_units[target.get()])
    board.reserve_units.erase(source.get())
    refresh_source_effects(board, TimingWindow::none)



# Remaining strength counts live models, including mixed attached components;
# retained destroyed models do not count towards half-strength (pp.66/86–87).
fun live_attachment_strength(Unit unit) -> Int:
    let alive = 0
    for model in range(unit.models.size()):
        alive = alive + int(unit[model].is_alive())
    return alive

# Numeric/source metadata is restore infrastructure for pp.66–67/86–88.
# Component identities are validated globally by Board's identity registry.
fun valid_attachment_state(Unit unit) -> Bool:
    if unit.attachment_role.value < 0 or unit.attachment_role.value > AttachmentRole::support.value or unit.roster_datasheet.value < 0 or unit.roster_datasheet.value >= MAX_DATASHEETCODE:
        return false
    let ability : AbilityKind
    for rule in range(unit.unit_abilities.size()):
        if unit.unit_abilities[rule].value < 0 or unit.unit_abilities[rule].value >= max(ability):
            return false
    for permission in range(unit.permitted_bodyguards.size()):
        if unit.permitted_bodyguards[permission].value <= 0 or unit.permitted_bodyguards[permission].value >= MAX_DATASHEETCODE:
            return false
        for prior in range(permission):
            if unit.permitted_bodyguards[prior] == unit.permitted_bodyguards[permission]:
                return false
    if unit.attached_units.empty():
        return true
    if unit.attachment_role.value != AttachmentRole::bodyguard.value or unit.bodyguard_starting_strength.value <= 0:
        return false
    let combined = unit.bodyguard_starting_strength.value
    for component in range(unit.attached_units.size()):
        ref record = unit.attached_units[component]
        if record.identity.value <= 0 or record.identity == unit.identity or record.role.value < AttachmentRole::leader.value or record.role.value > AttachmentRole::support.value or record.starting_strength.value <= 0 or record.starting_strength.value > MAX_UNIT_MODELS or record.datasheet.value < 0 or record.datasheet.value >= MAX_DATASHEETCODE:
            return false
        combined = combined + record.starting_strength.value
        for prior in range(component):
            if unit.attached_units[prior].role.value == record.role.value:
                return false
        for rule in range(record.abilities.size()):
            if record.abilities[rule].value < 0 or record.abilities[rule].value >= max(ability):
                return false
    if combined != unit.starting_strenght.value or combined > MAX_UNIT_MODELS:
        return false
    for model in range(unit.models.size()):
        if !attachment_origin_known(unit, unit[model]):
            return false
    for archive in range(unit.destroyed_models.value.size()):
        if !attachment_origin_known(unit, unit.destroyed_models.value[archive]):
            return false
    return true

# Revived members retain their original component even after all of its models
# have died; actual revival/setup belongs to17.J (pp.67/88;01.02.03).
fun attachment_origin_known(Unit unit, Model model) -> Bool:
    let known = model.original_unit == unit.identity
    for component in range(unit.attached_units.size()):
        known = known or model.original_unit == unit.attached_units[component].identity
    return known and faction_attachment_origin_valid(unit, model)

# Raw unit-scoped rules survive until their source component's last member;
# registered bearer grants independently use the specific-model clause (p.67).
fun attachment_component_has_rules(Unit unit, EntityIdentity component) -> Bool:
    let confers = false
    if component == unit.identity:
        confers = !unit.unit_abilities.empty() or faction_component_has_army_rules(unit, component)
    for record in range(unit.attached_units.size()):
        if unit.attached_units[record].identity == component:
            confers = !unit.attached_units[record].abilities.empty() or faction_component_has_army_rules(unit, component)
    for model in range(unit.models.size()):
        if unit[model].original_unit == component:
            confers = confers or !unit[model].abilities.empty() or faction_model_confers_army_rules(unit[model])
    return confers

# P67 retains conferred rules through the attacking unit's ALL attacks. Retain
# a specific registered bearer, or the last member of a unit-rule component;
# do not retain plain attached casualties that confer no such rules.
fun retain_attachment_rules_for_attack(Board board, UnitID target, ModelID model, DamageJob job) -> Bool:
    if !job.from_attack or !job.source_known or board[target].attached_units.empty():
        return false
    ref unit = board[target]
    ref dying = unit[model]
    let component_alive = false
    for member in range(unit.models.size()):
        component_alive = component_alive or (member != model.get() and unit[member].original_unit == dying.original_unit and unit[member].is_alive())
    let retain = !component_alive and attachment_component_has_rules(unit, dying.original_unit)
    for instance in range(board.source_instances.size()):
        ref source = board.source_instances[instance]
        if source.disabled:
            continue
        retain = retain or (source.source_model == dying.identity and (source.requires_live_source or source.aura or source.own_unit_passive))
        retain = retain or (!component_alive and source.source_model.value == 0 and source.source_unit == dying.original_unit and (source.requires_live_source or source.aura or source.own_unit_passive))
    return retain

# Ending one attacker's sequence releases only its deferred conferred rules;
# nested/unrelated attackers retain their own intervals (p.67).
fun release_attachment_rules(Board board, UnitID attacker):
    for unit in range(board.units.size()):
        for model in range(board[unit].models.size()):
            if board[unit][model].attachment_abilities_retained and board[unit][model].destroying_unit_known and board[unit][model].destroying_unit.get() == attacker.get():
                board[unit][model].attachment_abilities_retained = false
    refresh_source_effects(board, TimingWindow::none)


# Provenance repair for a later validated revival: retain component/start/use
# identities, and clear only transient destruction markers. Healing/setup and
# equipped-data restoration remain17.J (p.67/88;01.02.03).
fun restore_attachment_provenance(Unit unit, Model returned):
    assert(unit.attached_units.empty() or attachment_origin_known(unit, returned), "returned model has unknown attachment origin")
    returned.attachment_abilities_retained = false
    returned.destroyed_whole_unit = false
    returned.destruction_pending = false
    returned.destruction_released = false
    returned.destroyed_by_attack = false
    returned.destroying_unit_known = false
    returned.destruction_attack_suppressed = false
    unit.unit_destruction_event_issued = false
    unit.retired = false
