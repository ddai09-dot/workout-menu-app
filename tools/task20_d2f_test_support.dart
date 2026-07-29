import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'task20_d2d_test_support.dart';
import 'task20_d2e_test_support.dart';

Future<void> completePartialWorkoutForRecords(WidgetTester tester) async {
  await completeD2DOnboarding(tester);
  await createAndFinalizeFirstWeekMenu(tester);

  await tapText(tester, '開始');
  await waitForText(tester, '開始前の確認');
  await waitForText(
    tester,
    '予定どおり開始する',
    timeout: const Duration(seconds: 60),
  );
  await tapText(tester, '予定どおり開始する');
  await waitForText(
    tester,
    'トレーニング中',
    timeout: const Duration(seconds: 90),
  );
  await waitForText(tester, '1 / 2種目');

  await scrollToTextD2F(tester, 'その他の操作');
  await tapText(tester, 'その他の操作');
  await scrollToTextD2F(
    tester,
    'セット数を変更する',
    delta: 200,
    useLastScrollable: true,
  );
  await tapText(tester, 'セット数を変更する');
  await waitForText(tester, 'セット数');
  await selectFirstCupertinoPickerValue(tester);
  await waitForText(tester, 'セット 1 / 1');

  await tapText(tester, 'セット完了');
  await waitForText(tester, '休憩');
  if (find.text('休憩を終了する').evaluate().isNotEmpty) {
    await tapText(tester, '休憩を終了する');
  }
  await waitForText(tester, '次の種目へ');
  await tapText(tester, '次の種目へ');
  await waitForText(tester, '2 / 2種目');

  await scrollToTextD2F(tester, 'その他の操作');
  await tapText(tester, 'その他の操作');
  await scrollToTextD2F(
    tester,
    '途中で終了',
    delta: 200,
    useLastScrollable: true,
  );
  await tapText(tester, '途中で終了');
  await waitForText(tester, 'ここまでを記録して終了しますか？');
  await tapText(tester, '終了する');
  await waitForText(
    tester,
    '終了後の記録',
    timeout: const Duration(seconds: 90),
  );
  await chooseDropdownValue(
    tester,
    fieldLabel: '理由を選択',
    valueLabel: '自分の判断',
  );
  await tapText(tester, '記録して終了');
  await waitForText(
    tester,
    '今日やること',
    timeout: const Duration(seconds: 90),
  );
  expectHealthyFrame(tester);
}

Future<void> scrollToTextD2F(
  WidgetTester tester,
  String text, {
  double delta = 300,
  bool useLastScrollable = false,
}) async {
  final scrollables = find.byType(Scrollable);
  expect(scrollables, findsWidgets);
  await tester.scrollUntilVisible(
    find.text(text),
    delta,
    scrollable: useLastScrollable ? scrollables.last : scrollables.first,
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> tapNavigationLabelD2F(
  WidgetTester tester,
  String label,
) async {
  const destinationIndexes = <String, int>{
    'ホーム': 0,
    'メニュー': 1,
    '記録': 2,
    'マイページ': 3,
  };
  final index = destinationIndexes[label];
  if (index == null) {
    throw TestFailure('Unknown navigation destination: $label');
  }

  final navigationBarFinder = find.byType(NavigationBar);
  await waitForFinder(
    tester,
    navigationBarFinder,
    description: 'NavigationBar',
  );
  final navigationBar = tester.widget<NavigationBar>(navigationBarFinder);
  final callback = navigationBar.onDestinationSelected;
  if (callback == null) {
    throw TestFailure('NavigationBar.onDestinationSelected is null.');
  }
  callback(index);
  await tester.pump(const Duration(milliseconds: 500));
}
