import factions.orks.queries

# Model/component property contracts. Queries do not mutate game state; an
# additive grant does not erase intrinsic rules. Source-aware appenders mutate
# only their output collection. Concrete rules/citations: orks/queries.rl and
# https://wahapedia.ru/wh40k11ed/factions/orks/ (Army Rules and named cards).

# Override one model's keyword: negative removes, zero defers to its intrinsic
# keywords, positive grants. Current exceptions are Lifted/Fly, Blastajet/Smoke
# and the attached Painboss's Infantry-to-Mounted conversion (Orks cards).
fun faction_keyword_override(Model model, Keyword keyword) -> Int:
    return orks_keyword_override(model, keyword)

# Add a model-local ability permission; false leaves the ordinary ability
# lookup intact. Covers Nazdreg's Deep Strike and borrowed psychic abilities;
# unit-wide grants use faction_unit_grants_ability instead (Orks cards).
fun faction_model_grants_intrinsic_ability(Model model, AbilityKind kind) -> Bool:
    return orks_model_grants_intrinsic_ability(model, kind)

# Return additive inches for this bearer's M characteristic, not its final
# movement allowance. Core still applies characteristic modifiers/bounds.
# Current sources: Painboss's mounted conversion and Cybork Boosta.
fun faction_movement_bonus(Model model) -> Int:
    return orks_movement_bonus(model)

# Return the additive bearer-only T bonus from It Came From Da Drops.
# Zero means no contribution; core owns the remaining characteristic arithmetic.
fun faction_toughness_bonus(Model model) -> Int:
    return orks_toughness_bonus(model)

# Return an absolute InSv target, including the printed base and faction
# permissions; lower is better, a value above 6 means no usable save.
# Riled-up/Blastajet grant 5+; common granted saves/modifiers are combined later.
fun faction_invulnerable_base(Model model) -> Int:
    return orks_invulnerable_base(model)

# Apply bearer-specific attachment metadata to model while joining leader to
# bodyguard (core pp66-67). Currently marks a Painboss joining Mounted models;
# does not spread its keyword conversion to the bodyguard or authorize attachment.
fun faction_prepare_attached_model(Unit leader, Unit bodyguard, Model model):
    orks_prepare_attached_model(leader, bodyguard, model)

# Read the captured army-rule flag for an original component identity, using
# bodyguard/attached-component records. Used to retain conferred rules during
# destruction (core p67); unlike the singular hook, this does not rescan models.
fun faction_component_has_army_rules(Unit unit, EntityIdentity component) -> Bool:
    return orks_component_has_army_rules(unit, component)

# Identify whether this model can confer faction army rules, independently of
# whether it is currently alive. Core uses this fact when retaining a destroyed
# source through an attack (core p67): Waaagh! or a unit-wide riled-up passive.
fun faction_model_confers_army_rules(Model model) -> Bool:
    return orks_model_confers_army_rules(model)

# Answer whether faction status adds this weapon rule to this model/profile;
# false does not remove the weapon's own rules. Currently riled-up adds ranged
# Assault. Use the appender below when individual source provenance is required.
fun faction_model_has_weapon_rule(Model model, Weapon profile, WeaponRuleKind kind) -> Bool:
    return orks_model_has_weapon_rule(model, profile, kind)

# Append ranged Assault once per riled-up source key to rules, keeping each
# grant independently identifiable/expirable. Does not clear existing instances
# or choose between duplicates; core performs duplicate selection (core p78).
fun append_faction_intrinsic_weapon_rules(Model model, Weapon weapon, WeaponAbilitySet rules):
    append_riled_assault_rules(model, weapon, rules)

# Test War Horde's melee Sustained Hits eligibility for a battlefield source
# and selected weapon. This is a duplicate-rule selection gate, not an appender;
# it neither grants the rule immediately nor consumes a use (Get Stuck In).
fun faction_melee_sustained_rule_applies(Board board, UnitID source, Weapon weapon) -> Bool:
    return war_horde_melee_rule_applies(board, source, weapon)

# Scan models with original_unit == component for their Waaagh! flag when
# capturing attachment metadata (core pp66-67). This reads model membership;
# the plural hook reads the resulting stored component flag instead.
fun faction_component_has_army_rule(Unit unit, EntityIdentity component) -> Bool:
    return component_has_waaagh(unit, component)
