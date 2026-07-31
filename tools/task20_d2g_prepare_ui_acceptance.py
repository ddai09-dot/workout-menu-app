#!/usr/bin/env python3
from __future__ import annotations

import shutil
import sys
from pathlib import Path


def replace_exact(
    text: str,
    before: str,
    after: str,
    expected_count: int,
    label: str,
) -> str:
    actual_count = text.count(before)
    if actual_count != expected_count:
        raise SystemExit(
            f"D2G {label} source mismatch: "
            f"expected {expected_count}, found {actual_count} for {before!r}"
        )
    return text.replace(before, after)


def patch_ui_acceptance(test_path: Path) -> None:
    text = test_path.read_text(encoding="utf-8")

    text = replace_exact(
        text,
        "await waitForText(tester, '変更を破棄しますか？');",
        "await waitForVisibleTextD2G(tester, '変更を破棄しますか？');",
        2,
        "visible dialog",
    )
    text = replace_exact(
        text,
        "await tapText(tester, '編集を続ける');",
        "await tapVisibleTextD2G(tester, '編集を続ける');",
        1,
        "visible continue action",
    )
    text = replace_exact(
        text,
        "await tapText(tester, '破棄する');",
        "await tapVisibleTextD2G(tester, '破棄する');",
        1,
        "visible discard action",
    )

    text = replace_exact(
        text,
        "await waitForText(tester, 'トレーニング目的');",
        "await waitForPathD2G(tester, '/my-page');",
        1,
        "section return route",
    )
    text = replace_exact(
        text,
        "if (find.text('トレーニング設定').evaluate().isNotEmpty) {",
        "if (currentPathD2G(tester) == '/my-page') {",
        1,
        "goal save route",
    )
    text = replace_exact(
        text,
        """      await tapVisibleTextD2G(tester, '破棄する');
      await waitForText(tester, 'トレーニング設定');
""",
        """      await tapVisibleTextD2G(tester, '破棄する');
      await waitForPathD2G(tester, '/my-page');
""",
        1,
        "discard return route",
    )
    text = replace_exact(
        text,
        """      await tapText(tester, '今は変更しない');
      await waitForText(tester, 'トレーニング設定');
""",
        """      await tapText(tester, '今は変更しない');
      await waitForPathD2G(tester, '/my-page');
""",
        1,
        "restriction return route",
    )
    text = replace_exact(
        text,
        """      await pressVisibleBackControlD2G(tester);
      await waitForText(tester, 'トレーニング設定');

      await scrollToTextD2G(tester, '端末内データ');
""",
        """      await pressVisibleBackControlD2G(tester);
      await waitForPathD2G(tester, '/my-page');

      await scrollToTextD2G(tester, '端末内データ');
""",
        1,
        "FAQ return route",
    )

    test_path.write_text(text, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2g_prepare_ui_acceptance.py <app-dir>")

    repo_root = Path(__file__).resolve().parents[1]
    app_dir = Path(sys.argv[1]).resolve()
    pubspec = app_dir / "pubspec.yaml"
    if not pubspec.is_file():
        raise SystemExit(f"pubspec.yaml not found: {pubspec}")

    test_destination = (
        app_dir / "integration_test" / "task20_d2g_my_page_settings_test.dart"
    )
    source_files = {
        repo_root / "tools" / "task20_d2d_test_support.dart":
            app_dir / "integration_test" / "task20_d2d_test_support.dart",
        repo_root / "tools" / "task20_d2e_test_support.dart":
            app_dir / "integration_test" / "task20_d2e_test_support.dart",
        repo_root / "tools" / "task20_d2g_test_support.dart":
            app_dir / "integration_test" / "task20_d2g_test_support.dart",
        repo_root / "tools" / "task20_d2g_my_page_settings_test.dart":
            test_destination,
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

    for source, destination in source_files.items():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    patch_ui_acceptance(test_destination)

    print(f"Prepared Task 20-D2G test-only overlay in {app_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
