#!/usr/bin/env python3
from __future__ import annotations
import hashlib,json,sys
from pathlib import Path
R='9fb2b589aed40c043ec94ce0cfce877f723572f36786c4c87fcb4082a970cd69'
L='28299d8a1c9519594fdafc605406da791ee7bd3c5a1b10b0d793c86e88ed1e65'
T='878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5'
S='bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af'
A='cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe'
W='d721ebdf5294ef02a550dff7936a19c9ea979502e9e927bbfd4b3951f8f964a7'
ADJ='ec626105f62872cb2aa90137011442bb8300640818d36b5872026948c2f425e5'
EX={'build','.dart_tool'}
def req(t,v,l):
    if v not in t: raise SystemExit(f'Missing {l}: {v!r}')
def th(root,parts):
    d=hashlib.sha256(); fs=[]
    for part in parts:
        p=root/part
        if p.is_dir(): fs.extend(x for x in p.rglob('*') if x.is_file())
        elif p.is_file(): fs.append(p)
        else: raise SystemExit(f'Missing tree input: {part}')
    u=sorted(set(fs),key=lambda x:x.relative_to(root).as_posix())
    for p in u:
        rel=p.relative_to(root).as_posix(); d.update(rel.encode()); d.update(b'\0'); d.update(p.read_bytes()); d.update(b'\0')
    return d.hexdigest(),len(u)
def main():
    if len(sys.argv)!=2: raise SystemExit('Usage: task20_d2j_verify_canonical_v0915.py <app-root>')
    root=Path(sys.argv[1]).resolve(); pub=(root/'pubspec.yaml').read_text(encoding='utf-8')
    adj=root/'lib/features/workout/presentation/workout_adjustment_page.dart'; at=adj.read_text(encoding='utf-8')
    wp=root/'lib/features/weekly_planner/presentation/steps/weekly_planner_steps.dart'; weekly=wp.read_text(encoding='utf-8')
    manifest=(root/'FILE_MANIFEST.txt').read_text(encoding='utf-8')
    req(pub,'version: 0.9.15+33\n','version')
    if at.count('isExpanded: true,') != 2: raise SystemExit(f'Expected exactly two expanded pain-sheet dropdowns, got {at.count("isExpanded: true,")}')
    req(at,"DropdownButtonFormField<WorkoutBodyPartChoice>(\n                    isExpanded: true,",'body-part expanded dropdown')
    req(at,"DropdownButtonFormField<String>(\n                    isExpanded: true,",'action expanded dropdown')
    if hashlib.sha256(adj.read_bytes()).hexdigest()!=ADJ: raise SystemExit('Workout adjustment SHA mismatch')
    req(weekly,'constraints.maxWidth < 280 || textScaler.scale(16) > 20','v0.9.12 weekly responsive fix retained')
    if hashlib.sha256(wp.read_bytes()).hexdigest()!=W: raise SystemExit('Weekly planner SHA mismatch')
    readme=(root/'README.md').read_text(encoding='utf-8')
    req(readme,'実装基盤 v0.9.15','README version')
    req(readme,'v0.9.14','immutable local-only predecessor history')
    matrix=(root/'docs/VERSION_MATRIX.md').read_text(encoding='utf-8')
    req(matrix,'現在のプロジェクト版：`0.9.15+33`','matrix version')
    req(matrix,'| 0.9.15 |','matrix v0.9.15 history')
    exec_lane=(root/'tools/verify_task20_b_execution_lane.py').read_text(encoding='utf-8')
    req(exec_lane,'"task20_d2i": "AUTOMATED_PASS_DEFINED_GITHUB_HOSTED_IOS_SIMULATOR_SCOPE"','D2I accepted scope status')
    if 'PENDING_V0910_CURRENT_HEAD_REVALIDATION' in exec_lane or 'D2I_PENDING' in exec_lane: raise SystemExit('Stale D2I pending status remains')
    if '48/48' in readme and 'v0.9.2' not in readme: raise SystemExit('Unscoped stale 48/48 current-test wording remains')
    actual_files=sorted(p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.relative_to(root).parts[0] not in EX and '__pycache__' not in p.relative_to(root).parts); mf=[x for x in manifest.splitlines() if x]
    if mf!=actual_files: raise SystemExit('FILE_MANIFEST mismatch')
    runtime,nr=th(root,['lib','test']); lib,nl=th(root,['lib']); tests,nt=th(root,['test']); schema,ns=th(root,['docs/schema_v9.sqlite.sql','docs/migrations','lib/core/database/schema']); assets,na=th(root,['assets']); actual={'runtime':runtime,'product_lib':lib,'tests':tests,'schema':schema,'assets':assets}; expected={'runtime':R,'product_lib':L,'tests':T,'schema':S,'assets':A}
    for k,v in expected.items():
        if actual[k]!=v: raise SystemExit(f'{k} tree mismatch: {actual[k]} != {v}')
    result={'status':'PASS','task':'Task20-D2J documentation/evidence consistency + harness baseline','canonical_package':'implementation-v0.9.15.zip','app_version':'0.9.15+33','parent_canonical_version':'0.9.13+31','skipped_version_history':'v0.9.14+32 local-only immutable candidate','expected_flutter_test_count':56,'schema_version':9,'schema_table_count':75,'product_lib_changed_from_v0_9_13':False,'tests_changed_from_v0_9_13':False,'schema_changed_from_v0_9_13':False,'assets_changed_from_v0_9_13':False,'canonical_file_count':len(actual_files),'weekly_planner_sha256':W,'workout_adjustment_sha256':ADJ,'tree_hashes':actual,'tree_file_counts':{'runtime':nr,'product_lib':nl,'tests':nt,'schema':ns,'assets':na},'d2j_acceptance_status':'PENDING_EXACT_CURRENT_HEAD_CI_AND_ARTIFACT_AUDIT','task20_d2_fully_verified':False,'physical_device_verified':False,'native_accessibility_verified':False}
    print(json.dumps(result,ensure_ascii=False,sort_keys=True)); return 0
if __name__=='__main__': raise SystemExit(main())
