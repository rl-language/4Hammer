import board

# Bearer/army properties and source-card permissions consumed through neutral
# faction contracts. Shared arithmetic and sequencing remain in core.

# Orks active keywords, Blastajet Smoke suppression and Painboss bearer-only Mounted (respective cards; core p67).
fun orks_keyword_override(Model model, Keyword keyword) -> Int:
    for effect in range(model.rule_effects.size()):
        if keyword == Keyword::fly and model.rule_effects[effect].kind.value == RuleEffectKind::lifted.value:
            return 1
    if model.blastajet_force_field and keyword == Keyword::smoke:
        return -1
    # Painboss Runnin' wiv da Herd: no keyword spread to other models.
    if model.painboss_mounted_attachment:
        if keyword == Keyword::infantry:
            return -1
        if keyword == Keyword::mobile or keyword == Keyword::mounted:
            return 1
    return 0

# Nazdreg Deep Strike and borrowed psychic abilities retain their actual source permissions (Orks cards/Da Jump).
fun orks_model_grants_intrinsic_ability(Model model, AbilityKind kind) -> Bool:
    if kind == AbilityKind::deep_strike:
        for intrinsic in range(model.abilities.size()):
            if model.abilities[intrinsic] == AbilityKind::nazdregs_know_wotz:
                return true
    for effect in range(model.rule_effects.size()):
        if kind == AbilityKind::keep_huntin and model.rule_effects[effect].kind.value == RuleEffectKind::borrowed_keep_huntin.value or kind == AbilityKind::intimidating_motivation and model.rule_effects[effect].kind.value == RuleEffectKind::borrowed_intimidation.value:
            return true
    return false

# Painboss Runnin wiv da Herd and Cybork Boosta improve only the eligible bearer (Orks cards).
fun orks_movement_bonus(Model model) -> Int:
    return 4 * int(model.painboss_mounted_attachment) + 2 * int(model.orks_enhancement.value == OrksEnhancement::cybork_boosta.value)

# It Came From Da Drops improves bearer Toughness (Orks enhancement).
fun orks_toughness_bonus(Model model) -> Int:
    return int(model.orks_enhancement.value == OrksEnhancement::it_came_from_da_drops.value)

# Riled-up, Blastajet Force Field and psychic invulnerable permissions improve the printed base (Orks army/cards).
fun orks_invulnerable_base(Model model) -> Int:
    let base = model.profile.invuln_save()
    if model.blastajet_force_field:
        base = min(base, 5)
    if is_riled_up(model):
        base = min(base, 5)
    return base

# Painboss Runnin wiv da Herd changes this attached bearer only (Orks/Painboss; core pp66-67).
fun orks_prepare_attached_model(Unit leader, Unit bodyguard, Model model):
    if leader.roster_datasheet.value == OrksDatasheet::painboss.value and bodyguard.has_keyword(Keyword::mounted):
        model.painboss_mounted_attachment = true

# Warp Visions grants Fights First; core still checks every participating model (Orks/Wurrband; core p40).
# Orks transport passenger faction/type and Ghazghkull restrictions (Orks transport cards; core p64).
# Burna Mark prevents Hidden (Orks/Burna-Bommer).
fun orks_hidden_allowed(Board board, Unit unit) -> Bool:
    return unit_rule_effect(board, unit, RuleEffectKind::burna_mark) == 0

# Found Em and Extra Sneaky change detection range; core applies its shared9-30in cap (Orks cards).
fun orks_detection_modifier(Board board, Unit target) -> Int:
    return 3 * unit_rule_effect(board, target, RuleEffectKind::found_detection) - 3 * int(unit_has_orks_enhancement(target, OrksEnhancement::extra_sneaky))

# Source-owned no_charge restriction; core retains ordinary eligibility and expiry (Orks Pulse Jet/psychic cards).
# Source-owned no_action restriction; core retains ordinary eligibility and expiry (Orks Pulse Jet/psychic cards).
# Source-owned grounded restriction; core retains ordinary eligibility and expiry (Orks Pulse Jet/psychic cards).
# Only selected Orks packages grant their support cards; unassociated core cards pass through (Orks detachment sections).
fun orks_stratagem_selected(Board board, Bool player, Stratagem strat) -> Bool:
    let package = strat.orks_detachment()
    return package == OrksDetachment::none or (board.armies[int(player)].faction == ArmyFaction::orks and board.armies[int(player)].has_detachment(package))

# Named Orks effects forbid Overwatch on their target; core retains payment/shock/phase gates (Orks cards).
fun orks_stratagem_target_allowed(Board board, Bool player, Stratagem strat, Unit target) -> Bool:
    return !(strat == Stratagem::overwatch and unit_rule_effect(board, target, RuleEffectKind::overwatch_blocked) > 0)

# Orks support cards select friendly targets; generic core cards retain their own owner policy (Orks cards).
fun orks_stratagem_owner_allowed(Stratagem strat, Unit target, Bool player) -> Bool:
    return strat.orks_detachment() == OrksDetachment::none or target.owned_by_player1 == player

# Orks army/detachment rule, formerly embedded in core (Waaagh!/Get Stuck In; core p78).
fun append_riled_assault_rules(Model model, Weapon weapon, WeaponAbilitySet rules):
    if weapon.range() == 0:
        return
    for riled_index in range(model.riled_source_effects.size()):
        let granted = weapon_rule(WeaponRuleKind::assault)
        granted.source_effect = model.riled_source_effects[riled_index]
        rules.append(granted)

# Orks army/detachment rule, formerly embedded in core (Waaagh!/Get Stuck In; core p78).
fun war_horde_melee_rule_applies(Board board, UnitID source, Weapon weapon) -> Bool:
    if source.get() < 0 or source.get() >= board.units.size() or weapon.range() != 0:
        return false
    ref unit = board[source]
    ref army = board.armies[int(unit.owned_by_player1)]
    return army.faction == ArmyFaction::orks and army.has_detachment(OrksDetachment::war_horde) and unit.has_keyword(Keyword::orks)

# Only an attached Painboss may retain its bearer-specific Mounted conversion (Orks/Painboss).
fun orks_attachment_origin_valid(Unit unit, Model model) -> Bool:
    let painboss = false
    for component in range(unit.attached_units.size()):
        painboss = painboss or (model.original_unit == unit.attached_units[component].identity and unit.attached_units[component].datasheet.value == OrksDatasheet::painboss.value)
    return !model.painboss_mounted_attachment or painboss

# Attachment snapshot preserves actual army-rule permission through component lifetime (Orks/Waaagh!; p67).
fun component_has_waaagh(Unit unit, EntityIdentity component) -> Bool:
    let available = false
    for model in range(unit.models.size()):
        available = available or (unit[model].original_unit == component and unit[model].has_waaagh)
    return available

# Waaagh! attachment metadata follows the actual original component lifetime (Orks army rules; core p67).
fun orks_component_has_army_rules(Unit unit, EntityIdentity component) -> Bool:
    if component == unit.identity:
        return unit.bodyguard_waaagh
    for record in range(unit.attached_units.size()):
        if unit.attached_units[record].identity == component:
            return unit.attached_units[record].waaagh
    return false

# Actual Orks army rules can retain a destroyed conferred source during the attack (core p67).
fun orks_model_confers_army_rules(Model model) -> Bool:
    return model.has_waaagh or model.grants_unit_riled_up

# Nazdreg Unit Composition explicitly permits the three simultaneous profiles.
# Orks KFF/Pulsa equipment grants abilities rather than attacks (their Wargear Options).
# Waaagh riled-up supplies ranged Assault; intrinsic rules remain core (Orks Army Rules).
fun orks_model_has_weapon_rule(Model model, Weapon profile, WeaponRuleKind kind) -> Bool:
    return kind == WeaponRuleKind::assault and profile.range() > 0 and is_riled_up(model)

# Orks mandatory/optional timing availability; core owns controller grouping (user Rules Sequencing).
fun orks_timing_options_remaining(Board board, TimingWindow window, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_rules_remaining(board, window, player, progress.orks_rules, mandatory_only) or orks_package_windows_remaining(board, player, window, mandatory_only) or (!mandatory_only and window == TimingWindow::fight_start and (orks_offboard_support_available(board, SourceBank::reserves, player, true) or orks_offboard_support_available(board, SourceBank::embarked, player, true)))

# Per-controller Orks timing flags reset without exposing their count to core.
fun orks_reset_timing_progress(FactionTimingProgress progress):
    progress.orks_rules[0] = false
    progress.orks_rules[1] = false

# Da Button adds one Hazardous use after ordinary selected physical weapons (Orks/Dread Mob).
fun orks_extra_attack_hazards(Board board, Unit unit) -> Int:
    return int(unit_rule_effect(board, unit, RuleEffectKind::button_hazard) > 0)

# Finish the Orks attack ledger only after attack-end source processing.
# Automatic shock success is a source-owned permission, not a change to the core test (Orks cards).
fun orks_automatic_shock_success(Board board, Unit unit) -> Bool:
    return unit_rule_effect(board, unit, RuleEffectKind::automatic_shock_success) > 0

# Snotling psychic penalty contributes before the common Leadership comparison (Orks psychic card).
fun orks_leadership_roll_penalty(Board board, Unit unit) -> Int:
    return unit_rule_effect(board, unit, RuleEffectKind::snotling_leadership_penalty)

# Fuel Mixa Grot and source-owned Advance+2 contribute without replacing the shared roll (Orks cards).
fun orks_advance_distance_bonus(Board board, Unit unit) -> Int:
    return int(unit.has_ability(AbilityKind::fuel_mixa_grot)) + 2 * unit_rule_effect(board, unit, RuleEffectKind::advance_plus_two)

# Selected Shokk-boosta permission ends at this move boundary (Orks/Big-Mek).
fun orks_finish_move_selection(Board board, UnitID id):
    board[id].shokk_boosta_move = false

# Snapshot actual charge-end triggers after the completed move (Orks Mobbed/Krushin Impetus).
fun orks_charge_progress(Board board, UnitID source) -> FactionChargeProgress:
    let progress : FactionChargeProgress
    progress.mobbed = board[source].has_ability(AbilityKind::mobbed)
    progress.impetus = board[source].has_ability(AbilityKind::krushin_impetus)
    return progress

# Only unresolved Orks charge triggers remain; no core movement/charge rule is synthesized.
fun orks_charge_effects_remaining(FactionChargeProgress progress) -> Bool:
    return progress.mobbed or progress.impetus

# Dodge Dis provides a separately selectable+1 hit contribution (Orks/Squighog-Boyz; core modifier rules).
fun orks_innate_hit_bonus(Unit unit) -> Bool:
    return unit.has_ability(AbilityKind::dodge_dis)

# Brutal Impact contributes damage before other faction modifiers, preserving operation order (Orks/Squighog-Boyz).
fun append_orks_intrinsic_modifiers(Board board, UnitID source, ModifiedCharacteristic kind, RuleModifiers result):
    if kind.value == ModifiedCharacteristic::damage.value and board[source].has_charged and board[source].has_ability(AbilityKind::brutal_impact):
        result.append(rule_modifier(ModifierOperation::add, 1))

# Banner/Trophy Hunters add their distinct unit-wide charge contributions (Orks/Bannernob/Breaka-Boyz).
fun orks_unit_charge_bonus(Unit unit) -> Int:
    return int(unit.has_ability(AbilityKind::waaagh_banner)) + int(unit.has_ability(AbilityKind::trophy_hunters))

# Get Out da Way permits charge traversal only; common final overlap/engagement checks remain mandatory (Orks/Nobz).
fun orks_charge_traversal(Unit original, MovementGeometryPolicy policy):
    if original.has_ability(AbilityKind::get_out_da_way) and !policy.traverse_enemies:
        policy.traverse_enemies = true
        policy.exclude_monster_vehicle = true

# Never Too Busy waives only the engagement action gate (Orks/Boyz; core p58).
fun orks_action_while_engaged(Unit unit) -> Bool:
    return unit.has_ability(AbilityKind::never_too_busy_to_fight)

# Only Orks select Orks detachments; finite catalog, duplicate and user maximum-three gates remain explicit (Orks index).
fun orks_detachment_selection_valid(ArmyConfiguration army, OrksDetachment detachment) -> Bool:
    return army.faction == ArmyFaction::orks and detachment.value > 0 and detachment.value <= OrksDetachment::taktikal_brigade.value and army.detachments.has_capacity() and !army.has_detachment(detachment)

# Saved Orks detachments require the actual Orks army faction (roster integrity; core p8).
fun orks_army_configuration_valid(ArmyConfiguration army) -> Bool:
    return army.faction == ArmyFaction::orks or army.detachments.empty()

# Orks riled status is source-owned; keep the existing public read query.
fun is_riled_up(Model model) -> Bool:
    return !model.riled_source_effects.empty()
