#!/usr/bin/env python3
"""Restore the exact accepted v0.9.22 CI dependency lock without modifying the product ZIP."""

from __future__ import annotations

import base64
import gzip
import hashlib
import json
import sys
from pathlib import Path

EXPECTED_FIXTURE_SHA256 = "af9faaa6a3ded10940c3d33f2edde3847528413fe5cb0a61bc8ee05d668b2028"
EXPECTED_LOCK_SHA256 = "2b9fd241e021b09d40222cc738da578620fda952591bfc66d95ef08d1beef599"
EXPECTED_PUBSPEC_SHA256 = "e2991fbf2fb60559ffca36bdd204e531eea1bc5147ed779f923a4fd358a985df"
EXPECTED_CANDIDATE_SHA256 = "714b56ed1f074f22a500932719d75398ecfbc1c853da74e01eda85c4601fa6eb"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    app = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / "app"
    fixture = root / "tools/fixtures/task20_v0922_pubspec_lock.gz.b64"
    candidate = root / "implementation-v0.9.22.zip"
    pubspec = app / "pubspec.yaml"
    lock = app / "pubspec.lock"

    fixture_bytes = fixture.read_bytes()
    if sha256(fixture_bytes) != EXPECTED_FIXTURE_SHA256:
        raise SystemExit("accepted v0.9.22 CI lock fixture SHA mismatch")
    if sha256(candidate.read_bytes()) != EXPECTED_CANDIDATE_SHA256:
        raise SystemExit("canonical v0.9.22 candidate ZIP SHA mismatch before CI lock restore")
    if sha256(pubspec.read_bytes()) != EXPECTED_PUBSPEC_SHA256:
        raise SystemExit("canonical v0.9.22 pubspec.yaml SHA mismatch before CI lock restore")

    lock_bytes = gzip.decompress(base64.b64decode(fixture_bytes))
    if sha256(lock_bytes) != EXPECTED_LOCK_SHA256:
        raise SystemExit("decoded accepted v0.9.22 CI lock SHA mismatch")

    lock.write_bytes(lock_bytes)
    if sha256(lock.read_bytes()) != EXPECTED_LOCK_SHA256:
        raise SystemExit("restored app/pubspec.lock SHA mismatch")

    text = lock_bytes.decode("utf-8")
    if '  build_runner:\n' not in text or '    version: "2.15.1"\n' not in text:
        raise SystemExit("accepted build_runner resolution missing from restored lock")
    drift_start = text.find("  drift_dev:\n")
    if drift_start < 0 or '    version: "2.34.0"\n' not in text[drift_start:drift_start + 700]:
        raise SystemExit("accepted drift_dev 2.34.0 resolution missing from restored lock")

    print(json.dumps({
        "status": "PASS",
        "task": "Task20 v0.9.22 accepted CI dependency lock restore",
        "candidate_zip_sha256": EXPECTED_CANDIDATE_SHA256,
        "pubspec_sha256": EXPECTED_PUBSPEC_SHA256,
        "pubspec_lock_sha256": EXPECTED_LOCK_SHA256,
        "product_zip_changed": False,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
