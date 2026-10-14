"""Compare compiled current profiles/weapons with cached source HTML tables.

The optional price/enhancement rows are outside this data check. The source
HTML is required because the audit's text extracts omit invulnerable saves.
"""
import argparse
import html
import json
import re
from pathlib import Path

from rlc.program import Program


CARDS = {
    'Beastboss': (['orks_beastboss'],
                  ['orks_beastboss_shoota', 'orks_beastboss_klaw_and_beastchoppa']),
    'Beast-Snagga-Boyz': (['orks_beast_snagga_boy', 'orks_beast_snagga_nob'],
                         ['orks_slugga', 'orks_thump_gun', 'orks_choppa_standard',
                          'orks_choppa_hunter', 'orks_power_snappa']),
    'Squighog-Boyz': (['orks_squighog_boy', 'orks_nob_on_smasha_squig'],
                     ['orks_saddlegit_shiv', 'orks_slugga', 'orks_stikka_ranged',
                      'orks_big_choppa', 'orks_squig_jaws', 'orks_stikka_melee']),
}
CARDS.update({'Boyz': (['orks_boy', 'orks_boyz_nob'],
          ['orks_infantry_big_shoota',
           'orks_burna',
           'orks_kombi_rokkit_busta',
           'orks_kombi_rokkit_shoota',
           'orks_kombi_skorcha_shoota',
           'orks_kombi_skorcha_skorcha',
           'orks_kustom_shoota',
           'orks_rokkit_launcha_blasta',
           'orks_rokkit_launcha_busta',
           'orks_shoota',
           'orks_slugga',
           'orks_infantry_big_choppa',
           'orks_choppa_standard',
           'orks_kustom_choppa',
           'orks_power_klaw']),
 'Nobz': (['orks_nob'],
          ['orks_big_skorcha',
           'orks_kustom_big_shoota',
           'orks_kombi_rokkit_busta',
           'orks_kombi_rokkit_shoota',
           'orks_kustom_shoota',
           'orks_infantry_big_choppa',
           'orks_kustom_choppa',
           'orks_kustom_krumpa']),
 'Warboss': (['orks_warboss'],
             ['orks_kombi_rokkit_busta',
              'orks_kombi_rokkit_shoota',
              'orks_kombi_skorcha_shoota',
              'orks_kombi_skorcha_skorcha',
              'orks_kustom_shoota',
              'orks_warboss_kustom_choppa',
              'orks_warboss_power_klaw']),
 'Bigboss': (['orks_bigboss'], ['orks_slugga', 'orks_bigboss_big_choppa']),
 'Bannernob': (['orks_bannernob'], ['orks_shoota', 'orks_kustom_choppa']),
 'Stormboyz': (['orks_stormboy', 'orks_stormboy_nob'],
               ['orks_slugga',
                'orks_choppa_standard',
                'orks_kustom_choppa',
                'orks_power_klaw']),
 'Warbikers': (['orks_warbiker', 'orks_biker_nob'],
               ['orks_dual_kombi_rokkit_dakkagun',
                'orks_dual_kombi_rokkit_busta',
                'orks_dual_dakkagun',
                'orks_choppa_standard',
                'orks_kustom_choppa']),
 'Deff-Dread': (['orks_deff_dread'],
                ['orks_dread_big_shoota',
                 'orks_kustom_mega_blasta',
                 'orks_rokkit_launcha_blasta',
                 'orks_rokkit_launcha_busta',
                 'orks_skorcha',
                 'orks_extra_klaw',
                 'orks_dread_klaws']),
 'Killa-Kans': (['orks_killa_kan'],
                ['orks_kan_blasta_dakka',
                 'orks_kan_blasta_kill_shot',
                 'orks_kan_blasta_point_blank',
                 'orks_kan_klaw']),
 'Big-Mek-Dakkarig': (['orks_big_mek_dakkarig'],
                      ['orks_blitzkannon',
                       'orks_multi_busta_launcha',
                       'orks_stompy_feet']),
 'Beastboss-on-Squigosaur': (['orks_beastboss_on_squigosaur'],
                             ['orks_slugga',
                              'orks_thump_gun',
                              'orks_beastchoppa_standard',
                              'orks_beastchoppa_hunter',
                              'orks_squigosaur_jaws']),
 'Mozrog-Skragbad': (['orks_mozrog_skragbad'],
                     ['orks_thump_gun',
                      'orks_big_chompa_jaws',
                      'orks_gutrippa_standard',
                      'orks_gutrippa_hunter'])})


def number(text):
    cleaned = re.sub(r'[^0-9-]', '', html.unescape(text))
    return 0 if cleaned in ('', '-') else int(cleaned)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wrapper', type=Path, required=True)
    parser.add_argument('--source-dir', type=Path, required=True,
                        help='Retrieved Orks source HTML directory')
    args = parser.parse_args()
    module = Program(str(args.wrapper.resolve())).module
    profiles_checked, weapon_rows_checked = 0, 0
    for card, (profile_names, weapon_names) in CARDS.items():
        source = (args.source_dir / (card + '.html')).read_text()
        start = source.index('dsProfileBaseWrap')
        profile_block = source[start:source.index('ds2col', start)]
        values = re.findall(r'class="dsCharValue dsColorORK">(.*?)</div>',
                            profile_block)
        invulnerable = re.findall(r'class="dsCharInvulValue dsColorORK">(.*?)</div>',
                                 profile_block)
        assert len(values) == 6 * len(profile_names) and len(invulnerable) <= 1
        for index, name in enumerate(profile_names):
            profile = getattr(module.Profile, name)()
            actual = [profile.movement(), profile.thoughness(), profile.save(),
                      profile.wounds(), profile.leadership(), profile.control()]
            expected = [number(value) for value in values[index * 6:(index + 1) * 6]]
            assert actual == expected, (card, name, actual, expected)
            assert profile.invuln_save() == (number(invulnerable[0]) if invulnerable else 10), (card, 'InSv')
            profiles_checked += 1
        rows = re.findall(r'<tr class="dsWeaponRow">(.*?)</tr>', source, re.S)
        assert len(rows) >= len(weapon_names)
        for row, name in zip(rows, weapon_names):
            values = re.findall(r'class="ct pad2626">(.*?)</div>', row)
            assert len(values) == 6, (card, name)
            weapon = getattr(module.Weapon, name)()
            fixed_actual = [weapon.range(), weapon.skill(), weapon.strenght(), weapon.penetration()]
            fixed_expected = [0 if values[0] == 'Melee' else number(values[0]),
                              number(values[2]), number(values[3]), number(values[4])]
            assert fixed_actual == fixed_expected, (card, name, fixed_actual, fixed_expected)
            for value, stat in ((values[1], weapon.attacks()), (values[5], weapon.damage())):
                cleaned = html.unescape(re.sub(r'<[^>]+>', '', value)).strip()
                match = re.fullmatch(r'(\d*)D([36])(?:\+(\d+))?', cleaned)
                actual = [module.stat_dice_count(stat), module.stat_dice_sides(stat),
                          module.stat_intrinsic_constant(stat)]
                if match:
                    expected = [int(match[1] or 1), int(match[2]), int(match[3] or 0)]
                    assert actual == expected, (card, name, cleaned, actual, expected)
                else:
                    assert actual == [0, 0, 0], (card, name, cleaned, actual)
                    evaluated = module.evaluate_random_stat(stat)
                    assert evaluated.is_done() and evaluated.result.value == number(cleaned), (card, name, cleaned)

            printed = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', row)))
            for label, rule in (('Rapid Fire', 'rapid_fire'), ('Blast', 'blast'),
                                ('Cleave', 'cleave'), ('Sustained Hits', 'sustained_hit')):
                match = re.search(re.escape(label) + r' (\d+)', printed, re.I)
                kind = getattr(module.WeaponRuleKind, rule)()
                assert weapon.has_rule(kind) == bool(match), (card, name, label)
                if match:
                    assert weapon.get_rule_parameter(kind) == int(match[1]), (card, name, label, match[1])
            for label, rule in (('Torrent', 'torrent'), ('Hazardous', 'hazardous'),
                                ('Extra Attacks', 'extra_attacks'), ('Precision', 'precision'),
                                ('Assault', 'assault'), ('Ignores Cover', 'ignore_cover'),
                                ('Lethal Hits', 'letal_hits')):
                expected = bool(re.search(r'\b' + re.escape(label) + r'\b', printed, re.I))
                assert weapon.has_rule(getattr(module.WeaponRuleKind, rule)()) == expected, (card, name, label, printed)
            weapon_rows_checked += 1
    print(json.dumps({'cards': len(CARDS), 'profiles': profiles_checked,
                      'weapon_rows': weapon_rows_checked, 'result': 'PASS'}))


if __name__ == '__main__':
    main()
