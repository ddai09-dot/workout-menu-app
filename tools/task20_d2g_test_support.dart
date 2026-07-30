import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> scrollToTextD2G(
  WidgetTester tester,
  String text, {
  double delta = 320,
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

Future<void> tapNavigationLabelD2G(
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
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (navigationBarFinder.evaluate().isNotEmpty) {
      final navigationBar = tester.widget<NavigationBar>(navigationBarFinder);
      final callback = navigationBar.onDestinationSelected;
      if (callback == null) {
        throw TestFailure('NavigationBar.onDestinationSelected is null.');
      }
      callback(index);
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
  }
  throw TestFailure('Timed out waiting for NavigationBar.');
}

Future<void> pressVisibleBackControlD2G(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));

    final materialBack = find.byType(BackButton);
    if (materialBack.evaluate().isNotEmpty) {
      await tester.tap(materialBack.first);
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }

    final customBack = find.widgetWithIcon(IconButton, Icons.arrow_back);
    if (customBack.evaluate().isNotEmpty) {
      final button = tester.widget<IconButton>(customBack.first);
      final callback = button.onPressed;
      if (callback == null) {
        throw TestFailure('Visible settings back control is disabled.');
      }
      callback();
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
  }
  throw TestFailure('Timed out waiting for a visible Material back control.');
}
