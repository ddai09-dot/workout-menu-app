#!/usr/bin/env python3
"""Temporarily pin the accepted drift_dev version while CI-only UI overlays run."""

from __future__ import annotations

import json
import sys
from pathlib import Path

RANGE = "  drift_dev: ^2.34.0\n"
PIN = "  drift_dev: 2.34.0\n"
VERSION = "version: 0.9.22+40\n"
BUILD_RUNNER = "  build_runner: 2.15.1\n"


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] not in {"pin", "restore"}:
        raise SystemExit("Usage: task20_c4_transient_pin.py <pin|restore> <pubspec.yaml>")

    mode = sys.argv[1]
    path = Path(sys.argv[2]).resolve()
    text = path.read_text(encoding="utf-8")

    if VERSION not in text:
        raise SystemExit("Task20 C4 transient pin requires v0.9.22+40")
    if BUILD_RUNNER not in text:
        raise SystemExit("Task20 C4 transient pin requires build_runner 2.15.1")

    range_count = text.count(RANGE)
    pin_count = text.count(PIN)

    if mode == "pin":
        if range_count != 1 or pin_count != 0:
            raise SystemExit(
                f"Unexpected drift_dev state before pin: range={range_count} pin={pin_count}"
            )
        text = text.replace(RANGE, PIN, 1)
        expected = PIN
    else:
        if pin_count == 1 and range_count == 0:
            text = text.replace(PIN, RANGE, 1)
        elif range_count == 1 and pin_count == 0:
            pass
        else:
            raise SystemExit(
                f"Unexpected drift_dev state before restore: range={range_count} pin={pin_count}"
            )
        expected = RANGE

    path.write_text(text, encoding="utf-8")
    verified = path.read_text(encoding="utf-8")
    if verified.count(expected) != 1:
        raise SystemExit("Task20 C4 transient dependency state verification failed")

    print(
        json.dumps(
            {
                "status": "PASS",
                "task": "Task20 C4 transient UI-overlay dependency pin",
                "mode": mode,
                "drift_dev": "2.34.0" if mode == "pin" else "^2.34.0",
                "product_zip_changed": False,
                "product_runtime_changed": False,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
