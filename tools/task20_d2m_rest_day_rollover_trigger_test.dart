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

Future<void> _waitForRestDuration(
  ProviderContainer container,
  String sessionId,
  int expected,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final state =
        await container.read(workoutRepositoryProvider).loadSession(sessionId);
    if (state.rest?.durationSec == expected) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure(
    'D2M rest duration did not persist: session=$sessionId expected=$expected',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2M prepares an expired rest timer spanning a calendar-day boundary',
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

      await _scrollToText(tester, 'セット完了');
      await tapText(tester, 'セット完了');
      await waitForText(tester, '休憩');
      await waitForText(tester, '完了したセット');

      final context = tester.element(find.text('休憩').first);
      final container = ProviderScope.containerOf(context);
      final repository = container.read(workoutRepositoryProvider);
      final database = container.read(appDatabaseProvider);
      final initial = await repository.loadOpenSession();
      expect(initial, isNotNull);
      expect(initial!.rest, isNotNull);
      expect(initial.completedWorkSetCount, greaterThanOrEqualTo(1));

      final initialDuration = initial.rest!.durationSec;
      await _scrollToText(tester, '＋15秒');
      await tapText(tester, '＋15秒');
      await _waitForRestDuration(
        container,
        initial.sessionId,
        initialDuration + 15,
      );

      final nowUtc = DateTime.now().toUtc();
      final priorLocal = DateTime.now().subtract(const Duration(days: 1));
      final simulatedStartedAt =
          nowUtc.subtract(const Duration(days: 1, minutes: 5));
      final simulatedRestStartedAt =
          nowUtc.subtract(const Duration(days: 1, seconds: 5));
      final recordDate = _dateOnly(priorLocal);
      final nowText = nowUtc.toIso8601String();

      await database.customStatement(
        '''
        UPDATE workout_session
        SET started_at = ?, record_date = ?, rest_started_at = ?,
            last_local_saved_at = ?, last_interaction_at = ?, updated_at = ?,
            row_version = row_version + 1, sync_status = 'LOCAL_ONLY'
        WHERE id = ?
        ''',
        <Object?>[
          simulatedStartedAt.toIso8601String(),
          recordDate,
          simulatedRestStartedAt.toIso8601String(),
          nowText,
          nowText,
          nowText,
          initial.sessionId,
        ],
      );

      await container.read(workoutSessionProvider.notifier).reload();
      await waitForText(tester, '00:00');

      final prepared = await repository.loadSession(initial.sessionId);
      expect(prepared.statusCode, 'IN_PROGRESS');
      expect(prepared.rest, isNotNull);
      expect(prepared.rest!.durationSec, initialDuration + 15);
      expect(prepared.rest!.remainingSecondsAt(DateTime.now()), 0);
      expect(_dateOnly(prepared.recordDate), recordDate);
      expect(
        DateTime.parse(recordDate).isBefore(
          DateTime.parse(_dateOnly(DateTime.now())),
        ),
        isTrue,
      );

      final completedRows = await database.customSelect(
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
      expect(completedRows.read<int>('count'), greaterThanOrEqualTo(1));

      final metadata = <String, Object?>{
        'session_id': initial.sessionId,
        'record_date': recordDate,
        'rest_duration_sec': initialDuration + 15,
        'rest_remaining_sec': prepared.rest!.remainingSecondsAt(DateTime.now()),
        'completed_work_set_count': prepared.completedWorkSetCount,
        'simulated_started_at': simulatedStartedAt.toIso8601String(),
        'simulated_rest_started_at': simulatedRestStartedAt.toIso8601String(),
      };
      print('D2M_TRIGGER_METADATA=${jsonEncode(metadata)}');
      print('D2M_READY_FOR_OS_TERMINATION');

      while (true) {
        await tester.pump(const Duration(seconds: 1));
      }
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
