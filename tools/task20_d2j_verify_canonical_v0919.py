#!/usr/bin/env python3
from __future__ import annotations
import hashlib,json,sys
from pathlib import Path
R='9ba8d3602ceef5061e9607b8571f7ccf08024007988bd095ebb3d975f7fc31ac'
L='fc41b29ffc12ebea1601cb9f230833521deaf65b6e1edc520f4542f64ca63904'
T='878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5'
S='bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af'
A='cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe'
PARENT_L='28299d8a1c9519594fdafc605406da791ee7bd3c5a1b10b0d793c86e88ed1e65'
EX={'build','.dart_tool'}
def th(root,parts):
 d=hashlib.sha256(); fs=[]
 for part in parts:
  p=root/part; fs.extend(x for x in p.rglob('*') if x.is_file()) if p.is_dir() else fs.append(p)
 for p in sorted(set(fs),key=lambda x:x.relative_to(root).as_posix()):
  rel=p.relative_to(root).as_posix(); d.update(rel.encode()); d.update(b'\0'); d.update(p.read_bytes()); d.update(b'\0')
 return d.hexdigest()
def main():
 if len(sys.argv)!=2: raise SystemExit('Usage: task20_d2j_verify_canonical_v0919.py <app-root>')
 root=Path(sys.argv[1]).resolve(); pub=(root/'pubspec.yaml').read_text(); readme=(root/'README.md').read_text(); matrix=(root/'docs/VERSION_MATRIX.md').read_text(); decision=(root/'docs/DECISION_LOG.md').read_text(); source=(root/'lib/features/onboarding/presentation/steps/onboarding_steps.dart').read_text()
 for needle,text in [('version: 0.9.19+37',pub),('実装基盤 v0.9.19',readme),('現在のプロジェクト版：`0.9.19+37`',matrix),('| 0.9.19 |',matrix),('D-027',decision),('ニックネーム（必須）',decision)]:
  if needle not in text: raise SystemExit(f'Missing {needle}')
 external="""        Text(\n          'ニックネーム（必須）',\n          style: Theme.of(context).textTheme.titleSmall,\n        ),\n        const SizedBox(height: 8),\n        TextFormField("""
 if external not in source: raise SystemExit('nickname required label is not external/wrappable before TextFormField')
 nickname_block=source[source.index("key: ValueKey<String>('nickname-"):source.index("const SizedBox(height: 16)",source.index("key: ValueKey<String>('nickname-"))]
 if "labelText: 'ニックネーム（必須）'" in nickname_block: raise SystemExit('nickname floating label truncation source remains')
 if "hintText: '例：だいすけ'" not in nickname_block or 'maxLength: 30' not in nickname_block: raise SystemExit('nickname input contract changed unexpectedly')
 manifest=[x for x in (root/'FILE_MANIFEST.txt').read_text().splitlines() if x]; actual=sorted(p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.relative_to(root).parts[0] not in EX and '__pycache__' not in p.relative_to(root).parts)
 if manifest!=actual: raise SystemExit('FILE_MANIFEST mismatch')
 hashes={'runtime':th(root,['lib','test']),'product_lib':th(root,['lib']),'tests':th(root,['test']),'schema':th(root,['docs/schema_v9.sqlite.sql','docs/migrations','lib/core/database/schema']),'assets':th(root,['assets'])}; expected={'runtime':R,'product_lib':L,'tests':T,'schema':S,'assets':A}
 if hashes!=expected: raise SystemExit(f'tree mismatch: {hashes}')
 if hashes['product_lib']==PARENT_L: raise SystemExit('v0.9.19 must contain the intended product UI change')
 print(json.dumps({'status':'PASS','canonical_package':'implementation-v0.9.19.zip','app_version':'0.9.19+37','parent_canonical_version':'0.9.18+36','expected_flutter_test_count':56,'schema_version':9,'schema_table_count':75,'tree_hashes':hashes,'product_lib_changed_from_v0_9_18':True,'tests_changed_from_v0_9_18':False,'schema_changed_from_v0_9_18':False,'assets_changed_from_v0_9_18':False,'fix':'move required nickname label outside outlined input so enlarged text can wrap without floating-label truncation','d2j_acceptance_status':'PENDING_EXACT_CURRENT_HEAD_CI_AND_ARTIFACT_AUDIT','task20_d2_fully_verified':False},sort_keys=True)); return 0
if __name__=='__main__': raise SystemExit(main())
