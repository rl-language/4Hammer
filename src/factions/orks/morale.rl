import board
import source_effects

# Runtherd and War Horde Breakin' Heads are own-unit shock responses in every
# bank (named source cards; appendix01.02.04). Share eligibility, CP, D3 and
# shock removal; only mortal allocation dispatch depends on location (p24).
act orks_became_shocked(ctx Board board, frm EntityIdentity subject) -> OrksBecameShocked:
    frm location = locate_source(board, subject, invalid_entity_identity())
    if !location.found:
        return
    board.shared_actions.orks_runtherd_shock = orks_runtherd_shock(board, source_bank_unit(board, location.bank, location.unit.value))
    subaction*(board, source_bank_unit(board, location.bank, location.unit.value)) board.shared_actions.orks_runtherd_shock
    location = locate_source(board, subject, invalid_entity_identity())
    if !location.found or !orks_breakin_heads_available(board, source_bank_unit(board, location.bank, location.unit.value)):
        return
    board.orks_support_bank = location.bank
    board.orks_selected_unit = location.unit.value
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = source_bank_unit(board, location.bank, location.unit.value).owned_by_player1
    actions:
        act decline_breakin_heads()
        act breakin_heads()
            board.commit_stratagem(source_bank_unit(board, location.bank, location.unit.value).owned_by_player1, Stratagem::orks_breakin_heads, source_bank_unit(board, location.bank, location.unit.value))
            board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
            subaction* board.shared_actions.evaluate_random_stat
            frm wounds_result_snapshot_1 = board.shared_actions.evaluate_random_stat.result
            frm head_losses : CombatCounter
            head_losses = wounds_result_snapshot_1.value
            frm target : UnitID
            target = location.unit.value
            board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, location.bank, target, target, false, head_losses)
            subaction*(board) board.shared_actions.resolve_mortal_wounds
            location = locate_source(board, subject, invalid_entity_identity())
            if location.found:
                source_bank_unit(board, location.bank, location.unit.value).battle_socked = false
    board.current_decision_maker = previous_owner

# War Horde's explicit shocked-target exception stays in the stratagem
# registry; bank membership does not duplicate or relax its target conditions.
fun orks_breakin_heads_available(Board board, Unit unit) -> Bool:
    return unit.battle_socked and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::infantry) and !unit.attached_units.empty() and board.can_target_strat(unit.owned_by_player1, Stratagem::orks_breakin_heads, unit)

# Battlefield source callers translate selectors at the boundary; reserves and
# passengers already have a stable identity (core pp65/68; appendix01.02.04).
fun orks_became_shocked(Board board, UnitID target) -> OrksBecameShocked:
    let subject = invalid_entity_identity()
    if target.get() < board.units.size():
        subject = board[target].identity
    return orks_became_shocked(board, subject)

# Mob Mentality occurs at the Battle-shock STEP start, after command CP gain,
# before recovery eligibility is frozen; it is not a Command-phase-start rule.
act orks_mob_mentality_step(ctx Board board) -> OrksMobMentalityStep:
    while orks_mob_mentality_available(board):
        actions:
            act decline_mob_mentality()
                break
            act choose_mob_mentality_source(frm UnitID source) {orks_support_card_valid(board, source, Stratagem::orks_mob_mentality, board.current_player, TimingWindow::command_start)}
                board.shared_actions.use_orks_support_card = use_orks_support_card(board, source, Stratagem::orks_mob_mentality)
                subaction*(board) board.shared_actions.use_orks_support_card

# At most one use per payer/phase is consumed when the beneficiary is chosen.
fun orks_mob_mentality_available(Board board) -> Bool:
    let source : UnitID
    for slot in range(board.units.size()):
        source = slot
        if orks_support_card_valid(board, source, Stratagem::orks_mob_mentality, board.current_player, TimingWindow::command_start):
            return true
    return false

# Watchin' is an own-unit, once-per-army ability in every bank; only living
# bearers confer it. Source: Da Boss is Watchin'; appendix01.02.04.
fun orks_watchin_available(Board board, Unit unit) -> Bool:
    if unit.owned_by_player1 != board.current_player or !(board.timing.phase == BattlePhase::movement) or !has_live_model(unit):
        return false
    for member in range(unit.models.size()):
        ref model = unit[member]
        if model.is_alive() and model_has_orks_enhancement(unit, model, OrksEnhancement::da_boss_is_watchin) and source_usage_available(board, make_source_usage(unit.owned_by_player1, 200 + OrksEnhancement::da_boss_is_watchin.value, unit.identity, model.identity, SourceUseScope::army, source_use_limits(0, 0, 0, 1))):
            return true
    return false

# Commit the same army token and persisting grant irrespective of bank
# (Da Boss is Watchin'; appendix01.02.02/01.02.04).
fun commit_orks_watchin(Board board, Unit unit):
    for bearer in range(unit.models.size()):
        if unit[bearer].is_alive() and model_has_orks_enhancement(unit, unit[bearer], OrksEnhancement::da_boss_is_watchin):
            commit_source_usage(board, make_source_usage(unit.owned_by_player1, 200 + OrksEnhancement::da_boss_is_watchin.value, unit.identity, unit[bearer].identity, SourceUseScope::army, source_use_limits(0, 0, 0, 1)))
    grant_orks_own_payload(board, unit, 200 + OrksEnhancement::da_boss_is_watchin.value, riled_up_grant(), SourceDuration::next_own_turn)

# That'll Learn Ya counts actual living Gretchin, not GROTS keywords or
# attached Characters. It directly destroys the chosen models, without FNP.
# https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
fun orks_live_gretchin(Unit unit) -> Int:
    let count = 0
    for member in range(unit.models.size()):
        count = count + int(unit[member].is_alive() and model_matches_datasheet(unit[member], OrksDatasheet::gretchin))
    return count

# Own-unit correction also works in reserves/transports (01.02.04). Spend the
# round token before D3; resolve each normal destruction before clearing shock.
# https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
act orks_runtherd_shock(ctx Board board, ctx Unit unit) -> OrksRuntherdShock:
    if !unit.battle_socked or !unit.has_ability(AbilityKind::thatll_learn_ya) or orks_live_gretchin(unit) < 4:
        return
    frm bearer : ModelID
    for index in range(unit.models.size()):
        if unit[index].is_alive() and unit[index].has_ability(AbilityKind::thatll_learn_ya):
            bearer = index
    frm token = make_source_usage(unit.owned_by_player1, ORKS_RUNTHERD_RULE, unit[bearer].original_unit, unit[bearer].identity, SourceUseScope::unit, source_use_limits(0, 0, 1, 0))
    if !source_usage_available(board, token):
        return
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = unit.owned_by_player1
    act use_runtherd(Bool learn)
    if learn:
        commit_source_usage(board, token)
        board.shared_actions.evaluate_random_stat = evaluate_random_stat(dice_stat(3))
        subaction* board.shared_actions.evaluate_random_stat
        frm remaining = board.shared_actions.evaluate_random_stat.result
        while remaining.value > 0:
            act choose_punished_gretchin(frm ModelID casualty) {casualty.get() < unit.models.size(), unit[casualty].is_alive(), model_matches_datasheet(unit[casualty], OrksDatasheet::gretchin)}
            frm location = locate_source(board, unit.identity, invalid_entity_identity())
            assert(location.found, "Runtherd unit lost its bank")
            frm slot : UnitID
            slot = location.unit.value
            let job = damage_job(DamageKind::normal, slot, slot, false, false, unit[casualty].wounds_left(), unit[casualty].identity)
            job.bank = location.bank
            commit_wound_loss(board, job, casualty, unit[casualty].wounds_left(), false)
            frm jobs : DamageJobs
            board.shared_actions.resolve_damage_jobs = resolve_damage_jobs(board, jobs, false, slot)
            subaction*(board) board.shared_actions.resolve_damage_jobs
            remaining = remaining - 1
        unit.battle_socked = false
    board.current_decision_maker = previous_owner

# Mobbed applies to each engaged enemy MONSTER or VEHICLE, regardless of
# whether it was declared as a charge target. Corpses/offboard units do not roll.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz (Mobbed).
fun orks_mobbed_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    return source.get() >= 0 and source.get() < board.units.size() and target.get() >= 0 and target.get() < board.units.size() and source.get() != target.get() and board[source].has_charged and board[source].has_ability(AbilityKind::mobbed) and !board[source].off_battlefield and !board[target].off_battlefield and has_live_damage_recipient(board[target]) and board[target].owned_by_player1 != board[source].owned_by_player1 and (board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle)) and board[source].is_engaged_with(board[target])

# The13+ threshold is the current combined live strength at charge end,
# not starting strength, original Boy count or a price tier (Mobbed; core p66).
fun orks_mobbed_penalty(Unit unit) -> Int:
    return 1 + int(live_model_count(unit) >= 13)

# Mobbed's owner orders all affected enemy units; each opponent controls its
# own shock rules, then the charge controller is restored. Snapshot the13+
# strength threshold once when this charge-end ability starts resolving.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz (Mobbed).
act resolve_orks_mobbed(ctx Board board, frm UnitID source) -> OrksMobbed:
    frm previous_owner = board.current_decision_maker
    frm penalty : LinearlyDistributedInt<0, 8>
    penalty = orks_mobbed_penalty(board[source])
    frm pending : Bool[MAX_UNIT_COUNT]
    frm remaining : UnitIterator
    let target : UnitID
    for index in range(board.units.size()):
        target = index
        pending[index] = orks_mobbed_target_valid(board, source, target)
        remaining = remaining + int(pending[index])
    while remaining.value > 0:
        board.current_decision_maker = board[source].owned_by_player1
        act choose_mobbed_target(frm UnitID shock_target) {shock_target.get() < board.units.size(), pending[shock_target.get()]}
        pending[shock_target.get()] = false
        remaining = remaining - 1
        if orks_mobbed_target_valid(board, source, shock_target):
            board.shared_actions.battle_shock_test = battle_shock_test(board, board[shock_target], false, false, penalty)
            subaction*(board, board[shock_target]) board.shared_actions.battle_shock_test
    board.current_decision_maker = previous_owner

# Accepted automatic-success effects and Snotling penalties preserve their
# own source lifetimes. They do not recover shock outside the core step
# (Orks cards; core p30; appendix01.02.02).
fun append_orks_battle_shock_roll_effects(Board board, Unit unit, BattleShockRollEffects effects):
    effects.automatic_success = effects.automatic_success or orks_automatic_shock_success(board, unit)
    let penalty = orks_leadership_roll_penalty(board, unit)
    if penalty != 0:
        effects.modifiers.append(rule_modifier(ModifierOperation::subtract, penalty))
