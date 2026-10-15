import factions.orks.orks_infantry_data

# Big Mek in Mega Armour's independent replacement and optional extra slots.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
enum OrksMegaMekGun:
    kustom_shoota
    killsaw
    kombi_weapon
    mega_blasta

enum OrksMegaMekExtra:
    none
    tellyport_blasta
    force_field

# Current source metadata; no pricing, inferred hull geometry or legacy grants.
# All fourteen source bases in this module are circles (card URLs below).
fun orks_elite_bearer(Profile profile, OrksDatasheet tag, Bool character) -> Model:
    let model = orks_current_model(profile, tag)
    model.keywords.append(Keyword::infantry)
    if character:
        model.keywords.append(Keyword::character)
    return model

# Capture the actual starting component and printed attachment permissions.
# Source cards' Unit Composition/Leader/Support; core pp66/86.
fun finish_orks_elite_unit(Model model, String name, OrksDatasheet tag) -> Unit:
    let unit : Unit
    unit.name = name
    unit.models.append(model)
    configure_orks_attachment(unit, tag)
    unit.capture_starting_strength()
    return unit

# Alternate profiles share a physical group; Hunter applies only to the
# selected target, not to unrelated attacks (appendix04.01.03).
fun equip_orks_elite_profile(Model model, Weapon weapon, NamedWeaponProfile name, Int group, Bool hunter):
    let slot = model.weapons.size()
    equip_orks_profile(model, weapon, name, group)
    if hunter:
        model.hunter_profile_conditions[slot] = orks_monster_vehicle_rule(WeaponRuleKind::anti, 0)

# https://wahapedia.ru/wh40k11ed/factions/orks/Mek
fun make_orks_mek() -> Unit:
    let model = orks_elite_bearer(Profile::orks_mek, OrksDatasheet::mek, true)
    model.keywords.append(Keyword::explosives)
    model.abilities.append(AbilityKind::kustom_dakka)
    model.abilities.append(AbilityKind::clever_know_wotz)
    equip_orks_profile(model, Weapon::orks_mek_kustom_mega_slugga, NamedWeaponProfile::kustom_mega_slugga, 0)
    equip_orks_profile(model, Weapon::orks_mek_mek_s_toolz, NamedWeaponProfile::mek_s_toolz, 0)
    return finish_orks_elite_unit(model, "Mek"s, OrksDatasheet::mek)

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
fun make_orks_big_mek(Bool drilla, Bool traktor) -> Unit:
    let model = orks_elite_bearer(Profile::orks_big_mek, OrksDatasheet::big_mek, true)
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
    return finish_orks_elite_unit(model, "Big Mek"s, OrksDatasheet::big_mek)

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
fun make_orks_big_mek_in_mega_armour(OrksMegaMekGun gun, OrksMegaMekExtra extra) -> Unit:
    let model = orks_elite_bearer(Profile::orks_big_mek_in_mega_armour, OrksDatasheet::big_mek_in_mega_armour, true)
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
    return finish_orks_elite_unit(model, "Big Mek In Mega Armour"s, OrksDatasheet::big_mek_in_mega_armour)

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun
fun make_orks_big_mek_with_shokk_attack_gun() -> Unit:
    let model = orks_elite_bearer(Profile::orks_big_mek_with_shokk_attack_gun, OrksDatasheet::big_mek_with_shokk_attack_gun, true)
    model.keywords.append(Keyword::big_mek)
    model.keywords.append(Keyword::explosives)
    model.abilities.append(AbilityKind::more_dakka)
    model.abilities.append(AbilityKind::support_shokka)
    equip_orks_profile(model, Weapon::orks_big_mek_with_shokk_attack_gun_shokk_attack_gun, NamedWeaponProfile::shokk_attack_gun, 0)
    equip_orks_profile(model, Weapon::orks_big_mek_with_shokk_attack_gun_big_mek_s_toolz, NamedWeaponProfile::big_mek_s_toolz, 0)
    return finish_orks_elite_unit(model, "Big Mek With Shokk Attack Gun"s, OrksDatasheet::big_mek_with_shokk_attack_gun)

# https://wahapedia.ru/wh40k11ed/factions/orks/Painboy
fun make_orks_painboy() -> Unit:
    let model = orks_elite_bearer(Profile::orks_painboy, OrksDatasheet::painboy, true)
    model.abilities.append(AbilityKind::crude_surgery)
    model.abilities.append(AbilityKind::catch_dat_red_bit)
    equip_orks_profile(model, Weapon::orks_painboy_urty_syringe, NamedWeaponProfile::urty_syringe, 0)
    equip_orks_profile(model, Weapon::orks_painboy_dok_s_toolz, NamedWeaponProfile::dok_s_toolz, 0)
    return finish_orks_elite_unit(model, "Painboy"s, OrksDatasheet::painboy)

# https://wahapedia.ru/wh40k11ed/factions/orks/Painboss
fun make_orks_painboss() -> Unit:
    let model = orks_elite_bearer(Profile::orks_painboss, OrksDatasheet::painboss, true)
    model.keywords.append(Keyword::beast_snagga)
    model.abilities.append(AbilityKind::push_dat_bit_back_in)
    model.abilities.append(AbilityKind::hardy_bioniks)
    equip_orks_profile(model, Weapon::orks_painboss_beast_snagga_klaw, NamedWeaponProfile::beast_snagga_klaw, 0)
    return finish_orks_elite_unit(model, "Painboss"s, OrksDatasheet::painboss)

# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
fun make_orks_warboss_in_mega_armour() -> Unit:
    let model = orks_elite_bearer(Profile::orks_warboss_in_mega_armour, OrksDatasheet::warboss_in_mega_armour, true)
    model.keywords.append(Keyword::mega_armour)
    model.keywords.append(Keyword::warboss)
    model.transport_space = 2
    model.has_da_boss = true
    model.abilities.append(AbilityKind::krushin_impetus)
    model.abilities.append(AbilityKind::intimidating_motivation)
    equip_orks_profile(model, Weapon::orks_warboss_in_mega_armour_big_shoota, NamedWeaponProfile::big_shoota, 0)
    equip_orks_profile(model, Weapon::orks_warboss_in_mega_armour_uge_choppa, NamedWeaponProfile::uge_choppa, 0)
    return finish_orks_elite_unit(model, "Warboss In Mega Armour"s, OrksDatasheet::warboss_in_mega_armour)

# https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
fun make_orks_runtherd() -> Unit:
    let model = orks_elite_bearer(Profile::orks_runtherd, OrksDatasheet::runtherd, true)
    model.abilities.append(AbilityKind::thatll_learn_ya)
    equip_orks_profile(model, Weapon::orks_runtherd_slugga, NamedWeaponProfile::slugga, 0)
    equip_orks_profile(model, Weapon::orks_runtherd_runtherd_s_toolz, NamedWeaponProfile::runtherd_s_toolz, 0)
    return finish_orks_elite_unit(model, "Runtherd"s, OrksDatasheet::runtherd)

# https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga
fun make_orks_zodgrod_wortsnagga() -> Unit:
    let model = orks_elite_bearer(Profile::orks_zodgrod_wortsnagga, OrksDatasheet::zodgrod_wortsnagga, true)
    model.keywords.append(Keyword::epic_hero)
    model.keywords.append(Keyword::runtherd)
    model.grants_unit_riled_up = true
    model.abilities.append(AbilityKind::super_runts)
    equip_orks_profile(model, Weapon::orks_zodgrod_wortsnagga_squigstoppa, NamedWeaponProfile::squigstoppa, 0)
    equip_orks_profile(model, Weapon::orks_zodgrod_wortsnagga_da_grabzappa, NamedWeaponProfile::da_grabzappa, 0)
    return finish_orks_elite_unit(model, "Zodgrod Wortsnagga"s, OrksDatasheet::zodgrod_wortsnagga)

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
        let model = orks_elite_bearer(profile, OrksDatasheet::flash_gitz, false)
        model.keywords.append(Keyword::explosives)
        model.abilities.append(AbilityKind::finderz_keeperz)
        equip_orks_profile(model, Weapon::orks_flash_gitz_snazzgun_cutta, NamedWeaponProfile::snazzgun_cutta, 1)
        equip_orks_profile(model, Weapon::orks_flash_gitz_snazzgun_dakka, NamedWeaponProfile::snazzgun_dakka, 1)
        equip_orks_profile(model, Weapon::orks_flash_gitz_snazzgun_kill_shot, NamedWeaponProfile::snazzgun_kill_shot, 1)
        equip_orks_profile(model, Weapon::orks_flash_gitz_choppa, NamedWeaponProfile::choppa, 0)
        unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::flash_gitz)
    unit.capture_starting_strength()
    return unit

# Independent replacements versus the combined Twin Killsaws replacement.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
enum OrksMeganobLoadout:
    shoota_klaw
    shoota_saw
    kombi_klaw
    kombi_saw
    twin_saws

using OrksMeganobLoadouts = CheckedVector<OrksMeganobLoadout, 6>

# Preserve all printed model counts and per-model choices, not priced tiers.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
fun orks_meganob_loadout_valid(OrksMeganobLoadouts equipment) -> Bool:
    let valid = equipment.size() >= 2 and equipment.size() <= 6
    for index in range(equipment.size()):
        valid = valid and equipment[index].value >= 0 and equipment[index].value <= 4
    return valid

# Each physical ranged gun has one chosen profile; twin saws remove both
# default weapons and remain one melee weapon with Twin-linked.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
fun make_orks_meganobz(OrksMeganobLoadouts equipment) -> Unit:
    assert(orks_meganob_loadout_valid(equipment), "invalid Meganob equipment/count")
    let unit : Unit
    unit.name = "Meganobz"s
    for index in range(equipment.size()):
        let model = orks_elite_bearer(Profile::orks_meganob, OrksDatasheet::meganobz, false)
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
    configure_orks_attachment(unit, OrksDatasheet::meganobz)
    unit.capture_starting_strength()
    return unit

# Standard loadouts are a convenience over the complete independent choices.
# https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
fun make_orks_meganobz(Int count) -> Unit:
    assert(count >= 2 and count <= 6, "invalid Meganob count")
    let equipment : OrksMeganobLoadouts
    equipment.resize(count)
    return make_orks_meganobz(equipment)

# Indices0-4 name actual Boy models;5 means that replacement was not taken.
# Nob's replacement adds a SECOND pistol and removes his Smash Hammer.
# https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
fun orks_breaka_loadout_valid(Int knuckles, Int tankhammer) -> Bool:
    return knuckles >= 0 and knuckles <= 5 and tankhammer >= 0 and tankhammer <= 5 and (knuckles == 5 or tankhammer == 5 or knuckles != tankhammer)

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
        let model = orks_elite_bearer(profile, OrksDatasheet::breaka_boyz, false)
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
                    equip_orks_elite_profile(model, Weapon::orks_breaka_boyz_smash_hammer_standard, NamedWeaponProfile::smash_hammer_standard, 1, false)
                    equip_orks_elite_profile(model, Weapon::orks_breaka_boyz_smash_hammer_hunter, NamedWeaponProfile::smash_hammer_hunter, 1, true)
        unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::breaka_boyz)
    unit.capture_starting_strength()
    return unit

# The one optional Boy gets another physical launcher OR the Pulsa token.
# https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
enum OrksTankbustaExtra:
    none
    additional_launcher
    pulsa

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
        let model = orks_elite_bearer(profile, OrksDatasheet::tankbustas, false)
        model.keywords.append(Keyword::explosives)
        model.abilities.append(AbilityKind::bomb_squig)
        model.abilities.append(AbilityKind::rokkit_barrage)
        if index == 0:
            equip_orks_profile(model, Weapon::orks_tankbustas_choppa, NamedWeaponProfile::choppa, 0)
            equip_orks_profile(model, Weapon::orks_tankbustas_rokkit_pistol, NamedWeaponProfile::rokkit_pistol, 0)
            if nob_hammer:
                equip_orks_elite_profile(model, Weapon::orks_tankbustas_smash_hammer_standard, NamedWeaponProfile::smash_hammer_standard, 2, false)
                equip_orks_elite_profile(model, Weapon::orks_tankbustas_smash_hammer_hunter, NamedWeaponProfile::smash_hammer_hunter, 2, true)
            else:
                equip_orks_profile(model, Weapon::orks_tankbustas_rokkit_pistol, NamedWeaponProfile::rokkit_pistol, 0)
        else:
            equip_orks_profile(model, Weapon::orks_tankbustas_gitstikka, NamedWeaponProfile::gitstikka, 0)
            equip_orks_elite_profile(model, Weapon::orks_tankbustas_busta_rokkit_launcha_standard, NamedWeaponProfile::busta_rokkit_launcha_standard, 1, false)
            equip_orks_elite_profile(model, Weapon::orks_tankbustas_busta_rokkit_launcha_hunter, NamedWeaponProfile::busta_rokkit_launcha_hunter, 1, true)
            if index - 1 == extra_member:
                if extra.value == OrksTankbustaExtra::additional_launcher.value:
                    equip_orks_elite_profile(model, Weapon::orks_tankbustas_busta_rokkit_launcha_standard, NamedWeaponProfile::busta_rokkit_launcha_standard, 2, false)
                    equip_orks_elite_profile(model, Weapon::orks_tankbustas_busta_rokkit_launcha_hunter, NamedWeaponProfile::busta_rokkit_launcha_hunter, 2, true)
                if extra.value == OrksTankbustaExtra::pulsa.value:
                    model.abilities.append(AbilityKind::pulsa_rokkit)
        unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::tankbustas)
    unit.capture_starting_strength()
    return unit

# Exact10-20 range; models remain individuals, not crew or half-model tokens.
# Downtrodden's grouped seat rounding belongs in transport_rules, not W/OC.
# https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
fun make_orks_gretchin(Int count) -> Unit:
    assert(count >= 10 and count <= 20, "illegal Gretchin count")
    let unit : Unit
    unit.name = "Gretchin"s
    for index in range(count):
        let model = orks_elite_bearer(Profile::orks_gretchin, OrksDatasheet::gretchin, false)
        model.keywords.append(Keyword::grots)
        model.abilities.append(AbilityKind::thievin_scavengers)
        equip_orks_profile(model, Weapon::orks_gretchin_grot_blasta, NamedWeaponProfile::grot_blasta, 0)
        equip_orks_profile(model, Weapon::orks_gretchin_scavenged_shivs, NamedWeaponProfile::scavenged_shivs, 0)
        unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::gretchin)
    unit.capture_starting_strength()
    return unit
