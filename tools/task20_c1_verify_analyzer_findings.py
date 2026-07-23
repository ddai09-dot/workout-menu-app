#!/usr/bin/env python3
"""Verify Task 20-C1 removed targeted analyzer findings."""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

TARGETED_LINTS = {
    "discarded_futures",
    "unawaited_futures",
    "use_build_context_synchronously",
}
EXPECTED_UNIQUE_INFO_COUNT = 49
ISSUE_RE = re.compile(r"^\s*info\s+•.*•\s+([a-z0-9_]+)\s*$")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(
            "Usage: task20_c1_verify_analyzer_findings.py <flutter-analyze-log>"
        )

    log_path = Path(sys.argv[1]).resolve()
    if not log_path.is_file():
        raise SystemExit(f"Analyzer log not found: {log_path}")

    raw_findings: list[tuple[str, str]] = []
    for line in log_path.read_text(encoding="utf-8").splitlines():
        match = ISSUE_RE.match(line)
        if match:
            raw_findings.append((line.strip(), match.group(1)))

    unique_findings: list[tuple[str, str]] = []
    seen_lines: set[str] = set()
    for normalized_line, lint_name in raw_findings:
        if normalized_line in seen_lines:
            continue
        seen_lines.add(normalized_line)
        unique_findings.append((normalized_line, lint_name))

    counts = Counter(lint_name for _, lint_name in unique_findings)
    remaining_targeted = {
        lint: counts[lint] for lint in sorted(TARGETED_LINTS) if counts[lint]
    }
    if remaining_targeted:
        raise SystemExit(
            "Task 20-C1 targeted analyzer findings remain: "
            + json.dumps(remaining_targeted, sort_keys=True)
        )
    if len(unique_findings) != EXPECTED_UNIQUE_INFO_COUNT:
        raise SystemExit(
            f"Expected {EXPECTED_UNIQUE_INFO_COUNT} unique info findings after "
            f"Task 20-C1; found {len(unique_findings)} "
            f"({len(raw_findings)} raw info lines)"
        )

    result = {
        "status": "PASS",
        "task": "Task 20-C1",
        "analyzer_unique_info_count": len(unique_findings),
        "analyzer_raw_info_line_count": len(raw_findings),
        "duplicate_info_line_count": len(raw_findings) - len(unique_findings),
        "removed_categories": sorted(TARGETED_LINTS),
        "remaining_unique_counts": dict(sorted(counts.items())),
    }
    output_path = log_path.parent / "task20_c1_analyzer_verification.json"
    output_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
