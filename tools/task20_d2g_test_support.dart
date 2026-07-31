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

Future<void> tapVisibleTextD2G(
  WidgetTester tester,
  String text, {
  int index = 0,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    final visible = find.text(text).hitTestable();
    if (visible.evaluate().length > index) {
      await tester.tap(visible.at(index));
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
  }
  throw TestFailure('Timed out waiting to tap visible text: $text[$index]');
}

Future<void> waitForVisibleTextD2G(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(text).hitTestable().evaluate().isNotEmpty) {
      return;
    }
  }
  throw TestFailure('Timed out waiting for visible text: $text');
}

Future<void> pressVisibleBackControlD2G(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));

    final materialBack = find.byType(BackButton).hitTestable();
    if (materialBack.evaluate().isNotEmpty) {
      await tester.tap(materialBack.first);
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }

    final customBack = find
        .widgetWithIcon(IconButton, Icons.arrow_back)
        .hitTestable();
    if (customBack.evaluate().isNotEmpty) {
      final button = tester.widget<IconButton>(customBack.first);
      if (button.onPressed == null) {
        throw TestFailure('Visible settings back control is disabled.');
      }
      await tester.tap(customBack.first);
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
  }
  throw TestFailure('Timed out waiting for a visible Material back control.');
}
