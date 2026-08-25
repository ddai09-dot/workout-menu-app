# Task20-D2J レビュー資料

## 現在判定

Task20-D2のD2-11「文字拡大」をGitHub-hosted iOS Simulatorで自動確認する。受入条件は実装に合わせて緩和しない。main正本はv0.9.7 / v0.9.7+25のまま、PR #19はDraft／未mergeを維持する。

- D2H：current scope受入済み。
- D2I：定義済みGitHub-hosted iOS Simulator範囲で`AUTOMATED PASS`。
- D2J：未PASS。v0.9.16 Head `3417a66be92ec8879972e2e5d66a3a05f407704c`ではFlutter #258 SUCCESS、Dynamic Type #44 FAIL。standard iOS #245はこのHeadが正式受入不能のため新Head受入へ流用しない。
- Task20-D2／Task20-B全体：未完了。

## 正本系譜

- main：v0.9.7 / v0.9.7+25
- D2I accepted：v0.9.10 / v0.9.10+28
- D2J failed：v0.9.11 / v0.9.11+29
- D2J failed：v0.9.12 / v0.9.12+30
- D2J product-layout fix：v0.9.13 / v0.9.13+31、ZIP `d6b0016b669bde9091294c52d7c138ce964d90515b3dd42320bac784f3eef586`
- v0.9.14 / v0.9.14+32：local-only immutable candidate、ZIP `57c3df06f4cde4a96cb630a614374d52a7424cda5a8fef2ab5ec4535d9592ab0`
- v0.9.15 / v0.9.15+33：ZIP `ccf69d61ee4f98e7c3a0e8926ab42c53cf868f133303d573b1d30896d6119b60`
- v0.9.16 / v0.9.16+34：ZIP `e9e5d5f87eba8bde626bd14f7e2de6535f608edaa5cd1bac84b63b43e4040644`
- current candidate：v0.9.17 / v0.9.17+35、ZIP `969ccdf461d90a0936bce11050930b339d7bb50d6b879830b56d15f633560b2c`

## v0.9.16 Head結果

- Flutter #258：SUCCESS。
- Dynamic Type #44：D2A／D2D／D2Eの`この内容で開始する`／`セット完了`を通過。休憩後、画面外`次の種目へ`を生成前に`waitForText`して停止。新規製品failureではなくharness lazy-widget reachability defectと分類する。
- #44 Artifactは保存済み。D2Jは未PASS。

## v0.9.17修正

`次の種目へ`の先行`waitForText`を削除し、既存`tapText`のscroll探索＋ensureVisible＋tapで存在・到達・操作を一体検証する。受入条件、文言、製品`lib`、unit/widget test、Schema、Migration、Seed、assetsは変更しない。

## 正式受入条件

PR #19最新exact Headで以下をすべて要求する。

1. Flutter／standard iOS／D2Jの3 CI terminal SUCCESS
2. standard iOSでD2H current-candidate regression、D2I、D2A/C/D/E/F/G SUCCESS
3. C3 analyzer / C4 dependency gate SUCCESS
4. v0.9.10/11/12/13/15/16/17 ZIP SHA固定値一致
5. D2I/D2H/D2J result・log・metadata・Dynamic Type setter・PNG SHA/size監査
6. D2J必須PNG全件目視でblank／ErrorWidget／overflow／切れ／重なり／操作不能なし

満たした場合のみD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。D2J PASS後もDynamic Type全サイズ／最大カテゴリ、D2-08残件、D2-10未網羅、iPhone実機、native accessibilityは別残件。PR #19はDraft／未merge、main正本v0.9.7も変更しない。
