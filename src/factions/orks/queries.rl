import board

# Source-owned policies extracted from shared mechanics. No core sequencing.

# Orks active keywords, Blastajet Smoke suppression and Painboss bearer-only Mounted (respective cards; core p67).
fun orks_keyword_override(Model model, Keyword keyword) -> Int:
    for effect in range(model.orks_effects.size()):
        if keyword == Keyword::mobile and model.orks_effects[effect].kind.value == OrksEffectKind::mobile.value:
            return 1
        if keyword == Keyword::fly and model.orks_effects[effect].kind.value == OrksEffectKind::lifted.value:
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
    if kind == AbilityKind::deep_strike:
        for jump_effect in range(model.orks_effects.size()):
            if model.orks_effects[jump_effect].kind.value == OrksEffectKind::jump_deep_strike.value:
                return true
    for effect in range(model.orks_effects.size()):
        if kind == AbilityKind::keep_huntin and model.orks_effects[effect].kind.value == OrksEffectKind::borrowed_keep_huntin.value or kind == AbilityKind::intimidating_motivation and model.orks_effects[effect].kind.value == OrksEffectKind::borrowed_intimidation.value:
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
    if model.is_riled_up():
        base = min(base, 5)
    for effect in range(model.orks_effects.size()):
        if model.orks_effects[effect].kind.value == OrksEffectKind::invulnerable_four.value:
            base = min(base, 4)
        if model.orks_effects[effect].kind.value == OrksEffectKind::invulnerable_five.value:
            base = min(base, 5)
    return base

# Painboss Runnin wiv da Herd changes this attached bearer only (Orks/Painboss; core pp66-67).
fun orks_prepare_attached_model(Unit leader, Unit bodyguard, Model model):
    if leader.roster_datasheet.value == OrksDatasheet::painboss.value and bodyguard.has_keyword(Keyword::mounted):
        model.painboss_mounted_attachment = true

# Warp Visions grants Fights First; core still checks every participating model (Orks/Wurrband; core p40).
fun orks_fights_first(Model model) -> Bool:
    for effect in range(model.orks_effects.size()):
        if model.orks_effects[effect].kind.value == OrksEffectKind::fights_first.value:
            return true
    return false

# Orks transport passenger faction/type and Ghazghkull restrictions (Orks transport cards; core p64).
fun orks_passenger_permitted(Model carrier, Model passenger) -> Bool:
    if carrier.orks_transport_permissions and (!passenger.has_keyword(Keyword::orks) or !passenger.has_keyword(Keyword::infantry)):
        return false
    if carrier.beast_snagga_passengers_only and !passenger.has_keyword(Keyword::beast_snagga):
        return false
    if carrier.forbid_ghaz_passenger and model_matches_datasheet(passenger, OrksDatasheet::ghazghkull_thraka):
        return false
    return true

# Assault Disembark and Gut Hatch grant specific post-move charge permission (Orks transport cards).
fun orks_assault_disembark(Board board, Unit carrier_unit) -> Bool:
    return unit_orks_effect(board, carrier_unit, OrksEffectKind::assault_disembark) > 0 or carrier_unit.has_ability(AbilityKind::gut_hatch) and carrier_unit.history.move_kind == MovementKind::normal

# Burna Mark prevents Hidden (Orks/Burna-Bommer).
fun orks_hidden_allowed(Board board, Unit unit) -> Bool:
    return unit_orks_effect(board, unit, OrksEffectKind::burna_mark) == 0

# Found Em and Extra Sneaky change detection range; core applies its shared9-30in cap (Orks cards).
fun orks_detection_modifier(Board board, Unit target) -> Int:
    return 3 * unit_orks_effect(board, target, OrksEffectKind::found_detection) - 3 * int(unit_has_orks_enhancement(target, OrksEnhancement::extra_sneaky))

# Source-owned no_charge restriction; core retains ordinary eligibility and expiry (Orks Pulse Jet/psychic cards).
fun orks_charge_allowed(Board board, Unit unit) -> Bool:
    return unit_orks_effect(board, unit, OrksEffectKind::no_charge) == 0

# Source-owned no_action restriction; core retains ordinary eligibility and expiry (Orks Pulse Jet/psychic cards).
fun orks_action_allowed(Board board, Unit unit) -> Bool:
    return unit_orks_effect(board, unit, OrksEffectKind::no_action) == 0

# Source-owned grounded restriction; core retains ordinary eligibility and expiry (Orks Pulse Jet/psychic cards).
fun orks_flight_allowed(Board board, Unit unit) -> Bool:
    return unit_orks_effect(board, unit, OrksEffectKind::grounded) == 0

# Minefield Detail supplies Scouts6; all combined printed Scouts values must match (Orks/Taktikal Brigade; user ruling).
fun orks_scouts_override(Unit unit) -> Int:
    if unit_has_orks_enhancement(unit, OrksEnhancement::minefield_detail) and unit.embarked_transport.value == 0:
        for member in range(unit.models.size()):
            for entry in range(unit[member].scout_distances.size()):
                assert(unit[member].scout_distances[entry].value == 6, "Scouts values must all be identical")
        return 6
    return -1

# Completed Pulse Jet installs its source-owned charge/action/defence effects (Orks Pulse Jet Move).
fun orks_record_move_effects(Board board, UnitID id, MovementKind kind):
    if kind == MovementKind::pulse_jet:
        board[id].can_charge = false
        grant_orks_effect(board, id, id, 173, OrksEffectKind::no_charge, 1, SourceDuration::turn, invalid_entity_identity())
        grant_orks_effect(board, id, id, 174, OrksEffectKind::no_action, 1, SourceDuration::turn, invalid_entity_identity())
        grant_orks_effect(board, id, id, 175, OrksEffectKind::pulse_defence, 1, SourceDuration::next_own_turn, invalid_entity_identity())

# Pulse Engine supplies Pulse Jet selection permission (Orks/Wazdakka).
fun orks_special_move_available(Board board, Unit unit, MovementKind kind) -> Bool:
    return kind == MovementKind::pulse_jet and unit_orks_effect(board, unit, OrksEffectKind::pulse_engine) > 0

# Only selected Orks packages grant their support cards; unassociated core cards pass through (Orks detachment sections).
fun orks_stratagem_selected(Board board, Bool player, Stratagem strat) -> Bool:
    let package = strat.orks_detachment()
    return package == OrksDetachment::none or (board.armies[int(player)].faction == ArmyFaction::orks and board.armies[int(player)].has_detachment(package))

# Named Orks effects forbid Overwatch on their target; core retains payment/shock/phase gates (Orks cards).
fun orks_stratagem_target_allowed(Board board, Bool player, Stratagem strat, Unit target) -> Bool:
    return !(strat == Stratagem::overwatch and unit_orks_effect(board, target, OrksEffectKind::overwatch_blocked) > 0)

# Orks support cards select friendly targets; generic core cards retain their own owner policy (Orks cards).
fun orks_stratagem_owner_allowed(Stratagem strat, Unit target, Bool player) -> Bool:
    return strat.orks_detachment() == OrksDetachment::none or target.owned_by_player1 == player

# Validate bounded Orks effects/enhancement handles on save load; infrastructure, not another tabletop restriction.
fun orks_model_state_valid(Model model) -> Bool:
    if model.orks_enhancement.value < 0 or model.orks_enhancement.value > OrksEnhancement::warphead.value or model.orks_upgrade_origin.value < 0 or model.orks_upgrade_origin.value >= MAX_IDENTITY_SEQUENCE:
        return false
    for ork_effect in range(model.orks_effects.size()):
        ref grant = model.orks_effects[ork_effect]
        if grant.kind.value <= 0 or grant.kind.value > max(grant.kind) or grant.source_effect.value < 0 or grant.source_effect.value >= MAX_SOURCE_EFFECT_KEY or grant.amount.value < 0 or grant.amount.value >= MAX_CHARACTERISTIC or grant.associated_unit.value < 0 or grant.associated_unit.value >= MAX_IDENTITY_SEQUENCE:
            return false
    for riled_index in range(model.riled_source_effects.size()):
        if model.riled_source_effects[riled_index].value < 0 or model.riled_source_effects[riled_index].value >= MAX_SOURCE_EFFECT_KEY:
            return false
    return true

# Validate bounded Orks psychic usage on save load; generic Psyker level validation remains core.
fun orks_unit_state_valid(Unit unit) -> Bool:
    return !(unit.orks_psychic_usage.budget.round_stamp.value < 0 or unit.orks_psychic_usage.budget.round_stamp.value >= MAX_ROUNDS or unit.orks_psychic_usage.budget.spent.value < 0 or unit.orks_psychic_usage.budget.spent.value >= MAX_CHARACTERISTIC or unit.orks_psychic_usage.roar_phase.value < 0 or unit.orks_psychic_usage.roar_phase.value >= MAX_PHASE_STAMP or unit.orks_psychic_usage.visions_phase.value < 0 or unit.orks_psychic_usage.visions_phase.value >= MAX_PHASE_STAMP)

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

# Orks typed/riled grants share generic source handles and expiry (Waaagh!/01.02.02).
fun orks_install_source_grant(Model model, SourceGrant installed, SourceEffectKey key):
    if installed is OrksEffectGrant:
        installed.source_effect = key
        model.orks_effects.append(installed)
    if installed is RiledUpGrant:
        model.riled_source_effects.append(key)

# Remove only the matching Orks effect/riled key, including archived models (01.02.02; core p88).
fun orks_remove_source_grant(Model model, SourceEffectKey key):
    let effect_index = model.orks_effects.size()
    while effect_index > 0:
        effect_index = effect_index - 1
        if model.orks_effects[effect_index].source_effect == key:
            model.orks_effects.erase(effect_index)
    let index = model.riled_source_effects.size()
    while index > 0:
        index = index - 1
        if model.riled_source_effects[index] == key:
            model.riled_source_effects.erase(index)

# Validate faction typed source payloads before loading/dispatch; generic arithmetic validation stays core.
fun orks_source_grant_valid(SourceGrant grant) -> Bool:
    if grant is OrksEffectGrant:
        return grant.kind.value > 0 and grant.kind.value <= max(grant.kind) and grant.amount.value >= 0 and grant.associated_unit.value >= 0
    if grant is RiledUpGrant:
        return grant.enabled
    return false

# Returned members inherit only missing faction-owned grant keys (core p88/01.02.02).
fun orks_model_has_source_grant(Model model, SourceEffectKey key) -> Bool:
    let present = false
    for orks_effect in range(model.orks_effects.size()):
        present = present or model.orks_effects[orks_effect].source_effect == key
    for riled_index in range(model.riled_source_effects.size()):
        present = present or model.riled_source_effects[riled_index] == key
    return present

# Restored faction grants must refer to their real source recipients; preserve existing handle validation.
fun orks_model_source_handles_valid(Board board, Model model) -> Bool:
    let valid = true
    for riled_index in range(model.riled_source_effects.size()):
        valid = valid and source_handle_matches_model(board, model.riled_source_effects[riled_index], model.identity)
    return valid

# Surly return and Flyboyz aircraft destruction retain their pending casualty (Orks cards; core p87).
fun orks_has_destruction_trigger(Board board, Model model) -> Bool:
    return model.orks_enhancement.value == OrksEnhancement::surly_as_a_squiggoth.value or orks_aircraft_death_source(board, model)

# Orks attack ledger records actual wounds lost before clamping, not rolled damage (Orks detachment triggers).
fun orks_record_wound_loss(Board board, Unit unit, ModelID model, Int lost, Bool from_attack):
    if lost > 0 and from_attack and board.orks_attack_active:
        ref record = orks_attack_record(board, unit.identity)
        add_attack_count(record.wounds_lost, min(lost, unit[model].wounds_left()))

# Track Orks attack/phase kill provenance only after actual last-model destruction (Orks combat triggers).
fun orks_record_unit_destruction(Board board, Unit unit):
    if board.orks_attack_active and live_attachment_strength(unit) == 0:
        ref destruction_record = orks_attack_record(board, unit.identity)
        destruction_record.destroyed = true
        unit.orks_destroyed_attack = board.orks_attack_serial
        unit.orks_destroyed_phase = board.phase_serial.value + 1

# Flyin Headbutt requires the Aircraft unit destruction event (Orks/Flyboyz).
fun orks_unit_destruction_trigger(Board board, Unit unit, Model model) -> Bool:
    return orks_package(board, unit, OrksDetachment::flyboyz) and model.has_keyword(Keyword::aircraft)

# Surly return retains its source even in reserves/passengers; no offboard distance permission is introduced (Orks/Surly).
fun orks_offboard_destruction_trigger(Model model) -> Bool:
    return model.orks_enhancement.value == OrksEnhancement::surly_as_a_squiggoth.value

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

# Shokk-boosta permits model traversal without granting FLY or terrain traversal (Orks/Big-Mek).
fun orks_prepare_movement_policy(Unit unit, MovementKind kind, MovementGeometryPolicy policy):
    if kind == MovementKind::advance and unit.shokk_boosta_move:
        policy.traverse_enemies = true
        policy.exclude_titanic = false
        policy.exclude_monster_vehicle = false

# Pulse Jet traversal overrides remain separate from ordinary FLY/Walker costs (Orks Special Move Types).
fun orks_finish_movement_policy(MovementKind kind, MovementGeometryPolicy policy):
    if kind == MovementKind::pulse_jet:
        policy.traverse_enemies = true
        policy.traverse_terrain = true
        policy.free_vertical_movement = true
        policy.exclude_titanic = false
        policy.exclude_monster_vehicle = false

# Nazdreg Unit Composition explicitly permits the three simultaneous profiles.
fun orks_simultaneous_weapon_profile(Weapon profile) -> Bool:
    return profile.value == Weapon::orks_nazdreg_kustom_blasta_x_gatler.value or profile.value == Weapon::orks_nazdreg_kustom_blasta_x_shoota.value or profile.value == Weapon::orks_nazdreg_kustom_blasta_x_skorcha.value

# Orks KFF/Pulsa equipment grants abilities rather than attacks (their Wargear Options).
fun orks_nonattacking_equipment(Weapon profile) -> Bool:
    return profile.value == Weapon::orks_kustom_force_field.value or profile.value == Weapon::orks_pulsa_rokkit.value

# Waaagh riled-up supplies ranged Assault; intrinsic rules remain core (Orks Army Rules).
fun orks_model_has_weapon_rule(Model model, Weapon profile, WeaponRuleKind kind) -> Bool:
    return kind == WeaponRuleKind::assault and profile.range() > 0 and model.is_riled_up()
