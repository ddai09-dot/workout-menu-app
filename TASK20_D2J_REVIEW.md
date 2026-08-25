# Task20-D2J レビュー資料

## 現在判定

Task20-D2のD2-11「文字拡大」をGitHub-hosted iOS Simulatorで自動確認する。受入条件は実装に合わせて緩和しない。main正本はv0.9.7 / 0.9.7+25のまま、PR #19はDraft／未mergeを維持する。

- D2H：PR #17 exact Head `84dccd8f65f71ddce0c0201294bf648372c4de51`でcurrent scope受入済み。
- D2I：PR #18 exact Head `e48a66ee8cb3f23ba9ed69607c71f574fe1c508e`、Flutter #214／iOS #201 SUCCESS。定義済みGitHub-hosted iOS Simulator範囲で`AUTOMATED PASS`。
- D2J：未PASS。PR #19の直前Head `2888575f573312a70de285ce8a6eb18d0274ed23`ではFlutter #253 SUCCESS、standard iOS #240 FAIL、Dynamic Type #39 FAIL。
- Task20-D2／Task20-B全体：未完了。

## 正本系譜

- main：v0.9.7 / 0.9.7+25
- D2I accepted：v0.9.10 / 0.9.10+28
- D2J failed：v0.9.11 / 0.9.11+29
- D2J failed：v0.9.12 / 0.9.12+30
- D2J product-layout fix：v0.9.13 / 0.9.13+31、ZIP `d6b0016b669bde9091294c52d7c138ce964d90515b3dd42320bac784f3eef586`
- v0.9.14 / 0.9.14+32：ローカルのみで固定したdocs/evidence consistency候補。ZIP `57c3df06f4cde4a96cb630a614374d52a7424cda5a8fef2ab5ec4535d9592ab0`。GitHub未反映のまま履歴固定し、別SHAで再作成しない。
- current candidate：v0.9.15 / 0.9.15+33。v0.9.13の製品`lib`／test／Schema／Migration／Seed／assetsを保持し、文書整合性と受入harnessのみ修正する。

## 既存D2J failure履歴

- #3：Home TodayAction 192px下overflow。製品layout failure。
- #10：Menu empty state 121px下overflow＋CTA off-screen。製品layout failure。
- #21/#22：週間予定74px右overflow。v0.9.12でresponsive stackingを導入。
- #32：D2E開始前CTAを画面外まで探索しないharness defect。製品failureにはしない。
- #33：D2E pain sheet 39px右overflow。製品layout failure。v0.9.13で対象2 Dropdownへ`isExpanded: true`を追加。

## standard iOS証跡transport履歴

- #234：D2I compact phase2 test自体はPASSしたがmetadata stdout transport欠落。
- #235：D2H compactの複数finder一致によるharness target ambiguity。
- #237：D2H regular/compact PASS後、D2I `reportData`代入で`screenshots`を上書きしPNG欠落。既存`reportData`を保持してmetadataを追加する方式へ修正。

## exact Head `2888575f...` の終端結果

### Flutter #253

SUCCESS。v0.9.13 deterministic package、56 tests、C3 analyzer、C4 dependency等を通過。

### Dynamic Type #39 / run `32335444802`

FAIL。D2J enlarged-textはD2E調整導線まで到達し、直前の39px RenderFlex overflow再発は検出されなかった。その後`この内容で開始する`で`Timed out waiting to tap`。

対象画面は縦スクロールで、拡大文字時にCTAがListViewの未生成領域へ移動する。従来`tapFinder`はfinderが生成されるまで待つだけで、finder生成に必要なスクロールを行わないため停止した。製品layout/assertion failureではなくharness lazy-widget reachability defectと分類する。

### standard iOS #240 / run `32335444799`

FAIL。regular D2GはPASS。compact D2Gで`端末内データを削除`を`scrollToTextD2G`が生成前にfinderへ要求し0件で停止した。同じく遅延生成Widget探索のharness defect。D2H/D2Iの既存受入条件は変更しない。

## v0.9.15 harness修正

製品`lib/`は変更しない。

- `task20_d2d_test_support.dart`：tap対象がまだWidget treeへ生成されていない場合、visible vertical Scrollableをforward方向へ段階的にdragし、target生成後に従来どおり`ensureVisible`＋tapする。
- `task20_d2g_test_support.dart`：対象Textの存在をscroll前提にせず、選択したvisible vertical Scrollableをforward探索し、対象がそのScrollable配下へ生成された時点で`ensureVisible`する。
- assertion、文言、Dynamic Type category、retry policy、製品保存／遷移ロジックは変更しない。

## v0.9.15 canonical固定値

- parent canonical：v0.9.13 / 0.9.13+31
- ZIP SHA-256：`ccf69d61ee4f98e7c3a0e8926ab42c53cf868f133303d573b1d30896d6119b60`
- product `lib` tree：`28299d8a1c9519594fdafc605406da791ee7bd3c5a1b10b0d793c86e88ed1e65`
- test tree：`878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5`
- runtime (`lib` + `test`)：`9fb2b589aed40c043ec94ce0cfce877f723572f36786c4c87fcb4082a970cd69`
- Schema tree：`bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af`
- assets tree：`cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe`
- expected Flutter tests：56
- canonical files：306

ローカルでcanonical docs/evidence候補は26/26 static verifier PASS。v0.9.15 ZIPは3回再生成して同一SHA `ccf69d61...`。v0.9.13→v0.9.15 patch replayも一致。正式判定はGitHub exact current HeadのCI／Artifactのみを使う。

## D2J固定条件

- D1 `compact` role（iPhone SE相当）1台
- content-size category：`accessibility-extra-large`
- Dynamic Type setter/help/queryをArtifact保存
- D2A／D2D／D2E／D2G主要導線を同じ拡大文字状態で再利用
- `RenderFlex overflow`、Rendering Library exception、ErrorWidgetは自動FAIL
- startup infrastructure failureのみ既定条件で最大1回clean retry。product/assertion/layout failureは再試行しない

## 正式受入条件

同一exact current Headで以下をすべて要求する。

1. Task20-B2 ZIP Integration terminal SUCCESS
2. Task20-B2 iOS ZIP Integration terminal SUCCESS
3. Task20-D2J iOS Dynamic Type Acceptance terminal SUCCESS
4. standard iOSでD2H current-candidate regression、D2I、既存D2A/C/D/E/F/G SUCCESS
5. C3 analyzer / C4 dependency gate SUCCESS
6. v0.9.10／11／12／13／15 ZIP SHA固定値一致（v0.9.14はGitHub未反映のlocal-only履歴なのでformal lineageへ混入させない）
7. D2I／D2H／D2J result・log・metadata・Dynamic Type setter・PNG SHA/sizeをArtifact監査
8. D2J必須PNG全件目視でblank／ErrorWidget／overflow／切れ／重なり／操作不能なし

ここまで満たした場合だけD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。

## PASS後も残る範囲

Dynamic Type全サイズ／最大カテゴリ、D2-08 reset途中OS終了、D2-10未網羅、iPhone実機、native accessibility（VoiceOver等）。Task20-D2／Task20-B全体は未完了。PR #19はDraft／未merge、main正本v0.9.7も変更しない。
