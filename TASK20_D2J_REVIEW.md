# Task20-D2J レビュー資料

## 現在判定

Task20-D2のD2-11「文字拡大」をGitHub-hosted iOS Simulatorで自動確認する。受入条件は実装に合わせて緩和しない。main正本はv0.9.7 / v0.9.7+25のまま、PR #19はDraft／未mergeを維持する。

- D2H：current scope受入済み。
- D2I：定義済みGitHub-hosted iOS Simulator範囲で`AUTOMATED PASS`。
- D2J：未PASS。v0.9.17のDynamic Type #46はD2A／D2DをPASSし、D2Eも開始・セット完了・休憩画面まで到達したが、拡大文字時に画面外`休憩を終了する`が未生成のため条件分岐からスキップされ、休憩状態のまま`次の種目へ`を探索してFAILした。Artifact／画面／製品`_RestView`の状態遷移を突合し、製品不具合ではなくharness reachability defectと判定した。
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
- v0.9.17 / v0.9.17+35：ZIP `969ccdf461d90a0936bce11050930b339d7bb50d6b879830b56d15f633560b2c`
- current candidate：v0.9.18 / v0.9.18+36、ZIP `9d1c765ec0dcefb15170516e45ee93492bb775e00e75bf2f4f94db67edb90f82`

## v0.9.17 Head結果

- Flutter #260：SUCCESS。
- Dynamic Type #46：D2A／D2DをPASS。D2Eは`この内容で開始する`、`セット完了`、`D2E_05_rest`まで到達後、`休憩を終了する`が画面外未生成のため既存条件分岐からスキップされ、`次の種目へ`で停止。
- #46 Artifactは保存・診断済み。D2Jは未PASS。

## v0.9.18修正

`休憩を終了する`を明示scroll・存在確認・tapした後、`次の種目へ`もscroll・存在確認・tapする。受入条件、文言、製品`lib`、unit/widget test、Schema、Migration、Seed、assetsはv0.9.17から変更しない。

## 正式受入条件

PR #19最新exact Headで以下をすべて要求する。

1. Flutter／standard iOS／D2Jの3 CI terminal SUCCESS
2. standard iOSでD2H current-candidate regression、D2I、D2A/C/D/E/F/G SUCCESS
3. C3 analyzer / C4 dependency gate SUCCESS
4. v0.9.10/11/12/13/15/16/17/18 ZIP SHA固定値一致
5. D2I/D2H/D2J result・log・metadata・Dynamic Type setter・PNG SHA/size監査
6. D2J必須PNG全件目視でblank／ErrorWidget／overflow／切れ／重なり／操作不能なし

満たした場合のみD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。D2J PASS後もDynamic Type全サイズ／最大カテゴリ、D2-08残件、D2-10未網羅、iPhone実機、native accessibilityは別残件。PR #19はDraft／未merge、main正本v0.9.7も変更しない。
