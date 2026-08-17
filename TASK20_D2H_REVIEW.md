# Task20-D2H レビュー資料

## 対象

Task20-D2のD2-08「強制終了・再起動」の残件から、作成済み週間メニュー、記録済みトレーニング・身体測定、保存済みトレーニング設定を、OSレベルのプロセス終了後に同一Simulator・同一アプリデータで再読込する。

対象正本は実装基盤v0.9.7／アプリ0.9.7+25、Schema v9／75テーブル。製品コード、Schema、Migration、Seed、assetsは変更せず、integration-test overlay、runner、CI接続、レビュー資料、証跡メタデータだけを追加・是正する。

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

## CI・証跡の扱い

- 2026-08-03のhead `7fb33b97051f591e7da475417102eaf28f083d0d`に紐づくiOS run #174はGitHub API上で正常な終端SUCCESSを確認できず、最終証跡として採用しない。
- 後続head `12671ff97585ead9e1d10c21c3dcd9d5c9c875e0`ではFlutter #188がPASSし、iOS #175でD2H本体が通常／小型SimulatorともPASSした。ただしD2H `result.json` の`verified_cases`でD2-08だけ`D2-08`と表現され、D2-08全体PASSと誤読できる不整合が残っていたため、このheadも最終証跡にはしない。
- head `6e7a029e58cd933c0f52bc43d880b29588672a62`で、証跡ラベルのみ`D2-08`から`D2-08-partial`へ是正した。製品コード、テスト操作、Schema、Migration、Seed、assets、v0.9.7固定ZIPは変更していない。
- 同headではFlutter #189がSUCCESSし、iOS #176も検証を開始したが、本レビュー資料の整合性是正によりさらに新しいheadが発行される。このため#189／#176も最終判定の参考となる先行証跡に留める。
- D2Hの正式判定には、**このレビュー資料是正後の最新headに紐づくFlutter／iOS CIだけ**を使用する。過去headの部分成功を最新headの成功へ読み替えない。

## 判定境界

最新headのFlutter共通CIと、D2Hおよび既存回帰を含むiOS CIが終端SUCCESSした場合に限り、次を正式な確認範囲へ追加する。

- D2-06：記録済みセッション／セットのOSレベル終了後再読込を`AUTOMATED PASS（partial）`の確認範囲へ追加する。
- D2-07：保存済み主目的設定のOSレベル終了後再読込を`AUTOMATED PASS（partial）`の確認範囲へ追加する。
- D2-08：作成済み週間メニュー、記録済みセッション／セット、身体測定、保存済み設定の再起動ケースを`AUTOMATED PASS（partial）`の確認範囲へ追加する。D2-08全体PASSとはしない。
- D2-10：D2Hで確認した通常サイズ／小型サイズの画面範囲を`AUTOMATED PASS（partial）`へ追加する。

次は未完了のまま維持する。

- D2-08のその他の中断状態、休憩タイマー、日付またぎ等の未確認分岐
- D2-09の匿名ID旧新差分、削除／保持対象の完全確認、初期化直後再起動等の残件
- D2-10の未網羅画面、キーボード、全ダイアログ、横スクロール等
- D2-11文字拡大
- iPhone実機
- Dynamic Type詳細
- native accessibility
- Task20-D2全体
- Task20-B全体

PR #17は最新headの全必須CI・証跡が揃うまでDraft／未マージを維持し、部分自動受入を全体完了へ拡張しない。
