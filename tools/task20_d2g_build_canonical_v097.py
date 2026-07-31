#!/usr/bin/env python3
"""Build Task20-D2G canonical v0.9.7 from canonical v0.9.6."""
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

EXPECTED_ZIP_SHA256 = "3ba2fc7b668437208507f5277c81861a514b3be56586e10fa6a19928cf8b77b2"
EXPECTED_PATCH_SHA256 = "04435dc363b003a6ff860980d84d97d0eb97c0944f56acff1c04af4e451c3b88"
EXPECTED_PATCH_GZIP_SHA256 = "9697dea2dbe5be0a47dd8f695e4ea12f3b5b6a811a60ae573bd9db368117c24d"
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
            "Usage: task20_d2g_build_canonical_v097.py <v0.9.6-app-root> <output-zip>"
        )

    source = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    payload_path = Path(__file__).with_name("task20_d2g_v097.patch.gz.b64")
    if not source.is_dir():
        raise SystemExit(f"Input app root does not exist: {source}")
    if "version: 0.9.6+24" not in (source / "pubspec.yaml").read_text(encoding="utf-8"):
        raise SystemExit("Task20-D2G v0.9.7 builder requires canonical v0.9.6 input")
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

    with tempfile.TemporaryDirectory(prefix="task20-d2g-v097-") as temporary:
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
    print(f"Task20-D2G canonical package PASS: {output} sha256={actual}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
