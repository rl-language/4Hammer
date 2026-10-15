import attachment_rules

# All54 included current Orks datasheets. Catalog enum IDs stay in the shared
# profile/weapon catalogs; printed loadouts and permissions are owned here.

# Six is the largest included Orks permission list (Big Mek). These source-
# linked identities do not install profiles/equipment or permit excluded units.
fun orks_bodyguard_permission(BodyguardPermissions permissions, OrksDatasheet tag):
    let code : DatasheetCode
    code = tag.value
    permissions.append(code)

# Supplies core p66/19.01 eligibility from the17 included card permission
# lists, whose exact URLs are in doc/factions/orks/orks-unit-requirements.tsv.
# https://wahapedia.ru/wh40k11ed/factions/orks/ (Leader/Support on each card).
fun configure_orks_attachment(Unit unit, OrksDatasheet tag):
    assert(tag.value >= 0 and tag.value < MAX_DATASHEETCODE, "invalid Orks attachment datasheet")
    unit.roster_datasheet = tag.value
    unit.permitted_bodyguards.clear()
    unit.attachment_role = AttachmentRole::bodyguard
    if tag.value == OrksDatasheet::beastboss.value:
        unit.attachment_role = AttachmentRole::leader
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::beast_snagga_boyz)
    if tag.value == OrksDatasheet::big_mek.value:
        unit.attachment_role = AttachmentRole::leader
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::breaka_boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::flash_gitz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::mek_gunz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::nobz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::tankbustas)
    if tag.value == OrksDatasheet::big_mek_in_mega_armour.value:
        unit.attachment_role = AttachmentRole::leader
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::meganobz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::mek_gunz)
    if tag.value == OrksDatasheet::big_mek_with_shokk_attack_gun.value:
        unit.attachment_role = AttachmentRole::leader
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::mek_gunz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::nobz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::tankbustas)
    if tag.value == OrksDatasheet::boss_snikrot.value:
        unit.attachment_role = AttachmentRole::leader
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::kommandos)
    if tag.value == OrksDatasheet::deffkilla_wartrike.value:
        unit.attachment_role = AttachmentRole::leader
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::warbikers)
    if tag.value == OrksDatasheet::nazdreg.value or tag.value == OrksDatasheet::warboss_in_mega_armour.value:
        unit.attachment_role = AttachmentRole::leader
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::meganobz)
    if tag.value == OrksDatasheet::warboss.value:
        unit.attachment_role = AttachmentRole::leader
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::breaka_boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::nobz)
    if tag.value == OrksDatasheet::zodgrod_wortsnagga.value:
        unit.attachment_role = AttachmentRole::leader
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::gretchin)
    if tag.value == OrksDatasheet::bannernob.value:
        unit.attachment_role = AttachmentRole::support
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::nobz)
    if tag.value == OrksDatasheet::bigboss.value:
        unit.attachment_role = AttachmentRole::support
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::breaka_boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::nobz)
    if tag.value == OrksDatasheet::mek.value:
        unit.attachment_role = AttachmentRole::support
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::flash_gitz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::mek_gunz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::nobz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::tankbustas)
    if tag.value == OrksDatasheet::painboss.value:
        unit.attachment_role = AttachmentRole::support
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::beast_snagga_boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::squighog_boyz)
    if tag.value == OrksDatasheet::painboy.value:
        unit.attachment_role = AttachmentRole::support
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::breaka_boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::flash_gitz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::nobz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::tankbustas)
    if tag.value == OrksDatasheet::runtherd.value:
        unit.attachment_role = AttachmentRole::support
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::gretchin)
    if tag.value == OrksDatasheet::weirdboy.value:
        unit.attachment_role = AttachmentRole::support
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::beast_snagga_boyz)
        orks_bodyguard_permission(unit.permitted_bodyguards, OrksDatasheet::boyz)

# Finalize every completed Orks composition through one path: attachment
# permissions are source-card data and starting strength is frozen after all
# models/equipment exist (core pp66/86; each card's Unit Composition).
fun finalize_orks_unit(Unit unit, OrksDatasheet tag):
    configure_orks_attachment(unit, tag)
    unit.capture_starting_strength()

# Hunter eligibility is metadata on the equipped slot, not another weapon
# instance (core p16; supplied appendix04.01.03 Multiple Weapon Profiles).
fun equip_orks_profile(Model model, Weapon weapon, NamedWeaponProfile name, Int group, WeaponRule hunter_condition):
    let slot = model.weapons.size()
    equip_orks_profile(model, weapon, name, group)
    model.hunter_profile_conditions[slot] = hunter_condition

enum OrksBoyGunChoice:
    shoota
    big_shoota
    rokkit_launcha
    burna

cls OrksBoyzLoadout:
    Bool nob
    OrksNobMeleeChoice melee
    OrksNobGunChoice nob_gun
    OrksBoyGunChoice boy_gun

using OrksBoyzLoadouts = CheckedVector<OrksBoyzLoadout, MAX_UNIT_MODELS>

enum OrksDreadArmChoice:
    big_shoota
    skorcha
    extra_klaw
    kustom_mega_blasta
    rokkit_launcha

enum OrksGunwagonGun:
    kannon
    killkannon
    zzap_gun

# Hull sizes are explicit millimetre circle proxies, never inferred dimensions.
# User authorizes circular treatment of all noncircles; core p12 measurements.
using OrksHullDiameter = LinearlyDistributedInt<0, 1001>

cls OrksKommandoEquipment:
    OrksNobMeleeChoice nob_melee
    Bool burna
    Bool rokkit
    Bool breacha_ram
    Bool kustom_shoota

using OrksKommandoLoadout = CheckedVector<OrksKommandoEquipment, 10>

enum OrksMegaMekExtra:
    none
    tellyport_blasta
    force_field

# Big Mek in Mega Armour's independent replacement and optional extra slots.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
enum OrksMegaMekGun:
    kustom_shoota
    killsaw
    kombi_weapon
    mega_blasta

# Independent replacements versus the combined Twin Killsaws replacement.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
enum OrksMeganobLoadout:
    shoota_klaw
    shoota_saw
    kombi_klaw
    kombi_saw
    twin_saws

using OrksMeganobLoadouts = CheckedVector<OrksMeganobLoadout, 6>

enum OrksMekGun:
    smasha_gun
    bubblechukka
    kustom_mega_kannon
    traktor_kannon

using OrksMekGuns = CheckedVector<OrksMekGun, 3>

enum OrksNobGunChoice:
    kombi_skorcha
    kombi_rokkit
    kustom_shoota
    none

enum OrksNobLoadout:
    standard
    kombi_rokkit
    paired_krumpas
    big_skorcha
    kustom_big_shoota
    big_choppa

using OrksNobLoadouts = CheckedVector<OrksNobLoadout, MAX_UNIT_MODELS>

# Finite per-model muster choices encode the printed replacements, not prices.
# Sources: Orks/Boyz, Nobz, Warboss and Deff-Dread (11th-edition version1.2).
enum OrksNobMeleeChoice:
    kustom_choppa
    power_klaw
    big_choppa

# The one optional Boy gets another physical launcher OR the Pulsa token.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
enum OrksTankbustaExtra:
    none
    additional_launcher
    pulsa

enum OrksTrukkExtra:
    none
    buzzsaw
    grabbin_klaw

using OrksVehicleSwaps = CheckedVector<Bool, 6>

# One owned slot per printed profile, with a stable physical family/name.
# Multi-profile groups share one weapon (core p16; appendix04.01.03).
fun equip_orks_profile(Model model, Weapon weapon, NamedWeaponProfile name, Int group):
    assert(group >= 0 and group < MAX_WEAPON_SCOPES, "invalid physical weapon group")
    let slot = model.weapons.size()
    model.weapons.append(weapon)
    set_named_weapon_profile(model, slot, name)
    model.weapon_profile_groups[slot] = group

# Source adapters set real faction/datasheet/Army Rules metadata. They do not
# grant old Beast Snagga/FNP abilities or infer keywords from a factory name.
# https://wahapedia.ru/wh40k11ed/factions/orks/ (Waaagh!).
fun make_orks_model(Profile profile, OrksDatasheet tag) -> Model:
    let model : Model
    model.profile = profile
    set_model_datasheet(model, tag)
    model.has_waaagh = true
    model.keywords.append(Keyword::orks)
    return model

# Independent arm replacements preserve physical identity, including two
# distinct Extra Klaws. Neither swap removes the obligatory Dread Klaws.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
fun equip_orks_dread_arm(Model model, OrksDreadArmChoice choice, Int group):
    if choice.value == OrksDreadArmChoice::big_shoota.value:
        equip_orks_profile(model, Weapon::orks_dread_big_shoota, NamedWeaponProfile::big_shoota, group)
    if choice.value == OrksDreadArmChoice::skorcha.value:
        equip_orks_profile(model, Weapon::orks_skorcha, NamedWeaponProfile::skorcha, group)
    if choice.value == OrksDreadArmChoice::extra_klaw.value:
        equip_orks_profile(model, Weapon::orks_extra_klaw, NamedWeaponProfile::extra_klaw, group)
    if choice.value == OrksDreadArmChoice::kustom_mega_blasta.value:
        equip_orks_profile(model, Weapon::orks_kustom_mega_blasta, NamedWeaponProfile::kustom_mega_blasta, group)
    if choice.value == OrksDreadArmChoice::rokkit_launcha.value:
        equip_orks_profile(model, Weapon::orks_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, group)
        equip_orks_profile(model, Weapon::orks_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, group)

# Combi profiles share a physical group and require one selected profile.
# Boyz/Warboss printed equipment; appendix04.01.03/core p16.
fun equip_orks_nob_gun(Model model, OrksNobGunChoice choice):
    assert(choice.value >= 0 and choice.value <= 3, "invalid Nob gun choice")
    if choice.value == OrksNobGunChoice::kombi_skorcha.value:
        equip_orks_profile(model, Weapon::orks_kombi_skorcha_shoota, NamedWeaponProfile::kombi_skorcha_shoota, 1)
        equip_orks_profile(model, Weapon::orks_kombi_skorcha_skorcha, NamedWeaponProfile::kombi_skorcha_skorcha, 1)
    if choice.value == OrksNobGunChoice::kombi_rokkit.value:
        equip_orks_profile(model, Weapon::orks_kombi_rokkit_busta, NamedWeaponProfile::kombi_rokkit_busta_rokkit, 1)
        equip_orks_profile(model, Weapon::orks_kombi_rokkit_shoota, NamedWeaponProfile::kombi_rokkit_shoota, 1)
    if choice.value == OrksNobGunChoice::kustom_shoota.value:
        equip_orks_profile(model, Weapon::orks_kustom_shoota, NamedWeaponProfile::kustom_shoota, 0)

# Waaagh! Banner confers+1 charge through current unit source membership.
# The separate raw HTML box supplies its5+ InSv, omitted by text extraction.
# https://wahapedia.ru/wh40k11ed/factions/orks/Bannernob
fun make_orks_bannernob() -> Unit:
    let unit : Unit
    unit.name = "Bannernob"s
    let model = make_orks_model(Profile::orks_bannernob, OrksDatasheet::bannernob)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.abilities.append(AbilityKind::waaagh_banner)
    equip_orks_profile(model, Weapon::orks_shoota, NamedWeaponProfile::shoota, 0)
    equip_orks_profile(model, Weapon::orks_kustom_choppa, NamedWeaponProfile::kustom_choppa, 0)
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::bannernob)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon: equipment/composition.
fun make_orks_battlewagon(Int hull_mm, Int big_shootas, Bool ball, Bool klaw) -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_battlewagon, OrksDatasheet::battlewagon)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::frame)
    model.keywords.append(Keyword::transport)
    model.keywords.append(Keyword::wagon)
    model.abilities.append(AbilityKind::mobile_fortress)
    model.has_damaged = true
    model.damaged_threshold = 6
    model.has_deadly_demise = true
    model.deadly_demise = compound_stat(1, 6, 0)
    model.firing_deck = 11
    assert(hull_mm >= 0 and hull_mm <= 1000, "invalid circular hull proxy diameter")
    model.geometry.proxy_diameter_mm = hull_mm
    # Intentional imprecision, user-authorized temporary large circle.
    if hull_mm == 0:
        model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(OrksDatasheet::battlewagon)
    model.transport_permissions_known = true
    model.transport_capacity = 22
    model.permitted_passenger_keywords.append(Keyword::infantry)
    model.orks_transport_permissions = true
    assert(big_shootas >= 0 and big_shootas <= 4, "invalid extra Big Shootas")
    assert((big_shootas) >= 0 and (big_shootas) <= 5, "invalid physical weapon count")
    for weapon_copy_1 in range(big_shootas):
        let weapon_group_1 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_battlewagon_big_shoota, NamedWeaponProfile::big_shoota, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_battlewagon_crushin_bulk, NamedWeaponProfile::crushin_bulk, weapon_group_2)
    if ball:
        let weapon_group_3 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_battlewagon_wreckin_ball, NamedWeaponProfile::wreckin_ball, weapon_group_3)
    if klaw:
        let weapon_group_4 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_battlewagon_grabbin_klaw, NamedWeaponProfile::grabbin_klaw, weapon_group_4)
    let unit : Unit
    unit.name = "Battlewagon"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::battlewagon)
    return unit

# Construct every printed count/optional-loadout choice, retaining the Boy's
# Choppa and Slugga when adding a Thump Gun; Mobbed follows actual charge completion.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz
fun make_orks_beast_snagga_boyz(Int nobs, Int boys, Int thump_guns) -> Unit:
    assert(orks_snagga_composition_valid(nobs, boys, thump_guns), "illegal Beast Snagga composition/loadout")
    let unit : Unit
    unit.name = "Beast Snagga Boyz"s
    for nob_index in range(nobs):
        unit.models.append(orks_snagga_model(true, false))
    for boy_index in range(boys):
        unit.models.append(orks_snagga_model(false, boy_index < thump_guns))
    finalize_orks_unit(unit, OrksDatasheet::beast_snagga_boyz)
    return unit

# Current Beastboss grants Dodge Dis!/Keep Huntin' explicitly; source instances
# register after Board assigns identities, before actual movement.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss
fun make_orks_beastboss() -> Unit:
    let unit : Unit
    unit.name = "Beastboss"s
    let model = make_orks_model(Profile::orks_beastboss, OrksDatasheet::beastboss)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::beast_snagga)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::warboss)
    model.has_da_boss = true
    model.abilities.append(AbilityKind::dodge_dis)
    model.abilities.append(AbilityKind::keep_huntin)
    equip_orks_profile(model, Weapon::orks_beastboss_shoota, NamedWeaponProfile::shoota, 0)
    equip_orks_profile(model, Weapon::orks_beastboss_klaw_and_beastchoppa, NamedWeaponProfile::beast_snagga_klaw_and_beastchoppa, 0)
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::beastboss)
    return unit

# Standard/Hunter share one Beastchoppa; Hunter permits MONSTER/VEHICLE only.
# Keep Huntin' reuses110; Stampede and conditional Lone Operative stay live.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur
fun make_orks_beastboss_on_squigosaur(Bool thump_gun) -> Unit:
    let unit : Unit
    unit.name = "Beastboss on Squigosaur"s
    let model = make_orks_model(Profile::orks_beastboss_on_squigosaur, OrksDatasheet::beastboss_on_squigosaur)
    model.keywords.append(Keyword::monster)
    model.keywords.append(Keyword::beast_snagga)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::warboss)
    model.has_da_boss = true
    model.abilities.append(AbilityKind::keep_huntin)
    model.abilities.append(AbilityKind::thundering_stampede)
    model.abilities.append(AbilityKind::boss_of_da_hunt)
    equip_orks_profile(model, Weapon::orks_slugga, NamedWeaponProfile::slugga, 0)
    equip_orks_profile(model, Weapon::orks_beastchoppa_standard, NamedWeaponProfile::beastchoppa_standard, 1)
    equip_orks_profile(model, Weapon::orks_beastchoppa_hunter, NamedWeaponProfile::beastchoppa_hunter, 1)
    model.hunter_profile_conditions[2] = orks_monster_vehicle_rule(WeaponRuleKind::anti, 0)
    equip_orks_profile(model, Weapon::orks_squigosaur_jaws, NamedWeaponProfile::squigosaur_s_jaws, 0)
    if thump_gun:
        equip_orks_profile(model, Weapon::orks_thump_gun, NamedWeaponProfile::thump_gun, 0)
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::beastboss_on_squigosaur)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka: equipment/composition.
fun make_orks_big_ed_bossbunka(Int hull_mm, Int big_shootas) -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_big_ed_bossbunka, OrksDatasheet::big_ed_bossbunka)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::fortification)
    model.keywords.append(Keyword::frame)
    model.keywords.append(Keyword::transport)
    model.abilities.append(AbilityKind::raucous_occupants)
    model.abilities.append(AbilityKind::fortification_rules)
    model.abilities.append(AbilityKind::ramshackle_cover)
    model.has_deadly_demise = true
    model.deadly_demise = dice_stat(3)
    model.firing_deck = 11
    assert(hull_mm >= 0 and hull_mm <= 1000, "invalid circular hull proxy diameter")
    model.geometry.proxy_diameter_mm = hull_mm
    # Intentional imprecision, user-authorized temporary large circle.
    if hull_mm == 0:
        model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(OrksDatasheet::big_ed_bossbunka)
    model.transport_permissions_known = true
    model.transport_capacity = 11
    model.permitted_passenger_keywords.append(Keyword::infantry)
    model.orks_transport_permissions = true
    model.forbid_ghaz_passenger = true
    assert(big_shootas >= 0 and big_shootas <= 3, "invalid extra Big Shootas")
    assert((big_shootas + 1) >= 0 and (big_shootas + 1) <= 5, "invalid physical weapon count")
    for weapon_copy_1 in range(big_shootas + 1):
        let weapon_group_1 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_big_ed_bossbunka_big_shoota, NamedWeaponProfile::big_shoota, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_big_ed_bossbunka_gaze_of_gork_glare, NamedWeaponProfile::gaze_of_gork_glare, weapon_group_2)
    equip_orks_profile(model, Weapon::orks_big_ed_bossbunka_gaze_of_gork_squint, NamedWeaponProfile::gaze_of_gork_squint, weapon_group_2)
    let unit : Unit
    unit.name = "Big ed Bossbunka"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::big_ed_bossbunka)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
fun make_orks_big_mek(Bool drilla, Bool traktor) -> Unit:
    let model = make_orks_model(Profile::orks_big_mek, OrksDatasheet::big_mek)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::explosives)
    model.abilities.append(AbilityKind::more_dakka)
    model.abilities.append(AbilityKind::shokk_boosta)
    if drilla:
        equip_orks_profile(model, Weapon::orks_big_mek_drilla, NamedWeaponProfile::drilla, 0)
    else:
        equip_orks_profile(model, Weapon::orks_big_mek_power_klaw, NamedWeaponProfile::power_klaw, 0)
    if traktor:
        equip_orks_profile(model, Weapon::orks_big_mek_traktor_blasta, NamedWeaponProfile::traktor_blasta, 0)
    else:
        equip_orks_profile(model, Weapon::orks_big_mek_kustom_mega_blasta, NamedWeaponProfile::kustom_mega_blasta, 0)
    let unit : Unit
    unit.name = "Big Mek"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::big_mek)
    return unit

# Dakkarig has no Leader/Da Boss; its riled ranged rule and target-specific
# Blitzkannon A are evaluated at actual declaration/gathering windows.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-Dakkarig
fun make_orks_big_mek_dakkarig() -> Unit:
    let unit : Unit
    unit.name = "Big Mek Dakkarig"s
    let model = make_orks_model(Profile::orks_big_mek_dakkarig, OrksDatasheet::big_mek_dakkarig)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::big_mek)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::walker)
    model.has_deadly_demise = true
    model.deadly_demise = raw_stat(1)
    model.abilities.append(AbilityKind::even_more_dakka)
    model.abilities.append(AbilityKind::blitz_dem_gitz)
    equip_orks_profile(model, Weapon::orks_blitzkannon, NamedWeaponProfile::blitzkannon, 0)
    equip_orks_profile(model, Weapon::orks_multi_busta_launcha, NamedWeaponProfile::multi_busta_launcha, 0)
    equip_orks_profile(model, Weapon::orks_stompy_feet, NamedWeaponProfile::stompy_feet, 0)
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::big_mek_dakkarig)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
fun make_orks_big_mek_in_mega_armour(OrksMegaMekGun gun, OrksMegaMekExtra extra) -> Unit:
    let model = make_orks_model(Profile::orks_big_mek_in_mega_armour, OrksDatasheet::big_mek_in_mega_armour)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::big_mek)
    model.keywords.append(Keyword::explosives)
    model.keywords.append(Keyword::mega_armour)
    model.transport_space = 2
    model.abilities.append(AbilityKind::more_dakka)
    model.abilities.append(AbilityKind::fix_dat_armour_up)
    assert(gun.value >= 0 and gun.value <= 3 and extra.value >= 0 and extra.value <= 2, "invalid Mega Mek equipment")
    equip_orks_profile(model, Weapon::orks_big_mek_in_mega_armour_power_klaw, NamedWeaponProfile::power_klaw, 0)
    if gun.value == OrksMegaMekGun::kustom_shoota.value:
        equip_orks_profile(model, Weapon::orks_big_mek_in_mega_armour_kustom_shoota_aimed, NamedWeaponProfile::kustom_shoota_aimed, 1)
        equip_orks_profile(model, Weapon::orks_big_mek_in_mega_armour_kustom_shoota_point_blank, NamedWeaponProfile::kustom_shoota_point_blank, 1)
    if gun.value == OrksMegaMekGun::kombi_weapon.value:
        equip_orks_profile(model, Weapon::orks_big_mek_in_mega_armour_kombi_weapon_shoota, NamedWeaponProfile::kombi_weapon_shoota, 1)
        equip_orks_profile(model, Weapon::orks_big_mek_in_mega_armour_kombi_weapon_kill_shot, NamedWeaponProfile::kombi_weapon_kill_shot, 1)
        equip_orks_profile(model, Weapon::orks_big_mek_in_mega_armour_kombi_weapon_point_blank, NamedWeaponProfile::kombi_weapon_point_blank, 1)
    if gun.value == OrksMegaMekGun::killsaw.value:
        equip_orks_profile(model, Weapon::orks_big_mek_in_mega_armour_killsaw, NamedWeaponProfile::killsaw, 0)
    if gun.value == OrksMegaMekGun::mega_blasta.value:
        equip_orks_profile(model, Weapon::orks_big_mek_in_mega_armour_kustom_mega_blasta, NamedWeaponProfile::kustom_mega_blasta, 0)
    if extra.value == OrksMegaMekExtra::tellyport_blasta.value:
        equip_orks_profile(model, Weapon::orks_big_mek_in_mega_armour_tellyport_blasta, NamedWeaponProfile::tellyport_blasta, 0)
    if extra.value == OrksMegaMekExtra::force_field.value:
        model.abilities.append(AbilityKind::kustom_force_field)
    let unit : Unit
    unit.name = "Big Mek In Mega Armour"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::big_mek_in_mega_armour)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun
fun make_orks_big_mek_with_shokk_attack_gun() -> Unit:
    let model = make_orks_model(Profile::orks_big_mek_with_shokk_attack_gun, OrksDatasheet::big_mek_with_shokk_attack_gun)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::big_mek)
    model.keywords.append(Keyword::explosives)
    model.abilities.append(AbilityKind::more_dakka)
    model.abilities.append(AbilityKind::support_shokka)
    equip_orks_profile(model, Weapon::orks_big_mek_with_shokk_attack_gun_shokk_attack_gun, NamedWeaponProfile::shokk_attack_gun, 0)
    equip_orks_profile(model, Weapon::orks_big_mek_with_shokk_attack_gun_big_mek_s_toolz, NamedWeaponProfile::big_mek_s_toolz, 0)
    let unit : Unit
    unit.name = "Big Mek With Shokk Attack Gun"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::big_mek_with_shokk_attack_gun)
    return unit

# Support model uses its Precision Big Choppa and unit-wide melee hit rule.
# https://wahapedia.ru/wh40k11ed/factions/orks/Bigboss
fun make_orks_bigboss() -> Unit:
    let unit : Unit
    unit.name = "Bigboss"s
    let model = make_orks_model(Profile::orks_bigboss, OrksDatasheet::bigboss)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.abilities.append(AbilityKind::sumfin_to_prove)
    equip_orks_profile(model, Weapon::orks_slugga, NamedWeaponProfile::slugga, 0)
    equip_orks_profile(model, Weapon::orks_bigboss_big_choppa, NamedWeaponProfile::big_choppa, 0)
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::bigboss)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer: equipment/composition.
fun make_orks_blitza_bommer() -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_blitza_bommer, OrksDatasheet::blitza_bommer)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::aircraft)
    model.keywords.append(Keyword::fly)
    model.keywords.append(Keyword::speed_freeks)
    model.abilities.append(AbilityKind::boom_bomb)
    model.has_damaged = true
    model.damaged_threshold = 4
    model.has_deadly_demise = true
    model.deadly_demise = dice_stat(3)

    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_blitza_bommer_big_shoota, NamedWeaponProfile::big_shoota, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_blitza_bommer_dual_supa_shoota, NamedWeaponProfile::dual_supa_shoota, weapon_group_2)
    let weapon_group_3 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_blitza_bommer_armoured_impact, NamedWeaponProfile::armoured_impact, weapon_group_3)
    let unit : Unit
    unit.name = "Blitza bommer"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::blitza_bommer)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Boss-Snikrot: equipment/composition.
fun make_orks_boss_snikrot() -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_boss_snikrot, OrksDatasheet::boss_snikrot)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::epic_hero)
    model.keywords.append(Keyword::explosives)
    model.keywords.append(Keyword::smoke)
    model.abilities.append(AbilityKind::kunnin_infiltrator)
    model.abilities.append(AbilityKind::deff_from_shadows)
    model.abilities.append(AbilityKind::infiltrators)
    model.abilities.append(AbilityKind::lone_operative)
    model.abilities.append(AbilityKind::stealth)

    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_boss_snikrot_slugga, NamedWeaponProfile::slugga, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_boss_snikrot_mork_s_teef, NamedWeaponProfile::mork_s_teef, weapon_group_2)
    let unit : Unit
    unit.name = "Boss Snikrot"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::boss_snikrot)
    return unit

# Full per-model equipment permits mixed Nob choices and independent Boy
# quotas; counts follow the literal1–2/9–18 ranges, not priced10/20 tiers.
# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
fun make_orks_boyz(OrksBoyzLoadouts equipment) -> Unit:
    assert(orks_boyz_loadout_valid(equipment), "illegal Boyz composition/loadout")
    let unit : Unit
    unit.name = "Boyz"s
    for index in range(equipment.size()):
        unit.models.append(orks_boyz_model(equipment[index]))
    finalize_orks_unit(unit, OrksDatasheet::boyz)
    return unit

# Standard equipment convenience retains the complete per-model factory above.
# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
fun make_orks_boyz(Int nobs, Int boys) -> Unit:
    assert(nobs >= 1 and nobs <= 2 and boys >= 9 and boys <= 18, "illegal Boyz counts")
    let equipment : OrksBoyzLoadouts
    for index in range(nobs + boys):
        let item : OrksBoyzLoadout
        item.nob = index < nobs
        equipment.append(item)
    return make_orks_boyz(equipment)

# Nob plus exactly five Boys; a replacement removes both Hammer profiles.
# https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
fun make_orks_breaka_boyz(Bool nob_pistols, Int knuckles, Int tankhammer) -> Unit:
    assert(orks_breaka_loadout_valid(knuckles, tankhammer), "invalid Breaka replacements")
    let unit : Unit
    unit.name = "Breaka Boyz"s
    for index in range(6):
        let profile = Profile::orks_breaka_boy
        if index == 0:
            profile = Profile::orks_breaka_nob
        let model = make_orks_model(profile, OrksDatasheet::breaka_boyz)
        model.keywords.append(Keyword::infantry)
        model.keywords.append(Keyword::explosives)
        model.abilities.append(AbilityKind::bomb_squig)
        model.abilities.append(AbilityKind::trophy_hunters)
        if index == 0:
            equip_orks_profile(model, Weapon::orks_breaka_boyz_choppa, NamedWeaponProfile::choppa, 0)
            equip_orks_profile(model, Weapon::orks_breaka_boyz_rokkit_pistol, NamedWeaponProfile::rokkit_pistol, 0)
            if nob_pistols:
                equip_orks_profile(model, Weapon::orks_breaka_boyz_rokkit_pistol, NamedWeaponProfile::rokkit_pistol, 0)
        if index > 0 and knuckles == index - 1:
            equip_orks_profile(model, Weapon::orks_breaka_boyz_knucklebustas, NamedWeaponProfile::knucklebustas, 0)
        else:
            if index > 0 and tankhammer == index - 1:
                equip_orks_profile(model, Weapon::orks_breaka_boyz_tankhammer, NamedWeaponProfile::tankhammer, 0)
            else:
                if index > 0 or !nob_pistols:
                    equip_orks_profile(model, Weapon::orks_breaka_boyz_smash_hammer_standard, NamedWeaponProfile::smash_hammer_standard, 1)
                    equip_orks_profile(model, Weapon::orks_breaka_boyz_smash_hammer_hunter, NamedWeaponProfile::smash_hammer_hunter, 1, orks_monster_vehicle_rule(WeaponRuleKind::anti, 0))
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::breaka_boyz)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer: equipment/composition.
fun make_orks_burna_bommer(Bool missile_rack) -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_burna_bommer, OrksDatasheet::burna_bommer)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::aircraft)
    model.keywords.append(Keyword::fly)
    model.keywords.append(Keyword::speed_freeks)
    model.abilities.append(AbilityKind::burna_bomb)
    model.has_damaged = true
    model.damaged_threshold = 4
    model.has_deadly_demise = true
    model.deadly_demise = dice_stat(3)

    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_burna_bommer_dual_big_shoota, NamedWeaponProfile::dual_big_shoota, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_burna_bommer_dual_supa_shoota, NamedWeaponProfile::dual_supa_shoota, weapon_group_2)
    if missile_rack:
        let weapon_group_3 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_burna_bommer_skorcha_missile_rack, NamedWeaponProfile::skorcha_missile_rack, weapon_group_3)
    let weapon_group_4 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_burna_bommer_armoured_impact, NamedWeaponProfile::armoured_impact, weapon_group_4)
    let unit : Unit
    unit.name = "Burna bommer"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::burna_bommer)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Dakkajet: equipment/composition.
fun make_orks_dakkajet(Bool third_gun) -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_dakkajet, OrksDatasheet::dakkajet)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::aircraft)
    model.keywords.append(Keyword::fly)
    model.keywords.append(Keyword::speed_freeks)
    model.abilities.append(AbilityKind::strafing_run)
    model.has_damaged = true
    model.damaged_threshold = 4
    model.has_deadly_demise = true
    model.deadly_demise = dice_stat(3)

    assert((2 + int(third_gun)) >= 0 and (2 + int(third_gun)) <= 5, "invalid physical weapon count")
    for weapon_copy_1 in range(2 + int(third_gun)):
        let weapon_group_1 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_dakkajet_dual_supa_shoota, NamedWeaponProfile::dual_supa_shoota, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_dakkajet_armoured_impact, NamedWeaponProfile::armoured_impact, weapon_group_2)
    let unit : Unit
    unit.name = "Dakkajet"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::dakkajet)
    return unit

# The Big Shoota arm cannot take Skorcha; the Skorcha arm can take Big Shoota.
# Dread 'Ard enters incoming D arithmetic (both attack types); demise is fixed1.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
fun make_orks_deff_dread(OrksDreadArmChoice first, OrksDreadArmChoice second) -> Unit:
    assert(first.value >= 0 and first.value < 5 and first.value != OrksDreadArmChoice::skorcha.value and second.value >= 0 and second.value < 5, "illegal Deff Dread arms")
    let unit : Unit
    unit.name = "Deff Dread"s
    let model = make_orks_model(Profile::orks_deff_dread, OrksDatasheet::deff_dread)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::walker)
    model.has_deadly_demise = true
    model.deadly_demise = raw_stat(1)
    model.incoming_attack_modifiers.append(incoming_attack_modifier(ModifiedCharacteristic::damage, ModifierOperation::add, -1, IncomingAttackScope::any_attack))
    equip_orks_profile(model, Weapon::orks_dread_klaws, NamedWeaponProfile::dread_klaws, 0)
    equip_orks_dread_arm(model, first, 1)
    equip_orks_dread_arm(model, second, 2)
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::deff_dread)
    return unit

# Standard printed Dread: one Big Shoota, one Skorcha and Dread Klaws.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
fun make_orks_deff_dread() -> Unit:
    return make_orks_deff_dread(OrksDreadArmChoice::big_shoota, OrksDreadArmChoice::skorcha)

# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike: equipment/composition.
fun make_orks_deffkilla_wartrike() -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_deffkilla_wartrike, OrksDatasheet::deffkilla_wartrike)
    model.keywords.append(Keyword::mounted)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::speed_freeks)
    model.keywords.append(Keyword::warboss)
    model.abilities.append(AbilityKind::get_back_in_da_race)
    model.abilities.append(AbilityKind::fuel_mixa_grot)
    model.has_da_boss = true
    model.has_deadly_demise = true
    model.deadly_demise = raw_stat(1)

    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_deffkilla_wartrike_boomstikks, NamedWeaponProfile::boomstikks, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_deffkilla_wartrike_snagga_klaw_ranged, NamedWeaponProfile::snagga_klaw_ranged, weapon_group_2)
    equip_orks_profile(model, Weapon::orks_deffkilla_wartrike_snagga_klaw_melee, NamedWeaponProfile::snagga_klaw_melee, weapon_group_2)
    let weapon_group_3 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_deffkilla_wartrike_killa_jet_burna, NamedWeaponProfile::killa_jet_burna, weapon_group_3)
    equip_orks_profile(model, Weapon::orks_deffkilla_wartrike_killa_jet_cutta, NamedWeaponProfile::killa_jet_cutta, weapon_group_3)
    let unit : Unit
    unit.name = "Deffkilla Wartrike"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::deffkilla_wartrike)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas: individual replacement choices.
fun make_orks_deffkoptas(OrksVehicleSwaps swaps) -> Unit:
    assert(swaps.size() >= 3 and swaps.size() <= 6, "invalid composition")
    let count = 0
    for item in range(swaps.size()):
        count = count + int(swaps[item])
    assert(count <= swaps.size() / 3, "one Mega-blasta per three Koptas")
    let unit : Unit
    unit.name = "Deffkoptas"s
    for item_index in range(swaps.size()):
        # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
        let model = make_orks_model(Profile::orks_deffkoptas, OrksDatasheet::deffkoptas)
        model.keywords.append(Keyword::mounted)
        model.keywords.append(Keyword::explosives)
        model.keywords.append(Keyword::fly)
        model.keywords.append(Keyword::speed_freeks)
        model.keywords.append(Keyword::deffkoptas)
        model.abilities.append(AbilityKind::deff_from_above)
        model.abilities.append(AbilityKind::aerial_manoover)
        model.abilities.append(AbilityKind::deep_strike)

        if swaps[item_index]:
            let weapon_group_1 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_deffkoptas_kustom_mega_blasta, NamedWeaponProfile::kustom_mega_blasta, weapon_group_1)
        else:
            let weapon_group_2 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_deffkoptas_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, weapon_group_2)
            equip_orks_profile(model, Weapon::orks_deffkoptas_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, weapon_group_2)
        let weapon_group_3 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_deffkoptas_slugga, NamedWeaponProfile::slugga, weapon_group_3)
        let weapon_group_4 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_deffkoptas_choppa, NamedWeaponProfile::choppa, weapon_group_4)
        let weapon_group_5 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_deffkoptas_spinnin_blades, NamedWeaponProfile::spinnin_blades, weapon_group_5)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::deffkoptas)
    return unit

# The Kaptin is compulsory and has its own printed profile; all Snazzgun
# profiles belong to one physical gun per model (appendix04.01.03).
# https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
fun make_orks_flash_gitz(Int gitz) -> Unit:
    assert(gitz >= 4 and gitz <= 9, "Flash Gitz need one Kaptin and4-9 Gitz")
    let unit : Unit
    unit.name = "Flash Gitz"s
    for index in range(gitz + 1):
        let profile = Profile::orks_flash_git
        if index == 0:
            profile = Profile::orks_kaptin
        let model = make_orks_model(profile, OrksDatasheet::flash_gitz)
        model.keywords.append(Keyword::infantry)
        model.keywords.append(Keyword::explosives)
        model.abilities.append(AbilityKind::finderz_keeperz)
        equip_orks_profile(model, Weapon::orks_flash_gitz_snazzgun_cutta, NamedWeaponProfile::snazzgun_cutta, 1)
        equip_orks_profile(model, Weapon::orks_flash_gitz_snazzgun_dakka, NamedWeaponProfile::snazzgun_dakka, 1)
        equip_orks_profile(model, Weapon::orks_flash_gitz_snazzgun_kill_shot, NamedWeaponProfile::snazzgun_kill_shot, 1)
        equip_orks_profile(model, Weapon::orks_flash_gitz_choppa, NamedWeaponProfile::choppa, 0)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::flash_gitz)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka: equipment/composition.
fun make_orks_ghazghkull_thraka() -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_ghazghkull_thraka, OrksDatasheet::ghazghkull_thraka)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::epic_hero)
    model.keywords.append(Keyword::explosives)
    model.keywords.append(Keyword::warboss)
    model.abilities.append(AbilityKind::grand_warlords_ladz)
    model.abilities.append(AbilityKind::makari_banner)
    model.abilities.append(AbilityKind::prophet_waaagh)
    model.has_da_boss = true

    model.must_be_warlord = true
    model.transport_space = 4
    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_ghazghkull_thraka_mork_s_roar_aimed, NamedWeaponProfile::mork_s_roar_aimed, weapon_group_1)
    equip_orks_profile(model, Weapon::orks_ghazghkull_thraka_mork_s_roar_point_blank, NamedWeaponProfile::mork_s_roar_point_blank, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_ghazghkull_thraka_adamantine_eadbutt, NamedWeaponProfile::adamantine_eadbutt, weapon_group_2)
    let weapon_group_3 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_ghazghkull_thraka_gork_s_klaw, NamedWeaponProfile::gork_s_klaw, weapon_group_3)
    let unit : Unit
    unit.name = "Ghazghkull Thraka"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::ghazghkull_thraka)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut: equipment/composition.
fun make_orks_gorkanaut() -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_gorkanaut, OrksDatasheet::gorkanaut)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::titanic)
    model.keywords.append(Keyword::towering)
    model.keywords.append(Keyword::transport)
    model.keywords.append(Keyword::walker)
    model.abilities.append(AbilityKind::gut_hatch)
    model.abilities.append(AbilityKind::big_an_stompy)
    model.abilities.append(AbilityKind::super_heavy_walker)
    model.has_damaged = true
    model.damaged_threshold = 7
    model.has_deadly_demise = true
    model.deadly_demise = compound_stat(1, 6, 0)

    model.transport_permissions_known = true
    model.transport_capacity = 12
    model.permitted_passenger_keywords.append(Keyword::infantry)
    model.orks_transport_permissions = true
    model.forbid_ghaz_passenger = true
    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_gorkanaut_deffstorm_mega_shoota_aimed, NamedWeaponProfile::deffstorm_mega_shoota_aimed, weapon_group_1)
    equip_orks_profile(model, Weapon::orks_gorkanaut_deffstorm_mega_shoota_point_blank, NamedWeaponProfile::deffstorm_mega_shoota_point_blank, weapon_group_1)
    assert((2) >= 0 and (2) <= 5, "invalid physical weapon count")
    for weapon_copy_2 in range(2):
        let weapon_group_2 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_gorkanaut_dual_big_shoota, NamedWeaponProfile::dual_big_shoota, weapon_group_2)
    assert((2) >= 0 and (2) <= 5, "invalid physical weapon count")
    for weapon_copy_3 in range(2):
        let weapon_group_3 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_gorkanaut_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, weapon_group_3)
        equip_orks_profile(model, Weapon::orks_gorkanaut_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, weapon_group_3)
    let weapon_group_4 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_gorkanaut_skorcha, NamedWeaponProfile::skorcha, weapon_group_4)
    let weapon_group_5 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_gorkanaut_klaw_of_gork, NamedWeaponProfile::klaw_of_gork, weapon_group_5)
    let unit : Unit
    unit.name = "Gorkanaut"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::gorkanaut)
    return unit

# Exact10-20 range; models remain individuals, not crew or half-model tokens.
# Downtrodden's grouped seat rounding belongs in transport_rules, not W/OC.
# https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
fun make_orks_gretchin(Int count) -> Unit:
    assert(count >= 10 and count <= 20, "illegal Gretchin count")
    let unit : Unit
    unit.name = "Gretchin"s
    for index in range(count):
        let model = make_orks_model(Profile::orks_gretchin, OrksDatasheet::gretchin)
        model.keywords.append(Keyword::infantry)
        model.keywords.append(Keyword::grots)
        model.abilities.append(AbilityKind::thievin_scavengers)
        equip_orks_profile(model, Weapon::orks_gretchin_grot_blasta, NamedWeaponProfile::grot_blasta, 0)
        equip_orks_profile(model, Weapon::orks_gretchin_scavenged_shivs, NamedWeaponProfile::scavenged_shivs, 0)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::gretchin)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon: equipment/composition.
fun make_orks_gunwagon(Int hull_mm, Int big_shootas, Bool ball, Bool klaw, Bool lobba, OrksGunwagonGun gun) -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_gunwagon, OrksDatasheet::gunwagon)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::frame)
    model.keywords.append(Keyword::transport)
    model.keywords.append(Keyword::wagon)
    model.abilities.append(AbilityKind::mobile_arsenal)
    model.has_damaged = true
    model.damaged_threshold = 6
    model.has_deadly_demise = true
    model.deadly_demise = compound_stat(1, 6, 0)
    assert(hull_mm >= 0 and hull_mm <= 1000, "invalid circular hull proxy diameter")
    model.geometry.proxy_diameter_mm = hull_mm
    # Intentional imprecision, user-authorized temporary large circle.
    if hull_mm == 0:
        model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(OrksDatasheet::gunwagon)
    model.transport_permissions_known = true
    model.transport_capacity = 12
    model.permitted_passenger_keywords.append(Keyword::infantry)
    model.orks_transport_permissions = true
    assert(big_shootas >= 0 and big_shootas <= 4, "invalid extra Big Shootas")
    assert((big_shootas) >= 0 and (big_shootas) <= 5, "invalid physical weapon count")
    for weapon_copy_1 in range(big_shootas):
        let weapon_group_1 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_gunwagon_big_shoota, NamedWeaponProfile::big_shoota, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_gunwagon_crushin_bulk, NamedWeaponProfile::crushin_bulk, weapon_group_2)
    if ball:
        let weapon_group_3 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_gunwagon_wreckin_ball, NamedWeaponProfile::wreckin_ball, weapon_group_3)
    if klaw:
        let weapon_group_4 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_gunwagon_grabbin_klaw, NamedWeaponProfile::grabbin_klaw, weapon_group_4)
    assert(gun.value >= 0 and gun.value < 3, "invalid Gunwagon replacement")
    if gun.value == 0:
        let weapon_group_5 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_gunwagon_kannon_frag, NamedWeaponProfile::kannon_frag, weapon_group_5)
        equip_orks_profile(model, Weapon::orks_gunwagon_kannon_shell, NamedWeaponProfile::kannon_shell, weapon_group_5)
    if gun.value == 1:
        let weapon_group_6 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_gunwagon_killkannon, NamedWeaponProfile::killkannon, weapon_group_6)
    if gun.value == 2:
        let weapon_group_7 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_gunwagon_zzap_gun, NamedWeaponProfile::zzap_gun, weapon_group_7)
    if lobba:
        let weapon_group_8 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_gunwagon_lobba, NamedWeaponProfile::lobba, weapon_group_8)
    let unit : Unit
    unit.name = "Gunwagon"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::gunwagon)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig: equipment/composition.
fun make_orks_hunta_rig() -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_hunta_rig, OrksDatasheet::hunta_rig)
    model.keywords.append(Keyword::monster)
    model.keywords.append(Keyword::beast_snagga)
    model.keywords.append(Keyword::transport)
    model.keywords.append(Keyword::wagon)
    model.abilities.append(AbilityKind::fully_loaded_butchery)
    model.abilities.append(AbilityKind::tramplasquig_charge)
    model.has_damaged = true
    model.damaged_threshold = 6
    model.has_deadly_demise = true
    model.deadly_demise = compound_stat(1, 6, 0)
    model.firing_deck = 11

    model.transport_permissions_known = true
    model.transport_capacity = 22
    model.permitted_passenger_keywords.append(Keyword::infantry)
    model.orks_transport_permissions = true
    model.beast_snagga_passengers_only = true
    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_hunta_rig_eavy_lobba, NamedWeaponProfile::eavy_lobba, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_hunta_rig_stikka_kannon, NamedWeaponProfile::stikka_kannon, weapon_group_2)
    let weapon_group_3 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_hunta_rig_butcha_boyz, NamedWeaponProfile::butcha_boyz, weapon_group_3)
    let weapon_group_4 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_hunta_rig_savage_horns_and_hooves, NamedWeaponProfile::savage_horns_and_hooves, weapon_group_4)
    let weapon_group_5 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_hunta_rig_saw_blades, NamedWeaponProfile::saw_blades, weapon_group_5)
    let unit : Unit
    unit.name = "Hunta Rig"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::hunta_rig)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig: equipment/composition.
fun make_orks_kill_rig() -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_kill_rig, OrksDatasheet::kill_rig)
    model.keywords.append(Keyword::monster)
    model.keywords.append(Keyword::beast_snagga)
    model.keywords.append(Keyword::psyker)
    model.keywords.append(Keyword::transport)
    model.keywords.append(Keyword::wagon)
    model.abilities.append(AbilityKind::beastscent)
    model.abilities.append(AbilityKind::kill_rig_warpath)
    model.has_damaged = true
    model.damaged_threshold = 6
    model.has_deadly_demise = true
    model.deadly_demise = compound_stat(1, 6, 0)

    model.transport_permissions_known = true
    model.transport_capacity = 12
    model.permitted_passenger_keywords.append(Keyword::infantry)
    model.orks_transport_permissions = true
    model.beast_snagga_passengers_only = true
    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_kill_rig_eavy_lobba, NamedWeaponProfile::eavy_lobba, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_kill_rig_stikka_kannon, NamedWeaponProfile::stikka_kannon, weapon_group_2)
    let weapon_group_3 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_kill_rig_wurrtower, NamedWeaponProfile::wurrtower, weapon_group_3)
    let weapon_group_4 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_kill_rig_butcha_boyz, NamedWeaponProfile::butcha_boyz, weapon_group_4)
    let weapon_group_5 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_kill_rig_savage_horns_and_hooves, NamedWeaponProfile::savage_horns_and_hooves, weapon_group_5)
    let weapon_group_6 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_kill_rig_saw_blades, NamedWeaponProfile::saw_blades, weapon_group_6)
    let unit : Unit
    unit.name = "Kill Rig"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::kill_rig)
    unit.psyker_level = 1
    return unit

# Every Kan has three alternate profiles of ONE Kan Blasta plus its Kan Klaw;
# GROTS is a keyword distinct from the Gretchin datasheet identity.
# https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
fun make_orks_killa_kans(Int count) -> Unit:
    assert(count >= 3 and count <= 6, "illegal Killa Kan count")
    let unit : Unit
    unit.name = "Killa Kans"s
    for index in range(count):
        let model = make_orks_model(Profile::orks_killa_kan, OrksDatasheet::killa_kans)
        model.keywords.append(Keyword::vehicle)
        model.keywords.append(Keyword::walker)
        model.keywords.append(Keyword::grots)
        model.has_deadly_demise = true
        model.deadly_demise = raw_stat(1)
        equip_orks_profile(model, Weapon::orks_kan_blasta_dakka, NamedWeaponProfile::kan_blasta_dakka, 1)
        equip_orks_profile(model, Weapon::orks_kan_blasta_kill_shot, NamedWeaponProfile::kan_blasta_kill_shot, 1)
        equip_orks_profile(model, Weapon::orks_kan_blasta_point_blank, NamedWeaponProfile::kan_blasta_point_blank, 1)
        equip_orks_profile(model, Weapon::orks_kan_klaw, NamedWeaponProfile::kan_klaw, 0)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::killa_kans)
    return unit

# Exact source composition/loadout; declaration-time split happens separately.
# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
fun make_orks_kommandos(OrksKommandoLoadout equipment) -> Unit:
    assert(orks_kommando_loadout_valid(equipment), "invalid Kommando loadout")
    let unit : Unit
    unit.name = "Kommandos"s
    for item_index in range(10):
        ref item = equipment[item_index]
        # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
        let model = make_orks_model(Profile::orks_kommando, OrksDatasheet::kommandos)
        model.keywords.append(Keyword::infantry)
        model.keywords.append(Keyword::explosives)
        model.keywords.append(Keyword::smoke)
        model.keywords.append(Keyword::kommandos)
        model.abilities.append(AbilityKind::found_em)
        model.abilities.append(AbilityKind::taktikal_know_wotz)
        model.abilities.append(AbilityKind::nowhere_to_hide)
        model.abilities.append(AbilityKind::bomb_squig)
        model.abilities.append(AbilityKind::infiltrators)
        model.abilities.append(AbilityKind::stealth)

        if item_index == 0:
            model.profile = Profile::orks_kommando_nob
        let weapon_group_1 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_kommandos_slugga, NamedWeaponProfile::slugga, weapon_group_1)
        if item_index == 0 and item.nob_melee.value == OrksNobMeleeChoice::big_choppa.value:
            let weapon_group_2 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_kommandos_big_choppa, NamedWeaponProfile::big_choppa, weapon_group_2)
        else:
            if item_index == 0 and item.nob_melee.value == OrksNobMeleeChoice::power_klaw.value:
                let weapon_group_3 = model.weapons.size() + 1
                equip_orks_profile(model, Weapon::orks_kommandos_power_klaw, NamedWeaponProfile::power_klaw, weapon_group_3)
            else:
                if item.breacha_ram:
                    let weapon_group_4 = model.weapons.size() + 1
                    equip_orks_profile(model, Weapon::orks_kommandos_breacha_ram, NamedWeaponProfile::breacha_ram, weapon_group_4)
                else:
                    let weapon_group_5 = model.weapons.size() + 1
                    equip_orks_profile(model, Weapon::orks_kommandos_choppa, NamedWeaponProfile::choppa, weapon_group_5)
        if item.burna:
            let weapon_group_6 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_kommandos_burna, NamedWeaponProfile::burna, weapon_group_6)
        if item.rokkit:
            let weapon_group_7 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_kommandos_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, weapon_group_7)
            equip_orks_profile(model, Weapon::orks_kommandos_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, weapon_group_7)
        if item.kustom_shoota:
            let weapon_group_8 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_kommandos_kustom_shoota, NamedWeaponProfile::kustom_shoota, weapon_group_8)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::kommandos)
    return unit

# Each physical ranged gun has one chosen profile; twin saws remove both
# default weapons and remain one melee weapon with Twin-linked.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
fun make_orks_meganobz(OrksMeganobLoadouts equipment) -> Unit:
    assert(orks_meganob_loadout_valid(equipment), "invalid Meganob equipment/count")
    let unit : Unit
    unit.name = "Meganobz"s
    for index in range(equipment.size()):
        let model = make_orks_model(Profile::orks_meganob, OrksDatasheet::meganobz)
        model.keywords.append(Keyword::infantry)
        model.keywords.append(Keyword::mega_armour)
        model.keywords.append(Keyword::explosives)
        model.transport_space = 2
        model.abilities.append(AbilityKind::arrogant_invulnerability)
        model.abilities.append(AbilityKind::krumpin_time)
        if equipment[index].value == OrksMeganobLoadout::twin_saws.value:
            equip_orks_profile(model, Weapon::orks_meganobz_twin_killsaws, NamedWeaponProfile::twin_killsaws, 0)
        else:
            if equipment[index].value % 2 == 0:
                equip_orks_profile(model, Weapon::orks_meganobz_power_klaw, NamedWeaponProfile::power_klaw, 0)
            else:
                equip_orks_profile(model, Weapon::orks_meganobz_killsaw, NamedWeaponProfile::killsaw, 0)
            if equipment[index].value < 2:
                equip_orks_profile(model, Weapon::orks_meganobz_kustom_shoota_aimed, NamedWeaponProfile::kustom_shoota_aimed, 1)
                equip_orks_profile(model, Weapon::orks_meganobz_kustom_shoota_point_blank, NamedWeaponProfile::kustom_shoota_point_blank, 1)
            else:
                equip_orks_profile(model, Weapon::orks_meganobz_kombi_weapon_shoota, NamedWeaponProfile::kombi_weapon_shoota, 1)
                equip_orks_profile(model, Weapon::orks_meganobz_kombi_weapon_kill_shot, NamedWeaponProfile::kombi_weapon_kill_shot, 1)
                equip_orks_profile(model, Weapon::orks_meganobz_kombi_weapon_point_blank, NamedWeaponProfile::kombi_weapon_point_blank, 1)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::meganobz)
    return unit

# Standard loadouts are a convenience over the complete independent choices.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
fun make_orks_meganobz(Int count) -> Unit:
    assert(count >= 2 and count <= 6, "invalid Meganob count")
    let equipment : OrksMeganobLoadouts
    equipment.resize(count)
    return make_orks_meganobz(equipment)

# https://wahapedia.ru/wh40k11ed/factions/orks/Mek
fun make_orks_mek() -> Unit:
    let model = make_orks_model(Profile::orks_mek, OrksDatasheet::mek)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::explosives)
    model.abilities.append(AbilityKind::kustom_dakka)
    model.abilities.append(AbilityKind::clever_know_wotz)
    equip_orks_profile(model, Weapon::orks_mek_kustom_mega_slugga, NamedWeaponProfile::kustom_mega_slugga, 0)
    equip_orks_profile(model, Weapon::orks_mek_mek_s_toolz, NamedWeaponProfile::mek_s_toolz, 0)
    let unit : Unit
    unit.name = "Mek"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::mek)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz: crew tokens are not models.
fun make_orks_mek_gunz(OrksMekGuns guns, Int hull_mm) -> Unit:
    assert(guns.size() >= 1 and guns.size() <= 3, "invalid Mek Gunz composition")
    let unit : Unit
    unit.name = "Mek Gunz"s
    for item_index in range(guns.size()):
        assert(guns[item_index].value >= 0 and guns[item_index].value < 4, "invalid Mek Gun replacement")
        # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
        let model = make_orks_model(Profile::orks_mek_gunz, OrksDatasheet::mek_gunz)
        model.keywords.append(Keyword::vehicle)
        model.keywords.append(Keyword::frame)
        model.keywords.append(Keyword::grots)
        model.abilities.append(AbilityKind::madcap_artillery)
        assert(hull_mm >= 0 and hull_mm <= 1000, "invalid circular hull proxy diameter")
        model.geometry.proxy_diameter_mm = hull_mm
        # Intentional imprecision, user-authorized temporary large circle.
        if hull_mm == 0:
            model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(OrksDatasheet::mek_gunz)
        if guns[item_index].value == 0:
            let weapon_group_1 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_mek_gunz_smasha_gun, NamedWeaponProfile::smasha_gun, weapon_group_1)
        if guns[item_index].value == 1:
            let weapon_group_2 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_mek_gunz_bubblechukka, NamedWeaponProfile::bubblechukka, weapon_group_2)
        if guns[item_index].value == 2:
            let weapon_group_3 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_mek_gunz_kustom_mega_kannon, NamedWeaponProfile::kustom_mega_kannon, weapon_group_3)
        if guns[item_index].value == 3:
            let weapon_group_4 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_mek_gunz_traktor_kannon, NamedWeaponProfile::traktor_kannon, weapon_group_4)
        let weapon_group_5 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_mek_gunz_scavenged_shivs, NamedWeaponProfile::scavenged_shivs, weapon_group_5)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::mek_gunz)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut: equipment/composition.
fun make_orks_morkanaut() -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_morkanaut, OrksDatasheet::morkanaut)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::titanic)
    model.keywords.append(Keyword::towering)
    model.keywords.append(Keyword::transport)
    model.keywords.append(Keyword::walker)
    model.abilities.append(AbilityKind::gut_hatch)
    model.abilities.append(AbilityKind::big_an_shooty)
    model.abilities.append(AbilityKind::super_heavy_walker)
    model.has_damaged = true
    model.damaged_threshold = 7
    model.has_deadly_demise = true
    model.deadly_demise = compound_stat(1, 6, 0)

    model.transport_permissions_known = true
    model.transport_capacity = 12
    model.permitted_passenger_keywords.append(Keyword::infantry)
    model.orks_transport_permissions = true
    model.forbid_ghaz_passenger = true
    assert((2) >= 0 and (2) <= 5, "invalid physical weapon count")
    for weapon_copy_1 in range(2):
        let weapon_group_1 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_morkanaut_dual_big_shoota, NamedWeaponProfile::dual_big_shoota, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_morkanaut_kustom_mega_blasta, NamedWeaponProfile::kustom_mega_blasta, weapon_group_2)
    let weapon_group_3 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_morkanaut_kustom_mega_zappa, NamedWeaponProfile::kustom_mega_zappa, weapon_group_3)
    assert((2) >= 0 and (2) <= 5, "invalid physical weapon count")
    for weapon_copy_4 in range(2):
        let weapon_group_4 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_morkanaut_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, weapon_group_4)
        equip_orks_profile(model, Weapon::orks_morkanaut_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, weapon_group_4)
    let weapon_group_5 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_morkanaut_klaw_of_mork, NamedWeaponProfile::klaw_of_mork, weapon_group_5)
    let unit : Unit
    unit.name = "Morkanaut"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::morkanaut)
    return unit

# Epic Hero has a4+ printed InSv; Gutrippa Hunter is D6+1, not modified D6.
# One Last Kill rolls at destruction through the common delayed-fight kernel.
# https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad
fun make_orks_mozrog_skragbad() -> Unit:
    let unit : Unit
    unit.name = "Mozrog Skragbad"s
    let model = make_orks_model(Profile::orks_mozrog_skragbad, OrksDatasheet::mozrog_skragbad)
    model.keywords.append(Keyword::monster)
    model.keywords.append(Keyword::beast_snagga)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::epic_hero)
    model.abilities.append(AbilityKind::boss_of_da_hunt)
    model.abilities.append(AbilityKind::one_last_kill)
    model.abilities.append(AbilityKind::da_bigger_dey_iz)
    equip_orks_profile(model, Weapon::orks_thump_gun, NamedWeaponProfile::thump_gun, 0)
    equip_orks_profile(model, Weapon::orks_big_chompa_jaws, NamedWeaponProfile::big_chompa_s_jaws, 0)
    equip_orks_profile(model, Weapon::orks_gutrippa_standard, NamedWeaponProfile::gutrippa_standard, 1)
    equip_orks_profile(model, Weapon::orks_gutrippa_hunter, NamedWeaponProfile::gutrippa_hunter, 1)
    model.hunter_profile_conditions[3] = orks_monster_vehicle_rule(WeaponRuleKind::anti, 0)
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::mozrog_skragbad)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg: equipment/composition.
fun make_orks_nazdreg() -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_nazdreg, OrksDatasheet::nazdreg)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::epic_hero)
    model.keywords.append(Keyword::mega_armour)
    model.keywords.append(Keyword::warboss)
    model.abilities.append(AbilityKind::intimidating_motivation)
    model.abilities.append(AbilityKind::nazdregs_know_wotz)
    model.abilities.append(AbilityKind::supreme_kunnin)
    model.abilities.append(AbilityKind::deep_strike)
    model.has_da_boss = true

    model.transport_space = 2
    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_nazdreg_kustom_blasta_x_gatler, NamedWeaponProfile::kustom_blasta_x_gatler, weapon_group_1)
    model.simultaneous_ranged_profiles[model.weapons.size() - 1] = true
    equip_orks_profile(model, Weapon::orks_nazdreg_kustom_blasta_x_shoota, NamedWeaponProfile::kustom_blasta_x_shoota, weapon_group_1)
    model.simultaneous_ranged_profiles[model.weapons.size() - 1] = true
    equip_orks_profile(model, Weapon::orks_nazdreg_kustom_blasta_x_skorcha, NamedWeaponProfile::kustom_blasta_x_skorcha, weapon_group_1)
    model.simultaneous_ranged_profiles[model.weapons.size() - 1] = true
    equip_orks_profile(model, Weapon::orks_nazdreg_kustom_blasta_x, NamedWeaponProfile::kustom_blasta_x, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_nazdreg_moonchewa, NamedWeaponProfile::moonchewa, weapon_group_2)
    let unit : Unit
    unit.name = "Nazdreg"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::nazdreg)
    return unit

# Every printed5–10-model composition/valid mixed replacement is supported.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
fun make_orks_nobz(OrksNobLoadouts equipment) -> Unit:
    assert(orks_nobz_loadout_valid(equipment), "illegal Nobz composition/loadout")
    let unit : Unit
    unit.name = "Nobz"s
    for index in range(equipment.size()):
        unit.models.append(orks_nob_model(equipment[index]))
    finalize_orks_unit(unit, OrksDatasheet::nobz)
    return unit

# Standard Nobz retain all Kustom Krumpas/Shootas and actual card abilities.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
fun make_orks_nobz(Int count) -> Unit:
    assert(count >= 5 and count <= 10, "illegal Nobz count")
    let equipment : OrksNobLoadouts
    for index in range(count):
        equipment.append(OrksNobLoadout::standard)
    return make_orks_nobz(equipment)

# https://wahapedia.ru/wh40k11ed/factions/orks/Painboss
fun make_orks_painboss() -> Unit:
    let model = make_orks_model(Profile::orks_painboss, OrksDatasheet::painboss)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::beast_snagga)
    model.abilities.append(AbilityKind::push_dat_bit_back_in)
    model.abilities.append(AbilityKind::hardy_bioniks)
    equip_orks_profile(model, Weapon::orks_painboss_beast_snagga_klaw, NamedWeaponProfile::beast_snagga_klaw, 0)
    let unit : Unit
    unit.name = "Painboss"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::painboss)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Painboy
fun make_orks_painboy() -> Unit:
    let model = make_orks_model(Profile::orks_painboy, OrksDatasheet::painboy)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.abilities.append(AbilityKind::crude_surgery)
    model.abilities.append(AbilityKind::catch_dat_red_bit)
    equip_orks_profile(model, Weapon::orks_painboy_urty_syringe, NamedWeaponProfile::urty_syringe, 0)
    equip_orks_profile(model, Weapon::orks_painboy_dok_s_toolz, NamedWeaponProfile::dok_s_toolz, 0)
    let unit : Unit
    unit.name = "Painboy"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::painboy)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies: equipment/composition.
fun make_orks_rukkatrukk_squigbuggies(Int count) -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_rukkatrukk_squigbuggies, OrksDatasheet::rukkatrukk_squigbuggies)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::explosives)
    model.keywords.append(Keyword::speed_freeks)
    model.abilities.append(AbilityKind::squig_barrage)
    model.has_deadly_demise = true
    model.deadly_demise = raw_stat(1)

    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_rukkatrukk_squigbuggies_sawn_off_shotgun, NamedWeaponProfile::sawn_off_shotgun, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_rukkatrukk_squigbuggies_squig_launchas, NamedWeaponProfile::squig_launchas, weapon_group_2)
    let weapon_group_3 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_rukkatrukk_squigbuggies_saw_blades, NamedWeaponProfile::saw_blades, weapon_group_3)
    assert(count >= 1 and count <= 2, "composition requires1-2 models")
    let unit : Unit
    unit.name = "Rukkatrukk Squigbuggies"s
    for member_index in range(count):
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::rukkatrukk_squigbuggies)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
fun make_orks_runtherd() -> Unit:
    let model = make_orks_model(Profile::orks_runtherd, OrksDatasheet::runtherd)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.abilities.append(AbilityKind::thatll_learn_ya)
    equip_orks_profile(model, Weapon::orks_runtherd_slugga, NamedWeaponProfile::slugga, 0)
    equip_orks_profile(model, Weapon::orks_runtherd_runtherd_s_toolz, NamedWeaponProfile::runtherd_s_toolz, 0)
    let unit : Unit
    unit.name = "Runtherd"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::runtherd)
    return unit

# Current count/equipment/ability metadata; Bomb Squig instances require Board
# identities. Oval proxies follow user policy; the public starter uses this adapter.
# https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
fun make_orks_squighog_boyz(Int nobs, Int boys) -> Unit:
    assert(orks_squighog_composition_valid(nobs, boys), "illegal Squighog composition")
    let unit : Unit
    unit.name = "Squighog Boyz"s
    for nob_index in range(nobs):
        unit.models.append(orks_squighog_model(true))
    for boy_index in range(boys):
        unit.models.append(orks_squighog_model(false))
    finalize_orks_unit(unit, OrksDatasheet::squighog_boyz)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Stompa: equipment/composition.
fun make_orks_stompa(Int hull_mm) -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_stompa, OrksDatasheet::stompa)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::frame)
    model.keywords.append(Keyword::titanic)
    model.keywords.append(Keyword::towering)
    model.keywords.append(Keyword::transport)
    model.keywords.append(Keyword::walker)
    model.abilities.append(AbilityKind::idol_of_belligerence)
    model.abilities.append(AbilityKind::super_heavy_walker)
    model.has_damaged = true
    model.damaged_threshold = 10
    model.has_deadly_demise = true
    model.deadly_demise = compound_stat(2, 6, 0)
    assert(hull_mm >= 0 and hull_mm <= 1000, "invalid circular hull proxy diameter")
    model.geometry.proxy_diameter_mm = hull_mm
    # Intentional imprecision, user-authorized temporary large circle.
    if hull_mm == 0:
        model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(OrksDatasheet::stompa)
    model.grants_unit_riled_up = true
    model.transport_permissions_known = true
    model.transport_capacity = 22
    model.permitted_passenger_keywords.append(Keyword::infantry)
    model.orks_transport_permissions = true
    assert((5) >= 0 and (5) <= 5, "invalid physical weapon count")
    for weapon_copy_1 in range(5):
        let weapon_group_1 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_stompa_big_shoota, NamedWeaponProfile::big_shoota, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_stompa_deffkannon_and_supa_rokkits, NamedWeaponProfile::deffkannon_and_supa_rokkits, weapon_group_2)
    let weapon_group_3 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_stompa_skorcha, NamedWeaponProfile::skorcha, weapon_group_3)
    let weapon_group_4 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_stompa_supa_gatler_aimed, NamedWeaponProfile::supa_gatler_aimed, weapon_group_4)
    equip_orks_profile(model, Weapon::orks_stompa_supa_gatler_point_blank, NamedWeaponProfile::supa_gatler_point_blank, weapon_group_4)
    let weapon_group_5 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_stompa_mega_choppa, NamedWeaponProfile::mega_choppa, weapon_group_5)
    let unit : Unit
    unit.name = "Stompa"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::stompa)
    return unit

# Exactly one Nob,4–9 Stormboys; both profiles carry Deep Strike/Fly/Jump Pack.
# Rokkit Charge is an optional fight-selection grant rather than intrinsic A/S.
# https://wahapedia.ru/wh40k11ed/factions/orks/Stormboyz
fun make_orks_stormboyz(Int boys, Bool klaw) -> Unit:
    assert(boys >= 4 and boys <= 9, "illegal Stormboy count")
    let unit : Unit
    unit.name = "Stormboyz"s
    for index in range(boys + 1):
        let profile = Profile::orks_stormboy
        if index == 0:
            profile = Profile::orks_stormboy_nob
        let model = make_orks_model(profile, OrksDatasheet::stormboyz)
        model.keywords.append(Keyword::infantry)
        model.keywords.append(Keyword::explosives)
        model.keywords.append(Keyword::fly)
        model.keywords.append(Keyword::jump_pack)
        model.abilities.append(AbilityKind::deep_strike)
        model.abilities.append(AbilityKind::rokkit_charge)
        equip_orks_profile(model, Weapon::orks_slugga, NamedWeaponProfile::slugga, 0)
        let melee = Weapon::orks_choppa_standard
        let name = NamedWeaponProfile::choppa
        if index == 0:
            melee = Weapon::orks_kustom_choppa
            name = NamedWeaponProfile::kustom_choppa
            if klaw:
                melee = Weapon::orks_power_klaw
                name = NamedWeaponProfile::power_klaw
        equip_orks_profile(model, melee, name, 0)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::stormboyz)
    return unit

# A Nob replaces one of his TWO pistols. Pulsa is equipment, not a gun profile.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun make_orks_tankbustas(Bool nob_hammer, OrksTankbustaExtra extra, Int extra_member) -> Unit:
    assert(extra.value >= 0 and extra.value <= 2 and extra_member >= 0 and extra_member < 5, "invalid Tankbusta equipment")
    let unit : Unit
    unit.name = "Tankbustas"s
    for index in range(6):
        let profile = Profile::orks_tankbusta
        if index == 0:
            profile = Profile::orks_tankbusta_nob
        let model = make_orks_model(profile, OrksDatasheet::tankbustas)
        model.keywords.append(Keyword::infantry)
        model.keywords.append(Keyword::explosives)
        model.abilities.append(AbilityKind::bomb_squig)
        model.abilities.append(AbilityKind::rokkit_barrage)
        if index == 0:
            equip_orks_profile(model, Weapon::orks_tankbustas_choppa, NamedWeaponProfile::choppa, 0)
            equip_orks_profile(model, Weapon::orks_tankbustas_rokkit_pistol, NamedWeaponProfile::rokkit_pistol, 0)
            if nob_hammer:
                equip_orks_profile(model, Weapon::orks_tankbustas_smash_hammer_standard, NamedWeaponProfile::smash_hammer_standard, 2)
                equip_orks_profile(model, Weapon::orks_tankbustas_smash_hammer_hunter, NamedWeaponProfile::smash_hammer_hunter, 2, orks_monster_vehicle_rule(WeaponRuleKind::anti, 0))
            else:
                equip_orks_profile(model, Weapon::orks_tankbustas_rokkit_pistol, NamedWeaponProfile::rokkit_pistol, 0)
        else:
            equip_orks_profile(model, Weapon::orks_tankbustas_gitstikka, NamedWeaponProfile::gitstikka, 0)
            equip_orks_profile(model, Weapon::orks_tankbustas_busta_rokkit_launcha_standard, NamedWeaponProfile::busta_rokkit_launcha_standard, 1)
            equip_orks_profile(model, Weapon::orks_tankbustas_busta_rokkit_launcha_hunter, NamedWeaponProfile::busta_rokkit_launcha_hunter, 1, orks_monster_vehicle_rule(WeaponRuleKind::anti, 0))
            if index - 1 == extra_member:
                if extra.value == OrksTankbustaExtra::additional_launcher.value:
                    equip_orks_profile(model, Weapon::orks_tankbustas_busta_rokkit_launcha_standard, NamedWeaponProfile::busta_rokkit_launcha_standard, 2)
                    equip_orks_profile(model, Weapon::orks_tankbustas_busta_rokkit_launcha_hunter, NamedWeaponProfile::busta_rokkit_launcha_hunter, 2, orks_monster_vehicle_rule(WeaponRuleKind::anti, 0))
                if extra.value == OrksTankbustaExtra::pulsa.value:
                    model.abilities.append(AbilityKind::pulsa_rokkit)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::tankbustas)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Trukk: equipment/composition.
fun make_orks_trukk(Int hull_mm, Bool rokkit, OrksTrukkExtra extra) -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_trukk, OrksDatasheet::trukk)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::dedicated_transport)
    model.keywords.append(Keyword::frame)
    model.keywords.append(Keyword::speed_freeks)
    model.keywords.append(Keyword::transport)
    model.abilities.append(AbilityKind::pilin_out)
    model.has_deadly_demise = true
    model.deadly_demise = dice_stat(3)
    model.firing_deck = 12
    assert(hull_mm >= 0 and hull_mm <= 1000, "invalid circular hull proxy diameter")
    model.geometry.proxy_diameter_mm = hull_mm
    # Intentional imprecision, user-authorized temporary large circle.
    if hull_mm == 0:
        model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(OrksDatasheet::trukk)
    model.transport_permissions_known = true
    model.transport_capacity = 12
    model.permitted_passenger_keywords.append(Keyword::infantry)
    model.orks_transport_permissions = true
    model.forbid_ghaz_passenger = true
    model.forbidden_passenger_keywords.append(Keyword::jump_pack)
    assert(extra.value >= 0 and extra.value <= 2, "invalid Trukk extra")
    if rokkit:
        let weapon_group_1 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_trukk_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, weapon_group_1)
        equip_orks_profile(model, Weapon::orks_trukk_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, weapon_group_1)
    else:
        let weapon_group_2 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_trukk_dual_big_shoota, NamedWeaponProfile::dual_big_shoota, weapon_group_2)
    let weapon_group_3 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_trukk_spiked_ram, NamedWeaponProfile::spiked_ram, weapon_group_3)
    if extra.value == 1:
        let weapon_group_4 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_trukk_buzzsaw, NamedWeaponProfile::buzzsaw, weapon_group_4)
    if extra.value == 2:
        let weapon_group_5 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_trukk_grabbin_klaw, NamedWeaponProfile::grabbin_klaw, weapon_group_5)
    let unit : Unit
    unit.name = "Trukk"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::trukk)
    return unit

# Biker Nob's two combi profiles share one weapon; regular Bikers have a
# single Dual Dakkagun.75x42 ovals intentionally use75mm circle proxies.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers
fun make_orks_warbikers(Int boys) -> Unit:
    assert(boys >= 2 and boys <= 5, "illegal Warbiker count")
    let unit : Unit
    unit.name = "Warbikers"s
    for index in range(boys + 1):
        let profile = Profile::orks_warbiker
        if index == 0:
            profile = Profile::orks_biker_nob
        let model = make_orks_model(profile, OrksDatasheet::warbikers)
        model.keywords.append(Keyword::mounted)
        model.keywords.append(Keyword::explosives)
        model.keywords.append(Keyword::speed_freeks)
        model.abilities.append(AbilityKind::high_speed_carnage)
        # Intentional user-authorized long-axis circle; both axes remain metadata.
        model.geometry.unsupported_footprint = false
        if index == 0:
            equip_orks_profile(model, Weapon::orks_dual_kombi_rokkit_dakkagun, NamedWeaponProfile::dual_kombi_rokkit_dakkagun, 1)
            equip_orks_profile(model, Weapon::orks_dual_kombi_rokkit_busta, NamedWeaponProfile::dual_kombi_rokkit_busta_rokkit, 1)
            equip_orks_profile(model, Weapon::orks_kustom_choppa, NamedWeaponProfile::kustom_choppa, 0)
        else:
            equip_orks_profile(model, Weapon::orks_dual_dakkagun, NamedWeaponProfile::dual_dakkagun, 0)
            equip_orks_profile(model, Weapon::orks_choppa_standard, NamedWeaponProfile::choppa, 0)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::warbikers)
    return unit

# Warboss variants have their own A/WS/S and Cleave; never reuse Nob stats.
# Boss Ammo Runt applies only to the bearer; Intimidating Motivation uses112.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
fun make_orks_warboss(Bool klaw, OrksNobGunChoice gun) -> Unit:
    assert(gun.value >= 0 and gun.value < 3, "Warboss must retain a permitted gun")
    let unit : Unit
    unit.name = "Warboss"s
    let model = make_orks_model(Profile::orks_warboss, OrksDatasheet::warboss)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::explosives)
    model.keywords.append(Keyword::warboss)
    model.has_da_boss = true
    model.abilities.append(AbilityKind::boss_ammo_runt)
    model.abilities.append(AbilityKind::might_is_right)
    model.abilities.append(AbilityKind::intimidating_motivation)
    if klaw:
        equip_orks_profile(model, Weapon::orks_warboss_power_klaw, NamedWeaponProfile::power_klaw, 0)
    else:
        equip_orks_profile(model, Weapon::orks_warboss_kustom_choppa, NamedWeaponProfile::kustom_choppa, 0)
    equip_orks_nob_gun(model, gun)
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::warboss)
    return unit

# Literal default Warboss armament; replacements are the overload above.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
fun make_orks_warboss() -> Unit:
    return make_orks_warboss(false, OrksNobGunChoice::kustom_shoota)

# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
fun make_orks_warboss_in_mega_armour() -> Unit:
    let model = make_orks_model(Profile::orks_warboss_in_mega_armour, OrksDatasheet::warboss_in_mega_armour)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::mega_armour)
    model.keywords.append(Keyword::warboss)
    model.transport_space = 2
    model.has_da_boss = true
    model.abilities.append(AbilityKind::krushin_impetus)
    model.abilities.append(AbilityKind::intimidating_motivation)
    equip_orks_profile(model, Weapon::orks_warboss_in_mega_armour_big_shoota, NamedWeaponProfile::big_shoota, 0)
    equip_orks_profile(model, Weapon::orks_warboss_in_mega_armour_uge_choppa, NamedWeaponProfile::uge_choppa, 0)
    let unit : Unit
    unit.name = "Warboss In Mega Armour"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::warboss_in_mega_armour)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies: individual replacement choices.
fun make_orks_warbuggies(OrksVehicleSwaps swaps) -> Unit:
    assert(swaps.size() >= 1 and swaps.size() <= 2, "invalid composition")
    let count = 0
    for item in range(swaps.size()):
        count = count + int(swaps[item])
    let unit : Unit
    unit.name = "Warbuggies"s
    for item_index in range(swaps.size()):
        # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
        let model = make_orks_model(Profile::orks_warbuggies, OrksDatasheet::warbuggies)
        model.keywords.append(Keyword::vehicle)
        model.keywords.append(Keyword::explosives)
        model.keywords.append(Keyword::speed_freeks)
        model.abilities.append(AbilityKind::drive_by_skorchin)
        model.has_deadly_demise = true
        model.deadly_demise = raw_stat(1)

        if swaps[item_index]:
            let weapon_group_1 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_warbuggies_rivet_kannon_aimed, NamedWeaponProfile::rivet_kannon_aimed, weapon_group_1)
            equip_orks_profile(model, Weapon::orks_warbuggies_rivet_kannon_point_blank, NamedWeaponProfile::rivet_kannon_point_blank, weapon_group_1)
        else:
            let weapon_group_2 = model.weapons.size() + 1
            equip_orks_profile(model, Weapon::orks_warbuggies_mek_speshul_aimed, NamedWeaponProfile::mek_speshul_aimed, weapon_group_2)
            equip_orks_profile(model, Weapon::orks_warbuggies_mek_speshul_point_blank, NamedWeaponProfile::mek_speshul_point_blank, weapon_group_2)
        let weapon_group_3 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_warbuggies_extra_dakka, NamedWeaponProfile::extra_dakka, weapon_group_3)
        let weapon_group_4 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_warbuggies_spiked_ram, NamedWeaponProfile::spiked_ram, weapon_group_4)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::warbuggies)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks: equipment/composition.
fun make_orks_wartrakks(Int count) -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_wartrakks, OrksDatasheet::wartrakks)
    model.keywords.append(Keyword::mounted)
    model.keywords.append(Keyword::speed_freeks)
    model.abilities.append(AbilityKind::speednob_support)
    model.abilities.append(AbilityKind::bust_em)

    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_wartrakks_kustom_shoota, NamedWeaponProfile::kustom_shoota, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_wartrakks_multi_busta_launcha, NamedWeaponProfile::multi_busta_launcha, weapon_group_2)
    let weapon_group_3 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_wartrakks_kustom_choppa, NamedWeaponProfile::kustom_choppa, weapon_group_3)
    assert(count >= 1 and count <= 2, "composition requires1-2 models")
    let unit : Unit
    unit.name = "Wartrakks"s
    for member_index in range(count):
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::wartrakks)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet: equipment/composition.
fun make_orks_wazbom_blastajet(Bool tellyport, Bool field, Bool supa_shoota) -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_wazbom_blastajet, OrksDatasheet::wazbom_blastajet)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::aircraft)
    model.keywords.append(Keyword::fly)
    model.keywords.append(Keyword::smoke)
    model.keywords.append(Keyword::speed_freeks)
    model.abilities.append(AbilityKind::weak_spot)
    model.has_damaged = true
    model.damaged_threshold = 4
    model.has_deadly_demise = true
    model.deadly_demise = dice_stat(3)

    if supa_shoota:
        let weapon_group_1 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_wazbom_blastajet_dual_supa_shoota, NamedWeaponProfile::dual_supa_shoota, weapon_group_1)
    if tellyport:
        let weapon_group_2 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_wazbom_blastajet_dual_tellyport_mega_blasta, NamedWeaponProfile::dual_tellyport_mega_blasta, weapon_group_2)
    if !tellyport:
        let weapon_group_3 = model.weapons.size() + 1
        equip_orks_profile(model, Weapon::orks_wazbom_blastajet_dual_wazbom_mega_kannon, NamedWeaponProfile::dual_wazbom_mega_kannon, weapon_group_3)
    let weapon_group_4 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_wazbom_blastajet_smasha_gun, NamedWeaponProfile::smasha_gun, weapon_group_4)
    let weapon_group_5 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_wazbom_blastajet_armoured_impact, NamedWeaponProfile::armoured_impact, weapon_group_5)
    model.blastajet_force_field = field
    let unit : Unit
    unit.name = "Wazbom Blastajet"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::wazbom_blastajet)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek: equipment/composition.
fun make_orks_wazdakka_gutsmek() -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_wazdakka_gutsmek, OrksDatasheet::wazdakka_gutsmek)
    model.keywords.append(Keyword::mounted)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::epic_hero)
    model.keywords.append(Keyword::smoke)
    model.keywords.append(Keyword::speed_freeks)
    model.abilities.append(AbilityKind::full_throttle)
    model.abilities.append(AbilityKind::deep_strike)
    model.abilities.append(AbilityKind::lone_operative)
    model.has_deadly_demise = true
    model.deadly_demise = dice_stat(3)

    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_wazdakka_gutsmek_grabba_dragga_ranged, NamedWeaponProfile::grabba_dragga_ranged, weapon_group_1)
    equip_orks_profile(model, Weapon::orks_wazdakka_gutsmek_grabba_dragga_melee, NamedWeaponProfile::grabba_dragga_melee, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_wazdakka_gutsmek_psyko_gatler, NamedWeaponProfile::psyko_gatler, weapon_group_2)
    let weapon_group_3 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_wazdakka_gutsmek_speeding_bulk_and_flaming_exhaust, NamedWeaponProfile::speeding_bulk_and_flaming_exhaust, weapon_group_3)
    let weapon_group_4 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_wazdakka_gutsmek_fixit_s_wrench, NamedWeaponProfile::fixit_s_wrench, weapon_group_4)
    let unit : Unit
    unit.name = "Wazdakka Gutsmek"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::wazdakka_gutsmek)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy: equipment/composition.
fun make_orks_weirdboy() -> Unit:
    # Printed metadata: https://wahapedia.ru/wh40k11ed/factions/orks/ (this datasheet).
    let model = make_orks_model(Profile::orks_weirdboy, OrksDatasheet::weirdboy)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::psyker)
    model.abilities.append(AbilityKind::da_jump)
    model.abilities.append(AbilityKind::weirdboy_warpath)
    model.has_deadly_demise = true
    model.deadly_demise = dice_stat(3)

    let weapon_group_1 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_weirdboy_power_vomit, NamedWeaponProfile::power_vomit, weapon_group_1)
    let weapon_group_2 = model.weapons.size() + 1
    equip_orks_profile(model, Weapon::orks_weirdboy_copper_staff, NamedWeaponProfile::copper_staff, weapon_group_2)
    let unit : Unit
    unit.name = "Weirdboy"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::weirdboy)
    unit.psyker_level = 1
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga
fun make_orks_zodgrod_wortsnagga() -> Unit:
    let model = make_orks_model(Profile::orks_zodgrod_wortsnagga, OrksDatasheet::zodgrod_wortsnagga)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::epic_hero)
    model.keywords.append(Keyword::runtherd)
    model.grants_unit_riled_up = true
    model.abilities.append(AbilityKind::super_runts)
    equip_orks_profile(model, Weapon::orks_zodgrod_wortsnagga_squigstoppa, NamedWeaponProfile::squigstoppa, 0)
    equip_orks_profile(model, Weapon::orks_zodgrod_wortsnagga_da_grabzappa, NamedWeaponProfile::da_grabzappa, 0)
    let unit : Unit
    unit.name = "Zodgrod Wortsnagga"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::zodgrod_wortsnagga)
    return unit

# Every ten TOTAL models permits one of each distinct Boy replacement. Nob
# Big Choppa replaces both starting weapons; other unused fields must be default.
# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
fun orks_boyz_loadout_valid(OrksBoyzLoadouts equipment) -> Bool:
    let nobs = 0
    let boys = 0
    let specials : Int[4]
    let valid = true
    for index in range(equipment.size()):
        ref item = equipment[index]
        if item.nob:
            nobs = nobs + 1
            valid = valid and item.boy_gun.value == 0 and item.melee.value >= 0 and item.melee.value <= 2 and item.nob_gun.value >= 0 and item.nob_gun.value <= 3
            valid = valid and ((item.melee.value == OrksNobMeleeChoice::big_choppa.value and item.nob_gun.value == OrksNobGunChoice::none.value) or (item.melee.value != OrksNobMeleeChoice::big_choppa.value and item.nob_gun.value != OrksNobGunChoice::none.value))
        else:
            boys = boys + 1
            valid = valid and item.melee.value == 0 and item.nob_gun.value == 0 and item.boy_gun.value >= 0 and item.boy_gun.value <= 3
            if item.boy_gun.value >= 0 and item.boy_gun.value <= 3:
                specials[item.boy_gun.value] = specials[item.boy_gun.value] + 1
    valid = valid and nobs >= 1 and nobs <= 2 and boys >= 9 and boys <= 18
    for kind in range(3):
        valid = valid and specials[kind + 1] <= equipment.size() / 10
    return valid

# Boy models retain Slugga/Choppa when replacing their Shoota; the Nob has
# neither of those starting weapons. All rule metadata comes from this card.
# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
fun orks_boyz_model(OrksBoyzLoadout item) -> Model:
    let profile = Profile::orks_boy
    if item.nob:
        profile = Profile::orks_boyz_nob
    let model = make_orks_model(profile, OrksDatasheet::boyz)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::battleline)
    model.keywords.append(Keyword::explosives)
    model.keywords.append(Keyword::mob)
    model.abilities.append(AbilityKind::ammo_runts)
    model.abilities.append(AbilityKind::tide_of_muscle)
    model.abilities.append(AbilityKind::never_too_busy_to_fight)
    if item.nob:
        let melee = Weapon::orks_kustom_choppa
        let name = NamedWeaponProfile::kustom_choppa
        if item.melee.value == OrksNobMeleeChoice::power_klaw.value:
            melee = Weapon::orks_power_klaw
            name = NamedWeaponProfile::power_klaw
        if item.melee.value == OrksNobMeleeChoice::big_choppa.value:
            melee = Weapon::orks_infantry_big_choppa
            name = NamedWeaponProfile::big_choppa
        equip_orks_profile(model, melee, name, 0)
        equip_orks_nob_gun(model, item.nob_gun)
    else:
        equip_orks_profile(model, Weapon::orks_choppa_standard, NamedWeaponProfile::choppa, 0)
        equip_orks_profile(model, Weapon::orks_slugga, NamedWeaponProfile::slugga, 0)
        if item.boy_gun.value == OrksBoyGunChoice::shoota.value:
            equip_orks_profile(model, Weapon::orks_shoota, NamedWeaponProfile::shoota, 0)
        if item.boy_gun.value == OrksBoyGunChoice::big_shoota.value:
            equip_orks_profile(model, Weapon::orks_infantry_big_shoota, NamedWeaponProfile::big_shoota, 0)
        if item.boy_gun.value == OrksBoyGunChoice::burna.value:
            equip_orks_profile(model, Weapon::orks_burna, NamedWeaponProfile::burna, 0)
        if item.boy_gun.value == OrksBoyGunChoice::rokkit_launcha.value:
            equip_orks_profile(model, Weapon::orks_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, 1)
            equip_orks_profile(model, Weapon::orks_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, 1)
    return model

# Indices0-4 name actual Boy models;5 means that replacement was not taken.
# Nob's replacement adds a SECOND pistol and removes his Smash Hammer.
# https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
fun orks_breaka_loadout_valid(Int knuckles, Int tankhammer) -> Bool:
    return knuckles >= 0 and knuckles <= 5 and tankhammer >= 0 and tankhammer <= 5 and (knuckles == 5 or tankhammer == 5 or knuckles != tankhammer)

# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos: one Nob, nine Boys,
# independent extra slots; only the Breacha Ram replaces a Boy's Choppa.
fun orks_kommando_loadout_valid(OrksKommandoLoadout equipment) -> Bool:
    if equipment.size() != 10:
        return false
    let burnas = 0
    let rokkits = 0
    let rams = 0
    let shootas = 0
    let valid = true
    for item_index in range(10):
        ref item = equipment[item_index]
        if item_index == 0:
            valid = valid and !item.burna and !item.rokkit and !item.breacha_ram and !item.kustom_shoota and item.nob_melee.value >= 0 and item.nob_melee.value <= 2
        else:
            valid = valid and item.nob_melee.value == 0
            burnas = burnas + int(item.burna)
            rokkits = rokkits + int(item.rokkit)
            rams = rams + int(item.breacha_ram)
            shootas = shootas + int(item.kustom_shoota)
    return valid and burnas <= 1 and rokkits <= 1 and rams <= 1 and shootas <= 2

# Preserve all printed model counts and per-model choices, not priced tiers.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
fun orks_meganob_loadout_valid(OrksMeganobLoadouts equipment) -> Bool:
    let valid = equipment.size() >= 2 and equipment.size() <= 6
    for index in range(equipment.size()):
        valid = valid and equipment[index].value >= 0 and equipment[index].value <= 4
    return valid

# Paired Krumpas is equipment granting rerolls to Kustom Krumpa, not another
# melee profile. Heavy replacements remove both standard weapon slots.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
fun orks_nob_model(OrksNobLoadout equipment) -> Model:
    let model = make_orks_model(Profile::orks_nob, OrksDatasheet::nobz)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::explosives)
    model.abilities.append(AbilityKind::ammo_runts)
    model.abilities.append(AbilityKind::get_out_da_way)
    model.paired_krumpas = equipment.value == OrksNobLoadout::paired_krumpas.value
    let melee = Weapon::orks_kustom_krumpa
    let name = NamedWeaponProfile::kustom_krumpa
    if equipment.value == OrksNobLoadout::big_skorcha.value or equipment.value == OrksNobLoadout::kustom_big_shoota.value:
        melee = Weapon::orks_kustom_choppa
        name = NamedWeaponProfile::kustom_choppa
    if equipment.value == OrksNobLoadout::big_choppa.value:
        melee = Weapon::orks_infantry_big_choppa
        name = NamedWeaponProfile::big_choppa
    equip_orks_profile(model, melee, name, 0)
    if equipment.value == OrksNobLoadout::standard.value:
        equip_orks_profile(model, Weapon::orks_kustom_shoota, NamedWeaponProfile::kustom_shoota, 0)
    if equipment.value == OrksNobLoadout::kombi_rokkit.value:
        equip_orks_nob_gun(model, OrksNobGunChoice::kombi_rokkit)
    if equipment.value == OrksNobLoadout::big_skorcha.value:
        equip_orks_profile(model, Weapon::orks_big_skorcha, NamedWeaponProfile::big_skorcha, 0)
    if equipment.value == OrksNobLoadout::kustom_big_shoota.value:
        equip_orks_profile(model, Weapon::orks_kustom_big_shoota, NamedWeaponProfile::kustom_big_shoota, 0)
    return model

# Paired Krumpas/each heavy replacement has its own quota per five models;
# they replace the same original slots, so each model has one listed choice.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
fun orks_nobz_loadout_valid(OrksNobLoadouts equipment) -> Bool:
    let valid = equipment.size() >= 5 and equipment.size() <= 10
    let counts : Int[6]
    for index in range(equipment.size()):
        let kind = equipment[index].value
        valid = valid and kind >= 0 and kind < 6
        if kind >= 0 and kind < 6:
            counts[kind] = counts[kind] + 1
    for restricted in range(4):
        valid = valid and counts[restricted + 2] <= equipment.size() / 5
    return valid

# Exact composition from the source card; prices do not add a composition
# rule. Optional Thump Guns are extra equipment, limited by total model count.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz
fun orks_snagga_composition_valid(Int nobs, Int boys, Int thump_guns) -> Bool:
    return nobs >= 1 and nobs <= 2 and boys >= 9 and boys <= 18 and thump_guns >= 0 and thump_guns <= (nobs + boys) / 10

# Every model has the card's full keyword set; only the Nob/Boy profiles and
# equipment differ. 'Battleline' is a unit/model keyword, not a pricing rule.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz
fun orks_snagga_model(Bool nob, Bool thump_gun) -> Model:
    let profile = Profile::orks_beast_snagga_boy
    if nob:
        profile = Profile::orks_beast_snagga_nob
    let model = make_orks_model(profile, OrksDatasheet::beast_snagga_boyz)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::battleline)
    model.keywords.append(Keyword::beast_snagga)
    model.keywords.append(Keyword::mob)
    model.abilities.append(AbilityKind::mobbed)
    equip_orks_profile(model, Weapon::orks_slugga, NamedWeaponProfile::slugga, 0)
    if nob:
        assert(!thump_gun, "Thump Gun belongs to a Boy, not a Nob")
        equip_orks_profile(model, Weapon::orks_power_snappa, NamedWeaponProfile::power_snappa, 0)
    else:
        equip_orks_profile(model, Weapon::orks_choppa_standard, NamedWeaponProfile::choppa_standard, 1)
        equip_orks_profile(model, Weapon::orks_choppa_hunter, NamedWeaponProfile::choppa_hunter, 1)
        model.hunter_profile_conditions[2] = orks_monster_vehicle_rule(WeaponRuleKind::anti, 0)
        if thump_gun:
            equip_orks_profile(model, Weapon::orks_thump_gun, NamedWeaponProfile::thump_gun, 0)
    return model

# The printed ranges, not the priced4/8 rows, define legal model counts.
# https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
fun orks_squighog_composition_valid(Int nobs, Int boys) -> Bool:
    return nobs >= 1 and nobs <= 2 and boys >= 3 and boys <= 6

# Squighog equipment includes ranged+melee Stikka profiles as one physical
# weapon, and jaws as Extra Attacks. Neither profile has inherited Lance/FNP.
# The source gives75x42/90x52 ovals. User policy now permits temporary75/90mm
# long-axis circles; retain both axes and the explicit oval metadata.
# https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
fun orks_squighog_model(Bool nob) -> Model:
    let profile = Profile::orks_squighog_boy
    if nob:
        profile = Profile::orks_nob_on_smasha_squig
    let model = make_orks_model(profile, OrksDatasheet::squighog_boyz)
    model.keywords.append(Keyword::mounted)
    model.keywords.append(Keyword::beast_snagga)
    model.keywords.append(Keyword::explosives)
    model.keywords.append(Keyword::mobile)
    # User-authorized proxy: long-axis circle; original oval axes stay metadata.
    model.geometry.unsupported_footprint = false
    model.abilities.append(AbilityKind::bomb_squig)
    model.abilities.append(AbilityKind::brutal_impact)
    if nob:
        equip_orks_profile(model, Weapon::orks_slugga, NamedWeaponProfile::slugga, 0)
        equip_orks_profile(model, Weapon::orks_big_choppa, NamedWeaponProfile::big_choppa, 0)
    else:
        equip_orks_profile(model, Weapon::orks_saddlegit_shiv, NamedWeaponProfile::saddlegit_s_shiv, 0)
        equip_orks_profile(model, Weapon::orks_stikka_ranged, NamedWeaponProfile::stikka_ranged, 1)
        equip_orks_profile(model, Weapon::orks_stikka_melee, NamedWeaponProfile::stikka_melee, 1)
    equip_orks_profile(model, Weapon::orks_squig_jaws, NamedWeaponProfile::squig_s_jaws, 0)
    return model

# Intentional imprecision authorized by the user on2026-10-15. These large
# circles are TEMPORARY proxies, not measured models or source base sizes.
# Sources below say Use model; exact hull geometry is a later migration.
fun orks_temporary_hull_diameter(OrksDatasheet sheet) -> Int:
    if sheet.value == OrksDatasheet::stompa.value:
        return 240
    if sheet.value == OrksDatasheet::mek_gunz.value:
        return 100
    if sheet.value == OrksDatasheet::trukk.value:
        return 140
    return 160
