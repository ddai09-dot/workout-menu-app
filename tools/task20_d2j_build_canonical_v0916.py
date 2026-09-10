#!/usr/bin/env python3
from __future__ import annotations
import base64, gzip, hashlib, shutil, stat, subprocess, sys, tempfile, zipfile
from pathlib import Path
EXPECTED='e9e5d5f87eba8bde626bd14f7e2de6535f608edaa5cd1bac84b63b43e4040644'
PATCH_SHA='ea924e0189ed5b5f05a23ed65a119086a5677119f623fd7ad7aa43ae2d36e5f2'
EXCLUDED={'build','.dart_tool'}

def files(root: Path):
    return sorted(
        p.relative_to(root).as_posix()
        for p in root.rglob('*')
        if p.is_file()
        and p.relative_to(root).parts[0] not in EXCLUDED
        and '__pycache__' not in p.relative_to(root).parts
    )

def apply(root: Path) -> None:
    patch_b64=Path(__file__).with_name('task20_d2j_v0916.patch.gz.b64')
    if not patch_b64.exists(): raise SystemExit(f'Missing patch payload: {patch_b64}')
    try:
        patch=gzip.decompress(base64.b64decode(patch_b64.read_text(encoding='ascii')))
    except Exception as exc:
        raise SystemExit(f'Unable to decode v0.9.16 patch: {exc}')
    actual=hashlib.sha256(patch).hexdigest()
    if actual!=PATCH_SHA: raise SystemExit(f'v0.9.16 patch SHA mismatch: {actual} != {PATCH_SHA}')
    with tempfile.NamedTemporaryFile(prefix='task20-d2j-v0916-',suffix='.patch',delete=False) as handle:
        handle.write(patch); patch_path=Path(handle.name)
    try:
        check=subprocess.run(['git','apply','--check',str(patch_path)],cwd=root,text=True,capture_output=True)
        if check.returncode!=0: raise SystemExit(f'v0.9.16 patch precondition failed:\n{check.stdout}{check.stderr}')
        run=subprocess.run(['git','apply',str(patch_path)],cwd=root,text=True,capture_output=True)
        if run.returncode!=0: raise SystemExit(f'v0.9.16 patch apply failed:\n{run.stdout}{run.stderr}')
    finally:
        patch_path.unlink(missing_ok=True)

def main() -> int:
    if len(sys.argv)!=3: raise SystemExit('Usage: task20_d2j_build_canonical_v0916.py <v0.9.15-app-root> <output-zip>')
    src=Path(sys.argv[1]).resolve(); out=Path(sys.argv[2]).resolve()
    if 'version: 0.9.15+33' not in (src/'pubspec.yaml').read_text(encoding='utf-8'):
        raise SystemExit('requires canonical v0.9.15 / 0.9.15+33')
    with tempfile.TemporaryDirectory(prefix='task20-d2j-v0916-') as td:
        root=Path(td)/'app'; shutil.copytree(src,root); apply(root)
        if 'version: 0.9.16+34' not in (root/'pubspec.yaml').read_text(encoding='utf-8'):
            raise SystemExit('v0.9.16 patch did not set app version')
        fs=files(root); mf=[x for x in (root/'FILE_MANIFEST.txt').read_text(encoding='utf-8').splitlines() if x]
        if mf!=fs: raise SystemExit('FILE_MANIFEST mismatch')
        if out.exists(): out.unlink()
        with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
            for rel in fs:
                p=root/rel; i=zipfile.ZipInfo(rel,date_time=(2020,1,1,0,0,0)); i.create_system=3
                mode=0o755 if p.stat().st_mode&stat.S_IXUSR else 0o644
                i.external_attr=(stat.S_IFREG|mode)<<16; i.compress_type=zipfile.ZIP_DEFLATED; i.flag_bits|=0x800
                z.writestr(i,p.read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    actual=hashlib.sha256(out.read_bytes()).hexdigest()
    if actual!=EXPECTED: raise SystemExit(f'ZIP SHA mismatch: {actual} != {EXPECTED}')
    print(f'Task20-D2J canonical package PASS: {out} sha256={actual}')
    return 0
if __name__=='__main__': raise SystemExit(main())
