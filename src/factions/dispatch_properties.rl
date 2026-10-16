import factions.orks.queries


# Property contract between core and faction composition. Queries are pure and
# may be evaluated repeatedly. Model/Unit-only queries use the supplied object
# and installed metadata, without external range measurements. Appenders mutate
# only their result; the attachment preparation command explicitly mutates model.
# Implementations own applicability and source provenance; core owns arithmetic,
# ability aggregation and destruction retention. See README.md for conventions.

# Model.has_keyword expects a tri-state override: negative suppresses its
# intrinsic lookup, zero defers to it, positive grants keyword. Shared keyword
# grants have already been checked and take precedence. Do not mutate keywords;
# return zero when no applicable exception exists.
fun faction_keyword_override(Model model, Keyword keyword) -> Int:
    return orks_keyword_override(model, keyword)

# Model.has_ability ORs this model-local grant with shared grants and its
# stored abilities. Return false when no applicable grant exists. The query
# does not establish life/activation eligibility: core can inspect a retained
# casualty's properties, and unit-level consumers apply their own source gates.
fun faction_model_grants_intrinsic_ability(Model model, AbilityKind kind) -> Bool:
    return orks_model_grants_intrinsic_ability(model, kind)

# Return the additive contribution to this model's M characteristic in inches,
# or zero. Core inserts it into effective_characteristic_value alongside ordered
# modifiers and characteristic limits. Do not return final M, a roll result or
# the distance available for a particular movement mode.
fun faction_movement_bonus(Model model) -> Int:
    return orks_movement_bonus(model)

# Return the additive contribution to this model's T characteristic, or zero.
# Core combines it with stored modifiers and applies characteristic limits.
# Unit-level selection of which model's toughness to use is a separate step.
fun faction_toughness_bonus(Model model) -> Int:
    return orks_toughness_bonus(model)

# Return the absolute InSv base for this model, including its printed base;
# lower is better, above 6 means no usable base save. With no faction grant,
# return profile.invuln_save(), not zero. Core then chooses the better shared
# granted save and applies characteristic modifiers/limits.
fun faction_invulnerable_base(Model model) -> Int:
    return orks_invulnerable_base(model)

# Unit.attach_to calls this on each joining model before copying it into
# bodyguard. Apply model-local consequences of this permitted attachment;
# retain original-component provenance. Mutate model only: core owns the
# component lists, identities and transfer, and eligibility was checked earlier.
fun faction_prepare_attached_model(Unit leader, Unit bodyguard, Model model):
    orks_prepare_attached_model(leader, bodyguard, model)

# Read previously captured army-rule conferral metadata for component, an
# original unit identity inside unit. Return false if it has none. Core uses
# this snapshot to decide destruction retention, so do not replace it with a
# test of currently living members. Capture uses the singular hook below.
fun faction_component_has_army_rules(Unit unit, EntityIdentity component) -> Bool:
    return orks_component_has_army_rules(unit, component)

# Report whether model carries army rules whose conferral requires retention
# through the attack destroying its component. Core combines this with ordinary
# ability metadata when deciding retention. Inspect rule provenance, not current
# life or whether the player can activate the rule now; default false.
fun faction_model_confers_army_rules(Model model) -> Bool:
    return orks_model_confers_army_rules(model)

# Read additional presence of kind on this model/profile during weapon
# eligibility, before target declaration. False leaves ordinary profile/stored
# rules intact. Keep presence consistent with the instance appender below;
# this Boolean cannot select a parameter, source instance or target condition.
fun faction_model_has_weapon_rule(Model model, Weapon profile, WeaponRuleKind kind) -> Bool:
    return orks_model_has_weapon_rule(model, profile, kind)

# Append model-local rule instances for weapon to the existing rules snapshot.
# Keep parameters, conditions and independent source keys; do not select, merge
# or sum duplicate instances. No contribution is a no-op. Core selects among
# duplicates later; applying this twice to one snapshot can duplicate grants.
fun append_faction_intrinsic_weapon_rules(Model model, Weapon weapon, WeaponAbilitySet rules):
    append_riled_assault_rules(model, weapon, rules)

# Compatibility contract: true makes model_weapon_rules append one distinct
# Sustained Hits 1 instance for this battlefield source/weapon. Return false
# unless that exact melee grant applies, including source validity. Core owns
# duplicate selection; this interface cannot express another rule or parameter.
fun faction_melee_sustained_rule_applies(Board board, UnitID source, Weapon weapon) -> Bool:
    return war_horde_melee_rule_applies(board, source, weapon)

# Capture whether models with original_unit == component carry the army-rule
# metadata needed after attachment. Core stores the Boolean in component state;
# the plural hook reads it later. Do not require a currently activatable rule:
# capture and subsequent live/retained-source checks are separate operations.
fun faction_component_has_army_rule(Unit unit, EntityIdentity component) -> Bool:
    return component_has_waaagh(unit, component)
