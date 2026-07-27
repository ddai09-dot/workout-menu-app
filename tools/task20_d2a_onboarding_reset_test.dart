import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_menu_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D2A clean launch, onboarding completion, and local reset',
    (WidgetTester tester) async {
      await app.main();
      await tester.pump();

      await _waitForText(
        tester,
        'あなたに合うメニューを作ります',
        timeout: const Duration(seconds: 90),
      );
      _expectHealthyFrame(tester);
      await binding.takeScreenshot('D2A_01_clean_launch');

      await _tapText(tester, '登録を始める');
      await _waitForText(tester, '基本情報');

      await _tapText(tester, '次へ');
      await _waitForText(tester, 'ニックネームを入力してください。');

      final nicknameField = find.byType(TextFormField);
      expect(nicknameField, findsOneWidget);
      await tester.enterText(nicknameField, 'D2自動');
      await tester.pump(const Duration(milliseconds: 400));
      await _chooseFirstPickerValue(tester, '年齢（必須）');
      await _waitForSavingToFinish(tester);
      await _tapText(tester, '次へ');
      await _waitForText(tester, '一番の目的');

      await _tapTooltip(tester, '戻る');
      await _waitForText(tester, '基本情報');
      expect(find.text('D2自動'), findsOneWidget);
      expect(find.text('13歳'), findsOneWidget);
      await _tapText(tester, '次へ');
      await _waitForText(tester, '一番の目的');

      await _tapText(tester, '筋肉を大きくしたい');
      await _tapText(tester, '次へ');
      await _waitForText(tester, 'ほかの目的');
      await _tapText(tester, '特になし');
      await _tapText(tester, '次へ');

      await _waitForText(tester, 'トレーニング経験');
      await _tapText(tester, '未経験');
      await _tapText(tester, '1〜3か月');
      await _tapText(tester, '次へ');

      await _waitForText(tester, '現在の取り組み方');
      await _chooseFirstPickerValue(tester, '現在または直近の週頻度');
      await _tapText(tester, '自分では調整していない');
      await _tapText(tester, '記録していない');
      await _tapText(tester, '次へ');

      await _waitForText(tester, 'トレーニング環境');
      await _tapText(tester, '自宅');
      await _tapText(tester, '次へ');

      await _waitForText(tester, '使用できる器具');
      await _tapText(tester, '器具なし');
      await _tapText(tester, '次へ');

      await _waitForText(tester, '通常の予定');
      await _chooseFirstPickerValue(tester, '通常希望日数');
      await _tapText(tester, '月曜日');
      await _chooseFirstPickerValue(tester, '通常の1回時間');
      await _tapText(tester, '次へ');

      await _waitForText(tester, 'メニューの分け方');
      await _tapText(tester, 'アプリのおすすめに任せる');
      await _tapText(tester, '次へ');

      await _waitForText(tester, '優先部位・見た目');
      await _tapText(tester, '全身をバランスよく鍛えたい');
      await _tapTextAt(tester, '特にない', 0);
      await _tapTextAt(tester, '特にない', 1);
      await _tapText(tester, '次へ');

      await _waitForText(tester, '痛み・身体上の制限');
      await _tapText(tester, '次へ');

      await _waitForText(tester, '登録内容の確認');
      expect(find.textContaining('D2自動'), findsOneWidget);
      expect(find.text('筋肉を大きくしたい'), findsOneWidget);
      await binding.takeScreenshot('D2A_02_onboarding_review');
      await _tapText(tester, 'この内容で登録する');

      await _waitForText(
        tester,
        '今日やること',
        timeout: const Duration(seconds: 60),
      );
      _expectHealthyFrame(tester);
      await binding.takeScreenshot('D2A_03_home_after_onboarding');

      await _tapText(tester, 'マイページ');
      await _waitForText(tester, 'トレーニング設定');
      await _scrollUntilTextVisible(tester, '端末内データ');
      await _tapText(tester, '端末内データ');
      await _waitForText(tester, '端末内データを初期化');
      await _waitForText(tester, '削除されるもの');
      await _scrollUntilTextVisible(tester, '削除されないもの');
      expect(find.text('削除されないもの'), findsOneWidget);
      await _scrollUntilTextVisible(
        tester,
        '削除したデータは元に戻せないことを確認しました',
      );
      await _scrollUntilTextVisible(tester, '端末内データを削除');

      final resetButton =
          find.widgetWithText(FilledButton, '端末内データを削除');
      expect(resetButton, findsOneWidget);
      expect(tester.widget<FilledButton>(resetButton).onPressed, isNull);
      await binding.takeScreenshot('D2A_04_reset_before_acknowledgement');

      await _tapText(tester, '削除したデータは元に戻せないことを確認しました');
      expect(tester.widget<FilledButton>(resetButton).onPressed, isNotNull);
      await _tapText(tester, '端末内データを削除');
      await _waitForText(tester, 'すべて削除しますか？');
      await _tapText(tester, 'キャンセル');
      await _waitForText(tester, '端末内データを削除');

      await _tapText(tester, '端末内データを削除');
      await _waitForText(tester, 'すべて削除しますか？');
      await _tapText(tester, '削除する');
      await _waitForText(
        tester,
        'あなたに合うメニューを作ります',
        timeout: const Duration(seconds: 60),
      );
      expect(find.text('登録を始める'), findsOneWidget);
      expect(find.text('今日やること'), findsNothing);
      _expectHealthyFrame(tester);
      await binding.takeScreenshot('D2A_05_after_local_reset');
    },
    timeout: const Timeout(Duration(minutes: 12)),
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

Future<void> _scrollUntilTextVisible(
  WidgetTester tester,
  String text, {
  int maxScrolls = 12,
}) async {
  final target = find.text(text);
  for (var attempt = 0; attempt <= maxScrolls; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 250));
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
    final listViews = find.byType(ListView);
    if (listViews.evaluate().isEmpty) {
      throw TestFailure('No ListView available while scrolling for: $text');
    }
    await tester.drag(listViews.first, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 400));
  }
  throw TestFailure('Timed out scrolling to text: $text');
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await _tapFinder(tester, find.text(text), description: text);
}

Future<void> _tapTextAt(WidgetTester tester, String text, int index) async {
  final all = find.text(text);
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (all.evaluate().length > index) {
      await _tapFinder(
        tester,
        all.at(index),
        description: '$text[$index]',
      );
      return;
    }
  }
  throw TestFailure('Timed out waiting for text occurrence: $text[$index]');
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
