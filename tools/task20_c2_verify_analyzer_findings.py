#!/usr/bin/env python3
"""Verify Task 20-C2 removed deprecated APIs without regressing Task 20-C1."""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

TARGETED_LINTS = {
    "deprecated_member_use",
    "discarded_futures",
    "unawaited_futures",
    "use_build_context_synchronously",
}
EXPECTED_UNIQUE_INFO_COUNT = 33
ISSUE_RE = re.compile(r"^\s*info\s+•.*•\s+([a-z0-9_]+)\s*$")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(
            "Usage: task20_c2_verify_analyzer_findings.py <flutter-analyze-log>"
        )

    log_path = Path(sys.argv[1]).resolve()
    if not log_path.is_file():
        raise SystemExit(f"Analyzer log not found: {log_path}")

    raw_findings: list[tuple[str, str]] = []
    for line in log_path.read_text(encoding="utf-8").splitlines():
        match = ISSUE_RE.match(line)
        if match:
            raw_findings.append((line.strip(), match.group(1)))

    unique_by_line: dict[str, str] = {}
    for line, lint in raw_findings:
        unique_by_line.setdefault(line, lint)

    unique_lints = list(unique_by_line.values())
    counts = Counter(unique_lints)
    remaining_targeted = {
        lint: counts[lint] for lint in sorted(TARGETED_LINTS) if counts[lint]
    }
    if remaining_targeted:
        raise SystemExit(
            "Task 20-C2 targeted analyzer findings remain: "
            + json.dumps(remaining_targeted, sort_keys=True)
        )
    if len(unique_lints) != EXPECTED_UNIQUE_INFO_COUNT:
        raise SystemExit(
            f"Expected {EXPECTED_UNIQUE_INFO_COUNT} unique info findings after "
            f"Task 20-C2; found {len(unique_lints)} "
            f"(raw {len(raw_findings)})"
        )

    result = {
        "status": "PASS",
        "task": "Task 20-C2",
        "raw_analyzer_info_count": len(raw_findings),
        "unique_analyzer_info_count": len(unique_lints),
        "duplicate_exact_line_count": len(raw_findings) - len(unique_lints),
        "removed_categories": sorted(TARGETED_LINTS),
        "remaining_counts": dict(sorted(counts.items())),
    }
    output_path = log_path.parent / "task20_c2_analyzer_verification.json"
    output_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
