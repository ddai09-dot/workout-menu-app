#!/usr/bin/env python3
from __future__ import annotations
import hashlib, shutil, stat, sys, tempfile, zipfile
from pathlib import Path
EXPECTED='a1a2c89d73324a72d10a1d9b8a50bc896cf358f71a7c5dc485b8c3bd4faeb2a3'
EXCLUDED={'build','.dart_tool'}

def rep(p: Path, old: str, new: str, label: str) -> None:
    text=p.read_text(encoding='utf-8'); count=text.count(old)
    if count!=1: raise SystemExit(f'{label} replacement count mismatch: {count}')
    p.write_text(text.replace(old,new,1),encoding='utf-8')

def files(root: Path):
    return sorted(p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.relative_to(root).parts[0] not in EXCLUDED and '__pycache__' not in p.relative_to(root).parts)

def apply(root: Path) -> None:
    rep(root/'pubspec.yaml','version: 0.9.11+29','version: 0.9.12+30','version')
    p=root/'lib/features/weekly_planner/presentation/steps/weekly_planner_steps.dart'
    old="""              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: day.durationMin,
                      decoration: const InputDecoration(
                        labelText: '時間',
                        border: OutlineInputBorder(),
                      ),
                      items: WeeklyScheduleStep.durations
                          .map(
                            (int value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text(value == 120 ? '90分以上' : '$value分'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: onDurationChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: locations.any((value) => value.id == day.locationId)
                          ? day.locationId
                          : null,
                      decoration: const InputDecoration(
                        labelText: '場所',
                        border: OutlineInputBorder(),
                      ),
                      items: locations
                          .map(
                            (PlannerLocationChoice value) => DropdownMenuItem<String>(
                              value: value.id,
                              child: Text(value.name, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: onLocationChanged,
                    ),
                  ),
                ],
              ),"""
    new="""              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final textScaler = MediaQuery.textScalerOf(context);
                  final stackFields =
                      constraints.maxWidth < 280 || textScaler.scale(16) > 20;

                  final durationField = DropdownButtonFormField<int>(
                    initialValue: day.durationMin,
                    decoration: const InputDecoration(
                      labelText: '時間',
                      border: OutlineInputBorder(),
                    ),
                    items: WeeklyScheduleStep.durations
                        .map(
                          (int value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text(value == 120 ? '90分以上' : '$value分'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onDurationChanged,
                  );
                  final locationField = DropdownButtonFormField<String>(
                    initialValue: locations.any((value) => value.id == day.locationId)
                        ? day.locationId
                        : null,
                    decoration: const InputDecoration(
                      labelText: '場所',
                      border: OutlineInputBorder(),
                    ),
                    items: locations
                        .map(
                          (PlannerLocationChoice value) => DropdownMenuItem<String>(
                            value: value.id,
                            child: Text(value.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onLocationChanged,
                  );

                  if (stackFields) {
                    return Column(
                      children: <Widget>[
                        durationField,
                        const SizedBox(height: 12),
                        locationField,
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Expanded(child: durationField),
                      const SizedBox(width: 12),
                      Expanded(child: locationField),
                    ],
                  );
                },
              ),"""
    rep(p,old,new,'weekly schedule responsive fields')

    p=root/'README.md'
    t=p.read_text(encoding='utf-8')
    if t.count('実装基盤 v0.9.11')!=1 or t.count('アプリ版：`0.9.11+29`')!=1:
        raise SystemExit('README parent markers mismatch')
    t=t.replace('実装基盤 v0.9.11','実装基盤 v0.9.12',1).replace('アプリ版：`0.9.11+29`','アプリ版：`0.9.12+30`',1)
    section="""
## v0.9.12の変更

- Task20-D2J #22で、iPhone SE（3rd generation）＋`accessibility-extra-large`の「今週の予定」画面に74pxの横方向RenderFlex overflowを再現し、予定入力画面が最初の失敗境界であることを確定。
- 利用可能日の「時間」「場所」入力は標準文字／十分な幅では従来どおり横2列を維持し、拡大文字または狭幅時だけ縦積みに切り替える。
- 親はv0.9.11。Home TodayAction／Menu空状態の修正、D2I修正、56件test、Schema v9、Migration、Seed、assetsは維持。
"""
    if '## v0.9.12の変更' in t: raise SystemExit('README v0.9.12 already present')
    p.write_text(t+section,encoding='utf-8')

    p=root/'docs/VERSION_MATRIX.md'
    t=p.read_text(encoding='utf-8')
    if t.count('現在のプロジェクト版：`0.9.11+29`')!=1: raise SystemExit('matrix parent version mismatch')
    t=t.replace('現在のプロジェクト版：`0.9.11+29`','現在のプロジェクト版：`0.9.12+30`',1)
    row='- v0.9.12：Task20-D2J Dynamic Type schedule layout fix（時間／場所のresponsive stacking）\n'
    if row.strip() in t: raise SystemExit('matrix v0.9.12 already present')
    p.write_text(t+row,encoding='utf-8')

    p=root/'docs/weekly_algorithm_traceability_verification.json'
    text=p.read_text(encoding='utf-8')
    text=text.replace('"implementation_version": "0.9.11+29"','"implementation_version": "0.9.12+30"').replace('project version must be 0.9.11+29','project version must be 0.9.12+30')
    p.write_text(text,encoding='utf-8')

    p=root/'tools/verify_project_consistency.py'
    text=p.read_text(encoding='utf-8')
    if text.count('EXPECTED_APP_VERSION = "0.9.11+29"')!=1 or text.count('require(text, "0.9.11", label)')!=1: raise SystemExit('project verifier parent markers mismatch')
    text=text.replace('EXPECTED_APP_VERSION = "0.9.11+29"','EXPECTED_APP_VERSION = "0.9.12+30"',1).replace('require(text, "0.9.11", label)','require(text, "0.9.12", label)',1)
    p.write_text(text,encoding='utf-8')

    p=root/'tools/verify_task20_b_execution_lane.py'
    rep(p,'EXPECTED_APP_VERSION = "0.9.11+29"','EXPECTED_APP_VERSION = "0.9.12+30"','execution lane version')

    p=root/'tools/verify_weekly_algorithm_traceability.py'
    text=p.read_text(encoding='utf-8')
    if text.count('0.9.11+29')!=3: raise SystemExit(f'weekly verifier parent version count mismatch: {text.count("0.9.11+29")}')
    p.write_text(text.replace('0.9.11+29','0.9.12+30'),encoding='utf-8')

def main() -> int:
    if len(sys.argv)!=3: raise SystemExit('Usage: task20_d2j_build_canonical_v0912.py <v0.9.11-app-root> <output-zip>')
    src=Path(sys.argv[1]).resolve(); out=Path(sys.argv[2]).resolve()
    if 'version: 0.9.11+29' not in (src/'pubspec.yaml').read_text(encoding='utf-8'): raise SystemExit('requires canonical v0.9.11')
    with tempfile.TemporaryDirectory(prefix='task20-d2j-v0912-') as td:
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
    if actual!=EXPECTED: raise SystemExit(f'ZIP SHA mismatch: {actual} != {EXPECTED}')
    print(f'Task20-D2J canonical package PASS: {out} sha256={actual}')
    return 0
if __name__=='__main__': raise SystemExit(main())