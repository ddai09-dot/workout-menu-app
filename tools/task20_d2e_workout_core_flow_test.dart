import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/features/workout/presentation/workout_notifier.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2d_test_support.dart';
import 'task20_d2e_test_support.dart';

Future<void> verifyWorkoutStartRepository(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  final titleFinder = find.text('開始前の確認');
  expect(titleFinder, findsOneWidget);
  final context = tester.element(titleFinder);
  final routeState = GoRouterState.of(context);
  final dayPlanId = routeState.pathParameters['dayPlanId'];
  if (dayPlanId == null || dayPlanId.isEmpty) {
    await binding.takeScreenshot('D2E_DIAG_missing_day_plan_id');
    throw TestFailure(
      'Workout start route did not expose a non-empty dayPlanId. '
      'pathParameters=${routeState.pathParameters}',
    );
  }

  final container = ProviderScope.containerOf(context);
  try {
    final summary = await container
        .read(workoutRepositoryProvider)
        .loadLaunchSummary(dayPlanId)
        .timeout(const Duration(seconds: 30));
    if (summary.exercises.isEmpty) {
      await binding.takeScreenshot('D2E_DIAG_empty_launch_summary');
      throw TestFailure(
        'Workout start repository returned no exercises for dayPlanId=$dayPlanId',
      );
    }
  } catch (error, stackTrace) {
    await binding.takeScreenshot('D2E_DIAG_launch_repository_error');
    throw TestFailure(
      'Workout start repository failed for dayPlanId=$dayPlanId: '
      '$error\n$stackTrace',
    );
  }
}

String _visibleTextSnapshot() {
  return find
      .byType(Text)
      .evaluate()
      .map((element) {
        final text = element.widget as Text;
        return text.data ?? text.textSpan?.toPlainText() ?? '';
      })
      .where((text) => text.trim().isNotEmpty)
      .toSet()
      .join(' | ');
}

Future<void> waitForWorkoutStartReady(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  const readyText = '痛み・違和感がありますか？';
  const primaryActionText = '予定どおり開始する';
  const adjustmentActionText = '今日の状態を調整';
  const errorText = '今日のメニューを読み込めませんでした。';
  final deadline = DateTime.now().add(const Duration(seconds: 60));

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(readyText).evaluate().isNotEmpty) {
      try {
        expectHealthyFrame(tester);
        await scrollToText(tester, primaryActionText, delta: 200);
        await waitForText(tester, primaryActionText);
        await scrollToText(tester, adjustmentActionText, delta: 200);
        await waitForText(tester, adjustmentActionText);
        expectHealthyFrame(tester);
        return;
      } catch (error, stackTrace) {
        await binding.takeScreenshot('D2E_DIAG_start_cta_unreachable');
        final scrollableCount = find.byType(Scrollable).evaluate().length;
        final progressCount = find.byType(CircularProgressIndicator).evaluate().length;
        throw TestFailure(
          'Workout start summary loaded, but enlarged-text CTA reachability '
          'failed. error=$error; scrollables=$scrollableCount; '
          'progressIndicators=$progressCount; '
          'visibleTexts=${_visibleTextSnapshot()}\n$stackTrace',
        );
      }
    }
    if (find.text(errorText).evaluate().isNotEmpty) {
      await binding.takeScreenshot('D2E_DIAG_start_load_error');
      throw TestFailure(
        'Workout start summary returned the visible load-error state: $errorText',
      );
    }
  }

  await binding.takeScreenshot('D2E_DIAG_start_load_timeout');
  final progressCount = find.byType(CircularProgressIndicator).evaluate().length;
  throw TestFailure(
    'Workout start summary did not become ready or show the expected error '
    'within 60 seconds. progressIndicators=$progressCount; '
    'visibleTexts=${_visibleTextSnapshot()}',
  );
}

Future<void> scrollToText(
  WidgetTester tester,
  String text, {
  double delta = 300,
  bool useLastScrollable = false,
}) async {
  final scrollables = find.byType(Scrollable);
  expect(scrollables, findsWidgets);
  await tester.scrollUntilVisible(
    find.text(text),
    delta,
    scrollable: useLastScrollable ? scrollables.last : scrollables.first,
  );
  await tester.pump(const Duration(milliseconds: 300));
}

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
      await verifyWorkoutStartRepository(binding, tester);
      await waitForWorkoutStartReady(binding, tester);
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
      await scrollToText(tester, 'セット完了', delta: 200);
      expect(find.text('セット完了'), findsOneWidget);
      await scrollToText(tester, 'フォームを確認', delta: -200);
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
        find.byType(BackButton),
        description: 'exercise form BackButton',
      );
      await waitForText(tester, 'トレーニング中');

      await scrollToText(tester, 'その他の操作');
      await tapText(tester, 'その他の操作');
      await scrollToText(
        tester,
        'セット数を変更する',
        delta: 200,
        useLastScrollable: true,
      );
      await tapText(tester, 'セット数を変更する');
      await waitForText(tester, 'セット数');
      await selectFirstCupertinoPickerValue(tester);
      await waitForText(tester, 'セット 1 / 1');

      await tapText(tester, 'セット完了');
      await waitForText(tester, '休憩');
      expect(find.text('完了したセット'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_05_rest');

      await scrollToText(tester, '休憩を終了する', delta: 200);
      expect(find.text('休憩を終了する'), findsOneWidget);
      await tapText(tester, '休憩を終了する');
      await scrollToText(tester, '次の種目へ', delta: 200);
      expect(find.text('次の種目へ'), findsOneWidget);
      await tapText(tester, '次の種目へ');
      await waitForText(tester, '2 / 2種目');
      expect(find.text('フォームを確認'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_06_next_exercise');

      await scrollToText(tester, 'その他の操作');
      await tapText(tester, 'その他の操作');
      await scrollToText(
        tester,
        '途中で終了',
        delta: 200,
        useLastScrollable: true,
      );
      await tapText(tester, '途中で終了');
      await waitForText(tester, 'ここまでを記録して終了しますか？');
      expect(
        find.text('完了済みのセットは失われません。終了後に未完了理由を記録します。'),
        findsOneWidget,
      );
      await tapText(tester, '終了する');

      await waitForText(
        tester,
        '終了後の記録',
        timeout: const Duration(seconds: 90),
      );
      expect(find.text('全体のきつさ'), findsOneWidget);
      await scrollToText(tester, '未完了の理由', delta: 200);
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
