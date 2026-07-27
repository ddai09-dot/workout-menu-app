# Task20-D2B v0.9.4 レビュー資料

## 目的

PR #10でTask20-D2Aの対象範囲が完了した後、v0.9.3候補内に残っていた古いCI番号、Flutter未実行表現、全面的なSimulator未確認表現、D2AとD2全体の判定混同を是正する。

v0.9.3はPR #10の履歴証跡として変更せず、整合性修正版をv0.9.4／0.9.4+22として生成する。

## 生成手順

1. CIで固定SHAのv0.9.1を展開する。
2. 既存builderでv0.9.2を生成・検証する。
3. 既存builderでv0.9.3を生成・検証する。
4. `tools/task20_d2b_build_canonical_v094.py`が、SHA検証済みoverlay payloadをv0.9.3へ適用する。
5. `FILE_MANIFEST.txt`を再生成する。
6. 固定timestamp／permission／圧縮条件でv0.9.4 ZIPを決定論的に生成する。
7. ZIP SHA-256が次と一致しない場合は失敗する。

`06815b331f1e21f3bb4f4c6d856b0cb616bd5f651b39706289770593d71d71c1`

## overlayで更新する主要成果物

- `README.md`
- `pubspec.yaml`
- `docs/VERSION_MATRIX.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/TASK20_A_LOCAL_DATA_RESET_AND_FLUTTER_PREFLIGHT.md`
- `docs/TASK20_B_FLUTTER_IOS_EXECUTION.md`
- `docs/TASK20_D2A_LOCAL_RESET_NAVIGATION_FIX.md`
- `docs/TASK20_D2A_COMPLETION_REPORT.md`（新規）
- `docs/DECISION_LOG.md`
- `docs/PARKING_LOT.md`
- Task19.5-C1／C2／C4の後続検証状態
- 状態を出力する一部verifier

## 変更しない資産

v0.9.3とのtree hashを固定して検証する。

- runtime（`lib`＋`test`）：`28187ee0179263daa9608272603aa603c8194cf6f5af6eaf791043239f3a7269`
- schema／migration：`bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af`
- assets：`cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe`

これらのhashが変わった場合、`tools/task20_d2b_verify_canonical_v094.py`は失敗する。

## 判定境界

完了：

- Task20-D1起動スモーク
- Task20-D2AのD2-01、D2-03、D2-09、D2-10の一部

未完了：

- D2-02
- D2-04〜D2-08
- D2-09残件
- D2-10未網羅部分
- D2-11
- iPhone実機
- VoiceOver等のnative accessibility

Task20-D2およびTask20-B全体は未完了である。

## レビュー観点

- v0.9.3を同一version・別SHAで上書きしていないか
- fixed ZIP SHAとpayload SHAがコード上で固定されているか
- overlay適用前の各source SHAと適用後のtarget SHAを検証しているか
- manifestが実ファイルと完全一致するか
- runtime／schema／assetsの不変性が検証されるか
- D2A対象範囲の完了をD2全体へ拡張していないか
- 両CIがv0.9.4を展開後にFlutter／iOS／D1／D2Aを再実行するか
