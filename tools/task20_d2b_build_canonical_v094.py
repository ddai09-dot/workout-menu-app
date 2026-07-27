#!/usr/bin/env python3
"""Build Task20-D2B canonical v0.9.4 from canonical v0.9.3."""
from __future__ import annotations

import base64
import hashlib
import json
import shutil
import sys
import zipfile
import zlib
from pathlib import Path

EXPECTED_ZIP_SHA256 = "06815b331f1e21f3bb4f4c6d856b0cb616bd5f651b39706289770593d71d71c1"
EXPECTED_PAYLOAD_SHA256 = "a7153200788c2510b16e1e69668fc107e2c3294d3f3e9253dd1ba1940fa3e533"
EXCLUDED_TOP_LEVEL = {"build", ".dart_tool"}
PAYLOAD_DIRECTORY = "task20_d2b_v094_payload"


def fail(message: str) -> None:
    raise SystemExit(message)


def write_manifest(root: Path) -> None:
    files = sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
        and path.relative_to(root).parts[0] not in EXCLUDED_TOP_LEVEL
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
            if relative.parts[0] in EXCLUDED_TOP_LEVEL:
                continue
            info = zipfile.ZipInfo(relative.as_posix(), date_time=(2026, 7, 27, 0, 0, 0))
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info._compresslevel = 9
            info.external_attr = (path.stat().st_mode & 0o777) << 16
            archive.writestr(info, path.read_bytes())


def main() -> int:
    if len(sys.argv) != 3:
        fail("Usage: task20_d2b_build_canonical_v094.py <v0.9.3-root> <output-zip>")
    root = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    payload_directory = Path(__file__).resolve().with_name(PAYLOAD_DIRECTORY)
    payload_parts = sorted(payload_directory.glob("part-*.b64"))
    if not payload_parts:
        fail("Task20-D2B overlay payload parts are missing")
    encoded_payload = "".join(
        part.read_text(encoding="ascii").strip() for part in payload_parts
    )
    payload_bytes = base64.b64decode(encoded_payload, validate=True)
    payload_sha = hashlib.sha256(payload_bytes).hexdigest()
    if payload_sha != EXPECTED_PAYLOAD_SHA256:
        fail(f"Overlay payload SHA-256 mismatch: {payload_sha} != {EXPECTED_PAYLOAD_SHA256}")
    payload = json.loads(zlib.decompress(payload_bytes).decode("utf-8"))
    if payload.get("format") != 1 or payload.get("base_version") != "0.9.3+21":
        fail("Unsupported Task20-D2B overlay payload")
    pubspec = root / "pubspec.yaml"
    if not pubspec.is_file() or "version: 0.9.3+21\n" not in pubspec.read_text(encoding="utf-8"):
        fail("Input is not the v0.9.3+21 canonical package")

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
    write_manifest(root)
    write_deterministic_zip(root, output)
    actual_zip_sha = hashlib.sha256(output.read_bytes()).hexdigest()
    if actual_zip_sha != EXPECTED_ZIP_SHA256:
        fail(
            f"Canonical ZIP SHA-256 mismatch: "
            f"{actual_zip_sha} != {EXPECTED_ZIP_SHA256}"
        )
    print(f"Task20-D2B canonical package PASS: {output} sha256={actual_zip_sha}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
