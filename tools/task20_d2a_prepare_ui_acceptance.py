#!/usr/bin/env python3
from __future__ import annotations

import shutil
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2a_prepare_ui_acceptance.py <app-dir>")

    repo_root = Path(__file__).resolve().parents[1]
    app_dir = Path(sys.argv[1]).resolve()
    pubspec = app_dir / "pubspec.yaml"
    if not pubspec.is_file():
        raise SystemExit(f"pubspec.yaml not found: {pubspec}")

    source_test = repo_root / "tools" / "task20_d2a_onboarding_reset_test.dart"
    source_driver = repo_root / "tools" / "task20_d2a_driver.dart"
    for source in (source_test, source_driver):
        if not source.is_file():
            raise SystemExit(f"test overlay source not found: {source}")

    text = pubspec.read_text(encoding="utf-8")
    anchor = "  flutter_test:\n    sdk: flutter\n"
    if text.count(anchor) != 1:
        raise SystemExit("expected exactly one flutter_test SDK dependency")

    dependencies = (
        "  integration_test:\n"
        "    sdk: flutter\n"
        "  flutter_driver:\n"
        "    sdk: flutter\n"
    )
    missing = [
        dependency
        for dependency in (
            "  integration_test:\n    sdk: flutter\n",
            "  flutter_driver:\n    sdk: flutter\n",
        )
        if dependency not in text
    ]
    if missing:
        text = text.replace(anchor, anchor + "".join(missing), 1)
        pubspec.write_text(text, encoding="utf-8")

    integration_dir = app_dir / "integration_test"
    driver_dir = app_dir / "test_driver"
    integration_dir.mkdir(parents=True, exist_ok=True)
    driver_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(
        source_test,
        integration_dir / "task20_d2a_onboarding_reset_test.dart",
    )
    shutil.copyfile(source_driver, driver_dir / "task20_d2a_driver.dart")

    print(f"Prepared Task 20-D2A test overlay in {app_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
