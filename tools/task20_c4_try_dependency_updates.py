#!/usr/bin/env python3
"""Evaluate replacing exact compatibility pins with safe constraints."""

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

    text = pubspec.read_text(encoding="utf-8")
    if "  build_runner: 2.15.1\n" not in text:
        raise SystemExit("Required build_runner 2.15.1 compatibility pin is missing")
    replace_once(pubspec, "  drift_dev: 2.34.0\n", "  drift_dev: ^2.34.0\n")

    evidence_dir = root / "build/task20_b_logs/flutter"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    evidence = {
        "status": "APPLIED",
        "task": "Task 20-C4",
        "purpose": "Evaluate replacing the drift_dev exact pin with a compatible range",
        "attempt_1": {
            "result": "FAIL",
            "build_runner_requested": "^2.15.2",
            "drift_dev_requested": "^2.34.4",
            "stopped_step": "flutter_pub_get",
            "exit_code": 1,
            "cause": (
                "build_runner >=2.15.2 requires meta ^1.18.3, while Flutter "
                "3.44.6 pins meta 1.18.0"
            ),
            "decision": "retain build_runner 2.15.1 exact pin",
        },
        "attempt_2": {
            "result": "FAIL",
            "build_runner": "2.15.1",
            "drift_dev_requested": "^2.34.4",
            "stopped_step": "flutter_pub_get",
            "exit_code": 1,
            "cause": (
                "drift_dev >=2.34.1+1 requires analyzer ^13.0.0, which is "
                "incompatible with the current Flutter Test, Supabase, and "
                "Riverpod dependency graph"
            ),
            "decision": "do not require drift_dev 2.34.4 or later",
        },
        "attempt_3": {
            "build_runner": "2.15.1",
            "drift_dev_previous": "2.34.0",
            "drift_dev_requested": "^2.34.0",
            "expected_resolution": "2.34.0 under Flutter 3.44.6",
        },
        "merge_policy": (
            "Merge only if dependency resolution selects drift_dev 2.34.0 and "
            "Drift generation, strict analyze, Flutter tests, and iOS Simulator "
            "build all pass without unreviewed generated-source changes."
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
