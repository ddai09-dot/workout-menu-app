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

    # At the largest accessibility category the placeholder text can sit under
    # the fixed bottom action even after the label itself is visible. Match the
    # already-proven D2A interaction: target the tappable InkWell, make that
    # control visible, and tap the control rather than the obscured Text glyphs.
    support = app_dir / "integration_test" / "task20_d2d_test_support.dart"
    support_text = support.read_text(encoding="utf-8")
    old = """      await tester.ensureVisible(labelFinder);\n      await tester.pump(const Duration(milliseconds: 250));\n      final pickerField = find\n          .ancestor(of: labelFinder, matching: find.byType(Column))\n          .first;\n      final placeholder = find.descendant(\n        of: pickerField,\n        matching: find.text('選択してください'),\n      );\n      expect(placeholder, findsOneWidget);\n      await tester.tap(placeholder);\n"""
    new = """      final pickerField = find\n          .ancestor(of: labelFinder, matching: find.byType(Column))\n          .first;\n      final placeholder = find.descendant(\n        of: pickerField,\n        matching: find.text('選択してください'),\n      );\n      expect(placeholder, findsOneWidget);\n      final pickerTapTarget = find.ancestor(\n        of: placeholder,\n        matching: find.byType(InkWell),\n      );\n      expect(pickerTapTarget, findsOneWidget);\n      await tester.ensureVisible(pickerTapTarget.first);\n      await tester.pump(const Duration(milliseconds: 250));\n      await tester.tap(pickerTapTarget.first);\n"""
    if support_text.count(old) != 1:
        raise SystemExit("expected exactly one D2D picker tap block")
    support.write_text(support_text.replace(old, new, 1), encoding="utf-8")

    print(f"Prepared Task 20-D2D test overlay in {app_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
