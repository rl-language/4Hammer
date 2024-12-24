import action
import bounded_arg
import string
import learn
import vector2d
import stats
import board


fun required_wound_roll(AttackSequenceInfo info) -> Int:
    let strenght = info.source.strenght()
    let thoughness = info.target_toughness
    let modifiers = int(info.wound_roll_malus) * -1
    if thoughness < strenght and info.greater_strenght_wound_protection:
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
    let is_cp_rerollable = cp_rerollable and board.command_points[current_player] != 0 and !board.has_used_strat(Stratagem::reroll, current_player)
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
    let is_cp_rerollable = cp_rerollable and board.command_points[current_player] != 0 and !board.has_used_strat(Stratagem::reroll, current_player)
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

act single_attack(ctx Board board, ctx Unit target, ctx Unit source_unit) -> SingleAttack:
    frm generated_hits = 0
    frm generated_wounds = 0
    frm generated_effective_wounds = 0
    if board.attack_info.source.skill() == 0:
        generated_hits = 1
    else:
        board.current_roll = rerollable_dice_roll(board, board.attack_info.reroll_hits, false, true, source_unit.owner_id())
        subaction*(board) board.current_roll
        if board.current_roll.result < board.attack_info.source.skill() or board.current_roll.result == 1:
            return
        if board.current_roll.result == 6:
           generated_hits = generated_hits + source_unit.max_weapon_parameter(board.attack_info.source, WeaponRuleKind::sustained_hit) 
        if board.attack_info.source.has_rule(WeaponRuleKind::letal_hits):
            generated_wounds = generated_wounds + 1
        else:
            generated_hits = generated_hits + 1

    while generated_hits != 0:
        generated_hits = generated_hits - 1
        board.current_roll = rerollable_dice_roll(board, board.attack_info.reroll_wounds, board.attack_info.reroll1_wounds, true, source_unit.owner_id())
        subaction*(board) board.current_roll

        if board.current_roll.result < required_wound_roll(board.attack_info) or board.current_roll.result == 1:
            continue


        if board.current_roll.result == 6 and board.attack_info.source.has_rule(WeaponRuleKind::devastating_wounds):
            subaction* devastating_damage_roll = evaluate_random_stat(board.attack_info.source.damage(), 0)
            generated_effective_wounds = generated_effective_wounds + devastating_damage_roll.result
        else:
            generated_wounds = generated_wounds + 1 

    if generated_wounds == 0 and generated_effective_wounds == 0:
        return

    frm previous_decision_maker = board.current_decision_maker
    board.current_decision_maker = target.owned_by_player1
    act allocate_wound(frm ModelID id) {
        id.get() < target.models.size(),
        board.attack_info.source.has_rule(WeaponRuleKind::precision) or !target[id.get()].has_keyword(Keyword::character) or target.all_have_keyword(Keyword::character)
    }
    board.current_decision_maker = previous_decision_maker
        
    while generated_wounds != 0:
        generated_wounds = generated_wounds - 1

        board.current_roll = rerollable_dice_roll(board, false, false, true, target.owner_id())
        subaction*(board) board.current_roll 
        ref target_model = target.models[id.get()]
        let best_save = min(target_model.profile.save() + board.attack_info.source.penetration(), target_model.profile.invuln_save())
        if board.current_roll.result >= best_save:
            continue
        subaction* damage_roll = evaluate_random_stat(board.attack_info.source.damage(), 0)
        generated_effective_wounds = generated_effective_wounds + damage_roll.result

    ref target_model = target.models[id.get()]
    target.damage(id.get(), generated_effective_wounds)


act resolve_weapon(ctx Board board, frm Int source, frm Int current_model, frm Int target) -> ResolveWeapon:
    let distance = board[target].distance(board[source][current_model])
    let rapid_fire_attacks = 0
    if distance <= float(board.attack_info.source.range()) / 2.0:
        rapid_fire_attacks = board.attack_info.source.get_rule_parameter(WeaponRuleKind::rapid_fire)
    subaction* attacks_roll = evaluate_random_stat(board.attack_info.source.attacks(),  rapid_fire_attacks)

    frm current_attack = 0
    while current_attack != attacks_roll.result:
        ref target_unit = board[target]
        subaction* (board, board[target], board[source]) attack = single_attack(board, board[target], board[source])
        current_attack = current_attack + 1
        if board[target].models.size() == 0:
            break
    current_model = current_model + 1

fun _configure_attack(Board board, Int source, Int target, Bool overwatch):
    let attack : AttackSequenceInfo
    attack.source_unit_id = source 
    attack.target_unit_id = target
    if overwatch:
        attack.only_hits_on_6 = true 

    attack.target_toughness = board[target].get_unit_toughtness()
    attack.greater_strenght_wound_protection = board[target].has_greater_strenght_wound_protection()

    if target == board.oath_of_moment_target.get():
        if board[source].has_ability(AbilityKind::oath_of_moment):
            attack.reroll_hits = true
        if board[source].has_ability(AbilityKind::fury_of_the_first):
            attack.hit_roll_bonus = true
    board.attack_info = attack

act attack(ctx Board board, frm Int source, frm Int target, frm Bool melee, frm Bool overwatch) -> Attack:
    if board[source].models.size() == 0:
        return
    if board[target].models.size() == 0:
        return

    frm target_player = board[target].owner_id()
    board.current_decision_maker = board[target].owned_by_player1
    actions:
        act no_defensive_stratagem()
        act use_gene_wrought_resiliance() {
            board.command_points[target_player] != 0,
            board.players_faction[target_player] == Faction::strike_force_octavius,
            board.has_used_strat(Stratagem::gene_wrought_resiliance, target_player)
        }
            board[target].phase_modifiers.greater_strenght_wound_protection = true
            board.command_points[target_player] = board.command_points[target_player] - 1
            board.mark_strat_used(Stratagem::veteran_instincts, target_player)

    _configure_attack(board, source, target, overwatch)

    board.current_decision_maker = board[source].owned_by_player1
    actions:
        act no_offensive_stratagem()
        act use_veteran_instincts(){
            board.command_points[1-target_player] != 0,
            board[source].has_keyword(Keyword::terminator),
            board.has_used_strat(Stratagem::veteran_instincts, 1-target_player)
        }
            if board[target].has_keyword(Keyword::monster) or board[target].has_keyword(Keyword::vehicle):
                board.attack_info.reroll_wounds = true 
            else:
                board.attack_info.reroll1_wounds = true 
            board.command_points[1-target_player] = board.command_points[1-target_player] - 1
            board.mark_strat_used(Stratagem::veteran_instincts, 1-target_player)


    frm current_model = 0
    frm hazardous_uses = 0
    board.current_decision_maker = board[source].owned_by_player1
    while current_model != board[source].models.size() and !board[target].models.empty():
        ref model = board[source][current_model]
        frm distance = board[target].distance(model)
        actions:
            act select_weapon(BInt<0, MAX_WEAPONS> weapon_id) {
                weapon_id < board[source][current_model].weapons.size(),
                !melee or board[source][current_model].weapons[weapon_id.value].range() == 0,
                distance <= float(board[source][current_model].weapons[weapon_id.value].range())
            }
                board.attack_info.source = board[source][current_model].weapons[weapon_id.value]
            act skip()
                current_model = current_model + 1
                continue
        if board.attack_info.source.has_rule(WeaponRuleKind::hazardous):
            hazardous_uses = hazardous_uses + 1
        subaction*(board) resolve_weapon = resolve_weapon(board, source, current_model, target)
        current_model = current_model + 1

    board.attack_info.target_unit_id = source
    board.current_decision_maker = board[source].owned_by_player1
    while hazardous_uses != 0 and !board[source].empty():
        hazardous_uses = hazardous_uses - 1
        board.current_roll = rerollable_dice_roll(board, false, false, true, board[source].owner_id())
        subaction*(board) board.current_roll
        if board.current_roll.result != 1:
            continue
        act select_model(frm ModelID model) {
            model.get() < board[source].models.size(),
            board[source][model.get()].has_weapon_rule(WeaponRuleKind::hazardous)
        }
        # ToDo: handle non character version
        board[source].damage(model.get(), 3)

        


enum ProfileToUse:
    captain_octavius:
        Unit unit = make_octavius()
    librarian_tantus:
        Unit unit = make_tantus()
    terminator_squad:
        Unit unit = make_terminator_squad()
    infernus_squad:
        Unit unit = make_infernus_squad()

    fun equal(ProfileToUse other) -> Bool:
        return self.value == other.value

act battle_shock_step(ctx Board board) -> BattleShockStep:
    frm i = 0
    while i != board.units.size():
        board[i].battle_socked = false 
        board[i].has_run  = false 
        board[i].has_fought  = false 
        board[i].has_shoot = false 
        board[i].has_moved = false 
        board[i].has_charged = false
        if board.units[i].owned_by_player1 != board.current_player:
            i = i + 1 
            continue
        if !board.units[i].is_below_half_strenght():
            i = i + 1 
            continue 
        if board.has_used_strat(Stratagem::insane_bravery, int(!board.current_player)):
            continue
        if board.command_points[int(board.current_player)] != 0:
            act insane_bravery(Bool do_it)
            if do_it:
                board.command_points[int(board.current_player)] = board.command_points[int(board.current_player)] - 1
                i = i + 1 
                
                board.mark_strat_used(Stratagem::insane_bravery, int(board.current_player))
                continue

        board.current_pair_roll = rerollable_pair_dices_roll(board, false, false, true, int(board.current_player))
        subaction*(board) board.current_pair_roll
        if board.current_pair_roll.result.value + board.current_pair_roll.result2.value < board.units[i].get_leadership():
            board.units[i].battle_socked = true
        i = i + 1 

act command_phase(ctx Board board) -> CommandPhase:
    board.command_points[0] = board.command_points[0] + 1
    board.command_points[1] = board.command_points[1] + 1

    board.current_decision_maker = board.current_player 
    if board.players_faction[int(board.current_player)] == Faction::strike_force_octavius:
        actions:
            act do_not_use_oath()
            act select_oath_of_moment_target(frm UnitID model) {
                model.get() < board.units.size(),
                board[model.get()].owned_by_player1 != board.current_player
            }
            board.oath_of_moment_target = model
        actions:
            act do_not_use_duty_and_honour()
            act use_duty_and_honour(frm BInt<0, 4> objective) {
                board.get_objective_controller(objective.value) == int(board.current_player),
                board.command_points[int(!board.current_player)] != 0,
                !board.has_used_strat(Stratagem::duty_and_honour, int(board.current_player))
            }
            board.mark_strat_used(Stratagem::duty_and_honour, int(board.current_player))
            board.pinned_objectives[int(board.current_player)][objective.value] = true

    subaction*(board) shock_step = battle_shock_step(board)


    board.score()


    

act overwatch(ctx Board board, frm UnitID moved_unit) -> Overwatch:
    if board.command_points[int(!board.current_player)] == 0 or board.has_used_strat(Stratagem::overwatch, int(!board.current_player)):
        return
    board.mark_strat_used(Stratagem::overwatch, int(!board.current_player))
    board.current_decision_maker = !board[moved_unit.get()].owned_by_player1
    actions:
        act no_overwatch()
        act overwatch(frm UnitID source) {
            source.get() < board.units.size(),
            24.0 > board[source.get()].distance(board[moved_unit.get()]),
            board[source.get()].owned_by_player1 == !board.current_player
        }
            board.command_points[int(!board.current_player)] = board.command_points[int(!board.current_player)] - 1
            board.attack = attack(board, source.get(), moved_unit.get(), false, true)
            subaction*(board) board.attack

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
                board.attack = attack(board, source.get(), target.get(), true, false)
                subaction*(board) board.attack
                board[source.get()].has_fought = true
                if have_passed[int(!board.current_decision_maker)]:

                    board.current_decision_maker = !board.current_decision_maker

act fight_phase(ctx Board board) -> FightPhase:
    subaction*(board) fight_first_step = fight_step(board, true)
    subaction*(board) fight_step = fight_step(board, false)

act charge_phase(ctx Board board) -> ChargePhase:
    board.current_decision_maker = board.current_player 
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
                !board.units[source.get()].has_charged,
                board.units[source.get()].owned_by_player1 == board.current_player,
                board.units[target.get()].owned_by_player1 != board.current_player,
                board[target.get()].get_shortest_vector_to(board[source.get()]).length() < 12.0
            }
                board.overwatch = overwatch(board, source)
                subaction*(board) board.overwatch
                board[source.get()].has_charged = true
                if board[source.get()].models.size() == 0 or board[target.get()].models.size() == 0:
                    continue
                board.current_pair_roll = rerollable_pair_dices_roll(board, board[source.get()].can_reroll_charge(), false, true, int(board.current_player))
                subaction*(board) board.current_pair_roll
                let vector = board[source.get()].get_shortest_vector_to(board[target.get()])
                if vector.length() < float(board.current_pair_roll.result.value + board.current_pair_roll.result2.value):
                    board[source.get()].translate(vector * 0.9)
                    
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

act movement_phase(ctx Board board) -> MovementPhase:
    board.current_decision_maker = board.current_player 
    frm player_move : Move
    while true:
        actions:
            act end_move()
                break
            act move_unit(frm UnitID moving_unit) {
                moving_unit.get() < board.units.size(),
                board[moving_unit.get()].owned_by_player1 == board.current_player,
                !board[moving_unit.get()].has_moved
            }
                board[moving_unit.get()].has_moved = true
                player_move = move(board, moving_unit, 0)
                subaction*(board, moving_unit) player_move 
            act advance_unit(frm UnitID running_unit) {
                running_unit.get() < board.units.size(),
                board[running_unit.get()].owned_by_player1 == board.current_player,
                !board[running_unit.get()].has_moved
            }
                board[running_unit.get()].has_moved = true
                board[running_unit.get()].has_run = true
                board.current_roll = rerollable_dice_roll(board, false, false, true, int(board.current_player))
                subaction*(board) board.current_roll
                player_move = move(board, running_unit, board.current_roll.result.value)
                subaction*(board, running_unit) player_move 

    board.current_decision_maker = board.current_player 
    # reserve managment
    while true:
        subaction*(board) reserve_deployment = reserve_deployment(board, board.current_player)
        if reserve_deployment.done_deploying:
            break

    let can_rapid_ingress = board.command_points[int(!board.current_player)] != 0 and !board.has_used_strat(Stratagem::reroll, int(!board.current_player))
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
                !board.units[source.get()].has_run,
                !board[source.get()].has_shoot,
                board.units[source.get()].owned_by_player1 == board.current_player,
                board.units[target.get()].owned_by_player1 != board.current_player
            }
                board[source.get()].has_shoot = true
                board.attack = attack(board, source.get(), target.get(), false, false)
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
                act deploy_at(BoardPosition position) {
                    board.current_decision_maker or position.y <= 5,
                    !board.current_decision_maker or position.y >= BOARD_HEIGHT - 5
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
        subaction*(board) battle = round(board)
        board.current_round = board.current_round + 1

@classes
act play() -> Game: # required
    frm board : Board # required
    board.oath_of_moment_target = MAX_UNIT_COUNT 
    board.players_faction[0] = Faction::strike_force_octavius
    make_octavious_strike_force(board.reserve_units, false)
    board.players_faction[1] = Faction::strike_force_octavius
    make_octavious_strike_force(board.reserve_units, true)

    act pick_starting_player(Bool first_player)
    board.starting_player = first_player 

    subaction*(board) battle = battle(board) 



fun get_current_player(Game g) -> Int:
    if g.is_done():
        return -4
    let d : Dice
    d.value = 1
    if can g.pick_starting_player(true):
        return -1
    if can g.roll(d):
        return -1
    if can g.reroll(d):
        return -1
    if can g.roll_pair(d, d):
        return -1
    if can g.reroll_pair(d, d):
        return -1
    if can g.quantity(d):
        return -1
    return int(g.board.current_decision_maker)

fun score(Game g, Int player_id) -> Float:
    return float(g.board.score[player_id].value - g.board.score[1-player_id].value) 

fun get_num_players() -> Int:
    return 2

fun max_game_lenght() -> Int:
    return 5000

fun log_p1_score(Game g) -> Int:
    return g.board.score[0].value

fun log_p2_score(Game g) -> Int:
    return g.board.score[1].value

fun log_models_left1(Game g) -> Int:
    return g.board.count_models(0)

fun log_models_left2(Game g) -> Int:
    return g.board.count_models(1)


fun gen_methods():
    let x : Vector<Bool>
    let action : AnyGameAction
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

