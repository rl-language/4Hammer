import attack_declarations

using AllocationGroupID = BInt<0, MAX_UNIT_MODELS>
using AllocationGroupCounter = LinearlyDistributedInt<0, 33>

# CHARACTER models each form their own group; other models combine exactly
# when W/Sv/InSv agree, including no-invulnerable sentinels (p.19).
# Attack-scoped InSv includes the RANGED-only Kustom Force Field (Orks/
# Big-Mek-In-Mega-Armour), rather than a permanent model save.
fun allocation_group_matches(AllocationGroup group, Model model, Int invulnerable) -> Bool:
    return !group.character and !model.is_character() and group.wounds.value == model.profile.wounds() and group.save.value == model.effective_save() and group.invulnerable.value == invulnerable

# PRECISION needs a CHARACTER visible to a bearer in the gathered attack
# group, not any model from an unrelated weapon (p.84; visibility pp.24–25).
fun precision_model_visible(Board board, AttackSequenceInfo info, Int target_model) -> Bool:
    if info.precision_visibility_known:
        return info.precision_visible_targets[target_model]
    let visible = false
    for i in range(board[info.source_unit_id].models.size()):
        if board[info.source_unit_id][i].is_alive() and model_visible_to_model(board, board[info.source_unit_id][i], board[info.target_unit_id], board[info.target_unit_id][target_model]):
            visible = true
    return visible

# Build live membership before any saves; snapshots keep declared ordering
# independent of later casualty compaction (p.19). Attachments stay deferred.
fun make_allocation_groups(Board board, Unit target, AttackSequenceInfo info) -> AllocationGroups:
    let groups : AllocationGroups
    for i in range(target.models.size()):
        if !target[i].is_alive():
            continue
        let group_index = -1
        for j in range(groups.size()):
            if allocation_group_matches(groups[j], target[i], orks_allocation_invulnerable(target, target[i], info)):
                group_index = j
        if group_index < 0:
            let group : AllocationGroup
            group.wounds = target[i].profile.wounds()
            group.save = target[i].effective_save()
            group.invulnerable = orks_allocation_invulnerable(target, target[i], info)
            group.character = target[i].is_character()
            groups.append(group)
            group_index = groups.size() - 1
        groups[group_index].members.append(target[i].identity)
        groups[group_index].wounded = groups[group_index].wounded or target[i].suffered_wounds > 0
        if target[i].is_character():
            groups[group_index].precision_visible = precision_model_visible(board, info, i)
    return groups

# Pick the minimum mandatory tier before allowing discretionary ordering:
# wounded non-CHARACTER, other non-CHARACTER, wounded CHARACTER, others (p.19).
fun allocation_priority(AllocationGroup group) -> Int:
    return int(group.character) * 2 + int(!group.wounded)

# Every unchosen group of an earlier tier must precede the candidate (p.19).
fun allocation_order_valid(AllocationGroups groups, Bool[MAX_UNIT_MODELS] chosen, AllocationGroupID id) -> Bool:
    if id.value >= groups.size() or chosen[id.value]:
        return false
    for i in range(groups.size()):
        if !chosen[i] and allocation_priority(groups[i]) < allocation_priority(groups[id.value]):
            return false
    return true

# Look up a live stable member without redirecting to a compacted slot (p.19).
fun allocation_contains(Unit target, AllocationGroup group, Int model) -> Bool:
    if model < 0 or model >= target.models.size() or !target[model].is_alive():
        return false
    for i in range(group.members.size()):
        if target[model].identity == group.members[i]:
            return true
    return false

# A group's wounded member must receive the next save if possible (p.19).
fun allocation_model_valid(Unit target, AllocationGroup group, ModelID model) -> Bool:
    if !allocation_contains(target, group, model.get()):
        return false
    if target[model].suffered_wounds > 0:
        return true
    for i in range(target.models.size()):
        if allocation_contains(target, group, i) and target[i].suffered_wounds > 0:
            return false
    return true

# A retained destruction trigger does not keep its allocation group alive
# (pp.19/87); advance as soon as no live stable member remains.
fun allocation_group_alive(Unit target, AllocationGroup group) -> Bool:
    for i in range(target.models.size()):
        if allocation_contains(target, group, i):
            return true
    return false

# Test the same result against InSv first, then AP-adjusted Sv. Natural one
# always inflicts damage; AP is a nonpositive characteristic (p.19).
fun attack_save_succeeds(AllocationGroup group, Dice unmodified, Int ap) -> Bool:
    if unmodified == 1:
        return false
    if group.invulnerable.value >= 2 and group.invulnerable.value <= 6 and unmodified.value >= group.invulnerable.value:
        return true
    return max(1, unmodified.value + min(0, ap)) >= group.save.value

# Mortal allocation uses wounded non-CHARACTER first, then other ordinary
# models, then wounded CHARACTER, then other CHARACTER (p.24).
fun mortal_model_priority(Model model) -> Int:
    return int(model.is_character()) * 2 + int(model.suffered_wounds == 0)

# No save/group decision changes the mandatory mortal recipient tier (p.24).
fun mortal_model_valid(Unit target, ModelID model) -> Bool:
    if model.get() >= target.models.size() or !target[model].is_alive():
        return false
    for i in range(target.models.size()):
        if target[i].is_alive() and mortal_model_priority(target[i]) < mortal_model_priority(target[model]):
            return false
    return true

# Every live model individually needs MONSTER or VEHICLE, including mixed
# units with one of each; unit-wide keyword union is insufficient (p.24).
fun hazard_mortal_multiplier(Unit unit) -> Int:
    let all_large = true
    let alive = false
    for i in range(unit.models.size()):
        if unit[i].is_alive():
            alive = true
            all_large = all_large and (unit[i].has_keyword(Keyword::monster) or unit[i].has_keyword(Keyword::vehicle))
    if alive and all_large:
        return 3
    return 1

# Damage jobs form an explicit finite work stack for destruction cascades,
# avoiding recursive coroutine frames (infrastructure for pp.24/80/87).
enum DamageKind:
    normal
    mortal
    devastating
    remove_destroyed
    deferred_demise
    emergency_next
    emergency_setup

    # Infrastructure comparison keeps normal/mortal and removal paths distinct
    # for their different spill and destruction rules (pp.24/87).
    fun equal(DamageKind other) -> Bool:
        return self.value == other.value

cls DamageJob:
    DamageKind kind
    UnitID target
    UnitID source
    Bool source_known
    Bool from_attack
    CombatCounter amount
    EntityIdentity recipient

using DamageJobs = CheckedVector<DamageJob, 1024>

# Construct explicit provenance for delayed attack-caused triggers (p.87).
fun damage_job(DamageKind kind, UnitID target, UnitID source, Bool known, Bool attack, Int amount, EntityIdentity recipient) -> DamageJob:
    assert(amount >= 0 and amount < MAX_COMBAT_COUNTER, "damage job capacity exceeded")
    assert(!attack or known, "attack damage requires a known source")
    let job : DamageJob
    job.kind = kind
    job.target = target
    job.source = source
    job.source_known = known
    job.from_attack = attack
    job.amount = amount
    job.recipient = recipient
    return job

# Keep selector wrappers and a validity flag for pending trigger scans (p.87).
cls PendingDestruction:
    Bool found
    UnitID unit
    ModelID model

# Immediate/non-attack triggers precede further damage; attack triggers wait
# for their attacking unit's entire activation, only when such rules exist (p.87).
fun next_destruction(Board board, Bool finish_attacks, UnitID finished_source) -> PendingDestruction:
    let found : PendingDestruction
    for owner in range(2):
        for u in range(board.units.size()):
            for m in range(board[u].models.size()):
                if !found.found and board[u].owned_by_player1 == (board.current_player == (owner == 0)) and destruction_ready(board[u][m], finish_attacks, finished_source):
                    found.found = true
                    found.unit = u
                    found.model = m
    return found

# User-supplied Rules Sequencing: current player's triggers, in their chosen
# order, then opponent's. Eligibility still respects attack deferral (p.87).
fun destruction_ready(Model model, Bool finish_attacks, UnitID source) -> Bool:
    # Supplied Fight on Death postpones all destruction triggers until the
    # model's own unit attacks or phase end, overriding immediate retaliation.
    return model.destruction_pending and !(model.state == ModelState::fight_on_death) and (model.destruction_released or !model.destroyed_by_attack or (finish_attacks and model.destroying_unit_known and model.destroying_unit.get() == source.get()))

# A unit choice belongs to the controller of the next trigger tier (supplied
# Rules Sequencing); stale/foreign unit slots cannot consume a destruction.
fun destruction_unit_valid(Board board, UnitID unit, Bool player, Bool finish, UnitID source) -> Bool:
    if unit.get() >= board.units.size() or board[unit].owned_by_player1 != player:
        return false
    for i in range(board[unit].models.size()):
        if destruction_ready(board[unit][i], finish, source):
            return true
    return false

# Trigger presence determines retention, not merely taking attack damage
# (p.87). Existing faction hooks retain their legacy definitions until task 17.
fun has_destruction_trigger(Board board, UnitID source, Bool source_known, Model model, Bool fight_on_death) -> Bool:
    return has_source_destruction_trigger(board, source, source_known, model) or carrier_has_passengers(board, model.identity) or model.orks_enhancement.value == OrksEnhancement::surly_as_a_squiggoth.value or orks_aircraft_death_source(board, model) or fight_on_death or model.has_deadly_demise or model.has_keyword(Keyword::master_of_possession) or (source_known and source.get() < board.units.size() and model.is_character() and board[source].has_ability(AbilityKind::feeder_tendrils))

# Raw lost wounds are committed only after all prevention for that application.
# Snapshot provenance before removal so deferred hooks cannot target a new slot
# (p.87); prevention is resolved separately first (p.81).
fun commit_wound_loss(Board board, DamageJob job, ModelID model, Int lost, Bool fight_on_death):
    assert(lost >= 0, "negative wound loss")
    if lost > 0 and job.from_attack and board.orks_attack_active:
        ref record = orks_attack_record(board, board[job.target].identity)
        add_attack_count(record.wounds_lost, min(lost, board[job.target][model].wounds_left()))
    if lost > 0:
        board[job.target][model].suffered_wounds = min(board[job.target][model].profile.wounds(), board[job.target][model].suffered_wounds.value + lost)
    if board[job.target][model].wounds_left() <= 0:
        board[job.target][model].destroyed_phase = board.phase_serial.value + 1
        # Source lifetime p.67 independently requires retaining the bearer,
        # even if it has no Deadly Demise or other death-trigger ability.
        if board.orks_attack_active and live_attachment_strength(board[job.target]) == 0:
            ref destruction_record = orks_attack_record(board, board[job.target].identity)
            destruction_record.destroyed = true
            board[job.target].orks_destroyed_attack = board.orks_attack_serial
            board[job.target].orks_destroyed_phase = board.phase_serial.value + 1
        let retained_rules = retain_attachment_rules_for_attack(board, job.target, model, job)
        board[job.target][model].attachment_abilities_retained = retained_rules
        let unit_death = !board[job.target].unit_destruction_event_issued and live_attachment_strength(board[job.target]) == 0 and (has_source_unit_destruction_trigger(board, job) or orks_package(board, board[job.target], OrksDetachment::flyboyz) and board[job.target][model].has_keyword(Keyword::aircraft))
        board[job.target][model].destroyed_whole_unit = unit_death
        if unit_death:
            board[job.target].unit_destruction_event_issued = true
        if unit_death or retained_rules or has_destruction_trigger(board, job.source, job.source_known, board[job.target][model], fight_on_death):
            board[job.target][model].state = ModelState::pending_destruction
            if fight_on_death:
                board[job.target][model].state = ModelState::fight_on_death
            board[job.target][model].destruction_pending = true
            board[job.target][model].destroyed_by_attack = job.from_attack
            board[job.target][model].destroying_unit_known = job.source_known
            board[job.target][model].destroying_unit = job.source
            if job.source_known:
                board[job.target][model].destroying_unit_identity = board[job.source].identity
            board[job.target][model].destruction_fight_roll = board.attack_info.fight_on_death_roll
        else:
            board[job.target].remove_model(model.get())

# Source-backed death events require retention just like other destruction
# effects (p.87); generic grants resolve through the source dispatcher.
fun has_source_destruction_trigger(Board board, UnitID attacker, Bool known, Model model) -> Bool:
    if board.source_instances.size() == 0:
        return false
    let found = false
    let location = locate_source(board, invalid_entity_identity(), model.identity)
    if location.found:
        let event = source_event(SourceEventKind::model_destroyed, source_bank_unit(board, location.bank, location.unit.value).identity, invalid_entity_identity(), model.identity)
        if known and attacker.get() < board.units.size():
            event.target = board[attacker].identity
        for index in range(board.source_instances.size()):
            found = found or source_event_available(board, board.source_instances[index], event)
    return found


# A Bodyguard/Leader/Support component dying does not destroy the attached
# unit. Only its final live member emits the unit event (p.66/19.02).
fun has_source_unit_destruction_trigger(Board board, DamageJob job) -> Bool:
    let event = source_event(SourceEventKind::unit_destroyed, board[job.target].identity, invalid_entity_identity(), invalid_entity_identity())
    if job.source_known and job.source.get() < board.units.size():
        event.target = board[job.source].identity
    let found = false
    for instance in range(board.source_instances.size()):
        found = found or source_event_available(board, board.source_instances[instance], event)
    return found
