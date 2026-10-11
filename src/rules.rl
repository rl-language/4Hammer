import action
import bounded_arg
import string
import learn
import vector2d
import stats
import board
import movement_geometry
import terrain_rules

# Calculates the required roll to wound given a particular game state,
# that is, the calculation includes situational condition like the usage
# of a lance weapon, instead of only considering strenght and toughness
fun required_wound_roll(Board board, AttackSequenceInfo info) -> Int:

    let strenght = info.source.strenght()
    let thoughness = info.target_toughness.value
    let modifiers = info.total_wound_modifier() 
    if thoughness < strenght and info.greater_strenght_wound_protection:
        modifiers = modifiers + 1
    if info.has_weapon_rule(board, WeaponRuleKind::lance) and board[info.source_unit_id].has_charged:
        modifiers = modifiers + 1

    let clamped_modifier = 0
    if modifiers > 0:
        clamped_modifier = 1
    if 0 > modifiers:
        clamped_modifier = -1
 
    if strenght == thoughness:
        return 4 + clamped_modifier

    if strenght * 2 <= thoughness:
        return 6 + clamped_modifier
    
    if strenght < thoughness:
        return 5 + clamped_modifier

    if strenght >= thoughness * 2:
        return 2 + clamped_modifier
    
    if strenght > thoughness:
        return 3 + clamped_modifier

    return 0


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

fun get_hit_roll_bonus(Board board) -> Int:
    let sum = board.attack_info.total_hit_modifier() 
    if board.attack_info.has_weapon_rule(board, WeaponRuleKind::heavy) and board[board.attack_info.source_unit_id].has_moved:
        sum = sum + 1
    if sum >= 1:
        return 1
    if sum <= -1:
        return -1
    return 0

# Evaulates a single attack from a given model to a target unit
# A single attack can generate multiple hits, for example because
# of rules such as sutained_hits. 
# If the target is destroyed, this action triggers eventual on death
# mechanics.
# Hold generated hit/wound/damage counters across dice decisions
# (attack sequence pp.18–19). The new-edition pipeline remains tasks 9/10.
act single_attack(ctx Board board, ctx Unit target, ctx Unit source_unit) -> SingleAttack:
    # Invoking a real ranged attack, even one that misses, breaks Hidden for
    # this and the following turn (p.50). Merely selecting/skipping does not.
    if board.attack_info.source.range() > 0:
        board.record_ranged_attacks(board.attack_info.source_unit_id)
    frm generated_hits : CombatCounter
    frm generated_wounds : CombatCounter
    frm generated_effective_wounds : CombatCounter

    # autohit attacks
    if board.attack_info.source.skill() == 0:
        generated_hits = 1
    else:
        board.current_state = CurrentStateDescription::hit_roll
        board.current_roll = rerollable_dice_roll(board,
                                                  board.attack_info.reroll_hits, 
                                                  board.attack_info.reroll1_hits, 
                                                  true, 
                                                  bool(source_unit.owner_id()), board.attack_info.source_unit_id)
        subaction*(board) board.current_roll
        let roll_modifiers = get_hit_roll_bonus(board)
        if !attack_hit_roll_succeeds(board.current_roll.result, roll_modifiers, effective_attack_skill(board, board.attack_info)):
            board.current_state = CurrentStateDescription::none
            return
        # sixes trigger a explosive hits
        if board.current_roll.result == 6:
           generated_hits = generated_hits + board.attack_info.max_weapon_parameter(board, WeaponRuleKind::sustained_hit) 
        if board.attack_info.has_weapon_rule(board, WeaponRuleKind::letal_hits):
            generated_wounds = generated_wounds + 1
        else:
            generated_hits = generated_hits + 1

    while generated_hits != 0:
        generated_hits = generated_hits - 1
        board.current_state = CurrentStateDescription::wound_roll
        board.current_roll = rerollable_dice_roll(board, board.attack_info.reroll_wounds, board.attack_info.reroll1_wounds, true, bool(source_unit.owner_id()), board.attack_info.source_unit_id)
        subaction*(board) board.current_roll

        if board.current_roll.result < required_wound_roll(board, board.attack_info) or board.current_roll.result == 1:
            continue


        if board.current_roll.result == 6 and board.attack_info.source.has_rule(WeaponRuleKind::devastating_wounds):
            board.current_state = CurrentStateDescription::damage_roll
            let extra_damage = 0 
            if board.attack_info.has_weapon_rule(board, WeaponRuleKind::melta) and source_unit.distance(target) < 12.0:
                extra_damage = board.attack_info.max_weapon_parameter(board, WeaponRuleKind::melta)
                
            subaction* devastating_damage_roll = evaluate_random_stat(board.attack_info.source.damage())
            generated_effective_wounds = generated_effective_wounds + devastating_damage_roll.result.value
        else:
            generated_wounds = generated_wounds + 1 

    if generated_wounds == 0 and generated_effective_wounds == 0:
        board.current_state = CurrentStateDescription::none
        return

    frm previous_decision_maker = board.current_decision_maker
    if board.attack_info.source.has_rule(WeaponRuleKind::precision):
        board.current_decision_maker = !target.owned_by_player1
    else:
        board.current_decision_maker = target.owned_by_player1
    board.current_state = CurrentStateDescription::allocate_wound

    # Elects which model to allocate a suffered wounds too
    act allocate_wound(frm ModelID id) {
        id.get() < target.models.size(),
        !(target[id].state == ModelState::fight_on_death),
        board.attack_info.source.has_rule(WeaponRuleKind::precision) or !target[id.get()].has_keyword(Keyword::character) or target.all_have_keyword(Keyword::character)
    }
    board.current_decision_maker = previous_decision_maker
        
    while generated_wounds != 0:
        generated_wounds = generated_wounds - 1

        board.current_roll = rerollable_dice_roll(board, false, false, true, bool(target.owner_id()), board.attack_info.target_unit_id)
        board.current_state = CurrentStateDescription::save_roll
        subaction*(board) board.current_roll 
        ref target_model = target.models[id.get()]
        let best_save = min(target_model.profile.save() + board.attack_info.source.penetration() + int(board.attack_info.penetration_bonus), target_model.profile.invuln_save())
        if board.current_roll.result >= best_save:
            continue
        board.current_state = CurrentStateDescription::damage_roll
        subaction* damage_roll = evaluate_random_stat(board.attack_info.source.damage())
        generated_effective_wounds = generated_effective_wounds + damage_roll.result.value

    frm target_model = target[id]
    if target.damage(id.get(), generated_effective_wounds.value, board.attack_info.fight_on_death):
        subaction*(board, source_unit, target_model) on_model_destroyed = on_model_destroyed(board, source_unit, target_model)
    board.current_state = CurrentStateDescription::none

# Dispatch existing on-destruction abilities/stratagems after a casualty (core p.19).
# Feeder Tendrils checks the destroyed model, not the attacker; its faction
# definition is not in the supplied core book and still requires faction-source review.
act on_model_destroyed(ctx Board board, 
                       ctx Unit source, 
                       ctx Model destroyed) -> OnModelDestroyed:
    if destroyed.is_character() and source.has_ability(AbilityKind::feeder_tendrils):
        board.add_extra_cp(int(source.owned_by_player1))

    frm previous_owner = board.current_decision_maker
    if destroyed.has_keyword(Keyword::master_of_possession) and board.can_use_strat(!source.owned_by_player1, Stratagem::violent_unbidding):
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
                    source.deal_mortal_wound_damage(3)
                if dice == 5:
                    act roll(frm Dice damage)
                    source.deal_mortal_wound_damage(damage.value / 2)

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
    current_model = current_model.get() + 1

fun _configure_attack(Board board, Int source, Int target, Bool overwatch, Bool melee):
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
                board[source].deal_mortal_wound_damage(board.current_roll.result.value)
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
            board[source].damage(model.get(), 1)
            board.attack_info.profile_hit_roll_bonus.append(Profile::aranis_zarkan)
            board.attack_info.profile_wound_roll_bonus.append(Profile::aranis_zarkan)

        if board.players_faction[int(!target_player)] == Faction::tristraen_gilded_blade:

            actions:
                act use_dacatarai_stance() 
                board.attack_info.add_sustained_hits(1)
                act use_rendax_stance()             
                board.attack_info.add_letal_hits()



# One of the most important sequences of the game,
# it handles a full melee, ranged or overwatch attack 
# from a given target to a given source, including
# the activation of stratagems, the resolution of 
# dangerous weapons, fight on death, and so on.
# Retain unit/model attack iteration and Hazardous-use storage across actions
# (attacks pp.16–23; Hazardous p.81). Group declarations remain task 9.
# Selected shooting/fighting units temporarily own the active role (p.8);
# restore the calling roles after attacks and the legacy fight-on-death path.
act attack(ctx Board board, 
           frm UnitID source, 
           frm UnitID target, 
           frm Bool melee, 
           frm Bool overwatch) -> Attack:
    if board[source].models.size() == 0:
        return
    if board[target].models.size() == 0:
        return

    frm previous_owner = board.current_decision_maker
    frm previous_active = board.timing.active_player
    board.timing.active_player = board[source].owned_by_player1
    _configure_attack(board, source.get(), target.get(), overwatch, melee)

    subaction*(board) strats = use_attack_stratagems(board, source, target, melee)

    frm model : ModelIterator
    frm hazardous_uses : HazardousUses
    board.current_decision_maker = board[source].owned_by_player1
    while model != board[source].models.size() and !board[target].models.empty():
        let id : ModelID
        id = model.value
        subaction*(board) model_attack = resolve_model_attack(board, source, target, id, melee)
        hazardous_uses = hazardous_uses + model_attack.hazardous_uses
        model = model + 1


    ### Dangerous weapons
    board.attack_info.target_unit_id = source
    board.current_decision_maker = board[source].owned_by_player1
    while hazardous_uses != 0 and !board[source].empty():
        hazardous_uses = hazardous_uses - 1
        board.current_state = CurrentStateDescription::hazardous_roll
        board.current_roll = rerollable_dice_roll(board, false, false, true, bool(board[source].owner_id()), source)
        subaction*(board) board.current_roll
        if board.current_roll.result != 1:
            continue
        # select a model to damage because of a hazardous roll
        act select_model(ModelID model) {
            model.get() < board[source].models.size(),
            board[source][model.get()].has_weapon_rule(WeaponRuleKind::hazardous)
        }
        # ToDo: handle non character version
        board[source].damage(model.get(), 3)
    board.current_state = CurrentStateDescription::none
    
    ### fight on death
    _configure_attack(board, target.get(), source.get(), overwatch, melee)
    board.current_decision_maker = board[target].owned_by_player1
    board.timing.active_player = board[target].owned_by_player1
    model = 0
    while model != board[target].models.size() and !board[source].models.empty():
        if board[target][model.value].state == ModelState::fight_on_death:
            if board.attack_info.fight_on_death_roll != 2:
                # 2+ fight on death dice roll
                act roll(Dice result)
                if result < board.attack_info.fight_on_death_roll:
                   continue 
            let id : ModelID
            id = model.value
            subaction*(board) fight_on_death_attack = resolve_model_attack(board, target, source, id, melee)
        model = model + 1
    board[target].remove_figth_on_death_models()
    board.timing.active_player = previous_active
    board.current_decision_maker = previous_owner
        


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
        act ingress_at(BoardPosition position) {
            board.least_distance_from_player_units(position, !player) > 9.0,
            board.is_position_valid_for_reserve(position, board.reserve_units[reserve.get()]),
            setup_candidate_valid(board, board.reserve_units[reserve.get()], position)
        }
            board.units.append(board.reserve_units[reserve.get()])
            board.units.back().mark_set_up()
            board.units.back().try_arrange_at(position)
            board.units.back().has_moved = true
            board.reserve_units.erase(reserve.get())

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
        !board[target].empty(),
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
                !board[source].empty(),
                !used[source.get()],
                board[source].owned_by_player1 == board.current_player,
                board[source].has_ability(AbilityKind::neural_disruption),
                target.get() < board.units.size(),
                !board[target].empty(),
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
            !board[source].empty(),
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
# independent-model selection and full movement-mode timing remain task 11.
# A selected mover owns the active role until its move ends (p.8).
act move(ctx Board board, ctx UnitID unit, frm StatModifier additional_movement) -> Move:
    if board[unit.get()].models.size() == 0:
        return
    frm previous_owner = board.current_decision_maker
    frm previous_active = board.timing.active_player
    board.current_decision_maker = board[unit].owned_by_player1
    board.timing.active_player = board[unit].owned_by_player1
    # An impossible/cancelled move leaves positions unchanged rather than
    # trapping the game in a decision with no legal destinations (p.12).
    # Full Fall Back/path choice permissions are still task 11.
    actions:
        act skip()
        act move_to(BoardPosition position) {
            can_translate_unit(board, unit, position, additional_movement.value)
        }
            try_translate_unit(board, unit, position, additional_movement.value)
    board.timing.active_player = previous_active
    board.current_decision_maker = previous_owner

# Convert an internal movement increment to its bounded state domain
# so a full D6 Advance fits (p.33); the bound also drives inferred ML layout.
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
                !board[source].empty(),
                target.get() < board.units.size(),
                !board[target].empty(),
                !board[target.get()].empty(),
                !board[source.get()].empty(),
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
                !board[target].empty(),
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
                !board[source].empty(),
                target.get() < board.units.size(),
                !board[target].empty(),
                !board[target.get()].empty(),
                !board[source.get()].empty(),
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

# core rules reserve deployment 
# Preserve setup history when a reserve unit transfers to the battlefield
# (reserves/setup pp.68–71); placement/timing updates remain task 11.
act reserve_deployment(ctx Board board, frm Bool current_player) -> ReserveDeployment:
    frm done_deploying = false
    board.current_decision_maker = current_player 
    actions:
        act nothing_to_deploy()
            done_deploying = true
        act select_reserve_unit(frm UnitID id){
            id.get() < board.reserve_units.size(),
            board.reserve_units[id.get()].owned_by_player1 == current_player
        }
            # Failed/cancelled setup retains the reserve unit (p.14).
            actions:
                act skip()
                act place_at(BoardPosition position) {
                    board.least_distance_from_player_units(position, !current_player) > 9.0,
                    board.is_position_valid_for_reserve(position, board.reserve_units[id.get()]),
                    setup_candidate_valid(board, board.reserve_units[id.get()], position)
                }
                board.units.append(board.reserve_units[id.get()])
                board.units.back().mark_set_up()
                board.units.back().try_arrange_at(position)
                board.units.back().has_moved = true
                board.reserve_units.erase(id.get())
                act nothing_to_deploy()
                    done_deploying = true

# core rules desperate escape 
# Route casualties through the identity/history archive rather than bare erase
# (Desperate Escape p.33; destroyed/returning models pp.19/88). Mode rules are task 11.
act desperate_escape(ctx Board board, frm UnitID id) -> DesperateEscapeTest:
    if !board[id].battle_socked:
        return

    if board.faction_of_unit(id) == Faction::insidious_infiltrators and board.can_target_strat(board[id].owned_by_player1, Stratagem::predators_not_prey, board[id]):
        act use_predators_not_prey(Bool do_it)
        if do_it:
            board.commit_stratagem(board[id].owned_by_player1, Stratagem::predators_not_prey, board[id])
            return

    frm i : UnitIterator
    i = board[id].models.size()
    while i != 0:
        board.current_roll = rerollable_dice_roll(board, false, false, false, board[id].owned_by_player1)
        subaction*(board) board.current_roll
        if board.current_roll.result == 1:
            board[id].remove_model(i.value - 1)
        i = i - 1

# movement of a single unit, including possibly advancing and falling back 
act movement(ctx Board board, frm UnitID id, frm Bool use_the_gilded_spear) -> Movement:
    frm player_move : Move
    if board.is_in_melee(board[id]):
        subaction*(board) desperate_escape = desperate_escape(board, id)
        board[id].has_moved = true
        board[id].can_shoot = false
        board[id].can_charge = false
        player_move = move(board, id, 0)
        subaction*(board, id) player_move 
        return
    act advance(Bool do_it)
    if !do_it:
        board[id.get()].has_moved = true
        player_move = move(board, id, 2*int(use_the_gilded_spear))
        subaction*(board, id) player_move 
    else:
        board[id.get()].has_moved = true
        board[id.get()].has_run = true
        board.current_roll = rerollable_dice_roll(board, false, false, true, board[id].owned_by_player1, id)
        subaction*(board) board.current_roll
        player_move = move(board, id, board.current_roll.result.value)
        subaction*(board, id) player_move 

# core rules movement phase
# Exclude empty retired slots from movement decisions (destruction p.19;
# movement pp.32–33). Exact modes/stratagem windows remain tasks 11/15.
act movement_phase(ctx Board board) -> MovementPhase:
    board.current_decision_maker = board.current_player 
    while true:
        actions:
            act end_move()
                break
            act move_unit(frm UnitID id) {
                id.get() < board.units.size(),
                !board[id].empty(),
                board[id].owned_by_player1 == board.current_player,
                !board[id].has_moved
            }

                # stratagems
                frm use_gilded_spear : Bool
                if board.get_current_player_faction() == Faction::tristraen_gilded_blade and board.can_target_strat(board.current_player, Stratagem::the_gilded_spear, board[id]):
                    act use_gilded_spear(Bool do_it)
                    use_gilded_spear = do_it
                    if do_it:
                        board.commit_stratagem(board.current_player, Stratagem::the_gilded_spear, board[id])
       
                # move
                subaction*(board) move = movement(board, id, use_gilded_spear)

    board.current_decision_maker = board.current_player 
    # reserve managment
    while true:
        subaction*(board) reserve_deployment = reserve_deployment(board, board.current_player)
        if reserve_deployment.done_deploying:
            break

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
                !board[source].empty(),
                target.get() < board.units.size(),
                !board[target].empty(),
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

fun deployment_position_valid(Board board, BoardPosition position, Bool current_player, Bool infiltrates) -> Bool:
    if infiltrates:
        if board.least_distance_from_player_units(position, !current_player) < 9.0:
            return false
        if current_player:
            return position.y <= 18
        else:
            return position.y >= BOARD_HEIGHT - 18

    if current_player:
        return position.y <= 5
    else:
        return position.y >= BOARD_HEIGHT - 5

# the core rules sequence where players
# alterante deploying units in a valid position 
act deploy(ctx Board board) -> Deployment:
    board.current_decision_maker = board.starting_player
    frm passed_players = [false, false]
    while !passed_players[0] or !passed_players[1]:
        actions: 
            act done_deploying()
                passed_players[int(board.current_decision_maker)] = true
                board.current_decision_maker = !board.current_decision_maker
            act select_unit(frm UnitID unit_id) {
                unit_id.get() < board.reserve_units.size(),
                board.reserve_units[unit_id.get()].owned_by_player1 == board.current_decision_maker 
            }
                frm infiltrates = board.reserve_units[unit_id.get()].has_ability(AbilityKind::infiltrators)
                # Setup failure/cancellation must leave the unit in its original
                # location and allow a later attempt, not stall the action (p.14).
                actions:
                    act skip()
                    act deploy_at(BoardPosition position) {
                        deployment_position_valid(board, position, board.current_decision_maker, infiltrates),
                        setup_candidate_valid(board, board.reserve_units[unit_id.get()], position)
                    }
                        board.units.append(board.reserve_units[unit_id.get()])
                        board.reserve_units.erase(unit_id.get())
                        board.units.back().mark_set_up()
                        board.units.back().try_arrange_at(position)
                        if !passed_players[int(!board.current_decision_maker)]:
                            board.current_decision_maker = !board.current_decision_maker
        

# a 5 rounds battle, inlcuding deployment. 
# Initialize identities before attachments and freeze combined starting counts
# afterward (Leader/Support pp.66–67; starting strength p.86).
act battle(ctx Board board) -> Battle:
    board.identify_units()
    subaction*(board) attach_leaders = attach_leaders(board)
    board.capture_starting_strengths()
    subaction*(board) deploy = deploy(board)
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
