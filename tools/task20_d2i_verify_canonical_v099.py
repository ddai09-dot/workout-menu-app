#!/usr/bin/env python3
"""Verify the Task20-D2I v0.9.9 canonical package."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

EXPECTED_RUNTIME_TREE_SHA256 = "120ce9febc4a30d54909f04ba9f394aba2921c35e86237ac11a37708e7beb302"
EXPECTED_SCHEMA_TREE_SHA256 = "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af"
EXPECTED_ASSET_TREE_SHA256 = "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe"
EXPECTED_ONBOARDING_REPOSITORY_SHA256 = "5260b5ae2e2148e5dd0feb78e5a1e9b5dd2b8273106aad9bb2fad57358828a54"
EXPECTED_ONBOARDING_PROVIDER_SHA256 = "6f9a00f96a0572e44b264f48081fbab1bc2b82d81f8da669b05b791930b2fb9b"
EXPECTED_ONBOARDING_TEST_SHA256 = "638eb67c77d09721401767e756e2a5c2f99c993c1e02e90bd750a717b19478fd"
EXPECTED_FIX_REPORT_SHA256 = "0673d30c104057d1bf1db9fb457f3885ef537bf4bdfa9624450fe01562d15475"
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
        raise SystemExit("Usage: task20_d2i_verify_canonical_v099.py <app-root>")

    root = Path(sys.argv[1]).resolve()
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    repository_path = root / "lib/features/onboarding/data/local_onboarding_repository.dart"
    repository = repository_path.read_text(encoding="utf-8")
    provider_path = root / "lib/features/onboarding/presentation/onboarding_notifier.dart"
    provider = provider_path.read_text(encoding="utf-8")
    test_path = root / "test/features/onboarding/data/local_onboarding_repository_test.dart"
    tests = test_path.read_text(encoding="utf-8")
    report_path = root / "docs/TASK20_D2I_CURRENT_ONBOARDING_SCOPE_FIX.md"
    readme = (root / "README.md").read_text(encoding="utf-8")
    matrix = (root / "docs/VERSION_MATRIX.md").read_text(encoding="utf-8")
    roadmap = (root / "docs/IMPLEMENTATION_ROADMAP.md").read_text(encoding="utf-8")
    decision = (root / "docs/DECISION_LOG.md").read_text(encoding="utf-8")
    manifest_text = (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8")

    require(pubspec, "version: 0.9.9+27\n", "canonical app version")
    for marker in [
        "AccountRepository? accountRepository",
        "Future<String> _currentUserId()",
        "WHERE user_id = ?",
        "OnboardingStep.intro.code",
        "Current-user onboarding draft identity mismatch.",
    ]:
        require(repository, marker, "current-user onboarding scope")
    require(
        provider,
        "accountRepository: ref.watch(accountRepositoryProvider)",
        "production current-user onboarding provider",
    )
    for marker in [
        "loadStatus ignores another users completed profile",
        "intro-only current-user draft is notStarted",
        "advanced current-user draft is inProgress",
        "loadOrCreateDraft uses only the current account",
    ]:
        require(tests, marker, "current-user onboarding regression test")

    if not report_path.is_file():
        raise SystemExit("Task20-D2I current-user onboarding fix report is missing")
    require(readme, "実装基盤 v0.9.9", "README version")
    require(readme, "0.9.9+27", "README app version")
    require(matrix, "現在のプロジェクト版：`0.9.9+27`", "version matrix")
    require(matrix, "タスク20-D2I：Onboarding current-user境界", "version matrix v0.9.9 row")
    require(roadmap, "v0.9.9", "roadmap v0.9.9")
    require(decision, "D-017 Onboarding状態とdraftはcurrent userへ限定", "decision log D-017")
    require(manifest_text, "docs/TASK20_D2I_CURRENT_ONBOARDING_SCOPE_FIX.md", "manifest fix report")
    require(manifest_text, "test/features/onboarding/data/local_onboarding_repository_test.dart", "manifest regression test")

    require_sha(repository_path, EXPECTED_ONBOARDING_REPOSITORY_SHA256, "Onboarding repository")
    require_sha(provider_path, EXPECTED_ONBOARDING_PROVIDER_SHA256, "Onboarding provider")
    require_sha(test_path, EXPECTED_ONBOARDING_TEST_SHA256, "Onboarding repository test")
    require_sha(report_path, EXPECTED_FIX_REPORT_SHA256, "D2I onboarding fix report")

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
        "task": "Task20-D2I current-user onboarding scope fix",
        "canonical_package": "implementation-v0.9.9.zip",
        "app_version": "0.9.9+27",
        "schema_version": 9,
        "schema_table_count": 75,
        "runtime_behavior_changed_from_v0_9_8": True,
        "schema_changed_from_v0_9_8": False,
        "assets_changed_from_v0_9_8": False,
        "onboarding_status_scoped_to_current_user": True,
        "onboarding_draft_scoped_to_current_user": True,
        "intro_only_draft_is_not_started": True,
        "regression_tests_added": 4,
        "expected_flutter_test_count": 56,
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
    (output_dir / "task20_d2i_canonical_package_v099.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
