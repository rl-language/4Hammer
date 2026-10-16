import board
import source_effects

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
    if unit.owned_by_player1 != owner or bearer.get() >= unit.models.size() or orks_unit_has_any_option(unit) or !orks_package(board, unit, orks_enhancement_package(option)):
        return false
    ref model = unit[bearer.get()]
    if !enhancement_recipient_valid(unit, model, orks_is_upgrade(option)) or !orks_option_source_eligible(unit, model, option):
        return false
    let counter : EnhancementSelectionCounter
    for roster_unit in range(board.reserve_units.size()):
        ref existing = board.reserve_units[roster_unit]
        if existing.owned_by_player1 != owner:
            continue
        for model_index in range(existing.models.size()):
            let existing_option = existing[model_index].orks_enhancement.value
            if existing_option == 0:
                continue
            counter.record_choice(existing_option)
        counter.record_unit_copy(unit_has_orks_enhancement(existing, option))
    return counter.permits(option.value, orks_is_upgrade(option))

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
        equip_weapon(unit[bearer.get()], Weapon::orks_da_gobshot_thunderbuss, 0)
    if option.value == OrksEnhancement::da_krunch.value:
        equip_weapon(unit[bearer.get()], Weapon::orks_da_krunch, 0)
    if option.value == OrksEnhancement::eadbanger.value:
        equip_weapon(unit[bearer.get()], Weapon::orks_eadbanger, 0)

# Core Select Enhancements gives options to different roster units BEFORE
# forming attachments. Joining those original units does not select another
# option; the user's Epic Hero exclusion still applies to the attached unit.
fun orks_enhancement_attachment_valid(Unit leader, Unit bodyguard) -> Bool:
    let leader_option = orks_unit_has_any_option(leader)
    let bodyguard_option = orks_unit_has_any_option(bodyguard)
    return enhancement_attachment_valid(leader, bodyguard, leader_option or bodyguard_option)

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

# Kill Kommanda/Kaptin add one permission to the native list. An already
# permitted bodyguard stays one entry, preserving the exact seven-slot envelope.
fun orks_extra_bodyguard_permission(Unit unit, OrksDatasheet tag):
    for existing in range(unit.permitted_bodyguards.size()):
        if unit.permitted_bodyguards[existing].value == tag.value:
            return
    orks_bodyguard_permission(unit.permitted_bodyguards, tag)
