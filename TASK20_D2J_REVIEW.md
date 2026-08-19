# Task20-D2J レビュー資料

## 目的

Task20-D2のD2-11「文字拡大」を、既存の受入済み主要導線を再利用してGitHub-hosted iOS Simulator上で自動確認する。受入条件は実装に合わせて緩和しない。

main正本はv0.9.7のまま。D2Iの受入済み候補v0.9.10を親として、D2Jで実際に検出したHome／Menuのlayout failureだけをv0.9.11／0.9.11+29へ積む。

## 正本系譜と版番号衝突の解消

- main正本：v0.9.7 / 0.9.7+25
- D2I受入済み候補：v0.9.10 / 0.9.10+28、PR #18 Head `e48a66ee8cb3f23ba9ed69607c71f574fe1c508e`
- D2I：Flutter #214／iOS #201 SUCCESS。通常／小型Simulatorの定義済みD2-09範囲でAUTOMATED PASS
- D2J後継候補：v0.9.11 / 0.9.11+29

PR #19では一時的にD2J修正をv0.9.8と呼んで検証したが、PR #18ですでにv0.9.8〜v0.9.10がD2I履歴として固定されていることを再確認した。したがって暫定v0.9.8 builder類はcurrent treeから削除し、Git履歴とCI Artifactだけを失敗証跡として保持する。既存候補を上書きしない。

v0.9.11 builderはクリーンなv0.9.7からD2I累積patchを適用し、中間canonical ZIPが受入済みv0.9.10 SHA `9fce3c9dd234fcc669ed7e5b62b8b2d612b3fa80b634bca14406cf5c6bb4836f`と完全一致した場合だけD2J patchを適用する。

## D2J #3：Home TodayAction正式FAIL

Head `d837ebf1cfaba0e20f990673720fd9c345e6728e`、run `32201825637`ではD1、Dynamic Type setter、D2A基本情報まで進み、初期登録完了後のHome TodayActionで次を検出した。

`A RenderFlex overflowed by 192 pixels on the bottom.`

startup infrastructure failureではなく製品layout failureのため再試行せずFAIL。Artifact ID `9348172126`、digest `sha256:cfcc99a85a040a803e45f64a04260b1fdf05ab38f97377a233ab70c2a8a0c95b`。

原因はTodayActionカードが固定viewport内の非スクロールColumnで`Spacer()`を使用していたこと。暫定修正では`SingleChildScrollView`、`mainAxisSize: min`、固定24px間隔へ変更した。

## D2J #10：Home修正確認後のMenu正式FAIL

Head `2ee85fdab5c1c67c7047072fca96d8ff13c7d3b5`、run `32206128286`ではD1 PASS後、D2A attempt 1がstartup infrastructure failureでPNG 0枚だったためpredeclared policyに従い1回だけclean retryした。attempt 2は`All tests passed`まで完走し、旧Home 192px overflowが解消したことを確認した。

続くD2D phase1でMenu空状態`lib/features/menu/presentation/menu_page.dart`のColumnに次を検出した。

`A RenderFlex overflowed by 121 pixels on the bottom.`

同時に「今週のメニューを作成する」CTAがoff-screenとなりtap不能だった。これは製品layout failureのため再試行しない。Artifact ID `9350251863`、digest `sha256:8803c8a13d0f18e15213973784631d598ac8c679cbe24127b4c20f8a0c6b0069`。

## v0.9.11修正

受入済みv0.9.10のD2I製品修正と56件testを保持し、次の2画面だけ変更する。

1. Home TodayAction
   - `SingleChildScrollView`で必要時に縦スクロール可能
   - カード内Columnを`mainAxisSize: MainAxisSize.min`
   - `Spacer()`を`SizedBox(height: 24)`へ置換
2. Menu空状態
   - `LayoutBuilder`でviewport高を取得
   - `SingleChildScrollView`＋`ConstrainedBox(minHeight: constraints.maxHeight)`＋`Center`
   - 通常文字では従来の中央配置を維持し、拡大文字で必要高が超えた場合だけ縦スクロール可能

文言、CTA、遷移先、TodayAction判定、週間メニュー判定ロジック、D2J受入条件は変更しない。Schema v9／75 tables、Migration、Seed、assetsも変更しない。

## v0.9.11固定値

- accepted parent v0.9.10 ZIP SHA-256：`9fce3c9dd234fcc669ed7e5b62b8b2d612b3fa80b634bca14406cf5c6bb4836f`
- v0.9.11 ZIP SHA-256：`d2bc188138c32322ede945a73dd8a8bd28a3c316efe0ad1430b463cb8bc973ab`
- v0.9.7→v0.9.10 cumulative raw patch：`72bd9c46405191c7ec8153fdcd3383e2b11081ee5c2879e674e578c4a61b71a3`
- cumulative gzip patch：`09b425a0ac1cba70f85ca07a52a5d7a4c6e74bf480910542ce4cdc4b5cdb30c9`
- v0.9.10→v0.9.11 raw patch：`5aa56dba53247fe7ab6cc78e0d70842eb8a03dd2df9bd7dd8a50d569cae2f099`
- v0.9.11 gzip patch：`d16bc87443a98e172eb20bb5f05e6f126bc809005ee6453130dcebe0d7e81ae6`
- runtime tree (`lib` + `test`)：`3eeb5a3357ca1ec2a42f486de1b375312f1baf64bfde1682f1f38b7bc702a71e`
- product `lib` tree：`6eea4b98f6741cf7e02699cda31b8d2c5e894366e82c2b15f9c8fa287553bfdc`
- test tree：`878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5`
- Home SHA：`f18059798cba8a49f14b1792950ad70a43a9b3e414411334e70f8f76b2d1f2f7`
- Menu SHA：`5d617e30af5743aebe62e8a2947a67f3299d69c23e8b3e0a65cef5dd75cc7639`
- Schema tree：`bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af`
- assets tree：`cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe`
- expected Flutter Test count：56
- canonical file count：307

ローカルでは26工程`make verify`と、v0.9.7→exact v0.9.10→v0.9.11のdeterministic build/verifyをPASS済み。正式なFlutter runtime/analyzer/iOS結果はcurrent Head CIだけを根拠とする。

## D2J固定条件

- D1 `compact` role（iPhone SE相当）1台
- content-size category：`accessibility-extra-large`
- Simulator erase／boot後ごとにDynamic Type setterを適用し、setter、help、queryをArtifact保存
- D2A／D2D／D2E／D2G既存導線を同じ拡大文字状態で再利用
- 必須画面：intro、基本情報、メニュー、実施、マイページ
- drive logの`RenderFlex overflow`、Rendering Library exception、ErrorWidgetは自動FAIL
- startup infrastructure failureのみ「test開始前かつPNG 0枚」で最大1回再試行。product/assertion/layout failureは再試行しない

## 正式受入条件

同一current Headで以下をすべて要求する。

1. Task20-B2 ZIP Integration terminal SUCCESS
2. Task20-B2 iOS ZIP Integration terminal SUCCESS
3. Task20-D2J iOS Dynamic Type Acceptance terminal SUCCESS
4. current Head標準iOSでD2I回帰を含む既存受入群がSUCCESS
5. C3 Analyzer / C4 dependency gate SUCCESS
6. v0.9.10／v0.9.11 ZIP SHAがArtifactと固定値に一致
7. D2J `result.json`／log／Dynamic Type setter証跡／PNG SHA-size監査
8. D2J全PNGを目視し、blank、ErrorWidget、overflow、切れ、重なり、操作不能表示なし

ここまで満たした場合だけD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。

## 判定境界

D2J PASS後も、Dynamic Type全サイズ／最大カテゴリ、D2-08 reset途中OS終了、D2-10未網羅、iPhone実機、native accessibility（VoiceOver等）は別残件。Task20-D2／Task20-B全体は未完了。PR #19はDraft／未merge、main正本v0.9.7も変更しない。
