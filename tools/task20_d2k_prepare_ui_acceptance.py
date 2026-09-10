#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
import traceback
import zipfile
from pathlib import Path

EXPECTED_CANDIDATE_SHA256 = "714b56ed1f074f22a500932719d75398ecfbc1c853da74e01eda85c4601fa6eb"
EXPECTED_CANONICAL_SECURE_STORE_SHA256 = "33b463ca8f7cfd9e9e4cdf43ebb31f2e3cf8a517810dd835bfab1cfe0ec4881f"
SECURE_STORE_MEMBER = "lib/core/security/secure_store.dart"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def patch_secure_store_for_d2k(app_dir: Path) -> dict[str, object]:
    repo_root = Path(__file__).resolve().parents[1]
    secure_store = app_dir / SECURE_STORE_MEMBER
    if not secure_store.is_file():
        raise SystemExit(f"secure_store.dart not found: {secure_store}")

    evidence_dir = app_dir / "build" / "task20_d2k_reset_interruption"
    evidence_dir.mkdir(parents=True, exist_ok=True)

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
    marker_count = original.count(marker)
    replacement_count = original.count(replacement)
    already_instrumented = False
    canonical_recovered = False
    unexpected_sha256: str | None = None

    if marker_count == 0 and replacement_count == 0:
        # The outer lane has already authenticated the canonical v0.9.22 ZIP.
        # Some preceding iOS acceptance helpers can leave an app-source overlay
        # behind after their process exits. Recover only this test-overlaid file
        # from that exact ZIP, preserve the unexpected source as evidence, and
        # then apply the D2K-only instrumentation deterministically.
        candidate_zip = repo_root / "implementation-v0.9.22.zip"
        if not candidate_zip.is_file():
            raise SystemExit(f"canonical v0.9.22 candidate ZIP not found: {candidate_zip}")
        candidate_bytes = candidate_zip.read_bytes()
        candidate_sha256 = sha256_bytes(candidate_bytes)
        if candidate_sha256 != EXPECTED_CANDIDATE_SHA256:
            raise SystemExit(
                "D2K canonical candidate ZIP SHA mismatch during SecureStore recovery: "
                f"{candidate_sha256}"
            )
        with zipfile.ZipFile(candidate_zip) as archive:
            canonical_bytes = archive.read(SECURE_STORE_MEMBER)
        canonical_sha256 = sha256_bytes(canonical_bytes)
        if canonical_sha256 != EXPECTED_CANONICAL_SECURE_STORE_SHA256:
            raise SystemExit(
                "D2K canonical SecureStore SHA mismatch during recovery: "
                f"{canonical_sha256}"
            )
        canonical_text = canonical_bytes.decode("utf-8")
        if canonical_text.count(marker) != 1 or canonical_text.count(replacement) != 0:
            raise SystemExit("D2K canonical SecureStore marker contract mismatch during recovery")

        unexpected_bytes = original.encode("utf-8")
        unexpected_sha256 = sha256_bytes(unexpected_bytes)
        (evidence_dir / "secure_store_preinstrumentation_unexpected.dart").write_bytes(
            unexpected_bytes
        )
        (evidence_dir / "secure_store_recovery.json").write_text(
            json.dumps(
                {
                    "status": "RECOVERED",
                    "unexpected_sha256": unexpected_sha256,
                    "unexpected_marker_count": marker_count,
                    "unexpected_instrumented_count": replacement_count,
                    "candidate_zip_sha256": candidate_sha256,
                    "canonical_secure_store_sha256": canonical_sha256,
                    "product_zip_changed": False,
                },
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
        secure_store.write_bytes(canonical_bytes)
        original = canonical_text
        marker_count = 1
        replacement_count = 0
        canonical_recovered = True

    if marker_count == 1 and replacement_count == 0:
        canonical = original
        patched = original.replace(marker, replacement, 1)
        secure_store.write_text(patched, encoding="utf-8")
    elif marker_count == 0 and replacement_count == 1:
        # The outer iOS runner can retry after a simulator/startup failure
        # without re-extracting the canonical application tree. In that case
        # the D2K test-only overlay is already present and must be reusable.
        already_instrumented = True
        patched = original
        canonical = original.replace(replacement, marker, 1)
    else:
        raise SystemExit(
            "D2K secure-store instrumentation precondition mismatch: "
            f"expected canonical=(1,0) or already-instrumented=(0,1), "
            f"found marker={marker_count}, instrumented={replacement_count}"
        )

    return {
        "path": str(secure_store.relative_to(app_dir)),
        "original_sha256": hashlib.sha256(canonical.encode()).hexdigest(),
        "instrumented_sha256": hashlib.sha256(patched.encode()).hexdigest(),
        "already_instrumented": already_instrumented,
        "canonical_recovered": canonical_recovered,
        "unexpected_sha256": unexpected_sha256,
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

    evidence_dir = app_dir / "build" / "task20_d2k_reset_interruption"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    stage_file = evidence_dir / "prepare_stage.txt"

    stage_file.write_text("d2i_prepare\n", encoding="utf-8")
    d2i_result = subprocess.run(
        [
            sys.executable,
            str(repo_root / "tools" / "task20_d2i_prepare_ui_acceptance.py"),
            str(app_dir),
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    (evidence_dir / "d2i_prepare.log").write_text(
        d2i_result.stdout or "",
        encoding="utf-8",
    )
    if d2i_result.returncode != 0:
        raise SystemExit(
            f"Task 20-D2I overlay preparation failed with exit {d2i_result.returncode}; "
            f"see {evidence_dir / 'd2i_prepare.log'}"
        )

    stage_file.write_text("copy_d2k_tests\n", encoding="utf-8")
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

    stage_file.write_text("secure_store_instrumentation\n", encoding="utf-8")
    instrumentation = patch_secure_store_for_d2k(app_dir)
    (evidence_dir / "test_gate_instrumentation.json").write_text(
        json.dumps(instrumentation, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    stage_file.write_text("PASS\n", encoding="utf-8")
    print(f"Prepared Task 20-D2K test overlay in {app_dir}")
    print(json.dumps(instrumentation, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        exit_code = main()
    except BaseException as error:
        if len(sys.argv) == 2:
            app_dir = Path(sys.argv[1]).resolve()
            evidence_dir = app_dir / "build" / "task20_d2k_reset_interruption"
            evidence_dir.mkdir(parents=True, exist_ok=True)
            (evidence_dir / "prepare_failure.log").write_text(
                "".join(traceback.format_exception(type(error), error, error.__traceback__)),
                encoding="utf-8",
            )
        raise
    raise SystemExit(exit_code)
