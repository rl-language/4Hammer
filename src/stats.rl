import bounded_arg

using Dice = BInt<1, 7>
using Stat = Int | Dice 

fun raw_stat(Int value) ->  Stat:
    let stat : Stat 
    stat = value
    return stat

fun dice_stat(Int value) ->  Stat:
    let stat : Stat 
    let dice : Dice
    dice.value = value
    stat = dice
    return stat

enum WeaponRuleKind:
    pistol
    ignore_cover
    torrent
    rapid_fire
    psychic
    devastating_wounds
    sustained_hit
    letal_hits 
    precision
    hazardous
    anti_monster
    anti_vehichle
    anti_psychic
    heavy
    melta
    blast
    lance
    extra_attacks
    assault

    fun equal(WeaponRuleKind other) -> Bool:
        return self.value == other.value

fun write_in_observation_tensor(WeaponRuleKind obj, Int observer_id, Vector<Float> output, Int index):
    output[index] = (float(obj.value) - (float(max(obj)) / 2.0)) / float(max(obj))
    index = index + 1

fun size_as_observation_tensor(WeaponRuleKind kind) -> Int:
    return 1

cls WeaponRule:
    WeaponRuleKind kind
    Int parameter

fun weapon_rule(WeaponRuleKind kind, Int parameter) -> WeaponRule:
    let rule : WeaponRule
    rule.kind = kind
    rule.parameter = parameter
    return rule

fun weapon_rule(WeaponRuleKind kind) -> WeaponRule:
    let rule : WeaponRule
    rule.kind = kind
    return rule
    

using WeaponRules = Vector<WeaponRule>

fun no_weapon_rules() -> WeaponRules:
    let to_return : WeaponRules
    return to_return

fun weapon_rules() -> WeaponRules:
    let to_return : WeaponRules
    return to_return
fun weapon_rules(WeaponRule rule) -> WeaponRules:
    let to_return : WeaponRules
    to_return.append(rule)
    return to_return
fun weapon_rules(WeaponRule rule, WeaponRule rule2) -> WeaponRules:
    let to_return : WeaponRules
    to_return.append(rule)
    to_return.append(rule2)
    return to_return
fun weapon_rules(WeaponRule rule, WeaponRule rule2, WeaponRule rule3) -> WeaponRules:
    let to_return : WeaponRules
    to_return.append(rule)
    to_return.append(rule2)
    to_return.append(rule3)
    return to_return

fun weapon_rules(WeaponRule rule, WeaponRule rule2, WeaponRule rule3, WeaponRule rule4) -> WeaponRules:
    let to_return : WeaponRules
    to_return.append(rule)
    to_return.append(rule2)
    to_return.append(rule3)
    to_return.append(rule4)
    return to_return

fun weapon_rules(WeaponRule rule, WeaponRule rule2, WeaponRule rule3, WeaponRule rule4, WeaponRule rule5) -> WeaponRules:
    let to_return : WeaponRules
    to_return.append(rule)
    to_return.append(rule2)
    to_return.append(rule3)
    to_return.append(rule4)
    to_return.append(rule5)
    return to_return

enum Weapon:
    captain_storm_bolter:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 2
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2))
    relic_weapon:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 5
        Int penetration = 2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::letal_hits), weapon_rule(WeaponRuleKind::precision))
    smite_witchfire:
        Int range = 24
        Stat attacks = dice_stat(6)
        Int skill = 3
        Int strenght = 5
        Int penetration = 1
        Stat damage = dice_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::psychic))
    smite_focused_witchfire:
        Int range = 24
        Stat attacks = dice_stat(6)
        Int skill = 3
        Int strenght = 4
        Int penetration = 2
        Stat damage = dice_stat(3)
        WeaponRules rules = weapon_rules(
                        weapon_rule(WeaponRuleKind::psychic), 
                        weapon_rule(WeaponRuleKind::hazardous), 
                        weapon_rule(WeaponRuleKind::devastating_wounds))
    librarian_storm_bolter:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2))
    force_weapon:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 6
        Int penetration = 1
        Stat damage = dice_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::psychic))
    bolt_pistol:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    pyreblaster:
        Int range = 12
        Stat attacks = dice_stat(6)
        Int skill = 0
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(
                                weapon_rule(WeaponRuleKind::ignore_cover), 
                                weapon_rule(WeaponRuleKind::torrent))
    close_combact_weapon:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    assault_cannon:
        Int range = 24
        Stat attacks = raw_stat(6)
        Int skill = 3
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::devastating_wounds))
    terminator_storm_bolter:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2))
    terminator_power_fist:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 8
        Int penetration = 2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    terminator_power_weapon:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = 2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    death_shadow_claws_and_talons:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 6
        Int penetration = 2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision))
    lictor_claws_and_talons:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 7
        Int penetration = 2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision))
    leapers_talon:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 3
        Int strenght = 5
        Int penetration = 1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    rite_of_possession:
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 4
        Int penetration = -3
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
                                weapon_rule(WeaponRuleKind::psychic), 
                                weapon_rule(WeaponRuleKind::anti_psychic), 
                                weapon_rule(WeaponRuleKind::pistol), 
                                weapon_rule(WeaponRuleKind::precision))
    rite_of_possession_focused:
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 6
        Int penetration = 2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(
                                weapon_rule(WeaponRuleKind::psychic), 
                                weapon_rule(WeaponRuleKind::hazardous), 
                                weapon_rule(WeaponRuleKind::anti_psychic), 
                                weapon_rule(WeaponRuleKind::pistol), 
                                weapon_rule(WeaponRuleKind::precision))
    staff_of_possession:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 6
        Int penetration = 1
        Stat damage = dice_stat(3)
        WeaponRules rules = weapon_rules(
                                weapon_rule(WeaponRuleKind::psychic), 
                                weapon_rule(WeaponRuleKind::anti_psychic))
    hideous_mutations:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = 1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    boltgun:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    heavy_bolter:
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 5
        Int penetration = 1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::heavy),
            weapon_rule(WeaponRuleKind::sustained_hit, 1)
        )
    meltagun:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 9
        Int penetration = -4
        Stat damage = dice_stat(6)  
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::melta, 2))
    plasma_pistol_standard:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    plasma_pistol_supercharge:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 8
        Int penetration = -3
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::hazardous),
            weapon_rule(WeaponRuleKind::pistol)
        )
    accursed_weapon:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    close_combat_weapon:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    cultist_autopistol:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 3
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    cultist_bolt_pistol:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    brutal_assault_weapon:
        Int range = 0
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 3
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    beat_boss_shoota:
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1))
    beast_snagga_klaw:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::anti_monster, 4),
            weapon_rule(WeaponRuleKind::anti_vehichle, 4)
        )
    beastchoppa:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::anti_monster, 4),
            weapon_rule(WeaponRuleKind::anti_vehichle, 4))
    slugga:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    thump_gun:
        Int range = 18
        Stat attacks = dice_stat(3)  
        Int skill = 5
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast))
    choppa:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    power_snappa:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 7
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    saddlegit_weapons:
        Int range = 9
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 3
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::assault)
        )
    stikka_ranged:
        Int range = 9
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::assault),
            weapon_rule(WeaponRuleKind::anti_monster, 4),
            weapon_rule(WeaponRuleKind::anti_vehichle, 4)
        )
    big_choppa:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::anti_monster, 4),
            weapon_rule(WeaponRuleKind::anti_vehichle, 4)
        )
    stikka_melee:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::anti_monster, 4),
            weapon_rule(WeaponRuleKind::anti_vehichle, 4),
            weapon_rule(WeaponRuleKind::lance)
        )
    squighog_jaws:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::extra_attacks)
        )


    fun get_rule_parameter(WeaponRuleKind rule) -> Int:
        let i = 0
        let rules = self.rules()
        while i != rules.size():
            if rules[i].kind == rule: 
                return rules[i].parameter
            i = i + 1
        return 0 

    fun has_rule(WeaponRuleKind rule) -> Bool:
        let i = 0
        let rules = self.rules()
        while i != rules.size():
            if rules[i].kind == rule: 
                return true 
            i = i + 1
        return false

fun write_in_observation_tensor(Weapon obj, Int observer_id, Vector<Float> output, Int index):
    output[index] = (float(obj.value) - (float(max(obj)) / 2.0)) / float(max(obj))
    index = index + 1

fun size_as_observation_tensor(Weapon kind) -> Int:
    return 1

enum AbilityKind:
    deep_strike
    oath_of_moment
    veil_of_time
    leader
    unstoppable_valour
    fight_first
    fury_of_the_first
    infiltrators
    lone_operative
    stealth
    shadow_in_the_warp
    neural_disruption
    psychological_saboteur
    feeder_tendrils 
    pouncing_leap
    sacrificial_dagger 
    dark_pacts
    veterans_of_the_long_war
    morgrim
    beast_snagga
    warboss
    beastboss

    fun equal(AbilityKind other) -> Bool:
        return self.value == other.value

fun write_in_observation_tensor(AbilityKind obj, Int observer_id, Vector<Float> output, Int index):
    output[index] = (float(obj.value) - (float(max(obj)) / 2.0)) / float(max(obj))
    index = index + 1

fun size_as_observation_tensor(AbilityKind kind) -> Int:
    return 1

enum Faction:
    strike_force_octavius
    insidious_infiltrators
    zarkan_daemonkin
    morgrim_butchas

    fun equal(Faction other) -> Bool:
        return self.value == other.value

enum Keyword:
    infantry
    imperium
    terminator
    terminator_squad
    tacticus
    infernus_squad
    character
    captain
    octavius
    psyker
    adeptus_astartes 
    librarian_tantus
    great_devourer
    death_shadow
    vanguard_invader
    neurolictor
    von_ryan_leaper 
    lictor
    tyranids
    chaos_space_marine
    master_of_possession
    aranis_zarkan
    daemon
    possessed
    chaos
    legionaries
    damned
    cultist_mob
    mob
    mounted
    monster_hunters
    beast_snagga
    beastboss
    squighog_boyz
    monster # only implemented for veteran instincts 
    vehicle # only implemented for vetern instincts

    fun equal(Keyword other) -> Bool:
        return self.value == other.value

fun write_in_observation_tensor(Keyword obj, Int observer_id, Vector<Float> output, Int index):
    output[index] = (float(obj.value) - (float(max(obj)) / 2.0)) / float(max(obj))
    index = index + 1

fun size_as_observation_tensor(Keyword kind) -> Int:
    return 1

enum Profile:
    captain_octavius:
        Int movement = 5
        Int thoughness = 5
        Int save = 2
        Int invuln_save = 4
        Int feel_no_pain = 10
        Int wounds = 6
        Int leadership = 6
        Int control = 1
        Float base_size = 50.0
    librarian_tantus:
        Int movement = 5
        Int thoughness = 5
        Int save = 2
        Int invuln_save = 4
        Int feel_no_pain = 10
        Int wounds = 5
        Int leadership = 6
        Int control = 1
        Float base_size = 40.0
    infernus_squad:
        Int movement = 6
        Int thoughness = 4
        Int save = 3
        Int invuln_save = 10
        Int feel_no_pain = 10
        Int wounds = 2
        Int leadership = 6
        Int control = 1
        Float base_size = 32.0
    terminator_squad:
        Int movement = 5
        Int thoughness = 5
        Int save = 2
        Int invuln_save = 4
        Int wounds = 3
        Int leadership = 6
        Int control = 1
        Float base_size = 40.0
    death_shadow:
        Int movement = 8
        Int thoughness = 5
        Int save = 4
        Int invuln_save = 4
        Int feel_no_pain = 10
        Int wounds = 7
        Int leadership = 7
        Int control = 1
        Float base_size = 50.0
    lictor:
        Int movement = 8
        Int thoughness = 6
        Int save = 4
        Int invuln_save = 10
        Int wounds = 6
        Int leadership = 7
        Int control = 1
        Float base_size = 50.0
    von_ryan_leaper:
        Int movement = 10
        Int thoughness = 5
        Int save = 4
        Int invuln_save = 6
        Int feel_no_pain = 10
        Int wounds = 3
        Int leadership = 8
        Int control = 1
        Float base_size = 40.0
    aranis_zarkan:
        Int movement = 8
        Int thoughness = 4
        Int save = 3
        Int invuln_save = 5
        Int wounds = 4
        Int leadership = 6
        Int control = 1
        Float base_size = 40.0
    possessed:
        Int movement = 9
        Int thoughness = 6
        Int save = 3
        Int invuln_save = 5
        Int feel_no_pain = 10
        Int wounds = 3
        Int leadership = 6
        Int control = 1
        Float base_size = 40.0
    legionaries:
        Int movement = 6
        Int thoughness = 4
        Int save = 3
        Int invuln_save = 10
        Int wounds = 2
        Int leadership = 6
        Int control = 2
        Float base_size = 32.0
    cultist_mob:
        Int movement = 6
        Int thoughness = 3
        Int save = 6
        Int invuln_save = 10
        Int feel_no_pain = 10
        Int wounds = 1
        Int leadership = 7
        Int control = 1
        Float base_size = 25.0
    beastboss_morgrim:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int invuln_save = 5
        Int feel_no_pain = 5
        Int wounds = 6
        Int leadership = 6
        Int control = 1
        Float base_size = 50.0
    beast_snagga_boy:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int invuln_save = 10
        Int feel_no_pain = 6
        Int wounds = 2
        Int leadership = 7
        Int control = 2
        Float base_size = 32.0
    beast_snagga_nob:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int invuln_save = 10
        Int wounds = 3    
        Int feel_no_pain = 6
        Int leadership = 7
        Int control = 2
        Float base_size = 32.0
    squighog_boyz:
        Int movement = 10
        Int thoughness = 7
        Int save = 4
        Int invuln_save = 10
        Int feel_no_pain = 5
        Int wounds = 3
        Int leadership = 7
        Int control = 2
        Float base_size = 75.0
    nob_on_smasha_squig:
        Int movement = 10
        Int thoughness = 7
        Int save = 4
        Int invuln_save = 10
        Int feel_no_pain = 5
        Int wounds = 4
        Int leadership = 7
        Int control = 2
        Float base_size = 90.0


    fun equal(Profile other) -> Bool:
        return self.value == other.value

fun write_in_observation_tensor(Profile obj, Int observer_id, Vector<Float> output, Int index):
    output[index] = (float(obj.value) - (float(max(obj)) / 2.0)) / float(max(obj))
    index = index + 1

fun size_as_observation_tensor(Profile kind) -> Int:
    return 1

enum Stratagem:
    reroll:
        Int cost = 1
    overwatch:
        Int cost = 1 
    rapid_ingress:
        Int cost = 1
    insane_bravery:
        Int cost = 1
    veteran_instincts:
        Int cost = 1
    gene_wrought_resiliance:
        Int cost = 1 
    duty_and_honour:
        Int cost = 1 
    heroic_intervention:
        Int cost = 2
    swift_kill:
        Int cost = 1
    pheromone_trace:
        Int cost = 1
    predators_not_prey:
        Int cost = 1
    vindictive_strategy:
        Int cost = 1
    violent_unbidding:
        Int cost = 1
    demonic_fervour:
        Int cost = 1
    tough_as_squig_hide:
        Int cost = 1
    bestial_bellow:
        Int cost = 1

    fun equal(Stratagem other) -> Bool:
        return self.value == other.value
