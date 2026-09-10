#!/usr/bin/env python3
from __future__ import annotations
import hashlib,shutil,stat,sys,tempfile,zipfile
from pathlib import Path
EXPECTED='cd0781aa74b6be26aaf990ceb6e01a02064bb2ca0688e56d1bc603a8f95114ca'
EXCLUDED={'build','.dart_tool'}
def rep(p,o,n,label):
 t=p.read_text(encoding='utf-8'); c=t.count(o)
 if c!=1: raise SystemExit(f'{label} replacement count mismatch: {c}')
 p.write_text(t.replace(o,n,1),encoding='utf-8')
def files(root): return sorted(p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.relative_to(root).parts[0] not in EXCLUDED and '__pycache__' not in p.relative_to(root).parts)
def apply(root):
 rep(root/'pubspec.yaml','version: 0.9.10+28','version: 0.9.11+29','version')
 h=root/'lib/features/home/presentation/home_page.dart'
 rep(h,'data: (TodayAction value) => _TodayActionCard(action: value),','data: (TodayAction value) => SingleChildScrollView(\n              child: _TodayActionCard(action: value),\n            ),','Home scroll')
 rep(h,'        child: Column(\n          crossAxisAlignment: CrossAxisAlignment.stretch,','        child: Column(\n          mainAxisSize: MainAxisSize.min,\n          crossAxisAlignment: CrossAxisAlignment.stretch,','Home axis')
 rep(h,'            const Spacer(),','            const SizedBox(height: 24),','Home spacing')
 m=root/'lib/features/menu/presentation/menu_page.dart'
 old="""    return Center(\n      child: Padding(\n        padding: const EdgeInsets.all(24),\n        child: Column(\n          mainAxisSize: MainAxisSize.min,\n          children: <Widget>[\n            const Icon(Icons.calendar_month_outlined, size: 56),\n            const SizedBox(height: 16),\n            Text(\n              hasProgress ? '週間メニューの作成途中です' : '今週のメニューは未作成です',\n              style: Theme.of(context).textTheme.titleLarge,\n              textAlign: TextAlign.center,\n            ),\n            const SizedBox(height: 8),\n            Text(\n              hasProgress\n                  ? '入力内容は保存されています。前回の続きから再開できます。'\n                  : '今週の予定・体調・前週の結果を確認して、実施できるメニューを作成します。',\n              textAlign: TextAlign.center,\n            ),\n            const SizedBox(height: 24),\n            FilledButton(\n              onPressed: () => context.go('/menu/weekly-planner'),\n              child: Text(hasProgress ? '作成の続きをする' : '今週のメニューを作成する'),\n            ),\n          ],\n        ),\n      ),\n    );"""
 new="""    return LayoutBuilder(\n      builder: (BuildContext context, BoxConstraints constraints) {\n        return SingleChildScrollView(\n          child: ConstrainedBox(\n            constraints: BoxConstraints(minHeight: constraints.maxHeight),\n            child: Center(\n              child: Padding(\n                padding: const EdgeInsets.all(24),\n                child: Column(\n                  mainAxisSize: MainAxisSize.min,\n                  children: <Widget>[\n                    const Icon(Icons.calendar_month_outlined, size: 56),\n                    const SizedBox(height: 16),\n                    Text(\n                      hasProgress\n                          ? '週間メニューの作成途中です'\n                          : '今週のメニューは未作成です',\n                      style: Theme.of(context).textTheme.titleLarge,\n                      textAlign: TextAlign.center,\n                    ),\n                    const SizedBox(height: 8),\n                    Text(\n                      hasProgress\n                          ? '入力内容は保存されています。前回の続きから再開できます。'\n                          : '今週の予定・体調・前週の結果を確認して、実施できるメニューを作成します。',\n                      textAlign: TextAlign.center,\n                    ),\n                    const SizedBox(height: 24),\n                    FilledButton(\n                      onPressed: () => context.go('/menu/weekly-planner'),\n                      child: Text(\n                        hasProgress ? '作成の続きをする' : '今週のメニューを作成する',\n                      ),\n                    ),\n                  ],\n                ),\n              ),\n            ),\n          ),\n        );\n      },\n    );"""
 rep(m,old,new,'Menu empty state')
 p=root/'README.md'; t=p.read_text(encoding='utf-8').replace('実装基盤 v0.9.10','実装基盤 v0.9.11',1).replace('アプリ版：`0.9.10+28`','アプリ版：`0.9.11+29`',1); t+='\n\n## v0.9.11の変更\n\n- Task20-D2Jで検出したHome TodayActionとMenu空状態のDynamic Type overflowを、必要時のみ縦スクロール可能にして是正。\n- 親はTask20-D2I受入済みv0.9.10。Schema v9、Migration、Seed、assets、D2I修正と56件testは維持。\n'; p.write_text(t,encoding='utf-8')
 p=root/'docs/VERSION_MATRIX.md'; t=p.read_text(encoding='utf-8').replace('現在のプロジェクト版：`0.9.10+28`','現在のプロジェクト版：`0.9.11+29`',1)+'\n- v0.9.11：Task20-D2J Dynamic Type layout fix（Home TodayAction / Menu empty state）\n'; p.write_text(t,encoding='utf-8')
 p=root/'docs/weekly_algorithm_traceability_verification.json'; p.write_text(p.read_text(encoding='utf-8').replace('"implementation_version": "0.9.10+28"','"implementation_version": "0.9.11+29"').replace('project version must be 0.9.10+28','project version must be 0.9.11+29'),encoding='utf-8')
 for rel in ['tools/verify_project_consistency.py','tools/verify_task20_b_execution_lane.py','tools/verify_weekly_algorithm_traceability.py']:
  p=root/rel; p.write_text(p.read_text(encoding='utf-8').replace('0.9.10+28','0.9.11+29').replace('0.9.10','0.9.11'),encoding='utf-8')
def main():
 if len(sys.argv)!=3: raise SystemExit('Usage: task20_d2j_build_canonical_v0911.py <v0.9.10-app-root> <output-zip>')
 src=Path(sys.argv[1]).resolve(); out=Path(sys.argv[2]).resolve()
 if 'version: 0.9.10+28' not in (src/'pubspec.yaml').read_text(encoding='utf-8'): raise SystemExit('requires accepted canonical v0.9.10')
 with tempfile.TemporaryDirectory(prefix='task20-d2j-v0911-') as td:
  root=Path(td)/'app'; shutil.copytree(src,root); apply(root); fs=files(root); mf=[x for x in (root/'FILE_MANIFEST.txt').read_text(encoding='utf-8').splitlines() if x]
  if mf!=fs: raise SystemExit('FILE_MANIFEST mismatch')
  if out.exists(): out.unlink()
  with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
   for rel in fs:
    p=root/rel; i=zipfile.ZipInfo(rel,date_time=(2020,1,1,0,0,0)); i.create_system=3; mode=0o755 if p.stat().st_mode&stat.S_IXUSR else 0o644; i.external_attr=(stat.S_IFREG|mode)<<16; i.compress_type=zipfile.ZIP_DEFLATED; i.flag_bits|=0x800; z.writestr(i,p.read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
 actual=hashlib.sha256(out.read_bytes()).hexdigest()
 if actual!=EXPECTED: raise SystemExit(f'ZIP SHA mismatch: {actual} != {EXPECTED}')
 print(f'Task20-D2J canonical package PASS: {out} sha256={actual}'); return 0
if __name__=='__main__': raise SystemExit(main())