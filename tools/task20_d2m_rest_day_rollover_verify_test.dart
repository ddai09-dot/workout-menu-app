// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/core/database/providers/database_providers.dart';
import 'package:workout_menu_app/features/workout/presentation/workout_notifier.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2d_test_support.dart';

String _dateOnly(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

Future<void> _scrollToText(
  WidgetTester tester,
  String text, {
  double delta = 260,
}) async {
  final target = find.text(text);
  for (var attempt = 0; attempt < 20; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    final scrollables = find.byType(Scrollable).hitTestable();
    expect(scrollables, findsWidgets);
    await tester.drag(scrollables.first, Offset(0, -delta.abs()));
    await tester.pump(const Duration(milliseconds: 300));
  }
  throw TestFailure('D2M could not materialize text: $text');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2M restores an overnight rest timer after OS termination and advances safely',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await waitForText(
        tester,
        '未終了のトレーニングがあります',
        timeout: const Duration(seconds: 90),
      );
      await waitForText(tester, 'トレーニングを再開する');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2M_02_home_resume_after_restart');

      await tapText(tester, 'トレーニングを再開する');
      await waitForText(tester, '休憩', timeout: const Duration(seconds: 90));
      await waitForText(tester, '00:00');
      await waitForText(tester, '完了したセット');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2M_03_rest_restored_after_restart');

      final context = tester.element(find.text('休憩').first);
      final container = ProviderScope.containerOf(context);
      final repository = container.read(workoutRepositoryProvider);
      final database = container.read(appDatabaseProvider);
      final restored = await repository.loadOpenSession();
      expect(restored, isNotNull);
      expect(restored!.statusCode, 'IN_PROGRESS');
      expect(restored.rest, isNotNull);
      expect(restored.rest!.remainingSecondsAt(DateTime.now()), 0);
      expect(restored.completedWorkSetCount, greaterThanOrEqualTo(1));
      expect(
        DateTime.parse(_dateOnly(restored.recordDate)).isBefore(
          DateTime.parse(_dateOnly(DateTime.now())),
        ),
        isTrue,
      );

      final rest = restored.rest!;
      final nextLabel = rest.isLastExercise
          ? '終了後の記録へ'
          : rest.isLastSetOfExercise
              ? '次の種目へ'
              : '次のセットへ';
      await _scrollToText(tester, nextLabel);
      await tapText(tester, nextLabel);

      if (rest.isLastExercise) {
        await waitForText(
          tester,
          '終了後の記録',
          timeout: const Duration(seconds: 90),
        );
      } else {
        await waitForText(
          tester,
          'トレーニング中',
          timeout: const Duration(seconds: 90),
        );
      }
      await tester.pump(const Duration(milliseconds: 500));

      final advanced = await repository.loadSession(restored.sessionId);
      expect(advanced.rest, isNull);

      final recordedRest = await database.customSelect(
        '''
        SELECT MAX(wsr.rest_duration_sec) AS rest_duration_sec
        FROM work_set_record wsr
        JOIN session_exercise se ON se.id = wsr.session_exercise_id
        WHERE se.workout_session_id = ?
          AND wsr.voided_at IS NULL
        ''',
        variables: <Variable<Object>>[
          Variable.withString(restored.sessionId),
        ],
      ).getSingle();
      final actualRestSeconds =
          recordedRest.readNullable<int>('rest_duration_sec');
      expect(actualRestSeconds, isNotNull);
      expect(actualRestSeconds!, greaterThanOrEqualTo(60 * 60 * 20));

      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2M_04_advanced_after_restart');

      final metadata = <String, Object?>{
        'session_id': restored.sessionId,
        'record_date': _dateOnly(restored.recordDate),
        'rest_restored_after_restart': true,
        'rest_remaining_sec_after_restart': 0,
        'completed_work_set_count': restored.completedWorkSetCount,
        'advance_label': nextLabel,
        'actual_rest_duration_sec': actualRestSeconds,
        'rest_cleared_after_advance': advanced.rest == null,
      };
      final reportData = binding.reportData ??= <String, dynamic>{};
      reportData['task'] = 'Task20-D2M';
      reportData['phase'] = 'VERIFY';
      reportData['metadata'] = metadata;
      print('D2M_VERIFY_METADATA=${jsonEncode(metadata)}');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
