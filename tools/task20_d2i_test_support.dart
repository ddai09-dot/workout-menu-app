// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_menu_app/core/database/app_database.dart';
import 'package:workout_menu_app/core/database/providers/database_providers.dart';
import 'package:workout_menu_app/core/security/secure_store.dart';
import 'package:workout_menu_app/features/account/domain/account_repository.dart';
import 'package:workout_menu_app/features/account/presentation/account_notifier.dart';

const String d2iMetadataKey = 'task20_d2i_phase_metadata';
const String d2iOtherUserId = 'd2i-other-user';
const String d2iOtherProfileId = 'd2i-other-profile';
const String d2iFaqSentinelId = 'd2i-reset-sentinel';
const String d2iBodyMeasurementId = 'd2i-body-measurement';
const String d2iProgressionProposalId = 'd2i-progression-proposal';

const List<String> d2iUserOwnedBaseline = <String>[
  'accepted_progression_adjustment',
  'account_deletion_request',
  'account_link_history',
  'ai_chat_message',
  'ai_chat_session',
  'ai_feedback',
  'ai_response_cache',
  'app_preference',
  'body_measurement',
  'device_registration',
  'equipment_weight_option',
  'exercise_performance_series',
  'location_barbell_detail',
  'location_dumbbell_detail',
  'location_equipment',
  'notification_delivery_log',
  'notification_preference',
  'notification_schedule',
  'notification_setting_legacy_archive',
  'onboarding_draft',
  'planned_exercise',
  'planned_set',
  'post_workout_assessment',
  'progression_proposal',
  'progression_proposal_decision',
  'session_exercise',
  'session_exercise_evaluation',
  'session_pain_entry',
  'session_set_target',
  'standard_schedule_day',
  'sync_checkpoint',
  'sync_conflict_log',
  'sync_outbox',
  'sync_run_history',
  'training_location',
  'training_week',
  'user_experience_profile',
  'user_goal',
  'user_priority_part',
  'user_profile',
  'user_restriction',
  'user_training_setting',
  'weekly_available_day',
  'weekly_input',
  'weekly_menu',
  'weekly_pain_entry',
  'weekly_planner_draft',
  'weekly_priority_part',
  'weekly_stalled_exercise',
  'work_set_record',
  'workout_day_plan',
  'workout_session',
  'workout_session_event',
];

const List<String> d2iPreservedBaseline = <String>[
  'ai_dictionary',
  'ai_faq',
  'ai_prompt_template',
  'body_part_master',
  'equipment_master',
  'exercise_alternative',
  'exercise_body_part',
  'exercise_equipment',
  'exercise_equipment_option',
  'exercise_fatigue_tag',
  'exercise_form_asset',
  'exercise_form_copy',
  'exercise_joint',
  'exercise_master',
  'exercise_movement',
  'exercise_progression_profile',
  'fatigue_tag_master',
  'joint_master',
  'movement_master',
  'reason_template',
  'rule_version',
];

final class D2iRuntimeContext {
  const D2iRuntimeContext({
    required this.container,
    required this.database,
    required this.accountRepository,
    required this.secureStore,
  });

  final ProviderContainer container;
  final AppDatabase database;
  final AccountRepository accountRepository;
  final PlatformSecureStore secureStore;
}

final class D2iSchemaSnapshot {
  const D2iSchemaSnapshot({
    required this.appTables,
    required this.userOwnedTables,
    required this.preservedTables,
    required this.schemaSha256,
  });

  final List<String> appTables;
  final List<String> userOwnedTables;
  final List<String> preservedTables;
  final String schemaSha256;
}

D2iRuntimeContext d2iRuntimeContext(WidgetTester tester) {
  final context = tester.element(find.byType(MaterialApp).first);
  final container = ProviderScope.containerOf(context, listen: false);
  return D2iRuntimeContext(
    container: container,
    database: container.read(appDatabaseProvider),
    accountRepository: container.read(accountRepositoryProvider),
    secureStore: const PlatformSecureStore(),
  );
}

String d2iQuoteIdentifier(String identifier) {
  return '"${identifier.replaceAll('"', '""')}"';
}

Future<List<Map<String, Object?>>> d2iRawRows(
  AppDatabase database,
  String sql, {
  List<Variable<Object>> variables = const <Variable<Object>>[],
}) async {
  final rows = await database.customSelect(sql, variables: variables).get();
  return rows.map((row) => Map<String, Object?>.from(row.data)).toList();
}

Future<D2iSchemaSnapshot> d2iCaptureSchema(AppDatabase database) async {
  final tableRows = await d2iRawRows(
    database,
    "SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  final appTables = tableRows.map((row) => row['name']! as String).toList();
  expect(appTables.length, 75);

  final userOwned = <String>[];
  for (final table in appTables) {
    final info = await d2iTableInfo(database, table);
    if (info.any((row) => row['name'] == 'user_id')) {
      userOwned.add(table);
    }
  }
  userOwned.sort();
  final expectedUserOwned = [...d2iUserOwnedBaseline]..sort();
  expect(userOwned, expectedUserOwned);
  expect(userOwned.length, 53);

  for (final table in userOwned) {
    final info = await d2iTableInfo(database, table);
    final pkColumns = info.where((row) => (row['pk'] as int? ?? 0) > 0).toList();
    expect(pkColumns.length, 1, reason: '$table must have one primary key column');
    expect(pkColumns.single['name'], 'id', reason: '$table primary key must be id');
  }

  final preserved = appTables
      .where((table) => table != 'user_account' && !userOwned.contains(table))
      .toList()
    ..sort();
  final expectedPreserved = [...d2iPreservedBaseline]..sort();
  expect(preserved, expectedPreserved);
  expect(preserved.length, 21);

  final schemaText = tableRows
      .map((row) => '${row['name']}\u0000${row['sql'] ?? ''}')
      .join('\n');
  final schemaSha = sha256.convert(utf8.encode(schemaText)).toString();

  return D2iSchemaSnapshot(
    appTables: appTables,
    userOwnedTables: userOwned,
    preservedTables: preserved,
    schemaSha256: schemaSha,
  );
}

Future<List<Map<String, Object?>>> d2iTableInfo(
  AppDatabase database,
  String table,
) {
  return d2iRawRows(
    database,
    'PRAGMA table_info(${d2iQuoteIdentifier(table)})',
  );
}

Future<Map<String, int>> d2iUserOwnedCounts(
  AppDatabase database,
  List<String> tables,
  String userId,
) async {
  final result = <String, int>{};
  for (final table in tables) {
    final row = await database.customSelect(
      'SELECT COUNT(*) AS row_count FROM ${d2iQuoteIdentifier(table)} WHERE user_id = ?',
      variables: <Variable<Object>>[Variable<String>(userId)],
    ).getSingle();
    result[table] = row.read<int>('row_count');
  }
  return result;
}

Future<Map<String, List<String>>> d2iUserOwnedRowIds(
  AppDatabase database,
  List<String> tables,
  String userId,
) async {
  final result = <String, List<String>>{};
  for (final table in tables) {
    final rows = await database.customSelect(
      'SELECT id FROM ${d2iQuoteIdentifier(table)} WHERE user_id = ? ORDER BY id',
      variables: <Variable<Object>>[Variable<String>(userId)],
    ).get();
    result[table] = rows.map((row) => row.read<String>('id')).toList();
  }
  return result;
}

Future<int> d2iOldRowIdsRemaining(
  AppDatabase database,
  Map<String, List<String>> rowIds,
) async {
  var remaining = 0;
  for (final entry in rowIds.entries) {
    for (final id in entry.value) {
      final row = await database.customSelect(
        'SELECT COUNT(*) AS row_count FROM ${d2iQuoteIdentifier(entry.key)} WHERE id = ?',
        variables: <Variable<Object>>[Variable<String>(id)],
      ).getSingle();
      remaining += row.read<int>('row_count');
    }
  }
  return remaining;
}

Future<List<String>> d2iUserAccountIds(AppDatabase database) async {
  final rows = await database.customSelect(
    'SELECT id FROM user_account ORDER BY id',
  ).get();
  return rows.map((row) => row.read<String>('id')).toList();
}

Future<Map<String, int>> d2iPreservedCounts(
  AppDatabase database,
  List<String> tables,
) async {
  final result = <String, int>{};
  for (final table in tables) {
    final row = await database.customSelect(
      'SELECT COUNT(*) AS row_count FROM ${d2iQuoteIdentifier(table)}',
    ).getSingle();
    result[table] = row.read<int>('row_count');
  }
  return result;
}

Future<Map<String, String>> d2iPreservedFingerprints(
  AppDatabase database,
  List<String> tables,
) async {
  final result = <String, String>{};
  for (final table in tables) {
    final info = await d2iTableInfo(database, table);
    final columns = info.map((row) => row['name']! as String).toList();
    final rows = await d2iRawRows(
      database,
      'SELECT * FROM ${d2iQuoteIdentifier(table)}',
    );
    final normalizedRows = rows.map((row) {
      final normalized = <String, Object?>{};
      for (final column in columns) {
        normalized[column] = d2iNormalizeSqliteValue(row[column]);
      }
      return jsonEncode(normalized);
    }).toList()
      ..sort();
    result[table] = sha256.convert(utf8.encode(normalizedRows.join('\n'))).toString();
  }
  return result;
}

Object? d2iNormalizeSqliteValue(Object? value) {
  if (value == null) {
    return const <String, Object?>{'type': 'null', 'value': null};
  }
  if (value is Uint8List) {
    return <String, Object?>{'type': 'blob', 'value': base64Encode(value)};
  }
  if (value is int) {
    return <String, Object?>{'type': 'int', 'value': value};
  }
  if (value is double) {
    return <String, Object?>{'type': 'double', 'value': value};
  }
  if (value is String) {
    return <String, Object?>{'type': 'text', 'value': value};
  }
  return <String, Object?>{
    'type': value.runtimeType.toString(),
    'value': value.toString(),
  };
}

Future<void> d2iInsertContractFixtures(
  AppDatabase database,
  String oldUserId,
) async {
  await database.customStatement(
    'INSERT INTO body_measurement(id, user_id, measured_at, weight_kg, body_fat_percent) VALUES (?, ?, ?, ?, ?)',
    <Object?>[d2iBodyMeasurementId, oldUserId, '2026-08-18T09:00:00+09:00', 65.4, 18.7],
  );

  final activeRule = await database.customSelect(
    'SELECT id FROM rule_version WHERE is_active = 1 ORDER BY id LIMIT 1',
  ).getSingle();
  final ruleVersionId = activeRule.read<String>('id');
  await database.customStatement(
    'INSERT INTO progression_proposal(id, user_id, rule_version_id, proposal_type_code, proposed_value_json, reason_text_snapshot) VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>[
      d2iProgressionProposalId,
      oldUserId,
      ruleVersionId,
      'D2I_TEST_ONLY',
      '{"value":1}',
      'Task20-D2I test-only proposal',
    ],
  );

  await database.customStatement(
    'INSERT INTO user_account(id) VALUES (?)',
    <Object?>[d2iOtherUserId],
  );
  await database.customStatement(
    'INSERT INTO user_profile(id, user_id, nickname, age_years, age_updated_on) VALUES (?, ?, ?, ?, ?)',
    <Object?>[d2iOtherProfileId, d2iOtherUserId, 'D2I他ユーザー', 31, '2026-08-18'],
  );
  await database.customStatement(
    'INSERT INTO ai_faq(id, category_code, question_text, answer_text, content_version) VALUES (?, ?, ?, ?, ?)',
    <Object?>[
      d2iFaqSentinelId,
      'D2I_TEST_ONLY',
      'Task20-D2I reset persistence sentinel',
      'This row must survive local reset unchanged.',
      '1',
    ],
  );
}

Future<void> d2iAssertOtherUserPreserved(AppDatabase database) async {
  final account = await database.customSelect(
    'SELECT auth_provider, account_status FROM user_account WHERE id = ?',
    variables: <Variable<Object>>[Variable<String>(d2iOtherUserId)],
  ).getSingle();
  expect(account.read<String>('auth_provider'), 'ANONYMOUS');
  expect(account.read<String>('account_status'), 'ACTIVE');

  final profile = await database.customSelect(
    'SELECT nickname, age_years FROM user_profile WHERE id = ? AND user_id = ?',
    variables: <Variable<Object>>[
      Variable<String>(d2iOtherProfileId),
      Variable<String>(d2iOtherUserId),
    ],
  ).getSingle();
  expect(profile.read<String>('nickname'), 'D2I他ユーザー');
  expect(profile.read<int>('age_years'), 31);
}

Future<void> d2iAssertReplacementAccount(
  AppDatabase database,
  String oldUserId,
  String newUserId,
  List<String> preResetAccountIds,
) async {
  final oldCount = await database.customSelect(
    'SELECT COUNT(*) AS row_count FROM user_account WHERE id = ?',
    variables: <Variable<Object>>[Variable<String>(oldUserId)],
  ).getSingle();
  expect(oldCount.read<int>('row_count'), 0);

  final replacement = await database.customSelect(
    'SELECT auth_provider, account_status FROM user_account WHERE id = ?',
    variables: <Variable<Object>>[Variable<String>(newUserId)],
  ).getSingle();
  expect(replacement.read<String>('auth_provider'), 'ANONYMOUS');
  expect(replacement.read<String>('account_status'), 'ACTIVE');

  final expectedIds = preResetAccountIds.where((id) => id != oldUserId).toList()
    ..add(newUserId);
  expectedIds.sort();
  expect(await d2iUserAccountIds(database), expectedIds);
}

Future<int> d2iForeignKeyViolationCount(AppDatabase database) async {
  final rows = await database.customSelect('PRAGMA foreign_key_check').get();
  return rows.length;
}

Future<String> d2iOldNickname(AppDatabase database, String userId) async {
  final row = await database.customSelect(
    'SELECT nickname FROM user_profile WHERE user_id = ? AND deleted_at IS NULL LIMIT 1',
    variables: <Variable<Object>>[Variable<String>(userId)],
  ).getSingle();
  return row.read<String>('nickname');
}

Future<void> d2iWaitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final finder = find.text(text);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw TestFailure('Timed out waiting for text: $text');
}

Future<void> d2iWaitForIntroStable(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final title = find.text('あなたに合うメニューを作ります');
  final start = find.text('登録を始める');
  final deadline = DateTime.now().add(timeout);
  var stable = 0;
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (title.evaluate().isNotEmpty && start.evaluate().isNotEmpty) {
      stable += 1;
      if (stable >= 8) {
        return;
      }
    } else {
      stable = 0;
    }
  }
  throw TestFailure('Timed out waiting for stable onboarding intro.');
}

Future<void> d2iScrollUntilTextVisible(
  WidgetTester tester,
  String text, {
  int maxScrolls = 16,
}) async {
  final target = find.text(text);
  for (var attempt = 0; attempt <= maxScrolls; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 250));
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
    final lists = find.byType(ListView);
    expect(lists, findsWidgets);
    await tester.drag(lists.first, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 400));
  }
  throw TestFailure('Timed out scrolling to text: $text');
}

Future<void> d2iTapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await d2iWaitForText(tester, text);
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 500));
}

void d2iExpectHealthyFrame(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorWidget), findsNothing);
}

void d2iPrintMetadata(String phase, Map<String, Object?> payload) {
  print('D2I_${phase}_METADATA=${jsonEncode(payload)}');
}
