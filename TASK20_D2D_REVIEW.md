# Task20-D2D レビュー資料

## 対象

Task20-D2のD2-04「週間メニューの作成・途中復帰」のうち、前週実績が存在しない初回週の主要導線を、iPhone 16 Pro相当とiPhone SE（第3世代）相当の2 Simulatorで自動受入する。

## 2段階実行

### Phase 1

- クリーン状態から初期登録13画面を完了
- メニューtabで「今週のメニューは未作成です」を確認
- 週間メニュー作成を開始
- 今週の予定を確認
- 睡眠状態を4、モチベーションを2へ変更
- 今週の全体負荷を「負荷を下げたい」へ変更
- 優先部位を「全身を均等にする」へ変更
- 「今週の調整方針」stepで保存完了を確認
- 証跡PNGを取得

### プロセス終了

- `flutter drive --keep-app-running`でPhase 1終了後もRunnerを起動状態に維持
- `xcrun simctl terminate`の成功を必須条件としてOSレベル終了

### Phase 2

- 同一Simulator・同一アプリデータで別の`flutter drive`工程を開始
- メニューtabの「週間メニューの作成途中です」を確認
- 「作成の続きをする」で「今週の調整方針」へ復帰
- 睡眠状態、モチベーション、全体負荷、優先部位の復元をWidget stateで確認
- メニューを生成し「メニューを確認」へ到達
- 「条件を修正して作り直す」で予定画面へ戻る
- 予定・体調・調整方針が維持されていることを確認
- 再生成後「この内容で確定」を実行
- メニューtabに曜日別メニューと「今週を調整」が表示されることを確認

## 証跡

各端末6枚、合計12枚を取得する。

- `D2D_01_adjustment_saved.png`
- `D2D_02_menu_resume_card.png`
- `D2D_03_adjustment_restored.png`
- `D2D_04_review_generated.png`
- `D2D_05_revise_schedule_preserved.png`
- `D2D_06_final_menu.png`

## 変更しない範囲

- 実装基盤v0.9.4／アプリ0.9.4+22
- `lib`／`test`の製品コード
- Schema v9／75テーブル
- Migration／Seed／assets
- D1／D2A／D2Cの既存判定

## 判定境界

D2DがPASSした場合でも、D2-04は初回週導線に限る`AUTOMATED PASS（partial）`とする。

次は未確認のまま維持する。

- 前週実績が存在する場合の「前週の振り返り」step
- 確定済み過去記録が週間再生成で遡及変更されないことのDB証跡
- D2-04以外の未完了ケース
- iPhone実機
- native accessibility

Task20-D2およびTask20-B全体は未完了のまま維持する。
