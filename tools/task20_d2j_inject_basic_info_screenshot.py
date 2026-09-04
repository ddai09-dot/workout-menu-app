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
    d2e_marker = (
        "      await waitForText(\n"
        "        tester,\n"
        "        '今日やること',\n"
        "        timeout: const Duration(seconds: 90),\n"
        "      );\n"
        "      expect(find.text('トレーニング中'), findsNothing);\n"
        "      expect(find.text('終了後の記録'), findsNothing);"
    )
    d2e_replacement = (
        "      await waitForText(\n"
        "        tester,\n"
        "        '今日やること',\n"
        "        timeout: const Duration(seconds: 90),\n"
        "      );\n"
        "      final d2jTransitionDeadline = DateTime.now().add(\n"
        "        const Duration(seconds: 10),\n"
        "      );\n"
        "      while (DateTime.now().isBefore(d2jTransitionDeadline) &&\n"
        "          find.text('終了後の記録').evaluate().isNotEmpty) {\n"
        "        await tester.pump(const Duration(milliseconds: 250));\n"
        "      }\n"
        "      expect(find.text('トレーニング中'), findsNothing);\n"
        "      expect(find.text('終了後の記録'), findsNothing);"
    )
    _replace_once(d2e, d2e_marker, d2e_replacement, "D2E completion transition")

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

    print(f"Injected D2J screenshot and transition/overflow guards into {app_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
