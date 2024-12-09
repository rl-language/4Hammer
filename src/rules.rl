import action
import bounded_arg
import string
import learn
import vector2d
import stats
import board

using Dice = BInt<1, 7>
    
fun make_profile1() -> Unit:
    let profile : Unit 
    let i = 0
    while i != 20:
        let model : Model
        model.profile = Profile::baseline_human
        model.weapons.append(Weapon::laser_gun)
        model.position.x = i
        model.position.y = 10
        profile.models.append(model)
        i = i + 1
    return profile
    
fun make_profile2() -> Unit:
    let profile : Unit 
    let i = 0
    while i != 10:
        let model : Model
        model.profile = Profile::super_human
        model.weapons.append(Weapon::balter_gun)
        model.position.x = i
        model.position.y = 10
        profile.models.append(model)
        i = i + 1
    return profile


fun required_wound_roll(Weapon source, Int thoughness) -> Int:
    let strenght = source.strenght()
    if strenght == thoughness:
        return 4

    if strenght * 2 < thoughness:
        return 6
    
    if strenght < thoughness:
        return 5

    if strenght > thoughness * 2:
        return 2
    
    if strenght > thoughness:
        return 3

    return 0

act single_attack(ctx Unit target, frm Weapon source) -> SingleAttack:
    act hit_roll(Dice d)
    if d < source.skill():
        return

    act wound_roll(Dice d)
    if d < required_wound_roll(source, target.get_unit_toughtness()):
        return

    act allocate_wound(frm ModelID id) {
        id.get() < target.models.size()
    }

    act save_roll(Dice d)
    ref target_model = target.models[id.get()]
    if d.value >= (target_model.profile.save() + source.penetration()):
        return
    
    target_model.suffered_wounds = target_model.suffered_wounds + source.damage() 
    if target_model.suffered_wounds >= target_model.profile.wounds(): 
        target.models.erase(id.get())

act attack(ctx Board board, frm Int source, frm Int target) -> Attack:
    if board[target].models.size() == 0:
        return
    board.current_target_unit = target
    frm current_model = 0
    while current_model != board[source].models.size():
        frm weapon = board[source][current_model].weapons[0]
        frm current_attack = 0
        while current_attack != weapon.attacks():
            ref target_unit = board[target]
            if target_unit.distance(board[source][current_model]) > float(weapon.range()):
                current_attack = current_attack + 1
                continue
            subaction* (board[target]) attack = single_attack(board[target], weapon)
            current_attack = current_attack + 1
            if board[target].models.size() == 0:
                break
        current_model = current_model + 1

enum ProfileToUse:
    use_humans:
        Unit unit = make_profile1()
    use_super_humans:
        Unit unit = make_profile2()

    fun equal(ProfileToUse other) -> Bool:
        return self.value == other.value

act play() -> Game: # required
    frm board : Board # required
    board.units.append(make_profile1())
    board.units.back().owned_by_player1 = true
    board.units[0].translate(0, 5)

    act pick_profile(frm ProfileToUse profile)
    act select_position(BoardPosition position)  { 10.0 > position.as_vector().length() }

    board.units.append(profile.unit())
    board.units.back().move_to(position) 

    act select_target(frm UnitID source, frm UnitID target) {
        source.get() < board.units.size(),
        target.get() < board.units.size(),
        !board.units[source.get()].owned_by_player1,
        board.units[target.get()].owned_by_player1
    }


    subaction*(board) attack = attack(board, source.get(), target.get())

fun get_current_player(Game g) -> Int:
    if g.is_done():
        return -4
    let d : Dice
    d.value = 1
    if can g.hit_roll(d):
        return -1
    if can g.wound_roll(d):
        return -1
    if can g.save_roll(d):
        return -1
    return 0

fun score(Game g, Int player_id) -> Float:
    if !g.is_done(): 
        return 0.0 
    return float(20 - g.board.units[0].models.size())

fun get_num_players() -> Int:
    return 1

fun max_game_lenght() -> Int:
    return 5000

fun log_models_left(Game g) -> Int:
    return g.board.units[0].models.size()

fun log_use_humans(Game g) -> Int:
    return int(g.profile == ProfileToUse::use_humans)

fun gen_methods():
    let x : Vector<Bool>
    let action : AnyGameAction
    let profile = make_profile1()
    profile.models.size()
    to_string(Weapon::laser_gun)
    to_string(Profile::baseline_human)
    to_string(profile)
    to_string(profile.models[0])
    print(profile)
    to_string(action)
    print(action)
    to_string(enumerate(action))
    print(enumerate(action))
