import muster_rules
import board
import source_effects
import factions.orks.datasheets

# Pre-identity muster metadata, not model state. Small bounded ordinals are
# translated into the existing typed loadout validators/factories below.
# Sources: all54 included cards, doc/factions/orks/orks-unit-requirements.tsv; prices excluded.
cls OrksMusterEquipment:
    LinearlyDistributedInt<0, 6> primary
    LinearlyDistributedInt<0, 6> secondary
    Bool[4] extras

cls OrksMusterDraft:
    OrksDatasheet sheet
    LinearlyDistributedInt<1, 21> count
    BInt<1, 3> nobs
    OrksMusterEquipment[20] equipment

using OrksMusterValue = BInt<0, 21>

enum OrksMusterField:
    models
    nobs
    primary
    secondary
    extra_one
    extra_two
    extra_three
    extra_four

# Explicit allowlist keeps historical Forge World/Legends identities out.
# Source scope is the user's54 standard cards, not every catalog enum value.
fun orks_muster_included(OrksDatasheet sheet) -> Bool:
    if sheet.value == OrksDatasheet::bannernob.value:
        return true
    if sheet.value == OrksDatasheet::beastboss.value:
        return true
    if sheet.value == OrksDatasheet::big_mek_dakkarig.value:
        return true
    if sheet.value == OrksDatasheet::big_mek_with_shokk_attack_gun.value:
        return true
    if sheet.value == OrksDatasheet::bigboss.value:
        return true
    if sheet.value == OrksDatasheet::blitza_bommer.value:
        return true
    if sheet.value == OrksDatasheet::boss_snikrot.value:
        return true
    if sheet.value == OrksDatasheet::deffkilla_wartrike.value:
        return true
    if sheet.value == OrksDatasheet::ghazghkull_thraka.value:
        return true
    if sheet.value == OrksDatasheet::gorkanaut.value:
        return true
    if sheet.value == OrksDatasheet::hunta_rig.value:
        return true
    if sheet.value == OrksDatasheet::kill_rig.value:
        return true
    if sheet.value == OrksDatasheet::mek.value:
        return true
    if sheet.value == OrksDatasheet::morkanaut.value:
        return true
    if sheet.value == OrksDatasheet::mozrog_skragbad.value:
        return true
    if sheet.value == OrksDatasheet::nazdreg.value:
        return true
    if sheet.value == OrksDatasheet::painboss.value:
        return true
    if sheet.value == OrksDatasheet::painboy.value:
        return true
    if sheet.value == OrksDatasheet::runtherd.value:
        return true
    if sheet.value == OrksDatasheet::warboss_in_mega_armour.value:
        return true
    if sheet.value == OrksDatasheet::wazdakka_gutsmek.value:
        return true
    if sheet.value == OrksDatasheet::weirdboy.value:
        return true
    if sheet.value == OrksDatasheet::zodgrod_wortsnagga.value:
        return true
    if sheet.value == OrksDatasheet::battlewagon.value:
        return true
    if sheet.value == OrksDatasheet::big_ed_bossbunka.value:
        return true
    if sheet.value == OrksDatasheet::gunwagon.value:
        return true
    if sheet.value == OrksDatasheet::big_mek.value:
        return true
    if sheet.value == OrksDatasheet::big_mek_in_mega_armour.value:
        return true
    if sheet.value == OrksDatasheet::beastboss_on_squigosaur.value:
        return true
    if sheet.value == OrksDatasheet::burna_bommer.value:
        return true
    if sheet.value == OrksDatasheet::dakkajet.value:
        return true
    if sheet.value == OrksDatasheet::deff_dread.value:
        return true
    if sheet.value == OrksDatasheet::stompa.value:
        return true
    if sheet.value == OrksDatasheet::trukk.value:
        return true
    if sheet.value == OrksDatasheet::warboss.value:
        return true
    if sheet.value == OrksDatasheet::wazbom_blastajet.value:
        return true
    if sheet.value == OrksDatasheet::beast_snagga_boyz.value:
        return true
    if sheet.value == OrksDatasheet::squighog_boyz.value:
        return true
    if sheet.value == OrksDatasheet::stormboyz.value:
        return true
    if sheet.value == OrksDatasheet::warbikers.value:
        return true
    if sheet.value == OrksDatasheet::killa_kans.value:
        return true
    if sheet.value == OrksDatasheet::flash_gitz.value:
        return true
    if sheet.value == OrksDatasheet::gretchin.value:
        return true
    if sheet.value == OrksDatasheet::wartrakks.value:
        return true
    if sheet.value == OrksDatasheet::rukkatrukk_squigbuggies.value:
        return true
    if sheet.value == OrksDatasheet::breaka_boyz.value:
        return true
    if sheet.value == OrksDatasheet::tankbustas.value:
        return true
    if sheet.value == OrksDatasheet::boyz.value:
        return true
    if sheet.value == OrksDatasheet::nobz.value:
        return true
    if sheet.value == OrksDatasheet::meganobz.value:
        return true
    if sheet.value == OrksDatasheet::deffkoptas.value:
        return true
    if sheet.value == OrksDatasheet::warbuggies.value:
        return true
    if sheet.value == OrksDatasheet::mek_gunz.value:
        return true
    if sheet.value == OrksDatasheet::kommandos.value:
        return true
    return false

# Printed composition ranges, not priced size tiers (Orks card Unit Composition).
fun orks_muster_min(OrksDatasheet sheet) -> Int:
    if sheet.value == OrksDatasheet::boyz.value:
        return 10
    if sheet.value == OrksDatasheet::beast_snagga_boyz.value:
        return 10
    if sheet.value == OrksDatasheet::squighog_boyz.value:
        return 4
    if sheet.value == OrksDatasheet::nobz.value:
        return 5
    if sheet.value == OrksDatasheet::stormboyz.value:
        return 5
    if sheet.value == OrksDatasheet::warbikers.value:
        return 3
    if sheet.value == OrksDatasheet::killa_kans.value:
        return 3
    if sheet.value == OrksDatasheet::flash_gitz.value:
        return 5
    if sheet.value == OrksDatasheet::gretchin.value:
        return 10
    if sheet.value == OrksDatasheet::meganobz.value:
        return 2
    if sheet.value == OrksDatasheet::deffkoptas.value:
        return 3
    if sheet.value == OrksDatasheet::mek_gunz.value:
        return 1
    if sheet.value == OrksDatasheet::warbuggies.value:
        return 1
    if sheet.value == OrksDatasheet::wartrakks.value:
        return 1
    if sheet.value == OrksDatasheet::rukkatrukk_squigbuggies.value:
        return 1
    if sheet.value == OrksDatasheet::kommandos.value:
        return 10
    if sheet.value == OrksDatasheet::breaka_boyz.value or sheet.value == OrksDatasheet::tankbustas.value:
        return 6
    return 1

# Same source ranges; the upper bound is at most20 before attachments.
fun orks_muster_max(OrksDatasheet sheet) -> Int:
    if sheet.value == OrksDatasheet::boyz.value:
        return 20
    if sheet.value == OrksDatasheet::beast_snagga_boyz.value:
        return 20
    if sheet.value == OrksDatasheet::squighog_boyz.value:
        return 8
    if sheet.value == OrksDatasheet::nobz.value:
        return 10
    if sheet.value == OrksDatasheet::stormboyz.value:
        return 10
    if sheet.value == OrksDatasheet::warbikers.value:
        return 6
    if sheet.value == OrksDatasheet::killa_kans.value:
        return 6
    if sheet.value == OrksDatasheet::flash_gitz.value:
        return 10
    if sheet.value == OrksDatasheet::gretchin.value:
        return 20
    if sheet.value == OrksDatasheet::meganobz.value:
        return 6
    if sheet.value == OrksDatasheet::deffkoptas.value:
        return 6
    if sheet.value == OrksDatasheet::mek_gunz.value:
        return 3
    if sheet.value == OrksDatasheet::warbuggies.value:
        return 2
    if sheet.value == OrksDatasheet::wartrakks.value:
        return 2
    if sheet.value == OrksDatasheet::rukkatrukk_squigbuggies.value:
        return 2
    return orks_muster_min(sheet)

# Changes to composition reset equipment explicitly; no invalid old model kit
# or quota survives a resize. Constructors still enforce the card rules.
fun reset_orks_muster_equipment(OrksMusterDraft draft):
    let empty : OrksMusterEquipment
    for member_index in range(20):
        draft.equipment[member_index] = empty
    if draft.sheet.value == OrksDatasheet::deff_dread.value:
        draft.equipment[0].secondary = 1

# Default legal composition/equipment for every included card. No identities
# are allocated until the draft is accepted (core pp66-67, roster lifecycle).
fun orks_muster_draft(OrksDatasheet sheet) -> OrksMusterDraft:
    assert(orks_muster_included(sheet), "excluded Orks datasheet")
    let draft : OrksMusterDraft
    draft.sheet = sheet
    draft.count = orks_muster_min(sheet)
    reset_orks_muster_equipment(draft)
    return draft

# Typed conversion reuses source validators instead of duplicating quotas.
# Orks/Boyz equipment; the Nob Big Choppa replaces both original weapons.
fun orks_muster_boyz(OrksMusterDraft draft) -> OrksBoyzLoadouts:
    let result : OrksBoyzLoadouts
    for member_index in range(draft.count.value):
        let item = orks_boy_loadout()
        item.nob = member_index < draft.nobs.value
        if item.nob:
            item.melee = orks_nob_melee_choice(draft.equipment[member_index].primary.value)
            item.nob_gun = orks_nob_gun_choice(draft.equipment[member_index].secondary.value)
        else:
            item.boy_gun = orks_boy_gun_choice(draft.equipment[member_index].primary.value)
        result.append(item)
    return result

# Nobz's independently limited replacement types (Orks/Nobz).
fun orks_muster_nobz(OrksMusterDraft draft) -> OrksNobLoadouts:
    let result : OrksNobLoadouts
    for member_index in range(draft.count.value):
        let item = orks_nob_loadout_choice(draft.equipment[member_index].primary.value)
        result.append(item)
    return result

# Meganobz's five complete weapon pairs (Orks/Meganobz).
fun orks_muster_meganobz(OrksMusterDraft draft) -> OrksMeganobLoadouts:
    let result : OrksMeganobLoadouts
    for member_index in range(draft.count.value):
        let item = orks_meganob_loadout_choice(draft.equipment[member_index].primary.value)
        result.append(item)
    return result

# Kommandos retain independent optional slots, including multiple on one Boy.
# Source Orks/Kommandos, equipment and10-model formation split.
fun orks_muster_kommandos(OrksMusterDraft draft) -> OrksKommandoLoadout:
    let result : OrksKommandoLoadout
    for member_index in range(10):
        let item = orks_kommando_equipment()
        item.nob_melee = orks_nob_melee_choice(draft.equipment[member_index].primary.value)
        item.burna = draft.equipment[member_index].extras[0]
        item.rokkit = draft.equipment[member_index].extras[1]
        item.breacha_ram = draft.equipment[member_index].extras[2]
        item.kustom_shoota = draft.equipment[member_index].extras[3]
        result.append(item)
    return result

# Public drafts must pass the same existing quota validators as direct data
# factories; this gate is safe for every finite candidate and never constructs
# an invalid Unit just to test eligibility. Sources: each card Equipment.
fun orks_muster_valid(OrksMusterDraft draft) -> Bool:
    if !orks_muster_included(draft.sheet) or draft.count.value < orks_muster_min(draft.sheet) or draft.count.value > orks_muster_max(draft.sheet):
        return false
    for member_index in range(20):
        for field_index in range(6):
            let field : OrksMusterField
            field.value = field_index + 2
            let value = 0
            if field_index == 0:
                value = draft.equipment[member_index].primary.value
            if field_index == 1:
                value = draft.equipment[member_index].secondary.value
            if field_index >= 2:
                value = int(draft.equipment[member_index].extras[field_index - 2])
            let maximum = orks_muster_field_max(draft, member_index, field)
            let paired_nob = draft.sheet.value == OrksDatasheet::boyz.value and member_index < draft.nobs.value and draft.equipment[member_index].primary.value == 2 and field_index == 1 and value == 3
            if !paired_nob and ((maximum < 0 and value != 0) or (maximum >= 0 and value > maximum)):
                return false
    ref kit = draft.equipment[0]
    if draft.sheet.value == OrksDatasheet::boyz.value:
        return orks_boyz_loadout_valid(orks_muster_boyz(draft))
    if draft.sheet.value == OrksDatasheet::beast_snagga_boyz.value:
        return orks_snagga_composition_valid(draft.nobs.value, draft.count.value - draft.nobs.value, kit.primary.value)
    if draft.sheet.value == OrksDatasheet::squighog_boyz.value:
        return orks_squighog_composition_valid(draft.nobs.value, draft.count.value - draft.nobs.value)
    if draft.sheet.value == OrksDatasheet::nobz.value:
        return orks_nobz_loadout_valid(orks_muster_nobz(draft))
    if draft.sheet.value == OrksDatasheet::meganobz.value:
        return orks_meganob_loadout_valid(orks_muster_meganobz(draft))
    if draft.sheet.value == OrksDatasheet::kommandos.value:
        return orks_kommando_loadout_valid(orks_muster_kommandos(draft))
    if draft.sheet.value == OrksDatasheet::deff_dread.value:
        return kit.primary.value < 5 and kit.primary.value != 1 and kit.secondary.value < 5
    if draft.sheet.value == OrksDatasheet::deffkoptas.value:
        let replacements = 0
        for kopta_index in range(draft.count.value):
            replacements = replacements + int(draft.equipment[kopta_index].extras[0])
        return replacements <= draft.count.value / 3
    if draft.sheet.value == OrksDatasheet::breaka_boyz.value:
        let knuckles = 0
        let hammers = 0
        for breaka_index in range(6):
            if breaka_index == 0:
                continue
            knuckles = knuckles + int(draft.equipment[breaka_index].primary.value == 1)
            hammers = hammers + int(draft.equipment[breaka_index].primary.value == 2)
            if draft.equipment[breaka_index].primary.value > 2:
                return false
        return knuckles <= 1 and hammers <= 1
    return true

# Map draft ordinals to existing enum parameters, preserving one source of
# truth for profiles, capacities, abilities and exact physical copies.
# Sources: the54 Orks constructors' cited cards. Invalid drafts never commit.
fun make_orks_muster_unit(OrksMusterDraft draft) -> Unit:
    assert(orks_muster_valid(draft), "invalid Orks muster draft")
    ref kit = draft.equipment[0]
    let count = draft.count.value
    if draft.sheet.value == OrksDatasheet::bannernob.value:
        return make_orks_bannernob()
    if draft.sheet.value == OrksDatasheet::beastboss.value:
        return make_orks_beastboss()
    if draft.sheet.value == OrksDatasheet::big_mek_dakkarig.value:
        return make_orks_big_mek_dakkarig()
    if draft.sheet.value == OrksDatasheet::big_mek_with_shokk_attack_gun.value:
        return make_orks_big_mek_with_shokk_attack_gun()
    if draft.sheet.value == OrksDatasheet::bigboss.value:
        return make_orks_bigboss()
    if draft.sheet.value == OrksDatasheet::blitza_bommer.value:
        return make_orks_blitza_bommer()
    if draft.sheet.value == OrksDatasheet::boss_snikrot.value:
        return make_orks_boss_snikrot()
    if draft.sheet.value == OrksDatasheet::deffkilla_wartrike.value:
        return make_orks_deffkilla_wartrike()
    if draft.sheet.value == OrksDatasheet::ghazghkull_thraka.value:
        return make_orks_ghazghkull_thraka()
    if draft.sheet.value == OrksDatasheet::gorkanaut.value:
        return make_orks_gorkanaut()
    if draft.sheet.value == OrksDatasheet::hunta_rig.value:
        return make_orks_hunta_rig()
    if draft.sheet.value == OrksDatasheet::kill_rig.value:
        return make_orks_kill_rig()
    if draft.sheet.value == OrksDatasheet::mek.value:
        return make_orks_mek()
    if draft.sheet.value == OrksDatasheet::morkanaut.value:
        return make_orks_morkanaut()
    if draft.sheet.value == OrksDatasheet::mozrog_skragbad.value:
        return make_orks_mozrog_skragbad()
    if draft.sheet.value == OrksDatasheet::nazdreg.value:
        return make_orks_nazdreg()
    if draft.sheet.value == OrksDatasheet::painboss.value:
        return make_orks_painboss()
    if draft.sheet.value == OrksDatasheet::painboy.value:
        return make_orks_painboy()
    if draft.sheet.value == OrksDatasheet::runtherd.value:
        return make_orks_runtherd()
    if draft.sheet.value == OrksDatasheet::warboss_in_mega_armour.value:
        return make_orks_warboss_in_mega_armour()
    if draft.sheet.value == OrksDatasheet::wazdakka_gutsmek.value:
        return make_orks_wazdakka_gutsmek()
    if draft.sheet.value == OrksDatasheet::weirdboy.value:
        return make_orks_weirdboy()
    if draft.sheet.value == OrksDatasheet::zodgrod_wortsnagga.value:
        return make_orks_zodgrod_wortsnagga()
    if draft.sheet.value == OrksDatasheet::battlewagon.value:
        return make_orks_battlewagon(0, kit.primary.value, kit.extras[0], kit.extras[1])
    if draft.sheet.value == OrksDatasheet::big_ed_bossbunka.value:
        return make_orks_big_ed_bossbunka(0, kit.primary.value)
    if draft.sheet.value == OrksDatasheet::gunwagon.value:
        let gunwagon = orks_gunwagon_gun_choice(kit.secondary.value)
        return make_orks_gunwagon(0, kit.primary.value, kit.extras[0], kit.extras[1], kit.extras[2], gunwagon)
    if draft.sheet.value == OrksDatasheet::big_mek.value:
        return make_orks_big_mek(kit.extras[0], kit.extras[1])
    if draft.sheet.value == OrksDatasheet::big_mek_in_mega_armour.value:
        let mega_gun = orks_mega_mek_gun_choice(kit.primary.value)
        let mega_extra = orks_mega_mek_extra_choice(kit.secondary.value)
        return make_orks_big_mek_in_mega_armour(mega_gun, mega_extra)
    if draft.sheet.value == OrksDatasheet::beastboss_on_squigosaur.value:
        return make_orks_beastboss_on_squigosaur(kit.extras[0])
    if draft.sheet.value == OrksDatasheet::burna_bommer.value:
        return make_orks_burna_bommer(kit.extras[0])
    if draft.sheet.value == OrksDatasheet::dakkajet.value:
        return make_orks_dakkajet(kit.extras[0])
    if draft.sheet.value == OrksDatasheet::deff_dread.value:
        let dread_first = orks_dread_arm_choice(kit.primary.value)
        let dread_second = orks_dread_arm_choice(kit.secondary.value)
        return make_orks_deff_dread(dread_first, dread_second)
    if draft.sheet.value == OrksDatasheet::stompa.value:
        return make_orks_stompa(0)
    if draft.sheet.value == OrksDatasheet::trukk.value:
        let trukk_extra = orks_trukk_extra_choice(kit.primary.value)
        return make_orks_trukk(0, kit.extras[0], trukk_extra)
    if draft.sheet.value == OrksDatasheet::warboss.value:
        let warboss_gun = orks_nob_gun_choice(kit.primary.value)
        return make_orks_warboss(kit.extras[0], warboss_gun)
    if draft.sheet.value == OrksDatasheet::wazbom_blastajet.value:
        return make_orks_wazbom_blastajet(kit.extras[0], kit.extras[1], kit.extras[2])
    if draft.sheet.value == OrksDatasheet::beast_snagga_boyz.value:
        return make_orks_beast_snagga_boyz(draft.nobs.value, count - draft.nobs.value, kit.primary.value)
    if draft.sheet.value == OrksDatasheet::squighog_boyz.value:
        return make_orks_squighog_boyz(draft.nobs.value, count - draft.nobs.value)
    if draft.sheet.value == OrksDatasheet::stormboyz.value:
        return make_orks_stormboyz(count - 1, kit.extras[0])
    if draft.sheet.value == OrksDatasheet::warbikers.value:
        return make_orks_warbikers(count - 1)
    if draft.sheet.value == OrksDatasheet::killa_kans.value:
        return make_orks_killa_kans(count)
    if draft.sheet.value == OrksDatasheet::flash_gitz.value:
        return make_orks_flash_gitz(count - 1)
    if draft.sheet.value == OrksDatasheet::gretchin.value:
        return make_orks_gretchin(count)
    if draft.sheet.value == OrksDatasheet::wartrakks.value:
        return make_orks_wartrakks(count)
    if draft.sheet.value == OrksDatasheet::rukkatrukk_squigbuggies.value:
        return make_orks_rukkatrukk_squigbuggies(count)
    if draft.sheet.value == OrksDatasheet::breaka_boyz.value:
        let knuckles = 5
        let hammer = 5
        for breaka_index in range(6):
            if breaka_index == 0:
                continue
            if draft.equipment[breaka_index].primary.value == 1:
                knuckles = breaka_index - 1
            if draft.equipment[breaka_index].primary.value == 2:
                hammer = breaka_index - 1
        return make_orks_breaka_boyz(kit.extras[0], knuckles, hammer)
    if draft.sheet.value == OrksDatasheet::tankbustas.value:
        let tank_extra = orks_tankbusta_extra_choice(kit.secondary.value)
        return make_orks_tankbustas(kit.extras[0], tank_extra, kit.primary.value)
    if draft.sheet.value == OrksDatasheet::boyz.value:
        let boyz = orks_muster_boyz(draft)
        return make_orks_boyz(boyz)
    if draft.sheet.value == OrksDatasheet::nobz.value:
        let nobz = orks_muster_nobz(draft)
        return make_orks_nobz(nobz)
    if draft.sheet.value == OrksDatasheet::meganobz.value:
        let meganobz = orks_muster_meganobz(draft)
        return make_orks_meganobz(meganobz)
    if draft.sheet.value == OrksDatasheet::deffkoptas.value:
        let kopta_swaps : OrksVehicleSwaps
        for kopta_index in range(count):
            kopta_swaps.append(draft.equipment[kopta_index].extras[0])
        return make_orks_deffkoptas(kopta_swaps)
    if draft.sheet.value == OrksDatasheet::warbuggies.value:
        let buggy_swaps : OrksVehicleSwaps
        for buggy_index in range(count):
            buggy_swaps.append(draft.equipment[buggy_index].extras[0])
        return make_orks_warbuggies(buggy_swaps)
    if draft.sheet.value == OrksDatasheet::mek_gunz.value:
        let guns : OrksMekGuns
        for mek_index in range(count):
            let gun = orks_mek_gun_choice(draft.equipment[mek_index].primary.value)
            guns.append(gun)
        return make_orks_mek_gunz(guns, 0)
    if draft.sheet.value == OrksDatasheet::kommandos.value:
        let kommandos = orks_muster_kommandos(draft)
        return make_orks_kommandos(kommandos)
    assert(false, "included card lacks a muster factory")
    let impossible : Unit
    return impossible

# Field availability/upper bounds keep generic draft controls tied to the
# selected card/model. Labels below expose real equipment names, not ordinals.
# Source: each selected Orks card's Equipment/Unit Composition sections.
fun orks_muster_field_max(OrksMusterDraft draft, Int member_index, OrksMusterField field) -> Int:
    if member_index < 0 or member_index >= draft.count.value:
        return -1
    let sheet = draft.sheet
    if field.value == OrksMusterField::models.value:
        if orks_muster_min(sheet) != orks_muster_max(sheet):
            return orks_muster_max(sheet)
        return -1
    if field.value == OrksMusterField::nobs.value:
        if sheet.value == OrksDatasheet::boyz.value or sheet.value == OrksDatasheet::beast_snagga_boyz.value or sheet.value == OrksDatasheet::squighog_boyz.value:
            return 2
        return -1
    if field.value == OrksMusterField::primary.value:
        if sheet.value == OrksDatasheet::boyz.value:
            return 3 - int(member_index < draft.nobs.value)
        if sheet.value == OrksDatasheet::nobz.value:
            return 5
        if sheet.value == OrksDatasheet::meganobz.value:
            return 4
        if sheet.value == OrksDatasheet::mek_gunz.value:
            return 3
        if sheet.value == OrksDatasheet::breaka_boyz.value and member_index > 0:
            return 2
        if member_index == 0:
            if sheet.value == OrksDatasheet::battlewagon.value or sheet.value == OrksDatasheet::gunwagon.value or sheet.value == OrksDatasheet::tankbustas.value or sheet.value == OrksDatasheet::deff_dread.value:
                return 4
            if sheet.value == OrksDatasheet::big_ed_bossbunka.value or sheet.value == OrksDatasheet::big_mek_in_mega_armour.value:
                return 3
            if sheet.value == OrksDatasheet::trukk.value or sheet.value == OrksDatasheet::warboss.value or sheet.value == OrksDatasheet::kommandos.value or sheet.value == OrksDatasheet::beast_snagga_boyz.value:
                return 2
        return -1
    if field.value == OrksMusterField::secondary.value:
        if sheet.value == OrksDatasheet::boyz.value and member_index < draft.nobs.value and draft.equipment[member_index].primary.value != 2:
            return 2
        if member_index == 0:
            if sheet.value == OrksDatasheet::deff_dread.value:
                return 4
            if sheet.value == OrksDatasheet::big_mek_in_mega_armour.value or sheet.value == OrksDatasheet::gunwagon.value or sheet.value == OrksDatasheet::tankbustas.value:
                return 2
        return -1
    let extra = field.value - OrksMusterField::extra_one.value
    if extra < 0 or extra >= 4:
        return -1
    if sheet.value == OrksDatasheet::kommandos.value and member_index > 0:
        return 1
    if (sheet.value == OrksDatasheet::warbuggies.value or sheet.value == OrksDatasheet::deffkoptas.value) and extra == 0:
        return 1
    if member_index != 0:
        return -1
    if extra == 0 and (sheet.value == OrksDatasheet::beastboss_on_squigosaur.value or sheet.value == OrksDatasheet::burna_bommer.value or sheet.value == OrksDatasheet::dakkajet.value or sheet.value == OrksDatasheet::trukk.value or sheet.value == OrksDatasheet::warboss.value or sheet.value == OrksDatasheet::stormboyz.value or sheet.value == OrksDatasheet::breaka_boyz.value or sheet.value == OrksDatasheet::tankbustas.value):
        return 1
    if extra <= 1 and (sheet.value == OrksDatasheet::big_mek.value or sheet.value == OrksDatasheet::battlewagon.value):
        return 1
    if extra <= 2 and (sheet.value == OrksDatasheet::wazbom_blastajet.value or sheet.value == OrksDatasheet::gunwagon.value):
        return 1
    return -1

# Apply only structurally valid values. Composition changes intentionally reset
# equipment; paired Nob replacements update both slots together (Orks/Boyz).
fun assign_orks_muster_value(OrksMusterDraft draft, Int member_index, OrksMusterField field, Int value):
    if field.value == OrksMusterField::models.value:
        draft.count = value
        draft.nobs = 1
        if (draft.sheet.value == OrksDatasheet::boyz.value or draft.sheet.value == OrksDatasheet::beast_snagga_boyz.value) and value == 20 or draft.sheet.value == OrksDatasheet::squighog_boyz.value and value == 8:
            draft.nobs = 2
        reset_orks_muster_equipment(draft)
    else:
        if field.value == OrksMusterField::nobs.value:
            draft.nobs = value
            reset_orks_muster_equipment(draft)
        else:
            if field.value == OrksMusterField::primary.value:
                draft.equipment[member_index].primary = value
                if draft.sheet.value == OrksDatasheet::boyz.value and member_index < draft.nobs.value:
                    draft.equipment[member_index].secondary = 3 * int(value == 2)
            else:
                if field.value == OrksMusterField::secondary.value:
                    draft.equipment[member_index].secondary = value
                else:
                    draft.equipment[member_index].extras[field.value - OrksMusterField::extra_one.value] = value == 1

# Stage small bounded draft metadata, not a Board/Unit copy. Invalid quota
# choices reject atomically; source factories are called only after acceptance.
fun orks_muster_value_valid(OrksMusterDraft draft, Int member_index, OrksMusterField field, Int value) -> Bool:
    let maximum = orks_muster_field_max(draft, member_index, field)
    if value < 0 or value > maximum or (field.value == OrksMusterField::nobs.value and value == 0) or (field.value == OrksMusterField::models.value and value < orks_muster_min(draft.sheet)):
        return false
    let candidate = draft
    assign_orks_muster_value(candidate, member_index, field, value)
    return orks_muster_valid(candidate)

# Implementation capacity reserves room for both armies in the32-unit bank;
# it is not a tabletop muster limit and is independent of prices.
fun orks_muster_army_size(Board board, Bool owner) -> Int:
    let count = 0
    for slot in range(board.reserve_units.size()):
        count = count + int(board.reserve_units[slot].owned_by_player1 == owner)
    return count

# Live draft acceptance applies the same sourced copy limits as battle muster,
# including selected detachment Battleline grants. Identities are not consumed.
fun orks_muster_add_valid(Board board, Bool owner, OrksMusterDraft draft) -> Bool:
    if !board.reserve_units.has_capacity() or orks_muster_army_size(board, owner) >= 16 or !orks_muster_valid(draft):
        return false
    let unit = make_orks_muster_unit(draft)
    unit.owned_by_player1 = owner
    # Repeated pre-battle edits may exhaust the finite identity envelope;
    # reject the addition before identify_units can assert on a legal input.
    if board.next_identity.value + unit.models.size() + 1 > MAX_ENTITY_IDENTITIES:
        return false
    let copies = 0
    for slot in range(board.reserve_units.size()):
        if board.reserve_units[slot].owned_by_player1 == owner and board.reserve_units[slot][0].datasheet.value == draft.sheet.value:
            copies = copies + 1
    return copies < orks_muster_copy_limit(board, unit)

# Source-backed point-free muster; Warlord-capable Characters are mandatory
# before finishing (user supplied Warlord rule/core Select Army). All draft
# mutation precedes enhancements, Warlord selection, attachments and identities.
act muster_orks_unit(ctx Board board, frm Bool owner, frm OrksDatasheet sheet) -> MusterOrksUnit:
    frm draft = orks_muster_draft(sheet)
    frm member_index : ModelID
    frm finished = false
    while !finished:
        actions:
            act cancel_orks_muster_unit()
                finished = true
            act select_orks_muster_model(ModelID model) {model.get() < draft.count.value}
                member_index = model
            act choose_orks_muster_field(frm OrksMusterField field) {orks_muster_field_max(draft, member_index.get(), field) >= 0}
                act choose_orks_muster_value(OrksMusterValue value) {orks_muster_value_valid(draft, member_index.get(), field, value.value)}
                assign_orks_muster_value(draft, member_index.get(), field, value.value)
                if member_index.get() >= draft.count.value:
                    member_index = 0
            act add_orks_muster_unit() {orks_muster_add_valid(board, owner, draft)}
                board.reserve_units.append(make_orks_muster_unit(draft))
                board.reserve_units.back().owned_by_player1 = owner
                board.identify_units()
                finished = true

# No unit is committed until its complete loadout is legal. Removing an entry
# edits the pre-battle roster only, before any source/attachment registration.
act build_orks_roster(ctx Board board, frm Bool owner) -> BuildOrksRoster:
    board.current_decision_maker = owner
    frm finished = false
    while !finished:
        actions:
            act finish_orks_roster() {has_orks_warlord_choice(board, owner) and muster_copies_valid(board)}
                finished = true
            act choose_orks_muster_unit(OrksDatasheet sheet) {orks_muster_included(sheet), board.reserve_units.has_capacity(), orks_muster_army_size(board, owner) < 16}
                subaction*(board) entry = muster_orks_unit(board, owner, sheet)
            act remove_orks_muster_unit(UnitID unit) {unit.get() < board.reserve_units.size(), board.reserve_units[unit.get()].owned_by_player1 == owner}
                board.reserve_units.erase(unit.get())

# Equipment labels are sourced card terms. Generic ordinal storage stays an
# implementation detail rather than appearing as numbered weapon choices.
fun orks_muster_field_label(OrksMusterDraft draft, Int member_index, OrksMusterField field) -> String:
    if field.value == OrksMusterField::models.value:
        return "Number of models (resets equipment)"s
    if field.value == OrksMusterField::nobs.value:
        return "Number of Nobz (resets equipment)"s
    if field.value == OrksMusterField::secondary.value:
        if draft.sheet.value == OrksDatasheet::deff_dread.value:
            return "Second arm"s
        if draft.sheet.value == OrksDatasheet::big_mek_in_mega_armour.value:
            return "Extra equipment"s
        if draft.sheet.value == OrksDatasheet::gunwagon.value:
            return "Main gun"s
        if draft.sheet.value == OrksDatasheet::tankbustas.value:
            return "Extra equipment"s
        return "Nob ranged weapon"s
    if field.value == OrksMusterField::primary.value:
        if draft.sheet.value == OrksDatasheet::beast_snagga_boyz.value:
            return "Number of Thump Guns"s
        if draft.sheet.value == OrksDatasheet::battlewagon.value or draft.sheet.value == OrksDatasheet::gunwagon.value or draft.sheet.value == OrksDatasheet::big_ed_bossbunka.value:
            return "Number of Big Shootas"s
        if draft.sheet.value == OrksDatasheet::tankbustas.value:
            return "Boy receiving extra equipment"s
        if draft.sheet.value == OrksDatasheet::deff_dread.value:
            return "First arm"s
        return "Weapons"s
    let extra = field.value - OrksMusterField::extra_one.value
    let sheet = draft.sheet
    if sheet.value == OrksDatasheet::kommandos.value:
        if extra == 0:
            return "Burna"s
        if extra == 1:
            return "Rokkit launcha"s
        if extra == 2:
            return "Breacha ram"s
        return "Kustom shoota"s
    if sheet.value == OrksDatasheet::battlewagon.value or sheet.value == OrksDatasheet::gunwagon.value:
        if extra == 0:
            return "Wreckin ball"s
        if extra == 1:
            return "Grabbin klaw"s
        return "Lobba"s
    if sheet.value == OrksDatasheet::big_mek.value:
        if extra == 0:
            return "Drilla"s
        return "Traktor blasta"s
    if sheet.value == OrksDatasheet::wazbom_blastajet.value:
        if extra == 0:
            return "Tellyport mega-blastas"s
        if extra == 1:
            return "Kustom force field"s
        return "Dual supa-shoota"s
    if sheet.value == OrksDatasheet::beastboss_on_squigosaur.value:
        return "Thump Gun"s
    if sheet.value == OrksDatasheet::burna_bommer.value:
        return "Skorcha missile rack"s
    if sheet.value == OrksDatasheet::dakkajet.value:
        return "Third Dual Supa-shoota"s
    if sheet.value == OrksDatasheet::trukk.value:
        return "Rokkit launcha"s
    if sheet.value == OrksDatasheet::warboss.value or sheet.value == OrksDatasheet::stormboyz.value:
        return "Power klaw"s
    if sheet.value == OrksDatasheet::breaka_boyz.value:
        return "Second rokkit pistol"s
    if sheet.value == OrksDatasheet::tankbustas.value:
        return "Smash hammer"s
    if sheet.value == OrksDatasheet::deffkoptas.value:
        return "Kustom mega-blasta"s
    return "Rivet kannon"s

# Translate legal choice values through existing source enums. Composition and
# counts remain plain numbers; paired loadouts retain their named alternatives.
fun orks_muster_value_label(OrksMusterDraft draft, Int member_index, OrksMusterField field, Int value) -> String:
    if field.value == OrksMusterField::models.value or field.value == OrksMusterField::nobs.value:
        return to_string(value)
    if field.value >= OrksMusterField::extra_one.value:
        if value == 0:
            return "Not selected"s
        return "Selected"s
    let sheet = draft.sheet
    if sheet.value == OrksDatasheet::boyz.value:
        if member_index >= draft.nobs.value:
            let boy_gun = orks_boy_gun_choice(value)
            return to_string(boy_gun.label())
        if field.value == OrksMusterField::primary.value:
            let nob_melee = orks_nob_melee_choice(value)
            return to_string(nob_melee.label())
        let nob_gun = orks_nob_gun_choice(value)
        return to_string(nob_gun.label())
    if sheet.value == OrksDatasheet::nobz.value:
        let nob_loadout = orks_nob_loadout_choice(value)
        return to_string(nob_loadout.label())
    if sheet.value == OrksDatasheet::meganobz.value:
        let mega_loadout = orks_meganob_loadout_choice(value)
        return weapon_pair_label(mega_loadout)
    if sheet.value == OrksDatasheet::kommandos.value:
        let kommando_melee = orks_nob_melee_choice(value)
        return to_string(kommando_melee.label())
    if sheet.value == OrksDatasheet::mek_gunz.value:
        let mek_gun = orks_mek_gun_choice(value)
        return to_string(mek_gun.label())
    if sheet.value == OrksDatasheet::deff_dread.value:
        let dread_arm = orks_dread_arm_choice(value)
        return to_string(dread_arm.label())
    if sheet.value == OrksDatasheet::warboss.value:
        let boss_gun = orks_nob_gun_choice(value)
        return to_string(boss_gun.label())
    if sheet.value == OrksDatasheet::big_mek_in_mega_armour.value:
        if field.value == OrksMusterField::primary.value:
            let mega_gun = orks_mega_mek_gun_choice(value)
            return to_string(mega_gun.label())
        let mega_extra = orks_mega_mek_extra_choice(value)
        return to_string(mega_extra.label())
    if sheet.value == OrksDatasheet::trukk.value:
        let trukk_extra = orks_trukk_extra_choice(value)
        return to_string(trukk_extra.label())
    if sheet.value == OrksDatasheet::gunwagon.value and field.value == OrksMusterField::secondary.value:
        let wagon_gun = orks_gunwagon_gun_choice(value)
        return to_string(wagon_gun.label())
    if sheet.value == OrksDatasheet::tankbustas.value and field.value == OrksMusterField::primary.value:
        return "Boy "s + to_string(value + 1)
    if sheet.value == OrksDatasheet::tankbustas.value and field.value == OrksMusterField::secondary.value:
        let tank_extra = orks_tankbusta_extra_choice(value)
        return to_string(tank_extra.label())
    if sheet.value == OrksDatasheet::breaka_boyz.value:
        if value == 1:
            return "Knucklebustas"s
        if value == 2:
            return "Tankhammer"s
        return "Smash hammer"s
    return to_string(value)

# Point-free current starter roster replaces the old public Morgrim data:
# one Beastboss, four Squighogs and two ten-model Snagga units, each with its
# permitted extra Thump Gun. This is a starter configuration, not all54 cards.
# Sources: the three Orks card URLs above; prices are excluded by the user.
fun make_orks_starter_roster(UnitVector out, Bool owner) -> Faction:
    assert(out.size() + 4 <= MAX_UNIT_COUNT, "starter roster capacity exceeded")
    out.append(make_orks_beastboss())
    out.back().owned_by_player1 = owner
    out.append(make_orks_squighog_boyz(1, 3))
    out.back().owned_by_player1 = owner
    for mob_index in range(2):
        out.append(make_orks_beast_snagga_boyz(1, 9, 1))
        out.back().owned_by_player1 = owner
    # Keep the stable six-roster identifier/action API; its current Orks
    # content is now explicit, rather than inferred from the old name.
    return Faction::morgrim_butchas

# User-supplied Warlord definition: choose a CHARACTER unit carrying the army
# faction keyword, then an eligible CHARACTER model. These Orks selectors
# address the pre-formation reserve roster, not battlefield slots.
# Cannot-be-Warlord overrides required status (user definition). A model-level
# requirement such as Ghazghkull's cannot be satisfied by a different Character.
# Required-unit and required-model clauses are distinct. Only otherwise legal
# required choices participate; prohibitions retain precedence (user wording).
# Gather required eligible choices across the player's actual roster, rather
# than always selecting the first boss (user Warlord definition).
# Finite selectors safely reject spare indices and foreign units before access
# (editor protocol; user Warlord definition).
# A selected unit must contain a selectable model, so the second input cannot
# deadlock after an otherwise legal unit choice (user Warlord definition).
# Army construction remains data-driven: a legacy roster without current ORKS
# metadata is not certified here. Actual roster adapters must supply eligible
# Characters/requirements before claiming full current army construction.
# Both selectors retain established UnitID/ModelID shapes; explicit Godot
# buttons use reserves and this saved context. Restore caller roles afterward.
# One source-backed Battleline predicate serves both draft acceptance and the
# committed roster: Runt Swarm/Gretchin, Kult/Warbikers, Brigade/Stormboyz.
fun orks_force_battleline(Board board, Unit unit) -> Bool:
    return (orks_package(board, unit, OrksDetachment::runt_swarm) and orks_type(unit, OrksDatasheet::gretchin)) or (orks_package(board, unit, OrksDetachment::kult_of_speed) and orks_type(unit, OrksDatasheet::warbikers)) or (orks_package(board, unit, OrksDetachment::taktikal_brigade) and orks_type(unit, OrksDatasheet::stormboyz))

# User-supplied copy limits apply to effective Battleline membership at muster.
# Reuse this for draft choices and the final pre-attachment roster validation.
# Force dispositions change Battleline membership at muster without changing
# unit prices or adding new datasheets (Sneaky Little Gitz/Adrenaline Junkies/
# Suspiciously Well Organised). Replacement units retain the original trait.
fun register_orks_force_dispositions(Board board):
    let bank : SourceBank
    for bank_index in range(3):
        bank.value = bank_index
        for unit_index in range(source_bank_size(board, bank)):
            ref unit = source_bank_unit(board, bank, unit_index)
            if orks_force_battleline(board, unit):
                for bearer in range(unit.models.size()):
                    if !unit[bearer].has_keyword(Keyword::battleline):
                        unit[bearer].keywords.append(Keyword::battleline)

# User roster limits: three copies, six for Battleline, applied before
# attachments merge units. Detachment force dispositions precede this check.
# Named datasheet identity is explicit; unknown legacy fixtures are not guessed.
# Convert an already validated battlefield slot to the existing finite action
# selector; persistent references still use EntityIdentity (infrastructure).
# Configure at most three distinct Orks packages; no DP accounting is performed
# by user instruction (source: https://wahapedia.ru/wh40k11ed/factions/orks/).
# Package effects require their own ROADMAP batches; Get Stuck In is17.I1.
act select_orks_detachments(ctx Board board, frm Bool detachment_player) -> SelectOrksDetachments:
    if board.armies[int(detachment_player)].faction != ArmyFaction::orks:
        return
    board.current_decision_maker = detachment_player
    frm detachment_finished = false
    while !detachment_finished and board.armies[int(detachment_player)].detachments.has_capacity():
        actions:
            act finish_detachment_selection()
                detachment_finished = true
            act choose_orks_detachment(OrksDetachment detachment) {board.armies[int(detachment_player)].detachment_selection_valid(detachment)}
                let recorded = board.armies[int(detachment_player)].record_detachment(detachment)
                assert(recorded, "legal detachment selection must be recorded")

# UI infrastructure reads the one active draft frame; no second Board/Unit
# copy or alternative roster validator is installed in the host.
fun orks_active_muster_field_label(Board board, OrksMusterField field) -> String:
    ref entry = board.shared_actions.pick_army.roster.entry
    return orks_muster_field_label(entry.draft, entry.member_index.get(), field)

# Label a numeric input with its real source weapon/equipment choice.
fun orks_active_muster_value_label(Board board, Int value) -> String:
    ref entry = board.shared_actions.pick_army.roster.entry
    return orks_muster_value_label(entry.draft, entry.member_index.get(), entry.field, value)

# Orks supplies its army keyword and activation gate; core owns the universal
# Warlord selection algorithm (user Select Army definition).
fun select_orks_warlord(Board board, Bool player) -> SelectWarlord:
    return select_warlord(board, player, Keyword::orks, board.armies[int(player)].faction == ArmyFaction::orks)

# Orks draft completion requires an actual current-roster Warlord candidate.
fun has_orks_warlord_choice(Board board, Bool player) -> Bool:
    return has_warlord_choice(board, player, Keyword::orks)

# Drafts have not yet received committed force dispositions; supply the
# actual Orks override to the shared copy-limit calculation.
fun orks_muster_copy_limit(Board board, Unit unit) -> Int:
    return muster_copy_limit(unit, orks_force_battleline(board, unit))
