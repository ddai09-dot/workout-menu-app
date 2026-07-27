#!/usr/bin/env python3
"""Verify the Task20-D2B v0.9.4 canonical package."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

EXPECTED_RUNTIME_TREE_SHA256 = "28187ee0179263daa9608272603aa603c8194cf6f5af6eaf791043239f3a7269"
EXPECTED_SCHEMA_TREE_SHA256 = "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af"
EXPECTED_ASSET_TREE_SHA256 = "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe"


def require(text: str, value: str, label: str) -> None:
    if value not in text:
        raise SystemExit(f"Missing {label}: {value!r}")


def forbid(text: str, value: str, label: str) -> None:
    if value in text:
        raise SystemExit(f"Unexpected {label}: {value!r}")


def tree_hash(root: Path, parts: list[str]) -> tuple[str, int]:
    digest = hashlib.sha256()
    files: list[Path] = []
    for part in parts:
        path = root / part
        if path.is_dir():
            files.extend(p for p in path.rglob("*") if p.is_file())
        elif path.is_file():
            files.append(path)
        else:
            raise SystemExit(f"Missing tree-hash input: {part}")
    unique_files = sorted(set(files), key=lambda item: item.relative_to(root).as_posix())
    for path in unique_files:
        relative = path.relative_to(root).as_posix()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest(), len(unique_files)


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: task20_d2b_verify_canonical_v094.py <app-root>")

    root = Path(sys.argv[1]).resolve()
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    reset_page = (
        root / "lib/features/data_management/presentation/local_data_reset_page.dart"
    ).read_text(encoding="utf-8")
    readme = (root / "README.md").read_text(encoding="utf-8")
    matrix = (root / "docs/VERSION_MATRIX.md").read_text(encoding="utf-8")
    roadmap = (root / "docs/IMPLEMENTATION_ROADMAP.md").read_text(encoding="utf-8")
    decision = (root / "docs/DECISION_LOG.md").read_text(encoding="utf-8")
    task20_b = (root / "docs/TASK20_B_FLUTTER_IOS_EXECUTION.md").read_text(
        encoding="utf-8"
    )
    d2a_report = root / "docs/TASK20_D2A_COMPLETION_REPORT.md"
    manifest_path = root / "FILE_MANIFEST.txt"
    manifest = manifest_path.read_text(encoding="utf-8")

    require(pubspec, "version: 0.9.4+22\n", "canonical app version")
    require(reset_page, "context.go('/onboarding')", "direct onboarding navigation")
    forbid(reset_page, "context.go('/launch')", "legacy reset navigation")
    require(readme, "実装基盤 v0.9.4", "README version")
    require(readme, "Task20-D2A自動UI受入：対象範囲を完了", "D2A status")
    require(readme, "Task20-D2全体：未完了", "D2 boundary")
    require(matrix, "現在のプロジェクト版：`0.9.4+22`", "version matrix")
    require(matrix, "D2-10の一部を両SimulatorでPASS", "D2A evidence")
    require(roadmap, "D2A対象範囲は完了。Task20-D2全体は未完了", "roadmap boundary")
    require(decision, "D-010 Task20-D2Aの自動受入範囲を限定して完了扱い", "D2A decision")
    require(decision, "D-011 成果物整合性是正をv0.9.4として昇格", "promotion decision")
    require(task20_b, "D2A対象範囲の完了をTask20-B全体の完了とは扱わない", "Task20-B boundary")
    if not d2a_report.is_file():
        raise SystemExit("Task20-D2A completion report is missing")
    require(d2a_report.read_text(encoding="utf-8"), "Task20-D2Aは完了。Task20-D2およびTask20-B全体は未完了。", "D2A report verdict")
    require(manifest, "docs/TASK20_D2A_COMPLETION_REPORT.md", "D2A report manifest entry")

    actual_files = sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
        and path.relative_to(root).parts[0] not in {"build", ".dart_tool"}
    )
    manifest_files = [line for line in manifest.splitlines() if line]
    if manifest_files != actual_files:
        raise SystemExit("FILE_MANIFEST.txt does not exactly match canonical files")

    runtime_hash, runtime_files = tree_hash(root, ["lib", "test"])
    schema_hash, schema_files = tree_hash(
        root,
        ["docs/schema_v9.sqlite.sql", "docs/migrations", "lib/core/database/schema"],
    )
    asset_hash, asset_files = tree_hash(root, ["assets"])
    expected = {
        "runtime": EXPECTED_RUNTIME_TREE_SHA256,
        "schema": EXPECTED_SCHEMA_TREE_SHA256,
        "assets": EXPECTED_ASSET_TREE_SHA256,
    }
    actual = {"runtime": runtime_hash, "schema": schema_hash, "assets": asset_hash}
    for label, expected_hash in expected.items():
        if actual[label] != expected_hash:
            raise SystemExit(
                f"{label} tree changed unexpectedly: {actual[label]} != {expected_hash}"
            )

    result = {
        "status": "PASS",
        "task": "Task20-D2B canonical documentation alignment",
        "canonical_package": "implementation-v0.9.4.zip",
        "app_version": "0.9.4+22",
        "schema_version": 9,
        "schema_table_count": 75,
        "runtime_behavior_changed_from_v0_9_3": False,
        "schema_changed_from_v0_9_3": False,
        "assets_changed_from_v0_9_3": False,
        "tree_hashes": actual,
        "tree_file_counts": {
            "runtime": runtime_files,
            "schema": schema_files,
            "assets": asset_files,
        },
        "task20_d2a_scope_complete": True,
        "task20_d2_fully_verified": False,
        "physical_device_verified": False,
        "native_accessibility_verified": False,
    }
    output_dir = root / "build/task20_b_logs/flutter"
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "task20_d2b_canonical_package.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
