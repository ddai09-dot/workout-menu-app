#!/usr/bin/env python3
"""Build Task20-D2G canonical v0.9.6 from canonical v0.9.5."""
from __future__ import annotations

import base64
import gzip
import hashlib
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

EXPECTED_ZIP_SHA256 = "4db23063e90d3c8424076eb04d2ac3884d64b4cbc530fac94b738e0624e147ba"
EXPECTED_PATCH_SHA256 = "4ce9990858d6c2afc58c6ed5b48932ff7f7dad8eb0d43a096065846f777c4d2b"
EXPECTED_PATCH_GZIP_SHA256 = "bee8c21c732f79bb3c239647398ce0b9d034447048e3121fd9e2171dbbd0f0ad"
EXCLUDED_TOP_LEVEL = {"build", ".dart_tool"}
PATCH_FILE = "task20_d2g_v096.patch.gz.b64"


def fail(message: str) -> None:
    raise SystemExit(message)


def write_manifest(root: Path) -> None:
    files = sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
        and path.relative_to(root).parts[0] not in EXCLUDED_TOP_LEVEL
        and "__pycache__" not in path.relative_to(root).parts
    )
    (root / "FILE_MANIFEST.txt").write_text(
        "\n".join(files) + "\n", encoding="utf-8"
    )


def write_deterministic_zip(root: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(root.rglob("*")):
            if not path.is_file():
                continue
            relative = path.relative_to(root)
            if relative.parts[0] in EXCLUDED_TOP_LEVEL or "__pycache__" in relative.parts:
                continue
            info = zipfile.ZipInfo(relative.as_posix(), date_time=(2026, 7, 31, 0, 0, 0))
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info._compresslevel = 9
            info.external_attr = (path.stat().st_mode & 0o777) << 16
            archive.writestr(info, path.read_bytes())


def main() -> int:
    if len(sys.argv) != 3:
        fail("Usage: task20_d2g_build_canonical_v096.py <v0.9.5-root> <output-zip>")
    root = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    pubspec = root / "pubspec.yaml"
    if not pubspec.is_file() or "version: 0.9.5+23\n" not in pubspec.read_text(encoding="utf-8"):
        fail("Input is not the v0.9.5+23 canonical package")

    patch_path = Path(__file__).resolve().with_name(PATCH_FILE)
    compressed_patch = base64.b64decode(
        patch_path.read_text(encoding="ascii").strip(), validate=True
    )
    compressed_sha = hashlib.sha256(compressed_patch).hexdigest()
    if compressed_sha != EXPECTED_PATCH_GZIP_SHA256:
        fail(
            f"Compressed patch SHA-256 mismatch: {compressed_sha} != "
            f"{EXPECTED_PATCH_GZIP_SHA256}"
        )
    patch_bytes = gzip.decompress(compressed_patch)
    patch_sha = hashlib.sha256(patch_bytes).hexdigest()
    if patch_sha != EXPECTED_PATCH_SHA256:
        fail(f"Patch SHA-256 mismatch: {patch_sha} != {EXPECTED_PATCH_SHA256}")

    environment = os.environ.copy()
    environment["LC_ALL"] = "C"
    result = subprocess.run(
        ["patch", "-p1"],
        cwd=root,
        input=patch_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=environment,
        check=False,
    )
    if result.returncode != 0:
        fail("Canonical v0.9.6 patch failed:\n" + result.stdout.decode("utf-8", errors="replace"))

    shutil.rmtree(root / "build", ignore_errors=True)
    shutil.rmtree(root / ".dart_tool", ignore_errors=True)
    for cache in root.rglob("__pycache__"):
        shutil.rmtree(cache, ignore_errors=True)
    write_manifest(root)
    write_deterministic_zip(root, output)
    actual_zip_sha = hashlib.sha256(output.read_bytes()).hexdigest()
    if actual_zip_sha != EXPECTED_ZIP_SHA256:
        fail(f"Canonical ZIP SHA-256 mismatch: {actual_zip_sha} != {EXPECTED_ZIP_SHA256}")
    print(f"Task20-D2G canonical package PASS: {output} sha256={actual_zip_sha}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
