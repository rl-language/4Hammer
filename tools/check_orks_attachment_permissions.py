"""Cross-check compiled attachment metadata against the source inventory.

Use a matching CTest baseline wrapper; this check performs no compilation.
"""
import argparse
import csv
import json
from pathlib import Path

from rlc.program import Program


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wrapper', type=Path, required=True,
                        help='Matching generated baseline wrapper.py from CTest')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    module = Program(str(args.wrapper.resolve())).module
    with (root / 'doc/orks-unit-requirements.tsv').open() as source:
        rows = list(csv.DictReader(source, delimiter='\t'))
    identities = {}
    for code in range(1, 68):
        tag = module.OrksDatasheet()
        tag.value = code
        identities[tag.label().decode().upper()] = code
    assert len(rows) == len(identities), 'Duplicate or missing inventory cards'
    assert {row['unit'].upper() for row in rows} == set(identities)
    names = sorted(identities, key=len, reverse=True)
    roles = [0, 0, 0]
    permission_count = 0
    for row in rows:
        expected_role, expected = 0, []
        if row['implementation_scope'] == 'included':
            for role, column in ((1, 'leader_permissions'), (2, 'support_permissions')):
                if not row[column]:
                    continue
                assert expected_role == 0, (row['unit'], 'duplicate role')
                expected_role = role
                text = row[column].split(':', 1)[1].strip().upper()
                while text:
                    match = next((name for name in names if text == name or
                                  text.startswith(name + ' ')), None)
                    assert match, (row['unit'], text)
                    expected.append(identities[match])
                    text = text[len(match):].strip()
        tag = module.OrksDatasheet()
        tag.value = identities[row['unit'].upper()]
        unit = module.Unit()
        module.configure_orks_attachment(unit, tag)
        actual = [unit.permitted_bodyguards.get(index).contents.value
                  for index in range(unit.permitted_bodyguards.size())]
        assert unit.attachment_role.value == expected_role, (row['unit'], 'role')
        assert set(actual) == set(expected) and len(actual) == len(expected), (
            row['unit'], actual, expected)
        roles[expected_role] += 1
        permission_count += len(actual)
    assert roles[1:] == [10, 7]
    print(json.dumps({'catalog_cards': len(rows), 'leader_cards': roles[1],
                      'support_cards': roles[2], 'permission_edges': permission_count,
                      'excluded_cards_checked': sum(row['implementation_scope'] != 'included'
                                                    for row in rows),
                      'result': 'PASS'}))


if __name__ == '__main__':
    main()
