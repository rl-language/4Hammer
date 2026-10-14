"""Run Python rule regressions against the library already built for Godot."""
import argparse
import ast
import importlib
import json
import os
from pathlib import Path
import sys
import time
import traceback

ROOT = Path(__file__).resolve().parents[1]
SUITES = {'baseline': 'baseline.py', 'discrepancies': 'known_discrepancies.py'}
PYTHON_TESTS = ROOT / 'tests/python'


def manifest():
    return json.loads((ROOT / 'tests/known_discrepancies.json').read_text())


def discover(suite):
    declarations = [node for node in ast.parse((PYTHON_TESTS / SUITES[suite]).read_text()).body
                    if isinstance(node, ast.FunctionDef) and node.name.startswith('test_')]
    names = [node.name for node in declarations]
    if (not names and suite == 'baseline') or len(set(names)) != len(names):
        raise RuntimeError(f'Empty or duplicate {suite} test declarations')
    for node in declarations:
        if node.args.args or node.args.posonlyargs or node.args.kwonlyargs or node.args.vararg or node.args.kwarg:
            raise RuntimeError(f'Expected zero-argument Python test: {node.name}')
    if suite == 'discrepancies' and set(names) != set(manifest()):
        raise RuntimeError('Known-discrepancy manifest does not match Python declarations')
    return names


def load(wrapper, library):
    for path in (wrapper, library):
        if not path.is_file():
            raise RuntimeError(f'Missing Godot build artifact: {path}; build the game or specify --wrapper and --library')
    sys.path.insert(0, str(PYTHON_TESTS))
    from bindings import rl
    rl.load(wrapper, library)
    if any(name.startswith('test_') for name in rl.module.wrappers):
        raise RuntimeError('Bindings contain compiled tests; generate them from src/full_game.rl')
    for name, constant in [('get_state_schema_version', 'STATE_SCHEMA_VERSION'),
                           ('get_action_schema_version', 'ACTION_SCHEMA_VERSION'),
                           ('get_observation_schema_version', 'OBSERVATION_SCHEMA_VERSION')]:
        if getattr(rl, name)() != getattr(rl, constant):
            raise RuntimeError(f'Stale Godot library: {constant} differs; rebuild the game and bindings together')
    return rl


def execute(suite, name):
    module = importlib.import_module(Path(SUITES[suite]).stem)
    print(f'RUN: {name}', flush=True)
    try:
        result = getattr(module, name)()
        if type(result) is not bool:
            raise TypeError(f'{name} must return Bool, got {type(result).__name__}')
    except Exception:
        # Infrastructure/fixture exceptions must fail even for expected defects.
        traceback.print_exc()
        return 1
    if suite == 'discrepancies':
        if result:
            print(f'XPASS: {name}; promote assertion and remove manifest entry', flush=True)
            return 1
        print(f"XFAIL: {name} ({manifest()[name]['source']})", flush=True)
        return 77
    print(f"{'PASS' if result else 'FAIL'}: {name}", flush=True)
    return 0 if result else 1


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument('mode', choices=('list', 'check', 'run', 'all'))
    result.add_argument('--suite', choices=SUITES)
    result.add_argument('--wrapper', type=Path,
                        default=Path(os.environ.get('FOURHAMMER_PYTHON_WRAPPER', ROOT / 'build/skirmish.py')))
    result.add_argument('--library', type=Path,
                        default=Path(os.environ.get('FOURHAMMER_RULES_LIBRARY', ROOT / 'build/librules_x86_64_linux_debug.so')),
                        help='Existing Rulebook library linked by Godot; never compiled by this runner')
    result.add_argument('--test')
    return result


def main(argv=None):
    arguments = parser()
    args = arguments.parse_args(argv)
    suites = [args.suite] if args.suite else list(SUITES)
    discovered = [(suite, name) for suite in suites for name in discover(suite)]
    if args.mode == 'list':
        for suite, name in discovered:
            print(f'{suite}|{name}')
        return 0
    if args.mode == 'run' and (args.suite, args.test) not in discovered:
        arguments.error('--suite and --test must name a discovered test')
    if args.mode == 'all' and not discovered:
        print('No discrepancy assertions to run', flush=True)
        return 0
    load(args.wrapper.resolve(), args.library.resolve())
    if args.mode == 'check':
        print(f'Loaded Godot Rulebook library: {args.library.resolve()}', flush=True)
        print(f'Discovered {len(discovered)} Python assertions', flush=True)
        return 0
    if args.mode == 'run':
        return execute(args.suite, args.test)
    counts = {0: 0, 1: 0, 77: 0}
    started = time.monotonic()
    for suite, name in discovered:
        counts[execute(suite, name)] += 1
    print(f"Results: {counts[0]} PASS, {counts[77]} XFAIL, {counts[1]} FAIL/XPASS; {len(discovered)} executed", flush=True)
    print(f'Assertion execution: {time.monotonic() - started:.2f}s (library loading excluded)', flush=True)
    return int(counts[1] != 0)


if __name__ == '__main__':
    raise SystemExit(main())
