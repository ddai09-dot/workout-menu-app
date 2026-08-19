# Task20-D2J レビュー資料

## 目的

Task20-D2のD2-11「文字拡大」を、既存の受入済み主要導線を再利用してGitHub-hosted iOS Simulator上で自動確認する。

D2Jは**受入ハーネスのみ**を追加する。製品`lib/`、Schema、Migration、Seed、assets、固定ZIPは変更しない。対象正本はmainの実装基盤v0.9.7／アプリ0.9.7+25、Schema v9／75テーブルとする。

## 判定対象

既存チェックリストのD2-11条件：

- 標準文字サイズ基準の網羅確認
- 拡大文字でintro、基本情報、メニュー、実施、マイページ
- 主要ボタンへの到達
- 重なり・切れ・操作不能なし

標準文字サイズは同一PR Headで既存`Task 20-B2 iOS ZIP Integration`を回帰実行し、そのSUCCESSを基準とする。D2J専用workflowでは小型Simulator 1台に拡大文字を設定し、主要導線を再実行する。

## 拡大文字の固定条件

D2Jの受入カテゴリは`accessibility-extra-large`とする。

これはiOSのaccessibility content-size categoryであり、通常サイズより明確に大きい文字環境を確認するためのD2-11固定条件とする。ただし、これはDynamic Type全カテゴリ・最大カテゴリの網羅を意味しない。

Simulator起動・erase後ごとに`simctl ui ... content_size accessibility-extra-large`を実行し、setterの成功、`simctl ui` help、query出力を証跡へ保存する。設定できない場合はD2JをPASSにしない。

## 端末

D1で選択された`compact` role（iPhone SE相当）を1台使用する。

Issue #9のD2-11完了条件は最低1端末でのPASS。小型viewportと拡大文字を組み合わせ、レイアウト負荷が高い条件を正式受入対象にする。

## 再利用する既存導線

- D2A：intro、初期登録。D2Jでは最初の「基本情報」に1枚だけ追加スクリーンショットを注入
- D2D：週間メニュー作成・復帰・最終メニュー
- D2E：トレーニング実施
- D2G：マイページ設定

テスト内容そのものをD2J用に作り直さず、既存受入導線を同じ拡大文字環境で走らせる。

## D2Jの必須画面証跡

最低限、次の5画面が拡大文字状態で存在することを要求する。

1. `D2A_01_clean_launch.png` — intro
2. `D2J_02_basic_info_large.png` — 基本情報
3. `D2D_06_final_menu.png` — メニュー
4. `D2E_03_session.png` — 実施
5. `D2G_01_my_page_sections_top.png` — マイページ

実際にはD2A/D2D/D2E/D2Gが生成する全PNGをD2J Artifactへ集約し、SHA-256／sizeを`result.json`と照合して全画面を目視確認する。

## 自動FAIL条件

- `accessibility-extra-large`をSimulatorへ設定できない
- 上記既存導線のいずれかが失敗する
- 必須5画面のいずれかが生成されない
- drive logに`RenderFlex overflow`、Rendering Library exception、ErrorWidget等のシグナルが出る
- analyzer／dependency gateが失敗する

startup infrastructure failureのみ、既存D2受入と同じく「テスト開始前かつPNG 0枚」の場合に限定して最大1回再試行できる。製品・assertion・layout failureは再試行しない。

## 正式受入条件

同一PR Headで以下がすべてterminal SUCCESSであること。

- 既存Flutter ZIP CI
- 既存Task20-B2 iOS ZIP Integration（標準文字サイズ回帰）
- D2J iOS Dynamic Type Acceptance
- D2J Artifactのresult/log/PNG/hash監査
- D2J全PNGの目視確認

ここまで満たした場合だけD2-11を`AUTOMATED PASS`へ更新する。

## 判定境界

D2J PASS後も次は別残件として保持する。

- Dynamic Typeの全サイズ／最大accessibility categoryの詳細網羅
- D2-08のreset処理途中OS終了など未検証中断状態
- D2-10の全画面、キーボード、全ダイアログ等
- iPhone実機
- native accessibility（VoiceOver等）

したがってD2J単独ではTask20-D2およびTask20-B全体を完了にしない。
