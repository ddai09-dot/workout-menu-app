#!/usr/bin/env python3
"""Build Task20-D2I canonical v0.9.9 from canonical v0.9.8."""
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

EXPECTED_ZIP_SHA256 = "82186032482561daf7b56cfeeb8fdb5fd318aa294198af1abb65e72d2c123016"
EXPECTED_PATCH_SHA256 = "0f2272ce052aaeabd546e0ccf8fc6a52a98b6cc83454ab903858eab76538952c"
EXPECTED_PATCH_GZIP_SHA256 = "574dd95591531879a44f861d3bfe326d011e871b923facf85e09da0311776712"
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
            "Usage: task20_d2i_build_canonical_v099.py <v0.9.8-app-root> <output-zip>"
        )

    source = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    payload_dir = Path(__file__).parent
    payload_parts = sorted(payload_dir.glob("task20_d2i_v099.patch.gz.b64.part*"))
    if not source.is_dir():
        raise SystemExit(f"Input app root does not exist: {source}")
    if "version: 0.9.8+26" not in (source / "pubspec.yaml").read_text(encoding="utf-8"):
        raise SystemExit("Task20-D2I v0.9.9 builder requires canonical v0.9.8 input")
    if len(payload_parts) != 8:
        raise SystemExit(f"Patch payload chunk count mismatch: {len(payload_parts)} != 8")

    payload_text = "".join(part.read_text(encoding="utf-8").strip() for part in payload_parts)
    compressed = base64.b64decode(payload_text, validate=True)
    compressed_sha = hashlib.sha256(compressed).hexdigest()
    if compressed_sha != EXPECTED_PATCH_GZIP_SHA256:
        raise SystemExit(
            f"Compressed patch SHA mismatch: {compressed_sha} != {EXPECTED_PATCH_GZIP_SHA256}"
        )
    patch = gzip.decompress(compressed)
    patch_sha = hashlib.sha256(patch).hexdigest()
    if patch_sha != EXPECTED_PATCH_SHA256:
        raise SystemExit(f"Patch SHA mismatch: {patch_sha} != {EXPECTED_PATCH_SHA256}")

    with tempfile.TemporaryDirectory(prefix="task20-d2i-v099-") as temporary:
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
