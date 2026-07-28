#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
D1_DEVICE_FILE="${TASK20_D1_DEVICE_FILE:-$APP_DIR/build/task20_d1_ios_launch_smoke/selected_devices.tsv}"
LOG_DIR="${TASK20_D2E_LOG_DIR:-$APP_DIR/build/task20_d2e_workout_core_flow}"
RESULT_LINES="$LOG_DIR/device_results.ndjson"
DRIVE_TIMEOUT_SECONDS="${TASK20_D2E_DRIVE_TIMEOUT_SECONDS:-1200}"
MAX_STARTUP_ATTEMPTS="${TASK20_D2E_MAX_STARTUP_ATTEMPTS:-2}"
APP_BUNDLE="$APP_DIR/build/ios/iphonesimulator/Runner.app"
mkdir -p "$LOG_DIR"
: > "$RESULT_LINES"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Task 20-D2E iOS UI acceptance requires macOS." >&2
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

python3 "$ROOT/tools/task20_d2e_prepare_ui_acceptance.py" "$APP_DIR"
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

run_drive() {
  local udid="$1"
  local screenshot_dir="$2"
  local log_file="$3"
  local result_file="$4"
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
          --driver=test_driver/task20_d2e_driver.dart \
          --target=integration_test/task20_d2e_workout_core_flow_test.dart \
          -d "$udid"
  )
}

is_retryable_startup_failure() {
  local log_file="$1"
  local screenshot_dir="$2"
  [[ -z "$(find "$screenshot_dir" -type f -name 'D2E_*.png' -print -quit)" ]] && \
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

  echo "Task 20-D2E starting: role=$role device=$device_name runtime=$runtime udid=$udid"

  final_code=1
  successful_attempt=0
  attempted_count=0
  retryable_startup_failure=false
  drive_result_file=""

  for attempt in $(seq 1 "$MAX_STARTUP_ATTEMPTS"); do
    attempted_count="$attempt"
    attempt_dir="$device_dir/attempt_$attempt"
    attempt_screenshot_dir="$attempt_dir/screenshots"
    diagnostics_dir="$attempt_dir/simulator_diagnostics"
    drive_log="$attempt_dir/flutter_drive.log"
    drive_result_file="$attempt_dir/flutter_drive_result.json"
    rm -rf "$attempt_dir"
    mkdir -p "$attempt_screenshot_dir"

    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl erase "$udid"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b

    set +e
    run_drive "$udid" "$attempt_screenshot_dir" "$drive_log" "$drive_result_file"
    drive_code="$?"
    set -e

    if [[ "$drive_code" -ne 0 ]]; then
      capture_simulator_diagnostics "$udid" "$diagnostics_dir"
      retryable_startup_failure=false
      if is_retryable_startup_failure "$drive_log" "$attempt_screenshot_dir"; then
        retryable_startup_failure=true
      fi
      if [[ "$retryable_startup_failure" == true && "$attempt" -lt "$MAX_STARTUP_ATTEMPTS" ]]; then
        echo "Task 20-D2E startup infrastructure failure; retrying clean attempt."
        continue
      fi
      final_code="$drive_code"
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
      DRIVE_RESULT_FILE="$drive_result_file" ATTEMPTS="$attempted_count" \
      RETRYABLE_STARTUP_FAILURE="$retryable_startup_failure" python3 - <<'PY'
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
    "attempts": int(os.environ["ATTEMPTS"]),
    "retryable_startup_failure": os.environ["RETRYABLE_STARTUP_FAILURE"] == "true",
    "drive": load(os.environ["DRIVE_RESULT_FILE"]),
}
with Path(os.environ["RESULT_LINES"]).open("a", encoding="utf-8") as stream:
    stream.write(json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n")
PY
    exit "$final_code"
  fi

  for screenshot_name in \
    D2E_01_start_check.png \
    D2E_02_adjustment.png \
    D2E_03_session.png \
    D2E_04_form_fallback.png \
    D2E_05_rest.png \
    D2E_06_next_exercise.png \
    D2E_07_assessment.png \
    D2E_08_home_completed.png; do
    test -s "$screenshot_dir/$screenshot_name"
  done
  shasum -a 256 "$screenshot_dir"/*.png > "$device_dir/screenshots.sha256"

  ROLE="$role" DEVICE_NAME="$device_name" RUNTIME="$runtime" UDID="$udid" \
    SCREENSHOT_DIR="$screenshot_dir" RESULT_LINES="$RESULT_LINES" \
    DRIVE_RESULT_FILE="$drive_result_file" ATTEMPTS="$successful_attempt" python3 - <<'PY'
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
    "drive": load(os.environ["DRIVE_RESULT_FILE"]),
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
    raise SystemExit("Expected two passing Task 20-D2E device results")
if any(len(item.get("screenshots", [])) != 8 for item in devices):
    raise SystemExit("Expected eight Task 20-D2E screenshots per device")
result = {
    "task": "Task 20-D2E workout core-flow acceptance",
    "status": "PASS",
    "finished_at_utc": datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z"),
    "app_directory": os.environ["APP_DIR"],
    "bundle_id": os.environ["BUNDLE_ID"],
    "devices": devices,
    "verified_cases": ["D2-05-tested-scope", "D2-10-partial"],
    "verified_behaviors": [
        "first-week menu created and finalized through the UI",
        "workout start summary and safe adjustment entry",
        "fatigue and pain handling selected by the user without diagnosis",
        "workout session start and target display",
        "exercise form text remains usable while images are pending",
        "set-count adjustment and completed-set persistence",
        "rest completion and next-exercise transition",
        "early-stop confirmation and incomplete-reason assessment",
        "assessment save and return to home",
    ],
    "excluded_from_full_pass": [
        "process termination after workout input",
        "records-tab reflection and immutable-history evidence",
        "all pain-action branches",
        "full-session completion of every planned set",
    ],
    "startup_retry_policy": {
        "maximum_attempts": int(os.environ["MAX_STARTUP_ATTEMPTS"]),
        "retry_scope": "pre-test debug launch failures with no D2E screenshot only",
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

echo "Task 20-D2E workout core-flow acceptance passed."
