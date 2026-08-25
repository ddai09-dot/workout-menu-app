# Task20-D2J レビュー資料

## 現在判定

Task20-D2のD2-11「文字拡大」をGitHub-hosted iOS Simulatorで自動確認する。受入条件は実装に合わせて緩和しない。main正本はv0.9.7 / v0.9.7+25のまま、PR #19はDraft／未mergeを維持する。

- D2H：current scope受入済み。
- D2I：定義済みGitHub-hosted iOS Simulator範囲で`AUTOMATED PASS`。
- D2J：未PASS。v0.9.18ではharness reachability修正後の必須PNG目視監査で、`accessibility-extra-large`時にオンボーディングの`ニックネーム（必須）`がOutlined TextFormFieldのfloating label内で切れる製品UI不具合を確認した。自動テストの技術的成功だけでは受入とせず、必須画面の視認性条件違反としてNGにした。
- Task20-D2／Task20-B全体：未完了。

## 正本系譜

- main：v0.9.7 / v0.9.7+25
- D2I accepted：v0.9.10 / v0.9.10+28
- v0.9.11 / +29：ZIP `cd0781aa74b6be26aaf990ceb6e01a02064bb2ca0688e56d1bc603a8f95114ca`
- v0.9.12 / +30：ZIP `a1a2c89d73324a72d10a1d9b8a50bc896cf358f71a7c5dc485b8c3bd4faeb2a3`
- v0.9.13 / +31：ZIP `d6b0016b669bde9091294c52d7c138ce964d90515b3dd42320bac784f3eef586`
- v0.9.14 / +32：local-only immutable、ZIP `57c3df06f4cde4a96cb630a614374d52a7424cda5a8fef2ab5ec4535d9592ab0`
- v0.9.15 / +33：ZIP `ccf69d61ee4f98e7c3a0e8926ab42c53cf868f133303d573b1d30896d6119b60`
- v0.9.16 / +34：ZIP `e9e5d5f87eba8bde626bd14f7e2de6535f608edaa5cd1bac84b63b43e4040644`
- v0.9.17 / +35：ZIP `969ccdf461d90a0936bce11050930b339d7bb50d6b879830b56d15f633560b2c`
- v0.9.18 / +36：ZIP `9d1c765ec0dcefb15170516e45ee93492bb775e00e75bf2f4f94db67edb90f82`
- current candidate：v0.9.19 / v0.9.19+37、ZIP `94590c894063c6fac75a8db766ea2d0aa6bfe30842428e578f96e7094d614b0e`

## v0.9.19修正

`ニックネーム（必須）`をTextFormFieldの`labelText`から外し、入力欄の直前に通常Textとして配置する。これにより拡大文字時にfloating labelの狭い領域へ押し込まず、必要に応じて折り返せる。入力ヒント、最大30文字、unit/widget test、Schema、Migration、Seed、assetsはv0.9.18から変更しない。製品`lib`のみ意図したUI変更を含む。

## 正式受入条件

PR #19最新exact Headで以下をすべて要求する。

1. Flutter／standard iOS／D2Jの3 CI terminal SUCCESS
2. standard iOSでD2H current-candidate regression、D2I、D2A/C/D/E/F/G SUCCESS
3. C3 analyzer / C4 dependency gate SUCCESS
4. v0.9.10/11/12/13/15/16/17/18/19 ZIP SHA固定値一致
5. D2I/D2H/D2J result・log・metadata・Dynamic Type setter・PNG SHA/size監査
6. D2J必須PNG全件目視でblank／ErrorWidget／overflow／切れ／重なり／操作不能なし。特に`D2J_02_basic_info_large.png`の`ニックネーム（必須）`が欠けずに読めること

満たした場合のみD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。D2J PASS後もDynamic Type全サイズ／最大カテゴリ、D2-08残件、D2-10未網羅、iPhone実機、native accessibilityは別残件。PR #19はDraft／未merge、main正本v0.9.7も変更しない。
