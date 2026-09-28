// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/core/database/providers/database_providers.dart';
import 'package:workout_menu_app/features/records/presentation/records_notifier.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2d_test_support.dart';
import 'task20_d2f_test_support.dart';

Future<void> _waitForRecordsDashboard(WidgetTester tester) async {
  const readyText = 'トレーニング履歴';
  const errorText = '記録を読み込めませんでした。';
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(readyText).evaluate().isNotEmpty) return;
    if (find.text(errorText).evaluate().isNotEmpty) {
      throw TestFailure('D2O records dashboard entered the visible error state.');
    }
  }
  throw TestFailure('D2O records dashboard did not become ready.');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2O corrects a body measurement by voiding and superseding the old row',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await completePartialWorkoutForRecords(tester);

      final homeContext = tester.element(find.text('今日やること'));
      final container = ProviderScope.containerOf(homeContext);
      final repository = container.read(recordsRepositoryProvider);
      final database = container.read(appDatabaseProvider);

      await tapNavigationLabelD2F(tester, '記録');
      await _waitForRecordsDashboard(tester);
      await waitForText(tester, '体重・体脂肪率');
      await tapText(tester, '体重・体脂肪率');
      await waitForText(tester, '測定履歴');

      await tapText(tester, '測定を追加');
      await waitForText(tester, '保存する');
      var fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), '65.4');
      await tester.enterText(fields.at(1), '18.7');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));
      await tapText(tester, '保存する');
      await waitForText(tester, '測定を保存しました。');
      await scrollToTextD2F(tester, '65.4kg・18.7%', delta: 250);

      final originalMeasurements = await repository.loadBodyMeasurements();
      expect(originalMeasurements, hasLength(1));
      final original = originalMeasurements.single;
      expect(original.weightKg, 65.4);
      expect(original.bodyFatPercent, 18.7);

      final originalRow = await database.customSelect(
        '''
        SELECT id, measured_at, weight_kg, body_fat_percent, voided_at,
               supersedes_id, source_code, sync_status
        FROM body_measurement
        WHERE id = ?
        ''',
        variables: <Variable<Object>>[
          Variable.withString(original.id),
        ],
      ).getSingle();
      expect(originalRow.readNullable<String>('voided_at'), isNull);
      expect(originalRow.readNullable<String>('supersedes_id'), isNull);
      expect(originalRow.read<String>('source_code'), 'MANUAL');
      expect(originalRow.read<String>('sync_status'), 'LOCAL_ONLY');

      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2O_01_original_measurement');

      await tapText(tester, '訂正');
      await waitForText(tester, '測定を訂正');
      fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      expect(tester.widget<TextField>(fields.at(0)).controller?.text, '65.4');
      expect(tester.widget<TextField>(fields.at(1)).controller?.text, '18.7');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2O_02_correction_editor_prefilled');

      await tester.enterText(fields.at(0), '66.2');
      await tester.enterText(fields.at(1), '19.1');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));
      await tapText(tester, '保存する');
      await waitForText(tester, '測定を保存しました。');
      await scrollToTextD2F(tester, '66.2kg・19.1%', delta: 250);

      final correctedMeasurements = await repository.loadBodyMeasurements();
      expect(correctedMeasurements, hasLength(1));
      final corrected = correctedMeasurements.single;
      expect(corrected.id, isNot(original.id));
      expect(corrected.weightKg, 66.2);
      expect(corrected.bodyFatPercent, 19.1);
      expect(corrected.measuredAt.toUtc(), original.measuredAt.toUtc());
      expect(find.text('65.4kg・18.7%'), findsNothing);

      final rows = await database.customSelect(
        '''
        SELECT id, measured_at, weight_kg, body_fat_percent, voided_at,
               supersedes_id, source_code, sync_status
        FROM body_measurement
        WHERE id = ? OR id = ?
        ORDER BY created_at ASC
        ''',
        variables: <Variable<Object>>[
          Variable.withString(original.id),
          Variable.withString(corrected.id),
        ],
      ).get();
      expect(rows, hasLength(2));

      final oldRow = rows.firstWhere(
        (row) => row.read<String>('id') == original.id,
      );
      final newRow = rows.firstWhere(
        (row) => row.read<String>('id') == corrected.id,
      );
      expect(oldRow.readNullable<String>('voided_at'), isNotNull);
      expect(oldRow.readNullable<String>('supersedes_id'), isNull);
      expect(oldRow.read<double>('weight_kg'), 65.4);
      expect(oldRow.read<double>('body_fat_percent'), 18.7);

      expect(newRow.readNullable<String>('voided_at'), isNull);
      expect(newRow.read<String>('supersedes_id'), original.id);
      expect(newRow.read<double>('weight_kg'), 66.2);
      expect(newRow.read<double>('body_fat_percent'), 19.1);
      expect(newRow.read<String>('measured_at'), originalRow.read<String>('measured_at'));
      expect(newRow.read<String>('source_code'), 'MANUAL');
      expect(newRow.read<String>('sync_status'), 'LOCAL_ONLY');

      final activeCount = await database.customSelect(
        '''
        SELECT COUNT(*) AS count
        FROM body_measurement
        WHERE voided_at IS NULL
        ''',
      ).getSingle();
      expect(activeCount.read<int>('count'), 1);

      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2O_03_corrected_measurement');

      await tapNavigationLabelD2F(tester, '記録');
      await _waitForRecordsDashboard(tester);
      await waitForText(
        tester,
        '66.2kg・19.1%',
        timeout: const Duration(seconds: 60),
      );
      final dashboard = await repository.loadDashboard();
      expect(dashboard.latestWeightKg, 66.2);
      expect(dashboard.latestBodyFatPercent, 19.1);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2O_04_dashboard_uses_correction');

      final metadata = <String, Object?>{
        'original_id': original.id,
        'corrected_id': corrected.id,
        'original_voided': oldRow.readNullable<String>('voided_at') != null,
        'corrected_supersedes_original':
            newRow.read<String>('supersedes_id') == original.id,
        'active_measurement_count': activeCount.read<int>('count'),
        'corrected_weight_kg': corrected.weightKg,
        'corrected_body_fat_percent': corrected.bodyFatPercent,
        'measured_at_preserved':
            newRow.read<String>('measured_at') ==
            originalRow.read<String>('measured_at'),
        'dashboard_uses_correction':
            dashboard.latestWeightKg == 66.2 &&
            dashboard.latestBodyFatPercent == 19.1,
      };
      final reportData = binding.reportData ??= <String, dynamic>{};
      reportData['task'] = 'Task20-D2O';
      reportData['phase'] = 'VERIFY';
      reportData['metadata'] = metadata;
      print('D2O_VERIFY_METADATA=${jsonEncode(metadata)}');
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
