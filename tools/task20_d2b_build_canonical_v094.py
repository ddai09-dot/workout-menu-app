#!/usr/bin/env python3
"""Build Task20-D2B canonical v0.9.4 from canonical v0.9.3."""
from __future__ import annotations
import hashlib, shutil, zipfile
from pathlib import Path

EXPECTED_SHA256 = '06815b331f1e21f3bb4f4c6d856b0cb616bd5f651b39706289770593d71d71c1'
EXCLUDED_TOP_LEVEL = {'build', '.dart_tool'}
if len(__import__('sys').argv) != 3:
    raise SystemExit('Usage: task20_d2b_build_canonical_v094.py <v0.9.3-root> <output-zip>')
ROOT = Path(__import__('sys').argv[1]).resolve()
OUT = Path(__import__('sys').argv[2]).resolve()
pubspec = ROOT / 'pubspec.yaml'
if not pubspec.is_file() or 'version: 0.9.3+21\n' not in pubspec.read_text(encoding='utf-8'):
    raise SystemExit('Input is not the v0.9.3+21 canonical package')

def replace_once(rel, old, new):
    p=ROOT/rel
    t=p.read_text(encoding='utf-8')
    c=t.count(old)
    if c!=1: raise SystemExit(f'{rel}: expected once, found {c}: {old[:80]!r}')
    p.write_text(t.replace(old,new,1), encoding='utf-8')

def append_once(rel, marker, content):
    p=ROOT/rel; t=p.read_text(encoding='utf-8')
    if marker in t: raise SystemExit(f'{rel}: marker exists')
    p.write_text(t.rstrip()+"\n\n"+content.strip()+"\n", encoding='utf-8')

# Version promotion: source package changed, behavior/schema unchanged.
replace_once('pubspec.yaml','version: 0.9.3+21\n','version: 0.9.4+22\n')
for rel in ['tools/verify_task20_b_execution_lane.py','tools/verify_project_consistency.py']:
    replace_once(rel,'0.9.3+21','0.9.4+22')
replace_once('tools/verify_project_consistency.py','require(text, "0.9.3", label)','require(text, "0.9.4", label)')
for rel in ['tools/verify_weekly_algorithm_traceability.py','docs/weekly_algorithm_traceability_verification.json']:
    p=ROOT/rel; t=p.read_text(encoding='utf-8')
    t=t.replace('0.9.3+21','0.9.4+22')
    p.write_text(t,encoding='utf-8')

replace_once('README.md','# 筋トレメニュー提案アプリ 実装基盤 v0.9.3\n','# 筋トレメニュー提案アプリ 実装基盤 v0.9.4\n')
replace_once('README.md','- アプリ版：`0.9.3+21`\n','- アプリ版：`0.9.4+22`\n')
replace_once('README.md',
'''この成果物は**配布可能な完成アプリではありません**。Flutter共通CI、Flutter Test 48件、strict Analyzer、iOS Simulator debug buildは自動検証済みです。一方、Simulatorでの主要導線操作、端末内データ初期化の手動確認、iPhone実機、アクセシビリティは未確認です。MVPは端末内で完結する主要機能へ固定し、アカウント同期、AI相談、ネイティブ通知は通常UIとルートから除外しました。Schemaと接続境界は将来再開用として保持しています。\n''',
'''この成果物は**配布可能な完成アプリではありません**。Flutter共通CI、Flutter Test 48件、strict Analyzer、iOS Simulator debug build、Task20-D1起動スモーク、およびTask20-D2Aの自動UI受入（D2-01、D2-03、D2-09、D2-10の一部）は検証済みです。一方、週間メニュー、トレーニング実施、記録・進行、全設定、各状態での強制終了・再起動、全画面レイアウト、文字拡大、iPhone実機、VoiceOver等は未確認です。MVPは端末内で完結する主要機能へ固定し、アカウント同期、AI相談、ネイティブ通知は通常UIとルートから除外しました。Schemaと接続境界は将来再開用として保持しています。\n''')
replace_once('README.md','- マイページ通常設定編集：7カテゴリのローカル編集を実装済み。Flutter／iOS統合検証前\n','- マイページ通常設定編集：7カテゴリのローカル編集を実装済み。Flutter共通CIとiOS Simulator buildはPASS。手動編集・保存・破棄確認は未実施\n')
replace_once('README.md',
'''- main CI：Flutter run #42、iOS run #29\n\n未確認：\n\n- Simulator上の初期登録、週間生成、実施、記録、設定、データ初期化\n- 強制終了／再起動、画面サイズ、文字拡大\n''',
'''- v0.9.2最終main CI：Flutter run #48、iOS run #35 PASS\n- v0.9.3 PR #10最終検証：Flutter run #69、iOS run #56 PASS\n- Task20-D1：iPhone 16 Pro／iPhone SE（第3世代）の起動スモーク PASS\n- Task20-D2A：両SimulatorでD2-01、D2-03、D2-09、D2-10の一部をPASS。5時点×2端末の証跡PNGを確認\n- v0.9.3 main反映後CI：本成果物作成時点では独立確認記録なし\n\n未確認：\n\n- D2-02、D2-04〜D2-08、D2-11\n- D2-10の全画面・キーボード・横スクロール等の網羅確認\n- 初期化後のOSレベル強制終了・再起動、旧データ非復活、匿名ID差分の手動確認\n''')
replace_once('README.md',
'''## タスク20-Bの現在地\n\n- 自動検証部分：完了\n- Task20-B全体：未完了\n- 残件：手動Simulator、データ初期化操作、iPhone実機、アクセシビリティ\n''',
'''## タスク20-B／D2の現在地\n\n- Flutter・iOS自動検証：完了\n- Task20-D1起動スモーク：完了\n- Task20-D2A自動UI受入：対象範囲を完了\n- Task20-D2全体：未完了\n- Task20-B全体：未完了\n- 残件：D2-02、D2-04〜D2-08、D2-10未網羅部分、D2-11、iPhone実機、VoiceOver等のnative accessibility\n''')
append_once('README.md','- v0.9.4：成果物間の状態表現を是正',
'''## v0.9.4の変更\n\n- v0.9.3のアプリ挙動とSchemaを維持\n- README、Version Matrix、Roadmap、Task20-A／B／D2A文書の状態表現を同期\n- Task20-D2A完了レポートを追加\n- 「D2A対象範囲の完了」と「Task20-D2全体の未完了」を明確に分離\n- 古いCI番号、Flutter未実行表現、全面的なSimulator未確認表現を是正\n''')

replace_once('docs/VERSION_MATRIX.md','- 現在のプロジェクト版：`0.9.3+21`\n','- 現在のプロジェクト版：`0.9.4+22`\n')
replace_once('docs/VERSION_MATRIX.md','| 0.9.3 | 9 | タスク20-D2A：端末内データ初期化後の遷移是正 | Shell破棄中の二重ナビゲーションを避け、初期登録introへ直接遷移 |\n','| 0.9.3 | 9 | タスク20-D2A：端末内データ初期化後の遷移是正 | Shell破棄中の二重ナビゲーションを避け、初期登録introへ直接遷移 |\n| 0.9.4 | 9 | タスク20-D2B：成果物整合性是正 | D2A実績・未確認範囲・CI履歴を同期。アプリ挙動とSchemaは変更なし |\n')
replace_once('docs/VERSION_MATRIX.md',
'''- main反映後CI：Flutter run #42／iOS run #29 PASS\n\n自動検証部分は完了している。手動Simulator主要導線、ローカルデータ初期化の操作確認、iPhone実機、アクセシビリティは未確認のため、タスク20-B全体は未完了である。\n''',
'''- v0.9.2最終main CI：Flutter run #48／iOS run #35 PASS\n- v0.9.3 PR #10最終検証：Flutter run #69／iOS run #56 PASS\n- Task20-D1起動スモーク：通常サイズ／小型サイズともPASS\n- Task20-D2A：D2-01、D2-03、D2-09、D2-10の一部を両SimulatorでPASS\n- v0.9.3 main反映後CI：本成果物作成時点では独立確認記録なし\n\nFlutter・iOS自動検証、D1、D2A対象範囲は完了している。D2-02、D2-04〜D2-08、D2-10未網羅部分、D2-11、iPhone実機、native accessibilityは未確認のため、Task20-D2およびTask20-B全体は未完了である。\n''')

repls={
'## 0. 開発基盤【雛形・静的検証済み／Flutter統合前】':'## 0. 開発基盤【Flutter・iOS自動統合検証済み】',
'未完了：正式なFlutter/iOSプロジェクト生成、`pubspec.lock`、コード生成、実ビルド。':'実施済み：Flutter 3.44.6、`pubspec.lock`生成、Driftコード生成、strict Analyze、Flutter Test 48件、iOS Simulator debug build。未確認はiPhone実機とnative accessibility。',
'## 1. 初期登録【ローカル実装済み／統合未検証】':'## 1. 初期登録【自動統合済み／D2A主要導線PASS】',
'未完了：Flutter実行、Widget/Integration Test。マイページ通常設定編集はC2でローカル実装済み。':'Task20-D2Aでクリーン起動、必須入力、戻る操作、13画面完了、ホーム遷移を両Simulatorで確認済み。未完了はOS強制終了を伴う途中復帰、全入力分岐、文字拡大、実機。',
'## 3. トレーニング実施【ローカル実装済み／統合未検証】':'## 3. トレーニング実施【自動build・test済み／手動受入未完了】',
'## 4. 記録と進行提案【ローカル実装済み／統合未検証】':'## 4. 記録と進行提案【自動build・test済み／手動受入未完了】',
'- Flutterコンパイル、Widget Test、Golden Test':'- FlutterコンパイルとFlutter TestはPASS。Widget画面網羅、Golden Test',
'- Flutterコンパイル、Widget／Repository統合テスト':'- FlutterコンパイルとFlutter TestはPASS。Widget／Repositoryの画面・保存網羅テスト',
'未検証：Flutter Test、Repository統合、Widget、iOS Simulator／実機。':'Flutter共通CIとiOS Simulator buildはPASS。未検証は生成結果のRepository統合、Widget主要導線、手動Simulator／実機。',
'- Flutter Test、Widget Test、iOS Simulator／実機':'- Flutter TestはPASS。Widget主要導線、iOS通知のSimulator／実機検証',
'未検証：Flutterコンパイル、Widget Test、Router実行、iOS Simulator／実機。':'Flutter共通CIとiOS Simulator build、Router静的契約はPASS。主要導線の手動Simulator／実機は未確認。',
'## 14. タスク20-A ローカルMVPの端末内データ初期化・統合事前確認【ローカル実装・SQLite検証済み／Flutter未実行】':'## 14. タスク20-A ローカルMVPの端末内データ初期化【自動統合・D2A主要操作PASS】',
'- Simulator上の端末内データ初期化操作\n- 新しい匿名IDと初期登録復帰\n- 強制終了・再起動後の復帰':'- Task20-D2Aで説明、同意前無効、キャンセル、削除、初期登録intro復帰は両SimulatorでPASS\n- 匿名IDの旧新差分、全削除対象・保持対象の画面上確認\n- 初期化直後のOS強制終了・再起動後の旧データ非復活',
'- main CI：Flutter run #42、iOS run #29 PASS':'- v0.9.2最終main CI：Flutter run #48、iOS run #35 PASS\n- v0.9.3 PR #10：Flutter run #69、iOS run #56 PASS\n- Task20-D1起動スモーク：2端末PASS\n- Task20-D2A：D2-01、D2-03、D2-09、D2-10一部を2端末でPASS',
'未確認：Simulator主要導線、端末内データ初期化操作、iPhone実機、アクセシビリティ。よってTask20-B全体は未完了。':'未確認：D2-02、D2-04〜D2-08、D2-10未網羅部分、D2-11、iPhone実機、native accessibility。よってTask20-D2およびTask20-B全体は未完了。',
'1. Simulator主要導線の手動受入\n2. 端末内データ初期化、新匿名ID、初期登録復帰の操作確認\n3. iPhone実機試験\n4. VoiceOver、Dynamic Type、コントラスト、タップ領域、エラー表示':'1. D2-02：初期登録途中保存・OS強制終了復帰\n2. D2-04〜D2-08：週間メニュー、実施、記録、設定、各状態の再起動\n3. D2-09残件とD2-10未網羅部分、D2-11文字拡大\n4. iPhone実機試験\n5. VoiceOver、Dynamic Type、コントラスト、タップ領域、エラー表示'}
p=ROOT/'docs/IMPLEMENTATION_ROADMAP.md'; t=p.read_text(encoding='utf-8')
for old,new in repls.items():
    if old not in t: raise SystemExit(f'roadmap missing {old!r}')
    t=t.replace(old,new,1)
p.write_text(t,encoding='utf-8')
append_once('docs/IMPLEMENTATION_ROADMAP.md','## 18. タスク20-D2A 自動iOS UI受入','''## 18. タスク20-D1／D2A iOS Simulator受入【対象範囲完了】\n\n- D1：iPhone 16 Pro／iPhone SE（第3世代）のインストール、起動、静止画面到達、プロセス生存を確認\n- D2A：D2-01、D2-03、D2-09、D2-10の一部を両端末で実操作\n- 5時点×2端末、合計10枚のPNGをレビュー\n- 端末内データ初期化後の二重ナビゲーション不具合を検出・是正\n- D2A対象範囲は完了。Task20-D2全体は未完了\n''')

replace_once('docs/TASK20_A_LOCAL_DATA_RESET_AND_FLUTTER_PREFLIGHT.md','''- ローカルデータ初期化：ローカル実装済み、静的・SQLite契約検証済み\n- Flutterコンパイル／テスト：未実施\n- iOS Simulator／実機：未実施\n- タスク20全体：継続中\n''','''Task20-A完了時点ではローカル実装・静的・SQLite契約検証までであった。その後のTask20-B〜D2Aにより状態は次のとおり更新された。\n\n- ローカルデータ初期化：実装済み、静的・SQLite契約検証済み\n- Flutterコンパイル／テスト：PASS（Flutter Test 48／48）\n- iOS Simulator build／起動スモーク：PASS\n- D2A自動UI受入：説明、同意、キャンセル、削除、初期登録intro復帰を両SimulatorでPASS\n- iPhone実機／OS強制終了後の復帰／native accessibility：未実施\n- Task20-D2およびTask20全体：継続中\n''')
replace_once('docs/TASK20_A_LOCAL_DATA_RESET_AND_FLUTTER_PREFLIGHT.md','''### 作成済み・未実行\n\n- `local_account_repository_test.dart`\n- `local_data_reset_page_test.dart`\n- 既存My Page Widget Testへの項目確認追加\n\n### 未実施\n\n- `flutter pub get`\n- `pubspec.lock`生成\n- Driftコード生成\n- `flutter analyze`\n- `custom_lint`\n- `flutter test`\n- Widget／Repository統合／Golden Test\n- iOS Simulator／iPhone実機\n''','''### 後続工程で実施済み\n\n- `flutter pub get`、`pubspec.lock`生成、Driftコード生成\n- strict `flutter analyze`：Error 0／Warning 0／Info 0\n- Flutter Test：48／48 PASS\n- iOS Simulator debug build\n- Task20-D1起動スモーク\n- Task20-D2Aの端末内データ初期化主要操作\n\n### 引き続き未実施\n\n- D2-09の匿名ID差分、全保持／削除対象、OS強制終了後の旧データ非復活の手動確認\n- iPhone実機\n- VoiceOver、Dynamic Type等のnative accessibility\n''')
replace_once('docs/TASK20_A_LOCAL_DATA_RESET_AND_FLUTTER_PREFLIGHT.md','''.fvmrc`の固定版はFlutter 3.44.6である。現在のLinux環境にはFlutter、Dart、Xcodeがなく、`pubspec.lock`、Drift生成コード、`ios/`も存在しないため、実行検証はBLOCKEDである。\n''','''Task20-A作成環境ではFlutter／Xcode不足によりBLOCKEDだったが、後続のGitHub Actions実行レーンでFlutter 3.44.6とmacOS／Xcodeを用いた検証を完了した。BLOCKEDは現行状態ではなく履歴である。\n''')
replace_once('docs/TASK20_A_LOCAL_DATA_RESET_AND_FLUTTER_PREFLIGHT.md','''タスク20-Bとして、Flutter 3.44.6を導入した環境で依存解決・コード生成・解析・テストを実行し、失敗を是正する。その後、macOS/Xcode環境でiOSプロジェクト生成、Simulator、iPhone実機、データ初期化の操作・復帰・アクセシビリティを検証する。\n''','''次工程はTask20-D2の未実施ケースである。D2-02、D2-04〜D2-08、D2-09残件、D2-10未網羅部分、D2-11を実施し、その後にiPhone実機とnative accessibilityを確認する。\n''')

replace_once('docs/TASK20_B_FLUTTER_IOS_EXECUTION.md','''Flutter 3.44.6を公式release metadata／release ref／SHA-256で検証して導入し、LinuxのFlutter共通レーンとmacOSのiOS Simulatorレーンで自動検証を完了した。手動Simulator主要導線、ローカルデータ初期化の操作確認、iPhone実機、アクセシビリティは未確認であり、コード存在や自動build成功だけでTask 20-B全体を完了とは扱わない。\n''','''Flutter 3.44.6を公式release metadata／release ref／SHA-256で検証して導入し、LinuxのFlutter共通レーンとmacOSのiOS Simulatorレーンで自動検証を完了した。さらにTask20-D1の2端末起動スモークと、Task20-D2AのD2-01／D2-03／D2-09／D2-10一部を自動実操作で確認した。D2の残ケース、iPhone実機、native accessibilityは未確認であり、D2A対象範囲の完了をTask20-B全体の完了とは扱わない。\n''')
replace_once('docs/TASK20_B_FLUTTER_IOS_EXECUTION.md','- main反映後の最新実績：Flutter run #42、iOS run #29\n','''- v0.9.2最終main実績：Flutter run #48、iOS run #35\n- v0.9.3 PR #10最終実績：Flutter run #69、iOS run #56\n- Task20-D1：通常／小型Simulator起動スモーク PASS\n- Task20-D2A：D2-01、D2-03、D2-09、D2-10一部を両SimulatorでPASS\n- v0.9.3 main反映後CI：本成果物作成時点では独立確認記録なし\n''')
replace_once('docs/TASK20_B_FLUTTER_IOS_EXECUTION.md','''- Simulator起動後の初期登録\n- 週間メニュー作成\n- トレーニング実施\n- 記録・進行提案\n- フォーム文言／画像なしフォールバック\n- マイページ通常設定\n- 端末内データ初期化、新匿名ID、初期登録復帰\n- 強制終了／再起動、画面サイズ、文字拡大\n''','''- D2-02：初期登録途中保存・OS強制終了復帰\n- D2-04：週間メニュー作成・途中復帰\n- D2-05：トレーニング実施\n- D2-06：記録・進行提案、フォーム説明導線\n- D2-07：マイページ通常設定\n- D2-08：各状態の強制終了／再起動\n- D2-09残件：匿名ID差分、削除／保持対象、初期化直後再起動\n- D2-10未網羅部分とD2-11文字拡大\n''')
replace_once('docs/TASK20_B_FLUTTER_IOS_EXECUTION.md','上記手動受入・実機・アクセシビリティの結果を記録し、重大な不具合がないことを確認する。未実施項目を推定でPASSにしない。\n','D2-01〜D2-10を両端末、D2-11を最低1端末で完了し、実機・アクセシビリティの別タスクを明示管理する。D2Aで確認した範囲だけをPASSとし、未実施項目を推定でPASSにしない。\n')

replace_once('docs/DECISION_LOG.md','- 再検証：Task20-D2Aで通常サイズ・小型サイズの両Simulatorにて初期化後intro表示まで確認する\n','- 再検証結果：Task20-D2A run #56で通常サイズ・小型サイズの両Simulatorとも初期化後intro表示までPASS\n')
append_once('docs/DECISION_LOG.md','## D-010 Task20-D2Aの自動受入範囲を限定して完了扱い','''## D-010 Task20-D2Aの自動受入範囲を限定して完了扱い\n\n- 日付：2026-07-27\n- 区分：採用\n- 完了対象：D2-01、D2-03、D2-09、D2-10の一部\n- 根拠：iPhone 16 Pro／iPhone SE（第3世代）の両Simulatorで実操作がPASSし、5時点×2端末のPNGをレビューした\n- 完了扱いにしない対象：D2-02、D2-04〜D2-08、D2-10未網羅部分、D2-11、iPhone実機、native accessibility\n- 理由：部分自動化の成功をTask20-D2全体へ拡張すると、未実施ケースを推定でPASSにするため\n- 影響範囲：受入状態と成果物記載のみ。製品仕様、Schema、生成ロジックに変更なし\n\n## D-011 成果物整合性是正をv0.9.4として昇格\n\n- 日付：2026-07-27\n- 区分：採用\n- 対象：README、Version Matrix、Roadmap、Task20-A／B／D2A文書、正本管理記録\n- 理由：v0.9.3候補には古いCI番号、Flutter未実行表現、全面的なSimulator未確認表現が残っていたため\n- 採用：同じv0.9.3を別SHAで上書きせず、実装基盤v0.9.4／アプリ0.9.4+22として新しい正本候補を生成する\n- 保持：v0.9.3とPR #10のArtifactは履歴証跡として保持する\n- 変更なし：アプリ挙動、Schema v9／75テーブル、削除対象53テーブル、匿名ID再発行契約\n''')
replace_once('docs/PARKING_LOT.md','- 再開条件：Flutter共通検証とiOS Simulator buildが各1回以上PASSし、使用するcache Actionを完全長commit SHAへ固定し、cache keyへOS・architecture、Flutter version、release ref、pubspec lock hashを含められるとき\n','''- 現在の到達：Flutter共通検証とiOS Simulator buildのPASS条件は達成済み\n- 未達条件：採用するcache Actionの完全長SHA固定、cache key設計、restore失敗時の公式archive検証フォールバック\n- 再開条件：上記未達条件を満たし、cache利用時と未利用時の生成物・検証結果が一致するとき\n''')
append_once('docs/PARKING_LOT.md','## Active acceptance is not Parking Lot','''## Active acceptance is not Parking Lot\n\nTask20-D2の未実施ケース、iPhone実機、native accessibilityは、機能の一時除外ではなく現在進行中の受入タスクである。完了までParking Lotへ移さず、Issueと受入チェックリストで管理する。\n''')

(ROOT/'docs/TASK20_D2A_LOCAL_RESET_NAVIGATION_FIX.md').write_text('''# Task20-D2A 端末内データ初期化後ナビゲーション是正\n\n- 日付：2026-07-27\n- 実装基盤：v0.9.3で修正、v0.9.4で成果物整合性を是正\n- アプリ：0.9.4+22\n- Schema：v9／75テーブル、変更なし\n\n## 検出\n\nGitHub Actions上のiOS Simulator自動UI受入で、初期登録完了後に端末内データを削除すると、`StatefulNavigationShell`のGlobalKey重複例外が発生した。削除処理と匿名ID再発行は完了しており、停止点は削除成功後の画面遷移だった。\n\n## 原因\n\n`LocalDataResetPage`が`/launch`へ遷移した直後、LaunchPageが初期登録状態を監視して`/onboarding`へ再遷移していた。StatefulShellRouteの破棄と次の遷移が重なり、同一のStatefulNavigationShell GlobalKeyが一時的に重複した。\n\n## 採用した修正\n\n- ユーザー状態Providerのinvalidateは維持する。\n- 削除成功後は`/launch`を介さず、`/onboarding`へ直接遷移する。\n- 削除対象、削除順序、Secure Storageの匿名ID切替、DB transaction、Schemaは変更しない。\n\n## 最終検証\n\n- PR #10 head：`376d7c3c524ab50123cd317ec57247ae6245436e`\n- Flutter共通CI：run #69 PASS\n- iOS Simulator CI：run #56 PASS\n- 通常サイズ：iPhone 16 Pro PASS\n- 小型サイズ：iPhone SE（第3世代）PASS\n- 5時点×2端末、合計10枚のPNGレビュー PASS\n- strict Analyze：Error 0／Warning 0／Info 0\n- Flutter Test：48／48 PASS\n- iOS Simulator build／D1起動スモーク：PASS\n\n## 判定境界\n\nTask20-D2Aの対象範囲はPASSとする。Task20-D2全体、iPhone実機、VoiceOver等のnative accessibilityは未完了である。\n''',encoding='utf-8')
(ROOT/'docs/TASK20_D2A_COMPLETION_REPORT.md').write_text('''# Task20-D2A 自動iOS UI受入完了レポート\n\n- 実施日：2026-07-27\n- 対象PR：#10\n- merge commit：`1b90aea9b097f33a97aeb2e2552dcb572751f0b4`\n- 実装基盤：v0.9.3で機能修正、v0.9.4で成果物整合性是正\n- アプリ：0.9.4+22\n- Schema：v9／75テーブル、変更なし\n\n## 完了対象\n\n- D2-01：クリーン起動と初期登録intro\n- D2-03：必須入力、戻る操作、初期登録完了、ホーム遷移\n- D2-09：説明、同意前無効、キャンセル、削除、初期登録intro復帰\n- D2-10の一部：通常サイズ／小型サイズで同一導線を実行\n\n## 最終結果\n\n- Flutter共通CI run #69：PASS\n- iOS Simulator CI run #56：PASS\n- iPhone 16 Pro：PASS、5 screenshots\n- iPhone SE（第3世代）：PASS、5 screenshots\n- 合計10 screenshots：目視レビューPASS\n- 空白、エラー表示、overflow警告、ローディング途中画像の混入：なし\n- v0.9.3 PR Artifact SHA-256：`33077e5db54ac31ef0a99d709931a767a5abad163dba6a45f4ce8a3b91bad13c`\n- iOS Artifact digest：`sha256:5443fa5b57ef0fbe928c0e7d54207cfa63b0c48a37c089160087515f623e95e5`\n\n## 検証経緯\n\n- run #47：初期化後の二重ナビゲーション／GlobalKey重複を検出\n- run #54：小型端末の遅延生成Widget待機条件を是正\n- run #55初回：debug接続前のRunnerインフラ障害\n- run #55再実行：操作PASS、ただし証跡PNGにローディング表示が混入\n- run #56：安定表示待ちを追加し、両端末・全工程・10枚の証跡をPASS\n\n## 未完了\n\n- D2-02\n- D2-04〜D2-08\n- D2-09の匿名ID差分、全削除／保持対象、初期化直後のOS再起動\n- D2-10の全画面網羅\n- D2-11\n- iPhone実機\n- VoiceOver等のnative accessibility\n\n## 判定\n\nTask20-D2Aは完了。Task20-D2およびTask20-B全体は未完了。\n''',encoding='utf-8')

replace_once('tools/verify_task20_b_execution_lane.py','''    "recorded_automated_evidence": {"flutter_main_run": 42, "ios_main_run": 29},\n    "manual_acceptance": "NOT_VERIFIED",\n''','''    "recorded_automated_evidence": {\n        "v0_9_2_main": {"flutter_run": 48, "ios_run": 35},\n        "v0_9_3_pr10": {"flutter_run": 69, "ios_run": 56},\n        "task20_d1": "PASS_TWO_SIMULATORS",\n        "task20_d2a": ["D2-01", "D2-03", "D2-09", "D2-10-partial"],\n    },\n    "manual_acceptance": "PARTIALLY_VERIFIED_D2A_SCOPE_ONLY",\n    "task20_d2_fully_verified": False,\n''')
replace_once('tools/verify_notification_repository_contract.py','        "flutter_tests": "AUTHORED_NOT_EXECUTED",\n','        "flutter_test_source": "AUTHORED",\n        "flutter_test_execution": "VERIFIED_BY_TASK20_B_CI_48_OF_48",\n')
replace_once('tools/verify_training_settings_contract.py','        "flutter_tests": "SPECIFIED_NOT_EXECUTED",\n','        "flutter_test_source": "AUTHORED",\n        "flutter_test_execution": "VERIFIED_BY_TASK20_B_CI_48_OF_48",\n')
replace_once('docs/IMPLEMENTATION_ROADMAP.md','## 9. タスク19.5-C1 フォーム説明【ローカル実装済み／統合未検証】','## 9. タスク19.5-C1 フォーム説明【自動build・test済み／手動表示確認未完了】')
replace_once('docs/IMPLEMENTATION_ROADMAP.md','## 10. タスク19.5-C2 マイページ通常設定編集【ローカル実装済み／統合未検証】','## 10. タスク19.5-C2 マイページ通常設定編集【自動build・test済み／手動受入未完了】')
replace_once('docs/TASK19_5_C1_EXERCISE_FORM_FALLBACK.md','ローカル実装、静的検証、SQLite契約検証の範囲で完了。Flutter SDK・Xcodeがないため、コンパイル、Widget/Golden Test、iOS表示は未検証。','タスク19.5-C1完了時点ではローカル実装、静的検証、SQLite契約検証まで完了し、Flutter SDK・Xcode不足のため実行検証は未実施だった。後続のTask20-BでFlutterコンパイル、Flutter Test 48／48、iOS Simulator buildがPASSした。実画像144枚、Golden Test、手動iOS表示、iPhone実機は未確認。')
replace_once('docs/TASK19_5_C2_TRAINING_SETTINGS_EDITING.md','- 状態：ローカル実装・静的／SQLite契約検証済み、Flutter／iOS統合未検証','- 状態：ローカル実装・静的／SQLite契約検証済み。後続のTask20-BでFlutterコンパイル、Flutter Test 48／48、iOS Simulator buildがPASS。D2-07の手動受入は未実施')
replace_once('docs/TASK19_5_C2_TRAINING_SETTINGS_EDITING.md','Flutter SDKがないため、Widget Test、Repository統合テスト、`flutter analyze`、`flutter test`、iOS表示は未実行である。','タスク19.5-C2完了時点ではFlutter SDK不足により未実行だった。後続のTask20-Bでstrict `flutter analyze`、Flutter Test 48／48、iOS Simulator buildがPASSした。設定7区分の手動編集・保存・破棄確認、iPhone実機、native accessibilityは未実施である。')
replace_once('docs/TASK19_5_C4_NOTIFICATION_SQLITE_REPOSITORY.md','- Repository単体テストを作成したが、Flutter SDKがないため未実行。','- Repository単体テストを作成し、後続のTask20-B CIに含まれるFlutter Test 48／48でPASS。')
replace_once('docs/TASK19_5_C4_NOTIFICATION_SQLITE_REPOSITORY.md','- Flutter Test、Widget Test、iOS Simulator、iPhone実機確認','- Widget主要導線、ネイティブ通知のiOS Simulator／iPhone実機確認')

shutil.rmtree(ROOT / 'build', ignore_errors=True)
shutil.rmtree(ROOT / '.dart_tool', ignore_errors=True)
files=[]
for p in ROOT.rglob('*'):
    if p.is_file() and p.relative_to(ROOT).parts[0] not in {'build','.dart_tool'}:
        files.append(p.relative_to(ROOT).as_posix())
(ROOT/'FILE_MANIFEST.txt').write_text('\n'.join(sorted(files))+'\n',encoding='utf-8')
if OUT.exists(): OUT.unlink()
with zipfile.ZipFile(OUT,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for p in sorted(ROOT.rglob('*')):
        if not p.is_file(): continue
        rel=p.relative_to(ROOT)
        if rel.parts[0] in {'build','.dart_tool'}: continue
        info=zipfile.ZipInfo(rel.as_posix(),date_time=(2026,7,27,0,0,0))
        info.create_system=3; info.compress_type=zipfile.ZIP_DEFLATED; info._compresslevel=9
        info.external_attr=(p.stat().st_mode & 0o777)<<16
        z.writestr(info,p.read_bytes())
sha=hashlib.sha256(OUT.read_bytes()).hexdigest()
if sha != EXPECTED_SHA256:
    raise SystemExit(f'Canonical ZIP SHA-256 mismatch: {sha} != {EXPECTED_SHA256}')
print(f'Task20-D2B canonical package PASS: {OUT} sha256={sha}')
