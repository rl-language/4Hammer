"""Discover, compile once, and execute isolated Rulebook tests for CTest."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {"baseline": "baseline.rl", "discrepancies": "known_discrepancies.rl"}


def discover(suite):
    names = re.findall(r"^fun (test_\w+)\(\) -> Bool:",
                       (ROOT / "tests" / SOURCES[suite]).read_text(), re.M)
    if (not names and suite == "baseline") or len(set(names)) != len(names):
        raise RuntimeError(f"Empty or duplicate {suite} test declarations")
    if suite == "discrepancies":
        if set(names) != set(manifest()):
            raise RuntimeError("Known-discrepancy manifest does not match declarations")
    return names


def manifest():
    return json.loads((ROOT / "tests/known_discrepancies.json").read_text())


def load(directory, suite):
    from rlc.program import Program
    program = Program(str(directory / "wrapper.py"))
    tests = {name: functions for name, functions in program.module.wrappers.items()
             if name.startswith("test_")}
    if set(tests) != set(discover(suite)):
        raise RuntimeError("Compiled tests do not match source declarations")
    for name, functions in tests.items():
        if len(functions) != 1 or program.module.signatures[functions[0]] != [bool]:
            raise RuntimeError(f"Expected zero-argument Bool test: {name}")
    return tests


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("list", "build", "run"))
    parser.add_argument("--suite", choices=SOURCES)
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--compiler", default="rlc")
    parser.add_argument("--jobs", type=int, default=4,
                        help="compiler worker count (RLC 0.4.17+)")
    parser.add_argument("--optimize", action="store_true",
                        help="use -O2; omitted for debug builds")
    parser.add_argument("--test")
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    if args.mode == "list":
        for suite in SOURCES:
            for name in discover(suite):
                print(f"{suite}|{name}")
        return 0
    if args.suite is None or args.directory is None:
        parser.error("build/run require --suite and --directory")
    directory = args.directory.resolve()
    if args.mode == "build":
        discover(args.suite)
        directory.mkdir(parents=True, exist_ok=True)
        library = "lib.dll" if sys.platform == "win32" else (
            "lib.dylib" if sys.platform == "darwin" else "lib.so")
        # Remove only this fixture's outputs; never reuse a failed/stale build.
        for filename in ("wrapper.py", library):
            (directory / filename).unlink(missing_ok=True)
        common = [args.compiler, str(ROOT / "tests" / SOURCES[args.suite]),
                  "-i", str(ROOT / "src"), "--emit-precondition-checks",
                  "--emit-bound-checks", "-j", str(args.jobs)]
        if args.optimize:
            common.append("-O2")
        subprocess.run(common + ["--python", "-o", str(directory / "wrapper.py")], check=True)
        subprocess.run(common + ["--shared", "--pylib", "-o", str(directory / library)], check=True)
        if not (directory / library).is_file() or (directory / library).stat().st_size == 0:
            raise RuntimeError("Compiler did not produce a native test library")
        load(directory, args.suite)
        print(f"Compiled and verified {len(discover(args.suite))} {args.suite} tests", flush=True)
        return 0
    tests = load(directory, args.suite)
    if args.test not in tests:
        parser.error("--test must name a discovered test")
    print(f"RUN: {args.test}", flush=True)
    result = tests[args.test][0]()
    if args.suite == "discrepancies":
        if result:
            print(f"XPASS: {args.test}; promote assertion and remove manifest entry", flush=True)
            return 1
        print(f"XFAIL: {args.test} ({manifest()[args.test]['source']})", flush=True)
        return 77
    print(f"{'PASS' if result else 'FAIL'}: {args.test}", flush=True)
    return 0 if result else 1


if __name__ == "__main__":
    raise SystemExit(main())
