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
import 'task20_d2e_test_support.dart';

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

Future<void> _waitForPersistedReps(
  ProviderContainer container,
  String sessionId,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final loaded =
        await container.read(workoutRepositoryProvider).loadSession(sessionId);
    if (loaded.currentInput.reps == d2nSentinelReps) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure(
    'D2N input draft did not persist: session=$sessionId reps=$d2nSentinelReps',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2N persists current set input before OS termination',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await completeD2DOnboarding(tester);
      await createAndFinalizeFirstWeekMenu(tester);

      await tapText(tester, '開始');
      await waitForText(tester, '開始前の確認');
      await _scrollToText(tester, '予定どおり開始する');
      await tapText(tester, '予定どおり開始する');
      await waitForText(
        tester,
        'トレーニング中',
        timeout: const Duration(seconds: 90),
      );

      final context = tester.element(find.text('トレーニング中').first);
      final container = ProviderScope.containerOf(context);
      final repository = container.read(workoutRepositoryProvider);
      final database = container.read(appDatabaseProvider);
      final initial = await repository.loadOpenSession();
      expect(initial, isNotNull);
      expect(initial!.isResting, isFalse);
      expect(initial.currentExercise, isNotNull);
      expect(initial.currentExercise!.recordsRepetitions, isTrue);
      expect(initial.completedWorkSetCount, 0);

      await container.read(workoutSessionProvider.notifier).updateInput(
            (value) => value.copyWith(reps: d2nSentinelReps),
          );
      await _waitForPersistedReps(container, initial.sessionId);
      await _scrollToText(tester, '回数');
      await waitForText(tester, '${d2nSentinelReps}回');
      expectHealthyFrame(tester);

      final sessionRow = await database.customSelect(
        '''
        SELECT current_input_draft_json
        FROM workout_session
        WHERE id = ?
        ''',
        variables: <Variable<Object>>[
          Variable.withString(initial.sessionId),
        ],
      ).getSingle();
      final draftText = sessionRow.read<String>('current_input_draft_json');
      final draft = jsonDecode(draftText) as Map<String, dynamic>;
      expect(draft['reps'], d2nSentinelReps);

      final recordCount = await database.customSelect(
        '''
        SELECT COUNT(*) AS count
        FROM work_set_record wsr
        JOIN session_exercise se ON se.id = wsr.session_exercise_id
        WHERE se.workout_session_id = ?
          AND wsr.voided_at IS NULL
        ''',
        variables: <Variable<Object>>[
          Variable.withString(initial.sessionId),
        ],
      ).getSingle();
      expect(recordCount.read<int>('count'), 0);

      final metadata = <String, Object?>{
        'session_id': initial.sessionId,
        'exercise_id': initial.currentExercise!.exerciseId,
        'exercise_name': initial.currentExercise!.name,
        'sentinel_reps': d2nSentinelReps,
        'draft_persisted': true,
        'completed_work_set_count': initial.completedWorkSetCount,
        'work_set_record_count': recordCount.read<int>('count'),
      };
      print('D2N_TRIGGER_METADATA=${jsonEncode(metadata)}');
      print('D2N_READY_FOR_OS_TERMINATION');

      while (true) {
        await tester.pump(const Duration(seconds: 1));
      }
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
