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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2H phase 2 reloads menu, records, measurement, and settings after restart',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await waitForText(
        tester,
        '今日やること',
        timeout: const Duration(seconds: 90),
      );
      final homeContext = tester.element(find.text('今日やること'));
      final container = ProviderScope.containerOf(homeContext);
      final database = container.read(appDatabaseProvider);
      final recordsRepository = container.read(recordsRepositoryProvider);
      final settingsRepository = container.read(
        trainingSettingsRepositoryProvider,
      );

      final dashboard = await recordsRepository.loadDashboard();
      expect(dashboard.sessionsLast30Days, 1);
      expect(dashboard.workSetsLast30Days, 1);
      expect(dashboard.recentSessions, hasLength(1));
      expect(dashboard.latestWeightKg, 65.4);
      expect(dashboard.latestBodyFatPercent, 18.7);

      final measurements = await recordsRepository.loadBodyMeasurements();
      expect(measurements, hasLength(1));
      expect(measurements.single.weightKg, 65.4);
      expect(measurements.single.bodyFatPercent, 18.7);

      final settings = await settingsRepository.load();
      expect(settings.draft.primaryGoalCode, 'STRENGTH');

      final menuCountRow = await database.customSelect('''
        SELECT COUNT(*) AS row_count
        FROM weekly_menu
        WHERE deleted_at IS NULL
      ''').getSingle();
      expect(menuCountRow.read<int>('row_count'), 1);

      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2H_03_home_after_restart');

      await tapNavigationLabelD2F(tester, 'メニュー');
      await waitForText(
        tester,
        '今週を調整',
        timeout: const Duration(seconds: 60),
      );
      await waitForText(tester, '全身A');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2H_04_menu_after_restart');

      await tapNavigationLabelD2F(tester, '記録');
      await waitForRecordsDashboardD2H(tester);
      await waitForText(
        tester,
        '65.4kg・18.7%',
        timeout: const Duration(seconds: 60),
      );
      expect(find.text('1 / 1日 完了'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2H_05_records_after_restart');

      await tapNavigationLabelD2G(tester, 'マイページ');
      await waitForText(tester, 'トレーニング設定');
      await scrollToTextD2G(tester, '筋力を高めたい');
      expect(find.text('筋力を高めたい'), findsWidgets);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2H_06_settings_after_restart');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
