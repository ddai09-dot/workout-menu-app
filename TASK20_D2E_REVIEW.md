# Task20-D2E レビュー資料

## 対象

Task20-D2のD2-05「トレーニング開始・調整・実施・終了」の主要導線を、iPhone 16 Pro相当とiPhone SE（第3世代）相当の2 Simulatorで自動受入する。

対象正本は実装基盤v0.9.5／アプリ0.9.5+23とする。v0.9.4はTask20-D2B完了時点の履歴証跡として変更しない。

## run #73で検出した実装不整合

週間メニュー確定後、画面状態には生成時の`WeeklyMenuPlan`が残っていた一方、DB保存時には`workout_day_plan.id`が新規発行されていた。その結果、確定直後に表示される「開始」がDBに存在しない生成時`dayPlanId`を渡し、`WorkoutRepository.loadLaunchSummary`が`The selected workout day is not available.`で停止した。

v0.9.5では、`WeeklyPlannerNotifier.finalize()`が保存完了後にactiveかつ`FINALIZED`のPlanをDBから再読込し、永続化されたdayPlanIdを画面状態へ設定する。再読込できない場合や状態が`FINALIZED`でない場合は確定成功として扱わない。

## 実行導線

1. クリーン状態から初期登録13画面を完了する
2. 初回週の週間メニューをUIで作成・確定する
3. 確定直後の画面から予定日の「開始」を押す
4. 「開始前の確認」で種目・セット数・安全案内を確認する
5. 「今日の状態を調整」で利用時間、疲労、痛み対応を入力する
6. 痛み対応が診断ではなく、ユーザーが安全側の行動を選ぶUIであることを確認する
7. セッションを開始し、種目・目標値・セット入力を確認する
8. 「フォームを確認」を開き、画像未準備でもテキスト説明が成立することを確認する
9. 最初の種目を1セットへ変更し、セット完了を記録する
10. 休憩を終了し、次の種目へ進む
11. 「途中で終了」で完了済みセットを保持したまま終了後評価へ進む
12. 未完了理由を入力し、「記録して終了」でホームへ戻る

## 診断と受入の境界

run #73の原因特定用に、画面ルートから得た`dayPlanId`を同一ProviderScopeのRepositoryへ渡す診断assertionを追加している。これは原因を明確化する補助証跡であり、UI導線の代替ではない。最終PASSには、Repository診断だけでなく、開始前画面、調整、セッション、フォーム説明、休憩、次種目、終了後評価、ホーム復帰の全UI操作成功を必須とする。

## 証跡

各端末8枚、合計16枚を取得する。

- `D2E_01_start_check.png`
- `D2E_02_adjustment.png`
- `D2E_03_session.png`
- `D2E_04_form_fallback.png`
- `D2E_05_rest.png`
- `D2E_06_next_exercise.png`
- `D2E_07_assessment.png`
- `D2E_08_home_completed.png`

## 変更範囲

- `WeeklyPlannerNotifier.finalize()`の確定後Plan再読込
- 実装基盤v0.9.5／アプリ0.9.5+23への正本昇格
- v0.9.5決定論的生成、固定SHA、manifest、runtime変更範囲の検証
- D2E integration test overlay
- iOS Simulator runner
- CI実行とArtifact収集
- D2C／D2Dレビュー資料の判定境界是正

## 変更しない範囲

- Schema v9／75テーブル
- Migration／Seed／assets
- 週間メニュー生成ルール
- D1／D2A／D2Cの既存判定

D2Dについては、draft保存、OS終了後復帰、入力復元、生成、条件修正、画面上の確定表示のPASSを維持する。確定後PlanのDB再読込と確定直後のトレーニング開始可能性はD2Eの検証範囲とする。

## 判定境界

D2EがPASSした場合でも、D2-05は今回実行した主要導線に限る`AUTOMATED PASS（tested scope）`とする。D2-10は今回の画面範囲に限る`AUTOMATED PASS（partial）`とする。

次は未確認のまま維持する。

- トレーニング記録入力後の強制終了・再起動
- 記録tabへの反映と確定済み履歴の不変性
- 痛み対応の全分岐
- 予定した全セットを完遂する導線
- iPhone実機
- native accessibility

Task20-D2およびTask20-B全体は未完了のまま維持する。
