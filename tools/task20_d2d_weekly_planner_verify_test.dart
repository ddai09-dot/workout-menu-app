import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2d_test_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2D phase 2 restores, revises, generates, and finalizes the weekly plan',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await waitForAnyText(
        tester,
        <String>['今日やること', '週間メニューの続きを作りましょう'],
        timeout: const Duration(seconds: 90),
      );
      await tapText(tester, 'メニュー');
      await waitForText(tester, '週間メニューの作成途中です');
      expect(find.text('作成の続きをする'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2D_02_menu_resume_card');

      await tapText(tester, '作成の続きをする');
      await waitForText(tester, '今週の調整方針');
      expectChoiceSelected(tester, '負荷を下げたい');
      expectChoiceSelected(tester, '全身を均等にする');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2D_03_adjustment_restored');

      await tapFinder(
        tester,
        find.byIcon(Icons.arrow_back),
        description: 'back arrow icon',
      );
      await waitForText(tester, '現在の状態');
      expectSegmentValue(tester, selectorIndex: 0, value: 4);
      expectSegmentValue(tester, selectorIndex: 1, value: 2);
      await tapText(tester, '次へ');

      await waitForText(tester, '今週の調整方針');
      expectChoiceSelected(tester, '負荷を下げたい');
      expectChoiceSelected(tester, '全身を均等にする');
      await tapText(tester, 'メニューを作成する');

      await waitForText(
        tester,
        'メニューを確認',
        timeout: const Duration(seconds: 90),
      );
      await waitForText(tester, 'この内容で確定');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2D_04_review_generated');

      await tapText(tester, '条件を修正して作り直す');
      await waitForText(tester, '今週の予定');
      expect(find.text('トレーニングする'), findsWidgets);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2D_05_revise_schedule_preserved');

      await tapText(tester, '体調の確認へ');
      await waitForText(tester, '現在の状態');
      expectSegmentValue(tester, selectorIndex: 0, value: 4);
      expectSegmentValue(tester, selectorIndex: 1, value: 2);
      await tapText(tester, '次へ');

      await waitForText(tester, '今週の調整方針');
      expectChoiceSelected(tester, '負荷を下げたい');
      expectChoiceSelected(tester, '全身を均等にする');
      await tapText(tester, 'メニューを作成する');
      await waitForText(
        tester,
        'メニューを確認',
        timeout: const Duration(seconds: 90),
      );
      await tapText(tester, 'この内容で確定');

      await waitForText(
        tester,
        '今週を調整',
        timeout: const Duration(seconds: 90),
      );
      expect(find.text('今週のメニューは未作成です'), findsNothing);
      expect(find.text('週間メニューの作成途中です'), findsNothing);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2D_06_final_menu');
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
