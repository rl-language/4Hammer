"""Run supported contracts and known discrepancies; reject zero-test success."""

import os
from pathlib import Path
import re
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parents[1]
    expected = set(re.findall(r"^fun (test_\w+)\(\) -> Bool:", (root / "tests/baseline.rl").read_text(), re.M))
    if not expected:
        raise RuntimeError("No deterministic baseline tests declared")
    env = dict(os.environ, PYTHONUNBUFFERED="1")
    result = subprocess.run(
        ["rlc-test", "tests/baseline.rl", "-i", "src"],
        cwd=root, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    print(result.stdout, end="", flush=True)
    ran = re.findall(r"RUN: (test_\w+)", result.stdout)
    passed = re.findall(r"OK:  (test_\w+)", result.stdout)
    if result.returncode or len(ran) != len(expected) or set(ran) != expected or set(passed) != expected:
        raise RuntimeError(f"Baseline failed or incomplete: {len(ran)} RUN, {len(passed)} OK, exit {result.returncode}")
    result = subprocess.run([sys.executable, "tools/check_known_discrepancies.py"], cwd=root, env=env)
    if result.returncode:
        raise RuntimeError(f"Discrepancy check failed: exit {result.returncode}")
    print(f"Supported baseline: {len(passed)} passed; discrepancy assertions remain separate.", flush=True)


if __name__ == "__main__":
    main()
