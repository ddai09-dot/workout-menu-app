#!/usr/bin/env python3
from __future__ import annotations

import shutil
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2d_prepare_ui_acceptance.py <app-dir>")

    repo_root = Path(__file__).resolve().parents[1]
    app_dir = Path(sys.argv[1]).resolve()
    pubspec = app_dir / "pubspec.yaml"
    if not pubspec.is_file():
        raise SystemExit(f"pubspec.yaml not found: {pubspec}")

    source_files = {
        repo_root / "tools" / "task20_d2d_test_support.dart":
            app_dir / "integration_test" / "task20_d2d_test_support.dart",
        repo_root / "tools" / "task20_d2d_weekly_planner_prepare_test.dart":
            app_dir / "integration_test" / "task20_d2d_weekly_planner_prepare_test.dart",
        repo_root / "tools" / "task20_d2d_weekly_planner_verify_test.dart":
            app_dir / "integration_test" / "task20_d2d_weekly_planner_verify_test.dart",
        repo_root / "tools" / "task20_d2d_driver.dart":
            app_dir / "test_driver" / "task20_d2d_driver.dart",
    }
    for source in source_files:
        if not source.is_file():
            raise SystemExit(f"test overlay source not found: {source}")

    text = pubspec.read_text(encoding="utf-8")
    anchor = "  flutter_test:\n    sdk: flutter\n"
    if text.count(anchor) != 1:
        raise SystemExit("expected exactly one flutter_test SDK dependency")
    missing = [
        dependency
        for dependency in (
            "  integration_test:\n    sdk: flutter\n",
            "  flutter_driver:\n    sdk: flutter\n",
        )
        if dependency not in text
    ]
    if missing:
        pubspec.write_text(
            text.replace(anchor, anchor + "".join(missing), 1),
            encoding="utf-8",
        )

    for source, destination in source_files.items():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)

    # Rebuild the picker helper rather than patching a fragile sub-block. At the
    # maximum Dynamic Type category the placeholder glyphs can be covered by
    # the fixed bottom action while the enclosing control remains reachable.
    # Match the proven D2A interaction: target the tappable InkWell, ensure that
    # control is visible, then tap the control instead of the Text glyphs.
    support = app_dir / "integration_test" / "task20_d2d_test_support.dart"
    support_text = support.read_text(encoding="utf-8")
    start_marker = "Future<void> chooseFirstPickerValue(\n"
    end_marker = "\nFuture<void> selectSegmentValue(\n"
    if support_text.count(start_marker) != 1 or support_text.count(end_marker) != 1:
        raise SystemExit("expected exactly one D2D picker helper")
    start = support_text.index(start_marker)
    end = support_text.index(end_marker, start)
    helper = """Future<void> chooseFirstPickerValue(
  WidgetTester tester,
  String label,
) async {
  final labelCandidates = find.text(label);
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (labelCandidates.evaluate().isNotEmpty) {
      final labelFinder = labelCandidates.first;
      final pickerField = find
          .ancestor(of: labelFinder, matching: find.byType(Column))
          .first;
      final placeholder = find.descendant(
        of: pickerField,
        matching: find.text('選択してください'),
      );
      expect(placeholder, findsOneWidget);
      final pickerTapTarget = find.ancestor(
        of: placeholder,
        matching: find.byType(InkWell),
      );
      expect(pickerTapTarget, findsOneWidget);
      await tester.ensureVisible(pickerTapTarget.first);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(pickerTapTarget.first);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CupertinoPicker), findsOneWidget);
      await tapText(tester, 'この数値を使う');
      return;
    }
    await _scrollPrimaryVerticalScrollableForward(tester);
  }
  throw TestFailure('Timed out waiting for picker: $label');
}
"""
    support_text = support_text[:start] + helper + support_text[end:]
    support.write_text(support_text, encoding="utf-8")

    verified = support.read_text(encoding="utf-8")
    if "await tester.tap(placeholder);" in verified:
        raise SystemExit("D2D picker overlay still taps obscurable placeholder text")
    if verified.count("await tester.tap(pickerTapTarget.first);") != 1:
        raise SystemExit("D2D picker overlay did not install the InkWell tap target")

    print(f"Prepared Task 20-D2D test overlay in {app_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
