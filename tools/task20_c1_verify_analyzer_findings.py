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
EXPECTED_INFO_COUNT = 49
ISSUE_RE = re.compile(r"^\s*info\s+•.*•\s+([a-z0-9_]+)\s*$")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(
            "Usage: task20_c1_verify_analyzer_findings.py <flutter-analyze-log>"
        )

    log_path = Path(sys.argv[1]).resolve()
    if not log_path.is_file():
        raise SystemExit(f"Analyzer log not found: {log_path}")

    lint_names: list[str] = []
    for line in log_path.read_text(encoding="utf-8").splitlines():
        match = ISSUE_RE.match(line)
        if match:
            lint_names.append(match.group(1))

    counts = Counter(lint_names)
    remaining_targeted = {
        lint: counts[lint] for lint in sorted(TARGETED_LINTS) if counts[lint]
    }
    if remaining_targeted:
        raise SystemExit(
            "Task 20-C1 targeted analyzer findings remain: "
            + json.dumps(remaining_targeted, sort_keys=True)
        )
    if len(lint_names) != EXPECTED_INFO_COUNT:
        raise SystemExit(
            f"Expected {EXPECTED_INFO_COUNT} info findings after Task 20-C1; "
            f"found {len(lint_names)}"
        )

    result = {
        "status": "PASS",
        "task": "Task 20-C1",
        "analyzer_info_count": len(lint_names),
        "removed_categories": sorted(TARGETED_LINTS),
        "remaining_counts": dict(sorted(counts.items())),
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
