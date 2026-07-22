#!/usr/bin/env python3
"""Patch the v0.9.1 Flutter SDK installer to preserve macOS ZIP modes.

Python's ZipFile.extractall does not restore Unix executable bits or symlinks.
The official Flutter macOS archive carries those attributes, so the installer
must reproduce them before invoking flutter.
"""

from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(
            "Usage: task20_b2_fix_flutter_zip_permissions.py <extracted-app-root>"
        )
    root = Path(sys.argv[1]).resolve()
    path = root / "tools/install_pinned_flutter_sdk.py"
    text = path.read_text(encoding="utf-8")
    source = '''        elif archive_path.name.endswith(".zip"):
            with zipfile.ZipFile(archive_path) as archive:
                for member in archive.infolist():
                    _safe_destination(staging, member.filename)
                archive.extractall(staging)
'''
    target = '''        elif archive_path.name.endswith(".zip"):
            with zipfile.ZipFile(archive_path) as archive:
                staging_root = staging.resolve()
                for member in archive.infolist():
                    target_path = _safe_destination(staging, member.filename)
                    unix_mode = member.external_attr >> 16
                    if stat.S_ISLNK(unix_mode):
                        link_target = archive.read(member).decode("utf-8")
                        if Path(link_target).is_absolute():
                            raise ValueError(
                                f"Unsafe absolute symlink target: {member.filename} -> {link_target}"
                            )
                        resolved_target = (target_path.parent / link_target).resolve()
                        if (
                            staging_root not in resolved_target.parents
                            and resolved_target != staging_root
                        ):
                            raise ValueError(
                                f"Unsafe symlink target: {member.filename} -> {link_target}"
                            )
                        target_path.parent.mkdir(parents=True, exist_ok=True)
                        target_path.symlink_to(link_target)
                        continue
                    archive.extract(member, staging)
                    permission_bits = stat.S_IMODE(unix_mode)
                    if permission_bits and target_path.exists():
                        target_path.chmod(permission_bits)
            # Defensive fallback for archives whose metadata omit mode bits.
            for script in (staging / "flutter").rglob("*.sh"):
                _ensure_executable(script)
'''
    count = text.count(source)
    if count != 1:
        raise SystemExit(
            f"Expected exactly one macOS ZIP extraction block in {path}; found {count}"
        )
    path.write_text(text.replace(source, target), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
