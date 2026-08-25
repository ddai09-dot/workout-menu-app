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

## 直前Head `2888575f...` の終端結果

- Flutter #253：SUCCESS。
- standard iOS #240：FAIL。compact D2Gで遅延生成される`端末内データを削除`をscroll前にfinderへ要求したharness reachability defect。
- Dynamic Type #39：FAIL。D2Eで遅延生成される`この内容で開始する`をfinderが待つだけでscrollできなかったharness reachability defect。
- #39では直前の39px RenderFlex overflow再発は検出されていない。両FAILとも現時点で新たな製品failureとは判定しない。

## v0.9.15修正

製品`lib/`は変更しない。D2E/D2Gの受入harnessだけを、対象Widgetが未生成でもvisible vertical Scrollableをforward探索し、生成後に`ensureVisible`して操作する方式へ修正した。assertion、文言、Dynamic Type category、retry policy、製品保存／遷移ロジックは変更しない。

v0.9.15 ZIP SHA-256：`ccf69d61ee4f98e7c3a0e8926ab42c53cf868f133303d573b1d30896d6119b60`

## current Head

PR #19の最新Headに紐づくCIだけを正式判定対象とする。3 CIすべてが終端SUCCESSし、Artifact実物監査まで完了するまではD2J／D2-11をPASSにしない。

## 正式受入条件

1. 3 CI terminal SUCCESS
2. standard iOSでD2H current-candidate regression、D2I、D2A/C/D/E/F/G SUCCESS
3. C3 analyzer / C4 dependency gate SUCCESS
4. v0.9.10/11/12/13/15 ZIP SHA固定値一致
5. D2I/D2H/D2J result・log・metadata・Dynamic Type setter・PNG SHA/size監査
6. D2J必須PNG全件目視でblank／ErrorWidget／overflow／切れ／重なり／操作不能なし

満たした場合のみD2-11を定義済み1端末／`accessibility-extra-large`範囲で`AUTOMATED PASS`へ更新する。

D2J PASS後もDynamic Type全サイズ／最大カテゴリ、D2-08 reset途中OS終了、D2-10未網羅、iPhone実機、native accessibilityは別残件。Task20-D2／Task20-B全体は未完了。PR #19はDraft／未merge、main正本v0.9.7も変更しない。

詳細：`TASK20_D2J_REVIEW.md`
関連：Issue #9
