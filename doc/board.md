# board.rl

## cls AttackSequenceInfo

### Fields

* UnitID source_unit_id
* UnitID target_unit_id
* Bool penetration_bonus
* Bool hit_roll_bonus
* Bool hit_roll_malus
* BoundedVector<Profile, 3> profile_hit_roll_bonus
* BoundedVector<WeaponRule, 3> temporary_weapon_abilities
* Bool wound_roll_malus
* Bool wound_roll_bonus
* BoundedVector<Profile, 3> profile_wound_roll_bonus
* Bool reroll_hits
* Bool reroll1_hits
* Bool only_hits_on_6
* Bool reroll_wounds
* Bool reroll1_wounds
* Bool greater_strenght_wound_protection
* Bool fight_on_death
* Dice fight_on_death_roll
* Int target_toughness
* Weapon source
* Profile source_profile
* BInt<0, MAX_ROUNDS> current_round

### Methods

* fun `add_letal_hits() `
```
 required
 required
```
* fun `add_sustained_hits(Int parameter) `
* fun `max_weapon_parameter(Board board, WeaponRuleKind kind)  -> Int`
* fun `has_weapon_rule(Board board, WeaponRuleKind kind)  -> Bool`
* fun `total_hit_modifier()  -> Int`
* fun `total_wound_modifier()  -> Int`

## cls PhaseInfo

### Fields

* AlreadyUsedStratagems[2] already_used_stratagems

## cls Board

### Fields

* UnitVector units
* UnitVector reserve_units
* UnitID oath_of_moment_target
* Bool[2] has_used_shadow_in_the_warp
* AttackSequenceInfo attack_info
* Bool[2] obtained_extra_cp_this_round
* LinearlyDistributedInt<0, MAX_CP>[2] command_points
* LinearlyDistributedInt<0, MAX_ROUNDS> current_round
* Bool current_player
* Bool starting_player
* Bool current_decision_maker
* Faction[2] players_faction
* LinearlyDistributedInt<0, 50>[2] score
* Bool[4][2] pinned_objectives
* PhaseInfo phase_info
* Attack attack
* Overwatch overwatch
* RerollableDice current_roll
* RerollableDicePair current_pair_roll
* CurrentStateDescription current_state

### Methods

* fun `clear_phase_modifiers() `
```
 required
 required
```
* fun `get_current_player_faction()  -> Faction`
* fun `add_extra_cp(Int player_id) `
* fun `get_current_attacking_model()  -> ref Model`
* fun `get_score(Int player_id)  -> Int`
* fun `any_enemy_in_range_has_ability(Unit unit, Float allowed_range, AbilityKind ability)  -> Bool`
* fun `can_use_strat(Bool player, Stratagem strat)  -> Bool`
* fun `pay_strat(Bool player, Stratagem strat) `
* fun `mark_strat_used(Stratagem strat, Int player) `
* fun `has_used_strat(Stratagem strat, Int player)  -> Bool`
* fun `get(Int unit_id)  -> ref Unit`
* fun `get(UnitID unit_id)  -> ref Unit`
* fun `count_models(Int player_id)  -> Int`
* fun `is_in_melee(Unit u)  -> Bool`
* fun `faction_of_unit(UnitID id)  -> Faction`
* fun `least_distance_from_player_units(BoardPosition position, Bool player)  -> Float`
* fun `is_position_valid_for_reserve(BoardPosition position, Unit unit)  -> Bool`
* fun `remove_empty_units() `
* fun `get_objective_controller(Int x, Int y)  -> Int`
* fun `score_objective(Int x, Int y, Int objective_id) `
* fun `get_objective_controller(Int objective_id)  -> Int`
* fun `get_objectives_locations()  -> Vector<BoardPosition>`
* fun `score() `


### Free functions

* fun `append_to_string(ModelID to_add, String output) `
* fun `parse_string(ModelID result, String buffer, Int index)  -> Bool`
* fun `append_to_string(UnitID to_add, String output) `
* fun `parse_string(UnitID result, String buffer, Int index)  -> Bool`
