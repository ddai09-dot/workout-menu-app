#!/usr/bin/env python3
from __future__ import annotations
import base64, gzip, hashlib, shutil, stat, subprocess, sys, tempfile, zipfile
from pathlib import Path
EXPECTED='969ccdf461d90a0936bce11050930b339d7bb50d6b879830b56d15f633560b2c'
PATCH_SHA='d7294fbe974e308be007532becb1f3e5f55e093c43a8c790d3971fa4b89184a3'
EXCLUDED={'build','.dart_tool'}
def files(root: Path):
    return sorted(p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.relative_to(root).parts[0] not in EXCLUDED and '__pycache__' not in p.relative_to(root).parts)
def apply(root: Path) -> None:
    patch_b64=Path(__file__).with_name('task20_d2j_v0917.patch.gz.b64')
    patch=gzip.decompress(base64.b64decode(patch_b64.read_text(encoding='ascii')))
    actual=hashlib.sha256(patch).hexdigest()
    if actual!=PATCH_SHA: raise SystemExit(f'v0.9.17 patch SHA mismatch: {actual} != {PATCH_SHA}')
    with tempfile.NamedTemporaryFile(prefix='task20-d2j-v0917-',suffix='.patch',delete=False) as handle:
        handle.write(patch); patch_path=Path(handle.name)
    try:
        check=subprocess.run(['git','apply','--check',str(patch_path)],cwd=root,text=True,capture_output=True)
        if check.returncode!=0: raise SystemExit(f'v0.9.17 patch precondition failed:\n{check.stdout}{check.stderr}')
        run=subprocess.run(['git','apply',str(patch_path)],cwd=root,text=True,capture_output=True)
        if run.returncode!=0: raise SystemExit(f'v0.9.17 patch apply failed:\n{run.stdout}{run.stderr}')
    finally: patch_path.unlink(missing_ok=True)
def main() -> int:
    if len(sys.argv)!=3: raise SystemExit('Usage: task20_d2j_build_canonical_v0917.py <v0.9.16-app-root> <output-zip>')
    src=Path(sys.argv[1]).resolve(); out=Path(sys.argv[2]).resolve()
    if 'version: 0.9.16+34' not in (src/'pubspec.yaml').read_text(encoding='utf-8'): raise SystemExit('requires canonical v0.9.16 / 0.9.16+34')
    with tempfile.TemporaryDirectory(prefix='task20-d2j-v0917-') as td:
        root=Path(td)/'app'; shutil.copytree(src,root); apply(root)
        if 'version: 0.9.17+35' not in (root/'pubspec.yaml').read_text(encoding='utf-8'): raise SystemExit('v0.9.17 patch did not set app version')
        fs=files(root); mf=[x for x in (root/'FILE_MANIFEST.txt').read_text(encoding='utf-8').splitlines() if x]
        if mf!=fs: raise SystemExit('FILE_MANIFEST mismatch')
        if out.exists(): out.unlink()
        with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
            for rel in fs:
                p=root/rel; i=zipfile.ZipInfo(rel,date_time=(2020,1,1,0,0,0)); i.create_system=3
                mode=0o755 if p.stat().st_mode&stat.S_IXUSR else 0o644; i.external_attr=(stat.S_IFREG|mode)<<16; i.compress_type=zipfile.ZIP_DEFLATED; i.flag_bits|=0x800
                z.writestr(i,p.read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    actual=hashlib.sha256(out.read_bytes()).hexdigest()
    if actual!=EXPECTED: raise SystemExit(f'ZIP SHA mismatch: {actual} != {EXPECTED}')
    print(f'Task20-D2J canonical package PASS: {out} sha256={actual}')
    return 0
if __name__=='__main__': raise SystemExit(main())
