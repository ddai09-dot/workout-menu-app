#!/usr/bin/env python3
"""Finalize the v0.9.23 D2L candidate after the first exact-head matrix."""

from __future__ import annotations

import hashlib
import shutil
import stat
import sys
import tempfile
import zipfile
from pathlib import Path

INPUT_SHA256 = "0ee2baff7fab5f02dde3dc73acb7b22f61b752805d6fc41369cf5c7ae684f2ea"
OUTPUT_SHA256 = "af20274c36f59a3f50106ddb1369f46161ed25385e0d8120375d934694e7a687"
EXPECTED_PUBSPEC_SHA256 = "243a2ad8e6d3afd291046523a23a8d87b32f7683b8217d8d139c68a7183a2c28"
EXPECTED_TREE_HASHES = {
    "runtime": "9813fd38c2588305c21d426a08771f2c581ca5421b33fe04c0a54be5f070358a",
    "product_lib": "ddae1f6f44b588c9883d5adb12811bc41dc0f6860370d19738da2cc98f6b9428",
    "tests": "878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5",
    "schema": "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af",
    "assets": "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe",
}
EXCLUDED = {"build", ".dart_tool"}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if text.count(old) != 1:
        raise SystemExit(f"expected exactly one marker in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def package_files(root: Path) -> list[str]:
    return sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
        and path.relative_to(root).parts[0] not in EXCLUDED
        and "__pycache__" not in path.relative_to(root).parts
    )


def tree_hash(root: Path, parts: list[str]) -> str:
    digest = hashlib.sha256()
    files: list[Path] = []
    for part in parts:
        path = root / part
        if path.is_dir():
            files.extend(
                item
                for item in path.rglob("*")
                if item.is_file() and "__pycache__" not in item.parts
            )
        else:
            files.append(path)
    for path in sorted(set(files), key=lambda item: item.relative_to(root).as_posix()):
        rel = path.relative_to(root).as_posix()
        digest.update(rel.encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2l_finalize_v0923_candidate.py <implementation-v0.9.23.zip>")

    candidate = Path(sys.argv[1]).resolve()
    if sha256(candidate.read_bytes()) != INPUT_SHA256:
        raise SystemExit("unexpected pre-finalization v0.9.23 candidate SHA")

    with tempfile.TemporaryDirectory(prefix="task20-d2l-finalize-v0923-") as temp_dir:
        root = Path(temp_dir) / "app"
        root.mkdir()
        with zipfile.ZipFile(candidate) as archive:
            archive.extractall(root)

        steps = root / "lib/features/weekly_planner/presentation/steps/weekly_planner_steps.dart"
        replace_once(
            steps,
            """          DropdownButtonFormField<String>(\n            initialValue: draft.increaseMethodCode,\n""",
            """          DropdownButtonFormField<String>(\n            isExpanded: true,\n            initialValue: draft.increaseMethodCode,\n""",
        )
        replace_once(
            steps,
            """        DropdownButtonFormField<String>(\n          initialValue: draft.splitOverrideCode ?? 'DEFAULT',\n""",
            """        DropdownButtonFormField<String>(\n          isExpanded: true,\n          initialValue: draft.splitOverrideCode ?? 'DEFAULT',\n""",
        )

        pubspec_sha = sha256((root / "pubspec.yaml").read_bytes())
        if pubspec_sha != EXPECTED_PUBSPEC_SHA256:
            raise SystemExit(f"v0.9.23 pubspec SHA mismatch: {pubspec_sha}")

        hashes = {
            "runtime": tree_hash(root, ["lib", "test"]),
            "product_lib": tree_hash(root, ["lib"]),
            "tests": tree_hash(root, ["test"]),
            "schema": tree_hash(
                root,
                ["docs/schema_v9.sqlite.sql", "docs/migrations", "lib/core/database/schema"],
            ),
            "assets": tree_hash(root, ["assets"]),
        }
        if hashes != EXPECTED_TREE_HASHES:
            raise SystemExit(f"finalized v0.9.23 tree mismatch: {hashes}")

        files = package_files(root)
        manifest = [
            line
            for line in (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8").splitlines()
            if line
        ]
        if files != manifest:
            raise SystemExit("finalized v0.9.23 FILE_MANIFEST mismatch")

        staged = candidate.with_suffix(".finalized.zip")
        staged.unlink(missing_ok=True)
        with zipfile.ZipFile(
            staged, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
        ) as archive:
            for rel in files:
                path = root / rel
                info = zipfile.ZipInfo(rel, date_time=(2020, 1, 1, 0, 0, 0))
                info.create_system = 3
                mode = 0o755 if path.stat().st_mode & stat.S_IXUSR else 0o644
                info.external_attr = (stat.S_IFREG | mode) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                info.flag_bits |= 0x800
                archive.writestr(
                    info,
                    path.read_bytes(),
                    compress_type=zipfile.ZIP_DEFLATED,
                    compresslevel=9,
                )

        actual_sha = sha256(staged.read_bytes())
        if actual_sha != OUTPUT_SHA256:
            raise SystemExit(
                f"finalized v0.9.23 ZIP SHA mismatch: {actual_sha} != {OUTPUT_SHA256}"
            )
        staged.replace(candidate)

    print(
        "finalized v0.9.23 candidate: "
        f"sha256={OUTPUT_SHA256} runtime={EXPECTED_TREE_HASHES['runtime']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
