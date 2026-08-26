import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Offset _forwardDragOffsetD2G(AxisDirection direction, double delta) {
  switch (direction) {
    case AxisDirection.down:
      return Offset(0, -delta);
    case AxisDirection.up:
      return Offset(0, delta);
    case AxisDirection.right:
      return Offset(-delta, 0);
    case AxisDirection.left:
      return Offset(delta, 0);
  }
}

Future<void> scrollToTextD2G(
  WidgetTester tester,
  String text, {
  double delta = 320,
  bool useLastScrollable = false,
}) async {
  if (delta <= 0) {
    throw TestFailure('D2G scroll delta must be positive: $delta');
  }

  final scrollables = find.byType(Scrollable).hitTestable();
  expect(scrollables, findsWidgets);
  final verticalElements = scrollables.evaluate().where((element) {
    final scrollable = element.widget as Scrollable;
    return scrollable.axisDirection == AxisDirection.down ||
        scrollable.axisDirection == AxisDirection.up;
  }).toList();
  if (verticalElements.isEmpty) {
    throw TestFailure('No visible vertical Scrollable while finding: $text');
  }
  final selectedElement =
      useLastScrollable ? verticalElements.last : verticalElements.first;
  final scrollableFinder =
      find.byElementPredicate((element) => element == selectedElement);
  final deadline = DateTime.now().add(const Duration(seconds: 30));

  Future<bool> targetIsAvailable() async {
    await tester.pump(const Duration(milliseconds: 250));
    final targetInScrollable = find.descendant(
      of: scrollableFinder,
      matching: find.text(text),
    );
    if (targetInScrollable.evaluate().isEmpty) {
      return false;
    }
    await tester.ensureVisible(targetInScrollable.first);
    await tester.pump(const Duration(milliseconds: 300));
    return true;
  }

  Future<bool> scan({required bool forward}) async {
    while (DateTime.now().isBefore(deadline)) {
      if (await targetIsAvailable()) {
        return true;
      }

      final scrollable = tester.widget<Scrollable>(scrollableFinder);
      final state = tester.state<ScrollableState>(scrollableFinder);
      final position = state.position;
      final remaining = forward ? position.extentAfter : position.extentBefore;
      if (remaining <= 0.5) {
        return false;
      }
      final distance = math.min(delta, remaining + 1);
      await tester.drag(
        scrollableFinder,
        _forwardDragOffsetD2G(
          scrollable.axisDirection,
          forward ? distance : -distance,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    return false;
  }

  // Search in the natural forward direction first. If the target was lazily
  // disposed above the current viewport, reach the end and then scan back.
  // This mirrors what a user can do and does not relax the target assertion.
  if (await scan(forward: true) || await scan(forward: false)) {
    return;
  }
  throw TestFailure('Timed out scrolling to text: $text');
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

String? currentPathD2G(WidgetTester tester) {
  final visibleText = find.byType(Text).hitTestable();
  if (visibleText.evaluate().isEmpty) {
    return null;
  }
  final context = tester.element(visibleText.first);
  return GoRouter.of(context)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;
}

Future<void> waitForPathD2G(
  WidgetTester tester,
  String expectedPath, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  String? lastPath;
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    lastPath = currentPathD2G(tester);
    if (lastPath == expectedPath) {
      return;
    }
  }
  throw TestFailure(
    'Timed out waiting for route: $expectedPath; last route: $lastPath',
  );
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
