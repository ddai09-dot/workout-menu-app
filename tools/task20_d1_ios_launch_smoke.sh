#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_PATH="${1:-$ROOT/build/ios/iphonesimulator/Runner.app}"
BUNDLE_ID="${TASK20_D1_BUNDLE_ID:-jp.workoutmenu.workoutMenuApp}"
LOG_DIR="${TASK20_D1_LOG_DIR:-$ROOT/build/task20_d1_ios_launch_smoke}"
MAX_WAIT_SECONDS="${TASK20_D1_MAX_WAIT_SECONDS:-60}"
SAMPLE_INTERVAL_SECONDS="${TASK20_D1_SAMPLE_INTERVAL_SECONDS:-1}"
REQUIRED_STABLE_SAMPLES="${TASK20_D1_REQUIRED_STABLE_SAMPLES:-3}"
DEVICE_FILE="$LOG_DIR/selected_devices.tsv"
RESULT_LINES="$LOG_DIR/device_results.ndjson"

mkdir -p "$LOG_DIR"
: > "$RESULT_LINES"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: iOS Simulator launch smoke requires macOS." >&2
  exit 2
fi
for command_name in xcrun python3 shasum cmp; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: ${command_name} was not found." >&2
    exit 2
  fi
done
if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: Simulator app was not found: $APP_PATH" >&2
  exit 2
fi

xcrun simctl list devices available -j > "$LOG_DIR/available_devices.json"
python3 - "$LOG_DIR/available_devices.json" "$DEVICE_FILE" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
payload = json.loads(source.read_text(encoding="utf-8"))
roles = {
    "regular": "iPhone 16 Pro",
    "compact": "iPhone SE (3rd generation)",
}


def runtime_key(identifier: str) -> tuple[int, ...]:
    match = re.search(r"iOS-(\d+(?:-\d+)*)$", identifier)
    if not match:
        return (999,)
    return tuple(int(part) for part in match.group(1).split("-"))


available: dict[str, list[dict[str, object]]] = payload.get("devices", {})
runtimes = sorted(
    (identifier for identifier in available if ".iOS-" in identifier),
    key=runtime_key,
)
selected: list[tuple[str, str, str, str]] = []
used_udids: set[str] = set()
for role, preferred_name in roles.items():
    match: tuple[str, str, str, str] | None = None
    for runtime in runtimes:
        for device in available.get(runtime, []):
            if not device.get("isAvailable", True):
                continue
            if device.get("name") != preferred_name:
                continue
            udid = str(device.get("udid", ""))
            if not udid or udid in used_udids:
                continue
            match = (role, udid, runtime, preferred_name)
            break
        if match:
            break
    if match is None:
        raise SystemExit(f"No available simulator found for {role}: {preferred_name}")
    selected.append(match)
    used_udids.add(match[1])

target.write_text(
    "".join("\t".join(values) + "\n" for values in selected),
    encoding="utf-8",
)
PY

declare -a BOOTED_UDIDS=()
cleanup() {
  local udid
  for udid in "${BOOTED_UDIDS[@]:-}"; do
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

run_device() {
  local role="$1" udid="$2" runtime="$3" device_name="$4"
  local device_dir="$LOG_DIR/$role"
  local command_log="$device_dir/commands.log"
  local screenshot="$device_dir/initial_screen.png"
  local launch_output app_container screenshot_sha
  mkdir -p "$device_dir"
  : > "$command_log"

  {
    echo "role=$role"
    echo "device_name=$device_name"
    echo "runtime=$runtime"
    echo "udid=$udid"
  } | tee "$device_dir/device.txt"

  xcrun simctl shutdown "$udid" >>"$command_log" 2>&1 || true
  xcrun simctl erase "$udid" >>"$command_log" 2>&1
  xcrun simctl boot "$udid" >>"$command_log" 2>&1
  BOOTED_UDIDS+=("$udid")
  xcrun simctl bootstatus "$udid" -b >>"$command_log" 2>&1
  xcrun simctl install "$udid" "$APP_PATH" >>"$command_log" 2>&1
  app_container="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" app)"
  test -d "$app_container"
  printf '%s\n' "$app_container" > "$device_dir/app_container.txt"

  launch_output="$(xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" 2>&1)"
  printf '%s\n' "$launch_output" | tee "$device_dir/launch.txt" >>"$command_log"
  if [[ "$launch_output" != "$BUNDLE_ID:"* ]]; then
    echo "ERROR: Unexpected launch output for $role: $launch_output" >&2
    return 1
  fi

  local previous_sample="$device_dir/readiness_previous.png"
  local current_sample="$device_dir/readiness_current.png"
  local first_sample="$device_dir/first_sample.png"
  local started_epoch elapsed stable_transitions=0 attempt=0
  local required_transitions=$((REQUIRED_STABLE_SAMPLES - 1))
  if (( REQUIRED_STABLE_SAMPLES < 2 )); then
    echo "ERROR: TASK20_D1_REQUIRED_STABLE_SAMPLES must be at least 2." >&2
    return 2
  fi
  rm -f "$previous_sample" "$current_sample" "$first_sample" "$screenshot"
  started_epoch="$(date +%s)"
  while true; do
    attempt=$((attempt + 1))
    xcrun simctl io "$udid" screenshot "$current_sample" >>"$command_log" 2>&1
    test -s "$current_sample"
    if (( attempt == 1 )); then
      cp "$current_sample" "$first_sample"
    fi
    if [[ -f "$previous_sample" ]] && cmp -s "$previous_sample" "$current_sample"; then
      stable_transitions=$((stable_transitions + 1))
    else
      stable_transitions=0
    fi
    elapsed=$(( $(date +%s) - started_epoch ))
    if (( stable_transitions >= required_transitions )); then
      cp "$current_sample" "$screenshot"
      break
    fi
    if (( elapsed >= MAX_WAIT_SECONDS )); then
      cp "$current_sample" "$screenshot"
      echo "ERROR: Screen did not become stable within ${MAX_WAIT_SECONDS}s for $role." >&2
      return 1
    fi
    mv "$current_sample" "$previous_sample"
    sleep "$SAMPLE_INTERVAL_SECONDS"
  done
  rm -f "$previous_sample" "$current_sample"

  screenshot_sha="$(shasum -a 256 "$screenshot" | awk '{print $1}')"
  printf '%s  %s\n' "$screenshot_sha" "$(basename "$screenshot")" > "$device_dir/screenshot.sha256"
  printf '%s\n' "$elapsed" > "$device_dir/readiness_seconds.txt"

  # Successful termination after readiness proves that the process was still
  # alive when the stable screenshot was captured.
  xcrun simctl terminate "$udid" "$BUNDLE_ID" >>"$command_log" 2>&1

  ROLE="$role" UDID="$udid" RUNTIME="$runtime" DEVICE_NAME="$device_name" \
  SCREENSHOT="$screenshot" SCREENSHOT_SHA="$screenshot_sha" \
  APP_CONTAINER="$app_container" RESULT_LINES="$RESULT_LINES" \
  READINESS_SECONDS="$elapsed" STABLE_SAMPLES="$REQUIRED_STABLE_SAMPLES" python3 - <<'PY'
import json
import os
from pathlib import Path

payload = {
    "role": os.environ["ROLE"],
    "device_name": os.environ["DEVICE_NAME"],
    "runtime": os.environ["RUNTIME"],
    "udid": os.environ["UDID"],
    "app_container": os.environ["APP_CONTAINER"],
    "screenshot": os.environ["SCREENSHOT"],
    "screenshot_sha256": os.environ["SCREENSHOT_SHA"],
    "launch_alive_after_readiness": True,
    "screen_stable": True,
    "stable_screen_wait_seconds": int(os.environ["READINESS_SECONDS"]),
    "required_stable_samples": int(os.environ["STABLE_SAMPLES"]),
    "status": "PASS",
}
with Path(os.environ["RESULT_LINES"]).open("a", encoding="utf-8") as stream:
    stream.write(json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n")
PY

  xcrun simctl shutdown "$udid" >>"$command_log" 2>&1
}

while IFS=$'\t' read -r role udid runtime device_name; do
  run_device "$role" "$udid" "$runtime" "$device_name"
done < "$DEVICE_FILE"

BUNDLE_ID="$BUNDLE_ID" APP_PATH="$APP_PATH" MAX_WAIT_SECONDS="$MAX_WAIT_SECONDS" \
SAMPLE_INTERVAL_SECONDS="$SAMPLE_INTERVAL_SECONDS" REQUIRED_STABLE_SAMPLES="$REQUIRED_STABLE_SAMPLES" \
RESULT_LINES="$RESULT_LINES" LOG_DIR="$LOG_DIR" python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

lines = Path(os.environ["RESULT_LINES"]).read_text(encoding="utf-8").splitlines()
devices = [json.loads(line) for line in lines if line.strip()]
if len(devices) != 2 or any(item.get("status") != "PASS" for item in devices):
    raise SystemExit("Expected two passing simulator launch results")
result = {
    "task": "Task 20-D1 iOS Simulator launch smoke",
    "status": "PASS",
    "bundle_id": os.environ["BUNDLE_ID"],
    "app_path": os.environ["APP_PATH"],
    "max_wait_seconds": int(os.environ["MAX_WAIT_SECONDS"]),
    "sample_interval_seconds": int(os.environ["SAMPLE_INTERVAL_SECONDS"]),
    "required_stable_samples": int(os.environ["REQUIRED_STABLE_SAMPLES"]),
    "finished_at_utc": datetime.now(timezone.utc)
    .replace(microsecond=0)
    .isoformat()
    .replace("+00:00", "Z"),
    "devices": devices,
    "manual_core_flow_verified": False,
    "physical_device_verified": False,
    "accessibility_verified": False,
}
Path(os.environ["LOG_DIR"], "result.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, ensure_ascii=False, sort_keys=True))
PY

echo "Task 20-D1 iOS Simulator launch smoke passed."
