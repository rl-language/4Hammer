"""Compare compiled ordinary Orks option/card metadata with retrieved sources.

Use a matching CTest wrapper and the audit's separately extracted JSON files.
This checks identities, packages, Upgrade tags and printed CP; deterministic
Rulebook tests establish effect semantics and timing. No compilation occurs.
"""
import argparse
import json
import re
from pathlib import Path
from rlc.program import Program


def normalized(value):
    return re.sub(r'[^a-z0-9]', '', value.lower())


def enum_values(module, typename):
    source = Path(__file__).resolve().parents[1] / 'src'
    text = '\n'.join(path.read_text() for path in source.rglob('*.rl'))
    body = re.search(r'^enum ' + typename + r':\n((?:[ \t].*\n|\n)*)', text, re.M)[1]
    names = re.findall(r'^    ([a-z][a-z0-9_]*)(?::)?$', body, re.M)
    result = {}
    for code, name in enumerate(names):
        value = getattr(module, typename)()
        value.value = code
        result[normalized(name)] = value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wrapper', type=Path, required=True)
    parser.add_argument('--source-dir', type=Path, required=True,
                        help='Audit directory containing enhancements/stratagems.json')
    args = parser.parse_args()
    module = Program(str(args.wrapper.resolve())).module
    packages = enum_values(module, 'OrksDetachment')
    options = enum_values(module, 'OrksEnhancement')
    cards = enum_values(module, 'Stratagem')
    enhancements = json.loads((args.source_dir / 'enhancements.json').read_text())
    stratagems = [row for row in json.loads((args.source_dir / 'stratagems.json').read_text())
                  if normalized(row['detachment']) in packages]
    assert len(enhancements) == 38 and len(stratagems) == 40
    seen_options, seen_cards, seen_packages = set(), set(), set()
    for row in enhancements:
        # The source heading appends its separate UPGRADE badge to the name.
        # Check the badge independently rather than making it an enum identity.
        name = normalized(re.sub(r'\s+UPGRADE$', '', row['name']))
        option = options[name]
        package = packages[normalized(row['detachment'])]
        assert module.orks_enhancement_package(option).value == package.value, row
        assert module.orks_is_upgrade(option) == row['upgrade'], row
        seen_options.add(name)
        seen_packages.add(package.value)
    for row in stratagems:
        name = normalized('orks_' + row['name'])
        card = cards[name]
        package = packages[normalized(row['detachment'])]
        assert card.orks_detachment().value == package.value, row
        assert card.cost() == row['cp_cost'], row
        seen_cards.add(name)
        seen_packages.add(package.value)
    assert len(seen_options) == 38 and len(seen_cards) == 40
    assert len(seen_packages) == 15
    print(json.dumps(dict(result='PASS', detachments=15, enhancements=38,
                          upgrades=sum(row['upgrade'] for row in enhancements),
                          stratagems=40, scope='identity/package/Upgrade/printed CP')))


if __name__ == '__main__':
    main()
