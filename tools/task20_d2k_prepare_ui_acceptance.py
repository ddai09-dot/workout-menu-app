#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path


def patch_secure_store_for_d2k(app_dir: Path) -> dict[str, object]:
    secure_store = app_dir / "lib" / "core" / "security" / "secure_store.dart"
    if not secure_store.is_file():
        raise SystemExit(f"secure_store.dart not found: {secure_store}")

    original = secure_store.read_text(encoding="utf-8")
    marker = """  @override
  Future<void> write({
    required String key,
    required String value,
  }) {
    return _storage.write(key: key, value: value);
  }
"""
    replacement = """  @override
  Future<void> write({
    required String key,
    required String value,
  }) async {
    await _storage.write(key: key, value: value);

    const d2kGateEnabled = bool.fromEnvironment('TASK20_D2K_TEST_GATE');
    if (!d2kGateEnabled || key != 'current_user_id') {
      return;
    }
    final gateArmed = await _storage.read(key: 'task20_d2k_gate_armed');
    if (gateArmed != '1') {
      return;
    }

    // Test-only deterministic pause. The real secure-store write above has
    // completed, but LocalAccountRepository.resetLocalData has not yet begun
    // its database transaction. The host acquires BEGIN IMMEDIATE during this
    // pause, then waits for the release marker before OS termination.
    // ignore: avoid_print
    print('D2K_SECURE_KEY_SWITCHED_WAITING_FOR_HOST');
    await Future<void>.delayed(const Duration(seconds: 60));
    // ignore: avoid_print
    print('D2K_SECURE_KEY_GATE_RELEASED');
  }
"""
    count = original.count(marker)
    if count != 1:
        raise SystemExit(
            "D2K secure-store instrumentation precondition mismatch: "
            f"expected exactly one write method marker, found {count}"
        )
    patched = original.replace(marker, replacement, 1)
    secure_store.write_text(patched, encoding="utf-8")
    return {
        "path": str(secure_store.relative_to(app_dir)),
        "original_sha256": hashlib.sha256(original.encode()).hexdigest(),
        "instrumented_sha256": hashlib.sha256(patched.encode()).hexdigest(),
        "dart_define": "TASK20_D2K_TEST_GATE=true",
        "gate_key": "task20_d2k_gate_armed",
        "waiting_marker": "D2K_SECURE_KEY_SWITCHED_WAITING_FOR_HOST",
        "release_marker": "D2K_SECURE_KEY_GATE_RELEASED",
        "pause_seconds": 60,
        "product_zip_changed": False,
        "scope": "test-only overlay after canonical v0.9.22 extraction",
    }


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2k_prepare_ui_acceptance.py <app-dir>")

    repo_root = Path(__file__).resolve().parents[1]
    app_dir = Path(sys.argv[1]).resolve()
    if not (app_dir / "pubspec.yaml").is_file():
        raise SystemExit(f"pubspec.yaml not found: {app_dir / 'pubspec.yaml'}")

    subprocess.run(
        [
            sys.executable,
            str(repo_root / "tools" / "task20_d2i_prepare_ui_acceptance.py"),
            str(app_dir),
        ],
        check=True,
    )

    source_files = {
        repo_root / "tools" / "task20_d2k_reset_interruption_trigger_test.dart":
            app_dir / "integration_test" / "task20_d2k_reset_interruption_trigger_test.dart",
        repo_root / "tools" / "task20_d2k_reset_interruption_verify_test.dart":
            app_dir / "integration_test" / "task20_d2k_reset_interruption_verify_test.dart",
    }
    for source, destination in source_files.items():
        if not source.is_file():
            raise SystemExit(f"test overlay source not found: {source}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)

    instrumentation = patch_secure_store_for_d2k(app_dir)
    evidence_dir = app_dir / "build" / "task20_d2k_reset_interruption"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    (evidence_dir / "test_gate_instrumentation.json").write_text(
        json.dumps(instrumentation, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print(f"Prepared Task 20-D2K test overlay in {app_dir}")
    print(json.dumps(instrumentation, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
