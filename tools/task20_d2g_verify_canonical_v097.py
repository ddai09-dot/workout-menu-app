#!/usr/bin/env python3
"""Verify the Task20-D2G v0.9.7 canonical package."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

EXPECTED_RUNTIME_TREE_SHA256 = "f07c50e434961614bc3ba8acafb0e3b8c31084776481f7ddd3f3b256d28e3180"
EXPECTED_SCHEMA_TREE_SHA256 = "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af"
EXPECTED_ASSET_TREE_SHA256 = "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe"
EXPECTED_MY_PAGE_SHA256 = "7a10d40319e4566e50f280762c27e11fed1df91bffd4d78c4c5638cc3635fbc5"
EXPECTED_EDITOR_SHA256 = "13328a95bc07b708717843ab9aaf5bf68973e018070719b3cc8f79e8b8b2b741"
EXCLUDED_TOP_LEVEL = {"build", ".dart_tool"}


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
        raise SystemExit("Usage: task20_d2g_verify_canonical_v097.py <app-root>")

    root = Path(sys.argv[1]).resolve()
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    my_page_path = root / "lib/features/my_page/presentation/my_page.dart"
    my_page = my_page_path.read_text(encoding="utf-8")
    editor_path = root / "lib/features/settings/presentation/training_settings_edit_page.dart"
    editor = editor_path.read_text(encoding="utf-8")
    readme = (root / "README.md").read_text(encoding="utf-8")
    matrix = (root / "docs/VERSION_MATRIX.md").read_text(encoding="utf-8")
    roadmap = (root / "docs/IMPLEMENTATION_ROADMAP.md").read_text(encoding="utf-8")
    decision = (root / "docs/DECISION_LOG.md").read_text(encoding="utf-8")
    report_path = root / "docs/TASK20_D2G_SETTINGS_NAVIGATION_FIX.md"
    manifest = (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8")

    require(pubspec, "version: 0.9.7+25\n", "canonical app version")
    require(
        my_page,
        "onTap: () => context.push(\n                              '/my-page/settings/${section.pathSegment}',",
        "settings push navigation",
    )
    forbid(
        my_page,
        "onTap: () => context.go(\n                              '/my-page/settings/${section.pathSegment}',",
        "settings history replacement",
    )
    require(editor, "PopScope(", "unsaved-change PopScope")
    require(editor, "canPop: !_hasChanges", "change-state navigation guard")
    require(editor, "_draft = _original;", "discard state restoration")
    require(editor, "await WidgetsBinding.instance.endOfFrame;", "post-frame wait")
    require(editor, "context.pop();", "normal return navigation")

    actual_my_page_sha = hashlib.sha256(my_page_path.read_bytes()).hexdigest()
    if actual_my_page_sha != EXPECTED_MY_PAGE_SHA256:
        raise SystemExit(
            f"My Page SHA mismatch: {actual_my_page_sha} != {EXPECTED_MY_PAGE_SHA256}"
        )
    actual_editor_sha = hashlib.sha256(editor_path.read_bytes()).hexdigest()
    if actual_editor_sha != EXPECTED_EDITOR_SHA256:
        raise SystemExit(
            f"Training settings editor SHA mismatch: {actual_editor_sha} != {EXPECTED_EDITOR_SHA256}"
        )

    require(readme, "実装基盤 v0.9.7", "README version")
    require(readme, "`context.push`", "README navigation fix")
    require(matrix, "現在のプロジェクト版：`0.9.7+25`", "version matrix")
    require(matrix, "タスク20-D2G：設定編集の履歴保持", "version history")
    require(roadmap, "v0.9.7：設定画面への遷移を`context.push`", "roadmap fix")
    require(decision, "D-014 設定編集は戻り先を保持するpush遷移で開く", "decision")
    if not report_path.is_file():
        raise SystemExit("Task20-D2G settings-navigation fix report is missing")
    report = report_path.read_text(encoding="utf-8")
    require(report, "`context.go`から`context.push`", "fix report")
    require(manifest, "docs/TASK20_D2G_SETTINGS_NAVIGATION_FIX.md", "manifest report entry")

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
        "task": "Task20-D2G settings navigation fix",
        "canonical_package": "implementation-v0.9.7.zip",
        "app_version": "0.9.7+25",
        "schema_version": 9,
        "schema_table_count": 75,
        "runtime_behavior_changed_from_v0_9_6": True,
        "schema_changed_from_v0_9_6": False,
        "assets_changed_from_v0_9_6": False,
        "tree_hashes": actual,
        "tree_file_counts": {
            "runtime": runtime_files,
            "schema": schema_files,
            "assets": asset_files,
        },
        "fix": "preserve My Page history by opening settings with context.push",
        "task20_d2_fully_verified": False,
        "physical_device_verified": False,
        "native_accessibility_verified": False,
    }
    output_dir = root / "build/task20_b_logs/flutter"
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "task20_d2g_canonical_package_v097.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
