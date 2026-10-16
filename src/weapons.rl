import bounded_arg
import vector2d
import state_types
import keyword_predicates

using Dice = BInt<1, 7>

# Source expressions include D3, D6+6,2D6+2 and3D6+3 (all67 Orks scan).
# Intrinsic constants are part of the characteristic, not modifiers (02.02.03).
cls CompoundDice:
    LinearlyDistributedInt<1, 4> count
    Bool d3
    FixedStat constant

using Stat = FixedStat | Dice | CompoundDice

# Checked construction supports every audited compound expression without
# enlarging the six-face chance payload or summing hidden random values.
fun compound_stat(Int count, Int sides, Int constant) -> Stat:
    assert(count >= 1 and count <= 3 and (sides == 3 or sides == 6) and constant >= 0 and constant < MAX_CHARACTERISTIC, "unsupported dice expression")
    let expression : CompoundDice
    expression.count = count
    expression.d3 = sides == 3
    expression.constant = constant
    let result : Stat
    result = expression
    return result

# Roll-shape queries distinguish original dice from intrinsic constants for
# complete re-rolls and identical attack grouping (01.05.02/02.02.03).
fun stat_dice_count(Stat stat) -> Int:
    if stat is Dice:
        return 1
    if stat is CompoundDice:
        return stat.count.value
    return 0

fun stat_dice_sides(Stat stat) -> Int:
    if stat is Dice:
        return stat.value
    if stat is CompoundDice:
        return 6 - 3 * int(stat.d3)
    return 0

fun stat_intrinsic_constant(Stat stat) -> Int:
    if stat is CompoundDice:
        return stat.constant.value
    return 0

# Restore guard for random M/demise and explicit expression consumers;
# this is bounded-state infrastructure for pp.17/19/33/80.
fun valid_stat(Stat stat) -> Bool:
    if stat is FixedStat:
        return stat.value >= 0 and stat.value < MAX_CHARACTERISTIC
    if stat is Dice:
        return stat.value >= 1 and stat.value <= 6
    if stat is CompoundDice:
        return stat.count.value >= 1 and stat.count.value <= 3 and stat.constant.value >= 0 and stat.constant.value < MAX_CHARACTERISTIC
    return false

# Store a fixed weapon characteristic in a bounded standard type for inferred
# ML layout; supports attack count/damage (pp.17/19). Evaluation fix is task 9.
fun raw_stat(Int value) ->  Stat:
    let to_set : FixedStat
    to_set = value
    let stat : Stat 
    stat = to_set
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
    blast
    lance
    extra_attacks
    assault
    heavy
    melta
    close_quarters
    indirect_fire
    twin_linked
    one_shot
    cleave
    anti
    # Supa-glowy Fing requires two tests; it is distinct from Hazardous.
    supa_hazardous

    fun equal(WeaponRuleKind other) -> Bool:
        return self.value == other.value

fun write_in_observation_tensor(WeaponRuleKind obj, Int observer_id, Vector<Float> output, Int index):
    output[index] = (float(obj.value) - (float(max(obj)) / 2.0)) / float(max(obj))
    index = index + 1

fun size_as_observation_tensor(WeaponRuleKind kind) -> Int:
    return 1

cls WeaponRule:
    # Zero is an intrinsic/manual grant; nonzero belongs to one timed effect.
    SourceEffectKey source_effect
    # Close-range Dakka/Mow improve an existing instance until this key expires.
    SourceEffectKey parameter_increment_source
    FixedStat parameter_increment_amount
    WeaponRuleKind kind
    LinearlyDistributedInt<0, MAX_CHARACTERISTIC> parameter
    # Target predicates preserve adjacent/slash/excluded keyword meaning
    # (p.78; appendix02.05.01). Empty means no additional keyword condition.
    KeywordPredicate target_condition

# Bounded numeric ability metadata supports inferred ML layout; reject unsupported magnitudes (p.78).
fun weapon_rule(WeaponRuleKind kind, Int parameter) -> WeaponRule:
    let rule : WeaponRule
    rule.kind = kind
    assert(parameter >= 0 and parameter < MAX_CHARACTERISTIC, "weapon ability parameter capacity exceeded")
    rule.parameter = parameter
    return rule

# Presence-only abilities have parameter zero and still apply (pp.78–85).
fun weapon_rule(WeaponRuleKind kind) -> WeaponRule:
    let rule : WeaponRule
    rule.kind = kind
    return rule
    

using WeaponRules = Vector<WeaponRule>

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

# Legacy factories contained mixed AP signs. Preserve their magnitudes while
# storing all AP as nonpositive values for the p.19 save-result calculation.
# Literal slash/exclusion rules from these three Orks weapon tables.
# MONSTER/VEHICLE means either; non-MONSTER/VEHICLE excludes both (02.05.01).
# https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss
fun orks_monster_vehicle_rule(WeaponRuleKind kind, Int amount) -> WeaponRule:
    let rule = weapon_rule(kind, amount)
    let keyword : Keyword
    assert(rule.target_condition.append(KeywordClause::any, Keyword::monster.value, max(keyword)), "keyword capacity")
    assert(rule.target_condition.append(KeywordClause::any, Keyword::vehicle.value, max(keyword)), "keyword capacity")
    return rule

# Shoota/Slugga Lethal Hits exclude every unit with either listed keyword.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz
fun orks_non_monster_vehicle_rule(WeaponRuleKind kind, Int amount) -> WeaponRule:
    let rule = weapon_rule(kind, amount)
    let keyword : Keyword
    assert(rule.target_condition.append(KeywordClause::none, Keyword::monster.value, max(keyword)), "keyword capacity")
    assert(rule.target_condition.append(KeywordClause::none, Keyword::vehicle.value, max(keyword)), "keyword capacity")
    return rule

enum Weapon:
    none:
        Int family_id = 0
        StringLiteral label = "None"
        Int range = 0
        Stat attacks = raw_stat(0)
        Int skill = 0
        Int strenght = 0
        Int penetration = 0
        Stat damage = raw_stat(0)
        WeaponRules rules = weapon_rules()

    captain_storm_bolter:
        Int family_id = Weapon::captain_storm_bolter.value
        StringLiteral label = "captain storm bolter"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 2
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2))
    relic_weapon:
        Int family_id = Weapon::relic_weapon.value
        StringLiteral label = "relic weapon"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 5
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::letal_hits), weapon_rule(WeaponRuleKind::precision))
    smite_witchfire:
        Int family_id = Weapon::smite_witchfire.value
        StringLiteral label = "smite witchfire"
        Int range = 24
        Stat attacks = dice_stat(6)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = dice_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::psychic))
    smite_focused_witchfire:
        Int family_id = Weapon::smite_focused_witchfire.value
        StringLiteral label = "smite focused witchfire"
        Int range = 24
        Stat attacks = dice_stat(6)
        Int skill = 3
        Int strenght = 4
        Int penetration = -2
        Stat damage = dice_stat(3)
        WeaponRules rules = weapon_rules(
                        weapon_rule(WeaponRuleKind::psychic), 
                        weapon_rule(WeaponRuleKind::hazardous), 
                        weapon_rule(WeaponRuleKind::devastating_wounds))
    librarian_storm_bolter:
        Int family_id = Weapon::librarian_storm_bolter.value
        StringLiteral label = "librarian storm bolter"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2))
    force_weapon:
        Int family_id = Weapon::force_weapon.value
        StringLiteral label = "force weapon"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 6
        Int penetration = -1
        Stat damage = dice_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::psychic))
    bolt_pistol:
        Int family_id = Weapon::bolt_pistol.value
        StringLiteral label = "bolt pistol"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    pyreblaster:
        Int family_id = Weapon::pyreblaster.value
        StringLiteral label = "pyreblaster"
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
        Int family_id = Weapon::close_combact_weapon.value
        StringLiteral label = "close combact weapon"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    assault_cannon:
        Int family_id = Weapon::assault_cannon.value
        StringLiteral label = "assault cannon"
        Int range = 24
        Stat attacks = raw_stat(6)
        Int skill = 3
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::devastating_wounds))
    terminator_storm_bolter:
        Int family_id = Weapon::terminator_storm_bolter.value
        StringLiteral label = "terminator storm bolter"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2))
    terminator_power_fist:
        Int family_id = Weapon::terminator_power_fist.value
        StringLiteral label = "terminator power fist"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    terminator_power_weapon:
        Int family_id = Weapon::terminator_power_weapon.value
        StringLiteral label = "terminator power weapon"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    death_shadow_claws_and_talons:
        Int family_id = Weapon::death_shadow_claws_and_talons.value
        StringLiteral label = "death shadow claws and talons"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 6
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision))
    lictor_claws_and_talons:
        Int family_id = Weapon::lictor_claws_and_talons.value
        StringLiteral label = "lictor claws and talons"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision))
    leapers_talon:
        Int family_id = Weapon::leapers_talon.value
        StringLiteral label = "leapers talon"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    rite_of_possession:
        Int family_id = Weapon::rite_of_possession.value
        StringLiteral label = "rite of possession"
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
        Int family_id = Weapon::rite_of_possession_focused.value
        StringLiteral label = "rite of possession focused"
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 6
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(
                                weapon_rule(WeaponRuleKind::psychic), 
                                weapon_rule(WeaponRuleKind::hazardous), 
                                weapon_rule(WeaponRuleKind::anti_psychic), 
                                weapon_rule(WeaponRuleKind::pistol), 
                                weapon_rule(WeaponRuleKind::precision))
    staff_of_possession:
        Int family_id = Weapon::staff_of_possession.value
        StringLiteral label = "staff of possession"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 6
        Int penetration = -1
        Stat damage = dice_stat(3)
        WeaponRules rules = weapon_rules(
                                weapon_rule(WeaponRuleKind::psychic), 
                                weapon_rule(WeaponRuleKind::anti_psychic))
    hideous_mutations:
        Int family_id = Weapon::hideous_mutations.value
        StringLiteral label = "hideous mutations"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    boltgun:
        Int family_id = Weapon::boltgun.value
        StringLiteral label = "boltgun"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    heavy_bolter:
        Int family_id = Weapon::heavy_bolter.value
        StringLiteral label = "heavy bolter"
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::heavy),
            weapon_rule(WeaponRuleKind::sustained_hit, 1)
        )
    meltagun:
        Int family_id = Weapon::meltagun.value
        StringLiteral label = "meltagun"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 9
        Int penetration = -4
        Stat damage = dice_stat(6)  
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::melta, 2))
    plasma_pistol_standard:
        Int family_id = Weapon::plasma_pistol_standard.value
        StringLiteral label = "plasma pistol standard"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    plasma_pistol_supercharge:
        Int family_id = Weapon::plasma_pistol_standard.value
        StringLiteral label = "plasma pistol supercharge"
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
        Int family_id = Weapon::accursed_weapon.value
        StringLiteral label = "accursed weapon"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    close_combat_weapon:
        Int family_id = Weapon::close_combat_weapon.value
        StringLiteral label = "close combat weapon"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    cultist_autopistol:
        Int family_id = Weapon::cultist_autopistol.value
        StringLiteral label = "cultist autopistol"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 3
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    cultist_bolt_pistol:
        Int family_id = Weapon::cultist_bolt_pistol.value
        StringLiteral label = "cultist bolt pistol"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    brutal_assault_weapon:
        Int family_id = Weapon::brutal_assault_weapon.value
        StringLiteral label = "brutal assault weapon"
        Int range = 0
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 3
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    beat_boss_shoota:
        Int family_id = Weapon::beat_boss_shoota.value
        StringLiteral label = "beat boss shoota"
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1))
    beast_snagga_klaw:
        Int family_id = Weapon::beast_snagga_klaw.value
        StringLiteral label = "beast snagga klaw"
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
        Int family_id = Weapon::beastchoppa.value
        StringLiteral label = "beastchoppa"
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
        Int family_id = Weapon::slugga.value
        StringLiteral label = "slugga"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    thump_gun:
        Int family_id = Weapon::thump_gun.value
        StringLiteral label = "thump gun"
        Int range = 18
        Stat attacks = dice_stat(3)  
        Int skill = 5
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast))
    choppa:
        Int family_id = Weapon::choppa.value
        StringLiteral label = "choppa"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    power_snappa:
        Int family_id = Weapon::power_snappa.value
        StringLiteral label = "power snappa"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 7
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    saddlegit_weapons:
        Int family_id = Weapon::saddlegit_weapons.value
        StringLiteral label = "saddlegit weapons"
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
        Int family_id = Weapon::stikka_ranged.value
        StringLiteral label = "stikka ranged"
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
        Int family_id = Weapon::big_choppa.value
        StringLiteral label = "big choppa"
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
        Int family_id = Weapon::stikka_melee.value
        StringLiteral label = "stikka melee"
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
        Int family_id = Weapon::squighog_jaws.value
        StringLiteral label = "squighog jaws"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::extra_attacks)
        )
    vaultswords_behemor:
        Int family_id = Weapon::vaultswords_behemor.value
        StringLiteral label = "vaultswords behemor"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision))
    vaultswords_hurricanus:
        Int family_id = Weapon::vaultswords_hurricanus.value
        StringLiteral label = "vaultswords hurricanus"
        Int range = 0
        Stat attacks = raw_stat(9)
        Int skill = 2
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    vaultswords_victus:
        Int family_id = Weapon::vaultswords_victus.value
        StringLiteral label = "vaultswords victus"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 6
        Int penetration = -3
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::devastating_wounds))
    sentinel_blade_ranged:
        Int family_id = Weapon::sentinel_blade_ranged.value
        StringLiteral label = "sentinel blade ranged"
        Int range = 12
        Stat attacks = raw_stat(2)
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::assault),
            weapon_rule(WeaponRuleKind::pistol)
        )
    sentinel_blade_melee:
        Int family_id = Weapon::sentinel_blade_melee.value
        StringLiteral label = "sentinel blade melee"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 6
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    castellan_axe_ranged:
        Int family_id = Weapon::castellan_axe_ranged.value
        StringLiteral label = "castellan axe ranged"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault))
    guardian_spear_ranged:
        Int family_id = Weapon::guardian_spear_ranged.value
        StringLiteral label = "guardian spear ranged"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault))
    castellan_axe_melee:
        Int family_id = Weapon::castellan_axe_melee.value
        StringLiteral label = "castellan axe melee"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 2
        Int strenght = 9
        Int penetration = -1
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()
    guardian_spear_melee:
        Int family_id = Weapon::guardian_spear_melee.value
        StringLiteral label = "guardian spear melee"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    balistus_grenade_launcher:
        Int family_id = Weapon::balistus_grenade_launcher.value
        StringLiteral label = "balistus grenade launcher"
        Int range = 18
        Stat attacks = dice_stat(6)  
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast))

    guardian_spear_ranged_allarus:
        Int family_id = Weapon::guardian_spear_ranged_allarus.value
        StringLiteral label = "guardian spear ranged allarus"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault))

    guardian_spear_melee_allarus:
        Int family_id = Weapon::guardian_spear_melee_allarus.value
        StringLiteral label = "guardian spear melee allarus"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    boltstorm_gauntlet:
        Int family_id = Weapon::boltstorm_gauntlet.value
        StringLiteral label = "boltstorm gauntlet"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    power_fist_zacharial:
        Int family_id = Weapon::power_fist_zacharial.value
        StringLiteral label = "power fist zacharial"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    relic_chainsword:
        Int family_id = Weapon::relic_chainsword.value
        StringLiteral label = "relic chainsword"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::extra_attacks)
        )
    bolt_rifle:
        Int family_id = Weapon::bolt_rifle.value
        StringLiteral label = "bolt rifle"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::assault),
            weapon_rule(WeaponRuleKind::heavy)
        )
    plasma_incinerator_standard:
        Int family_id = Weapon::plasma_incinerator_standard.value
        StringLiteral label = "plasma incinerator standard"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::assault),
            weapon_rule(WeaponRuleKind::heavy)
        )

    plasma_incinerator_supercharge:
        Int family_id = Weapon::plasma_incinerator_standard.value
        StringLiteral label = "plasma incinerator supercharge"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 8
        Int penetration = -3
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(
            weapon_rule(WeaponRuleKind::assault),
            weapon_rule(WeaponRuleKind::hazardous),
            weapon_rule(WeaponRuleKind::heavy)
        )
    heavy_bolt_pistol:
        Int family_id = Weapon::heavy_bolt_pistol.value
        StringLiteral label = "heavy bolt pistol"
        Int range = 18
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))

    master_crafted_power_weapon:
        Int family_id = Weapon::master_crafted_power_weapon.value
        StringLiteral label = "master crafted power weapon"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()


    # Source-backed expression fixtures; current unit/loadout installation is17.P.
    # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
    stompa_supa_gatler_point_blank:
        Int family_id = Weapon::stompa_supa_gatler_point_blank.value
        StringLiteral label = "Supa-gatler - Point Blank"
        Int range = 12
        Stat attacks = compound_stat(3, 6, 3)
        Int skill = 0
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent))
    stompa_deffkannon_and_supa_rokkits:
        Int family_id = Weapon::stompa_deffkannon_and_supa_rokkits.value
        StringLiteral label = "Deffkannon and Supa-rokkits"
        Int range = 72
        Stat attacks = raw_stat(12)
        Int skill = 5
        Int strenght = 14
        Int penetration = -3
        Stat damage = compound_stat(1, 6, 2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2))

    # Current weapon tables for the17.H1 data adapters (not the old variants).
    # https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss
    # https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz
    # https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
    orks_beastboss_shoota:
        Int family_id = Weapon::orks_beastboss_shoota.value
        StringLiteral label = "Shoota"
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))
    orks_beastboss_klaw_and_beastchoppa:
        Int family_id = Weapon::orks_beastboss_klaw_and_beastchoppa.value
        StringLiteral label = "Beast Snagga Klaw and Beastchoppa"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::sustained_hit, 2))
    orks_slugga:
        Int family_id = Weapon::orks_slugga.value
        StringLiteral label = "Slugga"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))
    orks_thump_gun:
        Int family_id = Weapon::orks_thump_gun.value
        StringLiteral label = "Thump Gun"
        Int range = 18
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))
    orks_choppa_standard:
        Int family_id = Weapon::orks_choppa_standard.value
        StringLiteral label = "Choppa - Standard"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    orks_choppa_hunter:
        Int family_id = Weapon::orks_choppa_standard.value
        StringLiteral label = "Choppa - Hunter"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 6
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    orks_power_snappa:
        Int family_id = Weapon::orks_power_snappa.value
        StringLiteral label = "Power Snappa"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))
    orks_saddlegit_shiv:
        Int family_id = Weapon::orks_saddlegit_shiv.value
        StringLiteral label = "Saddlegit’s Shiv"
        Int range = 9
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 3
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault))
    orks_stikka_ranged:
        Int family_id = Weapon::orks_stikka_ranged.value
        StringLiteral label = "Stikka (ranged)"
        Int range = 9
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault), orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))
    orks_big_choppa:
        Int family_id = Weapon::orks_big_choppa.value
        StringLiteral label = "Big Choppa"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 7
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2), orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))
    orks_squig_jaws:
        Int family_id = Weapon::orks_squig_jaws.value
        StringLiteral label = "Squig’s Jaws"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks))
    orks_stikka_melee:
        Int family_id = Weapon::orks_stikka_ranged.value
        StringLiteral label = "Stikka (melee)"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))

    # Additional enhancement weapons use the literal Orks source rows. Prices
    # are omitted; each is a separate physical weapon (Brute Bosses/Wurrband).
    orks_da_gobshot_thunderbuss:
        Int family_id = Weapon::orks_da_gobshot_thunderbuss.value
        StringLiteral label = "Da Gobshot Thunderbuss"
        Int range = 24
        Stat attacks = raw_stat(6)
        Int skill = 4
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0), weapon_rule(WeaponRuleKind::rapid_fire, 6))
    orks_da_krunch:
        Int family_id = Weapon::orks_da_krunch.value
        StringLiteral label = "Da Krunch"
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 3), weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::letal_hits), weapon_rule(WeaponRuleKind::psychic))
    orks_eadbanger:
        Int family_id = Weapon::orks_eadbanger.value
        StringLiteral label = "'Eadbanger"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 6
        Int penetration = -3
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::precision), weapon_rule(WeaponRuleKind::psychic))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
    orks_infantry_big_shoota:
        Int family_id = Weapon::orks_infantry_big_shoota.value
        StringLiteral label = "Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
    orks_burna:
        Int family_id = Weapon::orks_burna.value
        StringLiteral label = "Burna"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_kombi_rokkit_busta:
        Int family_id = Weapon::orks_kombi_rokkit_busta.value
        StringLiteral label = "Kombi-rokkit - Busta Rokkit"
        Int range = 24
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_kombi_rokkit_shoota:
        Int family_id = Weapon::orks_kombi_rokkit_busta.value
        StringLiteral label = "Kombi-rokkit - Shoota"
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_kombi_skorcha_shoota:
        Int family_id = Weapon::orks_kombi_skorcha_shoota.value
        StringLiteral label = "Kombi-skorcha - Shoota"
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_kombi_skorcha_skorcha:
        Int family_id = Weapon::orks_kombi_skorcha_shoota.value
        StringLiteral label = "Kombi-skorcha - Skorcha"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_kustom_shoota:
        Int family_id = Weapon::orks_kustom_shoota.value
        StringLiteral label = "Kustom Shoota"
        Int range = 18
        Stat attacks = raw_stat(4)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_rokkit_launcha_blasta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Blasta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_rokkit_launcha_busta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Busta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Bannernob
    orks_shoota:
        Int family_id = Weapon::orks_beastboss_shoota.value
        StringLiteral label = "Shoota"
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
    orks_infantry_big_choppa:
        Int family_id = Weapon::orks_big_choppa.value
        StringLiteral label = "Big Choppa"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 7
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers
    orks_kustom_choppa:
        Int family_id = Weapon::orks_kustom_choppa.value
        StringLiteral label = "Kustom Choppa"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Stormboyz
    orks_power_klaw:
        Int family_id = Weapon::orks_power_klaw.value
        StringLiteral label = "Power Klaw"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
    orks_big_skorcha:
        Int family_id = Weapon::orks_big_skorcha.value
        StringLiteral label = "Big Skorcha"
        Int range = 18
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
    orks_kustom_big_shoota:
        Int family_id = Weapon::orks_kustom_big_shoota.value
        StringLiteral label = "Kustom Big Shoota"
        Int range = 18
        Stat attacks = raw_stat(8)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
    orks_kustom_krumpa:
        Int family_id = Weapon::orks_kustom_krumpa.value
        StringLiteral label = "Kustom Krumpa"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_warboss_kustom_choppa:
        Int family_id = Weapon::orks_kustom_choppa.value
        StringLiteral label = "Kustom Choppa"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_warboss_power_klaw:
        Int family_id = Weapon::orks_power_klaw.value
        StringLiteral label = "Power Klaw"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Bigboss
    orks_bigboss_big_choppa:
        Int family_id = Weapon::orks_big_choppa.value
        StringLiteral label = "Big Choppa"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers
    orks_dual_kombi_rokkit_dakkagun:
        Int family_id = Weapon::orks_dual_kombi_rokkit_dakkagun.value
        StringLiteral label = "Dual Kombi-rokkit - Dakkagun"
        Int range = 18
        Stat attacks = raw_stat(6)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers
    orks_dual_kombi_rokkit_busta:
        Int family_id = Weapon::orks_dual_kombi_rokkit_dakkagun.value
        StringLiteral label = "Dual Kombi-rokkit - Busta Rokkit"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers
    orks_dual_dakkagun:
        Int family_id = Weapon::orks_dual_dakkagun.value
        StringLiteral label = "Dual Dakkagun"
        Int range = 18
        Stat attacks = raw_stat(6)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_dread_big_shoota:
        Int family_id = Weapon::orks_infantry_big_shoota.value
        StringLiteral label = "Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_kustom_mega_blasta:
        Int family_id = Weapon::orks_kustom_mega_blasta.value
        StringLiteral label = "Kustom Mega-blasta"
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_skorcha:
        Int family_id = Weapon::orks_skorcha.value
        StringLiteral label = "Skorcha"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_extra_klaw:
        Int family_id = Weapon::orks_extra_klaw.value
        StringLiteral label = "Extra Klaw"
        Int range = 0
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_dread_klaws:
        Int family_id = Weapon::orks_dread_klaws.value
        StringLiteral label = "Dread Klaws"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 3
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
    orks_kan_blasta_dakka:
        Int family_id = Weapon::orks_kan_blasta_dakka.value
        StringLiteral label = "Kan Blasta - Dakka"
        Int range = 24
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::sustained_hit, 1), weapon_rule(WeaponRuleKind::ignore_cover))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
    orks_kan_blasta_kill_shot:
        Int family_id = Weapon::orks_kan_blasta_dakka.value
        StringLiteral label = "Kan Blasta - Kill Shot"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
    orks_kan_blasta_point_blank:
        Int family_id = Weapon::orks_kan_blasta_dakka.value
        StringLiteral label = "Kan Blasta - Point Blank"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
    orks_kan_klaw:
        Int family_id = Weapon::orks_kan_klaw.value
        StringLiteral label = "Kan Klaw"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-Dakkarig
    orks_blitzkannon:
        Int family_id = Weapon::orks_blitzkannon.value
        StringLiteral label = "Blitzkannon"
        Int range = 24
        Stat attacks = raw_stat(8)
        Int skill = 4
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::ignore_cover), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-Dakkarig
    orks_multi_busta_launcha:
        Int family_id = Weapon::orks_multi_busta_launcha.value
        StringLiteral label = "Multi-busta Launcha"
        Int range = 24
        Stat attacks = raw_stat(6)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::ignore_cover), weapon_rule(WeaponRuleKind::letal_hits))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-Dakkarig
    orks_stompy_feet:
        Int family_id = Weapon::orks_stompy_feet.value
        StringLiteral label = "Stompy Feet"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur
    orks_beastchoppa_standard:
        Int family_id = Weapon::orks_beastchoppa_standard.value
        StringLiteral label = "Beastchoppa - Standard"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 6
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur
    orks_beastchoppa_hunter:
        Int family_id = Weapon::orks_beastchoppa_standard.value
        StringLiteral label = "Beastchoppa - Hunter"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 12
        Int penetration = -2
        Stat damage = dice_stat(6)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur
    orks_squigosaur_jaws:
        Int family_id = Weapon::orks_squigosaur_jaws.value
        StringLiteral label = "Squigosaur’s Jaws"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks), orks_monster_vehicle_rule(WeaponRuleKind::anti, 3))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad
    orks_big_chompa_jaws:
        Int family_id = Weapon::orks_big_chompa_jaws.value
        StringLiteral label = "Big Chompa’s Jaws"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(4)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks), orks_monster_vehicle_rule(WeaponRuleKind::anti, 3))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad
    orks_gutrippa_standard:
        Int family_id = Weapon::orks_gutrippa_standard.value
        StringLiteral label = "Gutrippa - Standard"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad
    orks_gutrippa_hunter:
        Int family_id = Weapon::orks_gutrippa_standard.value
        StringLiteral label = "Gutrippa - Hunter"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 12
        Int penetration = -2
        Stat damage = compound_stat(1, 6, 1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::letal_hits))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
    orks_flash_gitz_snazzgun_cutta:
        Int family_id = Weapon::orks_flash_gitz_snazzgun_cutta.value
        StringLiteral label = "Snazzgun - Cutta"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 9
        Int penetration = -3
        Stat damage = compound_stat(1, 3, 2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::melta, 2), weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
    orks_flash_gitz_snazzgun_dakka:
        Int family_id = Weapon::orks_flash_gitz_snazzgun_cutta.value
        StringLiteral label = "Snazzgun - Dakka"
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::sustained_hit, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
    orks_flash_gitz_snazzgun_kill_shot:
        Int family_id = Weapon::orks_flash_gitz_snazzgun_cutta.value
        StringLiteral label = "Snazzgun - Kill Shot"
        Int range = 36
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
    orks_flash_gitz_choppa:
        Int family_id = Weapon::orks_choppa_standard.value
        StringLiteral label = "Choppa"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_kombi_weapon_shoota:
        Int family_id = Weapon::orks_meganobz_kombi_weapon_shoota.value
        StringLiteral label = "Kombi-weapon - Shoota"
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_kombi_weapon_kill_shot:
        Int family_id = Weapon::orks_meganobz_kombi_weapon_shoota.value
        StringLiteral label = "Kombi-weapon - Kill Shot"
        Int range = 24
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_kombi_weapon_point_blank:
        Int family_id = Weapon::orks_meganobz_kombi_weapon_shoota.value
        StringLiteral label = "Kombi-weapon - Point Blank"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_kustom_shoota_aimed:
        Int family_id = Weapon::orks_kustom_shoota.value
        StringLiteral label = "Kustom Shoota - Aimed"
        Int range = 18
        Stat attacks = raw_stat(4)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_kustom_shoota_point_blank:
        Int family_id = Weapon::orks_kustom_shoota.value
        StringLiteral label = "Kustom Shoota - Point Blank"
        Int range = 6
        Stat attacks = compound_stat(1, 3, 3)
        Int skill = 0
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent), weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_killsaw:
        Int family_id = Weapon::orks_meganobz_killsaw.value
        StringLiteral label = "Killsaw"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_power_klaw:
        Int family_id = Weapon::orks_power_klaw.value
        StringLiteral label = "Power Klaw"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_twin_killsaws:
        Int family_id = Weapon::orks_meganobz_twin_killsaws.value
        StringLiteral label = "Twin Killsaws"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::twin_linked))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek
    orks_mek_kustom_mega_slugga:
        Int family_id = Weapon::orks_mek_kustom_mega_slugga.value
        StringLiteral label = "Kustom Mega-slugga"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek
    orks_mek_mek_s_toolz:
        Int family_id = Weapon::orks_mek_mek_s_toolz.value
        StringLiteral label = "Mek’s Toolz"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
    orks_big_mek_kustom_mega_blasta:
        Int family_id = Weapon::orks_kustom_mega_blasta.value
        StringLiteral label = "Kustom Mega-blasta"
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
    orks_big_mek_traktor_blasta:
        Int family_id = Weapon::orks_big_mek_traktor_blasta.value
        StringLiteral label = "Traktor Blasta"
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = -2
        Stat damage = compound_stat(1, 3, 3)
        WeaponRules rules = weapon_rules(conditional_weapon_rule(WeaponRuleKind::anti, 2, Keyword::fly))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
    orks_big_mek_drilla:
        Int family_id = Weapon::orks_big_mek_drilla.value
        StringLiteral label = "Drilla"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 12
        Int penetration = -3
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
    orks_big_mek_power_klaw:
        Int family_id = Weapon::orks_power_klaw.value
        StringLiteral label = "Power Klaw"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kombi_weapon_shoota:
        Int family_id = Weapon::orks_meganobz_kombi_weapon_shoota.value
        StringLiteral label = "Kombi-weapon - Shoota"
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kombi_weapon_kill_shot:
        Int family_id = Weapon::orks_meganobz_kombi_weapon_shoota.value
        StringLiteral label = "Kombi-weapon - Kill Shot"
        Int range = 24
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kombi_weapon_point_blank:
        Int family_id = Weapon::orks_meganobz_kombi_weapon_shoota.value
        StringLiteral label = "Kombi-weapon - Point Blank"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kustom_mega_blasta:
        Int family_id = Weapon::orks_kustom_mega_blasta.value
        StringLiteral label = "Kustom Mega-blasta"
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kustom_shoota_aimed:
        Int family_id = Weapon::orks_kustom_shoota.value
        StringLiteral label = "Kustom Shoota - Aimed"
        Int range = 18
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kustom_shoota_point_blank:
        Int family_id = Weapon::orks_kustom_shoota.value
        StringLiteral label = "Kustom Shoota - Point Blank"
        Int range = 6
        Stat attacks = compound_stat(1, 3, 3)
        Int skill = 0
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent), weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_tellyport_blasta:
        Int family_id = Weapon::orks_big_mek_in_mega_armour_tellyport_blasta.value
        StringLiteral label = "Tellyport Blasta"
        Int range = 12
        Stat attacks = raw_stat(6)
        Int skill = 4
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_killsaw:
        Int family_id = Weapon::orks_meganobz_killsaw.value
        StringLiteral label = "Killsaw"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_power_klaw:
        Int family_id = Weapon::orks_power_klaw.value
        StringLiteral label = "Power Klaw"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun
    orks_big_mek_with_shokk_attack_gun_shokk_attack_gun:
        Int family_id = Weapon::orks_big_mek_with_shokk_attack_gun_shokk_attack_gun.value
        StringLiteral label = "Shokk Attack Gun"
        Int range = 60
        Stat attacks = compound_stat(1, 3, 3)
        Int skill = 5
        Int strenght = 12
        Int penetration = -4
        Stat damage = compound_stat(1, 6, 1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::heavy))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun
    orks_big_mek_with_shokk_attack_gun_big_mek_s_toolz:
        Int family_id = Weapon::orks_big_mek_with_shokk_attack_gun_big_mek_s_toolz.value
        StringLiteral label = "Big Mek’s Toolz"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Painboy
    orks_painboy_urty_syringe:
        Int family_id = Weapon::orks_painboy_urty_syringe.value
        StringLiteral label = "’Urty Syringe"
        Int range = 0
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 2
        Int penetration = 0
        Stat damage = compound_stat(1, 6, 0)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks), conditional_weapon_rule(WeaponRuleKind::anti, 4, Keyword::infantry), conditional_weapon_rule(WeaponRuleKind::devastating_wounds, 0, Keyword::infantry))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Painboy
    orks_painboy_dok_s_toolz:
        Int family_id = Weapon::orks_painboy_dok_s_toolz.value
        StringLiteral label = "Dok’s Toolz"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Painboss
    orks_painboss_beast_snagga_klaw:
        Int family_id = Weapon::orks_painboss_beast_snagga_klaw.value
        StringLiteral label = "Beast Snagga Klaw"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_rokkit_pistol:
        Int family_id = Weapon::orks_breaka_boyz_rokkit_pistol.value
        StringLiteral label = "Rokkit Pistol"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_smash_hammer_standard:
        Int family_id = Weapon::orks_breaka_boyz_smash_hammer_standard.value
        StringLiteral label = "Smash Hammer - Standard"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_smash_hammer_hunter:
        Int family_id = Weapon::orks_breaka_boyz_smash_hammer_standard.value
        StringLiteral label = "Smash Hammer - Hunter"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_choppa:
        Int family_id = Weapon::orks_choppa_standard.value
        StringLiteral label = "Choppa"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_knucklebustas:
        Int family_id = Weapon::orks_breaka_boyz_knucklebustas.value
        StringLiteral label = "Knucklebustas"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_tankhammer:
        Int family_id = Weapon::orks_breaka_boyz_tankhammer.value
        StringLiteral label = "Tankhammer"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::devastating_wounds))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_busta_rokkit_launcha_standard:
        Int family_id = Weapon::orks_tankbustas_busta_rokkit_launcha_standard.value
        StringLiteral label = "Busta Rokkit Launcha - Standard"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_busta_rokkit_launcha_hunter:
        Int family_id = Weapon::orks_tankbustas_busta_rokkit_launcha_standard.value
        StringLiteral label = "Busta Rokkit Launcha - Hunter"
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_rokkit_pistol:
        Int family_id = Weapon::orks_breaka_boyz_rokkit_pistol.value
        StringLiteral label = "Rokkit Pistol"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_choppa:
        Int family_id = Weapon::orks_choppa_standard.value
        StringLiteral label = "Choppa"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_gitstikka:
        Int family_id = Weapon::orks_tankbustas_gitstikka.value
        StringLiteral label = "Gitstikka"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_smash_hammer_standard:
        Int family_id = Weapon::orks_breaka_boyz_smash_hammer_standard.value
        StringLiteral label = "Smash Hammer - Standard"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_smash_hammer_hunter:
        Int family_id = Weapon::orks_breaka_boyz_smash_hammer_standard.value
        StringLiteral label = "Smash Hammer - Hunter"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
    orks_warboss_in_mega_armour_big_shoota:
        Int family_id = Weapon::orks_infantry_big_shoota.value
        StringLiteral label = "Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
    orks_warboss_in_mega_armour_uge_choppa:
        Int family_id = Weapon::orks_warboss_in_mega_armour_uge_choppa.value
        StringLiteral label = "’Uge Choppa"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
    orks_gretchin_grot_blasta:
        Int family_id = Weapon::orks_gretchin_grot_blasta.value
        StringLiteral label = "Grot Blasta"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 3
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
    orks_gretchin_scavenged_shivs:
        Int family_id = Weapon::orks_gretchin_scavenged_shivs.value
        StringLiteral label = "Scavenged Shivs"
        Int range = 0
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 2
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
    orks_runtherd_slugga:
        Int family_id = Weapon::orks_slugga.value
        StringLiteral label = "Slugga"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
    orks_runtherd_runtherd_s_toolz:
        Int family_id = Weapon::orks_runtherd_runtherd_s_toolz.value
        StringLiteral label = "Runtherd’s Toolz"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga
    orks_zodgrod_wortsnagga_squigstoppa:
        Int family_id = Weapon::orks_zodgrod_wortsnagga_squigstoppa.value
        StringLiteral label = "Squigstoppa"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters), orks_monster_vehicle_rule(WeaponRuleKind::anti, 4), orks_monster_vehicle_rule(WeaponRuleKind::devastating_wounds, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga
    orks_zodgrod_wortsnagga_da_grabzappa:
        Int family_id = Weapon::orks_zodgrod_wortsnagga_da_grabzappa.value
        StringLiteral label = "Da Grabzappa"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon
    orks_battlewagon_big_shoota:
        Int family_id = Weapon::orks_infantry_big_shoota.value
        StringLiteral label = "Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon
    orks_battlewagon_crushin_bulk:
        Int family_id = Weapon::orks_battlewagon_crushin_bulk.value
        StringLiteral label = "Crushin’ Bulk"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 3
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon
    orks_battlewagon_grabbin_klaw:
        Int family_id = Weapon::orks_battlewagon_grabbin_klaw.value
        StringLiteral label = "Grabbin’ Klaw"
        Int range = 0
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon
    orks_battlewagon_wreckin_ball:
        Int family_id = Weapon::orks_battlewagon_wreckin_ball.value
        StringLiteral label = "Wreckin’ Ball"
        Int range = 0
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 10
        Int penetration = 0
        Stat damage = compound_stat(1, 6, 0)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2), weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
    orks_big_ed_bossbunka_big_shoota:
        Int family_id = Weapon::orks_infantry_big_shoota.value
        StringLiteral label = "Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
    orks_big_ed_bossbunka_gaze_of_gork_glare:
        Int family_id = Weapon::orks_big_ed_bossbunka_gaze_of_gork_glare.value
        StringLiteral label = "Gaze of Gork - Glare"
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
    orks_big_ed_bossbunka_gaze_of_gork_squint:
        Int family_id = Weapon::orks_big_ed_bossbunka_gaze_of_gork_glare.value
        StringLiteral label = "Gaze of Gork - Squint"
        Int range = 18
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 12
        Int penetration = -3
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer
    orks_blitza_bommer_big_shoota:
        Int family_id = Weapon::orks_infantry_big_shoota.value
        StringLiteral label = "Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer
    orks_blitza_bommer_dual_supa_shoota:
        Int family_id = Weapon::orks_blitza_bommer_dual_supa_shoota.value
        StringLiteral label = "Dual Supa-shoota"
        Int range = 36
        Stat attacks = raw_stat(8)
        Int skill = 5
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 4), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer
    orks_blitza_bommer_armoured_impact:
        Int family_id = Weapon::orks_blitza_bommer_armoured_impact.value
        StringLiteral label = "Armoured Impact"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Boss-Snikrot
    orks_boss_snikrot_slugga:
        Int family_id = Weapon::orks_slugga.value
        StringLiteral label = "Slugga"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters), weapon_rule(WeaponRuleKind::precision), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Boss-Snikrot
    orks_boss_snikrot_mork_s_teef:
        Int family_id = Weapon::orks_boss_snikrot_mork_s_teef.value
        StringLiteral label = "Mork’s Teef"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 6
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision), conditional_weapon_rule(WeaponRuleKind::anti, 2, Keyword::infantry))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer
    orks_burna_bommer_dual_big_shoota:
        Int family_id = Weapon::orks_burna_bommer_dual_big_shoota.value
        StringLiteral label = "Dual Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(6)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 4), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer
    orks_burna_bommer_dual_supa_shoota:
        Int family_id = Weapon::orks_blitza_bommer_dual_supa_shoota.value
        StringLiteral label = "Dual Supa-shoota"
        Int range = 36
        Stat attacks = raw_stat(8)
        Int skill = 5
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 4), weapon_rule(WeaponRuleKind::sustained_hit, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer
    orks_burna_bommer_skorcha_missile_rack:
        Int family_id = Weapon::orks_burna_bommer_skorcha_missile_rack.value
        StringLiteral label = "Skorcha Missile Rack"
        Int range = 36
        Stat attacks = raw_stat(6)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2), weapon_rule(WeaponRuleKind::ignore_cover))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer
    orks_burna_bommer_armoured_impact:
        Int family_id = Weapon::orks_blitza_bommer_armoured_impact.value
        StringLiteral label = "Armoured Impact"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Dakkajet
    orks_dakkajet_dual_supa_shoota:
        Int family_id = Weapon::orks_blitza_bommer_dual_supa_shoota.value
        StringLiteral label = "Dual Supa-shoota"
        Int range = 36
        Stat attacks = raw_stat(8)
        Int skill = 5
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 4), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Dakkajet
    orks_dakkajet_armoured_impact:
        Int family_id = Weapon::orks_blitza_bommer_armoured_impact.value
        StringLiteral label = "Armoured Impact"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
    orks_deffkilla_wartrike_boomstikks:
        Int family_id = Weapon::orks_deffkilla_wartrike_boomstikks.value
        StringLiteral label = "Boomstikks"
        Int range = 12
        Stat attacks = raw_stat(6)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
    orks_deffkilla_wartrike_snagga_klaw_ranged:
        Int family_id = Weapon::orks_deffkilla_wartrike_snagga_klaw_ranged.value
        StringLiteral label = "Snagga Klaw (ranged)"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision), weapon_rule(WeaponRuleKind::assault))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
    orks_deffkilla_wartrike_killa_jet_burna:
        Int family_id = Weapon::orks_deffkilla_wartrike_killa_jet_burna.value
        StringLiteral label = "Killa Jet - Burna"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1), weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
    orks_deffkilla_wartrike_killa_jet_cutta:
        Int family_id = Weapon::orks_deffkilla_wartrike_killa_jet_burna.value
        StringLiteral label = "Killa Jet - Cutta"
        Int range = 0
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 10
        Int penetration = -3
        Stat damage = compound_stat(1, 6, 2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
    orks_deffkilla_wartrike_snagga_klaw_melee:
        Int family_id = Weapon::orks_deffkilla_wartrike_snagga_klaw_ranged.value
        StringLiteral label = "Snagga Klaw (melee)"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
    orks_deffkoptas_rokkit_launcha_blasta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Blasta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
    orks_deffkoptas_rokkit_launcha_busta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Busta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::letal_hits))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
    orks_deffkoptas_kustom_mega_blasta:
        Int family_id = Weapon::orks_kustom_mega_blasta.value
        StringLiteral label = "Kustom Mega-blasta"
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::letal_hits))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
    orks_deffkoptas_slugga:
        Int family_id = Weapon::orks_slugga.value
        StringLiteral label = "Slugga"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
    orks_deffkoptas_choppa:
        Int family_id = Weapon::orks_choppa_standard.value
        StringLiteral label = "Choppa"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
    orks_deffkoptas_spinnin_blades:
        Int family_id = Weapon::orks_deffkoptas_spinnin_blades.value
        StringLiteral label = "Spinnin’ Blades"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1), weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
    orks_ghazghkull_thraka_mork_s_roar_aimed:
        Int family_id = Weapon::orks_ghazghkull_thraka_mork_s_roar_aimed.value
        StringLiteral label = "Mork’s Roar - Aimed"
        Int range = 36
        Stat attacks = raw_stat(12)
        Int skill = 5
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 4), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
    orks_ghazghkull_thraka_mork_s_roar_point_blank:
        Int family_id = Weapon::orks_ghazghkull_thraka_mork_s_roar_aimed.value
        StringLiteral label = "Mork’s Roar - Point Blank"
        Int range = 9
        Stat attacks = compound_stat(2, 6, 2)
        Int skill = 0
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent), weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
    orks_ghazghkull_thraka_adamantine_eadbutt:
        Int family_id = Weapon::orks_ghazghkull_thraka_adamantine_eadbutt.value
        StringLiteral label = "Adamantine ’Eadbutt"
        Int range = 0
        Stat attacks = raw_stat(1)
        Int skill = 2
        Int strenght = 14
        Int penetration = -2
        Stat damage = compound_stat(1, 3, 3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks), weapon_rule(WeaponRuleKind::precision), weapon_rule(WeaponRuleKind::devastating_wounds))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
    orks_ghazghkull_thraka_gork_s_klaw:
        Int family_id = Weapon::orks_ghazghkull_thraka_gork_s_klaw.value
        StringLiteral label = "Gork’s Klaw"
        Int range = 0
        Stat attacks = raw_stat(7)
        Int skill = 2
        Int strenght = 14
        Int penetration = -3
        Stat damage = raw_stat(4)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2), weapon_rule(WeaponRuleKind::devastating_wounds))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
    orks_gorkanaut_deffstorm_mega_shoota_aimed:
        Int family_id = Weapon::orks_gorkanaut_deffstorm_mega_shoota_aimed.value
        StringLiteral label = "Deffstorm Mega-shoota - Aimed"
        Int range = 36
        Stat attacks = raw_stat(20)
        Int skill = 5
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
    orks_gorkanaut_deffstorm_mega_shoota_point_blank:
        Int family_id = Weapon::orks_gorkanaut_deffstorm_mega_shoota_aimed.value
        StringLiteral label = "Deffstorm Mega-shoota - Point Blank"
        Int range = 12
        Stat attacks = compound_stat(3, 6, 0)
        Int skill = 0
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
    orks_gorkanaut_dual_big_shoota:
        Int family_id = Weapon::orks_burna_bommer_dual_big_shoota.value
        StringLiteral label = "Dual Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(6)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 4), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
    orks_gorkanaut_rokkit_launcha_blasta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Blasta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
    orks_gorkanaut_rokkit_launcha_busta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Busta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
    orks_gorkanaut_skorcha:
        Int family_id = Weapon::orks_skorcha.value
        StringLiteral label = "Skorcha"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
    orks_gorkanaut_klaw_of_gork:
        Int family_id = Weapon::orks_gorkanaut_klaw_of_gork.value
        StringLiteral label = "Klaw of Gork"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 3
        Int strenght = 18
        Int penetration = -3
        Stat damage = raw_stat(6)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 3))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
    orks_gunwagon_big_shoota:
        Int family_id = Weapon::orks_infantry_big_shoota.value
        StringLiteral label = "Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
    orks_gunwagon_kannon_frag:
        Int family_id = Weapon::orks_gunwagon_kannon_frag.value
        StringLiteral label = "Kannon - frag"
        Int range = 36
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 4), weapon_rule(WeaponRuleKind::blast, 3))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
    orks_gunwagon_kannon_shell:
        Int family_id = Weapon::orks_gunwagon_kannon_frag.value
        StringLiteral label = "Kannon - shell"
        Int range = 36
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = compound_stat(1, 6, 1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
    orks_gunwagon_killkannon:
        Int family_id = Weapon::orks_gunwagon_killkannon.value
        StringLiteral label = "Killkannon"
        Int range = 24
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 6
        Int penetration = -3
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 4), weapon_rule(WeaponRuleKind::blast, 1), conditional_weapon_rule(WeaponRuleKind::anti, 3, Keyword::infantry))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
    orks_gunwagon_lobba:
        Int family_id = Weapon::orks_gunwagon_lobba.value
        StringLiteral label = "Lobba"
        Int range = 48
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 3), weapon_rule(WeaponRuleKind::indirect_fire))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
    orks_gunwagon_zzap_gun:
        Int family_id = Weapon::orks_gunwagon_zzap_gun.value
        StringLiteral label = "Zzap Gun"
        Int range = 36
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(4)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), weapon_rule(WeaponRuleKind::sustained_hit, 2), orks_monster_vehicle_rule(WeaponRuleKind::anti, 4), orks_monster_vehicle_rule(WeaponRuleKind::devastating_wounds, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
    orks_gunwagon_crushin_bulk:
        Int family_id = Weapon::orks_battlewagon_crushin_bulk.value
        StringLiteral label = "Crushin’ Bulk"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 3
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
    orks_gunwagon_grabbin_klaw:
        Int family_id = Weapon::orks_battlewagon_grabbin_klaw.value
        StringLiteral label = "Grabbin’ Klaw"
        Int range = 0
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
    orks_gunwagon_wreckin_ball:
        Int family_id = Weapon::orks_battlewagon_wreckin_ball.value
        StringLiteral label = "Wreckin’ Ball"
        Int range = 0
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 10
        Int penetration = 0
        Stat damage = compound_stat(1, 6, 0)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2), weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
    orks_hunta_rig_eavy_lobba:
        Int family_id = Weapon::orks_hunta_rig_eavy_lobba.value
        StringLiteral label = "’Eavy Lobba"
        Int range = 48
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2), weapon_rule(WeaponRuleKind::indirect_fire))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
    orks_hunta_rig_stikka_kannon:
        Int family_id = Weapon::orks_hunta_rig_stikka_kannon.value
        StringLiteral label = "Stikka Kannon"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
    orks_hunta_rig_butcha_boyz:
        Int family_id = Weapon::orks_hunta_rig_butcha_boyz.value
        StringLiteral label = "Butcha Boyz"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
    orks_hunta_rig_savage_horns_and_hooves:
        Int family_id = Weapon::orks_hunta_rig_savage_horns_and_hooves.value
        StringLiteral label = "Savage Horns and Hooves"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 8
        Int penetration = -1
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks), weapon_rule(WeaponRuleKind::lance))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
    orks_hunta_rig_saw_blades:
        Int family_id = Weapon::orks_hunta_rig_saw_blades.value
        StringLiteral label = "Saw Blades"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1), weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
    orks_kill_rig_eavy_lobba:
        Int family_id = Weapon::orks_hunta_rig_eavy_lobba.value
        StringLiteral label = "’Eavy Lobba"
        Int range = 48
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2), weapon_rule(WeaponRuleKind::indirect_fire))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
    orks_kill_rig_stikka_kannon:
        Int family_id = Weapon::orks_hunta_rig_stikka_kannon.value
        StringLiteral label = "Stikka Kannon"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
    orks_kill_rig_wurrtower:
        Int family_id = Weapon::orks_kill_rig_wurrtower.value
        StringLiteral label = "Wurrtower"
        Int range = 24
        Stat attacks = raw_stat(1)
        Int skill = 0
        Int strenght = 12
        Int penetration = -3
        Stat damage = raw_stat(6)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent), weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::psychic))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
    orks_kill_rig_butcha_boyz:
        Int family_id = Weapon::orks_hunta_rig_butcha_boyz.value
        StringLiteral label = "Butcha Boyz"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks), orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
    orks_kill_rig_savage_horns_and_hooves:
        Int family_id = Weapon::orks_hunta_rig_savage_horns_and_hooves.value
        StringLiteral label = "Savage Horns and Hooves"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 8
        Int penetration = -1
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks), weapon_rule(WeaponRuleKind::lance))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
    orks_kill_rig_saw_blades:
        Int family_id = Weapon::orks_hunta_rig_saw_blades.value
        StringLiteral label = "Saw Blades"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1), weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    orks_kommandos_burna:
        Int family_id = Weapon::orks_burna.value
        StringLiteral label = "Burna"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    orks_kommandos_kustom_shoota:
        Int family_id = Weapon::orks_kustom_shoota.value
        StringLiteral label = "Kustom Shoota"
        Int range = 18
        Stat attacks = raw_stat(4)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    orks_kommandos_rokkit_launcha_blasta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Blasta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    orks_kommandos_rokkit_launcha_busta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Busta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    orks_kommandos_slugga:
        Int family_id = Weapon::orks_slugga.value
        StringLiteral label = "Slugga"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    orks_kommandos_big_choppa:
        Int family_id = Weapon::orks_big_choppa.value
        StringLiteral label = "Big Choppa"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 7
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    orks_kommandos_breacha_ram:
        Int family_id = Weapon::orks_kommandos_breacha_ram.value
        StringLiteral label = "Breacha Ram"
        Int range = 0
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    orks_kommandos_choppa:
        Int family_id = Weapon::orks_choppa_standard.value
        StringLiteral label = "Choppa"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    orks_kommandos_power_klaw:
        Int family_id = Weapon::orks_power_klaw.value
        StringLiteral label = "Power Klaw"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
    orks_mek_gunz_smasha_gun:
        Int family_id = Weapon::orks_mek_gunz_smasha_gun.value
        StringLiteral label = "Smasha Gun"
        Int range = 48
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 7
        Int penetration = -3
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
    orks_mek_gunz_bubblechukka:
        Int family_id = Weapon::orks_mek_gunz_bubblechukka.value
        StringLiteral label = "Bubblechukka"
        Int range = 48
        Stat attacks = raw_stat(8)
        Int skill = 4
        Int strenght = 3
        Int penetration = -3
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 3), weapon_rule(WeaponRuleKind::letal_hits))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
    orks_mek_gunz_kustom_mega_kannon:
        Int family_id = Weapon::orks_mek_gunz_kustom_mega_kannon.value
        StringLiteral label = "Kustom Mega-kannon"
        Int range = 36
        Stat attacks = compound_stat(1, 3, 1)
        Int skill = 4
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(4)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
    orks_mek_gunz_traktor_kannon:
        Int family_id = Weapon::orks_mek_gunz_traktor_kannon.value
        StringLiteral label = "Traktor Kannon"
        Int range = 48
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 6
        Int penetration = -2
        Stat damage = compound_stat(1, 3, 3)
        WeaponRules rules = weapon_rules(conditional_weapon_rule(WeaponRuleKind::anti, 2, Keyword::fly))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
    orks_mek_gunz_scavenged_shivs:
        Int family_id = Weapon::orks_gretchin_scavenged_shivs.value
        StringLiteral label = "Scavenged Shivs"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 5
        Int strenght = 2
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
    orks_morkanaut_dual_big_shoota:
        Int family_id = Weapon::orks_burna_bommer_dual_big_shoota.value
        StringLiteral label = "Dual Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(6)
        Int skill = 4
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 4), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
    orks_morkanaut_kustom_mega_blasta:
        Int family_id = Weapon::orks_kustom_mega_blasta.value
        StringLiteral label = "Kustom Mega-blasta"
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
    orks_morkanaut_kustom_mega_zappa:
        Int family_id = Weapon::orks_morkanaut_kustom_mega_zappa.value
        StringLiteral label = "Kustom Mega-zappa"
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(4)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
    orks_morkanaut_rokkit_launcha_blasta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Blasta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
    orks_morkanaut_rokkit_launcha_busta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Busta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
    orks_morkanaut_klaw_of_mork:
        Int family_id = Weapon::orks_morkanaut_klaw_of_mork.value
        StringLiteral label = "Klaw of Mork"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 3
        Int strenght = 18
        Int penetration = -3
        Stat damage = raw_stat(6)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
    orks_nazdreg_kustom_blasta_x_gatler:
        Int family_id = Weapon::orks_nazdreg_kustom_blasta_x_gatler.value
        StringLiteral label = "Kustom Blasta X - Gatler"
        Int range = 24
        Stat attacks = raw_stat(6)
        Int skill = 4
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
    orks_nazdreg_kustom_blasta_x_shoota:
        Int family_id = Weapon::orks_nazdreg_kustom_blasta_x_gatler.value
        StringLiteral label = "Kustom Blasta X - Shoota"
        Int range = 18
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
    orks_nazdreg_kustom_blasta_x_skorcha:
        Int family_id = Weapon::orks_nazdreg_kustom_blasta_x_gatler.value
        StringLiteral label = "Kustom Blasta X - Skorcha"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
    orks_nazdreg_kustom_blasta_x:
        Int family_id = Weapon::orks_nazdreg_kustom_blasta_x_gatler.value
        StringLiteral label = "Kustom Blasta X"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1), weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
    orks_nazdreg_moonchewa:
        Int family_id = Weapon::orks_nazdreg_moonchewa.value
        StringLiteral label = "Moonchewa"
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1), weapon_rule(WeaponRuleKind::twin_linked))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies
    orks_rukkatrukk_squigbuggies_sawn_off_shotgun:
        Int family_id = Weapon::orks_rukkatrukk_squigbuggies_sawn_off_shotgun.value
        StringLiteral label = "Sawn-off Shotgun"
        Int range = 12
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies
    orks_rukkatrukk_squigbuggies_squig_launchas:
        Int family_id = Weapon::orks_rukkatrukk_squigbuggies_squig_launchas.value
        StringLiteral label = "Squig Launchas"
        Int range = 24
        Stat attacks = compound_stat(1, 6, 6)
        Int skill = 4
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::ignore_cover))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies
    orks_rukkatrukk_squigbuggies_saw_blades:
        Int family_id = Weapon::orks_hunta_rig_saw_blades.value
        StringLiteral label = "Saw Blades"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 7
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
    orks_stompa_big_shoota:
        Int family_id = Weapon::orks_infantry_big_shoota.value
        StringLiteral label = "Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
    orks_stompa_deffkannon_and_supa_rokkits:
        Int family_id = Weapon::stompa_deffkannon_and_supa_rokkits.value
        StringLiteral label = "Deffkannon and Supa-rokkits"
        Int range = 72
        Stat attacks = raw_stat(12)
        Int skill = 5
        Int strenght = 14
        Int penetration = -3
        Stat damage = compound_stat(1, 6, 2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
    orks_stompa_skorcha:
        Int family_id = Weapon::orks_skorcha.value
        StringLiteral label = "Skorcha"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
    orks_stompa_supa_gatler_aimed:
        Int family_id = Weapon::stompa_supa_gatler_point_blank.value
        StringLiteral label = "Supa-gatler - Aimed"
        Int range = 24
        Stat attacks = raw_stat(30)
        Int skill = 5
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::sustained_hit, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
    orks_stompa_supa_gatler_point_blank:
        Int family_id = Weapon::stompa_supa_gatler_point_blank.value
        StringLiteral label = "Supa-gatler - Point Blank"
        Int range = 12
        Stat attacks = compound_stat(3, 6, 3)
        Int skill = 0
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
    orks_stompa_mega_choppa:
        Int family_id = Weapon::orks_stompa_mega_choppa.value
        StringLiteral label = "Mega-choppa"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 3
        Int strenght = 24
        Int penetration = -4
        Stat damage = raw_stat(10)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 4))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
    orks_trukk_dual_big_shoota:
        Int family_id = Weapon::orks_burna_bommer_dual_big_shoota.value
        StringLiteral label = "Dual Big Shoota"
        Int range = 36
        Stat attacks = raw_stat(6)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 4), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
    orks_trukk_rokkit_launcha_blasta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Blasta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
    orks_trukk_rokkit_launcha_busta:
        Int family_id = Weapon::orks_rokkit_launcha_blasta.value
        StringLiteral label = "Rokkit Launcha - Busta"
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
    orks_trukk_buzzsaw:
        Int family_id = Weapon::orks_trukk_buzzsaw.value
        StringLiteral label = "Buzzsaw"
        Int range = 0
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1), weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
    orks_trukk_grabbin_klaw:
        Int family_id = Weapon::orks_battlewagon_grabbin_klaw.value
        StringLiteral label = "Grabbin’ Klaw"
        Int range = 0
        Stat attacks = raw_stat(2)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
    orks_trukk_spiked_ram:
        Int family_id = Weapon::orks_trukk_spiked_ram.value
        StringLiteral label = "Spiked Ram"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
    orks_warbuggies_extra_dakka:
        Int family_id = Weapon::orks_warbuggies_extra_dakka.value
        StringLiteral label = "Extra Dakka"
        Int range = 12
        Stat attacks = raw_stat(4)
        Int skill = 5
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::sustained_hit, 1), weapon_rule(WeaponRuleKind::assault), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
    orks_warbuggies_rivet_kannon_aimed:
        Int family_id = Weapon::orks_warbuggies_rivet_kannon_aimed.value
        StringLiteral label = "Rivet Kannon - Aimed"
        Int range = 24
        Stat attacks = raw_stat(6)
        Int skill = 4
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault), conditional_weapon_rule(WeaponRuleKind::anti, 4, Keyword::infantry), conditional_weapon_rule(WeaponRuleKind::devastating_wounds, 0, Keyword::infantry))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
    orks_warbuggies_rivet_kannon_point_blank:
        Int family_id = Weapon::orks_warbuggies_rivet_kannon_aimed.value
        StringLiteral label = "Rivet Kannon - Point Blank"
        Int range = 6
        Stat attacks = compound_stat(1, 3, 1)
        Int skill = 0
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent), weapon_rule(WeaponRuleKind::assault), conditional_weapon_rule(WeaponRuleKind::anti, 4, Keyword::infantry), conditional_weapon_rule(WeaponRuleKind::devastating_wounds, 0, Keyword::infantry))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
    orks_warbuggies_mek_speshul_aimed:
        Int family_id = Weapon::orks_warbuggies_mek_speshul_aimed.value
        StringLiteral label = "Mek Speshul - Aimed"
        Int range = 24
        Stat attacks = raw_stat(14)
        Int skill = 4
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::sustained_hit, 1), weapon_rule(WeaponRuleKind::assault), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
    orks_warbuggies_mek_speshul_point_blank:
        Int family_id = Weapon::orks_warbuggies_mek_speshul_aimed.value
        StringLiteral label = "Mek Speshul - Point Blank"
        Int range = 6
        Stat attacks = compound_stat(2, 6, 2)
        Int skill = 0
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent), weapon_rule(WeaponRuleKind::assault))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
    orks_warbuggies_spiked_ram:
        Int family_id = Weapon::orks_trukk_spiked_ram.value
        StringLiteral label = "Spiked Ram"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 7
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks
    orks_wartrakks_kustom_shoota:
        Int family_id = Weapon::orks_kustom_shoota.value
        StringLiteral label = "Kustom Shoota"
        Int range = 18
        Stat attacks = raw_stat(4)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks
    orks_wartrakks_multi_busta_launcha:
        Int family_id = Weapon::orks_multi_busta_launcha.value
        StringLiteral label = "Multi-busta Launcha"
        Int range = 24
        Stat attacks = compound_stat(1, 3, 3)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks
    orks_wartrakks_kustom_choppa:
        Int family_id = Weapon::orks_kustom_choppa.value
        StringLiteral label = "Kustom Choppa"
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
    orks_wazbom_blastajet_dual_supa_shoota:
        Int family_id = Weapon::orks_blitza_bommer_dual_supa_shoota.value
        StringLiteral label = "Dual Supa-shoota"
        Int range = 36
        Stat attacks = raw_stat(8)
        Int skill = 4
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 4), weapon_rule(WeaponRuleKind::ignore_cover), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
    orks_wazbom_blastajet_dual_tellyport_mega_blasta:
        Int family_id = Weapon::orks_wazbom_blastajet_dual_tellyport_mega_blasta.value
        StringLiteral label = "Dual Tellyport Mega-blasta"
        Int range = 24
        Stat attacks = raw_stat(6)
        Int skill = 4
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 6), weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::ignore_cover))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
    orks_wazbom_blastajet_dual_wazbom_mega_kannon:
        Int family_id = Weapon::orks_wazbom_blastajet_dual_wazbom_mega_kannon.value
        StringLiteral label = "Dual Wazbom Mega-kannon"
        Int range = 36
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(4)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::ignore_cover))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
    orks_wazbom_blastajet_smasha_gun:
        Int family_id = Weapon::orks_mek_gunz_smasha_gun.value
        StringLiteral label = "Smasha Gun"
        Int range = 48
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 6
        Int penetration = -3
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::ignore_cover))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
    orks_wazbom_blastajet_armoured_impact:
        Int family_id = Weapon::orks_blitza_bommer_armoured_impact.value
        StringLiteral label = "Armoured Impact"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
    orks_wazdakka_gutsmek_grabba_dragga_ranged:
        Int family_id = Weapon::orks_wazdakka_gutsmek_grabba_dragga_ranged.value
        StringLiteral label = "Grabba Dragga (ranged)"
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 2
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision), weapon_rule(WeaponRuleKind::assault))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
    orks_wazdakka_gutsmek_psyko_gatler:
        Int family_id = Weapon::orks_wazdakka_gutsmek_psyko_gatler.value
        StringLiteral label = "Psyko-gatler"
        Int range = 24
        Stat attacks = raw_stat(12)
        Int skill = 4
        Int strenght = 6
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::sustained_hit, 1), weapon_rule(WeaponRuleKind::assault), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
    orks_wazdakka_gutsmek_speeding_bulk_and_flaming_exhaust:
        Int family_id = Weapon::orks_wazdakka_gutsmek_speeding_bulk_and_flaming_exhaust.value
        StringLiteral label = "Speeding Bulk and Flaming Exhaust"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 2
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1), weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
    orks_wazdakka_gutsmek_fixit_s_wrench:
        Int family_id = Weapon::orks_wazdakka_gutsmek_fixit_s_wrench.value
        StringLiteral label = "Fixit’s Wrench"
        Int range = 0
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 3
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
    orks_wazdakka_gutsmek_grabba_dragga_melee:
        Int family_id = Weapon::orks_wazdakka_gutsmek_grabba_dragga_ranged.value
        StringLiteral label = "Grabba Dragga (melee)"
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2), weapon_rule(WeaponRuleKind::lance))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy
    orks_weirdboy_power_vomit:
        Int family_id = Weapon::orks_weirdboy_power_vomit.value
        StringLiteral label = "Power Vomit"
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = -3
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent), weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::psychic))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy
    orks_weirdboy_copper_staff:
        Int family_id = Weapon::orks_weirdboy_copper_staff.value
        StringLiteral label = "Copper Staff"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 8
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::psychic))

    # Magnitude lookup retains the first declared parameter, distinct from
    # Non-attacking roster equipment uses the same finite catalog. These
    # entries install datasheet permissions, never an attack (Orks cards).
    orks_kustom_force_field:
        Int family_id = Weapon::orks_kustom_force_field.value
        StringLiteral label = "Kustom Force Field"
        Int range = 0
        Stat attacks = raw_stat(0)
        Int skill = 0
        Int strenght = 0
        Int penetration = 0
        Stat damage = raw_stat(0)
        WeaponRules rules = weapon_rules()

    orks_pulsa_rokkit:
        Int family_id = Weapon::orks_pulsa_rokkit.value
        StringLiteral label = "Pulsa Rokkit"
        Int range = 0
        Stat attacks = raw_stat(0)
        Int skill = 0
        Int strenght = 0
        Int penetration = 0
        Stat damage = raw_stat(0)
        WeaponRules rules = weapon_rules()

    orks_paired_krumpas:
        Int family_id = Weapon::orks_kustom_krumpa.value
        StringLiteral label = "Paired Krumpas"
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()


    # presence for parameterless abilities (pp.80–85). Own copies exit once.
    fun get_rule_parameter(WeaponRuleKind rule) -> Int:
        let rules = self.rules()
        let result = 0
        let found = false
        for i in range(rules.size()):
            if !found and rules[i].kind == rule:
                result = rules[i].parameter.value
                found = true
        return result

    # HAZARDOUS/PRECISION/DEVASTATING WOUNDS depend on presence even at zero
    # parameter (pp.80/81/84). Finish the owning rule snapshot before returning.
    fun has_rule(WeaponRuleKind rule) -> Bool:
        let rules = self.rules()
        let found = false
        for i in range(rules.size()):
            found = found or rules[i].kind == rule
        return found

fun write_in_observation_tensor(Weapon obj, Int observer_id, Vector<Float> output, Int index):
    output[index] = (float(obj.value) - (float(max(obj)) / 2.0)) / float(max(obj))
    index = index + 1

fun size_as_observation_tensor(Weapon kind) -> Int:
    return 1


# Save-format helper, not a tabletop rule: bounded characteristic type names
# contain commas which RLC 0.3.3's indenter splits. Stable tags keep readable
# saves round-trippable while retaining inferred bounded ML types. These stored
# characteristics feed attack count/damage (core pp.17/19; reference 04.03/05.04).
fun append_to_string(CompoundDice expression, String output):
    append_to_string(expression.count, output)
    output.append(" "s)
    append_to_string(expression.d3, output)
    output.append(" "s)
    append_to_string(expression.constant, output)

# Stable expression codec retains original dice and intrinsic constant
# separately, without a custom observation writer (appendix02.02.03).
fun parse_string(CompoundDice expression, String buffer, Int index) -> Bool:
    return parse_string(expression.count, buffer, index) and parse_string(expression.d3, buffer, index) and parse_string(expression.constant, buffer, index)

fun append_to_string(Stat stat, String output):
    if stat is FixedStat:
        output.append("fixed "s)
        append_to_string(stat, output)
    else if stat is Dice:
        output.append("dice "s)
        append_to_string(stat, output)
    else if stat is CompoundDice:
        output.append("compound "s)
        append_to_string(stat, output)

# Decode the stable characteristic tags with the standard bound checks; a bad
# save must not introduce an unsupported attack/damage value (pp.17/19).
fun parse_string(Stat result, String buffer, Int index) -> Bool:
    while index < buffer.size() and is_space(buffer[index]):
        index = index + 1
    if buffer.substring_matches("fixed", index):
        index = index + 5
        let value : FixedStat
        if !parse_string(value, buffer, index):
            return false
        result = value
        return true
    if buffer.substring_matches("dice", index):
        index = index + 4
        let value : Dice
        if !parse_string(value, buffer, index):
            return false
        result = value
        return true
    if buffer.substring_matches("compound", index):
        index = index + 8
        let expression : CompoundDice
        if !parse_string(expression, buffer, index):
            return false
        result = expression
        return valid_stat(result)
    return false

# Presentation only: resolve a family's fixed label from its actual catalog
# representative; names are never stored as gameplay selectors (core p16).
fun weapon_family_label(Weapon profile) -> StringLiteral:
    if profile.family_id() == Weapon::stompa_supa_gatler_point_blank.value:
        return "Supa-gatler"
    if profile.family_id() == Weapon::stompa_deffkannon_and_supa_rokkits.value:
        return "Deffkannon and Supa-rokkits"
    if profile.family_id() == Weapon::orks_beastboss_shoota.value:
        return "Shoota"
    if profile.family_id() == Weapon::orks_beastboss_klaw_and_beastchoppa.value:
        return "Beast Snagga Klaw and Beastchoppa"
    if profile.family_id() == Weapon::orks_slugga.value:
        return "Slugga"
    if profile.family_id() == Weapon::orks_thump_gun.value:
        return "Thump Gun"
    if profile.family_id() == Weapon::orks_choppa_standard.value:
        return "Choppa"
    if profile.family_id() == Weapon::orks_power_snappa.value:
        return "Power Snappa"
    if profile.family_id() == Weapon::orks_saddlegit_shiv.value:
        return "Saddlegit’s Shiv"
    if profile.family_id() == Weapon::orks_stikka_ranged.value:
        return "Stikka"
    if profile.family_id() == Weapon::orks_big_choppa.value:
        return "Big Choppa"
    if profile.family_id() == Weapon::orks_squig_jaws.value:
        return "Squig’s Jaws"
    if profile.family_id() == Weapon::orks_da_gobshot_thunderbuss.value:
        return "Da Gobshot Thunderbuss"
    if profile.family_id() == Weapon::orks_da_krunch.value:
        return "Da Krunch"
    if profile.family_id() == Weapon::orks_eadbanger.value:
        return "'Eadbanger"
    if profile.family_id() == Weapon::orks_infantry_big_shoota.value:
        return "Big Shoota"
    if profile.family_id() == Weapon::orks_burna.value:
        return "Burna"
    if profile.family_id() == Weapon::orks_kombi_rokkit_busta.value:
        return "Kombi-rokkit"
    if profile.family_id() == Weapon::orks_kombi_skorcha_shoota.value:
        return "Kombi-skorcha"
    if profile.family_id() == Weapon::orks_kustom_shoota.value:
        return "Kustom Shoota"
    if profile.family_id() == Weapon::orks_rokkit_launcha_blasta.value:
        return "Rokkit Launcha"
    if profile.family_id() == Weapon::orks_kustom_choppa.value:
        return "Kustom Choppa"
    if profile.family_id() == Weapon::orks_power_klaw.value:
        return "Power Klaw"
    if profile.family_id() == Weapon::orks_big_skorcha.value:
        return "Big Skorcha"
    if profile.family_id() == Weapon::orks_kustom_big_shoota.value:
        return "Kustom Big Shoota"
    if profile.family_id() == Weapon::orks_kustom_krumpa.value:
        return "Kustom Krumpa"
    if profile.family_id() == Weapon::orks_dual_kombi_rokkit_dakkagun.value:
        return "Dual Kombi-rokkit"
    if profile.family_id() == Weapon::orks_dual_dakkagun.value:
        return "Dual Dakkagun"
    if profile.family_id() == Weapon::orks_kustom_mega_blasta.value:
        return "Kustom Mega-blasta"
    if profile.family_id() == Weapon::orks_skorcha.value:
        return "Skorcha"
    if profile.family_id() == Weapon::orks_extra_klaw.value:
        return "Extra Klaw"
    if profile.family_id() == Weapon::orks_dread_klaws.value:
        return "Dread Klaws"
    if profile.family_id() == Weapon::orks_kan_blasta_dakka.value:
        return "Kan Blasta"
    if profile.family_id() == Weapon::orks_kan_klaw.value:
        return "Kan Klaw"
    if profile.family_id() == Weapon::orks_blitzkannon.value:
        return "Blitzkannon"
    if profile.family_id() == Weapon::orks_multi_busta_launcha.value:
        return "Multi-busta Launcha"
    if profile.family_id() == Weapon::orks_stompy_feet.value:
        return "Stompy Feet"
    if profile.family_id() == Weapon::orks_beastchoppa_standard.value:
        return "Beastchoppa"
    if profile.family_id() == Weapon::orks_squigosaur_jaws.value:
        return "Squigosaur’s Jaws"
    if profile.family_id() == Weapon::orks_big_chompa_jaws.value:
        return "Big Chompa’s Jaws"
    if profile.family_id() == Weapon::orks_gutrippa_standard.value:
        return "Gutrippa"
    if profile.family_id() == Weapon::orks_flash_gitz_snazzgun_cutta.value:
        return "Snazzgun"
    if profile.family_id() == Weapon::orks_meganobz_kombi_weapon_shoota.value:
        return "Kombi-weapon"
    if profile.family_id() == Weapon::orks_meganobz_killsaw.value:
        return "Killsaw"
    if profile.family_id() == Weapon::orks_meganobz_twin_killsaws.value:
        return "Twin Killsaws"
    if profile.family_id() == Weapon::orks_mek_kustom_mega_slugga.value:
        return "Kustom Mega-slugga"
    if profile.family_id() == Weapon::orks_mek_mek_s_toolz.value:
        return "Mek’s Toolz"
    if profile.family_id() == Weapon::orks_big_mek_traktor_blasta.value:
        return "Traktor Blasta"
    if profile.family_id() == Weapon::orks_big_mek_drilla.value:
        return "Drilla"
    if profile.family_id() == Weapon::orks_big_mek_in_mega_armour_tellyport_blasta.value:
        return "Tellyport Blasta"
    if profile.family_id() == Weapon::orks_big_mek_with_shokk_attack_gun_shokk_attack_gun.value:
        return "Shokk Attack Gun"
    if profile.family_id() == Weapon::orks_big_mek_with_shokk_attack_gun_big_mek_s_toolz.value:
        return "Big Mek’s Toolz"
    if profile.family_id() == Weapon::orks_painboy_urty_syringe.value:
        return "’Urty Syringe"
    if profile.family_id() == Weapon::orks_painboy_dok_s_toolz.value:
        return "Dok’s Toolz"
    if profile.family_id() == Weapon::orks_painboss_beast_snagga_klaw.value:
        return "Beast Snagga Klaw"
    if profile.family_id() == Weapon::orks_breaka_boyz_rokkit_pistol.value:
        return "Rokkit Pistol"
    if profile.family_id() == Weapon::orks_breaka_boyz_smash_hammer_standard.value:
        return "Smash Hammer"
    if profile.family_id() == Weapon::orks_breaka_boyz_knucklebustas.value:
        return "Knucklebustas"
    if profile.family_id() == Weapon::orks_breaka_boyz_tankhammer.value:
        return "Tankhammer"
    if profile.family_id() == Weapon::orks_tankbustas_busta_rokkit_launcha_standard.value:
        return "Busta Rokkit Launcha"
    if profile.family_id() == Weapon::orks_tankbustas_gitstikka.value:
        return "Gitstikka"
    if profile.family_id() == Weapon::orks_warboss_in_mega_armour_uge_choppa.value:
        return "’Uge Choppa"
    if profile.family_id() == Weapon::orks_gretchin_grot_blasta.value:
        return "Grot Blasta"
    if profile.family_id() == Weapon::orks_gretchin_scavenged_shivs.value:
        return "Scavenged Shivs"
    if profile.family_id() == Weapon::orks_runtherd_runtherd_s_toolz.value:
        return "Runtherd’s Toolz"
    if profile.family_id() == Weapon::orks_zodgrod_wortsnagga_squigstoppa.value:
        return "Squigstoppa"
    if profile.family_id() == Weapon::orks_zodgrod_wortsnagga_da_grabzappa.value:
        return "Da Grabzappa"
    if profile.family_id() == Weapon::orks_battlewagon_crushin_bulk.value:
        return "Crushin’ Bulk"
    if profile.family_id() == Weapon::orks_battlewagon_grabbin_klaw.value:
        return "Grabbin’ Klaw"
    if profile.family_id() == Weapon::orks_battlewagon_wreckin_ball.value:
        return "Wreckin’ Ball"
    if profile.family_id() == Weapon::orks_big_ed_bossbunka_gaze_of_gork_glare.value:
        return "Gaze of Gork"
    if profile.family_id() == Weapon::orks_blitza_bommer_dual_supa_shoota.value:
        return "Dual Supa-shoota"
    if profile.family_id() == Weapon::orks_blitza_bommer_armoured_impact.value:
        return "Armoured Impact"
    if profile.family_id() == Weapon::orks_boss_snikrot_mork_s_teef.value:
        return "Mork’s Teef"
    if profile.family_id() == Weapon::orks_burna_bommer_dual_big_shoota.value:
        return "Dual Big Shoota"
    if profile.family_id() == Weapon::orks_burna_bommer_skorcha_missile_rack.value:
        return "Skorcha Missile Rack"
    if profile.family_id() == Weapon::orks_deffkilla_wartrike_boomstikks.value:
        return "Boomstikks"
    if profile.family_id() == Weapon::orks_deffkilla_wartrike_snagga_klaw_ranged.value:
        return "Snagga Klaw"
    if profile.family_id() == Weapon::orks_deffkilla_wartrike_killa_jet_burna.value:
        return "Killa Jet"
    if profile.family_id() == Weapon::orks_deffkoptas_spinnin_blades.value:
        return "Spinnin’ Blades"
    if profile.family_id() == Weapon::orks_ghazghkull_thraka_mork_s_roar_aimed.value:
        return "Mork’s Roar"
    if profile.family_id() == Weapon::orks_ghazghkull_thraka_adamantine_eadbutt.value:
        return "Adamantine ’Eadbutt"
    if profile.family_id() == Weapon::orks_ghazghkull_thraka_gork_s_klaw.value:
        return "Gork’s Klaw"
    if profile.family_id() == Weapon::orks_gorkanaut_deffstorm_mega_shoota_aimed.value:
        return "Deffstorm Mega-shoota"
    if profile.family_id() == Weapon::orks_gorkanaut_klaw_of_gork.value:
        return "Klaw of Gork"
    if profile.family_id() == Weapon::orks_gunwagon_kannon_frag.value:
        return "Kannon"
    if profile.family_id() == Weapon::orks_gunwagon_killkannon.value:
        return "Killkannon"
    if profile.family_id() == Weapon::orks_gunwagon_lobba.value:
        return "Lobba"
    if profile.family_id() == Weapon::orks_gunwagon_zzap_gun.value:
        return "Zzap Gun"
    if profile.family_id() == Weapon::orks_hunta_rig_eavy_lobba.value:
        return "’Eavy Lobba"
    if profile.family_id() == Weapon::orks_hunta_rig_stikka_kannon.value:
        return "Stikka Kannon"
    if profile.family_id() == Weapon::orks_hunta_rig_butcha_boyz.value:
        return "Butcha Boyz"
    if profile.family_id() == Weapon::orks_hunta_rig_savage_horns_and_hooves.value:
        return "Savage Horns and Hooves"
    if profile.family_id() == Weapon::orks_hunta_rig_saw_blades.value:
        return "Saw Blades"
    if profile.family_id() == Weapon::orks_kill_rig_wurrtower.value:
        return "Wurrtower"
    if profile.family_id() == Weapon::orks_kommandos_breacha_ram.value:
        return "Breacha Ram"
    if profile.family_id() == Weapon::orks_mek_gunz_smasha_gun.value:
        return "Smasha Gun"
    if profile.family_id() == Weapon::orks_mek_gunz_bubblechukka.value:
        return "Bubblechukka"
    if profile.family_id() == Weapon::orks_mek_gunz_kustom_mega_kannon.value:
        return "Kustom Mega-kannon"
    if profile.family_id() == Weapon::orks_mek_gunz_traktor_kannon.value:
        return "Traktor Kannon"
    if profile.family_id() == Weapon::orks_morkanaut_kustom_mega_zappa.value:
        return "Kustom Mega-zappa"
    if profile.family_id() == Weapon::orks_morkanaut_klaw_of_mork.value:
        return "Klaw of Mork"
    if profile.family_id() == Weapon::orks_nazdreg_kustom_blasta_x_gatler.value:
        return "Kustom Blasta X"
    if profile.family_id() == Weapon::orks_nazdreg_moonchewa.value:
        return "Moonchewa"
    if profile.family_id() == Weapon::orks_rukkatrukk_squigbuggies_sawn_off_shotgun.value:
        return "Sawn-off Shotgun"
    if profile.family_id() == Weapon::orks_rukkatrukk_squigbuggies_squig_launchas.value:
        return "Squig Launchas"
    if profile.family_id() == Weapon::orks_stompa_mega_choppa.value:
        return "Mega-choppa"
    if profile.family_id() == Weapon::orks_trukk_buzzsaw.value:
        return "Buzzsaw"
    if profile.family_id() == Weapon::orks_trukk_spiked_ram.value:
        return "Spiked Ram"
    if profile.family_id() == Weapon::orks_warbuggies_extra_dakka.value:
        return "Extra Dakka"
    if profile.family_id() == Weapon::orks_warbuggies_rivet_kannon_aimed.value:
        return "Rivet Kannon"
    if profile.family_id() == Weapon::orks_warbuggies_mek_speshul_aimed.value:
        return "Mek Speshul"
    if profile.family_id() == Weapon::orks_wazbom_blastajet_dual_tellyport_mega_blasta.value:
        return "Dual Tellyport Mega-blasta"
    if profile.family_id() == Weapon::orks_wazbom_blastajet_dual_wazbom_mega_kannon.value:
        return "Dual Wazbom Mega-kannon"
    if profile.family_id() == Weapon::orks_wazdakka_gutsmek_grabba_dragga_ranged.value:
        return "Grabba Dragga"
    if profile.family_id() == Weapon::orks_wazdakka_gutsmek_psyko_gatler.value:
        return "Psyko-gatler"
    if profile.family_id() == Weapon::orks_wazdakka_gutsmek_speeding_bulk_and_flaming_exhaust.value:
        return "Speeding Bulk and Flaming Exhaust"
    if profile.family_id() == Weapon::orks_wazdakka_gutsmek_fixit_s_wrench.value:
        return "Fixit’s Wrench"
    if profile.family_id() == Weapon::orks_weirdboy_power_vomit.value:
        return "Power Vomit"
    if profile.family_id() == Weapon::orks_weirdboy_copper_staff.value:
        return "Copper Staff"
    if profile.value == Weapon::none.value:
        return "Unknown"
    return profile.label()


# Each entry is one actual catalog profile. Zero is an independent primary;
# a positive value is the1-based earlier primary slot in this model. This
# distinguishes two copies without parallel name/group metadata (04.01.03).
cls EquippedWeapon:
    Weapon profile
    LinearlyDistributedInt<0, MAX_WEAPONS> secondary_profile_of

# Construction infrastructure; full same-model/backward-link validation runs
# when installing profiles or restoring a saved Model (core p16/04.01.03).
fun equipped_weapon(Weapon profile, Int primary) -> EquippedWeapon:
    assert(primary >= 0 and primary < MAX_WEAPONS, "invalid primary weapon index")
    let entry : EquippedWeapon
    entry.profile = profile
    entry.secondary_profile_of = primary
    return entry

# Ordinary independent weapons carry no secondary reference (core p16).
fun equipped_weapon(Weapon profile) -> EquippedWeapon:
    return equipped_weapon(profile, 0)

# Nazdreg explicitly fires all three ranged Kustom Blasta X profiles. This
# catalog property preserves the exception without per-model permission flags.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg (Unit Composition).
fun simultaneous_weapon_profile(Weapon profile) -> Bool:
    return profile.value == Weapon::orks_nazdreg_kustom_blasta_x_gatler.value or profile.value == Weapon::orks_nazdreg_kustom_blasta_x_shoota.value or profile.value == Weapon::orks_nazdreg_kustom_blasta_x_skorcha.value

# Shared finite equipment lists contain actual profiles; six covers every
# current printed replacement list. These temporaries never become actions.
using WeaponChoices = CheckedVector<Weapon, 6>

# Bounded list construction only; caller supplies the printed legal alternatives.
fun weapon_choices(Weapon item_0, Weapon item_1) -> WeaponChoices:
    let result : WeaponChoices
    result.append(item_0)
    result.append(item_1)
    return result

# Bounded list construction only; caller supplies the printed legal alternatives.
fun weapon_choices(Weapon item_0, Weapon item_1, Weapon item_2) -> WeaponChoices:
    let result : WeaponChoices
    result.append(item_0)
    result.append(item_1)
    result.append(item_2)
    return result

# Bounded list construction only; caller supplies the printed legal alternatives.
fun weapon_choices(Weapon item_0, Weapon item_1, Weapon item_2, Weapon item_3) -> WeaponChoices:
    let result : WeaponChoices
    result.append(item_0)
    result.append(item_1)
    result.append(item_2)
    result.append(item_3)
    return result

# Bounded list construction only; caller supplies the printed legal alternatives.
fun weapon_choices(Weapon item_0, Weapon item_1, Weapon item_2, Weapon item_3, Weapon item_4) -> WeaponChoices:
    let result : WeaponChoices
    result.append(item_0)
    result.append(item_1)
    result.append(item_2)
    result.append(item_3)
    result.append(item_4)
    return result

# Bounded list construction only; caller supplies the printed legal alternatives.
fun weapon_choices(Weapon item_0, Weapon item_1, Weapon item_2, Weapon item_3, Weapon item_4, Weapon item_5) -> WeaponChoices:
    let result : WeaponChoices
    result.append(item_0)
    result.append(item_1)
    result.append(item_2)
    result.append(item_3)
    result.append(item_4)
    result.append(item_5)
    return result

# Printed lists restrict the single catalog; no separate subset enum or
# whole-catalog public input is required (Orks card Wargear Options).
fun weapon_choice(WeaponChoices choices, Int index) -> Weapon:
    assert(index >= 0 and index < choices.size(), "invalid equipment choice index")
    return choices[index]

# Membership lookup supports source-card quotas without a second choice catalog.
fun weapon_choice_index(Weapon profile, WeaponChoices choices) -> Int:
    let found = -1
    for index in range(choices.size()):
        if choices[index].value == profile.value:
            found = index
    return found

# Pure source-card equipment eligibility; inspecting a choice never installs it.
fun weapon_allowed(Weapon profile, WeaponChoices choices) -> Bool:
    return weapon_choice_index(profile, choices) >= 0

# A two-weapon selection is two real profiles, not a bundle/catalog enum.
cls WeaponPair:
    Weapon gun
    Weapon melee

# Paired source-card replacements are two actual weapons (e.g. Orks/Meganobz).
fun weapon_pair(Weapon gun, Weapon melee) -> WeaponPair:
    let result : WeaponPair
    result.gun = gun
    result.melee = melee
    return result

# Roster equipment shares the catalog, but its zero-attack tokens grant only
# their printed nonattack rules (Orks Big Mek in Mega Armour/Tankbustas).
fun nonattacking_equipment(Weapon profile) -> Bool:
    return profile.value == Weapon::none.value or profile.value == Weapon::orks_kustom_force_field.value or profile.value == Weapon::orks_pulsa_rokkit.value

# Present two actual weapons only when the host requests the roster label.
fun weapon_pair_label(WeaponPair pair) -> String:
    if pair.gun.value == Weapon::none.value:
        return to_string(pair.melee.label())
    return to_string(pair.gun.label()) + " + "s + to_string(pair.melee.label())

# Derive a family selector from the same actual profile catalog; no second
# naming enum or independently mutable identity metadata is involved.
fun weapon_family(Weapon profile) -> Weapon:
    let result : Weapon
    result.value = profile.family_id()
    return result
