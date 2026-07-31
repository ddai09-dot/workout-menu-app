#!/usr/bin/env python3
"""Build Task20-D2G canonical v0.9.6 from canonical v0.9.5."""
from __future__ import annotations

import base64
import hashlib
import json
import shutil
import sys
import zipfile
import zlib
from pathlib import Path

EXPECTED_ZIP_SHA256 = "575e87b36a1c34623b6e20d76f6df29c8372bbea9849903e717c4c81662ecb79"
EXPECTED_PAYLOAD_SHA256 = "eaa41d49a2e19ead0da5aab9de103352d414578ef52b72fd496a65de5296f9fe"
EXCLUDED_TOP_LEVEL = {"build", ".dart_tool"}
PAYLOAD_DIRECTORY = "task20_d2g_v096_payload"


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
    payload_directory = Path(__file__).resolve().with_name(PAYLOAD_DIRECTORY)
    payload_parts = sorted(payload_directory.glob("part-*.b64"))
    if not payload_parts:
        fail("Task20-D2G v0.9.6 overlay payload parts are missing")
    encoded_payload = "".join(
        part.read_text(encoding="ascii").strip() for part in payload_parts
    )
    payload_bytes = base64.b64decode(encoded_payload, validate=True)
    payload_sha = hashlib.sha256(payload_bytes).hexdigest()
    if payload_sha != EXPECTED_PAYLOAD_SHA256:
        fail(f"Overlay payload SHA-256 mismatch: {payload_sha} != {EXPECTED_PAYLOAD_SHA256}")
    payload = json.loads(zlib.decompress(payload_bytes).decode("utf-8"))
    if (
        payload.get("format") != 1
        or payload.get("base_version") != "0.9.5+23"
        or payload.get("target_version") != "0.9.6+24"
    ):
        fail("Unsupported Task20-D2G v0.9.6 overlay payload")
    pubspec = root / "pubspec.yaml"
    if not pubspec.is_file() or "version: 0.9.5+23\n" not in pubspec.read_text(encoding="utf-8"):
        fail("Input is not the v0.9.5+23 canonical package")

    for item in payload["files"]:
        path = root / item["path"]
        source_sha = item["source_sha256"]
        if source_sha is None:
            if path.exists():
                fail(f"Overlay new file already exists: {item['path']}")
        else:
            if not path.is_file():
                fail(f"Overlay source file is missing: {item['path']}")
            actual_source_sha = hashlib.sha256(path.read_bytes()).hexdigest()
            if actual_source_sha != source_sha:
                fail(
                    f"Overlay source SHA-256 mismatch for {item['path']}: "
                    f"{actual_source_sha} != {source_sha}"
                )
        path.parent.mkdir(parents=True, exist_ok=True)
        content = item["content"].encode("utf-8")
        target_sha = hashlib.sha256(content).hexdigest()
        if target_sha != item["target_sha256"]:
            fail(f"Overlay target SHA-256 mismatch for {item['path']}")
        path.write_bytes(content)

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
