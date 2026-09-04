import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/core/database/providers/database_providers.dart';
import 'package:workout_menu_app/features/records/presentation/records_notifier.dart';
import 'package:workout_menu_app/features/settings/presentation/training_settings_providers.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2d_test_support.dart';
import 'task20_d2f_test_support.dart';
import 'task20_d2g_test_support.dart';

Future<void> waitForRecordsDashboardD2H(WidgetTester tester) async {
  const readyText = 'トレーニング履歴';
  const errorText = '記録を読み込めませんでした。';
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(readyText).evaluate().isNotEmpty) return;
    if (find.text(errorText).evaluate().isNotEmpty) {
      throw TestFailure('Records dashboard entered the visible error state.');
    }
  }
  throw TestFailure('Timed out waiting for the records dashboard.');
}

Future<void> saveBodyMeasurementD2H(WidgetTester tester) async {
  await tapNavigationLabelD2F(tester, '記録');
  await waitForRecordsDashboardD2H(tester);
  await tapText(tester, '体重・体脂肪率');
  await waitForText(tester, '測定履歴');
  await tapText(tester, '測定を追加');
  await waitForText(tester, '保存する');

  final fields = find.byType(TextField);
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), '65.4');
  await tester.enterText(fields.at(1), '18.7');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 500));
  await tapText(tester, '保存する');
  await waitForText(tester, '測定を保存しました。');
  await scrollToTextD2F(tester, '65.4kg・18.7%', delta: 250);
}

Future<void> savePrimaryGoalD2H(WidgetTester tester) async {
  await tapNavigationLabelD2G(tester, 'マイページ');
  await waitForText(tester, 'トレーニング設定');
  await scrollToTextD2G(tester, 'トレーニング目的');
  await tapText(tester, 'トレーニング目的');
  await waitForText(tester, '筋肉を大きくしたい');
  await tapTextAt(tester, '筋力を高めたい', 0);
  await tapText(tester, '変更を保存する');
  await waitForPathD2G(
    tester,
    '/my-page',
    timeout: const Duration(seconds: 90),
  );
  await scrollToTextD2G(tester, '筋力を高めたい');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2H phase 1 stores menu, workout record, measurement, and settings',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await completePartialWorkoutForRecords(tester);

      final homeContext = tester.element(find.text('今日やること'));
      final container = ProviderScope.containerOf(homeContext);
      final database = container.read(appDatabaseProvider);
      final recordsRepository = container.read(recordsRepositoryProvider);
      final settingsRepository = container.read(
        trainingSettingsRepositoryProvider,
      );

      await saveBodyMeasurementD2H(tester);
      final measurements = await recordsRepository.loadBodyMeasurements();
      expect(measurements, hasLength(1));
      expect(measurements.single.weightKg, 65.4);
      expect(measurements.single.bodyFatPercent, 18.7);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2H_01_measurement_saved');

      await savePrimaryGoalD2H(tester);
      final settings = await settingsRepository.load();
      expect(settings.draft.primaryGoalCode, 'STRENGTH');

      final dashboard = await recordsRepository.loadDashboard();
      expect(dashboard.sessionsLast30Days, 1);
      expect(dashboard.workSetsLast30Days, 1);
      expect(dashboard.recentSessions, hasLength(1));
      expect(dashboard.latestWeightKg, 65.4);
      expect(dashboard.latestBodyFatPercent, 18.7);

      final menuCountRow = await database.customSelect('''
        SELECT COUNT(*) AS row_count
        FROM weekly_menu
        WHERE deleted_at IS NULL
      ''').getSingle();
      expect(menuCountRow.read<int>('row_count'), 1);

      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2H_02_settings_saved');
    },
    timeout: const Timeout(Duration(minutes: 18)),
  );
}
