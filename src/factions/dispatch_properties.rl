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
# Return the additive contribution to this model's T characteristic, or zero.
# Core combines it with stored modifiers and applies characteristic limits.
# Unit-level selection of which model's toughness to use is a separate step.
# Return the absolute InSv base for this model, including its printed base;
# lower is better, above 6 means no usable base save. With no faction grant,
# return profile.invuln_save(), not zero. Core then chooses the better shared
# granted save and applies characteristic modifiers/limits.
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
# Compatibility contract: true makes model_weapon_rules append one distinct
# Sustained Hits 1 instance for this battlefield source/weapon. Return false
# unless that exact melee grant applies, including source validity. Core owns
# duplicate selection; this interface cannot express another rule or parameter.
fun faction_component_has_army_rule(Unit unit, EntityIdentity component) -> Bool:
    return component_has_waaagh(unit, component)

# Append characteristic arithmetic for this exact model and characteristic.
# Only the supplied modifiers may change. Core evaluates replacement/order,
# rounding, unmodifiable values and final limits (appendix02.02.01).
fun append_model_modifiers(Model model, ModifiedCharacteristic kind, RuleModifiers modifiers):
    append_orks_model_modifiers(model, kind, modifiers)

# Establish a model-local save permission, before characteristic modifiers.
# base is caller-owned, initially the printed/common granted target; lower is
# better and >6 means none. Never turn this into arithmetic (core p19).
fun append_model_save_permissions(Model model, InvulnerableSavePermission permission):
    append_orks_model_save_permissions(model, permission)
