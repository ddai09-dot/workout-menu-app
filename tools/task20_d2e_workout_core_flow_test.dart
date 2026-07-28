import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2d_test_support.dart';
import 'task20_d2e_test_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2E completes the tested workout start, execution, form, and assessment flow',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await completeD2DOnboarding(tester);
      await createAndFinalizeFirstWeekMenu(tester);

      await tapText(tester, '開始');
      await waitForText(tester, '開始前の確認');
      await waitForText(tester, '痛み・違和感がありますか？');
      await waitForText(tester, '予定どおり開始する');
      await waitForText(tester, '今日の状態を調整');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_01_start_check');

      await tapText(tester, '今日の状態を調整');
      await waitForText(tester, '今日の状態に合わせる');
      await tapText(tester, '45分');
      await selectSegmentValue(tester, selectorIndex: 0, value: 4);
      expect(
        find.text('高い疲労に合わせて、重量またはセットを減らします。'),
        findsOneWidget,
      );
      await tapText(tester, '追加');
      await waitForText(tester, '痛み・違和感の対応');
      expect(find.text('重量を下げる'), findsOneWidget);
      expect(find.textContaining('診断'), findsNothing);
      await tapText(tester, 'この対応を追加する');
      await waitForText(tester, '重量を下げる');
      expect(find.textContaining('痛み対応1件'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_02_adjustment');

      await tapText(tester, 'この内容で開始する');
      await waitForText(
        tester,
        'トレーニング中',
        timeout: const Duration(seconds: 90),
      );
      await waitForText(tester, '1 / 2種目');
      expect(find.text('フォームを確認'), findsOneWidget);
      expect(find.text('セット完了'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_03_session');

      await tapText(tester, 'フォームを確認');
      await waitForText(tester, '動作のポイント');
      await waitForText(tester, '注意点');
      expect(find.text('画像は準備中です'), findsWidgets);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_04_form_fallback');
      await tapFinder(
        tester,
        find.byIcon(Icons.arrow_back),
        description: 'exercise form back arrow',
      );
      await waitForText(tester, 'トレーニング中');

      await tapText(tester, 'その他の操作');
      await waitForText(tester, 'セット数を変更する');
      await tapText(tester, 'セット数を変更する');
      await waitForText(tester, 'セット数');
      await selectFirstCupertinoPickerValue(tester);
      await waitForText(tester, 'セット 1 / 1');

      await tapText(tester, 'セット完了');
      await waitForText(tester, '休憩');
      expect(find.text('完了したセット'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_05_rest');

      if (find.text('休憩を終了する').evaluate().isNotEmpty) {
        await tapText(tester, '休憩を終了する');
      }
      await waitForText(tester, '次の種目へ');
      await tapText(tester, '次の種目へ');
      await waitForText(tester, '2 / 2種目');
      expect(find.text('フォームを確認'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_06_next_exercise');

      await tapText(tester, 'その他の操作');
      await waitForText(tester, '途中で終了');
      await tapText(tester, '途中で終了');
      await waitForText(tester, 'ここまでを記録して終了しますか？');
      expect(find.text('完了済みのセットは失われません。終了後に未完了理由を記録します。'), findsOneWidget);
      await tapText(tester, '終了する');

      await waitForText(
        tester,
        '終了後の記録',
        timeout: const Duration(seconds: 90),
      );
      expect(find.text('全体のきつさ'), findsOneWidget);
      expect(find.text('未完了の理由'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_07_assessment');

      await chooseDropdownValue(
        tester,
        fieldLabel: '理由を選択',
        valueLabel: '自分の判断',
      );
      await tapText(tester, '記録して終了');
      await waitForText(
        tester,
        '今日やること',
        timeout: const Duration(seconds: 90),
      );
      expect(find.text('トレーニング中'), findsNothing);
      expect(find.text('終了後の記録'), findsNothing);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_08_home_completed');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
