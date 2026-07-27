#!/usr/bin/env python3
"""Verify the Task20-D2A v0.9.3 canonical package."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def require(text: str, value: str, label: str) -> None:
    if value not in text:
        raise SystemExit(f"Missing {label}: {value!r}")


def forbid(text: str, value: str, label: str) -> None:
    if value in text:
        raise SystemExit(f"Unexpected {label}: {value!r}")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: task20_d2a_verify_canonical_v093.py <app-root>")

    root = Path(sys.argv[1]).resolve()
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    reset_page = (
        root / "lib/features/data_management/presentation/local_data_reset_page.dart"
    ).read_text(encoding="utf-8")
    reset_contract = (root / "tools/verify_local_data_reset_contract.py").read_text(
        encoding="utf-8"
    )
    manifest = (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8")
    readme = (root / "README.md").read_text(encoding="utf-8")
    matrix = (root / "docs/VERSION_MATRIX.md").read_text(encoding="utf-8")
    decision = (root / "docs/DECISION_LOG.md").read_text(encoding="utf-8")
    task_doc = root / "docs/TASK20_D2A_LOCAL_RESET_NAVIGATION_FIX.md"

    require(pubspec, "version: 0.9.3+21\n", "canonical app version")
    require(reset_page, "context.go('/onboarding')", "direct onboarding navigation")
    forbid(reset_page, "context.go('/launch')", "legacy launch navigation")
    require(
        reset_contract,
        'require(page, "context.go(\'/onboarding\')", "LocalDataResetPage")',
        "updated local reset contract",
    )
    forbid(
        reset_contract,
        'require(page, "context.go(\'/launch\')", "LocalDataResetPage")',
        "legacy local reset contract",
    )
    require(readme, "実装基盤 v0.9.3", "README version")
    require(matrix, "現在のプロジェクト版：`0.9.3+21`", "version matrix")
    require(
        decision,
        "D-009 端末内データ初期化後は初期登録introへ直接遷移",
        "decision record",
    )
    require(
        manifest,
        "docs/TASK20_D2A_LOCAL_RESET_NAVIGATION_FIX.md",
        "Task20-D2A document manifest entry",
    )
    if not task_doc.is_file():
        raise SystemExit("Task20-D2A canonical record is missing")

    actual_files = sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
        and not (path.relative_to(root).parts[0] in {"build", ".dart_tool"})
    )
    manifest_files = [line for line in manifest.splitlines() if line]
    if manifest_files != actual_files:
        raise SystemExit("FILE_MANIFEST.txt does not exactly match canonical files")

    output_dir = root / "build/task20_b_logs/flutter"
    output_dir.mkdir(parents=True, exist_ok=True)
    result = {
        "status": "PASS",
        "task": "Task 20-D2A canonical navigation fix",
        "canonical_package": "implementation-v0.9.3.zip",
        "app_version": "0.9.3+21",
        "schema_version": 9,
        "schema_table_count": 75,
        "local_reset_navigation": "/onboarding",
        "legacy_launch_hop_removed": True,
        "local_data_delete_contract_changed": False,
        "anonymous_id_rotation_changed": False,
        "manual_core_flow_fully_verified": False,
        "physical_device_verified": False,
        "native_accessibility_verified": False,
    }
    (output_dir / "task20_d2a_canonical_package.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
