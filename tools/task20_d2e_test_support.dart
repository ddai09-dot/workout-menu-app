import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'task20_d2d_test_support.dart';

Future<void> createAndFinalizeFirstWeekMenu(WidgetTester tester) async {
  await tapText(tester, 'メニュー');
  await waitForText(tester, '今週のメニューは未作成です');
  await tapText(tester, '今週のメニューを作成する');
  await waitForText(tester, '今週のメニュー');
  await tapText(tester, '今週の予定を入力する');
  await waitForText(tester, '今週の予定');
  expect(find.text('トレーニングする'), findsWidgets);
  await tapText(tester, '体調の確認へ');
  await waitForText(tester, '現在の状態');
  await tapText(tester, '次へ');
  await waitForText(tester, '今週の調整方針');
  await tapText(tester, 'メニューを作成する');
  await waitForText(
    tester,
    'メニューを確認',
    timeout: const Duration(seconds: 90),
  );
  await tapText(tester, 'この内容で確定');
  await waitForText(
    tester,
    '今週を調整',
    timeout: const Duration(seconds: 90),
  );
  expect(find.text('開始'), findsOneWidget);
  expectHealthyFrame(tester);
}

Future<void> selectFirstCupertinoPickerValue(WidgetTester tester) async {
  final pickerFinder = find.byType(CupertinoPicker);
  await waitForFinder(tester, pickerFinder, description: 'CupertinoPicker');
  final picker = tester.widget<CupertinoPicker>(pickerFinder);
  expect(picker.onSelectedItemChanged, isNotNull);
  picker.onSelectedItemChanged!(0);
  await tester.pump(const Duration(milliseconds: 400));
  await tapText(tester, 'この数値を使う');
}

Future<void> chooseDropdownValue(
  WidgetTester tester, {
  required String fieldLabel,
  required String valueLabel,
}) async {
  await tapFinder(
    tester,
    find.text(fieldLabel),
    description: 'dropdown:$fieldLabel',
  );
  await waitForText(tester, valueLabel);
  await tapText(tester, valueLabel);
}

Future<void> waitForFinder(
  WidgetTester tester,
  Finder finder, {
  required String description,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for finder: $description');
}
