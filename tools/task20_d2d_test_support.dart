import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_menu_app/features/onboarding/presentation/widgets/choice_card.dart';

Future<void> completeD2DOnboarding(WidgetTester tester) async {
  await waitForText(
    tester,
    'あなたに合うメニューを作ります',
    timeout: const Duration(seconds: 90),
  );
  await tapText(tester, '登録を始める');
  await waitForText(tester, '基本情報');

  final nicknameField = find.byType(TextFormField);
  expect(nicknameField, findsOneWidget);
  await tester.enterText(nicknameField, 'D2週間');
  await tester.pump(const Duration(milliseconds: 400));
  await chooseFirstPickerValue(tester, '年齢（必須）');
  await waitForOnboardingSavingToFinish(tester);
  await tapText(tester, '次へ');

  await waitForText(tester, '一番の目的');
  await tapText(tester, '筋肉を大きくしたい');
  await tapText(tester, '次へ');

  await waitForText(tester, 'ほかの目的');
  await tapText(tester, '特になし');
  await tapText(tester, '次へ');

  await waitForText(tester, 'トレーニング経験');
  await tapText(tester, '未経験');
  await tapText(tester, '1〜3か月');
  await tapText(tester, '次へ');

  await waitForText(tester, '現在の取り組み方');
  await chooseFirstPickerValue(tester, '現在または直近の週頻度');
  await tapText(tester, '自分では調整していない');
  await tapText(tester, '記録していない');
  await tapText(tester, '次へ');

  await waitForText(tester, 'トレーニング環境');
  await tapText(tester, '自宅');
  await tapText(tester, '次へ');

  await waitForText(tester, '使用できる器具');
  await tapText(tester, '器具なし');
  await tapText(tester, '次へ');

  await waitForText(tester, '通常の予定');
  await chooseFirstPickerValue(tester, '通常希望日数');
  await tapText(tester, '月曜日');
  await chooseFirstPickerValue(tester, '通常の1回時間');
  await tapText(tester, '次へ');

  await waitForText(tester, 'メニューの分け方');
  await tapText(tester, 'アプリのおすすめに任せる');
  await tapText(tester, '次へ');

  await waitForText(tester, '優先部位・見た目');
  await tapText(tester, '全身をバランスよく鍛えたい');
  await tapTextAt(tester, '特にない', 0);
  await tapTextAt(tester, '特にない', 1);
  await tapText(tester, '次へ');

  await waitForText(tester, '痛み・身体上の制限');
  await tapText(tester, '次へ');

  await waitForText(tester, '登録内容の確認');
  expect(find.textContaining('D2週間'), findsOneWidget);
  await tapText(tester, 'この内容で登録する');
  await waitForText(
    tester,
    '今日やること',
    timeout: const Duration(seconds: 60),
  );
  expectHealthyFrame(tester);
}

Future<void> waitForText(
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

Future<String> waitForAnyText(
  WidgetTester tester,
  List<String> texts, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    for (final text in texts) {
      if (find.text(text).evaluate().isNotEmpty) {
        return text;
      }
    }
  }
  throw TestFailure('Timed out waiting for any text: ${texts.join(', ')}');
}

Future<void> waitForOnboardingSavingToFinish(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.text('保存中…').evaluate().isEmpty) {
      return;
    }
  }
  throw TestFailure('Timed out waiting for the onboarding save queue.');
}

Future<void> waitForWeeklySavingToFinish(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    final progressCount = find.byType(LinearProgressIndicator).evaluate().length;
    if (progressCount <= 1) {
      return;
    }
  }
  throw TestFailure('Timed out waiting for the weekly planner save queue.');
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tapFinder(tester, find.text(text), description: text);
}

Future<void> tapTextAt(
  WidgetTester tester,
  String text,
  int index,
) async {
  final all = find.text(text);
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (all.evaluate().length > index) {
      await tapFinder(
        tester,
        all.at(index),
        description: '$text[$index]',
      );
      return;
    }
  }
  throw TestFailure('Timed out waiting for text occurrence: $text[$index]');
}

Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
  await tapFinder(
    tester,
    find.byTooltip(tooltip),
    description: 'tooltip:$tooltip',
  );
}

Future<void> tapFinder(
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
      await waitForOnboardingSavingToFinish(tester);
      return;
    }
  }
  throw TestFailure('Timed out waiting to tap: $description');
}

Future<void> chooseFirstPickerValue(
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
      await tapText(tester, 'この数値を使う');
      return;
    }
  }
  throw TestFailure('Timed out waiting for picker: $label');
}

Future<void> selectSegmentValue(
  WidgetTester tester, {
  required int selectorIndex,
  required int value,
}) async {
  final selectors = find.byType(SegmentedButton<int>);
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (selectors.evaluate().length > selectorIndex) {
      final selector = selectors.at(selectorIndex);
      final valueFinder = find.descendant(
        of: selector,
        matching: find.text('$value'),
      );
      expect(valueFinder, findsOneWidget);
      await tester.ensureVisible(valueFinder);
      await tester.tap(valueFinder);
      await tester.pump(const Duration(milliseconds: 500));
      await waitForWeeklySavingToFinish(tester);
      return;
    }
  }
  throw TestFailure(
    'Timed out waiting for segmented selector $selectorIndex value $value',
  );
}

void expectSegmentValue(
  WidgetTester tester, {
  required int selectorIndex,
  required int value,
}) {
  final selectors = find.byType(SegmentedButton<int>);
  expect(selectors.evaluate().length, greaterThan(selectorIndex));
  final selector = tester.widget<SegmentedButton<int>>(
    selectors.at(selectorIndex),
  );
  expect(selector.selected, <int>{value});
}

void expectChoiceSelected(WidgetTester tester, String label) {
  final finder = find.widgetWithText(ChoiceCard, label);
  expect(finder, findsOneWidget);
  expect(tester.widget<ChoiceCard>(finder).selected, isTrue);
}

void expectHealthyFrame(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorWidget), findsNothing);
}
