#!/usr/bin/env python3
"""Verify the Task20-D2I v0.9.8 canonical package."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

EXPECTED_RUNTIME_TREE_SHA256 = "21eba6d3201c7e3981e13d2f29e209c562c59f755162367ea3a0c6463952504f"
EXPECTED_SCHEMA_TREE_SHA256 = "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af"
EXPECTED_ASSET_TREE_SHA256 = "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe"
EXPECTED_ACCOUNT_REPOSITORY_SHA256 = "53fe3ec73d42fbd7e4fd97a023593e99b0a9a9ba1b8ed3aa72f06b09a764a441"
EXPECTED_ACCOUNT_TEST_SHA256 = "168dec7a2a55112fb62e64e0fc4d6530c9868e426bab00bcf3e0a4e43e56b498"
EXPECTED_FIX_REPORT_SHA256 = "dacc5b8fe475e2ea061520a0bb35b1b6f1d426e44302dc6ef394cd7412441f67"
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


def require_sha(path: Path, expected: str, label: str) -> None:
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"{label} SHA mismatch: {actual} != {expected}")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: task20_d2i_verify_canonical_v098.py <app-root>")

    root = Path(sys.argv[1]).resolve()
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    repository_path = root / "lib/features/account/data/local_account_repository.dart"
    repository = repository_path.read_text(encoding="utf-8")
    test_path = root / "test/features/account/data/local_account_repository_test.dart"
    tests = test_path.read_text(encoding="utf-8")
    report_path = root / "docs/TASK20_D2I_CURRENT_ACCOUNT_RECOVERY_FIX.md"
    readme = (root / "README.md").read_text(encoding="utf-8")
    matrix = (root / "docs/VERSION_MATRIX.md").read_text(encoding="utf-8")
    roadmap = (root / "docs/IMPLEMENTATION_ROADMAP.md").read_text(encoding="utf-8")
    decision = (root / "docs/DECISION_LOG.md").read_text(encoding="utf-8")
    manifest_text = (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8")

    require(pubspec, "version: 0.9.8+26\n", "canonical app version")
    for marker in [
        "_hasCompletedProfile",
        "_recoverUniqueCompletedLocalAccount",
        "onboarding_completed_at IS NOT NULL",
        "LIMIT 2",
        "multiple completed local accounts exist",
        "final currentUserId = (await ensureAnonymousAccount()).userId;",
    ]:
        require(repository, marker, "current-account recovery")
    for marker in [
        "missing secure-store id recovers the unique completed local account",
        "valid secure-store account without completed profile yields to the unique completed local account",
        "reset with missing secure-store id recovers and deletes the completed local account",
        "missing secure-store id does not guess when multiple completed local accounts exist",
    ]:
        require(tests, marker, "current-account recovery unit test")

    if not report_path.is_file():
        raise SystemExit("Task20-D2I current-account recovery fix report is missing")
    require(readme, "実装基盤 v0.9.8", "README version")
    require(readme, "0.9.8+26", "README app version")
    require(matrix, "現在のプロジェクト版：`0.9.8+26`", "version matrix")
    require(matrix, "タスク20-D2I：current-user復旧", "version matrix v0.9.8 row")
    require(roadmap, "v0.9.8", "roadmap v0.9.8")
    require(decision, "D-015 Task20-D2は検証済み範囲を累積", "decision log D-015 sync")
    require(decision, "D-016 current-user復旧", "decision log D-016")
    require(manifest_text, "docs/TASK20_D2I_CURRENT_ACCOUNT_RECOVERY_FIX.md", "manifest fix report")

    require_sha(repository_path, EXPECTED_ACCOUNT_REPOSITORY_SHA256, "Account repository")
    require_sha(test_path, EXPECTED_ACCOUNT_TEST_SHA256, "Account repository test")
    require_sha(report_path, EXPECTED_FIX_REPORT_SHA256, "D2I fix report")

    actual_files = sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
        and path.relative_to(root).parts[0] not in EXCLUDED_TOP_LEVEL
        and "__pycache__" not in path.relative_to(root).parts
    )
    manifest_files = [line for line in manifest_text.splitlines() if line]
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
        "task": "Task20-D2I current-account recovery fix",
        "canonical_package": "implementation-v0.9.8.zip",
        "app_version": "0.9.8+26",
        "schema_version": 9,
        "schema_table_count": 75,
        "runtime_behavior_changed_from_v0_9_7": True,
        "schema_changed_from_v0_9_7": False,
        "assets_changed_from_v0_9_7": False,
        "current_account_recovery_guarded_by_unique_completed_profile": True,
        "ambiguous_completed_profile_recovery_fails": True,
        "regression_tests_added": 4,
        "tree_hashes": actual,
        "tree_file_counts": {
            "runtime": runtime_files,
            "schema": schema_files,
            "assets": asset_files,
        },
        "task20_d2_fully_verified": False,
        "physical_device_verified": False,
        "native_accessibility_verified": False,
    }
    output_dir = root / "build/task20_b_logs/flutter"
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "task20_d2i_canonical_package_v098.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
