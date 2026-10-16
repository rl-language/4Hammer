import source_effects

# Active source keys govern grants in every bank (01.02.02/01.02.04).
fun model_rule_effect(Board board, Model model, RuleEffectKind kind) -> Int:
    let amount = 0
    for effect_index in range(model.rule_effects.size()):
        ref effect = model.rule_effects[effect_index]
        if effect.kind.value == kind.value and source_grant_active(board, effect.source_effect):
            amount = amount + max(1, effect.amount.value)
    return amount

# Unit-wide grants are counted once, not once per recipient model.
fun unit_rule_effect(Board board, Unit unit, RuleEffectKind kind) -> Int:
    for model_index in range(unit.models.size()):
        if model_confers_attached_abilities(unit[model_index]) or unit[model_index].state == ModelState::fight_on_death:
            return model_rule_effect(board, unit[model_index], kind)
    return 0

# Common restrictions are source-owned permissions, independent of their trigger
# (01.02.02; ordinary charge/action/flight rules pp38/58/33).
fun rule_charge_allowed(Board board, Unit unit) -> Bool:
    return unit_rule_effect(board, unit, RuleEffectKind::no_charge) == 0

# Action permission is distinct from move/charge permission (core p58).
fun rule_action_allowed(Board board, Unit unit) -> Bool:
    return unit_rule_effect(board, unit, RuleEffectKind::no_action) == 0

# Grounding restricts flight without changing ordinary movement (core p33).
fun rule_flight_allowed(Board board, Unit unit) -> Bool:
    return unit_rule_effect(board, unit, RuleEffectKind::grounded) == 0

# Fights First grants augment intrinsic abilities for each participating model
# (core p40); expiry removes their keyed collection entries.
fun model_has_fights_first_grant(Model model) -> Bool:
    for status_index in range(model.rule_effects.size()):
        if model.rule_effects[status_index].kind.value == RuleEffectKind::fights_first.value:
            return true
    return false

# Save/load validates explicit bounded status data and provenance; infrastructure
# for persisting effects, not an additional tabletop rule (01.02.02).
fun valid_rule_effect(RuleEffectGrant grant) -> Bool:
    if grant.kind.value == RuleEffectKind::invulnerable_save.value and (grant.amount.value < 2 or grant.amount.value > 6):
        return false
    return grant.kind.value > 0 and grant.kind.value <= max(grant.kind) and grant.source_effect.value >= 0 and grant.source_effect.value < MAX_SOURCE_EFFECT_KEY and grant.amount.value >= 0 and grant.amount.value < MAX_CHARACTERISTIC and grant.associated_unit.value >= 0 and grant.associated_unit.value < MAX_IDENTITY_SEQUENCE

# A granted save can establish an absent InSv and never worsens a better base;
# ordinary characteristic modifiers are applied afterward (core p19/02.02.01).
fun granted_invulnerable_base(Model model, Int base) -> Int:
    for status_index in range(model.rule_effects.size()):
        if model.rule_effects[status_index].kind.value == RuleEffectKind::invulnerable_save.value:
            base = min(base, model.rule_effects[status_index].amount.value)
    return base

# Common granted keywords are additive; faction-specific overrides still own
# their printed removals/conversions (core p67, persisting effects01.02.02).
fun model_rule_keyword_granted(Model model, Keyword keyword) -> Bool:
    for status_index in range(model.rule_effects.size()):
        if keyword == Keyword::mobile and model.rule_effects[status_index].kind.value == RuleEffectKind::mobile.value:
            return true
    return false

# A source may grant the standard Deep Strike ability without changing the
# model's intrinsic datasheet ability list (core p69/01.02.02).
fun model_rule_ability_granted(Model model, AbilityKind kind) -> Bool:
    for status_index in range(model.rule_effects.size()):
        if kind == AbilityKind::deep_strike and model.rule_effects[status_index].kind.value == RuleEffectKind::deep_strike.value:
            return true
    return false
