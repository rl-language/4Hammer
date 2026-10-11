"""Prepare a pinned Clang 21 linker/runtime for RLC 0.4.13 on Debian 13 amd64.

Packages come from apt.llvm.org/trixie. Pins were checked against its signed
LLVM 21 InRelease using key 6084F3CF814B57C1CF12EFD515CF4D18AF4F7421,
then the authenticated Packages.gz SHA256. Each download is checksum-verified.
This is the narrow linker/sanitizer toolchain, not a complete LLVM SDK.
System libc headers, GCC 14, binutils and libLLVM dependencies are required.
"""

from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from urllib.request import urlopen
import hashlib,json,os,subprocess
root=Path('/workspace/4hammer-validation/toolchain21')
packages=root/'packages'
packages.mkdir(parents=True,exist_ok=True)
manifest=[
  {
    "Package": "clang-21",
    "Version": "1:21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50",
    "Filename": "pool/main/l/llvm-toolchain-21/clang-21_21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50_amd64.deb",
    "SHA256": "b29399ec1bcbda6ad6760ddb10291a21fc442d3e426193c7e83d58e2ed5021a2",
    "BaseURL": "https://apt.llvm.org/trixie/"
  },
  {
    "Package": "libclang-common-21-dev",
    "Version": "1:21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50",
    "Filename": "pool/main/l/llvm-toolchain-21/libclang-common-21-dev_21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50_amd64.deb",
    "SHA256": "4b55c0733a1d0389ccb05ec8d5b64a901af0ddf035fca68ddc0c79a499872403",
    "BaseURL": "https://apt.llvm.org/trixie/"
  },
  {
    "Package": "libclang-cpp21",
    "Version": "1:21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50",
    "Filename": "pool/main/l/llvm-toolchain-21/libclang-cpp21_21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50_amd64.deb",
    "SHA256": "f17f302cd393d15f513a16555a6a209f8e5db80a56a1924063190f684ba8d0a4",
    "BaseURL": "https://apt.llvm.org/trixie/"
  },
  {
    "Package": "libclang-rt-21-dev",
    "Version": "1:21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50",
    "Filename": "pool/main/l/llvm-toolchain-21/libclang-rt-21-dev_21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50_amd64.deb",
    "SHA256": "a3679de93a501379260d221be863e50da1f7f752c96b16e7c7b9722ea9f83784",
    "BaseURL": "https://apt.llvm.org/trixie/"
  },
  {
    "Package": "libclang1-21",
    "Version": "1:21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50",
    "Filename": "pool/main/l/llvm-toolchain-21/libclang1-21_21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50_amd64.deb",
    "SHA256": "b26441972de447989809ac65d6f12cbd6fcf6019e0708b63fb7b9eee447d95f4",
    "BaseURL": "https://apt.llvm.org/trixie/"
  },
  {
    "Package": "libllvm21",
    "Version": "1:21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50",
    "Filename": "pool/main/l/llvm-toolchain-21/libllvm21_21.1.8~++20251221033036+2078da43e25a-1~exp1~20251221153213.50_amd64.deb",
    "SHA256": "991d8f67b8414d7bcab70832538ef3def6a3a6eecdc4261d173009b516a0ab18",
    "BaseURL": "https://apt.llvm.org/trixie/"
  }
]
def download(package):
 dest=packages/Path(package['Filename']).name
 if not dest.exists():
  with urlopen(package['BaseURL']+package['Filename'],timeout=60) as response: dest.write_bytes(response.read())
 if hashlib.sha256(dest.read_bytes()).hexdigest()!=package['SHA256']: raise RuntimeError('Checksum mismatch: '+str(dest))
 return dest
with ThreadPoolExecutor(3) as pool:
 paths=list(pool.map(download,manifest))
for package,path in zip(manifest,paths):
 print('Verified and extracting '+package['Package'],flush=True)
 subprocess.run(['dpkg-deb','-x',str(path),str(root)],check=True)
# RLC's LLVM driver uses a per-target resource layout; Debian uses linux/arch-suffixed names.
# Link only same-version x86_64 runtimes into the expected layout.
runtime=root/'usr/lib/llvm-21/lib/clang/21/lib'
target=runtime/'x86_64-unknown-linux-gnu'
target.mkdir(exist_ok=True)
for source in (runtime/'linux').glob('*-x86_64.*'):
 name=source.name.replace('-x86_64.', '.')
 link=target/name
 if not link.exists(): link.symlink_to('../linux/'+source.name)
(root/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
env=dict(os.environ)
env['LD_LIBRARY_PATH']=str(root/'usr/lib/x86_64-linux-gnu')+':'+env.get('LD_LIBRARY_PATH','')
subprocess.run([str(root/'usr/lib/llvm-21/bin/clang'),'--version'],env=env,check=True)
