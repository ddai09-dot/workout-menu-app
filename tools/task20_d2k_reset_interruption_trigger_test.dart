// ignore_for_file: avoid_print

import 'dart:convert';

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
    'D2K enters the secure-key-switched transaction-blocked reset window',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();
      await d2iWaitForText(tester, 'ホーム');

      final runtime = d2iRuntimeContext(tester);
      final encoded = await runtime.secureStore.read(d2kMetadataKey);
      expect(encoded, isNotNull);
      final metadata = jsonDecode(encoded!) as Map<String, dynamic>;
      final oldUserId = metadata['oldUserId']! as String;
      expect(await runtime.secureStore.read('current_user_id'), oldUserId);

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
      await d2iTapText(tester, '端末内データを削除');
      await d2iWaitForText(tester, 'すべて削除しますか？');
      await d2iTapText(tester, '削除する');

      String? interruptedReplacementUserId;
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
        final currentUserId =
            await runtime.secureStore.read('current_user_id');
        if (currentUserId != null && currentUserId != oldUserId) {
          interruptedReplacementUserId = currentUserId;
          break;
        }
      }
      expect(interruptedReplacementUserId, isNotNull);
      await runtime.secureStore.write(
        key: d2kInterruptedReplacementKey,
        value: interruptedReplacementUserId!,
      );
      expect(find.text('削除しています'), findsOneWidget);
      d2iExpectHealthyFrame(tester);
      await binding.takeScreenshot('D2K_02_reset_blocked_in_progress');

      final reportData = binding.reportData ??= <String, dynamic>{};
      reportData['task'] = 'Task20-D2K';
      reportData['phase'] = 'TRIGGER';
      reportData['metadata'] = <String, Object?>{
        'old_user_id': oldUserId,
        'replacement_user_id': interruptedReplacementUserId,
        'secure_key_switched': true,
      };
      print(
        'D2K_RESET_CRITICAL_WINDOW_READY '
        'oldUserId=$oldUserId '
        'replacementUserId=$interruptedReplacementUserId',
      );

      // The host-side acceptance runner terminates the app after the marker
      // above while an external SQLite write lock keeps resetLocalData inside
      // its transaction attempt. The loop intentionally never completes on
      // its own; OS termination is the expected end of this phase.
      while (true) {
        await tester.pump(const Duration(seconds: 1));
      }
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
