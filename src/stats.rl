import bounded_arg
import weapons
import army_configuration

enum AbilityKind:
    deep_strike
    oath_of_moment
    veil_of_time
    leader
    unstoppable_valour
    fight_first
    fury_of_the_first
    infiltrators
    lone_operative
    stealth
    shadow_in_the_warp
    neural_disruption
    psychological_saboteur
    feeder_tendrils 
    pouncing_leap
    sacrificial_dagger 
    dark_pacts
    veterans_of_the_long_war
    morgrim
    beast_snagga
    warboss
    beastboss
    refuse_to_yield
    patrol_squads
    bladeguard              
    swords_of_the_chapter  
    shields_of_the_chapter 
    hover
    super_heavy_walker
    dodge_dis
    keep_huntin
    mobbed
    bomb_squig
    brutal_impact
    intimidating_motivation
    ammo_runts
    boss_ammo_runt
    tide_of_muscle
    never_too_busy_to_fight
    get_out_da_way
    might_is_right
    sumfin_to_prove
    waaagh_banner
    rokkit_charge
    high_speed_carnage
    even_more_dakka
    blitz_dem_gitz
    thundering_stampede
    boss_of_da_hunt
    one_last_kill
    da_bigger_dey_iz
    finderz_keeperz
    arrogant_invulnerability
    krumpin_time
    more_dakka
    kustom_dakka
    shokk_boosta
    fix_dat_armour_up
    kustom_force_field
    support_shokka
    crude_surgery
    catch_dat_red_bit
    push_dat_bit_back_in
    hardy_bioniks
    clever_know_wotz
    trophy_hunters
    rokkit_barrage
    pulsa_rokkit
    krushin_impetus
    thievin_scavengers
    thatll_learn_ya
    super_runts

    mobile_fortress
    raucous_occupants
    fortification_rules
    ramshackle_cover
    boom_bomb
    kunnin_infiltrator
    deff_from_shadows
    burna_bomb
    strafing_run
    get_back_in_da_race
    fuel_mixa_grot
    deff_from_above
    aerial_manoover
    grand_warlords_ladz
    makari_banner
    prophet_waaagh
    gut_hatch
    big_an_stompy
    mobile_arsenal
    fully_loaded_butchery
    tramplasquig_charge
    beastscent
    kill_rig_warpath
    found_em
    taktikal_know_wotz
    nowhere_to_hide
    bomb_squig
    madcap_artillery
    gut_hatch
    big_an_shooty
    intimidating_motivation
    nazdregs_know_wotz
    supreme_kunnin
    squig_barrage
    idol_of_belligerence
    pilin_out
    drive_by_skorchin
    speednob_support
    bust_em
    weak_spot
    full_throttle
    da_jump
    weirdboy_warpath

    fun equal(AbilityKind other) -> Bool:
        return self.value == other.value

fun write_in_observation_tensor(AbilityKind obj, Int observer_id, Vector<Float> output, Int index):
    output[index] = (float(obj.value) - (float(max(obj)) / 2.0)) / float(max(obj))
    index = index + 1

fun size_as_observation_tensor(AbilityKind kind) -> Int:
    return 1

enum Faction:
    strike_force_octavius
    insidious_infiltrators
    zarkan_daemonkin
    morgrim_butchas
    tristraen_gilded_blade
    vengeful_brethren

    fun equal(Faction other) -> Bool:
        return self.value == other.value

# Compatibility mapping separates six legacy rosters from actual army identity;
# it does not certify their old datasheets (Orks source; ROADMAP17.H).
fun army_faction_for_roster(Faction roster) -> ArmyFaction:
    if roster == Faction::insidious_infiltrators:
        return ArmyFaction::tyranids
    if roster == Faction::zarkan_daemonkin:
        return ArmyFaction::chaos_space_marines
    if roster == Faction::morgrim_butchas:
        return ArmyFaction::orks
    if roster == Faction::tristraen_gilded_blade:
        return ArmyFaction::adeptus_custodes
    return ArmyFaction::space_marines

enum Keyword:
    infantry
    imperium
    terminator
    terminator_squad
    tacticus
    infernus_squad
    intercessor_squad
    hellblaster_squad
    character
    captain
    octavius
    psyker
    adeptus_astartes 
    librarian_tantus
    great_devourer
    death_shadow
    vanguard_invader
    neurolictor
    von_ryan_leaper 
    lictor
    tyranids
    chaos_space_marine
    master_of_possession
    aranis_zarkan
    daemon
    possessed
    chaos
    legionaries
    damned
    cultist_mob
    mob
    mounted
    monster_hunters
    beast_snagga
    beastboss
    squighog_boyz
    blade_champion
    tristraen
    custodian_guard
    custodian_wardens
    allarus_custodians
    terminator
    gravis
    master_zacharial
    bladeguard_veteran_squad
    monster # only implemented for veteran instincts 
    vehicle # only implemented for vetern instincts
    aircraft
    titanic
    walker
    # Model-level cover/Hidden categories (p.50); no feature traversal added.
    beasts
    swarm
    fly
    fortification
    mobile
    explosives
    grenades
    smoke
    towering
    transport
    dedicated_transport
    # Faction keyword from the current Orks datasheets (Orks faction URL).
    orks
    warlord
    # Current Beastboss / Beast Snagga Boyz keywords (source card URLs below).
    warboss
    battleline
    # Ordinary Orks detachment selectors; append to preserve older IDs.
    epic_hero
    mega_armour
    big_mek
    bigboss
    mek
    speed_freeks
    wagon
    gretchin
    boyz
    nobz
    meganobz
    kommandos
    stormboyz
    warbikers
    deffkoptas
    jump_pack
    grots
    runtherd

    frame

    fun equal(Keyword other) -> Bool:
        return self.value == other.value

fun write_in_observation_tensor(Keyword obj, Int observer_id, Vector<Float> output, Int index):
    output[index] = (float(obj.value) - (float(max(obj)) / 2.0)) / float(max(obj))
    index = index + 1

fun size_as_observation_tensor(Keyword kind) -> Int:
    return 1

enum Profile:
    captain_octavius:
        Int movement = 5
        Int thoughness = 5
        Int save = 2
        Int invuln_save = 4
        Int feel_no_pain = 10
        Int wounds = 6
        Int leadership = 6
        Int control = 1
        Float base_size = 50.0
    librarian_tantus:
        Int movement = 5
        Int thoughness = 5
        Int save = 2
        Int invuln_save = 4
        Int feel_no_pain = 10
        Int wounds = 5
        Int leadership = 6
        Int control = 1
        Float base_size = 40.0
    infernus_squad:
        Int movement = 6
        Int thoughness = 4
        Int save = 3
        Int invuln_save = 10
        Int feel_no_pain = 10
        Int wounds = 2
        Int leadership = 6
        Int control = 1
        Float base_size = 32.0
    terminator_squad:
        Int movement = 5
        Int thoughness = 5
        Int save = 2
        Int invuln_save = 4
        Int wounds = 3
        Int leadership = 6
        Int control = 1
        Float base_size = 40.0
    death_shadow:
        Int movement = 8
        Int thoughness = 5
        Int save = 4
        Int invuln_save = 4
        Int feel_no_pain = 10
        Int wounds = 7
        Int leadership = 7
        Int control = 1
        Float base_size = 50.0
    lictor:
        Int movement = 8
        Int thoughness = 6
        Int save = 4
        Int invuln_save = 10
        Int wounds = 6
        Int leadership = 7
        Int control = 1
        Float base_size = 50.0
    von_ryan_leaper:
        Int movement = 10
        Int thoughness = 5
        Int save = 4
        Int invuln_save = 6
        Int feel_no_pain = 10
        Int wounds = 3
        Int leadership = 8
        Int control = 1
        Float base_size = 40.0
    aranis_zarkan:
        Int movement = 8
        Int thoughness = 4
        Int save = 3
        Int invuln_save = 5
        Int wounds = 4
        Int leadership = 6
        Int control = 1
        Float base_size = 40.0
    possessed:
        Int movement = 9
        Int thoughness = 6
        Int save = 3
        Int invuln_save = 5
        Int feel_no_pain = 10
        Int wounds = 3
        Int leadership = 6
        Int control = 1
        Float base_size = 40.0
    legionaries:
        Int movement = 6
        Int thoughness = 4
        Int save = 3
        Int invuln_save = 10
        Int wounds = 2
        Int leadership = 6
        Int control = 2
        Float base_size = 32.0
    cultist_mob:
        Int movement = 6
        Int thoughness = 3
        Int save = 6
        Int invuln_save = 10
        Int feel_no_pain = 10
        Int wounds = 1
        Int leadership = 7
        Int control = 1
        Float base_size = 25.0
    beastboss_morgrim:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int invuln_save = 5
        Int feel_no_pain = 5
        Int wounds = 6
        Int leadership = 6
        Int control = 1
        Float base_size = 50.0
    beast_snagga_boy:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int invuln_save = 10
        Int feel_no_pain = 6
        Int wounds = 2
        Int leadership = 7
        Int control = 2
        Float base_size = 32.0
    beast_snagga_nob:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int invuln_save = 10
        Int wounds = 3    
        Int feel_no_pain = 6
        Int leadership = 7
        Int control = 2
        Float base_size = 32.0
    squighog_boyz:
        Int movement = 10
        Int thoughness = 7
        Int save = 4
        Int invuln_save = 10
        Int feel_no_pain = 5
        Int wounds = 3
        Int leadership = 7
        Int control = 2
        Float base_size = 75.0
    nob_on_smasha_squig:
        Int movement = 10
        Int thoughness = 7
        Int save = 4
        Int invuln_save = 10
        Int feel_no_pain = 5
        Int wounds = 4
        Int leadership = 7
        Int control = 2
        Float base_size = 90.0
    tristraen:
        Int movement = 6
        Int thoughness = 6
        Int save = 2
        Int invuln_save = 4
        Int feel_no_pain = 10
        Int wounds = 6
        Int leadership = 6
        Int control = 2
        Float base_size = 40.0
    custodian_wardens:
        Int movement = 6
        Int thoughness = 6
        Int save = 2
        Int invuln_save = 4
        Int feel_no_pain = 10
        Int wounds = 3
        Int leadership = 6
        Int control = 2
        Float base_size = 40.0
    allarus_custodians:
        Int movement = 5
        Int thoughness = 7
        Int save = 2
        Int invuln_save = 4
        Int feel_no_pain = 10
        Int wounds = 4
        Int leadership = 6
        Int control = 2
        Float base_size = 40.0
    custodian_guard:
        Int movement = 6
        Int thoughness = 6
        Int save = 2
        Int invuln_save = 4
        Int feel_no_pain = 10
        Int wounds = 4
        Int leadership = 6
        Int control = 2
        Float base_size = 40.0
    master_zacharial:
        Int movement = 5
        Int thoughness = 6
        Int feel_no_pain = 10
        Int save = 3
        Int invuln_save = 4
        Int wounds = 6
        Int leadership = 6
        Int control = 1
        Float base_size = 40.0
    intercessor_squad:
        Int movement = 6
        Int thoughness = 4
        Int save = 3
        Int invuln_save = 10
        Int feel_no_pain = 10
        Int wounds = 2
        Int leadership = 6
        Int control = 2
        Float base_size = 32.0
    hellblaster_squad:
        Int movement = 6
        Int thoughness = 4
        Int save = 3
        Int invuln_save = 10
        Int feel_no_pain = 10
        Int wounds = 2
        Int leadership = 6
        Int control = 1
        Float base_size = 32.0
    bladeguard_veteran_squad:
        Int movement = 6
        Int thoughness = 4
        Int save = 3
        Int invuln_save = 4
        Int wounds = 3
        Int leadership = 6
        Int control = 1
        Float base_size = 40.0


    # Current11th-edition HTML profiles, including the separate InSv boxes.
    # https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss
    # https://wahapedia.ru/wh40k11ed/factions/orks/Beast-Snagga-Boyz
    # https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
    # Earlier enum entries remain stable legacy test data, not current cards.
    orks_beastboss:
        Int movement = 6
        Int thoughness = 6
        Int save = 4
        Int invuln_save = 5
        Int feel_no_pain = 6
        Int wounds = 6
        Int leadership = 6
        Int control = 1
        Float base_size = 50.0
    orks_beast_snagga_boy:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int invuln_save = 6
        Int feel_no_pain = 10
        Int wounds = 1
        Int leadership = 7
        Int control = 2
        Float base_size = 32.0
    orks_beast_snagga_nob:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int invuln_save = 6
        Int feel_no_pain = 10
        Int wounds = 3
        Int leadership = 7
        Int control = 2
        Float base_size = 32.0
    orks_squighog_boy:
        Int movement = 10
        Int thoughness = 6
        Int save = 4
        Int invuln_save = 6
        Int feel_no_pain = 10
        Int wounds = 3
        Int leadership = 7
        Int control = 2
        Float base_size = 75.0
    orks_nob_on_smasha_squig:
        Int movement = 10
        Int thoughness = 6
        Int save = 4
        Int invuln_save = 6
        Int feel_no_pain = 10
        Int wounds = 4
        Int leadership = 7
        Int control = 2
        Float base_size = 90.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
    orks_boy:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int wounds = 1
        Int leadership = 7
        Int control = 2
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 32.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Boyz
    orks_boyz_nob:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int wounds = 3
        Int leadership = 7
        Int control = 2
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
    orks_nob:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int wounds = 3
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss
    orks_warboss:
        Int movement = 6
        Int thoughness = 6
        Int save = 4
        Int wounds = 6
        Int leadership = 6
        Int control = 1
        Int invuln_save = 5
        Int feel_no_pain = 10
        Float base_size = 50.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Bigboss
    orks_bigboss:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int wounds = 5
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Bannernob
    orks_bannernob:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int wounds = 4
        Int leadership = 7
        Int control = 3
        Int invuln_save = 5
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Stormboyz
    orks_stormboy:
        Int movement = 12
        Int thoughness = 5
        Int save = 5
        Int wounds = 1
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 32.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Stormboyz
    orks_stormboy_nob:
        Int movement = 12
        Int thoughness = 5
        Int save = 5
        Int wounds = 3
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 32.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers
    orks_warbiker:
        Int movement = 12
        Int thoughness = 6
        Int save = 4
        Int wounds = 3
        Int leadership = 7
        Int control = 2
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 75.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbikers
    orks_biker_nob:
        Int movement = 12
        Int thoughness = 6
        Int save = 4
        Int wounds = 4
        Int leadership = 7
        Int control = 2
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 75.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deff-Dread
    orks_deff_dread:
        Int movement = 8
        Int thoughness = 9
        Int save = 2
        Int wounds = 8
        Int leadership = 7
        Int control = 3
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 60.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Killa-Kans
    orks_killa_kan:
        Int movement = 8
        Int thoughness = 7
        Int save = 3
        Int wounds = 5
        Int leadership = 8
        Int control = 2
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 60.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-Dakkarig
    orks_big_mek_dakkarig:
        Int movement = 8
        Int thoughness = 8
        Int save = 3
        Int wounds = 11
        Int leadership = 7
        Int control = 3
        Int invuln_save = 5
        Int feel_no_pain = 10
        Float base_size = 90.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss-on-Squigosaur
    orks_beastboss_on_squigosaur:
        Int movement = 10
        Int thoughness = 9
        Int save = 3
        Int wounds = 10
        Int leadership = 6
        Int control = 3
        Int invuln_save = 5
        Int feel_no_pain = 5
        Float base_size = 80.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mozrog-Skragbad
    orks_mozrog_skragbad:
        Int movement = 10
        Int thoughness = 9
        Int save = 3
        Int wounds = 10
        Int leadership = 6
        Int control = 3
        Int invuln_save = 4
        Int feel_no_pain = 5
        Float base_size = 80.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
    orks_kaptin:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int wounds = 3
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Flash-Gitz
    orks_flash_git:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int wounds = 3
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Meganobz
    orks_meganob:
        Int movement = 5
        Int thoughness = 6
        Int save = 2
        Int wounds = 3
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek
    orks_mek:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int wounds = 4
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 32.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
    orks_big_mek:
        Int movement = 6
        Int thoughness = 5
        Int save = 3
        Int wounds = 6
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 50.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-In-Mega-Armour
    orks_big_mek_in_mega_armour:
        Int movement = 5
        Int thoughness = 6
        Int save = 2
        Int wounds = 5
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun
    orks_big_mek_with_shokk_attack_gun:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int wounds = 5
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Painboy
    orks_painboy:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int wounds = 3
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 32.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Painboss
    orks_painboss:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int wounds = 4
        Int leadership = 7
        Int control = 1
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_boy:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int wounds = 2
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 32.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Breaka-Boyz
    orks_breaka_nob:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int wounds = 3
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbusta:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int wounds = 2
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 32.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Tankbustas
    orks_tankbusta_nob:
        Int movement = 6
        Int thoughness = 5
        Int save = 4
        Int wounds = 3
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warboss-In-Mega-Armour
    orks_warboss_in_mega_armour:
        Int movement = 5
        Int thoughness = 7
        Int save = 2
        Int wounds = 7
        Int leadership = 6
        Int control = 1
        Int invuln_save = 5
        Int feel_no_pain = 10
        Float base_size = 50.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gretchin
    orks_gretchin:
        Int movement = 6
        Int thoughness = 2
        Int save = 6
        Int wounds = 1
        Int leadership = 8
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 25.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Runtherd
    orks_runtherd:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int wounds = 3
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 32.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Zodgrod-Wortsnagga
    orks_zodgrod_wortsnagga:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int wounds = 5
        Int leadership = 7
        Int control = 1
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 50.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon; Use-model hulls require an explicit proxy input.
    orks_battlewagon:
        Int movement = 10
        Int thoughness = 11
        Int save = 3
        Int wounds = 16
        Int leadership = 7
        Int control = 5
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 0.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka; Use-model hulls require an explicit proxy input.
    orks_big_ed_bossbunka:
        Int movement = 0
        Int thoughness = 10
        Int save = 3
        Int wounds = 12
        Int leadership = 7
        Int control = 0
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 0.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer
    orks_blitza_bommer:
        Int movement = 0
        Int thoughness = 9
        Int save = 3
        Int wounds = 12
        Int leadership = 7
        Int control = 0
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 120.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Boss-Snikrot
    orks_boss_snikrot:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int wounds = 6
        Int leadership = 6
        Int control = 1
        Int invuln_save = 5
        Int feel_no_pain = 10
        Float base_size = 40.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer
    orks_burna_bommer:
        Int movement = 0
        Int thoughness = 9
        Int save = 3
        Int wounds = 12
        Int leadership = 7
        Int control = 0
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 120.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Dakkajet
    orks_dakkajet:
        Int movement = 0
        Int thoughness = 9
        Int save = 3
        Int wounds = 12
        Int leadership = 7
        Int control = 0
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 120.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
    orks_deffkilla_wartrike:
        Int movement = 12
        Int thoughness = 6
        Int save = 4
        Int wounds = 9
        Int leadership = 6
        Int control = 3
        Int invuln_save = 5
        Int feel_no_pain = 10
        Float base_size = 150.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
    orks_deffkoptas:
        Int movement = 12
        Int thoughness = 6
        Int save = 4
        Int wounds = 4
        Int leadership = 7
        Int control = 2
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 75.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
    orks_ghazghkull_thraka:
        Int movement = 8
        Int thoughness = 10
        Int save = 2
        Int wounds = 16
        Int leadership = 6
        Int control = 4
        Int invuln_save = 4
        Int feel_no_pain = 10
        Float base_size = 80.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
    orks_gorkanaut:
        Int movement = 9
        Int thoughness = 12
        Int save = 2
        Int wounds = 20
        Int leadership = 7
        Int control = 8
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 170.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon; Use-model hulls require an explicit proxy input.
    orks_gunwagon:
        Int movement = 10
        Int thoughness = 12
        Int save = 3
        Int wounds = 16
        Int leadership = 7
        Int control = 5
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 0.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
    orks_hunta_rig:
        Int movement = 10
        Int thoughness = 10
        Int save = 3
        Int wounds = 16
        Int leadership = 7
        Int control = 5
        Int invuln_save = 6
        Int feel_no_pain = 5
        Float base_size = 170.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
    orks_kill_rig:
        Int movement = 10
        Int thoughness = 10
        Int save = 3
        Int wounds = 16
        Int leadership = 7
        Int control = 5
        Int invuln_save = 6
        Int feel_no_pain = 5
        Float base_size = 170.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    orks_kommando:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int wounds = 1
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 32.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    orks_kommando_nob:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int wounds = 3
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 32.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz; Use-model hulls require an explicit proxy input.
    orks_mek_gunz:
        Int movement = 5
        Int thoughness = 6
        Int save = 4
        Int wounds = 6
        Int leadership = 8
        Int control = 2
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 0.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
    orks_morkanaut:
        Int movement = 9
        Int thoughness = 12
        Int save = 2
        Int wounds = 20
        Int leadership = 7
        Int control = 8
        Int invuln_save = 5
        Int feel_no_pain = 10
        Float base_size = 170.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
    orks_nazdreg:
        Int movement = 5
        Int thoughness = 7
        Int save = 2
        Int wounds = 8
        Int leadership = 6
        Int control = 1
        Int invuln_save = 5
        Int feel_no_pain = 10
        Float base_size = 60.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies
    orks_rukkatrukk_squigbuggies:
        Int movement = 12
        Int thoughness = 7
        Int save = 4
        Int wounds = 9
        Int leadership = 7
        Int control = 3
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 150.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa; Use-model hulls require an explicit proxy input.
    orks_stompa:
        Int movement = 10
        Int thoughness = 14
        Int save = 2
        Int wounds = 30
        Int leadership = 6
        Int control = 12
        Int invuln_save = 5
        Int feel_no_pain = 10
        Float base_size = 0.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk; Use-model hulls require an explicit proxy input.
    orks_trukk:
        Int movement = 12
        Int thoughness = 8
        Int save = 4
        Int wounds = 10
        Int leadership = 7
        Int control = 2
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 0.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
    orks_warbuggies:
        Int movement = 12
        Int thoughness = 7
        Int save = 4
        Int wounds = 9
        Int leadership = 7
        Int control = 3
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 150.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks
    orks_wartrakks:
        Int movement = 12
        Int thoughness = 6
        Int save = 4
        Int wounds = 7
        Int leadership = 7
        Int control = 3
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 105.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
    orks_wazbom_blastajet:
        Int movement = 0
        Int thoughness = 9
        Int save = 3
        Int wounds = 12
        Int leadership = 7
        Int control = 0
        Int invuln_save = 6
        Int feel_no_pain = 10
        Float base_size = 120.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
    orks_wazdakka_gutsmek:
        Int movement = 14
        Int thoughness = 8
        Int save = 3
        Int wounds = 10
        Int leadership = 6
        Int control = 3
        Int invuln_save = 4
        Int feel_no_pain = 10
        Float base_size = 120.0

    # https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy
    orks_weirdboy:
        Int movement = 6
        Int thoughness = 5
        Int save = 5
        Int wounds = 4
        Int leadership = 7
        Int control = 1
        Int invuln_save = 10
        Int feel_no_pain = 10
        Float base_size = 50.0

    fun equal(Profile other) -> Bool:
        return self.value == other.value

fun write_in_observation_tensor(Profile obj, Int observer_id, Vector<Float> output, Int index):
    output[index] = (float(obj.value) - (float(max(obj)) / 2.0)) / float(max(obj))
    index = index + 1

fun size_as_observation_tensor(Profile kind) -> Int:
    return 1

# Source dimensions are immutable profile metadata, not a new stored float.
# Squighog ovals require the17.H3 geometry kernel before fielding these models.
# https://wahapedia.ru/wh40k11ed/factions/orks/Squighog-Boyz
fun profile_base_width(Profile profile) -> Float:
    if profile == Profile::orks_squighog_boy:
        return 42.0
    if profile == Profile::orks_nob_on_smasha_squig:
        return 52.0
    if profile == Profile::orks_warbiker or profile == Profile::orks_biker_nob:
        return 42.0
    if profile == Profile::orks_blitza_bommer:
        return 92.0
    if profile == Profile::orks_burna_bommer:
        return 92.0
    if profile == Profile::orks_dakkajet:
        return 92.0
    if profile == Profile::orks_deffkilla_wartrike:
        return 95.0
    if profile == Profile::orks_deffkoptas:
        return 42.0
    if profile == Profile::orks_gorkanaut:
        return 109.0
    if profile == Profile::orks_hunta_rig:
        return 109.0
    if profile == Profile::orks_kill_rig:
        return 109.0
    if profile == Profile::orks_morkanaut:
        return 109.0
    if profile == Profile::orks_rukkatrukk_squigbuggies:
        return 95.0
    if profile == Profile::orks_warbuggies:
        return 95.0
    if profile == Profile::orks_wartrakks:
        return 70.0
    if profile == Profile::orks_wazbom_blastajet:
        return 92.0
    if profile == Profile::orks_wazdakka_gutsmek:
        return 92.0
    return profile.base_size()

enum Stratagem:
    reroll:
        Int cost = 1
    overwatch:
        Int cost = 1 
    rapid_ingress:
        Int cost = 1
    insane_bravery:
        Int cost = 1
    veteran_instincts:
        Int cost = 1
    gene_wrought_resiliance:
        Int cost = 1 
    duty_and_honour:
        Int cost = 1 
    heroic_intervention:
        Int cost = 1
    swift_kill:
        Int cost = 1
    pheromone_trace:
        Int cost = 1
    predators_not_prey:
        Int cost = 1
    vindictive_strategy:
        Int cost = 1
    violent_unbidding:
        Int cost = 1
    demonic_fervour:
        Int cost = 1
    overawing_magnificence:
        Int cost = 1
    the_gilded_spear:
        Int cost = 1
    relic_munitions:
        Int cost = 1
    unyielding:
        Int cost = 1
    epic_challenge:
        Int cost = 1
    explosives:
        Int cost = 1
    crushing_impact:
        Int cost = 1
    smokescreen:
        Int cost = 1
    counteroffensive:
        Int cost = 2

    orks_breakin_heads:
        Int cost = 1
    orks_hit_em_harder:
        Int cost = 1
    orks_orks_is_never_beaten:
        Int cost = 1
    orks_mow_em_down:
        Int cost = 1
    orks_fungus_fuel_injection:
        Int cost = 1
    orks_close_range_dakka:
        Int cost = 1
    orks_unbridled_carnage:
        Int cost = 1
    orks_mob_mentality:
        Int cost = 1
    orks_ere_we_go:
        Int cost = 1
    orks_too_arrogant_to_die:
        Int cost = 1
    orks_armed_to_da_teef:
        Int cost = 1
    orks_hulking_brutes:
        Int cost = 1
    orks_infested_war_zone:
        Int cost = 2
    orks_scarper:
        Int cost = 1
    orks_grot_shields:
        Int cost = 1
    orks_kustom_dakka:
        Int cost = 1
    orks_glowin_dakka:
        Int cost = 1
    orks_never_enough_dakka:
        Int cost = 1
    orks_dubious_restraint:
        Int cost = 1
    orks_mind_mostly_on_the_mission:
        Int cost = 1
    orks_while_their_backs_are_turned:
        Int cost = 1
    orks_drive_by_bustin:
        Int cost = 1
    orks_grab_it:
        Int cost = 1
    orks_gun_crazy_show_offs:
        Int cost = 1
    orks_where_d_ya_fink_you_re_going:
        Int cost = 1
    orks_goaded_into_action:
        Int cost = 1
    orks_instinctive_hunters:
        Int cost = 1
    orks_vindictive_artillerists:
        Int cost = 1
    orks_crazed_rampage:
        Int cost = 1
    orks_dread_power:
        Int cost = 1
    orks_stomping_juggernaut:
        Int cost = 1
    orks_keep_it_runnin:
        Int cost = 1
    orks_readied_brawlers:
        Int cost = 1
    orks_impending_krunch:
        Int cost = 1
    orks_delicious_eating_squigs:
        Int cost = 1
    orks_dakkastorm:
        Int cost = 1
    orks_speediest_freeks:
        Int cost = 1
    orks_flyin_headbutt:
        Int cost = 1
    orks_long_uncontrolled_bursts:
        Int cost = 1
    orks_whirligig_evasion:
        Int cost = 1

    # Configuration gates only: effects/targets/windows remain later batches.
    # Source cards and CP values: doc/factions/orks/orks-stratagem-costs.tsv (Orks faction URL).
    fun orks_detachment() -> OrksDetachment:
        if self == Stratagem::orks_breakin_heads or self == Stratagem::orks_hit_em_harder or self == Stratagem::orks_orks_is_never_beaten or self == Stratagem::orks_mow_em_down or self == Stratagem::orks_fungus_fuel_injection or self == Stratagem::orks_close_range_dakka:
            return OrksDetachment::war_horde
        if self == Stratagem::orks_unbridled_carnage or self == Stratagem::orks_mob_mentality or self == Stratagem::orks_ere_we_go:
            return OrksDetachment::green_tide
        if self == Stratagem::orks_too_arrogant_to_die or self == Stratagem::orks_armed_to_da_teef or self == Stratagem::orks_hulking_brutes:
            return OrksDetachment::bully_boyz
        if self == Stratagem::orks_infested_war_zone or self == Stratagem::orks_scarper or self == Stratagem::orks_grot_shields:
            return OrksDetachment::runt_swarm
        if self == Stratagem::orks_kustom_dakka or self == Stratagem::orks_glowin_dakka or self == Stratagem::orks_never_enough_dakka:
            return OrksDetachment::shoota_boyz
        if self == Stratagem::orks_dubious_restraint or self == Stratagem::orks_mind_mostly_on_the_mission or self == Stratagem::orks_while_their_backs_are_turned:
            return OrksDetachment::taktikal_brigade
        if self == Stratagem::orks_drive_by_bustin or self == Stratagem::orks_grab_it or self == Stratagem::orks_gun_crazy_show_offs:
            return OrksDetachment::wreckas
        if self == Stratagem::orks_where_d_ya_fink_you_re_going or self == Stratagem::orks_goaded_into_action or self == Stratagem::orks_instinctive_hunters:
            return OrksDetachment::da_big_hunt
        if self == Stratagem::orks_vindictive_artillerists:
            return OrksDetachment::madcap_meks
        if self == Stratagem::orks_crazed_rampage or self == Stratagem::orks_dread_power or self == Stratagem::orks_stomping_juggernaut:
            return OrksDetachment::dread_mob
        if self == Stratagem::orks_keep_it_runnin or self == Stratagem::orks_readied_brawlers or self == Stratagem::orks_impending_krunch:
            return OrksDetachment::blitz_brigade
        if self == Stratagem::orks_delicious_eating_squigs or self == Stratagem::orks_dakkastorm or self == Stratagem::orks_speediest_freeks:
            return OrksDetachment::kult_of_speed
        if self == Stratagem::orks_flyin_headbutt or self == Stratagem::orks_long_uncontrolled_bursts or self == Stratagem::orks_whirligig_evasion:
            return OrksDetachment::flyboyz
        return OrksDetachment::none

    # Printed exceptions do not waive affordability or phase/unit limits
    # (Orks Breakin' Heads / Infested War Zone / Flyin' Headbutt; core p.54).
    fun target_policy() -> StratagemTargetPolicy:
        if self == Stratagem::orks_breakin_heads:
            return StratagemTargetPolicy::allow_shocked
        if self == Stratagem::orks_infested_war_zone or self == Stratagem::orks_flyin_headbutt:
            return StratagemTargetPolicy::destroyed_unit
        return StratagemTargetPolicy::ordinary

    fun equal(Stratagem other) -> Bool:
        return self.value == other.value


# Original shape metadata survives the user-authorized long-axis circle proxy.
# Sources: Orks/Squighog-Boyz75x42 and90x52mm; exact ovals are deferred.
fun profile_has_oval_base(Profile profile) -> Bool:
    return profile == Profile::orks_squighog_boy or profile == Profile::orks_nob_on_smasha_squig or profile == Profile::orks_warbiker or profile == Profile::orks_biker_nob or profile == Profile::orks_blitza_bommer or profile == Profile::orks_burna_bommer or profile == Profile::orks_dakkajet or profile == Profile::orks_deffkilla_wartrike or profile == Profile::orks_deffkoptas or profile == Profile::orks_gorkanaut or profile == Profile::orks_hunta_rig or profile == Profile::orks_kill_rig or profile == Profile::orks_morkanaut or profile == Profile::orks_rukkatrukk_squigbuggies or profile == Profile::orks_warbuggies or profile == Profile::orks_wartrakks or profile == Profile::orks_wazbom_blastajet or profile == Profile::orks_wazdakka_gutsmek
