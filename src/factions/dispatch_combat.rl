import factions.orks.combat
import factions.orks.morale
import factions.orks.queries

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
fun faction_hit_interceptor(Board board, Unit unit) -> Int:
    return orks_grot_shield(board, unit)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun attack_with_faction_reactions(Board board, UnitID source, UnitID target, Bool melee, Bool overwatch) -> AttackWithOrksReactions:
    return attack_with_orks_reactions(board, source, target, melee, overwatch)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_pre_declaration_options(Board board, UnitID source) -> OrksShokkaSelection:
    return orks_shokka_selection(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_shooting_finished(Board board, UnitID source) -> OrksShootingOptionEnd:
    return orks_shooting_option_end(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_shooting_support(Board board, UnitID source) -> OrksDreadherderShooting:
    return orks_dreadherder_shooting(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_engagement_exception(Board board, Unit unit) -> Bool:
    return orks_engaged_only_fortifications(board, unit)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_intervening_cover(Board board, Model observer, Model target) -> Bool:
    return orks_ramshackle_obscures(board, observer, target)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_observer_grants_cover(Board board, Model observer) -> Bool:
    return orks_wobbled_observer(board, observer)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_hit_results(Board board, UnitID source) -> OrksHitEffects:
    return orks_resolve_hit_effects(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_datasheet_fight_selection(Board board, UnitID source) -> OrksDatasheetFightSelection:
    return orks_datasheet_fight_selection(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_melee_weapon_selection(Board board, UnitID source) -> OrksRokkitSelection:
    return orks_rokkit_selection(board, source)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun append_faction_datasheet_weapon_rules(Board board, UnitID source, Weapon selected, WeaponAbilitySet result):
    append_orks_datasheet_weapon_rules(board, source, selected, result)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun append_faction_datasheet_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    append_orks_datasheet_modifiers(board, source, declaration, kind, result)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_attack_targeted(Board board, UnitID source, UnitID target, Bool melee) -> OrksAttackTargeted:
    return orks_attack_targeted(board, source, target, melee)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun intercept_faction_hits(Board board, UnitID target, CombatCounter count) -> OrksHitInterception:
    return intercept_orks_hits(board, target, count)

# Composition hook: combat adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_allocation_invulnerable(Unit unit, Model model, AttackSequenceInfo info) -> Int:
    return orks_allocation_invulnerable(unit, model, info)

# Composition hook: morale adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_became_shocked(Board board, EntityIdentity subject) -> OrksBecameShocked:
    return orks_became_shocked(board, subject)

# Composition hook: morale adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_became_shocked(Board board, UnitID target) -> OrksBecameShocked:
    return orks_became_shocked(board, target)

# Composition hook: morale adapter owns eligibility and its cited rule; contexts and source identity are preserved.
fun faction_before_battle_shock(Board board) -> OrksMobMentalityStep:
    return orks_mob_mentality_step(board)

# Faction death choices return results; core owns casualty removal and mortal-job order.
fun faction_before_destruction(Board board, Model casualty, PendingDestruction event) -> OrksBeforeDestruction:
    return orks_before_destruction(board, casualty, event)

# Da Button adds one Hazardous use after ordinary selected physical weapons (Orks/Dread Mob).
fun faction_extra_attack_hazards(Board board, Unit unit) -> Int:
    return orks_extra_attack_hazards(board, unit)

# Core attack-end sequencing precedes faction ledger closure.
fun end_faction_attack(Board board):
    orks_end_attack(board)

# Automatic shock success is a source-owned permission, not a change to the core test (Orks cards).
fun faction_automatic_shock_success(Board board, Unit unit) -> Bool:
    return orks_automatic_shock_success(board, unit)

# Snotling psychic penalty contributes before the common Leadership comparison (Orks psychic card).
fun faction_leadership_roll_penalty(Board board, Unit unit) -> Int:
    return orks_leadership_roll_penalty(board, unit)

# Offer one faction Shooting-phase ability alongside ordinary shooting choices.
fun faction_shooting_phase_choice(Board board) -> OrksShootingPhaseChoice:
    return orks_shooting_phase_choice(board)

# Unpredictable Genius owns its single-target trigger and effect; common declarations/grouping remain core (Orks/Madcap Meks).
fun faction_declarations_complete(Board board, DeclaredWeapons declarations, UnitID source, Bool melee) -> OrksDeclarationsComplete:
    return orks_declarations_complete(board, declarations, source, melee)

# Mobbed/Impetus remain interleaved with common charge-end effects in the charger-chosen order (Orks cards; user Rules Sequencing).
# Preserve the common pending context while choosing one atomic faction effect.
fun faction_charge_choice(Board board, FactionChargeProgress progress, Bool crushing_pending, UnitID source) -> OrksChargeChoice:
    return orks_charge_choice(board, progress, crushing_pending, source)

# Snapshot actual charge-end triggers after the completed move (Orks Mobbed/Krushin Impetus).
fun faction_charge_progress(Board board, UnitID source) -> FactionChargeProgress:
    return orks_charge_progress(board, source)

# Only unresolved Orks charge triggers remain; no core movement/charge rule is synthesized.
fun faction_charge_effects_remaining(FactionChargeProgress progress) -> Bool:
    return orks_charge_effects_remaining(progress)

# Dodge Dis provides a separately selectable+1 hit contribution (Orks/Squighog-Boyz; core modifier rules).
fun faction_innate_hit_bonus(Unit unit) -> Bool:
    return orks_innate_hit_bonus(unit)

# Capture Wrecka objective selection, Ammo Runt and paid attack choices before declarations (Orks cards).
fun faction_attack_selection_options(Board board, UnitID source, Bool melee) -> OrksAttackSelectionOptions:
    return orks_attack_selection_options(board, source, melee)

# Brutal Impact contributes damage before other faction modifiers, preserving operation order (Orks/Squighog-Boyz).
fun append_faction_intrinsic_modifiers(Board board, UnitID source, ModifiedCharacteristic kind, RuleModifiers result):
    append_orks_intrinsic_modifiers(board, source, kind, result)
