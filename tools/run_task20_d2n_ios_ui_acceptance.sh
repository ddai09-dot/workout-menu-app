#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
D1_DEVICE_FILE="${TASK20_D1_DEVICE_FILE:-$APP_DIR/build/task20_d1_ios_launch_smoke/selected_devices.tsv}"
LOG_DIR="${TASK20_D2N_LOG_DIR:-$APP_DIR/build/task20_d2n_workout_input_interruption}"
TRIGGER_TIMEOUT_SECONDS="${TASK20_D2N_TRIGGER_TIMEOUT_SECONDS:-1200}"
TRIGGER_DRIVE_TIMEOUT_SECONDS="${TASK20_D2N_TRIGGER_DRIVE_TIMEOUT_SECONDS:-900}"
TRIGGER_MAX_STARTUP_ATTEMPTS="${TASK20_D2N_TRIGGER_MAX_STARTUP_ATTEMPTS:-2}"
VERIFY_TIMEOUT_SECONDS="${TASK20_D2N_VERIFY_TIMEOUT_SECONDS:-900}"
VERIFY_MAX_STARTUP_ATTEMPTS="${TASK20_D2N_VERIFY_MAX_STARTUP_ATTEMPTS:-2}"
APP_BUNDLE="$APP_DIR/build/ios/iphonesimulator/Runner.app"

rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

current_stage="bootstrap"
udid=""
BUNDLE_ID=""
trigger_pid=""

set_stage() {
  current_stage="$1"
  printf '%s\n' "$current_stage" > "$LOG_DIR/stage.txt"
}

record_failure() {
  local code="$1" line="$2" command="$3"
  {
    echo "status=FAIL"
    echo "stage=$current_stage"
    echo "exit_code=$code"
    echo "line=$line"
    echo "command=$command"
    echo "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$LOG_DIR/failure.txt"
}
trap 'code=$?; record_failure "$code" "$LINENO" "$BASH_COMMAND"' ERR

cleanup() {
  if [[ -n "${trigger_pid:-}" ]] && kill -0 "$trigger_pid" >/dev/null 2>&1; then
    kill "$trigger_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "${udid:-}" && -n "${BUNDLE_ID:-}" ]]; then
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

set_stage "preflight"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Task 20-D2N iOS UI acceptance requires macOS." >&2
  exit 2
fi
for command_name in flutter dart xcrun python3 shasum plutil awk grep; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "ERROR: $command_name was not found." >&2
    exit 2
  }
done
test -f "$D1_DEVICE_FILE"
test -d "$APP_BUNDLE"
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$APP_BUNDLE/Info.plist")"
test -n "$BUNDLE_ID"

selected_line="$(awk -F '\t' '$1 == "regular" {print; exit}' "$D1_DEVICE_FILE")"
if [[ -z "$selected_line" ]]; then
  selected_line="$(head -n 1 "$D1_DEVICE_FILE")"
fi
IFS=$'\t' read -r role udid runtime device_name <<<"$selected_line"
test -n "$udid"
printf '%s\t%s\t%s\t%s\n' "$role" "$udid" "$runtime" "$device_name" > "$LOG_DIR/selected_device.tsv"
printf '%s\n' "$BUNDLE_ID" > "$LOG_DIR/bundle_id.txt"

set_stage "overlay_preflight"
python3 "$ROOT/tools/task20_d2n_prepare_ui_acceptance.py" "$APP_DIR"
(
  set -x
  cd "$APP_DIR"
  flutter pub get
  dart format     integration_test/task20_d2n_workout_input_trigger_test.dart     integration_test/task20_d2n_workout_input_verify_test.dart
  flutter analyze     integration_test/task20_d2n_workout_input_trigger_test.dart     integration_test/task20_d2n_workout_input_verify_test.dart
) 2>&1 | tee "$LOG_DIR/overlay_preflight.log"

screenshot_dir="$LOG_DIR/screenshots"
trigger_log="$LOG_DIR/trigger_flutter_drive.log"
verify_log="$LOG_DIR/verify_flutter_drive.log"
verify_result="$LOG_DIR/verify_flutter_drive_result.json"
mkdir -p "$screenshot_dir"

wait_for_marker() {
  local path="$1" marker="$2" timeout_seconds="$3"
  local deadline=$(( $(date +%s) + timeout_seconds ))
  while (( $(date +%s) < deadline )); do
    if [[ -f "$path" ]] && grep -Fq "$marker" "$path"; then
      return 0
    fi
    if [[ -n "${trigger_pid:-}" ]] && ! kill -0 "$trigger_pid" >/dev/null 2>&1; then
      echo "ERROR: Trigger drive exited before marker: $marker" >&2
      tail -n 160 "$path" >&2 || true
      return 1
    fi
    sleep 1
  done
  echo "ERROR: Timed out waiting for marker: $marker" >&2
  tail -n 160 "$path" >&2 || true
  return 1
}

capture_host_screenshot() {
  local filename="$1"
  local destination="$screenshot_dir/$filename"
  rm -f "$destination"
  for attempt in 1 2 3; do
    if xcrun simctl io "$udid" screenshot "$destination" >>"$LOG_DIR/host_screenshot.log" 2>&1       && [[ -s "$destination" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

set_stage "trigger_launch"
trigger_successful_attempt=0
trigger_active_log=""
for trigger_attempt in $(seq 1 "$TRIGGER_MAX_STARTUP_ATTEMPTS"); do
  trigger_attempt_log="$LOG_DIR/trigger_flutter_drive_attempt_$trigger_attempt.log"
  trigger_attempt_result="$LOG_DIR/trigger_flutter_drive_attempt_$trigger_attempt.json"

  if [[ "$trigger_attempt" -eq 1 ]]; then
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl erase "$udid"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b
  else
    # Retry only when the prior attempt never entered D2N and the log proves a
    # Flutter debug-attach/startup failure. Keep CoreSimulator warm while
    # clearing app-local state before retrying.
    xcrun simctl boot "$udid" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$udid" -b
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl uninstall "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl keychain "$udid" reset
    xcrun simctl privacy "$udid" reset all "$BUNDLE_ID" >/dev/null 2>&1 || true
  fi

  (
    cd "$APP_DIR"
    TASK20_D2_SCREENSHOT_DIR="$screenshot_dir" \
      python3 "$ROOT/tools/task20_d2a_run_with_timeout.py" \
        --timeout-seconds "$TRIGGER_DRIVE_TIMEOUT_SECONDS" \
        --log-file "$trigger_attempt_log" \
        --result-file "$trigger_attempt_result" \
        -- \
        flutter drive \
          --keep-app-running \
          --no-dds \
          --driver=test_driver/task20_d2e_driver.dart \
          --target=integration_test/task20_d2n_workout_input_trigger_test.dart \
          -d "$udid"
  ) &
  trigger_pid="$!"

  set +e
  wait_for_marker "$trigger_attempt_log" 'D2N_READY_FOR_OS_TERMINATION' "$TRIGGER_TIMEOUT_SECONDS"
  marker_code="$?"
  set -e

  if [[ "$marker_code" -eq 0 ]]; then
    trigger_successful_attempt="$trigger_attempt"
    trigger_active_log="$trigger_attempt_log"
    break
  fi

  if kill -0 "$trigger_pid" >/dev/null 2>&1; then
    kill "$trigger_pid" >/dev/null 2>&1 || true
  fi
  set +e
  wait "$trigger_pid"
  set -e
  trigger_pid=""

  trigger_retryable_startup_failure=false
  if [[ -z "$(find "$screenshot_dir" -type f -name 'D2N_*.png' -print -quit)" ]] && \
    grep -Eqi \
      'Application failed to start|Error waiting for a debug connection|log reader failed unexpectedly|Unable to launch|Failed to start' \
      "$trigger_attempt_log"; then
    trigger_retryable_startup_failure=true
  fi

  if [[ "$trigger_retryable_startup_failure" == true && "$trigger_attempt" -lt "$TRIGGER_MAX_STARTUP_ATTEMPTS" ]]; then
    echo "Task 20-D2N trigger startup infrastructure failure; retrying warm with no accepted D2N evidence."
    continue
  fi

  cp "$trigger_attempt_log" "$trigger_log"
  exit 1
done

if [[ "$trigger_successful_attempt" -eq 0 || -z "$trigger_active_log" ]]; then
  echo "ERROR: D2N trigger never reached the acceptance marker." >&2
  exit 1
fi
printf '%s\n' "$trigger_successful_attempt" > "$LOG_DIR/trigger_successful_attempt.txt"

set_stage "input_draft_ready"
grep -Fq 'D2N_TRIGGER_METADATA=' "$trigger_active_log"
capture_host_screenshot 'D2N_01_input_saved_before_termination.png'

set_stage "os_termination"
xcrun simctl terminate "$udid" "$BUNDLE_ID" >"$LOG_DIR/os_termination.log" 2>&1
printf 'os_level_terminate=PASS\n' >> "$LOG_DIR/os_termination.log"

set_stage "trigger_teardown"
for _ in $(seq 1 30); do
  if ! kill -0 "$trigger_pid" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if kill -0 "$trigger_pid" >/dev/null 2>&1; then
  kill "$trigger_pid" >/dev/null 2>&1 || true
fi
set +e
wait "$trigger_pid"
trigger_exit_code="$?"
set -e
trigger_pid=""
printf '%s\n' "$trigger_exit_code" > "$LOG_DIR/trigger_exit_code.txt"
cp "$trigger_active_log" "$trigger_log"

set_stage "restart_verification"
xcrun simctl bootstatus "$udid" -b
sleep 2

verify_successful_attempt=0
verify_final_code=1
for verify_attempt in $(seq 1 "$VERIFY_MAX_STARTUP_ATTEMPTS"); do
  verify_attempt_log="$LOG_DIR/verify_flutter_drive_attempt_$verify_attempt.log"
  verify_attempt_result="$LOG_DIR/verify_flutter_drive_attempt_$verify_attempt.json"
  set +e
  (
    cd "$APP_DIR"
    TASK20_D2_SCREENSHOT_DIR="$screenshot_dir"       python3 "$ROOT/tools/task20_d2a_run_with_timeout.py"         --timeout-seconds "$VERIFY_TIMEOUT_SECONDS"         --log-file "$verify_attempt_log"         --result-file "$verify_attempt_result"         --         flutter drive           --keep-app-running           --no-dds           --driver=test_driver/task20_d2e_driver.dart           --target=integration_test/task20_d2n_workout_input_verify_test.dart           -d "$udid"
  )
  verify_code="$?"
  set -e

  cp "$verify_attempt_log" "$verify_log"
  cp "$verify_attempt_result" "$verify_result"

  if [[ "$verify_code" -eq 0 ]]; then
    verify_successful_attempt="$verify_attempt"
    verify_final_code=0
    break
  fi

  verify_retryable_startup_failure=false
  if [[ ! -s "$screenshot_dir/D2N_02_home_resume_after_restart.png" ]] &&     grep -Eqi       'Application failed to start|Error waiting for a debug connection|log reader failed unexpectedly|Unable to launch|Failed to start'       "$verify_attempt_log"; then
    verify_retryable_startup_failure=true
  fi

  if [[ "$verify_retryable_startup_failure" == true && "$verify_attempt" -lt "$VERIFY_MAX_STARTUP_ATTEMPTS" ]]; then
    echo "Task 20-D2N verify startup infrastructure failure; retrying without erasing persisted state."
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$udid" -b
    sleep 2
    continue
  fi

  verify_final_code="$verify_code"
  break
done

printf '%s\n' "$verify_successful_attempt" > "$LOG_DIR/verify_successful_attempt.txt"
if [[ "$verify_final_code" -ne 0 ]]; then
  exit "$verify_final_code"
fi

set_stage "acceptance_assertions"
for required in   D2N_01_input_saved_before_termination.png   D2N_02_home_resume_after_restart.png   D2N_03_input_restored_after_restart.png   D2N_04_rest_after_restored_input_commit.png; do
  test -s "$screenshot_dir/$required" || {
    echo "ERROR: Missing D2N screenshot: $required" >&2
    exit 1
  }
done

grep -Fq 'D2N_TRIGGER_METADATA=' "$trigger_log"
grep -Fq 'D2N_VERIFY_METADATA=' "$verify_log"
grep -Fq '"draft_restored_after_restart":true' "$verify_log"
grep -Fq '"recorded_actual_reps":37' "$verify_log"
grep -Fq '"draft_cleared_after_commit":true' "$verify_log"
grep -Fq 'os_level_terminate=PASS' "$LOG_DIR/os_termination.log"

(
  cd "$screenshot_dir"
  shasum -a 256 D2N_*.png | sort > "$LOG_DIR/screenshots.sha256"
)

set_stage "result_write"
ROLE="$role" UDID="$udid" RUNTIME="$runtime" DEVICE_NAME="$device_name" BUNDLE_ID="$BUNDLE_ID" TRIGGER_EXIT_CODE="$trigger_exit_code" VERIFY_SUCCESSFUL_ATTEMPT="$verify_successful_attempt" LOG_DIR="$LOG_DIR" python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

log_dir = Path(os.environ["LOG_DIR"])
result = {
    "task": "Task 20-D2N workout input interruption acceptance",
    "status": "PASS",
    "scope": "one GitHub-hosted iOS Simulator; current set input saved before OS termination, restored after relaunch, then committed exactly once",
    "role": os.environ["ROLE"],
    "device_name": os.environ["DEVICE_NAME"],
    "runtime": os.environ["RUNTIME"],
    "udid": os.environ["UDID"],
    "bundle_id": os.environ["BUNDLE_ID"],
    "os_level_terminate": "PASS",
    "trigger_exit_code_after_expected_os_kill": int(os.environ["TRIGGER_EXIT_CODE"]),
    "verify_successful_attempt": int(os.environ["VERIFY_SUCCESSFUL_ATTEMPT"]),
    "sentinel_reps": 37,
    "draft_restored_after_restart": True,
    "no_completed_set_before_restart": True,
    "restored_input_committed_once": True,
    "draft_cleared_after_commit": True,
    "screenshots": [
        "D2N_01_input_saved_before_termination.png",
        "D2N_02_home_resume_after_restart.png",
        "D2N_03_input_restored_after_restart.png",
        "D2N_04_rest_after_restored_input_commit.png",
    ],
    "finished_at_utc": datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z"),
}
(log_dir / "result.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, ensure_ascii=False, sort_keys=True))
PY

rm -f "$LOG_DIR/failure.txt"
set_stage "PASS"
echo "Task 20-D2N workout-input interruption acceptance passed."
