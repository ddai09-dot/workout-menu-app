#!/usr/bin/env python3
"""Verify Task 20-C4 resolved versions after removing temporary pins."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def parse_version(value: str) -> tuple[int, ...]:
    match = re.match(r"^(\d+(?:\.\d+)*)", value)
    if match is None:
        raise SystemExit(f"Unsupported version string: {value}")
    return tuple(int(part) for part in match.group(1).split("."))


def package_version(lock_text: str, package: str) -> str:
    pattern = re.compile(
        rf"^  {re.escape(package)}:\n(?:(?:    .*\n)*)?    version: \"([^\"]+)\"$",
        re.MULTILINE,
    )
    match = pattern.search(lock_text)
    if match is None:
        raise SystemExit(f"Resolved package not found in pubspec.lock: {package}")
    return match.group(1)


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit(
            "Usage: task20_c4_verify_dependency_resolution.py "
            "<pubspec.yaml> <pubspec.lock>"
        )

    pubspec_path = Path(sys.argv[1]).resolve()
    lock_path = Path(sys.argv[2]).resolve()
    if not pubspec_path.is_file() or not lock_path.is_file():
        raise SystemExit("pubspec.yaml or pubspec.lock was not found")

    pubspec = pubspec_path.read_text(encoding="utf-8")
    if "  build_runner: ^2.15.2\n" not in pubspec:
        raise SystemExit("build_runner update constraint was not applied")
    if "  drift_dev: ^2.34.4\n" not in pubspec:
        raise SystemExit("drift_dev update constraint was not applied")
    if "  build_runner: 2.15.1\n" in pubspec or "  drift_dev: 2.34.0\n" in pubspec:
        raise SystemExit("A temporary exact dependency pin remains in pubspec.yaml")

    lock_text = lock_path.read_text(encoding="utf-8")
    resolved = {
        "build_runner": package_version(lock_text, "build_runner"),
        "drift_dev": package_version(lock_text, "drift_dev"),
    }
    minimum = {
        "build_runner": (2, 15, 2),
        "drift_dev": (2, 34, 4),
    }
    for package, value in resolved.items():
        if parse_version(value) < minimum[package]:
            raise SystemExit(
                f"{package} resolved below the trial minimum: {value} < "
                f"{'.'.join(map(str, minimum[package]))}"
            )

    result = {
        "status": "PASS",
        "task": "Task 20-C4",
        "constraints": {
            "build_runner": "^2.15.2",
            "drift_dev": "^2.34.4",
        },
        "resolved": resolved,
        "temporary_exact_pins_removed": True,
    }
    output = lock_path.parent / "build/task20_b_logs/flutter/task20_c4_dependency_result.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
