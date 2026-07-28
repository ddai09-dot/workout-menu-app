# Task20-D2C レビュー資料

## 対象

Task20-D2のD2-02「初期登録の途中保存・復帰」を、iPhone 16 Pro相当とiPhone SE（第3世代）相当の2 Simulatorで自動受入する。

## 2段階実行

### Phase 1

- クリーン起動
- ニックネームと年齢を入力
- 一番の目的、ほかの目的まで進む
- 「トレーニング経験」画面で保存完了を待つ
- `flutter drive --keep-app-running`でPhase 1終了後もRunnerを起動状態に維持
- 証跡PNGを取得

### プロセス終了

- `xcrun simctl terminate`でRunnerをOSレベル終了
- terminate成功を必須条件とし、Phase 1終了時点で既に停止している場合はFAILとする
- 再launchして終了操作を代替確認するフォールバックは行わない

### Phase 2

- 同一Simulator・同一アプリデータで再起動
- 「登録の続きがあります」を確認
- リセット確認のキャンセルでdraftが維持されることを確認
- 「続きから再開」で「トレーニング経験」へ戻ることを確認
- 戻る操作でニックネームと年齢が復元されていることを確認
- フロー内リセットのキャンセルで値が維持されることを確認
- リセット確定でintroへ戻ることを確認

## 証跡

各端末5枚、合計10枚を取得する。

- `D2C_01_saved_midway.png`
- `D2C_02_resume_prompt.png`
- `D2C_03_resumed_step.png`
- `D2C_04_values_restored.png`
- `D2C_05_reset_to_intro.png`

## 変更しない範囲

- D2C正式判定時の実装基盤v0.9.4／アプリ0.9.4+22
- `lib`／既存`test`の製品コード
- Schema v9／75テーブル
- Migration／Seed／assets
- 既存D1／D2A判定

## 判定境界

D2CがPASSした場合に完了へ追加できるのはD2-02とD2-10の該当画面範囲だけである。Task20-D2およびTask20-B全体は未完了のまま維持する。
