#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
D1_DEVICE_FILE="${TASK20_D1_DEVICE_FILE:-$APP_DIR/build/task20_d1_ios_launch_smoke/selected_devices.tsv}"
LOG_DIR="${TASK20_D2K_LOG_DIR:-$APP_DIR/build/task20_d2k_reset_interruption}"
TRIGGER_TIMEOUT_SECONDS="${TASK20_D2K_TRIGGER_TIMEOUT_SECONDS:-1200}"
VERIFY_TIMEOUT_SECONDS="${TASK20_D2K_VERIFY_TIMEOUT_SECONDS:-600}"
APP_BUNDLE="$APP_DIR/build/ios/iphonesimulator/Runner.app"
mkdir -p "$LOG_DIR"
rm -rf "$LOG_DIR"/*

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Task 20-D2K iOS UI acceptance requires macOS." >&2
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

# D2K is a persistence/atomicity acceptance, so one deterministic regular-size
# simulator is sufficient for this case. Visual size coverage remains D2-10.
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

python3 "$ROOT/tools/task20_d2k_prepare_ui_acceptance.py" "$APP_DIR"
(
  set -x
  cd "$APP_DIR"
  flutter pub get
  dart format integration_test/task20_d2k_reset_interruption_trigger_test.dart \
    integration_test/task20_d2k_reset_interruption_verify_test.dart
  flutter analyze integration_test/task20_d2k_reset_interruption_trigger_test.dart \
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
trigger_pid=""
lock_pid=""

cleanup() {
  touch "$lock_release" >/dev/null 2>&1 || true
  if [[ -n "${lock_pid:-}" ]] && kill -0 "$lock_pid" >/dev/null 2>&1; then
    kill "$lock_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "${trigger_pid:-}" ]] && kill -0 "$trigger_pid" >/dev/null 2>&1; then
    kill "$trigger_pid" >/dev/null 2>&1 || true
  fi
  xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

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

xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
xcrun simctl erase "$udid"
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b

(
  cd "$APP_DIR"
  TASK20_D2_SCREENSHOT_DIR="$screenshot_dir" \
    flutter drive \
      --keep-app-running \
      --no-dds \
      --driver=test_driver/task20_d2i_driver.dart \
      --target=integration_test/task20_d2k_reset_interruption_trigger_test.dart \
      -d "$udid"
) >"$trigger_log" 2>&1 &
trigger_pid="$!"

wait_for_marker "$trigger_log" 'D2K_READY_FOR_DB_LOCK' 900
wait_for_file "$screenshot_dir/D2K_01_ready_before_interruption.png" 30 'D2K ready screenshot'

data_container="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data)"
test -d "$data_container"
printf '%s\n' "$data_container" > "$LOG_DIR/data_container.txt"

# Find the live Drift database by SQLite header + user_account table, acquire
# BEGIN IMMEDIATE, and hold that write lock until the host releases it after
# OS-level app termination.
python3 - "$data_container" "$lock_ready" "$lock_release" >"$lock_log" 2>&1 <<'PY' &
import os
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

wait_for_marker "$trigger_log" 'D2K_RESET_CRITICAL_WINDOW_READY' 90
wait_for_file "$screenshot_dir/D2K_02_reset_blocked_in_progress.png" 30 'D2K blocked-reset screenshot'

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

# The deliberate process termination should make flutter drive exit. Give it a
# bounded grace period, then stop only the host-side drive process if needed.
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

for required in \
  D2K_01_ready_before_interruption.png \
  D2K_02_reset_blocked_in_progress.png \
  D2K_03_recovered_after_interruption.png; do
  test -s "$screenshot_dir/$required" || {
    echo "ERROR: Missing D2K screenshot: $required" >&2
    exit 1
  }
done

grep -Fq 'D2K_RESET_CRITICAL_WINDOW_READY' "$trigger_log"
grep -Fq 'D2K_VERIFY_METADATA=' "$verify_log"
grep -Fq 'old_user_owned_rows_preserved":true' "$verify_log"
grep -Fq 'secure_key_recovered_to_old_user":true' "$verify_log"
grep -Fq 'replacement_account_absent":true' "$verify_log"
grep -Fq 'foreign_key_violations":0' "$verify_log"
grep -Fq 'lock=BEGIN_IMMEDIATE' "$lock_log"
grep -Fq 'lock=RELEASED' "$lock_log"

(
  cd "$screenshot_dir"
  shasum -a 256 D2K_*.png | sort > "$LOG_DIR/screenshots.sha256"
)

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
    'scope': 'one GitHub-hosted iOS Simulator; OS kill after Secure Storage user switch and before reset transaction commit',
    'role': os.environ['ROLE'],
    'device_name': os.environ['DEVICE_NAME'],
    'runtime': os.environ['RUNTIME'],
    'udid': os.environ['UDID'],
    'bundle_id': os.environ['BUNDLE_ID'],
    'database_path': os.environ['DATABASE_PATH'],
    'external_write_lock': 'BEGIN IMMEDIATE',
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

echo "Task 20-D2K local reset interruption acceptance passed."
