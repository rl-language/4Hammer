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


def number(text):
    return int(re.sub(r'[^0-9-]', '', html.unescape(text)))


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
        assert len(values) == 6 * len(profile_names) and len(invulnerable) == 1
        for index, name in enumerate(profile_names):
            profile = getattr(module.Profile, name)()
            actual = [profile.movement(), profile.thoughness(), profile.save(),
                      profile.wounds(), profile.leadership(), profile.control()]
            expected = [number(value) for value in values[index * 6:(index + 1) * 6]]
            assert actual == expected, (card, name, actual, expected)
            assert profile.invuln_save() == number(invulnerable[0]), (card, 'InSv')
            profiles_checked += 1
        rows = re.findall(r'<tr class="dsWeaponRow">(.*?)</tr>', source, re.S)
        assert len(rows) >= len(weapon_names)
        for row, name in zip(rows, weapon_names):
            values = re.findall(r'class="ct pad2626">(.*?)</div>', row)
            assert len(values) == 6, (card, name)
            expected = [0 if value == 'Melee' else number(value) for value in values]
            weapon = getattr(module.Weapon, name)()
            assert module.orks17h1_weapon_values(weapon, *expected), (card, name, expected)
            weapon_rows_checked += 1
    print(json.dumps({'cards': len(CARDS), 'profiles': profiles_checked,
                      'weapon_rows': weapon_rows_checked, 'result': 'PASS'}))


if __name__ == '__main__':
    main()
