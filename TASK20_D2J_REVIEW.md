# Task20-D2J レビュー資料

## 目的

Task20-D2のD2-11「文字拡大」を、既存の受入済み主要導線を再利用してGitHub-hosted iOS Simulator上で自動確認する。受入条件は実装に合わせて緩和しない。

main正本はv0.9.7のまま。D2Iの受入済み候補v0.9.10を親として、D2Jで実際に検出したHome／Menuのlayout failureだけをv0.9.11／0.9.11+29へ積む。

## 正本系譜

- main正本：v0.9.7 / 0.9.7+25
- D2I受入済み候補：v0.9.10 / 0.9.10+28、PR #18 Head `e48a66ee8cb3f23ba9ed69607c71f574fe1c508e`
- D2I：Flutter #214／iOS #201 SUCCESS。定義済みSimulator範囲でD2-09 AUTOMATED PASS
- D2J current candidate：v0.9.11 / 0.9.11+29

PR #19で一時的に使用したD2J v0.9.8表記は、PR #18ですでにv0.9.8〜v0.9.10が履歴固定されているため撤回した。既存候補を上書きしない。

v0.9.11 current builderはpayloadを持たない。クリーンなv0.9.7からPR #18でSUCCESS実績のあるD2I v0.9.8／v0.9.9／v0.9.10 builder・payloadを同じGit blobのまま使い、中間v0.9.10 ZIP SHAが受入済み値 `9fce3c9dd234fcc669ed7e5b62b8b2d612b3fa80b634bca14406cf5c6bb4836f` に一致した場合だけ、v0.9.11 builderが2画面とversion整合の限定置換を行う。

## D2J正式FAIL履歴

### D2J #3 — Home TodayAction

Head `d837ebf1cfaba0e20f990673720fd9c345e6728e` / run `32201825637`。小型Simulator＋`accessibility-extra-large`で初期登録完了後のHomeに `RenderFlex overflowed by 192 pixels on the bottom` を検出。startup failureではなく製品layout failureのため再試行せずFAIL。

Artifact ID `9348172126` / digest `sha256:cfcc99a85a040a803e45f64a04260b1fdf05ab38f97377a233ab70c2a8a0c95b`。

### D2J #10 — Menu empty state

Head `2ee85fdab5c1c67c7047072fca96d8ff13c7d3b5` / run `32206128286`。Home修正後はD2Aを完走し、旧192px overflow解消を確認。その後D2D開始時のMenu空状態で `RenderFlex overflowed by 121 pixels on the bottom` を検出し、「今週のメニューを作成する」CTAがoff-screenとなってtap不能。製品layout failureのため再試行しない。

Artifact ID `9350251863` / digest `sha256:8803c8a13d0f18e15213973784631d598ac8c679cbe24127b4c20f8a0c6b0069`。

## v0.9.11修正

受入済みv0.9.10のD2I製品修正と56件testを保持し、次の2画面だけ変更する。

1. Home TodayAction
   - `SingleChildScrollView`
   - `mainAxisSize: MainAxisSize.min`
   - `Spacer()`を`SizedBox(height: 24)`へ置換
2. Menu空状態
   - `LayoutBuilder`
   - `SingleChildScrollView`
   - `ConstrainedBox(minHeight: constraints.maxHeight)`＋`Center`
   - 通常文字では従来の中央配置を維持し、拡大時だけ必要に応じて縦スクロール

文言、CTA、遷移先、TodayAction判定、週間メニュー判定、D2J受入条件は変更しない。Schema v9／75 tables、Migration、Seed、assetsも変更しない。

## v0.9.11固定値

- accepted parent v0.9.10 ZIP SHA-256：`9fce3c9dd234fcc669ed7e5b62b8b2d612b3fa80b634bca14406cf5c6bb4836f`
- v0.9.11 ZIP SHA-256：`cd0781aa74b6be26aaf990ceb6e01a02064bb2ca0688e56d1bc603a8f95114ca`
- runtime tree (`lib` + `test`)：`3eeb5a3357ca1ec2a42f486de1b375312f1baf64bfde1682f1f38b7bc702a71e`
- product `lib` tree：`6eea4b98f6741cf7e02699cda31b8d2c5e894366e82c2b15f9c8fa287553bfdc`
- test tree：`878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5`
- Home SHA：`f18059798cba8a49f14b1792950ad70a43a9b3e414411334e70f8f76b2d1f2f7`
- Menu SHA：`5d617e30af5743aebe62e8a2947a67f3299d69c23e8b3e0a65cef5dd75cc7639`
- Schema tree：`bc1dcc6000defb6de64156e6f019056bf983bcc185cfda108c1635cb754f4af`
- assets tree：`cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe`
- expected Flutter test count：56
- canonical file count：306

ローカルではpayload-free v0.9.11で全26 static verify、v0.9.10→v0.9.11 deterministic build、product/runtime/schema/assets hash照合をPASS済み。正式なFlutter runtime/analyzer/iOS結果はcurrent Head CIだけを根拠とする。

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
4. current Head標準iOSでD2I回帰を含む既存受入群SUCCESS
5. C3 analyzer / C4 dependency gate SUCCESS
6. v0.9.10／v0.9.11 ZIP SHAがArtifactと固定値に一致
7. D2J result/log/Dynamic Type setter/PNG SHA-size監査
8. D2J全PNGを目視し、blank、ErrorWidget、overflow、切れ、重なり、操作不能表示なし

ここまで満たした場合だけD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。

## 判定境界

D2J PASS後も、Dynamic Type全サイズ／最大カテゴリ、D2-08 reset途中OS終了、D2-10未網羅、iPhone実機、native accessibility（VoiceOver等）は別残件。Task20-D2／Task20-B全体は未完了。PR #19はDraft／未merge、main正本v0.9.7も変更しない。
