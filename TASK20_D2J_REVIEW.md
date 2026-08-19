# Task20-D2J レビュー資料

## 目的

Task20-D2のD2-11「文字拡大」を、既存の受入済み主要導線を再利用してGitHub-hosted iOS Simulator上で自動確認する。

当初は受入ハーネスのみでmain正本v0.9.7／0.9.7+25を検証したが、正式D2J runで製品レイアウト不具合を検出した。そのため現在は、v0.9.7を変更せず、必要最小限の製品修正を積んだ**正本候補v0.9.8／0.9.8+26**をD2Jおよび標準回帰で再検証する。Schemaはv9／75テーブルのまま、Migration、Seed、assetsは変更しない。

## v0.9.7で検出した正式FAIL

PR Head `d837ebf1cfaba0e20f990673720fd9c345e6728e` のTask20-D2J run #3（run `32201825637`）で、以下を確認した。

- 固定v0.9.7 SHA-256：`3ba2fc7b668437208507f5277c81861a514b3be56586e10fa6a19928cf8b77b2`
- Task20-B iOS Simulator checks：PASS
- D1：iPhone 16 Pro／iPhone SE（3rd generation）ともPASS
- iPhone SE（3rd generation）へ`accessibility-extra-large`設定：成功
- D2A：初期登録を最後まで完了し、ホームの「今日やること」表示まで到達
- ホーム表示直後のhealthy-frame確認で`A RenderFlex overflowed by 192 pixels on the bottom.`を検出
- これはstartup infrastructure failureではなく製品layout failureのため再試行せずFAIL

FAIL Artifact：ID `9348172126`、digest `sha256:cfcc99a85a040a803e45f64a04260b1fdf05ab38f97377a233ab70c2a8a0c95b`。

## v0.9.8修正内容

原因はHomeのTodayActionカードが固定viewport内の非スクロール`Column`で`Spacer()`を使用しており、拡大文字時にタイトル・説明・CTAの必要高が小型画面高を超えることだった。

v0.9.8ではHomeのTodayAction表示だけを次のように変更する。

- TodayAction領域を`SingleChildScrollView`で縦スクロール可能にする
- カード内`Column`を`mainAxisSize: MainAxisSize.min`にする
- 高さを消費する`Spacer()`を固定間隔`SizedBox(height: 24)`へ置き換える

文言、CTA、遷移先、TodayActionの判定ロジックは変更しない。Schema／Migration／Seed／assetsも変更しない。

正本候補v0.9.8の決定論的ZIP SHA-256は`3dad8b26599a12f09700e36ca6d7255a2d9c10e89b1917ff413780c1af9b1f44`。v0.9.7からのtree比較ではSchema hashとassets hashは完全一致し、runtimeだけが意図どおり変化する。

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

**v0.9.8を再構築する同一PR Head**で以下がすべてterminal SUCCESSであること。

- Flutter ZIP CI
- Task20-B2 iOS ZIP Integration（標準文字サイズ回帰）
- D2J iOS Dynamic Type Acceptance
- analyzer／dependency gate
- D2J Artifactのresult/log/PNG/hash監査
- D2J全PNGの目視確認

ここまで満たした場合だけD2-11を`AUTOMATED PASS`へ更新する。v0.9.7のFAIL runは原因・修正の監査証跡として保持し、PASS根拠には使用しない。

## 判定境界

D2J PASS後も次は別残件として保持する。

- Dynamic Typeの全サイズ／最大accessibility categoryの詳細網羅
- D2-08のreset処理途中OS終了など未検証中断状態
- D2-10の全画面、キーボード、全ダイアログ等
- iPhone実機
- native accessibility（VoiceOver等）

したがってD2J単独ではTask20-D2およびTask20-B全体を完了にしない。
