#!/usr/bin/env python3
from __future__ import annotations

import shutil
import sys
from pathlib import Path


def patch_visible_dialog_interactions(test_path: Path) -> None:
    text = test_path.read_text(encoding="utf-8")
    replacements = (
        (
            "await waitForText(tester, '変更を破棄しますか？');",
            "await waitForVisibleTextD2G(tester, '変更を破棄しますか？');",
            2,
        ),
        (
            "await tapText(tester, '編集を続ける');",
            "await tapVisibleTextD2G(tester, '編集を続ける');",
            1,
        ),
        (
            "await tapText(tester, '破棄する');",
            "await tapVisibleTextD2G(tester, '破棄する');",
            1,
        ),
    )
    for before, after, expected_count in replacements:
        actual_count = text.count(before)
        if actual_count != expected_count:
            raise SystemExit(
                "D2G visible-interaction patch source mismatch: "
                f"expected {expected_count}, found {actual_count} for {before!r}"
            )
        text = text.replace(before, after)

    diagnostic_anchor = """      await tapVisibleTextD2G(tester, '破棄する');
      await waitForText(tester, 'トレーニング設定');
"""
    diagnostic_replacement = """      await tapVisibleTextD2G(tester, '破棄する');
      await tester.pump(const Duration(seconds: 2));
      final diagnosticTexts = tester
          .widgetList<Text>(find.byType(Text).hitTestable())
          .map((Text widget) =>
              widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
      debugPrint(
        'D2G_AFTER_DISCARD_VISIBLE_TEXTS=${diagnosticTexts.join(' | ')}',
      );
      final diagnosticTextFinder = find.byType(Text).hitTestable();
      if (diagnosticTextFinder.evaluate().isNotEmpty) {
        final diagnosticContext = tester.element(diagnosticTextFinder.first);
        debugPrint(
          'D2G_AFTER_DISCARD_CAN_POP='
          '${Navigator.of(diagnosticContext).canPop()}',
        );
        debugPrint(
          'D2G_AFTER_DISCARD_ROUTE='
          '${ModalRoute.of(diagnosticContext)?.settings.name}',
        );
      }
      await binding.takeScreenshot('DIAG_D2G_after_discard');
      await waitForVisibleTextD2G(
        tester,
        'トレーニング設定',
        timeout: const Duration(seconds: 10),
      );
"""
    if text.count(diagnostic_anchor) != 1:
        raise SystemExit(
            "D2G discard diagnostic anchor mismatch: "
            f"expected 1, found {text.count(diagnostic_anchor)}"
        )
    text = text.replace(diagnostic_anchor, diagnostic_replacement, 1)
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
    patch_visible_dialog_interactions(test_destination)

    print(f"Prepared Task 20-D2G test-only overlay in {app_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
