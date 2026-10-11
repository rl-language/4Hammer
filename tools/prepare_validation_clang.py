"""Extract pinned Debian Clang 19 packages without a system installation.

For the Debian 13 amd64 cloud environment with libLLVM-19, libc headers, GCC
and binutils already available. Downloads stay outside the checkout, and every
package is checked against the recorded SHA256 before extraction.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import urllib.request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("/workspace/4hammer-validation/toolchain"))
    args = parser.parse_args()
    if platform.machine() != "x86_64" or platform.system() != "Linux":
        raise RuntimeError("This pinned toolchain is for Linux amd64")
    root = args.output.resolve()
    packages = root / "packages"
    packages.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(Path(__file__).with_name("validation-clang-packages.json").read_text())
    for package in manifest:
        dest = packages / Path(package["Filename"]).name
        if not dest.exists():
            print(f"Downloading {package['Package']} {package['Version']}", flush=True)
            with urllib.request.urlopen("https://deb.debian.org/debian/" + package["Filename"], timeout=60) as response:
                dest.write_bytes(response.read())
        if hashlib.sha256(dest.read_bytes()).hexdigest() != package["SHA256"]:
            raise RuntimeError(f"Checksum mismatch: {dest}")
        subprocess.run(["dpkg-deb", "-x", str(dest), str(root)], check=True)
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    env = dict(os.environ)
    env["LD_LIBRARY_PATH"] = str(root / "usr/lib/x86_64-linux-gnu") + ":" + env.get("LD_LIBRARY_PATH", "")
    clang = root / "usr/lib/llvm-19/bin/clang"
    subprocess.run([str(clang), "--version"], env=env, check=True)
    print(f"Use --clang={clang} and LD_LIBRARY_PATH={env['LD_LIBRARY_PATH']}", flush=True)


if __name__ == "__main__":
    main()
