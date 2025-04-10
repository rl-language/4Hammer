# units.rl

## cls Model

### Fields

* BoardPosition position
* Profile profile
* Wounds suffered_wounds
* WeaponsVector weapons
* Abilities abilities
* Keywords keywords
* ModelState state

### Methods

* fun `base_size_in_inches()  -> Float`
```
 required
```
* fun `is_below_half_wounds()  -> Bool`
* fun `has_keyword(Keyword keyword)  -> Bool`
* fun `has_weapon_rule(WeaponRuleKind rule)  -> Bool`
* fun `has_ability(AbilityKind kind)  -> Bool`
* fun `consolidate_torward(Unit other) `
* fun `is_character()  -> Bool`
* fun `distance(Model model)  -> Float`
* fun `wounds_left()  -> Int`

## cls ModelID

### Fields

* BInt<0, MAX_UNIT_MODELS> id

### Methods

* fun `get()  -> Int`

## cls UnitID

### Fields

* BInt<0, MAX_UNIT_COUNT> id

### Methods

* fun `get()  -> Int`
* fun `assign(Int value) `

## cls PhaseModifiers

### Fields

* Bool greater_strenght_wound_protection

## cls Unit

### Fields

* ModelVector models
* Bool owned_by_player1
* Hidden<String> name
* Bool has_moved
* Bool has_run
* Bool has_fought
* Bool has_shoot
* Bool battle_socked
* Bool has_charged
* Bool can_shoot
* Bool can_charge
* ModelID starting_strenght
* PhaseModifiers phase_modifiers

### Methods

* fun `has_greater_strenght_wound_protection()  -> Bool`
```
 required
 required
 required
```
* fun `clear_phase_modifiers() `
* fun `is_lone_operative()  -> Bool`
* fun `remove_figth_on_death_models() `
* fun `can_reroll_charge()  -> Bool`
* fun `owner_id()  -> Int`
* fun `get_temporary_weapon_rules()  -> BoundedVector<WeaponRule, 1>`
* fun `empty()  -> Bool`
* fun `consolidate_torward(Unit other) `
* fun `attach_to(Unit other) `
* fun `get_leadership()  -> Int`
* fun `has_temporary_wepon_rule(WeaponRuleKind rule)  -> Bool`
* fun `is_below_half_strenght()  -> Bool`
* fun `get_temporary_weapon_parameter(WeaponRuleKind rule)  -> Int`
* fun `max_weapon_parameter(Weapon w, WeaponRuleKind kind)  -> Int`
* fun `all_have_ability(AbilityKind kind)  -> Bool`
* fun `all_have_keyword(Keyword kind)  -> Bool`
* fun `has_keyword(Keyword kind)  -> Bool`
* fun `has_ability(AbilityKind kind)  -> Bool`
* fun `get_unit_toughtness()  -> Int`
* fun `translate(Int x, Int y) `
* fun `move_to(BoardPosition new_position) `
* fun `translate(Vector2D v) `
* fun `distance(BoardPosition position)  -> Float`
* fun `distance(Unit unit)  -> Float`
* fun `distance(Model model)  -> Float`
* fun `get_shortest_vector_to(Unit other)  -> Vector2D`
* fun `get_shortest_vector_to(Model model)  -> Vector2D`
* fun `get_nearest_model_index(Model model)  -> Int`
* fun `distance(Vector2D position)  -> Float`
* fun `get(Int model_id)  -> ref Model`
* fun `get(ModelID model_id)  -> ref Model`
* fun `arrange() `
* fun `damage(Int target_model_id, Int damage)  -> Bool`
* fun `damage(Int target_model_id, Int damage, Bool fight_on_death)  -> Bool`
* fun `damage(ModelID target_model_id)  -> Bool`
* fun `deal_mortal_wound_damage(Int wounds) `


### Free functions

* fun `unit_id(Int id)  -> UnitID`
* fun `make_tantus()  -> Unit`
* fun `make_infernus_squad()  -> Unit`
* fun `make_terminator_squad()  -> Unit`
* fun `make_octavius()  -> Unit`
* fun `make_death_shadow()  -> Unit`
* fun `make_lictor()  -> Unit`
* fun `make_von_ryan_leaper()  -> Unit`
* fun `make_aranis_zarkan()  -> Unit`
* fun `make_possessed()  -> Unit`
* fun `make_cultist_mob()  -> Unit`
* fun `make_legionaries()  -> Unit`
* fun `make_beastboss_morgrim()  -> Unit`
* fun `make_beast_snagga_boyz()  -> Unit`
* fun `make_squighog_boyz()  -> Unit`
* fun `make_tristrean()  -> Unit`
* fun `make_custodian_guard()  -> Unit`
* fun `make_custodian_wardens()  -> Unit`
* fun `make_allarus_custodians()  -> Unit`
* fun `make_octavious_strike_force(UnitVector out, Bool owner)  -> Faction`
* fun `make_insidious_infiltrators(UnitVector out, Bool owner)  -> Faction`
* fun `make_zarkan_deamonkin(UnitVector out, Bool owner)  -> Faction`
* fun `make_morgrim_butchas(UnitVector out, Bool owner)  -> Faction`
* fun `make_tristrean_gilded_blade(UnitVector out, Bool owner)  -> Faction`
* fun `make_master_zacharial()  -> Unit`
* fun `make_intercessor_squad()  -> Unit`
* fun `make_hellblaster_squad()  -> Unit`
* fun `make_bladeguard_veteran_squad()  -> Unit`
* fun `make_vengeful_brethren(UnitVector out, Bool owner)  -> Faction`
