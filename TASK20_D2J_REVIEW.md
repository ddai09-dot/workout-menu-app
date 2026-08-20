# Task20-D2J レビュー資料

## 目的

Task20-D2のD2-11「文字拡大」を、既存の受入済み主要導線を再利用してGitHub-hosted iOS Simulator上で自動確認する。受入条件は実装に合わせて緩和しない。

main正本はv0.9.7のまま。D2I受入済みv0.9.10を保持し、D2Jで実際に検出した失敗候補を上書きせず履歴固定する。現在候補は **v0.9.13 / 0.9.13+31**。

## 正本系譜

- main正本：v0.9.7 / 0.9.7+25
- D2I受入済み候補：v0.9.10 / 0.9.10+28、PR #18 Head `e48a66ee8cb3f23ba9ed69607c71f574fe1c508e`
- D2J失敗候補：v0.9.11 / 0.9.11+29
- D2J失敗候補：v0.9.12 / 0.9.12+30
- D2J current candidate：v0.9.13 / 0.9.13+31

current build lineageはクリーンなv0.9.7からD2I v0.9.8〜v0.9.10を既存builderで再現し、v0.9.11、v0.9.12、v0.9.13を順にpayload-free builderで再現する。既存候補のZIP SHAは上書きしない。

## D2J正式FAIL履歴

### D2J #3 — Home TodayAction

Head `d837ebf1cfaba0e20f990673720fd9c345e6728e`。iPhone SE相当＋`accessibility-extra-large`でHomeに192px下overflow。製品layout failure。

### D2J #10 — Menu empty state

Head `2ee85fdab5c1c67c7047072fca96d8ff13c7d3b5`。Home修正後、Menu空状態で121px下overflow＋CTA off-screen。製品layout failure。

### D2J #21 / #22 — 「今週の予定」74px右overflow

v0.9.11で74px右overflowを検出。診断Head `4d782c73f900834dda11ac8b4b6793af7468b510` / run #22でD2D主要画面checkpointを追加し、`task20_d2d_weekly_planner_prepare_test.dart:27`、すなわち「今週の予定」表示直後を最初の失敗境界として確定。Artifact ID `9355195565` / digest `sha256:86443bc753da7cf97fcfa4aba25b3b44298dacf0c9bedfa5dca568129890d419`。

### D2J #32 — D2E start CTA harness reachability

Head `576360754d1e112621ee43b5dc4837c3cdb1ca68` / run `32317977300`。v0.9.12の週間予定修正はD2D enlarged-text経路を通過したが、D2Eで「予定どおり開始する」を待つテストが失敗。製品画面はListViewで、テスト側が拡大文字時に画面外のCTAまでスクロールしていなかったため、harness reachability defectと診断。製品failureとは判定せず、テスト側だけスクロール＋診断を追加した。

### D2J #33 — D2E adjustment sheet 39px右overflow

Head `369a3977661a058569ba5f500f493d887b6b5762` / run `32325112684`。CTA reachability修正後、D2E開始前確認を通過し `D2E_01_start_check.png` を生成。その後「今日の状態に合わせる」→痛み・違和感対応の導線で39px右方向RenderFlex overflowを検出した。これはstartup/harness failureではなく製品layout failureのため、v0.9.12を失敗候補として固定する。

Artifact ID `9391867618` / digest `sha256:48f7854831225a755b950f2357d51627999bb982320ff4745ff6b46b05b86f5e`。

## 標準iOS #234 — D2I証跡transport failure

Head `369a3977661a058569ba5f500f493d887b6b5762` / run `32325112771`。D2Iのregular phase1/phase2、compact phase1はテストPASS＋metadata chunk取得。compact phase2もアプリ側テスト自体はPASSしたが、`flutter:` metadata行がdriver logへ転送されず、runnerが `metadata marker not found: D2I_PHASE2_METADATA` でFAILした。

これはD2I製品挙動の失敗ではなく証跡transportの欠陥。v0.9.13 current Headではtest processのstdoutに依存せず、`IntegrationTestWidgetsFlutterBinding.reportData`をdriver側`responseDataCallback`で受け、既存parser互換のmetadata chunkとしてdriver stdoutへ出力する。検査項目・比較条件は変更しない。

## v0.9.13修正

対象：`lib/features/workout/presentation/workout_adjustment_page.dart` の痛み・違和感対応sheet。

小型Simulator＋`accessibility-extra-large`では、身体部位／対応内容の`DropdownButtonFormField`で選択ラベルのintrinsic widthが利用可能幅を超え、内部Rowが39px右overflowした。v0.9.13では対象2フィールドへ `isExpanded: true` を付与し、選択表示をfield幅内に制約する。

- 文言、選択肢、保存、遷移、workoutロジックは変更しない
- v0.9.12の週間予定responsive stackingを保持
- D2I修正、56 testsを保持
- Schema v9 / 75 tables、Migration、Seed、assetsは変更しない

## v0.9.13固定値

- parent v0.9.12 ZIP SHA-256：`a1a2c89d73324a72d10a1d9b8a50bc896cf358f71a7c5dc485b8c3bd4faeb2a3`
- v0.9.13 ZIP SHA-256：`d6b0016b669bde9091294c52d7c138ce964d90515b3dd42320bac784f3eef586`
- runtime tree (`lib` + `test`)：`9fb2b589aed40c043ec94ce0cfce877f723572f36786c4c87fcb4082a970cd69`
- product `lib` tree：`28299d8a1c9519594fdafc605406da791ee7bd3c5a1b10b0d793c86e88ed1e65`
- test tree：`878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5`
- weekly planner SHA-256：`d721ebdf5294ef02a550dff7936a19c9ea979502e9e927bbfd4b3951f8f964a7`
- workout adjustment SHA-256：`ec626105f62872cb2aa90137011442bb8300640818d36b5872026948c2f425e5`
- Schema tree：`bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af`
- assets tree：`cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe`
- expected Flutter tests：56
- canonical file count：306

ローカルではv0.9.13 builderをクリーンなv0.9.12へ適用し、2回のdeterministic buildが同一ZIP SHA `d6b0016b...` になった。verifierでproduct/runtime/test/schema/assets hashを照合済み。正式なruntime/analyzer/iOS/Dynamic Type結果はexact current Head CIのみを根拠とする。

## current Head標準iOS回帰

historical D2H PASSはPR #17のv0.9.7 Headに対する証跡であり、v0.9.13の回帰証跡には流用しない。v0.9.13標準iOSレーンへD2Hを組み込み、current candidateで以下を再検証する。

- finalized weekly menu persistence
- partial workout record persistence
- body measurement persistence
- primary training goal persistence
- OS-level process termination/restart

D2Hの判定範囲は従来どおりD2-06/07/08/10 partialであり、Task20-D2全体PASSへ拡張しない。

## D2J固定条件

- D1 `compact` role（iPhone SE相当）1台
- content-size category：`accessibility-extra-large`
- erase／boot後ごとにDynamic Type setterを適用し、setter/help/queryをArtifact保存
- D2A／D2D／D2E／D2G既存導線を同じ拡大文字状態で再利用
- 必須画面：intro、基本情報、メニュー、実施、マイページ
- `RenderFlex overflow`、Rendering Library exception、ErrorWidgetは自動FAIL
- startup infrastructure failureのみ既定条件で最大1回clean retry。product/assertion/layout failureは再試行しない

## 正式受入条件

同一current Headで以下をすべて要求する。

1. Task20-B2 ZIP Integration terminal SUCCESS
2. Task20-B2 iOS ZIP Integration terminal SUCCESS
3. Task20-D2J iOS Dynamic Type Acceptance terminal SUCCESS
4. 標準iOSでD2H current-candidate regression、D2I、既存D2A/C/D/E/F/GがSUCCESS
5. C3 analyzer / C4 dependency gate SUCCESS
6. v0.9.10／v0.9.11／v0.9.12／v0.9.13 ZIP SHAが固定値に一致
7. D2I result/metadata、D2H result、D2J result/log/Dynamic Type setter/PNG SHA-sizeをArtifact監査
8. D2J全PNGを目視し、blank、ErrorWidget、overflow、切れ、重なり、操作不能表示なし

ここまで満たした場合だけD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。

## 判定境界

D2J PASS後も、Dynamic Type全サイズ／最大カテゴリ、D2-08 reset途中OS終了、D2-10未網羅、iPhone実機、native accessibility（VoiceOver等）は別残件。Task20-D2／Task20-B全体は未完了。PR #19はDraft／未merge、main正本v0.9.7も変更しない。
