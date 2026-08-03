#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
D1_DEVICE_FILE="${TASK20_D1_DEVICE_FILE:-$APP_DIR/build/task20_d1_ios_launch_smoke/selected_devices.tsv}"
LOG_DIR="${TASK20_D2H_LOG_DIR:-$APP_DIR/build/task20_d2h_restart_persistence}"
RESULT_LINES="$LOG_DIR/device_results.ndjson"
DRIVE_TIMEOUT_SECONDS="${TASK20_D2H_DRIVE_TIMEOUT_SECONDS:-1500}"
MAX_STARTUP_ATTEMPTS="${TASK20_D2H_MAX_STARTUP_ATTEMPTS:-2}"
APP_BUNDLE="$APP_DIR/build/ios/iphonesimulator/Runner.app"
mkdir -p "$LOG_DIR"
: > "$RESULT_LINES"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Task 20-D2H iOS UI acceptance requires macOS." >&2
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
test -n "$BUNDLE_ID"
printf '%s\n' "$BUNDLE_ID" > "$LOG_DIR/bundle_id.txt"
cp "$APP_DIR/pubspec.yaml" "$LOG_DIR/canonical_pubspec.yaml"
if [[ -f "$APP_DIR/pubspec.lock" ]]; then
  cp "$APP_DIR/pubspec.lock" "$LOG_DIR/canonical_pubspec.lock"
fi

python3 "$ROOT/tools/task20_d2h_prepare_ui_acceptance.py" "$APP_DIR"
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

capture_diagnostics() {
  local udid="$1"
  local destination="$2"
  mkdir -p "$destination"
  xcrun simctl list > "$destination/simctl_list.txt" 2>&1 || true
  xcrun simctl listapps "$udid" > "$destination/listapps.txt" 2>&1 || true
  xcrun simctl spawn "$udid" log show \
    --style compact \
    --last 25m \
    --predicate 'process == "Runner" OR eventMessage CONTAINS[c] "Runner" OR eventMessage CONTAINS[c] "workout"' \
    > "$destination/simulator_recent.log" 2>&1 || true
}

run_phase() {
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
          --driver=test_driver/task20_d2h_driver.dart \
          --target="$target" \
          -d "$udid"
  )
}

is_retryable_startup_failure() {
  local log_file="$1"
  local screenshot_glob="$2"
  local screenshot_dir="$3"
  [[ -z "$(find "$screenshot_dir" -type f -name "$screenshot_glob" -print -quit)" ]] && \
    grep -Eqi \
      'Application failed to start|Error waiting for a debug connection|log reader failed unexpectedly|Unable to launch|Failed to start' \
      "$log_file"
}

while IFS=$'\t' read -r role udid runtime device_name; do
  device_dir="$LOG_DIR/$role"
  final_screenshot_dir="$device_dir/screenshots"
  rm -rf "$device_dir"
  mkdir -p "$final_screenshot_dir"

  final_code=1
  successful_attempt=0
  attempted_count=0
  failure_stage="not_started"
  retryable_startup_failure=false
  phase1_result_file=""
  phase2_result_file=""

  for attempt in $(seq 1 "$MAX_STARTUP_ATTEMPTS"); do
    attempted_count="$attempt"
    attempt_dir="$device_dir/attempt_$attempt"
    screenshot_dir="$attempt_dir/screenshots"
    phase1_log="$attempt_dir/phase1_flutter_drive.log"
    phase2_log="$attempt_dir/phase2_flutter_drive.log"
    phase1_result_file="$attempt_dir/phase1_flutter_drive_result.json"
    phase2_result_file="$attempt_dir/phase2_flutter_drive_result.json"
    process_log="$attempt_dir/process_restart.log"
    rm -rf "$attempt_dir"
    mkdir -p "$screenshot_dir"

    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl erase "$udid"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b

    set +e
    run_phase \
      "$udid" \
      "$screenshot_dir" \
      integration_test/task20_d2h_restart_persistence_prepare_test.dart \
      "$phase1_log" \
      "$phase1_result_file"
    phase1_code="$?"
    set -e
    if [[ "$phase1_code" -ne 0 ]]; then
      failure_stage="phase1"
      capture_diagnostics "$udid" "$attempt_dir/simulator_diagnostics/phase1"
      retryable_startup_failure=false
      if is_retryable_startup_failure \
        "$phase1_log" 'D2H_0[1-2]_*.png' "$screenshot_dir"; then
        retryable_startup_failure=true
      fi
      if [[ "$retryable_startup_failure" == true && "$attempt" -lt "$MAX_STARTUP_ATTEMPTS" ]]; then
        continue
      fi
      final_code="$phase1_code"
      break
    fi

    failure_stage="process_termination"
    {
      echo "bundle_id=$BUNDLE_ID"
      echo "phase1_keep_app_running=true"
      xcrun simctl terminate "$udid" "$BUNDLE_ID"
      echo "os_level_terminate=PASS"
    } > "$process_log" 2>&1 || {
      capture_diagnostics "$udid" "$attempt_dir/simulator_diagnostics/process_termination"
      final_code=1
      break
    }

    set +e
    run_phase \
      "$udid" \
      "$screenshot_dir" \
      integration_test/task20_d2h_restart_persistence_verify_test.dart \
      "$phase2_log" \
      "$phase2_result_file"
    phase2_code="$?"
    set -e
    if [[ "$phase2_code" -ne 0 ]]; then
      failure_stage="phase2"
      capture_diagnostics "$udid" "$attempt_dir/simulator_diagnostics/phase2"
      retryable_startup_failure=false
      if is_retryable_startup_failure \
        "$phase2_log" 'D2H_0[3-6]_*.png' "$screenshot_dir"; then
        retryable_startup_failure=true
      fi
      if [[ "$retryable_startup_failure" == true && "$attempt" -lt "$MAX_STARTUP_ATTEMPTS" ]]; then
        continue
      fi
      final_code="$phase2_code"
      break
    fi

    cp -R "$screenshot_dir/." "$final_screenshot_dir/"
    successful_attempt="$attempt"
    failure_stage="none"
    final_code=0
    retryable_startup_failure=false
    break
  done

  if [[ "$final_code" -ne 0 ]]; then
    ROLE="$role" DEVICE_NAME="$device_name" RUNTIME="$runtime" UDID="$udid" \
      EXIT_CODE="$final_code" RESULT_LINES="$RESULT_LINES" \
      FAILURE_STAGE="$failure_stage" ATTEMPTS="$attempted_count" \
      RETRYABLE_STARTUP_FAILURE="$retryable_startup_failure" \
      PHASE1_RESULT_FILE="$phase1_result_file" PHASE2_RESULT_FILE="$phase2_result_file" \
      python3 - <<'PY'
import json
import os
from pathlib import Path


def load(path: str) -> dict:
    file = Path(path)
    return json.loads(file.read_text(encoding="utf-8")) if file.is_file() else {}


payload = {
    "role": os.environ["ROLE"],
    "device_name": os.environ["DEVICE_NAME"],
    "runtime": os.environ["RUNTIME"],
    "udid": os.environ["UDID"],
    "status": "FAIL",
    "exit_code": int(os.environ["EXIT_CODE"]),
    "failure_stage": os.environ["FAILURE_STAGE"],
    "attempts": int(os.environ["ATTEMPTS"]),
    "retryable_startup_failure": os.environ["RETRYABLE_STARTUP_FAILURE"] == "true",
    "phase1": load(os.environ["PHASE1_RESULT_FILE"]),
    "phase2": load(os.environ["PHASE2_RESULT_FILE"]),
}
with Path(os.environ["RESULT_LINES"]).open("a", encoding="utf-8") as stream:
    stream.write(json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n")
PY
    exit "$final_code"
  fi

  for screenshot_name in \
    D2H_01_measurement_saved.png \
    D2H_02_settings_saved.png \
    D2H_03_home_after_restart.png \
    D2H_04_menu_after_restart.png \
    D2H_05_records_after_restart.png \
    D2H_06_settings_after_restart.png; do
    test -s "$final_screenshot_dir/$screenshot_name"
  done
  shasum -a 256 "$final_screenshot_dir"/*.png > "$device_dir/screenshots.sha256"

  ROLE="$role" DEVICE_NAME="$device_name" RUNTIME="$runtime" UDID="$udid" \
    SCREENSHOT_DIR="$final_screenshot_dir" RESULT_LINES="$RESULT_LINES" \
    PHASE1_RESULT_FILE="$phase1_result_file" PHASE2_RESULT_FILE="$phase2_result_file" \
    ATTEMPTS="$successful_attempt" python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path


def load(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


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
    raise SystemExit("Expected two passing Task 20-D2H device results")
result = {
    "task": "Task 20-D2H restart persistence acceptance",
    "status": "PASS",
    "finished_at_utc": datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z"),
    "app_directory": os.environ["APP_DIR"],
    "bundle_id": os.environ["BUNDLE_ID"],
    "devices": devices,
    "verified_cases": ["D2-06-partial", "D2-07-partial", "D2-08", "D2-10-partial"],
    "verified_behaviors": [
        "finalized weekly menu persists after OS-level process termination",
        "partial workout record persists after restart",
        "body measurement persists after restart",
        "saved primary training goal persists after restart",
        "repository and database reload values match the expected fixture",
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

echo "Task 20-D2H restart persistence acceptance passed."
