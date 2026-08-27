#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2k_prepare_ui_acceptance.py <app-dir>")

    repo_root = Path(__file__).resolve().parents[1]
    app_dir = Path(sys.argv[1]).resolve()
    if not (app_dir / "pubspec.yaml").is_file():
        raise SystemExit(f"pubspec.yaml not found: {app_dir / 'pubspec.yaml'}")

    subprocess.run(
        [
            sys.executable,
            str(repo_root / "tools" / "task20_d2i_prepare_ui_acceptance.py"),
            str(app_dir),
        ],
        check=True,
    )

    source_files = {
        repo_root / "tools" / "task20_d2k_reset_interruption_prepare_test.dart":
            app_dir / "integration_test" / "task20_d2k_reset_interruption_prepare_test.dart",
        repo_root / "tools" / "task20_d2k_reset_interruption_trigger_test.dart":
            app_dir / "integration_test" / "task20_d2k_reset_interruption_trigger_test.dart",
        repo_root / "tools" / "task20_d2k_reset_interruption_verify_test.dart":
            app_dir / "integration_test" / "task20_d2k_reset_interruption_verify_test.dart",
    }
    for source, destination in source_files.items():
        if not source.is_file():
            raise SystemExit(f"test overlay source not found: {source}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)

    print(f"Prepared Task 20-D2K test overlay in {app_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
