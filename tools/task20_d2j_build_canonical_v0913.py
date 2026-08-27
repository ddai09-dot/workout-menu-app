#!/usr/bin/env python3
from __future__ import annotations
import hashlib, shutil, stat, sys, tempfile, zipfile
from pathlib import Path
EXPECTED='d6b0016b669bde9091294c52d7c138ce964d90515b3dd42320bac784f3eef586'
EXCLUDED={'build','.dart_tool'}

def rep(p: Path, old: str, new: str, label: str) -> None:
    text=p.read_text(encoding='utf-8'); count=text.count(old)
    if count!=1: raise SystemExit(f'{label} replacement count mismatch: {count}')
    p.write_text(text.replace(old,new,1),encoding='utf-8')

def files(root: Path):
    return sorted(p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.relative_to(root).parts[0] not in EXCLUDED and '__pycache__' not in p.relative_to(root).parts)

def apply(root: Path) -> None:
    rep(root/'pubspec.yaml','version: 0.9.12+30','version: 0.9.13+31','version')

    p=root/'lib/features/workout/presentation/workout_adjustment_page.dart'
    text=p.read_text(encoding='utf-8')
    body_old="""                  DropdownButtonFormField<WorkoutBodyPartChoice>(
                    initialValue: bodyPart,"""
    body_new="""                  DropdownButtonFormField<WorkoutBodyPartChoice>(
                    isExpanded: true,
                    initialValue: bodyPart,"""
    action_old="""                  DropdownButtonFormField<String>(
                    initialValue: actionCode,"""
    action_new="""                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: actionCode,"""
    if text.count(body_old)!=1 or text.count(action_old)!=1:
        raise SystemExit('workout adjustment dropdown parent markers mismatch')
    p.write_text(text.replace(body_old,body_new,1).replace(action_old,action_new,1),encoding='utf-8')

    p=root/'README.md'; t=p.read_text(encoding='utf-8')
    if t.count('実装基盤 v0.9.12')!=1 or t.count('アプリ版：`0.9.12+30`')!=1:
        raise SystemExit('README parent markers mismatch')
    t=t.replace('実装基盤 v0.9.12','実装基盤 v0.9.13',1).replace('アプリ版：`0.9.12+30`','アプリ版：`0.9.13+31`',1)
    section="""

## v0.9.13の変更

- Task20-D2J #33で、iPhone SE（3rd generation）＋`accessibility-extra-large`のD2E調整導線に39pxの横方向RenderFlex overflowを検出。
- 調整画面の痛み・違和感追加シートにある「部位」「対応」Dropdownを利用可能幅へ展開し、長い選択肢がボタン幅を押し広げないようにする。
- 親はv0.9.12。週間予定のresponsive stacking、Home／Menu修正、D2I修正、56件test、Schema v9、Migration、Seed、assetsは維持。
- v0.9.12に残っていたTask20-B static evidenceのD2I `PENDING`表記を、受入済みのdefined GitHub-hosted iOS Simulator scope `AUTOMATED PASS`へ訂正する（製品挙動の変更なし）。
"""
    if '## v0.9.13の変更' in t: raise SystemExit('README v0.9.13 already present')
    (root/'README.md').write_text(t+section,encoding='utf-8')

    p=root/'docs/VERSION_MATRIX.md'; t=p.read_text(encoding='utf-8')
    if t.count('現在のプロジェクト版：`0.9.12+30`')!=1: raise SystemExit('matrix parent version mismatch')
    t=t.replace('現在のプロジェクト版：`0.9.12+30`','現在のプロジェクト版：`0.9.13+31`',1)
    row='- v0.9.13：Task20-D2J workout-adjustment dropdown width fix（pain sheet expanded fields）\n'
    if row.strip() in t: raise SystemExit('matrix v0.9.13 already present')
    p.write_text(t+row,encoding='utf-8')

    p=root/'docs/weekly_algorithm_traceability_verification.json'; t=p.read_text(encoding='utf-8')
    if t.count('0.9.12+30')!=2: raise SystemExit(f'traceability parent version count mismatch: {t.count("0.9.12+30")}')
    p.write_text(t.replace('0.9.12+30','0.9.13+31'),encoding='utf-8')

    rep(root/'tools/verify_project_consistency.py','EXPECTED_APP_VERSION = "0.9.12+30"','EXPECTED_APP_VERSION = "0.9.13+31"','project verifier version')
    rep(root/'tools/verify_task20_b_execution_lane.py','EXPECTED_APP_VERSION = "0.9.12+30"','EXPECTED_APP_VERSION = "0.9.13+31"','execution lane version')
    p=root/'tools/verify_weekly_algorithm_traceability.py'; t=p.read_text(encoding='utf-8')
    if t.count('0.9.12+30')!=3: raise SystemExit(f'weekly verifier parent version count mismatch: {t.count("0.9.12+30")}')
    p.write_text(t.replace('0.9.12+30','0.9.13+31'),encoding='utf-8')

    # Correct stale D2I status carried forward in v0.9.12 after formal D2I acceptance.
    p=root/'tools/verify_task20_b_execution_lane.py'; t=p.read_text(encoding='utf-8')
    old='"task20_d2i": "PENDING_V0910_CURRENT_HEAD_REVALIDATION"'
    new='"task20_d2i": "AUTOMATED_PASS_DEFINED_GITHUB_HOSTED_IOS_SIMULATOR_SCOPE"'
    old_status='"acceptance_status": "PARTIALLY_VERIFIED_D2A_D2C_D2D_D2E_D2F_D2G_D2H_SCOPE_D2I_PENDING"'
    new_status='"acceptance_status": "PARTIALLY_VERIFIED_D2A_D2C_D2D_D2E_D2F_D2G_D2H_SCOPE_D2I_DEFINED_GITHUB_HOSTED_IOS_SIMULATOR_SCOPE_PASS"'
    if t.count(old)!=1 or t.count(old_status)!=1: raise SystemExit('D2I stale-status markers mismatch')
    p.write_text(t.replace(old,new,1).replace(old_status,new_status,1),encoding='utf-8')

def main() -> int:
    if len(sys.argv)!=3: raise SystemExit('Usage: task20_d2j_build_canonical_v0913.py <v0.9.12-app-root> <output-zip>')
    src=Path(sys.argv[1]).resolve(); out=Path(sys.argv[2]).resolve()
    if 'version: 0.9.12+30' not in (src/'pubspec.yaml').read_text(encoding='utf-8'): raise SystemExit('requires canonical v0.9.12')
    with tempfile.TemporaryDirectory(prefix='task20-d2j-v0913-') as td:
        root=Path(td)/'app'; shutil.copytree(src,root); apply(root)
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
    if EXPECTED and actual!=EXPECTED: raise SystemExit(f'ZIP SHA mismatch: {actual} != {EXPECTED}')
    print(f'Task20-D2J canonical package PASS: {out} sha256={actual}')
    return 0
if __name__=='__main__': raise SystemExit(main())