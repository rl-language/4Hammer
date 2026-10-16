import replacement_rules
import board
import source_effects

# Only completely empty retired slots may be assigned to a NEW replacement
# unit. Ordinary returns retain their own reserved slot. Check all bank returns
# and pending destruction references before recycling; preserve the old unit in
# the identity archive (Infested War Zone; allocation infrastructure, not a rule).
# New units allocate new unit/component/model identities. A revived model uses
# its old identity instead; conflating these violates Infested War Zone/01.02.10.
# Literal identical battle-start equipment/strength, fresh histories/wounds and
# identities, with original component membership mapped into the new unit.
# Adding during battle is not another mustering choice or a price calculation.
# Surly is a compulsory end-phase roll, not a free revival choice or a new
# model. Only its bearer destroyed in THIS phase can consume the army token.
fun orks_surly_archive_valid(Board board, UnitID source, ModelID archive, Bool owner) -> Bool:
    if source.get() >= board.units.size() or board[source].owned_by_player1 != owner or archive.get() >= board[source].destroyed_models.value.size():
        return false
    return orks_surly_casualty_valid(board, board[source], archive)

# One casualty predicate for all banks: the actual bearer, this phase and its
# unspent army token. Source: Surly as a Squiggoth; appendix01.02.03.
fun orks_surly_casualty_valid(Board board, Unit unit, ModelID archive) -> Bool:
    if archive.get() >= unit.destroyed_models.value.size():
        return false
    ref model = unit.destroyed_models.value[archive.get()]
    return model.orks_enhancement.value == OrksEnhancement::surly_as_a_squiggoth.value and model.destroyed_phase == board.phase_serial.value + 1 and source_usage_available(board, make_source_usage(unit.owned_by_player1, 200 + OrksEnhancement::surly_as_a_squiggoth.value, unit.identity, model.identity, SourceUseScope::army, source_use_limits(0, 0, 0, 1)))

# No distances are measured from offboard units; Surly uses its archived
# physical death location instead (source card, not reserve visibility).
fun orks_surly_available(Board board, UnitID source, Bool owner, TimingWindow window) -> Bool:
    if source.get() >= board.units.size() or !(window == TimingWindow::command_end or window == TimingWindow::movement_end or window == TimingWindow::shooting_end or window == TimingWindow::charge_end or window == TimingWindow::fight_end):
        return false
    let archive : ModelID
    for member in range(board[source].destroyed_models.value.size()):
        archive = member
        if orks_surly_archive_valid(board, source, archive, owner):
            return true
    return false

# Source mandates the roll even if placement cannot be supported. A passed
# roll returns the original bearer with3W, retaining once-only weapon history.
act resolve_orks_surly(ctx Board board, frm UnitID source, frm Bool owner) -> OrksSurly:
    act choose_surly_casualty(frm ModelID archive) {orks_surly_archive_valid(board, source, archive, owner)}
    board.shared_actions.return_orks_surly = return_orks_surly(board, board[source], SourceBank::battlefield, source, archive)
    subaction*(board, board[source]) board.shared_actions.return_orks_surly

# One Surly roll/usage/restoration path. Battlefield returns select a nearest
# legal quad; passengers need capacity; reserves need no position (01.02.03).
act return_orks_surly(ctx Board board, ctx Unit unit, frm SourceBank bank, frm UnitID source, frm ModelID archive) -> OrksSurlyReturn:
    commit_source_usage(board, make_source_usage(unit.owned_by_player1, 200 + OrksEnhancement::surly_as_a_squiggoth.value, unit.identity, unit.destroyed_models.value[archive.get()].identity, SourceUseScope::army, source_use_limits(0, 0, 0, 1)))
    act roll(Dice surly_face)
    if surly_face.value >= 2:
        board.shared_actions.return_model = return_model(board, unit, bank, source, archive, ReturnPlacementPolicy::nearest_unengaged, 3)
        subaction*(board, unit) board.shared_actions.return_model

# Reserve/passenger phase-end selection delegates to the SAME Surly rule as
# battlefield timing windows. This adapter only iterates banks (01.02.04);
# retained deaths have already resolved through the common damage engine.
act resolve_orks_bank_returns(ctx Board board) -> OrksBankReturns:
    frm previous_owner = board.current_decision_maker
    frm owner = board.current_player
    frm controllers : BInt<0, 3>
    while controllers.value < 2:
        board.current_decision_maker = owner
        frm bank : SourceBank
        frm bank_count : BInt<0, 3>
        bank_count = 0
        while bank_count.value < 2:
            bank.value = bank_count.value + 1
            frm slot : UnitIterator
            slot = 0
            while slot.value < source_bank_size(board, bank):
                if source_bank_unit(board, bank, slot.value).owned_by_player1 == owner:
                    frm archive : ModelIterator
                    archive = 0
                    while archive.value < source_bank_unit(board, bank, slot.value).destroyed_models.value.size():
                        frm revive : ModelID
                        revive = archive.value
                        if orks_surly_casualty_valid(board, source_bank_unit(board, bank, slot.value), revive):
                            frm source : UnitID
                            source = slot.value
                            board.shared_actions.return_orks_surly = return_orks_surly(board, source_bank_unit(board, bank, slot.value), bank, source, revive)
                            subaction*(board, source_bank_unit(board, bank, slot.value)) board.shared_actions.return_orks_surly
                        else:
                            archive = archive + 1
                slot = slot + 1
            bank_count = bank_count + 1
        owner = !owner
        controllers = controllers + 1
    board.current_decision_maker = previous_owner

# The repair grants a model hit bonus even when it was already at full W.
# Range is bearer-to-model; forbidden Aircraft/Titanic and other banks cannot
# qualify. A vehicle unit's nearby member cannot stand in for a distant model.
# https://wahapedia.ru/wh40k11ed/factions/orks/Mek
fun orks_mek_target_valid(Board board, SourceInstance source, UnitID target, ModelID model) -> Bool:
    if target.get() >= board.units.size() or model.get() >= board[target].models.size() or board[target].off_battlefield or board[target].owned_by_player1 != source.owner:
        return false
    ref recipient = board[target][model]
    if !recipient.is_alive() or !recipient.has_keyword(Keyword::orks) or !recipient.has_keyword(Keyword::vehicle) or recipient.has_keyword(Keyword::aircraft) or recipient.has_keyword(Keyword::titanic):
        return false
    let location = locate_source(board, source.source_unit, source.source_model)
    if !location.found or location.bank.value != SourceBank::battlefield.value:
        return false
    ref actor = board[location.unit.value]
    let bearer = actor.find_model(source.source_model)
    return bearer >= 0 and actor[bearer].is_alive() and actor[bearer].distance(recipient) <= 3.0

# Invariants for all-bank own-unit healing; range-based Painboss targets
# remain battlefield units except for its own unit's explicit self-range.
# Sources: Orks/Painboy, Painboss, Big-Mek-In-Mega-Armour; appendix01.02.04.
fun orks_healing_target_valid(Board board, SourceInstance instance, SourceBank bank, UnitID target) -> Bool:
    if target.get() >= source_bank_size(board, bank):
        return false
    ref unit = source_bank_unit(board, bank, target.get())
    if unit.owned_by_player1 != instance.owner or !has_live_model(unit):
        return false
    let source = locate_source(board, instance.source_unit, instance.source_model)
    if !source.found:
        return false
    ref actor = source_bank_unit(board, source.bank, source.unit.value)
    if instance.rule.value != ORKS_PAINBOSS_RULE:
        return unit.identity == actor.identity
    if !unit.has_keyword(Keyword::beast_snagga):
        return false
    if unit.identity == actor.identity:
        return true
    return bank.value == SourceBank::battlefield.value and source.bank.value == SourceBank::battlefield.value and !unit.off_battlefield and !actor.off_battlefield and live_unit_distance(actor, unit) <= 6.0

# A successful repair heals only the selected model, never revives a model.
# The hit grant has its own recipient identity and survives source death.
# https://wahapedia.ru/wh40k11ed/factions/orks/Mek (Clever Know-wotz).
act repair_orks_vehicle(ctx Board board, frm SourceInstance instance) -> OrksVehicleRepair:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = instance.owner
    act choose_mek_repair_unit(frm UnitID target) {orks_mek_unit_has_target(board, instance, target)}
    board.orks_selected_unit = target
    act choose_mek_repair_model(frm ModelID repaired) {orks_mek_target_valid(board, instance, target, repaired)}
    board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
    subaction* board.shared_actions.evaluate_random_stat
    board[target][repaired].suffered_wounds = max(0, board[target][repaired].suffered_wounds.value - board.shared_actions.evaluate_random_stat.result.value)
    frm grant : SourceInstance
    grant.rule = ORKS_MEK_REPAIR_RULE
    grant.owner = instance.owner
    grant.source_unit = board[target].identity
    grant.source_model = board[target][repaired].identity
    grant.recipient = SourceTarget::source_model
    grant.duration = SourceDuration::next_own_movement
    grant.label.value = SourceLabel::clever_know_wotz
    frm payload : OrksEffectGrant
    payload.kind = OrksEffectKind::clever_hit
    payload.amount = 1
    grant.grant = payload
    # Repeated repairs reuse the model's grant prototype, while separate
    # effect keys keep both start/end hit contributions until their expiry.
    # A new source slot per repair would exhaust the finite source arena.
    let grant_index = -1
    for source_index in range(board.source_instances.size()):
        ref existing = board.source_instances[source_index]
        if existing.rule.value == ORKS_MEK_REPAIR_RULE and existing.source_model == grant.source_model and existing.duration.value == SourceDuration::next_own_movement.value:
            grant_index = source_index
    if grant_index < 0:
        let handle = register_source_instance(board, grant)
        grant_index = handle.value
    commit_source_effect_to_unit(board, grant, grant_index, board[target].identity)
    board.current_decision_maker = previous_owner

# Unit selection is separate from model selection to preserve Godot inputs.
# Orks/Mek Clever Know-wotz's bearer-to-model range, not unit-anchor range.
fun orks_mek_unit_has_target(Board board, SourceInstance instance, UnitID target) -> Bool:
    if target.get() >= board.units.size():
        return false
    let member : ModelID
    for index in range(board[target].models.size()):
        member = index
        if orks_mek_target_valid(board, instance, target, member):
            return true
    return false

# All-bank command healing calls the same one-wound kernel as existing
# revival cards. Roll optional D3 BEFORE allocating any of the total wounds.
# Sources: Orks/Painboy, Painboss, Big-Mek-In-Mega-Armour;02.02.04.
act orks_command_healing(ctx Board board, frm SourceInstance instance) -> OrksCommandHealing:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = instance.owner
    frm actor = locate_source(board, instance.source_unit, instance.source_model)
    frm bank = actor.bank
    frm target : UnitID
    target = actor.unit.value
    if instance.rule.value == ORKS_PAINBOSS_RULE and bank.value == SourceBank::battlefield.value:
        act choose_painboss_healing_unit(UnitID recipient) {orks_healing_target_valid(board, instance, SourceBank::battlefield, recipient)}
        target = recipient
    frm remaining : FixedStat
    remaining = 3
    if instance.rule.value == ORKS_SURGERY_RULE:
        frm bearer : ModelID
        bearer = source_bank_unit(board, actor.bank, actor.unit.value).find_model(instance.source_model)
        frm token = make_source_usage(source_bank_unit(board, actor.bank, actor.unit.value).owned_by_player1, ORKS_ORDERLY_RULE, source_bank_unit(board, actor.bank, actor.unit.value)[bearer].original_unit, source_bank_unit(board, actor.bank, actor.unit.value)[bearer].identity, SourceUseScope::unit, source_use_limits(0, 0, 0, 1))
        if source_usage_available(board, token):
            act use_grot_orderly(Bool use_orderly)
            if use_orderly:
                commit_source_usage(board, token)
                board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
                subaction* board.shared_actions.evaluate_random_stat
                remaining = remaining.value + board.shared_actions.evaluate_random_stat.result.value
    board.shared_actions.heal_unit = heal_unit(board, source_bank_unit(board, bank, target.get()), bank, remaining)
    subaction*(board, source_bank_unit(board, bank, target.get())) board.shared_actions.heal_unit
    board.current_decision_maker = previous_owner

# Infested War Zone owns eligibility/reserve destination and registration;
# shared construction supplies a fresh battle-start unit (01.02.10).
fun create_orks_replacement(Board board, UnitID destroyed):
    assert(board.reserve_units.has_capacity() and !board[destroyed].battle_start_models.value.empty(), "replacement needs its original roster and a reserve slot")
    let replacement = make_replacement_unit(board, board[destroyed])
    board.reserve_units.append(replacement)
    register_orks_option_passives(board)
    register_orks_force_dispositions(board)
    register_orks_datasheet_sources(board)

# Only private Orks transient state is reset when core creates a new unit.
fun prepare_orks_replacement_unit(Unit unit):
    unit.orks_destroyed_attack = 0
    unit.orks_destroyed_phase = 0
    let psychic : OrksPsychicUsage
    unit.orks_psychic_usage = psychic

# Original upgrade ownership follows the newly allocated replacement component.
fun prepare_orks_replacement_model(Model model, EntityIdentity replacement):
    if model.orks_upgrade_origin.value > 0:
        model.orks_upgrade_origin = replacement
    model.orks_effects.clear()
    model.riled_source_effects.clear()
