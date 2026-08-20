# Task20-D2J レビュー資料

## 目的

Task20-D2のD2-11「文字拡大」を、既存の受入済み主要導線を再利用してGitHub-hosted iOS Simulator上で自動確認する。受入条件は実装に合わせて緩和しない。

main正本はv0.9.7のまま。D2I受入済みv0.9.10を保持し、D2Jで実際に検出したDynamic Type layout failureを既存候補へ上書きせず順次修正する。

## 正本系譜

- main正本：v0.9.7 / 0.9.7+25
- D2I受入済み候補：v0.9.10 / 0.9.10+28、PR #18 Head `e48a66ee8cb3f23ba9ed69607c71f574fe1c508e`
- D2J失敗候補：v0.9.11 / 0.9.11+29
- D2J current candidate：v0.9.12 / 0.9.12+30

PR #19で一時的に使用したD2J v0.9.8表記は、PR #18ですでにv0.9.8〜v0.9.10が履歴固定されているため撤回した。既存候補を上書きしない。

current build lineageはD2J専用gzip/base64 payloadを使わない。クリーンなv0.9.7からPR #18でSUCCESS実績のあるD2I v0.9.8／v0.9.9／v0.9.10 builder・payloadを同じGit blobのまま再利用し、受入済みv0.9.10 ZIP SHAを一致確認した後、payload-free v0.9.11 builderでHome／Menu修正を再現する。さらにv0.9.11 ZIP SHAを一致確認してから、payload-free v0.9.12 builderが週間予定画面とversion整合だけを限定変更する。

## D2J正式FAIL履歴

### D2J #3 — Home TodayAction

Head `d837ebf1cfaba0e20f990673720fd9c345e6728e` / run `32201825637`。小型Simulator＋`accessibility-extra-large`で初期登録完了後のHomeに `RenderFlex overflowed by 192 pixels on the bottom` を検出。startup failureではなく製品layout failureのため再試行せずFAIL。

Artifact ID `9348172126` / digest `sha256:cfcc99a85a040a803e45f64a04260b1fdf05ab38f97377a233ab70c2a8a0c95b`。

### D2J #10 — Menu empty state

Head `2ee85fdab5c1c67c7047072fca96d8ff13c7d3b5` / run `32206128286`。Home修正後はD2Aを完走し、旧192px overflow解消を確認。その後D2D開始時のMenu空状態で `RenderFlex overflowed by 121 pixels on the bottom` を検出し、「今週のメニューを作成する」CTAがoff-screenとなってtap不能。製品layout failureのため再試行しない。

Artifact ID `9350251863` / digest `sha256:8803c8a13d0f18e15213973784631d598ac8c679cbe24127b4c20f8a0c6b0069`。

### D2J #21 — 週間予定導線内の横overflow

Head `91477d8edde0b77ab0fe6011e25aec512ce65ff2` / run `32218251710`。payload-free v0.9.11正本再構築、Task20-B iOS、D1、D2AはPASSし、Home 192px／Menu 121px failureの解消を確認。D2Dで `RenderFlex overflowed by 74 pixels on the right` を検出した。

当時のD2Dは途中画面で`takeException()`していなかったため、最終healthy-frame判定だけでは発生画面を断定しなかった。Artifact ID `9353382638` / digest `sha256:f714388e938935b31091cf3215a220ded77f4fc64e838e83904aed4f899dd088`。

### D2J #22 — 「今週の予定」画面を失敗境界として確定

診断Head `4d782c73f900834dda11ac8b4b6793af7468b510` / run `32220684231`。製品v0.9.11は変更せず、D2D受入テストへ各画面境界の`expectHealthyFrame()`を6件追加した。

- Flutter #236：SUCCESS
- 標準iOS #223：SUCCESS
- D2J #22：FAILURE

D2J #22のD2D phase1 attempt 1はdebug connection前に1800秒timeoutし、predeclared startup policyに従いclean retry。attempt 2はアプリへ接続後、`task20_d2d_weekly_planner_prepare_test.dart:27`のhealthy-frame判定で同じ `RenderFlex overflowed by 74 pixels on the right` を再現した。

line 27は「今週の予定」表示直後、かつ「現在の状態」へ遷移する前であるため、74px横overflowの最初の失敗境界を週間予定入力画面と確定した。Artifact ID `9355195565` / digest `sha256:86443bc753da7cf97fcfa4aba25b3b44298dacf0c9bedfa5dca568129890d419`。

## v0.9.11修正（失敗候補として固定）

受入済みv0.9.10のD2I修正と56件testを保持し、Home TodayActionとMenu空状態だけを必要時スクロール可能にした。

v0.9.11固定値：

- ZIP SHA-256：`cd0781aa74b6be26aaf990ceb6e01a02064bb2ca0688e56d1bc603a8f95114ca`
- runtime tree：`3eeb5a3357ca1ec2a42f486de1b375312f1baf64bfde1682f1f38b7bc702a71e`
- product lib tree：`6eea4b98f6741cf7e02699cda31b8d2c5e894366e82c2b15f9c8fa287553bfdc`
- test tree：`878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5`
- Schema tree：`bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af`
- assets tree：`cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe`
- expected Flutter tests：56
- canonical file count：306

## v0.9.12修正

v0.9.11を上書きせず、v0.9.12 / 0.9.12+30として週間予定画面だけを追加修正する。

対象：`lib/features/weekly_planner/presentation/steps/weekly_planner_steps.dart` の利用可能日カード。

従来は「時間」「場所」の`DropdownButtonFormField`を常に1行2列の`Row`へ配置していた。iPhone SE＋`accessibility-extra-large`では各Dropdownの有効横幅が不足し、内部RenderFlexが74px右方向へoverflowした。

v0.9.12では`LayoutBuilder`と`MediaQuery.textScalerOf(context)`で表示条件を判定する。

- 十分な幅かつ標準文字：従来どおり1行2列を維持
- `constraints.maxWidth < 280` または `textScaler.scale(16) > 20`：時間／場所を縦積みに切り替える
- 文言、選択肢、保存ロジック、遷移、週間メニュー生成ロジック、D2J受入条件は変更しない
- v0.9.11のHome／Menu修正、D2I修正、56件testを保持
- Schema v9 / 75 tables、Migration、Seed、assetsは変更しない

## v0.9.12固定値

- parent v0.9.11 ZIP SHA-256：`cd0781aa74b6be26aaf990ceb6e01a02064bb2ca0688e56d1bc603a8f95114ca`
- v0.9.12 ZIP SHA-256：`a1a2c89d73324a72d10a1d9b8a50bc896cf358f71a7c5dc485b8c3bd4faeb2a3`
- runtime tree (`lib` + `test`)：`bbae98d2221ecfd912f14cc0beec8b28a5f568743463acb711ce3439011d9168`
- product `lib` tree：`e5cb6241453f8792036ae52425ebc62a9f91e61f9e08b3b2afa77dd625404fc0`
- test tree：`878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5`
- weekly planner source SHA-256：`d721ebdf5294ef02a550dff7936a19c9ea979502e9e927bbfd4b3951f8f964a7`
- Schema tree：`bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af`
- assets tree：`cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe`
- expected Flutter tests：56
- canonical file count：306

ローカルでは全26 static verifyをPASS。クリーンなv0.9.11からpayload-free v0.9.12 builderで再生成したZIPが手元正本とバイト単位一致し、verifierでproduct/runtime/test/schema/assets hashを照合済み。正式なFlutter runtime/analyzer/iOS/Dynamic Type結果はv0.9.12 exact current Head CIだけを根拠とする。

## D2J固定条件

- D1 `compact` role（iPhone SE相当）1台
- content-size category：`accessibility-extra-large`
- Simulator erase／boot後ごとにDynamic Type setterを適用し、setter、help、queryをArtifact保存
- D2A／D2D／D2E／D2G既存導線を同じ拡大文字状態で再利用
- D2Dは各主要画面境界でhealthy-frameを検査し、例外を後段へ持ち越さない
- 必須画面：intro、基本情報、メニュー、実施、マイページ
- drive logの`RenderFlex overflow`、Rendering Library exception、ErrorWidgetは自動FAIL
- startup infrastructure failureのみ既定条件で最大1回clean retry。product/assertion/layout failureは再試行しない

## 正式受入条件

同一current Headで以下をすべて要求する。

1. Task20-B2 ZIP Integration terminal SUCCESS
2. Task20-B2 iOS ZIP Integration terminal SUCCESS
3. Task20-D2J iOS Dynamic Type Acceptance terminal SUCCESS
4. current Head標準iOSでD2I回帰を含む既存受入群SUCCESS
5. C3 analyzer / C4 dependency gate SUCCESS
6. v0.9.10／v0.9.11／v0.9.12 ZIP SHAがArtifactと固定値に一致
7. D2J result/log/Dynamic Type setter/PNG SHA-size監査
8. D2J全PNGを目視し、blank、ErrorWidget、overflow、切れ、重なり、操作不能表示なし

ここまで満たした場合だけD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。

## 判定境界

D2J PASS後も、Dynamic Type全サイズ／最大カテゴリ、D2-08 reset途中OS終了、D2-10未網羅、iPhone実機、native accessibility（VoiceOver等）は別残件。Task20-D2／Task20-B全体は未完了。PR #19はDraft／未merge、main正本v0.9.7も変更しない。
