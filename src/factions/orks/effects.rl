import rule_effects
import board
import source_effects

# Non-characteristic grants are keyed to the same expiry machinery as ordinary
# modifiers (01.02.02); no stale declaration can resurrect an expired grant.
# Effects installed on an entire unit count one source once, rather than
# adding the same grant for each recipient (e.g. Advance+2 and Leadership-1).
# Every sourced grant uses a stable rule/unit handle, reused on later phases;
# effect identity, not a mutable source payload, owns each installed copy.
# Orks cards and appendix01.02.02; no additional rule-use limit is invented.
fun grant_orks_effect(Board board, UnitID source, UnitID target, Int rule, RuleEffectKind kind, Int amount, SourceDuration duration, EntityIdentity associated):
    let grant : RuleEffectGrant
    grant.kind = kind
    grant.amount = amount
    grant.associated_unit = associated
    let payload : SourceGrant
    payload = grant
    grant_orks_typed_payload(board, board[source].identity, board[source].owned_by_player1, board[target].identity, rule, payload, duration)

# Characteristic grants use the same keyed lifecycle as flag grants. Multiple
# typed payloads remain separate sources, not flattened final values (02.02.01).
fun grant_orks_typed_payload(Board board, EntityIdentity source, Bool owner, EntityIdentity target, Int rule, SourceGrant payload, SourceDuration duration):
    let instance : SourceInstance
    instance.rule = rule
    instance.label.value = SourceLabel::orks_detachment_modifier
    instance.source_unit = source
    instance.owner = owner
    instance.recipient = SourceTarget::target_unit
    instance.duration = duration
    instance.offboard_allowed = true
    instance.allow_retained_source = true
    instance.grant = payload
    commit_reusable_unit_grant(board, instance, target)

# UnitID callers and own-unit bank adapters share one keyed source installer.
# Effects retain identity and duration across transfers (01.02.02/01.02.04).
fun grant_orks_typed_payload(Board board, UnitID source, UnitID target, Int rule, SourceGrant payload, SourceDuration duration):
    grant_orks_typed_payload(board, board[source].identity, board[source].owned_by_player1, board[target].identity, rule, payload, duration)

# Own-unit grants never measure a range; use the same lifetime/key handling
# on battlefield, in reserves and embarked (appendix01.02.04).
fun grant_orks_own_payload(Board board, Unit unit, Int rule, SourceGrant payload, SourceDuration duration):
    grant_orks_typed_payload(board, unit.identity, unit.owned_by_player1, unit.identity, rule, payload, duration)

# The typed overload preserves the finite generated binding surface while
# sharing the same installer and expiry logic (appendix01.02.02).
fun grant_orks_own_payload(Board board, Unit unit, Int rule, RuleEffectGrant payload, SourceDuration duration):
    let typed : SourceGrant
    typed = payload
    grant_orks_own_payload(board, unit, rule, typed, duration)

# Concrete alternatives keep the exported binding surface finite; the common
# keyed installer owns expiry and provenance for both printed payload kinds.
fun grant_orks_payload(Board board, UnitID source, UnitID target, Int rule, SourceGrant payload, SourceDuration duration):
    let typed : SourceGrant
    typed = payload
    grant_orks_typed_payload(board, source, target, rule, typed, duration)

# Characteristic changes enter the same ordered modifier/source pipeline.
fun grant_orks_payload(Board board, UnitID source, UnitID target, Int rule, CharacteristicModifier payload, SourceDuration duration):
    let typed : SourceGrant
    typed = payload
    grant_orks_typed_payload(board, source, target, rule, typed, duration)

# Derived weapon rules retain the actual source expiry key in their immutable
# declaration; a later phase cannot revive a stale grant (01.02.02/p78).
fun append_orks_effect_ability(Board board, Model model, RuleEffectKind effect_kind, WeaponRuleKind weapon_kind, Int amount, WeaponAbilitySet rules):
    for effect in range(model.rule_effects.size()):
        if model.rule_effects[effect].kind.value == effect_kind.value and source_grant_active(board, model.rule_effects[effect].source_effect):
            let rule = weapon_rule(weapon_kind, amount)
            rule.source_effect = model.rule_effects[effect].source_effect
            rules.append(rule)

# Starting equipment includes intrinsic data, not a copy of old timed buffs.
# New physical weapon use starts from the battle-start template (01.02.10).
# Temperamental Shokka grants are bearer-only and named-weapon scoped. Copying
# one model's upgrade to every carrier/unit member would change the card rule.
fun grant_orks_model_effect(Board board, UnitID source, ModelID bearer, Int rule, RuleEffectKind kind):
    let instance : SourceInstance
    instance.rule = rule
    instance.owner = board[source].owned_by_player1
    instance.source_unit = board[source].identity
    instance.source_model = board[source][bearer].identity
    instance.recipient = SourceTarget::source_model
    instance.duration = SourceDuration::phase
    instance.label.value = SourceLabel::temperamental_shokka
    if kind.value == RuleEffectKind::boss_ammo_hit.value:
        instance.label.value = SourceLabel::boss_ammo_runt
    let effect : RuleEffectGrant
    effect.kind = kind
    effect.amount = 1
    instance.grant = effect
    let handle = register_source_instance(board, instance)
    commit_source_effect_to_unit(board, instance, handle.value, board[source].identity)

# Source-owned removal scans every bank/archive, preserving equal buffs from
# unrelated sources. Infrastructure for Madcap's explicit 'until ... has shot'.

# One typed status installs all three printed riled benefits through consumers,
# with exact-key expiry rather than independent buff lifetimes (Orks Waaagh!).
fun riled_up_grant() -> SourceGrant:
    let grant : RuleEffectGrant
    grant.kind = RuleEffectKind::riled_up
    grant.amount = 1
    let result : SourceGrant
    result = grant
    return result
