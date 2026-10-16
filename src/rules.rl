import factions.dispatch
import attack_reactions
import action
import ability_procedures
import healing_rules
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
import firing_deck_rules
import source_effects
import modifier_choices
import attachment_rules

# User-supplied sequencing: turn owner's source instances in their chosen
# order, then the opponent's. Declining optional sources spends no usage.
# Actual faction grants remain source data; this dispatcher installs typed grants.
act resolve_source_event(ctx Board board, frm SourceEvent trigger, frm Bool unit_destroyed) -> SourceEventResolution:
    frm previous_owner = board.current_decision_maker
    frm previous_candidates = board.active_source_events
    frm pending = collect_destruction_sources(board, trigger, unit_destroyed)
    frm player = board.current_player
    frm controllers : BInt<0, 3>
    while controllers.value < 2:
        board.current_decision_maker = player
        while source_events_remaining(board, pending, player, false):
            board.active_source_events = pending
            actions:
                act finish_source_events() {!source_events_remaining(board, pending, player, true)}
                    break
                act choose_source_event(frm SourceEventID event) {pending_source_valid(board, pending, event, player)}
                    commit_pending_source(board, pending, event, player)
        player = !player
        controllers = controllers + 1
    board.active_source_events = previous_candidates
    board.current_decision_maker = previous_owner

# Existing gameplay boundaries have no accompanying unit-destruction event;
# retain their context interface while death dispatch merges both (pp.66/87).
fun resolve_source_event(Board board, SourceEvent trigger) -> SourceEventResolution:
    return resolve_source_event(board, trigger, false)

# Wound thresholds use the printed equality boundaries (p.18). The user-
# supplied appendix 02.02.01 caps cumulative roll modifiers at +/-1; a bonus
# reduces the required unmodified result, while protection worsens the roll.
fun required_wound_roll(Board board, AttackSequenceInfo info) -> Int:
    let modifier = info.total_wound_modifier()
    # Lance consumes only a completed charge move this turn (pp.37/82).
    if info.target_toughness.value < info.attack_strength() and info.greater_strenght_wound_protection:
        modifier = modifier - 1
    if info.has_weapon_rule(board, WeaponRuleKind::lance) and board[info.source_unit_id].has_charged:
        modifier = modifier + 1
    return base_wound_threshold(info.attack_strength(), info.target_toughness.value) - min(1, max(-1, modifier))


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

    assert(valid_stat(stat), "invalid random characteristic")
    frm maximum : Dice
    maximum = stat_dice_sides(stat)
    frm count : LinearlyDistributedInt<1, 4>
    count = stat_dice_count(stat)
    frm index : LinearlyDistributedInt<0, 4>
    while index.value < count.value:
        act quantity(Dice dice) {dice.value <= maximum.value}
        result = result + dice.value
        index = index + 1
    let total = result.value + stat_intrinsic_constant(stat) + fixed_extra.value
    assert(total >= 0 and total < MAX_RANDOM_STAT_RESULT, "random characteristic result capacity exceeded")
    result = total

fun evaluate_random_stat(Stat stat) -> RollStat:
    let zero : StatModifier 
    return evaluate_random_stat(stat, zero)

fun evaluate_random_stat(Stat stat, Int modifier) -> RollStat:
    let mod: StatModifier 
    mod= modifier
    return evaluate_random_stat(stat, mod) 

# Random A is generated separately per weapon at gathering; random D per
# damaging attack after allocation (supplied appendix 02.02.03). Apply
# characteristic arithmetic only after any replacement dice (01.05.02). Command
# Re-roll targets the controlling unit and spends before replacement (p.56).
act evaluate_weapon_characteristic(ctx Board board, frm Stat stat, frm StatModifier extra, frm Bool player, frm UnitID target, frm RuleModifiers modifiers, frm ModifiedCharacteristic characteristic_kind) -> WeaponStatRoll:
    let zero : StatModifier
    board.shared_actions.evaluate_random_stat = evaluate_random_stat(stat, zero)
    subaction* board.shared_actions.evaluate_random_stat
    frm initial_result_snapshot_1 = board.shared_actions.evaluate_random_stat.result
    frm result = initial_result_snapshot_1
    if stat_dice_count(stat) > 0:
        frm maximum : Dice
        maximum = stat_dice_sides(stat)
        if can_command_reroll(board, player, target, true):
            frm previous_owner = board.current_decision_maker
            board.current_decision_maker = player
            act keep_it(Bool keep)
            if !keep:
                board.commit_stratagem(player, Stratagem::reroll, board[target])
                # A summed roll re-rolls every original die, once (01.05.02).
                result = stat_intrinsic_constant(stat)
                frm reroll_index : LinearlyDistributedInt<0, 4>
                while reroll_index.value < stat_dice_count(stat):
                    act reroll(Dice replacement) {replacement.value <= maximum.value}
                    result = result + replacement.value
                    reroll_index = reroll_index + 1
            board.current_decision_maker = previous_owner
    let effective = modified_characteristic(result.value, characteristic_kind, modifiers, false, extra.value)
    assert(effective >= 0 and effective < MAX_RANDOM_STAT_RESULT, "weapon characteristic result capacity exceeded")
    result = effective

# Legacy callers use unmodified arithmetic; actual A/D consumers supply their
# scoped operation list (appendix02.02.01/02.02.03).
fun evaluate_weapon_characteristic(Board board, Stat stat, StatModifier extra, Bool player, UnitID target) -> WeaponStatRoll:
    let modifiers : RuleModifiers
    return evaluate_weapon_characteristic(board, stat, extra, player, target, modifiers, ModifiedCharacteristic::damage)

# Convert a supported characteristic increment to standard bounded storage,
# rejecting unsupported values rather than silently clamping (pp.17/19).
fun evaluate_weapon_characteristic(Board board, Stat stat, Int extra, Bool player, UnitID target) -> WeaponStatRoll:
    assert(extra >= 0 and extra < MAX_STAT_MODIFIER, "characteristic increment capacity exceeded")
    let bounded : StatModifier
    bounded = extra
    return evaluate_weapon_characteristic(board, stat, bounded, player, target)

# Core A/D increments enter the addition step after the original dice and any
# re-roll, before division/subtraction (appendix02.02.01/01.05.02).
fun evaluate_weapon_characteristic(Board board, Stat stat, Int extra, Bool player, UnitID target, RuleModifiers modifiers, ModifiedCharacteristic kind) -> WeaponStatRoll:
    assert(extra >= 0 and extra < MAX_STAT_MODIFIER, "characteristic increment capacity exceeded")
    let bounded : StatModifier
    bounded = extra
    return evaluate_weapon_characteristic(board, stat, bounded, player, target, modifiers, kind)

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

# Damaged24.39 joins other hit increments before the cumulative cap (02.02.01).
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
        record_attack_hits(board, board.attack_info.target_unit_id, count.value)
    else:
        board.current_state = CurrentStateDescription::hit_roll
        frm hit_rerolls = !board.attack_info.only_hits_on_6 and !(board.attack_info.shooting_kind == ShootingKind::indirect and board.attack_info.has_weapon_rule(board, WeaponRuleKind::indirect_fire))
        board.shared_actions.collect_attack_dice = collect_attack_dice(board, count, board.attack_info.reroll_hits and hit_rerolls, board.attack_info.reroll1_hits and hit_rerolls, hit_rerolls, source_unit.owned_by_player1, board.attack_info.source_unit_id)
        subaction*(board) board.shared_actions.collect_attack_dice
        frm hits_pool_snapshot_1 = board.shared_actions.collect_attack_dice.pool
        # Lethal Hits is optional per critical hit; mixed choices within a
        # batch must remain possible without an exponential action domain (p.82).
        frm lethal_wounds : CombatCounter
        frm lethal_remaining : CombatCounter
        frm shield_lethal_deferred = faction_hit_interceptor(board, target) >= 0
        if board.attack_info.has_weapon_rule(board, WeaponRuleKind::letal_hits) and !shield_lethal_deferred:
            lethal_remaining = hits_pool_snapshot_1.faces[5]
        while lethal_remaining > 0:
            board.current_decision_maker = source_unit.owned_by_player1
            act use_lethal_hits(Bool automatically_wound)
            if automatically_wound:
                lethal_wounds = lethal_wounds + 1
            lethal_remaining = lethal_remaining - 1
        frm hit_face : Dice
        frm hit_index : LinearlyDistributedInt<0, 7>
        while hit_index.value < 6:
            hit_face = hit_index.value + 1
            hit_index = hit_index + 1
            # Each ordinary die can choose its own subset after re-rolls,
            # before modifiers are applied (02.02.01/02.02.02). Preserve the
            # aggregate fast path when no supported permission is present.
            if hit_face.value > 1 and hit_face.value < 6 and !board.attack_info.only_hits_on_6 and (board.attack_info.may_ignore_skill_modifiers or board.attack_info.may_ignore_hit_modifiers):
                frm skill_options = attack_skill_choices(board, board.attack_info)
                frm hit_options = attack_hit_choices(board, board.attack_info)
                frm ordinary_remaining : CombatCounter
                ordinary_remaining = hits_pool_snapshot_1.faces[hit_face.value - 1]
                frm selection_kind = ModifierSelectionKind::weapon_skill
                if board.attack_info.source.range() > 0:
                    selection_kind = ModifierSelectionKind::ballistic_skill
                while ordinary_remaining > 0:
                    board.shared_actions.choose_attack_modifiers = choose_attack_modifiers(board, skill_options, source_unit.owned_by_player1, selection_kind, board.attack_info.may_ignore_skill_modifiers)
                    subaction*(board) board.shared_actions.choose_attack_modifiers
                    frm skills_result_snapshot_2 = board.shared_actions.choose_attack_modifiers.result
                    board.shared_actions.choose_attack_modifiers = choose_attack_modifiers(board, hit_options, source_unit.owned_by_player1, ModifierSelectionKind::hit_roll, board.attack_info.may_ignore_hit_modifiers)
                    subaction*(board) board.shared_actions.choose_attack_modifiers
                    frm increments_result_snapshot_3 = board.shared_actions.choose_attack_modifiers.result
                    let selected_outcome = classify_attack_hit(board, board.attack_info, hit_face, selected_hit_bonus(hit_face.value, increments_result_snapshot_3), selected_attack_skill(board.attack_info, skills_result_snapshot_2))
                    if selected_outcome == AttackRollResult::success:
                        frm ordinary_count : CombatCounter
                        ordinary_count = 1
                        board.shared_actions.intercept_faction_hits = intercept_faction_hits(board, board.attack_info.target_unit_id, ordinary_count)
                        subaction*(board) board.shared_actions.intercept_faction_hits
                        frm ordinary_shield_intercepted_snapshot_4 = board.shared_actions.intercept_faction_hits.intercepted
                        add_attack_count(generated_hits, 1 - ordinary_shield_intercepted_snapshot_4.value)
                        record_attack_hits(board, board.attack_info.target_unit_id, 1 - ordinary_shield_intercepted_snapshot_4.value)
                    ordinary_remaining = ordinary_remaining - 1
                continue
            frm outcome : AttackRollResult
            outcome = classify_attack_hit(board, board.attack_info, hit_face, get_hit_roll_bonus(board))
            if outcome == AttackRollResult::critical and shield_lethal_deferred:
                # Resolve each original critical in controller order: optional
                # Lethal first, then its Grot Shield cancellation. This avoids
                # choosing a retroactive subset after seeing shield survival.
                frm critical_remaining : CombatCounter
                critical_remaining = hits_pool_snapshot_1.faces[5]
                while critical_remaining > 0:
                    frm automatic = false
                    if board.attack_info.has_weapon_rule(board, WeaponRuleKind::letal_hits):
                        board.current_decision_maker = source_unit.owned_by_player1
                        act use_lethal_hits(Bool automatically_wound)
                        automatic = automatically_wound
                    frm one_critical : CombatCounter
                    one_critical = 1
                    board.shared_actions.intercept_faction_hits = intercept_faction_hits(board, board.attack_info.target_unit_id, one_critical)
                    subaction*(board) board.shared_actions.intercept_faction_hits
                    frm critical_shield_intercepted_snapshot_5 = board.shared_actions.intercept_faction_hits.intercepted
                    let additional_hits = board.attack_info.max_weapon_parameter(board, WeaponRuleKind::sustained_hit)
                    add_attack_count(generated_hits, additional_hits)
                    record_attack_hits(board, board.attack_info.target_unit_id, additional_hits)
                    if critical_shield_intercepted_snapshot_5 == 0:
                        record_attack_hits(board, board.attack_info.target_unit_id, 1)
                        if automatic:
                            add_attack_count(generated_wounds, 1)
                        else:
                            add_attack_count(generated_hits, 1)
                    critical_remaining = critical_remaining - 1
                continue
            if outcome == AttackRollResult::critical or outcome == AttackRollResult::success:
                frm rolled_count : CombatCounter
                rolled_count = hits_pool_snapshot_1.faces[hit_face.value - 1]
                board.shared_actions.intercept_faction_hits = intercept_faction_hits(board, board.attack_info.target_unit_id, rolled_count)
                subaction*(board) board.shared_actions.intercept_faction_hits
                frm shielding_intercepted_snapshot_6 = board.shared_actions.intercept_faction_hits.intercepted
                frm remaining_hits : CombatCounter
                remaining_hits = rolled_count.value - shielding_intercepted_snapshot_6.value
                record_attack_hits(board, board.attack_info.target_unit_id, remaining_hits.value)
                if outcome == AttackRollResult::critical:
                    add_attack_count(generated_hits, rolled_count.value * board.attack_info.max_weapon_parameter(board, WeaponRuleKind::sustained_hit))
                    record_attack_hits(board, board.attack_info.target_unit_id, rolled_count.value * board.attack_info.max_weapon_parameter(board, WeaponRuleKind::sustained_hit))
                    add_attack_count(generated_wounds, lethal_wounds.value)
                    add_attack_count(generated_hits, remaining_hits.value - lethal_wounds.value)
                else:
                    add_attack_count(generated_hits, remaining_hits.value)
    if generated_hits > 0:
        board.current_state = CurrentStateDescription::wound_roll
        board.shared_actions.collect_attack_dice = collect_attack_dice(board, generated_hits, board.attack_info.reroll_wounds or board.attack_info.has_weapon_rule(board, WeaponRuleKind::twin_linked), board.attack_info.reroll1_wounds, true, source_unit.owned_by_player1, board.attack_info.source_unit_id)
        subaction*(board) board.shared_actions.collect_attack_dice
        frm wounds_pool_snapshot_7 = board.shared_actions.collect_attack_dice.pool
        frm wound_result : Dice
        frm wound_index : BInt<0, 7>
        while wound_index.value < 6:
            wound_index = wound_index + 1
            wound_result = wound_index.value
            let outcome = classify_attack_wound(board, board.attack_info, wound_result, required_wound_roll(board, board.attack_info))
            if outcome == AttackRollResult::failed:
                continue
            if outcome == AttackRollResult::critical and board.attack_info.has_weapon_rule(board, WeaponRuleKind::devastating_wounds):
                add_attack_count(generated_critical_wounds, wounds_pool_snapshot_7.faces[wound_result.value - 1].value)
            else:
                add_attack_count(generated_wounds, wounds_pool_snapshot_7.faces[wound_result.value - 1].value)
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
act prevent_wound_loss(ctx Board board, frm SourceBank bank, frm UnitID target, frm ModelID model, frm CombatCounter amount) -> WoundPrevention:
    frm lost : CombatCounter
    frm count : CombatCounter
    frm threshold : LinearlyDistributedInt<0, 11>
    threshold = source_bank_unit(board, bank, target.get())[model].profile.feel_no_pain()
    if threshold > 6:
        lost = amount
        return
    board.current_decision_maker = source_bank_unit(board, bank, target.get()).owned_by_player1
    board.current_state = CurrentStateDescription::feel_no_pain_roll
    while count < amount:
        act roll(Dice prevention)
        if prevention.value < threshold.value:
            lost = lost + 1
        count = count + 1

# Battlefield compatibility shares the same prevention frame (p81).
fun prevent_wound_loss(Board board, UnitID target, ModelID model, CombatCounter amount) -> WoundPrevention:
    return prevent_wound_loss(board, SourceBank::battlefield, target, model, amount)

# Finite jobs and a nonrecursive destruction scan let immediate death effects
# interrupt mortal allocation, while attack-triggered deaths wait (pp.24/80/87).
# Job snapshots, not references into the work vector, survive child actions.
act resolve_damage_jobs(ctx Board board, frm DamageJobs jobs, frm Bool finish_attacks, frm UnitID finished_source) -> DamageResolution:
    frm previous_owner = board.current_decision_maker
    frm previous_target = board.attack_info.target_unit_id
    frm previous_bank = board.damage_bank
    # P67 conferral ends once this attacking unit's full sequence is finished,
    # before its delayed destruction effects and removals are resolved.
    if finish_attacks:
        release_attachment_rules(board, finished_source)
    frm current_job : DamageJob
    frm event : PendingDestruction
    frm casualty : Model
    frm absent_source : Unit
    frm retaliation : CombatCounter
    while true:
        event = next_destruction(board, finish_attacks, finished_source)
        if event.found:
            board.current_decision_maker = source_bank_unit(board, event.bank, event.unit.get()).owned_by_player1
            if destruction_bank_count(board, board.current_decision_maker, finish_attacks, finished_source) > 1:
                act choose_destruction_bank(frm SourceBank death_bank) {destruction_bank_valid(board, death_bank, board.current_decision_maker, finish_attacks, finished_source)}
                event.bank = death_bank
            board.damage_bank = event.bank
            act choose_destruction_unit(frm UnitID dying_unit) {destruction_unit_valid(board, event.bank, dying_unit, board.current_decision_maker, finish_attacks, finished_source)}
            event.unit = dying_unit
            board.attack_info.target_unit_id = dying_unit
            act resolve_destruction_model(frm ModelID dying_model) {dying_model.get() < source_bank_unit(board, event.bank, dying_unit.get()).models.size(), destruction_ready(source_bank_unit(board, event.bank, dying_unit.get())[dying_model], finish_attacks, finished_source)}
            event.model = dying_model
            casualty = source_bank_unit(board, event.bank, event.unit.get())[event.model]
            frm destroying_identity : EntityIdentity
            destroying_identity = 0
            if casualty.destroying_unit_known:
                destroying_identity = casualty.destroying_unit_identity
            subaction*(board, casualty) faction_death = faction_before_destruction(board, casualty, event)
            frm suppress_demise = faction_death.suppress_demise
            frm faction_death_recipient = faction_death.headbutt_recipient
            frm faction_death_mortals = faction_death.crash_mortals
            board.shared_actions.resolve_source_event = resolve_source_event(board, source_event(SourceEventKind::model_destroyed, source_bank_unit(board, event.bank, event.unit.get()).identity, destroying_identity, casualty.identity), casualty.destroyed_whole_unit)
            subaction*(board) board.shared_actions.resolve_source_event
            source_bank_unit(board, event.bank, event.unit.get())[event.model].destruction_pending = false
            source_bank_unit(board, event.bank, event.unit.get())[event.model].destroyed_whole_unit = false
            absent_source.owned_by_player1 = !source_bank_unit(board, event.bank, event.unit.get()).owned_by_player1
            retaliation = 0
            if event.bank.value == SourceBank::battlefield.value and casualty.destroying_unit_known:
                board.shared_actions.on_model_destroyed = on_model_destroyed(board, board[casualty.destroying_unit], casualty)
                subaction*(board, board[casualty.destroying_unit], casualty) board.shared_actions.on_model_destroyed
                frm triggered_generated_mortal_snapshot_2 = board.shared_actions.on_model_destroyed.generated_mortal
                retaliation = triggered_generated_mortal_snapshot_2
            else:
                if event.bank.value == SourceBank::battlefield.value:
                    board.shared_actions.on_model_destroyed = on_model_destroyed(board, absent_source, casualty)
                    subaction*(board, absent_source, casualty) board.shared_actions.on_model_destroyed
            # Retain physical presence through the triggered effects; removal
            # is queued beneath their mortal jobs (Deadly Demise p.80).
            if casualty.state == ModelState::pending_destruction:
                let removal = damage_job(DamageKind::remove_destroyed, event.unit, casualty.destroying_unit, casualty.destroying_unit_known, false, 0, casualty.identity)
                removal.bank = event.bank
                jobs.append(removal)
            # Headbutt says before removal. This LIFO work stack must put the
            # chosen mortals ABOVE removal, just like other death retaliation.
            if faction_death_mortals > 0:
                jobs.append(damage_job(DamageKind::mortal, faction_death_recipient, event.unit, true, false, faction_death_mortals.value, invalid_entity_identity()))
            if casualty.destroying_unit_known and retaliation > 0:
                jobs.append(damage_job(DamageKind::mortal, casualty.destroying_unit, event.unit, true, false, retaliation.value, invalid_entity_identity()))
            # p.65 requires passenger hazards/setup before carrier Deadly
            # Demise. Deferred jobs keep that ordering without recursive frames.
            if event.bank.value == SourceBank::battlefield.value and casualty.has_deadly_demise and !suppress_demise:
                jobs.append(damage_job(DamageKind::deferred_demise, event.unit, event.unit, true, false, 0, casualty.identity))
            if event.bank.value == SourceBank::battlefield.value and carrier_has_passengers(board, casualty.identity):
                jobs.append(damage_job(DamageKind::emergency_next, event.unit, event.unit, true, false, 0, casualty.identity))
            continue
        if jobs.empty():
            break
        current_job = jobs.back()
        jobs.pop()
        if current_job.kind == DamageKind::emergency_next:
            if !carrier_has_passengers(board, current_job.recipient):
                continue
            board.current_decision_maker = board.current_player
            act choose_emergency_passenger(frm UnitID emergency_passenger) {emergency_passenger.get() < board.embarked_units.size(), board.embarked_units[emergency_passenger.get()].embarked_transport == current_job.recipient}
            frm emergency_slot = stage_disembarking_passenger(board, emergency_passenger)
            frm emergency_hazard_count : CombatCounter
            emergency_hazard_count = board[emergency_slot].models.size()
            frm emergency_multiplier : LinearlyDistributedInt<1, 4>
            emergency_multiplier = hazard_mortal_multiplier(board[emergency_slot])
            board.current_state = CurrentStateDescription::hazardous_roll
            board.shared_actions.collect_attack_dice = collect_attack_dice(board, emergency_hazard_count, false, false, true, board[emergency_slot].owned_by_player1, emergency_slot)
            subaction*(board) board.shared_actions.collect_attack_dice
            frm emergency_hazards_pool_snapshot_4 = board.shared_actions.collect_attack_dice.pool
            emergency_hazard_count = (emergency_hazards_pool_snapshot_4.faces[0].value + emergency_hazards_pool_snapshot_4.faces[1].value) * emergency_multiplier.value
            jobs.append(current_job)
            jobs.append(damage_job(DamageKind::emergency_setup, emergency_slot, current_job.target, true, false, 0, current_job.recipient))
            if emergency_hazard_count > 0:
                jobs.append(damage_job(DamageKind::mortal, emergency_slot, current_job.target, false, false, emergency_hazard_count.value, invalid_entity_identity()))
            continue
        if current_job.kind == DamageKind::emergency_setup:
            frm emergency_location = find_passenger_carrier(board, current_job.recipient)
            frm emergency_original = source_bank_unit(board, current_job.bank, current_job.target.get())
            frm emergency_candidate : Unit
            arrange_emergency_survivors(board, emergency_original, emergency_candidate, emergency_location, current_job.target.get())
            source_bank_unit(board, current_job.bank, current_job.target.get()) = emergency_candidate
            finish_disembark(board, current_job.target, DisembarkMode::emergency)
            # Models unable to set up are destroyed, without a damage/FNP roll
            # (p.65). Retain any own destruction hook in the same work engine.
            for unplaced_index in range(emergency_original.models.size()):
                if source_bank_unit(board, current_job.bank, current_job.target.get()).find_model(emergency_original[unplaced_index].identity) < 0:
                    let unplaced = emergency_original[unplaced_index]
                    unplaced.suffered_wounds = unplaced.profile.wounds()
                    unplaced.off_battlefield = true
                    if has_destruction_trigger(board, current_job.source, false, unplaced, false):
                        unplaced.state = ModelState::pending_destruction
                        unplaced.destruction_pending = true
                        unplaced.destroyed_by_attack = false
                        unplaced.destroying_unit_known = false
                        source_bank_unit(board, current_job.bank, current_job.target.get()).models.append(unplaced)
                    else:
                        source_bank_unit(board, current_job.bank, current_job.target.get()).destroyed_models.value.append(unplaced)
            continue
        if current_job.kind == DamageKind::deferred_demise:
            frm demise_index : ModelID
            let found_demise = source_bank_unit(board, current_job.bank, current_job.target.get()).find_model(current_job.recipient)
            if found_demise < 0:
                continue
            demise_index = found_demise
            casualty = source_bank_unit(board, current_job.bank, current_job.target.get())[demise_index]
            board.current_decision_maker = source_bank_unit(board, current_job.bank, current_job.target.get()).owned_by_player1
            board.current_state = CurrentStateDescription::destruction_roll
            act roll(Dice explosion)
            if explosion == 6:
                frm nearby : UnitIterator
                nearby = board.units.size()
                while nearby.value > 0:
                    nearby = nearby - 1
                    if has_live_damage_recipient(board[nearby.value]) and board[nearby.value].distance(casualty) <= 6.0:
                        board.shared_actions.evaluate_random_stat = evaluate_random_stat(casualty.deadly_demise)
                        subaction* board.shared_actions.evaluate_random_stat
                        frm demise_amount_result_snapshot_5 = board.shared_actions.evaluate_random_stat.result
                        let affected : UnitID
                        affected = nearby.value
                        jobs.append(damage_job(DamageKind::mortal, affected, current_job.target, true, false, demise_amount_result_snapshot_5.value, invalid_entity_identity()))
            continue
        if current_job.kind == DamageKind::remove_destroyed:
            let removed = source_bank_unit(board, current_job.bank, current_job.target.get()).find_model(current_job.recipient)
            if removed >= 0:
                source_bank_unit(board, current_job.bank, current_job.target.get()).remove_model(removed)
            continue
        if current_job.amount == 0 or !has_live_damage_recipient(source_bank_unit(board, current_job.bank, current_job.target.get())):
            continue
        board.damage_bank = current_job.bank
        board.attack_info.target_unit_id = current_job.target
        board.current_decision_maker = source_bank_unit(board, current_job.bank, current_job.target.get()).owned_by_player1
        frm recipient : ModelID
        if current_job.recipient.value > 0:
            let existing = source_bank_unit(board, current_job.bank, current_job.target.get()).find_model(current_job.recipient)
            if existing < 0 or !source_bank_unit(board, current_job.bank, current_job.target.get())[existing].is_alive():
                continue
            recipient = existing
        else:
            board.current_state = CurrentStateDescription::mortal_wound
            act select_mortal_model(frm ModelID mortal_model) {mortal_model_valid(source_bank_unit(board, current_job.bank, current_job.target.get()), mortal_model)}
            recipient = mortal_model
        frm identity = source_bank_unit(board, current_job.bank, current_job.target.get())[recipient].identity
        frm application : CombatCounter
        application = 1
        if current_job.kind == DamageKind::normal:
            application = current_job.amount
        board.shared_actions.prevent_wound_loss = prevent_wound_loss(board, current_job.bank, current_job.target, recipient, application)
        subaction*(board) board.shared_actions.prevent_wound_loss
        frm prevention_lost_snapshot_6 = board.shared_actions.prevent_wound_loss.lost
        frm faction_fight_death = false
        frm faction_threshold : BInt<0, 5>
        faction_threshold = faction_fight_death_threshold(board, source_bank_unit(board, current_job.bank, current_job.target.get()), source_bank_unit(board, current_job.bank, current_job.target.get())[recipient])
        if prevention_lost_snapshot_6 > 0 and prevention_lost_snapshot_6.value >= source_bank_unit(board, current_job.bank, current_job.target.get())[recipient].wounds_left() and faction_threshold > 0:
            board.current_decision_maker = source_bank_unit(board, current_job.bank, current_job.target.get()).owned_by_player1
            act roll(Dice fight_death_face)
            faction_fight_death = fight_death_face.value >= faction_threshold.value
        commit_wound_loss(board, current_job, recipient, prevention_lost_snapshot_6.value, faction_fight_death or (current_job.from_attack and board.attack_info.fight_on_death and current_job.target.get() == previous_target.get()))
        if faction_fight_death:
            # The faction permission was already rolled at destruction. Do not
            # ask its successful retained fighter to roll again on selection.
            source_bank_unit(board, current_job.bank, current_job.target.get())[recipient].destruction_fight_roll = 1
        refresh_source_effects(board, TimingWindow::none)
        if !(current_job.kind == DamageKind::normal):
            current_job.amount = current_job.amount - 1
            if current_job.kind == DamageKind::devastating:
                if prevention_lost_snapshot_6 > 0:
                    current_job.recipient = identity
                else:
                    if current_job.recipient.value == identity.value and source_bank_unit(board, current_job.bank, current_job.target.get()).find_model(identity) >= 0 and source_bank_unit(board, current_job.bank, current_job.target.get())[source_bank_unit(board, current_job.bank, current_job.target.get()).find_model(identity)].suffered_wounds == 0:
                        current_job.recipient = invalid_entity_identity()
            if current_job.amount > 0:
                jobs.append(current_job)
    board.attack_info.target_unit_id = previous_target
    board.damage_bank = previous_bank
    board.current_decision_maker = previous_owner
    board.current_state = CurrentStateDescription::none

# Explicit invalid identity denotes mortal allocation still to be selected;
# it is lifecycle metadata, not an unbounded damage or ML numeric domain.
fun invalid_entity_identity() -> EntityIdentity:
    let identity : EntityIdentity
    return identity

# Ordinary mortals spill by one-wound allocation; damage jobs process immediate
# destruction before the next recipient, with no save roll (pp.24/87).
act resolve_mortal_wounds(ctx Board board, frm SourceBank bank, frm UnitID target, frm UnitID source, frm Bool source_known, frm CombatCounter amount) -> MortalWounds:
    frm jobs : DamageJobs
    let job = damage_job(DamageKind::mortal, target, source, source_known, false, amount.value, invalid_entity_identity())
    job.bank = bank
    jobs.append(job)
    board.shared_actions.resolve_damage_jobs = resolve_damage_jobs(board, jobs, false, source)
    subaction*(board) board.shared_actions.resolve_damage_jobs

# Battlefield selectors use the same damage engine as reserve/passenger
# own-unit mortals; only jobs' bank differs (p24; appendix01.02.04).
fun resolve_mortal_wounds(Board board, UnitID target, UnitID source, Bool source_known, CombatCounter amount) -> MortalWounds:
    return resolve_mortal_wounds(board, SourceBank::battlefield, target, source, source_known, amount)

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
        board.shared_actions.collect_attack_dice = collect_attack_dice(board, generated_wounds, false, false, true, target.owned_by_player1, board.attack_info.target_unit_id)
        subaction*(board) board.shared_actions.collect_attack_dice
        frm saves_pool_snapshot_1 = board.shared_actions.collect_attack_dice.pool
        frm face : BInt<1, 8>
        face = 1
        frm order_index : AllocationGroupCounter
        frm active_group : AllocationGroupID
        while face.value <= 6 and has_live_attack_recipient(target):
            if saves_pool_snapshot_1.faces[face.value - 1] == 0:
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
            saves_pool_snapshot_1.faces[face.value - 1] = saves_pool_snapshot_1.faces[face.value - 1] - 1
            if attack_save_succeeds(groups[active_group.value], die, board.attack_info.attack_penetration(target[id])):
                continue
            board.current_state = CurrentStateDescription::damage_roll
            # Merge the allocated model's incoming D before the per-attack roll
            # arithmetic/floor (p.19, appendix02.02.01/02.02.03).
            frm normal_modifiers = combined_incoming_modifiers(board.attack_info.damage_modifiers, target[id].incoming_attack_modifiers, ModifiedCharacteristic::damage, board.attack_info.source.range() == 0)
            board.shared_actions.evaluate_weapon_characteristic = evaluate_weapon_characteristic(board, board.attack_info.source.damage(), board.attack_info.melta_damage_bonus.value, source_unit.owned_by_player1, board.attack_info.source_unit_id, normal_modifiers, ModifiedCharacteristic::damage)
            subaction*(board) board.shared_actions.evaluate_weapon_characteristic
            frm normal_amount_result_snapshot_2 = board.shared_actions.evaluate_weapon_characteristic.result
            frm jobs : DamageJobs
            jobs.clear()
            jobs.append(damage_job(DamageKind::normal, board.attack_info.target_unit_id, board.attack_info.source_unit_id, true, true, normal_amount_result_snapshot_2.value, target[id].identity))
            board.shared_actions.resolve_damage_jobs = resolve_damage_jobs(board, jobs, false, board.attack_info.source_unit_id)
            subaction*(board) board.shared_actions.resolve_damage_jobs
    while generated_critical_wounds > 0 and has_live_attack_recipient(target):
        board.current_decision_maker = target.owned_by_player1
        board.current_state = CurrentStateDescription::mortal_wound
        act allocate_mortal(frm ModelID critical_model) {mortal_model_valid(target, critical_model)}
        frm critical_recipient = target[critical_model].identity
        board.current_state = CurrentStateDescription::damage_roll
        # Devastating attacks use the allocated recipient's D modifiers before
        # conversion to mortal wound loss, not on each wound separately (p.80).
        frm critical_modifiers = combined_incoming_modifiers(board.attack_info.damage_modifiers, target[critical_model].incoming_attack_modifiers, ModifiedCharacteristic::damage, board.attack_info.source.range() == 0)
        board.shared_actions.evaluate_weapon_characteristic = evaluate_weapon_characteristic(board, board.attack_info.source.damage(), board.attack_info.melta_damage_bonus.value, source_unit.owned_by_player1, board.attack_info.source_unit_id, critical_modifiers, ModifiedCharacteristic::damage)
        subaction*(board) board.shared_actions.evaluate_weapon_characteristic
        frm critical_amount_result_snapshot_4 = board.shared_actions.evaluate_weapon_characteristic.result
        frm critical_jobs : DamageJobs
        critical_jobs.clear()
        critical_jobs.append(damage_job(DamageKind::devastating, board.attack_info.target_unit_id, board.attack_info.source_unit_id, true, true, critical_amount_result_snapshot_4.value, critical_recipient))
        board.shared_actions.resolve_damage_jobs = resolve_damage_jobs(board, critical_jobs, false, board.attack_info.source_unit_id)
        subaction*(board) board.shared_actions.resolve_damage_jobs
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
    board.shared_actions.collect_attack_dice = collect_attack_dice(board, amount, false, false, true, board[unit].owned_by_player1, unit)
    subaction*(board) board.shared_actions.collect_attack_dice
    frm hazards_pool_snapshot_1 = board.shared_actions.collect_attack_dice.pool
    amount = (hazards_pool_snapshot_1.faces[0].value + hazards_pool_snapshot_1.faces[1].value) * multiplier.value
    board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, unit, unit, false, amount)
    subaction*(board) board.shared_actions.resolve_mortal_wounds

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

# Configure the selected target before its declared groups and timing effects
# (pp.16–18). Faction consumers remain explicit legacy fixtures for task 17.
fun configure_attack_info(Board board, Int source, Int target, Bool overwatch, Bool melee):
    let attack : AttackSequenceInfo
    attack.source_unit_id = source 
    attack.target_unit_id = target
    if overwatch:
        attack.only_hits_on_6 = true 

    attack.shooting_kind = board[source].shooting_kind
    append_unit_hit_modifiers(board[source], attack.unit_ability_hit_modifiers)
    # p.18 / appendix05.02.01: snapshot effective T without bounded clamping.
    # The storage capacity is engine infrastructure, not a tabletop maximum.
    let target_toughness = board[target].get_unit_toughtness()
    assert(target_toughness >= 0 and target_toughness < MAX_CHARACTERISTIC, "target Toughness snapshot capacity exceeded")
    attack.target_toughness = target_toughness
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
                board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, source, source, false, pact_damage)
                subaction*(board) board.shared_actions.resolve_mortal_wounds
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
            board.shared_actions.resolve_damage_jobs = resolve_damage_jobs(board, offering_jobs, false, source)
            subaction*(board) board.shared_actions.resolve_damage_jobs
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
                board.shared_actions.choose_weapon_abilities = choose_weapon_abilities(board, declarations.back().selected_rules)
                subaction*(board) board.shared_actions.choose_weapon_abilities
                frm ability_choices_chosen_snapshot_1 = board.shared_actions.choose_weapon_abilities.chosen
                declarations.back().selected_rules = ability_choices_chosen_snapshot_1
                declarations.back().current_target_rules = ability_choices_chosen_snapshot_1
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
    if melee:
        let total = declaration_fixed_attacks(board, source, weapon, 0)
        assert(total >= 0 and total < MAX_CHARACTERISTIC, "melee attack share capacity exceeded")
        if melee and total == 0:
            return
        remaining = total
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
    # Damaged is bearer-local, refreshed for every new group (core24.39).
    info.damaged_hit_penalty = board[source][model].is_damaged()
    info.unit_ability_hit_modifiers.clear()
    append_unit_hit_modifiers(board[source], info.unit_ability_hit_modifiers)
    #02.02.02: permissions follow the actual bearer (carrier for Firing Deck),
    # not the chosen target or an unrelated model in a mixed unit.
    info.may_ignore_skill_modifiers = attack_permission_available(board, board[source][model], info.source.range() == 0, true)
    info.may_ignore_hit_modifiers = attack_permission_available(board, board[source][model], info.source.range() == 0, false)
    # Recompute each new group's battlefield T after earlier casualties/effects
    # (appendix05.02.01); target_info only preserves the enclosing rule choices.
    info.source_unit_id = source
    info.target_unit_id = target
    let live_toughness = board[target].get_unit_toughtness()
    assert(live_toughness >= 0 and live_toughness < MAX_CHARACTERISTIC, "group Toughness snapshot capacity exceeded")
    info.target_toughness = live_toughness
    info.skill_modifiers = declaration_modifiers(board, source, weapon, ModifiedCharacteristic::weapon_skill)
    if weapon.weapon.range() > 0:
        info.skill_modifiers = declaration_modifiers(board, source, weapon, ModifiedCharacteristic::ballistic_skill)
    info.damage_modifiers = declaration_modifiers(board, source, weapon, ModifiedCharacteristic::damage)
    info.ap_modifiers = declaration_modifiers(board, source, weapon, ModifiedCharacteristic::armour_penetration)
    let strength_modifiers = declaration_modifiers(board, source, weapon, ModifiedCharacteristic::strength)
    let strength = modified_characteristic(weapon.weapon.strenght(), ModifiedCharacteristic::strength, strength_modifiers, false)
    assert(strength >= 0 and strength < MAX_CHARACTERISTIC, "weapon Strength snapshot capacity exceeded")
    info.weapon_strength = strength
    info.characteristics_known = true
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
    append_attack_effects(board, source, target, weapon, info)
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
# melee weapons contribute their modified declared share. Apply a gather-time
# core bonus as the difference of total modified A with/without that bonus;
# applying the bearer modifiers to each share would multiply split attacks.
act gather_weapon_count(ctx Board board, frm UnitID source, frm UnitID target, frm DeclaredWeapon declaration, frm Bool melee) -> WeaponAttackCount:
    frm result : RandomStatResult
    if melee and weapon_has_fixed_attacks(declaration.weapon):
        let extra = gathering_extra_attacks(board, source, target, declaration)
        let count = declaration.shares[target.get()].value + declaration_fixed_attacks(board, source, declaration, extra) - declaration_fixed_attacks(board, source, declaration, 0)
        assert(count >= 0 and count < MAX_RANDOM_STAT_RESULT, "melee gathered attack capacity exceeded")
        result = count
    else:
        board.current_state = CurrentStateDescription::quantity_roll
        board.shared_actions.evaluate_weapon_characteristic = evaluate_weapon_characteristic(board, declaration.weapon.attacks(), gathering_extra_attacks(board, source, target, declaration), board[source].owned_by_player1, source, declaration_attack_modifiers(board, source, declaration), ModifiedCharacteristic::attacks)
        subaction*(board) board.shared_actions.evaluate_weapon_characteristic
        frm generated_result_snapshot_1 = board.shared_actions.evaluate_weapon_characteristic.result
        result = generated_result_snapshot_1

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
            board.shared_actions.choose_weapon_abilities = choose_weapon_abilities(board, available)
            subaction*(board) board.shared_actions.choose_weapon_abilities
            frm granted_choices_chosen_snapshot_1 = board.shared_actions.choose_weapon_abilities.chosen
            declarations[index.value].current_target_rules = granted_choices_chosen_snapshot_1
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
    begin_attack_results(board)
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
    subaction*(board) faction_selection = faction_attack_selection_options(board, source, melee)
    board.shared_actions.resolve_source_event = resolve_source_event(board, source_event(SourceEventKind::attack_selection, board[source].identity, board[target].identity, invalid_entity_identity()))
    subaction*(board) board.shared_actions.resolve_source_event
    if !melee and board.timing.phase == BattlePhase::shooting and board[source].owned_by_player1 == board.current_player:
        subaction*(board) declaration_options = faction_pre_declaration_options(board, source)
    frm declarations : DeclaredWeapons
    frm model : ModelIterator
    frm hazardous_uses : HazardousUses
    while model.value < board[source].models.size():
        let id : ModelID
        id = model.value
        subaction*(board, declarations) selection = declare_model_weapons(board, declarations, source, id, melee)
        model = model + 1
    if !melee and !overwatch and board.timing.phase == BattlePhase::shooting and board[source].owned_by_player1 == board.current_player:
        subaction*(board, declarations) deck_selection = select_firing_deck(board, declarations, source)
    frm declaration_index : LinearlyDistributedInt<0, MAX_SELECTED_WEAPONS_PLUS1>
    while declaration_index.value < declarations.size():
        subaction*(board) targets = declare_weapon_targets(board, declarations[declaration_index.value], source, melee)
        declarations.set(declaration_index.value, targets.weapon)
        declaration_index = declaration_index + 1
    subaction*(board, declarations) declaration_effects = faction_declarations_complete(board, declarations, source, melee)
    frm declaration_effect = declaration_effects.effect
    while has_unresolved_attacks(declarations):
        board.current_decision_maker = board[source].owned_by_player1
        board.shared_actions.revalidate_attack_targets = revalidate_attack_targets(board, declarations, source, melee)
        subaction*(board, declarations) board.shared_actions.revalidate_attack_targets
        if !has_unresolved_attacks(declarations):
            break
        act choose_attack_target(UnitID unit) {target_has_unresolved_weapons(declarations, unit)}
        target = unit
        board.shared_actions.resolve_source_event = resolve_source_event(board, source_event(SourceEventKind::attack_targeted, board[source].identity, board[target].identity, invalid_entity_identity()))
        subaction*(board) board.shared_actions.resolve_source_event
        subaction*(board) detachment_defence = faction_attack_targeted(board, source, target, melee)
        configure_attack_info(board, source.get(), target.get(), overwatch, melee)
        subaction*(board) strats = use_attack_stratagems(board, source, target, melee)
        frm target_info = board.attack_info
        board.current_decision_maker = board[source].owned_by_player1
        subaction*(board, declarations) target_abilities = prepare_target_weapon_abilities(board, declarations, source, target, target_info)
        while target_has_unresolved_weapons(declarations, target):
            board.shared_actions.revalidate_attack_targets = revalidate_attack_targets(board, declarations, source, melee)
            subaction*(board, declarations) board.shared_actions.revalidate_attack_targets
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
    board.shared_actions.resolve_damage_jobs = resolve_damage_jobs(board, cleanup_jobs, true, source)
    subaction*(board) board.shared_actions.resolve_damage_jobs
    remove_scoped_source_effect(board, declaration_effect)
    if !melee and board.timing.phase == BattlePhase::shooting and board[source].owned_by_player1 == board.current_player:
        subaction*(board) hit_effects = faction_hit_results(board, source)
        subaction*(board) options_end = faction_shooting_finished(board, source)
    hazardous_uses = declared_hazardous_uses(declarations)
    board.shared_actions.resolve_hazards = resolve_hazards(board, source, hazardous_uses)
    subaction*(board) board.shared_actions.resolve_hazards
    if faction_extra_attack_hazards(board, board[source]) > 0:
        frm button_test : HazardousUses
        button_test = faction_extra_attack_hazards(board, board[source])
        board.shared_actions.resolve_hazards = resolve_hazards(board, source, button_test)
        subaction*(board) board.shared_actions.resolve_hazards

    board.shared_actions.resolve_source_event = resolve_source_event(board, source_event(SourceEventKind::attack_end, board[source].identity, board[target].identity, invalid_entity_identity()))
    subaction*(board) board.shared_actions.resolve_source_event
    end_attack_results(board)
    board.timing.active_player = previous_active
    board[source].shooting_kind = previous_kind
    board.current_decision_maker = previous_owner
    board.current_state = CurrentStateDescription::none


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
    board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, target, source, true, amount)
    subaction*(board) board.shared_actions.resolve_mortal_wounds
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
    # p.56 requires the bearer's effective T dice; do not clamp that count.
    let impact_toughness = board[source][model].effective_toughness()
    assert(impact_toughness >= 0 and impact_toughness < MAX_CHARACTERISTIC, "Crushing Impact Toughness capacity exceeded")
    total = impact_toughness
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
    board.shared_actions.resolve_damage_jobs = resolve_damage_jobs(board, jobs, false, source)
    subaction*(board) board.shared_actions.resolve_damage_jobs
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
    board.shared_actions.attack_with_reactions = attack_with_reactions(board, source, target, false, true)
    subaction*(board) board.shared_actions.attack_with_reactions
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
    board.shared_actions.charge = charge(board, source, kind)
    subaction*(board) board.shared_actions.charge
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
    register_faction_datasheet_sources(board)
    board.open_timing_window(window)
    frm player = board.timing.active_player
    # Exactly two controller groups; bounded frame storage supports ML inference.
    frm count : BInt<0, 3>
    frm core_progress : CoreTimingProgress
    frm faction_progress : FactionTimingProgress
    frm previous_candidates = board.active_source_events
    frm source_trigger : SourceEvent
    source_trigger.kind = SourceEventKind::timing_window
    source_trigger.window = window
    frm pending = collect_source_events(board, source_trigger)
    while count < 2:
        let i = 0
        while i < 9:
            core_progress.resolved[i] = false
            i = i + 1
        reset_faction_timing_progress(faction_progress)
        board.current_decision_maker = player
        board.timing.controller = player
        if count == 1:
            board.timing.stage = TimingStage::opposing_player_rules
        while timing_rules_remaining(board, window, player, core_progress.resolved) or source_events_remaining(board, pending, player, false) or faction_timing_options_remaining(board, window, player, faction_progress, false):
            board.active_source_events = pending
            frm core_choice = core_timing_choice(board, core_progress, faction_progress, pending, window, player)
            frm faction_choice = faction_timing_choice(board, core_progress, faction_progress, pending, window, player)
            subaction(board, core_progress, faction_progress, pending) core_choice, faction_choice
            if core_choice.started:
                subaction*(board, core_progress, faction_progress, pending) core_choice
                if core_choice.finished:
                    break
            else:
                subaction*(board, core_progress, faction_progress, pending) faction_choice
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
    board.active_source_events = previous_candidates
    board.close_timing_window()

# Roll against any Leadership characteristic (p.9). Only a successful roll
# in the Command Battle-shock step clears shock present at that step's start
# (p.30). Insane Bravery is restricted to that step and once per battle (p.56).
# Mobbed supplies the -1/-2 roll penalty through this same pipeline:
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz
act battle_shock_test(ctx Board board, ctx Unit unit, frm Bool command_step, frm Bool recover_shock, frm LinearlyDistributedInt<0, 8> penalty) -> BattleShockTest:
    if unit.empty():
        return
    frm previous_owner = board.current_decision_maker
    board.current_decision_maker = unit.owned_by_player1
    board.shared_actions.resolve_source_event = resolve_source_event(board, source_event(SourceEventKind::shock_start, unit.identity, invalid_entity_identity(), invalid_entity_identity()))
    subaction*(board) board.shared_actions.resolve_source_event
    frm shocked_before = unit.battle_socked
    frm auto_pass = faction_automatic_shock_success(board, unit)
    if !auto_pass and command_step and board.timing.phase == BattlePhase::command and unit.owned_by_player1 == board.current_player and !board.has_used_insane_bravery[int(unit.owned_by_player1)] and board.can_target_strat(unit.owned_by_player1, Stratagem::insane_bravery, unit):
        act insane_bravery(Bool do_it)
        if do_it:
            board.commit_stratagem(unit.owned_by_player1, Stratagem::insane_bravery, unit)
            auto_pass = true
    if !auto_pass:
        # Leadership/Battle-shock is absent from Command Re-roll's list (p.56).
        board.current_pair_roll = rerollable_pair_dices_roll(board, false, false, false, unit.owned_by_player1)
        subaction*(board) board.current_pair_roll
        if !unit.leadership_roll_succeeds(max(1, board.current_pair_roll.result.value + board.current_pair_roll.result2.value - penalty.value - faction_leadership_roll_penalty(board, unit))):
            unit.battle_socked = true
        else:
            if command_step and recover_shock:
                unit.battle_socked = false
    else:
        if command_step and recover_shock:
            unit.battle_socked = false
    if !shocked_before and unit.battle_socked:
        board.shared_actions.faction_became_shocked = faction_became_shocked(board, unit.identity)
        subaction*(board) board.shared_actions.faction_became_shocked
    board.shared_actions.resolve_source_event = resolve_source_event(board, source_event(SourceEventKind::shock_end, unit.identity, invalid_entity_identity(), invalid_entity_identity()))
    subaction*(board) board.shared_actions.resolve_source_event
    board.current_decision_maker = previous_owner

# Existing callers have no extra penalty; Mobbed uses the same shock pipeline
# with its printed-1/-2 roll modifier, including start/end source triggers.
fun battle_shock_test(Board board, Unit unit, Bool command_step, Bool recover_shock) -> BattleShockTest:
    let penalty : LinearlyDistributedInt<0, 8>
    return battle_shock_test(board, unit, command_step, recover_shock, penalty)


# Test each live friendly unit once when already shocked or at/below half
# (p.30). Snapshot shock at the step's start for the printed recovery condition;
# never clear the opponent's shock or automatically expire a friendly effect.
act battle_shock_step(ctx Board board) -> BattleShockStep:
    subaction*(board) mob_mentality = faction_before_battle_shock(board)
    # Freeze recovery eligibility at the step's start for EVERY bank (p30;
    # appendix01.02.04). Storage location must not change the printed test.
    frm shocked_at_start : Bool[MAX_UNIT_COUNT][3]
    let initial_bank : SourceBank
    for initial_bank_index in range(3):
        initial_bank.value = initial_bank_index
        for initial_slot in range(source_bank_size(board, initial_bank)):
            shocked_at_start[initial_bank_index][initial_slot] = source_bank_unit(board, initial_bank, initial_slot).battle_socked
    frm bank : SourceBank
    frm bank_index : BInt<0, 4>
    while bank_index.value < 3:
        bank.value = bank_index.value
        frm slot : UnitIterator
        slot = 0
        while slot.value < source_bank_size(board, bank):
            if !source_bank_unit(board, bank, slot.value).empty() and source_bank_unit(board, bank, slot.value).owned_by_player1 == board.current_player and (source_bank_unit(board, bank, slot.value).battle_socked or source_bank_unit(board, bank, slot.value).is_at_or_below_half_strength()):
                board.shared_actions.battle_shock_test = battle_shock_test(board, source_bank_unit(board, bank, slot.value), true, shocked_at_start[bank_index.value][slot.value])
                subaction*(board, source_bank_unit(board, bank, slot.value)) board.shared_actions.battle_shock_test
            slot = slot + 1
        bank_index = bank_index + 1


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
                board.shared_actions.battle_shock_test = battle_shock_test(board, board[i.value], false, false)
                subaction*(board, board[i.value]) board.shared_actions.battle_shock_test
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
                board.shared_actions.battle_shock_test = battle_shock_test(board, board[target], false, false)
                subaction*(board, board[target]) board.shared_actions.battle_shock_test

# core rule command phase 
# Gain both players' Core CP before Battle-shock, then resolve Command
# abilities (p.30). Start/end windows are owned by turn(), not repeated here.
act command_phase(ctx Board board) -> CommandPhase:
    for i in range(2):
        board.command_points[i] = board.command_points[i] + 1
    # Recovery is a roll here rather than automatic shock expiration (p.30).
    subaction*(board) shock_step = battle_shock_step(board)
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::command_abilities)
    subaction*(board) board.shared_actions.resolve_timing_window
    board.current_decision_maker = board.current_player

# Movement-only dispatch allows targeted Keep Huntin'/Bomb Squig and ordinary
# source grants to share controller ordering. Damage/destruction dispatch stays
# separate so its action frame cannot recursively contain itself.
# Sources: Orks/Beastboss Keep Huntin'; Orks/Squighog-Boyz Bomb Squig;
# user Rules Sequencing; mortal allocation/destruction core pp24/87.
act resolve_movement_sources(ctx Board board, frm SourceEvent trigger) -> MovementSourceResolution:
    register_faction_datasheet_sources(board)
    frm previous_owner = board.current_decision_maker
    frm previous_candidates = board.active_source_events
    frm pending = collect_source_events(board, trigger)
    frm player = board.current_player
    frm controllers : BInt<0, 3>
    while controllers.value < 2:
        board.current_decision_maker = player
        while faction_movement_events_remaining(board, pending, player, false):
            board.active_source_events = pending
            actions:
                act finish_source_events() {!faction_movement_events_remaining(board, pending, player, true)}
                    break
                act choose_movement_source(frm SourceEventID event) {faction_movement_event_available(board, pending, event, player)}
                    subaction*(board, pending) chosen_movement_effect = faction_resolve_movement_source(board, pending, event, player)

        player = !player
        controllers = controllers + 1
    board.active_source_events = previous_candidates
    board.current_decision_maker = previous_owner

# Independent model movement preserves staged positions until full coherency.
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
    frm move_start_event = source_event(SourceEventKind::move_start, board[unit].identity, invalid_entity_identity(), invalid_entity_identity())
    move_start_event.movement = board[unit].pending_move_kind
    if move_start_event.movement == MovementKind::stationary:
        move_start_event.movement = MovementKind::normal
    board.shared_actions.resolve_movement_sources = resolve_movement_sources(board, move_start_event)
    subaction*(board) board.shared_actions.resolve_movement_sources
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
                        act rotate_model(MovementRotation rotation) {!rotated, model_can_move(original[model])}
                            path.final_rotation = rotation.value * 1000
                            rotated = true
    if completed:
        # p.58: direct out-of-phase movement also interrupts pending actions.
        board[unit].interrupt_actions()
        # Any completed move, including out-of-phase moves, blocks a later
        # surge in this phase (p.70); stationary never enters this action.
        board[unit].history.last_move_phase = board.phase_serial.value + 1
        board[unit].history.made_move_this_turn = true
    if completed:
        frm move_end_event = source_event(SourceEventKind::move_end, board[unit].identity, invalid_entity_identity(), invalid_entity_identity())
        move_end_event.movement = kind
        board.shared_actions.resolve_movement_sources = resolve_movement_sources(board, move_end_event)
        subaction*(board) board.shared_actions.resolve_movement_sources
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
    board.shared_actions.resolve_damage_jobs = resolve_damage_jobs(board, jobs, false, source)
    subaction*(board) board.shared_actions.resolve_damage_jobs
    subaction*(board) returns = faction_pending_returns(board)

# Pile In/consolidation are optional staged per-model moves, separate from
# attack selection (pp.38/42). No partial path changes live positions; closest
# target ties are controller choices. Physical features/continuous grid are deferred.
act melee_move(ctx Board board, frm UnitID source, frm Bool consolidate, frm Bool overrun) -> MeleeMove:
    if !melee_move_eligible(board, source, consolidate, overrun):
        return
    board.shared_actions.faction_move_selection = faction_move_selection(board, source, true)
    subaction*(board) board.shared_actions.faction_move_selection
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
    subaction*(board) datasheet_psychic_fight = faction_datasheet_fight_selection(board, source)
    subaction*(board) melee_options = faction_melee_weapon_selection(board, source)
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
        board.shared_actions.melee_move = melee_move(board, source, false, true)
        subaction*(board) board.shared_actions.melee_move
    let unused_target : UnitID
    board.shared_actions.attack_with_reactions = attack_with_reactions(board, source, unused_target, true, false)
    subaction*(board) board.shared_actions.attack_with_reactions
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
                board.shared_actions.selected_fight = selected_fight(board, source)
                subaction*(board) board.shared_actions.selected_fight
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
                    board.shared_actions.melee_move = melee_move(board, source, consolidate, false)
                    subaction*(board) board.shared_actions.melee_move
                    frm moving_completed_snapshot_1 = board.shared_actions.melee_move.completed
                    frm moving_kind_snapshot_1 = board.shared_actions.melee_move.kind
                    if consolidate and moving_completed_snapshot_1 and moving_kind_snapshot_1 == MeleeMoveKind::engaging:
                        for i in range(board.units.size()):
                            if board[i].owned_by_player1 != mover and !board[i].has_fought and board[source].is_engaged_with(board[i]):
                                board[i].history.consolidation_fight_pending = board.phase_serial.value + 1
                                board[i].history.fight_eligible_phase = board.phase_serial.value + 1
                        while has_consolidation_response(board, !mover):
                            board.current_decision_maker = !mover
                            act select_consolidation_fighter(frm UnitID response) {response.get() < board.units.size(), board[response].owned_by_player1 != mover, consolidation_response_valid(board, response)}
                            board.shared_actions.selected_fight = selected_fight(board, response)
                            subaction*(board) board.shared_actions.selected_fight
                    board.current_decision_maker = mover
        side = side + 1
        mover = !mover
    board.current_decision_maker = previous_owner

# Core fight bodies are phase-wide Pile In, mandatory fights and consolidation
# (pp.38–43). The user retires the previous Orks implementation; its obsolete
# Bestial Bellow decision must not appear before the new edition's Fight step.
act fight_phase(ctx Board board) -> FightPhase:
    board.shared_actions.melee_move_step = melee_move_step(board, false)
    subaction*(board) board.shared_actions.melee_move_step
    subaction*(board) fights = fight_step(board, true)
    board.shared_actions.melee_move_step = melee_move_step(board, true)
    subaction*(board) board.shared_actions.melee_move_step

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
    frm charge_roll_effects : ChargeRollEffects
    append_charge_roll_effects(board, board[source], charge_roll_effects)
    board.current_pair_roll = rerollable_pair_dices_roll(board, board[source].can_reroll_charge() or charge_roll_effects.reroll, false, true, board[source].owned_by_player1, source)
    subaction*(board) board.current_pair_roll
    if original.has_keyword(Keyword::fly):
        act charge_take_to_skies(Bool do_it)
        skies = do_it
    maximum = charge_distance(board, original, board.current_pair_roll.result.value + board.current_pair_roll.result2.value, kind, skies)
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
                        act rotate_charge_model(MovementRotation rotation) {!rotated, model_can_move(original[model])}
                            path.final_rotation = rotation.value * 1000
                            rotated = true
    # A candidate snapshot predates declaration. Preserve declaration after
    # committing it so a success cannot be declared again this phase (p.36).
    board[source].history.declared_charge_phase = board.phase_serial.value + 1
    if completed:
        record_charge_move(board, source)
        # Mobbed and Crushing Impact share the charge-end controller group;
        # the charging player chooses their order (user Rules Sequencing).
        frm faction_progress = faction_charge_progress(board, source)
        frm crushing_pending = crushing_source_valid(board, source)
        while faction_charge_effects_remaining(faction_progress) or crushing_pending:
            frm core_choice = core_charge_choice(board, faction_progress, crushing_pending, source)
            frm faction_choice = faction_charge_choice(board, faction_progress, crushing_pending, source)
            subaction(board, faction_progress, crushing_pending) core_choice, faction_choice
            if core_choice.started:
                subaction*(board, faction_progress, crushing_pending) core_choice
            else:
                subaction*(board, faction_progress, crushing_pending) faction_choice
        board.shared_actions.faction_charge_finished = faction_charge_finished(board, source)
        subaction*(board) board.shared_actions.faction_charge_finished
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
                board.shared_actions.charge = charge(board, source, ChargeKind::ordinary)
                subaction*(board) board.shared_actions.charge
                board.current_decision_maker = board.current_player

# Desperate Escape rolls one complete hazard batch per model, then applies
# ordinary mortal allocation/FNP/destruction instead of deleting models (pp.24/33).
act desperate_escape(ctx Board board, frm UnitID id) -> DesperateEscapeTest:
    # Orks/Big-ed-Bossbunka Fortification automatically passes these hazards.
    if !board[id].battle_socked and permits_escape_without_hazards(board, board[id]):
        return
    frm count : CombatCounter
    count = live_attachment_strength(board[id])
    frm penalty : FixedStat
    penalty = faction_escape_penalty(board, board[id])
    frm extra_count : CombatCounter
    extra_count = faction_extra_escape_hazards(board, board[id])
    frm shocked = board[id].battle_socked
    board.shared_actions.collect_attack_dice = collect_attack_dice(board, count, false, false, true, board[id].owned_by_player1, id)
    subaction*(board) board.shared_actions.collect_attack_dice
    frm hazards_pool_snapshot_1 = board.shared_actions.collect_attack_dice.pool
    frm failures : CombatCounter
    for face in range(6):
        if face + 1 - penalty.value <= 2:
            add_attack_count(failures, hazards_pool_snapshot_1.faces[face].value)
    if extra_count > 0:
        board.shared_actions.collect_attack_dice = collect_attack_dice(board, extra_count, false, false, true, board[id].owned_by_player1, id)
        subaction*(board) board.shared_actions.collect_attack_dice
        frm additional_pool_snapshot_2 = board.shared_actions.collect_attack_dice.pool
        for extra_face in range(6):
            if extra_face + 1 - penalty.value - int(shocked) <= 2:
                add_attack_count(failures, additional_pool_snapshot_2.faces[extra_face].value)
    failures = failures.value * hazard_mortal_multiplier(board[id])
    board.shared_actions.resolve_mortal_wounds = resolve_mortal_wounds(board, id, id, false, failures)
    subaction*(board) board.shared_actions.resolve_mortal_wounds

# Choose an explicit mutually exclusive move. Random M is determined once
# when selected; advance roll and fall-back hazards precede paths (p.33;
# supplied appendix 02.02.03). A failed staged move can be retried (p.12).
act movement(ctx Board board, frm UnitID id, frm Bool use_the_gilded_spear) -> Movement:
    board.shared_actions.faction_movement_abilities = faction_movement_abilities(board, id)
    subaction*(board) board.shared_actions.faction_movement_abilities
    board.shared_actions.faction_move_selection = faction_move_selection(board, id, false)
    subaction*(board) board.shared_actions.faction_move_selection
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
        board.shared_actions.evaluate_random_stat = evaluate_random_stat(board[id][random_index.value].random_movement)
        subaction* board.shared_actions.evaluate_random_stat
        frm random_m_result_snapshot_3 = board.shared_actions.evaluate_random_stat.result
        board[id].movement_override = max(1, random_m_result_snapshot_3.value) + 1
    while !selected:
        frm core_choice = core_move_kind_choice(board, id, use_the_gilded_spear)
        frm faction_choice = faction_special_move_choice(board, id)
        subaction(board) core_choice, faction_choice
        if core_choice.started:
            subaction*(board) core_choice
            kind = core_choice.kind
            extra = core_choice.extra
        else:
            subaction*(board) faction_choice
            kind = faction_choice.kind
            extra = faction_choice.extra
        selected = true
    if kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape:
        board.shared_actions.faction_move_mode = faction_move_mode(board, id, kind)
        subaction*(board) board.shared_actions.faction_move_mode
        board.shared_actions.faction_fallback_selection = faction_fallback_selection(board, id)
        subaction*(board) board.shared_actions.faction_fallback_selection
        if faction_forces_escape(board, board[id]):
            kind = MovementKind::desperate_escape
        capture_faction_selected_move(board, id, kind)
        if kind == MovementKind::desperate_escape:
            board.shared_actions.desperate_escape = desperate_escape(board, id)
            subaction*(board) board.shared_actions.desperate_escape
    if !(board[id].history.selected_move_phase == board.phase_serial.value + 1) and has_live_model(board[id]):
        board[id].pending_move_kind = kind
        board[id].move_takes_to_skies = false
        if board[id].has_keyword(Keyword::fly) and rule_flight_allowed(board, board[id]):
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
        board.shared_actions.move = move(board, id, extra)
        subaction*(board, id) board.shared_actions.move
        frm player_move_completed_snapshot_8 = board.shared_actions.move.completed
        if mobile:
            for i in range(board[id].models.size()):
                if !was_mobile[i]:
                    let k = board[id][i].keywords.size() - 1
                    while k >= 0:
                        if board[id][i].keywords[k] == Keyword::mobile:
                            board[id][i].keywords.erase(k)
                        k = k - 1
            if player_move_completed_snapshot_8:
                act roll(Dice mobile_hazard)
                if mobile_hazard.value == 1:
                    board[id].battle_socked = true
        if player_move_completed_snapshot_8:
            record_move(board, id, kind)
            if kind == MovementKind::desperate_escape and !board[id].battle_socked:
                board.shared_actions.battle_shock_test = battle_shock_test(board, board[id], false, false)
                subaction*(board, board[id]) board.shared_actions.battle_shock_test
        else:
            # The move failed and returns all positions. Selection still has a
            # legal stationary/retry path through the phase loop (pp.12/32).
            board[id].history.move_kind = MovementKind::stationary
    finish_faction_move_selection(board, id)
    if board[id].history.last_move_phase == board.phase_serial.value + 1 and !(board[id].history.move_kind == MovementKind::stationary) and has_live_model(board[id]):
        subaction*(board) faction_reactions = faction_after_move(board, id)
    board.shared_actions.post_move_embark = post_move_embark(board, id)
    subaction*(board) board.shared_actions.post_move_embark
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
act disembark(ctx Board board, frm UnitID passenger_bank, frm Bool reactive) -> Disembark:
    frm completed = false
    assert(reactive or ordinary_disembark_valid(board, passenger_bank), "illegal disembarkation")
    frm carrier_location = find_passenger_carrier(board, board.embarked_units[passenger_bank.get()].embarked_transport)
    frm mode = required_disembark_mode(board, board.embarked_units[passenger_bank.get()], carrier_location)
    if reactive:
        mode = DisembarkMode::rapid
    subaction*(board) selected_passenger = faction_disembark_selection(board, passenger_bank, carrier_location)
    if mode == DisembarkMode::assault:
        act choose_assault_disembark(Bool use_assault)
        if !use_assault:
            mode = DisembarkMode::rapid
    actions:
        act decline_disembark()
            return
        act confirm_disembark_mode(DisembarkMode chosen_mode) {chosen_mode == mode}
    frm passenger_slot = stage_disembarking_passenger(board, passenger_bank)
    if mode == DisembarkMode::combat:
        frm disembark_hazards : HazardousUses
        disembark_hazards = board[passenger_slot].models.size()
        board.shared_actions.resolve_hazards = resolve_hazards(board, passenger_slot, disembark_hazards)
        subaction*(board) board.shared_actions.resolve_hazards
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
    completed = true
    board.moving_unit = previous_mover

# Every friendly unit must be selected exactly once, including reserves.
# No remaining arbitrary end-phase escape bypasses mandatory selection (p.32).
act movement_phase(ctx Board board) -> MovementPhase:
    board.current_decision_maker = board.current_player
    while true:
        frm core_choice = core_movement_phase_choice(board)
        frm faction_choice = faction_movement_phase_choice(board)
        subaction(board) core_choice, faction_choice
        if core_choice.started:
            subaction*(board) core_choice
            if core_choice.finished:
                break
        else:
            subaction*(board) faction_choice
    board.current_decision_maker = board.current_player


# Select the shooting type before weapons, even for a unit with no ranged
# weapons; shooting prohibits phase-local action starts (pp.34–35/57/88).


act selected_shooting(ctx Board board, frm UnitID source, frm UnitID initial_target) -> SelectedShooting:
    board.shared_actions.faction_shooting_support = faction_shooting_support(board, source)
    subaction*(board) board.shared_actions.faction_shooting_support
    board[source].has_shoot = true
    board[source].history.shot_this_phase = true
    act choose_shooting_kind(ShootingKind kind) {shooting_kind_valid(board, source, kind)}
    board[source].shooting_kind = kind
    board.shared_actions.attack_with_reactions = attack_with_reactions(board, source, initial_target, false, false)
    subaction*(board) board.shared_actions.attack_with_reactions

# Keep the existing two-UnitID click selector as a compatibility entrypoint;
# the new one-unit selector also supports no-weapon units (pp.34–35/88).
act shooting_phase(ctx Board board) -> ShootingPhase:
    board.current_decision_maker = board.current_player
    while true:
        frm core_choice = core_shooting_phase_choice(board)
        frm faction_choice = faction_shooting_phase_choice(board)
        subaction(board) core_choice, faction_choice
        if core_choice.started:
            subaction*(board) core_choice
            if core_choice.finished:
                break
        else:
            subaction*(board) faction_choice

# one of the most important sequences, the whole turn of a single
# player, as specified by the core rules
# Reset turn-local carriers and expire per-phase records at existing boundaries
# (turn/phase sequence pp.28–30). Explicit start/end windows remain task 5.
act turn(ctx Board board, frm Bool player_id) -> Turn:
    # Infrastructure: turn windows run sequentially (p28). Their effects and
    # history stay in Board, so reuse the completed frame instead of snapshots.
    board.current_player = player_id
    board.timing.active_player = player_id
    board.current_decision_maker = player_id
    board.start_turn_history()
    frm retained_cleanup : PhaseRetainedCleanup
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::turn_start)
    subaction*(board) board.shared_actions.resolve_timing_window
    board.begin_phase(BattlePhase::command)
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::command_start)
    subaction*(board) board.shared_actions.resolve_timing_window
    subaction*(board) command_phase = command_phase(board)
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::command_end)
    subaction*(board) board.shared_actions.resolve_timing_window
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.begin_phase(BattlePhase::movement)
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::movement_start)
    subaction*(board) board.shared_actions.resolve_timing_window
    subaction*(board) movement_phase = movement_phase(board)
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::movement_end)
    subaction*(board) board.shared_actions.resolve_timing_window
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.begin_phase(BattlePhase::shooting)
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::shooting_start)
    subaction*(board) board.shared_actions.resolve_timing_window
    subaction*(board) shooting_phase = shooting_phase(board)
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::shooting_end)
    subaction*(board) board.shared_actions.resolve_timing_window
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    for i in range(board.units.size()):
        board[i].history.ingress_locked = false
    board.begin_phase(BattlePhase::charge)
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::charge_start)
    subaction*(board) board.shared_actions.resolve_timing_window
    subaction*(board) charge_phase = charge_phase(board)
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::charge_end)
    subaction*(board) board.shared_actions.resolve_timing_window
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.begin_phase(BattlePhase::fight)
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::fight_start)
    subaction*(board) board.shared_actions.resolve_timing_window
    subaction*(board) fight_phase = fight_phase(board)
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::fight_end)
    subaction*(board) board.shared_actions.resolve_timing_window
    retained_cleanup = cleanup_phase_retained(board)
    subaction*(board) retained_cleanup
    board.clear_phase_modifiers()
    board.timing.phase = BattlePhase::none
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::turn_end)
    subaction*(board) board.shared_actions.resolve_timing_window
    return_opponent_aircraft(board)
    board.current_decision_maker = board.current_player

# Round start precedes both turns; round end follows both (p.28). The current
# player resolves their group first per the user's sequencing definition.
act round(ctx Board board) -> Round:
    # Infrastructure: round windows run sequentially (p28); effects/history
    # remain in Board after their completed child frame is reused.
    board.current_player = board.starting_player
    board.timing.active_player = board.starting_player
    board.obtained_extra_cp_this_round[0] = false
    board.obtained_extra_cp_this_round[1] = false
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::round_start)
    subaction*(board) board.shared_actions.resolve_timing_window
    frm player_turn = turn(board, board.starting_player)
    subaction*(board) player_turn
    player_turn = turn(board, !board.starting_player)
    subaction*(board) player_turn
    board.current_player = board.starting_player
    board.timing.active_player = board.starting_player
    board.shared_actions.resolve_timing_window = resolve_timing_window(board, TimingWindow::round_end)
    subaction*(board) board.shared_actions.resolve_timing_window
    expire_unused_reserves(board)

# Muster attachments use explicit Leader/Support permissions and separate
# role slots (p.66). Source comes first in the two-UnitID editor payload; both
# indices address reserves and are supplied by named choice-panel buttons.
act attach_leaders(ctx Board board) -> AttachLeaderStep:
    frm previous_owner = board.current_decision_maker
    frm attachment_player = board.starting_player
    frm passed_players : Bool[2]
    while !passed_players[0] or !passed_players[1]:
        board.current_decision_maker = attachment_player
        actions:
            act done_attaching()
                passed_players[int(attachment_player)] = true
            act attach_unit(frm UnitID attach_source, frm UnitID attach_target) {attachment_valid(board, attach_source, attach_target, attachment_player)}
                attach_reserved_unit(board, attach_source, attach_target, attachment_player)
        if !passed_players[int(!attachment_player)]:
            attachment_player = !attachment_player
    board.current_decision_maker = previous_owner

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
fun surge(Board board, UnitID source, StatModifier distance, Bool triggered) -> GrantedMove:
    let permitted = triggered and source.get() < board.units.size() and has_live_model(board[source]) and !board[source].battle_socked and !board.is_in_melee(board[source]) and board[source].history.last_move_phase != board.phase_serial.value + 1 and !board[source].history.ingress_locked and has_surge_target(board, source)
    return granted_move(board, source, distance, MovementKind::surge, false, permitted)

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
                    board.shared_actions.move = move(board, scout, distance)
                    subaction*(board, scout) board.shared_actions.move
                    frm scout_move_completed_snapshot_1 = board.shared_actions.move.completed
                    if scout_move_completed_snapshot_1:
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
    register_faction_force_dispositions(board)
    assert(muster_copies_valid(board), "muster exceeds unit copy limits")
    subaction*(board) faction_formations = faction_prebattle_formations(board)
    subaction*(board) attach_leaders = attach_leaders(board)
    board.capture_starting_strengths()
    register_faction_option_passives(board)
    register_faction_force_dispositions(board)
    register_faction_passive_rules(board)
    register_faction_datasheet_sources(board)
    subaction*(board) transport_formations = declare_transport_passengers(board)
    subaction*(board) reserves = declare_strategic_reserves(board)
    subaction*(board) deploy = deploy(board)
    subaction*(board) redeploy = faction_prebattle_redeploy(board)
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

# Host presentation only: source labels are finite state; allocate their text
# when Godot displays the current choice, never during effect registration.
fun<T> pretty_string(Board b, T obj) -> String:
    if obj is GamePickMorgrimButcha:
        return "Orks (current units)"s
    if obj is GameChooseSourceEvent:
        if obj.event.value < b.active_source_events.size():
            return source_label_text(b.source_instances[b.active_source_events[obj.event.value].source.value].label.value)
    if obj is GameChooseMovementSource:
        if obj.event.value < b.active_source_events.size():
            return source_label_text(b.source_instances[b.active_source_events[obj.event.value].source.value].label.value)
    if obj is GameChooseWindowSource:
        if obj.event.value < b.active_source_events.size():
            return source_label_text(b.source_instances[b.active_source_events[obj.event.value].source.value].label.value)
    if obj is GameSelectWeapon:
        if !(b.get_current_attacking_model().weapons.size() > obj.weapon_id.value):
            return to_string(obj)
        return to_string(b.get_current_attacking_model().weapons[obj.weapon_id.value].profile)
    if obj is GameChooseAttackWeapon:
        if obj.weapon.value < b.attack.declarations.size():
            return to_string(b.attack.declarations[obj.weapon.value].weapon)
    return to_string(obj)

# Child alternatives are initialized before single-step forwarding. The selected
# child then completes atomically before the outer controller offers siblings.
# One core timing alternative; common sequencing remains outside faction resolution (core pp28-30; user Rules Sequencing).
act core_timing_choice(ctx Board board, ctx CoreTimingProgress core_progress, ctx FactionTimingProgress progress, ctx PendingSourceEvents pending, frm TimingWindow window, frm Bool player) -> CoreTimingChoice:
    frm started = false
    frm finished = false
    actions:
        act finish_timing_rules() {(!(window == TimingWindow::turn_end) or !has_incoherent_units(board, player)) and !source_events_remaining(board, pending, player, true) and !faction_timing_options_remaining(board, window, player, progress, true)}
            started = true
            finished = true
        act choose_window_source(frm SourceEventID event) {pending_source_valid(board, pending, event, player)}
            started = true
            subaction*(board, pending) chosen_window_effect = faction_resolve_timing_source(board, pending, event, player)
        act choose_timing_rule(frm TimingRule rule) {
            !core_progress.resolved[int(rule.value)],
            timing_rule_available(board, window, player, rule)
        }
            started = true
            core_progress.resolved[int(rule.value)] = true
            if rule == TimingRule::regain_coherency:
                board.shared_actions.regain_coherency = regain_coherency(board, player)
                subaction*(board) board.shared_actions.regain_coherency
            if rule == TimingRule::rapid_ingress:
                board.shared_actions.timing_rapid_ingress = timing_rapid_ingress(board, player)
                subaction*(board) board.shared_actions.timing_rapid_ingress
            if rule == TimingRule::fire_overwatch:
                board.shared_actions.timing_overwatch = timing_overwatch(board, player)
                subaction*(board) board.shared_actions.timing_overwatch
            if rule == TimingRule::shadow_in_the_warp:
                board.shared_actions.shadow_in_the_warp = shadow_in_the_warp(board, player)
                subaction*(board) board.shared_actions.shadow_in_the_warp
            if rule == TimingRule::neural_disruption:
                board.shared_actions.neural_disruption = neural_disruption(board)
                subaction*(board) board.shared_actions.neural_disruption
            if rule == TimingRule::oath_of_moment:
                board.shared_actions.timing_oath_of_moment = timing_oath_of_moment(board)
                subaction*(board) board.shared_actions.timing_oath_of_moment
            if rule == TimingRule::heroic_intervention:
                board.shared_actions.timing_heroic_intervention = timing_heroic_intervention(board, player)
                subaction*(board) board.shared_actions.timing_heroic_intervention
            if rule == TimingRule::smokescreen:
                board.shared_actions.timing_smokescreen = timing_smokescreen(board, player)
                subaction*(board) board.shared_actions.timing_smokescreen
            if rule == TimingRule::objective_stratagem:
                board.shared_actions.timing_objective_stratagem = timing_objective_stratagem(board)
                subaction*(board) board.shared_actions.timing_objective_stratagem
            board.current_decision_maker = player

# One common movement_phase choice, preserving its original core legality/effects (core Movement/Shooting phase).
act core_movement_phase_choice(ctx Board board) -> CoreMovementPhaseChoice:
    frm started = false
    frm finished = false
    actions:
        act select_disembarking_unit(frm UnitID disembark_passenger) {ordinary_disembark_valid(board, disembark_passenger)}
            started = true
            board.shared_actions.disembark = disembark(board, disembark_passenger, false)
            subaction*(board) board.shared_actions.disembark
            frm disembark_completed = board.shared_actions.disembark.completed
            frm disembark_mode_snapshot = board.shared_actions.disembark.mode
            frm disembark_slot_snapshot = board.shared_actions.disembark.passenger_slot
            if disembark_completed and disembark_mode_snapshot == DisembarkMode::tactical and !board[disembark_slot_snapshot].empty():
                board.shared_actions.movement = movement(board, disembark_slot_snapshot, false)
                subaction*(board) board.shared_actions.movement
        act end_move() {movement_selection_complete(board, board.current_player)}
            started = true
            finished = true
        act move_unit(frm UnitID id) {id.get() < board.units.size(), has_live_model(board[id]), !board[id].off_battlefield, !board[id].has_keyword(Keyword::aircraft), board[id].owned_by_player1 == board.current_player, board[id].history.selected_move_phase != board.phase_serial.value + 1}
            started = true
            frm use_gilded_spear = false
            # Preserve this legacy supplied-roster hook without inventing
            # new faction authority; exact faction replacement is task 17.
            if board.get_current_player_faction() == Faction::tristraen_gilded_blade and board.can_target_strat(board.current_player, Stratagem::the_gilded_spear, board[id]):
                act use_gilded_spear(Bool do_it)
                use_gilded_spear = do_it
                if do_it:
                    board.commit_stratagem(board.current_player, Stratagem::the_gilded_spear, board[id])
            board.shared_actions.movement = movement(board, id, use_gilded_spear)
            subaction*(board) board.shared_actions.movement
        act select_reserve_unit(frm UnitID reserve_id) {reserve_id.get() < board.reserve_units.size(), has_live_model(board.reserve_units[reserve_id.get()]), board.reserve_units[reserve_id.get()].owned_by_player1 == board.current_player, board.reserve_units[reserve_id.get()].history.selected_move_phase != board.phase_serial.value + 1}
            started = true
            actions:
                act skip()
                # pp.32/69/74: a reserve Aircraft may defer ingress,
                # including round one, without making a Stationary move.
                act defer_aircraft_ingress() {board.reserve_units[reserve_id.get()].has_keyword(Keyword::aircraft)}
                    board.reserve_units[reserve_id.get()].history.selected_move_phase = board.phase_serial.value + 1
                act reserve_remain_stationary() {!board.reserve_units[reserve_id.get()].has_keyword(Keyword::aircraft)}
                    board.reserve_units[reserve_id.get()].history.selected_move_phase = board.phase_serial.value + 1
                    board.reserve_units[reserve_id.get()].history.move_kind = MovementKind::stationary
                act place_at(BoardPosition position) {faction_ingress_round_allowed(board, board.reserve_units[reserve_id.get()]), battlefield_entry_available(board, board.reserve_units[reserve_id.get()]), setup_at_valid(board, board.reserve_units[reserve_id.get()], position, MovementKind::ingress, false)}
                    enter_from_reserves(board, reserve_id, position, MovementKind::ingress)

# One common shooting_phase choice, preserving its original core legality/effects (core Movement/Shooting phase).
act core_shooting_phase_choice(ctx Board board) -> CoreShootingPhaseChoice:
    frm started = false
    frm finished = false
    actions:
        act end_shooting_phase()
            started = true
            finished = true
        act use_explosives(frm UnitID explosives_source) {explosives_source_valid(board, explosives_source)}
            started = true
            subaction*(board) explosives = resolve_explosives(board, explosives_source)
        act select_shooting_unit(frm UnitID shooting_unit) {shooting_unit_valid(board, shooting_unit)}
            started = true
            board.shared_actions.selected_shooting = selected_shooting(board, shooting_unit, shooting_unit)
            subaction*(board) board.shared_actions.selected_shooting
        act select_target(frm UnitID source, frm UnitID target) {
            shooting_unit_valid(board, source),
            target.get() < board.units.size(),
            has_live_attack_recipient(board[target]),
            board[target].owned_by_player1 != board.current_player,
            unit_visible_to_unit(board, board[source], board[target]) or shooting_kind_valid(board, source, ShootingKind::indirect)
        }
            started = true
            board.shared_actions.selected_shooting = selected_shooting(board, source, target)
            subaction*(board) board.shared_actions.selected_shooting

# One common Crushing Impact choice alongside faction charge effects (core p55; user Rules Sequencing).
act core_charge_choice(ctx Board board, ctx FactionChargeProgress progress, ctx Bool crushing_pending, frm UnitID source) -> CoreChargeChoice:
    frm started = false
    actions:
        act decline_crushing_impact() {crushing_pending}
            started = true
            crushing_pending = false
        act crushing_impact() {crushing_pending, crushing_source_valid(board, source)}
            started = true
            crushing_pending = false
            board.shared_actions.resolve_crushing_impact = resolve_crushing_impact(board, source)
            subaction*(board) board.shared_actions.resolve_crushing_impact

# Ordinary move selection and Advance/Fall Back core procedure, with source hooks at their original boundaries (core p33).
act core_move_kind_choice(ctx Board board, frm UnitID id, frm Bool use_the_gilded_spear) -> CoreMoveKindChoice:
    frm started = false
    frm kind : MovementKind
    frm extra : StatModifier
    actions:
        act remain_stationary() {battlefield_move_eligible(board, id, MovementKind::stationary)}
            started = true
            record_move(board, id, MovementKind::stationary)
        act normal_move() {battlefield_move_eligible(board, id, MovementKind::normal)}
            started = true
            kind = MovementKind::normal
            extra = 2 * int(use_the_gilded_spear)
        act advance(Bool do_it) {battlefield_move_eligible(board, id, MovementKind::advance)}
            started = true
            kind = MovementKind::normal
            extra = 2 * int(use_the_gilded_spear)
            if do_it:
                kind = MovementKind::advance
                board.shared_actions.faction_move_mode = faction_move_mode(board, id, kind)
                subaction*(board) board.shared_actions.faction_move_mode
                capture_advance_charge_permission(board, id)
                subaction*(board) advance_selection = faction_prepare_advance(board, id)
                frm advance_roll_effects : AdvanceRollEffects
                append_advance_roll_effects(board, board[id], advance_roll_effects)
                board.current_roll = rerollable_dice_roll(board, advance_roll_effects.reroll, false, true, board[id].owned_by_player1, id)
                subaction*(board) board.current_roll
                subaction*(board) advance_result = faction_modify_advance_roll(board, id)
                advance_roll_effects.modifiers.clear()
                append_advance_roll_effects(board, board[id], advance_roll_effects)
                extra = modified_dice_result(board.current_roll.result.value, advance_roll_effects.modifiers, false, false)
                capture_faction_selected_move(board, id, kind)
        act ordered_retreat() {battlefield_move_eligible(board, id, MovementKind::ordered_retreat)}
            started = true
            kind = MovementKind::ordered_retreat
            capture_faction_selected_move(board, id, kind)
        act desperate_escape() {battlefield_move_eligible(board, id, MovementKind::desperate_escape)}
            started = true
            kind = MovementKind::desperate_escape
            capture_faction_selected_move(board, id, kind)
