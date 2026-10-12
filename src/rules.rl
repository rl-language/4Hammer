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
import charge_rules
import fight_rules
import core_stratagem_rules
import transport_rules

# Wound thresholds use the printed equality boundaries (p.18). The user-
# supplied appendix 02.02.01 caps cumulative roll modifiers at +/-1; a bonus
# reduces the required unmodified result, while protection worsens the roll.
fun required_wound_roll(Board board, AttackSequenceInfo info) -> Int:
    let modifier = info.total_wound_modifier()
    # Lance consumes only a completed charge move this turn (pp.37/82).
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

# Heavy requires own Shooting phase, no setup/engagement and <=3in per model
# (p.82). Engaged source/target penalties are cumulative before the cap (pp.35/63).
fun get_hit_roll_bonus(Board board) -> Int:
    let sum = board.attack_info.total_hit_modifier() - board.attack_info.engaged_hit_penalties.value
    if board.attack_info.has_weapon_rule(board, WeaponRuleKind::heavy) and (board.attack_info.heavy_bonus or (!board.attack_info.weapon_rules_known and heavy_unit_eligible(board, board.attack_info.source_unit_id))):
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
    # Only Torrent grants automatic hits; skill zero is unavailable profile data (p.85).
    assert(count == 0 or board.attack_info.source.skill() > 0 or board.attack_info.has_weapon_rule(board, WeaponRuleKind::torrent), "missing hit skill without Torrent")
    if board.attack_info.has_weapon_rule(board, WeaponRuleKind::torrent):
        generated_hits = count
    else:
        board.current_state = CurrentStateDescription::hit_roll
        frm hit_rerolls = !board.attack_info.only_hits_on_6 and !(board.attack_info.shooting_kind == ShootingKind::indirect and board.attack_info.has_weapon_rule(board, WeaponRuleKind::indirect_fire))
        subaction*(board) hits = collect_attack_dice(board, count, board.attack_info.reroll_hits and hit_rerolls, board.attack_info.reroll1_hits and hit_rerolls, hit_rerolls, source_unit.owned_by_player1, board.attack_info.source_unit_id)
        # Lethal Hits is optional per critical hit; mixed choices within a
        # batch must remain possible without an exponential action domain (p.82).
        frm lethal_wounds : CombatCounter
        frm lethal_remaining : CombatCounter
        if board.attack_info.has_weapon_rule(board, WeaponRuleKind::letal_hits):
            lethal_remaining = hits.pool.faces[5]
        while lethal_remaining > 0:
            board.current_decision_maker = source_unit.owned_by_player1
            act use_lethal_hits(Bool automatically_wound)
            if automatically_wound:
                lethal_wounds = lethal_wounds + 1
            lethal_remaining = lethal_remaining - 1
        frm hit_face : Dice
        for i in range(6):
            hit_face = i + 1
            let outcome = classify_attack_hit(board, board.attack_info, hit_face, get_hit_roll_bonus(board))
            if outcome == AttackRollResult::critical:
                add_attack_count(generated_hits, hits.pool.faces[i].value * board.attack_info.max_weapon_parameter(board, WeaponRuleKind::sustained_hit))
                add_attack_count(generated_wounds, lethal_wounds.value)
                add_attack_count(generated_hits, hits.pool.faces[i].value - lethal_wounds.value)
            else:
                if outcome == AttackRollResult::success:
                    add_attack_count(generated_hits, hits.pool.faces[i].value)
    if generated_hits > 0:
        board.current_state = CurrentStateDescription::wound_roll
        subaction*(board) wounds = collect_attack_dice(board, generated_hits, board.attack_info.reroll_wounds or board.attack_info.has_weapon_rule(board, WeaponRuleKind::twin_linked), board.attack_info.reroll1_wounds, true, source_unit.owned_by_player1, board.attack_info.source_unit_id)
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
                        if has_live_damage_recipient(board[nearby.value]) and board[nearby.value].distance(casualty) <= 6.0:
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
        if current_job.amount == 0 or !has_live_damage_recipient(board[current_job.target]):
            continue
        board.attack_info.target_unit_id = current_job.target
        board.current_decision_maker = board[current_job.target].owned_by_player1
        frm recipient : ModelID
        if current_job.recipient.value > 0:
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
    if count == 0 or !has_live_damage_recipient(board[unit]):
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
    board.attack_info.plunging_fire = plunging_fire_applies(board, source, current_model.get(), target, board.attack_info.source.range() > 0)
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

    attack.shooting_kind = board[source].shooting_kind
    attack.target_toughness = board[target].get_unit_toughtness()
    attack.greater_strenght_wound_protection = board[target].has_greater_strenght_wound_protection()


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

    board.attack_info.source_profile = model.profile
    frm used_weapons : Bool[MAX_WEAPONS] 
    while true:
        actions:
            act select_weapon(BInt<0, MAX_WEAPONS> weapon_id) {
                weapon_id < board[source][current_model].weapons.size(),
                !melee or board[source][current_model].weapons[weapon_id.value].range() == 0,
                board[target].distance(board[source][current_model]) <= float(board[source][current_model].weapons[weapon_id.value].range()),
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
    if !attack_model_allowed(board, source, current_model.get(), melee):
        return
    frm selected : Bool[MAX_WEAPONS]
    frm main_selected = false
    board.current_state = CurrentStateDescription::select_weapon
    while true:
        actions:
            act select_weapon(frm BInt<0, MAX_WEAPONS> weapon_id) {
                weapon_selection_valid(board, source, current_model.get(), weapon_id.value, melee, selected, main_selected)
            }
                declarations.append(make_declared_weapon(board, source, current_model.get(), weapon_id.value))
                selected[weapon_id.value] = true
                # Duplicate ability choice happens before target declarations (p.78).
                subaction*(board) ability_choices = choose_weapon_abilities(board, declarations.back().selected_rules)
                declarations.back().selected_rules = ability_choices.chosen
                declarations.back().current_target_rules = ability_choices.chosen
                # One Shot is consumed by selection, even if no target remains (p.83).
                if declared_weapon_has_kind(declarations.back(), WeaponRuleKind::one_shot):
                    consume_one_shot_profile(board[source][current_model.get()], weapon_id.value)
                if !declared_weapon_has_kind(declarations.back(), WeaponRuleKind::extra_attacks):
                    main_selected = true
            act skip() {may_finish_all_weapon_selection(board, source, current_model.get(), melee, selected, main_selected)}
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
                snapshot_weapon_target(board, source, weapon, target_id)
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
    frm snap_replacement_selected = false
    while weapon_index.value < declarations.size():
        frm old_target : UnitIterator
        while old_target.value < MAX_UNIT_COUNT:
            let id : UnitID
            id = old_target.value
            ref weapon = declarations[weapon_index.value]
            if weapon.targeted[old_target.value] and !weapon.resolved[old_target.value] and !declaration_target_valid(board, source, weapon, id, melee):
                if declaration_has_replacement_target(board, source, weapon, melee, !snap_replacement_selected):
                    actions:
                        act retarget_weapon(UnitID source_id, frm UnitID replacement) {
                            source_id.get() == source.get(),
                            declaration_target_valid(board, source, declarations[weapon_index.value], replacement, melee, !snap_replacement_selected)
                        }
                            if board[source].shooting_kind == ShootingKind::snap:
                                board[source].snap_target = replacement
                                snap_replacement_selected = true
                            declarations[weapon_index.value].targeted[replacement.get()] = true
                            declarations[weapon_index.value].resolved[replacement.get()] = false
                            snapshot_weapon_target(board, source, declarations[weapon_index.value], replacement)
                            declarations[weapon_index.value].shares[replacement.get()] = declarations[weapon_index.value].shares[replacement.get()] + declarations[weapon_index.value].shares[old_target.value].value
                            declarations[weapon_index.value].shares[old_target.value] = 0
                            declarations[weapon_index.value].targeted[old_target.value] = false
                        act discard_attacks()
                declarations[weapon_index.value].resolved[old_target.value] = true
            old_target = old_target.value + 1
        weapon_index = weapon_index + 1

# Snapshot the applicable profile/cover for grouping from a selected weapon
# (p.17). Targeted effects remain the owning target's shared configuration.
fun declared_attack_info(Board board, UnitID source, UnitID target, DeclaredWeapon weapon, AttackSequenceInfo target_info) -> AttackSequenceInfo:
    let info = target_info
    info.source = weapon.weapon
    info.weapon_rules_known = true
    info.selected_weapon_rules = weapon.current_target_rules
    info.temporary_weapon_abilities.clear()
    info.shooting_kind = board[source].shooting_kind
    info.heavy_bonus = heavy_unit_eligible(board, source)
    info.melta_damage_bonus = 0
    if weapon.half_range[target.get()]:
        info.melta_damage_bonus = chosen_weapon_parameter(board, target, weapon.current_target_rules, WeaponRuleKind::melta)
    let model = declared_model_index(board, source, weapon)
    assert(model >= 0, "declared source no longer exists")
    info.source_profile = board[source][model].profile
    info.engaged_hit_penalties = 0
    info.plunging_fire = plunging_fire_applies(board, source, model, target, info.source.range() > 0)
    info.target_has_cover = info.source.range() > 0 and (target_info.target_has_cover or smoke_cover_applies(board, board[source][model], target) or unit_has_benefit_of_cover(board, board[source][model], board[target]) or (info.shooting_kind == ShootingKind::indirect and info.has_weapon_rule(board, WeaponRuleKind::indirect_fire)))
    info.indirect_stationary_visible = !board[source].has_run and !board[source].history.was_set_up_this_turn and board[source].history.move_kind == MovementKind::stationary and stationary_this_turn(board[source]) and friendly_unit_sees_target(board, source, target)
    let cq = info.has_weapon_rule(board, WeaponRuleKind::pistol) or info.has_weapon_rule(board, WeaponRuleKind::close_quarters)
    let cq_exception = cq and board[source].is_engaged_with(board[target])
    if info.source.range() > 0 and !cq_exception:
        if info.shooting_kind == ShootingKind::close_quarters and monster_vehicle_model(board[source][model]):
            info.engaged_hit_penalties = info.engaged_hit_penalties + 1
        if board.is_in_melee(board[target]) and (board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle)):
            info.engaged_hit_penalties = info.engaged_hit_penalties + 1
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
    if declaration.weapon.range() > 0 and declaration.half_range[target.get()]:
        extra = chosen_weapon_parameter(board, target, declaration.current_target_rules, WeaponRuleKind::rapid_fire)
    if chosen_weapon_has_rule(board, target, declaration.current_target_rules, WeaponRuleKind::blast):
        let magnitude = max(1, chosen_weapon_parameter(board, target, declaration.current_target_rules, WeaponRuleKind::blast))
        extra = extra + magnitude * (declaration.target_model_counts[target.get()].value / 5)
    if chosen_weapon_has_rule(board, target, declaration.current_target_rules, WeaponRuleKind::cleave):
        let targets = 0
        for i in range(MAX_UNIT_COUNT):
            targets = targets + int(declaration.targeted[i])
        if targets == 1:
            extra = extra + chosen_weapon_parameter(board, target, declaration.current_target_rules, WeaponRuleKind::cleave) * (declaration.target_model_counts[target.get()].value / 5)
    assert(extra >= 0 and extra < MAX_STAT_MODIFIER, "weapon attack-bonus capacity exceeded")
    return extra

# Retain a selected weapon value, not a local reference into an iteration,
# while collecting its random A (supplied appendix 02.02.03). Split fixed-A
# melee weapons contribute exactly their previously declared target share.
act gather_weapon_count(ctx Board board, frm UnitID source, frm UnitID target, frm DeclaredWeapon declaration, frm Bool melee) -> WeaponAttackCount:
    frm result : RandomStatResult
    if melee and weapon_has_fixed_attacks(declaration.weapon):
        result = declaration.shares[target.get()].value + gathering_extra_attacks(board, source, target, declaration)
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

# Rules granting abilities after target selection must not silently maximize
# duplicates. Retain the original Select Weapons choice, then choose between
# it and newly granted instances for this target's attacks (p.78; targeted effects p.54).
act prepare_target_weapon_abilities(ctx Board board, ctx DeclaredWeapons declarations, frm UnitID source, frm UnitID target, frm AttackSequenceInfo target_info) -> PrepareTargetWeaponAbilities:
    frm index : LinearlyDistributedInt<0, MAX_SELECTED_WEAPONS_PLUS1>
    while index.value < declarations.size():
        if declarations[index.value].targeted[target.get()] and !declarations[index.value].resolved[target.get()]:
            frm available : WeaponAbilitySet
            available = declarations[index.value].selected_rules
            for i in range(target_info.temporary_weapon_abilities.size()):
                available.append(target_info.temporary_weapon_abilities[i])
            subaction*(board) granted_choices = choose_weapon_abilities(board, available)
            declarations[index.value].current_target_rules = granted_choices.chosen
        index = index + 1

# Full activation: select all weapons, declare all targets, choose target then
# weapon group and complete that target before another (pp.16–18). Existing
# Attack-triggered destruction waits for all target groups, then Hazardous
# resolves (pp.24/87). Supplied Fight on Death retains casualties until their
# own unit attacks or phase end and uses this same grouped attack pipeline.
act attack(ctx Board board, frm UnitID source, frm UnitID target, frm Bool melee, frm Bool overwatch) -> Attack:
    if board[source].empty():
        return
    board.identify_unit(board[source])
    if !melee:
        board[source].history.shot_this_phase = true
    frm previous_owner = board.current_decision_maker
    frm previous_kind = board[source].shooting_kind
    if overwatch:
        board[source].shooting_kind = ShootingKind::snap
        board[source].snap_target = target
        board.attack_info.target_unit_id = target
    frm previous_active = board.timing.active_player
    board.timing.active_player = board[source].owned_by_player1
    board.current_decision_maker = board[source].owned_by_player1
    frm previous_destroyed_attack = board.allow_destroyed_attack
    frm previous_destroyed_unit = board.destroyed_attack_unit
    board.allow_destroyed_attack = melee
    board.destroyed_attack_unit = source
    # Legacy grant thresholds remain explicit fixture data. A failed grant
    # cannot authorise a corpse's attacks; generic timing is the supplied appendix.
    frm grant_model : ModelIterator
    while grant_model.value < board[source].models.size():
        if melee and board[source][grant_model.value].state == ModelState::fight_on_death and board[source][grant_model.value].destruction_fight_roll > 1:
            act roll(Dice grant_face)
            board[source][grant_model.value].destruction_attack_suppressed = grant_face.value < board[source][grant_model.value].destruction_fight_roll.value
        grant_model = grant_model + 1
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
        subaction*(board, declarations) target_abilities = prepare_target_weapon_abilities(board, declarations, source, target, target_info)
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
    release_retained_fighters(board, source)
    board.allow_destroyed_attack = previous_destroyed_attack
    board.destroyed_attack_unit = previous_destroyed_unit
    frm cleanup_jobs : DamageJobs
    subaction*(board) deaths = resolve_damage_jobs(board, cleanup_jobs, true, source)
    for i in range(declarations.size()):
        if declared_weapon_has_kind(declarations[i], WeaponRuleKind::hazardous):
            hazardous_uses = hazardous_uses + 1
    subaction*(board) hazards = resolve_hazards(board, source, hazardous_uses)

    board.timing.active_player = previous_active
    board[source].shooting_kind = previous_kind
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
    return source.get() < board.units.size() and target.get() < board.units.size() and !board[source].empty() and !board[target].empty() and board[source].owned_by_player1 != board[target].owned_by_player1 and live_unit_distance(board[source], board[target]) <= 24.0 and unit_visible_to_unit(board, board[source], board[target])

# Check a source before offering the timing rule: accepting an option with
# no eligible target would otherwise stall the phase (p.57).
fun overwatch_source_valid(Board board, Bool player, UnitID source) -> Bool:
    if source.get() >= board.units.size() or board[source].owned_by_player1 != player or !board.can_target_strat(player, Stratagem::overwatch, board[source]) or board.is_in_melee(board[source]) or board[source].has_keyword(Keyword::titanic) or !has_live_model(board[source]) or board[source].off_battlefield or !board[source].can_shoot or board[source].history.deck_shooting_locked or board[source].history.fell_back_this_turn or board[source].history.action_started or board[source].history.shot_this_phase:
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

# Heroic Intervention's source must be unengaged and eligible for a charge;
# either mode can be available, including Into the Fray against non-chargers
# (pp.36/57). Costs are checked per mode before expenditure.
fun heroic_mode_valid(Board board, Bool player, UnitID source, ChargeKind kind) -> Bool:
    if kind == ChargeKind::ordinary or !charge_source_valid(board, source, player):
        return false
    if board[source].has_keyword(Keyword::vehicle) and !board[source].has_keyword(Keyword::character) and !board[source].has_keyword(Keyword::walker):
        return false
    let cost = heroic_intervention_cost(board[source])
    if kind == ChargeKind::into_the_fray:
        cost = cost + 1
    if !board.can_target_strat_with_cost(player, Stratagem::heroic_intervention, board[source], cost):
        return false
    for i in range(board.units.size()):
        let target : UnitID
        target = i
        if charge_target_valid(board, source, target, 12, kind):
            return true
    return false

# Expose a source choice only if at least one pre-roll Heroic mode is usable
# (p.57); never enter a decision with no legal mode.
fun heroic_source_valid(Board board, Bool player, UnitID source) -> Bool:
    return heroic_mode_valid(board, player, source, ChargeKind::leap_to_defend) or heroic_mode_valid(board, player, source, ChargeKind::into_the_fray)

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
    if window == TimingWindow::shooting_start and rule == TimingRule::smokescreen:
        for i in range(board.units.size()):
            let source : UnitID
            source = i
            if smoke_source_valid(board, player, source):
                return true
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
fun timing_rules_remaining(Board board, TimingWindow window, Bool player, Bool[9] resolved) -> Bool:
    let i = 0
    while i < 9:
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
        act ingress_at(BoardPosition position) {battlefield_entry_available(board, board.reserve_units[reserve.get()]), setup_at_valid(board, board.reserve_units[reserve.get()], position, MovementKind::ingress, false)}
            enter_from_reserves(board, reserve, position, MovementKind::ingress)

# p.57: select and spend before the phase-long cover grant; the enclosing
# start window supplies exact timing and controller ordering.
act timing_smokescreen(ctx Board board, frm Bool player) -> TimingSmokescreen:
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = player
    act smokescreen(UnitID source) {smoke_source_valid(board, player, source)}
    board.commit_stratagem(player, Stratagem::smokescreen, board[source])
    board[source].phase_modifiers.smokescreen = true
    board.current_decision_maker = previous_owner

# p.56: choose bearer then visible unengaged target, roll exactly six dice,
# and use the common mortal/FNP/destruction pipeline (pp.24/81/87).
act resolve_explosives(ctx Board board, frm UnitID source) -> Explosives:
    if !explosives_source_valid(board, source):
        return
    frm previous_owner = board.current_decision_maker
    frm previous_active = board.timing.active_player
    frm previous_mover = board.moving_unit
    board.current_decision_maker = board[source].owned_by_player1
    board.timing.active_player = board[source].owned_by_player1
    board.moving_unit = source
    board.commit_stratagem(board[source].owned_by_player1, Stratagem::explosives, board[source])
    act choose_explosives_model(frm ModelID model) {explosives_model_has_target(board, source, model)}
    act choose_explosives_target(frm UnitID target) {explosives_target_valid(board, source, model, target)}
    frm amount : CombatCounter
    frm index : BInt<0, 7>
    while index < 6:
        act roll(Dice face)
        if face.value >= 4:
            amount = amount + 1
        index = index + 1
    subaction*(board) damage = resolve_mortal_wounds(board, target, source, true, amount)
    board.moving_unit = previous_mover
    board.timing.active_player = previous_active
    board.current_decision_maker = previous_owner

# p.56: choose engaged enemy then engaged source model, roll T dice, cap both
# mortal totals at six and apply both even if the source is destroyed. No
# Command Re-roll is allowed for this stratagem-specific roll (p.56 list).
act resolve_crushing_impact(ctx Board board, frm UnitID source) -> CrushingImpact:
    if !crushing_source_valid(board, source):
        return
    frm previous_owner = board.current_decision_maker
    frm previous_active = board.timing.active_player
    frm previous_mover = board.moving_unit
    board.current_decision_maker = board[source].owned_by_player1
    board.timing.active_player = board[source].owned_by_player1
    board.commit_stratagem(board[source].owned_by_player1, Stratagem::crushing_impact, board[source])
    act choose_impact_target(frm UnitID target) {crushing_target_valid(board, source, target)}
    board.moving_unit = source
    act choose_impact_model(frm ModelID model) {crushing_model_valid(board, source, target, model)}
    frm total : Toughness
    total = board[source][model].profile.thoughness()
    frm index : Toughness
    frm self_amount : CombatCounter
    frm enemy_amount : CombatCounter
    while index < total:
        act roll(Dice face)
        if face.value == 1:
            self_amount = min(6, self_amount.value + 1)
        if face.value >= 5:
            enemy_amount = min(6, enemy_amount.value + 1)
        index = index + 1
    frm jobs : DamageJobs
    # Stack order applies current-player losses first; all destruction effects
    # use the common Rules Sequencing engine, not bespoke casualty deletion.
    jobs.append(damage_job(DamageKind::mortal, target, source, true, false, enemy_amount.value, invalid_entity_identity()))
    jobs.append(damage_job(DamageKind::mortal, source, source, false, false, self_amount.value, invalid_entity_identity()))
    subaction*(board) damage = resolve_damage_jobs(board, jobs, false, source)
    board.moving_unit = previous_mover
    board.timing.active_player = previous_active
    board.current_decision_maker = previous_owner

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

# Choose Heroic's mode before rolling, commit its actual cost, then use the
# same post-roll multi-target movement as normal charges (pp.36–37/57).
act timing_heroic_intervention(ctx Board board, frm Bool player) -> TimingHeroicIntervention:
    board.current_decision_maker = player
    act select_intervening_unit(frm UnitID source) {heroic_source_valid(board, player, source)}
    act choose_intervention_mode(frm ChargeKind kind) {heroic_mode_valid(board, player, source, kind)}
    let cost = heroic_intervention_cost(board[source])
    if kind == ChargeKind::into_the_fray:
        cost = cost + 1
    board.commit_stratagem_with_cost(player, Stratagem::heroic_intervention, board[source], cost)
    subaction*(board) intervention_charge = charge(board, source, kind)
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
    frm resolved : Bool[9]
    while count < 2:
        let i = 0
        while i < 9:
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
                    if rule == TimingRule::smokescreen:
                        subaction*(board) smoke = timing_smokescreen(board, player)
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

    # Supplied appendix 01.02.04 explicitly requires the same Command tests
    # for strategic reserves (core cross-reference pp.68–69). These are army
    # units, without granting battlefield visibility or distance eligibility.
    frm reserve_index : UnitIterator
    while reserve_index.value < board.reserve_units.size():
        if !board.reserve_units[reserve_index.value].empty() and board.reserve_units[reserve_index.value].owned_by_player1 == board.current_player and (board.reserve_units[reserve_index.value].battle_socked or board.reserve_units[reserve_index.value].is_at_or_below_half_strength()):
            frm reserve_recover = board.reserve_units[reserve_index.value].battle_socked
            subaction*(board, board.reserve_units[reserve_index.value]) reserve_shock_test = battle_shock_test(board, board.reserve_units[reserve_index.value], true, reserve_recover)
        reserve_index = reserve_index + 1
    # Supplied appendix 01.02.04 explicitly requires the same Command tests
    # for strategic reserves (core cross-reference pp.68–69). These are army
    # units, without granting battlefield visibility or distance eligibility.
    frm passenger_index : UnitIterator
    while passenger_index.value < board.embarked_units.size():
        if !board.embarked_units[passenger_index.value].empty() and board.embarked_units[passenger_index.value].owned_by_player1 == board.current_player and (board.embarked_units[passenger_index.value].battle_socked or board.embarked_units[passenger_index.value].is_at_or_below_half_strength()):
            frm passenger_recover = board.embarked_units[passenger_index.value].battle_socked
            subaction*(board, board.embarked_units[passenger_index.value]) passenger_shock_test = battle_shock_test(board, board.embarked_units[passenger_index.value], true, passenger_recover)
        passenger_index = passenger_index + 1


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

# Independent moves retain full Advance increments and per-model constraints
# (pp.12/32–33). Overwatch is exclusively an end-of-Movement timing action.
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
                                candidate[model].set_geometry_position(path.points.back().as_geometry_point())
                            candidate[model].geometry.rotation = path.final_rotation
                            candidate[model].history = original[model].history
                            record_path_movement(candidate[model].history, original[model], path, skies)
                            selected[model.get()] = true
                            model_done = true
                        act waypoint(BoardPosition position) {waypoint_valid(board, original, path, position, kind, extra.value, override_m.value, skies)}
                            path.append_point(geometry_point(position.x.value * MICROMETRES_PER_INCH, position.y.value * MICROMETRES_PER_INCH, original[model].geometry_position().z.value))
                        act rotate_model(MovementRotation rotation) {!rotated}
                            path.final_rotation = rotation.value * 1000
                            rotated = true
    if completed:
        # p.58: direct out-of-phase movement also interrupts pending actions.
        board[unit].interrupt_actions()
        # Any completed move, including out-of-phase moves, blocks a later
        # surge in this phase (p.70); stationary never enters this action.
        board[unit].history.last_move_phase = board.phase_serial.value + 1
        board[unit].history.made_move_this_turn = true
    board.moving_unit = previous_mover
    board.timing.active_player = previous_active
    board.current_decision_maker = previous_owner

# Bound an internal allowance while retaining the legacy three-argument
# context used by existing out-of-phase moves (pp.12/33).
fun move(Board board, UnitID unit, Int additional_movement) -> Move:
    let modifier : StatModifier
    modifier = additional_movement
    return move(board, unit, modifier)

# Phase-end fallback required by the supplied Fight on Death appendix: release
# retained models, resolve destruction effects in the common ordering, then
# archive/remove them. Turn reuses one bounded cleanup frame across all phases.
act cleanup_phase_retained(ctx Board board) -> PhaseRetainedCleanup:
    release_phase_retained_fighters(board)
    frm jobs : DamageJobs
    let source : UnitID
    subaction*(board) destruction_cleanup = resolve_damage_jobs(board, jobs, false, source)

# Pile In/consolidation are optional staged per-model moves, separate from
# attack selection (pp.38/42). No partial path changes live positions; closest
# target ties are controller choices. Physical features/continuous grid are deferred.
act melee_move(ctx Board board, frm UnitID source, frm Bool consolidate, frm Bool overrun) -> MeleeMove:
    if !melee_move_eligible(board, source, consolidate, overrun):
        return
    frm previous_owner = board.current_decision_maker
    frm previous_active = board.timing.active_player
    frm previous_mover = board.moving_unit
    frm original : Unit
    original = board[source]
    frm candidate : Unit
    candidate = original
    frm kind = MeleeMoveKind::pile_in
    if consolidate:
        kind = consolidation_kind(board, original)
    frm objective : BInt<0, 4>
    frm targets : Bool[MAX_UNIT_COUNT]
    frm approaches : UnitID[MAX_UNIT_MODELS]
    frm selected : Bool[MAX_UNIT_MODELS]
    frm finished = false
    frm completed = false
    frm target_done = false
    frm count : LinearlyDistributedInt<0, MAX_UNIT_COUNT_PLUS1>
    board.current_decision_maker = original.owned_by_player1
    board.timing.active_player = original.owned_by_player1
    board.moving_unit = source
    if kind == MeleeMoveKind::objective:
        actions:
            act cancel_melee_move()
                finished = true
            act choose_melee_objective(BInt<0, 4> objective_id) {melee_objective_valid(board, original, objective_id.value)}
                objective = objective_id
    else:
        if kind == MeleeMoveKind::ongoing or (kind == MeleeMoveKind::pile_in and board.is_in_melee(original)):
            for i in range(board.units.size()):
                if melee_enemy_valid(board, original, i) and original.is_engaged_with(board[i]):
                    targets[i] = true
                    count = count + 1
            target_done = true
        while !target_done:
            actions:
                act cancel_melee_move()
                    target_done = true
                    finished = true
                act select_melee_target(UnitID target) {melee_target_valid(board, original, target, kind), !targets[target.get()]}
                    targets[target.get()] = true
                    count = count + 1
                act finish_melee_targets() {count > 0}
                    target_done = true
        if count == 0:
            finished = true
    for i in range(original.models.size()):
        for u in range(board.units.size()):
            let target : UnitID
            target = u
            if nearest_melee_target_valid(board, original[i], targets, target):
                approaches[i] = target
                break
    while !finished:
        actions:
            act cancel_melee_move()
                finished = true
            act restart_melee_move()
                candidate = original
                for i in range(MAX_UNIT_MODELS):
                    selected[i] = false
            act finish_melee_move() {melee_finish_valid(board, original, candidate, source, kind, targets, approaches, objective.value)}
                board[source] = candidate
                completed = true
                finished = true
            act select_melee_model(frm ModelID model) {model.get() < original.models.size(), !selected[model.get()], !melee_model_locked(board, original[model], original, kind)}
                if !(kind == MeleeMoveKind::objective):
                    act choose_melee_approach(UnitID target) {nearest_melee_target_valid(board, original[model], targets, target)}
                    approaches[model.get()] = target
                frm path : ModelPath
                path.points.clear()
                path.model = model
                path.final_rotation = original[model].geometry.rotation
                frm model_done = false
                frm rotated = false
                while !model_done:
                    actions:
                        act finish_melee_model()
                            if !path.points.empty():
                                candidate[model].set_geometry_position(path.points.back().as_geometry_point())
                            candidate[model].geometry.rotation = path.final_rotation
                            candidate[model].history = original[model].history
                            record_path_movement(candidate[model].history, original[model], path, false)
                            selected[model.get()] = true
                            model_done = true
                        act melee_waypoint(BoardPosition position) {melee_waypoint_valid(board, original, path, position, kind)}
                            path.append_point(geometry_point(position.x.value * MICROMETRES_PER_INCH, position.y.value * MICROMETRES_PER_INCH, original[model].geometry_position().z.value))
                        act rotate_melee_model(MovementRotation rotation) {!rotated}
                            path.final_rotation = rotation.value * 1000
                            rotated = true
    if completed:
        board[source].history.last_move_phase = board.phase_serial.value + 1
        board[source].history.made_move_this_turn = true
        if consolidate:
            board[source].history.consolidation_phase = board.phase_serial.value + 1
        else if !overrun:
            board[source].history.pile_in_phase = board.phase_serial.value + 1
    board.moving_unit = previous_mover
    board.timing.active_player = previous_active
    board.current_decision_maker = previous_owner

# Selection consumes a fight before attacks (p.40) and scopes roles (p.8).
# Overrun permits an additional Pile In; retained destroyed models attack with
# their unit through shared declarations/groups, never immediate retaliation.
# Epic Challenge must be offered just after selection, before attacks (p.56).
act selected_fight(ctx Board board, frm UnitID source) -> SelectedFight:
    if !fight_unit_eligible(board, source):
        return
    frm previous_owner = board.current_decision_maker
    frm previous_active = board.timing.active_player
    board.timing.active_player = board[source].owned_by_player1
    board[source].has_fought = true
    board[source].history.fight_eligible_phase = board.phase_serial.value + 1
    board[source].history.consolidation_fight_pending = 0
    board.current_decision_maker = board[source].owned_by_player1
    if epic_source_valid(board, source):
        actions:
            act decline_epic_challenge()
            act epic_challenge()
                board.commit_stratagem(board[source].owned_by_player1, Stratagem::epic_challenge, board[source])
                frm previous_mover = board.moving_unit
                board.moving_unit = source
                act choose_epic_character(ModelID model) {epic_model_valid(board, source, model)}
                board[source][model].history.epic_challenge = true
                board.moving_unit = previous_mover
    act choose_fight_kind(FightKind kind) {fight_kind_valid(board, source, kind)}
    if kind == FightKind::overrun:
        subaction*(board) overrun_move = melee_move(board, source, false, true)
    let unused_target : UnitID
    board.attack = attack(board, source, unused_target, true, false)
    subaction*(board) board.attack
    board.timing.active_player = previous_active
    board.current_decision_maker = previous_owner

# Current player starts; alternate after every fight. The chooser who first
# encounters no remaining Fights First units starts remaining combats. Newly
# eligible Fights First units restore priority after each remaining fight (p.40).
# Counteroffensive follows enemy attacks here, not consolidation responses (p.57).
act fight_step(ctx Board board, frm Bool start_first) -> FightStep:
    frm previous_owner = board.current_decision_maker
    frm chooser = board.current_player
    frm first = start_first
    frm counter_pending = false
    frm counter_source : UnitID
    begin_fight_step(board)
    while player_can_fight(board, false, false) or player_can_fight(board, true, false):
        refresh_fight_eligibility(board)
        if !player_can_fight(board, false, true) and !player_can_fight(board, true, true):
            first = false
        else:
            first = true
        board.current_decision_maker = chooser
        actions:
            act pass_fight() {!player_can_fight(board, chooser, first)}
                chooser = !chooser
            act select_fighting_unit(frm UnitID source) {source.get() < board.units.size(), board[source].owned_by_player1 == chooser, fight_unit_eligible(board, source), (!first or fight_first_unit(board[source])), !counter_pending or source.get() == counter_source.get()}
                counter_pending = false
                subaction*(board) fighting = selected_fight(board, source)
                chooser = !chooser
                if board[source].owned_by_player1 == board.current_player and counteroffensive_available(board, chooser):
                    board.current_decision_maker = chooser
                    actions:
                        act decline_counteroffensive()
                        act counteroffensive(UnitID counter_unit) {counteroffensive_target_valid(board, chooser, counter_unit)}
                            board.commit_stratagem(chooser, Stratagem::counteroffensive, board[counter_unit])
                            board[counter_unit].phase_modifiers.counteroffensive = true
                            counter_source = counter_unit
                            counter_pending = true
    board.current_decision_maker = previous_owner

# Phase-wide moves resolve all active-player choices before opponent choices
# (pp.38/42). Engaging consolidation queues every newly engaged, unfought enemy
# for the opponent's mandatory response, even if it becomes unengaged later.
act melee_move_step(ctx Board board, frm Bool consolidate) -> MeleeMoveStep:
    frm mover = board.current_player
    frm side : BInt<0, 3>
    frm previous_owner = board.current_decision_maker
    while side < 2:
        board.current_decision_maker = mover
        frm done = false
        while !done:
            actions:
                act finish_melee_step()
                    done = true
                act select_melee_unit(frm UnitID source) {source.get() < board.units.size(), board[source].owned_by_player1 == mover, melee_move_eligible(board, source, consolidate, false)}
                    subaction*(board) moving = melee_move(board, source, consolidate, false)
                    if consolidate and moving.completed and moving.kind == MeleeMoveKind::engaging:
                        for i in range(board.units.size()):
                            if board[i].owned_by_player1 != mover and !board[i].has_fought and board[source].is_engaged_with(board[i]):
                                board[i].history.consolidation_fight_pending = board.phase_serial.value + 1
                                board[i].history.fight_eligible_phase = board.phase_serial.value + 1
                        while has_consolidation_response(board, !mover):
                            board.current_decision_maker = !mover
                            act select_consolidation_fighter(frm UnitID response) {response.get() < board.units.size(), board[response].owned_by_player1 != mover, consolidation_response_valid(board, response)}
                            subaction*(board) answering = selected_fight(board, response)
                    board.current_decision_maker = mover
        side = side + 1
        mover = !mover
    board.current_decision_maker = previous_owner

# Keep the legacy Bestial Bellow grant explicit until faction data arrives.
# Core fight bodies are phase-wide Pile In, dynamic mandatory fights and
# phase-wide consolidation (pp.38–43); turn owns start/end windows.
act fight_phase(ctx Board board) -> FightPhase:
    if board.players_faction[int(board.current_player)] == Faction::morgrim_butchas:
        actions:
            act use_bestial_bellow(frm UnitID unit, frm UnitID target) {target.get() < board.units.size(), has_live_attack_recipient(board[target]), unit.get() < board.units.size(), !board[unit].empty(), board[unit].has_keyword(Keyword::beastboss) or board[unit].has_keyword(Keyword::squighog_boyz), board.can_target_strat(board.current_player, Stratagem::bestial_bellow, board[unit]), board[target].distance(board[unit]) < 3.0}
                board.commit_stratagem(board.current_player, Stratagem::bestial_bellow, board[unit])
                subaction*(board, board[target]) shock_test = battle_shock_test(board, board[target], false, false)
            act skip()
    subaction*(board) pile_in = melee_move_step(board, false)
    subaction*(board) fights = fight_step(board, true)
    subaction*(board) consolidation = melee_move_step(board, true)

# Declare once, roll/reroll before choosing targets, and commit only a legal
# completed move (pp.36–37). All pending numbers/paths remain bounded. Restore
# caller roles and model-selector context on completion or cancellation (p.8).
# Successful own Charge-phase moves offer immediate Crushing Impact (p.56).
act charge(ctx Board board, frm UnitID source, frm ChargeKind kind) -> Charge:
    if source.get() >= board.units.size():
        return
    if !charge_source_valid(board, source, board[source].owned_by_player1):
        return
    frm previous_owner = board.current_decision_maker
    frm previous_active = board.timing.active_player
    frm previous_mover = board.moving_unit
    frm original : Unit
    original = board[source]
    frm candidate : Unit
    candidate = original
    frm targets : Bool[MAX_UNIT_COUNT]
    frm target_count : LinearlyDistributedInt<0, MAX_UNIT_COUNT_PLUS1>
    frm selected_models : Bool[MAX_UNIT_MODELS]
    frm maximum : ChargeDistance
    frm skies = false
    frm cancelled = false
    frm completed = false
    board[source].history.declared_charge_phase = board.phase_serial.value + 1
    board.current_decision_maker = board[source].owned_by_player1
    board.timing.active_player = board[source].owned_by_player1
    board.moving_unit = source
    board.current_pair_roll = rerollable_pair_dices_roll(board, board[source].can_reroll_charge(), false, true, board[source].owned_by_player1, source)
    subaction*(board) board.current_pair_roll
    if original.has_keyword(Keyword::fly):
        act charge_take_to_skies(Bool do_it)
        skies = do_it
    maximum = charge_distance(original, board.current_pair_roll.result.value + board.current_pair_roll.result2.value, kind, skies)
    frm target_selection_done = false
    while !target_selection_done:
        actions:
            act cancel_charge()
                cancelled = true
                target_selection_done = true
            act select_charge_target(UnitID target) {charge_target_valid(board, source, target, maximum.value, kind), !targets[target.get()]}
                targets[target.get()] = true
                target_count = target_count + 1
            act finish_charge_targets() {target_count > 0}
                target_selection_done = true
    frm movement_done = cancelled
    while !movement_done:
        actions:
            act cancel_charge()
                movement_done = true
            act restart_charge_move()
                candidate = original
                for i in range(MAX_UNIT_MODELS):
                    selected_models[i] = false
            act finish_charge_move() {charge_finish_valid(board, original, candidate, source, targets, maximum.value, skies)}
                board[source] = candidate
                completed = true
                movement_done = true
            act charge_move_to(BoardPosition position) {charge_translate_valid(board, original, source, position, targets, maximum.value, skies)}
                candidate = original
                charge_translate_candidate(board, original, candidate, source, position, targets, maximum.value, skies)
                board[source] = candidate
                completed = true
                movement_done = true
            act select_charging_model(frm ModelID model) {model.get() < original.models.size(), original[model].is_alive(), !selected_models[model.get()]}
                frm path : ModelPath
                path.points.clear()
                path.model = model
                path.final_rotation = original[model].geometry.rotation
                frm model_done = false
                frm rotated = false
                while !model_done:
                    actions:
                        act finish_charge_model()
                            if !path.points.empty():
                                candidate[model].set_geometry_position(path.points.back().as_geometry_point())
                            candidate[model].geometry.rotation = path.final_rotation
                            candidate[model].history = original[model].history
                            record_path_movement(candidate[model].history, original[model], path, skies)
                            selected_models[model.get()] = true
                            model_done = true
                        act charge_waypoint(BoardPosition position) {charge_waypoint_valid(board, original, path, position, maximum.value, skies)}
                            path.append_point(geometry_point(position.x.value * MICROMETRES_PER_INCH, position.y.value * MICROMETRES_PER_INCH, original[model].geometry_position().z.value))
                        act rotate_charge_model(MovementRotation rotation) {!rotated}
                            path.final_rotation = rotation.value * 1000
                            rotated = true
    # A candidate snapshot predates declaration. Preserve declaration after
    # committing it so a success cannot be declared again this phase (p.36).
    board[source].history.declared_charge_phase = board.phase_serial.value + 1
    if completed:
        record_charge_move(board, source)
        if crushing_source_valid(board, source):
            actions:
                act decline_crushing_impact()
                act crushing_impact()
                    subaction*(board) impact = resolve_crushing_impact(board, source)
    board.moving_unit = previous_mover
    board.timing.active_player = previous_active
    board.current_decision_maker = previous_owner

# Existing Pouncing Leap fixture supplies a free-use discount; its replacement
# faction source is task 17. Core Heroic Intervention's base cost is p.57.
fun heroic_intervention_cost(Unit unit) -> Int:
    if unit.has_ability(AbilityKind::pouncing_leap):
        return 0
    return Stratagem::heroic_intervention.cost()

# The active player chooses a charger, then resolves the entire attempt
# before selecting another unit. Targets are selected only after rolling
# (p.36); old target-first faction interception awaits sourced task-17 data.
act charge_phase(ctx Board board) -> ChargePhase:
    board.current_decision_maker = board.current_player
    while true:
        actions:
            act end_charge()
                break
            act select_charging_unit(frm UnitID source) {charge_source_valid(board, source, board.current_player)}
                subaction*(board) selected_charge = charge(board, source, ChargeKind::ordinary)
                board.current_decision_maker = board.current_player

# Ingress setup validates every base before transfer; failed setup remains
# selectable for another attempt or stationary choice (pp.14/69).
act reserve_deployment(ctx Board board, frm Bool current_player) -> ReserveDeployment:
    frm done_deploying = false
    board.current_decision_maker = current_player
    actions:
        act nothing_to_deploy() {movement_selection_complete(board, current_player)}
            done_deploying = true
        act select_reserve_unit(frm UnitID id) {id.get() < board.reserve_units.size(), has_live_model(board.reserve_units[id.get()]), board.reserve_units[id.get()].owned_by_player1 == current_player, board.reserve_units[id.get()].history.selected_move_phase != board.phase_serial.value + 1}
            actions:
                act skip()
                # p.74 prohibits Stationary for Aircraft. Deferring arrival is
                # a selection decision, not a new move type (pp.32/69).
                act defer_aircraft_ingress() {board.reserve_units[id.get()].has_keyword(Keyword::aircraft)}
                    board.reserve_units[id.get()].history.selected_move_phase = board.phase_serial.value + 1
                act reserve_remain_stationary() {!board.reserve_units[id.get()].has_keyword(Keyword::aircraft)}
                    board.reserve_units[id.get()].history.selected_move_phase = board.phase_serial.value + 1
                    board.reserve_units[id.get()].history.move_kind = MovementKind::stationary
                act place_at(BoardPosition position) {board.current_round >= 1, battlefield_entry_available(board, board.reserve_units[id.get()]), setup_at_valid(board, board.reserve_units[id.get()], position, MovementKind::ingress, false)}
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
    if !(board[id].history.selected_move_phase == board.phase_serial.value + 1) and has_live_model(board[id]):
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
    subaction*(board) embark_after_move = post_move_embark(board, id)
    if !has_live_model(board[id]):
        board[id].history.selected_move_phase = board.phase_serial.value + 1
    board[id].movement_override = previous_override
    board[id].move_takes_to_skies = false
    board[id].pending_move_kind = MovementKind::normal

# Optional embarkation is offered immediately after the permitted completed
# move, with a carrier-unit choice followed by its actual model (18.02 p.64).
act post_move_embark(ctx Board board, frm UnitID passenger_source) -> PostMoveEmbark:
    if !has_embark_choice(board, passenger_source):
        return
    frm previous_mover = board.moving_unit
    frm previous_embark_owner = board.current_decision_maker
    board.current_decision_maker = board[passenger_source].owned_by_player1
    actions:
        act decline_embark()
        act choose_embark_transport(frm UnitID embark_carrier) {embark_carrier.get() < board.units.size(), board[embark_carrier].owned_by_player1 == board[passenger_source].owned_by_player1}
            board.moving_unit = embark_carrier
            actions:
                act cancel_embark()
                act choose_embark_model(frm ModelID embark_model) {embark_after_move_valid(board, passenger_source, embark_carrier, embark_model)}
                    embark_battlefield_unit(board, passenger_source, embark_carrier, embark_model)
    board.moving_unit = previous_mover
    board.current_decision_maker = previous_embark_owner

# Stage a compulsory mode's hazard damage before battlefield placement;
# bank histories/usage persist and legal individual/preset setups share the
# exact same geometry kernel (18.04 p.65, appendix01.02.02).
act disembark(ctx Board board, frm UnitID passenger_bank) -> Disembark:
    assert(ordinary_disembark_valid(board, passenger_bank), "illegal disembarkation")
    frm carrier_location = find_passenger_carrier(board, board.embarked_units[passenger_bank.get()].embarked_transport)
    frm mode = required_disembark_mode(board, board.embarked_units[passenger_bank.get()], carrier_location)
    actions:
        act decline_disembark()
            return
        act confirm_disembark_mode(DisembarkMode chosen_mode) {chosen_mode == mode}
    frm passenger_slot = stage_disembarking_passenger(board, passenger_bank)
    if mode == DisembarkMode::combat:
        frm disembark_hazards : HazardousUses
        disembark_hazards = board[passenger_slot].models.size()
        subaction*(board) combat_hazards = resolve_hazards(board, passenger_slot, disembark_hazards)
    frm previous_mover = board.moving_unit
    board.moving_unit = passenger_slot
    frm candidate = board[passenger_slot]
    mark_unit_offboard(candidate, false)
    frm placed : Bool[MAX_UNIT_MODELS]
    frm complete = candidate.empty()
    while !complete:
        actions:
            act restart_disembark_setup()
                candidate = board[passenger_slot]
                mark_unit_offboard(candidate, false)
                for reset_model in range(MAX_UNIT_MODELS):
                    placed[reset_model] = false
            act use_legal_disembark_setup() {transport_has_setup(board, board[passenger_slot], carrier_location, mode, passenger_slot.get())}
                candidate = board[passenger_slot]
                mark_unit_offboard(candidate, false)
                assert(search_transport_setup(board, candidate, carrier_location, mode, passenger_slot.get(), 0), "validated setup search failed")
                complete = true
            act disembark_at(BoardPosition position) {transport_preset_valid(board, board[passenger_slot], carrier_location, mode, passenger_slot.get(), position)}
                candidate = board[passenger_slot]
                mark_unit_offboard(candidate, false)
                assert(arrange_transport_candidate(board, candidate, carrier_location, mode, passenger_slot.get(), position), "validated preset failed")
                complete = true
            act select_disembarking_model(frm ModelID disembark_model) {disembark_model.get() < candidate.models.size(), !placed[disembark_model.get()]}
                act place_disembarking_model(BoardPosition position) {disembark_model_input_valid(board, candidate, carrier_location, mode, passenger_slot.get(), disembark_model, position)}
                candidate[disembark_model].position = position
                placed[disembark_model.get()] = true
            act finish_disembark_setup() {all_models_selected(candidate, placed), transport_setup_valid(board, candidate, carrier_location, mode, passenger_slot.get())}
                complete = true
    board[passenger_slot] = candidate
    finish_disembark(board, passenger_slot, mode)
    if mode == DisembarkMode::tactical and !board[passenger_slot].empty():
        subaction*(board) tactical_move = movement(board, passenger_slot, false)
    board.moving_unit = previous_mover

# Every friendly unit must be selected exactly once, including reserves.
# No remaining arbitrary end-phase escape bypasses mandatory selection (p.32).
act movement_phase(ctx Board board) -> MovementPhase:
    board.current_decision_maker = board.current_player
    while true:
        actions:
            act select_disembarking_unit(frm UnitID disembark_passenger) {ordinary_disembark_valid(board, disembark_passenger)}
                subaction*(board) passenger_disembark = disembark(board, disembark_passenger)
            act end_move() {movement_selection_complete(board, board.current_player)}
                break
            act move_unit(frm UnitID id) {id.get() < board.units.size(), has_live_model(board[id]), !board[id].off_battlefield, !board[id].has_keyword(Keyword::aircraft), board[id].owned_by_player1 == board.current_player, board[id].history.selected_move_phase != board.phase_serial.value + 1}
                frm use_gilded_spear = false
                # Preserve this legacy supplied-roster hook without inventing
                # new faction authority; exact faction replacement is task 17.
                if board.get_current_player_faction() == Faction::tristraen_gilded_blade and board.can_target_strat(board.current_player, Stratagem::the_gilded_spear, board[id]):
                    act use_gilded_spear(Bool do_it)
                    use_gilded_spear = do_it
                    if do_it:
                        board.commit_stratagem(board.current_player, Stratagem::the_gilded_spear, board[id])
                subaction*(board) chosen_move = movement(board, id, use_gilded_spear)
            act select_reserve_unit(frm UnitID reserve_id) {reserve_id.get() < board.reserve_units.size(), has_live_model(board.reserve_units[reserve_id.get()]), board.reserve_units[reserve_id.get()].owned_by_player1 == board.current_player, board.reserve_units[reserve_id.get()].history.selected_move_phase != board.phase_serial.value + 1}
                actions:
                    act skip()
                    # pp.32/69/74: a reserve Aircraft may defer ingress,
                    # including round one, without making a Stationary move.
                    act defer_aircraft_ingress() {board.reserve_units[reserve_id.get()].has_keyword(Keyword::aircraft)}
                        board.reserve_units[reserve_id.get()].history.selected_move_phase = board.phase_serial.value + 1
                    act reserve_remain_stationary() {!board.reserve_units[reserve_id.get()].has_keyword(Keyword::aircraft)}
                        board.reserve_units[reserve_id.get()].history.selected_move_phase = board.phase_serial.value + 1
                        board.reserve_units[reserve_id.get()].history.move_kind = MovementKind::stationary
                    act place_at(BoardPosition position) {board.current_round >= 1, battlefield_entry_available(board, board.reserve_units[reserve_id.get()]), setup_at_valid(board, board.reserve_units[reserve_id.get()], position, MovementKind::ingress, false)}
                        enter_from_reserves(board, reserve_id, position, MovementKind::ingress)
    board.current_decision_maker = board.current_player

# Select the shooting type before weapons, even for a unit with no ranged
# weapons; shooting prohibits phase-local action starts (pp.34–35/57/88).
act selected_shooting(ctx Board board, frm UnitID source, frm UnitID initial_target) -> SelectedShooting:
    board[source].has_shoot = true
    board[source].history.shot_this_phase = true
    act choose_shooting_kind(ShootingKind kind) {shooting_kind_valid(board, source, kind)}
    board[source].shooting_kind = kind
    board.attack = attack(board, source, initial_target, false, false)
    subaction*(board) board.attack

# Keep the existing two-UnitID click selector as a compatibility entrypoint;
# the new one-unit selector also supports no-weapon units (pp.34–35/88).
act shooting_phase(ctx Board board) -> ShootingPhase:
    board.current_decision_maker = board.current_player
    while true:
        actions:
            act end_shooting_phase()
                break
            act use_explosives(frm UnitID explosives_source) {explosives_source_valid(board, explosives_source)}
                subaction*(board) explosives = resolve_explosives(board, explosives_source)
            act select_shooting_unit(frm UnitID shooting_unit) {shooting_unit_valid(board, shooting_unit)}
                subaction*(board) firing_unit = selected_shooting(board, shooting_unit, shooting_unit)
            act select_target(frm UnitID source, frm UnitID target) {
                shooting_unit_valid(board, source),
                target.get() < board.units.size(),
                has_live_attack_recipient(board[target]),
                board[target].owned_by_player1 != board.current_player,
                unit_visible_to_unit(board, board[source], board[target]) or shooting_kind_valid(board, source, ShootingKind::indirect)
            }
                subaction*(board) firing_target = selected_shooting(board, source, target)

# one of the most important sequences, the whole turn of a single
# player, as specified by the core rules
# Reset turn-local carriers and expire per-phase records at existing boundaries
# (turn/phase sequence pp.28–30). Explicit start/end windows remain task 5.
act turn(ctx Board board, frm Bool player_id) -> Turn:
    board.current_player = player_id
    board.timing.active_player = player_id
    board.current_decision_maker = player_id
    board.start_turn_history()
    frm retained_cleanup : PhaseRetainedCleanup
    subaction*(board) start = resolve_timing_window(board, TimingWindow::turn_start)
    board.begin_phase(BattlePhase::command)
    subaction*(board) command_start = resolve_timing_window(board, TimingWindow::command_start)
    subaction*(board) command_phase = command_phase(board)
    subaction*(board) command_end = resolve_timing_window(board, TimingWindow::command_end)
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.begin_phase(BattlePhase::movement)
    subaction*(board) movement_start = resolve_timing_window(board, TimingWindow::movement_start)
    subaction*(board) movement_phase = movement_phase(board)
    subaction*(board) movement_end = resolve_timing_window(board, TimingWindow::movement_end)
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.begin_phase(BattlePhase::shooting)
    subaction*(board) shooting_start = resolve_timing_window(board, TimingWindow::shooting_start)
    subaction*(board) shooting_phase = shooting_phase(board)
    subaction*(board) shooting_end = resolve_timing_window(board, TimingWindow::shooting_end)
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    for i in range(board.units.size()):
        board[i].history.ingress_locked = false
    board.begin_phase(BattlePhase::charge)
    subaction*(board) charge_start = resolve_timing_window(board, TimingWindow::charge_start)
    subaction*(board) charge_phase = charge_phase(board)
    subaction*(board) charge_end = resolve_timing_window(board, TimingWindow::charge_end)
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.begin_phase(BattlePhase::fight)
    subaction*(board) fight_start = resolve_timing_window(board, TimingWindow::fight_start)
    subaction*(board) fight_phase = fight_phase(board)
    subaction*(board) fight_end = resolve_timing_window(board, TimingWindow::fight_end)
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.clear_phase_modifiers()
    board.timing.phase = BattlePhase::none
    subaction*(board) end = resolve_timing_window(board, TimingWindow::turn_end)
    return_opponent_aircraft(board)
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

# Friendly whole units may start inside an explicitly permitted transport
# model in Declare Battle Formations (18.01 p.64), before reserve selection.
act declare_transport_passengers(ctx Board board) -> DeclareTransportPassengers:
    frm formation_player = board.starting_player
    frm formation_count : BInt<0, 3>
    while formation_count.value < 2:
        board.current_decision_maker = formation_player
        frm formation_finished = !has_formation_transport(board, formation_player)
        while !formation_finished:
            actions:
                act finish_transport_formations()
                    formation_finished = true
                act choose_formation_passenger(frm UnitID formation_passenger) {formation_passenger.get() < board.reserve_units.size(), board.reserve_units[formation_passenger.get()].owned_by_player1 == formation_player}
                    actions:
                        act cancel_formation_embark()
                        act choose_formation_transport(frm UnitID formation_carrier) {formation_carrier.get() < board.reserve_units.size(), board.reserve_units[formation_carrier.get()].owned_by_player1 == formation_player, formation_carrier.get() != formation_passenger.get()}
                            board.moving_unit = formation_carrier
                            actions:
                                act cancel_formation_carrier()
                                act choose_formation_carrier_model(frm ModelID formation_model) {transport_can_carry(board, board.reserve_units[formation_passenger.get()], board.reserve_units[formation_carrier.get()], formation_model.get())}
                                    embark_formation_unit(board, formation_passenger, formation_carrier, formation_model)
        formation_count = formation_count + 1
        formation_player = !formation_player

# Pre-battle reserve choices require explicit points; AIRCRAFT/transport
# formation exceptions await task 16, not invented roster costs (p.68).
act declare_strategic_reserves(ctx Board board) -> DeclareStrategicReserves:
    reserve_aircraft_for_formations(board)
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
                    # User-directed setup policy: archive units with no legal
                    # supported placement; do not grant free reserve permission.
                    act destroy_unplaceable_unit() {!deployment_has_position(board, board.reserve_units[unit_id.get()])}
                        destroy_unplaceable_reserve(board, unit_id)
                        if !passed_players[int(!board.current_decision_maker)]:
                            board.current_decision_maker = !board.current_decision_maker
                    act deploy_at(BoardPosition position) {setup_at_valid(board, board.reserve_units[unit_id.get()], position, MovementKind::normal, infiltrates)}
                        enter_from_reserves(board, unit_id, position, MovementKind::normal)
                        if !passed_players[int(!board.current_decision_maker)]:
                            board.current_decision_maker = !board.current_decision_maker

# A granting rule must explicitly trigger this move and provide its distance;
# no illustrative faction trigger is manufactured (pp.70/74). Closest target,
# per-model obligations and once-per-phase movement are enforced by helpers.
act surge(ctx Board board, frm UnitID source, frm StatModifier distance, frm Bool triggered) -> Surge:
    if !triggered or source.get() >= board.units.size() or !has_live_model(board[source]) or board[source].battle_socked or board.is_in_melee(board[source]) or board[source].history.last_move_phase == board.phase_serial.value + 1 or board[source].history.ingress_locked or !has_surge_target(board, source):
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
                act select_scout_unit(frm UnitID scout) {scout.get() < board.units.size(), board[scout].owned_by_player1 == player, !board[scout].history.scouts_resolved, transport_scouts_distance(board, board[scout]) > 0, unit_in_home_zone(board[scout], player)}
                    board[scout].pending_move_kind = MovementKind::scout
                    frm distance : StatModifier
                    distance = transport_scouts_distance(board, board[scout])
                    subaction*(board, scout) scout_move = move(board, scout, distance)
                    if scout_move.completed:
                        board[scout].history.scouts_resolved = true
                        record_move(board, scout, MovementKind::scout)
                    board[scout].pending_move_kind = MovementKind::normal
                act select_scout_reserve(frm UnitID reserve) {reserve.get() < board.reserve_units.size(), board.reserve_units[reserve.get()].owned_by_player1 == player, board.reserve_units[reserve.get()].history.strategic_reserve, !board.reserve_units[reserve.get()].history.scouts_resolved, transport_scouts_distance(board, board.reserve_units[reserve.get()]) > 0, board.units.has_capacity()}
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
    subaction*(board) transport_formations = declare_transport_passengers(board)
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
