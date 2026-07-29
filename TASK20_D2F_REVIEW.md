# Task20-D2F レビュー資料

## 対象

Task20-D2のD2-06「記録・進行」のうち、直前セッションの記録反映、履歴詳細、種目別推移、身体測定の追加、提案がない場合の表示を、通常サイズ／小型サイズの2 iOS Simulatorで自動受入する。

対象正本はmain上の実装基盤v0.9.5／アプリ0.9.5+23、Schema v9／75テーブルとする。製品コード、Migration、Seed、assetsは変更しない。

## 実行導線

1. クリーン状態から初期登録と初回週メニュー確定を行う
2. プッシュアップを1セット完了し、2種目目で途中終了する
3. 終了後評価を保存してホームへ戻る
4. 記録Dashboardで今週、直近30日、最近のトレーニングを確認する
5. トレーニング履歴とセッション詳細を開く
6. 種目別一覧とプッシュアップの同一系列推移を開く
7. 体重65.4kg・体脂肪率18.7%を追加する
8. 測定履歴とDashboardの最新値への反映を確認する
9. 次回調整提案の空状態を確認する

UI表示だけでなく、同一ProviderScopeのRecordsRepositoryからセッション、セット、種目系列、身体測定の保存値を再読込して照合する。

## 証跡

各端末8枚、合計16枚を取得する。

- `D2F_01_dashboard_recorded.png`
- `D2F_02_history.png`
- `D2F_03_session_detail.png`
- `D2F_04_exercise_list.png`
- `D2F_05_exercise_detail.png`
- `D2F_06_measurement_saved.png`
- `D2F_07_dashboard_measurement.png`
- `D2F_08_proposals_empty.png`

## 判定境界

PASS時もD2-06は`AUTOMATED PASS（partial）`とする。次は未確認のまま維持する。

- 後続の週間メニュー再生成後も確定済み履歴が変化しないこと
- 身体測定訂正時の旧記録void／新記録supersedes契約
- 提案が存在する場合の採用・維持・保留・拒否
- 器具・バリエーション・左右が異なる複数系列の分離
- 記録入力後の強制終了・再起動
- iPhone実機、Dynamic Type、native accessibility

Task20-D2およびTask20-B全体は未完了とする。
