import factions.orks.queries

# Calculation/event-specific contracts for any army implementation. Queries
# are pure; appenders mutate only their initialized output. Actions borrow
# original contexts, finish accepted work atomically and restore controller
# ownership. Core owns common mechanics, sequencing and frame lifetime.
# See README.md and doc/army-api.md; named rule citations belong in adapters.

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

# Capture component rule-conferral metadata before attachment, independently
# of whether an ability is currently activatable. Core retains this snapshot
# through the destroying attack; live survivors alone are insufficient (p67).
# No applicable conferral returns false. Do not mutate membership or state.
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
