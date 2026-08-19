#!/usr/bin/env python3
"""Build Task20-D2I canonical v0.9.8 from canonical v0.9.7."""
from __future__ import annotations

import base64
import gzip
import hashlib
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

EXPECTED_ZIP_SHA256 = "96ec3656dfe8c8d03654975d54daa7160a93788abf6f03ad8e502c0d3136726f"
EXPECTED_PATCH_SHA256 = "05718424ba4b06eb15cdbcbce7f921992064ee2c322aa0669c51bbddac00bc71"
EXPECTED_PATCH_GZIP_SHA256 = "dfb200abbed9a3b9964a10a1ff87ff4cb0e90ba2f0312addef8c10ea660236e0"
EXCLUDED_TOP_LEVEL = {"build", ".dart_tool"}


def canonical_files(root: Path) -> list[str]:
    return sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
        and path.relative_to(root).parts[0] not in EXCLUDED_TOP_LEVEL
        and "__pycache__" not in path.relative_to(root).parts
    )


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit(
            "Usage: task20_d2i_build_canonical_v098.py <v0.9.7-app-root> <output-zip>"
        )

    source = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    payload_path = Path(__file__).with_name("task20_d2i_v098.patch.gz.b64")
    if not source.is_dir():
        raise SystemExit(f"Input app root does not exist: {source}")
    if "version: 0.9.7+25" not in (source / "pubspec.yaml").read_text(encoding="utf-8"):
        raise SystemExit("Task20-D2I v0.9.8 builder requires canonical v0.9.7 input")
    if not payload_path.is_file():
        raise SystemExit(f"Patch payload is missing: {payload_path}")

    compressed = base64.b64decode(payload_path.read_text(encoding="utf-8"))
    compressed_sha = hashlib.sha256(compressed).hexdigest()
    if compressed_sha != EXPECTED_PATCH_GZIP_SHA256:
        raise SystemExit(
            f"Compressed patch SHA mismatch: {compressed_sha} != {EXPECTED_PATCH_GZIP_SHA256}"
        )
    patch = gzip.decompress(compressed)
    patch_sha = hashlib.sha256(patch).hexdigest()
    if patch_sha != EXPECTED_PATCH_SHA256:
        raise SystemExit(f"Patch SHA mismatch: {patch_sha} != {EXPECTED_PATCH_SHA256}")

    with tempfile.TemporaryDirectory(prefix="task20-d2i-v098-") as temporary:
        root = Path(temporary) / "app"
        shutil.copytree(source, root)
        subprocess.run(
            ["patch", "--batch", "--forward", "-p1"],
            cwd=root,
            input=patch,
            check=True,
        )

        files = canonical_files(root)
        manifest = [
            line
            for line in (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8").splitlines()
            if line
        ]
        if manifest != files:
            raise SystemExit("Patched FILE_MANIFEST.txt does not match canonical files")

        output.parent.mkdir(parents=True, exist_ok=True)
        if output.exists():
            output.unlink()
        with zipfile.ZipFile(
            output,
            "w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        ) as archive:
            for relative in files:
                path = root / relative
                info = zipfile.ZipInfo(relative, date_time=(2020, 1, 1, 0, 0, 0))
                info.create_system = 3
                mode = 0o755 if (path.stat().st_mode & stat.S_IXUSR) else 0o644
                info.external_attr = (stat.S_IFREG | mode) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                info.flag_bits |= 0x800
                archive.writestr(
                    info,
                    path.read_bytes(),
                    compress_type=zipfile.ZIP_DEFLATED,
                    compresslevel=9,
                )

    actual = hashlib.sha256(output.read_bytes()).hexdigest()
    if actual != EXPECTED_ZIP_SHA256:
        raise SystemExit(f"ZIP SHA-256 mismatch: {actual} != {EXPECTED_ZIP_SHA256}")
    print(f"Task20-D2I canonical package PASS: {output} sha256={actual}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
