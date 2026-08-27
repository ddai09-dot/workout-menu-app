// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2f_test_support.dart';
import 'task20_d2i_test_support.dart';

const String d2kMetadataKey = 'task20_d2k_phase_metadata';
const String d2kInterruptedReplacementKey =
    'task20_d2k_interrupted_replacement_user_id';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2K prepares one completed local account before an interrupted reset',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();
      await d2iWaitForIntroStable(tester);

      final initialRuntime = d2iRuntimeContext(tester);
      await initialRuntime.secureStore.delete(d2kMetadataKey);
      await initialRuntime.secureStore.delete(d2kInterruptedReplacementKey);

      await completePartialWorkoutForRecords(tester);
      final runtime = d2iRuntimeContext(tester);
      final account = await runtime.accountRepository.ensureAnonymousAccount();
      final oldUserId = account.userId;
      expect(await runtime.secureStore.read('current_user_id'), oldUserId);

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
      expect(nonZeroTables.length, greaterThanOrEqualTo(10));

      final accountIds = await d2iUserAccountIds(runtime.database);
      expect(accountIds, <String>[oldUserId]);
      final preservedCounts = await d2iPreservedCounts(
        runtime.database,
        schema.preservedTables,
      );
      final preservedFingerprints = await d2iPreservedFingerprints(
        runtime.database,
        schema.preservedTables,
      );
      expect(await d2iForeignKeyViolationCount(runtime.database), 0);

      final metadata = <String, Object?>{
        'oldUserId': oldUserId,
        'appTables': schema.appTables,
        'userOwnedTables': schema.userOwnedTables,
        'preservedTables': schema.preservedTables,
        'schemaSha256': schema.schemaSha256,
        'preCounts': preCounts,
        'preRowIds': preRowIds,
        'preAccountIds': accountIds,
        'preservedCounts': preservedCounts,
        'preservedFingerprints': preservedFingerprints,
        'nonZeroTables': nonZeroTables,
      };
      await runtime.secureStore.write(
        key: d2kMetadataKey,
        value: jsonEncode(metadata),
      );

      await tapNavigationLabelD2F(tester, 'マイページ');
      await d2iWaitForText(tester, 'トレーニング設定');
      await d2iScrollUntilTextVisible(tester, '端末内データ');
      await d2iTapText(tester, '端末内データ');
      await d2iWaitForText(tester, '端末内データを初期化');
      await d2iScrollUntilTextVisible(
        tester,
        '削除したデータは元に戻せないことを確認しました',
      );
      await d2iScrollUntilTextVisible(tester, '端末内データを削除');
      await d2iTapText(
        tester,
        '削除したデータは元に戻せないことを確認しました',
      );
      d2iExpectHealthyFrame(tester);
      await binding.takeScreenshot('D2K_01_ready_before_interruption');

      final reportData = binding.reportData ??= <String, dynamic>{};
      reportData['task'] = 'Task20-D2K';
      reportData['phase'] = 'PREPARE';
      reportData['metadata'] = <String, Object?>{
        'old_user_id': oldUserId,
        'user_owned_table_count': schema.userOwnedTables.length,
        'nonzero_user_owned_table_count': nonZeroTables.length,
        'schema_sha256': schema.schemaSha256,
        'foreign_key_violations': 0,
      };
      print(
        'D2K_PREPARE_READY oldUserId=$oldUserId '
        'nonZeroTables=${nonZeroTables.length}',
      );
    },
    timeout: const Timeout(Duration(minutes: 18)),
  );
}
