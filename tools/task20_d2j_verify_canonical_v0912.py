#!/usr/bin/env python3
from __future__ import annotations
import hashlib,json,sys
from pathlib import Path
R='bbae98d2221ecfd912f14cc0beec8b28a5f568743463acb711ce3439011d9168'; L='e5cb6241453f8792036ae52425ebc62a9f91e61f9e08b3b2afa77dd625404fc0'; T='878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5'; S='bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af'; A='cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe'; W='d721ebdf5294ef02a550dff7936a19c9ea979502e9e927bbfd4b3951f8f964a7'; EX={'build','.dart_tool'}
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
    if len(sys.argv)!=2: raise SystemExit('Usage: task20_d2j_verify_canonical_v0912.py <app-root>')
    root=Path(sys.argv[1]).resolve(); pub=(root/'pubspec.yaml').read_text(encoding='utf-8'); wp=root/'lib/features/weekly_planner/presentation/steps/weekly_planner_steps.dart'; weekly=wp.read_text(encoding='utf-8'); manifest=(root/'FILE_MANIFEST.txt').read_text(encoding='utf-8')
    req(pub,'version: 0.9.12+30\n','version'); req(weekly,'final stackFields =','responsive stack gate'); req(weekly,'constraints.maxWidth < 280 || textScaler.scale(16) > 20','responsive stack condition'); req(weekly,'Expanded(child: durationField)','horizontal duration field'); req(weekly,'locationField','location field'); req(weekly,'const SizedBox(height: 12)','vertical gap')
    if hashlib.sha256(wp.read_bytes()).hexdigest()!=W: raise SystemExit('Weekly planner SHA mismatch')
    req((root/'README.md').read_text(encoding='utf-8'),'実装基盤 v0.9.12','README version'); req((root/'docs/VERSION_MATRIX.md').read_text(encoding='utf-8'),'現在のプロジェクト版：`0.9.12+30`','matrix version')
    actual_files=sorted(p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.relative_to(root).parts[0] not in EX and '__pycache__' not in p.relative_to(root).parts); mf=[x for x in manifest.splitlines() if x]
    if mf!=actual_files: raise SystemExit('FILE_MANIFEST mismatch')
    runtime,nr=th(root,['lib','test']); lib,nl=th(root,['lib']); tests,nt=th(root,['test']); schema,ns=th(root,['docs/schema_v9.sqlite.sql','docs/migrations','lib/core/database/schema']); assets,na=th(root,['assets']); actual={'runtime':runtime,'product_lib':lib,'tests':tests,'schema':schema,'assets':assets}; expected={'runtime':R,'product_lib':L,'tests':T,'schema':S,'assets':A}
    for k,v in expected.items():
        if actual[k]!=v: raise SystemExit(f'{k} tree mismatch: {actual[k]} != {v}')
    result={'status':'PASS','task':'Task20-D2J Dynamic Type schedule layout fix','canonical_package':'implementation-v0.9.12.zip','app_version':'0.9.12+30','accepted_parent_version':'0.9.11+29','expected_flutter_test_count':56,'schema_version':9,'schema_table_count':75,'schema_changed_from_v0_9_11':False,'assets_changed_from_v0_9_11':False,'canonical_file_count':len(actual_files),'weekly_planner_sha256':W,'tree_hashes':actual,'tree_file_counts':{'runtime':nr,'product_lib':nl,'tests':nt,'schema':ns,'assets':na},'d2j_acceptance_status':'PENDING_CURRENT_HEAD_CI_AND_ARTIFACT_AUDIT','task20_d2_fully_verified':False,'physical_device_verified':False,'native_accessibility_verified':False}; out=root/'build/task20_b_logs/flutter'; out.mkdir(parents=True,exist_ok=True); (out/'task20_d2j_canonical_package_v0912.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,sort_keys=True)+'\n',encoding='utf-8'); print(json.dumps(result,ensure_ascii=False,sort_keys=True)); return 0
if __name__=='__main__': raise SystemExit(main())