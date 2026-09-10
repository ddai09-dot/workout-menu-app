import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/core/database/app_database.dart';
import 'package:workout_menu_app/core/database/providers/database_providers.dart';
import 'package:workout_menu_app/core/widgets/primary_action_button.dart';
import 'package:workout_menu_app/features/settings/domain/training_settings_repository.dart';
import 'package:workout_menu_app/features/settings/presentation/training_settings_providers.dart';
import 'package:workout_menu_app/main.dart' as app;

import 'task20_d2d_test_support.dart';
import 'task20_d2e_test_support.dart';
import 'task20_d2g_test_support.dart';

Future<String> snapshotCurrentMenu(AppDatabase database) async {
  const tables = <String>[
    'training_week',
    'weekly_menu',
    'workout_day_plan',
    'planned_exercise',
    'planned_set',
  ];
  final snapshot = <String, Object?>{};
  for (final table in tables) {
    final rows = await database
        .customSelect('SELECT * FROM $table WHERE deleted_at IS NULL ORDER BY id')
        .get();
    snapshot[table] = rows
        .map((row) => Map<String, Object?>.from(row.data))
        .toList(growable: false);
  }
  return jsonEncode(snapshot);
}

void expectSaveButtonEnabled(WidgetTester tester, bool enabled) {
  final finder = find.byType(PrimaryActionButton);
  expect(finder, findsOneWidget);
  final button = tester.widget<PrimaryActionButton>(finder);
  expect(button.onPressed, enabled ? isNotNull : isNull);
}

Future<void> verifySectionRoute(
  WidgetTester tester, {
  required String title,
  required String description,
}) async {
  await scrollToTextD2G(tester, title);
  await tapText(tester, title);
  await waitForText(tester, description);
  expectSaveButtonEnabled(tester, false);
  expectHealthyFrame(tester);
  await pressVisibleBackControlD2G(tester);
  await waitForText(tester, 'トレーニング目的');
}

Future<void> waitForGoalSaveOutcomeD2G(
  WidgetTester tester, {
  required TrainingSettingsRepository settingsRepository,
  required IntegrationTestWidgetsFlutterBinding binding,
}) async {
  const errorText =
      '変更を保存できませんでした。入力内容は画面に残っています。もう一度お試しください。';
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text('トレーニング設定').evaluate().isNotEmpty) {
      return;
    }
    if (find.text(errorText).evaluate().isNotEmpty) {
      await binding.takeScreenshot('DIAG_D2G_goal_save_failed');
      final snapshot = await settingsRepository.load();
      throw TestFailure(
        'Goal save failed in UI. Persisted primaryGoalCode: '
        '${snapshot.draft.primaryGoalCode}; expected: STRENGTH.',
      );
    }
  }
  await binding.takeScreenshot('DIAG_D2G_goal_save_timeout');
  final snapshot = await settingsRepository.load();
  throw TestFailure(
    'Timed out waiting for goal save navigation. Persisted primaryGoalCode: '
    '${snapshot.draft.primaryGoalCode}; expected: STRENGTH.',
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2G validates My Page settings, discard, save impact, FAQ, and data entry',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await completeD2DOnboarding(tester);
      await createAndFinalizeFirstWeekMenu(tester);

      await tapNavigationLabelD2G(tester, 'マイページ');
      await waitForText(tester, 'トレーニング設定');
      expect(find.text('トレーニング目的'), findsOneWidget);
      expect(find.text('経験・継続状況'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2G_01_my_page_sections_top');

      final myPageContext = tester.element(find.text('トレーニング設定'));
      final container = ProviderScope.containerOf(myPageContext);
      final database = container.read(appDatabaseProvider);
      final settingsRepository = container.read(trainingSettingsRepositoryProvider);
      final menuBeforeSettings = await snapshotCurrentMenu(database);

      const sectionDescriptions = <String, String>{
        'トレーニング目的': '主目的と副目的を変更します。',
        '経験・継続状況': '経験期間、現在の頻度、記録習慣を変更します。',
        '環境・器具': '利用場所と、実際に使用できる器具を変更します。',
        '通常の予定': '通常の日数、曜日、時間、場所を変更します。',
        'メニューの分け方': '動作別、部位別、アプリおすすめから選びます。',
        '優先部位': '優先部位、見た目の希望、腹筋の目的を変更します。',
        '痛み・身体上の制限': '痛みの扱いと、避ける部位・動作・種目を変更します。',
      };
      for (final entry in sectionDescriptions.entries) {
        await verifySectionRoute(
          tester,
          title: entry.key,
          description: entry.value,
        );
      }

      await scrollToTextD2G(tester, '用語・FAQ');
      expect(find.text('端末内データ'), findsOneWidget);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2G_02_my_page_sections_bottom');

      await scrollToTextD2G(tester, 'メニューの分け方');
      await tapText(tester, 'メニューの分け方');
      await waitForText(tester, 'アプリのおすすめに任せる');
      await tapText(tester, '部位を基準に分ける');
      expectSaveButtonEnabled(tester, true);
      await pressVisibleBackControlD2G(tester);
      await waitForText(tester, '変更を破棄しますか？');
      await binding.takeScreenshot('D2G_03_discard_confirmation');
      await tapText(tester, '編集を続ける');
      await waitForText(tester, 'メニューの分け方');
      expectSaveButtonEnabled(tester, true);
      await pressVisibleBackControlD2G(tester);
      await waitForText(tester, '変更を破棄しますか？');
      await tapText(tester, '破棄する');
      await waitForText(tester, 'トレーニング設定');
      final afterDiscard = await settingsRepository.load();
      expect(afterDiscard.draft.splitPreferenceCode, 'APP');
      expect(await snapshotCurrentMenu(database), menuBeforeSettings);

      await scrollToTextD2G(tester, 'トレーニング目的');
      await tapText(tester, 'トレーニング目的');
      await waitForText(tester, '筋肉を大きくしたい');
      expect(find.text('筋力を高めたい'), findsNWidgets(2));
      await tapTextAt(tester, '筋力を高めたい', 0);
      expectSaveButtonEnabled(tester, true);
      await tapText(tester, '変更を保存する');
      await waitForGoalSaveOutcomeD2G(
        tester,
        settingsRepository: settingsRepository,
        binding: binding,
      );
      final afterGoalSave = await settingsRepository.load();
      expect(afterGoalSave.draft.primaryGoalCode, 'STRENGTH');
      expect(await snapshotCurrentMenu(database), menuBeforeSettings);
      await waitForText(tester, '筋力を高めたい');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2G_04_goal_saved');

      await scrollToTextD2G(tester, '痛み・身体上の制限');
      await tapText(tester, '痛み・身体上の制限');
      await waitForText(tester, '現在、痛みや違和感がある部位');
      await tapTextAt(tester, '肩', 0);
      expectSaveButtonEnabled(tester, true);
      await tapText(tester, '変更を保存する');
      await waitForText(
        tester,
        '今週のメニューも確認しますか？',
        timeout: const Duration(seconds: 90),
      );
      expect(
        find.textContaining('作成済みメニューは自動変更していません'),
        findsOneWidget,
      );
      await binding.takeScreenshot('D2G_05_restriction_review_prompt');
      await tapText(tester, '今は変更しない');
      await waitForText(tester, 'トレーニング設定');
      final afterRestrictionSave = await settingsRepository.load();
      expect(
        afterRestrictionSave.draft.painActionsByArea['JOINT:JT001'],
        'REDUCE_LOAD',
      );
      expect(await snapshotCurrentMenu(database), menuBeforeSettings);
      final appliesFromRows = await database.customSelect('''
        SELECT change_applies_from
        FROM user_training_setting
        WHERE deleted_at IS NULL
        ORDER BY updated_at DESC
        LIMIT 1
      ''').get();
      expect(appliesFromRows, hasLength(1));
      expect(
        appliesFromRows.single.read<String>('change_applies_from'),
        'NEXT_MENU',
      );
      await scrollToTextD2G(tester, '痛み・身体上の制限');
      await waitForText(tester, '1件設定');
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2G_06_restriction_saved');

      await scrollToTextD2G(tester, '用語・FAQ');
      await tapText(tester, '用語・FAQ');
      await waitForText(tester, 'RPE');
      await waitForText(tester, 'ダブルプログレッション');
      await tapText(tester, 'RPE');
      await waitForText(
        tester,
        '主観的運動強度。あと何回できそうかを含めて、きつさを評価する考え方です。',
      );
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2G_07_faq');
      await pressVisibleBackControlD2G(tester);
      await waitForText(tester, 'トレーニング設定');

      await scrollToTextD2G(tester, '端末内データ');
      await tapText(tester, '端末内データ');
      await waitForText(tester, '端末内データを初期化');
      await waitForText(tester, '削除されるもの');
      await scrollToTextD2G(tester, '削除されないもの');
      await scrollToTextD2G(tester, '端末内データを削除');
      final deleteButton = find.ancestor(
        of: find.text('端末内データを削除'),
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      expect(deleteButton, findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(deleteButton).onPressed, isNull);
      expectHealthyFrame(tester);
      await binding.takeScreenshot('D2G_08_data_reset_entry');
    },
    timeout: const Timeout(Duration(minutes: 18)),
  );
}
