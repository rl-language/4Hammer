"""Run desired-rule assertions individually; only recorded false results are expected.

A crash, missing test, new failure outside the manifest or unexpected pass fails
the check. When fixing a discrepancy, promote its test to baseline.rl and remove
its manifest entry. An expected failure is not rule compliance.
"""

import json
from pathlib import Path
from rlc import compile


def main():
    root = Path(__file__).resolve().parents[1]
    expected = json.loads((root / "tests/known_discrepancies.json").read_text())
    with compile(
        [str(root / "tests/known_discrepancies.rl")],
        rlc_includes=[str(root / "src")],
        gen_python_methods=False,
        optimized=False,
    ) as program:
        tests = {
            name: functions
            for name, functions in program.module.wrappers.items()
            if name.startswith("test_")
        }
        if set(tests) != set(expected):
            raise RuntimeError(f"Manifest mismatch: {set(tests) ^ set(expected)}")
        unexpected = []
        for name, functions in tests.items():
            if len(functions) != 1 or program.module.signatures[functions[0]] != [bool]:
                raise RuntimeError(f"Expected zero-argument Bool test: {name}")
            if functions[0]():
                print(f"XPASS: {name}; promote test and remove manifest entry", flush=True)
                unexpected.append(name)
            else:
                print(f"XFAIL: {name} ({expected[name]['source']})", flush=True)
        print(f"Known discrepancies: {len(tests) - len(unexpected)} XFAIL, {len(unexpected)} XPASS", flush=True)
        return bool(unexpected)


if __name__ == "__main__":
    raise SystemExit(main())
