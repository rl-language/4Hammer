import bounded_arg
import string

# Source-backed name catalog only, not profiles/stats or faction grants.
# See doc/factions/orks/orks-named-identities.tsv and the 67-datasheet audit.
# IDs are append-only within a storage schema; stored fields use standard
# LinearlyDistributedInt rather than one-hot catalog enums.
const MAX_DATASHEETCODE = 68
using DatasheetCode = LinearlyDistributedInt<0, MAX_DATASHEETCODE>

enum OrksDatasheet:
    unknown
    bannernob
    battlewagon
    beast_snagga_boyz
    beastboss
    beastboss_on_squigosaur
    big_mek
    big_mek_dakkarig
    big_mek_in_mega_armour
    big_mek_with_shokk_attack_gun
    big_trakk
    big_ed_bossbunka
    bigboss
    blitza_bommer
    boss_snikrot
    boss_zagstruk
    boyz
    breaka_boyz
    burna_boyz
    burna_bommer
    dakkajet
    deff_dread
    deffkilla_wartrike
    deffkoptas
    flash_gitz
    gargantuan_squiggoth
    ghazghkull_thraka
    gorkanaut
    gretchin
    grot_mega_tank
    grot_tanks
    gunwagon
    hunta_rig
    kaptin_badrukk
    kill_rig
    kill_tank
    killa_kans
    kommandos
    lifta_wagon
    lootas
    mad_dok_grotsnik
    meganobz
    mek
    mek_gunz
    mekboy_workshop
    morkanaut
    mozrog_skragbad
    nazdreg
    nobz
    painboss
    painboy
    rukkatrukk_squigbuggies
    runtherd
    squighog_boyz
    stompa
    stormboyz
    tankbustas
    trukk
    warbikers
    warboss
    warboss_in_mega_armour
    warboss_on_warbike
    warbuggies
    wartrakks
    wazbom_blastajet
    wazdakka_gutsmek
    weirdboy
    zodgrod_wortsnagga

    # Source labels are metadata; identities are compact standard bounded codes.
    fun label() -> StringLiteral:
        if self.value == OrksDatasheet::unknown.value:
            return "Unknown"
        if self.value == OrksDatasheet::bannernob.value:
            return "Bannernob"
        if self.value == OrksDatasheet::battlewagon.value:
            return "Battlewagon"
        if self.value == OrksDatasheet::beast_snagga_boyz.value:
            return "Beast Snagga Boyz"
        if self.value == OrksDatasheet::beastboss.value:
            return "Beastboss"
        if self.value == OrksDatasheet::beastboss_on_squigosaur.value:
            return "Beastboss on Squigosaur"
        if self.value == OrksDatasheet::big_mek.value:
            return "Big Mek"
        if self.value == OrksDatasheet::big_mek_dakkarig.value:
            return "Big Mek Dakkarig"
        if self.value == OrksDatasheet::big_mek_in_mega_armour.value:
            return "Big Mek In Mega Armour"
        if self.value == OrksDatasheet::big_mek_with_shokk_attack_gun.value:
            return "Big Mek With Shokk Attack Gun"
        if self.value == OrksDatasheet::big_trakk.value:
            return "Big Trakk"
        if self.value == OrksDatasheet::big_ed_bossbunka.value:
            return "Big’ed Bossbunka"
        if self.value == OrksDatasheet::bigboss.value:
            return "Bigboss"
        if self.value == OrksDatasheet::blitza_bommer.value:
            return "Blitza-bommer"
        if self.value == OrksDatasheet::boss_snikrot.value:
            return "Boss Snikrot"
        if self.value == OrksDatasheet::boss_zagstruk.value:
            return "Boss Zagstruk"
        if self.value == OrksDatasheet::boyz.value:
            return "Boyz"
        if self.value == OrksDatasheet::breaka_boyz.value:
            return "Breaka Boyz"
        if self.value == OrksDatasheet::burna_boyz.value:
            return "Burna Boyz"
        if self.value == OrksDatasheet::burna_bommer.value:
            return "Burna-bommer"
        if self.value == OrksDatasheet::dakkajet.value:
            return "Dakkajet"
        if self.value == OrksDatasheet::deff_dread.value:
            return "Deff Dread"
        if self.value == OrksDatasheet::deffkilla_wartrike.value:
            return "Deffkilla Wartrike"
        if self.value == OrksDatasheet::deffkoptas.value:
            return "Deffkoptas"
        if self.value == OrksDatasheet::flash_gitz.value:
            return "Flash Gitz"
        if self.value == OrksDatasheet::gargantuan_squiggoth.value:
            return "Gargantuan Squiggoth"
        if self.value == OrksDatasheet::ghazghkull_thraka.value:
            return "Ghazghkull Thraka"
        if self.value == OrksDatasheet::gorkanaut.value:
            return "Gorkanaut"
        if self.value == OrksDatasheet::gretchin.value:
            return "Gretchin"
        if self.value == OrksDatasheet::grot_mega_tank.value:
            return "Grot Mega-tank"
        if self.value == OrksDatasheet::grot_tanks.value:
            return "Grot Tanks"
        if self.value == OrksDatasheet::gunwagon.value:
            return "Gunwagon"
        if self.value == OrksDatasheet::hunta_rig.value:
            return "Hunta Rig"
        if self.value == OrksDatasheet::kaptin_badrukk.value:
            return "Kaptin Badrukk"
        if self.value == OrksDatasheet::kill_rig.value:
            return "Kill Rig"
        if self.value == OrksDatasheet::kill_tank.value:
            return "Kill Tank"
        if self.value == OrksDatasheet::killa_kans.value:
            return "Killa Kans"
        if self.value == OrksDatasheet::kommandos.value:
            return "Kommandos"
        if self.value == OrksDatasheet::lifta_wagon.value:
            return "Lifta Wagon"
        if self.value == OrksDatasheet::lootas.value:
            return "Lootas"
        if self.value == OrksDatasheet::mad_dok_grotsnik.value:
            return "Mad Dok Grotsnik"
        if self.value == OrksDatasheet::meganobz.value:
            return "Meganobz"
        if self.value == OrksDatasheet::mek.value:
            return "Mek"
        if self.value == OrksDatasheet::mek_gunz.value:
            return "Mek Gunz"
        if self.value == OrksDatasheet::mekboy_workshop.value:
            return "Mekboy Workshop"
        if self.value == OrksDatasheet::morkanaut.value:
            return "Morkanaut"
        if self.value == OrksDatasheet::mozrog_skragbad.value:
            return "Mozrog Skragbad"
        if self.value == OrksDatasheet::nazdreg.value:
            return "Nazdreg"
        if self.value == OrksDatasheet::nobz.value:
            return "Nobz"
        if self.value == OrksDatasheet::painboss.value:
            return "Painboss"
        if self.value == OrksDatasheet::painboy.value:
            return "Painboy"
        if self.value == OrksDatasheet::rukkatrukk_squigbuggies.value:
            return "Rukkatrukk Squigbuggies"
        if self.value == OrksDatasheet::runtherd.value:
            return "Runtherd"
        if self.value == OrksDatasheet::squighog_boyz.value:
            return "Squighog Boyz"
        if self.value == OrksDatasheet::stompa.value:
            return "Stompa"
        if self.value == OrksDatasheet::stormboyz.value:
            return "Stormboyz"
        if self.value == OrksDatasheet::tankbustas.value:
            return "Tankbustas"
        if self.value == OrksDatasheet::trukk.value:
            return "Trukk"
        if self.value == OrksDatasheet::warbikers.value:
            return "Warbikers"
        if self.value == OrksDatasheet::warboss.value:
            return "Warboss"
        if self.value == OrksDatasheet::warboss_in_mega_armour.value:
            return "Warboss In Mega Armour"
        if self.value == OrksDatasheet::warboss_on_warbike.value:
            return "Warboss on Warbike"
        if self.value == OrksDatasheet::warbuggies.value:
            return "Warbuggies"
        if self.value == OrksDatasheet::wartrakks.value:
            return "Wartrakks"
        if self.value == OrksDatasheet::wazbom_blastajet.value:
            return "Wazbom Blastajet"
        if self.value == OrksDatasheet::wazdakka_gutsmek.value:
            return "Wazdakka Gutsmek"
        if self.value == OrksDatasheet::weirdboy.value:
            return "Weirdboy"
        if self.value == OrksDatasheet::zodgrod_wortsnagga.value:
            return "Zodgrod Wortsnagga"
        return "Invalid"

const MAX_WEAPONNAMECODE = 140
using WeaponNameCode = LinearlyDistributedInt<0, MAX_WEAPONNAMECODE>

enum NamedWeapon:
    unknown
    eadbanger
    urty_syringe
    adamantine_eadbutt
    armoured_hull
    armoured_impact
    beast_snagga_klaw
    beast_snagga_klaw_and_beastchoppa
    beastchoppa
    big_chompa_s_jaws
    big_choppa
    big_mek_s_toolz
    big_shoota
    big_skorcha
    blitzkannon
    boomstikks
    breacha_ram
    bubblechukka
    burna
    busta_rokkit_launcha
    butcha_boyz
    buzzsaw
    choppa
    copper_staff
    crushin_bulk
    cuttin_flames
    da_gobshot_thunderbuss
    da_grabzappa
    da_krunch
    da_rippa
    da_vulcha_s_klaws_and_choppa
    deff_rolla
    deffgun
    deffkannon_and_supa_rokkits
    deffstorm_mega_shoota
    dok_s_toolz
    dread_klaws
    drilla
    dual_big_shoota
    dual_dakkagun
    dual_grotzooka
    dual_kombi_rokkit
    dual_kustom_mega_blasta
    dual_rokkit_launcha
    dual_skorcha
    dual_supa_shoota
    dual_tellyport_mega_blasta
    dual_wazbom_mega_kannon
    extra_dakka
    extra_klaw
    fixit_s_wrench
    gaze_of_gork
    gitstikka
    gork_s_klaw
    grabba_dragga
    grabbin_klaw
    grot_blasta
    grot_tank_shoota
    grotzooka
    gun_stock_and_fists
    gutrippa
    huge_tusks
    kan_blasta
    kan_klaw
    kannon
    killa_jet
    killkannon
    killsaw
    klaw_of_gork
    klaw_of_mork
    knucklebustas
    kombi_rokkit
    kombi_skorcha
    kombi_weapon
    kustom_big_shoota
    kustom_blasta_x
    kustom_choppa
    kustom_krumpa
    kustom_mega_blasta
    kustom_mega_kannon
    kustom_mega_slugga
    kustom_mega_zappa
    kustom_shoota
    lifta_droppa
    lobba
    mega_choppa
    mega_tank_weapons
    mek_speshul
    mek_s_toolz
    moonchewa
    mork_s_roar
    mork_s_teef
    multi_busta_launcha
    power_klaw
    power_snappa
    power_vomit
    psyko_gatler
    ramshackle_hull
    rivet_kannon
    rokkit_launcha
    rokkit_pistol
    runtherd_s_toolz
    saddlegit_s_shiv
    savage_horns_and_hooves
    saw_blades
    sawn_off_shotgun
    scavenged_shivs
    shokk_attack_gun
    shoota
    skorcha
    skorcha_missile_rack
    slugga
    smash_hammer
    smasha_gun
    snagga_klaw
    snazzgun
    speeding_bulk_and_flaming_exhaust
    spiked_ram
    spinnin_blades
    squig_launchas
    squigosaur_s_jaws
    squigstoppa
    squig_s_jaws
    stikka
    stikka_kannon
    stompy_feet
    supa_gatler
    supa_kannon
    tank_kannon
    tankhammer
    tellyport_blasta
    thump_gun
    traktor_blasta
    traktor_kannon
    twin_killsaws
    wreckin_ball
    wurrtower
    zzap_gun
    eavy_lobba
    uge_choppa

    # Source labels are metadata; identities are compact standard bounded codes.
    fun label() -> StringLiteral:
        if self.value == NamedWeapon::unknown.value:
            return "Unknown"
        if self.value == NamedWeapon::eadbanger.value:
            return "'Eadbanger"
        if self.value == NamedWeapon::urty_syringe.value:
            return "’Urty Syringe"
        if self.value == NamedWeapon::adamantine_eadbutt.value:
            return "Adamantine ’Eadbutt"
        if self.value == NamedWeapon::armoured_hull.value:
            return "Armoured Hull"
        if self.value == NamedWeapon::armoured_impact.value:
            return "Armoured Impact"
        if self.value == NamedWeapon::beast_snagga_klaw.value:
            return "Beast Snagga Klaw"
        if self.value == NamedWeapon::beast_snagga_klaw_and_beastchoppa.value:
            return "Beast Snagga Klaw and Beastchoppa"
        if self.value == NamedWeapon::beastchoppa.value:
            return "Beastchoppa"
        if self.value == NamedWeapon::big_chompa_s_jaws.value:
            return "Big Chompa’s Jaws"
        if self.value == NamedWeapon::big_choppa.value:
            return "Big Choppa"
        if self.value == NamedWeapon::big_mek_s_toolz.value:
            return "Big Mek’s Toolz"
        if self.value == NamedWeapon::big_shoota.value:
            return "Big Shoota"
        if self.value == NamedWeapon::big_skorcha.value:
            return "Big Skorcha"
        if self.value == NamedWeapon::blitzkannon.value:
            return "Blitzkannon"
        if self.value == NamedWeapon::boomstikks.value:
            return "Boomstikks"
        if self.value == NamedWeapon::breacha_ram.value:
            return "Breacha Ram"
        if self.value == NamedWeapon::bubblechukka.value:
            return "Bubblechukka"
        if self.value == NamedWeapon::burna.value:
            return "Burna"
        if self.value == NamedWeapon::busta_rokkit_launcha.value:
            return "Busta Rokkit Launcha"
        if self.value == NamedWeapon::butcha_boyz.value:
            return "Butcha Boyz"
        if self.value == NamedWeapon::buzzsaw.value:
            return "Buzzsaw"
        if self.value == NamedWeapon::choppa.value:
            return "Choppa"
        if self.value == NamedWeapon::copper_staff.value:
            return "Copper Staff"
        if self.value == NamedWeapon::crushin_bulk.value:
            return "Crushin’ Bulk"
        if self.value == NamedWeapon::cuttin_flames.value:
            return "Cuttin' Flames"
        if self.value == NamedWeapon::da_gobshot_thunderbuss.value:
            return "Da Gobshot Thunderbuss"
        if self.value == NamedWeapon::da_grabzappa.value:
            return "Da Grabzappa"
        if self.value == NamedWeapon::da_krunch.value:
            return "Da Krunch"
        if self.value == NamedWeapon::da_rippa.value:
            return "Da Rippa"
        if self.value == NamedWeapon::da_vulcha_s_klaws_and_choppa.value:
            return "Da Vulcha's Klaws and Choppa"
        if self.value == NamedWeapon::deff_rolla.value:
            return "Deff Rolla"
        if self.value == NamedWeapon::deffgun.value:
            return "Deffgun"
        if self.value == NamedWeapon::deffkannon_and_supa_rokkits.value:
            return "Deffkannon and Supa-rokkits"
        if self.value == NamedWeapon::deffstorm_mega_shoota.value:
            return "Deffstorm Mega-shoota"
        if self.value == NamedWeapon::dok_s_toolz.value:
            return "Dok’s Toolz"
        if self.value == NamedWeapon::dread_klaws.value:
            return "Dread Klaws"
        if self.value == NamedWeapon::drilla.value:
            return "Drilla"
        if self.value == NamedWeapon::dual_big_shoota.value:
            return "Dual Big Shoota"
        if self.value == NamedWeapon::dual_dakkagun.value:
            return "Dual Dakkagun"
        if self.value == NamedWeapon::dual_grotzooka.value:
            return "Dual Grotzooka"
        if self.value == NamedWeapon::dual_kombi_rokkit.value:
            return "Dual Kombi-rokkit"
        if self.value == NamedWeapon::dual_kustom_mega_blasta.value:
            return "Dual Kustom Mega-blasta"
        if self.value == NamedWeapon::dual_rokkit_launcha.value:
            return "Dual Rokkit Launcha"
        if self.value == NamedWeapon::dual_skorcha.value:
            return "Dual Skorcha"
        if self.value == NamedWeapon::dual_supa_shoota.value:
            return "Dual Supa-shoota"
        if self.value == NamedWeapon::dual_tellyport_mega_blasta.value:
            return "Dual Tellyport Mega-blasta"
        if self.value == NamedWeapon::dual_wazbom_mega_kannon.value:
            return "Dual Wazbom Mega-kannon"
        if self.value == NamedWeapon::extra_dakka.value:
            return "Extra Dakka"
        if self.value == NamedWeapon::extra_klaw.value:
            return "Extra Klaw"
        if self.value == NamedWeapon::fixit_s_wrench.value:
            return "Fixit’s Wrench"
        if self.value == NamedWeapon::gaze_of_gork.value:
            return "Gaze of Gork"
        if self.value == NamedWeapon::gitstikka.value:
            return "Gitstikka"
        if self.value == NamedWeapon::gork_s_klaw.value:
            return "Gork’s Klaw"
        if self.value == NamedWeapon::grabba_dragga.value:
            return "Grabba Dragga"
        if self.value == NamedWeapon::grabbin_klaw.value:
            return "Grabbin’ Klaw"
        if self.value == NamedWeapon::grot_blasta.value:
            return "Grot Blasta"
        if self.value == NamedWeapon::grot_tank_shoota.value:
            return "Grot Tank Shoota"
        if self.value == NamedWeapon::grotzooka.value:
            return "Grotzooka"
        if self.value == NamedWeapon::gun_stock_and_fists.value:
            return "Gun Stock and Fists"
        if self.value == NamedWeapon::gutrippa.value:
            return "Gutrippa"
        if self.value == NamedWeapon::huge_tusks.value:
            return "Huge tusks"
        if self.value == NamedWeapon::kan_blasta.value:
            return "Kan Blasta"
        if self.value == NamedWeapon::kan_klaw.value:
            return "Kan Klaw"
        if self.value == NamedWeapon::kannon.value:
            return "Kannon"
        if self.value == NamedWeapon::killa_jet.value:
            return "Killa Jet"
        if self.value == NamedWeapon::killkannon.value:
            return "Killkannon"
        if self.value == NamedWeapon::killsaw.value:
            return "Killsaw"
        if self.value == NamedWeapon::klaw_of_gork.value:
            return "Klaw of Gork"
        if self.value == NamedWeapon::klaw_of_mork.value:
            return "Klaw of Mork"
        if self.value == NamedWeapon::knucklebustas.value:
            return "Knucklebustas"
        if self.value == NamedWeapon::kombi_rokkit.value:
            return "Kombi-rokkit"
        if self.value == NamedWeapon::kombi_skorcha.value:
            return "Kombi-skorcha"
        if self.value == NamedWeapon::kombi_weapon.value:
            return "Kombi-weapon"
        if self.value == NamedWeapon::kustom_big_shoota.value:
            return "Kustom Big Shoota"
        if self.value == NamedWeapon::kustom_blasta_x.value:
            return "Kustom Blasta X"
        if self.value == NamedWeapon::kustom_choppa.value:
            return "Kustom Choppa"
        if self.value == NamedWeapon::kustom_krumpa.value:
            return "Kustom Krumpa"
        if self.value == NamedWeapon::kustom_mega_blasta.value:
            return "Kustom Mega-blasta"
        if self.value == NamedWeapon::kustom_mega_kannon.value:
            return "Kustom Mega-kannon"
        if self.value == NamedWeapon::kustom_mega_slugga.value:
            return "Kustom Mega-slugga"
        if self.value == NamedWeapon::kustom_mega_zappa.value:
            return "Kustom Mega-zappa"
        if self.value == NamedWeapon::kustom_shoota.value:
            return "Kustom Shoota"
        if self.value == NamedWeapon::lifta_droppa.value:
            return "Lifta-droppa"
        if self.value == NamedWeapon::lobba.value:
            return "Lobba"
        if self.value == NamedWeapon::mega_choppa.value:
            return "Mega-choppa"
        if self.value == NamedWeapon::mega_tank_weapons.value:
            return "Mega-tank Weapons"
        if self.value == NamedWeapon::mek_speshul.value:
            return "Mek Speshul"
        if self.value == NamedWeapon::mek_s_toolz.value:
            return "Mek’s Toolz"
        if self.value == NamedWeapon::moonchewa.value:
            return "Moonchewa"
        if self.value == NamedWeapon::mork_s_roar.value:
            return "Mork’s Roar"
        if self.value == NamedWeapon::mork_s_teef.value:
            return "Mork’s Teef"
        if self.value == NamedWeapon::multi_busta_launcha.value:
            return "Multi-busta Launcha"
        if self.value == NamedWeapon::power_klaw.value:
            return "Power Klaw"
        if self.value == NamedWeapon::power_snappa.value:
            return "Power Snappa"
        if self.value == NamedWeapon::power_vomit.value:
            return "Power Vomit"
        if self.value == NamedWeapon::psyko_gatler.value:
            return "Psyko-gatler"
        if self.value == NamedWeapon::ramshackle_hull.value:
            return "Ramshackle Hull"
        if self.value == NamedWeapon::rivet_kannon.value:
            return "Rivet Kannon"
        if self.value == NamedWeapon::rokkit_launcha.value:
            return "Rokkit Launcha"
        if self.value == NamedWeapon::rokkit_pistol.value:
            return "Rokkit Pistol"
        if self.value == NamedWeapon::runtherd_s_toolz.value:
            return "Runtherd’s Toolz"
        if self.value == NamedWeapon::saddlegit_s_shiv.value:
            return "Saddlegit’s Shiv"
        if self.value == NamedWeapon::savage_horns_and_hooves.value:
            return "Savage Horns and Hooves"
        if self.value == NamedWeapon::saw_blades.value:
            return "Saw Blades"
        if self.value == NamedWeapon::sawn_off_shotgun.value:
            return "Sawn-off Shotgun"
        if self.value == NamedWeapon::scavenged_shivs.value:
            return "Scavenged Shivs"
        if self.value == NamedWeapon::shokk_attack_gun.value:
            return "Shokk Attack Gun"
        if self.value == NamedWeapon::shoota.value:
            return "Shoota"
        if self.value == NamedWeapon::skorcha.value:
            return "Skorcha"
        if self.value == NamedWeapon::skorcha_missile_rack.value:
            return "Skorcha Missile Rack"
        if self.value == NamedWeapon::slugga.value:
            return "Slugga"
        if self.value == NamedWeapon::smash_hammer.value:
            return "Smash Hammer"
        if self.value == NamedWeapon::smasha_gun.value:
            return "Smasha Gun"
        if self.value == NamedWeapon::snagga_klaw.value:
            return "Snagga Klaw"
        if self.value == NamedWeapon::snazzgun.value:
            return "Snazzgun"
        if self.value == NamedWeapon::speeding_bulk_and_flaming_exhaust.value:
            return "Speeding Bulk and Flaming Exhaust"
        if self.value == NamedWeapon::spiked_ram.value:
            return "Spiked Ram"
        if self.value == NamedWeapon::spinnin_blades.value:
            return "Spinnin’ Blades"
        if self.value == NamedWeapon::squig_launchas.value:
            return "Squig Launchas"
        if self.value == NamedWeapon::squigosaur_s_jaws.value:
            return "Squigosaur’s Jaws"
        if self.value == NamedWeapon::squigstoppa.value:
            return "Squigstoppa"
        if self.value == NamedWeapon::squig_s_jaws.value:
            return "Squig’s Jaws"
        if self.value == NamedWeapon::stikka.value:
            return "Stikka"
        if self.value == NamedWeapon::stikka_kannon.value:
            return "Stikka Kannon"
        if self.value == NamedWeapon::stompy_feet.value:
            return "Stompy Feet"
        if self.value == NamedWeapon::supa_gatler.value:
            return "Supa-gatler"
        if self.value == NamedWeapon::supa_kannon.value:
            return "Supa-kannon"
        if self.value == NamedWeapon::tank_kannon.value:
            return "Tank Kannon"
        if self.value == NamedWeapon::tankhammer.value:
            return "Tankhammer"
        if self.value == NamedWeapon::tellyport_blasta.value:
            return "Tellyport Blasta"
        if self.value == NamedWeapon::thump_gun.value:
            return "Thump Gun"
        if self.value == NamedWeapon::traktor_blasta.value:
            return "Traktor Blasta"
        if self.value == NamedWeapon::traktor_kannon.value:
            return "Traktor Kannon"
        if self.value == NamedWeapon::twin_killsaws.value:
            return "Twin Killsaws"
        if self.value == NamedWeapon::wreckin_ball.value:
            return "Wreckin’ Ball"
        if self.value == NamedWeapon::wurrtower.value:
            return "Wurrtower"
        if self.value == NamedWeapon::zzap_gun.value:
            return "Zzap Gun"
        if self.value == NamedWeapon::eavy_lobba.value:
            return "’Eavy Lobba"
        if self.value == NamedWeapon::uge_choppa.value:
            return "’Uge Choppa"
        return "Invalid"

const MAX_WEAPONPROFILECODE = 177
using WeaponProfileCode = LinearlyDistributedInt<0, MAX_WEAPONPROFILECODE>

enum NamedWeaponProfile:
    unknown
    eadbanger
    urty_syringe
    adamantine_eadbutt
    armoured_hull
    armoured_impact
    beast_snagga_klaw
    beast_snagga_klaw_and_beastchoppa
    beastchoppa_hunter
    beastchoppa_standard
    big_chompa_s_jaws
    big_choppa
    big_mek_s_toolz
    big_shoota
    big_skorcha
    blitzkannon
    boomstikks
    breacha_ram
    bubblechukka
    burna
    busta_rokkit_launcha_hunter
    busta_rokkit_launcha_standard
    butcha_boyz
    buzzsaw
    choppa
    choppa_hunter
    choppa_standard
    copper_staff
    crushin_bulk
    cuttin_flames
    da_gobshot_thunderbuss
    da_grabzappa
    da_krunch
    da_rippa_standard
    da_rippa_supercharge
    da_vulcha_s_klaws_and_choppa
    deff_rolla
    deffgun
    deffkannon_and_supa_rokkits
    deffstorm_mega_shoota_aimed
    deffstorm_mega_shoota_point_blank
    dok_s_toolz
    dread_klaws
    drilla
    dual_big_shoota
    dual_dakkagun
    dual_grotzooka
    dual_kombi_rokkit_busta_rokkit
    dual_kombi_rokkit_dakkagun
    dual_kustom_mega_blasta
    dual_rokkit_launcha_blasta
    dual_rokkit_launcha_busta
    dual_skorcha
    dual_supa_shoota
    dual_tellyport_mega_blasta
    dual_wazbom_mega_kannon
    extra_dakka
    extra_klaw
    fixit_s_wrench
    gaze_of_gork_glare
    gaze_of_gork_squint
    gitstikka
    gork_s_klaw
    grabba_dragga_melee
    grabba_dragga_ranged
    grabbin_klaw
    grot_blasta
    grot_tank_shoota
    grotzooka
    gun_stock_and_fists
    gutrippa_hunter
    gutrippa_standard
    huge_tusks_strike
    kan_blasta_dakka
    kan_blasta_kill_shot
    kan_blasta_point_blank
    kan_klaw
    kannon_frag
    kannon_shell
    killa_jet_burna
    killa_jet_cutta
    killkannon
    killsaw
    klaw_of_gork
    klaw_of_mork
    knucklebustas
    kombi_rokkit_busta_rokkit
    kombi_rokkit_shoota
    kombi_skorcha_shoota
    kombi_skorcha_skorcha
    kombi_weapon_kill_shot
    kombi_weapon_point_blank
    kombi_weapon_shoota
    kustom_big_shoota
    kustom_blasta_x
    kustom_blasta_x_gatler
    kustom_blasta_x_shoota
    kustom_blasta_x_skorcha
    kustom_choppa
    kustom_krumpa
    kustom_mega_blasta
    kustom_mega_kannon
    kustom_mega_slugga
    kustom_mega_zappa
    kustom_shoota
    kustom_shoota_aimed
    kustom_shoota_point_blank
    lifta_droppa
    lobba
    mega_choppa
    mega_tank_weapons
    mek_speshul_aimed
    mek_speshul_point_blank
    mek_s_toolz
    moonchewa
    mork_s_roar_aimed
    mork_s_roar_point_blank
    mork_s_teef
    multi_busta_launcha
    power_klaw
    power_snappa
    power_vomit
    psyko_gatler
    ramshackle_hull
    rivet_kannon_aimed
    rivet_kannon_point_blank
    rokkit_launcha_blasta
    rokkit_launcha_busta
    rokkit_pistol
    runtherd_s_toolz
    saddlegit_s_shiv
    savage_horns_and_hooves
    saw_blades
    sawn_off_shotgun
    scavenged_shivs
    shokk_attack_gun
    shoota
    skorcha
    skorcha_missile_rack
    slugga
    smash_hammer_hunter
    smash_hammer_standard
    smasha_gun
    snagga_klaw_melee
    snagga_klaw_ranged
    snazzgun_cutta
    snazzgun_dakka
    snazzgun_kill_shot
    speeding_bulk_and_flaming_exhaust
    spiked_ram
    spinnin_blades
    squig_launchas
    squigosaur_s_jaws
    squigstoppa
    squig_s_jaws
    stikka_melee
    stikka_ranged
    stikka_kannon
    stompy_feet
    supa_gatler_aimed
    supa_gatler_point_blank
    supa_kannon
    supa_kannon_frag
    supa_kannon_shell
    tank_kannon_blasta
    tank_kannon_tankhamma
    tankhammer
    tellyport_blasta
    thump_gun
    traktor_blasta
    traktor_kannon
    twin_killsaws
    wreckin_ball
    wurrtower
    zzap_gun
    eavy_lobba
    uge_choppa

    # Source labels are metadata; identities are compact standard bounded codes.
    fun label() -> StringLiteral:
        if self.value == NamedWeaponProfile::unknown.value:
            return "Unknown"
        if self.value == NamedWeaponProfile::eadbanger.value:
            return "'Eadbanger"
        if self.value == NamedWeaponProfile::urty_syringe.value:
            return "’Urty Syringe"
        if self.value == NamedWeaponProfile::adamantine_eadbutt.value:
            return "Adamantine ’Eadbutt"
        if self.value == NamedWeaponProfile::armoured_hull.value:
            return "Armoured Hull"
        if self.value == NamedWeaponProfile::armoured_impact.value:
            return "Armoured Impact"
        if self.value == NamedWeaponProfile::beast_snagga_klaw.value:
            return "Beast Snagga Klaw"
        if self.value == NamedWeaponProfile::beast_snagga_klaw_and_beastchoppa.value:
            return "Beast Snagga Klaw and Beastchoppa"
        if self.value == NamedWeaponProfile::beastchoppa_hunter.value:
            return "Beastchoppa - Hunter"
        if self.value == NamedWeaponProfile::beastchoppa_standard.value:
            return "Beastchoppa - Standard"
        if self.value == NamedWeaponProfile::big_chompa_s_jaws.value:
            return "Big Chompa’s Jaws"
        if self.value == NamedWeaponProfile::big_choppa.value:
            return "Big Choppa"
        if self.value == NamedWeaponProfile::big_mek_s_toolz.value:
            return "Big Mek’s Toolz"
        if self.value == NamedWeaponProfile::big_shoota.value:
            return "Big Shoota"
        if self.value == NamedWeaponProfile::big_skorcha.value:
            return "Big Skorcha"
        if self.value == NamedWeaponProfile::blitzkannon.value:
            return "Blitzkannon"
        if self.value == NamedWeaponProfile::boomstikks.value:
            return "Boomstikks"
        if self.value == NamedWeaponProfile::breacha_ram.value:
            return "Breacha Ram"
        if self.value == NamedWeaponProfile::bubblechukka.value:
            return "Bubblechukka"
        if self.value == NamedWeaponProfile::burna.value:
            return "Burna"
        if self.value == NamedWeaponProfile::busta_rokkit_launcha_hunter.value:
            return "Busta Rokkit Launcha - Hunter"
        if self.value == NamedWeaponProfile::busta_rokkit_launcha_standard.value:
            return "Busta Rokkit Launcha - Standard"
        if self.value == NamedWeaponProfile::butcha_boyz.value:
            return "Butcha Boyz"
        if self.value == NamedWeaponProfile::buzzsaw.value:
            return "Buzzsaw"
        if self.value == NamedWeaponProfile::choppa.value:
            return "Choppa"
        if self.value == NamedWeaponProfile::choppa_hunter.value:
            return "Choppa - Hunter"
        if self.value == NamedWeaponProfile::choppa_standard.value:
            return "Choppa - Standard"
        if self.value == NamedWeaponProfile::copper_staff.value:
            return "Copper Staff"
        if self.value == NamedWeaponProfile::crushin_bulk.value:
            return "Crushin’ Bulk"
        if self.value == NamedWeaponProfile::cuttin_flames.value:
            return "Cuttin' Flames"
        if self.value == NamedWeaponProfile::da_gobshot_thunderbuss.value:
            return "Da Gobshot Thunderbuss"
        if self.value == NamedWeaponProfile::da_grabzappa.value:
            return "Da Grabzappa"
        if self.value == NamedWeaponProfile::da_krunch.value:
            return "Da Krunch"
        if self.value == NamedWeaponProfile::da_rippa_standard.value:
            return "Da Rippa - Standard"
        if self.value == NamedWeaponProfile::da_rippa_supercharge.value:
            return "Da Rippa - Supercharge"
        if self.value == NamedWeaponProfile::da_vulcha_s_klaws_and_choppa.value:
            return "Da Vulcha's Klaws and Choppa"
        if self.value == NamedWeaponProfile::deff_rolla.value:
            return "Deff Rolla"
        if self.value == NamedWeaponProfile::deffgun.value:
            return "Deffgun"
        if self.value == NamedWeaponProfile::deffkannon_and_supa_rokkits.value:
            return "Deffkannon and Supa-rokkits"
        if self.value == NamedWeaponProfile::deffstorm_mega_shoota_aimed.value:
            return "Deffstorm Mega-shoota - Aimed"
        if self.value == NamedWeaponProfile::deffstorm_mega_shoota_point_blank.value:
            return "Deffstorm Mega-shoota - Point Blank"
        if self.value == NamedWeaponProfile::dok_s_toolz.value:
            return "Dok’s Toolz"
        if self.value == NamedWeaponProfile::dread_klaws.value:
            return "Dread Klaws"
        if self.value == NamedWeaponProfile::drilla.value:
            return "Drilla"
        if self.value == NamedWeaponProfile::dual_big_shoota.value:
            return "Dual Big Shoota"
        if self.value == NamedWeaponProfile::dual_dakkagun.value:
            return "Dual Dakkagun"
        if self.value == NamedWeaponProfile::dual_grotzooka.value:
            return "Dual Grotzooka"
        if self.value == NamedWeaponProfile::dual_kombi_rokkit_busta_rokkit.value:
            return "Dual Kombi-rokkit - Busta Rokkit"
        if self.value == NamedWeaponProfile::dual_kombi_rokkit_dakkagun.value:
            return "Dual Kombi-rokkit - Dakkagun"
        if self.value == NamedWeaponProfile::dual_kustom_mega_blasta.value:
            return "Dual Kustom Mega-blasta"
        if self.value == NamedWeaponProfile::dual_rokkit_launcha_blasta.value:
            return "Dual Rokkit Launcha - Blasta"
        if self.value == NamedWeaponProfile::dual_rokkit_launcha_busta.value:
            return "Dual Rokkit Launcha - Busta"
        if self.value == NamedWeaponProfile::dual_skorcha.value:
            return "Dual Skorcha"
        if self.value == NamedWeaponProfile::dual_supa_shoota.value:
            return "Dual Supa-shoota"
        if self.value == NamedWeaponProfile::dual_tellyport_mega_blasta.value:
            return "Dual Tellyport Mega-blasta"
        if self.value == NamedWeaponProfile::dual_wazbom_mega_kannon.value:
            return "Dual Wazbom Mega-kannon"
        if self.value == NamedWeaponProfile::extra_dakka.value:
            return "Extra Dakka"
        if self.value == NamedWeaponProfile::extra_klaw.value:
            return "Extra Klaw"
        if self.value == NamedWeaponProfile::fixit_s_wrench.value:
            return "Fixit’s Wrench"
        if self.value == NamedWeaponProfile::gaze_of_gork_glare.value:
            return "Gaze of Gork - Glare"
        if self.value == NamedWeaponProfile::gaze_of_gork_squint.value:
            return "Gaze of Gork - Squint"
        if self.value == NamedWeaponProfile::gitstikka.value:
            return "Gitstikka"
        if self.value == NamedWeaponProfile::gork_s_klaw.value:
            return "Gork’s Klaw"
        if self.value == NamedWeaponProfile::grabba_dragga_melee.value:
            return "Grabba Dragga (melee)"
        if self.value == NamedWeaponProfile::grabba_dragga_ranged.value:
            return "Grabba Dragga (ranged)"
        if self.value == NamedWeaponProfile::grabbin_klaw.value:
            return "Grabbin’ Klaw"
        if self.value == NamedWeaponProfile::grot_blasta.value:
            return "Grot Blasta"
        if self.value == NamedWeaponProfile::grot_tank_shoota.value:
            return "Grot Tank Shoota"
        if self.value == NamedWeaponProfile::grotzooka.value:
            return "Grotzooka"
        if self.value == NamedWeaponProfile::gun_stock_and_fists.value:
            return "Gun Stock and Fists"
        if self.value == NamedWeaponProfile::gutrippa_hunter.value:
            return "Gutrippa - Hunter"
        if self.value == NamedWeaponProfile::gutrippa_standard.value:
            return "Gutrippa - Standard"
        if self.value == NamedWeaponProfile::huge_tusks_strike.value:
            return "Huge tusks - strike"
        if self.value == NamedWeaponProfile::kan_blasta_dakka.value:
            return "Kan Blasta - Dakka"
        if self.value == NamedWeaponProfile::kan_blasta_kill_shot.value:
            return "Kan Blasta - Kill Shot"
        if self.value == NamedWeaponProfile::kan_blasta_point_blank.value:
            return "Kan Blasta - Point Blank"
        if self.value == NamedWeaponProfile::kan_klaw.value:
            return "Kan Klaw"
        if self.value == NamedWeaponProfile::kannon_frag.value:
            return "Kannon - frag"
        if self.value == NamedWeaponProfile::kannon_shell.value:
            return "Kannon - shell"
        if self.value == NamedWeaponProfile::killa_jet_burna.value:
            return "Killa Jet - Burna"
        if self.value == NamedWeaponProfile::killa_jet_cutta.value:
            return "Killa Jet - Cutta"
        if self.value == NamedWeaponProfile::killkannon.value:
            return "Killkannon"
        if self.value == NamedWeaponProfile::killsaw.value:
            return "Killsaw"
        if self.value == NamedWeaponProfile::klaw_of_gork.value:
            return "Klaw of Gork"
        if self.value == NamedWeaponProfile::klaw_of_mork.value:
            return "Klaw of Mork"
        if self.value == NamedWeaponProfile::knucklebustas.value:
            return "Knucklebustas"
        if self.value == NamedWeaponProfile::kombi_rokkit_busta_rokkit.value:
            return "Kombi-rokkit - Busta Rokkit"
        if self.value == NamedWeaponProfile::kombi_rokkit_shoota.value:
            return "Kombi-rokkit - Shoota"
        if self.value == NamedWeaponProfile::kombi_skorcha_shoota.value:
            return "Kombi-skorcha - Shoota"
        if self.value == NamedWeaponProfile::kombi_skorcha_skorcha.value:
            return "Kombi-skorcha - Skorcha"
        if self.value == NamedWeaponProfile::kombi_weapon_kill_shot.value:
            return "Kombi-weapon - Kill Shot"
        if self.value == NamedWeaponProfile::kombi_weapon_point_blank.value:
            return "Kombi-weapon - Point Blank"
        if self.value == NamedWeaponProfile::kombi_weapon_shoota.value:
            return "Kombi-weapon - Shoota"
        if self.value == NamedWeaponProfile::kustom_big_shoota.value:
            return "Kustom Big Shoota"
        if self.value == NamedWeaponProfile::kustom_blasta_x.value:
            return "Kustom Blasta X"
        if self.value == NamedWeaponProfile::kustom_blasta_x_gatler.value:
            return "Kustom Blasta X - Gatler"
        if self.value == NamedWeaponProfile::kustom_blasta_x_shoota.value:
            return "Kustom Blasta X - Shoota"
        if self.value == NamedWeaponProfile::kustom_blasta_x_skorcha.value:
            return "Kustom Blasta X - Skorcha"
        if self.value == NamedWeaponProfile::kustom_choppa.value:
            return "Kustom Choppa"
        if self.value == NamedWeaponProfile::kustom_krumpa.value:
            return "Kustom Krumpa"
        if self.value == NamedWeaponProfile::kustom_mega_blasta.value:
            return "Kustom Mega-blasta"
        if self.value == NamedWeaponProfile::kustom_mega_kannon.value:
            return "Kustom Mega-kannon"
        if self.value == NamedWeaponProfile::kustom_mega_slugga.value:
            return "Kustom Mega-slugga"
        if self.value == NamedWeaponProfile::kustom_mega_zappa.value:
            return "Kustom Mega-zappa"
        if self.value == NamedWeaponProfile::kustom_shoota.value:
            return "Kustom Shoota"
        if self.value == NamedWeaponProfile::kustom_shoota_aimed.value:
            return "Kustom Shoota - Aimed"
        if self.value == NamedWeaponProfile::kustom_shoota_point_blank.value:
            return "Kustom Shoota - Point Blank"
        if self.value == NamedWeaponProfile::lifta_droppa.value:
            return "Lifta-droppa"
        if self.value == NamedWeaponProfile::lobba.value:
            return "Lobba"
        if self.value == NamedWeaponProfile::mega_choppa.value:
            return "Mega-choppa"
        if self.value == NamedWeaponProfile::mega_tank_weapons.value:
            return "Mega-tank Weapons"
        if self.value == NamedWeaponProfile::mek_speshul_aimed.value:
            return "Mek Speshul - Aimed"
        if self.value == NamedWeaponProfile::mek_speshul_point_blank.value:
            return "Mek Speshul - Point Blank"
        if self.value == NamedWeaponProfile::mek_s_toolz.value:
            return "Mek’s Toolz"
        if self.value == NamedWeaponProfile::moonchewa.value:
            return "Moonchewa"
        if self.value == NamedWeaponProfile::mork_s_roar_aimed.value:
            return "Mork’s Roar - Aimed"
        if self.value == NamedWeaponProfile::mork_s_roar_point_blank.value:
            return "Mork’s Roar - Point Blank"
        if self.value == NamedWeaponProfile::mork_s_teef.value:
            return "Mork’s Teef"
        if self.value == NamedWeaponProfile::multi_busta_launcha.value:
            return "Multi-busta Launcha"
        if self.value == NamedWeaponProfile::power_klaw.value:
            return "Power Klaw"
        if self.value == NamedWeaponProfile::power_snappa.value:
            return "Power Snappa"
        if self.value == NamedWeaponProfile::power_vomit.value:
            return "Power Vomit"
        if self.value == NamedWeaponProfile::psyko_gatler.value:
            return "Psyko-gatler"
        if self.value == NamedWeaponProfile::ramshackle_hull.value:
            return "Ramshackle Hull"
        if self.value == NamedWeaponProfile::rivet_kannon_aimed.value:
            return "Rivet Kannon - Aimed"
        if self.value == NamedWeaponProfile::rivet_kannon_point_blank.value:
            return "Rivet Kannon - Point Blank"
        if self.value == NamedWeaponProfile::rokkit_launcha_blasta.value:
            return "Rokkit Launcha - Blasta"
        if self.value == NamedWeaponProfile::rokkit_launcha_busta.value:
            return "Rokkit Launcha - Busta"
        if self.value == NamedWeaponProfile::rokkit_pistol.value:
            return "Rokkit Pistol"
        if self.value == NamedWeaponProfile::runtherd_s_toolz.value:
            return "Runtherd’s Toolz"
        if self.value == NamedWeaponProfile::saddlegit_s_shiv.value:
            return "Saddlegit’s Shiv"
        if self.value == NamedWeaponProfile::savage_horns_and_hooves.value:
            return "Savage Horns and Hooves"
        if self.value == NamedWeaponProfile::saw_blades.value:
            return "Saw Blades"
        if self.value == NamedWeaponProfile::sawn_off_shotgun.value:
            return "Sawn-off Shotgun"
        if self.value == NamedWeaponProfile::scavenged_shivs.value:
            return "Scavenged Shivs"
        if self.value == NamedWeaponProfile::shokk_attack_gun.value:
            return "Shokk Attack Gun"
        if self.value == NamedWeaponProfile::shoota.value:
            return "Shoota"
        if self.value == NamedWeaponProfile::skorcha.value:
            return "Skorcha"
        if self.value == NamedWeaponProfile::skorcha_missile_rack.value:
            return "Skorcha Missile Rack"
        if self.value == NamedWeaponProfile::slugga.value:
            return "Slugga"
        if self.value == NamedWeaponProfile::smash_hammer_hunter.value:
            return "Smash Hammer - Hunter"
        if self.value == NamedWeaponProfile::smash_hammer_standard.value:
            return "Smash Hammer - Standard"
        if self.value == NamedWeaponProfile::smasha_gun.value:
            return "Smasha Gun"
        if self.value == NamedWeaponProfile::snagga_klaw_melee.value:
            return "Snagga Klaw (melee)"
        if self.value == NamedWeaponProfile::snagga_klaw_ranged.value:
            return "Snagga Klaw (ranged)"
        if self.value == NamedWeaponProfile::snazzgun_cutta.value:
            return "Snazzgun - Cutta"
        if self.value == NamedWeaponProfile::snazzgun_dakka.value:
            return "Snazzgun - Dakka"
        if self.value == NamedWeaponProfile::snazzgun_kill_shot.value:
            return "Snazzgun - Kill Shot"
        if self.value == NamedWeaponProfile::speeding_bulk_and_flaming_exhaust.value:
            return "Speeding Bulk and Flaming Exhaust"
        if self.value == NamedWeaponProfile::spiked_ram.value:
            return "Spiked Ram"
        if self.value == NamedWeaponProfile::spinnin_blades.value:
            return "Spinnin’ Blades"
        if self.value == NamedWeaponProfile::squig_launchas.value:
            return "Squig Launchas"
        if self.value == NamedWeaponProfile::squigosaur_s_jaws.value:
            return "Squigosaur’s Jaws"
        if self.value == NamedWeaponProfile::squigstoppa.value:
            return "Squigstoppa"
        if self.value == NamedWeaponProfile::squig_s_jaws.value:
            return "Squig’s Jaws"
        if self.value == NamedWeaponProfile::stikka_melee.value:
            return "Stikka (melee)"
        if self.value == NamedWeaponProfile::stikka_ranged.value:
            return "Stikka (ranged)"
        if self.value == NamedWeaponProfile::stikka_kannon.value:
            return "Stikka Kannon"
        if self.value == NamedWeaponProfile::stompy_feet.value:
            return "Stompy Feet"
        if self.value == NamedWeaponProfile::supa_gatler_aimed.value:
            return "Supa-gatler - Aimed"
        if self.value == NamedWeaponProfile::supa_gatler_point_blank.value:
            return "Supa-gatler - Point Blank"
        if self.value == NamedWeaponProfile::supa_kannon.value:
            return "Supa-kannon"
        if self.value == NamedWeaponProfile::supa_kannon_frag.value:
            return "Supa-kannon - Frag"
        if self.value == NamedWeaponProfile::supa_kannon_shell.value:
            return "Supa-kannon - Shell"
        if self.value == NamedWeaponProfile::tank_kannon_blasta.value:
            return "Tank Kannon - Blasta"
        if self.value == NamedWeaponProfile::tank_kannon_tankhamma.value:
            return "Tank Kannon - Tankhamma"
        if self.value == NamedWeaponProfile::tankhammer.value:
            return "Tankhammer"
        if self.value == NamedWeaponProfile::tellyport_blasta.value:
            return "Tellyport Blasta"
        if self.value == NamedWeaponProfile::thump_gun.value:
            return "Thump Gun"
        if self.value == NamedWeaponProfile::traktor_blasta.value:
            return "Traktor Blasta"
        if self.value == NamedWeaponProfile::traktor_kannon.value:
            return "Traktor Kannon"
        if self.value == NamedWeaponProfile::twin_killsaws.value:
            return "Twin Killsaws"
        if self.value == NamedWeaponProfile::wreckin_ball.value:
            return "Wreckin’ Ball"
        if self.value == NamedWeaponProfile::wurrtower.value:
            return "Wurrtower"
        if self.value == NamedWeaponProfile::zzap_gun.value:
            return "Zzap Gun"
        if self.value == NamedWeaponProfile::eavy_lobba.value:
            return "’Eavy Lobba"
        if self.value == NamedWeaponProfile::uge_choppa.value:
            return "’Uge Choppa"
        return "Invalid"

# Profiles retain their printed physical weapon family (appendix04.01.03).
# This identity mapping does not import stats or equipment permissions.
fun named_profile_weapon(NamedWeaponProfile profile) -> NamedWeapon:
    if profile.value == NamedWeaponProfile::eadbanger.value:
        return NamedWeapon::eadbanger
    if profile.value == NamedWeaponProfile::urty_syringe.value:
        return NamedWeapon::urty_syringe
    if profile.value == NamedWeaponProfile::adamantine_eadbutt.value:
        return NamedWeapon::adamantine_eadbutt
    if profile.value == NamedWeaponProfile::armoured_hull.value:
        return NamedWeapon::armoured_hull
    if profile.value == NamedWeaponProfile::armoured_impact.value:
        return NamedWeapon::armoured_impact
    if profile.value == NamedWeaponProfile::beast_snagga_klaw.value:
        return NamedWeapon::beast_snagga_klaw
    if profile.value == NamedWeaponProfile::beast_snagga_klaw_and_beastchoppa.value:
        return NamedWeapon::beast_snagga_klaw_and_beastchoppa
    if profile.value == NamedWeaponProfile::beastchoppa_hunter.value:
        return NamedWeapon::beastchoppa
    if profile.value == NamedWeaponProfile::beastchoppa_standard.value:
        return NamedWeapon::beastchoppa
    if profile.value == NamedWeaponProfile::big_chompa_s_jaws.value:
        return NamedWeapon::big_chompa_s_jaws
    if profile.value == NamedWeaponProfile::big_choppa.value:
        return NamedWeapon::big_choppa
    if profile.value == NamedWeaponProfile::big_mek_s_toolz.value:
        return NamedWeapon::big_mek_s_toolz
    if profile.value == NamedWeaponProfile::big_shoota.value:
        return NamedWeapon::big_shoota
    if profile.value == NamedWeaponProfile::big_skorcha.value:
        return NamedWeapon::big_skorcha
    if profile.value == NamedWeaponProfile::blitzkannon.value:
        return NamedWeapon::blitzkannon
    if profile.value == NamedWeaponProfile::boomstikks.value:
        return NamedWeapon::boomstikks
    if profile.value == NamedWeaponProfile::breacha_ram.value:
        return NamedWeapon::breacha_ram
    if profile.value == NamedWeaponProfile::bubblechukka.value:
        return NamedWeapon::bubblechukka
    if profile.value == NamedWeaponProfile::burna.value:
        return NamedWeapon::burna
    if profile.value == NamedWeaponProfile::busta_rokkit_launcha_hunter.value:
        return NamedWeapon::busta_rokkit_launcha
    if profile.value == NamedWeaponProfile::busta_rokkit_launcha_standard.value:
        return NamedWeapon::busta_rokkit_launcha
    if profile.value == NamedWeaponProfile::butcha_boyz.value:
        return NamedWeapon::butcha_boyz
    if profile.value == NamedWeaponProfile::buzzsaw.value:
        return NamedWeapon::buzzsaw
    if profile.value == NamedWeaponProfile::choppa.value:
        return NamedWeapon::choppa
    if profile.value == NamedWeaponProfile::choppa_hunter.value:
        return NamedWeapon::choppa
    if profile.value == NamedWeaponProfile::choppa_standard.value:
        return NamedWeapon::choppa
    if profile.value == NamedWeaponProfile::copper_staff.value:
        return NamedWeapon::copper_staff
    if profile.value == NamedWeaponProfile::crushin_bulk.value:
        return NamedWeapon::crushin_bulk
    if profile.value == NamedWeaponProfile::cuttin_flames.value:
        return NamedWeapon::cuttin_flames
    if profile.value == NamedWeaponProfile::da_gobshot_thunderbuss.value:
        return NamedWeapon::da_gobshot_thunderbuss
    if profile.value == NamedWeaponProfile::da_grabzappa.value:
        return NamedWeapon::da_grabzappa
    if profile.value == NamedWeaponProfile::da_krunch.value:
        return NamedWeapon::da_krunch
    if profile.value == NamedWeaponProfile::da_rippa_standard.value:
        return NamedWeapon::da_rippa
    if profile.value == NamedWeaponProfile::da_rippa_supercharge.value:
        return NamedWeapon::da_rippa
    if profile.value == NamedWeaponProfile::da_vulcha_s_klaws_and_choppa.value:
        return NamedWeapon::da_vulcha_s_klaws_and_choppa
    if profile.value == NamedWeaponProfile::deff_rolla.value:
        return NamedWeapon::deff_rolla
    if profile.value == NamedWeaponProfile::deffgun.value:
        return NamedWeapon::deffgun
    if profile.value == NamedWeaponProfile::deffkannon_and_supa_rokkits.value:
        return NamedWeapon::deffkannon_and_supa_rokkits
    if profile.value == NamedWeaponProfile::deffstorm_mega_shoota_aimed.value:
        return NamedWeapon::deffstorm_mega_shoota
    if profile.value == NamedWeaponProfile::deffstorm_mega_shoota_point_blank.value:
        return NamedWeapon::deffstorm_mega_shoota
    if profile.value == NamedWeaponProfile::dok_s_toolz.value:
        return NamedWeapon::dok_s_toolz
    if profile.value == NamedWeaponProfile::dread_klaws.value:
        return NamedWeapon::dread_klaws
    if profile.value == NamedWeaponProfile::drilla.value:
        return NamedWeapon::drilla
    if profile.value == NamedWeaponProfile::dual_big_shoota.value:
        return NamedWeapon::dual_big_shoota
    if profile.value == NamedWeaponProfile::dual_dakkagun.value:
        return NamedWeapon::dual_dakkagun
    if profile.value == NamedWeaponProfile::dual_grotzooka.value:
        return NamedWeapon::dual_grotzooka
    if profile.value == NamedWeaponProfile::dual_kombi_rokkit_busta_rokkit.value:
        return NamedWeapon::dual_kombi_rokkit
    if profile.value == NamedWeaponProfile::dual_kombi_rokkit_dakkagun.value:
        return NamedWeapon::dual_kombi_rokkit
    if profile.value == NamedWeaponProfile::dual_kustom_mega_blasta.value:
        return NamedWeapon::dual_kustom_mega_blasta
    if profile.value == NamedWeaponProfile::dual_rokkit_launcha_blasta.value:
        return NamedWeapon::dual_rokkit_launcha
    if profile.value == NamedWeaponProfile::dual_rokkit_launcha_busta.value:
        return NamedWeapon::dual_rokkit_launcha
    if profile.value == NamedWeaponProfile::dual_skorcha.value:
        return NamedWeapon::dual_skorcha
    if profile.value == NamedWeaponProfile::dual_supa_shoota.value:
        return NamedWeapon::dual_supa_shoota
    if profile.value == NamedWeaponProfile::dual_tellyport_mega_blasta.value:
        return NamedWeapon::dual_tellyport_mega_blasta
    if profile.value == NamedWeaponProfile::dual_wazbom_mega_kannon.value:
        return NamedWeapon::dual_wazbom_mega_kannon
    if profile.value == NamedWeaponProfile::extra_dakka.value:
        return NamedWeapon::extra_dakka
    if profile.value == NamedWeaponProfile::extra_klaw.value:
        return NamedWeapon::extra_klaw
    if profile.value == NamedWeaponProfile::fixit_s_wrench.value:
        return NamedWeapon::fixit_s_wrench
    if profile.value == NamedWeaponProfile::gaze_of_gork_glare.value:
        return NamedWeapon::gaze_of_gork
    if profile.value == NamedWeaponProfile::gaze_of_gork_squint.value:
        return NamedWeapon::gaze_of_gork
    if profile.value == NamedWeaponProfile::gitstikka.value:
        return NamedWeapon::gitstikka
    if profile.value == NamedWeaponProfile::gork_s_klaw.value:
        return NamedWeapon::gork_s_klaw
    if profile.value == NamedWeaponProfile::grabba_dragga_melee.value:
        return NamedWeapon::grabba_dragga
    if profile.value == NamedWeaponProfile::grabba_dragga_ranged.value:
        return NamedWeapon::grabba_dragga
    if profile.value == NamedWeaponProfile::grabbin_klaw.value:
        return NamedWeapon::grabbin_klaw
    if profile.value == NamedWeaponProfile::grot_blasta.value:
        return NamedWeapon::grot_blasta
    if profile.value == NamedWeaponProfile::grot_tank_shoota.value:
        return NamedWeapon::grot_tank_shoota
    if profile.value == NamedWeaponProfile::grotzooka.value:
        return NamedWeapon::grotzooka
    if profile.value == NamedWeaponProfile::gun_stock_and_fists.value:
        return NamedWeapon::gun_stock_and_fists
    if profile.value == NamedWeaponProfile::gutrippa_hunter.value:
        return NamedWeapon::gutrippa
    if profile.value == NamedWeaponProfile::gutrippa_standard.value:
        return NamedWeapon::gutrippa
    if profile.value == NamedWeaponProfile::huge_tusks_strike.value:
        return NamedWeapon::huge_tusks
    if profile.value == NamedWeaponProfile::kan_blasta_dakka.value:
        return NamedWeapon::kan_blasta
    if profile.value == NamedWeaponProfile::kan_blasta_kill_shot.value:
        return NamedWeapon::kan_blasta
    if profile.value == NamedWeaponProfile::kan_blasta_point_blank.value:
        return NamedWeapon::kan_blasta
    if profile.value == NamedWeaponProfile::kan_klaw.value:
        return NamedWeapon::kan_klaw
    if profile.value == NamedWeaponProfile::kannon_frag.value:
        return NamedWeapon::kannon
    if profile.value == NamedWeaponProfile::kannon_shell.value:
        return NamedWeapon::kannon
    if profile.value == NamedWeaponProfile::killa_jet_burna.value:
        return NamedWeapon::killa_jet
    if profile.value == NamedWeaponProfile::killa_jet_cutta.value:
        return NamedWeapon::killa_jet
    if profile.value == NamedWeaponProfile::killkannon.value:
        return NamedWeapon::killkannon
    if profile.value == NamedWeaponProfile::killsaw.value:
        return NamedWeapon::killsaw
    if profile.value == NamedWeaponProfile::klaw_of_gork.value:
        return NamedWeapon::klaw_of_gork
    if profile.value == NamedWeaponProfile::klaw_of_mork.value:
        return NamedWeapon::klaw_of_mork
    if profile.value == NamedWeaponProfile::knucklebustas.value:
        return NamedWeapon::knucklebustas
    if profile.value == NamedWeaponProfile::kombi_rokkit_busta_rokkit.value:
        return NamedWeapon::kombi_rokkit
    if profile.value == NamedWeaponProfile::kombi_rokkit_shoota.value:
        return NamedWeapon::kombi_rokkit
    if profile.value == NamedWeaponProfile::kombi_skorcha_shoota.value:
        return NamedWeapon::kombi_skorcha
    if profile.value == NamedWeaponProfile::kombi_skorcha_skorcha.value:
        return NamedWeapon::kombi_skorcha
    if profile.value == NamedWeaponProfile::kombi_weapon_kill_shot.value:
        return NamedWeapon::kombi_weapon
    if profile.value == NamedWeaponProfile::kombi_weapon_point_blank.value:
        return NamedWeapon::kombi_weapon
    if profile.value == NamedWeaponProfile::kombi_weapon_shoota.value:
        return NamedWeapon::kombi_weapon
    if profile.value == NamedWeaponProfile::kustom_big_shoota.value:
        return NamedWeapon::kustom_big_shoota
    if profile.value == NamedWeaponProfile::kustom_blasta_x.value:
        return NamedWeapon::kustom_blasta_x
    if profile.value == NamedWeaponProfile::kustom_blasta_x_gatler.value:
        return NamedWeapon::kustom_blasta_x
    if profile.value == NamedWeaponProfile::kustom_blasta_x_shoota.value:
        return NamedWeapon::kustom_blasta_x
    if profile.value == NamedWeaponProfile::kustom_blasta_x_skorcha.value:
        return NamedWeapon::kustom_blasta_x
    if profile.value == NamedWeaponProfile::kustom_choppa.value:
        return NamedWeapon::kustom_choppa
    if profile.value == NamedWeaponProfile::kustom_krumpa.value:
        return NamedWeapon::kustom_krumpa
    if profile.value == NamedWeaponProfile::kustom_mega_blasta.value:
        return NamedWeapon::kustom_mega_blasta
    if profile.value == NamedWeaponProfile::kustom_mega_kannon.value:
        return NamedWeapon::kustom_mega_kannon
    if profile.value == NamedWeaponProfile::kustom_mega_slugga.value:
        return NamedWeapon::kustom_mega_slugga
    if profile.value == NamedWeaponProfile::kustom_mega_zappa.value:
        return NamedWeapon::kustom_mega_zappa
    if profile.value == NamedWeaponProfile::kustom_shoota.value:
        return NamedWeapon::kustom_shoota
    if profile.value == NamedWeaponProfile::kustom_shoota_aimed.value:
        return NamedWeapon::kustom_shoota
    if profile.value == NamedWeaponProfile::kustom_shoota_point_blank.value:
        return NamedWeapon::kustom_shoota
    if profile.value == NamedWeaponProfile::lifta_droppa.value:
        return NamedWeapon::lifta_droppa
    if profile.value == NamedWeaponProfile::lobba.value:
        return NamedWeapon::lobba
    if profile.value == NamedWeaponProfile::mega_choppa.value:
        return NamedWeapon::mega_choppa
    if profile.value == NamedWeaponProfile::mega_tank_weapons.value:
        return NamedWeapon::mega_tank_weapons
    if profile.value == NamedWeaponProfile::mek_speshul_aimed.value:
        return NamedWeapon::mek_speshul
    if profile.value == NamedWeaponProfile::mek_speshul_point_blank.value:
        return NamedWeapon::mek_speshul
    if profile.value == NamedWeaponProfile::mek_s_toolz.value:
        return NamedWeapon::mek_s_toolz
    if profile.value == NamedWeaponProfile::moonchewa.value:
        return NamedWeapon::moonchewa
    if profile.value == NamedWeaponProfile::mork_s_roar_aimed.value:
        return NamedWeapon::mork_s_roar
    if profile.value == NamedWeaponProfile::mork_s_roar_point_blank.value:
        return NamedWeapon::mork_s_roar
    if profile.value == NamedWeaponProfile::mork_s_teef.value:
        return NamedWeapon::mork_s_teef
    if profile.value == NamedWeaponProfile::multi_busta_launcha.value:
        return NamedWeapon::multi_busta_launcha
    if profile.value == NamedWeaponProfile::power_klaw.value:
        return NamedWeapon::power_klaw
    if profile.value == NamedWeaponProfile::power_snappa.value:
        return NamedWeapon::power_snappa
    if profile.value == NamedWeaponProfile::power_vomit.value:
        return NamedWeapon::power_vomit
    if profile.value == NamedWeaponProfile::psyko_gatler.value:
        return NamedWeapon::psyko_gatler
    if profile.value == NamedWeaponProfile::ramshackle_hull.value:
        return NamedWeapon::ramshackle_hull
    if profile.value == NamedWeaponProfile::rivet_kannon_aimed.value:
        return NamedWeapon::rivet_kannon
    if profile.value == NamedWeaponProfile::rivet_kannon_point_blank.value:
        return NamedWeapon::rivet_kannon
    if profile.value == NamedWeaponProfile::rokkit_launcha_blasta.value:
        return NamedWeapon::rokkit_launcha
    if profile.value == NamedWeaponProfile::rokkit_launcha_busta.value:
        return NamedWeapon::rokkit_launcha
    if profile.value == NamedWeaponProfile::rokkit_pistol.value:
        return NamedWeapon::rokkit_pistol
    if profile.value == NamedWeaponProfile::runtherd_s_toolz.value:
        return NamedWeapon::runtherd_s_toolz
    if profile.value == NamedWeaponProfile::saddlegit_s_shiv.value:
        return NamedWeapon::saddlegit_s_shiv
    if profile.value == NamedWeaponProfile::savage_horns_and_hooves.value:
        return NamedWeapon::savage_horns_and_hooves
    if profile.value == NamedWeaponProfile::saw_blades.value:
        return NamedWeapon::saw_blades
    if profile.value == NamedWeaponProfile::sawn_off_shotgun.value:
        return NamedWeapon::sawn_off_shotgun
    if profile.value == NamedWeaponProfile::scavenged_shivs.value:
        return NamedWeapon::scavenged_shivs
    if profile.value == NamedWeaponProfile::shokk_attack_gun.value:
        return NamedWeapon::shokk_attack_gun
    if profile.value == NamedWeaponProfile::shoota.value:
        return NamedWeapon::shoota
    if profile.value == NamedWeaponProfile::skorcha.value:
        return NamedWeapon::skorcha
    if profile.value == NamedWeaponProfile::skorcha_missile_rack.value:
        return NamedWeapon::skorcha_missile_rack
    if profile.value == NamedWeaponProfile::slugga.value:
        return NamedWeapon::slugga
    if profile.value == NamedWeaponProfile::smash_hammer_hunter.value:
        return NamedWeapon::smash_hammer
    if profile.value == NamedWeaponProfile::smash_hammer_standard.value:
        return NamedWeapon::smash_hammer
    if profile.value == NamedWeaponProfile::smasha_gun.value:
        return NamedWeapon::smasha_gun
    if profile.value == NamedWeaponProfile::snagga_klaw_melee.value:
        return NamedWeapon::snagga_klaw
    if profile.value == NamedWeaponProfile::snagga_klaw_ranged.value:
        return NamedWeapon::snagga_klaw
    if profile.value == NamedWeaponProfile::snazzgun_cutta.value:
        return NamedWeapon::snazzgun
    if profile.value == NamedWeaponProfile::snazzgun_dakka.value:
        return NamedWeapon::snazzgun
    if profile.value == NamedWeaponProfile::snazzgun_kill_shot.value:
        return NamedWeapon::snazzgun
    if profile.value == NamedWeaponProfile::speeding_bulk_and_flaming_exhaust.value:
        return NamedWeapon::speeding_bulk_and_flaming_exhaust
    if profile.value == NamedWeaponProfile::spiked_ram.value:
        return NamedWeapon::spiked_ram
    if profile.value == NamedWeaponProfile::spinnin_blades.value:
        return NamedWeapon::spinnin_blades
    if profile.value == NamedWeaponProfile::squig_launchas.value:
        return NamedWeapon::squig_launchas
    if profile.value == NamedWeaponProfile::squigosaur_s_jaws.value:
        return NamedWeapon::squigosaur_s_jaws
    if profile.value == NamedWeaponProfile::squigstoppa.value:
        return NamedWeapon::squigstoppa
    if profile.value == NamedWeaponProfile::squig_s_jaws.value:
        return NamedWeapon::squig_s_jaws
    if profile.value == NamedWeaponProfile::stikka_melee.value:
        return NamedWeapon::stikka
    if profile.value == NamedWeaponProfile::stikka_ranged.value:
        return NamedWeapon::stikka
    if profile.value == NamedWeaponProfile::stikka_kannon.value:
        return NamedWeapon::stikka_kannon
    if profile.value == NamedWeaponProfile::stompy_feet.value:
        return NamedWeapon::stompy_feet
    if profile.value == NamedWeaponProfile::supa_gatler_aimed.value:
        return NamedWeapon::supa_gatler
    if profile.value == NamedWeaponProfile::supa_gatler_point_blank.value:
        return NamedWeapon::supa_gatler
    if profile.value == NamedWeaponProfile::supa_kannon.value:
        return NamedWeapon::supa_kannon
    if profile.value == NamedWeaponProfile::supa_kannon_frag.value:
        return NamedWeapon::supa_kannon
    if profile.value == NamedWeaponProfile::supa_kannon_shell.value:
        return NamedWeapon::supa_kannon
    if profile.value == NamedWeaponProfile::tank_kannon_blasta.value:
        return NamedWeapon::tank_kannon
    if profile.value == NamedWeaponProfile::tank_kannon_tankhamma.value:
        return NamedWeapon::tank_kannon
    if profile.value == NamedWeaponProfile::tankhammer.value:
        return NamedWeapon::tankhammer
    if profile.value == NamedWeaponProfile::tellyport_blasta.value:
        return NamedWeapon::tellyport_blasta
    if profile.value == NamedWeaponProfile::thump_gun.value:
        return NamedWeapon::thump_gun
    if profile.value == NamedWeaponProfile::traktor_blasta.value:
        return NamedWeapon::traktor_blasta
    if profile.value == NamedWeaponProfile::traktor_kannon.value:
        return NamedWeapon::traktor_kannon
    if profile.value == NamedWeaponProfile::twin_killsaws.value:
        return NamedWeapon::twin_killsaws
    if profile.value == NamedWeaponProfile::wreckin_ball.value:
        return NamedWeapon::wreckin_ball
    if profile.value == NamedWeaponProfile::wurrtower.value:
        return NamedWeapon::wurrtower
    if profile.value == NamedWeaponProfile::zzap_gun.value:
        return NamedWeapon::zzap_gun
    if profile.value == NamedWeaponProfile::eavy_lobba.value:
        return NamedWeapon::eavy_lobba
    if profile.value == NamedWeaponProfile::uge_choppa.value:
        return NamedWeapon::uge_choppa
    return NamedWeapon::unknown

# A printed name can occur in both attack tables; keep the actual Melee
# classification when importing profile identity (p.16/appendix04.01.03).
fun named_profile_is_melee(NamedWeaponProfile profile) -> Bool:
    if profile.value == NamedWeaponProfile::urty_syringe.value:
        return true
    if profile.value == NamedWeaponProfile::adamantine_eadbutt.value:
        return true
    if profile.value == NamedWeaponProfile::armoured_hull.value:
        return true
    if profile.value == NamedWeaponProfile::armoured_impact.value:
        return true
    if profile.value == NamedWeaponProfile::beast_snagga_klaw.value:
        return true
    if profile.value == NamedWeaponProfile::beast_snagga_klaw_and_beastchoppa.value:
        return true
    if profile.value == NamedWeaponProfile::beastchoppa_hunter.value:
        return true
    if profile.value == NamedWeaponProfile::beastchoppa_standard.value:
        return true
    if profile.value == NamedWeaponProfile::big_chompa_s_jaws.value:
        return true
    if profile.value == NamedWeaponProfile::big_choppa.value:
        return true
    if profile.value == NamedWeaponProfile::big_mek_s_toolz.value:
        return true
    if profile.value == NamedWeaponProfile::breacha_ram.value:
        return true
    if profile.value == NamedWeaponProfile::butcha_boyz.value:
        return true
    if profile.value == NamedWeaponProfile::buzzsaw.value:
        return true
    if profile.value == NamedWeaponProfile::choppa.value:
        return true
    if profile.value == NamedWeaponProfile::choppa_hunter.value:
        return true
    if profile.value == NamedWeaponProfile::choppa_standard.value:
        return true
    if profile.value == NamedWeaponProfile::copper_staff.value:
        return true
    if profile.value == NamedWeaponProfile::crushin_bulk.value:
        return true
    if profile.value == NamedWeaponProfile::cuttin_flames.value:
        return true
    if profile.value == NamedWeaponProfile::da_grabzappa.value:
        return true
    if profile.value == NamedWeaponProfile::da_vulcha_s_klaws_and_choppa.value:
        return true
    if profile.value == NamedWeaponProfile::deff_rolla.value:
        return true
    if profile.value == NamedWeaponProfile::dok_s_toolz.value:
        return true
    if profile.value == NamedWeaponProfile::dread_klaws.value:
        return true
    if profile.value == NamedWeaponProfile::drilla.value:
        return true
    if profile.value == NamedWeaponProfile::extra_klaw.value:
        return true
    if profile.value == NamedWeaponProfile::fixit_s_wrench.value:
        return true
    if profile.value == NamedWeaponProfile::gitstikka.value:
        return true
    if profile.value == NamedWeaponProfile::gork_s_klaw.value:
        return true
    if profile.value == NamedWeaponProfile::grabba_dragga_melee.value:
        return true
    if profile.value == NamedWeaponProfile::grabbin_klaw.value:
        return true
    if profile.value == NamedWeaponProfile::gun_stock_and_fists.value:
        return true
    if profile.value == NamedWeaponProfile::gutrippa_hunter.value:
        return true
    if profile.value == NamedWeaponProfile::gutrippa_standard.value:
        return true
    if profile.value == NamedWeaponProfile::huge_tusks_strike.value:
        return true
    if profile.value == NamedWeaponProfile::kan_klaw.value:
        return true
    if profile.value == NamedWeaponProfile::killa_jet_burna.value:
        return true
    if profile.value == NamedWeaponProfile::killa_jet_cutta.value:
        return true
    if profile.value == NamedWeaponProfile::killsaw.value:
        return true
    if profile.value == NamedWeaponProfile::klaw_of_gork.value:
        return true
    if profile.value == NamedWeaponProfile::klaw_of_mork.value:
        return true
    if profile.value == NamedWeaponProfile::knucklebustas.value:
        return true
    if profile.value == NamedWeaponProfile::kustom_blasta_x.value:
        return true
    if profile.value == NamedWeaponProfile::kustom_choppa.value:
        return true
    if profile.value == NamedWeaponProfile::kustom_krumpa.value:
        return true
    if profile.value == NamedWeaponProfile::mega_choppa.value:
        return true
    if profile.value == NamedWeaponProfile::mek_s_toolz.value:
        return true
    if profile.value == NamedWeaponProfile::moonchewa.value:
        return true
    if profile.value == NamedWeaponProfile::mork_s_teef.value:
        return true
    if profile.value == NamedWeaponProfile::power_klaw.value:
        return true
    if profile.value == NamedWeaponProfile::power_snappa.value:
        return true
    if profile.value == NamedWeaponProfile::ramshackle_hull.value:
        return true
    if profile.value == NamedWeaponProfile::runtherd_s_toolz.value:
        return true
    if profile.value == NamedWeaponProfile::savage_horns_and_hooves.value:
        return true
    if profile.value == NamedWeaponProfile::saw_blades.value:
        return true
    if profile.value == NamedWeaponProfile::scavenged_shivs.value:
        return true
    if profile.value == NamedWeaponProfile::smash_hammer_hunter.value:
        return true
    if profile.value == NamedWeaponProfile::smash_hammer_standard.value:
        return true
    if profile.value == NamedWeaponProfile::snagga_klaw_melee.value:
        return true
    if profile.value == NamedWeaponProfile::speeding_bulk_and_flaming_exhaust.value:
        return true
    if profile.value == NamedWeaponProfile::spiked_ram.value:
        return true
    if profile.value == NamedWeaponProfile::spinnin_blades.value:
        return true
    if profile.value == NamedWeaponProfile::squigosaur_s_jaws.value:
        return true
    if profile.value == NamedWeaponProfile::squig_s_jaws.value:
        return true
    if profile.value == NamedWeaponProfile::stikka_melee.value:
        return true
    if profile.value == NamedWeaponProfile::stompy_feet.value:
        return true
    if profile.value == NamedWeaponProfile::tankhammer.value:
        return true
    if profile.value == NamedWeaponProfile::twin_killsaws.value:
        return true
    if profile.value == NamedWeaponProfile::wreckin_ball.value:
        return true
    if profile.value == NamedWeaponProfile::uge_choppa.value:
        return true
    return false
