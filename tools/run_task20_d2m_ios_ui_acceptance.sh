#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
D1_DEVICE_FILE="${TASK20_D1_DEVICE_FILE:-$APP_DIR/build/task20_d1_ios_launch_smoke/selected_devices.tsv}"
LOG_DIR="${TASK20_D2M_LOG_DIR:-$APP_DIR/build/task20_d2m_rest_day_rollover}"
TRIGGER_TIMEOUT_SECONDS="${TASK20_D2M_TRIGGER_TIMEOUT_SECONDS:-1200}"
VERIFY_TIMEOUT_SECONDS="${TASK20_D2M_VERIFY_TIMEOUT_SECONDS:-900}"
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
  echo "ERROR: Task 20-D2M iOS UI acceptance requires macOS." >&2
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
python3 "$ROOT/tools/task20_d2m_prepare_ui_acceptance.py" "$APP_DIR"
(
  set -x
  cd "$APP_DIR"
  flutter pub get
  dart format     integration_test/task20_d2m_rest_day_rollover_trigger_test.dart     integration_test/task20_d2m_rest_day_rollover_verify_test.dart
  flutter analyze     integration_test/task20_d2m_rest_day_rollover_trigger_test.dart     integration_test/task20_d2m_rest_day_rollover_verify_test.dart
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

set_stage "simulator_boot"
xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
xcrun simctl erase "$udid"
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b

set_stage "trigger_launch"
(
  cd "$APP_DIR"
  TASK20_D2_SCREENSHOT_DIR="$screenshot_dir"     flutter drive       --keep-app-running       --no-dds       --driver=test_driver/task20_d2e_driver.dart       --target=integration_test/task20_d2m_rest_day_rollover_trigger_test.dart       -d "$udid"
) >"$trigger_log" 2>&1 &
trigger_pid="$!"

set_stage "rest_day_rollover_ready"
wait_for_marker "$trigger_log" 'D2M_READY_FOR_OS_TERMINATION' "$TRIGGER_TIMEOUT_SECONDS"
grep -Fq 'D2M_TRIGGER_METADATA=' "$trigger_log"
capture_host_screenshot 'D2M_01_rest_before_termination.png'

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

set_stage "restart_verification"
xcrun simctl bootstatus "$udid" -b
sleep 2
(
  cd "$APP_DIR"
  TASK20_D2_SCREENSHOT_DIR="$screenshot_dir"     python3 "$ROOT/tools/task20_d2a_run_with_timeout.py"       --timeout-seconds "$VERIFY_TIMEOUT_SECONDS"       --log-file "$verify_log"       --result-file "$verify_result"       --       flutter drive         --keep-app-running         --no-dds         --driver=test_driver/task20_d2e_driver.dart         --target=integration_test/task20_d2m_rest_day_rollover_verify_test.dart         -d "$udid"
)

set_stage "acceptance_assertions"
for required in   D2M_01_rest_before_termination.png   D2M_02_home_resume_after_restart.png   D2M_03_rest_restored_after_restart.png   D2M_04_advanced_after_restart.png; do
  test -s "$screenshot_dir/$required" || {
    echo "ERROR: Missing D2M screenshot: $required" >&2
    exit 1
  }
done

grep -Fq 'D2M_TRIGGER_METADATA=' "$trigger_log"
grep -Fq 'D2M_VERIFY_METADATA=' "$verify_log"
grep -Fq '"rest_restored_after_restart":true' "$verify_log"
grep -Fq '"rest_remaining_sec_after_restart":0' "$verify_log"
grep -Fq '"rest_cleared_after_advance":true' "$verify_log"
grep -Fq 'os_level_terminate=PASS' "$LOG_DIR/os_termination.log"

(
  cd "$screenshot_dir"
  shasum -a 256 D2M_*.png | sort > "$LOG_DIR/screenshots.sha256"
)

set_stage "result_write"
ROLE="$role" UDID="$udid" RUNTIME="$runtime" DEVICE_NAME="$device_name" BUNDLE_ID="$BUNDLE_ID" TRIGGER_EXIT_CODE="$trigger_exit_code" LOG_DIR="$LOG_DIR" python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

log_dir = Path(os.environ["LOG_DIR"])
result = {
    "task": "Task 20-D2M rest timer and day-rollover interruption acceptance",
    "status": "PASS",
    "scope": "one GitHub-hosted iOS Simulator; active rest persisted across simulated prior-day session plus real OS termination/relaunch",
    "role": os.environ["ROLE"],
    "device_name": os.environ["DEVICE_NAME"],
    "runtime": os.environ["RUNTIME"],
    "udid": os.environ["UDID"],
    "bundle_id": os.environ["BUNDLE_ID"],
    "os_level_terminate": "PASS",
    "trigger_exit_code_after_expected_os_kill": int(os.environ["TRIGGER_EXIT_CODE"]),
    "rest_duration_adjustment_persisted": True,
    "prior_day_record_date_preserved": True,
    "expired_rest_restored_after_restart": True,
    "open_session_resume_from_home": True,
    "rest_advance_after_restart": True,
    "screenshots": [
        "D2M_01_rest_before_termination.png",
        "D2M_02_home_resume_after_restart.png",
        "D2M_03_rest_restored_after_restart.png",
        "D2M_04_advanced_after_restart.png",
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
echo "Task 20-D2M rest timer/day-rollover acceptance passed."
