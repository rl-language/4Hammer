import bounded_arg
import stats
import vector2d
import machine_learning

using Wounds = LinearlyDistributedInt<0, 10>
const MAX_WEAPONS = 4
using WeaponsVector = BoundedVector<Weapon, MAX_WEAPONS>
using Abilities = BoundedVector<AbilityKind, 4>
using Keywords = BoundedVector<Keyword, 7>


cls Model:
    BoardPosition position # required
    Profile profile
    Wounds suffered_wounds
    WeaponsVector weapons
    Abilities abilities 
    Keywords keywords 

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

using ModelVector = BoundedVector<Model, 7>

cls ModelID: # required
    BInt<0, 7> id

    fun get() -> Int:
        return self.id.value

const MAX_UNIT_COUNT = 10
cls UnitID: # required
    BInt<0, MAX_UNIT_COUNT> id

    fun get() -> Int:
        return self.id.value

    fun assign(Int value):
        self.id = value

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
    ModelID starting_strenght
    PhaseModifiers phase_modifiers

    fun has_greater_strenght_wound_protection() -> Bool:
        return self.phase_modifiers.greater_strenght_wound_protection 

    fun clear_phase_modifiers():
        let mod : PhaseModifiers
        self.phase_modifiers = mod

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

    fun arrange():
        if self.models.size() == 1:
            return
        let i = 1
        while i != self.models.size():
            ref model = self.models[i]
            model.position = self.models[i-1].position
            model.position.x = model.position.x + int(1.0 + model.base_size_in_inches())
            i = i + 1

    fun damage(Int target_model_id, Int damage):
        ref target_model = self.models[target_model_id]
        target_model.suffered_wounds = target_model.suffered_wounds + damage 
        if target_model.suffered_wounds >= target_model.profile.wounds(): 
            self.models.erase(target_model_id)
        


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

fun make_octavious_strike_force(UnitVector out, Bool owner):
    out.append(make_octavius())
    out.back().owned_by_player1 = owner
    out.append(make_tantus())
    out.back().owned_by_player1 = owner
    out.append(make_infernus_squad())
    out.back().owned_by_player1 = owner
    out.append(make_terminator_squad())
    out.back().owned_by_player1 = owner
