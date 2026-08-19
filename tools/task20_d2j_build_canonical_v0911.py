#!/usr/bin/env python3
"""Build Task20-D2J canonical v0.9.11 from canonical v0.9.7 via accepted v0.9.10."""
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

EXPECTED_V097_VERSION = "version: 0.9.7+25"
EXPECTED_V0910_VERSION = "version: 0.9.10+28"
EXPECTED_V0911_VERSION = "version: 0.9.11+29"
EXPECTED_V0910_ZIP_SHA256 = "9fce3c9dd234fcc669ed7e5b62b8b2d612b3fa80b634bca14406cf5c6bb4836f"
EXPECTED_V0911_ZIP_SHA256 = "d2bc188138c32322ede945a73dd8a8bd28a3c316efe0ad1430b463cb8bc973ab"
EXPECTED_BASE_PATCH_SHA256 = "72bd9c46405191c7ec8153fdcd3383e2b11081ee5c2879e674e578c4a61b71a3"
EXPECTED_BASE_PATCH_GZIP_SHA256 = "09b425a0ac1cba70f85ca07a52a5d7a4c6e74bf480910542ce4cdc4b5cdb30c9"
EXPECTED_D2J_PATCH_SHA256 = "5aa56dba53247fe7ab6cc78e0d70842eb8a03dd2df9bd7dd8a50d569cae2f099"
EXPECTED_D2J_PATCH_GZIP_SHA256 = "d16bc87443a98e172eb20bb5f05e6f126bc809005ee6453130dcebe0d7e81ae6"
EXCLUDED_TOP_LEVEL = {"build", ".dart_tool"}


def canonical_files(root: Path) -> list[str]:
    return sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
        and path.relative_to(root).parts[0] not in EXCLUDED_TOP_LEVEL
        and "__pycache__" not in path.relative_to(root).parts
    )


def load_patch(path: Path, expected_gzip: str, expected_raw: str) -> bytes:
    if not path.is_file():
        raise SystemExit(f"Patch payload is missing: {path}")
    compressed = base64.b64decode(path.read_text(encoding="utf-8"))
    compressed_sha = hashlib.sha256(compressed).hexdigest()
    if compressed_sha != expected_gzip:
        raise SystemExit(f"Compressed patch SHA mismatch: {compressed_sha} != {expected_gzip}")
    patch = gzip.decompress(compressed)
    raw_sha = hashlib.sha256(patch).hexdigest()
    if raw_sha != expected_raw:
        raise SystemExit(f"Patch SHA mismatch: {raw_sha} != {expected_raw}")
    return patch


def apply_patch(root: Path, patch: bytes) -> None:
    subprocess.run(
        ["patch", "--batch", "--forward", "-p1"],
        cwd=root,
        input=patch,
        check=True,
    )


def verify_manifest(root: Path) -> list[str]:
    files = canonical_files(root)
    manifest = [
        line
        for line in (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8").splitlines()
        if line
    ]
    if manifest != files:
        raise SystemExit("FILE_MANIFEST.txt does not match canonical files")
    return files


def write_zip(root: Path, output: Path, files: list[str]) -> str:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
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
    return hashlib.sha256(output.read_bytes()).hexdigest()


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit(
            "Usage: task20_d2j_build_canonical_v0911.py <v0.9.7-app-root> <output-zip>"
        )

    source = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    tool_dir = Path(__file__).resolve().parent
    base_payload = tool_dir / "task20_d2j_v0910_base.patch.gz.b64"
    d2j_payload = tool_dir / "task20_d2j_v0911.patch.gz.b64"
    if not source.is_dir():
        raise SystemExit(f"Input app root does not exist: {source}")
    if EXPECTED_V097_VERSION not in (source / "pubspec.yaml").read_text(encoding="utf-8"):
        raise SystemExit("v0.9.11 builder requires canonical v0.9.7 input")

    base_patch = load_patch(
        base_payload,
        EXPECTED_BASE_PATCH_GZIP_SHA256,
        EXPECTED_BASE_PATCH_SHA256,
    )
    d2j_patch = load_patch(
        d2j_payload,
        EXPECTED_D2J_PATCH_GZIP_SHA256,
        EXPECTED_D2J_PATCH_SHA256,
    )

    with tempfile.TemporaryDirectory(prefix="task20-d2j-v0911-") as temporary:
        root = Path(temporary) / "app"
        shutil.copytree(source, root)

        # Reconstruct and cryptographically prove the accepted D2I v0.9.10 parent.
        apply_patch(root, base_patch)
        if EXPECTED_V0910_VERSION not in (root / "pubspec.yaml").read_text(encoding="utf-8"):
            raise SystemExit("Intermediate accepted parent is not v0.9.10+28")
        parent_files = verify_manifest(root)
        intermediate = Path(temporary) / "implementation-v0.9.10.zip"
        parent_sha = write_zip(root, intermediate, parent_files)
        if parent_sha != EXPECTED_V0910_ZIP_SHA256:
            raise SystemExit(
                f"Accepted v0.9.10 parent SHA mismatch: {parent_sha} != {EXPECTED_V0910_ZIP_SHA256}"
            )
        parent_output = output.with_name("implementation-v0.9.10.zip")
        shutil.copyfile(intermediate, parent_output)

        # Apply only the D2J v0.9.11 delta after proving the parent bytes.
        apply_patch(root, d2j_patch)
        if EXPECTED_V0911_VERSION not in (root / "pubspec.yaml").read_text(encoding="utf-8"):
            raise SystemExit("Patched result is not v0.9.11+29")
        files = verify_manifest(root)
        actual = write_zip(root, output, files)

    if actual != EXPECTED_V0911_ZIP_SHA256:
        raise SystemExit(f"v0.9.11 ZIP SHA mismatch: {actual} != {EXPECTED_V0911_ZIP_SHA256}")
    print(
        "Task20-D2J canonical package PASS: "
        f"parent_v0910_sha256={EXPECTED_V0910_ZIP_SHA256} "
        f"output={output} sha256={actual}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
