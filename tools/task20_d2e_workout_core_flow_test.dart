import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/app/bootstrap.dart';
import 'package:workout_menu_app/core/database/app_database.dart';
import 'package:workout_menu_app/core/database/database_provider.dart';
import 'package:workout_menu_app/features/account/data/local_account_repository.dart';
import 'package:workout_menu_app/features/account/domain/account_repository.dart';
import 'package:workout_menu_app/features/onboarding/data/local_onboarding_repository.dart';
import 'package:workout_menu_app/features/onboarding/domain/onboarding_repository.dart';
import 'package:workout_menu_app/features/weekly_planner/data/local_weekly_planner_repository.dart';
import 'package:workout_menu_app/features/weekly_planner/domain/weekly_planner_repository.dart';
import 'package:workout_menu_app/features/workout/data/local_workout_repository.dart';
import 'package:workout_menu_app/features/workout/domain/workout_repository.dart';

import 'task20_d2d_test_support.dart';
import 'task20_d2e_test_support.dart';

Future<void> waitForWorkoutStartReady(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  const requiredTexts = <String>[
    '今日の状態を調整',
    'この内容で開始する',
  ];
  const errorText = '開始前の確認を読み込めませんでした。';
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 400));
    final ready = requiredTexts.every(
      (text) => find.text(text).evaluate().isNotEmpty,
    );
    if (ready) {
      return;
    }
    if (find.text(errorText).evaluate().isNotEmpty) {
      await binding.takeScreenshot('D2E_DIAG_start_load_error');
      throw TestFailure(
        'Workout start summary returned the visible load-error state: $errorText',
      );
    }
    final scrollables = find.byType(Scrollable).hitTestable();
    if (scrollables.evaluate().isNotEmpty) {
      await tester.drag(scrollables.first, const Offset(0, -220));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  await binding.takeScreenshot('D2E_DIAG_start_load_timeout');
  throw TestFailure(
    'Timed out waiting for the workout-start summary to expose its primary actions.',
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2E completes the tested workout start, execution, form, and assessment flow',
    (tester) async {
      final database = AppDatabase.inMemory();
      final accountRepository = LocalAccountRepository(database: database);
      final onboardingRepository = LocalOnboardingRepository(
        database: database,
        accountRepository: accountRepository,
      );
      final weeklyRepository = LocalWeeklyPlannerRepository(
        database: database,
        accountRepository: accountRepository,
      );
      final workoutRepository = LocalWorkoutRepository(
        database: database,
        accountRepository: accountRepository,
      );
      addTearDown(database.close);

      final account = await accountRepository.resolveCurrentAccount();
      await completeOnboardingForD2E(
        database: database,
        accountId: account.accountId,
      );
      await seedFinalizedPlanForD2E(
        database: database,
        accountId: account.accountId,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            accountRepositoryProvider.overrideWithValue(accountRepository),
            onboardingRepositoryProvider.overrideWithValue(onboardingRepository),
            weeklyPlannerRepositoryProvider.overrideWithValue(weeklyRepository),
            workoutRepositoryProvider.overrideWithValue(workoutRepository),
          ],
          child: const WorkoutMenuBootstrap(),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      await waitForText(tester, 'ホーム');
      await tapNavigationLabel(tester, 'メニュー');
      await waitForText(tester, '週間メニュー');
      await scrollToText(tester, '今日のトレーニング');
      await tapText(tester, '今日のトレーニング');
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
      await scrollToText(tester, 'フォームを確認', delta: -200);
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
      await waitForText(tester, 'その他の操作');
      await tapText(tester, 'セット数を変更');
      await waitForText(tester, 'セット数を変更');
      await chooseFirstPickerValue(tester, 'セット数');
      await tapText(tester, 'この数値を使う');
      await scrollToText(tester, 'セット 1 / 1', delta: -200);
      expect(find.text('セット 1 / 1'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_05_set_count_changed');

      await scrollToText(tester, 'セット完了');
      await tapText(tester, 'セット完了');
      await waitForText(tester, '休憩');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_06_rest_timer');
      await tapText(tester, 'スキップ');

      await scrollToText(tester, '次の種目へ');
      await tapText(tester, '次の種目へ');
      await waitForText(tester, '2 / 2種目');
      await scrollToText(tester, 'セット完了');
      await tapText(tester, 'セット完了');
      await waitForText(tester, '休憩');
      await tapText(tester, 'スキップ');
      await scrollToText(tester, 'トレーニングを終了');
      await tapText(tester, 'トレーニングを終了');
      await waitForText(tester, '今日のトレーニングを振り返る');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_07_assessment');

      await tapText(tester, '完了');
      await waitForText(tester, 'ホーム');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2E_08_completed_home');
    },
  );
}
