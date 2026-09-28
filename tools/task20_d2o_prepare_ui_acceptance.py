#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2o_prepare_ui_acceptance.py <app-dir>")

    repo_root = Path(__file__).resolve().parents[1]
    app_dir = Path(sys.argv[1]).resolve()
    if not (app_dir / "pubspec.yaml").is_file():
        raise SystemExit(f"pubspec.yaml not found: {app_dir / 'pubspec.yaml'}")

    completed = subprocess.run(
        [
            sys.executable,
            str(repo_root / "tools" / "task20_d2f_prepare_ui_acceptance.py"),
            str(app_dir),
        ],
        text=True,
        capture_output=True,
    )
    if completed.returncode != 0:
        raise SystemExit(
            "D2O could not prepare its D2F dependency:\n"
            f"{completed.stdout}{completed.stderr}"
        )
    if completed.stdout:
        print(completed.stdout, end="")

    source = repo_root / "tools" / "task20_d2o_body_measurement_correction_test.dart"
    destination = (
        app_dir / "integration_test" / "task20_d2o_body_measurement_correction_test.dart"
    )
    if not source.is_file():
        raise SystemExit(f"test overlay source not found: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)

    required = [
        app_dir / "integration_test" / "task20_d2d_test_support.dart",
        app_dir / "integration_test" / "task20_d2e_test_support.dart",
        app_dir / "integration_test" / "task20_d2f_test_support.dart",
        app_dir / "test_driver" / "task20_d2f_driver.dart",
    ]
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise SystemExit(f"D2O dependency overlay missing: {missing}")

    print(f"Prepared Task 20-D2O test overlay in {app_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
