#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
D1_DEVICE_FILE="${TASK20_D1_DEVICE_FILE:-$APP_DIR/build/task20_d1_ios_launch_smoke/selected_devices.tsv}"
LOG_DIR="${TASK20_D2D_LOG_DIR:-$APP_DIR/build/task20_d2d_weekly_planner_resume}"
RESULT_LINES="$LOG_DIR/device_results.ndjson"
DRIVE_TIMEOUT_SECONDS="${TASK20_D2D_DRIVE_TIMEOUT_SECONDS:-720}"
MAX_STARTUP_ATTEMPTS="${TASK20_D2D_MAX_STARTUP_ATTEMPTS:-2}"
APP_BUNDLE="$APP_DIR/build/ios/iphonesimulator/Runner.app"
mkdir -p "$LOG_DIR"
: > "$RESULT_LINES"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Task 20-D2D iOS UI acceptance requires macOS." >&2
  exit 2
fi
for command_name in flutter dart xcrun python3 shasum plutil; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "ERROR: $command_name was not found." >&2
    exit 2
  }
done
if [[ ! -f "$D1_DEVICE_FILE" ]]; then
  echo "ERROR: D1 selected device file was not found: $D1_DEVICE_FILE" >&2
  exit 2
fi
if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "ERROR: iOS Simulator app bundle was not found: $APP_BUNDLE" >&2
  exit 2
fi
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$APP_BUNDLE/Info.plist")"
if [[ -z "$BUNDLE_ID" ]]; then
  echo "ERROR: CFBundleIdentifier is empty." >&2
  exit 2
fi

cp "$APP_DIR/pubspec.yaml" "$LOG_DIR/canonical_pubspec.yaml"
if [[ -f "$APP_DIR/pubspec.lock" ]]; then
  cp "$APP_DIR/pubspec.lock" "$LOG_DIR/canonical_pubspec.lock"
fi
printf '%s\n' "$BUNDLE_ID" > "$LOG_DIR/bundle_id.txt"

python3 "$ROOT/tools/task20_d2d_prepare_ui_acceptance.py" "$APP_DIR"
(
  set -x
  cd "$APP_DIR"
  flutter pub get
  dart format integration_test test_driver
  flutter analyze integration_test
  flutter analyze test_driver
) 2>&1 | tee "$LOG_DIR/overlay_preflight.log"

cleanup() {
  while IFS=$'\t' read -r role udid runtime device_name; do
    [[ -n "${udid:-}" ]] || continue
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  done < "$D1_DEVICE_FILE"
}
trap cleanup EXIT

capture_simulator_diagnostics() {
  local udid="$1"
  local destination="$2"
  mkdir -p "$destination"
  xcrun simctl list > "$destination/simctl_list.txt" 2>&1 || true
  xcrun simctl listapps "$udid" > "$destination/listapps.txt" 2>&1 || true
  xcrun simctl spawn "$udid" log show \
    --style compact \
    --last 20m \
    --predicate 'process == "Runner" OR eventMessage CONTAINS[c] "Runner" OR eventMessage CONTAINS[c] "workout"' \
    > "$destination/simulator_recent.log" 2>&1 || true
}

run_drive_phase() {
  local udid="$1"
  local screenshot_dir="$2"
  local target="$3"
  local log_file="$4"
  local result_file="$5"
  (
    cd "$APP_DIR"
    TASK20_D2_SCREENSHOT_DIR="$screenshot_dir" \
      python3 "$ROOT/tools/task20_d2a_run_with_timeout.py" \
        --timeout-seconds "$DRIVE_TIMEOUT_SECONDS" \
        --log-file "$log_file" \
        --result-file "$result_file" \
        -- \
        flutter drive \
          --keep-app-running \
          --no-dds \
          --driver=test_driver/task20_d2d_driver.dart \
          --target="$target" \
          -d "$udid"
  )
}

is_retryable_startup_failure() {
  local log_file="$1"
  local screenshot_pattern="$2"
  local screenshot_dir="$3"
  [[ -z "$(find "$screenshot_dir" -type f -name "$screenshot_pattern" -print -quit)" ]] && \
    grep -Eqi \
      'Application failed to start|Error waiting for a debug connection|log reader failed unexpectedly|Unable to launch|Failed to start' \
      "$log_file"
}

while IFS=$'\t' read -r role udid runtime device_name; do
  device_dir="$LOG_DIR/$role"
  screenshot_dir="$device_dir/screenshots"
  mkdir -p "$device_dir"
  rm -rf "$screenshot_dir"
  mkdir -p "$screenshot_dir"

  echo "Task 20-D2D starting: role=$role device=$device_name runtime=$runtime udid=$udid"

  final_code=1
  successful_attempt=0
  attempted_count=0
  retryable_startup_failure=false
  phase1_result_file=""
  phase2_result_file=""
  process_log=""

  for attempt in $(seq 1 "$MAX_STARTUP_ATTEMPTS"); do
    attempted_count="$attempt"
    attempt_dir="$device_dir/attempt_$attempt"
    attempt_screenshot_dir="$attempt_dir/screenshots"
    diagnostics_dir="$attempt_dir/simulator_diagnostics"
    phase1_log="$attempt_dir/phase1_flutter_drive.log"
    phase2_log="$attempt_dir/phase2_flutter_drive.log"
    phase1_result_file="$attempt_dir/phase1_flutter_drive_result.json"
    phase2_result_file="$attempt_dir/phase2_flutter_drive_result.json"
    process_log="$attempt_dir/process_restart.log"
    rm -rf "$attempt_dir"
    mkdir -p "$attempt_screenshot_dir"

    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl erase "$udid"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b

    set +e
    run_drive_phase \
      "$udid" \
      "$attempt_screenshot_dir" \
      integration_test/task20_d2d_weekly_planner_prepare_test.dart \
      "$phase1_log" \
      "$phase1_result_file"
    phase1_code="$?"
    set -e

    if [[ "$phase1_code" -ne 0 ]]; then
      capture_simulator_diagnostics "$udid" "$diagnostics_dir/phase1"
      retryable_startup_failure=false
      if is_retryable_startup_failure \
        "$phase1_log" 'D2D_01_adjustment_saved.png' "$attempt_screenshot_dir"; then
        retryable_startup_failure=true
      fi
      if [[ "$retryable_startup_failure" == true && "$attempt" -lt "$MAX_STARTUP_ATTEMPTS" ]]; then
        echo "Task 20-D2D phase 1 startup infrastructure failure; retrying clean attempt."
        continue
      fi
      final_code="$phase1_code"
      break
    fi

    if [[ ! -s "$attempt_screenshot_dir/D2D_01_adjustment_saved.png" ]]; then
      echo "ERROR: Task 20-D2D phase 1 screenshot is missing." >&2
      final_code=1
      break
    fi

    {
      echo "bundle_id=$BUNDLE_ID"
      echo "phase1_keep_app_running=true"
      if xcrun simctl terminate "$udid" "$BUNDLE_ID"; then
        echo "os_level_terminate=PASS"
      else
        echo "os_level_terminate=FAIL"
      fi
    } > "$process_log" 2>&1

    if ! grep -qx 'os_level_terminate=PASS' "$process_log"; then
      echo "ERROR: OS-level process termination was not verified for $role." >&2
      capture_simulator_diagnostics "$udid" "$diagnostics_dir/process_restart"
      final_code=1
      break
    fi

    set +e
    run_drive_phase \
      "$udid" \
      "$attempt_screenshot_dir" \
      integration_test/task20_d2d_weekly_planner_verify_test.dart \
      "$phase2_log" \
      "$phase2_result_file"
    phase2_code="$?"
    set -e

    if [[ "$phase2_code" -ne 0 ]]; then
      capture_simulator_diagnostics "$udid" "$diagnostics_dir/phase2"
      retryable_startup_failure=false
      if is_retryable_startup_failure \
        "$phase2_log" 'D2D_0[2-6]_*.png' "$attempt_screenshot_dir"; then
        retryable_startup_failure=true
      fi
      if [[ "$retryable_startup_failure" == true && "$attempt" -lt "$MAX_STARTUP_ATTEMPTS" ]]; then
        echo "Task 20-D2D phase 2 startup infrastructure failure; retrying clean two-phase attempt."
        continue
      fi
      final_code="$phase2_code"
      break
    fi

    cp -R "$attempt_screenshot_dir/." "$screenshot_dir/"
    successful_attempt="$attempt"
    final_code=0
    retryable_startup_failure=false
    break
  done

  if [[ "$final_code" -ne 0 ]]; then
    ROLE="$role" DEVICE_NAME="$device_name" RUNTIME="$runtime" UDID="$udid" \
      EXIT_CODE="$final_code" RESULT_LINES="$RESULT_LINES" \
      PHASE1_RESULT_FILE="$phase1_result_file" PHASE2_RESULT_FILE="$phase2_result_file" \
      PROCESS_LOG="$process_log" ATTEMPTS="$attempted_count" \
      RETRYABLE_STARTUP_FAILURE="$retryable_startup_failure" python3 - <<'PY'
import json
import os
from pathlib import Path


def load(path: str) -> dict:
    file = Path(path)
    return json.loads(file.read_text(encoding="utf-8")) if file.is_file() else {}


process_log = Path(os.environ["PROCESS_LOG"])
payload = {
    "role": os.environ["ROLE"],
    "device_name": os.environ["DEVICE_NAME"],
    "runtime": os.environ["RUNTIME"],
    "udid": os.environ["UDID"],
    "status": "FAIL",
    "exit_code": int(os.environ["EXIT_CODE"]),
    "attempts": int(os.environ["ATTEMPTS"]),
    "retryable_startup_failure": os.environ["RETRYABLE_STARTUP_FAILURE"] == "true",
    "phase1": load(os.environ["PHASE1_RESULT_FILE"]),
    "phase2": load(os.environ["PHASE2_RESULT_FILE"]),
    "process_restart_log": process_log.read_text(encoding="utf-8") if process_log.is_file() else "",
}
with Path(os.environ["RESULT_LINES"]).open("a", encoding="utf-8") as stream:
    stream.write(json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n")
PY
    exit "$final_code"
  fi

  for screenshot_name in \
    D2D_01_adjustment_saved.png \
    D2D_02_menu_resume_card.png \
    D2D_03_adjustment_restored.png \
    D2D_04_review_generated.png \
    D2D_05_revise_schedule_preserved.png \
    D2D_06_final_menu.png; do
    test -s "$screenshot_dir/$screenshot_name"
  done
  shasum -a 256 "$screenshot_dir"/*.png > "$device_dir/screenshots.sha256"

  ROLE="$role" DEVICE_NAME="$device_name" RUNTIME="$runtime" UDID="$udid" \
    SCREENSHOT_DIR="$screenshot_dir" RESULT_LINES="$RESULT_LINES" \
    PHASE1_RESULT_FILE="$phase1_result_file" PHASE2_RESULT_FILE="$phase2_result_file" \
    PROCESS_LOG="$process_log" ATTEMPTS="$successful_attempt" python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path


def load(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


process_text = Path(os.environ["PROCESS_LOG"]).read_text(encoding="utf-8")
if "phase1_keep_app_running=true" not in process_text:
    raise SystemExit("phase 1 keep-app-running evidence is missing")
if "os_level_terminate=PASS" not in process_text:
    raise SystemExit("OS-level termination evidence is missing")

screenshots = []
for path in sorted(Path(os.environ["SCREENSHOT_DIR"]).glob("*.png")):
    screenshots.append({
        "name": path.name,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "size_bytes": path.stat().st_size,
    })
payload = {
    "role": os.environ["ROLE"],
    "device_name": os.environ["DEVICE_NAME"],
    "runtime": os.environ["RUNTIME"],
    "udid": os.environ["UDID"],
    "status": "PASS",
    "attempts": int(os.environ["ATTEMPTS"]),
    "phase1_keep_app_running": True,
    "os_level_process_termination_verified": True,
    "phase1": load(os.environ["PHASE1_RESULT_FILE"]),
    "phase2": load(os.environ["PHASE2_RESULT_FILE"]),
    "screenshots": screenshots,
}
with Path(os.environ["RESULT_LINES"]).open("a", encoding="utf-8") as stream:
    stream.write(json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n")
PY

  xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl shutdown "$udid"
done < "$D1_DEVICE_FILE"

APP_DIR="$APP_DIR" LOG_DIR="$LOG_DIR" RESULT_LINES="$RESULT_LINES" \
  MAX_STARTUP_ATTEMPTS="$MAX_STARTUP_ATTEMPTS" BUNDLE_ID="$BUNDLE_ID" python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

lines = Path(os.environ["RESULT_LINES"]).read_text(encoding="utf-8").splitlines()
devices = [json.loads(line) for line in lines if line.strip()]
if len(devices) != 2 or any(item.get("status") != "PASS" for item in devices):
    raise SystemExit("Expected two passing Task 20-D2D device results")
if any(len(item.get("screenshots", [])) != 6 for item in devices):
    raise SystemExit("Expected six Task 20-D2D screenshots per device")
result = {
    "task": "Task 20-D2D weekly planner resume and finalize acceptance",
    "status": "PASS",
    "finished_at_utc": datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z"),
    "app_directory": os.environ["APP_DIR"],
    "bundle_id": os.environ["BUNDLE_ID"],
    "devices": devices,
    "verified_cases": ["D2-04-partial", "D2-08-partial", "D2-10-partial"],
    "verified_behaviors": [
        "first-week empty menu state",
        "weekly schedule and condition entry",
        "weekly planner draft saved at adjustment step",
        "application kept running after phase 1",
        "OS-level process termination between phases",
        "in-progress menu card after relaunch",
        "current weekly planner step and answers restored",
        "condition revision preserves schedule and answers",
        "rule-based weekly menu generation",
        "weekly menu finalization and menu display",
    ],
    "excluded_from_full_pass": [
        "previous-week reflection with completed history",
        "proof that finalized historical records are never rewritten",
    ],
    "startup_retry_policy": {
        "maximum_attempts": int(os.environ["MAX_STARTUP_ATTEMPTS"]),
        "retry_scope": "phase-specific pre-test debug launch failures with no phase screenshot only",
        "test_or_app_failures_retried": False,
    },
    "task20_d2_fully_verified": False,
    "physical_device_verified": False,
    "native_accessibility_verified": False,
}
Path(os.environ["LOG_DIR"], "result.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, ensure_ascii=False, sort_keys=True))
PY

echo "Task 20-D2D weekly planner resume acceptance passed."
