// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2f_test_support.dart';
import 'task20_d2i_test_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2I local reset deletes current user data and preserves non-user data',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();
      await d2iWaitForIntroStable(tester);

      final initialContext = d2iRuntimeContext(tester);
      await initialContext.secureStore.delete(d2iMetadataKey);

      await completePartialWorkoutForRecords(tester);
      final runtime = d2iRuntimeContext(tester);
      final account = await runtime.accountRepository.ensureAnonymousAccount();
      final oldUserId = account.userId;
      expect(await runtime.secureStore.read('current_user_id'), oldUserId);
      final oldNickname = await d2iOldNickname(runtime.database, oldUserId);

      await d2iInsertContractFixtures(runtime.database, oldUserId);
      final schema = await d2iCaptureSchema(runtime.database);
      final preCounts = await d2iUserOwnedCounts(
        runtime.database,
        schema.userOwnedTables,
        oldUserId,
      );
      final preRowIds = await d2iUserOwnedRowIds(
        runtime.database,
        schema.userOwnedTables,
        oldUserId,
      );
      final nonZeroTables = preCounts.entries
          .where((entry) => entry.value > 0)
          .map((entry) => entry.key)
          .toList()
        ..sort();
      expect(nonZeroTables, isNotEmpty);
      expect(preCounts['body_measurement'], greaterThan(0));
      expect(preCounts['progression_proposal'], greaterThan(0));
      expect(preCounts['workout_session'], greaterThan(0));
      expect(preCounts['work_set_record'], greaterThan(0));
      expect(preCounts['weekly_menu'], greaterThan(0));

      final preservedCounts = await d2iPreservedCounts(
        runtime.database,
        schema.preservedTables,
      );
      final preservedFingerprints = await d2iPreservedFingerprints(
        runtime.database,
        schema.preservedTables,
      );
      final preResetAccountIds = await d2iUserAccountIds(runtime.database);
      expect(preResetAccountIds, contains(oldUserId));
      expect(preResetAccountIds, contains(d2iOtherUserId));
      await d2iAssertOtherUserPreserved(runtime.database);
      expect(await d2iForeignKeyViolationCount(runtime.database), 0);

      await tapNavigationLabelD2F(tester, 'マイページ');
      await d2iWaitForText(tester, 'トレーニング設定');
      await d2iScrollUntilTextVisible(tester, '端末内データ');
      await d2iTapText(tester, '端末内データ');
      await d2iWaitForText(tester, '端末内データを初期化');
      expect(find.text('削除されるもの'), findsOneWidget);
      await d2iScrollUntilTextVisible(tester, '削除されないもの');
      expect(find.text('削除されないもの'), findsOneWidget);
      await d2iScrollUntilTextVisible(
        tester,
        '削除したデータは元に戻せないことを確認しました',
      );
      await d2iScrollUntilTextVisible(tester, '端末内データを削除');

      final resetButton = find.ancestor(
        of: find.text('端末内データを削除'),
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      expect(resetButton, findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(resetButton).onPressed, isNull);
      await d2iTapText(tester, '削除したデータは元に戻せないことを確認しました');
      expect(tester.widget<ButtonStyleButton>(resetButton).onPressed, isNotNull);
      d2iExpectHealthyFrame(tester);
      await binding.takeScreenshot('D2I_01_reset_ready');

      await d2iTapText(tester, '端末内データを削除');
      await d2iWaitForText(tester, 'すべて削除しますか？');
      await d2iTapText(tester, 'キャンセル');
      await d2iWaitForText(tester, '端末内データを削除');

      final accountAfterCancel = await runtime.accountRepository.ensureAnonymousAccount();
      expect(accountAfterCancel.userId, oldUserId);
      expect(await runtime.secureStore.read('current_user_id'), oldUserId);
      expect(
        await d2iUserOwnedCounts(runtime.database, schema.userOwnedTables, oldUserId),
        preCounts,
      );
      expect(await d2iUserAccountIds(runtime.database), preResetAccountIds);
      await d2iAssertOtherUserPreserved(runtime.database);

      await d2iTapText(tester, '端末内データを削除');
      await d2iWaitForText(tester, 'すべて削除しますか？');
      await d2iTapText(tester, '削除する');
      await d2iWaitForIntroStable(tester);
      expect(find.text('今日やること'), findsNothing);
      d2iExpectHealthyFrame(tester);
      await binding.takeScreenshot('D2I_02_intro_after_reset');

      final newAccount = await runtime.accountRepository.ensureAnonymousAccount();
      final newUserId = newAccount.userId;
      expect(newUserId, isNot(oldUserId));
      expect(await runtime.secureStore.read('current_user_id'), newUserId);

      final postCounts = await d2iUserOwnedCounts(
        runtime.database,
        schema.userOwnedTables,
        oldUserId,
      );
      expect(postCounts.values.every((count) => count == 0), isTrue);
      final oldRowIdsRemaining = await d2iOldRowIdsRemaining(runtime.database, preRowIds);
      expect(oldRowIdsRemaining, 0);
      await d2iAssertReplacementAccount(
        runtime.database,
        oldUserId,
        newUserId,
        preResetAccountIds,
      );
      await d2iAssertOtherUserPreserved(runtime.database);

      final postSchema = await d2iCaptureSchema(runtime.database);
      expect(postSchema.appTables, schema.appTables);
      expect(postSchema.userOwnedTables, schema.userOwnedTables);
      expect(postSchema.preservedTables, schema.preservedTables);
      expect(postSchema.schemaSha256, schema.schemaSha256);
      expect(
        await d2iPreservedCounts(runtime.database, schema.preservedTables),
        preservedCounts,
      );
      expect(
        await d2iPreservedFingerprints(runtime.database, schema.preservedTables),
        preservedFingerprints,
      );
      expect(await d2iForeignKeyViolationCount(runtime.database), 0);

      final metadata = <String, Object?>{
        'oldUserId': oldUserId,
        'newUserId': newUserId,
        'oldNickname': oldNickname,
        'appTables': schema.appTables,
        'userOwnedTables': schema.userOwnedTables,
        'preservedTables': schema.preservedTables,
        'schemaSha256': schema.schemaSha256,
        'preservedTableCounts': preservedCounts,
        'preservedTableFingerprints': preservedFingerprints,
        'preResetUserOwnedCounts': preCounts,
        'preResetNonZeroUserOwnedTables': nonZeroTables,
        'preResetOldRowIds': preRowIds,
        'otherUserId': d2iOtherUserId,
        'preResetUserAccountIds': preResetAccountIds,
        'phase1OldRowIdsRemaining': oldRowIdsRemaining,
        'phase1ForeignKeyViolations': 0,
      };
      await runtime.secureStore.write(
        key: d2iMetadataKey,
        value: jsonEncode(metadata),
      );
      expect(await runtime.secureStore.read(d2iMetadataKey), isNotNull);

      d2iPrintMetadata('PHASE1', <String, Object?>{
        'old_user_id': oldUserId,
        'new_user_id': newUserId,
        'app_table_count': schema.appTables.length,
        'user_owned_table_count': schema.userOwnedTables.length,
        'preserved_table_count': schema.preservedTables.length,
        'schema_sha256': schema.schemaSha256,
        'pre_reset_nonzero_user_owned_table_count': nonZeroTables.length,
        'pre_reset_nonzero_user_owned_tables': nonZeroTables,
        'old_user_rows_remaining': postCounts.values.fold<int>(0, (sum, count) => sum + count),
        'pre_reset_old_row_ids_remaining': oldRowIdsRemaining,
        'foreign_key_violations': 0,
      });
    },
    timeout: const Timeout(Duration(minutes: 18)),
  );
}
