#!/usr/bin/env python3
"""Verify Task20-D2I v0.9.10 analyzer-import-only candidate."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

EXPECTED_RUNTIME_TREE_SHA256 = "739b2f5dae66f86a9e6b368b1ba7c440684c650f67843d9834d107c20ce21e6a"
EXPECTED_PRODUCT_LIB_TREE_SHA256 = "0d13db6a7af6d8cbaaa25120b24fbfb3504f236c6168a2a24eb2705efc316570"
EXPECTED_SCHEMA_TREE_SHA256 = "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af"
EXPECTED_ASSET_TREE_SHA256 = "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe"
EXPECTED_TEST_SHA256 = "062edb4892f0e6288eaf4e986ed0c244bc2f1664346c4f5fbd9f0d5e0ef06b78"
EXPECTED_REPORT_SHA256 = "a67a526bbdecef997ec2949b997cf1dcf87c390b305e512523179ac0207105e3"
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
        raise SystemExit("Usage: task20_d2i_verify_canonical_v0910.py <app-root>")

    root = Path(sys.argv[1]).resolve()
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    test_path = root / "test/features/onboarding/data/local_onboarding_repository_test.dart"
    tests = test_path.read_text(encoding="utf-8")
    report_path = root / "docs/TASK20_D2I_V099_ANALYZER_IMPORT_FIX.md"
    readme = (root / "README.md").read_text(encoding="utf-8")
    matrix = (root / "docs/VERSION_MATRIX.md").read_text(encoding="utf-8")
    decision = (root / "docs/DECISION_LOG.md").read_text(encoding="utf-8")
    manifest_text = (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8")

    require(pubspec, "version: 0.9.10+28\n", "canonical app version")
    require(
        tests,
        "app_database.dart' hide OnboardingDraft;",
        "DB-generated OnboardingDraft import disambiguation",
    )
    require(tests, "onboarding/domain/onboarding_draft.dart';", "domain OnboardingDraft import")
    require(readme, "実装基盤 v0.9.10", "README version")
    require(readme, "#212／iOS #199", "README failed-candidate evidence")
    require(matrix, "現在のプロジェクト版：`0.9.10+28`", "version matrix")
    require(matrix, "0.9.10", "version matrix v0.9.10 row")
    require(decision, "D-018", "decision log D-018")
    require(manifest_text, "docs/TASK20_D2I_V099_ANALYZER_IMPORT_FIX.md", "manifest report")
    if not report_path.is_file():
        raise SystemExit("v0.9.9 analyzer import fix report is missing")
    require_sha(test_path, EXPECTED_TEST_SHA256, "Onboarding repository test")
    require_sha(report_path, EXPECTED_REPORT_SHA256, "Analyzer import fix report")

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
    product_lib_hash, product_lib_files = tree_hash(root, ["lib"])
    schema_hash, schema_files = tree_hash(
        root,
        ["docs/schema_v9.sqlite.sql", "docs/migrations", "lib/core/database/schema"],
    )
    asset_hash, asset_files = tree_hash(root, ["assets"])
    actual = {
        "runtime": runtime_hash,
        "product_lib": product_lib_hash,
        "schema": schema_hash,
        "assets": asset_hash,
    }
    expected = {
        "runtime": EXPECTED_RUNTIME_TREE_SHA256,
        "product_lib": EXPECTED_PRODUCT_LIB_TREE_SHA256,
        "schema": EXPECTED_SCHEMA_TREE_SHA256,
        "assets": EXPECTED_ASSET_TREE_SHA256,
    }
    for label, expected_hash in expected.items():
        if actual[label] != expected_hash:
            raise SystemExit(f"{label} tree mismatch: {actual[label]} != {expected_hash}")

    result = {
        "status": "PASS",
        "task": "Task20-D2I v0.9.9 analyzer import disambiguation",
        "canonical_package": "implementation-v0.9.10.zip",
        "app_version": "0.9.10+28",
        "schema_version": 9,
        "schema_table_count": 75,
        "product_runtime_changed_from_v0_9_9": False,
        "test_source_changed_from_v0_9_9": True,
        "schema_changed_from_v0_9_9": False,
        "assets_changed_from_v0_9_9": False,
        "ambiguous_onboarding_draft_import_resolved": True,
        "expected_flutter_test_count": 56,
        "tree_hashes": actual,
        "tree_file_counts": {
            "runtime": runtime_files,
            "product_lib": product_lib_files,
            "schema": schema_files,
            "assets": asset_files,
        },
        "task20_d2_fully_verified": False,
        "physical_device_verified": False,
        "native_accessibility_verified": False,
    }
    output_dir = root / "build/task20_b_logs/flutter"
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "task20_d2i_canonical_package_v0910.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
