import named_identities
import state_types

# Authority: user-supplied appendix 02.02.01, not a quotation from the PDF.
# Operation order is replace, multiply, add, divide, subtract; round up once.
enum ModifierOperation:
    replace
    multiply
    add
    divide
    subtract

const MAX_RULE_MODIFIER = 4097

cls RuleModifier:
    ModifierOperation operation
    LinearlyDistributedInt<0, MAX_RULE_MODIFIER> amount
    Bool negative

    # Signed computation uses two standard bounded fields, without a custom
    # tensor writer or a negative template argument in generated binding names.
    fun signed_amount() -> Int:
        if self.negative:
            return -self.amount.value
        return self.amount.value

using RuleModifiers = CheckedVector<RuleModifier, 16>

# Check the supported modifier range before constructing its bounded standard
# fields (user-supplied appendix 02.02.01; capacity is implementation policy).
fun rule_modifier(ModifierOperation operation, Int amount) -> RuleModifier:
    assert(amount > -MAX_RULE_MODIFIER and amount < MAX_RULE_MODIFIER, "modifier amount capacity exceeded")
    let result : RuleModifier
    result.operation = operation
    result.negative = amount < 0
    result.amount = abs(amount)
    return result

# Generic arithmetic is computed transiently; stored amounts/collections stay
# bounded for inferred ML layout. '-'/'*'/'N/A' callers mark unmodifiable.
# Replacing a value with zero also prevents later modification (02.02.01).
fun apply_rule_modifiers(Int base, RuleModifiers modifiers, Bool unmodifiable, Int extra_addition) -> Int:
    let value = float(base)
    let locked = unmodifiable
    for operation in range(5):
        for i in range(modifiers.size()):
            ref modifier = modifiers[i]
            if locked or modifier.operation.value != operation:
                continue
            if operation == 0:
                value = float(modifier.signed_amount())
                locked = modifier.amount.value == 0
            if operation == 1:
                value = value * float(modifier.signed_amount())
            if operation == 2:
                value = value + float(modifier.signed_amount())
            if operation == 3:
                assert(modifier.amount.value > 0 and !modifier.negative, "modifier division must be positive")
                value = value / float(modifier.amount.value)
            if operation == 4:
                value = value - float(modifier.signed_amount())
        # Core cover/Plunging Fire increments share the addition step (02.02.01).
        if operation == 2 and !locked:
            value = value + float(extra_addition)
    assert(value > -1000000000.0 and value < 1000000000.0, "modifier calculation capacity exceeded")
    let rounded = int(value)
    if float(rounded) < value:
        rounded = rounded + 1
    return rounded

# Compatibility arithmetic entry without an additional core increment (02.02.01).
fun apply_rule_modifiers(Int base, RuleModifiers modifiers, Bool unmodifiable) -> Int:
    return apply_rule_modifiers(base, modifiers, unmodifiable, 0)

enum ModifiedCharacteristic:
    movement
    toughness
    save
    invulnerable_save
    leadership
    objective_control
    range
    attacks
    weapon_skill
    ballistic_skill
    strength
    armour_penetration
    damage
    detection_range

# Characteristic floors/caps are applied after all arithmetic, as supplied in
# appendix 02.02.01. Zero/special replacements are handled before this helper.
fun characteristic_limit(ModifiedCharacteristic kind, Int value) -> Int:
    if kind.value == ModifiedCharacteristic::save.value or kind.value == ModifiedCharacteristic::invulnerable_save.value:
        return max(2, value)
    if kind.value == ModifiedCharacteristic::leadership.value:
        return min(8, max(5, value))
    if kind.value == ModifiedCharacteristic::objective_control.value:
        return max(0, value)
    if kind.value == ModifiedCharacteristic::weapon_skill.value or kind.value == ModifiedCharacteristic::ballistic_skill.value:
        return min(6, max(2, value))
    if kind.value == ModifiedCharacteristic::armour_penetration.value:
        return min(0, value)
    if kind.value == ModifiedCharacteristic::detection_range.value:
        return min(30, max(9, value))
    return max(1, value)

# Do not apply minima to special values or a replacement locked to zero;
# otherwise apply the printed post-modification characteristic bounds.
fun modified_characteristic(Int base, ModifiedCharacteristic kind, RuleModifiers modifiers, Bool unmodifiable, Int extra_addition) -> Int:
    let result = apply_rule_modifiers(base, modifiers, unmodifiable, extra_addition)
    let locked = unmodifiable
    for i in range(modifiers.size()):
        locked = locked or (modifiers[i].operation.value == ModifierOperation::replace.value and modifiers[i].amount.value == 0)
    if locked:
        return result
    return characteristic_limit(kind, result)

# Existing consumers need no extra increment; keep one characteristic policy.
fun modified_characteristic(Int base, ModifiedCharacteristic kind, RuleModifiers modifiers, Bool unmodifiable) -> Int:
    return modified_characteristic(base, kind, modifiers, unmodifiable, 0)

# Rolls are modified after rerolls; hit/wound cumulative changes cap at +/-1,
# all roll results are at least one, and charge totals cap at 12 (02.02.01).
fun modified_dice_result(Int original, RuleModifiers modifiers, Bool hit_or_wound, Bool charge) -> Int:
    let result = apply_rule_modifiers(original, modifiers, false)
    if hit_or_wound:
        result = original + min(1, max(-1, result - original))
    if charge:
        result = min(12, result)
    return max(1, result)

# CP cost can increase by at most one or decrease to zero (02.02.01); this is
# cost policy, separate from the player's bounded CP balance and spending.
fun modified_cp_cost(Int original, RuleModifiers modifiers) -> Int:
    return min(original + 1, max(0, apply_rule_modifiers(original, modifiers, false)))

# Sparse per-bearer arithmetic metadata (appendix02.02.01). Source abilities
# install only their affected models; expiry/source-instance policy belongs to17.E.
# This shares one bounded list rather than sixteen slots for every characteristic.
cls CharacteristicModifier:
    ModifiedCharacteristic characteristic
    RuleModifier modifier
    # Zero affects the bearer/all equipped weapons; nonzero is slot+1.
    # Ordinary bounded storage avoids a separate modifier vector per slot.
    LinearlyDistributedInt<0, MAX_WEAPON_SCOPES> weapon_scope
    # Optional conjunctive name predicates; zero means no named restriction.
    WeaponNameCode weapon_name
    WeaponProfileCode profile_name
    # A nonzero representative slot may select every profile of that instance.
    Bool physical_scope

using CharacteristicModifiers = CheckedVector<CharacteristicModifier, 16>

# Construct model-scoped arithmetic without inventing a unit-wide grant (02.02.01).
fun characteristic_modifier(ModifiedCharacteristic characteristic, ModifierOperation operation, Int amount) -> CharacteristicModifier:
    let result : CharacteristicModifier
    result.characteristic = characteristic
    result.modifier = rule_modifier(operation, amount)
    return result

# Saved metadata must not introduce invalid enums, amounts or zero/negative
# divisors before effective queries execute (appendix02.02.01 infrastructure).
fun valid_characteristic_modifiers(CharacteristicModifiers modifiers) -> Bool:
    if MAX_WEAPON_SCOPES != MAX_WEAPONS + 1:
        return false
    for i in range(modifiers.size()):
        ref entry = modifiers[i]
        if entry.weapon_scope.value < 0 or entry.weapon_scope.value > MAX_WEAPONS or (entry.weapon_scope.value > 0 and !weapon_characteristic_kind(entry.characteristic)):
            return false
        if entry.weapon_name.value < 0 or entry.weapon_name.value >= MAX_WEAPONNAMECODE or entry.profile_name.value < 0 or entry.profile_name.value >= MAX_WEAPONPROFILECODE:
            return false
        if (entry.weapon_name.value > 0 or entry.profile_name.value > 0 or entry.physical_scope) and !weapon_characteristic_kind(entry.characteristic):
            return false
        if entry.physical_scope and entry.weapon_scope.value == 0:
            return false
        if entry.characteristic.value < 0 or entry.characteristic.value > ModifiedCharacteristic::detection_range.value:
            return false
        if entry.modifier.operation.value < 0 or entry.modifier.operation.value > ModifierOperation::subtract.value or entry.modifier.amount.value < 0 or entry.modifier.amount.value >= MAX_RULE_MODIFIER:
            return false
        if entry.modifier.operation.value == ModifierOperation::divide.value and (entry.modifier.amount.value == 0 or entry.modifier.negative):
            return false
    return true

# Filter before arithmetic; replacement/order/rounding/floors are shared with
# the supplied appendix. One exit lets generated cleanup release owning locals.
fun effective_characteristic_value(Int base, ModifiedCharacteristic characteristic, CharacteristicModifiers modifiers, Bool special) -> Int:
    assert(valid_characteristic_modifiers(modifiers), "invalid characteristic modifiers")
    let applicable : RuleModifiers
    for i in range(modifiers.size()):
        if modifiers[i].characteristic.value == characteristic.value:
            applicable.append(modifiers[i].modifier)
    return modified_characteristic(base, characteristic, applicable, special)

# Appendix02.02.01: these characteristics belong to equipped weapon profiles.
fun weapon_characteristic_kind(ModifiedCharacteristic kind) -> Bool:
    return kind.value >= ModifiedCharacteristic::range.value and kind.value <= ModifiedCharacteristic::damage.value

# Explicit physical-slot grants do not leak to other weapons (p.16/02.02.01).
# Random A/D consumers follow in17.C2b2; no faction grant is invented here.
fun weapon_characteristic_modifier(ModifiedCharacteristic kind, ModifierOperation operation, Int amount, Int slot) -> CharacteristicModifier:
    assert(weapon_characteristic_kind(kind) and slot >= 0 and slot < MAX_WEAPONS, "invalid weapon modifier scope")
    let result = characteristic_modifier(kind, operation, amount)
    result.weapon_scope = slot + 1
    return result

# Snapshotted raw operations cannot contain invalid enums/divisors on load
# (appendix02.02.01; saved-state infrastructure).
fun valid_rule_modifiers(RuleModifiers modifiers) -> Bool:
    for i in range(modifiers.size()):
        if modifiers[i].operation.value < 0 or modifiers[i].operation.value > ModifierOperation::subtract.value or modifiers[i].amount.value < 0 or modifiers[i].amount.value >= MAX_RULE_MODIFIER:
            return false
        if modifiers[i].operation.value == ModifierOperation::divide.value and (modifiers[i].amount.value == 0 or modifiers[i].negative):
            return false
    return true

# Named grants affect every equipped copy/profile of that physical family;
# e.g. Hunta Rig Fully Loaded Butchery names Butcha Boyz specifically:
# https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
fun named_weapon_modifier(ModifiedCharacteristic kind, ModifierOperation operation, Int amount, NamedWeapon name) -> CharacteristicModifier:
    assert(weapon_characteristic_kind(kind) and name.value > 0 and name.value < MAX_WEAPONNAMECODE, "invalid named weapon grant")
    let result = characteristic_modifier(kind, operation, amount)
    result.weapon_name = name.value
    return result

# Profile-only restrictions do not become family-wide grants (04.01.03).
fun named_profile_modifier(ModifiedCharacteristic kind, ModifierOperation operation, Int amount, NamedWeaponProfile profile) -> CharacteristicModifier:
    assert(weapon_characteristic_kind(kind) and profile.value > 0 and profile.value < MAX_WEAPONPROFILECODE, "invalid named profile grant")
    let result = characteristic_modifier(kind, operation, amount)
    result.profile_name = profile.value
    return result

# Select a physical instance through one of its owned slots, including every
# alternate profile in that nonzero group (appendix04.01.03); group0 is one slot.
fun physical_weapon_modifier(ModifiedCharacteristic kind, ModifierOperation operation, Int amount, Int slot) -> CharacteristicModifier:
    let result = weapon_characteristic_modifier(kind, operation, amount, slot)
    result.physical_scope = true
    return result
