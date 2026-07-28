#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
D1_DEVICE_FILE="${TASK20_D1_DEVICE_FILE:-$APP_DIR/build/task20_d1_ios_launch_smoke/selected_devices.tsv}"
LOG_DIR="${TASK20_D2D_LOG_DIR:-$APP_DIR/build/task20_d2d_weekly_planner_resume}"
RESULT_LINES="$LOG_DIR/device_results.ndjson"
PHASE1_TIMEOUT_SECONDS="${TASK20_D2D_PHASE1_TIMEOUT_SECONDS:-480}"
PHASE2_TIMEOUT_SECONDS="${TASK20_D2D_PHASE2_TIMEOUT_SECONDS:-300}"
PHASE1_MAX_STARTUP_ATTEMPTS="${TASK20_D2D_PHASE1_MAX_STARTUP_ATTEMPTS:-3}"
PHASE2_MAX_STARTUP_ATTEMPTS="${TASK20_D2D_PHASE2_MAX_STARTUP_ATTEMPTS:-3}"
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
  local timeout_seconds="$6"
  (
    cd "$APP_DIR"
    TASK20_D2_SCREENSHOT_DIR="$screenshot_dir" \
      python3 "$ROOT/tools/task20_d2a_run_with_timeout.py" \
        --timeout-seconds "$timeout_seconds" \
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

append_failure_result() {
  local role="$1"
  local device_name="$2"
  local runtime="$3"
  local udid="$4"
  local exit_code="$5"
  local phase1_result_file="$6"
  local phase2_result_file="$7"
  local process_log="$8"
  local phase1_attempts="$9"
  local phase2_attempts="${10}"
  local retryable_phase="${11}"
  ROLE="$role" DEVICE_NAME="$device_name" RUNTIME="$runtime" UDID="$udid" \
    EXIT_CODE="$exit_code" RESULT_LINES="$RESULT_LINES" \
    PHASE1_RESULT_FILE="$phase1_result_file" PHASE2_RESULT_FILE="$phase2_result_file" \
    PROCESS_LOG="$process_log" PHASE1_ATTEMPTS="$phase1_attempts" \
    PHASE2_ATTEMPTS="$phase2_attempts" RETRYABLE_PHASE="$retryable_phase" python3 - <<'PY'
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
    "phase1_startup_attempts": int(os.environ["PHASE1_ATTEMPTS"]),
    "phase2_startup_attempts": int(os.environ["PHASE2_ATTEMPTS"]),
    "retryable_startup_failure_phase": os.environ["RETRYABLE_PHASE"] or None,
    "phase1": load(os.environ["PHASE1_RESULT_FILE"]),
    "phase2": load(os.environ["PHASE2_RESULT_FILE"]),
    "process_restart_log": process_log.read_text(encoding="utf-8") if process_log.is_file() else "",
}
with Path(os.environ["RESULT_LINES"]).open("a", encoding="utf-8") as stream:
    stream.write(json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n")
PY
}

while IFS=$'\t' read -r role udid runtime device_name; do
  device_dir="$LOG_DIR/$role"
  screenshot_dir="$device_dir/screenshots"
  process_log="$device_dir/process_restart.log"
  rm -rf "$device_dir"
  mkdir -p "$screenshot_dir"

  echo "Task 20-D2D starting: role=$role device=$device_name runtime=$runtime udid=$udid"

  final_code=1
  phase1_attempts=0
  phase2_attempts=0
  phase1_result_file=""
  phase2_result_file=""
  retryable_phase=""

  # Phase 1 startup retries are clean attempts. A test/app failure is never retried.
  for phase1_attempt in $(seq 1 "$PHASE1_MAX_STARTUP_ATTEMPTS"); do
    phase1_attempts="$phase1_attempt"
    attempt_dir="$device_dir/phase1_attempt_$phase1_attempt"
    attempt_screenshot_dir="$attempt_dir/screenshots"
    diagnostics_dir="$attempt_dir/simulator_diagnostics"
    phase1_log="$attempt_dir/phase1_flutter_drive.log"
    candidate_phase1_result="$attempt_dir/phase1_flutter_drive_result.json"
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
      "$candidate_phase1_result" \
      "$PHASE1_TIMEOUT_SECONDS"
    phase1_code="$?"
    set -e

    if [[ "$phase1_code" -eq 0 && -s "$attempt_screenshot_dir/D2D_01_adjustment_saved.png" ]]; then
      cp "$attempt_screenshot_dir/D2D_01_adjustment_saved.png" "$screenshot_dir/"
      phase1_result_file="$candidate_phase1_result"
      final_code=0
      break
    fi

    capture_simulator_diagnostics "$udid" "$diagnostics_dir"
    if [[ "$phase1_code" -ne 0 ]] && is_retryable_startup_failure \
      "$phase1_log" 'D2D_01_adjustment_saved.png' "$attempt_screenshot_dir"; then
      retryable_phase="phase1"
      if [[ "$phase1_attempt" -lt "$PHASE1_MAX_STARTUP_ATTEMPTS" ]]; then
        echo "Task 20-D2D phase 1 startup infrastructure failure; retrying a clean phase 1 attempt."
        continue
      fi
    fi

    final_code="${phase1_code:-1}"
    [[ "$final_code" -ne 0 ]] || final_code=1
    break
  done

  if [[ "$final_code" -ne 0 || -z "$phase1_result_file" ]]; then
    append_failure_result "$role" "$device_name" "$runtime" "$udid" \
      "$final_code" "$phase1_result_file" "$phase2_result_file" "$process_log" \
      "$phase1_attempts" "$phase2_attempts" "$retryable_phase"
    exit "$final_code"
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
    capture_simulator_diagnostics "$udid" "$device_dir/process_restart_diagnostics"
    append_failure_result "$role" "$device_name" "$runtime" "$udid" \
      1 "$phase1_result_file" "$phase2_result_file" "$process_log" \
      "$phase1_attempts" "$phase2_attempts" "process_termination"
    exit 1
  fi

  # Phase 2 retries preserve the Simulator data created by Phase 1.
  final_code=1
  retryable_phase=""
  for phase2_attempt in $(seq 1 "$PHASE2_MAX_STARTUP_ATTEMPTS"); do
    phase2_attempts="$phase2_attempt"
    attempt_dir="$device_dir/phase2_attempt_$phase2_attempt"
    attempt_screenshot_dir="$attempt_dir/screenshots"
    diagnostics_dir="$attempt_dir/simulator_diagnostics"
    phase2_log="$attempt_dir/phase2_flutter_drive.log"
    candidate_phase2_result="$attempt_dir/phase2_flutter_drive_result.json"
    rm -rf "$attempt_dir"
    mkdir -p "$attempt_screenshot_dir"

    xcrun simctl bootstatus "$udid" -b
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    sleep 2

    set +e
    run_drive_phase \
      "$udid" \
      "$attempt_screenshot_dir" \
      integration_test/task20_d2d_weekly_planner_verify_test.dart \
      "$phase2_log" \
      "$candidate_phase2_result" \
      "$PHASE2_TIMEOUT_SECONDS"
    phase2_code="$?"
    set -e

    if [[ "$phase2_code" -eq 0 ]]; then
      missing=false
      for screenshot_name in \
        D2D_02_menu_resume_card.png \
        D2D_03_adjustment_restored.png \
        D2D_04_review_generated.png \
        D2D_05_revise_schedule_preserved.png \
        D2D_06_final_menu.png; do
        if [[ ! -s "$attempt_screenshot_dir/$screenshot_name" ]]; then
          missing=true
          break
        fi
      done
      if [[ "$missing" == false ]]; then
        cp -R "$attempt_screenshot_dir/." "$screenshot_dir/"
        phase2_result_file="$candidate_phase2_result"
        final_code=0
        retryable_phase=""
        break
      fi
    fi

    capture_simulator_diagnostics "$udid" "$diagnostics_dir"
    if [[ "$phase2_code" -ne 0 ]] && is_retryable_startup_failure \
      "$phase2_log" 'D2D_0[2-6]_*.png' "$attempt_screenshot_dir"; then
      retryable_phase="phase2"
      if [[ "$phase2_attempt" -lt "$PHASE2_MAX_STARTUP_ATTEMPTS" ]]; then
        echo "Task 20-D2D phase 2 startup infrastructure failure; retrying phase 2 with the saved draft preserved."
        continue
      fi
    fi

    final_code="${phase2_code:-1}"
    [[ "$final_code" -ne 0 ]] || final_code=1
    break
  done

  if [[ "$final_code" -ne 0 || -z "$phase2_result_file" ]]; then
    append_failure_result "$role" "$device_name" "$runtime" "$udid" \
      "$final_code" "$phase1_result_file" "$phase2_result_file" "$process_log" \
      "$phase1_attempts" "$phase2_attempts" "$retryable_phase"
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
    PROCESS_LOG="$process_log" PHASE1_ATTEMPTS="$phase1_attempts" \
    PHASE2_ATTEMPTS="$phase2_attempts" python3 - <<'PY'
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
    "phase1_startup_attempts": int(os.environ["PHASE1_ATTEMPTS"]),
    "phase2_startup_attempts": int(os.environ["PHASE2_ATTEMPTS"]),
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
  PHASE1_MAX_STARTUP_ATTEMPTS="$PHASE1_MAX_STARTUP_ATTEMPTS" \
  PHASE2_MAX_STARTUP_ATTEMPTS="$PHASE2_MAX_STARTUP_ATTEMPTS" \
  PHASE1_TIMEOUT_SECONDS="$PHASE1_TIMEOUT_SECONDS" \
  PHASE2_TIMEOUT_SECONDS="$PHASE2_TIMEOUT_SECONDS" BUNDLE_ID="$BUNDLE_ID" python3 - <<'PY'
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
        "phase1_maximum_attempts": int(os.environ["PHASE1_MAX_STARTUP_ATTEMPTS"]),
        "phase2_maximum_attempts": int(os.environ["PHASE2_MAX_STARTUP_ATTEMPTS"]),
        "phase1_timeout_seconds": int(os.environ["PHASE1_TIMEOUT_SECONDS"]),
        "phase2_timeout_seconds": int(os.environ["PHASE2_TIMEOUT_SECONDS"]),
        "retry_scope": "phase-specific pre-test debug launch failures with no phase screenshot only",
        "phase2_retry_preserves_phase1_saved_data": True,
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
