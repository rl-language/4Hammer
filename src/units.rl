import bounded_arg
import stats
import vector2d
import machine_learning
import range

using Wounds = LinearlyDistributedInt<0, 10>
const MAX_WEAPONS = 4
using WeaponsVector = BoundedVector<Weapon, MAX_WEAPONS>
using Abilities = BoundedVector<AbilityKind, 4>
using Keywords = BoundedVector<Keyword, 7>

# some rules specify that models are not to be removed after being destroyed until some other event happens, for example fight on death. We keep track of this special statuses with this enum
enum ModelState:
    normal
    fight_on_death

    fun equal(ModelState other) -> Bool:
        return self.value == other.value

cls Model:
    BoardPosition position # required
    Profile profile
    Wounds suffered_wounds
    WeaponsVector weapons
    Abilities abilities 
    Keywords keywords 
    ModelState state

    fun base_size_in_inches() -> Float:
        return self.profile.base_size() / 25.4

    fun is_below_half_wounds() -> Bool:
        return self.suffered_wounds * 2 > self.profile.wounds()

    fun has_keyword(Keyword keyword) -> Bool:
        let i = 0
        let rules = self.keywords
        while i != rules.size():
            if rules[i] == keyword: 
                return true 
            i = i + 1
        return false

    fun has_weapon_rule(WeaponRuleKind rule) -> Bool:
        let i = 0
        while i != self.weapons.size():
            if self.weapons[i].has_rule(rule):
                return true 
            i = i + 1
        return false

    fun has_ability(AbilityKind kind) -> Bool:
        let i = 0
        let rules = self.abilities
        while i != rules.size():
            if rules[i] == kind: 
                return true 
            i = i + 1
        return false

    fun consolidate_torward(Unit other):
        let consolidation = other.get_shortest_vector_to(self) * -1.0
    
        if consolidation.length() > 2.0:
            consolidation = (consolidation.as_float_vector().normalized() * 2.0).as_int_vector()
        self.position = self.position + consolidation

    fun is_character() -> Bool:
        return self.has_keyword(Keyword::character)

    fun distance(Model model) -> Float:
        return (model.position.as_vector() - self.position.as_vector()).length() - ((model.base_size_in_inches() + self.base_size_in_inches()) /2.0)

    fun wounds_left() -> Int:
        return self.profile.wounds() - self.suffered_wounds.value

const MAX_UNIT_MODELS = 12
using ModelVector = BoundedVector<Model, MAX_UNIT_MODELS>

cls ModelID: # required
    BInt<0, MAX_UNIT_MODELS> id

    fun get() -> Int:
        return self.id.value


const MAX_UNIT_COUNT = 10
cls UnitID: # required
    BInt<0, MAX_UNIT_COUNT> id

    fun get() -> Int:
        return self.id.value

    fun assign(Int value):
        self.id = value

fun unit_id(Int id) -> UnitID:
    let to_return :  UnitID
    to_return = id
    return to_return

cls PhaseModifiers:
    Bool greater_strenght_wound_protection 

cls Unit:
    ModelVector models # required
    Bool owned_by_player1 # required
    Hidden<String> name # required
    Bool has_moved
    Bool has_run 
    Bool has_fought
    Bool has_shoot
    Bool battle_socked
    Bool has_charged
    Bool can_shoot
    Bool can_charge
    ModelID starting_strenght
    PhaseModifiers phase_modifiers

    fun has_greater_strenght_wound_protection() -> Bool:
        return self.phase_modifiers.greater_strenght_wound_protection 

    fun clear_phase_modifiers():
        let mod : PhaseModifiers
        self.phase_modifiers = mod

    fun is_lone_operative() -> Bool:
        return self.has_ability(AbilityKind::lone_operative)

    fun remove_figth_on_death_models():
        let i = self.models.size() - 1
        while i > 0:
            if self.models[i].state == ModelState::fight_on_death:
                self.models.erase(i)
            i = i - 1

    fun can_reroll_charge() -> Bool:
        return self.has_ability(AbilityKind::unstoppable_valour)

    fun owner_id() -> Int:
        return int(self.owned_by_player1)
    
    fun get_temporary_weapon_rules() -> BoundedVector<WeaponRule, 1>:
        let to_return : BoundedVector<WeaponRule, 1>
        if self.has_ability(AbilityKind::veil_of_time)  and self.models.size() != 1:
            to_return.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
        return to_return

    fun empty() -> Bool:
        return self.models.empty()

    fun consolidate_torward(Unit other):
        let i = 0
        while i != self.models.size():
            self.models[i].consolidate_torward(other)
            i = i + 1

    fun attach_to(Unit other):
        assert(self.models.size() == 1, "only units with one model can be attached")
        other.models.append(self.models[0])
        self.models.erase(0)

    fun get_leadership() -> Int:
        if self.models.empty():
            return 0
        let best_leadership = self.models[0].profile.leadership()
        let i = 1
        while i != self.models.size():
            best_leadership = max(best_leadership, self.models[i].profile.leadership())
            i = i + 1

        return best_leadership
        
    fun has_temporary_wepon_rule(WeaponRuleKind rule) -> Bool: 
        let temp_rules = self.get_temporary_weapon_rules()
        let i = 0
        while i != temp_rules.size():
            if temp_rules[i].kind == rule:
                return true
            i = i + 1
        return false

    fun is_below_half_strenght() -> Bool:
        if self.starting_strenght.get() == 1:
            return self.models[0].is_below_half_wounds()
        
        return self.starting_strenght.get() / 2 > self.models.size()

    fun get_temporary_weapon_parameter(WeaponRuleKind rule) -> Int: 
        let temp_rules = self.get_temporary_weapon_rules()
        let i = 0
        while i != temp_rules.size():
            if temp_rules[i].kind == rule:
                return temp_rules[i].parameter
            i = i + 1
        return 0

    fun max_weapon_parameter(Weapon w, WeaponRuleKind kind) -> Int:
        return max(w.get_rule_parameter(kind), self.get_temporary_weapon_parameter(kind)) 

    fun all_have_ability(AbilityKind kind) -> Bool:
        let i = 0
        while i != self.models.size():
            if !self.models[i].has_ability(kind):
                return false
            i = i + 1
        return true

    fun all_have_keyword(Keyword kind) -> Bool:
        let i = 0
        while i != self.models.size():
            if !self.models[i].has_keyword(kind):
                return false
            i = i + 1
        return true

    fun has_keyword(Keyword kind) -> Bool:
        let i = 0
        while i != self.models.size():
            if self.models[i].has_keyword(kind):
                return true
            i = i + 1
        return false

    fun has_ability(AbilityKind kind) -> Bool:
        let i = 0
        while i != self.models.size():
            if self.models[i].has_ability(kind):
                return true 
            i = i + 1
        return false

    fun get_unit_toughtness() -> Int:
        if self.models.size() == 0:
            return 0
        let max_toughness = self.models[0].profile.thoughness()
        let i = 1
        while i != self.models.size():
            let max_toughness = max(self.models[i].profile.thoughness(), max_toughness)
            i = i + 1
        return max_toughness 

    fun translate(Int x, Int y):
        let v : Vector2D
        v.x = x
        v.y = y
        self.translate(v)


    fun move_to(BoardPosition new_position):
        if self.models.size() == 0:
            return
        let v = new_position.as_vector() - self.models[0].position.as_vector()
        self.translate(v)

    fun translate(Vector2D v):
        let i = 0
        while i != self.models.size():
            ref model = self.models[i]
            model.position = model.position + v
            i = i + 1

    fun distance(BoardPosition position) -> Float:
        return self.distance(position.as_vector()) 

    fun distance(Unit unit) -> Float:
        if unit.models.size() == 0:
            return 100.0
        if self.models.size() == 0:
            return 100.0
        return self.distance(unit.models[0]) 

    fun distance(Model model) -> Float:
        assert(self.models.size() != 0, "calculanting distance to empty unit")
        let shortest = self.models[0].distance(model)
        let i = 1
        while i != self.models.size():
            if shortest > self.models[i].distance(model):
                shortest = self.models[i].distance(model)
            i = i + 1
        return shortest 

    fun get_shortest_vector_to(Unit other) -> Vector2D:
        let their_nearest_model = 0
        let our_nearest_model = 0
        let shortest_lenght = 100.0
        let i = 1
        while i != self.models.size():
            let j = 0
            while j != other.models.size():
                if shortest_lenght > self[i].distance(other[j]):
                    shortest_lenght = self[i].distance(other[j])
                    their_nearest_model = j
                    our_nearest_model = i
                j = j + 1
            i = i + 1
        return other.models[their_nearest_model].position.as_vector() - self.models[our_nearest_model].position.as_vector()

    fun get_shortest_vector_to(Model model) -> Vector2D:
        let nearest_model = self.get_nearest_model_index(model)
        return model.position.as_vector() - self.models[nearest_model].position.as_vector()

    fun get_nearest_model_index(Model model) -> Int:
        assert(self.models.size() != 0, "calculanting distance to empty unit")
        let nearest_model = 0 
        let i = 1
        while i != self.models.size():
            if self.models[nearest_model].distance(model) > self.models[i].distance(model):
                nearest_model = i
            i = i + 1
        return nearest_model

    fun distance(Vector2D position) -> Float:
        assert(self.models.size() != 0, "calculanting distance to empty unit")
        let nearest = self.models[0].position.as_vector()
        let i = 1
        while i != self.models.size():
            if (nearest - position).length() > (self.models[i].position.as_vector() - position).length():
                nearest = self.models[i].position.as_vector()
            i = i + 1
        return (nearest - position).length() 

    fun get(Int model_id) -> ref Model:
        return self.models[model_id]

    fun get(ModelID model_id) -> ref Model:
        return self.models[model_id.get()]

    fun arrange():
        if self.models.size() == 1:
            return
        let i = 1
        while i != self.models.size():
            ref model = self.models[i]
            model.position = self.models[i-1].position
            model.position.x = model.position.x + int(1.0 + model.base_size_in_inches())
            i = i + 1

    fun damage(Int target_model_id, Int damage) -> Bool:
        ref target_model = self.models[target_model_id]
        target_model.suffered_wounds = target_model.suffered_wounds + damage 
        if target_model.suffered_wounds >= target_model.profile.wounds(): 
            self.models.erase(target_model_id)
            return true
        return false

    fun damage(Int target_model_id, Int damage, Bool fight_on_death) -> Bool:
        ref target_model = self.models[target_model_id]
        target_model.suffered_wounds = target_model.suffered_wounds + damage 
        if target_model.suffered_wounds >= target_model.profile.wounds(): 
            if fight_on_death:
                target_model.state = ModelState::fight_on_death
            else:
                self.models.erase(target_model_id)
            return true
        return false

    fun damage(ModelID target_model_id) -> Bool:
        return self.damage(target_model_id.get(), 1)

    fun deal_mortal_wound_damage(Int wounds):
        for i in range(wounds):
            self.damage(0, 1)
            if self.models.size() == 0:
                return
        


using UnitVector = BoundedVector<Unit, MAX_UNIT_COUNT>


fun make_tantus() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::librarian_tantus
    model.abilities.append(AbilityKind::deep_strike)
    model.abilities.append(AbilityKind::leader)
    model.abilities.append(AbilityKind::oath_of_moment)
    model.abilities.append(AbilityKind::veil_of_time)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::imperium)
    model.keywords.append(Keyword::terminator)
    model.keywords.append(Keyword::psyker)
    model.keywords.append(Keyword::octavius)
    model.keywords.append(Keyword::librarian_tantus)
    model.weapons.append(Weapon::librarian_storm_bolter)
    model.weapons.append(Weapon::smite_witchfire)
    model.weapons.append(Weapon::smite_focused_witchfire)
    model.weapons.append(Weapon::force_weapon)
    profile.name = "librarian tantus"s
    profile.models.append(model)
    return profile

fun make_infernus_squad() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::infernus_squad
    model.abilities.append(AbilityKind::oath_of_moment)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::imperium)
    model.keywords.append(Keyword::tacticus)
    model.keywords.append(Keyword::infernus_squad)
    model.weapons.append(Weapon::bolt_pistol)
    model.weapons.append(Weapon::pyreblaster)
    model.weapons.append(Weapon::close_combact_weapon)
    profile.name = "infernus squad"s
    profile.models.append(model)
    profile.models.append(model)
    profile.models.append(model)
    profile.models.append(model)
    profile.models.append(model)
    return profile

fun make_terminator_squad() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::terminator_squad
    model.abilities.append(AbilityKind::oath_of_moment)
    model.abilities.append(AbilityKind::fury_of_the_first)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::imperium)
    model.keywords.append(Keyword::terminator)
    model.keywords.append(Keyword::terminator_squad)
    model.weapons.append(Weapon::terminator_storm_bolter)
    model.weapons.append(Weapon::terminator_power_fist)
    profile.name = "terminator squad"s
    profile.models.append(model)
    profile.models.append(model)
    profile.models.append(model)

    model.weapons.clear()
    model.weapons.append(Weapon::terminator_storm_bolter)
    model.weapons.append(Weapon::terminator_power_weapon)
    profile.models.append(model)

    model.weapons.clear()
    model.weapons.append(Weapon::terminator_power_fist)
    model.weapons.append(Weapon::assault_cannon)
    profile.models.append(model)

    return profile

fun make_octavius() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::captain_octavius
    model.abilities.append(AbilityKind::deep_strike)
    model.abilities.append(AbilityKind::leader)
    model.abilities.append(AbilityKind::oath_of_moment)
    model.abilities.append(AbilityKind::unstoppable_valour)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::imperium)
    model.keywords.append(Keyword::terminator)
    model.keywords.append(Keyword::captain)
    model.keywords.append(Keyword::octavius)
    model.keywords.append(Keyword::adeptus_astartes)
    model.weapons.append(Weapon::captain_storm_bolter)
    model.weapons.append(Weapon::relic_weapon)
    profile.name = "captain octavious"s
    profile.models.append(model)
    return profile

fun make_death_shadow() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::death_shadow
    model.abilities.append(AbilityKind::infiltrators)
    model.abilities.append(AbilityKind::lone_operative)
    model.abilities.append(AbilityKind::stealth)
    model.abilities.append(AbilityKind::shadow_in_the_warp)
    model.abilities.append(AbilityKind::neural_disruption)
    model.abilities.append(AbilityKind::psychological_saboteur)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::great_devourer)
    model.keywords.append(Keyword::death_shadow)
    model.keywords.append(Keyword::vanguard_invader)
    model.keywords.append(Keyword::neurolictor)
    model.keywords.append(Keyword::tyranids)
    model.weapons.append(Weapon::death_shadow_claws_and_talons)
    profile.name = "death's shadow"s
    profile.models.append(model)
    return profile

fun make_lictor() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::lictor
    model.abilities.append(AbilityKind::infiltrators)
    model.abilities.append(AbilityKind::lone_operative)
    model.abilities.append(AbilityKind::stealth)
    model.abilities.append(AbilityKind::fight_first)
    model.abilities.append(AbilityKind::feeder_tendrils)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::great_devourer)
    model.keywords.append(Keyword::lictor)
    model.keywords.append(Keyword::vanguard_invader)
    model.keywords.append(Keyword::tyranids)
    model.weapons.append(Weapon::lictor_claws_and_talons)
    profile.name = "lictor"s
    profile.models.append(model)
    return profile

fun make_von_ryan_leaper() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::von_ryan_leaper
    model.abilities.append(AbilityKind::infiltrators)
    model.abilities.append(AbilityKind::stealth)
    model.abilities.append(AbilityKind::fight_first)
    model.abilities.append(AbilityKind::pouncing_leap)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::von_ryan_leaper)
    model.keywords.append(Keyword::great_devourer)
    model.keywords.append(Keyword::vanguard_invader)
    model.keywords.append(Keyword::tyranids)
    model.weapons.append(Weapon::leapers_talon)
    profile.name = "von ryan's leaper"s
    profile.models.append(model)
    profile.models.append(model)
    profile.models.append(model)
    return profile

fun make_aranis_zarkan() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::aranis_zarkan
    model.abilities.append(AbilityKind::dark_pacts)
    model.abilities.append(AbilityKind::leader)

    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::psyker)
    model.keywords.append(Keyword::chaos)
    model.keywords.append(Keyword::master_of_possession)
    model.keywords.append(Keyword::aranis_zarkan)
    model.weapons.append(Weapon::rite_of_possession)
    model.weapons.append(Weapon::rite_of_possession_focused)
    model.weapons.append(Weapon::staff_of_possession)
    profile.name = "aranis zarkan"s
    profile.models.append(model)
    return profile

fun make_possessed() -> Unit:
    let profile : Unit 
    let model : Model
    
    model.profile = Profile::possessed
    
    model.abilities.append(AbilityKind::dark_pacts)
    
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::chaos)
    model.keywords.append(Keyword::daemon)      
    model.keywords.append(Keyword::possessed)   

    model.weapons.append(Weapon::hideous_mutations)
    
    profile.name = "Possessed"s
    for i in range(5):
        profile.models.append(model)
    return profile

fun make_cultist_mob() -> Unit:
    let profile : Unit
    let champion : Model
    champion.profile = Profile::cultist_mob
    champion.abilities.append(AbilityKind::dark_pacts)
    champion.keywords.append(Keyword::infantry)
    champion.keywords.append(Keyword::chaos)
    champion.keywords.append(Keyword::damned)
    champion.keywords.append(Keyword::cultist_mob) 
    champion.weapons.append(Weapon::cultist_bolt_pistol)
    champion.weapons.append(Weapon::brutal_assault_weapon)

    let i = 0
    while i != 9:
        let cultist : Model
        cultist.profile = Profile::cultist_mob
        cultist.abilities.append(AbilityKind::dark_pacts)
        cultist.keywords.append(Keyword::infantry)
        cultist.keywords.append(Keyword::chaos)
        cultist.keywords.append(Keyword::damned)
        cultist.keywords.append(Keyword::cultist_mob)
        cultist.weapons.append(Weapon::cultist_autopistol)
        cultist.weapons.append(Weapon::brutal_assault_weapon)
        profile.models.append(cultist)
        i = i + 1

    profile.models.append(champion)

    profile.name = "Cultist Mob"s
    return profile

fun make_legionaries() -> Unit:
    let profile : Unit
    profile.name = "Legionaries (10 models)"s

    # Prepare a single Model object with shared stats, abilities, and keywords
    let model : Model
    model.profile = Profile::legionaries
    model.abilities.append(AbilityKind::dark_pacts)
    # model.abilities.append(AbilityKind::veterans_of_the_long_war)  # if you’ve defined it

    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::chaos)
    model.keywords.append(Keyword::damned)
    model.keywords.append(Keyword::legionaries)
    # model.keywords.append(Keyword::battleline)  # if you’ve defined it

    # 1) ASPIRING CHAMPION
    model.weapons.clear()
    model.weapons.append(Weapon::plasma_pistol_standard)
    model.weapons.append(Weapon::plasma_pistol_supercharge)
    model.weapons.append(Weapon::accursed_weapon)
    profile.models.append(model)  # This copies champion’s state into the unit

    # 2) LEGIONARY with Meltagun
    model.weapons.clear()
    model.weapons.append(Weapon::bolt_pistol)
    model.weapons.append(Weapon::meltagun)
    model.weapons.append(Weapon::close_combat_weapon)
    profile.models.append(model)  # Copies meltagun loadout

    # 3) LEGIONARY with Heavy Bolter
    model.weapons.clear()
    model.weapons.append(Weapon::bolt_pistol)
    model.weapons.append(Weapon::heavy_bolter)
    model.weapons.append(Weapon::close_combat_weapon)
    profile.models.append(model)  # Copies heavy bolter loadout

    # 4) 7 LEGIONARIES with Boltgun
    for i in range(7):
        model.weapons.clear()
        model.weapons.append(Weapon::bolt_pistol)
        model.weapons.append(Weapon::boltgun)
        model.weapons.append(Weapon::close_combat_weapon)
        profile.models.append(model)  # Copies boltgun loadout each time

    return profile

fun make_beastboss_morgrim() -> Unit:
    let boss_unit : Unit
    let boss_model : Model
    
    # Use the pre-defined profile for Beastboss Morgrim
    boss_model.profile = Profile::beastboss_morgrim
    boss_model.abilities.append(AbilityKind::leader)
    boss_model.abilities.append(AbilityKind::beast_snagga)
    boss_model.abilities.append(AbilityKind::warboss)
    boss_model.abilities.append(AbilityKind::beastboss)
    boss_model.abilities.append(AbilityKind::morgrim)
    
    boss_model.keywords.append(Keyword::infantry)
    boss_model.keywords.append(Keyword::character)
    boss_model.keywords.append(Keyword::beastboss)

    boss_model.weapons.append(Weapon::beat_boss_shoota)

    boss_model.weapons.append(Weapon::beast_snagga_klaw)

    boss_model.weapons.append(Weapon::beastchoppa)

    boss_unit.models.append(boss_model)
    boss_unit.name = "Beastboss Morgrim"s
    return boss_unit

fun make_beast_snagga_boyz() -> Unit:
    let unit : Unit
    unit.name = "Beast Snagga Boyz"s
    let nob_model : Model
    nob_model.profile = Profile::beast_snagga_nob
    nob_model.abilities.append(AbilityKind::beast_snagga)
    nob_model.keywords.append(Keyword::infantry)
    nob_model.keywords.append(Keyword::mob)
    nob_model.keywords.append(Keyword::monster_hunters)
    nob_model.weapons.append(Weapon::slugga)
    nob_model.weapons.append(Weapon::power_snappa)
    unit.models.append(nob_model)
    let thumpgun_boy : Model
    thumpgun_boy.profile = Profile::beast_snagga_boy
    thumpgun_boy.abilities.append(AbilityKind::beast_snagga)
    thumpgun_boy.keywords.append(Keyword::infantry)
    thumpgun_boy.keywords.append(Keyword::mob)
    thumpgun_boy.keywords.append(Keyword::monster_hunters)

    thumpgun_boy.weapons.append(Weapon::thump_gun)
    thumpgun_boy.weapons.append(Weapon::close_combat_weapon)

    unit.models.append(thumpgun_boy)

    let boy : Model
    boy.profile = Profile::beast_snagga_boy
    boy.abilities.append(AbilityKind::beast_snagga)
    boy.keywords.append(Keyword::infantry)
    boy.keywords.append(Keyword::mob)
    boy.keywords.append(Keyword::monster_hunters)

    boy.weapons.append(Weapon::slugga)
    boy.weapons.append(Weapon::choppa)

    for i in range(8):
        unit.models.append(boy)

    return unit

fun make_squighog_boyz() -> Unit:
    let unit : Unit
    unit.name = "Squighog Boyz"s

    let nob_model : Model
    nob_model.profile = Profile::nob_on_smasha_squig
    nob_model.abilities.append(AbilityKind::beast_snagga)
    nob_model.keywords.append(Keyword::mounted)
    nob_model.keywords.append(Keyword::beast_snagga)
    nob_model.keywords.append(Keyword::squighog_boyz)
    
    # Weapons: slugga, big choppa, squighog_jaws
    nob_model.weapons.append(Weapon::slugga)
    nob_model.weapons.append(Weapon::big_choppa)
    nob_model.weapons.append(Weapon::squighog_jaws)
    
    unit.models.append(nob_model)

    # 2) 3 standard Squighog Boyz
    for i in range(3):
        let hog_boy : Model
        hog_boy.profile = Profile::squighog_boyz
        hog_boy.abilities.append(AbilityKind::beast_snagga)
        hog_boy.keywords.append(Keyword::mounted)
        hog_boy.keywords.append(Keyword::beast_snagga)
        hog_boy.keywords.append(Keyword::squighog_boyz)

        # Weapons: saddlegit_weapons, stikka_ranged, squighog_jaws
        hog_boy.weapons.append(Weapon::saddlegit_weapons)
        hog_boy.weapons.append(Weapon::stikka_ranged)
        hog_boy.weapons.append(Weapon::squighog_jaws)

        unit.models.append(hog_boy)

    return unit


fun make_octavious_strike_force(UnitVector out, Bool owner) -> Faction:
    out.append(make_octavius())
    out.back().owned_by_player1 = owner
    out.append(make_tantus())
    out.back().owned_by_player1 = owner
    out.append(make_infernus_squad())
    out.back().owned_by_player1 = owner
    out.append(make_terminator_squad())
    out.back().owned_by_player1 = owner
    return Faction::strike_force_octavius

fun make_insidious_infiltrators(UnitVector out, Bool owner) -> Faction:
    out.append(make_death_shadow())
    out.back().owned_by_player1 = owner
    out.append(make_lictor())
    out.back().owned_by_player1 = owner
    for i in range(3):
        out.append(make_von_ryan_leaper())
        out.back().owned_by_player1 = owner
    return Faction::insidious_infiltrators

fun make_zarkan_deamonkin(UnitVector out, Bool owner) -> Faction:
    out.append(make_aranis_zarkan())
    out.back().owned_by_player1 = owner
    out.append(make_possessed())
    out.back().owned_by_player1 = owner
    out.append(make_cultist_mob())
    out.back().owned_by_player1 = owner
    out.append(make_legionaries())
    out.back().owned_by_player1 = owner
    return Faction::insidious_infiltrators

fun make_morgrim_butchas(UnitVector out, Bool owner) -> Faction:
    out.append(make_beastboss_morgrim())
    out.back().owned_by_player1 = owner
    out.append(make_squighog_boyz())
    out.back().owned_by_player1 = owner
    out.append(make_beast_snagga_boyz())
    out.back().owned_by_player1 = owner
    out.append(make_beast_snagga_boyz())
    out.back().owned_by_player1 = owner
    return Faction::insidious_infiltrators
