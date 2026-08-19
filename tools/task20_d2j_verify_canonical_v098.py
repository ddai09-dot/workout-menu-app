#!/usr/bin/env python3
"""Verify the Task20-D2J v0.9.8 Dynamic Type home fix canonical package."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

EXPECTED_RUNTIME_TREE_SHA256 = "9214b9170f0bb72b1cb1cc5297714862f84633cf31f230b372e438e166852a05"
EXPECTED_SCHEMA_TREE_SHA256 = "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af"
EXPECTED_ASSET_TREE_SHA256 = "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe"
EXPECTED_HOME_SHA256 = "f18059798cba8a49f14b1792950ad70a43a9b3e414411334e70f8f76b2d1f2f7"
EXCLUDED_TOP_LEVEL = {"build", ".dart_tool"}


def require(text: str, value: str, label: str) -> None:
    if value not in text:
        raise SystemExit(f"Missing {label}: {value!r}")


def tree_hash(root: Path, parts: list[str]) -> tuple[str, int]:
    digest = hashlib.sha256()
    files: list[Path] = []
    for part in parts:
        path = root / part
        if path.is_dir():
            files.extend(item for item in path.rglob("*") if item.is_file())
        elif path.is_file():
            files.append(path)
        else:
            raise SystemExit(f"Missing tree-hash input: {part}")
    unique = sorted(set(files), key=lambda item: item.relative_to(root).as_posix())
    for path in unique:
        relative = path.relative_to(root).as_posix()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest(), len(unique)


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: task20_d2j_verify_canonical_v098.py <app-root>")
    root = Path(sys.argv[1]).resolve()
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    home_path = root / "lib/features/home/presentation/home_page.dart"
    home = home_path.read_text(encoding="utf-8")
    readme = (root / "README.md").read_text(encoding="utf-8")
    matrix = (root / "docs/VERSION_MATRIX.md").read_text(encoding="utf-8")
    roadmap = (root / "docs/IMPLEMENTATION_ROADMAP.md").read_text(encoding="utf-8")
    report_path = root / "docs/TASK20_D2J_DYNAMIC_TYPE_HOME_FIX.md"
    manifest = (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8")

    require(pubspec, "version: 0.9.8+26\n", "canonical app version")
    require(home, "data: (TodayAction value) => SingleChildScrollView(", "scrollable TodayAction")
    require(home, "mainAxisSize: MainAxisSize.min", "minimum-height TodayAction column")
    require(home, "const SizedBox(height: 24)", "non-flex action spacing")
    if "const Spacer()" in home:
        raise SystemExit("Home TodayAction still contains Spacer")
    if hashlib.sha256(home_path.read_bytes()).hexdigest() != EXPECTED_HOME_SHA256:
        raise SystemExit("HomePage SHA mismatch")

    require(readme, "実装基盤 v0.9.8", "README version")
    require(matrix, "現在のプロジェクト版：`0.9.8+26`", "version matrix")
    require(matrix, "タスク20-D2J：ホーム画面Dynamic Type overflow修正", "version history")
    require(roadmap, "v0.9.8：TodayAction領域", "roadmap fix")
    if not report_path.is_file():
        raise SystemExit("Task20-D2J home fix report is missing")
    require(manifest, "docs/TASK20_D2J_DYNAMIC_TYPE_HOME_FIX.md", "manifest report entry")

    actual_files = sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
        and path.relative_to(root).parts[0] not in EXCLUDED_TOP_LEVEL
        and "__pycache__" not in path.relative_to(root).parts
    )
    manifest_files = [line for line in manifest.splitlines() if line]
    if manifest_files != actual_files:
        raise SystemExit("FILE_MANIFEST.txt does not exactly match canonical files")

    runtime_hash, runtime_files = tree_hash(root, ["lib", "test"])
    schema_hash, schema_files = tree_hash(root, ["docs/schema_v9.sqlite.sql", "docs/migrations", "lib/core/database/schema"])
    asset_hash, asset_files = tree_hash(root, ["assets"])
    actual = {"runtime": runtime_hash, "schema": schema_hash, "assets": asset_hash}
    expected = {"runtime": EXPECTED_RUNTIME_TREE_SHA256, "schema": EXPECTED_SCHEMA_TREE_SHA256, "assets": EXPECTED_ASSET_TREE_SHA256}
    for label, expected_hash in expected.items():
        if actual[label] != expected_hash:
            raise SystemExit(f"{label} tree mismatch: {actual[label]} != {expected_hash}")

    result = {
        "status": "PASS",
        "task": "Task20-D2J Dynamic Type home overflow fix",
        "canonical_package": "implementation-v0.9.8.zip",
        "app_version": "0.9.8+26",
        "schema_version": 9,
        "schema_table_count": 75,
        "runtime_behavior_changed_from_v0_9_7": True,
        "schema_changed_from_v0_9_7": False,
        "assets_changed_from_v0_9_7": False,
        "tree_hashes": actual,
        "tree_file_counts": {"runtime": runtime_files, "schema": schema_files, "assets": asset_files},
        "fix": "make Home TodayAction vertically scrollable and remove height-consuming Spacer",
        "task20_d2_fully_verified": False,
        "physical_device_verified": False,
        "native_accessibility_verified": False,
    }
    output_dir = root / "build/task20_b_logs/flutter"
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "task20_d2j_canonical_package_v098.json").write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
