#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
D1_DEVICE_FILE="${TASK20_D1_DEVICE_FILE:-$APP_DIR/build/task20_d1_ios_launch_smoke/selected_devices.tsv}"
LOG_DIR="${TASK20_D2O_LOG_DIR:-$APP_DIR/build/task20_d2o_body_measurement_correction}"
DRIVE_TIMEOUT_SECONDS="${TASK20_D2O_DRIVE_TIMEOUT_SECONDS:-1800}"
MAX_STARTUP_ATTEMPTS="${TASK20_D2O_MAX_STARTUP_ATTEMPTS:-2}"
APP_BUNDLE="$APP_DIR/build/ios/iphonesimulator/Runner.app"

rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Task 20-D2O iOS UI acceptance requires macOS." >&2
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

python3 "$ROOT/tools/task20_d2o_prepare_ui_acceptance.py" "$APP_DIR"
(
  set -x
  cd "$APP_DIR"
  flutter pub get
  dart format integration_test/task20_d2o_body_measurement_correction_test.dart
  flutter analyze integration_test/task20_d2o_body_measurement_correction_test.dart
) 2>&1 | tee "$LOG_DIR/overlay_preflight.log"

cleanup() {
  xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

run_drive() {
  local screenshot_dir="$1"
  local drive_log="$2"
  local drive_result="$3"
  (
    cd "$APP_DIR"
    TASK20_D2_SCREENSHOT_DIR="$screenshot_dir" \
      python3 "$ROOT/tools/task20_d2a_run_with_timeout.py" \
        --timeout-seconds "$DRIVE_TIMEOUT_SECONDS" \
        --log-file "$drive_log" \
        --result-file "$drive_result" \
        -- \
        flutter drive \
          --keep-app-running \
          --no-dds \
          --driver=test_driver/task20_d2f_driver.dart \
          --target=integration_test/task20_d2o_body_measurement_correction_test.dart \
          -d "$udid"
  )
}

successful_attempt=0
final_code=1
final_log=""
final_result=""
screenshot_dir="$LOG_DIR/screenshots"
mkdir -p "$screenshot_dir"

for attempt in $(seq 1 "$MAX_STARTUP_ATTEMPTS"); do
  attempt_dir="$LOG_DIR/attempt_$attempt"
  attempt_screenshots="$attempt_dir/screenshots"
  drive_log="$attempt_dir/flutter_drive.log"
  drive_result="$attempt_dir/flutter_drive_result.json"
  rm -rf "$attempt_dir"
  mkdir -p "$attempt_screenshots"

  if [[ "$attempt" -eq 1 ]]; then
    printf '%s\n' 'fresh-erase' > "$attempt_dir/device_reset_mode.txt"
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl erase "$udid"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b
  else
    printf '%s\n' 'warm-retry-no-erase' > "$attempt_dir/device_reset_mode.txt"
    xcrun simctl boot "$udid" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$udid" -b
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl uninstall "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl keychain "$udid" reset
    xcrun simctl privacy "$udid" reset all "$BUNDLE_ID" >/dev/null 2>&1 || true
  fi

  set +e
  run_drive "$attempt_screenshots" "$drive_log" "$drive_result"
  drive_code="$?"
  set -e

  if [[ "$drive_code" -eq 0 ]]; then
    cp -R "$attempt_screenshots/." "$screenshot_dir/"
    successful_attempt="$attempt"
    final_code=0
    final_log="$drive_log"
    final_result="$drive_result"
    break
  fi

  retryable=false
  if [[ -z "$(find "$attempt_screenshots" -type f -name 'D2O_*.png' -print -quit)" ]] && \
    grep -Eqi \
      'Application failed to start|Error waiting for a debug connection|log reader failed unexpectedly|Unable to launch|Failed to start' \
      "$drive_log"; then
    retryable=true
  fi

  final_code="$drive_code"
  final_log="$drive_log"
  final_result="$drive_result"
  if [[ "$retryable" == true && "$attempt" -lt "$MAX_STARTUP_ATTEMPTS" ]]; then
    echo "Task 20-D2O startup infrastructure failure; retrying warm before any D2O evidence exists."
    continue
  fi
  break
done

printf '%s\n' "$successful_attempt" > "$LOG_DIR/successful_attempt.txt"
cp "$final_log" "$LOG_DIR/flutter_drive.log"
cp "$final_result" "$LOG_DIR/flutter_drive_result.json"
if [[ "$final_code" -ne 0 ]]; then
  exit "$final_code"
fi

for required in \
  D2O_01_original_measurement.png \
  D2O_02_correction_editor_prefilled.png \
  D2O_03_corrected_measurement.png \
  D2O_04_dashboard_uses_correction.png; do
  test -s "$screenshot_dir/$required" || {
    echo "ERROR: Missing D2O screenshot: $required" >&2
    exit 1
  }
done

grep -Fq 'D2O_VERIFY_METADATA=' "$LOG_DIR/flutter_drive.log"
grep -Fq '"original_voided":true' "$LOG_DIR/flutter_drive.log"
grep -Fq '"corrected_supersedes_original":true' "$LOG_DIR/flutter_drive.log"
grep -Fq '"active_measurement_count":1' "$LOG_DIR/flutter_drive.log"
grep -Fq '"measured_at_preserved":true' "$LOG_DIR/flutter_drive.log"
grep -Fq '"dashboard_uses_correction":true' "$LOG_DIR/flutter_drive.log"

(
  cd "$screenshot_dir"
  shasum -a 256 D2O_*.png | sort > "$LOG_DIR/screenshots.sha256"
)

ROLE="$role" UDID="$udid" RUNTIME="$runtime" DEVICE_NAME="$device_name" \
BUNDLE_ID="$BUNDLE_ID" SUCCESSFUL_ATTEMPT="$successful_attempt" LOG_DIR="$LOG_DIR" \
python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

log_dir = Path(os.environ["LOG_DIR"])
result = {
    "task": "Task 20-D2O body measurement correction acceptance",
    "status": "PASS",
    "scope": "one GitHub-hosted iOS Simulator; manual measurement correction preserves audit history using voided_at plus supersedes_id",
    "role": os.environ["ROLE"],
    "device_name": os.environ["DEVICE_NAME"],
    "runtime": os.environ["RUNTIME"],
    "udid": os.environ["UDID"],
    "bundle_id": os.environ["BUNDLE_ID"],
    "successful_attempt": int(os.environ["SUCCESSFUL_ATTEMPT"]),
    "original_measurement_voided": True,
    "replacement_supersedes_original": True,
    "single_active_measurement_after_correction": True,
    "measured_at_preserved": True,
    "dashboard_uses_corrected_measurement": True,
    "screenshots": [
        "D2O_01_original_measurement.png",
        "D2O_02_correction_editor_prefilled.png",
        "D2O_03_corrected_measurement.png",
        "D2O_04_dashboard_uses_correction.png",
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

echo "Task 20-D2O body-measurement correction acceptance passed."
