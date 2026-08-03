# Task20-D2H レビュー資料

## 対象

Task20-D2のD2-08「強制終了・再起動」の残件から、作成済み週間メニュー、記録済みトレーニング・身体測定、保存済みトレーニング設定を、OSレベルのプロセス終了後に同一Simulator・同一アプリデータで再読込する。

対象正本は実装基盤v0.9.7／アプリ0.9.7+25、Schema v9／75テーブル。製品コード、Schema、Migration、Seed、assetsは変更せず、integration-test overlay、runner、CI接続、証跡だけを追加する。

## 2段階実行

### Phase 1

1. クリーン状態から初期登録と初回週メニュー確定を行う
2. トレーニングを1セット記録し、2種目目で途中終了する
3. 体重65.4kg・体脂肪率18.7%をUIから保存する
4. マイページで主目的を「筋力を高めたい」へ変更して保存する
5. RecordsRepository、TrainingSettingsRepository、AppDatabaseで永続化値を確認する
6. `flutter drive --keep-app-running`終了後に`xcrun simctl terminate`でOSレベル終了する

### Phase 2

1. 同一Simulator・同一アプリデータで別の`flutter drive`を開始する
2. ホームへ復帰し、例外・空白・overflowがないことを確認する
3. 作成済み週間メニューと「今週を調整」を確認する
4. 記録Dashboardで1セッション・1セット、65.4kg・18.7%を確認する
5. マイページで保存済みの「筋力を高めたい」を確認する
6. Repository／DB再読込値がPhase 1と一致することを確認する

## 証跡

各端末6枚、合計12枚を取得する。

- `D2H_01_measurement_saved.png`
- `D2H_02_settings_saved.png`
- `D2H_03_home_after_restart.png`
- `D2H_04_menu_after_restart.png`
- `D2H_05_records_after_restart.png`
- `D2H_06_settings_after_restart.png`

## 判定境界

PASS時は次を更新候補とする。

- D2-06：記録後再起動を確認範囲へ追加
- D2-07：設定保存後再起動を確認範囲へ追加
- D2-08：現在列挙されている作成済みメニュー、記録入力後、設定保存後を自動確認
- D2-10：D2Hで確認した通常／小型画面範囲を追加

D2-08以外の未確認分岐、D2-11、iPhone実機、Dynamic Type詳細、native accessibilityは未完了のまま維持する。Task20-D2およびTask20-B全体も未完了とする。
