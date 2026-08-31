#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
D1_DEVICE_FILE="${TASK20_D1_DEVICE_FILE:-$APP_DIR/build/task20_d1_ios_launch_smoke/selected_devices.tsv}"
LOG_DIR="${TASK20_D2K_LOG_DIR:-$APP_DIR/build/task20_d2k_reset_interruption}"
TRIGGER_TIMEOUT_SECONDS="${TASK20_D2K_TRIGGER_TIMEOUT_SECONDS:-1200}"
VERIFY_TIMEOUT_SECONDS="${TASK20_D2K_VERIFY_TIMEOUT_SECONDS:-600}"
APP_BUNDLE="$APP_DIR/build/ios/iphonesimulator/Runner.app"

parent_preflight_backup=""
if [[ -f "$LOG_DIR/parent_preflight.log" ]]; then
  parent_preflight_backup="$(mktemp)"
  cp "$LOG_DIR/parent_preflight.log" "$parent_preflight_backup"
fi
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"
if [[ -n "$parent_preflight_backup" && -f "$parent_preflight_backup" ]]; then
  cp "$parent_preflight_backup" "$LOG_DIR/parent_preflight.log"
  rm -f "$parent_preflight_backup"
fi

current_stage="bootstrap"
udid=""
BUNDLE_ID=""
trigger_pid=""
lock_pid=""
lock_release=""

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
    echo "pwd=$(pwd)"
    echo "PATH=$PATH"
  } > "$LOG_DIR/failure.txt"
}
trap 'code=$?; failed_line=$LINENO; failed_command=$BASH_COMMAND; record_failure "$code" "$failed_line" "$failed_command"' ERR

cleanup() {
  if [[ -n "${lock_release:-}" ]]; then
    touch "$lock_release" >/dev/null 2>&1 || true
  fi
  if [[ -n "${lock_pid:-}" ]] && kill -0 "$lock_pid" >/dev/null 2>&1; then
    kill "$lock_pid" >/dev/null 2>&1 || true
  fi
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
  echo "ERROR: Task 20-D2K iOS UI acceptance requires macOS." >&2
  exit 2
fi
for command_name in flutter dart xcrun python3 shasum plutil awk grep; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "ERROR: $command_name was not found." >&2
    exit 2
  }
done
{
  echo "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "pwd=$(pwd)"
  echo "PATH=$PATH"
  for command_name in flutter dart xcrun python3 shasum plutil awk grep; do
    echo "$command_name=$(command -v "$command_name")"
  done
} > "$LOG_DIR/runner_preflight.log"

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

selected_line="$(awk -F '\t' '$1 == "regular" {print; exit}' "$D1_DEVICE_FILE")"
if [[ -z "$selected_line" ]]; then
  selected_line="$(head -n 1 "$D1_DEVICE_FILE")"
fi
IFS=$'\t' read -r role udid runtime device_name <<<"$selected_line"
if [[ -z "${udid:-}" ]]; then
  echo "ERROR: No D2K simulator was selected." >&2
  exit 2
fi
printf '%s\t%s\t%s\t%s\n' "$role" "$udid" "$runtime" "$device_name" > "$LOG_DIR/selected_device.tsv"
printf '%s\n' "$BUNDLE_ID" > "$LOG_DIR/bundle_id.txt"

set_stage "overlay_preflight"
python3 "$ROOT/tools/task20_d2k_prepare_ui_acceptance.py" "$APP_DIR"
(
  set -x
  cd "$APP_DIR"
  flutter pub get
  dart format lib/core/security/secure_store.dart \
    integration_test/task20_d2k_reset_interruption_trigger_test.dart \
    integration_test/task20_d2k_reset_interruption_verify_test.dart
  flutter analyze lib/core/security/secure_store.dart \
    integration_test/task20_d2k_reset_interruption_trigger_test.dart \
    integration_test/task20_d2k_reset_interruption_verify_test.dart
) 2>&1 | tee "$LOG_DIR/overlay_preflight.log"

trigger_log="$LOG_DIR/trigger_flutter_drive.log"
verify_log="$LOG_DIR/verify_flutter_drive.log"
verify_result="$LOG_DIR/verify_flutter_drive_result.json"
screenshot_dir="$LOG_DIR/screenshots"
lock_ready="$LOG_DIR/db_lock_ready"
lock_release="$LOG_DIR/db_lock_release"
lock_log="$LOG_DIR/db_lock.log"
mkdir -p "$screenshot_dir"
rm -f "$lock_ready" "$lock_release"

wait_for_file() {
  local path="$1" timeout_seconds="$2" description="$3"
  local deadline=$(( $(date +%s) + timeout_seconds ))
  while (( $(date +%s) < deadline )); do
    [[ -s "$path" || -e "$path" ]] && return 0
    sleep 1
  done
  echo "ERROR: Timed out waiting for $description: $path" >&2
  return 1
}

wait_for_marker() {
  local path="$1" marker="$2" timeout_seconds="$3"
  local deadline=$(( $(date +%s) + timeout_seconds ))
  while (( $(date +%s) < deadline )); do
    if [[ -f "$path" ]] && grep -Fq "$marker" "$path"; then
      return 0
    fi
    if [[ -n "${trigger_pid:-}" ]] && ! kill -0 "$trigger_pid" >/dev/null 2>&1; then
      echo "ERROR: Trigger drive exited before marker: $marker" >&2
      tail -n 120 "$path" >&2 || true
      return 1
    fi
    sleep 1
  done
  echo "ERROR: Timed out waiting for trigger marker: $marker" >&2
  tail -n 120 "$path" >&2 || true
  return 1
}

capture_host_screenshot() {
  local filename="$1"
  local destination="$screenshot_dir/$filename"
  local log_file="$LOG_DIR/${filename%.png}_host_screenshot.log"
  local attempt
  rm -f "$destination"
  : > "$log_file"
  for attempt in 1 2 3; do
    echo "attempt=$attempt" >> "$log_file"
    if xcrun simctl io "$udid" screenshot "$destination" >> "$log_file" 2>&1 \
      && [[ -s "$destination" ]]; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: Failed to capture host Simulator screenshot: $destination" >&2
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
  TASK20_D2_SCREENSHOT_DIR="$screenshot_dir" \
    flutter drive \
      --keep-app-running \
      --no-dds \
      --dart-define=TASK20_D2K_TEST_GATE=true \
      --driver=test_driver/task20_d2i_driver.dart \
      --target=integration_test/task20_d2k_reset_interruption_trigger_test.dart \
      -d "$udid"
) >"$trigger_log" 2>&1 &
trigger_pid="$!"

set_stage "ready_marker"
wait_for_marker "$trigger_log" 'D2K_READY_FOR_DB_LOCK' "$TRIGGER_TIMEOUT_SECONDS"
capture_host_screenshot 'D2K_01_ready_before_interruption.png'

set_stage "secure_key_switch_gate"
wait_for_marker "$trigger_log" 'D2K_SECURE_KEY_SWITCHED_WAITING_FOR_HOST' 120

set_stage "database_discovery"
data_container="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data)"
test -d "$data_container"
printf '%s\n' "$data_container" > "$LOG_DIR/data_container.txt"

set_stage "database_lock"
python3 - "$data_container" "$lock_ready" "$lock_release" >"$lock_log" 2>&1 <<'PY' &
import sqlite3
import sys
import time
from pathlib import Path

root = Path(sys.argv[1])
ready = Path(sys.argv[2])
release = Path(sys.argv[3])
candidates = []
for path in root.rglob('*'):
    if not path.is_file() or path.name.endswith(('-wal', '-shm')):
        continue
    try:
        if path.stat().st_size < 16:
            continue
        with path.open('rb') as stream:
            if stream.read(16) != b'SQLite format 3\x00':
                continue
        probe = sqlite3.connect(f'file:{path}?mode=ro', uri=True, timeout=1)
        try:
            row = probe.execute(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='user_account'"
            ).fetchone()
            if row and row[0] == 1:
                candidates.append(path)
        finally:
            probe.close()
    except (OSError, sqlite3.Error):
        continue
if len(candidates) != 1:
    raise SystemExit(f'Expected exactly one app database, found: {candidates}')
db = candidates[0]
print(f'database={db}', flush=True)
connection = sqlite3.connect(str(db), timeout=30, isolation_level=None)
connection.execute('PRAGMA busy_timeout=30000')
connection.execute('BEGIN IMMEDIATE')
ready.write_text(str(db) + '\n', encoding='utf-8')
print('lock=BEGIN_IMMEDIATE', flush=True)
try:
    deadline = time.time() + 180
    while time.time() < deadline and not release.exists():
        time.sleep(0.1)
    if not release.exists():
        raise SystemExit('Host never released D2K database lock')
finally:
    connection.execute('ROLLBACK')
    connection.close()
print('lock=RELEASED', flush=True)
PY
lock_pid="$!"

wait_for_file "$lock_ready" 30 'external SQLite BEGIN IMMEDIATE lock'
database_path="$(head -n 1 "$lock_ready")"
printf '%s\n' "$database_path" > "$LOG_DIR/database_path.txt"

set_stage "critical_window"
wait_for_marker "$trigger_log" 'D2K_RESET_CRITICAL_WINDOW_READY' 120

set_stage "transaction_blocked"
wait_for_marker "$trigger_log" 'D2K_SECURE_KEY_GATE_RELEASED' 90
sleep 2
capture_host_screenshot 'D2K_02_reset_blocked_in_progress.png'

set_stage "os_termination"
terminate_status="FAIL"
if xcrun simctl terminate "$udid" "$BUNDLE_ID" >>"$LOG_DIR/os_termination.log" 2>&1; then
  terminate_status="PASS"
fi
printf 'os_level_terminate=%s\n' "$terminate_status" >> "$LOG_DIR/os_termination.log"
if [[ "$terminate_status" != "PASS" ]]; then
  echo "ERROR: OS-level terminate failed during D2K critical window." >&2
  exit 1
fi

touch "$lock_release"
wait "$lock_pid"
lock_pid=""

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
xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
sleep 2
(
  cd "$APP_DIR"
  TASK20_D2_SCREENSHOT_DIR="$screenshot_dir" \
    python3 "$ROOT/tools/task20_d2a_run_with_timeout.py" \
      --timeout-seconds "$VERIFY_TIMEOUT_SECONDS" \
      --log-file "$verify_log" \
      --result-file "$verify_result" \
      -- \
      flutter drive \
        --keep-app-running \
        --no-dds \
        --driver=test_driver/task20_d2i_driver.dart \
        --target=integration_test/task20_d2k_reset_interruption_verify_test.dart \
        -d "$udid"
)
capture_host_screenshot 'D2K_03_recovered_after_interruption.png'

set_stage "acceptance_assertions"
for required in \
  D2K_01_ready_before_interruption.png \
  D2K_02_reset_blocked_in_progress.png \
  D2K_03_recovered_after_interruption.png; do
  test -s "$screenshot_dir/$required" || {
    echo "ERROR: Missing D2K screenshot: $required" >&2
    exit 1
  }
done

grep -Fq 'D2K_SECURE_KEY_SWITCHED_WAITING_FOR_HOST' "$trigger_log"
grep -Fq 'D2K_SECURE_KEY_GATE_RELEASED' "$trigger_log"
grep -Fq 'D2K_RESET_CRITICAL_WINDOW_READY' "$trigger_log"
grep -Fq 'D2K_VERIFY_METADATA=' "$verify_log"
grep -Fq 'old_user_owned_rows_preserved":true' "$verify_log"
grep -Fq 'secure_key_recovered_to_old_user":true' "$verify_log"
grep -Fq 'replacement_account_absent":true' "$verify_log"
grep -Fq 'foreign_key_violations":0' "$verify_log"
grep -Fq 'lock=BEGIN_IMMEDIATE' "$lock_log"
grep -Fq 'lock=RELEASED' "$lock_log"
test -s "$LOG_DIR/test_gate_instrumentation.json"
grep -Fq '"product_zip_changed": false' "$LOG_DIR/test_gate_instrumentation.json"

(
  cd "$screenshot_dir"
  shasum -a 256 D2K_*.png | sort > "$LOG_DIR/screenshots.sha256"
)

set_stage "result_write"
ROLE="$role" UDID="$udid" RUNTIME="$runtime" DEVICE_NAME="$device_name" \
BUNDLE_ID="$BUNDLE_ID" DATABASE_PATH="$database_path" \
TRIGGER_EXIT_CODE="$trigger_exit_code" LOG_DIR="$LOG_DIR" python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

log_dir = Path(os.environ['LOG_DIR'])
result = {
    'task': 'Task 20-D2K local reset interruption',
    'status': 'PASS',
    'scope': 'one GitHub-hosted iOS Simulator; OS kill after Secure Storage user switch while reset DB transaction is blocked',
    'role': os.environ['ROLE'],
    'device_name': os.environ['DEVICE_NAME'],
    'runtime': os.environ['RUNTIME'],
    'udid': os.environ['UDID'],
    'bundle_id': os.environ['BUNDLE_ID'],
    'database_path': os.environ['DATABASE_PATH'],
    'external_write_lock': 'BEGIN IMMEDIATE',
    'secure_store_test_gate': 'PASS',
    'gate_released_before_os_termination': True,
    'critical_window_marker_seen': True,
    'os_level_terminate': 'PASS',
    'trigger_exit_code_after_expected_os_kill': int(os.environ['TRIGGER_EXIT_CODE']),
    'restart_verification': 'PASS',
    'old_user_owned_rows_preserved': True,
    'secure_key_recovered_to_old_user': True,
    'replacement_account_absent': True,
    'preserved_tables_unchanged': True,
    'schema_unchanged': True,
    'foreign_key_violations': 0,
    'finished_at_utc': datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z'),
}
(log_dir / 'result.json').write_text(
    json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + '\n',
    encoding='utf-8',
)
print(json.dumps(result, ensure_ascii=False, sort_keys=True))
PY
rm -f "$LOG_DIR/failure.txt"
set_stage "PASS"
echo "Task 20-D2K local reset interruption acceptance passed."
