// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2i_test_support.dart';

const String d2kMetadataKey = 'task20_d2k_phase_metadata';
const String d2kInterruptedReplacementKey =
    'task20_d2k_interrupted_replacement_user_id';

Map<String, int> _intMap(Object? value) {
  final raw = value! as Map<String, dynamic>;
  return raw.map((key, entryValue) => MapEntry(key, entryValue as int));
}

Map<String, String> _stringMap(Object? value) {
  final raw = value! as Map<String, dynamic>;
  return raw.map(
    (key, entryValue) => MapEntry(key, entryValue as String),
  );
}

Map<String, List<String>> _stringListMap(Object? value) {
  final raw = value! as Map<String, dynamic>;
  return raw.map(
    (key, entryValue) => MapEntry(
      key,
      (entryValue! as List<dynamic>).cast<String>(),
    ),
  );
}

List<String> _stringList(Object? value) =>
    (value! as List<dynamic>).cast<String>();

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2K restart recovers the complete pre-reset state after interruption',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();
      await d2iWaitForText(tester, 'ホーム');

      final runtime = d2iRuntimeContext(tester);
      final encoded = await runtime.secureStore.read(d2kMetadataKey);
      expect(encoded, isNotNull);
      final metadata = jsonDecode(encoded!) as Map<String, dynamic>;
      final oldUserId = metadata['oldUserId']! as String;
      final replacementUserId =
          await runtime.secureStore.read(d2kInterruptedReplacementKey);
      expect(replacementUserId, isNotNull);
      expect(replacementUserId, isNot(oldUserId));

      final account = await runtime.accountRepository.ensureAnonymousAccount();
      expect(account.userId, oldUserId);
      expect(await runtime.secureStore.read('current_user_id'), oldUserId);

      final schema = await d2iCaptureSchema(runtime.database);
      expect(schema.appTables, _stringList(metadata['appTables']));
      expect(schema.userOwnedTables, _stringList(metadata['userOwnedTables']));
      expect(schema.preservedTables, _stringList(metadata['preservedTables']));
      expect(schema.schemaSha256, metadata['schemaSha256']);

      final preCounts = _intMap(metadata['preCounts']);
      final postCounts = await d2iUserOwnedCounts(
        runtime.database,
        schema.userOwnedTables,
        oldUserId,
      );
      expect(postCounts, preCounts);

      final preRowIds = _stringListMap(metadata['preRowIds']);
      final postRowIds = await d2iUserOwnedRowIds(
        runtime.database,
        schema.userOwnedTables,
        oldUserId,
      );
      expect(postRowIds, preRowIds);

      final preAccountIds = _stringList(metadata['preAccountIds']);
      final postAccountIds = await d2iUserAccountIds(runtime.database);
      expect(postAccountIds, preAccountIds);
      expect(postAccountIds.contains(replacementUserId), isFalse);

      expect(
        await d2iPreservedCounts(runtime.database, schema.preservedTables),
        _intMap(metadata['preservedCounts']),
      );
      expect(
        await d2iPreservedFingerprints(
          runtime.database,
          schema.preservedTables,
        ),
        _stringMap(metadata['preservedFingerprints']),
      );
      expect(await d2iForeignKeyViolationCount(runtime.database), 0);
      d2iExpectHealthyFrame(tester);
      await binding.takeScreenshot('D2K_03_recovered_after_interruption');

      final reportMetadata = <String, Object?>{
        'old_user_id': oldUserId,
        'interrupted_replacement_user_id': replacementUserId,
        'secure_key_recovered_to_old_user': true,
        'old_user_owned_rows_preserved': true,
        'replacement_account_absent': true,
        'schema_sha256': schema.schemaSha256,
        'foreign_key_violations': 0,
      };
      final reportData = binding.reportData ??= <String, dynamic>{};
      reportData['task'] = 'Task20-D2K';
      reportData['phase'] = 'VERIFY';
      reportData['metadata'] = reportMetadata;
      print('D2K_VERIFY_METADATA=${jsonEncode(reportMetadata)}');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
