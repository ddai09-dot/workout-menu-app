#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2j_inject_basic_info_screenshot.py <app-dir>")

    app_dir = Path(sys.argv[1]).resolve()
    target = app_dir / "integration_test" / "task20_d2a_onboarding_reset_test.dart"
    if not target.is_file():
        raise SystemExit(f"D2A integration test overlay not found: {target}")

    text = target.read_text(encoding="utf-8")
    marker = "      await _waitForText(tester, '基本情報');\n\n      await _tapText(tester, '次へ');"
    replacement = (
        "      await _waitForText(tester, '基本情報');\n"
        "      _expectHealthyFrame(tester);\n"
        "      await binding.takeScreenshot('D2J_02_basic_info_large');\n\n"
        "      await _tapText(tester, '次へ');"
    )
    if text.count(marker) != 1:
        raise SystemExit(
            "Expected exactly one first-basic-info D2A marker before injection; "
            f"found {text.count(marker)}"
        )
    target.write_text(text.replace(marker, replacement, 1), encoding="utf-8")
    print(f"Injected D2J basic-info screenshot into {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
