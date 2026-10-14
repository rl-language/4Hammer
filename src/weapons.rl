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
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::letal_hits), weapon_rule(WeaponRuleKind::precision))
    smite_witchfire:
        Int range = 24
        Stat attacks = dice_stat(6)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = dice_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::psychic))
    smite_focused_witchfire:
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
        Int penetration = -1
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
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    terminator_power_weapon:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    death_shadow_claws_and_talons:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 6
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision))
    lictor_claws_and_talons:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision))
    leapers_talon:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
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
        Int penetration = -2
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
        Int penetration = -1
        Stat damage = dice_stat(3)
        WeaponRules rules = weapon_rules(
                                weapon_rule(WeaponRuleKind::psychic), 
                                weapon_rule(WeaponRuleKind::anti_psychic))
    hideous_mutations:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
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
        Int penetration = -1
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
    vaultswords_behemor:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision))
    vaultswords_hurricanus:
        Int range = 0
        Stat attacks = raw_stat(9)
        Int skill = 2
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    vaultswords_victus:
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 6
        Int penetration = -3
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::devastating_wounds))
    sentinel_blade_ranged:
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
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 6
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    castellan_axe_ranged:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault))
    guardian_spear_ranged:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault))
    castellan_axe_melee:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 2
        Int strenght = 9
        Int penetration = -1
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()
    guardian_spear_melee:
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    balistus_grenade_launcher:
        Int range = 18
        Stat attacks = dice_stat(6)  
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast))

    guardian_spear_ranged_allarus:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault))

    guardian_spear_melee_allarus:
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    boltstorm_gauntlet:
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 2
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))
    power_fist_zacharial:
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()
    relic_chainsword:
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
        Int range = 18
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::pistol))

    master_crafted_power_weapon:
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
        Int range = 12
        Stat attacks = compound_stat(3, 6, 3)
        Int skill = 0
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent))
    stompa_deffkannon_and_supa_rokkits:
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
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))
    orks_beastboss_klaw_and_beastchoppa:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::sustained_hit, 2))
    orks_slugga:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))
    orks_thump_gun:
        Int range = 18
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 6
        Int penetration = 0
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))
    orks_choppa_standard:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    orks_choppa_hunter:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 6
        Int penetration = -2
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()
    orks_power_snappa:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))
    orks_saddlegit_shiv:
        Int range = 9
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 3
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault))
    orks_stikka_ranged:
        Int range = 9
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault), orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))
    orks_big_choppa:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 7
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2), orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))
    orks_squig_jaws:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks))
    orks_stikka_melee:
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
        Int range = 24
        Stat attacks = raw_stat(6)
        Int skill = 4
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0), weapon_rule(WeaponRuleKind::rapid_fire, 6))
    orks_da_krunch:
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 3), weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::letal_hits), weapon_rule(WeaponRuleKind::psychic))
    orks_eadbanger:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 6
        Int penetration = -3
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::precision), weapon_rule(WeaponRuleKind::psychic))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
    orks_infantry_big_shoota:
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
    orks_burna:
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_kombi_rokkit_busta:
        Int range = 24
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_kombi_rokkit_shoota:
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_kombi_skorcha_shoota:
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_kombi_skorcha_skorcha:
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_kustom_shoota:
        Int range = 18
        Stat attacks = raw_stat(4)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_rokkit_launcha_blasta:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_rokkit_launcha_busta:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Bannernob
    orks_shoota:
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
    orks_infantry_big_choppa:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 7
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers
    orks_kustom_choppa:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Stormboyz
    orks_power_klaw:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
    orks_big_skorcha:
        Int range = 18
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
    orks_kustom_big_shoota:
        Int range = 18
        Stat attacks = raw_stat(8)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
    orks_kustom_krumpa:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_warboss_kustom_choppa:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_warboss_power_klaw:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Bigboss
    orks_bigboss_big_choppa:
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::precision))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers
    orks_dual_kombi_rokkit_dakkagun:
        Int range = 18
        Stat attacks = raw_stat(6)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers
    orks_dual_kombi_rokkit_busta:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers
    orks_dual_dakkagun:
        Int range = 18
        Stat attacks = raw_stat(6)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::assault), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_dread_big_shoota:
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_kustom_mega_blasta:
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 5
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_skorcha:
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_extra_klaw:
        Int range = 0
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_dread_klaws:
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 3
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
    orks_kan_blasta_dakka:
        Int range = 24
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::sustained_hit, 1), weapon_rule(WeaponRuleKind::ignore_cover))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
    orks_kan_blasta_kill_shot:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
    orks_kan_blasta_point_blank:
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 2), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
    orks_kan_klaw:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-Dakkarig
    orks_blitzkannon:
        Int range = 24
        Stat attacks = raw_stat(8)
        Int skill = 4
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::ignore_cover), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-Dakkarig
    orks_multi_busta_launcha:
        Int range = 24
        Stat attacks = raw_stat(6)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::ignore_cover), weapon_rule(WeaponRuleKind::letal_hits))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-Dakkarig
    orks_stompy_feet:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur
    orks_beastchoppa_standard:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 6
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur
    orks_beastchoppa_hunter:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 12
        Int penetration = -2
        Stat damage = dice_stat(6)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur
    orks_squigosaur_jaws:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks), orks_monster_vehicle_rule(WeaponRuleKind::anti, 3))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad
    orks_big_chompa_jaws:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(4)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks), orks_monster_vehicle_rule(WeaponRuleKind::anti, 3))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad
    orks_gutrippa_standard:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad
    orks_gutrippa_hunter:
        Int range = 0
        Stat attacks = raw_stat(6)
        Int skill = 2
        Int strenght = 12
        Int penetration = -2
        Stat damage = compound_stat(1, 6, 1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::letal_hits))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
    orks_flash_gitz_snazzgun_cutta:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 9
        Int penetration = -3
        Stat damage = compound_stat(1, 3, 2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::melta, 2), weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
    orks_flash_gitz_snazzgun_dakka:
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = -1
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::sustained_hit, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
    orks_flash_gitz_snazzgun_kill_shot:
        Int range = 36
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
    orks_flash_gitz_choppa:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_kombi_weapon_shoota:
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_kombi_weapon_kill_shot:
        Int range = 24
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_kombi_weapon_point_blank:
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_kustom_shoota_aimed:
        Int range = 18
        Stat attacks = raw_stat(4)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_kustom_shoota_point_blank:
        Int range = 6
        Stat attacks = compound_stat(1, 3, 3)
        Int skill = 0
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent), weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_killsaw:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_power_klaw:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganobz_twin_killsaws:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::twin_linked))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek
    orks_mek_kustom_mega_slugga:
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 8
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek
    orks_mek_mek_s_toolz:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
    orks_big_mek_kustom_mega_blasta:
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
    orks_big_mek_traktor_blasta:
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 6
        Int penetration = -2
        Stat damage = compound_stat(1, 3, 3)
        WeaponRules rules = weapon_rules(conditional_weapon_rule(WeaponRuleKind::anti, 2, Keyword::fly))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
    orks_big_mek_drilla:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 12
        Int penetration = -3
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
    orks_big_mek_power_klaw:
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kombi_weapon_shoota:
        Int range = 18
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 1), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kombi_weapon_kill_shot:
        Int range = 24
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kombi_weapon_point_blank:
        Int range = 12
        Stat attacks = raw_stat(3)
        Int skill = 0
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::torrent))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kustom_mega_blasta:
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kustom_shoota_aimed:
        Int range = 18
        Stat attacks = raw_stat(4)
        Int skill = 4
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_kustom_shoota_point_blank:
        Int range = 6
        Stat attacks = compound_stat(1, 3, 3)
        Int skill = 0
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::torrent), weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_tellyport_blasta:
        Int range = 12
        Stat attacks = raw_stat(6)
        Int skill = 4
        Int strenght = 9
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_killsaw:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour_power_klaw:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun
    orks_big_mek_with_shokk_attack_gun_shokk_attack_gun:
        Int range = 60
        Stat attacks = compound_stat(1, 3, 3)
        Int skill = 5
        Int strenght = 12
        Int penetration = -4
        Stat damage = compound_stat(1, 6, 1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::blast, 1), weapon_rule(WeaponRuleKind::heavy))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun
    orks_big_mek_with_shokk_attack_gun_big_mek_s_toolz:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Painboy
    orks_painboy_urty_syringe:
        Int range = 0
        Stat attacks = raw_stat(1)
        Int skill = 3
        Int strenght = 2
        Int penetration = 0
        Stat damage = compound_stat(1, 6, 0)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::extra_attacks), conditional_weapon_rule(WeaponRuleKind::anti, 4, Keyword::infantry), conditional_weapon_rule(WeaponRuleKind::devastating_wounds, 0, Keyword::infantry))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Painboy
    orks_painboy_dok_s_toolz:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Painboss
    orks_painboss_beast_snagga_klaw:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_rokkit_pistol:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_smash_hammer_standard:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_smash_hammer_hunter:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_choppa:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_knucklebustas:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules(orks_monster_vehicle_rule(WeaponRuleKind::anti, 4))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boyz_tankhammer:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::hazardous), weapon_rule(WeaponRuleKind::devastating_wounds))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_busta_rokkit_launcha_standard:
        Int range = 24
        Stat attacks = raw_stat(2)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_busta_rokkit_launcha_hunter:
        Int range = 24
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_rokkit_pistol:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 10
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_choppa:
        Int range = 0
        Stat attacks = raw_stat(4)
        Int skill = 3
        Int strenght = 5
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_gitstikka:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_smash_hammer_standard:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbustas_smash_hammer_hunter:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
    orks_warboss_in_mega_armour_big_shoota:
        Int range = 36
        Stat attacks = raw_stat(3)
        Int skill = 4
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::rapid_fire, 2), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
    orks_warboss_in_mega_armour_uge_choppa:
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 12
        Int penetration = -2
        Stat damage = raw_stat(3)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::cleave, 2))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
    orks_gretchin_grot_blasta:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 4
        Int strenght = 3
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
    orks_gretchin_scavenged_shivs:
        Int range = 0
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 2
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
    orks_runtherd_slugga:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 4
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters), orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
    orks_runtherd_runtherd_s_toolz:
        Int range = 0
        Stat attacks = raw_stat(3)
        Int skill = 3
        Int strenght = 5
        Int penetration = 0
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules()

    # https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga
    orks_zodgrod_wortsnagga_squigstoppa:
        Int range = 12
        Stat attacks = raw_stat(1)
        Int skill = 5
        Int strenght = 4
        Int penetration = -1
        Stat damage = raw_stat(1)
        WeaponRules rules = weapon_rules(weapon_rule(WeaponRuleKind::close_quarters), orks_monster_vehicle_rule(WeaponRuleKind::anti, 4), orks_monster_vehicle_rule(WeaponRuleKind::devastating_wounds, 0))

    # https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga
    orks_zodgrod_wortsnagga_da_grabzappa:
        Int range = 0
        Stat attacks = raw_stat(5)
        Int skill = 2
        Int strenght = 7
        Int penetration = -2
        Stat damage = raw_stat(2)
        WeaponRules rules = weapon_rules()

    # Magnitude lookup retains the first declared parameter, distinct from
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
