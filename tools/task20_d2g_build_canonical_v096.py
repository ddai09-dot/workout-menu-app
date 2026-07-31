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

EXPECTED_ZIP_SHA256 = "575e87b36a1c34623b6e20d76f6df29c8372bbea9849903e717c4c81662ecb79"
EXPECTED_PATCH_SHA256 = "9fd54ee37e8976e938101f46200253ac22df8d01c4cffaf2e85435af5fd308c2"
EXPECTED_PATCH_GZIP_SHA256 = "a8904df782735144d9e383342c084a71abfc08011e0c082b3bd97031412b9214"
EXCLUDED_TOP_LEVEL = {"build", ".dart_tool"}
PATCH_GZIP_BASE64 = """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"""


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

    compressed_patch = base64.b64decode(PATCH_GZIP_BASE64, validate=True)
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
