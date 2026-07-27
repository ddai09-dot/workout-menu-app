import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2C phase 2 restores and resets the onboarding draft after relaunch',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await _waitForText(
        tester,
        '登録の続きがあります',
        timeout: const Duration(seconds: 90),
      );
      expect(find.text('続きから再開'), findsOneWidget);
      _expectHealthyFrame(tester);
      await binding.takeScreenshot('D2C_02_resume_prompt');

      await _tapText(tester, '最初からやり直す');
      await _waitForText(tester, '最初からやり直しますか？');
      await _tapText(tester, 'キャンセル');
      await _waitForText(tester, '登録の続きがあります');

      await _tapText(tester, '続きから再開');
      await _waitForText(tester, 'トレーニング経験');
      _expectHealthyFrame(tester);
      await binding.takeScreenshot('D2C_03_resumed_step');

      await _tapTooltip(tester, '戻る');
      await _waitForText(tester, 'ほかの目的');
      await _tapTooltip(tester, '戻る');
      await _waitForText(tester, '一番の目的');
      await _tapTooltip(tester, '戻る');
      await _waitForText(tester, '基本情報');
      expect(find.text('D2再開'), findsOneWidget);
      expect(find.text('13歳'), findsOneWidget);
      await binding.takeScreenshot('D2C_04_values_restored');

      await _tapText(tester, '最初からやり直す');
      await _waitForText(tester, '最初からやり直しますか？');
      await _tapText(tester, 'キャンセル');
      await _waitForText(tester, '基本情報');
      expect(find.text('D2再開'), findsOneWidget);
      expect(find.text('13歳'), findsOneWidget);

      await _tapText(tester, '最初からやり直す');
      await _waitForText(tester, '最初からやり直しますか？');
      await _tapText(tester, 'やり直す');
      await _waitForText(
        tester,
        'あなたに合うメニューを作ります',
        timeout: const Duration(seconds: 60),
      );
      expect(find.text('D2再開'), findsNothing);
      _expectHealthyFrame(tester);
      await binding.takeScreenshot('D2C_05_reset_to_intro');
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<void> _waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 30),
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

Future<void> _waitForSavingToFinish(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.text('保存中…').evaluate().isEmpty) {
      return;
    }
  }
  throw TestFailure('Timed out waiting for the onboarding save queue.');
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await _tapFinder(tester, find.text(text), description: text);
}

Future<void> _tapTooltip(WidgetTester tester, String tooltip) async {
  await _tapFinder(
    tester,
    find.byTooltip(tooltip),
    description: 'tooltip:$tooltip',
  );
}

Future<void> _tapFinder(
  WidgetTester tester,
  Finder finder, {
  required String description,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) {
      final target = finder.first;
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 500));
      await _waitForSavingToFinish(tester);
      return;
    }
  }
  throw TestFailure('Timed out waiting to tap: $description');
}

void _expectHealthyFrame(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorWidget), findsNothing);
}
