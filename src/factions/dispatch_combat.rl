import factions.orks.combat
import factions.orks.morale
import factions.orks.queries

# Neutral combat entrypoints. This composition module is the only layer
# that selects concrete faction behavior; core algorithms do not inspect it.

# Surly return and Flyboyz aircraft destruction retain their pending casualty (Orks cards; core p87).
fun faction_has_destruction_trigger(Board board, Model model) -> Bool:
    return orks_has_destruction_trigger(board, model)

# Orks attack ledger records actual wounds lost before clamping, not rolled damage (Orks detachment triggers).
fun faction_record_wound_loss(Board board, Unit unit, ModelID model, Int lost, Bool from_attack):
    orks_record_wound_loss(board, unit, model, lost, from_attack)

# Track Orks attack/phase kill provenance only after actual last-model destruction (Orks combat triggers).
fun faction_record_unit_destruction(Board board, Unit unit):
    orks_record_unit_destruction(board, unit)

# Flyin Headbutt requires the Aircraft unit destruction event (Orks/Flyboyz).
fun faction_unit_destruction_trigger(Board board, Unit unit, Model model) -> Bool:
    return orks_unit_destruction_trigger(board, unit, model)

# Surly return retains its source even in reserves/passengers; no offboard distance permission is introduced (Orks/Surly).
fun faction_offboard_destruction_trigger(Model model) -> Bool:
    return orks_offboard_destruction_trigger(model)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun append_faction_package_weapon_rules(Board board, UnitID source, Int bearer, Int slot, WeaponAbilitySet result):
    append_orks_package_weapon_rules(board, source, bearer, slot, result)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun append_faction_package_weapon_rules(Board board, UnitID source, Int bearer, Weapon selected, WeaponCode name, WeaponAbilitySet result):
    append_orks_package_weapon_rules(board, source, bearer, selected, name, result)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun append_faction_declaration_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    append_orks_declaration_modifiers(board, source, declaration, kind, result)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun append_faction_attack_effects(Board board, UnitID source, UnitID target, DeclaredWeapon weapon, AttackSequenceInfo info):
    append_orks_attack_effects(board, source, target, weapon, info)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_model_grants_ability(Unit unit, Model model, AbilityKind kind) -> Bool:
    return orks_model_grants_ability(unit, model, kind)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_lone_operative(Board board, Unit unit) -> Bool:
    return orks_lone_operative(board, unit)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun begin_faction_attack(Board board):
    begin_orks_attack(board)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun record_faction_hits(Board board, UnitID target, Int count):
    record_orks_hits(board, target, count)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_fight_death_threshold(Board board, Unit unit, Model model) -> Int:
    return orks_fight_death_threshold(board, unit, model)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_grot_shield(Board board, Unit unit) -> Int:
    return orks_grot_shield(board, unit)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun attack_with_faction_reactions(Board board, UnitID source, UnitID target, Bool melee, Bool overwatch) -> AttackWithOrksReactions:
    return attack_with_orks_reactions(board, source, target, melee, overwatch)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_single_declared_target(DeclaredWeapons declarations) -> Int:
    return orks_single_declared_target(declarations)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_unpredictable_genius(Board board, UnitID source, UnitID target) -> OrksUnpredictableGenius:
    return orks_unpredictable_genius(board, source, target)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_shokka_selection(Board board, UnitID source) -> OrksShokkaSelection:
    return orks_shokka_selection(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_shooting_option_end(Board board, UnitID source) -> OrksShootingOptionEnd:
    return orks_shooting_option_end(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_dreadherder_shooting(Board board, UnitID source) -> OrksDreadherderShooting:
    return orks_dreadherder_shooting(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_dreadherder_available(Board board, UnitID source) -> Bool:
    return orks_dreadherder_available(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_engaged_only_fortifications(Board board, Unit unit) -> Bool:
    return orks_engaged_only_fortifications(board, unit)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_ramshackle_obscures(Board board, Model observer, Model target) -> Bool:
    return orks_ramshackle_obscures(board, observer, target)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_wobbled_observer(Board board, Model observer) -> Bool:
    return orks_wobbled_observer(board, observer)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_resolve_hit_effects(Board board, UnitID source) -> OrksHitEffects:
    return orks_resolve_hit_effects(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_datasheet_fight_selection(Board board, UnitID source) -> OrksDatasheetFightSelection:
    return orks_datasheet_fight_selection(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_datasheet_selection(Board board, UnitID source) -> OrksDatasheetSelection:
    return orks_datasheet_selection(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_rokkit_selection(Board board, UnitID source) -> OrksRokkitSelection:
    return orks_rokkit_selection(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun append_faction_datasheet_weapon_rules(Board board, UnitID source, Weapon selected, WeaponAbilitySet result):
    append_orks_datasheet_weapon_rules(board, source, selected, result)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun append_faction_datasheet_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    append_orks_datasheet_modifiers(board, source, declaration, kind, result)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_attack_selection(Board board, UnitID actor, Bool melee) -> OrksAttackSelection:
    return orks_attack_selection(board, actor, melee)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_attack_targeted(Board board, UnitID source, UnitID target, Bool melee) -> OrksAttackTargeted:
    return orks_attack_targeted(board, source, target, melee)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun intercept_faction_hits(Board board, UnitID target, CombatCounter count) -> OrksHitInterception:
    return intercept_orks_hits(board, target, count)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_allocation_invulnerable(Unit unit, Model model, AttackSequenceInfo info) -> Int:
    return orks_allocation_invulnerable(unit, model, info)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun secure_faction_gretchin_objectives(Board board, SourceInstance instance):
    secure_orks_gretchin_objectives(board, instance)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_krushin_impetus(Board board, UnitID source) -> OrksKrushinImpetus:
    return orks_krushin_impetus(board, source)

# Composition hook: morale adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_became_shocked(Board board, EntityIdentity subject) -> OrksBecameShocked:
    return orks_became_shocked(board, subject)

# Composition hook: morale adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_became_shocked(Board board, UnitID target) -> OrksBecameShocked:
    return orks_became_shocked(board, target)

# Composition hook: morale adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_mob_mentality_step(Board board) -> OrksMobMentalityStep:
    return orks_mob_mentality_step(board)

# Composition hook: morale adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun resolve_faction_mobbed(Board board, UnitID source) -> OrksMobbed:
    return resolve_orks_mobbed(board, source)
