#!/usr/bin/env python3
"""Verify Task20-D2J v0.9.11 canonical package and D2I-parent preservation."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

EXPECTED_RUNTIME_TREE_SHA256 = "3eeb5a3357ca1ec2a42f486de1b375312f1baf64bfde1682f1f38b7bc702a71e"
EXPECTED_PRODUCT_LIB_TREE_SHA256 = "6eea4b98f6741cf7e02699cda31b8d2c5e894366e82c2b15f9c8fa287553bfdc"
EXPECTED_TEST_TREE_SHA256 = "878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5"
EXPECTED_SCHEMA_TREE_SHA256 = "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af"
EXPECTED_ASSET_TREE_SHA256 = "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe"
EXPECTED_HOME_SHA256 = "f18059798cba8a49f14b1792950ad70a43a9b3e414411334e70f8f76b2d1f2f7"
EXPECTED_MENU_SHA256 = "5d617e30af5743aebe62e8a2947a67f3299d69c23e8b3e0a65cef5dd75cc7639"
EXPECTED_ACCEPTED_PARENT_ZIP_SHA256 = "9fce3c9dd234fcc669ed7e5b62b8b2d612b3fa80b634bca14406cf5c6bb4836f"
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
        raise SystemExit("Usage: task20_d2j_verify_canonical_v0911.py <app-root>")
    root = Path(sys.argv[1]).resolve()
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    home_path = root / "lib/features/home/presentation/home_page.dart"
    menu_path = root / "lib/features/menu/presentation/menu_page.dart"
    home = home_path.read_text(encoding="utf-8")
    menu = menu_path.read_text(encoding="utf-8")
    account = (root / "lib/features/account/data/local_account_repository.dart").read_text(encoding="utf-8")
    onboarding = (root / "lib/features/onboarding/data/local_onboarding_repository.dart").read_text(encoding="utf-8")
    onboarding_test = (root / "test/features/onboarding/data/local_onboarding_repository_test.dart").read_text(encoding="utf-8")
    manifest = (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8")

    require(pubspec, "version: 0.9.11+29\n", "canonical app version")

    # D2J layout fixes must remain exact and acceptance must not be weakened.
    require(home, "data: (TodayAction value) => SingleChildScrollView(", "scrollable Home TodayAction")
    require(home, "mainAxisSize: MainAxisSize.min", "minimum-height Home column")
    require(home, "const SizedBox(height: 24)", "Home fixed action spacing")
    if "const Spacer()" in home:
        raise SystemExit("Home TodayAction still contains Spacer")
    require(menu, "return LayoutBuilder(", "Menu empty-state layout builder")
    require(menu, "return SingleChildScrollView(", "Menu empty-state scroll view")
    require(menu, "BoxConstraints(minHeight: constraints.maxHeight)", "Menu minimum viewport height")
    require(menu, "child: Center(", "Menu normal-state centering")
    if hashlib.sha256(home_path.read_bytes()).hexdigest() != EXPECTED_HOME_SHA256:
        raise SystemExit("HomePage SHA mismatch")
    if hashlib.sha256(menu_path.read_bytes()).hexdigest() != EXPECTED_MENU_SHA256:
        raise SystemExit("MenuPage SHA mismatch")

    # Preserve accepted D2I product/test boundaries from v0.9.10.
    require(account, "onboarding_completed_at IS NOT NULL", "D2I completed-account recovery")
    require(account, "Cannot recover current account because multiple completed local accounts exist", "D2I ambiguity guard")
    require(onboarding, "Future<String> _currentUserId() async", "D2I current-user onboarding scope")
    require(onboarding, "ensureAnonymousAccount()", "D2I AccountRepository current-user source")
    require(onboarding, "OnboardingStep.intro", "D2I INTRO boundary")
    require(onboarding_test, "hide OnboardingDraft;", "v0.9.10 analyzer import fix")
    require(
        (root / "docs/TASK20_D2I_V099_ANALYZER_IMPORT_FIX.md").read_text(encoding="utf-8"),
        "v0.9.10",
        "D2I v0.9.10 history",
    )
    require(
        (root / "docs/TASK20_D2J_DYNAMIC_TYPE_LAYOUT_FIX.md").read_text(encoding="utf-8"),
        "121 pixels",
        "D2J Menu failure history",
    )

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
    lib_hash, lib_files = tree_hash(root, ["lib"])
    test_hash, test_files = tree_hash(root, ["test"])
    schema_hash, schema_files = tree_hash(
        root,
        ["docs/schema_v9.sqlite.sql", "docs/migrations", "lib/core/database/schema"],
    )
    asset_hash, asset_files = tree_hash(root, ["assets"])
    actual = {
        "runtime": runtime_hash,
        "product_lib": lib_hash,
        "tests": test_hash,
        "schema": schema_hash,
        "assets": asset_hash,
    }
    expected = {
        "runtime": EXPECTED_RUNTIME_TREE_SHA256,
        "product_lib": EXPECTED_PRODUCT_LIB_TREE_SHA256,
        "tests": EXPECTED_TEST_TREE_SHA256,
        "schema": EXPECTED_SCHEMA_TREE_SHA256,
        "assets": EXPECTED_ASSET_TREE_SHA256,
    }
    for label, expected_hash in expected.items():
        if actual[label] != expected_hash:
            raise SystemExit(f"{label} tree mismatch: {actual[label]} != {expected_hash}")

    result = {
        "status": "PASS",
        "task": "Task20-D2J Dynamic Type Home/Menu layout fix",
        "canonical_package": "implementation-v0.9.11.zip",
        "app_version": "0.9.11+29",
        "accepted_parent_version": "0.9.10+28",
        "accepted_parent_zip_sha256": EXPECTED_ACCEPTED_PARENT_ZIP_SHA256,
        "accepted_parent_reconstructed_and_sha_verified_by_builder": True,
        "d2i_product_and_test_boundaries_preserved": True,
        "expected_flutter_test_count": 56,
        "schema_version": 9,
        "schema_table_count": 75,
        "schema_changed_from_v0_9_10": False,
        "assets_changed_from_v0_9_10": False,
        "tree_hashes": actual,
        "tree_file_counts": {
            "runtime": runtime_files,
            "product_lib": lib_files,
            "tests": test_files,
            "schema": schema_files,
            "assets": asset_files,
        },
        "fixes": [
            "Home TodayAction is vertically scrollable when enlarged text exceeds the viewport",
            "Menu empty state preserves normal centering and becomes vertically scrollable when needed",
        ],
        "d2j_acceptance_status": "PENDING_CURRENT_HEAD_CI_AND_ARTIFACT_AUDIT",
        "task20_d2_fully_verified": False,
        "physical_device_verified": False,
        "native_accessibility_verified": False,
    }
    output_dir = root / "build/task20_b_logs/flutter"
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "task20_d2j_canonical_package_v0911.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
