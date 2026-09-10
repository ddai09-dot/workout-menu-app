#!/usr/bin/env python3
from __future__ import annotations
import hashlib,json,sys
from pathlib import Path
R='3eeb5a3357ca1ec2a42f486de1b375312f1baf64bfde1682f1f38b7bc702a71e'; L='6eea4b98f6741cf7e02699cda31b8d2c5e894366e82c2b15f9c8fa287553bfdc'; T='878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5'; S='bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af'; A='cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe'; H='f18059798cba8a49f14b1792950ad70a43a9b3e414411334e70f8f76b2d1f2f7'; M='5d617e30af5743aebe62e8a2947a67f3299d69c23e8b3e0a65cef5dd75cc7639'; EX={'build','.dart_tool'}
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
 if len(sys.argv)!=2: raise SystemExit('Usage: task20_d2j_verify_canonical_v0911.py <app-root>')
 root=Path(sys.argv[1]).resolve(); pub=(root/'pubspec.yaml').read_text(encoding='utf-8'); hp=root/'lib/features/home/presentation/home_page.dart'; mp=root/'lib/features/menu/presentation/menu_page.dart'; home=hp.read_text(encoding='utf-8'); menu=mp.read_text(encoding='utf-8'); manifest=(root/'FILE_MANIFEST.txt').read_text(encoding='utf-8')
 req(pub,'version: 0.9.11+29\n','version'); req(home,'data: (TodayAction value) => SingleChildScrollView(','Home scroll'); req(home,'mainAxisSize: MainAxisSize.min','Home axis'); req(home,'const SizedBox(height: 24)','Home spacing')
 if 'const Spacer()' in home: raise SystemExit('Home still contains Spacer')
 req(menu,'return LayoutBuilder(','Menu LayoutBuilder'); req(menu,'SingleChildScrollView(','Menu scroll'); req(menu,'BoxConstraints(minHeight: constraints.maxHeight)','Menu min height'); req(menu,"'今週のメニューを作成する'",'Menu CTA')
 if hashlib.sha256(hp.read_bytes()).hexdigest()!=H: raise SystemExit('Home SHA mismatch')
 if hashlib.sha256(mp.read_bytes()).hexdigest()!=M: raise SystemExit('Menu SHA mismatch')
 req((root/'README.md').read_text(encoding='utf-8'),'実装基盤 v0.9.11','README version'); req((root/'docs/VERSION_MATRIX.md').read_text(encoding='utf-8'),'現在のプロジェクト版：`0.9.11+29`','matrix version')
 actual_files=sorted(p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.relative_to(root).parts[0] not in EX and '__pycache__' not in p.relative_to(root).parts); mf=[x for x in manifest.splitlines() if x]
 if mf!=actual_files: raise SystemExit('FILE_MANIFEST mismatch')
 runtime,nr=th(root,['lib','test']); lib,nl=th(root,['lib']); tests,nt=th(root,['test']); schema,ns=th(root,['docs/schema_v9.sqlite.sql','docs/migrations','lib/core/database/schema']); assets,na=th(root,['assets']); actual={'runtime':runtime,'product_lib':lib,'tests':tests,'schema':schema,'assets':assets}; expected={'runtime':R,'product_lib':L,'tests':T,'schema':S,'assets':A}
 for k,v in expected.items():
  if actual[k]!=v: raise SystemExit(f'{k} tree mismatch: {actual[k]} != {v}')
 result={'status':'PASS','task':'Task20-D2J Dynamic Type Home/Menu layout fix','canonical_package':'implementation-v0.9.11.zip','app_version':'0.9.11+29','accepted_parent_version':'0.9.10+28','expected_flutter_test_count':56,'schema_version':9,'schema_table_count':75,'schema_changed_from_v0_9_10':False,'assets_changed_from_v0_9_10':False,'canonical_file_count':len(actual_files),'tree_hashes':actual,'tree_file_counts':{'runtime':nr,'product_lib':nl,'tests':nt,'schema':ns,'assets':na},'d2j_acceptance_status':'PENDING_CURRENT_HEAD_CI_AND_ARTIFACT_AUDIT','task20_d2_fully_verified':False,'physical_device_verified':False,'native_accessibility_verified':False}; out=root/'build/task20_b_logs/flutter'; out.mkdir(parents=True,exist_ok=True); (out/'task20_d2j_canonical_package_v0911.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,sort_keys=True)+'\n',encoding='utf-8'); print(json.dumps(result,ensure_ascii=False,sort_keys=True)); return 0
if __name__=='__main__': raise SystemExit(main())