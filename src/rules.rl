import action
import bounded_arg
import string
import learn
import vector2d
import stats
import board
import movement_geometry
import terrain_rules
import attack_dice
import attack_declarations
import damage_rules
import movement_rules

# Wound thresholds use the printed equality boundaries (p.18). The user-
# supplied appendix 02.02.01 caps cumulative roll modifiers at +/-1; a bonus
# reduces the required unmodified result, while protection worsens the roll.
fun required_wound_roll(Board board, AttackSequenceInfo info) -> Int:
    let modifier = info.total_wound_modifier()
    if info.target_toughness.value < info.source.strenght() and info.greater_strenght_wound_protection:
        modifier = modifier - 1
    if info.has_weapon_rule(board, WeaponRuleKind::lance) and board[info.source_unit_id].has_charged:
        modifier = modifier + 1
    return base_wound_threshold(info.source.strenght(), info.target_toughness.value) - min(1, max(-1, modifier))


using StatModifier = LinearlyDistributedInt<0, MAX_STAT_MODIFIER>
using RandomStatResult = LinearlyDistributedInt<0, MAX_RANDOM_STAT_RESULT>
# Rappresents the evaluation of stats such as the damage stat
# of weapons, which sometime is written as 1D6 + 3
# Expose chance results for random attack/damage characteristics and retain
# their full supported increment (pp.17/19; Advance p.33). Fixed characteristics
# are bounded FixedStat values, not primitive Int alternatives (pp.10/17).
act evaluate_random_stat(frm Stat stat, frm  StatModifier fixed_extra) -> RollStat:
    frm result : RandomStatResult 

    if stat is FixedStat:
        result = stat.value + fixed_extra.value
        return

    if stat is Dice:
        frm max_quantity = stat
        # if the stat has a dice component, 
        # selects the value for that dice 
        act quantity(Dice dice) {
            dice.value <= max_quantity.value
        }
        result = dice.value + fixed_extra.value

fun evaluate_random_stat(Stat stat) -> RollStat:
    let zero : StatModifier 
    return evaluate_random_stat(stat, zero)

fun evaluate_random_stat(Stat stat, Int modifier) -> RollStat:
    let mod: StatModifier 
    mod= modifier
    return evaluate_random_stat(stat, mod) 

# Random A is generated separately per weapon at gathering; random D per
# damaging attack after allocation (supplied appendix 02.02.03). Command
# Re-roll targets the controlling unit and spends before replacement (p.56).
act evaluate_weapon_characteristic(ctx Board board, frm Stat stat, frm StatModifier extra, frm Bool player, frm UnitID target) -> WeaponStatRoll:
    subaction* initial = evaluate_random_stat(stat, extra)
    frm result = initial.result
    if stat is Dice:
        frm maximum = stat
        if can_command_reroll(board, player, target, true):
            frm previous_owner = board.current_decision_maker
            board.current_decision_maker = player
            act keep_it(Bool keep)
            if !keep:
                board.commit_stratagem(player, Stratagem::reroll, board[target])
                act reroll(Dice replacement) {replacement.value <= maximum.value}
                result = replacement.value + extra.value
            board.current_decision_maker = previous_owner

# Convert a supported characteristic increment to standard bounded storage,
# rejecting unsupported values rather than silently clamping (pp.17/19).
fun evaluate_weapon_characteristic(Board board, Stat stat, Int extra, Bool player, UnitID target) -> WeaponStatRoll:
    assert(extra >= 0 and extra < MAX_STAT_MODIFIER, "characteristic increment capacity exceeded")
    let bounded : StatModifier
    bounded = extra
    return evaluate_weapon_characteristic(board, stat, bounded, player, target)

# Command Re-roll needs a friendly target and obeys phase/unit use limits
# (pp.54/56). Unknown targets cannot bypass that eligibility gate.
fun can_command_reroll(Board board, Bool player, UnitID target, Bool known) -> Bool:
    return known and target.get() < board.units.size() and board[target].owned_by_player1 == player and board.can_target_strat(player, Stratagem::reroll, board[target])

# Pair chance input stays neutral; the unit's owner decides whether to reroll,
# spends before new dice, then returns control to the caller (pp.9/54/56).
act rerollable_pair_dices_roll(ctx Board board, frm Bool reroll, frm Bool reroll_1s, frm Bool cp_rerollable, frm Bool current_player, frm UnitID strat_target, frm Bool target_known) -> RerollableDicePair:
    frm original_decision_maker = board.current_decision_maker
    act roll_pair(frm Dice result, frm Dice result2)
    frm is_non_cp_rerollable = reroll or (reroll_1s and result == 1)
    let is_cp_rerollable = cp_rerollable and can_command_reroll(board, current_player, strat_target, target_known)
    if is_non_cp_rerollable or is_cp_rerollable:
        board.current_decision_maker = current_player
        act keep_it(Bool do_it)
        if !do_it:
            if !is_non_cp_rerollable:
                board.commit_stratagem(current_player, Stratagem::reroll, board[strat_target])
            act reroll_pair(Dice new_value, Dice new_value2)
            result = new_value
            result2 = new_value2
    board.current_decision_maker = original_decision_maker

# Legacy free-roll callers have no stratagem target; no targetless CP use
# is inferred (p.56). Supply the six-argument overload for a friendly target.
fun rerollable_pair_dices_roll(Board board, Bool reroll, Bool reroll_1s, Bool cp_rerollable, Bool current_player) -> RerollableDicePair:
    let target : UnitID
    return rerollable_pair_dices_roll(board, reroll, reroll_1s, cp_rerollable, current_player, target, false)

# Preserve explicit targeted CP eligibility while keeping action payloads as
# Dice/Dice rather than adding unit selectors to random outcomes (p.56).
fun rerollable_pair_dices_roll(Board board, Bool reroll, Bool reroll_1s, Bool cp_rerollable, Bool current_player, UnitID target) -> RerollableDicePair:
    return rerollable_pair_dices_roll(board, reroll, reroll_1s, cp_rerollable, current_player, target, true)

# Single-die chance and optional reroll decisions restore the same caller
# owner on every path; accepted CP rerolls commit before dice (pp.9/54/56).
act rerollable_dice_roll(ctx Board board, frm Bool reroll, frm Bool reroll_1s, frm Bool cp_rerollable, frm Bool current_player, frm UnitID strat_target, frm Bool target_known) -> RerollableDice:
    frm original_decision_maker = board.current_decision_maker
    act roll(frm Dice result)
    frm is_non_cp_rerollable = reroll or (reroll_1s and result == 1)
    let is_cp_rerollable = cp_rerollable and can_command_reroll(board, current_player, strat_target, target_known)
    if is_non_cp_rerollable or is_cp_rerollable:
        board.current_decision_maker = current_player
        act keep_it(Bool do_it)
        if !do_it:
            if !is_non_cp_rerollable:
                board.commit_stratagem(current_player, Stratagem::reroll, board[strat_target])
            act reroll(Dice new_value)
            result = new_value
    board.current_decision_maker = original_decision_maker

# Targetless compatibility is restricted to free rerolls/chance input (p.56).
fun rerollable_dice_roll(Board board, Bool reroll, Bool reroll_1s, Bool cp_rerollable, Bool current_player) -> RerollableDice:
    let target : UnitID
    return rerollable_dice_roll(board, reroll, reroll_1s, cp_rerollable, current_player, target, false)

# The caller supplies the actual friendly unit targeted by Command Re-roll
# (p.56); selectors remain internal frame state rather than chance payloads.
fun rerollable_dice_roll(Board board, Bool reroll, Bool reroll_1s, Bool cp_rerollable, Bool current_player, UnitID target) -> RerollableDice:
    return rerollable_dice_roll(board, reroll, reroll_1s, cp_rerollable, current_player, target, true)

# Hit modifiers are cumulative before the +/-1 cap (supplied appendix
# 02.02.01). Heavy requires Remained Stationary (p.81); the existing has_moved
# flag represents that legacy choice until movement-mode state in task 11.
fun get_hit_roll_bonus(Board board) -> Int:
    let sum = board.attack_info.total_hit_modifier()
    if board.attack_info.has_weapon_rule(board, WeaponRuleKind::heavy) and !board[board.attack_info.source_unit_id].has_moved:
        sum = sum + 1
    return min(1, max(-1, sum))

# Offer a batch decision only when an original die is eligible. No empty
# reroll-only boundary may stall the sequence (p.18; Command Re-roll p.56).
fun has_batch_reroll(Board board, CombatCounter[6] eligible, Bool reroll_all, Bool reroll_ones, Bool cp_allowed, Bool player, UnitID target) -> Bool:
    for i in range(6):
        if eligible[i] > 0 and (reroll_all or (reroll_ones and i == 0) or (cp_allowed and can_command_reroll(board, player, target, true))):
            return true
    return false

# Collect every original result before offering re-rolls or evaluating the
# batch (p.18; supplied appendix modifiers apply after re-rolls). Separate
# original eligibility counts prevent re-rolling a replacement result.
act collect_attack_dice(ctx Board board, frm CombatCounter count, frm Bool reroll_all, frm Bool reroll_ones, frm Bool cp_allowed, frm Bool player, frm UnitID strat_target) -> AttackDiceBatch:
    frm pool : AttackDicePool
    frm original_owner = board.current_decision_maker
    while pool.total < count:
        act roll(Dice value)
        pool.add(value)
    frm eligible = pool.faces
    board.current_decision_maker = player
    while has_batch_reroll(board, eligible, reroll_all, reroll_ones, cp_allowed, player, strat_target):
        actions:
            act keep_batch()
                break
            act select_reroll(frm Dice original) {
                eligible[original.value - 1] > 0,
                reroll_all or (reroll_ones and original == 1) or (cp_allowed and can_command_reroll(board, player, strat_target, true))
            }
                if !(reroll_all or (reroll_ones and original == 1)):
                    board.commit_stratagem(player, Stratagem::reroll, board[strat_target])
                eligible[original.value - 1] = eligible[original.value - 1] - 1
                act reroll(Dice replacement)
                pool.replace(original, replacement)
    board.current_decision_maker = original_owner

# Resolve the complete group's hit batch before its wound batch (pp.17–18).
# Critical-only Lethal Hits bypasses wound rolls; Sustained additional hits
# require their own wound rolls and are not additional critical hits (pp.82/84).
act resolve_attack_dice(ctx Board board, ctx Unit target, ctx Unit source_unit, frm CombatCounter count) -> GroupAttackDice:
    frm generated_hits : CombatCounter
    frm generated_wounds : CombatCounter
    frm generated_critical_wounds : CombatCounter
    if count > 0 and board.attack_info.source.range() > 0:
        board.record_ranged_attacks(board.attack_info.source_unit_id)
    if board.attack_info.source.skill() == 0 or board.attack_info.has_weapon_rule(board, WeaponRuleKind::torrent):
        generated_hits = count
    else:
        board.current_state = CurrentStateDescription::hit_roll
        subaction*(board) hits = collect_attack_dice(board, count, board.attack_info.reroll_hits, board.attack_info.reroll1_hits, true, source_unit.owned_by_player1, board.attack_info.source_unit_id)
        frm hit_face : Dice
        for i in range(6):
            hit_face = i + 1
            let outcome = classify_attack_hit(board, board.attack_info, hit_face, get_hit_roll_bonus(board))
            if outcome == AttackRollResult::critical:
                add_attack_count(generated_hits, hits.pool.faces[i].value * board.attack_info.max_weapon_parameter(board, WeaponRuleKind::sustained_hit))
                if board.attack_info.has_weapon_rule(board, WeaponRuleKind::letal_hits):
                    add_attack_count(generated_wounds, hits.pool.faces[i].value)
                else:
                    add_attack_count(generated_hits, hits.pool.faces[i].value)
            else:
                if outcome == AttackRollResult::success:
                    add_attack_count(generated_hits, hits.pool.faces[i].value)
    if generated_hits > 0:
        board.current_state = CurrentStateDescription::wound_roll
        subaction*(board) wounds = collect_attack_dice(board, generated_hits, board.attack_info.reroll_wounds, board.attack_info.reroll1_wounds, true, source_unit.owned_by_player1, board.attack_info.source_unit_id)
        frm wound_result : Dice
        frm wound_index : BInt<0, 7>
        while wound_index.value < 6:
            wound_index = wound_index + 1
            wound_result = wound_index.value
            let outcome = classify_attack_wound(board, board.attack_info, wound_result, required_wound_roll(board, board.attack_info))
            if outcome == AttackRollResult::failed:
                continue
            if outcome == AttackRollResult::critical and board.attack_info.has_weapon_rule(board, WeaponRuleKind::devastating_wounds):
                add_attack_count(generated_critical_wounds, wounds.pool.faces[wound_result.value - 1].value)
            else:
                add_attack_count(generated_wounds, wounds.pool.faces[wound_result.value - 1].value)
    board.current_state = CurrentStateDescription::none

# Declare the target owner's full allocation order before saves (p.19). Even
# mandatory singleton choices retain a finite group selector for the editor.
act declare_allocation_order(ctx Board board, frm AllocationGroups groups, frm Bool player) -> AllocationOrder:
    frm order : CheckedVector<AllocationGroupID, MAX_UNIT_MODELS>
    frm chosen : Bool[MAX_UNIT_MODELS]
    board.current_state = CurrentStateDescription::allocation_order
    board.current_decision_maker = player
    while order.size() < groups.size():
        act choose_save_group(frm AllocationGroupID group) {allocation_order_valid(groups, chosen, group)}
        order.append(group)
        chosen[group.value] = true

# Feel No Pain rolls for every would-be wound in a normal damage application
# before committing losses; mortals call this with one wound (p.81).
act prevent_wound_loss(ctx Board board, frm UnitID target, frm ModelID model, frm CombatCounter amount) -> WoundPrevention:
    frm lost : CombatCounter
    frm count : CombatCounter
    frm threshold : LinearlyDistributedInt<0, 11>
    threshold = board[target][model].profile.feel_no_pain()
    if threshold > 6:
        lost = amount
        return
    board.current_decision_maker = board[target].owned_by_player1
    board.current_state = CurrentStateDescription::feel_no_pain_roll
    while count < amount:
        act roll(Dice prevention)
        if prevention.value < threshold.value:
            lost = lost + 1
        count = count + 1

# Finite jobs and a nonrecursive destruction scan let immediate death effects
# interrupt mortal allocation, while attack-triggered deaths wait (pp.24/80/87).
# Job snapshots, not references into the work vector, survive child actions.
act resolve_damage_jobs(ctx Board board, frm DamageJobs jobs, frm Bool finish_attacks, frm UnitID finished_source) -> DamageResolution:
    frm previous_owner = board.current_decision_maker
    frm previous_target = board.attack_info.target_unit_id
    frm current_job : DamageJob
    frm event : PendingDestruction
    frm casualty : Model
    frm absent_source : Unit
    frm retaliation : CombatCounter
    while true:
        event = next_destruction(board, finish_attacks, finished_source)
        if event.found:
            board.current_decision_maker = board[event.unit].owned_by_player1
            act choose_destruction_unit(frm UnitID dying_unit) {destruction_unit_valid(board, dying_unit, board.current_decision_maker, finish_attacks, finished_source)}
            event.unit = dying_unit
            board.attack_info.target_unit_id = dying_unit
            act resolve_destruction_model(frm ModelID dying_model) {dying_model.get() < board[dying_unit].models.size(), destruction_ready(board[dying_unit][dying_model], finish_attacks, finished_source)}
            event.model = dying_model
            casualty = board[event.unit][event.model]
            board[event.unit][event.model].destruction_pending = false
            absent_source.owned_by_player1 = !board[event.unit].owned_by_player1
            retaliation = 0
            if casualty.destroying_unit_known:
                subaction*(board, board[casualty.destroying_unit], casualty) triggered = on_model_destroyed(board, board[casualty.destroying_unit], casualty)
                retaliation = triggered.generated_mortal
            else:
                subaction*(board, absent_source, casualty) uncredited = on_model_destroyed(board, absent_source, casualty)
            # Retain physical presence through the triggered effects; removal
            # is queued beneath their mortal jobs (Deadly Demise p.80).
            if casualty.state == ModelState::pending_destruction:
                jobs.append(damage_job(DamageKind::remove_destroyed, event.unit, casualty.destroying_unit, casualty.destroying_unit_known, false, 0, casualty.identity))
            if casualty.destroying_unit_known and retaliation > 0:
                jobs.append(damage_job(DamageKind::mortal, casualty.destroying_unit, event.unit, true, false, retaliation.value, invalid_entity_identity()))
            if casualty.has_deadly_demise:
                board.current_state = CurrentStateDescription::destruction_roll
                act roll(Dice explosion)
                if explosion == 6:
                    frm nearby : UnitIterator
                    nearby = board.units.size()
                    while nearby.value > 0:
                        nearby = nearby - 1
                        if has_live_attack_recipient(board[nearby.value]) and board[nearby.value].distance(casualty) <= 6.0:
                            subaction* demise_amount = evaluate_random_stat(casualty.deadly_demise)
                            let affected : UnitID
                            affected = nearby.value
                            jobs.append(damage_job(DamageKind::mortal, affected, event.unit, true, false, demise_amount.result.value, invalid_entity_identity()))
            continue
        if jobs.empty():
            break
        current_job = jobs.back()
        jobs.pop()
        if current_job.kind == DamageKind::remove_destroyed:
            let removed = board[current_job.target].find_model(current_job.recipient)
            if removed >= 0:
                board[current_job.target].remove_model(removed)
            continue
        if current_job.amount == 0 or !has_live_attack_recipient(board[current_job.target]):
            continue
        board.attack_info.target_unit_id = current_job.target
        board.current_decision_maker = board[current_job.target].owned_by_player1
        frm recipient : ModelID
        if current_job.recipient.value >= 0:
            let existing = board[current_job.target].find_model(current_job.recipient)
            if existing < 0 or !board[current_job.target][existing].is_alive():
                continue
            recipient = existing
        else:
            board.current_state = CurrentStateDescription::mortal_wound
            act select_mortal_model(frm ModelID mortal_model) {mortal_model_valid(board[current_job.target], mortal_model)}
            recipient = mortal_model
        frm identity = board[current_job.target][recipient].identity
        frm application : CombatCounter
        application = 1
        if current_job.kind == DamageKind::normal:
            application = current_job.amount
        subaction*(board) prevention = prevent_wound_loss(board, current_job.target, recipient, application)
        commit_wound_loss(board, current_job, recipient, prevention.lost.value, current_job.from_attack and board.attack_info.fight_on_death and current_job.target.get() == previous_target.get())
        if !(current_job.kind == DamageKind::normal):
            current_job.amount = current_job.amount - 1
            if current_job.kind == DamageKind::devastating:
                if prevention.lost > 0:
                    current_job.recipient = identity
                else:
                    if current_job.recipient.value == identity.value and board[current_job.target].find_model(identity) >= 0 and board[current_job.target][board[current_job.target].find_model(identity)].suffered_wounds == 0:
                        current_job.recipient = invalid_entity_identity()
            if current_job.amount > 0:
                jobs.append(current_job)
    board.attack_info.target_unit_id = previous_target
    board.current_decision_maker = previous_owner
    board.current_state = CurrentStateDescription::none

# Explicit invalid identity denotes mortal allocation still to be selected;
# it is lifecycle metadata, not an unbounded damage or ML numeric domain.
fun invalid_entity_identity() -> EntityIdentity:
    let identity : EntityIdentity
    return identity

# Ordinary mortals spill by one-wound allocation; damage jobs process immediate
# destruction before the next recipient, with no save roll (pp.24/87).
act resolve_mortal_wounds(ctx Board board, frm UnitID target, frm UnitID source, frm Bool source_known, frm CombatCounter amount) -> MortalWounds:
    frm jobs : DamageJobs
    jobs.append(damage_job(DamageKind::mortal, target, source, source_known, false, amount.value, invalid_entity_identity()))
    subaction*(board) damage = resolve_damage_jobs(board, jobs, false, source)

# Ordered group saves use ascending rerolled results; evaluate each against
# the live current group's characteristics, then apply that attack alone (p.19).
# DEVASTATING WOUNDS follows all normal damage and caps each critical attack
# to one actually damaged model (pp.24/80), with FNP still allowed (p.81).
act resolve_attack_damage(ctx Board board, ctx Unit target, ctx Unit source_unit, frm CombatCounter generated_wounds, frm CombatCounter generated_critical_wounds) -> AttackDamage:
    frm previous_owner = board.current_decision_maker
    if !has_live_attack_recipient(target) or (generated_wounds == 0 and generated_critical_wounds == 0):
        return
    board.identify_unit(target)
    frm groups = make_allocation_groups(board, target, board.attack_info)
    board.active_allocation_groups = groups
    board.active_allocation_target = board.attack_info.target_unit_id
    frm precision : AllocationGroupID
    frm use_precision = false
    if generated_wounds > 0:
        subaction*(board) ordered = declare_allocation_order(board, groups, target.owned_by_player1)
        if board.attack_info.has_weapon_rule(board, WeaponRuleKind::precision):
            frm has_visible = false
            for i in range(groups.size()):
                has_visible = has_visible or (groups[i].character and groups[i].precision_visible)
            if has_visible:
                board.current_decision_maker = source_unit.owned_by_player1
                actions:
                    act skip_precision()
                    act choose_precision_group(frm AllocationGroupID group) {group.value < groups.size(), groups[group.value].character, groups[group.value].precision_visible}
                        precision = group
                        use_precision = true
        board.current_state = CurrentStateDescription::save_roll
        subaction*(board) saves = collect_attack_dice(board, generated_wounds, false, false, true, target.owned_by_player1, board.attack_info.target_unit_id)
        frm face : BInt<1, 8>
        face = 1
        frm order_index : AllocationGroupCounter
        frm active_group : AllocationGroupID
        while face.value <= 6 and has_live_attack_recipient(target):
            if saves.pool.faces[face.value - 1] == 0:
                face = face + 1
                continue
            if use_precision and !allocation_group_alive(target, groups[precision.value]):
                use_precision = false
            while order_index.value < ordered.order.size() and !allocation_group_alive(target, groups[ordered.order[order_index.value].value]):
                order_index = order_index + 1
            if use_precision:
                active_group = precision
            else:
                if order_index.value == ordered.order.size():
                    break
                active_group = ordered.order[order_index.value]
            board.current_decision_maker = target.owned_by_player1
            board.current_state = CurrentStateDescription::allocate_wound
            act allocate_wound(frm ModelID id) {allocation_model_valid(target, groups[active_group.value], id)}
            frm die : Dice
            die = face.value
            saves.pool.faces[face.value - 1] = saves.pool.faces[face.value - 1] - 1
            if attack_save_succeeds(groups[active_group.value], die, board.attack_info.source.penetration() - int(board.attack_info.penetration_bonus)):
                continue
            board.current_state = CurrentStateDescription::damage_roll
            subaction*(board) normal_amount = evaluate_weapon_characteristic(board, board.attack_info.source.damage(), board.attack_info.melta_damage_bonus.value, source_unit.owned_by_player1, board.attack_info.source_unit_id)
            frm jobs : DamageJobs
            jobs.clear()
            jobs.append(damage_job(DamageKind::normal, board.attack_info.target_unit_id, board.attack_info.source_unit_id, true, true, normal_amount.result.value, target[id].identity))
            subaction*(board) normal_damage = resolve_damage_jobs(board, jobs, false, board.attack_info.source_unit_id)
    while generated_critical_wounds > 0 and has_live_attack_recipient(target):
        board.current_decision_maker = target.owned_by_player1
        board.current_state = CurrentStateDescription::mortal_wound
        act allocate_mortal(frm ModelID critical_model) {mortal_model_valid(target, critical_model)}
        frm critical_recipient = target[critical_model].identity
        board.current_state = CurrentStateDescription::damage_roll
        subaction*(board) critical_amount = evaluate_weapon_characteristic(board, board.attack_info.source.damage(), board.attack_info.melta_damage_bonus.value, source_unit.owned_by_player1, board.attack_info.source_unit_id)
        frm critical_jobs : DamageJobs
        critical_jobs.clear()
        critical_jobs.append(damage_job(DamageKind::devastating, board.attack_info.target_unit_id, board.attack_info.source_unit_id, true, true, critical_amount.result.value, critical_recipient))
        subaction*(board) mortal_damage = resolve_damage_jobs(board, critical_jobs, false, board.attack_info.source_unit_id)
        generated_critical_wounds = generated_critical_wounds - 1
    board.current_decision_maker = previous_owner
    board.current_state = CurrentStateDescription::none

# Hazard count is selected weapons, including weapons that never found a
# target (p.81). Collect every hazard before rerolls/damage; 1–2 fails (p.24).
act resolve_hazards(ctx Board board, frm UnitID unit, frm HazardousUses count) -> HazardRolls:
    if count == 0 or !has_live_attack_recipient(board[unit]):
        return
    frm amount : CombatCounter
    amount = count.value
    frm multiplier : LinearlyDistributedInt<1, 4>
    multiplier = hazard_mortal_multiplier(board[unit])
    board.current_state = CurrentStateDescription::hazardous_roll
    subaction*(board) hazards = collect_attack_dice(board, amount, false, false, true, board[unit].owned_by_player1, unit)
    amount = (hazards.pool.faces[0].value + hazards.pool.faces[1].value) * multiplier.value
    subaction*(board) mortals = resolve_mortal_wounds(board, unit, unit, false, amount)

# Preserve the existing one-attack entrypoint for fixtures and legacy callers;
# dice use the same batch pipeline as declared groups (pp.17–18).
act single_attack(ctx Board board, ctx Unit target, ctx Unit source_unit) -> SingleAttack:
    let count : CombatCounter
    count = 1
    subaction*(board, target, source_unit) dice = resolve_attack_dice(board, target, source_unit, count)
    subaction*(board, target, source_unit) damage = resolve_attack_damage(board, target, source_unit, dice.generated_wounds, dice.generated_critical_wounds)

# Dispatch existing on-destruction abilities/stratagems after a casualty (core p.19).
# Feeder Tendrils checks the destroyed model, not the attacker; its faction
# definition is not in the supplied core book and still requires faction-source review.
act on_model_destroyed(ctx Board board, 
                       ctx Unit source, 
                       ctx Model destroyed) -> OnModelDestroyed:
    frm generated_mortal : CombatCounter
    if destroyed.is_character() and source.has_ability(AbilityKind::feeder_tendrils):
        board.add_extra_cp(int(source.owned_by_player1))

    frm previous_owner = board.current_decision_maker
    if !source.empty() and destroyed.has_keyword(Keyword::master_of_possession) and board.can_use_strat(!source.owned_by_player1, Stratagem::violent_unbidding):
        board.current_decision_maker = !source.owned_by_player1
        actions:
            act skip()
            # master of possessions can use violent unbidding
            act use_violent_unbidding() 
                board.commit_stratagem(!source.owned_by_player1, Stratagem::violent_unbidding)
                # roll the dice to select the amount of mortal wounds inflicted
                act roll(frm Dice dice)
                if dice == 1:
                    board.current_decision_maker = previous_owner
                    return
                if dice == 6:
                    generated_mortal = 3
                if dice == 5:
                    act roll(frm Dice damage)
                    generated_mortal = damage.value / 2

    board.current_decision_maker = previous_owner

# resolve all attacks from one source model to a target model,
# given a particular weapon used. the weapon is provided by
# configuring board.attack_info.source
act resolve_weapon(ctx Board board, 
                   frm UnitID source, 
                   frm ModelID current_model, 
                   frm UnitID target) -> ResolveWeapon:
    # Cover is assessed for every target model from this firing model, and
    # changes BS rather than a save or clamped hit modifier (p.50).
    board.attack_info.target_has_cover = board.attack_info.source.range() > 0 and unit_has_benefit_of_cover(board, board[source][current_model], board[target])
    let distance = board[target].distance(board[source][current_model])
    let rapid_fire_attacks = 0
    if distance <= float(board.attack_info.source.range()) / 2.0:
        rapid_fire_attacks = board.attack_info.source.get_rule_parameter(WeaponRuleKind::rapid_fire)

    board.current_state = CurrentStateDescription::quantity_roll
    subaction* attacks_roll = evaluate_random_stat(board.attack_info.source.attacks(),  rapid_fire_attacks)

    if board.attack_info.has_weapon_rule(board, WeaponRuleKind::blast):
       attacks_roll.result = attacks_roll.result + board[target].models.size() / 5


    frm current_attack : RandomStatResult
    while current_attack != attacks_roll.result:
        ref target_unit = board[target]
        subaction* (board, board[target], board[source]) attack = single_attack(board, board[target], board[source])

        current_attack = current_attack + 1
        if board[target].models.size() == 0:
            break

# Configure the selected target before its declared groups and timing effects
# (pp.16–18). Faction consumers remain explicit legacy fixtures for task 17.
fun configure_attack_info(Board board, Int source, Int target, Bool overwatch, Bool melee):
    let attack : AttackSequenceInfo
    attack.source_unit_id = source 
    attack.target_unit_id = target
    if overwatch:
        attack.only_hits_on_6 = true 

    attack.target_toughness = board[target].get_unit_toughtness()
    attack.greater_strenght_wound_protection = board[target].has_greater_strenght_wound_protection()

    if board[target].has_ability(AbilityKind::stealth) and !melee:
        attack.hit_roll_malus = true

    # neurolictor psycological sabuteur
    if board[source].battle_socked and board.any_enemy_in_range_has_ability(board[source], 12.0, AbilityKind::psychological_saboteur):
        attack.hit_roll_malus = true
    if board[target].battle_socked and board.any_enemy_in_range_has_ability(board[target], 12.0, AbilityKind::psychological_saboteur):
        attack.wound_roll_bonus = true

    if target == board.oath_of_moment_target.get():
        if board[source].has_ability(AbilityKind::oath_of_moment):
            attack.reroll_hits = true
        if board[source].has_ability(AbilityKind::fury_of_the_first):
            attack.hit_roll_bonus = true
    board.attack_info = attack

# this is the game sequence where a player selects one or more
# weapons, depending how many the model can use, to fight with 
# the target unit, and resolves those weapons one at the time
# Retain per-model weapon/Hazardous counts through attack decisions
# (weapon declarations p.17; Hazardous p.81). Resolution rewrite is task 9.
act resolve_model_attack(ctx Board board, 
                         frm UnitID source, 
                         frm UnitID target, 
                         frm ModelID current_model, 
                         frm Bool melee) -> ModelAttack:
    board.current_state = CurrentStateDescription::select_weapon

    ref model = board[source][current_model]
    frm hazardous_uses : HazardousUses

    # cache the distance for performance, mark it hidden so it does
    # not get delivered to the gpu, since it is implied
    # by the positions of units anyway
    frm dist : Hidden<Float>
    dist = board[target].distance(model)

    board.attack_info.source_profile = model.profile
    frm used_weapons : Bool[MAX_WEAPONS] 
    while true:
        actions:
            act select_weapon(BInt<0, MAX_WEAPONS> weapon_id) {
                weapon_id < board[source][current_model].weapons.size(),
                !melee or board[source][current_model].weapons[weapon_id.value].range() == 0,
                dist.value <= float(board[source][current_model].weapons[weapon_id.value].range()),
                !board[source].has_run or board[source][current_model].weapons[weapon_id.value].has_rule(WeaponRuleKind::assault),
                !used_weapons[weapon_id.value],
                melee or model_can_see_unit(board, board[source][current_model], board[target])
            }
                board.attack_info.source = board[source][current_model].weapons[weapon_id.value]            
                used_weapons[weapon_id.value] = true
            act skip()
                return
        if board.attack_info.source.has_rule(WeaponRuleKind::hazardous):
            hazardous_uses = hazardous_uses + 1
        subaction*(board) resolve_weapon = resolve_weapon(board, source, current_model, target)
        # in melee you can only attack with one weapon unless it has extra attacks
        if melee and !board.attack_info.has_weapon_rule(board, WeaponRuleKind::extra_attacks):
            return
        
        # pistols can be used instead of other weapons
        if board.attack_info.has_weapon_rule(board, WeaponRuleKind::pistol):
            return
        # early out if we killed everyone
        if board[target].models.size() == 0:
            return

# rappresents all the various stratagems that can 
# be triggered after a target has been elected to attack,
# but before attacks get resolved.
act use_attack_stratagems(ctx Board board, 
                          frm UnitID source, 
                          frm UnitID target, 
                          frm Bool melee) -> UseAttackStratagems:
    frm target_player = bool(board[target].owner_id())
    board.current_decision_maker = board[target].owned_by_player1
    actions:
        act no_defensive_stratagem()
        act tough_as_squig_hide() {
            board.can_target_strat(bool(target_player), Stratagem::tough_as_squig_hide, board[target]),
            board.players_faction[int(target_player)] == Faction::morgrim_butchas
        }
            board[target].phase_modifiers.greater_strenght_wound_protection = true
            board.commit_stratagem(bool(target_player), Stratagem::tough_as_squig_hide, board[target])
        act use_gene_wrought_resiliance() {
            board.can_target_strat(bool(target_player), Stratagem::gene_wrought_resiliance, board[target]),
            board.players_faction[int(target_player)] == Faction::strike_force_octavius
        }
            board[target].phase_modifiers.greater_strenght_wound_protection = true
            board.commit_stratagem(bool(target_player), Stratagem::gene_wrought_resiliance, board[target])
        act use_daemonic_fervour() {
            board.can_target_strat(bool(target_player), Stratagem::demonic_fervour, board[target]),
            board.players_faction[int(target_player)] == Faction::zarkan_daemonkin
        }
            board.commit_stratagem(bool(target_player), Stratagem::demonic_fervour, board[target])
            board.attack_info.fight_on_death = true
            board.attack_info.fight_on_death_roll = 1
        act use_unyielding() {
            board.can_target_strat(bool(target_player), Stratagem::unyielding, board[target]),
            board.players_faction[int(target_player)] == Faction::vengeful_brethren
        }
            board.commit_stratagem(bool(target_player), Stratagem::unyielding, board[target])
            board.attack_info.fight_on_death = true
            board.attack_info.fight_on_death_roll = 4
            if board[source].has_ability(AbilityKind::bladeguard):
                board.attack_info.fight_on_death_roll = 3

    board.current_decision_maker = board[source].owned_by_player1
    actions:
        act no_offensive_stratagem()
        act use_veteran_instincts(){
            board[source].has_keyword(Keyword::terminator),
            board.can_target_strat(!bool(target_player), Stratagem::veteran_instincts, board[source])
        }
            if board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle):
                board.attack_info.reroll_wounds = true 
            else:
                board.attack_info.reroll1_wounds = true 
            board.commit_stratagem(!bool(target_player), Stratagem::veteran_instincts, board[source])
        act use_dark_pact(){
            board.players_faction[int(target_player)] == Faction::zarkan_daemonkin
        }
            board.current_pair_roll = rerollable_pair_dices_roll(board, false, false, false, board[source].owned_by_player1)
            subaction*(board) board.current_pair_roll
            # Generic Leadership is the sum of both dice (p.9); this fixes
            # the existing faction roll without supplying new faction effects.
            if !board[source].leadership_roll_succeeds(board.current_pair_roll.result.value + board.current_pair_roll.result2.value):
                board.current_roll = rerollable_dice_roll(board, false, false, false, !target_player)
                subaction*(board) board.current_roll 
                # The legacy faction effect now uses core mortal allocation/FNP
                # instead of repeatedly damaging model zero (pp.24/81).
                frm pact_damage : CombatCounter
                pact_damage = board.current_roll.result.value
                subaction*(board) pact_mortals = resolve_mortal_wounds(board, source, source, false, pact_damage)
            act select_ability(Bool use_letal_hits)
            if use_letal_hits:
                board.attack_info.add_letal_hits()
            else:
                board.attack_info.add_sustained_hits(1)
                
        act use_swift_kill(){
            melee,
            board[source].has_keyword(Keyword::terminator),

            board.can_target_strat(!bool(target_player), Stratagem::swift_kill, board[source]),
            board.players_faction[int(!target_player)] == Faction::insidious_infiltrators
        }
            board.attack_info.penetration_bonus = true
            board.commit_stratagem(!bool(target_player), Stratagem::swift_kill, board[source])
        act use_vindictive_strategy(){
            board.can_target_strat(!bool(target_player), Stratagem::vindictive_strategy, board[source]),
            board.players_faction[int(!target_player)] == Faction::zarkan_daemonkin
        }
            board.attack_info.reroll1_hits = true
            if board[target].is_below_half_strenght():
                board.attack_info.reroll1_wounds = true
            board.commit_stratagem(!bool(target_player), Stratagem::vindictive_strategy, board[source])
        act use_sacrificial_dagger(){
            board.players_faction[int(!target_player)] == Faction::zarkan_daemonkin,
            board[source].has_ability(AbilityKind::sacrificial_dagger)
        }
            act select_model(frm ModelID model) {
                model.get() < board[source].models.size()
            }
            # Wound-loss prevention/destruction is shared core infrastructure;
            # the faction rule itself still awaits task-17 source validation.
            frm offering_jobs : DamageJobs
            offering_jobs.append(damage_job(DamageKind::normal, source, source, false, false, 1, board[source][model].identity))
            subaction*(board) offering = resolve_damage_jobs(board, offering_jobs, false, source)
            board.attack_info.profile_hit_roll_bonus.append(Profile::aranis_zarkan)
            board.attack_info.profile_wound_roll_bonus.append(Profile::aranis_zarkan)

        if board.players_faction[int(!target_player)] == Faction::tristraen_gilded_blade:

            actions:
                act use_dacatarai_stance() 
                board.attack_info.add_sustained_hits(1)
                act use_rendax_stance()             
                board.attack_info.add_letal_hits()



# Select weapons for this model without rolling any hit/wound dice (p.16).
# Retain the existing SelectWeapon numeric payload and Skip button; melee must
# select its ordinary weapon, then may select additional Extra Attacks weapons.
act declare_model_weapons(ctx Board board, ctx DeclaredWeapons declarations, frm UnitID source, frm ModelID current_model, frm Bool melee) -> DeclareModelWeapons:
    frm selected : Bool[MAX_WEAPONS]
    frm main_selected = false
    board.current_state = CurrentStateDescription::select_weapon
    while true:
        actions:
            act select_weapon(BInt<0, MAX_WEAPONS> weapon_id) {
                weapon_selection_valid(board, source, current_model.get(), weapon_id.value, melee, selected, main_selected)
            }
                declarations.append(make_declared_weapon(board, source, current_model.get(), weapon_id.value))
                selected[weapon_id.value] = true
                if !declarations.back().weapon.has_rule(WeaponRuleKind::extra_attacks):
                    main_selected = true
            act skip() {may_finish_weapon_selection(board, source, current_model.get(), melee, main_selected)}
                break

# Targets are declared for every selected weapon before resolution (pp.16–17).
# Melee shares consume the fixed A budget, with at least one attack per target.
# User-directed assumption: no random-A melee weapons exist. Assert this
# rather than inventing a split policy conflicting with appendix 02.02.03.
act declare_weapon_targets(ctx Board board, frm DeclaredWeapon weapon, frm UnitID source, frm Bool melee) -> DeclareWeaponTargets:
    assert(!melee or weapon_has_fixed_attacks(weapon.weapon), "random-A melee weapons are unsupported by user assumption")
    if !declaration_has_target(board, source, weapon, melee):
        return
    frm remaining : AttackShare
    let attacks = weapon.weapon.attacks()
    if attacks is FixedStat:
        remaining = attacks.value
    frm chosen : UnitID
    while true:
        actions:
            act declare_target(UnitID source_id, frm UnitID target_id) {
                source_id.get() == source.get(),
                declaration_target_valid(board, source, weapon, target_id, melee),
                !weapon.targeted[target_id.get()]
            }
                weapon.targeted[target_id.get()] = true
                # MELTA uses target-selection range, not later positions (p.83).
                if weapon.weapon.range() > 0 and board[target_id].distance(board[source][declared_model_index(board, source, weapon)]) <= float(weapon.weapon.range()) / 2.0:
                    let bonus = board[source].max_weapon_parameter(weapon.weapon, WeaponRuleKind::melta)
                    assert(bonus >= 0 and bonus < MAX_STAT_MODIFIER, "Melta bonus capacity exceeded")
                    weapon.melta_bonus[target_id.get()] = bonus
                chosen = target_id
            act skip_target() {!melee}
                break
        if melee:
            act assign_attacks(AttackShareChoice count) {
                count.value <= remaining.value,
                count.value == remaining.value or has_another_declaration_target(board, source, weapon, melee)
            }
            weapon.shares[chosen.get()] = count.value
            remaining = remaining - count.value
            if remaining > 0:
                continue
        break

# Supplied appendix 04.03.03 permits a new target if the original is no longer
# eligible/viable, including a destroyed target. Preserve the unresolved share;
# no surviving source/target means attacks are lost, not an empty selector.
act revalidate_attack_targets(ctx Board board, ctx DeclaredWeapons declarations, frm UnitID source, frm Bool melee) -> RevalidateAttackTargets:
    frm weapon_index : LinearlyDistributedInt<0, MAX_SELECTED_WEAPONS_PLUS1>
    while weapon_index.value < declarations.size():
        frm old_target : UnitIterator
        while old_target.value < MAX_UNIT_COUNT:
            let id : UnitID
            id = old_target.value
            ref weapon = declarations[weapon_index.value]
            if weapon.targeted[old_target.value] and !weapon.resolved[old_target.value] and !declaration_target_valid(board, source, weapon, id, melee):
                if declaration_has_target(board, source, weapon, melee):
                    actions:
                        act retarget_weapon(UnitID source_id, frm UnitID replacement) {
                            source_id.get() == source.get(),
                            declaration_target_valid(board, source, declarations[weapon_index.value], replacement, melee)
                        }
                            declarations[weapon_index.value].targeted[replacement.get()] = true
                            declarations[weapon_index.value].resolved[replacement.get()] = false
                            declarations[weapon_index.value].shares[replacement.get()] = declarations[weapon_index.value].shares[replacement.get()] + declarations[weapon_index.value].shares[old_target.value].value
                        act discard_attacks()
                declarations[weapon_index.value].resolved[old_target.value] = true
            old_target = old_target.value + 1
        weapon_index = weapon_index + 1

# Snapshot the applicable profile/cover for grouping from a selected weapon
# (p.17). Targeted effects remain the owning target's shared configuration.
fun declared_attack_info(Board board, UnitID source, UnitID target, DeclaredWeapon weapon, AttackSequenceInfo target_info) -> AttackSequenceInfo:
    let info = target_info
    info.source = weapon.weapon
    info.melta_damage_bonus = weapon.melta_bonus[target.get()]
    let model = declared_model_index(board, source, weapon)
    assert(model >= 0, "declared source no longer exists")
    info.source_profile = board[source][model].profile
    info.target_has_cover = info.source.range() > 0 and unit_has_benefit_of_cover(board, board[source][model], board[target])
    return info

# Group comparisons finish in an ordinary helper before any suspension;
# no temporary profile/rule copies cross a dice action boundary (p.17).
fun declared_weapon_matches(Board board, UnitID source, UnitID target, DeclaredWeapon declaration, AttackSequenceInfo info, AttackSequenceInfo target_info) -> Bool:
    let candidate = declared_attack_info(board, source, target, declaration, target_info)
    return attacks_are_identical(board, info, candidate)

# Determine whether a declaration uses its already split fixed-A shares,
# without retaining a narrowed temporary union across an action (p.17).
fun weapon_has_fixed_attacks(Weapon weapon) -> Bool:
    let attacks = weapon.attacks()
    return attacks is FixedStat

# Gather-time additions belong to individual weapons (p.17; Rapid Fire/Blast
# pp.79/83), so different ranges may change A without changing group identity.
fun gathering_extra_attacks(Board board, UnitID source, UnitID target, DeclaredWeapon declaration) -> Int:
    let extra = 0
    if declaration.weapon.range() > 0 and board[target].distance(board[source][declared_model_index(board, source, declaration)]) <= float(declaration.weapon.range()) / 2.0:
        extra = declaration.weapon.get_rule_parameter(WeaponRuleKind::rapid_fire)
    if declaration.weapon.has_rule(WeaponRuleKind::blast):
        extra = extra + board[target].models.size() / 5
    return extra

# Retain a selected weapon value, not a local reference into an iteration,
# while collecting its random A (supplied appendix 02.02.03). Split fixed-A
# melee weapons contribute exactly their previously declared target share.
act gather_weapon_count(ctx Board board, frm UnitID source, frm UnitID target, frm DeclaredWeapon declaration, frm Bool melee) -> WeaponAttackCount:
    frm result : RandomStatResult
    if melee and weapon_has_fixed_attacks(declaration.weapon):
        result = declaration.shares[target.get()].value
    else:
        board.current_state = CurrentStateDescription::quantity_roll
        subaction*(board) generated = evaluate_weapon_characteristic(board, declaration.weapon.attacks(), gathering_extra_attacks(board, source, target, declaration), board[source].owned_by_player1, source)
        result = generated.result

# Gather every identical unresolved weapon; roll random A independently and
# combine afterward (p.17; supplied appendix 02.02.03). Keep the loop's source
# contexts stable and retain only bounded counters/weapon snapshots across dice.
act gather_attack_group(ctx Board board, ctx DeclaredWeapons declarations, frm UnitID source, frm UnitID target, frm AttackWeaponID chosen, frm Bool melee, frm AttackSequenceInfo target_info) -> GatherAttackGroup:
    frm info = declared_attack_info(board, source, target, declarations[chosen.value], target_info)
    frm count : CombatCounter
    frm index : LinearlyDistributedInt<0, MAX_SELECTED_WEAPONS_PLUS1>
    info.precision_visibility_known = true
    let no_visibility : Bool[MAX_UNIT_MODELS]
    info.precision_visible_targets = no_visibility
    while index.value < declarations.size():
        if declarations[index.value].targeted[target.get()] and !declarations[index.value].resolved[target.get()] and declared_weapon_matches(board, source, target, declarations[index.value], info, target_info):
            declarations[index.value].resolved[target.get()] = true
            # PRECISION visibility is the union of actual gathered bearers
            # rather than every member of the source unit (p.84).
            for target_model in range(board[target].models.size()):
                info.precision_visible_targets[target_model] = info.precision_visible_targets[target_model] or model_visible_to_model(board, board[source][declared_model_index(board, source, declarations[index.value])], board[target], board[target][target_model])
            subaction*(board) generated = gather_weapon_count(board, source, target, declarations[index.value], melee)
            add_attack_count(count, generated.result.value)
            declarations[index.value].made_attacks = declarations[index.value].made_attacks or generated.result.value > 0
        index = index + 1
    board.attack_info = info

# Full activation: select all weapons, declare all targets, choose target then
# weapon group and complete that target before another (pp.16–18). Existing
# Attack-triggered destruction waits for all target groups, then Hazardous
# resolves (pp.24/87). Full fight-on-death combat sequencing remains task 14.
act attack(ctx Board board, frm UnitID source, frm UnitID target, frm Bool melee, frm Bool overwatch) -> Attack:
    if board[source].empty():
        return
    board.identify_unit(board[source])
    frm previous_owner = board.current_decision_maker
    frm previous_active = board.timing.active_player
    board.timing.active_player = board[source].owned_by_player1
    board.current_decision_maker = board[source].owned_by_player1
    frm declarations : DeclaredWeapons
    frm model : ModelIterator
    frm hazardous_uses : HazardousUses
    while model.value < board[source].models.size():
        let id : ModelID
        id = model.value
        subaction*(board, declarations) selection = declare_model_weapons(board, declarations, source, id, melee)
        model = model + 1
    frm declaration_index : LinearlyDistributedInt<0, MAX_SELECTED_WEAPONS_PLUS1>
    while declaration_index.value < declarations.size():
        subaction*(board) targets = declare_weapon_targets(board, declarations[declaration_index.value], source, melee)
        declarations.set(declaration_index.value, targets.weapon)
        declaration_index = declaration_index + 1
    while has_unresolved_attacks(declarations):
        board.current_decision_maker = board[source].owned_by_player1
        subaction*(board, declarations) viability = revalidate_attack_targets(board, declarations, source, melee)
        if !has_unresolved_attacks(declarations):
            break
        act choose_attack_target(UnitID unit) {target_has_unresolved_weapons(declarations, unit)}
        target = unit
        configure_attack_info(board, source.get(), target.get(), overwatch, melee)
        subaction*(board) strats = use_attack_stratagems(board, source, target, melee)
        frm target_info = board.attack_info
        board.current_decision_maker = board[source].owned_by_player1
        while target_has_unresolved_weapons(declarations, target):
            subaction*(board, declarations) changed = revalidate_attack_targets(board, declarations, source, melee)
            if !target_has_unresolved_weapons(declarations, target):
                break
            act choose_attack_weapon(frm AttackWeaponID weapon) {
                weapon.value < declarations.size(),
                declarations[weapon.value].targeted[target.get()],
                !declarations[weapon.value].resolved[target.get()]
            }
            subaction*(board, declarations) gathering = gather_attack_group(board, declarations, source, target, weapon, melee, target_info)
            subaction*(board, board[target], board[source]) dice = resolve_attack_dice(board, board[target], board[source], gathering.count)
            subaction*(board, board[target], board[source]) damage = resolve_attack_damage(board, board[target], board[source], dice.generated_wounds, dice.generated_critical_wounds)
    # Finish conditional attack-caused triggers after every declared target,
    # before post-attack Hazardous checks (pp.81/87).
    frm cleanup_jobs : DamageJobs
    subaction*(board) deaths = resolve_damage_jobs(board, cleanup_jobs, true, source)
    for i in range(declarations.size()):
        if declarations[i].weapon.has_rule(WeaponRuleKind::hazardous):
            hazardous_uses = hazardous_uses + 1
    subaction*(board) hazards = resolve_hazards(board, source, hazardous_uses)

    # Retaliation eligibility remains the legacy faction/fighting bridge (task
    # 14), but every retained casualty across all declared targets is cleaned
    # exactly once after its triggers/explicit fight-on-death exception (p.87).
    frm death_unit : UnitIterator
    while death_unit.value < board.units.size():
        if board[death_unit.value].owned_by_player1 != board[source].owned_by_player1:
            model = 0
            while model.value < board[death_unit.value].models.size():
                if board[death_unit.value][model.value].state == ModelState::fight_on_death and board[death_unit.value][model.value].destroying_unit.get() == source.get():
                    frm death_identity = board[death_unit.value][model.value].identity
                    frm retaliate = has_live_attack_recipient(board[source])
                    frm death_roll = board[death_unit.value][model.value].destruction_fight_roll
                    if retaliate and death_roll != 2:
                        act roll(Dice result)
                        retaliate = result.value >= death_roll.value
                    if retaliate:
                        frm dying_unit : UnitID
                        dying_unit = death_unit.value
                        configure_attack_info(board, dying_unit.get(), source.get(), overwatch, melee)
                        board.current_decision_maker = board[dying_unit].owned_by_player1
                        board.timing.active_player = board[dying_unit].owned_by_player1
                        let id : ModelID
                        id = model.value
                        subaction*(board) fight_on_death_attack = resolve_model_attack(board, dying_unit, source, id, melee)
                        cleanup_jobs.clear()
                        subaction*(board) retaliation_deaths = resolve_damage_jobs(board, cleanup_jobs, true, dying_unit)
                    let retained = board[death_unit.value].find_model(death_identity)
                    if retained >= 0:
                        board[death_unit.value].remove_model(retained)
                    continue
                model = model + 1
        death_unit = death_unit + 1
    board.timing.active_player = previous_active
    board.current_decision_maker = previous_owner
    board.current_state = CurrentStateDescription::none


enum ProfileToUse:
    captain_octavius:
        Unit unit = make_octavius()
    librarian_tantus:
        Unit unit = make_tantus()
    terminator_squad:
        Unit unit = make_terminator_squad()
    infernus_squad:
        Unit unit = make_infernus_squad()
    death_shadow:
        Unit unit = make_death_shadow()
    make_lictor:
        Unit unit = make_lictor()
    make_von_ryan_leaper:
        Unit unit = make_von_ryan_leaper()

    fun equal(ProfileToUse other) -> Bool:
        return self.value == other.value




# End-turn coherency applies to both armies, including the opposing army
# (p.14). Empty/retired slots have no models to remove.
fun has_incoherent_units(Board board, Bool player) -> Bool:
    let i = 0
    while i < board.units.size():
        if board[i].owned_by_player1 == player and !board[i].empty() and !board[i].is_coherent():
            return true
        i = i + 1
    return false

# Snap shooting has a friendly unengaged, non-TITANIC source and one enemy
# in 24-inch range and visible under the user-approved area abstraction
# (p.57). Full shooting modes and weapon target rules remain task 12.
fun overwatch_target_valid(Board board, UnitID source, UnitID target) -> Bool:
    return source.get() < board.units.size() and target.get() < board.units.size() and !board[source].empty() and !board[target].empty() and board[source].owned_by_player1 != board[target].owned_by_player1 and board[source].distance(board[target]) <= 24.0 and unit_visible_to_unit(board, board[source], board[target]) and (!board[target].is_lone_operative() or board[source].distance(board[target]) <= 12.0)

# Check a source before offering the timing rule: accepting an option with
# no eligible target would otherwise stall the phase (p.57).
fun overwatch_source_valid(Board board, Bool player, UnitID source) -> Bool:
    if source.get() >= board.units.size() or board[source].owned_by_player1 != player or !board.can_target_strat(player, Stratagem::overwatch, board[source]) or board.is_in_melee(board[source]) or board[source].has_keyword(Keyword::titanic):
        return false
    let i = 0
    while i < board.units.size():
        let target : UnitID
        target = i
        if overwatch_target_valid(board, source, target):
            return true
        i = i + 1
    return false

# Rapid Ingress's target is the reserve unit, not the moving enemy unit;
# its printed first-round/AIRCRAFT exclusions apply (p.57).
fun rapid_ingress_target_valid(Board board, Bool player, UnitID reserve) -> Bool:
    return board.current_round >= 1 and reserve.get() < board.reserve_units.size() and board.reserve_units[reserve.get()].owned_by_player1 == player and !board.reserve_units[reserve.get()].has_keyword(Keyword::aircraft) and board.can_target_strat(player, Stratagem::rapid_ingress, board.reserve_units[reserve.get()])

# Existing Heroic Intervention resolves at end of the opponent's Charge
# phase, targeting a friendly unengaged unit; VEHICLE targets must be CHARACTER/WALKER (p.57).
# Leap to Defend enemy eligibility is known here; the full post-roll charge
# workflow and Into the Fray mode remain tasks 13/15.
fun heroic_source_valid(Board board, Bool player, UnitID source) -> Bool:
    if source.get() >= board.units.size() or board[source].owned_by_player1 != player or board.is_in_melee(board[source]) or (board[source].has_keyword(Keyword::vehicle) and !board[source].has_keyword(Keyword::character) and !board[source].has_keyword(Keyword::walker)) or !board.can_target_strat_with_cost(player, Stratagem::heroic_intervention, board[source], heroic_intervention_cost(board[source])):
        return false
    let i = 0
    while i < board.units.size():
        if !board[i].empty() and board[i].owned_by_player1 != player and board[i].has_charged and board[source].distance(board[i]) <= 12.0:
            return true
        i = i + 1
    return false

# Offer only effects actually available in this window. Owners choose their
# ordering; the active player's group precedes the opposing group (user's
# Rules Sequencing definition; printed boundaries pp.28–30/32/57).
fun timing_rule_available(Board board, TimingWindow window, Bool player, TimingRule rule) -> Bool:
    if window == TimingWindow::turn_end and rule == TimingRule::regain_coherency:
        return has_incoherent_units(board, player)
    if window == TimingWindow::movement_end and player != board.current_player:
        let i = 0
        if rule == TimingRule::rapid_ingress:
            while i < board.reserve_units.size():
                let slot : UnitID
                slot = i
                if rapid_ingress_target_valid(board, player, slot):
                    return true
                i = i + 1
        if rule == TimingRule::fire_overwatch:
            while i < board.units.size():
                let slot : UnitID
                slot = i
                if overwatch_source_valid(board, player, slot):
                    return true
                i = i + 1
    if window == TimingWindow::charge_end and player != board.current_player and rule == TimingRule::heroic_intervention:
        let i = 0
        while i < board.units.size():
            let slot : UnitID
            slot = i
            if heroic_source_valid(board, player, slot):
                return true
            i = i + 1
    if window == TimingWindow::command_abilities:
        if rule == TimingRule::shadow_in_the_warp:
            return board.players_faction[int(player)] == Faction::insidious_infiltrators and !board.has_used_shadow_in_the_warp[int(player)]
        if player != board.current_player:
            return false
        if rule == TimingRule::neural_disruption:
            let i = 0
            while i < board.units.size():
                if board[i].owned_by_player1 == player and !board[i].empty() and board[i].has_ability(AbilityKind::neural_disruption):
                    return true
                i = i + 1
        if rule == TimingRule::oath_of_moment or rule == TimingRule::objective_stratagem:
            return board.players_faction[int(player)] == Faction::strike_force_octavius or board.players_faction[int(player)] == Faction::vengeful_brethren
    return false

# Determine whether another choice is needed without adding empty-window
# buttons. Resolved/declined optional rules are not offered twice (pp.28–30).
fun timing_rules_remaining(Board board, TimingWindow window, Bool player, Bool[8] resolved) -> Bool:
    let i = 0
    while i < 8:
        let rule : TimingRule
        rule.value = i
        if !resolved[i] and timing_rule_available(board, window, player, rule):
            return true
        i = i + 1
    return false

# Owners choose both unit order and removals until every unit is coherent.
# These casualties are archived but deliberately bypass destruction callbacks
# (p.14). Reuse the existing target-unit model selector, then restore it.
act regain_coherency(ctx Board board, frm Bool player) -> RegainCoherency:
    frm previous_target = board.attack.target
    board.current_decision_maker = player
    while has_incoherent_units(board, player):
        act select_incoherent_unit(frm UnitID unit) {
            unit.get() < board.units.size(),
            !board[unit].empty(),
            board[unit].owned_by_player1 == player,
            !board[unit].is_coherent()
        }
        board.attack.target = unit
        while !board[unit].is_coherent():
            act remove_incoherent_model(ModelID model) {model.get() < board[unit].models.size()}
            board[unit].remove_model(model.get())
    board.attack.target = previous_target

# Spend on the selected reserve unit before its ingress effect (pp.54/57).
# Failed/cancelled setup returns it to reserves (p.14); task 11 owns all ingress
# distances/placement conditions beyond the existing geometry validation.
act timing_rapid_ingress(ctx Board board, frm Bool player) -> TimingRapidIngress:
    board.current_decision_maker = player
    act select_ingress_unit(frm UnitID reserve) {rapid_ingress_target_valid(board, player, reserve)}
    board.commit_stratagem(player, Stratagem::rapid_ingress, board.reserve_units[reserve.get()])
    actions:
        act skip()
        act ingress_at(BoardPosition position) {board.units.has_capacity(), setup_at_valid(board, board.reserve_units[reserve.get()], position, MovementKind::ingress, false)}
            enter_from_reserves(board, reserve, position, MovementKind::ingress)

# Fire Overwatch is a choice at the end of the opponent's Movement phase,
# rather than after every individual move/charge (p.57). Full snap-shooting
# declaration/visibility/attack semantics remain with tasks 8/9/12/15.
act timing_overwatch(ctx Board board, frm Bool player) -> TimingOverwatch:
    board.current_decision_maker = player
    act overwatch(frm UnitID source) {overwatch_source_valid(board, player, source)}
    board.commit_stratagem(player, Stratagem::overwatch, board[source])
    act overwatch_target(frm UnitID target) {overwatch_target_valid(board, source, target)}
    board.attack = attack(board, source, target, false, true)
    subaction*(board) board.attack
    board.current_decision_maker = player

# The old per-charge interception prompt is replaced by an end-phase
# timing choice (p.57). This uses the existing charge engine until task 13.
act timing_heroic_intervention(ctx Board board, frm Bool player) -> TimingHeroicIntervention:
    board.current_decision_maker = player
    act select_intervening_unit(frm UnitID source) {heroic_source_valid(board, player, source)}
    board.commit_stratagem_with_cost(player, Stratagem::heroic_intervention, board[source], heroic_intervention_cost(board[source]))
    act intervention_target(frm UnitID target) {
        target.get() < board.units.size(),
        has_live_attack_recipient(board[target]),
        board[target].owned_by_player1 != player,
        board[target].has_charged,
        board[source].distance(board[target]) <= 12.0
    }
    subaction*(board) charge = charge(board, source, target, false)
    board.current_decision_maker = player

# These are existing faction effects, not invented new-edition datasheets.
# Move their input into an individually ordered Command ability (p.30); their
# actual faction definitions still require supplied data in task 17.
act timing_oath_of_moment(ctx Board board) -> TimingOathOfMoment:
    board.current_state = CurrentStateDescription::select_oath_of_moment_target
    actions:
        act select_oath_of_moment_target(frm UnitID unit) {
            unit.get() < board.units.size(),
            !board[unit].empty(),
            board[unit].owned_by_player1 != board.current_player
        }
            board.oath_of_moment_target = unit
        act skip()
    board.current_state = CurrentStateDescription::none

# Correct expenditure/decline bookkeeping for these existing faction options
# (p.54); target semantics require their unsupplied faction rules, task 17.
act timing_objective_stratagem(ctx Board board) -> TimingObjectiveStratagem:
    board.current_state = CurrentStateDescription::use_duty_and_honour
    actions:
        act use_duty_and_honour(frm BInt<0, 4> objective) {
            board.players_faction[int(board.current_player)] == Faction::strike_force_octavius,
            board.get_objective_controller(objective.value) == int(board.current_player),
            board.can_use_strat(board.current_player, Stratagem::duty_and_honour)
        }
            board.commit_stratagem(board.current_player, Stratagem::duty_and_honour)
            board.grant_secured_objective(objective.value, board.current_player)
        act use_pheromone_trail(frm BInt<0, 4> phero_objective) {
            board.players_faction[int(board.current_player)] == Faction::insidious_infiltrators,
            board.get_objective_controller(phero_objective.value) == int(board.current_player),
            board.can_use_strat(board.current_player, Stratagem::pheromone_trace)
        }
            board.commit_stratagem(board.current_player, Stratagem::pheromone_trace)
            board.grant_secured_objective(phero_objective.value, board.current_player)
        act skip()
    board.current_state = CurrentStateDescription::none

# Resolve simultaneous non-mission effects in the user's supplied sequence.
# Each controller chooses among available rule kinds in any order; mission
# effects follow both groups at printed end windows (pp.28–30/32–38/54/57).
# No mission rules or unspecified faction effects are synthesized.
act resolve_timing_window(ctx Board board, frm TimingWindow window) -> TimingWindowResolution:
    board.open_timing_window(window)
    frm player = board.timing.active_player
    # Exactly two controller groups; bounded frame storage supports ML inference.
    frm count : BInt<0, 3>
    frm resolved : Bool[8]
    while count < 2:
        let i = 0
        while i < 8:
            resolved[i] = false
            i = i + 1
        board.current_decision_maker = player
        board.timing.controller = player
        if count == 1:
            board.timing.stage = TimingStage::opposing_player_rules
        while timing_rules_remaining(board, window, player, resolved):
            actions:
                act finish_timing_rules() {!(window == TimingWindow::turn_end) or !has_incoherent_units(board, player)}
                    break
                act choose_timing_rule(frm TimingRule rule) {
                    !resolved[int(rule.value)],
                    timing_rule_available(board, window, player, rule)
                }
                    resolved[int(rule.value)] = true
                    if rule == TimingRule::regain_coherency:
                        subaction*(board) cleanup = regain_coherency(board, player)
                    if rule == TimingRule::rapid_ingress:
                        subaction*(board) ingress = timing_rapid_ingress(board, player)
                    if rule == TimingRule::fire_overwatch:
                        subaction*(board) overwatch = timing_overwatch(board, player)
                    if rule == TimingRule::shadow_in_the_warp:
                        subaction*(board) shadow = shadow_in_the_warp(board, player)
                    if rule == TimingRule::neural_disruption:
                        subaction*(board) neural = neural_disruption(board)
                    if rule == TimingRule::oath_of_moment:
                        subaction*(board) oath = timing_oath_of_moment(board)
                    if rule == TimingRule::heroic_intervention:
                        subaction*(board) intervention = timing_heroic_intervention(board, player)
                    if rule == TimingRule::objective_stratagem:
                        subaction*(board) objective = timing_objective_stratagem(board)
                    board.current_decision_maker = player
        player = !player
        count = count + 1
    # Control is recalculated at every phase/turn end after non-mission
    # effects, before mission achievements (pp.28–30/52).
    board.timing.stage = TimingStage::mission_rules
    if window == TimingWindow::command_end or window == TimingWindow::movement_end or window == TimingWindow::shooting_end or window == TimingWindow::charge_end or window == TimingWindow::fight_end:
        board.update_objective_control(true)
    if window == TimingWindow::turn_end:
        board.update_objective_control(false)
    if window == TimingWindow::command_end:
        board.score()
    board.close_timing_window()

enum Player:
    player_1
    player_2

# Editor fixture helper: initialize entity identity/starting strength on creation
# to support later lifecycle rules (starting strength p.86; destruction p.19).
act spawn_unit(ctx Board board) -> PickUnit:
    act spawn(frm ProfileToUse profile)
    act set_owner(frm Player player)
    frm unit = profile.unit()
    unit.owned_by_player1 = player.value == 0
    board.identify_unit(unit)
    unit.capture_starting_strength()
    actions:
        act place_in_reserve()
            board.reserve_units.append(unit)
        act place_at(frm BoardPosition position) {setup_candidate_valid(board, unit, position)}
            # Fixture setup must obey full-base placement too (pp.12/14).
            unit.try_arrange_at(position)
            board.units.append(unit)

# Roll against any Leadership characteristic (p.9). Only a successful roll
# in the Command Battle-shock step clears shock present at that step's start
# (p.30). Insane Bravery is restricted to that step and once per battle (p.56).
act battle_shock_test(ctx Board board, ctx Unit unit, frm Bool command_step, frm Bool recover_shock) -> BattleShockTest:
    if unit.empty():
        return
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = unit.owned_by_player1
    frm auto_pass = false
    if command_step and board.timing.phase == BattlePhase::command and unit.owned_by_player1 == board.current_player and !board.has_used_insane_bravery[int(unit.owned_by_player1)] and board.can_target_strat(unit.owned_by_player1, Stratagem::insane_bravery, unit):
        act insane_bravery(Bool do_it)
        if do_it:
            board.commit_stratagem(unit.owned_by_player1, Stratagem::insane_bravery, unit)
            auto_pass = true
    if !auto_pass:
        # Leadership/Battle-shock is absent from Command Re-roll's list (p.56).
        board.current_pair_roll = rerollable_pair_dices_roll(board, false, false, false, unit.owned_by_player1)
        subaction*(board) board.current_pair_roll
        if !unit.leadership_roll_succeeds(board.current_pair_roll.result.value + board.current_pair_roll.result2.value):
            unit.battle_socked = true
        else:
            if command_step and recover_shock:
                unit.battle_socked = false
    else:
        if command_step and recover_shock:
            unit.battle_socked = false
    board.current_decision_maker = previous_owner

# Test each live friendly unit once when already shocked or at/below half
# (p.30). Snapshot shock at the step's start for the printed recovery condition;
# never clear the opponent's shock or automatically expire a friendly effect.
act battle_shock_step(ctx Board board) -> BattleShockStep:
    frm shocked_at_start : Bool[MAX_UNIT_COUNT]
    for index in range(board.units.size()):
        shocked_at_start[index] = board[index].battle_socked
    frm i : UnitIterator
    while i != board.units.size():
        if board[i.value].empty() or board[i.value].owned_by_player1 != board.current_player:
            i = i + 1
            continue
        if !board[i.value].battle_socked and !board[i.value].is_at_or_below_half_strength():
            i = i + 1
            continue
        subaction*(board, board[i.value]) shock_test = battle_shock_test(board, board[i.value], true, shocked_at_start[i.value])
        i = i + 1


# tyranids shadow in the warp rules
act shadow_in_the_warp(ctx Board board, frm Bool player) -> ShadowInTheWarp:
    if !(board.players_faction[int(player)] == Faction::insidious_infiltrators) or board.has_used_shadow_in_the_warp[int(player)]:
        return
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = player
    act use_shadow_in_the_warp(Bool do_it)
    if do_it:
        board.has_used_shadow_in_the_warp[int(player)] = true
        frm i : UnitIterator
        while i != board.units.size():
            if !board[i.value].empty() and board[i.value].owned_by_player1 != player:
                subaction*(board, board[i.value]) shock_test = battle_shock_test(board, board[i.value], false, false)
            i = i + 1
    board.current_decision_maker = previous_owner

# tyranids neural disruption rules 
# Exclude destroyed target slots from this existing faction decision
# (destroyed units p.19). Neural Disruption itself needs supplied faction data.
act neural_disruption(ctx Board board) -> NeuralDisruption:
    if !(board.players_faction[int(board.current_player)] == Faction::insidious_infiltrators):
        return
    frm used : Bool[MAX_UNIT_COUNT]
    while true:
        actions:
            act skip()
                break
            act select_neural_disruption_target(frm UnitID source, frm UnitID target) {
                source.get() < board.units.size(),
                has_live_attack_recipient(board[source]),
                !used[source.get()],
                board[source].owned_by_player1 == board.current_player,
                board[source].has_ability(AbilityKind::neural_disruption),
                target.get() < board.units.size(),
                has_live_attack_recipient(board[target]),
                board[target].owned_by_player1 != board.current_player,
                board[source].distance(board[target]) <= 12.0
            }
                used[source.get()] = true
                subaction*(board, board[target]) shock_test = battle_shock_test(board, board[target], false, false)

# core rule command phase 
# Gain both players' Core CP before Battle-shock, then resolve Command
# abilities (p.30). Start/end windows are owned by turn(), not repeated here.
act command_phase(ctx Board board) -> CommandPhase:
    for i in range(2):
        board.command_points[i] = board.command_points[i] + 1
    # Recovery is a roll here rather than automatic shock expiration (p.30).
    subaction*(board) shock_step = battle_shock_step(board)
    subaction*(board) abilities = resolve_timing_window(board, TimingWindow::command_abilities)
    board.current_decision_maker = board.current_player

# core rules overwatch sequence
# Only spend/record Overwatch when an affordable opponent accepts it
# (cost/player p.54; Overwatch p.55). New timing/targets remain task 15.
act overwatch(ctx Board board, frm UnitID moved_unit) -> Overwatch:
    if board[moved_unit].empty() or !board.can_use_strat(!board[moved_unit].owned_by_player1, Stratagem::overwatch):
        return
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = !board[moved_unit.get()].owned_by_player1
    board.current_state = CurrentStateDescription::overwatch
    actions:
        act skip()
        act overwatch(frm UnitID source) {
            source.get() < board.units.size(),
            has_live_attack_recipient(board[source]),
            !board[moved_unit].is_lone_operative() or board[source].distance(board[source]) < 12.0,
            24.0 > board[source.get()].distance(board[moved_unit.get()]),
            board[source.get()].owned_by_player1 == !board[moved_unit].owned_by_player1,
            board[source].can_shoot,
            board.can_target_strat(!board[moved_unit].owned_by_player1, Stratagem::overwatch, board[source])
        }
            board.commit_stratagem(!board[moved_unit].owned_by_player1, Stratagem::overwatch, board[source])
            board.attack = attack(board, source, moved_unit, false, true)
            subaction*(board) board.attack
    board.current_state = CurrentStateDescription::none
    board.current_decision_maker = previous_owner

# core rules movement rules, including the possiblity 
# of advancing and the triggering of overwatches
# Keep the full Advance increment and record the movement phase
# (Normal/Advance pp.32–33). Validate each model/path and final coherency (p.12);
# Independent model paths share the existing BoardPosition grid and ctx
# contracts; stage positions until complete final coherency passes (pp.12/87).
act move(ctx Board board, ctx UnitID unit, frm StatModifier additional_movement) -> Move:
    if unit.get() >= board.units.size() or !has_live_model(board[unit]) or board[unit].history.ingress_locked:
        return
    frm previous_owner = board.current_decision_maker
    frm previous_active = board.timing.active_player
    frm previous_mover : UnitID
    previous_mover = board.moving_unit
    frm original : Unit
    original = board[unit]
    frm candidate : Unit
    candidate = original
    frm kind = original.pending_move_kind
    if kind == MovementKind::stationary:
        kind = MovementKind::normal
    frm extra = additional_movement
    frm override_m : MovementOverride
    override_m = original.movement_override.value
    frm skies = original.move_takes_to_skies
    frm selected : Bool[MAX_UNIT_MODELS]
    frm finished = false
    frm completed = false
    board.moving_unit = unit
    board.current_decision_maker = original.owned_by_player1
    board.timing.active_player = original.owned_by_player1
    while !finished:
        actions:
            act skip()
                finished = true
            act finish_move() {complete_move_valid(board, original, candidate, unit, kind, extra.value)}
                board[unit] = candidate
                completed = true
                finished = true
            act move_to(BoardPosition position) {rigid_move_valid(board, original, unit, position, kind, extra.value, override_m.value, skies)}
                candidate = original
                translate_move_candidate(board, original, candidate, unit, position, kind, extra.value, override_m.value, skies)
                board[unit] = candidate
                completed = true
                finished = true
            act select_moving_model(frm ModelID model) {model.get() < original.models.size(), original[model].is_alive(), !selected[model.get()]}
                frm path : ModelPath
                path.points.clear()
                path.model = model
                path.final_rotation = original[model].geometry.rotation
                frm model_done = false
                frm rotated = false
                while !model_done:
                    actions:
                        act finish_model()
                            if path.points.size() > 0:
                                candidate[model].set_geometry_position(path.points.back())
                            candidate[model].geometry.rotation = path.final_rotation
                            candidate[model].history.distance_moved_this_turn = original[model].history.distance_moved_this_turn.value + path_distance(original[model], path, skies) / float(MICROMETRES_PER_INCH)
                            selected[model.get()] = true
                            model_done = true
                        act waypoint(BoardPosition position) {waypoint_valid(board, original, path, position, kind, extra.value, override_m.value, skies)}
                            path.points.append(geometry_point(position.x.value * MICROMETRES_PER_INCH, position.y.value * MICROMETRES_PER_INCH, original[model].geometry_position().z.value))
                        act rotate_model(MovementRotation rotation) {!rotated}
                            path.final_rotation = rotation.value * 1000
                            rotated = true
    if completed:
        # Any completed move, including out-of-phase moves, blocks a later
        # surge in this phase (p.70); stationary never enters this action.
        board[unit].history.last_move_phase = board.phase_serial
    board.moving_unit = previous_mover
    board.timing.active_player = previous_active
    board.current_decision_maker = previous_owner

# Bound an internal allowance while retaining the legacy three-argument
# context used by existing out-of-phase moves (pp.12/33).
fun move(Board board, UnitID unit, Int additional_movement) -> Move:
    let modifier : StatModifier
    modifier = additional_movement
    return move(board, unit, modifier)

# core rules fight step 
# Do not expose empty retired slots as fighting participants/targets
# (destroyed units p.19; fighting pp.38–43). Fight sequencing is task 14.
act fight_step(ctx Board board, frm Bool fight_first_phase) -> FightStep:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = !board.current_player
    frm have_passed = [false, false]
    while !have_passed[0] or !have_passed[1]:
        actions:
            act end_fight_step()
                have_passed[int(board.current_decision_maker)] = true
                board.current_decision_maker = !board.current_decision_maker
            act select_target(frm UnitID source, frm UnitID target) {
                source.get() < board.units.size(),
                has_live_attack_recipient(board[source]),
                target.get() < board.units.size(),
                has_live_attack_recipient(board[target]),
                has_live_attack_recipient(board[target]),
                has_live_attack_recipient(board[source]),
                !board[source.get()].has_fought,
                !fight_first_phase or board.units[source.get()].has_charged or board.units[source.get()].has_ability(AbilityKind::fight_first),
                board.units[source.get()].owned_by_player1 == board.current_decision_maker,
                board.units[target.get()].owned_by_player1 != board.current_decision_maker,
                board[target.get()].get_shortest_vector_to(board[source.get()]).length() < 2.0
            }
                board.units[source.get()].consolidate_torward(board.units[target.get()])
                board.attack = attack(board, source, target, true, false)
                subaction*(board) board.attack
                board[source.get()].has_fought = true
                if have_passed[int(!board.current_decision_maker)]:

                    board.current_decision_maker = !board.current_decision_maker
    board.current_decision_maker = previous_owner

# core rules fight phase
# Correct existing Bestial Bellow target bounds and its actual payer/cost
# (generic stratagem expenditure p.54). Its faction effect requires faction data.
act fight_phase(ctx Board board) -> FightPhase:
    if board.players_faction[int(board.current_player)] == Faction::morgrim_butchas:
        actions:
            act use_bestial_bellow(frm UnitID unit, frm UnitID target) {
                target.get() < board.units.size(),
                has_live_attack_recipient(board[target]),
                unit.get() < board.units.size(),
                !board[unit].empty(),
                board[unit].has_keyword(Keyword::beastboss) or board[unit].has_keyword(Keyword::squighog_boyz),
                board.can_target_strat(board.current_player, Stratagem::bestial_bellow, board[unit]),
                board[target].distance(board[unit]) < 3.0
            }
                board.commit_stratagem(board.current_player, Stratagem::bestial_bellow, board[unit])

                subaction*(board, board[target]) shock_test = battle_shock_test(board, board[target], false, false)
                
            act skip()
    subaction*(board) fight_first_step = fight_step(board, true)
    subaction*(board) fight_step = fight_step(board, false)

# Charge attempts keep the selected unit’s active/decision roles and restore
# the caller afterward (p.8); the complete charge procedure remains task 13.
act charge(ctx Board board, frm UnitID source, frm UnitID target, Bool can_be_overwatched) -> Charge:
    board[source.get()].has_charged = true

    if board[source.get()].models.size() == 0 or board[target.get()].models.size() == 0:
        return 
    frm previous_owner = board.current_decision_maker
    frm previous_active = board.timing.active_player
    board.current_decision_maker = board[source].owned_by_player1
    board.timing.active_player = board[source].owned_by_player1
    board.current_pair_roll = rerollable_pair_dices_roll(board, board[source.get()].can_reroll_charge(), false, true, board[source].owned_by_player1, source)
    subaction*(board) board.current_pair_roll
    let vector = board[source.get()].get_shortest_vector_to(board[target.get()])
    if vector.length() < float(board.current_pair_roll.result.value + board.current_pair_roll.result2.value):
        board[source.get()].translate(vector * 0.9)
    board.timing.active_player = previous_active
    board.current_decision_maker = previous_owner

# Existing Pouncing Leap fixture supplies a free-use discount; its replacement
# faction source is task 17. Core Heroic Intervention's base cost is p.57.
fun heroic_intervention_cost(Unit unit) -> Int:
    if unit.has_ability(AbilityKind::pouncing_leap):
        return 0
    return Stratagem::heroic_intervention.cost()

# core rules charge step
# Exclude destroyed slots from charging/interception choices
# (destroyed units p.19; charges pp.36–37). Revised sequence is task 13.
act charge_phase(ctx Board board) -> ChargePhase:
    board.current_decision_maker = board.current_player 
    frm charge_act : Charge
    while true:
        actions:
            act end_charge()
                break
            act select_target(frm UnitID source, frm UnitID target) {
                source.get() < board.units.size(),
                has_live_attack_recipient(board[source]),
                target.get() < board.units.size(),
                has_live_attack_recipient(board[target]),
                has_live_attack_recipient(board[target]),
                has_live_attack_recipient(board[source]),
                !board.units[source.get()].has_run,
                board.units[source.get()].can_charge,
                !board.units[source.get()].has_charged,
                board.units[source.get()].owned_by_player1 == board.current_player,
                board.units[target.get()].owned_by_player1 != board.current_player,
                board[target.get()].get_shortest_vector_to(board[source.get()]).length() < 12.0
            }
                charge_act = charge(board, source, target, true)
                frm charge_reduction : Bool
                # before charge stratagems
                board.current_decision_maker = !board.current_player
                actions:
                    act skip()
                    act use_overawing_magnificence() {
                        board.faction_of_unit(target) == Faction::tristraen_gilded_blade,
                        board.can_target_strat(!board.current_player, Stratagem::overawing_magnificence, board[target])
                    }
                        charge_reduction = true
                        board.commit_stratagem(!board.current_player, Stratagem::overawing_magnificence, board[target])
                board.current_decision_maker = board.current_player
                subaction*(board) charge_act

                board.current_decision_maker = board.current_player

# Ingress setup validates every base before transfer; failed setup remains
# selectable for another attempt or stationary choice (pp.14/69).
act reserve_deployment(ctx Board board, frm Bool current_player) -> ReserveDeployment:
    frm done_deploying = false
    board.current_decision_maker = current_player
    actions:
        act nothing_to_deploy() {movement_selection_complete(board, current_player)}
            done_deploying = true
        act select_reserve_unit(frm UnitID id) {id.get() < board.reserve_units.size(), has_live_model(board.reserve_units[id.get()]), board.reserve_units[id.get()].owned_by_player1 == current_player, board.reserve_units[id.get()].history.selected_move_phase != board.phase_serial}
            actions:
                act skip()
                act reserve_remain_stationary()
                    board.reserve_units[id.get()].history.selected_move_phase = board.phase_serial
                    board.reserve_units[id.get()].history.move_kind = MovementKind::stationary
                act place_at(BoardPosition position) {board.current_round >= 1, board.units.has_capacity(), setup_at_valid(board, board.reserve_units[id.get()], position, MovementKind::ingress, false)}
                    enter_from_reserves(board, id, position, MovementKind::ingress)

# Desperate Escape rolls one complete hazard batch per model, then applies
# ordinary mortal allocation/FNP/destruction instead of deleting models (pp.24/33).
act desperate_escape(ctx Board board, frm UnitID id) -> DesperateEscapeTest:
    frm count : HazardousUses
    count = board[id].models.size()
    subaction*(board) hazards = resolve_hazards(board, id, count)

# Choose an explicit mutually exclusive move. Random M is determined once
# when selected; advance roll and fall-back hazards precede paths (p.33;
# supplied appendix 02.02.03). A failed staged move can be retried (p.12).
act movement(ctx Board board, frm UnitID id, frm Bool use_the_gilded_spear) -> Movement:
    frm selected = false
    frm kind : MovementKind
    frm extra : StatModifier
    frm previous_override : MovementOverride
    previous_override = board[id].movement_override
    board[id].movement_override = MOVE_M_UNSET
    frm random_index : ModelIterator
    random_index = 0
    while random_index.value < board[id].models.size() and (!board[id][random_index.value].is_alive() or !board[id][random_index.value].has_random_movement):
        random_index = random_index + 1
    if random_index.value < board[id].models.size():
        # Random characteristic determination is not on Command Re-roll's list.
        subaction* random_m = evaluate_random_stat(board[id][random_index.value].random_movement)
        board[id].movement_override = max(1, random_m.result.value) + 1
    while !selected:
        actions:
            act remain_stationary() {battlefield_move_eligible(board, id, MovementKind::stationary)}
                record_move(board, id, MovementKind::stationary)
                selected = true
            act normal_move() {battlefield_move_eligible(board, id, MovementKind::normal)}
                kind = MovementKind::normal
                extra = 2 * int(use_the_gilded_spear)
                selected = true
            act advance(Bool do_it) {battlefield_move_eligible(board, id, MovementKind::advance)}
                kind = MovementKind::normal
                extra = 2 * int(use_the_gilded_spear)
                if do_it:
                    kind = MovementKind::advance
                    board.current_roll = rerollable_dice_roll(board, false, false, true, board[id].owned_by_player1, id)
                    subaction*(board) board.current_roll
                    extra = board.current_roll.result.value
                selected = true
            act ordered_retreat() {battlefield_move_eligible(board, id, MovementKind::ordered_retreat)}
                kind = MovementKind::ordered_retreat
                selected = true
            act desperate_escape() {battlefield_move_eligible(board, id, MovementKind::desperate_escape)}
                kind = MovementKind::desperate_escape
                subaction*(board) escape = desperate_escape(board, id)
                selected = true
    if !(board[id].history.selected_move_phase == board.phase_serial) and has_live_model(board[id]):
        board[id].pending_move_kind = kind
        board[id].move_takes_to_skies = false
        if board[id].has_keyword(Keyword::fly):
            act take_to_skies(Bool do_it)
            board[id].move_takes_to_skies = do_it
        frm mobile = false
        frm was_mobile : Bool[MAX_UNIT_MODELS]
        if board[id].has_ability(AbilityKind::super_heavy_walker):
            act walker_mobile(Bool do_it)
            mobile = do_it
            if mobile:
                for i in range(board[id].models.size()):
                    was_mobile[i] = board[id][i].has_keyword(Keyword::mobile)
                    if !was_mobile[i]:
                        board[id][i].keywords.append(Keyword::mobile)
        subaction*(board, id) player_move = move(board, id, extra)
        if mobile:
            for i in range(board[id].models.size()):
                if !was_mobile[i]:
                    let k = board[id][i].keywords.size() - 1
                    while k >= 0:
                        if board[id][i].keywords[k] == Keyword::mobile:
                            board[id][i].keywords.erase(k)
                        k = k - 1
            if player_move.completed:
                act roll(Dice mobile_hazard)
                if mobile_hazard.value == 1:
                    board[id].battle_socked = true
        if player_move.completed:
            record_move(board, id, kind)
            if kind == MovementKind::desperate_escape and !board[id].battle_socked:
                subaction*(board, board[id]) shock = battle_shock_test(board, board[id], false, false)
        else:
            # The move failed and returns all positions. Selection still has a
            # legal stationary/retry path through the phase loop (pp.12/32).
            board[id].history.move_kind = MovementKind::stationary
    if !has_live_model(board[id]):
        board[id].history.selected_move_phase = board.phase_serial
    board[id].movement_override = previous_override
    board[id].move_takes_to_skies = false
    board[id].pending_move_kind = MovementKind::normal

# Every friendly unit must be selected exactly once, including reserves.
# No remaining arbitrary end-phase escape bypasses mandatory selection (p.32).
act movement_phase(ctx Board board) -> MovementPhase:
    board.current_decision_maker = board.current_player
    while true:
        actions:
            act end_move() {movement_selection_complete(board, board.current_player)}
                break
            act move_unit(frm UnitID id) {id.get() < board.units.size(), has_live_model(board[id]), board[id].owned_by_player1 == board.current_player, board[id].history.selected_move_phase != board.phase_serial}
                frm use_gilded_spear = false
                # Preserve this legacy supplied-roster hook without inventing
                # new faction authority; exact faction replacement is task 17.
                if board.get_current_player_faction() == Faction::tristraen_gilded_blade and board.can_target_strat(board.current_player, Stratagem::the_gilded_spear, board[id]):
                    act use_gilded_spear(Bool do_it)
                    use_gilded_spear = do_it
                    if do_it:
                        board.commit_stratagem(board.current_player, Stratagem::the_gilded_spear, board[id])
                subaction*(board) chosen_move = movement(board, id, use_gilded_spear)
            act select_reserve_unit(frm UnitID reserve_id) {reserve_id.get() < board.reserve_units.size(), has_live_model(board.reserve_units[reserve_id.get()]), board.reserve_units[reserve_id.get()].owned_by_player1 == board.current_player, board.reserve_units[reserve_id.get()].history.selected_move_phase != board.phase_serial}
                actions:
                    act skip()
                    act reserve_remain_stationary()
                        board.reserve_units[reserve_id.get()].history.selected_move_phase = board.phase_serial
                        board.reserve_units[reserve_id.get()].history.move_kind = MovementKind::stationary
                    act place_at(BoardPosition position) {board.current_round >= 1, board.units.has_capacity(), setup_at_valid(board, board.reserve_units[reserve_id.get()], position, MovementKind::ingress, false)}
                        enter_from_reserves(board, reserve_id, position, MovementKind::ingress)
    board.current_decision_maker = board.current_player

# core rules shooting phase
# Exclude destroyed source/target slots and retain last-attack turn history
# (shooting pp.34–35; destruction p.19). Mode/eligibility rewrite is task 12.
act shooting_phase(ctx Board board) -> ShootingPhase:
    board.current_decision_maker = board.current_player 
    while true:
        actions:
            act end_shooting_phase()
                break
            act select_target(frm UnitID source, frm UnitID target) {
                source.get() < board.units.size(),
                has_live_attack_recipient(board[source]),
                target.get() < board.units.size(),
                has_live_attack_recipient(board[target]),
                !board[target].is_lone_operative() or board[source].distance(board[source]) < 12.0,
                !board[source].has_shoot,
                board[source].can_shoot,
                board.units[source.get()].owned_by_player1 == board.current_player,
                board.units[target.get()].owned_by_player1 != board.current_player,
                unit_visible_to_unit(board, board[source], board[target])
            }
                board[source.get()].has_shoot = true
                board.attack = attack(board, source, target, false, false)
                subaction*(board) board.attack
    
# one of the most important sequences, the whole turn of a single
# player, as specified by the core rules
# Reset turn-local carriers and expire per-phase records at existing boundaries
# (turn/phase sequence pp.28–30). Explicit start/end windows remain task 5.
act turn(ctx Board board, frm Bool player_id) -> Turn:
    board.current_player = player_id
    board.timing.active_player = player_id
    board.current_decision_maker = player_id
    board.start_turn_history()
    subaction*(board) start = resolve_timing_window(board, TimingWindow::turn_start)
    board.begin_phase(BattlePhase::command)
    subaction*(board) command_start = resolve_timing_window(board, TimingWindow::command_start)
    subaction*(board) command_phase = command_phase(board)
    subaction*(board) command_end = resolve_timing_window(board, TimingWindow::command_end)
    board.begin_phase(BattlePhase::movement)
    subaction*(board) movement_start = resolve_timing_window(board, TimingWindow::movement_start)
    subaction*(board) movement_phase = movement_phase(board)
    subaction*(board) movement_end = resolve_timing_window(board, TimingWindow::movement_end)
    board.begin_phase(BattlePhase::shooting)
    subaction*(board) shooting_start = resolve_timing_window(board, TimingWindow::shooting_start)
    subaction*(board) shooting_phase = shooting_phase(board)
    subaction*(board) shooting_end = resolve_timing_window(board, TimingWindow::shooting_end)
    for i in range(board.units.size()):
        board[i].history.ingress_locked = false
    board.begin_phase(BattlePhase::charge)
    subaction*(board) charge_start = resolve_timing_window(board, TimingWindow::charge_start)
    subaction*(board) charge_phase = charge_phase(board)
    subaction*(board) charge_end = resolve_timing_window(board, TimingWindow::charge_end)
    board.begin_phase(BattlePhase::fight)
    subaction*(board) fight_start = resolve_timing_window(board, TimingWindow::fight_start)
    subaction*(board) fight_phase = fight_phase(board)
    subaction*(board) fight_end = resolve_timing_window(board, TimingWindow::fight_end)
    board.clear_phase_modifiers()
    board.timing.phase = BattlePhase::none
    subaction*(board) end = resolve_timing_window(board, TimingWindow::turn_end)
    board.current_decision_maker = board.current_player

# Round start precedes both turns; round end follows both (p.28). The current
# player resolves their group first per the user's sequencing definition.
act round(ctx Board board) -> Round:
    board.current_player = board.starting_player
    board.timing.active_player = board.starting_player
    board.obtained_extra_cp_this_round[0] = false
    board.obtained_extra_cp_this_round[1] = false
    subaction*(board) start = resolve_timing_window(board, TimingWindow::round_start)
    frm player_turn = turn(board, board.starting_player)
    subaction*(board) player_turn
    player_turn = turn(board, !board.starting_player)
    subaction*(board) player_turn
    board.current_player = board.starting_player
    board.timing.active_player = board.starting_player
    subaction*(board) end = resolve_timing_window(board, TimingWindow::round_end)
    expire_unused_reserves(board)

# the game sequence before the battle start where players
# can elect to attach leaders to units
act attach_leaders(ctx Board board) -> AttachLeaderStep:
    board.current_decision_maker = board.starting_player
    frm passed_players = [false, false]
    while !passed_players[0] or !passed_players[1]:
        actions: 
            act done_attaching()
                passed_players[int(board.current_decision_maker)] = true
                board.current_decision_maker = !board.current_decision_maker
            act attack_character(frm UnitID unit_id, frm UnitID char_id) {
                unit_id.get() < board.reserve_units.size(),
                char_id.get() < board.reserve_units.size(),
                board.reserve_units[unit_id.get()].owned_by_player1 == board.current_decision_maker,
                board.reserve_units[char_id.get()].owned_by_player1 == board.current_decision_maker,
                board.reserve_units[char_id.get()].models.size() == 1,
                board.reserve_units[char_id.get()].has_keyword(Keyword::character),
                !board.reserve_units[unit_id.get()].all_have_keyword(Keyword::character)
            }
            board.reserve_units[char_id.get()].attach_to(board.reserve_units[unit_id.get()])
            board.reserve_units.erase(char_id.get())
            if !passed_players[int(!board.current_decision_maker)]:
                board.current_decision_maker = !board.current_decision_maker

# Legacy mission-zone accessor remains for external bindings; actual setup
# always uses complete candidate checks below (pp.14/82).
fun deployment_position_valid(Board board, BoardPosition position, Bool current_player, Bool infiltrates) -> Bool:
    if infiltrates:
        return true
    if current_player:
        return position.y.value <= 5
    return position.y.value >= BOARD_HEIGHT - 5

# Pre-battle reserve choices require explicit points; AIRCRAFT/transport
# formation exceptions await task 16, not invented roster costs (p.68).
act declare_strategic_reserves(ctx Board board) -> DeclareStrategicReserves:
    frm player = board.starting_player
    frm count : BInt<0, 3>
    while count.value < 2:
        board.current_decision_maker = player
        frm finished = false
        while !finished:
            actions:
                act finish_reserve_selection()
                    finished = true
                act choose_strategic_reserve(UnitID reserve) {strategic_reserve_valid(board, player, reserve)}
                    board.reserve_units[reserve.get()].history.strategic_reserve = true
        count = count + 1
        player = !player

# Alternate deploying every non-reserved unit; validate every base's home or
# Infiltrators constraints before removing a reserve entry (pp.14/68/82).
act deploy(ctx Board board) -> Deployment:
    board.current_decision_maker = board.starting_player
    frm passed_players = [false, false]
    while !passed_players[0] or !passed_players[1]:
        actions:
            act done_deploying() {deployment_complete(board, board.current_decision_maker)}
                passed_players[int(board.current_decision_maker)] = true
                board.current_decision_maker = !board.current_decision_maker
            act select_unit(frm UnitID unit_id) {unit_id.get() < board.reserve_units.size(), board.reserve_units[unit_id.get()].owned_by_player1 == board.current_decision_maker, !board.reserve_units[unit_id.get()].history.strategic_reserve, board.units.has_capacity()}
                frm infiltrates = board.reserve_units[unit_id.get()].all_have_ability(AbilityKind::infiltrators)
                actions:
                    act skip()
                    act deploy_at(BoardPosition position) {setup_at_valid(board, board.reserve_units[unit_id.get()], position, MovementKind::normal, infiltrates)}
                        enter_from_reserves(board, unit_id, position, MovementKind::normal)
                        if !passed_players[int(!board.current_decision_maker)]:
                            board.current_decision_maker = !board.current_decision_maker

# A granting rule must explicitly trigger this move and provide its distance;
# no illustrative faction trigger is manufactured (pp.70/74). Closest target,
# per-model obligations and once-per-phase movement are enforced by helpers.
act surge(ctx Board board, frm UnitID source, frm StatModifier distance, frm Bool triggered) -> Surge:
    if !triggered or source.get() >= board.units.size() or !has_live_model(board[source]) or board[source].battle_socked or board.is_in_melee(board[source]) or board[source].history.last_move_phase == board.phase_serial or board[source].history.ingress_locked or !has_surge_target(board, source):
        return
    frm previous_owner = board.current_decision_maker
    frm previous_target = board.surge_target
    board.current_decision_maker = board[source].owned_by_player1
    act select_surge_target(frm UnitID target) {surge_target_valid(board, source, target)}
    board.surge_target = target
    board[source].pending_move_kind = MovementKind::surge
    subaction*(board, source) moved = move(board, source, distance)
    if moved.completed:
        record_move(board, source, MovementKind::surge)
    board[source].pending_move_kind = MovementKind::normal
    board.surge_target = previous_target
    board.current_decision_maker = previous_owner

# Resolve optional Scouts before the first battle round, current player's
# choices before opponent's. Dedicated-transport passengers await task 16
# (pp.78/84/88; user-supplied Rules Sequencing).
act resolve_scouts(ctx Board board) -> ResolveScouts:
    frm player = board.starting_player
    frm count : BInt<0, 3>
    board.prebattle_scouts = true
    while count.value < 2:
        board.current_decision_maker = player
        frm finished = false
        while !finished:
            actions:
                act finish_scouts()
                    finished = true
                act select_scout_unit(frm UnitID scout) {scout.get() < board.units.size(), board[scout].owned_by_player1 == player, !board[scout].history.scouts_resolved, scouts_distance(board[scout]) > 0, unit_in_home_zone(board[scout], player)}
                    board[scout].pending_move_kind = MovementKind::scout
                    frm distance : StatModifier
                    distance = scouts_distance(board[scout])
                    subaction*(board, scout) scout_move = move(board, scout, distance)
                    if scout_move.completed:
                        board[scout].history.scouts_resolved = true
                        record_move(board, scout, MovementKind::scout)
                    board[scout].pending_move_kind = MovementKind::normal
                act select_scout_reserve(frm UnitID reserve) {reserve.get() < board.reserve_units.size(), board.reserve_units[reserve.get()].owned_by_player1 == player, board.reserve_units[reserve.get()].history.strategic_reserve, !board.reserve_units[reserve.get()].history.scouts_resolved, scouts_distance(board.reserve_units[reserve.get()]) > 0, board.units.has_capacity()}
                    actions:
                        act skip()
                        act scout_setup_at(BoardPosition position) {setup_at_valid(board, board.reserve_units[reserve.get()], position, MovementKind::scout, false)}
                            enter_from_reserves(board, reserve, position, MovementKind::scout)
                            board.units.back().history.scouts_resolved = true
        count = count + 1
        player = !player
    board.prebattle_scouts = false
    board.current_decision_maker = board.starting_player

# a 5 rounds battle, inlcuding deployment. 
# Initialize identities before attachments and freeze combined starting counts
# afterward (Leader/Support pp.66–67; starting strength p.86).
act battle(ctx Board board) -> Battle:
    board.identify_units()
    subaction*(board) attach_leaders = attach_leaders(board)
    board.capture_starting_strengths()
    subaction*(board) reserves = declare_strategic_reserves(board)
    subaction*(board) deploy = deploy(board)
    subaction*(board) scouts = resolve_scouts(board)
    while board.current_round != 5:
        subaction*(board) round = round(board)
        board.current_round = board.current_round + 1


# Load transactionally and reject incompatible/invalid identity state; this is
# implementation compatibility, not a tabletop instruction. It protects
# preserved model/unit lifecycle references (destruction/returns pp.19/88).
fun set_state(Game g, String s) -> Bool:
    let candidate = g
    if !from_string(candidate, s):
        return false
    if !valid_state_foundations(candidate.board):
        return false
    g = candidate
    return true

fun main() -> Int:
    let state = play()
    let dice : Dice
    let str = to_string(state).to_indented_lines()
    print(str)
    set_state(state, str)
    if from_string(state, str):
        return 0
    return 1

fun<T> pretty_string(Board b, T obj) -> String:
    if obj is GameSelectWeapon:
        if !(b.get_current_attacking_model().weapons.size() > obj.weapon_id.value):
            return to_string(obj)
        return to_string(b.get_current_attacking_model().weapons[obj.weapon_id.value])
    if obj is GameChooseAttackWeapon:
        if obj.weapon.value < b.attack.declarations.size():
            return to_string(b.attack.declarations[obj.weapon.value].weapon)
    return to_string(obj)


# the game sequence where players are allowed to pick units.
# Assign entity identities as roster models enter state, before attachment or
# casualty bookkeeping (attachments pp.66–67; destruction/returns pp.19/88).
act pick_army(ctx Board board, frm Bool current_player) -> PickFaction:
    board.current_decision_maker = current_player
    actions:
        act pick_strike_force_octavious()
        board.players_faction[int(current_player)] = make_octavious_strike_force(board.reserve_units, current_player)
        act pick_insidious_infiltrators()
        board.players_faction[int(current_player)] = make_insidious_infiltrators(board.reserve_units, current_player)
        act pick_zarkan_deamonkin()
        board.players_faction[int(current_player)] = make_zarkan_deamonkin(board.reserve_units, current_player)
        act pick_morgrim_butcha()
        board.players_faction[int(current_player)] = make_morgrim_butchas(board.reserve_units, current_player)
        act pick_tristean_gilded_blade()
        board.players_faction[int(current_player)] = make_tristrean_gilded_blade(board.reserve_units, current_player)

        act pick_vengeful_brethren()
        board.players_faction[int(current_player)] = make_vengeful_brethren(board.reserve_units, current_player)



    board.identify_units()
