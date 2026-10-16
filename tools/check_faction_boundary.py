"""Reject concrete Orks behavior in core functions/actions.

Shared catalogs/types, serialization labels and typed context storage are allowed.
This is a source audit, separate from the entirely native rule-test runner.
"""
import json
from pathlib import Path
import re


def audit(root):
    src = root / 'src'
    concrete = set()
    for path in (src / 'factions/orks').glob('*.rl'):
        concrete.update(re.findall(r'^(?:fun|act) (\w+)\(', path.read_text(), re.M))
    presentation = {'as_string_literal', 'source_label_text', 'weapon_family_label',
                    'pretty_string'}
    errors = []
    functions = 0
    for path in sorted(src.glob('*.rl')):
        declaration = None
        scope = None
        for number, original in enumerate(path.read_text().splitlines(), 1):
            line = re.sub(r'"[^"\n]*"|#[^\n]*', '', original).rstrip()
            if not line.strip():
                continue
            if re.match(r'^import factions\.orks\.(?!types\b)', line):
                errors.append((str(path.relative_to(root)), number,
                               'concrete behavior import'))
            if not line.startswith(' '):
                declaration = None
                scope = ('enum' if line.startswith('enum ') else
                         'class' if line.startswith('cls ') else None)
            header = re.match(r'^(?:    )?(?:fun(?:<[^\n]*>)?|act) (\w+)\(', line)
            if header:
                declaration = header[1]
                functions += 1
                continue
            if not declaration or scope == 'enum':
                continue
            calls = set(re.findall(r'\b(\w+)\(', line))
            for call in sorted(calls & concrete):
                errors.append((str(path.relative_to(root)), number,
                               'concrete behavior call: ' + call))
            if declaration in presentation:
                continue
            if re.search(r'\b(?:OrksEffectKind|OrksEnhancement|OrksDatasheet)::', line):
                errors.append((str(path.relative_to(root)), number,
                               'embedded faction rule/identity check'))
            if re.search(r'\b(?:if|while|return)\b.*\.(?:orks_\w+|has_waaagh|grants_unit_riled_up|riled_source_effects|shokk_boosta_move|bodyguard_waaagh)\b', line):
                errors.append((str(path.relative_to(root)), number,
                               'embedded faction-state policy'))
            if re.search(r'\bORKS_[A-Z_]+\b', line):
                errors.append((str(path.relative_to(root)), number,
                               'embedded faction rule code'))
    return {'result': 'FAIL' if errors else 'PASS',
            'core_functions_and_actions_scanned': functions,
            'concrete_adapter_symbols': len(concrete), 'errors': errors}


def main():
    result = audit(Path(__file__).resolve().parents[1])
    print(json.dumps(result, indent=2))
    raise SystemExit(bool(result['errors']))


if __name__ == '__main__':
    main()
