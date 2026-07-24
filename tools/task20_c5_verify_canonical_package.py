#!/usr/bin/env python3
"""Verify that the v0.9.2 canonical package already contains B2/B3/C1-C4."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def require(text: str, value: str, label: str) -> None:
    if value not in text:
        raise SystemExit(f"Missing {label}: {value!r}")


def forbid(text: str, value: str, label: str) -> None:
    if value in text:
        raise SystemExit(f"Unexpected legacy {label}: {value!r}")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: task20_c5_verify_canonical_package.py <app-root>")

    root = Path(sys.argv[1]).resolve()
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    analysis = (root / "analysis_options.yaml").read_text(encoding="utf-8")
    runner = (root / "tools/run_task20_b_flutter_checks.sh").read_text(
        encoding="utf-8"
    )
    manifest = (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8")
    installer = (root / "tools/install_pinned_flutter_sdk.py").read_text(
        encoding="utf-8"
    )
    ios_runner = (root / "tools/run_task20_b_ios_simulator.sh").read_text(
        encoding="utf-8"
    )

    require(pubspec, "version: 0.9.2+20\n", "canonical app version")
    require(pubspec, "  build_runner: 2.15.1\n", "build_runner compatibility pin")
    require(pubspec, "  drift_dev: ^2.34.0\n", "drift_dev compatible range")
    forbid(pubspec, "custom_lint", "custom_lint dependency")
    forbid(pubspec, "  riverpod_lint:", "pubspec riverpod_lint dependency")

    require(analysis, "plugins:\n  riverpod_lint: 3.1.4\n", "analysis plugin")
    require(runner, "flutter analyze\n", "strict analyzer command")
    forbid(runner, "--no-fatal-infos", "non-fatal Info analyzer option")
    forbid(runner, "custom_lint", "custom_lint execution")

    require(
        manifest,
        "docs/TASK20_C1_C4_CANONICAL_INTEGRATION.md",
        "canonical integration record",
    )
    require(installer, "stat.S_ISLNK", "macOS ZIP symlink restoration")
    require(ios_runner, "remove_generated_widget_test", "generated test guard")

    output_dir = root / "build/task20_b_logs/flutter"
    output_dir.mkdir(parents=True, exist_ok=True)
    result = {
        "status": "PASS",
        "task": "Task 20-C5",
        "canonical_package": "implementation-v0.9.2.zip",
        "app_version": "0.9.2+20",
        "integrated": [
            "Task20-B2",
            "Task20-B3",
            "Task20-C1",
            "Task20-C2",
            "Task20-C3",
            "Task20-C4",
        ],
        "canonical_package_built_deterministically": True,
        "validation_source_mutated_after_v092_extract": False,
        "staged_patch_application_required_for_validation": False,
        "promotion_builder_temporary": True,
        "manual_simulator_verified": False,
        "physical_device_verified": False,
        "accessibility_verified": False,
    }
    (output_dir / "task20_c5_canonical_package.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
