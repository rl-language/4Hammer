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

cls OrksBoyzLoadout:
    Bool nob
    Weapon melee
    Weapon nob_gun
    Weapon boy_gun

using OrksBoyzLoadouts = CheckedVector<OrksBoyzLoadout, MAX_UNIT_MODELS>

# Hull sizes are explicit millimetre circle proxies, never inferred dimensions.
# User authorizes circular treatment of all noncircles; core p12 measurements.
using OrksHullDiameter = LinearlyDistributedInt<0, 1001>

cls OrksKommandoEquipment:
    Weapon nob_melee
    Bool burna
    Bool rokkit
    Bool breacha_ram
    Bool kustom_shoota

using OrksKommandoLoadout = CheckedVector<OrksKommandoEquipment, 10>

# Independent replacements versus the combined Twin Killsaws replacement.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
using OrksMeganobLoadout = WeaponPair

using OrksMeganobLoadouts = CheckedVector<OrksMeganobLoadout, 6>

using OrksMekGuns = CheckedVector<Weapon, 3>

using OrksNobLoadouts = CheckedVector<Weapon, MAX_UNIT_MODELS>

# Per-weapon swaps for the current six-profile vehicle envelope; source-card
# factories validate which physical copies permit replacement.
using OrksVehicleSwaps = CheckedVector<Bool, 6>

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
fun equip_orks_dread_arm(Model model, Weapon choice):
    assert(weapon_allowed(choice, orks_dread_arm_choices()), "invalid Dread arm")
    let primary = model.weapons.size() + 1
    equip_weapon(model, choice, 0)
    if choice.value == Weapon::orks_rokkit_launcha_blasta.value:
        equip_weapon(model, Weapon::orks_rokkit_launcha_busta, primary)

# Combi profiles share a physical group and require one selected profile.
# Boyz/Warboss printed equipment; appendix04.01.03/core p16.
fun equip_orks_nob_gun(Model model, Weapon choice):
    assert(weapon_allowed(choice, orks_nob_gun_choices()), "invalid Nob gun choice")
    let primary = model.weapons.size() + 1
    if choice.value != Weapon::none.value:
        equip_weapon(model, choice, 0)
    if choice.value == Weapon::orks_kombi_skorcha_shoota.value:
        equip_weapon(model, Weapon::orks_kombi_skorcha_skorcha, primary)
    if choice.value == Weapon::orks_kombi_rokkit_busta.value:
        equip_weapon(model, Weapon::orks_kombi_rokkit_shoota, primary)

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
    equip_weapon(model, Weapon::orks_shoota, 0)
    equip_weapon(model, Weapon::orks_kustom_choppa, 0)
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
        equip_weapon(model, Weapon::orks_battlewagon_big_shoota, 0)
    equip_weapon(model, Weapon::orks_battlewagon_crushin_bulk, 0)
    if ball:
        equip_weapon(model, Weapon::orks_battlewagon_wreckin_ball, 0)
    if klaw:
        equip_weapon(model, Weapon::orks_battlewagon_grabbin_klaw, 0)
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
    equip_weapon(model, Weapon::orks_beastboss_shoota, 0)
    equip_weapon(model, Weapon::orks_beastboss_klaw_and_beastchoppa, 0)
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
    equip_weapon(model, Weapon::orks_slugga, 0)
    let primary_profile_12 = model.weapons.size() + 1
    equip_weapon(model, Weapon::orks_beastchoppa_standard, 0)
    equip_weapon(model, Weapon::orks_beastchoppa_hunter, primary_profile_12)
    model.hunter_profile_conditions[2] = orks_monster_vehicle_rule(WeaponRuleKind::anti, 0)
    equip_weapon(model, Weapon::orks_squigosaur_jaws, 0)
    if thump_gun:
        equip_weapon(model, Weapon::orks_thump_gun, 0)
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
        equip_weapon(model, Weapon::orks_big_ed_bossbunka_big_shoota, 0)
    let primary_profile_14 = model.weapons.size() + 1
    equip_weapon(model, Weapon::orks_big_ed_bossbunka_gaze_of_gork_glare, 0)
    equip_weapon(model, Weapon::orks_big_ed_bossbunka_gaze_of_gork_squint, primary_profile_14)
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
        equip_weapon(model, Weapon::orks_big_mek_drilla, 0)
    else:
        equip_weapon(model, Weapon::orks_big_mek_power_klaw, 0)
    if traktor:
        equip_weapon(model, Weapon::orks_big_mek_traktor_blasta, 0)
    else:
        equip_weapon(model, Weapon::orks_big_mek_kustom_mega_blasta, 0)
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
    equip_weapon(model, Weapon::orks_blitzkannon, 0)
    equip_weapon(model, Weapon::orks_multi_busta_launcha, 0)
    equip_weapon(model, Weapon::orks_stompy_feet, 0)
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::big_mek_dakkarig)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
fun make_orks_big_mek_in_mega_armour(Weapon gun, Weapon extra) -> Unit:
    let model = make_orks_model(Profile::orks_big_mek_in_mega_armour, OrksDatasheet::big_mek_in_mega_armour)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::big_mek)
    model.keywords.append(Keyword::explosives)
    model.keywords.append(Keyword::mega_armour)
    model.transport_space = 2
    model.abilities.append(AbilityKind::more_dakka)
    model.abilities.append(AbilityKind::fix_dat_armour_up)
    assert(weapon_allowed(gun, orks_mega_mek_gun_choices()) and weapon_allowed(extra, orks_mega_mek_extra_choices()), "invalid Mega Mek equipment")
    equip_weapon(model, Weapon::orks_big_mek_in_mega_armour_power_klaw, 0)
    let primary = model.weapons.size() + 1
    equip_weapon(model, gun, 0)
    if gun.value == Weapon::orks_big_mek_in_mega_armour_kustom_shoota_aimed.value:
        equip_weapon(model, Weapon::orks_big_mek_in_mega_armour_kustom_shoota_point_blank, primary)
    if gun.value == Weapon::orks_big_mek_in_mega_armour_kombi_weapon_shoota.value:
        equip_weapon(model, Weapon::orks_big_mek_in_mega_armour_kombi_weapon_kill_shot, primary)
        equip_weapon(model, Weapon::orks_big_mek_in_mega_armour_kombi_weapon_point_blank, primary)
    if extra.value == Weapon::orks_big_mek_in_mega_armour_tellyport_blasta.value:
        equip_weapon(model, Weapon::orks_big_mek_in_mega_armour_tellyport_blasta, 0)
    if extra.value == Weapon::orks_kustom_force_field.value:
        equip_weapon(model, extra, 0)
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
    equip_weapon(model, Weapon::orks_big_mek_with_shokk_attack_gun_shokk_attack_gun, 0)
    equip_weapon(model, Weapon::orks_big_mek_with_shokk_attack_gun_big_mek_s_toolz, 0)
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
    equip_weapon(model, Weapon::orks_slugga, 0)
    equip_weapon(model, Weapon::orks_bigboss_big_choppa, 0)
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

    equip_weapon(model, Weapon::orks_blitza_bommer_big_shoota, 0)
    equip_weapon(model, Weapon::orks_blitza_bommer_dual_supa_shoota, 0)
    equip_weapon(model, Weapon::orks_blitza_bommer_armoured_impact, 0)
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

    equip_weapon(model, Weapon::orks_boss_snikrot_slugga, 0)
    equip_weapon(model, Weapon::orks_boss_snikrot_mork_s_teef, 0)
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
        let item = orks_boy_loadout()
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
            equip_weapon(model, Weapon::orks_breaka_boyz_choppa, 0)
            equip_weapon(model, Weapon::orks_breaka_boyz_rokkit_pistol, 0)
            if nob_pistols:
                equip_weapon(model, Weapon::orks_breaka_boyz_rokkit_pistol, 0)
        if index > 0 and knuckles == index - 1:
            equip_weapon(model, Weapon::orks_breaka_boyz_knucklebustas, 0)
        else:
            if index > 0 and tankhammer == index - 1:
                equip_weapon(model, Weapon::orks_breaka_boyz_tankhammer, 0)
            else:
                if index > 0 or !nob_pistols:
                    let primary_profile_22 = model.weapons.size() + 1
                    equip_weapon(model, Weapon::orks_breaka_boyz_smash_hammer_standard, 0)
                    equip_weapon(model, Weapon::orks_breaka_boyz_smash_hammer_hunter, primary_profile_22, orks_monster_vehicle_rule(WeaponRuleKind::anti, 0))
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

    equip_weapon(model, Weapon::orks_burna_bommer_dual_big_shoota, 0)
    equip_weapon(model, Weapon::orks_burna_bommer_dual_supa_shoota, 0)
    if missile_rack:
        equip_weapon(model, Weapon::orks_burna_bommer_skorcha_missile_rack, 0)
    equip_weapon(model, Weapon::orks_burna_bommer_armoured_impact, 0)
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
        equip_weapon(model, Weapon::orks_dakkajet_dual_supa_shoota, 0)
    equip_weapon(model, Weapon::orks_dakkajet_armoured_impact, 0)
    let unit : Unit
    unit.name = "Dakkajet"s
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::dakkajet)
    return unit

# The Big Shoota arm cannot take Skorcha; the Skorcha arm can take Big Shoota.
# Dread 'Ard enters incoming D arithmetic (both attack types); demise is fixed1.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
fun make_orks_deff_dread(Weapon first, Weapon second) -> Unit:
    assert(weapon_allowed(first, orks_dread_arm_choices()) and first.value != Weapon::orks_skorcha.value and weapon_allowed(second, orks_dread_arm_choices()), "illegal Deff Dread arms")
    let unit : Unit
    unit.name = "Deff Dread"s
    let model = make_orks_model(Profile::orks_deff_dread, OrksDatasheet::deff_dread)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::walker)
    model.has_deadly_demise = true
    model.deadly_demise = raw_stat(1)
    model.incoming_attack_modifiers.append(incoming_attack_modifier(ModifiedCharacteristic::damage, ModifierOperation::add, -1, IncomingAttackScope::any_attack))
    equip_weapon(model, Weapon::orks_dread_klaws, 0)
    equip_orks_dread_arm(model, first)
    equip_orks_dread_arm(model, second)
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::deff_dread)
    return unit

# Standard printed Dread: one Big Shoota, one Skorcha and Dread Klaws.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
fun make_orks_deff_dread() -> Unit:
    return make_orks_deff_dread(Weapon::orks_dread_big_shoota, Weapon::orks_skorcha)

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

    equip_weapon(model, Weapon::orks_deffkilla_wartrike_boomstikks, 0)
    let primary_profile_30 = model.weapons.size() + 1
    equip_weapon(model, Weapon::orks_deffkilla_wartrike_snagga_klaw_ranged, 0)
    equip_weapon(model, Weapon::orks_deffkilla_wartrike_snagga_klaw_melee, primary_profile_30)
    let primary_profile_31 = model.weapons.size() + 1
    equip_weapon(model, Weapon::orks_deffkilla_wartrike_killa_jet_burna, 0)
    equip_weapon(model, Weapon::orks_deffkilla_wartrike_killa_jet_cutta, primary_profile_31)
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
            equip_weapon(model, Weapon::orks_deffkoptas_kustom_mega_blasta, 0)
        else:
            let primary_profile_33 = model.weapons.size() + 1
            equip_weapon(model, Weapon::orks_deffkoptas_rokkit_launcha_blasta, 0)
            equip_weapon(model, Weapon::orks_deffkoptas_rokkit_launcha_busta, primary_profile_33)
        equip_weapon(model, Weapon::orks_deffkoptas_slugga, 0)
        equip_weapon(model, Weapon::orks_deffkoptas_choppa, 0)
        equip_weapon(model, Weapon::orks_deffkoptas_spinnin_blades, 0)
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
        let primary_profile_37 = model.weapons.size() + 1
        equip_weapon(model, Weapon::orks_flash_gitz_snazzgun_cutta, 0)
        equip_weapon(model, Weapon::orks_flash_gitz_snazzgun_dakka, primary_profile_37)
        equip_weapon(model, Weapon::orks_flash_gitz_snazzgun_kill_shot, primary_profile_37)
        equip_weapon(model, Weapon::orks_flash_gitz_choppa, 0)
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
    let primary_profile_38 = model.weapons.size() + 1
    equip_weapon(model, Weapon::orks_ghazghkull_thraka_mork_s_roar_aimed, 0)
    equip_weapon(model, Weapon::orks_ghazghkull_thraka_mork_s_roar_point_blank, primary_profile_38)
    equip_weapon(model, Weapon::orks_ghazghkull_thraka_adamantine_eadbutt, 0)
    equip_weapon(model, Weapon::orks_ghazghkull_thraka_gork_s_klaw, 0)
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
    let primary_profile_41 = model.weapons.size() + 1
    equip_weapon(model, Weapon::orks_gorkanaut_deffstorm_mega_shoota_aimed, 0)
    equip_weapon(model, Weapon::orks_gorkanaut_deffstorm_mega_shoota_point_blank, primary_profile_41)
    assert((2) >= 0 and (2) <= 5, "invalid physical weapon count")
    for weapon_copy_2 in range(2):
        equip_weapon(model, Weapon::orks_gorkanaut_dual_big_shoota, 0)
    assert((2) >= 0 and (2) <= 5, "invalid physical weapon count")
    for weapon_copy_3 in range(2):
        let primary_profile_43 = model.weapons.size() + 1
        equip_weapon(model, Weapon::orks_gorkanaut_rokkit_launcha_blasta, 0)
        equip_weapon(model, Weapon::orks_gorkanaut_rokkit_launcha_busta, primary_profile_43)
    equip_weapon(model, Weapon::orks_gorkanaut_skorcha, 0)
    equip_weapon(model, Weapon::orks_gorkanaut_klaw_of_gork, 0)
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
        equip_weapon(model, Weapon::orks_gretchin_grot_blasta, 0)
        equip_weapon(model, Weapon::orks_gretchin_scavenged_shivs, 0)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::gretchin)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon: equipment/composition.
fun make_orks_gunwagon(Int hull_mm, Int big_shootas, Bool ball, Bool klaw, Bool lobba, Weapon gun) -> Unit:
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
        equip_weapon(model, Weapon::orks_gunwagon_big_shoota, 0)
    equip_weapon(model, Weapon::orks_gunwagon_crushin_bulk, 0)
    if ball:
        equip_weapon(model, Weapon::orks_gunwagon_wreckin_ball, 0)
    if klaw:
        equip_weapon(model, Weapon::orks_gunwagon_grabbin_klaw, 0)
    assert(weapon_allowed(gun, orks_gunwagon_gun_choices()), "invalid Gunwagon replacement")
    let primary = model.weapons.size() + 1
    equip_weapon(model, gun, 0)
    if gun.value == Weapon::orks_gunwagon_kannon_frag.value:
        equip_weapon(model, Weapon::orks_gunwagon_kannon_shell, primary)
    if lobba:
        equip_weapon(model, Weapon::orks_gunwagon_lobba, 0)
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
    equip_weapon(model, Weapon::orks_hunta_rig_eavy_lobba, 0)
    equip_weapon(model, Weapon::orks_hunta_rig_stikka_kannon, 0)
    equip_weapon(model, Weapon::orks_hunta_rig_butcha_boyz, 0)
    equip_weapon(model, Weapon::orks_hunta_rig_savage_horns_and_hooves, 0)
    equip_weapon(model, Weapon::orks_hunta_rig_saw_blades, 0)
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
    equip_weapon(model, Weapon::orks_kill_rig_eavy_lobba, 0)
    equip_weapon(model, Weapon::orks_kill_rig_stikka_kannon, 0)
    equip_weapon(model, Weapon::orks_kill_rig_wurrtower, 0)
    equip_weapon(model, Weapon::orks_kill_rig_butcha_boyz, 0)
    equip_weapon(model, Weapon::orks_kill_rig_savage_horns_and_hooves, 0)
    equip_weapon(model, Weapon::orks_kill_rig_saw_blades, 0)
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
        let primary_profile_65 = model.weapons.size() + 1
        equip_weapon(model, Weapon::orks_kan_blasta_dakka, 0)
        equip_weapon(model, Weapon::orks_kan_blasta_kill_shot, primary_profile_65)
        equip_weapon(model, Weapon::orks_kan_blasta_point_blank, primary_profile_65)
        equip_weapon(model, Weapon::orks_kan_klaw, 0)
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
        equip_weapon(model, Weapon::orks_kommandos_slugga, 0)
        if item_index == 0 and item.nob_melee.value == Weapon::orks_infantry_big_choppa.value:
            equip_weapon(model, Weapon::orks_kommandos_big_choppa, 0)
        else:
            if item_index == 0 and item.nob_melee.value == Weapon::orks_power_klaw.value:
                equip_weapon(model, Weapon::orks_kommandos_power_klaw, 0)
            else:
                if item.breacha_ram:
                    equip_weapon(model, Weapon::orks_kommandos_breacha_ram, 0)
                else:
                    equip_weapon(model, Weapon::orks_kommandos_choppa, 0)
        if item.burna:
            equip_weapon(model, Weapon::orks_kommandos_burna, 0)
        if item.rokkit:
            let primary_profile_72 = model.weapons.size() + 1
            equip_weapon(model, Weapon::orks_kommandos_rokkit_launcha_blasta, 0)
            equip_weapon(model, Weapon::orks_kommandos_rokkit_launcha_busta, primary_profile_72)
        if item.kustom_shoota:
            equip_weapon(model, Weapon::orks_kommandos_kustom_shoota, 0)
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
        equip_weapon(model, equipment[index].melee, 0)
        if equipment[index].gun.value != Weapon::none.value:
            let primary = model.weapons.size() + 1
            equip_weapon(model, equipment[index].gun, 0)
            if equipment[index].gun.value == Weapon::orks_meganobz_kustom_shoota_aimed.value:
                equip_weapon(model, Weapon::orks_meganobz_kustom_shoota_point_blank, primary)
            else:
                equip_weapon(model, Weapon::orks_meganobz_kombi_weapon_kill_shot, primary)
                equip_weapon(model, Weapon::orks_meganobz_kombi_weapon_point_blank, primary)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::meganobz)
    return unit

# Standard loadouts are a convenience over the complete independent choices.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
fun make_orks_meganobz(Int count) -> Unit:
    assert(count >= 2 and count <= 6, "invalid Meganob count")
    let equipment : OrksMeganobLoadouts
    for member in range(count):
        equipment.append(orks_meganob_loadout_choice(0))
    return make_orks_meganobz(equipment)

# https://wahapedia.ru/wh40k11ed/factions/orks/Mek
fun make_orks_mek() -> Unit:
    let model = make_orks_model(Profile::orks_mek, OrksDatasheet::mek)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::explosives)
    model.abilities.append(AbilityKind::kustom_dakka)
    model.abilities.append(AbilityKind::clever_know_wotz)
    equip_weapon(model, Weapon::orks_mek_kustom_mega_slugga, 0)
    equip_weapon(model, Weapon::orks_mek_mek_s_toolz, 0)
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
        assert(weapon_allowed(guns[item_index], orks_mek_gun_choices()), "invalid Mek Gun replacement")
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
        equip_weapon(model, guns[item_index], 0)
        equip_weapon(model, Weapon::orks_mek_gunz_scavenged_shivs, 0)
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
        equip_weapon(model, Weapon::orks_morkanaut_dual_big_shoota, 0)
    equip_weapon(model, Weapon::orks_morkanaut_kustom_mega_blasta, 0)
    equip_weapon(model, Weapon::orks_morkanaut_kustom_mega_zappa, 0)
    assert((2) >= 0 and (2) <= 5, "invalid physical weapon count")
    for weapon_copy_4 in range(2):
        let primary_profile_84 = model.weapons.size() + 1
        equip_weapon(model, Weapon::orks_morkanaut_rokkit_launcha_blasta, 0)
        equip_weapon(model, Weapon::orks_morkanaut_rokkit_launcha_busta, primary_profile_84)
    equip_weapon(model, Weapon::orks_morkanaut_klaw_of_mork, 0)
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
    equip_weapon(model, Weapon::orks_thump_gun, 0)
    equip_weapon(model, Weapon::orks_big_chompa_jaws, 0)
    let primary_profile_86 = model.weapons.size() + 1
    equip_weapon(model, Weapon::orks_gutrippa_standard, 0)
    equip_weapon(model, Weapon::orks_gutrippa_hunter, primary_profile_86)
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
    let primary_profile_87 = model.weapons.size() + 1
    equip_weapon(model, Weapon::orks_nazdreg_kustom_blasta_x_gatler, 0)
    equip_weapon(model, Weapon::orks_nazdreg_kustom_blasta_x_shoota, primary_profile_87)
    equip_weapon(model, Weapon::orks_nazdreg_kustom_blasta_x_skorcha, primary_profile_87)
    equip_weapon(model, Weapon::orks_nazdreg_kustom_blasta_x, primary_profile_87)
    equip_weapon(model, Weapon::orks_nazdreg_moonchewa, 0)
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
        equipment.append(Weapon::orks_kustom_shoota)
    return make_orks_nobz(equipment)

# https://wahapedia.ru/wh40k11ed/factions/orks/Painboss
fun make_orks_painboss() -> Unit:
    let model = make_orks_model(Profile::orks_painboss, OrksDatasheet::painboss)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::beast_snagga)
    model.abilities.append(AbilityKind::push_dat_bit_back_in)
    model.abilities.append(AbilityKind::hardy_bioniks)
    equip_weapon(model, Weapon::orks_painboss_beast_snagga_klaw, 0)
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
    equip_weapon(model, Weapon::orks_painboy_urty_syringe, 0)
    equip_weapon(model, Weapon::orks_painboy_dok_s_toolz, 0)
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

    equip_weapon(model, Weapon::orks_rukkatrukk_squigbuggies_sawn_off_shotgun, 0)
    equip_weapon(model, Weapon::orks_rukkatrukk_squigbuggies_squig_launchas, 0)
    equip_weapon(model, Weapon::orks_rukkatrukk_squigbuggies_saw_blades, 0)
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
    equip_weapon(model, Weapon::orks_runtherd_slugga, 0)
    equip_weapon(model, Weapon::orks_runtherd_runtherd_s_toolz, 0)
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
        equip_weapon(model, Weapon::orks_stompa_big_shoota, 0)
    equip_weapon(model, Weapon::orks_stompa_deffkannon_and_supa_rokkits, 0)
    equip_weapon(model, Weapon::orks_stompa_skorcha, 0)
    let primary_profile_95 = model.weapons.size() + 1
    equip_weapon(model, Weapon::orks_stompa_supa_gatler_aimed, 0)
    equip_weapon(model, Weapon::orks_stompa_supa_gatler_point_blank, primary_profile_95)
    equip_weapon(model, Weapon::orks_stompa_mega_choppa, 0)
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
        equip_weapon(model, Weapon::orks_slugga, 0)
        let melee = Weapon::orks_choppa_standard
        if index == 0:
            melee = Weapon::orks_kustom_choppa
            if klaw:
                melee = Weapon::orks_power_klaw
        equip_weapon(model, melee, 0)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::stormboyz)
    return unit

# A Nob replaces one of his TWO pistols. Pulsa is equipment, not a gun profile.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun make_orks_tankbustas(Bool nob_hammer, Weapon extra, Int extra_member) -> Unit:
    assert(weapon_allowed(extra, orks_tankbusta_extra_choices()) and extra_member >= 0 and extra_member < 5, "invalid Tankbusta equipment")
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
            equip_weapon(model, Weapon::orks_tankbustas_choppa, 0)
            equip_weapon(model, Weapon::orks_tankbustas_rokkit_pistol, 0)
            if nob_hammer:
                let primary_profile_97 = model.weapons.size() + 1
                equip_weapon(model, Weapon::orks_tankbustas_smash_hammer_standard, 0)
                equip_weapon(model, Weapon::orks_tankbustas_smash_hammer_hunter, primary_profile_97, orks_monster_vehicle_rule(WeaponRuleKind::anti, 0))
            else:
                equip_weapon(model, Weapon::orks_tankbustas_rokkit_pistol, 0)
        else:
            equip_weapon(model, Weapon::orks_tankbustas_gitstikka, 0)
            let primary_profile_98 = model.weapons.size() + 1
            equip_weapon(model, Weapon::orks_tankbustas_busta_rokkit_launcha_standard, 0)
            equip_weapon(model, Weapon::orks_tankbustas_busta_rokkit_launcha_hunter, primary_profile_98, orks_monster_vehicle_rule(WeaponRuleKind::anti, 0))
            if index - 1 == extra_member:
                if extra.value == Weapon::orks_tankbustas_busta_rokkit_launcha_standard.value:
                    let primary_profile_99 = model.weapons.size() + 1
                    equip_weapon(model, Weapon::orks_tankbustas_busta_rokkit_launcha_standard, 0)
                    equip_weapon(model, Weapon::orks_tankbustas_busta_rokkit_launcha_hunter, primary_profile_99, orks_monster_vehicle_rule(WeaponRuleKind::anti, 0))
                if extra.value == Weapon::orks_pulsa_rokkit.value:
                    equip_weapon(model, extra, 0)
                    model.abilities.append(AbilityKind::pulsa_rokkit)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::tankbustas)
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Trukk: equipment/composition.
fun make_orks_trukk(Int hull_mm, Bool rokkit, Weapon extra) -> Unit:
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
    assert(weapon_allowed(extra, orks_trukk_extra_choices()), "invalid Trukk extra")
    if rokkit:
        let primary_profile_100 = model.weapons.size() + 1
        equip_weapon(model, Weapon::orks_trukk_rokkit_launcha_blasta, 0)
        equip_weapon(model, Weapon::orks_trukk_rokkit_launcha_busta, primary_profile_100)
    else:
        equip_weapon(model, Weapon::orks_trukk_dual_big_shoota, 0)
    equip_weapon(model, Weapon::orks_trukk_spiked_ram, 0)
    if extra.value == orks_trukk_extra_choice(1).value:
        equip_weapon(model, Weapon::orks_trukk_buzzsaw, 0)
    if extra.value == orks_trukk_extra_choice(2).value:
        equip_weapon(model, Weapon::orks_trukk_grabbin_klaw, 0)
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
            let primary_profile_105 = model.weapons.size() + 1
            equip_weapon(model, Weapon::orks_dual_kombi_rokkit_dakkagun, 0)
            equip_weapon(model, Weapon::orks_dual_kombi_rokkit_busta, primary_profile_105)
            equip_weapon(model, Weapon::orks_kustom_choppa, 0)
        else:
            equip_weapon(model, Weapon::orks_dual_dakkagun, 0)
            equip_weapon(model, Weapon::orks_choppa_standard, 0)
        unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::warbikers)
    return unit

# Warboss variants have their own A/WS/S and Cleave; never reuse Nob stats.
# Boss Ammo Runt applies only to the bearer; Intimidating Motivation uses112.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
fun make_orks_warboss(Bool klaw, Weapon gun) -> Unit:
    assert(weapon_allowed(gun, orks_nob_gun_choices()) and gun.value != Weapon::none.value, "Warboss must retain a permitted gun")
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
        equip_weapon(model, Weapon::orks_warboss_power_klaw, 0)
    else:
        equip_weapon(model, Weapon::orks_warboss_kustom_choppa, 0)
    equip_orks_nob_gun(model, gun)
    unit.models.append(model)
    finalize_orks_unit(unit, OrksDatasheet::warboss)
    return unit

# Literal default Warboss armament; replacements are the overload above.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
fun make_orks_warboss() -> Unit:
    return make_orks_warboss(false, Weapon::orks_kustom_shoota)

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
    equip_weapon(model, Weapon::orks_warboss_in_mega_armour_big_shoota, 0)
    equip_weapon(model, Weapon::orks_warboss_in_mega_armour_uge_choppa, 0)
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
            let primary_profile_106 = model.weapons.size() + 1
            equip_weapon(model, Weapon::orks_warbuggies_rivet_kannon_aimed, 0)
            equip_weapon(model, Weapon::orks_warbuggies_rivet_kannon_point_blank, primary_profile_106)
        else:
            let primary_profile_107 = model.weapons.size() + 1
            equip_weapon(model, Weapon::orks_warbuggies_mek_speshul_aimed, 0)
            equip_weapon(model, Weapon::orks_warbuggies_mek_speshul_point_blank, primary_profile_107)
        equip_weapon(model, Weapon::orks_warbuggies_extra_dakka, 0)
        equip_weapon(model, Weapon::orks_warbuggies_spiked_ram, 0)
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

    equip_weapon(model, Weapon::orks_wartrakks_kustom_shoota, 0)
    equip_weapon(model, Weapon::orks_wartrakks_multi_busta_launcha, 0)
    equip_weapon(model, Weapon::orks_wartrakks_kustom_choppa, 0)
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
        equip_weapon(model, Weapon::orks_wazbom_blastajet_dual_supa_shoota, 0)
    if tellyport:
        equip_weapon(model, Weapon::orks_wazbom_blastajet_dual_tellyport_mega_blasta, 0)
    if !tellyport:
        equip_weapon(model, Weapon::orks_wazbom_blastajet_dual_wazbom_mega_kannon, 0)
    equip_weapon(model, Weapon::orks_wazbom_blastajet_smasha_gun, 0)
    equip_weapon(model, Weapon::orks_wazbom_blastajet_armoured_impact, 0)
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

    let primary_profile_118 = model.weapons.size() + 1
    equip_weapon(model, Weapon::orks_wazdakka_gutsmek_grabba_dragga_ranged, 0)
    equip_weapon(model, Weapon::orks_wazdakka_gutsmek_grabba_dragga_melee, primary_profile_118)
    equip_weapon(model, Weapon::orks_wazdakka_gutsmek_psyko_gatler, 0)
    equip_weapon(model, Weapon::orks_wazdakka_gutsmek_speeding_bulk_and_flaming_exhaust, 0)
    equip_weapon(model, Weapon::orks_wazdakka_gutsmek_fixit_s_wrench, 0)
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

    equip_weapon(model, Weapon::orks_weirdboy_power_vomit, 0)
    equip_weapon(model, Weapon::orks_weirdboy_copper_staff, 0)
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
    equip_weapon(model, Weapon::orks_zodgrod_wortsnagga_squigstoppa, 0)
    equip_weapon(model, Weapon::orks_zodgrod_wortsnagga_da_grabzappa, 0)
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
            valid = valid and item.boy_gun.value == Weapon::orks_shoota.value and weapon_allowed(item.melee, orks_nob_melee_choices()) and weapon_allowed(item.nob_gun, orks_nob_gun_choices())
            valid = valid and ((item.melee.value == Weapon::orks_infantry_big_choppa.value and item.nob_gun.value == Weapon::none.value) or (item.melee.value != Weapon::orks_infantry_big_choppa.value and item.nob_gun.value != Weapon::none.value))
        else:
            boys = boys + 1
            let choice = weapon_choice_index(item.boy_gun, orks_boy_gun_choices())
            valid = valid and item.melee.value == Weapon::orks_kustom_choppa.value and item.nob_gun.value == Weapon::orks_kombi_skorcha_shoota.value and choice >= 0
            if choice >= 0:
                specials[choice] = specials[choice] + 1
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
        equip_weapon(model, item.melee, 0)
        equip_orks_nob_gun(model, item.nob_gun)
    else:
        equip_weapon(model, Weapon::orks_choppa_standard, 0)
        equip_weapon(model, Weapon::orks_slugga, 0)
        let primary = model.weapons.size() + 1
        equip_weapon(model, item.boy_gun, 0)
        if item.boy_gun.value == Weapon::orks_rokkit_launcha_blasta.value:
            equip_weapon(model, Weapon::orks_rokkit_launcha_busta, primary)
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
            valid = valid and !item.burna and !item.rokkit and !item.breacha_ram and !item.kustom_shoota and weapon_allowed(item.nob_melee, orks_nob_melee_choices())
        else:
            valid = valid and item.nob_melee.value == Weapon::orks_kustom_choppa.value
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
        ref pair = equipment[index]
        let twin = pair.melee.value == Weapon::orks_meganobz_twin_killsaws.value
        let ordinary = (pair.melee.value == Weapon::orks_meganobz_power_klaw.value or pair.melee.value == Weapon::orks_meganobz_killsaw.value) and (pair.gun.value == Weapon::orks_meganobz_kustom_shoota_aimed.value or pair.gun.value == Weapon::orks_meganobz_kombi_weapon_shoota.value)
        valid = valid and ((twin and pair.gun.value == Weapon::none.value) or (!twin and ordinary))
    return valid

# Paired Krumpas is equipment granting rerolls to Kustom Krumpa, not another
# melee profile. Heavy replacements remove both standard weapon slots.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
fun orks_nob_model(Weapon equipment) -> Model:
    let model = make_orks_model(Profile::orks_nob, OrksDatasheet::nobz)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::explosives)
    model.abilities.append(AbilityKind::ammo_runts)
    model.abilities.append(AbilityKind::get_out_da_way)
    let melee = Weapon::orks_kustom_krumpa
    if equipment.value == Weapon::orks_paired_krumpas.value:
        melee = equipment
    if equipment.value == Weapon::orks_big_skorcha.value or equipment.value == Weapon::orks_kustom_big_shoota.value:
        melee = Weapon::orks_kustom_choppa
    if equipment.value == Weapon::orks_infantry_big_choppa.value:
        melee = Weapon::orks_infantry_big_choppa
    equip_weapon(model, melee, 0)
    if equipment.value == Weapon::orks_kustom_shoota.value:
        equip_weapon(model, Weapon::orks_kustom_shoota, 0)
    if equipment.value == Weapon::orks_kombi_rokkit_busta.value:
        equip_orks_nob_gun(model, Weapon::orks_kombi_rokkit_busta)
    if equipment.value == Weapon::orks_big_skorcha.value:
        equip_weapon(model, Weapon::orks_big_skorcha, 0)
    if equipment.value == Weapon::orks_kustom_big_shoota.value:
        equip_weapon(model, Weapon::orks_kustom_big_shoota, 0)
    return model

# Paired Krumpas/each heavy replacement has its own quota per five models;
# they replace the same original slots, so each model has one listed choice.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
fun orks_nobz_loadout_valid(OrksNobLoadouts equipment) -> Bool:
    let valid = equipment.size() >= 5 and equipment.size() <= 10
    let counts : Int[6]
    for index in range(equipment.size()):
        let choice = weapon_choice_index(equipment[index], orks_nob_loadout_choices())
        valid = valid and choice >= 0
        if choice >= 0:
            counts[choice] = counts[choice] + 1
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
    equip_weapon(model, Weapon::orks_slugga, 0)
    if nob:
        assert(!thump_gun, "Thump Gun belongs to a Boy, not a Nob")
        equip_weapon(model, Weapon::orks_power_snappa, 0)
    else:
        let primary_profile_125 = model.weapons.size() + 1
        equip_weapon(model, Weapon::orks_choppa_standard, 0)
        equip_weapon(model, Weapon::orks_choppa_hunter, primary_profile_125)
        model.hunter_profile_conditions[2] = orks_monster_vehicle_rule(WeaponRuleKind::anti, 0)
        if thump_gun:
            equip_weapon(model, Weapon::orks_thump_gun, 0)
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
        equip_weapon(model, Weapon::orks_slugga, 0)
        equip_weapon(model, Weapon::orks_big_choppa, 0)
    else:
        equip_weapon(model, Weapon::orks_saddlegit_shiv, 0)
        let primary_profile_126 = model.weapons.size() + 1
        equip_weapon(model, Weapon::orks_stikka_ranged, 0)
        equip_weapon(model, Weapon::orks_stikka_melee, primary_profile_126)
    equip_weapon(model, Weapon::orks_squig_jaws, 0)
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

# These are printed per-slot alternatives, all drawn from the single Weapon
# catalog. Sources: the corresponding Orks card URLs on the factories below.
# Allowed actual profiles replace the old subset enum; printed Wargear Options.
# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
fun orks_boy_gun_choices() -> WeaponChoices:
    return weapon_choices(Weapon::orks_shoota, Weapon::orks_infantry_big_shoota, Weapon::orks_rokkit_launcha_blasta, Weapon::orks_burna)

# Preserve the finite roster ordinal while constructing actual catalog equipment.
# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
fun orks_boy_gun_choice(Int index) -> Weapon:
    return weapon_choice(orks_boy_gun_choices(), index)

# Allowed actual profiles replace the old subset enum; printed Wargear Options.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
fun orks_dread_arm_choices() -> WeaponChoices:
    return weapon_choices(Weapon::orks_dread_big_shoota, Weapon::orks_skorcha, Weapon::orks_extra_klaw, Weapon::orks_kustom_mega_blasta, Weapon::orks_rokkit_launcha_blasta)

# Preserve the finite roster ordinal while constructing actual catalog equipment.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
fun orks_dread_arm_choice(Int index) -> Weapon:
    return weapon_choice(orks_dread_arm_choices(), index)

# Allowed actual profiles replace the old subset enum; printed Wargear Options.
# https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
fun orks_gunwagon_gun_choices() -> WeaponChoices:
    return weapon_choices(Weapon::orks_gunwagon_kannon_frag, Weapon::orks_gunwagon_killkannon, Weapon::orks_gunwagon_zzap_gun)

# Preserve the finite roster ordinal while constructing actual catalog equipment.
# https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
fun orks_gunwagon_gun_choice(Int index) -> Weapon:
    return weapon_choice(orks_gunwagon_gun_choices(), index)

# Allowed actual profiles replace the old subset enum; printed Wargear Options.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
fun orks_mega_mek_extra_choices() -> WeaponChoices:
    return weapon_choices(Weapon::none, Weapon::orks_big_mek_in_mega_armour_tellyport_blasta, Weapon::orks_kustom_force_field)

# Preserve the finite roster ordinal while constructing actual catalog equipment.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
fun orks_mega_mek_extra_choice(Int index) -> Weapon:
    return weapon_choice(orks_mega_mek_extra_choices(), index)

# Allowed actual profiles replace the old subset enum; printed Wargear Options.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
fun orks_mega_mek_gun_choices() -> WeaponChoices:
    return weapon_choices(Weapon::orks_big_mek_in_mega_armour_kustom_shoota_aimed, Weapon::orks_big_mek_in_mega_armour_killsaw, Weapon::orks_big_mek_in_mega_armour_kombi_weapon_shoota, Weapon::orks_big_mek_in_mega_armour_kustom_mega_blasta)

# Preserve the finite roster ordinal while constructing actual catalog equipment.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
fun orks_mega_mek_gun_choice(Int index) -> Weapon:
    return weapon_choice(orks_mega_mek_gun_choices(), index)

# Allowed actual profiles replace the old subset enum; printed Wargear Options.
# https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
fun orks_mek_gun_choices() -> WeaponChoices:
    return weapon_choices(Weapon::orks_mek_gunz_smasha_gun, Weapon::orks_mek_gunz_bubblechukka, Weapon::orks_mek_gunz_kustom_mega_kannon, Weapon::orks_mek_gunz_traktor_kannon)

# Preserve the finite roster ordinal while constructing actual catalog equipment.
# https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
fun orks_mek_gun_choice(Int index) -> Weapon:
    return weapon_choice(orks_mek_gun_choices(), index)

# Allowed actual profiles replace the old subset enum; printed Wargear Options.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
fun orks_nob_gun_choices() -> WeaponChoices:
    return weapon_choices(Weapon::orks_kombi_skorcha_shoota, Weapon::orks_kombi_rokkit_busta, Weapon::orks_kustom_shoota, Weapon::none)

# Preserve the finite roster ordinal while constructing actual catalog equipment.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
fun orks_nob_gun_choice(Int index) -> Weapon:
    return weapon_choice(orks_nob_gun_choices(), index)

# Allowed actual profiles replace the old subset enum; printed Wargear Options.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
fun orks_nob_loadout_choices() -> WeaponChoices:
    return weapon_choices(Weapon::orks_kustom_shoota, Weapon::orks_kombi_rokkit_busta, Weapon::orks_paired_krumpas, Weapon::orks_big_skorcha, Weapon::orks_kustom_big_shoota, Weapon::orks_infantry_big_choppa)

# Preserve the finite roster ordinal while constructing actual catalog equipment.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
fun orks_nob_loadout_choice(Int index) -> Weapon:
    return weapon_choice(orks_nob_loadout_choices(), index)

# Allowed actual profiles replace the old subset enum; printed Wargear Options.
# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
fun orks_nob_melee_choices() -> WeaponChoices:
    return weapon_choices(Weapon::orks_kustom_choppa, Weapon::orks_power_klaw, Weapon::orks_infantry_big_choppa)

# Preserve the finite roster ordinal while constructing actual catalog equipment.
# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
fun orks_nob_melee_choice(Int index) -> Weapon:
    return weapon_choice(orks_nob_melee_choices(), index)

# Allowed actual profiles replace the old subset enum; printed Wargear Options.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun orks_tankbusta_extra_choices() -> WeaponChoices:
    return weapon_choices(Weapon::none, Weapon::orks_tankbustas_busta_rokkit_launcha_standard, Weapon::orks_pulsa_rokkit)

# Preserve the finite roster ordinal while constructing actual catalog equipment.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
fun orks_tankbusta_extra_choice(Int index) -> Weapon:
    return weapon_choice(orks_tankbusta_extra_choices(), index)

# Allowed actual profiles replace the old subset enum; printed Wargear Options.
# https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
fun orks_trukk_extra_choices() -> WeaponChoices:
    return weapon_choices(Weapon::none, Weapon::orks_trukk_buzzsaw, Weapon::orks_trukk_grabbin_klaw)

# Preserve the finite roster ordinal while constructing actual catalog equipment.
# https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
fun orks_trukk_extra_choice(Int index) -> Weapon:
    return weapon_choice(orks_trukk_extra_choices(), index)

# Meganobz replace two independent slots or both with Twin Killsaws.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
fun orks_meganob_loadout_choice(Int index) -> WeaponPair:
    assert(index >= 0 and index < 5, "invalid Meganob equipment choice")
    let gun = Weapon::orks_meganobz_kustom_shoota_aimed
    let melee = Weapon::orks_meganobz_power_klaw
    if index == 1 or index == 3:
        melee = Weapon::orks_meganobz_killsaw
    if index >= 2:
        gun = Weapon::orks_meganobz_kombi_weapon_shoota
    if index == 4:
        gun = Weapon::none
        melee = Weapon::orks_meganobz_twin_killsaws
    return weapon_pair(gun, melee)

# Generated lifecycle leaves Weapon enums at their catalog default, which is
# not a datasheet default. Set each slot explicitly instead of custom init.
fun orks_boy_loadout() -> OrksBoyzLoadout:
    let item : OrksBoyzLoadout
    item.melee = Weapon::orks_kustom_choppa
    item.nob_gun = Weapon::orks_kombi_skorcha_shoota
    item.boy_gun = Weapon::orks_shoota
    return item

# Explicit default Nob melee equipment; generated enum defaults do not infer
# the Kommandos card's loadout (Orks/Kommandos, Unit Composition).
fun orks_kommando_equipment() -> OrksKommandoEquipment:
    let item : OrksKommandoEquipment
    item.nob_melee = Weapon::orks_kustom_choppa
    return item
