#!/usr/bin/env python3
"""Evaluate removal of the Task 20-B2 dependency pins."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def replace_once(path: Path, source: str, target: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(source)
    if count != 1:
        raise SystemExit(
            f"Expected exactly one match in {path}: {source!r}; found {count}"
        )
    path.write_text(text.replace(source, target), encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(
            "Usage: task20_c4_try_dependency_updates.py <extracted-app-root>"
        )
    root = Path(sys.argv[1]).resolve()
    pubspec = root / "pubspec.yaml"
    if not pubspec.is_file():
        raise SystemExit(f"pubspec.yaml not found under {root}")

    replace_once(pubspec, "  build_runner: 2.15.1\n", "  build_runner: ^2.15.2\n")
    replace_once(pubspec, "  drift_dev: 2.34.0\n", "  drift_dev: ^2.34.4\n")

    evidence_dir = root / "build/task20_b_logs/flutter"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    evidence = {
        "status": "APPLIED",
        "task": "Task 20-C4",
        "purpose": "Evaluate removal of temporary dependency pins",
        "previous": {
            "build_runner": "2.15.1",
            "drift_dev": "2.34.0",
        },
        "requested": {
            "build_runner": "^2.15.2",
            "drift_dev": "^2.34.4",
        },
        "merge_policy": (
            "Merge only if dependency resolution, Drift generation, strict analyze, "
            "Flutter tests, and iOS Simulator build all pass without unreviewed "
            "generated-source changes."
        ),
        "functionality_removed": False,
    }
    (evidence_dir / "task20_c4_dependency_trial.json").write_text(
        json.dumps(evidence, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
