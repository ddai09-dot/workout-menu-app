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

  // Do not require the Scrollable's center point to be hit-testable here.
  // With accessibility-extra-large, a transient enlarged SnackBar can cover
  // that center point even though the My Page ListView remains visibly exposed
  // and user-scrollable in its upper region. Restrict to onstage, attached,
  // vertical Scrollables, then start the real drag from the exposed upper part
  // of the selected RenderBox below.
  final scrollables = find.byType(Scrollable);
  final verticalElements = scrollables.evaluate().where((element) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return false;
    }
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

  Future<void> dragForward(double distance) async {
    final scrollable = tester.widget<Scrollable>(scrollableFinder);
    final renderBox = tester.renderObject<RenderBox>(scrollableFinder);
    if (renderBox.size.width <= 24 || renderBox.size.height <= 24) {
      throw TestFailure(
        'D2G Scrollable has no usable drag surface while finding: $text; '
        'size=${renderBox.size}',
      );
    }
    final preferredY = renderBox.size.height * 0.20;
    final localY = math.max(
      12.0,
      math.min(preferredY, renderBox.size.height - 12.0),
    );
    final dragStart = renderBox.localToGlobal(
      Offset(renderBox.size.width / 2, localY),
    );
    await tester.dragFrom(
      dragStart,
      _forwardDragOffsetD2G(scrollable.axisDirection, distance),
    );
  }

  if (await targetIsAvailable()) {
    return;
  }

  // When enlarged text causes ListView children above the current viewport to
  // be lazily disposed, reset the same scroll position to its start and scan
  // forward again with real drag gestures. This keeps the target assertion and
  // user-scroll reachability intact while avoiding direction-dependent lazy
  // child discovery.
  final initialState = tester.state<ScrollableState>(scrollableFinder);
  final initialPosition = initialState.position;
  if (initialPosition.extentBefore > 0.5) {
    initialPosition.jumpTo(initialPosition.minScrollExtent);
    await tester.pump(const Duration(milliseconds: 500));
    if (await targetIsAvailable()) {
      return;
    }
  }

  while (DateTime.now().isBefore(deadline)) {
    final state = tester.state<ScrollableState>(scrollableFinder);
    final position = state.position;
    final remaining = position.extentAfter;
    if (remaining <= 0.5) {
      break;
    }
    final distance = math.min(delta, remaining + 1);
    await dragForward(distance);
    await tester.pump(const Duration(milliseconds: 300));
    if (await targetIsAvailable()) {
      return;
    }
  }

  final finalState = tester.state<ScrollableState>(scrollableFinder);
  final finalPosition = finalState.position;
  throw TestFailure(
    'Timed out scrolling to text: $text; '
    'pixels=${finalPosition.pixels.toStringAsFixed(1)}, '
    'min=${finalPosition.minScrollExtent.toStringAsFixed(1)}, '
    'max=${finalPosition.maxScrollExtent.toStringAsFixed(1)}',
  );
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
