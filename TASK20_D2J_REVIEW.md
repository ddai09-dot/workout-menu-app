# Task20-D2J レビュー資料

## 現在判定

Task20-D2のD2-11「文字拡大」をGitHub-hosted iOS Simulatorで自動確認する。受入条件は実装に合わせて緩和しない。main正本はv0.9.7 / v0.9.7+25のまま、PR #19はDraft／未mergeを維持する。

- D2H：current scope受入済み。
- D2I：定義済みGitHub-hosted iOS Simulator範囲で`AUTOMATED PASS`。
- D2J：未PASS。v0.9.19でオンボーディングの`ニックネーム（必須）`切れを修正し、D2Gのlazy-list／SnackBar hit-test系harness defectも是正したが、exact Head `216e34dbbefce3da6fdc2530b6ae22a26c670f9f`のDynamic Type #54でD2G設定編集画面に製品UIの横overflowを新たに検出した。v0.9.20で限定修正し、最新exact Headで再受入する。
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
- v0.9.19 / +37：ZIP `94590c894063c6fac75a8db766ea2d0aa6bfe30842428e578f96e7094d614b0e`
- current candidate：v0.9.20 / v0.9.20+38、ZIP `d94fd5cc83cabef0b9b0949961175f2f6421bf7d54981e746dcd02635c68469f`

## Dynamic Type #54失敗

exact Head `216e34dbbefce3da6fdc2530b6ae22a26c670f9f`のDynamic Type #54はcanonical v0.9.19再構築、Task20-B iOS checks、D1、D2A、D2DをPASSした。D2E attempt 1はFlutter debug接続startup infrastructure timeoutだったがwarm retry後のattempt 2でPASSした。

D2Gでは`D2G_05_restriction_review_prompt.png`取得後、設定保存を完了してMy Pageへ戻った段階のhealthy-frame確認で`A RenderFlex overflowed by 162 pixels on the right.`を検出した。失敗Artifact ID `9593477234`、digest `sha256:cd02e0a63e8bda2258a8294413569d95a63dc40bc3feec82c2494fa198a90fbf`。

証跡と製品構造を照合すると、設定編集AppBarが長い区分名`痛み・身体上の制限`をtitleに置き、保存中はさらに`保存中…`をactionsへ追加する構造だった。`accessibility-extra-large`で横幅制約を超えるため、harnessではなく製品UI不具合と分類する。

## v0.9.20修正

- 設定編集AppBarのtitleを短い`設定`へ固定する。
- 完全な区分名は本文先頭へ移し、通常Textとして折返し可能にする。
- 保存中表示は固定24pxの`CircularProgressIndicator`＋`Semantics(label: '保存中')`へ変更し、AppBar横幅を圧迫しない。
- 今週メニュー確認Dialogを`scrollable: true`にし、拡大文字時も本文へ到達可能にする。
- 56件の既存unit/widget test、Schema v9／75テーブル、Migration、Seed、assetsはv0.9.19から変更しない。
- v0.9.20 ZIPは親v0.9.19から決定的再構築し、SHA-256 `d94fd5cc83cabef0b9b0949961175f2f6421bf7d54981e746dcd02635c68469f`へ固定する。

## 正式受入条件

PR #19最新exact Headで以下をすべて要求する。

1. Flutter／standard iOS／D2Jの3 CI terminal SUCCESS
2. standard iOSでD2H current-candidate regression、D2I、D2A/C/D/E/F/G SUCCESS
3. C3 analyzer / C4 dependency gate SUCCESS
4. v0.9.10/11/12/13/15/16/17/18/19/20 ZIP SHA固定値一致
5. D2I/D2H/D2J result・log・metadata・Dynamic Type setter・PNG SHA/size監査
6. D2J必須PNG全件目視でblank／ErrorWidget／overflow／切れ／重なり／操作不能なし。特に`D2J_02_basic_info_large.png`の`ニックネーム（必須）`、D2G設定編集画面・確認Dialog・保存後My Pageを確認する

満たした場合のみD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。D2J PASS後もDynamic Type全サイズ／最大カテゴリ、D2-08残件、D2-10未網羅、iPhone実機、native accessibilityは別残件。PR #19はDraft／未merge、main正本v0.9.7も変更しない。
