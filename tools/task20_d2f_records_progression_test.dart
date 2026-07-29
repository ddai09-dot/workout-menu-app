import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/features/records/presentation/records_notifier.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2d_test_support.dart';
import 'task20_d2e_test_support.dart';
import 'task20_d2f_test_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2F reflects the completed workout in records and supports measurement entry',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await completePartialWorkoutForRecords(tester);
      await tapNavigationLabelD2F(tester, '記録');
      await waitForText(
        tester,
        '最近のトレーニング',
        timeout: const Duration(seconds: 90),
      );
      await waitForText(tester, '全身A');
      expect(find.text('1 / 1日 完了'), findsOneWidget);
      expectHealthyFrame(tester);

      final recordsContext = tester.element(find.text('最近のトレーニング'));
      final container = ProviderScope.containerOf(recordsContext);
      final repository = container.read(recordsRepositoryProvider);
      final dashboard = await repository.loadDashboard();
      expect(dashboard.sessionsLast30Days, 1);
      expect(dashboard.workSetsLast30Days, 1);
      expect(dashboard.completedThisWeek, 1);
      expect(dashboard.plannedThisWeek, 1);
      expect(dashboard.recentSessions, hasLength(1));
      final session = dashboard.recentSessions.single;
      expect(session.statusCode, 'PARTIAL');
      expect(session.focusText, '全身A');
      expect(session.exerciseCount, 1);
      expect(session.workSetCount, 1);
      expect(session.hadPain, isFalse);
      await binding.takeScreenshot('D2F_01_dashboard_recorded');

      await tapText(tester, 'トレーニング履歴');
      await waitForText(tester, '一部実施');
      expect(find.textContaining('1種目・1セット'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2F_02_history');

      await tapText(tester, '全身A');
      await waitForText(tester, 'トレーニング詳細');
      await waitForText(tester, 'プッシュアップ');
      expect(find.text('一部実施'), findsOneWidget);
      expect(find.text('8回'), findsOneWidget);
      final detail = await repository.loadWorkoutDetail(session.sessionId);
      expect(detail.exercises, hasLength(2));
      expect(detail.exercises.first.name, 'プッシュアップ');
      expect(detail.exercises.first.sets, hasLength(1));
      expect(detail.exercises.first.sets.single.reps, 8);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2F_03_session_detail');

      await tapNavigationLabelD2F(tester, '記録');
      await waitForText(tester, '種目別の推移');
      await tapText(tester, '種目別の推移');
      await waitForText(tester, 'プッシュアップ');
      final summaries = await repository.loadExerciseSummaries();
      expect(summaries, isNotEmpty);
      final pushUp = summaries.firstWhere((item) => item.name == 'プッシュアップ');
      expect(pushUp.sessionCount, 1);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2F_04_exercise_list');

      await tapText(tester, 'プッシュアップ');
      await waitForText(tester, '種目の推移');
      await waitForFinder(
        tester,
        find.textContaining('1回の有効記録'),
        description: 'one valid exercise record',
      );
      final exerciseHistory = await repository.loadExerciseHistory(pushUp.exerciseId);
      expect(exerciseHistory.series, isNotEmpty);
      expect(exerciseHistory.series.first.points, hasLength(1));
      expect(exerciseHistory.series.first.points.single.totalReps, 8);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2F_05_exercise_detail');

      await tapNavigationLabelD2F(tester, '記録');
      await waitForText(tester, '体重・体脂肪率');
      await tapText(tester, '体重・体脂肪率');
      await waitForText(tester, '測定履歴');
      await tapText(tester, '測定を追加');
      await waitForText(tester, '保存する');
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), '65.4');
      await tester.enterText(fields.at(1), '18.7');
      tester.testTextInput.hide();
      await tester.pump(const Duration(milliseconds: 500));
      await tapText(tester, '保存する');
      await waitForText(tester, '測定を保存しました。');
      await waitForText(tester, '65.4kg・18.7%');
      final measurements = await repository.loadBodyMeasurements();
      expect(measurements, hasLength(1));
      expect(measurements.single.weightKg, 65.4);
      expect(measurements.single.bodyFatPercent, 18.7);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2F_06_measurement_saved');

      await tapNavigationLabelD2F(tester, '記録');
      await waitForText(
        tester,
        '65.4kg・18.7%',
        timeout: const Duration(seconds: 60),
      );
      final refreshedDashboard = await repository.loadDashboard();
      expect(refreshedDashboard.latestWeightKg, 65.4);
      expect(refreshedDashboard.latestBodyFatPercent, 18.7);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2F_07_dashboard_measurement');

      await tapText(tester, '次回の調整提案');
      await waitForText(tester, '確認が必要な提案はありません。');
      expect(
        find.text('痛み・睡眠不足・目標未達の状態では、安易な増量を提案しません。'),
        findsOneWidget,
      );
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2F_08_proposals_empty');
    },
    timeout: const Timeout(Duration(minutes: 14)),
  );
}
