#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2e_prepare_ui_acceptance.py <app-dir>")

    repo_root = Path(__file__).resolve().parents[1]
    app_dir = Path(sys.argv[1]).resolve()
    pubspec = app_dir / "pubspec.yaml"
    if not pubspec.is_file():
        raise SystemExit(f"pubspec.yaml not found: {pubspec}")

    # D2E depends on the D2D onboarding helper. Re-run the D2D preparer here
    # instead of copying its raw source directly: the D2D preparer normalizes
    # the picker interaction to the reachable InkWell target for the maximum
    # Dynamic Type category. This also makes standalone D2E preparation safe.
    d2d_prepare = repo_root / "tools" / "task20_d2d_prepare_ui_acceptance.py"
    completed = subprocess.run(
        [sys.executable, str(d2d_prepare), str(app_dir)],
        text=True,
        capture_output=True,
    )
    if completed.returncode != 0:
        raise SystemExit(
            "D2E could not prepare its D2D dependency:\n"
            f"{completed.stdout}{completed.stderr}"
        )
    if completed.stdout:
        print(completed.stdout, end="")

    source_files = {
        repo_root / "tools" / "task20_d2e_test_support.dart":
            app_dir / "integration_test" / "task20_d2e_test_support.dart",
        repo_root / "tools" / "task20_d2e_workout_core_flow_test.dart":
            app_dir / "integration_test" / "task20_d2e_workout_core_flow_test.dart",
        repo_root / "tools" / "task20_d2e_driver.dart":
            app_dir / "test_driver" / "task20_d2e_driver.dart",
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
        destination.write_bytes(source.read_bytes())

    # At accessibility-extra-extra-large the launch summary is valid but the
    # lower cards are not materialized by ListView until it scrolls. The old
    # readiness loop only searched the current element tree, so it timed out
    # while showing a healthy "開始前の確認" screen. Scroll the visible ListView
    # forward while waiting so the pain card and CTAs can be built and found.
    #
    # Newer raw overlay sources already contain this hardening. Keep this
    # preparer idempotent so D2E can safely consume either the historical raw
    # source or the already-hardened source without applying the patch twice.
    flow = app_dir / "integration_test" / "task20_d2e_workout_core_flow_test.dart"
    flow_text = flow.read_text(encoding="utf-8")
    old = """    if (find.text(errorText).evaluate().isNotEmpty) {\n      await binding.takeScreenshot('D2E_DIAG_start_load_error');\n      throw TestFailure(\n        'Workout start summary returned the visible load-error state: $errorText',\n      );\n    }\n  }\n\n  await binding.takeScreenshot('D2E_DIAG_start_load_timeout');\n"""
    new = """    if (find.text(errorText).evaluate().isNotEmpty) {\n      await binding.takeScreenshot('D2E_DIAG_start_load_error');\n      throw TestFailure(\n        'Workout start summary returned the visible load-error state: $errorText',\n      );\n    }\n    final scrollables = find.byType(Scrollable).hitTestable();\n    if (scrollables.evaluate().isNotEmpty) {\n      await tester.drag(scrollables.first, const Offset(0, -220));\n      await tester.pump(const Duration(milliseconds: 300));\n    }\n  }\n\n  await binding.takeScreenshot('D2E_DIAG_start_load_timeout');\n"""
    installed_marker = "await tester.drag(scrollables.first, const Offset(0, -220));"
    old_count = flow_text.count(old)
    installed_count = flow_text.count(installed_marker)
    if old_count == 1 and installed_count == 0:
        flow.write_text(flow_text.replace(old, new, 1), encoding="utf-8")
    elif old_count == 0 and installed_count == 1:
        pass
    else:
        raise SystemExit(
            "unexpected D2E workout-start readiness state: "
            f"old={old_count}, installed={installed_count}"
        )

    d2d_support = app_dir / "integration_test" / "task20_d2d_test_support.dart"
    d2d_text = d2d_support.read_text(encoding="utf-8")
    if "await tester.tap(placeholder);" in d2d_text:
        raise SystemExit("D2E preparation restored the obsolete D2D placeholder tap")
    if d2d_text.count("await tester.tap(pickerTapTarget.first);") != 1:
        raise SystemExit("D2E preparation lost the D2D InkWell picker target")

    verified_flow = flow.read_text(encoding="utf-8")
    if verified_flow.count(installed_marker) != 1:
        raise SystemExit("D2E enlarged-text readiness scroll was not installed")
    forward_form_materialization = "await scrollToText(tester, 'フォームを確認', delta: 200);"
    backward_form_materialization = "await scrollToText(tester, 'フォームを確認', delta: -200);"
    if verified_flow.count(forward_form_materialization) != 2:
        raise SystemExit("D2E forward form-action materialization was not preserved")
    if verified_flow.count(backward_form_materialization) != 1:
        raise SystemExit("D2E backward form-action materialization was not preserved")
    lazy_scroll_marker = "Timed out materializing text while scrolling: $text"
    if verified_flow.count(lazy_scroll_marker) != 1:
        raise SystemExit("D2E lazy text materialization helper was not preserved")
    if "tester.scrollUntilVisible(" in verified_flow:
        raise SystemExit("D2E restored scrollUntilVisible, which cannot materialize lazy text")

    print(f"Prepared Task 20-D2E test overlay in {app_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
