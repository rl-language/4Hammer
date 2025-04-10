# weapons.rl

## cls WeaponRule

### Fields

* WeaponRuleKind kind
* Int parameter


### Free functions

* fun `raw_stat(Int value)  -> Stat`
* fun `dice_stat(Int value)  -> Stat`
* fun `write_in_observation_tensor(WeaponRuleKind obj, Int observer_id, Vector<Float> output, Int index) `
* fun `size_as_observation_tensor(WeaponRuleKind kind)  -> Int`
* fun `weapon_rule(WeaponRuleKind kind, Int parameter)  -> WeaponRule`
* fun `weapon_rule(WeaponRuleKind kind)  -> WeaponRule`
* fun `no_weapon_rules()  -> WeaponRules`
* fun `weapon_rules()  -> WeaponRules`
* fun `weapon_rules(WeaponRule rule)  -> WeaponRules`
* fun `weapon_rules(WeaponRule rule, WeaponRule rule2)  -> WeaponRules`
* fun `weapon_rules(WeaponRule rule, WeaponRule rule2, WeaponRule rule3)  -> WeaponRules`
* fun `weapon_rules(WeaponRule rule, WeaponRule rule2, WeaponRule rule3, WeaponRule rule4)  -> WeaponRules`
* fun `weapon_rules(WeaponRule rule, WeaponRule rule2, WeaponRule rule3, WeaponRule rule4, WeaponRule rule5)  -> WeaponRules`
* fun `write_in_observation_tensor(Weapon obj, Int observer_id, Vector<Float> output, Int index) `
* fun `size_as_observation_tensor(Weapon kind)  -> Int`
