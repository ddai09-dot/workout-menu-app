#!/usr/bin/env python3
from __future__ import annotations

import shutil
import sys
from pathlib import Path


def patch_training_settings_navigation(app_dir: Path) -> None:
    path = (
        app_dir
        / "lib"
        / "features"
        / "settings"
        / "presentation"
        / "training_settings_edit_page.dart"
    )
    if not path.is_file():
        raise SystemExit(f"training settings page not found: {path}")

    text = path.read_text(encoding="utf-8")
    helper_marker = "Future<void> _popAfterAllowing() async"
    if helper_marker in text:
        return

    replacements = (
        (
            """        _allowPop = true;
        context.pop();
""",
            """        await _popAfterAllowing();
""",
            1,
        ),
        (
            """    _allowPop = true;
    if (review == true) {
      context.go('/menu/weekly-planner');
    } else {
      context.pop();
    }
""",
            """    if (review == true) {
      context.go('/menu/weekly-planner');
    } else {
      await _popAfterAllowing();
    }
""",
            1,
        ),
        (
            """    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      context.pop();
    }
""",
            """    if (discard == true && mounted) {
      await _popAfterAllowing();
    }
""",
            1,
        ),
    )

    for before, after, expected_count in replacements:
        actual_count = text.count(before)
        if actual_count != expected_count:
            raise SystemExit(
                "training settings navigation patch source mismatch: "
                f"expected {expected_count}, found {actual_count} for {before!r}"
            )
        text = text.replace(before, after, expected_count)

    helper_anchor = """  void _requestPop() {
"""
    helper = """  Future<void> _popAfterAllowing() async {
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

"""
    if text.count(helper_anchor) != 1:
        raise SystemExit("expected one _requestPop helper insertion point")
    text = text.replace(helper_anchor, helper + helper_anchor, 1)

    if text.count(helper_marker) != 1:
        raise SystemExit("expected one post-frame pop helper")
    if text.count("await _popAfterAllowing();") != 3:
        raise SystemExit("expected three safe settings pop call sites")
    path.write_text(text, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2g_prepare_ui_acceptance.py <app-dir>")

    repo_root = Path(__file__).resolve().parents[1]
    app_dir = Path(sys.argv[1]).resolve()
    pubspec = app_dir / "pubspec.yaml"
    if not pubspec.is_file():
        raise SystemExit(f"pubspec.yaml not found: {pubspec}")

    source_files = {
        repo_root / "tools" / "task20_d2d_test_support.dart":
            app_dir / "integration_test" / "task20_d2d_test_support.dart",
        repo_root / "tools" / "task20_d2e_test_support.dart":
            app_dir / "integration_test" / "task20_d2e_test_support.dart",
        repo_root / "tools" / "task20_d2g_test_support.dart":
            app_dir / "integration_test" / "task20_d2g_test_support.dart",
        repo_root / "tools" / "task20_d2g_my_page_settings_test.dart":
            app_dir / "integration_test" / "task20_d2g_my_page_settings_test.dart",
        repo_root / "tools" / "task20_d2g_driver.dart":
            app_dir / "test_driver" / "task20_d2g_driver.dart",
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

    patch_training_settings_navigation(app_dir)

    for source, destination in source_files.items():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)

    print(f"Prepared Task 20-D2G test and navigation-fix overlay in {app_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
