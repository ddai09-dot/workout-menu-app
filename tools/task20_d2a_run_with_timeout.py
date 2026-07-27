#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import selectors
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


def _utc_now() -> str:
    return (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def _terminate_process_group(process: subprocess.Popen[bytes]) -> None:
    if process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=10)
        return
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        return
    process.wait(timeout=10)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run a command with streamed output and a hard timeout."
    )
    parser.add_argument("--timeout-seconds", type=int, required=True)
    parser.add_argument("--log-file", type=Path, required=True)
    parser.add_argument("--result-file", type=Path, required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    command = list(args.command)
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("a command is required after --")
    if args.timeout_seconds <= 0:
        parser.error("--timeout-seconds must be positive")

    args.log_file.parent.mkdir(parents=True, exist_ok=True)
    args.result_file.parent.mkdir(parents=True, exist_ok=True)

    started_at = _utc_now()
    started_monotonic = time.monotonic()
    timed_out = False
    exit_code: int | None = None

    with args.log_file.open("wb") as log_stream:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            env=os.environ.copy(),
        )
        assert process.stdout is not None
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        deadline = started_monotonic + args.timeout_seconds

        try:
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 and process.poll() is None:
                    timed_out = True
                    message = (
                        f"\nERROR: command exceeded {args.timeout_seconds} seconds; "
                        "terminating process group.\n"
                    ).encode("utf-8")
                    sys.stdout.buffer.write(message)
                    sys.stdout.buffer.flush()
                    log_stream.write(message)
                    log_stream.flush()
                    _terminate_process_group(process)

                events = selector.select(timeout=max(0.0, min(0.25, remaining)))
                for key, _ in events:
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if chunk:
                        sys.stdout.buffer.write(chunk)
                        sys.stdout.buffer.flush()
                        log_stream.write(chunk)
                        log_stream.flush()
                    else:
                        selector.unregister(key.fileobj)

                if process.poll() is not None:
                    while True:
                        chunk = process.stdout.read(65536)
                        if not chunk:
                            break
                        sys.stdout.buffer.write(chunk)
                        sys.stdout.buffer.flush()
                        log_stream.write(chunk)
                        log_stream.flush()
                    break
        finally:
            selector.close()
            if process.poll() is None:
                _terminate_process_group(process)

        exit_code = process.returncode

    finished_monotonic = time.monotonic()
    result = {
        "command": command,
        "started_at_utc": started_at,
        "finished_at_utc": _utc_now(),
        "duration_seconds": round(finished_monotonic - started_monotonic, 3),
        "timeout_seconds": args.timeout_seconds,
        "timed_out": timed_out,
        "exit_code": 124 if timed_out else exit_code,
        "log_file": str(args.log_file),
    }
    args.result_file.write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 124 if timed_out else int(exit_code or 0)


if __name__ == "__main__":
    raise SystemExit(main())
