#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


def _replace_once(target: Path, marker: str, replacement: str, label: str) -> None:
    if not target.is_file():
        raise SystemExit(f"{label} integration test overlay not found: {target}")
    text = target.read_text(encoding="utf-8")
    if text.count(marker) != 1:
        raise SystemExit(
            f"Expected exactly one {label} marker before injection; "
            f"found {text.count(marker)}"
        )
    target.write_text(text.replace(marker, replacement, 1), encoding="utf-8")


def _require_once(target: Path, marker: str, label: str) -> None:
    if not target.is_file():
        raise SystemExit(f"{label} integration test overlay not found: {target}")
    text = target.read_text(encoding="utf-8")
    if text.count(marker) != 1:
        raise SystemExit(
            f"Expected exactly one {label} marker; found {text.count(marker)}"
        )


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2j_inject_basic_info_screenshot.py <app-dir>")

    app_dir = Path(sys.argv[1]).resolve()

    d2a = app_dir / "integration_test" / "task20_d2a_onboarding_reset_test.dart"
    d2a_marker = "      await _waitForText(tester, '基本情報');\n\n      await _tapText(tester, '次へ');"
    d2a_replacement = (
        "      await _waitForText(tester, '基本情報');\n"
        "      _expectHealthyFrame(tester);\n"
        "      await binding.takeScreenshot('D2J_02_basic_info_large');\n\n"
        "      await _tapText(tester, '次へ');"
    )
    _replace_once(d2a, d2a_marker, d2a_replacement, "first-basic-info D2A")

    d2e = app_dir / "integration_test" / "task20_d2e_workout_core_flow_test.dart"
    d2e_transition_guard = (
        "      await waitForText(\n"
        "        tester,\n"
        "        '今日やること',\n"
        "        timeout: const Duration(seconds: 90),\n"
        "      );\n"
        "      await waitForTextAbsent(\n"
        "        tester,\n"
        "        '終了後の記録',\n"
        "        timeout: const Duration(seconds: 30),\n"
        "      );\n"
        "      expect(find.text('トレーニング中'), findsNothing);\n"
        "      expect(find.text('終了後の記録'), findsNothing);"
    )
    # D2E now owns the transition-settling wait. D2J must verify that exact
    # accepted guard instead of replacing the obsolete pre-wait source block.
    # Keep the uniqueness check so source drift cannot silently weaken D2J.
    _require_once(d2e, d2e_transition_guard, "D2E completion transition guard")

    d2g = app_dir / "integration_test" / "task20_d2g_my_page_settings_test.dart"
    d2g_marker = (
        "      await tapTextAt(tester, '肩', 0);\n"
        "      expectSaveButtonEnabled(tester, true);"
    )
    d2g_replacement = (
        "      await tapTextAt(tester, '肩', 0);\n"
        "      await waitForText(tester, 'メニューでの扱い');\n"
        "      expect(find.text('負荷を下げる'), findsOneWidget);\n"
        "      expectHealthyFrame(tester);\n"
        "      expectSaveButtonEnabled(tester, true);"
    )
    _replace_once(d2g, d2g_marker, d2g_replacement, "D2G restriction dropdown")

    print(f"Injected D2J screenshot/overflow guards and verified D2E transition guard in {app_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
