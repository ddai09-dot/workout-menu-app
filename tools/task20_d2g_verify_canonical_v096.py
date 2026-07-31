#!/usr/bin/env python3
"""Verify the Task20-D2G v0.9.6 canonical package."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

EXPECTED_RUNTIME_TREE_SHA256 = "60e0318cb0b32cbe349156e5fe54367533c26fdcb5c80b7b8d265a5d8f42bc9d"
EXPECTED_SCHEMA_TREE_SHA256 = "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af"
EXPECTED_ASSET_TREE_SHA256 = "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe"
EXPECTED_EDITOR_SHA256 = "bf2dd8d6cf4d4d3d22b8eab035bf293edc851d4c5fe98f59260540b308b14370"


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
        raise SystemExit("Usage: task20_d2g_verify_canonical_v096.py <app-root>")

    root = Path(sys.argv[1]).resolve()
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    editor_path = root / "lib/features/settings/presentation/training_settings_edit_page.dart"
    editor = editor_path.read_text(encoding="utf-8")
    readme = (root / "README.md").read_text(encoding="utf-8")
    matrix = (root / "docs/VERSION_MATRIX.md").read_text(encoding="utf-8")
    roadmap = (root / "docs/IMPLEMENTATION_ROADMAP.md").read_text(encoding="utf-8")
    decision = (root / "docs/DECISION_LOG.md").read_text(encoding="utf-8")
    fix_report = root / "docs/TASK20_D2G_SETTINGS_RETURN_FIX.md"
    manifest = (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8")

    require(pubspec, "version: 0.9.6+24\n", "canonical app version")
    require(editor, "Future<void> _returnToMyPageAfterAllowing() async", "return helper")
    require(editor, "setState(() => _allowPop = true);", "PopScope permission update")
    require(editor, "await WidgetsBinding.instance.endOfFrame;", "post-frame wait")
    require(editor, "context.go('/my-page');", "explicit My Page navigation")
    if editor.count("await _returnToMyPageAfterAllowing();") != 3:
        raise SystemExit("Expected exactly three safe My Page return call sites")
    forbid(
        editor,
        "setState(() => _allowPop = true);\n      context.pop();",
        "same-frame discard pop",
    )
    actual_editor_sha = hashlib.sha256(editor_path.read_bytes()).hexdigest()
    if actual_editor_sha != EXPECTED_EDITOR_SHA256:
        raise SystemExit(
            f"Training settings editor SHA mismatch: {actual_editor_sha} != {EXPECTED_EDITOR_SHA256}"
        )

    require(readme, "実装基盤 v0.9.6", "README version")
    require(readme, "PopScope", "README fix summary")
    require(matrix, "現在のプロジェクト版：`0.9.6+24`", "version matrix")
    require(matrix, "タスク20-D2G：設定編集の安全な復帰", "version history")
    require(roadmap, "v0.9.6：PopScope許可状態", "roadmap fix")
    require(decision, "D-013 設定編集からの復帰はPopScope反映後に実行する", "decision")
    if not fix_report.is_file():
        raise SystemExit("Task20-D2G settings-return fix report is missing")
    require(
        fix_report.read_text(encoding="utf-8"),
        "WidgetsBinding.instance.endOfFrame",
        "fix report",
    )
    require(manifest, "docs/TASK20_D2G_SETTINGS_RETURN_FIX.md", "fix report manifest entry")

    actual_files = sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
        and path.relative_to(root).parts[0] not in {"build", ".dart_tool"}
        and "__pycache__" not in path.relative_to(root).parts
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
    actual = {"runtime": runtime_hash, "schema": schema_hash, "assets": asset_hash}
    expected = {
        "runtime": EXPECTED_RUNTIME_TREE_SHA256,
        "schema": EXPECTED_SCHEMA_TREE_SHA256,
        "assets": EXPECTED_ASSET_TREE_SHA256,
    }
    for label, expected_hash in expected.items():
        if actual[label] != expected_hash:
            raise SystemExit(f"{label} tree mismatch: {actual[label]} != {expected_hash}")

    result = {
        "status": "PASS",
        "task": "Task20-D2G settings return fix",
        "canonical_package": "implementation-v0.9.6.zip",
        "app_version": "0.9.6+24",
        "schema_version": 9,
        "schema_table_count": 75,
        "runtime_behavior_changed_from_v0_9_5": True,
        "schema_changed_from_v0_9_5": False,
        "assets_changed_from_v0_9_5": False,
        "tree_hashes": actual,
        "tree_file_counts": {
            "runtime": runtime_files,
            "schema": schema_files,
            "assets": asset_files,
        },
        "fix": "wait for PopScope rebuild before explicit My Page navigation",
        "task20_d2_fully_verified": False,
        "physical_device_verified": False,
        "native_accessibility_verified": False,
    }
    output_dir = root / "build/task20_b_logs/flutter"
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "task20_d2g_canonical_package.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
