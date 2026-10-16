import factions.orks.queries

# Neutral properties entrypoints. This composition module is the only layer
# that selects concrete faction behavior; core algorithms do not inspect it.

# Orks active keywords, Blastajet Smoke suppression and Painboss bearer-only Mounted (respective cards; core p67).
fun faction_keyword_override(Model model, Keyword keyword) -> Int:
    return orks_keyword_override(model, keyword)

# Nazdreg Deep Strike and borrowed psychic abilities retain their actual source permissions (Orks cards/Da Jump).
fun faction_model_grants_intrinsic_ability(Model model, AbilityKind kind) -> Bool:
    return orks_model_grants_intrinsic_ability(model, kind)

# Painboss Runnin wiv da Herd and Cybork Boosta improve only the eligible bearer (Orks cards).
fun faction_movement_bonus(Model model) -> Int:
    return orks_movement_bonus(model)

# It Came From Da Drops improves bearer Toughness (Orks enhancement).
fun faction_toughness_bonus(Model model) -> Int:
    return orks_toughness_bonus(model)

# Riled-up, Blastajet Force Field and psychic invulnerable permissions improve the printed base (Orks army/cards).
fun faction_invulnerable_base(Model model) -> Int:
    return orks_invulnerable_base(model)

# Painboss Runnin wiv da Herd changes this attached bearer only (Orks/Painboss; core pp66-67).
fun faction_prepare_attached_model(Unit leader, Unit bodyguard, Model model):
    orks_prepare_attached_model(leader, bodyguard, model)

# Warp Visions grants Fights First; core still checks every participating model (Orks/Wurrband; core p40).
fun faction_fights_first(Model model) -> Bool:
    return orks_fights_first(model)

# Waaagh! attachment metadata follows the actual original component lifetime (Orks army rules; core p67).
fun faction_component_has_army_rules(Unit unit, EntityIdentity component) -> Bool:
    return orks_component_has_army_rules(unit, component)

# Actual Orks army rules can retain a destroyed conferred source during the attack (core p67).
fun faction_model_confers_army_rules(Model model) -> Bool:
    return orks_model_confers_army_rules(model)

# Nazdreg Unit Composition allows its three simultaneous profiles.
fun faction_simultaneous_weapon_profile(Weapon profile) -> Bool:
    return orks_simultaneous_weapon_profile(profile)

# Orks KFF and Pulsa are equipment rather than attacks.
fun faction_nonattacking_equipment(Weapon profile) -> Bool:
    return orks_nonattacking_equipment(profile)

# Waaagh riled-up supplies ranged Assault; core retains intrinsic rules.
fun faction_model_has_weapon_rule(Model model, Weapon profile, WeaponRuleKind kind) -> Bool:
    return orks_model_has_weapon_rule(model, profile, kind)

# Composition hook: queries adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun append_faction_intrinsic_weapon_rules(Model model, Weapon weapon, WeaponAbilitySet rules):
    append_riled_assault_rules(model, weapon, rules)

# Composition hook: queries adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_melee_sustained_rule_applies(Board board, UnitID source, Weapon weapon) -> Bool:
    return war_horde_melee_rule_applies(board, source, weapon)

# Composition hook: queries adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_component_has_army_rule(Unit unit, EntityIdentity component) -> Bool:
    return component_has_waaagh(unit, component)
