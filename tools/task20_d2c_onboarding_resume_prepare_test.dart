import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2C phase 1 saves an onboarding draft beyond three screens',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await _waitForText(
        tester,
        'あなたに合うメニューを作ります',
        timeout: const Duration(seconds: 90),
      );
      await _tapText(tester, '登録を始める');
      await _waitForText(tester, '基本情報');

      final nicknameField = find.byType(TextFormField);
      expect(nicknameField, findsOneWidget);
      await tester.enterText(nicknameField, 'D2再開');
      await tester.pump(const Duration(milliseconds: 400));
      await _chooseFirstPickerValue(tester, '年齢（必須）');
      await _waitForSavingToFinish(tester);
      await _tapText(tester, '次へ');

      await _waitForText(tester, '一番の目的');
      await _tapText(tester, '筋肉を大きくしたい');
      await _tapText(tester, '次へ');

      await _waitForText(tester, 'ほかの目的');
      await _tapText(tester, '特になし');
      await _tapText(tester, '次へ');

      await _waitForText(tester, 'トレーニング経験');
      await _waitForSavingToFinish(tester);
      _expectHealthyFrame(tester);
      await binding.takeScreenshot('D2C_01_saved_midway');
    },
    timeout: const Timeout(Duration(minutes: 6)),
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
  final finder = find.text(text);
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
  throw TestFailure('Timed out waiting to tap: $text');
}

Future<void> _chooseFirstPickerValue(
  WidgetTester tester,
  String label,
) async {
  final labelCandidates = find.text(label);
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (labelCandidates.evaluate().isNotEmpty) {
      final labelFinder = labelCandidates.first;
      await tester.ensureVisible(labelFinder);
      await tester.pump(const Duration(milliseconds: 250));
      final pickerField = find
          .ancestor(of: labelFinder, matching: find.byType(Column))
          .first;
      final placeholder = find.descendant(
        of: pickerField,
        matching: find.text('選択してください'),
      );
      expect(placeholder, findsOneWidget);
      await tester.tap(placeholder);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CupertinoPicker), findsOneWidget);
      await _tapText(tester, 'この数値を使う');
      return;
    }
  }
  throw TestFailure('Timed out waiting for picker: $label');
}

void _expectHealthyFrame(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorWidget), findsNothing);
}
