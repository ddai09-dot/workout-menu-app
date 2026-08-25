# Task20-D2J レビュー資料

## 現在判定

Task20-D2のD2-11「文字拡大」をGitHub-hosted iOS Simulatorで自動確認する。受入条件は実装に合わせて緩和しない。main正本はv0.9.7 / v0.9.7+25のまま、PR #19はDraft／未mergeを維持する。

- D2H：PR #17 exact Head `84dccd8f65f71ddce0c0201294bf648372c4de51`でcurrent scope受入済み。
- D2I：PR #18 exact Head `e48a66ee8cb3f23ba9ed69607c71f574fe1c508e`、Flutter #214／iOS #201 SUCCESS。定義済みGitHub-hosted iOS Simulator範囲で`AUTOMATED PASS`。
- D2J：未PASS。PR #19 Head `90d1bfd37fb3ea356b1b3558342e1ffe6b148205`ではFlutter #256 SUCCESS、Dynamic Type #42 FAIL、standard iOS #243は終端待ち。
- Task20-D2／Task20-B全体：未完了。

## 正本系譜

- main：v0.9.7 / v0.9.7+25
- D2I accepted：v0.9.10 / v0.9.10+28
- D2J failed：v0.9.11 / v0.9.11+29
- D2J failed：v0.9.12 / v0.9.12+30
- D2J product-layout fix：v0.9.13 / v0.9.13+31、ZIP `d6b0016b669bde9091294c52d7c138ce964d90515b3dd42320bac784f3eef586`
- v0.9.14 / v0.9.14+32：local-only immutable candidate。ZIP `57c3df06f4cde4a96cb630a614374d52a7424cda5a8fef2ab5ec4535d9592ab0`。GitHub formal lineageへ混入させず別SHAで上書きしない。
- v0.9.15 / v0.9.15+33：ZIP `ccf69d61ee4f98e7c3a0e8926ab42c53cf868f133303d573b1d30896d6119b60`。Head `90d1bfd3...`でFlutter #256 SUCCESS、Dynamic Type #42 FAIL。
- next candidate：v0.9.16 / v0.9.16+34。製品`lib`／unit・widget test／Schema／Migration／Seed／assetsはv0.9.15から不変。ZIP `e9e5d5f87eba8bde626bd14f7e2de6535f608edaa5cd1bac84b63b43e4040644`。

## Head `90d1bfd3...` の結果

- Flutter #256：SUCCESS。56/56、C3、C4、Artifact監査PASS。
- Dynamic Type #42：FAIL。D2A／D2DとD2Eの旧停止点`この内容で開始する`を通過後、セッション画面の画面外`セット完了`をWidget生成前に直接assertして0件停止。製品側に対象操作は存在し、新規RenderFlex overflow／ErrorWidgetは確認されていないため追加のharness lazy-widget reachability defectと分類する。
- standard iOS #243：終端待ち。結果確定前にPR branchを動かさず、D2G compact修正の証跡を保持する。

## v0.9.16修正

D2Eで画面外になり得る`セット完了`と`未完了の理由`をscrollで生成・可視化した後に既存assertを行う。assertion自体、後続tap、文言、Dynamic Type category、retry policy、製品保存／遷移ロジックは変更しない。

正本文書に残っていた`D2-09残件`と、D2-05〜D2-07全体が未確認と読める表現も、既受入範囲を変えずに是正する。

## 正式受入条件

PR #19の最新Headに紐づく以下をすべて要求する。

1. Flutter／standard iOS／D2Jの3 CI terminal SUCCESS
2. standard iOSでD2H current-candidate regression、D2I、D2A/C/D/E/F/G SUCCESS
3. C3 analyzer / C4 dependency gate SUCCESS
4. v0.9.10/11/12/13/15/16 ZIP SHA固定値一致
5. D2I/D2H/D2J result・log・metadata・Dynamic Type setter・PNG SHA/size監査
6. D2J必須PNG全件目視でblank／ErrorWidget／overflow／切れ／重なり／操作不能なし

満たした場合のみD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。D2J PASS後もDynamic Type全サイズ／最大カテゴリ、D2-08残件、D2-10未網羅、iPhone実機、native accessibilityは別残件。PR #19はDraft／未merge、main正本v0.9.7も変更しない。
