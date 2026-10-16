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
