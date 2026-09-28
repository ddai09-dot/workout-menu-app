// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/core/database/app_database.dart';
import 'package:workout_menu_app/core/database/providers/database_providers.dart';
import 'package:workout_menu_app/features/progression/presentation/progression_notifier.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2d_test_support.dart';
import 'task20_d2f_test_support.dart';

Future<void> _waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(text).evaluate().isNotEmpty) return;
  }
  throw TestFailure('D2P timed out waiting for text: $text');
}

Future<void> _waitForProposalStatus(
  AppDatabase database,
  String proposalId,
  String expectedStatus,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final row = await database.customSelect(
      'SELECT status_code FROM progression_proposal WHERE id = ?',
      variables: <Variable<Object>>[Variable.withString(proposalId)],
    ).getSingle();
    if (row.read<String>('status_code') == expectedStatus) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure(
    'D2P proposal $proposalId did not reach status $expectedStatus',
  );
}

Future<Map<String, String>> _fixtureIds(AppDatabase database) async {
  final user = await database.customSelect(
    'SELECT id FROM user_account ORDER BY created_at ASC LIMIT 1',
  ).getSingle();
  final rule = await database.customSelect(
    'SELECT id FROM rule_version WHERE is_active = 1 ORDER BY released_at DESC LIMIT 1',
  ).getSingle();
  final exercise = await database.customSelect(
    "SELECT id FROM exercise_master WHERE name_ja = 'プッシュアップ' LIMIT 1",
  ).getSingle();
  return <String, String>{
    'userId': user.read<String>('id'),
    'ruleVersionId': rule.read<String>('id'),
    'exerciseId': exercise.read<String>('id'),
  };
}

Future<void> _insertProposal(
  AppDatabase database, {
  required Map<String, String> ids,
  required String id,
  required String typeCode,
  required String reason,
  required Map<String, Object?> currentValue,
  required Map<String, Object?> proposedValue,
  required int priority,
}) async {
  final now = DateTime.now().toUtc().toIso8601String();
  await database.customStatement(
    '''
    INSERT INTO progression_proposal (
      id, user_id, rule_version_id, created_at, updated_at,
      exercise_id, performance_series_key, proposal_type_code,
      current_value_json, proposed_value_json, reason_text_snapshot,
      status_code, cooldown_remaining_sessions, proposal_key, priority
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'PENDING', 0, ?, ?)
    ''',
    <Object?>[
      id,
      ids['userId'],
      ids['ruleVersionId'],
      now,
      now,
      ids['exerciseId'],
      'D2P|$id',
      typeCode,
      jsonEncode(currentValue),
      jsonEncode(proposedValue),
      reason,
      'D2P_KEY_$id',
      priority,
    ],
  );
}

Finder _proposalCard(String reason) {
  final reasonFinder = find.text(reason);
  expect(reasonFinder, findsOneWidget);
  final card = find.ancestor(of: reasonFinder, matching: find.byType(Card));
  expect(card, findsOneWidget);
  return card;
}

Future<void> _tapCardText(
  WidgetTester tester, {
  required String reason,
  required String label,
}) async {
  final card = _proposalCard(reason);
  final labelFinder = find.descendant(of: card, matching: find.text(label));
  expect(labelFinder, findsOneWidget);
  await tester.ensureVisible(labelFinder);
  await tester.pump(const Duration(milliseconds: 350));
  final hit = labelFinder.hitTestable();
  expect(hit, findsOneWidget);
  await tester.tap(hit);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<QueryRow> _proposalRow(AppDatabase database, String id) {
  return database.customSelect(
    '''
    SELECT status_code, cooldown_remaining_sessions, applied_at
    FROM progression_proposal
    WHERE id = ?
    ''',
    variables: <Variable<Object>>[Variable.withString(id)],
  ).getSingle();
}

Future<QueryRow> _decisionRow(AppDatabase database, String id) {
  return database.customSelect(
    '''
    SELECT decision_code, applies_to_code, application_result_code,
           target_planned_exercise_id
    FROM progression_proposal_decision
    WHERE progression_proposal_id = ?
    ORDER BY decided_at DESC
    LIMIT 1
    ''',
    variables: <Variable<Object>>[Variable.withString(id)],
  ).getSingle();
}

Future<void> _refreshProposals(
  ProviderContainer container,
  WidgetTester tester,
) async {
  container.invalidate(progressionProposalsProvider);
  await container.read(progressionProposalsProvider.future);
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2P accepts, maintains, defers, and rejects visible progression proposals',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await completePartialWorkoutForRecords(tester);

      final homeContext = tester.element(find.text('今日やること'));
      final container = ProviderScope.containerOf(homeContext);
      final database = container.read(appDatabaseProvider);
      final ids = await _fixtureIds(database);

      GoRouter.of(homeContext).go('/records/proposals');
      await tester.pump(const Duration(milliseconds: 700));
      await _waitForText(tester, '次回の調整提案');
      await _waitForText(tester, '確認が必要な提案はありません。');

      const acceptId = 'd2p-proposal-accept';
      const acceptReason = 'D2P採用テスト';
      await _insertProposal(
        database,
        ids: ids,
        id: acceptId,
        typeCode: 'ALTERNATIVE_EXERCISE',
        reason: acceptReason,
        currentValue: const <String, Object?>{'setCount': 2},
        proposedValue: const <String, Object?>{'setCount': 2},
        priority: 10,
      );
      await _refreshProposals(container, tester);
      await _waitForText(tester, acceptReason);
      await _waitForText(tester, '次回作成時に確認する');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2P_01_accept_ready');

      await _tapCardText(
        tester,
        reason: acceptReason,
        label: '次回作成時に確認する',
      );
      await _waitForProposalStatus(database, acceptId, 'ACCEPTED');
      final acceptProposal = await _proposalRow(database, acceptId);
      expect(acceptProposal.read<int>('cooldown_remaining_sessions'), 0);
      expect(acceptProposal.readNullable<String>('applied_at'), isNotNull);
      final acceptDecision = await _decisionRow(database, acceptId);
      expect(acceptDecision.read<String>('decision_code'), 'ACCEPT');
      expect(
        acceptDecision.read<String>('application_result_code'),
        'MANUAL_REVIEW_REQUIRED',
      );
      expect(
        acceptDecision.readNullable<String>('target_planned_exercise_id'),
        isNull,
      );
      final adjustment = await database.customSelect(
        '''
        SELECT adjustment_type_code, status_code
        FROM accepted_progression_adjustment
        WHERE progression_proposal_id = ?
          AND deleted_at IS NULL
        ''',
        variables: <Variable<Object>>[Variable.withString(acceptId)],
      ).getSingle();
      expect(adjustment.read<String>('adjustment_type_code'), 'ALTERNATIVE_EXERCISE');
      expect(adjustment.read<String>('status_code'), 'REVIEW_REQUIRED');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2P_02_accept_recorded');

      const maintainId = 'd2p-proposal-maintain';
      const maintainReason = 'D2P維持テスト';
      await _insertProposal(
        database,
        ids: ids,
        id: maintainId,
        typeCode: 'INCREASE_WEIGHT',
        reason: maintainReason,
        currentValue: const <String, Object?>{'weightKg': 10.0},
        proposedValue: const <String, Object?>{'weightKg': 12.5},
        priority: 20,
      );
      await _refreshProposals(container, tester);
      await _waitForText(tester, maintainReason);
      await _tapCardText(
        tester,
        reason: maintainReason,
        label: '今回は維持',
      );
      await _waitForProposalStatus(database, maintainId, 'MAINTAINED');
      final maintainProposal = await _proposalRow(database, maintainId);
      expect(maintainProposal.read<int>('cooldown_remaining_sessions'), 1);
      expect(maintainProposal.readNullable<String>('applied_at'), isNull);
      final maintainDecision = await _decisionRow(database, maintainId);
      expect(maintainDecision.read<String>('decision_code'), 'MAINTAIN');
      expect(
        maintainDecision.read<String>('application_result_code'),
        'NOT_APPLICABLE',
      );
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2P_03_maintain_recorded');

      const deferId = 'd2p-proposal-defer';
      const deferReason = 'D2P保留テスト';
      await _insertProposal(
        database,
        ids: ids,
        id: deferId,
        typeCode: 'EXTEND_REPS',
        reason: deferReason,
        currentValue: const <String, Object?>{'targetRepsUpper': 10},
        proposedValue: const <String, Object?>{'targetRepsUpper': 12},
        priority: 30,
      );
      await _refreshProposals(container, tester);
      await _waitForText(tester, deferReason);
      await _tapCardText(
        tester,
        reason: deferReason,
        label: '後で決める',
      );
      await _waitForProposalStatus(database, deferId, 'DEFERRED');
      final deferProposal = await _proposalRow(database, deferId);
      expect(deferProposal.read<int>('cooldown_remaining_sessions'), 0);
      expect(deferProposal.readNullable<String>('applied_at'), isNull);
      final deferDecision = await _decisionRow(database, deferId);
      expect(deferDecision.read<String>('decision_code'), 'DEFER');
      expect(
        deferDecision.read<String>('application_result_code'),
        'NOT_APPLICABLE',
      );
      await _waitForText(tester, deferReason);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2P_04_defer_remains_visible');

      const rejectId = 'd2p-proposal-reject';
      const rejectReason = 'D2P拒否テスト';
      await _insertProposal(
        database,
        ids: ids,
        id: rejectId,
        typeCode: 'ADD_SET',
        reason: rejectReason,
        currentValue: const <String, Object?>{'setCount': 2},
        proposedValue: const <String, Object?>{'setCount': 3},
        priority: 5,
      );
      await _refreshProposals(container, tester);
      await _waitForText(tester, rejectReason);
      await _tapCardText(
        tester,
        reason: rejectReason,
        label: 'この提案を断る',
      );
      await _waitForText(tester, '提案を断りますか？');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2P_05_reject_confirmation');
      final rejectButton = find.widgetWithText(FilledButton, '断る').hitTestable();
      expect(rejectButton, findsOneWidget);
      await tester.tap(rejectButton);
      await tester.pump(const Duration(milliseconds: 350));
      await _waitForProposalStatus(database, rejectId, 'REJECTED');
      final rejectProposal = await _proposalRow(database, rejectId);
      expect(rejectProposal.read<int>('cooldown_remaining_sessions'), 2);
      expect(rejectProposal.readNullable<String>('applied_at'), isNull);
      final rejectDecision = await _decisionRow(database, rejectId);
      expect(rejectDecision.read<String>('decision_code'), 'REJECT');
      expect(
        rejectDecision.read<String>('application_result_code'),
        'NOT_APPLICABLE',
      );

      final decisionCount = await database.customSelect(
        '''
        SELECT COUNT(*) AS count
        FROM progression_proposal_decision
        WHERE progression_proposal_id IN (?, ?, ?, ?)
        ''',
        variables: <Variable<Object>>[
          Variable.withString(acceptId),
          Variable.withString(maintainId),
          Variable.withString(deferId),
          Variable.withString(rejectId),
        ],
      ).getSingle();
      expect(decisionCount.read<int>('count'), 4);

      final adjustmentCount = await database.customSelect(
        '''
        SELECT COUNT(*) AS count
        FROM accepted_progression_adjustment
        WHERE progression_proposal_id IN (?, ?, ?, ?)
          AND deleted_at IS NULL
        ''',
        variables: <Variable<Object>>[
          Variable.withString(acceptId),
          Variable.withString(maintainId),
          Variable.withString(deferId),
          Variable.withString(rejectId),
        ],
      ).getSingle();
      expect(adjustmentCount.read<int>('count'), 1);

      await _waitForText(tester, deferReason);
      expect(find.text(rejectReason), findsNothing);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2P_06_final_deferred_only');

      final metadata = <String, Object?>{
        'accept_status': acceptProposal.read<String>('status_code'),
        'accept_application_result':
            acceptDecision.read<String>('application_result_code'),
        'accept_adjustment_status': adjustment.read<String>('status_code'),
        'maintain_status': maintainProposal.read<String>('status_code'),
        'maintain_cooldown': maintainProposal.read<int>(
          'cooldown_remaining_sessions',
        ),
        'defer_status': deferProposal.read<String>('status_code'),
        'defer_still_visible': find.text(deferReason).evaluate().isNotEmpty,
        'reject_status': rejectProposal.read<String>('status_code'),
        'reject_cooldown': rejectProposal.read<int>(
          'cooldown_remaining_sessions',
        ),
        'decision_count': decisionCount.read<int>('count'),
        'accepted_adjustment_count': adjustmentCount.read<int>('count'),
      };
      final reportData = binding.reportData ??= <String, dynamic>{};
      reportData['task'] = 'Task20-D2P';
      reportData['phase'] = 'VERIFY';
      reportData['metadata'] = metadata;
      print('D2P_VERIFY_METADATA=${jsonEncode(metadata)}');
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
