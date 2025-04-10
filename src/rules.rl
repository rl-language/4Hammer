import action
import bounded_arg
import string
import learn
import vector2d
import stats
import board

fun required_wound_roll(Board board, AttackSequenceInfo info) -> Int:

    let strenght = info.source.strenght()
    let thoughness = info.target_toughness
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

    if strenght * 2 < thoughness:
        return 6 + clamped_modifier
    
    if strenght < thoughness:
        return 5 + clamped_modifier

    if strenght > thoughness * 2:
        return 2 + clamped_modifier
    
    if strenght > thoughness:
        return 3 + clamped_modifier

    return 0

act evaluate_random_stat(frm Stat stat, frm Int fixed_extra) -> RollStat:
    frm result = 0

    if stat is Int:
        result = stat + fixed_extra
        return

    if stat is Dice:
        frm max_quantity = stat.value
        act quantity(Dice dice) {
            dice.value <= max_quantity
        }
        result = dice.value + fixed_extra

act rerollable_pair_dices_roll(ctx Board board, frm Bool reroll, frm Bool reroll_1s, frm Bool cp_rerollable, frm Int current_player) -> RerollableDicePair:
    act roll_pair(frm Dice result, frm Dice result2)
    frm is_non_cp_rerollable = reroll or (reroll_1s and result == 1)
    let is_cp_rerollable = cp_rerollable and board.can_use_strat(bool(current_player), Stratagem::reroll)
    if is_non_cp_rerollable or is_cp_rerollable:
        frm original_decision_maker = board.current_decision_maker
        board.current_decision_maker = bool(current_player)
        act keep_it(Bool do_it)
        board.current_decision_maker = original_decision_maker 
        if do_it:
            return
        act reroll_pair(Dice new_value, Dice new_value2)
        if !is_non_cp_rerollable: 
            board.command_points[current_player] = board.command_points[current_player] - 1
            board.mark_strat_used(Stratagem::reroll, current_player)
        result = new_value
        result2 = new_value2
        return

act rerollable_dice_roll(ctx Board board, frm Bool reroll, frm Bool reroll_1s, frm Bool cp_rerollable, frm Int current_player) -> RerollableDice:
    act roll(frm Dice result)
    frm is_non_cp_rerollable = reroll or (reroll_1s and result == 1)
    let is_cp_rerollable = cp_rerollable and board.can_use_strat(bool(current_player), Stratagem::reroll)
    if is_non_cp_rerollable or is_cp_rerollable:
        act keep_it(Bool do_it)
        if do_it:
            return
        act reroll(Dice new_value)
        if !is_non_cp_rerollable: 
            board.command_points[current_player] = board.command_points[current_player] - 1
            board.mark_strat_used(Stratagem::reroll, current_player)
        result = new_value
        return

fun get_hit_roll_bonus(Board board) -> Int:
    let sum = board.attack_info.total_hit_modifier() 
    #board[board.attack_info.source_unit_id].
    if board.attack_info.has_weapon_rule(board, WeaponRuleKind::heavy) and board[board.attack_info.source_unit_id].has_moved:
        sum = sum + 1
    if sum >= 1:
        return 1
    if sum <= -1:
        return -1
    return 0

act single_attack(ctx Board board, ctx Unit target, ctx Unit source_unit) -> SingleAttack:
    frm generated_hits = 0
    frm generated_wounds = 0
    frm generated_effective_wounds = 0

    # autohit attacks
    if board.attack_info.source.skill() == 0:
        generated_hits = 1
    else:
        board.current_state = CurrentStateDescription::hit_roll
        board.current_roll = rerollable_dice_roll(board, board.attack_info.reroll_hits, board.attack_info.reroll1_hits, true, source_unit.owner_id())
        subaction*(board) board.current_roll
        let roll_modifiers = get_hit_roll_bonus(board)
        if board.current_roll.result + roll_modifiers < board.attack_info.source.skill() or board.current_roll.result == 1:
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
        board.current_roll = rerollable_dice_roll(board, board.attack_info.reroll_wounds, board.attack_info.reroll1_wounds, true, source_unit.owner_id())
        subaction*(board) board.current_roll

        if board.current_roll.result < required_wound_roll(board, board.attack_info) or board.current_roll.result == 1:
            continue


        if board.current_roll.result == 6 and board.attack_info.source.has_rule(WeaponRuleKind::devastating_wounds):
            board.current_state = CurrentStateDescription::damage_roll
            let extra_damage = 0 
            if board.attack_info.has_weapon_rule(board, WeaponRuleKind::melta) and source_unit.distance(target) < 12.0:
                extra_damage = board.attack_info.max_weapon_parameter(board, WeaponRuleKind::melta)
                
            subaction* devastating_damage_roll = evaluate_random_stat(board.attack_info.source.damage(), 0)
            generated_effective_wounds = generated_effective_wounds + devastating_damage_roll.result
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
    act allocate_wound(frm ModelID id) {
        id.get() < target.models.size(),
        !(target[id].state == ModelState::fight_on_death),
        board.attack_info.source.has_rule(WeaponRuleKind::precision) or !target[id.get()].has_keyword(Keyword::character) or target.all_have_keyword(Keyword::character)
    }
    board.current_decision_maker = previous_decision_maker
        
    while generated_wounds != 0:
        generated_wounds = generated_wounds - 1

        board.current_roll = rerollable_dice_roll(board, false, false, true, target.owner_id())
        board.current_state = CurrentStateDescription::save_roll
        subaction*(board) board.current_roll 
        ref target_model = target.models[id.get()]
        let best_save = min(target_model.profile.save() + board.attack_info.source.penetration() + int(board.attack_info.penetration_bonus), target_model.profile.invuln_save())
        if board.current_roll.result >= best_save:
            continue
        board.current_state = CurrentStateDescription::damage_roll
        subaction* damage_roll = evaluate_random_stat(board.attack_info.source.damage(), 0)
        generated_effective_wounds = generated_effective_wounds + damage_roll.result

    frm target_model = target[id]
    if target.damage(id.get(), generated_effective_wounds, board.attack_info.fight_on_death):
        subaction*(board, source_unit, target_model) on_model_destroyed = on_model_destroyed(board, source_unit, target_model)
    board.current_state = CurrentStateDescription::none

act on_model_destroyed(ctx Board board, ctx Unit source, ctx Model destroyed) -> OnModelDestroyed:
    if is_character and source.has_ability(AbilityKind::feeder_tendrils):
        board.add_extra_cp(int(source.owned_by_player1))

    if destroyed.has_keyword(Keyword::master_of_possession) and board.can_use_strat(!source.owned_by_player1, Stratagem::violent_unbidding):
        actions:
            act skip()
            act use_violent_unbidding() 
                board.pay_strat(!source.owned_by_player1, Stratagem::violent_unbidding)
                board.mark_strat_used(Stratagem::violent_unbidding, 1-int(source.owned_by_player1))
                act roll(frm Dice dice)
                if dice == 1:
                    return
                if dice == 6:
                    source.deal_mortal_wound_damage(3)
                if dice == 5:
                    act roll(frm Dice damage)
                    source.deal_mortal_wound_damage(damage.value / 2)


act resolve_weapon(ctx Board board, frm Int source, frm Int current_model, frm Int target) -> ResolveWeapon:
    let distance = board[target].distance(board[source][current_model])
    let rapid_fire_attacks = 0
    if distance <= float(board.attack_info.source.range()) / 2.0:
        rapid_fire_attacks = board.attack_info.source.get_rule_parameter(WeaponRuleKind::rapid_fire)

    board.current_state = CurrentStateDescription::quantity_roll
    subaction* attacks_roll = evaluate_random_stat(board.attack_info.source.attacks(),  rapid_fire_attacks)

    if board.attack_info.has_weapon_rule(board, WeaponRuleKind::blast):
       attacks_roll.result = attacks_roll.result + board[target].models.size() / 5


    frm current_attack = 0
    while current_attack != attacks_roll.result:
        ref target_unit = board[target]
        subaction* (board, board[target], board[source]) attack = single_attack(board, board[target], board[source])

        current_attack = current_attack + 1
        if board[target].models.size() == 0:
            break
    current_model = current_model + 1

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

act resolve_model_attack(ctx Board board, frm UnitID source, frm UnitID target, frm Int current_model, frm Bool melee) -> ModelAttack:
    board.current_state = CurrentStateDescription::select_weapon

    ref model = board[source][current_model]
    frm hazardous_uses = 0
    frm distance = board[target].distance(model)

    board.attack_info.source_profile = model.profile
    frm used_weapons : Bool[MAX_WEAPONS] 
    while true:
        actions:
            act select_weapon(BInt<0, MAX_WEAPONS> weapon_id) {
                weapon_id < board[source][current_model].weapons.size(),
                !melee or board[source][current_model].weapons[weapon_id.value].range() == 0,
                distance <= float(board[source][current_model].weapons[weapon_id.value].range()),
                !board[source].has_run or board[source][current_model].weapons[weapon_id.value].has_rule(WeaponRuleKind::assault),
                !used_weapons[weapon_id.value]
            }
                board.attack_info.source = board[source][current_model].weapons[weapon_id.value]            
                used_weapons[weapon_id.value] = true
            act skip()
                return
        if board.attack_info.source.has_rule(WeaponRuleKind::hazardous):
            hazardous_uses = hazardous_uses + 1
        subaction*(board) resolve_weapon = resolve_weapon(board, source.get(), current_model, target.get())
        # in melee you can only attack with one weapon unless it has extra attacks
        if melee and !board.attack_info.has_weapon_rule(board, WeaponRuleKind::extra_attacks):
            return
        
        # pistols can be used instead of other weapons
        if board.attack_info.has_weapon_rule(board, WeaponRuleKind::pistol):
            return
        # early out if we killed everyone
        if board[target].models.size() == 0:
            return

act use_attack_stratagems(ctx Board board, frm UnitID source, frm UnitID target, frm Bool melee) -> UseAttackStratagems:
    frm target_player = board[target].owner_id()
    board.current_decision_maker = board[target].owned_by_player1
    actions:
        act no_defensive_stratagem()
        act tough_as_squig_hide() {
            board.can_use_strat(bool(target_player), Stratagem::tough_as_squig_hide),
            board.players_faction[target_player] == Faction::morgrim_butchas
        }
            board[target].phase_modifiers.greater_strenght_wound_protection = true
            board.pay_strat(bool(target_player), Stratagem::tough_as_squig_hide)
            board.mark_strat_used(Stratagem::tough_as_squig_hide, target_player)
        act use_gene_wrought_resiliance() {
            board.can_use_strat(bool(target_player), Stratagem::gene_wrought_resiliance),
            board.players_faction[target_player] == Faction::strike_force_octavius
        }
            board[target].phase_modifiers.greater_strenght_wound_protection = true
            board.pay_strat(bool(target_player), Stratagem::gene_wrought_resiliance)
            board.mark_strat_used(Stratagem::gene_wrought_resiliance, target_player)
        act use_daemonic_fervour() {
            board.can_use_strat(bool(target_player), Stratagem::demonic_fervour),
            board.players_faction[target_player] == Faction::zarkan_daemonkin
        }
            board.pay_strat(bool(target_player), Stratagem::demonic_fervour)
            board.mark_strat_used(Stratagem::demonic_fervour, target_player)
            board.attack_info.fight_on_death = true
            board.attack_info.fight_on_death_roll = 1
        act use_unyielding() {
            board.can_use_strat(bool(target_player), Stratagem::unyielding),
            board.players_faction[target_player] == Faction::vengeful_brethren
        }
            board.pay_strat(bool(target_player), Stratagem::unyielding)
            board.mark_strat_used(Stratagem::unyielding, target_player)
            board.attack_info.fight_on_death = true
            board.attack_info.fight_on_death_roll = 4
            if board[source].has_ability(AbilityKind::bladeguard):
                board.attack_info.fight_on_death_roll = 3

    board.current_decision_maker = board[source].owned_by_player1
    actions:
        act no_offensive_stratagem()
        act use_veteran_instincts(){
            board[source].has_keyword(Keyword::terminator),
            board.can_use_strat(!bool(target_player), Stratagem::veteran_instincts)
        }
            if board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle):
                board.attack_info.reroll_wounds = true 
            else:
                board.attack_info.reroll1_wounds = true 
            board.pay_strat(!bool(target_player), Stratagem::veteran_instincts)
            board.mark_strat_used(Stratagem::veteran_instincts, 1-target_player)
        act use_dark_pact(){
            board.players_faction[1-target_player] == Faction::zarkan_daemonkin
        }
            board.current_pair_roll = rerollable_pair_dices_roll(board, false, false, true, 1-target_player)
            subaction*(board) board.current_roll 
            if board.current_pair_roll.result < board[source].get_leadership():
                board.current_roll = rerollable_dice_roll(board, false, false, false, 1 - target_player)
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

            board.can_use_strat(!bool(target_player), Stratagem::swift_kill),
            board.players_faction[1-target_player] == Faction::insidious_infiltrators
        }
            board.attack_info.penetration_bonus = true
            board.pay_strat(!bool(target_player), Stratagem::swift_kill)
            board.mark_strat_used(Stratagem::swift_kill, 1-target_player)
        act use_vindictive_strategy(){
            board.can_use_strat(!bool(target_player), Stratagem::vindictive_strategy),
            board.players_faction[1-target_player] == Faction::zarkan_daemonkin
        }
            board.attack_info.reroll1_hits = true
            if board[target].is_below_half_strenght():
                board.attack_info.reroll1_wounds = true
            board.pay_strat(!bool(target_player), Stratagem::vindictive_strategy)
            board.mark_strat_used(Stratagem::vindictive_strategy, 1-target_player)
        act use_sacrificial_dagger(){
            board.players_faction[1-target_player] == Faction::zarkan_daemonkin,
            board[source].has_ability(AbilityKind::sacrificial_dagger)
        }
            act select_model(frm ModelID model) {
                model.get() < board[source].models.size()
            }
            board[source].damage(model.get(), 1)
            board.attack_info.profile_hit_roll_bonus.append(Profile::aranis_zarkan)
            board.attack_info.profile_wound_roll_bonus.append(Profile::aranis_zarkan)

        if board.players_faction[1-target_player] == Faction::tristraen_gilded_blade:

            actions:
                act use_dacatarai_stance() 
                board.attack_info.add_sustained_hits(1)
                act use_rendax_stance()             
                board.attack_info.add_letal_hits()



act attack(ctx Board board, frm UnitID source, frm UnitID target, frm Bool melee, frm Bool overwatch) -> Attack:
    if board[source].models.size() == 0:
        return
    if board[target].models.size() == 0:
        return

    _configure_attack(board, source.get(), target.get(), overwatch, melee)

    subaction*(board) strats = use_attack_stratagems(board, source, target, melee)

    frm model = 0
    frm hazardous_uses = 0
    board.current_decision_maker = board[source].owned_by_player1
    while model != board[source].models.size() and !board[target].models.empty():
        subaction*(board) model_attack = resolve_model_attack(board, source, target, model, melee)
        hazardous_uses = hazardous_uses + model_attack.hazardous_uses
        model = model + 1


    ### Dangerous weapons
    board.attack_info.target_unit_id = source
    board.current_decision_maker = board[source].owned_by_player1
    while hazardous_uses != 0 and !board[source].empty():
        hazardous_uses = hazardous_uses - 1
        board.current_state = CurrentStateDescription::hazardous_roll
        board.current_roll = rerollable_dice_roll(board, false, false, true, board[source].owner_id())
        subaction*(board) board.current_roll
        if board.current_roll.result != 1:
            continue
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
    model = 0
    while model != board[target].models.size() and !board[source].models.empty():
        if board[target][model].state == ModelState::fight_on_death:
            if board.attack_info.fight_on_death_roll != 2:
                act roll(Dice result)
                if result < board.attack_info.fight_on_death_roll:
                   continue 
            subaction*(board) fight_on_death_attack = resolve_model_attack(board, target, source, model, melee)
        model = model + 1
    board[target].remove_figth_on_death_models()
        


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


enum Player:
    player_1
    player_2

act spawn_unit(ctx Board board) -> PickUnit:
    act spawn(frm ProfileToUse profile)
    act set_owner(frm Player player)
    frm unit = profile.unit()
    unit.owned_by_player1 = player.value == 0
    actions:
        act place_in_reserve()
            board.reserve_units.append(unit)
        act place_at(frm BoardPosition position)
            unit[0].position = position
            unit.arrange()
            board.units.append(unit)

act battle_shock_test(ctx Board board, ctx Unit unit) -> BattleShockTest:
    if board.can_use_strat(!board.current_player, Stratagem::insane_bravery):
        act insane_bravery(Bool do_it)
        if do_it:
            board.command_points[int(board.current_player)] = board.command_points[int(board.current_player)] - 1
                
            board.mark_strat_used(Stratagem::insane_bravery, int(board.current_player))
                return

    board.current_pair_roll = rerollable_pair_dices_roll(board, false, false, true, int(board.current_player))
    subaction*(board) board.current_pair_roll
    if board.current_pair_roll.result.value + board.current_pair_roll.result2.value < unit.get_leadership():
        unit.battle_socked = true

act battle_shock_step(ctx Board board) -> BattleShockStep:
    frm i = 0
    while i != board.units.size():
        board[i].battle_socked = false 
        board[i].has_run  = false 
        board[i].has_fought  = false 
        board[i].has_shoot = false 
        board[i].has_moved = false 
        board[i].has_charged = false
        board[i].can_shoot = true
        board[i].can_charge = true
        if board[i].owned_by_player1 != board.current_player:
            i = i + 1
            continue
        if !board[i].is_below_half_strenght():
            i = i + 1
            continue
        subaction*(board, board[i]) shock_test = battle_shock_test(board, board[i])
        i = i + 1


act shadow_in_the_warp(ctx Board board, frm Bool player) -> ShadowInTheWarp:
    if !(board.players_faction[int(player)] == Faction::insidious_infiltrators):
        return

    board.current_decision_maker = player
    if board.has_used_shadow_in_the_warp[int(player)]:
        return

    act use_shadow_in_the_warp(Bool do_it) 
    if !do_it:
        return

    board.has_used_shadow_in_the_warp[int(player)] = true
    frm i = 0
    while i != board.units.size():
        if board[i].owned_by_player1 != player:
            subaction*(board, board[i]) shock_test = battle_shock_test(board, board[i])
        i = i + 1

act neural_disruption(ctx Board board) -> NeuralDisruption:
    if !(board.players_faction[int(board.current_player)] == Faction::insidious_infiltrators):
        return
    frm i = 0
    while i != board.units.size():
        if board[i].owned_by_player1 == board.current_player and board[i].has_ability(AbilityKind::neural_disruption):
            actions:
                act select_neural_disruption_target(frm UnitID target) {
                    target.get() < board.units.size(),
                    board[target].owned_by_player1 != board.current_player,
                    board[target].distance(board[i]) < 12.0
                }
                    subaction*(board, board[i]) shock_test = battle_shock_test(board, board[target])
                act skip()
        i = i + 1

act command_phase(ctx Board board) -> CommandPhase:
    for i in range(2):
        board.command_points[i] = board.command_points[i] + 1
        board.obtained_extra_cp_this_round[i] = false

    # offer to play shadow in the warp to both players
    subaction*(board) shadow1 = shadow_in_the_warp(board, board.current_player)
    subaction*(board) shadow2 = shadow_in_the_warp(board, !board.current_player)

    board.current_decision_maker = board.current_player 
    subaction*(board) neural_disruption = neural_disruption(board)

    let faction = board.players_faction[int(board.current_player)]
    if  faction == Faction::strike_force_octavius or faction == Faction::vengeful_brethren:
        board.current_state = CurrentStateDescription::select_oath_of_moment_target
        actions:
            act select_oath_of_moment_target(frm UnitID unit) {
                unit.get() < board.units.size(),
                board[unit].owned_by_player1 != board.current_player
            }
            board.oath_of_moment_target = unit
            act skip()
        board.current_state = CurrentStateDescription::use_duty_and_honour
        actions:
            act use_duty_and_honour(frm BInt<0, 4> objective) {
                board.players_faction[int(board.current_player)] == Faction::strike_force_octavius,
                board.get_objective_controller(objective.value) == int(board.current_player),
                !board.can_use_strat(board.current_player, Stratagem::duty_and_honour)
            }
            board.mark_strat_used(Stratagem::duty_and_honour, int(board.current_player))
            board.pinned_objectives[int(board.current_player)][objective.value] = true
            act use_pheromone_trail(frm BInt<0, 4> phero_objective) {
                board.players_faction[int(board.current_player)] == Faction::insidious_infiltrators,
                board.get_objective_controller(phero_objective.value) == int(board.current_player),
                !board.can_use_strat(board.current_player, Stratagem::pheromone_trace)
            }
            board.mark_strat_used(Stratagem::pheromone_trace, int(board.current_player))
            board.pinned_objectives[int(board.current_player)][phero_objective.value] = true
            act skip()
        board.current_state = CurrentStateDescription::none

    subaction*(board) shock_step = battle_shock_step(board)


    board.score()


    

act overwatch(ctx Board board, frm UnitID moved_unit) -> Overwatch:
    if board.can_use_strat(!board.current_player, Stratagem::overwatch):
        return
    board.mark_strat_used(Stratagem::overwatch, int(!board.current_player))
    board.current_decision_maker = !board[moved_unit.get()].owned_by_player1
    board.current_state = CurrentStateDescription::overwatch
    actions:
        act skip()
        act overwatch(frm UnitID source) {
            source.get() < board.units.size(),
            !board[moved_unit].is_lone_operative() or board[source].distance(board[source]) < 12.0,
            24.0 > board[source.get()].distance(board[moved_unit.get()]),
            board[source.get()].owned_by_player1 == !board.current_player,
            board[source].can_shoot
        }
            board.command_points[int(!board.current_player)] = board.command_points[int(!board.current_player)] - 1
            board.attack = attack(board, source, moved_unit, false, true)
            subaction*(board) board.attack
    board.current_state = CurrentStateDescription::none

act move(ctx Board board, ctx UnitID unit, frm Int additional_movement) -> Move:
    if board[unit.get()].models.size() == 0:
        return
    board.current_decision_maker = board.current_player
    act move_to(BoardPosition position) {
        (position.as_vector() - board[unit.get()][0].position.as_vector()).length() <= float(board[unit.get()][0].profile.movement() + additional_movement)
    }

    board[unit.get()].move_to(position)

    board.overwatch = overwatch(board, unit)
    subaction*(board) board.overwatch
    

act fight_step(ctx Board board, frm Bool fight_first_phase) -> FightStep:
    board.current_decision_maker = !board.current_player
    frm have_passed = [false, false]
    while !have_passed[0] or !have_passed[1]:
        actions:
            act end_fight_step()
                have_passed[int(board.current_decision_maker)] = true
                board.current_decision_maker = !board.current_decision_maker
            act select_target(frm UnitID source, frm UnitID target) {
                source.get() < board.units.size(),
                target.get() < board.units.size(),
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

act fight_phase(ctx Board board) -> FightPhase:
    if board.players_faction[int(board.current_player)] == Faction::morgrim_butchas:
        actions:
            act use_bestial_bellow(frm UnitID unit, frm UnitID target) {
                unit.get() < board.units.size(),
                board[unit].has_keyword(Keyword::beastboss) or board[unit].has_keyword(Keyword::squighog_boyz),
                board.can_use_strat(board.current_player, Stratagem::bestial_bellow),
                board[target].distance(board[unit]) < 3.0
            }
                board.pay_strat(!board.current_player, Stratagem::heroic_intervention)
                board.mark_strat_used(Stratagem::heroic_intervention, int(!board.current_player))

                subaction*(board, board[target]) shock_test = battle_shock_test(board, board[target])
                
            act skip()
    subaction*(board) fight_first_step = fight_step(board, true)
    subaction*(board) fight_step = fight_step(board, false)

act charge(ctx Board board, frm UnitID source, frm UnitID target, Bool can_be_overwatched) -> Charge:
    if can_be_overwatched:
        board.overwatch = overwatch(board, source)
        subaction*(board) board.overwatch
        board[source.get()].has_charged = true

    if board[source.get()].models.size() == 0 or board[target.get()].models.size() == 0:
        return 
    board.current_pair_roll = rerollable_pair_dices_roll(board, board[source.get()].can_reroll_charge(), false, true, int(board.current_player))
    subaction*(board) board.current_pair_roll
    let vector = board[source.get()].get_shortest_vector_to(board[target.get()])
    if vector.length() < float(board.current_pair_roll.result.value + board.current_pair_roll.result2.value):
        board[source.get()].translate(vector * 0.9)
    

act charge_phase(ctx Board board) -> ChargePhase:
    board.current_decision_maker = board.current_player 
    frm charge_act : Charge
    while true:
        actions:
            act end_charge()
                break
            act select_target(frm UnitID source, frm UnitID target) {
                source.get() < board.units.size(),
                target.get() < board.units.size(),
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
                actions:
                    act skip()
                    act use_overawing_magnificence() {
                        board.faction_of_unit(target) == Faction::tristraen_gilded_blade,
                        board.can_use_strat(!board.current_player, Stratagem::overawing_magnificence) 
                    }
                        charge_reduction = true
                        board.pay_strat(!board.current_player, Stratagem::overawing_magnificence) 
                        board.mark_strat_used(Stratagem::overawing_magnificence, int(!board.current_player)) 
                subaction*(board) charge_act

                # after charge stratagem
                actions:
                    act skip()
                    act use_heroic_intervention(frm UnitID interceptor) {
                        interceptor.get() < board.units.size(),
                        !board[interceptor].empty(),
                        !board[source].empty(),
                        board[interceptor.get()].get_shortest_vector_to(board[source.get()]).length() < 12.0,
                        board[interceptor].owned_by_player1 != board[source].owned_by_player1,
                        board.can_use_strat(!board.current_player, Stratagem::heroic_intervention) or board[interceptor].has_ability(AbilityKind::pouncing_leap)
                    }
                        if !board[interceptor].has_ability(AbilityKind::pouncing_leap):
                            board.pay_strat(!board.current_player, Stratagem::heroic_intervention)
                        board.mark_strat_used(Stratagem::heroic_intervention, int(!board.current_player))
                        charge_act = charge(board, interceptor, source, false)
                        subaction*(board) charge_act
                

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
            actions:
                act place_at(BoardPosition position) {
                    board.least_distance_from_player_units(position, !current_player) > 9.0,
                    board.is_position_valid_for_reserve(position, board.reserve_units[id.get()])
                }
                board.units.append(board.reserve_units[id.get()])
                board.units.back().move_to(position)
                board.units.back().arrange()
                board.units.back().has_moved = true
                board.reserve_units.erase(id.get())
                act nothing_to_deploy()
                    done_deploying = true

act desperate_escape(ctx Board board, frm UnitID id) -> DesperateEscapeTest:
    if !board[id].battle_socked:
        return

    if board.faction_of_unit(id) == Faction::insidious_infiltrators:
        act use_predators_not_prey(Bool do_it) {
            board.can_use_strat(board[id].owned_by_player1, Stratagem::predators_not_prey)
        }
        board.mark_strat_used(Stratagem::predators_not_prey, int(board[id].owned_by_player1))
        board.pay_strat(board[id].owned_by_player1, Stratagem::predators_not_prey)
        return

    frm i = board[id].models.size()
    while i != 0:
        board.current_roll = rerollable_dice_roll(board, false, false, true, int(board[id].owned_by_player1))
        subaction*(board) board.current_roll
        if board.current_roll.result == 1:
            board[id].models.erase(i)
        i = i - 1

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
        board.current_roll = rerollable_dice_roll(board, false, false, true, int(board.current_player))
        subaction*(board) board.current_roll
        player_move = move(board, id, board.current_roll.result.value)
        subaction*(board, id) player_move 

act movement_phase(ctx Board board) -> MovementPhase:
    board.current_decision_maker = board.current_player 
    while true:
        actions:
            act end_move()
                break
            act move_unit(frm UnitID id) {
                id.get() < board.units.size(),
                board[id].owned_by_player1 == board.current_player,
                !board[id].has_moved
            }

                # stratagems
                frm use_gilded_spear : Bool
                if board.get_current_player_faction() == Faction::tristraen_gilded_blade and board.can_use_strat(board.current_player, Stratagem::the_gilded_spear):
                    act use_gilded_spear(Bool do_it)
                    use_gilded_spear = do_it
                    board.pay_strat(board.current_player, Stratagem::the_gilded_spear)
                    board.mark_strat_used(Stratagem::the_gilded_spear, int(board.current_player))
       
                # move
                subaction*(board) move = movement(board, id, use_gilded_spear)

    board.current_decision_maker = board.current_player 
    # reserve managment
    while true:
        subaction*(board) reserve_deployment = reserve_deployment(board, board.current_player)
        if reserve_deployment.done_deploying:
            break

    let can_rapid_ingress = board.can_use_strat(!board.current_player, Stratagem::rapid_ingress)
    if can_rapid_ingress:
        board.current_decision_maker = !board.current_player 
        subaction*(board) rapid_ingress = reserve_deployment(board, !board.current_player)
        board.command_points[int(!board.current_player)] = board.command_points[int(!board.current_player)] - 1
        board.mark_strat_used(Stratagem::rapid_ingress, int(!board.current_player))
        

act shooting_phase(ctx Board board) -> ShootingPhase:
    board.current_decision_maker = board.current_player 
    while true:
        actions:
            act end_shooting_phase()
                break
            act select_target(frm UnitID source, frm UnitID target) {
                source.get() < board.units.size(),
                target.get() < board.units.size(),
                !board[target].is_lone_operative() or board[source].distance(board[source]) < 12.0,
                !board[source].has_shoot,
                board[source].can_shoot,
                board.units[source.get()].owned_by_player1 == board.current_player,
                board.units[target.get()].owned_by_player1 != board.current_player
            }
                board[source.get()].has_shoot = true
                board.attack = attack(board, source, target, false, false)
                subaction*(board) board.attack
    

act turn(ctx Board board, frm Bool player_id) -> Turn:
    board.current_player = player_id
    subaction*(board) command_phase = command_phase(board)
    subaction*(board) movement_phase = movement_phase(board)
    subaction*(board) shooting_phase = shooting_phase(board)
    board.clear_phase_modifiers() 
    subaction*(board) charge_phase = charge_phase(board)
    board.clear_phase_modifiers() 
    subaction*(board) fight_phase = fight_phase(board)
    board.clear_phase_modifiers() 

act round(ctx Board board) -> Round:
    frm player_turn = turn(board, board.starting_player)
    subaction*(board) player_turn
    player_turn = turn(board, !board.starting_player)
    subaction*(board) player_turn

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
                act deploy_at(BoardPosition position) {
                    deployment_position_valid(board, position, board.current_decision_maker, infiltrates)
                }
                board.units.append(board.reserve_units[unit_id.get()])
                board.reserve_units.erase(unit_id.get())
                board.units.back().move_to(position)
                board.units.back().arrange()
                if !passed_players[int(!board.current_decision_maker)]:
                    board.current_decision_maker = !board.current_decision_maker
        

act battle(ctx Board board) -> Battle:
    subaction*(board) attach_leaders = attach_leaders(board)
    subaction*(board) deploy = deploy(board)
    while board.current_round != 5:
        subaction*(board) round = round(board)
        board.current_round = board.current_round + 1


fun<T> set_state(T g, String s) -> Bool:
    return from_string(g, s)

fun main() -> Int:
    let state = play()
    let dice : Dice
    let str = to_string(state).to_indented_lines()
    print(str)
    set_state(state, str)
    if from_string(state, str):
        return 0
    return 1

fun get_num_players() -> Int:
    return 2

fun max_game_lenght() -> Int:
    return 5000

fun gen_methods():
    let x : Vector<Bool>
    let action : AnyGameAction
    let board : Board
    for alternative of action:
        pretty_string(board, alternative)
    pretty_string(board, action)
    let profile = make_tantus()
    to_string(Weapon::captain_storm_bolter)
    to_string(Profile::captain_octavius)
    profile.models.size()
    to_string(profile)
    to_string(profile.models[0])
    print(profile)
    to_string(action)
    print(action)
    to_string(enumerate(action))
    to_string(true)
    to_string(CurrentStateDescription::none)
    print(enumerate(action))

fun fuzz(Vector<Byte> input):
    let state = play()
    let x : AnyGameAction
    let enumeration = enumerate(x)
    let index = 0
    while index + 8 < input.size() and !state.is_done():
        let num_action : Int
        from_byte_vector(num_action, input, index)
        if num_action < 0:
          num_action = num_action * -1 
        if num_action < 0:
          num_action = 0 

        let executable : Vector<AnyGameAction>
        let i = 0
        #print("VALIDS")
        while i < enumeration.size():
          if can apply(enumeration.get(i), state):
            #print(enumeration.get(i))
            executable.append(enumeration.get(i))
          i = i + 1
        #print("ENDVALIDS")
        if executable.size() == 0:
            assert(false, "zero valid actions")

        print(executable.get(num_action % executable.size()))
        apply(executable.get(num_action % executable.size()), state)


fun pretty_print(Game game):
    print_indented(game)

fun<T> pretty_string(Board b, T obj) -> String:
    if obj is GameSelectWeapon:
        if !(b.get_current_attacking_model().weapons.size() > obj.weapon_id.value):
            return to_string(obj)
        return to_string(b.get_current_attacking_model().weapons[obj.weapon_id.value])
    return to_string(obj)


act attack_sequence(ctx Board board, frm Bool overwatch, frm Bool melee) -> AttackSequence:
    act select_target(UnitID source, UnitID target) { 
        source.get() < board.units.size(), 
        target.get() < board.units.size(), 
        source.get() != target.get()
    }
    board.attack = attack(board, source, target, overwatch, melee)
    subaction*(board) board.attack

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
            

@classes
act play() -> Game:
    frm board : Board
    subaction*(board) p1 = pick_army(board, false)
    subaction*(board) p2 = pick_army(board, true)
    subaction*(board) battle = battle(board)
    

@classes
act play2() -> Game2:
    frm board : Board
    frm sequence : AttackSequence

    while true:
        actions:
            act spawn_unit()
                subaction*(board) spawn_unit = spawn_unit(board)
            act skip()
                break

    actions:
        act only_shoot()
            sequence = attack_sequence(board, false, false)
            subaction*(board) sequence
        act only_overwatch()
            sequence = attack_sequence(board, true, false)
            subaction*(board) sequence
        act only_melee_attack()
            sequence = attack_sequence(board, false, true)
            subaction*(board) sequence
        act fullgame()
            subaction*(board) battle = battle(board)

fun score(Game g, Int player_id) -> Float:
    if g.board.units.size() < 2:
        return 0.0
    let count = g.board.units[1].models.size()
    if player_id == 0:
        # Player 0's score: models destroyed in player 1's unit
        return float(5- count)
    else:
        # Player 1's score: models remaining in their unit
        return float(count)

fun get_current_player(Game g) -> Int:
    if g.is_done():
        return -4
    let d : Dice
    d.value = 1
    if can g.roll(d):
        return -1
    if can g.reroll(d):
        return -1
    if can g.quantity(d):
        return -1
    return int(g.board.current_decision_maker)

fun log_alive_models_player1(Game g) -> Int:
    return g.board.count_models(0)

fun log_alive_models_player2(Game g) -> Int:
    return g.board.count_models(1)
