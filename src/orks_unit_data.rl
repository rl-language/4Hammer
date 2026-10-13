import attachment_rules

# Exact composition from the source card; prices do not add a composition
# rule. Optional Thump Guns are extra equipment, limited by total model count.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz
fun orks_snagga_composition_valid(Int nobs, Int boys, Int thump_guns) -> Bool:
    return nobs >= 1 and nobs <= 2 and boys >= 9 and boys <= 18 and thump_guns >= 0 and thump_guns <= (nobs + boys) / 10

# The printed ranges, not the priced4/8 rows, define legal model counts.
# https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
fun orks_squighog_composition_valid(Int nobs, Int boys) -> Bool:
    return nobs >= 1 and nobs <= 2 and boys >= 3 and boys <= 6

# Source adapters set real faction/datasheet/Army Rules metadata. They do not
# grant old Beast Snagga/FNP abilities or infer keywords from a factory name.
# https://wahapedia.ru/wh40k11ed/factions/orks/ (Waaagh!).
fun orks_current_model(Profile profile, OrksDatasheet tag) -> Model:
    let model : Model
    model.profile = profile
    set_model_datasheet(model, tag)
    model.has_waaagh = true
    model.keywords.append(Keyword::orks)
    return model

# One owned slot per printed profile, with a stable physical family/name.
# Multi-profile groups share one weapon (core p16; appendix04.01.03).
fun equip_orks_profile(Model model, Weapon weapon, NamedWeaponProfile name, Int group):
    assert(group >= 0 and group < MAX_WEAPON_SCOPES, "invalid physical weapon group")
    let slot = model.weapons.size()
    model.weapons.append(weapon)
    set_named_weapon_profile(model, slot, name)
    model.weapon_profile_groups[slot] = group

# Current Beastboss profile/equipment/keywords/core Army Rules only; Dodge
# Dis!/Keep Huntin' source adapters are17.H2 before production roster switching.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss
fun make_orks_beastboss() -> Unit:
    let unit : Unit
    unit.name = "Beastboss"s
    let model = orks_current_model(Profile::orks_beastboss, OrksDatasheet::beastboss)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::beast_snagga)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::warboss)
    model.has_da_boss = true
    equip_orks_profile(model, Weapon::orks_beastboss_shoota, NamedWeaponProfile::shoota, 0)
    equip_orks_profile(model, Weapon::orks_beastboss_klaw_and_beastchoppa, NamedWeaponProfile::beast_snagga_klaw_and_beastchoppa, 0)
    unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::beastboss)
    unit.capture_starting_strength()
    return unit

# Every model has the card's full keyword set; only the Nob/Boy profiles and
# equipment differ. 'Battleline' is a unit/model keyword, not a pricing rule.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz
fun orks_snagga_model(Bool nob, Bool thump_gun) -> Model:
    let profile = Profile::orks_beast_snagga_boy
    if nob:
        profile = Profile::orks_beast_snagga_nob
    let model = orks_current_model(profile, OrksDatasheet::beast_snagga_boyz)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::battleline)
    model.keywords.append(Keyword::beast_snagga)
    model.keywords.append(Keyword::mob)
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

# Construct every printed count/optional-loadout choice, retaining the Boy's
# Choppa and Slugga when adding a Thump Gun. Mobbed's hook follows in17.H2.
# https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz
fun make_orks_beast_snagga_boyz(Int nobs, Int boys, Int thump_guns) -> Unit:
    assert(orks_snagga_composition_valid(nobs, boys, thump_guns), "illegal Beast Snagga composition/loadout")
    let unit : Unit
    unit.name = "Beast Snagga Boyz"s
    for nob_index in range(nobs):
        unit.models.append(orks_snagga_model(true, false))
    for boy_index in range(boys):
        unit.models.append(orks_snagga_model(false, boy_index < thump_guns))
    configure_orks_attachment(unit, OrksDatasheet::beast_snagga_boyz)
    unit.capture_starting_strength()
    return unit

# Squighog equipment includes ranged+melee Stikka profiles as one physical
# weapon, and jaws as Extra Attacks. Neither profile has inherited Lance/FNP.
# The source gives75x42/90x52 ovals: keep them unavailable for placement until
#17.H3 supports those footprints; never pretend they are75/90mm circles.
# https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
fun orks_squighog_model(Bool nob) -> Model:
    let profile = Profile::orks_squighog_boy
    if nob:
        profile = Profile::orks_nob_on_smasha_squig
    let model = orks_current_model(profile, OrksDatasheet::squighog_boyz)
    model.keywords.append(Keyword::mounted)
    model.keywords.append(Keyword::beast_snagga)
    model.keywords.append(Keyword::explosives)
    model.keywords.append(Keyword::mobile)
    model.geometry.unsupported_footprint = true
    if nob:
        equip_orks_profile(model, Weapon::orks_slugga, NamedWeaponProfile::slugga, 0)
        equip_orks_profile(model, Weapon::orks_big_choppa, NamedWeaponProfile::big_choppa, 0)
    else:
        equip_orks_profile(model, Weapon::orks_saddlegit_shiv, NamedWeaponProfile::saddlegit_s_shiv, 0)
        equip_orks_profile(model, Weapon::orks_stikka_ranged, NamedWeaponProfile::stikka_ranged, 1)
        equip_orks_profile(model, Weapon::orks_stikka_melee, NamedWeaponProfile::stikka_melee, 1)
    equip_orks_profile(model, Weapon::orks_squig_jaws, NamedWeaponProfile::squig_s_jaws, 0)
    return model

# Count/equipment data only; Bomb Squig/Brutal Impact and oval geometry must
# be completed before production roster migration (17.H2/H3).
# https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
fun make_orks_squighog_boyz(Int nobs, Int boys) -> Unit:
    assert(orks_squighog_composition_valid(nobs, boys), "illegal Squighog composition")
    let unit : Unit
    unit.name = "Squighog Boyz"s
    for nob_index in range(nobs):
        unit.models.append(orks_squighog_model(true))
    for boy_index in range(boys):
        unit.models.append(orks_squighog_model(false))
    configure_orks_attachment(unit, OrksDatasheet::squighog_boyz)
    unit.capture_starting_strength()
    return unit
