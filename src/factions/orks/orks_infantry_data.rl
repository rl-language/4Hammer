import factions.orks.orks_unit_data

# Finite per-model muster choices encode the printed replacements, not prices.
# Sources: Orks/Boyz, Nobz, Warboss and Deff-Dread (11th-edition version1.2).
enum OrksNobMeleeChoice:
    kustom_choppa
    power_klaw
    big_choppa

enum OrksNobGunChoice:
    kombi_skorcha
    kombi_rokkit
    kustom_shoota
    none

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

enum OrksNobLoadout:
    standard
    kombi_rokkit
    paired_krumpas
    big_skorcha
    kustom_big_shoota
    big_choppa

using OrksNobLoadouts = CheckedVector<OrksNobLoadout, MAX_UNIT_MODELS>

enum OrksDreadArmChoice:
    big_shoota
    skorcha
    extra_klaw
    kustom_mega_blasta
    rokkit_launcha

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

# Boy models retain Slugga/Choppa when replacing their Shoota; the Nob has
# neither of those starting weapons. All rule metadata comes from this card.
# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
fun orks_boyz_model(OrksBoyzLoadout item) -> Model:
    let profile = Profile::orks_boy
    if item.nob:
        profile = Profile::orks_boyz_nob
    let model = orks_current_model(profile, OrksDatasheet::boyz)
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

# Full per-model equipment permits mixed Nob choices and independent Boy
# quotas; counts follow the literal1–2/9–18 ranges, not priced10/20 tiers.
# https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
fun make_orks_boyz(OrksBoyzLoadouts equipment) -> Unit:
    assert(orks_boyz_loadout_valid(equipment), "illegal Boyz composition/loadout")
    let unit : Unit
    unit.name = "Boyz"s
    for index in range(equipment.size()):
        unit.models.append(orks_boyz_model(equipment[index]))
    configure_orks_attachment(unit, OrksDatasheet::boyz)
    unit.capture_starting_strength()
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

# Paired Krumpas is equipment granting rerolls to Kustom Krumpa, not another
# melee profile. Heavy replacements remove both standard weapon slots.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
fun orks_nob_model(OrksNobLoadout equipment) -> Model:
    let model = orks_current_model(Profile::orks_nob, OrksDatasheet::nobz)
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

# Every printed5–10-model composition/valid mixed replacement is supported.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
fun make_orks_nobz(OrksNobLoadouts equipment) -> Unit:
    assert(orks_nobz_loadout_valid(equipment), "illegal Nobz composition/loadout")
    let unit : Unit
    unit.name = "Nobz"s
    for index in range(equipment.size()):
        unit.models.append(orks_nob_model(equipment[index]))
    configure_orks_attachment(unit, OrksDatasheet::nobz)
    unit.capture_starting_strength()
    return unit

# Standard Nobz retain all Kustom Krumpas/Shootas and actual card abilities.
# https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
fun make_orks_nobz(Int count) -> Unit:
    assert(count >= 5 and count <= 10, "illegal Nobz count")
    let equipment : OrksNobLoadouts
    for index in range(count):
        equipment.append(OrksNobLoadout::standard)
    return make_orks_nobz(equipment)

# Warboss variants have their own A/WS/S and Cleave; never reuse Nob stats.
# Boss Ammo Runt applies only to the bearer; Intimidating Motivation uses112.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
fun make_orks_warboss(Bool klaw, OrksNobGunChoice gun) -> Unit:
    assert(gun.value >= 0 and gun.value < 3, "Warboss must retain a permitted gun")
    let unit : Unit
    unit.name = "Warboss"s
    let model = orks_current_model(Profile::orks_warboss, OrksDatasheet::warboss)
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
    configure_orks_attachment(unit, OrksDatasheet::warboss)
    unit.capture_starting_strength()
    return unit

# Literal default Warboss armament; replacements are the overload above.
# https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
fun make_orks_warboss() -> Unit:
    return make_orks_warboss(false, OrksNobGunChoice::kustom_shoota)

# Support model uses its Precision Big Choppa and unit-wide melee hit rule.
# https://wahapedia.ru/wh40k11ed/factions/orks/Bigboss
fun make_orks_bigboss() -> Unit:
    let unit : Unit
    unit.name = "Bigboss"s
    let model = orks_current_model(Profile::orks_bigboss, OrksDatasheet::bigboss)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.abilities.append(AbilityKind::sumfin_to_prove)
    equip_orks_profile(model, Weapon::orks_slugga, NamedWeaponProfile::slugga, 0)
    equip_orks_profile(model, Weapon::orks_bigboss_big_choppa, NamedWeaponProfile::big_choppa, 0)
    unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::bigboss)
    unit.capture_starting_strength()
    return unit

# Waaagh! Banner confers+1 charge through current unit source membership.
# The separate raw HTML box supplies its5+ InSv, omitted by text extraction.
# https://wahapedia.ru/wh40k11ed/factions/orks/Bannernob
fun make_orks_bannernob() -> Unit:
    let unit : Unit
    unit.name = "Bannernob"s
    let model = orks_current_model(Profile::orks_bannernob, OrksDatasheet::bannernob)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.abilities.append(AbilityKind::waaagh_banner)
    equip_orks_profile(model, Weapon::orks_shoota, NamedWeaponProfile::shoota, 0)
    equip_orks_profile(model, Weapon::orks_kustom_choppa, NamedWeaponProfile::kustom_choppa, 0)
    unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::bannernob)
    unit.capture_starting_strength()
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
        let model = orks_current_model(profile, OrksDatasheet::stormboyz)
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
    configure_orks_attachment(unit, OrksDatasheet::stormboyz)
    unit.capture_starting_strength()
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
        let model = orks_current_model(profile, OrksDatasheet::warbikers)
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
    configure_orks_attachment(unit, OrksDatasheet::warbikers)
    unit.capture_starting_strength()
    return unit

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

# The Big Shoota arm cannot take Skorcha; the Skorcha arm can take Big Shoota.
# Dread 'Ard enters incoming D arithmetic (both attack types); demise is fixed1.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
fun make_orks_deff_dread(OrksDreadArmChoice first, OrksDreadArmChoice second) -> Unit:
    assert(first.value >= 0 and first.value < 5 and first.value != OrksDreadArmChoice::skorcha.value and second.value >= 0 and second.value < 5, "illegal Deff Dread arms")
    let unit : Unit
    unit.name = "Deff Dread"s
    let model = orks_current_model(Profile::orks_deff_dread, OrksDatasheet::deff_dread)
    model.keywords.append(Keyword::vehicle)
    model.keywords.append(Keyword::walker)
    model.has_deadly_demise = true
    model.deadly_demise = raw_stat(1)
    model.incoming_attack_modifiers.append(incoming_attack_modifier(ModifiedCharacteristic::damage, ModifierOperation::add, -1, IncomingAttackScope::any_attack))
    equip_orks_profile(model, Weapon::orks_dread_klaws, NamedWeaponProfile::dread_klaws, 0)
    equip_orks_dread_arm(model, first, 1)
    equip_orks_dread_arm(model, second, 2)
    unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::deff_dread)
    unit.capture_starting_strength()
    return unit

# Standard printed Dread: one Big Shoota, one Skorcha and Dread Klaws.
# https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
fun make_orks_deff_dread() -> Unit:
    return make_orks_deff_dread(OrksDreadArmChoice::big_shoota, OrksDreadArmChoice::skorcha)

# Every Kan has three alternate profiles of ONE Kan Blasta plus its Kan Klaw;
# GROTS is a keyword distinct from the Gretchin datasheet identity.
# https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
fun make_orks_killa_kans(Int count) -> Unit:
    assert(count >= 3 and count <= 6, "illegal Killa Kan count")
    let unit : Unit
    unit.name = "Killa Kans"s
    for index in range(count):
        let model = orks_current_model(Profile::orks_killa_kan, OrksDatasheet::killa_kans)
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
    configure_orks_attachment(unit, OrksDatasheet::killa_kans)
    unit.capture_starting_strength()
    return unit

# Dakkarig has no Leader/Da Boss; its riled ranged rule and target-specific
# Blitzkannon A are evaluated at actual declaration/gathering windows.
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-Dakkarig
fun make_orks_big_mek_dakkarig() -> Unit:
    let unit : Unit
    unit.name = "Big Mek Dakkarig"s
    let model = orks_current_model(Profile::orks_big_mek_dakkarig, OrksDatasheet::big_mek_dakkarig)
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
    configure_orks_attachment(unit, OrksDatasheet::big_mek_dakkarig)
    unit.capture_starting_strength()
    return unit

# Standard/Hunter share one Beastchoppa; Hunter permits MONSTER/VEHICLE only.
# Keep Huntin' reuses110; Stampede and conditional Lone Operative stay live.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur
fun make_orks_beastboss_on_squigosaur(Bool thump_gun) -> Unit:
    let unit : Unit
    unit.name = "Beastboss on Squigosaur"s
    let model = orks_current_model(Profile::orks_beastboss_on_squigosaur, OrksDatasheet::beastboss_on_squigosaur)
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
    configure_orks_attachment(unit, OrksDatasheet::beastboss_on_squigosaur)
    unit.capture_starting_strength()
    return unit

# Epic Hero has a4+ printed InSv; Gutrippa Hunter is D6+1, not modified D6.
# One Last Kill rolls at destruction through the common delayed-fight kernel.
# https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad
fun make_orks_mozrog_skragbad() -> Unit:
    let unit : Unit
    unit.name = "Mozrog Skragbad"s
    let model = orks_current_model(Profile::orks_mozrog_skragbad, OrksDatasheet::mozrog_skragbad)
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
    configure_orks_attachment(unit, OrksDatasheet::mozrog_skragbad)
    unit.capture_starting_strength()
    return unit
