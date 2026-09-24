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

const int d2nSentinelReps = 37;

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
  throw TestFailure('D2N could not materialize text: $text');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2N restores current input after OS termination and commits it safely',
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
      await binding.takeScreenshot('D2N_02_home_resume_after_restart');

      await tapText(tester, 'トレーニングを再開する');
      await waitForText(
        tester,
        'トレーニング中',
        timeout: const Duration(seconds: 90),
      );
      await _scrollToText(tester, '回数');
      await waitForText(tester, '${d2nSentinelReps}回');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2N_03_input_restored_after_restart');

      final context = tester.element(find.text('トレーニング中').first);
      final container = ProviderScope.containerOf(context);
      final repository = container.read(workoutRepositoryProvider);
      final database = container.read(appDatabaseProvider);
      final restored = await repository.loadOpenSession();
      expect(restored, isNotNull);
      expect(restored!.isResting, isFalse);
      expect(restored.currentInput.reps, d2nSentinelReps);
      expect(restored.completedWorkSetCount, 0);

      final beforeCount = await database.customSelect(
        '''
        SELECT COUNT(*) AS count
        FROM work_set_record wsr
        JOIN session_exercise se ON se.id = wsr.session_exercise_id
        WHERE se.workout_session_id = ?
          AND wsr.voided_at IS NULL
        ''',
        variables: <Variable<Object>>[
          Variable.withString(restored.sessionId),
        ],
      ).getSingle();
      expect(beforeCount.read<int>('count'), 0);

      await _scrollToText(tester, 'セット完了');
      await tapText(tester, 'セット完了');
      await waitForText(tester, '休憩', timeout: const Duration(seconds: 90));

      final completed = await repository.loadSession(restored.sessionId);
      expect(completed.rest, isNotNull);
      expect(completed.completedWorkSetCount, 1);

      final recorded = await database.customSelect(
        '''
        SELECT actual_reps
        FROM work_set_record wsr
        JOIN session_exercise se ON se.id = wsr.session_exercise_id
        WHERE se.workout_session_id = ?
          AND wsr.voided_at IS NULL
        ORDER BY wsr.completed_at DESC
        LIMIT 1
        ''',
        variables: <Variable<Object>>[
          Variable.withString(restored.sessionId),
        ],
      ).getSingle();
      expect(recorded.read<int>('actual_reps'), d2nSentinelReps);

      final sessionRow = await database.customSelect(
        '''
        SELECT current_input_draft_json
        FROM workout_session
        WHERE id = ?
        ''',
        variables: <Variable<Object>>[
          Variable.withString(restored.sessionId),
        ],
      ).getSingle();
      expect(sessionRow.read<String>('current_input_draft_json'), '{}');

      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2N_04_rest_after_restored_input_commit');

      final metadata = <String, Object?>{
        'session_id': restored.sessionId,
        'sentinel_reps': d2nSentinelReps,
        'draft_restored_after_restart': true,
        'work_set_record_count_before_commit': beforeCount.read<int>('count'),
        'recorded_actual_reps': recorded.read<int>('actual_reps'),
        'completed_work_set_count_after_commit': completed.completedWorkSetCount,
        'draft_cleared_after_commit':
            sessionRow.read<String>('current_input_draft_json') == '{}',
      };
      final reportData = binding.reportData ??= <String, dynamic>{};
      reportData['task'] = 'Task20-D2N';
      reportData['phase'] = 'VERIFY';
      reportData['metadata'] = metadata;
      print('D2N_VERIFY_METADATA=${jsonEncode(metadata)}');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
