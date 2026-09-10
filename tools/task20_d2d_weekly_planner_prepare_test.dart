import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2d_test_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2D phase 1 saves a weekly planner draft before process termination',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await completeD2DOnboarding(tester);
      await tapText(tester, 'メニュー');
      await waitForText(tester, '今週のメニューは未作成です');
      expectHealthyFrame(tester);
      await tapText(tester, '今週のメニューを作成する');

      await waitForText(tester, '今週のメニュー');
      expectHealthyFrame(tester);
      await tapText(tester, '今週の予定を入力する');
      await waitForText(tester, '今週の予定');
      expect(find.text('トレーニングする'), findsWidgets);
      expectHealthyFrame(tester);
      await tapText(tester, '体調の確認へ');

      await waitForText(tester, '現在の状態');
      expectHealthyFrame(tester);
      await selectSegmentValue(tester, selectorIndex: 0, value: 4);
      await selectSegmentValue(tester, selectorIndex: 1, value: 2);
      expectHealthyFrame(tester);
      await tapText(tester, '次へ');

      await waitForText(tester, '今週の調整方針');
      expectHealthyFrame(tester);
      await tapText(tester, '負荷を下げたい');
      await tapText(tester, '全身を均等にする');
      await waitForWeeklySavingToFinish(tester);
      expectChoiceSelected(tester, '負荷を下げたい');
      expectChoiceSelected(tester, '全身を均等にする');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2D_01_adjustment_saved');
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
