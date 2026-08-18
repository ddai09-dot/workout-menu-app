// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2i_test_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2I local reset survives OS-level process restart without resurrection',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();
      await d2iWaitForIntroStable(tester);
      d2iExpectHealthyFrame(tester);
      await binding.takeScreenshot('D2I_03_intro_after_restart');

      final runtime = d2iRuntimeContext(tester);
      final metadataText = await runtime.secureStore.read(d2iMetadataKey);
      expect(metadataText, isNotNull);
      final metadata = jsonDecode(metadataText!) as Map<String, dynamic>;

      final oldUserId = metadata['oldUserId']! as String;
      final expectedNewUserId = metadata['newUserId']! as String;
      final oldNickname = metadata['oldNickname']! as String;
      final expectedAppTables = (metadata['appTables']! as List<dynamic>).cast<String>();
      final expectedUserOwned = (metadata['userOwnedTables']! as List<dynamic>).cast<String>();
      final expectedPreserved = (metadata['preservedTables']! as List<dynamic>).cast<String>();
      final expectedSchemaSha = metadata['schemaSha256']! as String;
      final expectedPreservedCounts = (metadata['preservedTableCounts']! as Map<String, dynamic>)
          .map((key, value) => MapEntry<String, int>(key, value as int));
      final expectedFingerprints =
          (metadata['preservedTableFingerprints']! as Map<String, dynamic>)
              .map((key, value) => MapEntry<String, String>(key, value as String));
      final preRowIdsDynamic = metadata['preResetOldRowIds']! as Map<String, dynamic>;
      final preRowIds = preRowIdsDynamic.map(
        (key, value) => MapEntry<String, List<String>>(
          key,
          (value as List<dynamic>).cast<String>(),
        ),
      );
      final preResetAccountIds =
          (metadata['preResetUserAccountIds']! as List<dynamic>).cast<String>();
      final nonZeroTables =
          (metadata['preResetNonZeroUserOwnedTables']! as List<dynamic>).cast<String>();

      final current = await runtime.accountRepository.ensureAnonymousAccount();
      expect(current.userId, expectedNewUserId);
      expect(current.userId, isNot(oldUserId));
      expect(await runtime.secureStore.read('current_user_id'), expectedNewUserId);

      final schema = await d2iCaptureSchema(runtime.database);
      expect(schema.appTables, expectedAppTables);
      expect(schema.userOwnedTables, expectedUserOwned);
      expect(schema.preservedTables, expectedPreserved);
      expect(schema.schemaSha256, expectedSchemaSha);

      final postRestartCounts = await d2iUserOwnedCounts(
        runtime.database,
        schema.userOwnedTables,
        oldUserId,
      );
      expect(postRestartCounts.values.every((count) => count == 0), isTrue);
      final oldRowIdsRemaining = await d2iOldRowIdsRemaining(runtime.database, preRowIds);
      expect(oldRowIdsRemaining, 0);

      await d2iAssertReplacementAccount(
        runtime.database,
        oldUserId,
        expectedNewUserId,
        preResetAccountIds,
      );
      await d2iAssertOtherUserPreserved(runtime.database);
      expect(
        await d2iPreservedCounts(runtime.database, schema.preservedTables),
        expectedPreservedCounts,
      );
      expect(
        await d2iPreservedFingerprints(runtime.database, schema.preservedTables),
        expectedFingerprints,
      );
      expect(await d2iForeignKeyViolationCount(runtime.database), 0);

      await d2iTapText(tester, '登録を始める');
      await d2iWaitForText(tester, '基本情報');
      expect(find.text(oldNickname), findsNothing);
      d2iExpectHealthyFrame(tester);
      await binding.takeScreenshot('D2I_04_clean_basic_info_after_restart');

      d2iPrintMetadata('PHASE2', <String, Object?>{
        'old_user_id': oldUserId,
        'new_user_id': expectedNewUserId,
        'app_table_count': schema.appTables.length,
        'user_owned_table_count': schema.userOwnedTables.length,
        'preserved_table_count': schema.preservedTables.length,
        'schema_sha256': schema.schemaSha256,
        'pre_reset_nonzero_user_owned_table_count': nonZeroTables.length,
        'pre_reset_nonzero_user_owned_tables': nonZeroTables,
        'old_user_rows_remaining': postRestartCounts.values.fold<int>(0, (sum, count) => sum + count),
        'pre_reset_old_row_ids_remaining': oldRowIdsRemaining,
        'foreign_key_violations': 0,
      });

      await runtime.secureStore.delete(d2iMetadataKey);
      expect(await runtime.secureStore.read(d2iMetadataKey), isNull);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
