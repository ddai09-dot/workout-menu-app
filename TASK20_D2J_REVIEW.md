# Task20-D2J レビュー資料

## 現在判定

Task20-D2のD2-11「文字拡大」をGitHub-hosted iOS Simulatorで自動確認する。受入条件は実装に合わせて緩和しない。main正本はv0.9.7 / v0.9.7+25のまま、PR #19はDraft／未mergeを維持する。

- D2H：current scope受入済み。
- D2I：定義済みGitHub-hosted iOS Simulator範囲で`AUTOMATED PASS`。
- D2J：未PASS。v0.9.22で前回の右162px overflow修正後、Dynamic Type #80はD2A／D2D／D2EをPASSし、D2G終盤の端末内データ初期化画面で`削除されないもの`を通常waitだけで待ったためlazy/scroll範囲外となりtimeoutした。製品overflow再発ではなくharnessの拡大文字スクロール不足と分類し、対象文言を既存`scrollToTextD2G`で実際に到達してから後続判定するよう修正した。最新exact Headで再受入する。
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
- v0.9.20 / +38：ZIP `d94fd5cc83cabef0b9b0949961175f2f6421bf7d54981e746dcd02635c68469f`
- v0.9.21 / +39：ZIP `678d2e00c4d52b324be18c4b266e6eda49a51478b4e732456ebc0c32bf4a6447`
- current candidate：v0.9.22 / v0.9.22+40、ZIP `714b56ed1f074f22a500932719d75398ecfbc1c853da74e01eda85c4601fa6eb`

## v0.9.21再受入で判明した2点

### D2G製品UI overflow

Dynamic Type #68 attempt 1はD2A／D2D／D2Eを通過し、D2Gで肩の痛み・制限を追加して保存後、healthy-frame確認で`A RenderFlex overflowed by 162 pixels on the right.`を再検出した。failure Artifact ID `9596186360`、digest `sha256:6bc2f54dca253b4fec618e11467f0d2fc2a55eb66e937e8b81fdb6b23838ff75`。

肩を選択すると追加表示される`DropdownButtonFormField`が拡大文字時の横幅制約に未対応だったため、v0.9.22では`isExpanded: true`と`itemHeight: null`を設定する。D2G harnessにも肩選択直後の`expectHealthyFrame`を追加し、保存後まで例外を持ち越さず発生箇所を前倒し検出する。

### D2E画面遷移同期

Dynamic Type #68 attempt 2はD2A／D2DをPASS。D2E attempt 1はdebug接続timeout、warm retry後のattempt 2ではホームの`今日やること`出現まで到達したが、遷移アニメーション中に旧画面`終了後の記録`が一時的に残る状態で既存不在assertを即時実行して停止した。

v0.9.22では受入条件を変更せず、ホーム文言の出現後に遷移元`終了後の記録`が消えるまで最大10秒待機してから、既存の`findsNothing` assertionを実行する。

## v0.9.22再受入で判明したharness不足

Dynamic Type #80はcanonical rebuild、Task20-B iOS checks、D1、D2A、D2D phase1/phase2、D2EをPASSした。D2Gでも前回の右162px overflowは再発せず終盤の端末内データ初期化画面まで到達したが、`削除されないもの`を`waitForText`だけで待ったため、`accessibility-extra-large`で下方に押し出されたlazy childを生成・到達できずtimeoutした。

D2Gでは直後に`端末内データを削除`へ`scrollToTextD2G`を使っており、この画面自体はスクロール可能な設計である。受入文言やassertionを削除せず、`削除されないもの`も同じ既存スクロールヘルパーで実際に到達してから後続の削除ボタン無効判定へ進むようharnessのみ修正する。

## v0.9.22修正

- 痛み・身体上の制限の選択後Dropdownを`isExpanded: true`／`itemHeight: null`へ変更する。
- D2Gは肩選択直後にも`メニューでの扱い`／`負荷を下げる`を確認し、`expectHealthyFrame`を実行する。
- D2Eはホーム遷移後、遷移元文言の消失待ちを追加してから既存不在assertを維持する。
- D2G端末内データ初期化画面は`削除されないもの`を`scrollToTextD2G`で到達確認し、既存の削除ボタン無効判定を維持する。
- 56件の既存unit/widget test、Schema v9／75テーブル、Migration、Seed、assetsはv0.9.21から変更しない。
- v0.9.22 ZIPは親v0.9.21から決定的再構築し、SHA-256 `714b56ed1f074f22a500932719d75398ecfbc1c853da74e01eda85c4601fa6eb`へ固定する。
- 保存済みpatch payloadのSHAは`a182569ec8020758f7d442758b1275ea0ad8d39535ee2d4117b5bb1fb48605b4`。v0.9.21 builderがweekly trace証跡JSONを`0.9.21+39`へ再生成してからv0.9.22 patchを適用するため、その1行だけ実行時に正規化したeffective patch SHAを`248b0c8fa774efb35f648b07a3439bb9b1a458f7fcd9a31a4b11150934338c35`へ固定する。正規化後の出力tree／ZIPはローカル再現で上記v0.9.22固定値と一致済み。
- この文書更新を含む最新exact Headの3 CIとArtifact／PNG監査が完了するまではD2J／D2-11をPASSにしない。

## 正式受入条件

PR #19最新exact Headで以下をすべて要求する。

1. Flutter／standard iOS／D2Jの3 CI terminal SUCCESS
2. standard iOSでD2H current-candidate regression、D2I、D2A/C/D/E/F/G SUCCESS
3. C3 analyzer / C4 dependency gate SUCCESS
4. v0.9.10/11/12/13/15/16/17/18/19/20/21/22 ZIP SHA固定値一致
5. D2I/D2H/D2J result・log・metadata・Dynamic Type setter・PNG SHA/size監査
6. D2J必須PNG全件目視でblank／ErrorWidget／overflow／切れ／重なり／操作不能なし。特に`D2J_02_basic_info_large.png`、D2Gの痛み・制限設定画面、確認Dialog、保存後My Page、端末内データ初期化画面を確認する

満たした場合のみD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。D2J PASS後もDynamic Type全サイズ／最大カテゴリ、D2-08残件、D2-10未網羅、iPhone実機、native accessibilityは別残件。PR #19はDraft／未merge、main正本v0.9.7も変更しない。
