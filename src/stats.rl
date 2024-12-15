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
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::psychic), weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::devastating_wounds))
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
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::ignore_cover), weapon_rule(WeaponRuleKind::torrent))
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

    fun equal(AbilityKind other) -> Bool:
        return self.value == other.value

fun write_in_observation_tensor(AbilityKind obj, Int observer_id, Vector<Float> output, Int index):
    output[index] = (float(obj.value) - (float(max(obj)) / 2.0)) / float(max(obj))
    index = index + 1

fun size_as_observation_tensor(AbilityKind kind) -> Int:
    return 1

enum Faction:
    strike_force_octavius

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
        Int wounds = 6
        Int leadership = 6
        Int control = 1
        Float base_size = 50.0
    librarian_tantus:
        Int movement = 5
        Int thoughness = 5
        Int save = 2
        Int invuln_save = 4
        Int wounds = 5
        Int leadership = 6
        Int control = 1
        Float base_size = 40.0
    infernus_squad:
        Int movement = 6
        Int thoughness = 4
        Int save = 3
        Int invuln_save = 10
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

    fun equal(Stratagem other) -> Bool:
        return self.value == other.value
