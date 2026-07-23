#!/usr/bin/env python3
"""Verify Task 20-C3 restored a clean, strict analyzer gate."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ISSUE_RE = re.compile(r"^\s*(error|warning|info)\s+•")


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit(
            "Usage: task20_c3_verify_analyzer_clean.py "
            "<flutter-analyze-log> <flutter-runner-script>"
        )

    log_path = Path(sys.argv[1]).resolve()
    runner_path = Path(sys.argv[2]).resolve()
    if not log_path.is_file():
        raise SystemExit(f"Analyzer log not found: {log_path}")
    if not runner_path.is_file():
        raise SystemExit(f"Flutter runner not found: {runner_path}")

    findings = [
        line.strip()
        for line in log_path.read_text(encoding="utf-8").splitlines()
        if ISSUE_RE.match(line)
    ]
    if findings:
        raise SystemExit(
            "Task 20-C3 analyzer findings remain: "
            + json.dumps(findings, ensure_ascii=False)
        )

    runner_text = runner_path.read_text(encoding="utf-8")
    if "flutter analyze --no-fatal-infos" in runner_text:
        raise SystemExit("Task 20-C3 strict analyzer gate was not restored")
    if '"flutter_analyze" "flutter_analyze.log" flutter analyze\n' not in runner_text:
        raise SystemExit("Expected strict flutter analyze command was not found")

    result = {
        "status": "PASS",
        "task": "Task 20-C3",
        "analyzer_finding_count": 0,
        "strict_analyzer_command": "flutter analyze",
        "no_fatal_infos_present": False,
    }
    output_path = log_path.parent / "task20_c3_analyzer_verification.json"
    output_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
