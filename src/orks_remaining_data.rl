import orks_elite_data

# Hull sizes are explicit millimetre circle proxies, never inferred dimensions.
# User authorizes circular treatment of all noncircles; core p12 measurements.
using OrksHullDiameter = LinearlyDistributedInt<0, 1001>

enum OrksGunwagonGun:
    kannon
    killkannon
    zzap_gun

enum OrksMekGun:
    smasha_gun
    bubblechukka
    kustom_mega_kannon
    traktor_kannon

using OrksMekGuns = CheckedVector<OrksMekGun, 3>
using OrksVehicleSwaps = CheckedVector<Bool, 6>

enum OrksTrukkExtra:
    none
    buzzsaw
    grabbin_klaw

cls OrksKommandoEquipment:
    OrksNobMeleeChoice nob_melee
    Bool burna
    Bool rokkit
    Bool breacha_ram
    Bool kustom_shoota

using OrksKommandoLoadout = CheckedVector<OrksKommandoEquipment, 10>

# Source profile rows share the actual physical family, with a fresh group
# for EACH equipped copy. Nazdreg alone may select all three ranged profiles.
# Each branch is sourced by its card URL; appendix04.01.03/core p16.
fun equip_orks_remaining_family(Model model, NamedWeaponProfile family, Int copies):
    assert(copies >= 0 and copies <= 5, "invalid physical weapon count")
    let matched = false
    for copy_index in range(copies):
        let group = model.weapons.size() + 1
        # https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon
        if model.datasheet.value == OrksDatasheet::battlewagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::big_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_battlewagon_big_shoota, NamedWeaponProfile::big_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon
        if model.datasheet.value == OrksDatasheet::battlewagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::crushin_bulk).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_battlewagon_crushin_bulk, NamedWeaponProfile::crushin_bulk, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon
        if model.datasheet.value == OrksDatasheet::battlewagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::grabbin_klaw).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_battlewagon_grabbin_klaw, NamedWeaponProfile::grabbin_klaw, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon
        if model.datasheet.value == OrksDatasheet::battlewagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::wreckin_ball).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_battlewagon_wreckin_ball, NamedWeaponProfile::wreckin_ball, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
        if model.datasheet.value == OrksDatasheet::big_ed_bossbunka.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::big_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_big_ed_bossbunka_big_shoota, NamedWeaponProfile::big_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
        if model.datasheet.value == OrksDatasheet::big_ed_bossbunka.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::gaze_of_gork_glare).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_big_ed_bossbunka_gaze_of_gork_glare, NamedWeaponProfile::gaze_of_gork_glare, group)
            equip_orks_profile(model, Weapon::orks_big_ed_bossbunka_gaze_of_gork_squint, NamedWeaponProfile::gaze_of_gork_squint, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer
        if model.datasheet.value == OrksDatasheet::blitza_bommer.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::big_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_blitza_bommer_big_shoota, NamedWeaponProfile::big_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer
        if model.datasheet.value == OrksDatasheet::blitza_bommer.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::dual_supa_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_blitza_bommer_dual_supa_shoota, NamedWeaponProfile::dual_supa_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer
        if model.datasheet.value == OrksDatasheet::blitza_bommer.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::armoured_impact).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_blitza_bommer_armoured_impact, NamedWeaponProfile::armoured_impact, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Boss-Snikrot
        if model.datasheet.value == OrksDatasheet::boss_snikrot.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::slugga).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_boss_snikrot_slugga, NamedWeaponProfile::slugga, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Boss-Snikrot
        if model.datasheet.value == OrksDatasheet::boss_snikrot.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::mork_s_teef).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_boss_snikrot_mork_s_teef, NamedWeaponProfile::mork_s_teef, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer
        if model.datasheet.value == OrksDatasheet::burna_bommer.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::dual_big_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_burna_bommer_dual_big_shoota, NamedWeaponProfile::dual_big_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer
        if model.datasheet.value == OrksDatasheet::burna_bommer.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::dual_supa_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_burna_bommer_dual_supa_shoota, NamedWeaponProfile::dual_supa_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer
        if model.datasheet.value == OrksDatasheet::burna_bommer.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::skorcha_missile_rack).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_burna_bommer_skorcha_missile_rack, NamedWeaponProfile::skorcha_missile_rack, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer
        if model.datasheet.value == OrksDatasheet::burna_bommer.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::armoured_impact).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_burna_bommer_armoured_impact, NamedWeaponProfile::armoured_impact, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Dakkajet
        if model.datasheet.value == OrksDatasheet::dakkajet.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::dual_supa_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_dakkajet_dual_supa_shoota, NamedWeaponProfile::dual_supa_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Dakkajet
        if model.datasheet.value == OrksDatasheet::dakkajet.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::armoured_impact).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_dakkajet_armoured_impact, NamedWeaponProfile::armoured_impact, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
        if model.datasheet.value == OrksDatasheet::deffkilla_wartrike.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::boomstikks).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_deffkilla_wartrike_boomstikks, NamedWeaponProfile::boomstikks, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
        if model.datasheet.value == OrksDatasheet::deffkilla_wartrike.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::snagga_klaw_ranged).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_deffkilla_wartrike_snagga_klaw_ranged, NamedWeaponProfile::snagga_klaw_ranged, group)
            equip_orks_profile(model, Weapon::orks_deffkilla_wartrike_snagga_klaw_melee, NamedWeaponProfile::snagga_klaw_melee, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
        if model.datasheet.value == OrksDatasheet::deffkilla_wartrike.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::killa_jet_burna).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_deffkilla_wartrike_killa_jet_burna, NamedWeaponProfile::killa_jet_burna, group)
            equip_orks_profile(model, Weapon::orks_deffkilla_wartrike_killa_jet_cutta, NamedWeaponProfile::killa_jet_cutta, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
        if model.datasheet.value == OrksDatasheet::deffkoptas.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::rokkit_launcha_blasta).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_deffkoptas_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, group)
            equip_orks_profile(model, Weapon::orks_deffkoptas_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
        if model.datasheet.value == OrksDatasheet::deffkoptas.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::kustom_mega_blasta).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_deffkoptas_kustom_mega_blasta, NamedWeaponProfile::kustom_mega_blasta, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
        if model.datasheet.value == OrksDatasheet::deffkoptas.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::slugga).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_deffkoptas_slugga, NamedWeaponProfile::slugga, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
        if model.datasheet.value == OrksDatasheet::deffkoptas.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::choppa).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_deffkoptas_choppa, NamedWeaponProfile::choppa, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
        if model.datasheet.value == OrksDatasheet::deffkoptas.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::spinnin_blades).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_deffkoptas_spinnin_blades, NamedWeaponProfile::spinnin_blades, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
        if model.datasheet.value == OrksDatasheet::ghazghkull_thraka.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::mork_s_roar_aimed).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_ghazghkull_thraka_mork_s_roar_aimed, NamedWeaponProfile::mork_s_roar_aimed, group)
            equip_orks_profile(model, Weapon::orks_ghazghkull_thraka_mork_s_roar_point_blank, NamedWeaponProfile::mork_s_roar_point_blank, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
        if model.datasheet.value == OrksDatasheet::ghazghkull_thraka.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::adamantine_eadbutt).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_ghazghkull_thraka_adamantine_eadbutt, NamedWeaponProfile::adamantine_eadbutt, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
        if model.datasheet.value == OrksDatasheet::ghazghkull_thraka.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::gork_s_klaw).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_ghazghkull_thraka_gork_s_klaw, NamedWeaponProfile::gork_s_klaw, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
        if model.datasheet.value == OrksDatasheet::gorkanaut.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::deffstorm_mega_shoota_aimed).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gorkanaut_deffstorm_mega_shoota_aimed, NamedWeaponProfile::deffstorm_mega_shoota_aimed, group)
            equip_orks_profile(model, Weapon::orks_gorkanaut_deffstorm_mega_shoota_point_blank, NamedWeaponProfile::deffstorm_mega_shoota_point_blank, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
        if model.datasheet.value == OrksDatasheet::gorkanaut.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::dual_big_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gorkanaut_dual_big_shoota, NamedWeaponProfile::dual_big_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
        if model.datasheet.value == OrksDatasheet::gorkanaut.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::rokkit_launcha_blasta).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gorkanaut_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, group)
            equip_orks_profile(model, Weapon::orks_gorkanaut_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
        if model.datasheet.value == OrksDatasheet::gorkanaut.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::skorcha).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gorkanaut_skorcha, NamedWeaponProfile::skorcha, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
        if model.datasheet.value == OrksDatasheet::gorkanaut.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::klaw_of_gork).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gorkanaut_klaw_of_gork, NamedWeaponProfile::klaw_of_gork, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
        if model.datasheet.value == OrksDatasheet::gunwagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::big_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gunwagon_big_shoota, NamedWeaponProfile::big_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
        if model.datasheet.value == OrksDatasheet::gunwagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::kannon_frag).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gunwagon_kannon_frag, NamedWeaponProfile::kannon_frag, group)
            equip_orks_profile(model, Weapon::orks_gunwagon_kannon_shell, NamedWeaponProfile::kannon_shell, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
        if model.datasheet.value == OrksDatasheet::gunwagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::killkannon).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gunwagon_killkannon, NamedWeaponProfile::killkannon, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
        if model.datasheet.value == OrksDatasheet::gunwagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::lobba).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gunwagon_lobba, NamedWeaponProfile::lobba, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
        if model.datasheet.value == OrksDatasheet::gunwagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::zzap_gun).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gunwagon_zzap_gun, NamedWeaponProfile::zzap_gun, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
        if model.datasheet.value == OrksDatasheet::gunwagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::crushin_bulk).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gunwagon_crushin_bulk, NamedWeaponProfile::crushin_bulk, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
        if model.datasheet.value == OrksDatasheet::gunwagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::grabbin_klaw).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gunwagon_grabbin_klaw, NamedWeaponProfile::grabbin_klaw, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
        if model.datasheet.value == OrksDatasheet::gunwagon.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::wreckin_ball).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_gunwagon_wreckin_ball, NamedWeaponProfile::wreckin_ball, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
        if model.datasheet.value == OrksDatasheet::hunta_rig.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::eavy_lobba).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_hunta_rig_eavy_lobba, NamedWeaponProfile::eavy_lobba, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
        if model.datasheet.value == OrksDatasheet::hunta_rig.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::stikka_kannon).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_hunta_rig_stikka_kannon, NamedWeaponProfile::stikka_kannon, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
        if model.datasheet.value == OrksDatasheet::hunta_rig.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::butcha_boyz).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_hunta_rig_butcha_boyz, NamedWeaponProfile::butcha_boyz, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
        if model.datasheet.value == OrksDatasheet::hunta_rig.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::savage_horns_and_hooves).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_hunta_rig_savage_horns_and_hooves, NamedWeaponProfile::savage_horns_and_hooves, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
        if model.datasheet.value == OrksDatasheet::hunta_rig.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::saw_blades).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_hunta_rig_saw_blades, NamedWeaponProfile::saw_blades, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
        if model.datasheet.value == OrksDatasheet::kill_rig.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::eavy_lobba).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kill_rig_eavy_lobba, NamedWeaponProfile::eavy_lobba, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
        if model.datasheet.value == OrksDatasheet::kill_rig.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::stikka_kannon).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kill_rig_stikka_kannon, NamedWeaponProfile::stikka_kannon, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
        if model.datasheet.value == OrksDatasheet::kill_rig.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::wurrtower).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kill_rig_wurrtower, NamedWeaponProfile::wurrtower, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
        if model.datasheet.value == OrksDatasheet::kill_rig.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::butcha_boyz).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kill_rig_butcha_boyz, NamedWeaponProfile::butcha_boyz, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
        if model.datasheet.value == OrksDatasheet::kill_rig.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::savage_horns_and_hooves).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kill_rig_savage_horns_and_hooves, NamedWeaponProfile::savage_horns_and_hooves, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
        if model.datasheet.value == OrksDatasheet::kill_rig.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::saw_blades).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kill_rig_saw_blades, NamedWeaponProfile::saw_blades, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
        if model.datasheet.value == OrksDatasheet::kommandos.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::burna).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kommandos_burna, NamedWeaponProfile::burna, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
        if model.datasheet.value == OrksDatasheet::kommandos.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::kustom_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kommandos_kustom_shoota, NamedWeaponProfile::kustom_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
        if model.datasheet.value == OrksDatasheet::kommandos.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::rokkit_launcha_blasta).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kommandos_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, group)
            equip_orks_profile(model, Weapon::orks_kommandos_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
        if model.datasheet.value == OrksDatasheet::kommandos.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::slugga).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kommandos_slugga, NamedWeaponProfile::slugga, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
        if model.datasheet.value == OrksDatasheet::kommandos.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::big_choppa).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kommandos_big_choppa, NamedWeaponProfile::big_choppa, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
        if model.datasheet.value == OrksDatasheet::kommandos.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::breacha_ram).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kommandos_breacha_ram, NamedWeaponProfile::breacha_ram, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
        if model.datasheet.value == OrksDatasheet::kommandos.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::choppa).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kommandos_choppa, NamedWeaponProfile::choppa, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
        if model.datasheet.value == OrksDatasheet::kommandos.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::power_klaw).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_kommandos_power_klaw, NamedWeaponProfile::power_klaw, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
        if model.datasheet.value == OrksDatasheet::mek_gunz.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::smasha_gun).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_mek_gunz_smasha_gun, NamedWeaponProfile::smasha_gun, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
        if model.datasheet.value == OrksDatasheet::mek_gunz.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::bubblechukka).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_mek_gunz_bubblechukka, NamedWeaponProfile::bubblechukka, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
        if model.datasheet.value == OrksDatasheet::mek_gunz.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::kustom_mega_kannon).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_mek_gunz_kustom_mega_kannon, NamedWeaponProfile::kustom_mega_kannon, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
        if model.datasheet.value == OrksDatasheet::mek_gunz.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::traktor_kannon).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_mek_gunz_traktor_kannon, NamedWeaponProfile::traktor_kannon, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
        if model.datasheet.value == OrksDatasheet::mek_gunz.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::scavenged_shivs).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_mek_gunz_scavenged_shivs, NamedWeaponProfile::scavenged_shivs, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
        if model.datasheet.value == OrksDatasheet::morkanaut.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::dual_big_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_morkanaut_dual_big_shoota, NamedWeaponProfile::dual_big_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
        if model.datasheet.value == OrksDatasheet::morkanaut.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::kustom_mega_blasta).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_morkanaut_kustom_mega_blasta, NamedWeaponProfile::kustom_mega_blasta, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
        if model.datasheet.value == OrksDatasheet::morkanaut.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::kustom_mega_zappa).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_morkanaut_kustom_mega_zappa, NamedWeaponProfile::kustom_mega_zappa, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
        if model.datasheet.value == OrksDatasheet::morkanaut.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::rokkit_launcha_blasta).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_morkanaut_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, group)
            equip_orks_profile(model, Weapon::orks_morkanaut_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
        if model.datasheet.value == OrksDatasheet::morkanaut.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::klaw_of_mork).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_morkanaut_klaw_of_mork, NamedWeaponProfile::klaw_of_mork, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
        if model.datasheet.value == OrksDatasheet::nazdreg.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::kustom_blasta_x_gatler).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_nazdreg_kustom_blasta_x_gatler, NamedWeaponProfile::kustom_blasta_x_gatler, group)
            model.simultaneous_ranged_profiles[model.weapons.size() - 1] = true
            equip_orks_profile(model, Weapon::orks_nazdreg_kustom_blasta_x_shoota, NamedWeaponProfile::kustom_blasta_x_shoota, group)
            model.simultaneous_ranged_profiles[model.weapons.size() - 1] = true
            equip_orks_profile(model, Weapon::orks_nazdreg_kustom_blasta_x_skorcha, NamedWeaponProfile::kustom_blasta_x_skorcha, group)
            model.simultaneous_ranged_profiles[model.weapons.size() - 1] = true
            equip_orks_profile(model, Weapon::orks_nazdreg_kustom_blasta_x, NamedWeaponProfile::kustom_blasta_x, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
        if model.datasheet.value == OrksDatasheet::nazdreg.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::moonchewa).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_nazdreg_moonchewa, NamedWeaponProfile::moonchewa, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies
        if model.datasheet.value == OrksDatasheet::rukkatrukk_squigbuggies.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::sawn_off_shotgun).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_rukkatrukk_squigbuggies_sawn_off_shotgun, NamedWeaponProfile::sawn_off_shotgun, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies
        if model.datasheet.value == OrksDatasheet::rukkatrukk_squigbuggies.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::squig_launchas).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_rukkatrukk_squigbuggies_squig_launchas, NamedWeaponProfile::squig_launchas, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies
        if model.datasheet.value == OrksDatasheet::rukkatrukk_squigbuggies.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::saw_blades).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_rukkatrukk_squigbuggies_saw_blades, NamedWeaponProfile::saw_blades, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
        if model.datasheet.value == OrksDatasheet::stompa.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::big_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_stompa_big_shoota, NamedWeaponProfile::big_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
        if model.datasheet.value == OrksDatasheet::stompa.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::deffkannon_and_supa_rokkits).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_stompa_deffkannon_and_supa_rokkits, NamedWeaponProfile::deffkannon_and_supa_rokkits, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
        if model.datasheet.value == OrksDatasheet::stompa.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::skorcha).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_stompa_skorcha, NamedWeaponProfile::skorcha, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
        if model.datasheet.value == OrksDatasheet::stompa.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::supa_gatler_aimed).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_stompa_supa_gatler_aimed, NamedWeaponProfile::supa_gatler_aimed, group)
            equip_orks_profile(model, Weapon::orks_stompa_supa_gatler_point_blank, NamedWeaponProfile::supa_gatler_point_blank, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
        if model.datasheet.value == OrksDatasheet::stompa.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::mega_choppa).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_stompa_mega_choppa, NamedWeaponProfile::mega_choppa, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
        if model.datasheet.value == OrksDatasheet::trukk.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::dual_big_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_trukk_dual_big_shoota, NamedWeaponProfile::dual_big_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
        if model.datasheet.value == OrksDatasheet::trukk.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::rokkit_launcha_blasta).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_trukk_rokkit_launcha_blasta, NamedWeaponProfile::rokkit_launcha_blasta, group)
            equip_orks_profile(model, Weapon::orks_trukk_rokkit_launcha_busta, NamedWeaponProfile::rokkit_launcha_busta, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
        if model.datasheet.value == OrksDatasheet::trukk.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::buzzsaw).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_trukk_buzzsaw, NamedWeaponProfile::buzzsaw, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
        if model.datasheet.value == OrksDatasheet::trukk.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::grabbin_klaw).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_trukk_grabbin_klaw, NamedWeaponProfile::grabbin_klaw, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
        if model.datasheet.value == OrksDatasheet::trukk.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::spiked_ram).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_trukk_spiked_ram, NamedWeaponProfile::spiked_ram, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
        if model.datasheet.value == OrksDatasheet::warbuggies.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::extra_dakka).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_warbuggies_extra_dakka, NamedWeaponProfile::extra_dakka, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
        if model.datasheet.value == OrksDatasheet::warbuggies.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::rivet_kannon_aimed).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_warbuggies_rivet_kannon_aimed, NamedWeaponProfile::rivet_kannon_aimed, group)
            equip_orks_profile(model, Weapon::orks_warbuggies_rivet_kannon_point_blank, NamedWeaponProfile::rivet_kannon_point_blank, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
        if model.datasheet.value == OrksDatasheet::warbuggies.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::mek_speshul_aimed).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_warbuggies_mek_speshul_aimed, NamedWeaponProfile::mek_speshul_aimed, group)
            equip_orks_profile(model, Weapon::orks_warbuggies_mek_speshul_point_blank, NamedWeaponProfile::mek_speshul_point_blank, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
        if model.datasheet.value == OrksDatasheet::warbuggies.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::spiked_ram).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_warbuggies_spiked_ram, NamedWeaponProfile::spiked_ram, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks
        if model.datasheet.value == OrksDatasheet::wartrakks.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::kustom_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wartrakks_kustom_shoota, NamedWeaponProfile::kustom_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks
        if model.datasheet.value == OrksDatasheet::wartrakks.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::multi_busta_launcha).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wartrakks_multi_busta_launcha, NamedWeaponProfile::multi_busta_launcha, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks
        if model.datasheet.value == OrksDatasheet::wartrakks.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::kustom_choppa).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wartrakks_kustom_choppa, NamedWeaponProfile::kustom_choppa, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
        if model.datasheet.value == OrksDatasheet::wazbom_blastajet.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::dual_supa_shoota).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wazbom_blastajet_dual_supa_shoota, NamedWeaponProfile::dual_supa_shoota, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
        if model.datasheet.value == OrksDatasheet::wazbom_blastajet.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::dual_tellyport_mega_blasta).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wazbom_blastajet_dual_tellyport_mega_blasta, NamedWeaponProfile::dual_tellyport_mega_blasta, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
        if model.datasheet.value == OrksDatasheet::wazbom_blastajet.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::dual_wazbom_mega_kannon).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wazbom_blastajet_dual_wazbom_mega_kannon, NamedWeaponProfile::dual_wazbom_mega_kannon, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
        if model.datasheet.value == OrksDatasheet::wazbom_blastajet.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::smasha_gun).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wazbom_blastajet_smasha_gun, NamedWeaponProfile::smasha_gun, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
        if model.datasheet.value == OrksDatasheet::wazbom_blastajet.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::armoured_impact).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wazbom_blastajet_armoured_impact, NamedWeaponProfile::armoured_impact, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
        if model.datasheet.value == OrksDatasheet::wazdakka_gutsmek.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::grabba_dragga_ranged).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wazdakka_gutsmek_grabba_dragga_ranged, NamedWeaponProfile::grabba_dragga_ranged, group)
            equip_orks_profile(model, Weapon::orks_wazdakka_gutsmek_grabba_dragga_melee, NamedWeaponProfile::grabba_dragga_melee, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
        if model.datasheet.value == OrksDatasheet::wazdakka_gutsmek.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::psyko_gatler).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wazdakka_gutsmek_psyko_gatler, NamedWeaponProfile::psyko_gatler, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
        if model.datasheet.value == OrksDatasheet::wazdakka_gutsmek.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::speeding_bulk_and_flaming_exhaust).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wazdakka_gutsmek_speeding_bulk_and_flaming_exhaust, NamedWeaponProfile::speeding_bulk_and_flaming_exhaust, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
        if model.datasheet.value == OrksDatasheet::wazdakka_gutsmek.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::fixit_s_wrench).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_wazdakka_gutsmek_fixit_s_wrench, NamedWeaponProfile::fixit_s_wrench, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy
        if model.datasheet.value == OrksDatasheet::weirdboy.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::power_vomit).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_weirdboy_power_vomit, NamedWeaponProfile::power_vomit, group)
        # https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy
        if model.datasheet.value == OrksDatasheet::weirdboy.value and named_profile_weapon(family).value == named_profile_weapon(NamedWeaponProfile::copper_staff).value:
            matched = true
            equip_orks_profile(model, Weapon::orks_weirdboy_copper_staff, NamedWeaponProfile::copper_staff, group)
    assert(matched or copies == 0, "weapon family absent from current datasheet")

# Exact source keywords/core abilities; remaining ability consumers live in
# orks_remaining_rules. Ovals intentionally use their source long-axis circle;
# source short axes remain available via profile_base_width (user policy).
fun orks_remaining_model(OrksDatasheet sheet, Int hull_mm) -> Model:
    let model : Model
    let matched = false
    # https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon
    if sheet.value == OrksDatasheet::battlewagon.value:
        matched = true
        model = orks_current_model(Profile::orks_battlewagon, sheet)
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
            model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(sheet)
        model.transport_permissions_known = true
        model.transport_capacity = 22
        model.permitted_passenger_keywords.append(Keyword::infantry)
        model.orks_transport_permissions = true
    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka
    if sheet.value == OrksDatasheet::big_ed_bossbunka.value:
        matched = true
        model = orks_current_model(Profile::orks_big_ed_bossbunka, sheet)
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
            model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(sheet)
        model.transport_permissions_known = true
        model.transport_capacity = 11
        model.permitted_passenger_keywords.append(Keyword::infantry)
        model.orks_transport_permissions = true
        model.forbid_ghaz_passenger = true
    # https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer
    if sheet.value == OrksDatasheet::blitza_bommer.value:
        matched = true
        model = orks_current_model(Profile::orks_blitza_bommer, sheet)
        model.keywords.append(Keyword::vehicle)
        model.keywords.append(Keyword::aircraft)
        model.keywords.append(Keyword::fly)
        model.keywords.append(Keyword::speed_freeks)
        model.abilities.append(AbilityKind::boom_bomb)
        model.has_damaged = true
        model.damaged_threshold = 4
        model.has_deadly_demise = true
        model.deadly_demise = dice_stat(3)
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Boss-Snikrot
    if sheet.value == OrksDatasheet::boss_snikrot.value:
        matched = true
        model = orks_current_model(Profile::orks_boss_snikrot, sheet)
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
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer
    if sheet.value == OrksDatasheet::burna_bommer.value:
        matched = true
        model = orks_current_model(Profile::orks_burna_bommer, sheet)
        model.keywords.append(Keyword::vehicle)
        model.keywords.append(Keyword::aircraft)
        model.keywords.append(Keyword::fly)
        model.keywords.append(Keyword::speed_freeks)
        model.abilities.append(AbilityKind::burna_bomb)
        model.has_damaged = true
        model.damaged_threshold = 4
        model.has_deadly_demise = true
        model.deadly_demise = dice_stat(3)
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Dakkajet
    if sheet.value == OrksDatasheet::dakkajet.value:
        matched = true
        model = orks_current_model(Profile::orks_dakkajet, sheet)
        model.keywords.append(Keyword::vehicle)
        model.keywords.append(Keyword::aircraft)
        model.keywords.append(Keyword::fly)
        model.keywords.append(Keyword::speed_freeks)
        model.abilities.append(AbilityKind::strafing_run)
        model.has_damaged = true
        model.damaged_threshold = 4
        model.has_deadly_demise = true
        model.deadly_demise = dice_stat(3)
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike
    if sheet.value == OrksDatasheet::deffkilla_wartrike.value:
        matched = true
        model = orks_current_model(Profile::orks_deffkilla_wartrike, sheet)
        model.keywords.append(Keyword::mounted)
        model.keywords.append(Keyword::character)
        model.keywords.append(Keyword::speed_freeks)
        model.keywords.append(Keyword::warboss)
        model.abilities.append(AbilityKind::get_back_in_da_race)
        model.abilities.append(AbilityKind::fuel_mixa_grot)
        model.has_da_boss = true
        model.has_deadly_demise = true
        model.deadly_demise = raw_stat(1)
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Deffkoptas
    if sheet.value == OrksDatasheet::deffkoptas.value:
        matched = true
        model = orks_current_model(Profile::orks_deffkoptas, sheet)
        model.keywords.append(Keyword::mounted)
        model.keywords.append(Keyword::explosives)
        model.keywords.append(Keyword::fly)
        model.keywords.append(Keyword::speed_freeks)
        model.keywords.append(Keyword::deffkoptas)
        model.abilities.append(AbilityKind::deff_from_above)
        model.abilities.append(AbilityKind::aerial_manoover)
        model.abilities.append(AbilityKind::deep_strike)
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka
    if sheet.value == OrksDatasheet::ghazghkull_thraka.value:
        matched = true
        model = orks_current_model(Profile::orks_ghazghkull_thraka, sheet)
        model.keywords.append(Keyword::infantry)
        model.keywords.append(Keyword::character)
        model.keywords.append(Keyword::epic_hero)
        model.keywords.append(Keyword::explosives)
        model.keywords.append(Keyword::warboss)
        model.abilities.append(AbilityKind::grand_warlords_ladz)
        model.abilities.append(AbilityKind::makari_banner)
        model.abilities.append(AbilityKind::prophet_waaagh)
        model.has_da_boss = true
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
        model.must_be_warlord = true
        model.transport_space = 4
    # https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut
    if sheet.value == OrksDatasheet::gorkanaut.value:
        matched = true
        model = orks_current_model(Profile::orks_gorkanaut, sheet)
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
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
        model.transport_permissions_known = true
        model.transport_capacity = 12
        model.permitted_passenger_keywords.append(Keyword::infantry)
        model.orks_transport_permissions = true
        model.forbid_ghaz_passenger = true
    # https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon
    if sheet.value == OrksDatasheet::gunwagon.value:
        matched = true
        model = orks_current_model(Profile::orks_gunwagon, sheet)
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
            model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(sheet)
        model.transport_permissions_known = true
        model.transport_capacity = 12
        model.permitted_passenger_keywords.append(Keyword::infantry)
        model.orks_transport_permissions = true
    # https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig
    if sheet.value == OrksDatasheet::hunta_rig.value:
        matched = true
        model = orks_current_model(Profile::orks_hunta_rig, sheet)
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
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
        model.transport_permissions_known = true
        model.transport_capacity = 22
        model.permitted_passenger_keywords.append(Keyword::infantry)
        model.orks_transport_permissions = true
        model.beast_snagga_passengers_only = true
    # https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig
    if sheet.value == OrksDatasheet::kill_rig.value:
        matched = true
        model = orks_current_model(Profile::orks_kill_rig, sheet)
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
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
        model.transport_permissions_known = true
        model.transport_capacity = 12
        model.permitted_passenger_keywords.append(Keyword::infantry)
        model.orks_transport_permissions = true
        model.beast_snagga_passengers_only = true
    # https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
    if sheet.value == OrksDatasheet::kommandos.value:
        matched = true
        model = orks_current_model(Profile::orks_kommando, sheet)
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
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz
    if sheet.value == OrksDatasheet::mek_gunz.value:
        matched = true
        model = orks_current_model(Profile::orks_mek_gunz, sheet)
        model.keywords.append(Keyword::vehicle)
        model.keywords.append(Keyword::frame)
        model.keywords.append(Keyword::grots)
        model.abilities.append(AbilityKind::madcap_artillery)
        assert(hull_mm >= 0 and hull_mm <= 1000, "invalid circular hull proxy diameter")
        model.geometry.proxy_diameter_mm = hull_mm
        # Intentional imprecision, user-authorized temporary large circle.
        if hull_mm == 0:
            model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(sheet)
    # https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut
    if sheet.value == OrksDatasheet::morkanaut.value:
        matched = true
        model = orks_current_model(Profile::orks_morkanaut, sheet)
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
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
        model.transport_permissions_known = true
        model.transport_capacity = 12
        model.permitted_passenger_keywords.append(Keyword::infantry)
        model.orks_transport_permissions = true
        model.forbid_ghaz_passenger = true
    # https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg
    if sheet.value == OrksDatasheet::nazdreg.value:
        matched = true
        model = orks_current_model(Profile::orks_nazdreg, sheet)
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
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
        model.transport_space = 2
    # https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies
    if sheet.value == OrksDatasheet::rukkatrukk_squigbuggies.value:
        matched = true
        model = orks_current_model(Profile::orks_rukkatrukk_squigbuggies, sheet)
        model.keywords.append(Keyword::vehicle)
        model.keywords.append(Keyword::explosives)
        model.keywords.append(Keyword::speed_freeks)
        model.abilities.append(AbilityKind::squig_barrage)
        model.has_deadly_demise = true
        model.deadly_demise = raw_stat(1)
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Stompa
    if sheet.value == OrksDatasheet::stompa.value:
        matched = true
        model = orks_current_model(Profile::orks_stompa, sheet)
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
            model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(sheet)
        model.grants_unit_riled_up = true
        model.transport_permissions_known = true
        model.transport_capacity = 22
        model.permitted_passenger_keywords.append(Keyword::infantry)
        model.orks_transport_permissions = true
    # https://wahapedia.ru/wh40k11ed/factions/orks/Trukk
    if sheet.value == OrksDatasheet::trukk.value:
        matched = true
        model = orks_current_model(Profile::orks_trukk, sheet)
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
            model.geometry.proxy_diameter_mm = orks_temporary_hull_diameter(sheet)
        model.transport_permissions_known = true
        model.transport_capacity = 12
        model.permitted_passenger_keywords.append(Keyword::infantry)
        model.orks_transport_permissions = true
        model.forbid_ghaz_passenger = true
        model.forbidden_passenger_keywords.append(Keyword::jump_pack)
    # https://wahapedia.ru/wh40k11ed/factions/orks/Warbuggies
    if sheet.value == OrksDatasheet::warbuggies.value:
        matched = true
        model = orks_current_model(Profile::orks_warbuggies, sheet)
        model.keywords.append(Keyword::vehicle)
        model.keywords.append(Keyword::explosives)
        model.keywords.append(Keyword::speed_freeks)
        model.abilities.append(AbilityKind::drive_by_skorchin)
        model.has_deadly_demise = true
        model.deadly_demise = raw_stat(1)
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks
    if sheet.value == OrksDatasheet::wartrakks.value:
        matched = true
        model = orks_current_model(Profile::orks_wartrakks, sheet)
        model.keywords.append(Keyword::mounted)
        model.keywords.append(Keyword::speed_freeks)
        model.abilities.append(AbilityKind::speednob_support)
        model.abilities.append(AbilityKind::bust_em)
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet
    if sheet.value == OrksDatasheet::wazbom_blastajet.value:
        matched = true
        model = orks_current_model(Profile::orks_wazbom_blastajet, sheet)
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
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek
    if sheet.value == OrksDatasheet::wazdakka_gutsmek.value:
        matched = true
        model = orks_current_model(Profile::orks_wazdakka_gutsmek, sheet)
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
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    # https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy
    if sheet.value == OrksDatasheet::weirdboy.value:
        matched = true
        model = orks_current_model(Profile::orks_weirdboy, sheet)
        model.keywords.append(Keyword::infantry)
        model.keywords.append(Keyword::character)
        model.keywords.append(Keyword::psyker)
        model.abilities.append(AbilityKind::da_jump)
        model.abilities.append(AbilityKind::weirdboy_warpath)
        model.has_deadly_demise = true
        model.deadly_demise = dice_stat(3)
        assert(hull_mm == 0, "source base must not be replaced by an invented size")
    assert(matched, "remaining adapter requires a current standard datasheet")
    return model

# https://wahapedia.ru/wh40k11ed/factions/orks/Boss-Snikrot: equipment/composition.
fun make_orks_boss_snikrot() -> Unit:
    let model = orks_remaining_model(OrksDatasheet::boss_snikrot, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::slugga, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::mork_s_teef, 1)
    return finish_orks_elite_unit(model, "Boss Snikrot"s, OrksDatasheet::boss_snikrot)

# https://wahapedia.ru/wh40k11ed/factions/orks/Ghazghkull-Thraka: equipment/composition.
fun make_orks_ghazghkull_thraka() -> Unit:
    let model = orks_remaining_model(OrksDatasheet::ghazghkull_thraka, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::mork_s_roar_aimed, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::adamantine_eadbutt, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::gork_s_klaw, 1)
    return finish_orks_elite_unit(model, "Ghazghkull Thraka"s, OrksDatasheet::ghazghkull_thraka)

# https://wahapedia.ru/wh40k11ed/factions/orks/Gorkanaut: equipment/composition.
fun make_orks_gorkanaut() -> Unit:
    let model = orks_remaining_model(OrksDatasheet::gorkanaut, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::deffstorm_mega_shoota_aimed, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::dual_big_shoota, 2)
    equip_orks_remaining_family(model, NamedWeaponProfile::rokkit_launcha_blasta, 2)
    equip_orks_remaining_family(model, NamedWeaponProfile::skorcha, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::klaw_of_gork, 1)
    return finish_orks_elite_unit(model, "Gorkanaut"s, OrksDatasheet::gorkanaut)

# https://wahapedia.ru/wh40k11ed/factions/orks/Hunta-Rig: equipment/composition.
fun make_orks_hunta_rig() -> Unit:
    let model = orks_remaining_model(OrksDatasheet::hunta_rig, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::eavy_lobba, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::stikka_kannon, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::butcha_boyz, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::savage_horns_and_hooves, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::saw_blades, 1)
    return finish_orks_elite_unit(model, "Hunta Rig"s, OrksDatasheet::hunta_rig)

# https://wahapedia.ru/wh40k11ed/factions/orks/Kill-Rig: equipment/composition.
fun make_orks_kill_rig() -> Unit:
    let model = orks_remaining_model(OrksDatasheet::kill_rig, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::eavy_lobba, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::stikka_kannon, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::wurrtower, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::butcha_boyz, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::savage_horns_and_hooves, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::saw_blades, 1)
    let unit = finish_orks_elite_unit(model, "Kill Rig"s, OrksDatasheet::kill_rig)
    unit.psyker_level = 1
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Morkanaut: equipment/composition.
fun make_orks_morkanaut() -> Unit:
    let model = orks_remaining_model(OrksDatasheet::morkanaut, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::dual_big_shoota, 2)
    equip_orks_remaining_family(model, NamedWeaponProfile::kustom_mega_blasta, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::kustom_mega_zappa, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::rokkit_launcha_blasta, 2)
    equip_orks_remaining_family(model, NamedWeaponProfile::klaw_of_mork, 1)
    return finish_orks_elite_unit(model, "Morkanaut"s, OrksDatasheet::morkanaut)

# https://wahapedia.ru/wh40k11ed/factions/orks/Nazdreg: equipment/composition.
fun make_orks_nazdreg() -> Unit:
    let model = orks_remaining_model(OrksDatasheet::nazdreg, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::kustom_blasta_x_gatler, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::moonchewa, 1)
    return finish_orks_elite_unit(model, "Nazdreg"s, OrksDatasheet::nazdreg)

# https://wahapedia.ru/wh40k11ed/factions/orks/Stompa: equipment/composition.
fun make_orks_stompa(Int hull_mm) -> Unit:
    let model = orks_remaining_model(OrksDatasheet::stompa, hull_mm)
    equip_orks_remaining_family(model, NamedWeaponProfile::big_shoota, 5)
    equip_orks_remaining_family(model, NamedWeaponProfile::deffkannon_and_supa_rokkits, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::skorcha, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::supa_gatler_aimed, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::mega_choppa, 1)
    return finish_orks_elite_unit(model, "Stompa"s, OrksDatasheet::stompa)

# https://wahapedia.ru/wh40k11ed/factions/orks/Wartrakks: equipment/composition.
fun make_orks_wartrakks(Int count) -> Unit:
    let model = orks_remaining_model(OrksDatasheet::wartrakks, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::kustom_shoota, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::multi_busta_launcha, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::kustom_choppa, 1)
    assert(count >= 1 and count <= 2, "composition requires1-2 models")
    let unit : Unit
    unit.name = "Wartrakks"s
    for member_index in range(count):
        unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::wartrakks)
    unit.capture_starting_strength()
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Wazdakka-Gutsmek: equipment/composition.
fun make_orks_wazdakka_gutsmek() -> Unit:
    let model = orks_remaining_model(OrksDatasheet::wazdakka_gutsmek, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::grabba_dragga_ranged, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::psyko_gatler, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::speeding_bulk_and_flaming_exhaust, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::fixit_s_wrench, 1)
    return finish_orks_elite_unit(model, "Wazdakka Gutsmek"s, OrksDatasheet::wazdakka_gutsmek)

# https://wahapedia.ru/wh40k11ed/factions/orks/Weirdboy: equipment/composition.
fun make_orks_weirdboy() -> Unit:
    let model = orks_remaining_model(OrksDatasheet::weirdboy, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::power_vomit, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::copper_staff, 1)
    let unit = finish_orks_elite_unit(model, "Weirdboy"s, OrksDatasheet::weirdboy)
    unit.psyker_level = 1
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Rukkatrukk-Squigbuggies: equipment/composition.
fun make_orks_rukkatrukk_squigbuggies(Int count) -> Unit:
    let model = orks_remaining_model(OrksDatasheet::rukkatrukk_squigbuggies, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::sawn_off_shotgun, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::squig_launchas, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::saw_blades, 1)
    assert(count >= 1 and count <= 2, "composition requires1-2 models")
    let unit : Unit
    unit.name = "Rukkatrukk Squigbuggies"s
    for member_index in range(count):
        unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::rukkatrukk_squigbuggies)
    unit.capture_starting_strength()
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon: equipment/composition.
fun make_orks_battlewagon(Int hull_mm, Int big_shootas, Bool ball, Bool klaw) -> Unit:
    let model = orks_remaining_model(OrksDatasheet::battlewagon, hull_mm)
    assert(big_shootas >= 0 and big_shootas <= 4, "invalid extra Big Shootas")
    equip_orks_remaining_family(model, NamedWeaponProfile::big_shoota, big_shootas)
    equip_orks_remaining_family(model, NamedWeaponProfile::crushin_bulk, 1)
    if ball:
        equip_orks_remaining_family(model, NamedWeaponProfile::wreckin_ball, 1)
    if klaw:
        equip_orks_remaining_family(model, NamedWeaponProfile::grabbin_klaw, 1)
    return finish_orks_elite_unit(model, "Battlewagon"s, OrksDatasheet::battlewagon)

# https://wahapedia.ru/wh40k11ed/factions/orks/Gunwagon: equipment/composition.
fun make_orks_gunwagon(Int hull_mm, Int big_shootas, Bool ball, Bool klaw, Bool lobba, OrksGunwagonGun gun) -> Unit:
    let model = orks_remaining_model(OrksDatasheet::gunwagon, hull_mm)
    assert(big_shootas >= 0 and big_shootas <= 4, "invalid extra Big Shootas")
    equip_orks_remaining_family(model, NamedWeaponProfile::big_shoota, big_shootas)
    equip_orks_remaining_family(model, NamedWeaponProfile::crushin_bulk, 1)
    if ball:
        equip_orks_remaining_family(model, NamedWeaponProfile::wreckin_ball, 1)
    if klaw:
        equip_orks_remaining_family(model, NamedWeaponProfile::grabbin_klaw, 1)
    assert(gun.value >= 0 and gun.value < 3, "invalid Gunwagon replacement")
    if gun.value == 0:
        equip_orks_remaining_family(model, NamedWeaponProfile::kannon_frag, 1)
    if gun.value == 1:
        equip_orks_remaining_family(model, NamedWeaponProfile::killkannon, 1)
    if gun.value == 2:
        equip_orks_remaining_family(model, NamedWeaponProfile::zzap_gun, 1)
    if lobba:
        equip_orks_remaining_family(model, NamedWeaponProfile::lobba, 1)
    return finish_orks_elite_unit(model, "Gunwagon"s, OrksDatasheet::gunwagon)

# https://wahapedia.ru/wh40k11ed/factions/orks/Big-ed-Bossbunka: equipment/composition.
fun make_orks_big_ed_bossbunka(Int hull_mm, Int big_shootas) -> Unit:
    let model = orks_remaining_model(OrksDatasheet::big_ed_bossbunka, hull_mm)
    assert(big_shootas >= 0 and big_shootas <= 3, "invalid extra Big Shootas")
    equip_orks_remaining_family(model, NamedWeaponProfile::big_shoota, big_shootas + 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::gaze_of_gork_glare, 1)
    return finish_orks_elite_unit(model, "Big ed Bossbunka"s, OrksDatasheet::big_ed_bossbunka)

# https://wahapedia.ru/wh40k11ed/factions/orks/Blitza-bommer: equipment/composition.
fun make_orks_blitza_bommer() -> Unit:
    let model = orks_remaining_model(OrksDatasheet::blitza_bommer, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::big_shoota, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::dual_supa_shoota, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::armoured_impact, 1)
    return finish_orks_elite_unit(model, "Blitza bommer"s, OrksDatasheet::blitza_bommer)

# https://wahapedia.ru/wh40k11ed/factions/orks/Burna-bommer: equipment/composition.
fun make_orks_burna_bommer(Bool missile_rack) -> Unit:
    let model = orks_remaining_model(OrksDatasheet::burna_bommer, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::dual_big_shoota, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::dual_supa_shoota, 1)
    if missile_rack:
        equip_orks_remaining_family(model, NamedWeaponProfile::skorcha_missile_rack, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::armoured_impact, 1)
    return finish_orks_elite_unit(model, "Burna bommer"s, OrksDatasheet::burna_bommer)

# https://wahapedia.ru/wh40k11ed/factions/orks/Dakkajet: equipment/composition.
fun make_orks_dakkajet(Bool third_gun) -> Unit:
    let model = orks_remaining_model(OrksDatasheet::dakkajet, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::dual_supa_shoota, 2 + int(third_gun))
    equip_orks_remaining_family(model, NamedWeaponProfile::armoured_impact, 1)
    return finish_orks_elite_unit(model, "Dakkajet"s, OrksDatasheet::dakkajet)

# https://wahapedia.ru/wh40k11ed/factions/orks/Wazbom-Blastajet: equipment/composition.
fun make_orks_wazbom_blastajet(Bool tellyport, Bool field, Bool supa_shoota) -> Unit:
    let model = orks_remaining_model(OrksDatasheet::wazbom_blastajet, 0)
    if supa_shoota:
        equip_orks_remaining_family(model, NamedWeaponProfile::dual_supa_shoota, 1)
    if tellyport:
        equip_orks_remaining_family(model, NamedWeaponProfile::dual_tellyport_mega_blasta, 1)
    if !tellyport:
        equip_orks_remaining_family(model, NamedWeaponProfile::dual_wazbom_mega_kannon, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::smasha_gun, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::armoured_impact, 1)
    model.blastajet_force_field = field
    return finish_orks_elite_unit(model, "Wazbom Blastajet"s, OrksDatasheet::wazbom_blastajet)

# https://wahapedia.ru/wh40k11ed/factions/orks/Deffkilla-Wartrike: equipment/composition.
fun make_orks_deffkilla_wartrike() -> Unit:
    let model = orks_remaining_model(OrksDatasheet::deffkilla_wartrike, 0)
    equip_orks_remaining_family(model, NamedWeaponProfile::boomstikks, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::snagga_klaw_ranged, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::killa_jet_burna, 1)
    return finish_orks_elite_unit(model, "Deffkilla Wartrike"s, OrksDatasheet::deffkilla_wartrike)

# https://wahapedia.ru/wh40k11ed/factions/orks/Trukk: equipment/composition.
fun make_orks_trukk(Int hull_mm, Bool rokkit, OrksTrukkExtra extra) -> Unit:
    let model = orks_remaining_model(OrksDatasheet::trukk, hull_mm)
    assert(extra.value >= 0 and extra.value <= 2, "invalid Trukk extra")
    if rokkit:
        equip_orks_remaining_family(model, NamedWeaponProfile::rokkit_launcha_blasta, 1)
    else:
        equip_orks_remaining_family(model, NamedWeaponProfile::dual_big_shoota, 1)
    equip_orks_remaining_family(model, NamedWeaponProfile::spiked_ram, 1)
    if extra.value == 1:
        equip_orks_remaining_family(model, NamedWeaponProfile::buzzsaw, 1)
    if extra.value == 2:
        equip_orks_remaining_family(model, NamedWeaponProfile::grabbin_klaw, 1)
    return finish_orks_elite_unit(model, "Trukk"s, OrksDatasheet::trukk)

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
        let model = orks_remaining_model(OrksDatasheet::deffkoptas, 0)
        if swaps[item_index]:
            equip_orks_remaining_family(model, NamedWeaponProfile::kustom_mega_blasta, 1)
        else:
            equip_orks_remaining_family(model, NamedWeaponProfile::rokkit_launcha_blasta, 1)
        equip_orks_remaining_family(model, NamedWeaponProfile::slugga, 1)
        equip_orks_remaining_family(model, NamedWeaponProfile::choppa, 1)
        equip_orks_remaining_family(model, NamedWeaponProfile::spinnin_blades, 1)
        unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::deffkoptas)
    unit.capture_starting_strength()
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
        let model = orks_remaining_model(OrksDatasheet::warbuggies, 0)
        if swaps[item_index]:
            equip_orks_remaining_family(model, NamedWeaponProfile::rivet_kannon_aimed, 1)
        else:
            equip_orks_remaining_family(model, NamedWeaponProfile::mek_speshul_aimed, 1)
        equip_orks_remaining_family(model, NamedWeaponProfile::extra_dakka, 1)
        equip_orks_remaining_family(model, NamedWeaponProfile::spiked_ram, 1)
        unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::warbuggies)
    unit.capture_starting_strength()
    return unit

# https://wahapedia.ru/wh40k11ed/factions/orks/Mek-Gunz: crew tokens are not models.
fun make_orks_mek_gunz(OrksMekGuns guns, Int hull_mm) -> Unit:
    assert(guns.size() >= 1 and guns.size() <= 3, "invalid Mek Gunz composition")
    let unit : Unit
    unit.name = "Mek Gunz"s
    for item_index in range(guns.size()):
        assert(guns[item_index].value >= 0 and guns[item_index].value < 4, "invalid Mek Gun replacement")
        let model = orks_remaining_model(OrksDatasheet::mek_gunz, hull_mm)
        if guns[item_index].value == 0:
            equip_orks_remaining_family(model, NamedWeaponProfile::smasha_gun, 1)
        if guns[item_index].value == 1:
            equip_orks_remaining_family(model, NamedWeaponProfile::bubblechukka, 1)
        if guns[item_index].value == 2:
            equip_orks_remaining_family(model, NamedWeaponProfile::kustom_mega_kannon, 1)
        if guns[item_index].value == 3:
            equip_orks_remaining_family(model, NamedWeaponProfile::traktor_kannon, 1)
        equip_orks_remaining_family(model, NamedWeaponProfile::scavenged_shivs, 1)
        unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::mek_gunz)
    unit.capture_starting_strength()
    return unit

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

# Exact source composition/loadout; declaration-time split happens separately.
# https://wahapedia.ru/wh40k11ed/factions/orks/Kommandos
fun make_orks_kommandos(OrksKommandoLoadout equipment) -> Unit:
    assert(orks_kommando_loadout_valid(equipment), "invalid Kommando loadout")
    let unit : Unit
    unit.name = "Kommandos"s
    for item_index in range(10):
        ref item = equipment[item_index]
        let model = orks_remaining_model(OrksDatasheet::kommandos, 0)
        if item_index == 0:
            model.profile = Profile::orks_kommando_nob
        equip_orks_remaining_family(model, NamedWeaponProfile::slugga, 1)
        if item_index == 0 and item.nob_melee.value == OrksNobMeleeChoice::big_choppa.value:
            equip_orks_remaining_family(model, NamedWeaponProfile::big_choppa, 1)
        else:
            if item_index == 0 and item.nob_melee.value == OrksNobMeleeChoice::power_klaw.value:
                equip_orks_remaining_family(model, NamedWeaponProfile::power_klaw, 1)
            else:
                if item.breacha_ram:
                    equip_orks_remaining_family(model, NamedWeaponProfile::breacha_ram, 1)
                else:
                    equip_orks_remaining_family(model, NamedWeaponProfile::choppa, 1)
        if item.burna:
            equip_orks_remaining_family(model, NamedWeaponProfile::burna, 1)
        if item.rokkit:
            equip_orks_remaining_family(model, NamedWeaponProfile::rokkit_launcha_blasta, 1)
        if item.kustom_shoota:
            equip_orks_remaining_family(model, NamedWeaponProfile::kustom_shoota, 1)
        unit.models.append(model)
    configure_orks_attachment(unit, OrksDatasheet::kommandos)
    unit.capture_starting_strength()
    return unit

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
