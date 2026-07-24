#!/usr/bin/env python3
"""Build the Task 20-C5 v0.9.2 canonical package from v0.9.1."""
from __future__ import annotations
import base64, gzip, hashlib, shutil, subprocess, sys, zipfile
from pathlib import Path

EXPECTED_SHA256 = "322aa363bbd3f2cccc8c615e56975c4c4c5c0ab7b1ac772c4eae20a4536099f3"
EXCLUDED_TOP_LEVEL = {"build", ".dart_tool"}


def fail(message: str) -> None:
    raise SystemExit(message)


def load_patch() -> bytes:
    parts = sorted(Path(__file__).resolve().parent.glob("task20_c5_patch_payload.part*"))
    if len(parts) != 4:
        fail(f"Expected 4 Task20-C5 patch payload parts; found {len(parts)}")
    encoded = "".join(path.read_text(encoding="ascii") for path in parts)
    try:
        return gzip.decompress(base64.b85decode(encoded.encode("ascii")))
    except Exception as exc:
        fail(f"Task20-C5 patch payload decode failed: {exc}")


def reorder_ios_validation(root: Path) -> None:
    """Run canonical source verification before flutter create mutates iOS files."""
    path = root / "tools/run_task20_b_ios_simulator.sh"
    text = path.read_text(encoding="utf-8")
    create_start = text.find('GENERATED_WIDGET_TEST_PATH="test/widget_test.dart"')
    common_start = text.find('COMMON_LOG_DIR="$LOG_DIR/flutter_checks"', create_start)
    build_start = text.find(
        'run_logged_step "flutter_build_ios_simulator"', common_start
    )
    if min(create_start, common_start, build_start) < 0:
        fail("Expected Task20-B iOS validation blocks were not found")
    create_chunk = text[create_start:common_start]
    common_chunk = text[common_start:build_start]
    if text.count('COMMON_LOG_DIR="$LOG_DIR/flutter_checks"') != 1:
        fail("Expected exactly one common Flutter-check block")
    path.write_text(
        text[:create_start] + common_chunk + "\n" + create_chunk + text[build_start:],
        encoding="utf-8",
    )


def write_deterministic_zip(root: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(root.rglob("*")):
            if not path.is_file():
                continue
            relative = path.relative_to(root)
            if relative.parts and relative.parts[0] in EXCLUDED_TOP_LEVEL:
                continue
            info = zipfile.ZipInfo(
                relative.as_posix(), date_time=(2026, 7, 24, 0, 0, 0)
            )
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info._compresslevel = 9
            info.external_attr = (path.stat().st_mode & 0o777) << 16
            archive.writestr(info, path.read_bytes())


def main() -> int:
    if len(sys.argv) != 3:
        fail("Usage: task20_c5_build_canonical_v092.py <v0.9.1-root> <output-zip>")
    root, output = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
    pubspec = root / "pubspec.yaml"
    if not pubspec.is_file() or "version: 0.9.1+19\n" not in pubspec.read_text(
        encoding="utf-8"
    ):
        fail("Input is not the v0.9.1+19 canonical package")
    completed = subprocess.run(
        ["patch", "-p1", "--batch", "--forward", "--no-backup-if-mismatch"],
        cwd=root,
        input=load_patch(),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if completed.returncode != 0:
        sys.stdout.buffer.write(completed.stdout)
        fail(f"Canonical integration patch failed with exit code {completed.returncode}")
    if "version: 0.9.2+20\n" not in pubspec.read_text(encoding="utf-8"):
        fail("Canonical integration did not produce v0.9.2+20")
    reorder_ios_validation(root)
    shutil.rmtree(root / "build", ignore_errors=True)
    shutil.rmtree(root / ".dart_tool", ignore_errors=True)
    write_deterministic_zip(root, output)
    actual = hashlib.sha256(output.read_bytes()).hexdigest()
    if actual != EXPECTED_SHA256:
        fail(f"Canonical ZIP SHA-256 mismatch: {actual} != {EXPECTED_SHA256}")
    print(f"Task 20-C5 canonical package PASS: {output} sha256={actual}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
