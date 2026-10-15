import board

# Shared selectors for the literal ordinary package rules; never identify a
# faction by the historical roster name. Source: Orks Detachments at
# https://wahapedia.ru/wh40k11ed/factions/orks/
fun orks_package(Board board, Unit unit, OrksDetachment package) -> Bool:
    ref army = board.armies[int(unit.owned_by_player1)]
    return army.faction == ArmyFaction::orks and army.has_detachment(package)

# Named datasheets and explicit keywords describe the same source unit type;
# attached units retain their actual constituent datasheet membership (01.02.07).
fun orks_type(Unit unit, OrksDatasheet tag) -> Bool:
    return unit_matches_datasheet(unit, tag)

# BIG MEK covers its printed variants; this is source metadata, not a profile
# approximation (Orks enhancement eligibility and Big Mek keyword lists).
fun orks_big_mek(Model model) -> Bool:
    return model.has_keyword(Keyword::big_mek) or model_matches_datasheet(model, OrksDatasheet::big_mek) or model_matches_datasheet(model, OrksDatasheet::big_mek_dakkarig) or model_matches_datasheet(model, OrksDatasheet::big_mek_in_mega_armour) or model_matches_datasheet(model, OrksDatasheet::big_mek_with_shokk_attack_gun)

# Every living/retained original upgrade component must still confer its rule
# after bodyguard death; enhancements on a specific bearer follow that model (p67).
fun model_has_orks_enhancement(Unit unit, Model model, OrksEnhancement enhancement) -> Bool:
    return model.orks_enhancement.value == enhancement.value and (model_confers_attached_abilities(model) or model.state == ModelState::fight_on_death) and (model.orks_upgrade_origin.value == 0 or orks_upgrade_component_present(unit, model.orks_upgrade_origin))

# Unit-granting options are not spread to other units, and do not survive the
# loss of their original component except through p67's retained attack window.
fun unit_has_orks_enhancement(Unit unit, OrksEnhancement enhancement) -> Bool:
    let present = false
    for model_index in range(unit.models.size()):
        present = present or model_has_orks_enhancement(unit, unit[model_index], enhancement)
    return present

# Non-characteristic grants are keyed to the same expiry machinery as ordinary
# modifiers (01.02.02); no stale declaration can resurrect an expired grant.
fun model_orks_effect(Board board, Model model, OrksEffectKind kind) -> Int:
    let amount = 0
    for effect_index in range(model.orks_effects.size()):
        ref effect = model.orks_effects[effect_index]
        if effect.kind.value == kind.value and source_grant_active(board, effect.source_effect):
            amount = amount + max(1, effect.amount.value)
    return amount

# Effects installed on an entire unit count one source once, rather than
# adding the same grant for each recipient (e.g. Advance+2 and Leadership-1).
fun unit_orks_effect(Board board, Unit unit, OrksEffectKind kind) -> Int:
    for model_index in range(unit.models.size()):
        if model_confers_attached_abilities(unit[model_index]) or unit[model_index].state == ModelState::fight_on_death:
            return model_orks_effect(board, unit[model_index], kind)
    return 0

# Upgrade versus ordinary enhancement is literal source tagging; second/third
# Upgrade copies do not consume the user's four counted enhancement slots.
fun orks_is_upgrade(OrksEnhancement option) -> Bool:
    return option.value == OrksEnhancement::ardboyz.value or option.value == OrksEnhancement::wimp_kickaz.value or option.value == OrksEnhancement::extra_sneaky.value or option.value == OrksEnhancement::minefield_detail.value or option.value == OrksEnhancement::throat_slittas.value or option.value == OrksEnhancement::supa_snazz_dakka.value or option.value == OrksEnhancement::temperamental_shokka.value or option.value == OrksEnhancement::enhanced_runt_maw.value or option.value == OrksEnhancement::targetin_gizmos.value or option.value == OrksEnhancement::boss_boomer.value or option.value == OrksEnhancement::smoky_gubbinz.value or option.value == OrksEnhancement::flyboss.value or option.value == OrksEnhancement::impulsive_recon.value

# Sources are partitioned by the selected ordinary detachment, never merely
# by army faction. Boarding Actions and prices remain outside the user scope.
fun orks_enhancement_package(OrksEnhancement option) -> OrksDetachment:
    let value = option.value
    if value >= 1 and value <= 4:
        return OrksDetachment::war_horde
    if value <= 6 and value >= 5:
        return OrksDetachment::green_tide
    if value <= 8 and value >= 7:
        return OrksDetachment::bully_boyz
    if value <= 10 and value >= 9:
        return OrksDetachment::runt_swarm
    if value <= 12 and value >= 11:
        return OrksDetachment::shoota_boyz
    if value <= 14 and value >= 13:
        return OrksDetachment::taktikal_brigade
    if value <= 16 and value >= 15:
        return OrksDetachment::wreckas
    if value <= 18 and value >= 17:
        return OrksDetachment::da_big_hunt
    if value <= 21 and value >= 19:
        return OrksDetachment::madcap_meks
    if value <= 23 and value >= 22:
        return OrksDetachment::dread_mob
    if value <= 25 and value >= 24:
        return OrksDetachment::blitz_brigade
    if value <= 27 and value >= 26:
        return OrksDetachment::kult_of_speed
    if value <= 29 and value >= 28:
        return OrksDetachment::flyboyz
    if value <= 35 and value >= 30:
        return OrksDetachment::brute_bosses
    if value <= 38 and value >= 36:
        return OrksDetachment::wurrband
    return OrksDetachment::none

# Literal unit groups shared by source clauses; ALL infantry restrictions are
# checked separately from these ANY named alternatives (appendix02.05.01).
fun orks_taktikal_unit(Unit unit) -> Bool:
    return orks_type(unit, OrksDatasheet::boyz) or orks_type(unit, OrksDatasheet::kommandos) or orks_type(unit, OrksDatasheet::stormboyz)

# Wreckas' loot-hunter group excludes unrelated infantry despite army identity.
fun orks_wrecka_unit(Unit unit) -> Bool:
    return orks_type(unit, OrksDatasheet::breaka_boyz) or orks_type(unit, OrksDatasheet::flash_gitz) or orks_type(unit, OrksDatasheet::tankbustas)

# Green Tide, Bully Boyz and Throat-slittas add separate ability instances;
# p78's duplicate chooser still decides between sources without summing them.
fun append_orks_package_weapon_rules(Board board, UnitID source, Int bearer, Int slot, WeaponAbilitySet result):
    let name : WeaponNameCode
    name = equipped_named_weapon(board[source][bearer], slot).value
    append_orks_package_weapon_rules(board, source, bearer, board[source][bearer].weapons[slot], name, result)

# Borrowed Firing Deck weapons receive carrier-model/unit package rules using
# their own named profile, never the carrier's coincidentally matching slot.
# Orks detachment cards and core Firing Deck p81.
fun append_orks_package_weapon_rules(Board board, UnitID source, Int bearer, Weapon selected, WeaponNameCode name, WeaponAbilitySet result):
    ref unit = board[source]
    ref model = unit[bearer]
    let melee = selected.range() == 0
    if melee and orks_package(board, unit, OrksDetachment::green_tide):
        if orks_type(unit, OrksDatasheet::boyz):
            result.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
        if unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::infantry) and unit.has_charged:
            result.append(conditional_weapon_rule(WeaponRuleKind::letal_hits, 0, orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0).target_condition))
    if melee and orks_package(board, unit, OrksDetachment::bully_boyz) and (orks_type(unit, OrksDatasheet::nobz) or orks_type(unit, OrksDatasheet::meganobz)):
        result.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    if !melee and orks_package(board, unit, OrksDetachment::shoota_boyz) and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::infantry):
        result.append(weapon_rule(WeaponRuleKind::assault))
    if !melee:
        append_orks_effect_ability(board, model, OrksEffectKind::ranged_assault, WeaponRuleKind::assault, 0, result)
        append_orks_effect_ability(board, model, OrksEffectKind::ranged_lethal, WeaponRuleKind::letal_hits, 0, result)
        append_orks_effect_ability(board, model, OrksEffectKind::ranged_sustained, WeaponRuleKind::sustained_hit, 1, result)
        append_orks_effect_ability(board, model, OrksEffectKind::ranged_hazardous, WeaponRuleKind::hazardous, 0, result)
        append_orks_effect_ability(board, model, OrksEffectKind::vindictive_all, WeaponRuleKind::letal_hits, 0, result)
        append_orks_effect_ability(board, model, OrksEffectKind::vindictive_all, WeaponRuleKind::sustained_hit, 1, result)
        append_orks_effect_ability(board, model, OrksEffectKind::vindictive_all, WeaponRuleKind::hazardous, 0, result)
    else:
        append_orks_effect_ability(board, model, OrksEffectKind::melee_lethal, WeaponRuleKind::letal_hits, 0, result)
    if melee and unit_has_orks_enhancement(unit, OrksEnhancement::throat_slittas):
        result.append(orks_non_monster_vehicle_rule(WeaponRuleKind::letal_hits, 0))
    if !melee and model_has_orks_enhancement(unit, model, OrksEnhancement::supa_glowy_fing):
        result.append(conditional_weapon_rule(WeaponRuleKind::anti, 4, Keyword::infantry))
        result.append(weapon_rule(WeaponRuleKind::devastating_wounds))
        result.append(weapon_rule(WeaponRuleKind::supa_hazardous))
    if !melee and unit_has_orks_enhancement(unit, OrksEnhancement::targetin_gizmos) and orks_carrier_has_passenger(board, model, true):
        result.append(weapon_rule(WeaponRuleKind::ignore_cover))
        if unit_is_riled_up(unit):
            result.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
    if !melee and name.value == NamedWeapon::shokk_attack_gun.value:
        append_orks_effect_ability(board, model, OrksEffectKind::shokka_torrent, WeaponRuleKind::torrent, 0, result)
        append_orks_effect_ability(board, model, OrksEffectKind::shokka_sustained, WeaponRuleKind::sustained_hit, 2, result)
    # Source wording increases existing numeric instances instead of creating
    # a competing instance; apply increments to each before duplicate selection.
    if !melee and unit_has_orks_enhancement(unit, OrksEnhancement::supa_snazz_dakka) and name.value == NamedWeapon::snazzgun.value:
        result.append(weapon_rule(WeaponRuleKind::rapid_fire, 1))
    for effect_index in range(model.orks_effects.size()):
        ref effect = model.orks_effects[effect_index]
        if !source_grant_active(board, effect.source_effect):
            continue
        if !melee and effect.kind.value == OrksEffectKind::rapid_fire_increment.value:
            increment_orks_weapon_ability(result, WeaponRuleKind::rapid_fire, effect.amount.value, effect.source_effect)
        if melee and effect.kind.value == OrksEffectKind::cleave_increment.value:
            increment_orks_weapon_ability(result, WeaponRuleKind::cleave, effect.amount.value, effect.source_effect)

# Close-range Dakka/Mow 'Em Down explicitly improve a printed numeric rule;
# the resulting instance keeps its condition and expiry key (Orks cards; p78).
fun increment_orks_weapon_ability(WeaponAbilitySet rules, WeaponRuleKind kind, Int increment, SourceEffectKey key):
    if increment == 0:
        return
    let found = false
    for rule_index in range(rules.size()):
        if rules[rule_index].kind == kind:
            assert(rules[rule_index].parameter_increment_source.value == 0, "only one friendly stratagem can improve this ability per phase")
            rules[rule_index].parameter_increment_source = key
            rules[rule_index].parameter_increment_amount = increment
            rules[rule_index].parameter = rules[rule_index].parameter.value + increment
            found = true
    if !found:
        let granted = weapon_rule(kind, increment)
        granted.source_effect = key
        rules.append(granted)

# Model/weapon arithmetic is inserted before core rounding/caps. Da Hunt is
# target-dependent and handled at gathered attack time, not as an aura.
fun append_orks_declaration_modifiers(Board board, UnitID source, DeclaredWeapon declaration, ModifiedCharacteristic kind, RuleModifiers result):
    let bearer = declared_model_index(board, source, declaration)
    if bearer < 0:
        return
    ref unit = board[source]
    ref model = unit[bearer]
    let melee = declaration.weapon.range() == 0
    let addition = 0
    if melee and kind.value == ModifiedCharacteristic::armour_penetration.value and unit.has_charged and model_has_orks_enhancement(unit, model, OrksEnhancement::headwoppas_killchoppa):
        addition = addition - 1
    if melee and kind.value == ModifiedCharacteristic::attacks.value and model_has_orks_enhancement(unit, model, OrksEnhancement::ferocious_show_off):
        addition = addition + 1 + int(live_attachment_strength(unit) >= 11)
    if melee and kind.value == ModifiedCharacteristic::damage.value and model_has_orks_enhancement(unit, model, OrksEnhancement::brutal_but_kunnin):
        addition = addition + 1
    if !melee and kind.value == ModifiedCharacteristic::range.value:
        if orks_package(board, unit, OrksDetachment::shoota_boyz) and unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::infantry) and unit_is_riled_up(unit):
            addition = addition + 3
        if unit_has_orks_enhancement(unit, OrksEnhancement::targetin_squigs) and !declared_weapon_has_kind(declaration, WeaponRuleKind::torrent):
            addition = addition + 3
    if kind.value == ModifiedCharacteristic::attacks.value:
        if melee:
            addition = addition + unit_orks_effect(board, unit, OrksEffectKind::unbridled_attacks)
        addition = addition + unit_orks_effect(board, unit, OrksEffectKind::button_attacks)
        if !melee and declaration.weapon_name.value == NamedWeapon::shokk_attack_gun.value:
            addition = addition + model_orks_effect(board, model, OrksEffectKind::shokka_attacks)
    if kind.value == ModifiedCharacteristic::strength.value:
        addition = addition + 2 * unit_orks_effect(board, unit, OrksEffectKind::button_strength)
        if orks_package(board, unit, OrksDetachment::wurrband) and model.has_keyword(Keyword::orks) and model.has_keyword(Keyword::psyker) and declared_weapon_has_kind(declaration, WeaponRuleKind::psychic):
            addition = addition + 1 + orks_psychic_contributors(board, unit, model) / 5
    if kind.value == ModifiedCharacteristic::armour_penetration.value:
        addition = addition - unit_orks_effect(board, unit, OrksEffectKind::button_ap)
    if addition != 0:
        result.append(rule_modifier(ModifierOperation::add, addition))

# Wurrband counts actual passenger models, not occupied seats, and combines
# models in the psyker's unit OR embarked in that psyker model as printed.
fun embarked_models_for_psyker(Board board, EntityIdentity psyker) -> Int:
    let count = 0
    for passenger in range(board.embarked_units.size()):
        if board.embarked_units[passenger].embarked_transport == psyker:
            count = count + live_attachment_strength(board.embarked_units[passenger])
    return count

# Selected movement grants are captured at selection, so later status changes
# do not retroactively waive a previously selected Advance/Fall Back (Waaagh!).
fun orks_move_charge_permission(Board board, Unit unit, MovementKind kind) -> Bool:
    let fallback = kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape
    if !fallback and !(kind == MovementKind::advance):
        return false
    if unit_orks_effect(board, unit, OrksEffectKind::turbo_engine) > 0:
        return true
    if orks_package(board, unit, OrksDetachment::kult_of_speed) and unit.has_keyword(Keyword::speed_freeks):
        return true
    if !fallback:
        return false
    return (orks_package(board, unit, OrksDetachment::taktikal_brigade) and orks_taktikal_unit(unit)) or unit_has_orks_enhancement(unit, OrksEnhancement::glory_hog) or unit_has_orks_enhancement(unit, OrksEnhancement::kunnin_but_brutal)

# Runt Swarm's Advance/Fall Back permission waives only that action gate;
# shock, OC, engagement, shooting and once-per-turn restrictions still apply.
fun orks_move_action_permission(Board board, Unit unit, MovementKind kind) -> Bool:
    return (kind == MovementKind::advance or kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape) and ((orks_package(board, unit, OrksDetachment::runt_swarm) and orks_type(unit, OrksDatasheet::gretchin)) or unit_orks_effect(board, unit, OrksEffectKind::action_move_permission) > 0)

# Blitz Brigade excludes points only for Flyboyz Aircraft; public point-free
# mode already omits all price caps. It grants no substitute reserve quota.
fun orks_charge_reroll(Board board, Unit unit) -> Bool:
    return (orks_package(board, unit, OrksDetachment::blitz_brigade) and unit.has_keyword(Keyword::wagon)) or unit_has_orks_enhancement(unit, OrksEnhancement::competitive_streak)


# Carrier psykers count their actual embarked models instead of their own
# unit; ordinary psykers count their unit (Wurrband Powers of da Waaagh!).
fun orks_psychic_contributors(Board board, Unit unit, Model model) -> Int:
    if model.has_keyword(Keyword::transport):
        return embarked_models_for_psyker(board, model.identity)
    return live_attachment_strength(unit)

# Every sourced grant uses a stable rule/unit handle, reused on later phases;
# effect identity, not a mutable source payload, owns each installed copy.
# Orks cards and appendix01.02.02; no additional rule-use limit is invented.
fun grant_orks_effect(Board board, UnitID source, UnitID target, Int rule, OrksEffectKind kind, Int amount, SourceDuration duration, EntityIdentity associated):
    let grant : OrksEffectGrant
    grant.kind = kind
    grant.amount = amount
    grant.associated_unit = associated
    let payload : SourceGrant
    payload = grant
    grant_orks_typed_payload(board, board[source].identity, board[source].owned_by_player1, board[target].identity, rule, payload, duration)

# Duplicate upgrades count by original unit/component, not per equipped model;
# configuration precedes interactive attachment so options may add permissions.
# Attachment validation preserves original roster choices and the Epic Hero policy.
fun orks_unit_has_any_option(Unit unit) -> Bool:
    let found = false
    for model_index in range(unit.models.size()):
        found = found or unit[model_index].orks_enhancement.value != 0
    return found

# Literal source option requirements; global Character/Epic/duplicates/count
# checks are applied separately, so Upgrade tags do not erase card restrictions.
fun orks_option_source_eligible(Unit unit, Model model, OrksEnhancement option) -> Bool:
    let infantry = model.has_keyword(Keyword::infantry)
    let warboss = model.has_keyword(Keyword::warboss)
    let big_mek = orks_big_mek(model)
    let kind = option.value
    if kind >= 1 and kind <= 4:
        return model.has_keyword(Keyword::orks)
    if kind == OrksEnhancement::ferocious_show_off.value:
        return model.has_keyword(Keyword::orks) and infantry
    if kind == OrksEnhancement::ardboyz.value:
        return orks_type(unit, OrksDatasheet::boyz)
    if kind == OrksEnhancement::wimp_kickaz.value:
        return orks_type(unit, OrksDatasheet::nobz)
    if kind == OrksEnhancement::tellyporta_boss.value:
        return model.has_keyword(Keyword::mega_armour)
    if kind == OrksEnhancement::extra_sneaky.value or kind == OrksEnhancement::minefield_detail.value:
        return orks_type(unit, OrksDatasheet::gretchin)
    if kind == OrksEnhancement::supa_glowy_fing.value:
        return model.has_keyword(Keyword::orks) and infantry and !model_matches_datasheet(model, OrksDatasheet::weirdboy)
    if kind == OrksEnhancement::targetin_squigs.value:
        return big_mek or warboss or model.has_keyword(Keyword::bigboss) or model_matches_datasheet(model, OrksDatasheet::bigboss)
    if kind == OrksEnhancement::kill_kommanda.value or kind == OrksEnhancement::kaptins_hat.value:
        return infantry and (big_mek or warboss)
    if kind == OrksEnhancement::throat_slittas.value:
        return orks_type(unit, OrksDatasheet::kommandos) or orks_type(unit, OrksDatasheet::stormboyz)
    if kind == OrksEnhancement::supa_snazz_dakka.value:
        return orks_type(unit, OrksDatasheet::flash_gitz)
    if kind == OrksEnhancement::glory_hog.value:
        return model.has_keyword(Keyword::beast_snagga)
    if kind == OrksEnhancement::it_came_from_da_drops.value:
        return model_matches_datasheet(model, OrksDatasheet::beastboss_on_squigosaur)
    if kind == OrksEnhancement::mekwaaagh_mastermind.value or kind == OrksEnhancement::dreadherder.value:
        return big_mek
    if kind == OrksEnhancement::temperamental_shokka.value or kind == OrksEnhancement::enhanced_runt_maw.value:
        return model_matches_datasheet(model, OrksDatasheet::big_mek_with_shokk_attack_gun)
    if kind == OrksEnhancement::cybork_boosta.value:
        return big_mek or model.has_keyword(Keyword::mek) or model_matches_datasheet(model, OrksDatasheet::mek)
    if kind == OrksEnhancement::targetin_gizmos.value or kind == OrksEnhancement::boss_boomer.value:
        return unit.has_keyword(Keyword::wagon)
    if kind == OrksEnhancement::smoky_gubbinz.value:
        return unit.has_keyword(Keyword::speed_freeks) and !unit.has_keyword(Keyword::aircraft)
    if kind == OrksEnhancement::competitive_streak.value:
        return model_matches_datasheet(model, OrksDatasheet::deffkilla_wartrike)
    if kind == OrksEnhancement::flyboss.value or kind == OrksEnhancement::impulsive_recon.value:
        return unit.has_keyword(Keyword::orks) and unit.has_keyword(Keyword::aircraft)
    if kind == OrksEnhancement::surly_as_a_squiggoth.value:
        return infantry and warboss
    if kind >= OrksEnhancement::brutal_but_kunnin.value and kind <= OrksEnhancement::da_gobshot_thunderbuss.value:
        return warboss
    if kind >= OrksEnhancement::da_krunch.value and kind <= OrksEnhancement::warphead.value:
        return model.has_keyword(Keyword::orks) and model.has_keyword(Keyword::psyker)
    return false

# One enhancement per distinct unit, unique ordinary enhancements, up to3
# instances per Upgrade, and at most4 counted choices (user authority + core
# Muster Armies/Select Enhancements). An attached Epic Hero rejects the unit.
fun orks_option_selection_valid(Board board, UnitID unit_id, ModelID bearer, OrksEnhancement option, Bool owner) -> Bool:
    if unit_id.get() >= board.reserve_units.size() or option.value <= 0 or option.value > OrksEnhancement::warphead.value:
        return false
    ref unit = board.reserve_units[unit_id.get()]
    if unit.owned_by_player1 != owner or bearer.get() >= unit.models.size() or unit.has_keyword(Keyword::epic_hero) or orks_unit_has_any_option(unit) or !orks_package(board, unit, orks_enhancement_package(option)):
        return false
    ref model = unit[bearer.get()]
    if !model.is_alive() or (!orks_is_upgrade(option) and !model.has_keyword(Keyword::character)) or !orks_option_source_eligible(unit, model, option):
        return false
    let counted : Bool[39]
    let copies = 0
    let total = 0
    for roster_unit in range(board.reserve_units.size()):
        ref existing = board.reserve_units[roster_unit]
        if existing.owned_by_player1 != owner:
            continue
        for model_index in range(existing.models.size()):
            let existing_option = existing[model_index].orks_enhancement.value
            if existing_option == 0:
                continue
            if !counted[existing_option]:
                counted[existing_option] = true
                total = total + 1
        if unit_has_orks_enhancement(existing, option):
            copies = copies + 1
    return (counted[option.value] or total < 4) and copies < (1 + 2 * int(orks_is_upgrade(option)))

# Unit-only upgrades mark the original qualifying component, so a separated
# leader does not retain an extinct bodyguard's upgrade (pp66–67).
fun apply_orks_option(Board board, UnitID selected, ModelID bearer, OrksEnhancement option, Bool owner):
    assert(orks_option_selection_valid(board, selected, bearer, option, owner), "illegal Orks enhancement")
    ref unit = board.reserve_units[selected.get()]
    if orks_is_upgrade(option) and option.value != OrksEnhancement::temperamental_shokka.value and option.value != OrksEnhancement::enhanced_runt_maw.value:
        for member in range(unit.models.size()):
            unit[member].orks_enhancement = option
            unit[member].orks_upgrade_origin = unit.identity
    else:
        unit[bearer.get()].orks_enhancement = option
    if option.value == OrksEnhancement::kill_kommanda.value:
        orks_extra_bodyguard_permission(unit, OrksDatasheet::kommandos)
    if option.value == OrksEnhancement::kaptins_hat.value:
        orks_extra_bodyguard_permission(unit, OrksDatasheet::flash_gitz)
    if option.value == OrksEnhancement::flyboss.value:
        for member in range(unit.models.size()):
            if !unit[member].has_keyword(Keyword::character):
                unit[member].keywords.append(Keyword::character)
    if option.value == OrksEnhancement::warphead.value:
        unit[bearer.get()].has_deadly_demise = true
        unit[bearer.get()].deadly_demise = dice_stat(6)
    if option.value == OrksEnhancement::da_gobshot_thunderbuss.value:
        equip_orks_profile(unit[bearer.get()], Weapon::orks_da_gobshot_thunderbuss, NamedWeaponProfile::da_gobshot_thunderbuss, 0)
    if option.value == OrksEnhancement::da_krunch.value:
        equip_orks_profile(unit[bearer.get()], Weapon::orks_da_krunch, NamedWeaponProfile::da_krunch, 0)
    if option.value == OrksEnhancement::eadbanger.value:
        equip_orks_profile(unit[bearer.get()], Weapon::orks_eadbanger, NamedWeaponProfile::eadbanger, 0)

# Core Select Enhancements gives options to different roster units BEFORE
# forming attachments. Joining those original units does not select another
# option; the user's Epic Hero exclusion still applies to the attached unit.
fun orks_enhancement_attachment_valid(Unit leader, Unit bodyguard) -> Bool:
    let leader_option = orks_unit_has_any_option(leader)
    let bodyguard_option = orks_unit_has_any_option(bodyguard)
    return !(leader_option or bodyguard_option) or (!leader.has_keyword(Keyword::epic_hero) and !bodyguard.has_keyword(Keyword::epic_hero))

# Nazdreg/Nazdreg's Know-wotz gives the whole attached unit Deep Strike.
# Tellyporta Boss is a unit grant excluding Vehicle units, whereas Kill
# Kommanda grants only its attached bearer Infiltrators/Stealth (source cards).
fun orks_unit_grants_ability(Unit unit, AbilityKind kind) -> Bool:
    if kind == AbilityKind::deep_strike:
        for member_index in range(unit.models.size()):
            if model_confers_attached_abilities(unit[member_index]) and unit[member_index].has_ability(AbilityKind::nazdregs_know_wotz):
                return true
        return !unit.has_keyword(Keyword::vehicle) and unit_has_orks_enhancement(unit, OrksEnhancement::tellyporta_boss)
    return false

# Options use one enum, reserve-unit and model decisions independently. This
# prevents huge action products and keeps offboard Godot selectors explicit.
act select_orks_options(ctx Board board, frm Bool owner) -> SelectOrksOptions:
    if board.armies[int(owner)].faction != ArmyFaction::orks:
        return
    board.current_decision_maker = owner
    if !orks_any_option_available(board, owner):
        return
    frm finished = false
    while !finished:
        actions:
            act finish_orks_options()
                finished = true
            act choose_orks_option(frm OrksEnhancement option) {orks_option_available(board, option, owner)}
                actions:
                    act cancel_orks_option()
                    act choose_orks_option_unit(frm UnitID option_unit) {orks_option_unit_available(board, option_unit, option, owner)}
                        board.orks_selected_unit = option_unit
                        actions:
                            act cancel_orks_option_bearer()
                            act choose_orks_option_bearer(ModelID option_bearer) {orks_option_selection_valid(board, option_unit, option_bearer, option, owner)}
                                apply_orks_option(board, option_unit, option_bearer, option, owner)

# Availability scans actual roster data before exposing a source option; an
# unsupported future datasheet is never fabricated just to enable a choice.
fun orks_option_unit_available(Board board, UnitID unit, OrksEnhancement option, Bool owner) -> Bool:
    if unit.get() >= board.reserve_units.size():
        return false
    let bearer : ModelID
    for model in range(board.reserve_units[unit.get()].models.size()):
        bearer = model
        if orks_option_selection_valid(board, unit, bearer, option, owner):
            return true
    return false

# Package selection, quotas and literal bearer eligibility determine which
# enhancement buttons exist (core Muster Armies + user four-count policy).
fun orks_option_available(Board board, OrksEnhancement option, Bool owner) -> Bool:
    let unit : UnitID
    for roster_unit in range(board.reserve_units.size()):
        unit = roster_unit
        if orks_option_unit_available(board, unit, option, owner):
            return true
    return false

# Range to an objective is a base-range test regardless of current control/OC;
# Wreckas does not require the marker to be owned (Wreckin' and Lootin').
fun orks_near_any_objective(Board board, Unit unit) -> Bool:
    for objective in range(4):
        let definition = board.objective_range_definition(objective)
        for member in range(unit.models.size()):
            if unit[member].is_alive() and board.model_in_objective_range(unit[member], definition):
                return true
    return false

# Gather all source-dependent effects before modifier caps and hit/wound
# classification; each hit contribution remains individually ignorable.
# Sources: Da Hunt is On, Skyborne Loons and the40 Orks source cards.
fun append_orks_attack_effects(Board board, UnitID source, UnitID target, DeclaredWeapon weapon, AttackSequenceInfo info):
    ref unit = board[source]
    ref victim = board[target]
    let bearer = declared_model_index(board, source, weapon)
    ref model = unit[bearer]
    let ranged = weapon.weapon.range() > 0
    append_orks_datasheet_attack_effects(board, source, target, weapon, info)
    if orks_package(board, unit, OrksDetachment::da_big_hunt) and unit.has_keyword(Keyword::beast_snagga) and (victim.has_keyword(Keyword::monster) or victim.has_keyword(Keyword::vehicle)):
        info.ap_modifiers.append(rule_modifier(ModifierOperation::add, -1))
    if ranged and orks_package(board, unit, OrksDetachment::flyboyz) and unit_is_riled_up(unit) and unit.has_keyword(Keyword::orks) and (unit.has_keyword(Keyword::aircraft) or orks_type(unit, OrksDatasheet::deffkoptas)):
        info.orks_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
    if model_has_orks_enhancement(unit, model, OrksEnhancement::proper_killy) or unit_orks_effect(board, unit, OrksEffectKind::reroll_hits_ones) > 0:
        info.reroll1_hits = true
    if unit_orks_effect(board, unit, OrksEffectKind::reroll_hits_all) > 0:
        info.reroll_hits = true
    if unit_orks_effect(board, unit, OrksEffectKind::armed_to_da_teef) > 0:
        info.reroll1_hits = true
        info.reroll_hits = info.reroll_hits or unit_is_riled_up(unit)
    if ranged and orks_package(board, unit, OrksDetachment::wreckas) and orks_wrecka_unit(unit) and board.timing.phase == BattlePhase::shooting and unit.owned_by_player1 == board.current_player and (unit.history.wrecka_objective_selection or orks_near_any_objective(board, victim)):
        info.reroll1_hits = true
    if ranged:
        if unit_orks_effect(board, unit, OrksEffectKind::reroll_hits_fly) > 0 and victim.has_keyword(Keyword::fly):
            info.reroll_hits = true
        if unit_orks_effect(board, unit, OrksEffectKind::wound_bonus_non_monster_vehicle) > 0 and !victim.has_keyword(Keyword::monster) and !victim.has_keyword(Keyword::vehicle):
            info.orks_wound_modifiers.append(rule_modifier(ModifierOperation::add, 1))
        if unit_orks_effect(board, unit, OrksEffectKind::close_range_ap) > 0 and live_unit_distance(unit, victim) <= 9.0:
            info.ap_modifiers.append(rule_modifier(ModifierOperation::add, -1))
        if weapon.borrowed_weapon and unit_orks_effect(board, unit, OrksEffectKind::deck_hit_bonus) > 0:
            info.orks_hit_modifiers.append(rule_modifier(ModifierOperation::add, 1))
        if unit_orks_effect(board, unit, OrksEffectKind::hit_plus_one) > 0:
            info.orks_hit_modifiers.append(rule_modifier(ModifierOperation::add, unit_orks_effect(board, unit, OrksEffectKind::hit_plus_one)))
        if unit_orks_effect(board, victim, OrksEffectKind::all_wound_protection) > 0 or (unit_orks_effect(board, victim, OrksEffectKind::strong_wound_protection) > 0 and info.attack_strength() > info.target_toughness.value):
            info.orks_wound_modifiers.append(rule_modifier(ModifierOperation::add, -1))
        if victim.all_have_ability(AbilityKind::stealth):
            info.orks_hit_modifiers.append(rule_modifier(ModifierOperation::add, -1))
        info.orks_fail_hits_three = unit_orks_effect(board, victim, OrksEffectKind::fail_hits_one_to_three) > 0
        if unit_orks_effect(board, victim, OrksEffectKind::lifted) > 0:
            info.target_has_cover = false
        else:
            info.target_has_cover = info.target_has_cover or orks_smoky_cover(board, model, victim)

# Intentional user-approved approximation: every noncircular footprint is a
# circle, and intervening circular bases stand in for model-body obscuration.
# Smoky Gubbinz uses partial cover only; this never blocks physical visibility.
fun orks_smoky_cover(Board board, Model observer, Unit target) -> Bool:
    if target.empty():
        return false
    for target_model in range(target.models.size()):
        let obscured = false
        for blocker_unit in range(board.units.size()):
            ref blockers = board.units[blocker_unit]
            if blockers.off_battlefield or !unit_has_orks_enhancement(blockers, OrksEnhancement::smoky_gubbinz):
                continue
            for blocker_model in range(blockers.models.size()):
                ref blocker = blockers[blocker_model]
                if !blocker.is_alive() or blocker.identity == observer.identity or blocker.identity == target[target_model].identity:
                    continue
                let distance = point_segment_distance_squared(float(blocker.position.x.value * MICROMETRES_PER_INCH), float(blocker.position.y.value * MICROMETRES_PER_INCH), float(observer.position.x.value * MICROMETRES_PER_INCH), float(observer.position.y.value * MICROMETRES_PER_INCH), float(target[target_model].position.x.value * MICROMETRES_PER_INCH), float(target[target_model].position.y.value * MICROMETRES_PER_INCH))
                obscured = obscured or distance <= blocker.base_radius_micrometres() * blocker.base_radius_micrometres()
        if !obscured:
            return false
    return true

# Permanent Follow Me Ladz/Ardboyz/Mekwaaagh! grants reuse the established
# live-source machinery; bodyguard upgrades use their original component.
fun register_orks_option_passives(Board board):
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            for bearer in range(unit.models.size()):
                ref model = unit[bearer]
                let option = model.orks_enhancement
                if !model.is_alive() or (option.value != OrksEnhancement::follow_me_ladz.value and option.value != OrksEnhancement::ardboyz.value and option.value != OrksEnhancement::mekwaaagh_mastermind.value):
                    continue
                let instance : SourceInstance
                instance.rule = 200 + option.value
                instance.name.value = "Permanent Orks option"s
                instance.owner = unit.owned_by_player1
                instance.source_unit = model.original_unit
                instance.source_model = model.identity
                if option.value == OrksEnhancement::ardboyz.value:
                    instance.source_unit = model.orks_upgrade_origin
                    instance.source_model = 0
                instance.own_unit_passive = true
                instance.offboard_allowed = true
                instance.requires_live_source = true
                instance.duration = SourceDuration::battle
                instance.grant = riled_up_grant()
                if option.value == OrksEnhancement::follow_me_ladz.value:
                    instance.grant = characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 2)
                if option.value == OrksEnhancement::ardboyz.value:
                    instance.grant = characteristic_modifier(ModifiedCharacteristic::save, ModifierOperation::replace, 4)
                if !orks_unit_source_registered(board, instance):
                    let handle = register_source_instance(board, instance)

# Force dispositions change Battleline membership at muster without changing
# unit prices or adding new datasheets (Sneaky Little Gitz/Adrenaline Junkies/
# Suspiciously Well Organised). Replacement units retain the original trait.
fun register_orks_force_dispositions(Board board):
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            let battleline = orks_package(board, unit, OrksDetachment::runt_swarm) and orks_type(unit, OrksDatasheet::gretchin)
            battleline = battleline or (orks_package(board, unit, OrksDetachment::kult_of_speed) and orks_type(unit, OrksDatasheet::warbikers))
            battleline = battleline or (orks_package(board, unit, OrksDetachment::taktikal_brigade) and orks_type(unit, OrksDatasheet::stormboyz))
            if battleline:
                for bearer in range(unit.models.size()):
                    if !unit[bearer].has_keyword(Keyword::battleline):
                        unit[bearer].keywords.append(Keyword::battleline)

# Advance/Fall Back waivers are retained at selection; later riled/option loss
# cannot retroactively change that selected move's restrictions (source wording).
fun capture_orks_selected_move(Board board, UnitID source, MovementKind kind):
    ref unit = board[source]
    if kind == MovementKind::ordered_retreat or kind == MovementKind::desperate_escape:
        unit.history.fallback_allows_charge = orks_move_charge_permission(board, unit, kind)
        unit.history.fallback_allows_shooting = unit_has_orks_enhancement(unit, OrksEnhancement::kunnin_but_brutal)
    unit.history.selected_move_allows_action = orks_move_action_permission(board, unit, kind)
    if orks_package(board, unit, OrksDetachment::kult_of_speed) and unit.has_keyword(Keyword::speed_freeks):
        grant_orks_effect(board, source, source, 430, OrksEffectKind::ranged_assault, 1, SourceDuration::turn, invalid_entity_identity())

# Cargo-derived rules cease when the specified passenger leaves/dies, even
# though the carrier still lives (Blitzboss/Boss Boomer). No offboard distance.
fun orks_source_transport_dependency(Board board, SourceInstance instance) -> Bool:
    if instance.required_embarked_model.value == 0:
        return true
    let location = locate_source(board, invalid_entity_identity(), instance.required_embarked_model)
    if !location.found or location.bank.value != SourceBank::embarked.value:
        return false
    ref passenger = board.embarked_units[location.unit.value]
    let model = passenger.find_model(instance.required_embarked_model)
    return model >= 0 and passenger[model].is_alive() and passenger.embarked_transport == instance.required_carrier_model

# Dynamic replacement units may outlive old source slots. Reuse only a dead
# source with no active effect; generation snapshots reject every stale pending
# reference. This preserves finite source/action domains without artificial CP
# or unit-creation limits (Infested War Zone; implementation infrastructure).
fun reusable_orks_source_slot(Board board) -> Int:
    if board.source_instances.has_capacity():
        return -1
    for source_index in range(board.source_instances.size()):
        ref instance = board.source_instances[source_index]
        if source_confers_rules(board, instance):
            continue
        let referenced = false
        for effect in range(board.source_effects.size()):
            referenced = referenced or board.source_effects[effect].source.value == source_index
        if !referenced:
            return source_index
    return -1


# Fight on Death explicitly keeps models on the battlefield for their unit's
# attack, including targeting by stratagems (user-supplied appendix). This
# permission never makes an ordinary corpse a live source or attack target.
fun orks_retained_source_present(Board board, SourceInstance instance) -> Bool:
    let location = locate_source(board, instance.source_unit, instance.source_model)
    if !location.found:
        return false
    ref unit = source_bank_unit(board, location.bank, location.unit.value)
    for member in range(unit.models.size()):
        if unit[member].state == ModelState::fight_on_death:
            return true
    return false

# Characteristic grants use the same keyed lifecycle as flag grants. Multiple
# typed payloads remain separate sources, not flattened final values (02.02.01).
fun grant_orks_typed_payload(Board board, EntityIdentity source, Bool owner, EntityIdentity target, Int rule, SourceGrant payload, SourceDuration duration):
    let instance : SourceInstance
    instance.rule = rule
    instance.name.value = "Orks detachment modifier"s
    instance.source_unit = source
    instance.owner = owner
    instance.recipient = SourceTarget::target_unit
    instance.duration = duration
    instance.offboard_allowed = true
    instance.allow_retained_source = true
    instance.grant = payload
    let found = -1
    for source_index in range(board.source_instances.size()):
        if board.source_instances[source_index].rule.value == rule and board.source_instances[source_index].source_unit == instance.source_unit and board.source_instances[source_index].owner == instance.owner:
            found = source_index
    if found < 0:
        let handle = register_source_instance(board, instance)
        found = handle.value
    else:
        board.source_instances[found].grant = payload
        board.source_instances[found].duration = duration
    commit_source_effect_to_unit(board, board.source_instances[found], found, target)

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
fun grant_orks_own_payload(Board board, Unit unit, Int rule, OrksEffectGrant payload, SourceDuration duration):
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

# Wimp-kickaz and the accepted Hunt card force a Desperate Escape; their unit
# source must still be engaged at this actual selection (ordinary source text).
fun orks_forces_escape(Board board, Unit unit) -> Bool:
    for enemy in range(board.units.size()):
        ref opponent = board.units[enemy]
        if opponent.owned_by_player1 != unit.owned_by_player1 and opponent.is_engaged_with(unit) and (unit_has_orks_enhancement(opponent, OrksEnhancement::wimp_kickaz) or unit_orks_effect(board, opponent, OrksEffectKind::hunt_escape_hazards) > 0):
            return true
    return false

# Each riled Wimp-kickaz instance supplies its printed cumulative-1; Hunt's
# shocked penalty applies only to its extra rolls, not the base hazard batch.
fun orks_escape_penalty(Board board, Unit unit) -> Int:
    let penalty = 0
    for enemy in range(board.units.size()):
        ref opponent = board.units[enemy]
        if opponent.owned_by_player1 != unit.owned_by_player1 and opponent.is_engaged_with(unit) and unit_has_orks_enhancement(opponent, OrksEnhancement::wimp_kickaz) and unit_is_riled_up(opponent):
            penalty = penalty + 1
    return penalty

# Once a Hunt-granted unit forces this escape, all engaged Beast Snagga units
# contribute3 extra rolls against Monster/Vehicle, as the card explicitly says.
fun orks_extra_escape_hazards(Board board, Unit unit) -> Int:
    if !unit.has_keyword(Keyword::monster) and !unit.has_keyword(Keyword::vehicle):
        return 0
    let active = false
    let count = 0
    for enemy in range(board.units.size()):
        ref opponent = board.units[enemy]
        if opponent.owned_by_player1 != unit.owned_by_player1 and opponent.is_engaged_with(unit):
            active = active or unit_orks_effect(board, opponent, OrksEffectKind::hunt_escape_hazards) > 0
            count = count + int(opponent.has_keyword(Keyword::beast_snagga))
    return 3 * count * int(active)

# A retained Fight on Death member is still part of its original upgrade unit
# while its own attacks resolve (supplied Fight on Death; p67 component scope).
fun orks_upgrade_component_present(Unit unit, EntityIdentity component) -> Bool:
    if component_source_active(unit, component):
        return true
    for model in range(unit.models.size()):
        if unit[model].original_unit == component and unit[model].state == ModelState::fight_on_death:
            return true
    return false

# Empty package choices finish automatically; a valid option never disappears
# merely because the public starter has fewer than the planned54 datasheets.
fun orks_any_option_available(Board board, Bool owner) -> Bool:
    let option : OrksEnhancement
    for kind in range(38):
        option.value = kind + 1
        if orks_option_available(board, option, owner):
            return true
    return false


# Derived weapon rules retain the actual source expiry key in their immutable
# declaration; a later phase cannot revive a stale grant (01.02.02/p78).
fun append_orks_effect_ability(Board board, Model model, OrksEffectKind effect_kind, WeaponRuleKind weapon_kind, Int amount, WeaponAbilitySet rules):
    for effect in range(model.orks_effects.size()):
        if model.orks_effects[effect].kind.value == effect_kind.value and source_grant_active(board, model.orks_effects[effect].source_effect):
            let rule = weapon_rule(weapon_kind, amount)
            rule.source_effect = model.orks_effects[effect].source_effect
            rules.append(rule)

# Only completely empty retired slots may be assigned to a NEW replacement
# unit. Ordinary returns retain their own reserved slot. Check all bank returns
# and pending destruction references before recycling; preserve the old unit in
# the identity archive (Infested War Zone; allocation infrastructure, not a rule).
fun orks_replacement_slot(Board board) -> Int:
    if board.units.has_capacity():
        return board.units.size()
    for slot in range(board.units.size()):
        if !board[slot].models.empty() or !board[slot].retired:
            continue
        let reserved = false
        for reserve in range(board.reserve_units.size()):
            reserved = reserved or (board.reserve_units[reserve].has_return_slot and board.reserve_units[reserve].return_slot.get() == slot)
        for passenger in range(board.embarked_units.size()):
            reserved = reserved or (board.embarked_units[passenger].has_return_slot and board.embarked_units[passenger].return_slot.get() == slot)
        for unit in range(board.units.size()):
            for model in range(board[unit].models.size()):
                reserved = reserved or (board[unit][model].destruction_pending and board[unit][model].destroying_unit_known and board[unit][model].destroying_unit.get() == slot)
        let archive : ModelID
        for casualty in range(board[slot].destroyed_models.value.size()):
            archive = casualty
            reserved = reserved or orks_surly_archive_valid(board, unit_id_for_orks_slot(slot), archive, board[slot].owned_by_player1)
        if !reserved:
            return slot
    return -1

# New units allocate new unit/component/model identities. A revived model uses
# its old identity instead; conflating these violates Infested War Zone/01.02.10.
fun allocate_orks_identity(Board board) -> EntityIdentity:
    assert(board.next_identity.value < MAX_ENTITY_IDENTITIES, "entity identity capacity exceeded")
    board.next_identity = board.next_identity + 1
    return board.next_identity

# Literal identical battle-start equipment/strength, fresh histories/wounds and
# identities, with original component membership mapped into the new unit.
# Adding during battle is not another mustering choice or a price calculation.
fun create_orks_replacement(Board board, UnitID destroyed):
    ref original = board[destroyed]
    assert(board.reserve_units.has_capacity() and !original.battle_start_models.value.empty(), "replacement needs its original roster and a reserve slot")
    let replacement = original
    replacement.identity = allocate_orks_identity(board)
    replacement.models = original.battle_start_models.value
    replacement.destroyed_models.value.clear()
    replacement.movement_distance_limit = 0
    replacement.has_moved = false
    replacement.has_run = false
    replacement.has_charged = false
    replacement.has_shoot = false
    replacement.has_fought = false
    replacement.can_shoot = true
    replacement.can_charge = true
    replacement.battle_socked = false
    replacement.retired = false
    replacement.is_generated_replacement = true
    replacement.has_return_slot = false
    replacement.off_battlefield = true
    replacement.embarked_transport = 0
    replacement.unit_destruction_event_issued = false
    replacement.orks_destroyed_attack = 0
    replacement.orks_destroyed_phase = 0
    let history : UnitHistory
    replacement.history = history
    replacement.history.strategic_reserve = true
    let phase : PhaseModifiers
    replacement.phase_modifiers = phase
    let psychic : OrksPsychicUsage
    replacement.orks_psychic_usage = psychic
    let old_components : CheckedVector<EntityIdentity, 2>
    for component in range(replacement.attached_units.size()):
        old_components.append(replacement.attached_units[component].identity)
        replacement.attached_units[component].identity = allocate_orks_identity(board)
    for member in range(replacement.models.size()):
        ref model = replacement[member]
        model.identity = allocate_orks_identity(board)
        let origin = replacement.identity
        for component in range(old_components.size()):
            if model.original_unit == old_components[component]:
                origin = replacement.attached_units[component].identity
        model.original_unit = origin
        if model.orks_upgrade_origin.value > 0:
            model.orks_upgrade_origin = replacement.identity
        model.suffered_wounds = 0
        model.state = ModelState::normal
        model.off_battlefield = true
        model.destruction_pending = false
        model.destroyed_whole_unit = false
        model.destroyed_by_attack = false
        model.destruction_released = false
        model.destruction_attack_suppressed = false
        model.attachment_abilities_retained = false
        model.destroying_unit_known = false
        model.destroying_unit_identity = 0
        model.orks_effects.clear()
        model.riled_source_effects.clear()
        let keyword = model.keywords.size()
        while keyword > 0:
            keyword = keyword - 1
            if model.keywords[keyword] == Keyword::warlord:
                model.keywords.erase(keyword)
        strip_orks_temporary_model_grants(model)
    replacement.battle_start_models.value = replacement.models
    board.reserve_units.append(replacement)
    register_orks_option_passives(board)
    register_orks_force_dispositions(board)
    register_orks_unit_rules(board)

# Starting equipment includes intrinsic data, not a copy of old timed buffs.
# New physical weapon use starts from the battle-start template (01.02.10).
fun strip_orks_temporary_model_grants(Model model):
    let index = model.characteristic_modifiers.size()
    while index > 0:
        index = index - 1
        if model.characteristic_modifiers[index].source_effect.value > 0:
            model.characteristic_modifiers.erase(index)
    index = model.incoming_attack_modifiers.size()
    while index > 0:
        index = index - 1
        if model.incoming_attack_modifiers[index].source_effect.value > 0:
            model.incoming_attack_modifiers.erase(index)
    index = model.attack_modifier_permissions.size()
    while index > 0:
        index = index - 1
        if model.attack_modifier_permissions[index].source_effect.value > 0:
            model.attack_modifier_permissions.erase(index)
    for weapon in range(model.weapons.size()):
        index = model.additional_weapon_rules[weapon].size()
        while index > 0:
            index = index - 1
            if model.additional_weapon_rules[weapon][index].source_effect.value > 0:
                model.additional_weapon_rules[weapon].erase(index)

# Kill Kommanda affects only its bearer while attached, not its bodyguards;
# Tellyporta's unit grant is separate. Orks Taktikal Brigade enhancement card.
fun orks_model_grants_ability(Unit unit, Model model, AbilityKind kind) -> Bool:
    return model.original_unit != unit.identity and component_source_active(unit, unit.identity) and model_has_orks_enhancement(unit, model, OrksEnhancement::kill_kommanda) and (kind == AbilityKind::infiltrators or kind == AbilityKind::stealth)

# Dreadherder grants the unit Lone Operative while within3in of a friendly
# non-Big-Mek ORKS Walker; offboard units cannot measure this distance.
fun orks_lone_operative(Board board, Unit unit) -> Bool:
    if orks_remaining_lone_operative(board, unit) or unit.is_lone_operative() or orks_snagga_following(board, unit) or orks_shokka_supported(board, unit):
        return true
    if unit.off_battlefield or !unit.attached_units.empty() or !unit_has_orks_enhancement(unit, OrksEnhancement::dreadherder):
        return false
    for nearby in range(board.units.size()):
        ref walker = board.units[nearby]
        if !walker.off_battlefield and has_live_model(walker) and walker.owned_by_player1 == unit.owned_by_player1 and walker.has_keyword(Keyword::orks) and walker.has_keyword(Keyword::walker) and !walker.has_keyword(Keyword::big_mek) and orks_dreadherder_bearer_near(unit, walker):
            return true
    return false

# Attack bookkeeping follows actual hits and prevented wound loss; declaration
# alone cannot trigger Gun-crazy Show-offs/Goaded Into Action (Orks cards).
fun orks_attack_record(Board board, EntityIdentity target) -> ref OrksAttackRecord:
    let found = -1
    for record in range(board.orks_attack_records.size()):
        if board.orks_attack_records[record].target == target:
            found = record
    if found < 0:
        let entry : OrksAttackRecord
        entry.target = target
        board.orks_attack_records.append(entry)
        found = board.orks_attack_records.size() - 1
    return board.orks_attack_records[found]

# A bounded activation serial distinguishes a unit destroyed by this attacking
# unit from an earlier casualty. This is identity infrastructure for Infested.
fun begin_orks_attack(Board board):
    assert(board.orks_attack_serial.value + 1 < 1025, "attack serial capacity exceeded")
    board.orks_attack_serial = board.orks_attack_serial + 1
    board.orks_attack_records.clear()
    board.orks_attack_active = true

# A successful original roll is distinct from generated Sustained Hits. Grot
# Shields cancels only rolled hits, leaving the separately generated hits.
fun record_orks_hits(Board board, UnitID target, Int count):
    if board.orks_attack_active and count > 0:
        ref record = orks_attack_record(board, board[target].identity)
        add_attack_count(record.successful_hits, count)
        if board.attack_info.squig_launcha_weapon:
            add_attack_count(record.squig_launcha_hits, count)

# Brute Force Warbosses roll3+, riled+1; paid Fight-on-Death cards roll4+,
# with riled+1 or Crazed Rampage's Deff Dread+3. Selection of their own unit
# to fight closes eligibility, even if individual models did not attack.
fun orks_fight_death_threshold(Board board, Unit unit, Model model) -> Int:
    if unit.has_fought or model.state == ModelState::fight_on_death:
        return 0
    let threshold = 0
    # Mozrog/One Last Kill: destroy-time2+ only in Fight before selection.
    # https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad
    if board.timing.phase == BattlePhase::fight and model.has_ability(AbilityKind::one_last_kill):
        threshold = 2
    if orks_package(board, unit, OrksDetachment::brute_bosses) and model.has_keyword(Keyword::warboss):
        threshold = 3 - int(unit_is_riled_up(unit))
    if board.timing.phase == BattlePhase::fight:
        if unit_orks_effect(board, unit, OrksEffectKind::fight_on_death_four) > 0:
            let card_threshold = 4 - int(unit_is_riled_up(unit))
            if threshold == 0 or threshold > card_threshold:
                threshold = card_threshold
        if unit_orks_effect(board, unit, OrksEffectKind::fight_on_death_dread) > 0:
            let dread_threshold = 4 - 3 * int(orks_type(unit, OrksDatasheet::deff_dread))
            if threshold == 0 or threshold > dread_threshold:
                threshold = dread_threshold
    return threshold

# Grot Shields uses a living Gretchin unit named by the accepted grant; losing
# its last battlefield model ends interception without changing the CP target.
fun orks_grot_shield(Board board, Unit unit) -> Int:
    for member in range(unit.models.size()):
        for effect in range(unit[member].orks_effects.size()):
            ref grant = unit[member].orks_effects[effect]
            if grant.kind.value == OrksEffectKind::grot_shield.value and source_grant_active(board, grant.source_effect):
                for grots in range(board.units.size()):
                    if board.units[grots].identity == grant.associated_unit and !board.units[grots].off_battlefield and has_live_model(board.units[grots]):
                        return grots
    return -1

# Flyin' Headbutt needs the destroyed Aircraft retained until its decision;
# pre-setup casualties with no actual source location cannot use that card.
fun orks_aircraft_death_source(Board board, Model model) -> Bool:
    if !model.has_keyword(Keyword::aircraft):
        return false
    let location = locate_source(board, invalid_entity_identity(), model.identity)
    return location.found and orks_package(board, source_bank_unit(board, location.bank, location.unit.value), OrksDetachment::flyboyz)

# Cargo keyword checks use actual living passenger models in this specific
# carrier. Seats/other transports and offboard distance never count (p64).
fun orks_carrier_has_passenger(Board board, Model carrier, Bool big_mek) -> Bool:
    for passenger in range(board.embarked_units.size()):
        ref unit = board.embarked_units[passenger]
        if unit.embarked_transport != carrier.identity:
            continue
        for member in range(unit.models.size()):
            if unit[member].is_alive() and (big_mek and orks_big_mek(unit[member]) or !big_mek and unit[member].has_keyword(Keyword::warboss)):
                return true
    return false

# Cargo passives reuse keyed own-unit source grants, with an explicit passenger
# dependency. Blitzboss ceases immediately on disembark/death; its accepted
# source usage history is never reset when cargo returns (source card;01.02.02).
fun register_orks_cargo_passives(Board board):
    for passenger in range(board.embarked_units.size()):
        ref unit = board.embarked_units[passenger]
        let carrier = find_passenger_carrier(board, unit.embarked_transport)
        if !carrier.found:
            continue
        let bank = SourceBank::battlefield
        if carrier.reserve:
            bank = SourceBank::reserves
        ref carrier_unit = source_bank_unit(board, bank, carrier.unit.get())
        ref carrier_model = carrier_unit[carrier.model]
        for member in range(unit.models.size()):
            ref bearer = unit[member]
            if !bearer.is_alive():
                continue
            let blitz = model_has_orks_enhancement(unit, bearer, OrksEnhancement::blitzboss) and !carrier_unit.has_keyword(Keyword::walker)
            let boomer = unit_has_orks_enhancement(carrier_unit, OrksEnhancement::boss_boomer) and bearer.has_keyword(Keyword::warboss)
            for effect_index in range(4):
                if effect_index < 2 and !blitz or effect_index >= 2 and !boomer:
                    continue
                if effect_index == 2 and !bearer.has_ability(AbilityKind::keep_huntin) or effect_index == 3 and !bearer.has_ability(AbilityKind::intimidating_motivation):
                    continue
                let instance : SourceInstance
                instance.rule = 460 + effect_index
                instance.owner = carrier_unit.owned_by_player1
                instance.source_unit = carrier_unit.identity
                instance.source_model = carrier_model.identity
                instance.required_embarked_model = bearer.identity
                instance.required_carrier_model = carrier_model.identity
                instance.own_unit_passive = true
                instance.requires_live_source = true
                instance.offboard_allowed = true
                instance.duration = SourceDuration::battle
                instance.name.value = "Orks cargo enhancement"s
                instance.grant = characteristic_modifier(ModifiedCharacteristic::movement, ModifierOperation::add, 2)
                if effect_index == 1:
                    let protection : OrksEffectGrant
                    protection.kind = OrksEffectKind::invulnerable_five
                    protection.amount = 1
                    instance.grant = protection
                if effect_index >= 2:
                    let ability : OrksEffectGrant
                    ability.kind = OrksEffectKind::borrowed_keep_huntin
                    if effect_index == 3:
                        ability.kind = OrksEffectKind::borrowed_intimidation
                    ability.amount = 1
                    instance.grant = ability
                let registered = -1
                for known in range(board.source_instances.size()):
                    if board.source_instances[known].rule.value == instance.rule.value and board.source_instances[known].source_model == instance.source_model:
                        registered = known
                if registered < 0:
                    let added = register_source_instance(board, instance)
                else:
                    board.source_instances[registered].required_embarked_model = bearer.identity
    refresh_source_effects(board, TimingWindow::none)
    register_orks_unit_rules(board)

# Temperamental Shokka grants are bearer-only and named-weapon scoped. Copying
# one model's upgrade to every carrier/unit member would change the card rule.
fun grant_orks_model_effect(Board board, UnitID source, ModelID bearer, Int rule, OrksEffectKind kind):
    let instance : SourceInstance
    instance.rule = rule
    instance.owner = board[source].owned_by_player1
    instance.source_unit = board[source].identity
    instance.source_model = board[source][bearer].identity
    instance.recipient = SourceTarget::source_model
    instance.duration = SourceDuration::phase
    instance.name.value = "Temperamental Shokka"s
    if kind.value == OrksEffectKind::boss_ammo_hit.value:
        instance.name.value = "Boss' Ammo Runt"s
    let effect : OrksEffectGrant
    effect.kind = kind
    effect.amount = 1
    instance.grant = effect
    let handle = register_source_instance(board, instance)
    commit_source_effect_to_unit(board, instance, handle.value, board[source].identity)

# Dreadherder measures from its actual bearer, not a closer bodyguard. Its
# model Lone Operative remains subject to the unattached core rule (p83).
fun orks_dreadherder_bearer_near(Unit unit, Unit walker) -> Bool:
    for member in range(unit.models.size()):
        if model_has_orks_enhancement(unit, unit[member], OrksEnhancement::dreadherder) and live_distance_to_model(walker, unit[member]) <= 3.0:
            return true
    return false

# User roster limits: three copies, six for Battleline, applied before
# attachments merge units. Detachment force dispositions precede this check.
# Named datasheet identity is explicit; unknown legacy fixtures are not guessed.
fun orks_muster_copies_valid(Board board) -> Bool:
    for slot in range(board.reserve_units.size()):
        ref unit = board.reserve_units[slot]
        if unit.models.empty() or !unit.has_keyword(Keyword::orks):
            continue
        let code = unit[0].datasheet.value
        if code == 0:
            continue
        let copies = 0
        for other in range(board.reserve_units.size()):
            ref candidate = board.reserve_units[other]
            if !candidate.models.empty() and candidate.owned_by_player1 == unit.owned_by_player1 and candidate[0].datasheet.value == code:
                copies = copies + 1
        if copies > 3 + 3 * int(unit.has_keyword(Keyword::battleline)):
            return false
    return true

# Convert an already validated battlefield slot to the existing finite action
# selector; persistent references still use EntityIdentity (infrastructure).
fun unit_id_for_orks_slot(Int slot) -> UnitID:
    let result : UnitID
    result = slot
    return result

# Save integrity covers the new bounded activation ledger and modifier stacks;
# these are implementation invariants, not additional tabletop restrictions.
fun valid_orks_detachment_foundations(Board board) -> Bool:
    if board.orks_attack_serial.value < 0 or board.orks_attack_serial.value >= 1025 or board.orks_reaction_target.value < 0 or board.orks_reaction_target.value > board.next_identity.value:
        return false
    if !valid_rule_modifiers(board.attack_info.orks_hit_modifiers) or !valid_rule_modifiers(board.attack_info.orks_wound_modifiers):
        return false
    for record in range(board.orks_attack_records.size()):
        ref entry = board.orks_attack_records[record]
        if entry.target.value <= 0 or entry.target.value > board.next_identity.value or entry.successful_hits.value < 0 or entry.successful_hits.value >= MAX_COMBAT_COUNTER or entry.wounds_lost.value < 0 or entry.wounds_lost.value >= MAX_COMBAT_COUNTER:
            return false
        # Squig Barrage's weapon-specific hits are a subset of all hits;
        # malformed saves cannot fabricate post-shot triggers (Squigbuggies).
        if entry.squig_launcha_hits.value < 0 or entry.squig_launcha_hits.value > entry.successful_hits.value:
            return false
        for previous in range(record):
            if board.orks_attack_records[previous].target == entry.target:
                return false
    return true

# Kill Kommanda/Kaptin add one permission to the native list. An already
# permitted bodyguard stays one entry, preserving the exact seven-slot envelope.
fun orks_extra_bodyguard_permission(Unit unit, OrksDatasheet tag):
    for existing in range(unit.permitted_bodyguards.size()):
        if unit.permitted_bodyguards[existing].value == tag.value:
            return
    orks_bodyguard_permission(unit.permitted_bodyguards, tag)
