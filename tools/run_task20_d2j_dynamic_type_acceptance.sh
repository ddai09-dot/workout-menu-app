#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
D1_DEVICE_FILE="${TASK20_D1_DEVICE_FILE:-$APP_DIR/build/task20_d1_ios_launch_smoke/selected_devices.tsv}"
LOG_DIR="${TASK20_D2J_LOG_DIR:-$APP_DIR/build/task20_d2j_dynamic_type}"
DRIVE_TIMEOUT_SECONDS="${TASK20_D2J_DRIVE_TIMEOUT_SECONDS:-1800}"
MAX_STARTUP_ATTEMPTS="${TASK20_D2J_MAX_STARTUP_ATTEMPTS:-2}"
TARGET_CATEGORY="accessibility-extra-large"
APP_BUNDLE="$APP_DIR/build/ios/iphonesimulator/Runner.app"
AGGREGATE_SCREENSHOTS="$LOG_DIR/screenshots"
mkdir -p "$LOG_DIR" "$AGGREGATE_SCREENSHOTS"
rm -rf "$AGGREGATE_SCREENSHOTS"
mkdir -p "$AGGREGATE_SCREENSHOTS"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Task20-D2J iOS Dynamic Type acceptance requires macOS." >&2
  exit 2
fi
for command_name in flutter dart xcrun python3 shasum plutil awk grep; do
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

selected_line="$(awk -F '\t' '$1 == "compact" { print; exit }' "$D1_DEVICE_FILE")"
if [[ -z "$selected_line" ]]; then
  echo "ERROR: D2J requires the D1 compact-role Simulator selection." >&2
  exit 2
fi
printf '%s\n' "$selected_line" > "$LOG_DIR/selected_device.tsv"
IFS=$'\t' read -r ROLE UDID RUNTIME DEVICE_NAME <<< "$selected_line"
if [[ -z "${UDID:-}" || -z "${DEVICE_NAME:-}" ]]; then
  echo "ERROR: invalid selected-device row: $selected_line" >&2
  exit 2
fi

cp "$APP_DIR/pubspec.yaml" "$LOG_DIR/canonical_pubspec.yaml"
if [[ -f "$APP_DIR/pubspec.lock" ]]; then
  cp "$APP_DIR/pubspec.lock" "$LOG_DIR/canonical_pubspec.lock"
fi

# Reuse the already accepted UI fixtures instead of inventing duplicate D2J flows.
python3 "$ROOT/tools/task20_d2a_prepare_ui_acceptance.py" "$APP_DIR"
python3 "$ROOT/tools/task20_d2d_prepare_ui_acceptance.py" "$APP_DIR"
python3 "$ROOT/tools/task20_d2e_prepare_ui_acceptance.py" "$APP_DIR"
python3 "$ROOT/tools/task20_d2g_prepare_ui_acceptance.py" "$APP_DIR"
python3 "$ROOT/tools/task20_d2j_inject_basic_info_screenshot.py" "$APP_DIR"
(
  set -x
  cd "$APP_DIR"
  flutter pub get
  dart format integration_test test_driver
  flutter analyze integration_test
  flutter analyze test_driver
) 2>&1 | tee "$LOG_DIR/overlay_preflight.log"

cleanup() {
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

capture_diagnostics() {
  local destination="$1"
  mkdir -p "$destination"
  xcrun simctl list > "$destination/simctl_list.txt" 2>&1 || true
  xcrun simctl listapps "$UDID" > "$destination/listapps.txt" 2>&1 || true
  xcrun simctl spawn "$UDID" log show \
    --style compact \
    --last 25m \
    --predicate 'process == "Runner" OR eventMessage CONTAINS[c] "Runner" OR eventMessage CONTAINS[c] "workout"' \
    > "$destination/simulator_recent.log" 2>&1 || true
}

prepare_fresh_device() {
  local evidence_dir="$1"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl erase "$UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b
  bash "$ROOT/tools/task20_d2j_apply_dynamic_type.sh" "$UDID" "$evidence_dir"
}

assert_no_overflow() {
  local log_file="$1"
  if grep -Eqi \
    'A RenderFlex overflowed|EXCEPTION CAUGHT BY RENDERING LIBRARY|overflowed by [0-9]+ pixels|ErrorWidget' \
    "$log_file"; then
    echo "ERROR: rendering overflow/ErrorWidget signal found in $log_file" >&2
    return 1
  fi
}

is_retryable_startup_failure() {
  local log_file="$1"
  local screenshot_dir="$2"
  [[ -z "$(find "$screenshot_dir" -type f -name '*.png' -print -quit)" ]] && \
    grep -Eqi \
      'Application failed to start|Error waiting for a debug connection|log reader failed unexpectedly|Unable to launch|Failed to start' \
      "$log_file"
}

run_fresh_case() {
  local case_id="$1"
  local driver="$2"
  local target="$3"
  local expected_pattern="$4"
  local case_dir="$LOG_DIR/$case_id"
  local final_screenshots="$case_dir/screenshots"
  rm -rf "$case_dir"
  mkdir -p "$final_screenshots"

  local final_code=1
  local successful_attempt=0
  local final_result_file=""
  for attempt in $(seq 1 "$MAX_STARTUP_ATTEMPTS"); do
    local attempt_dir="$case_dir/attempt_$attempt"
    local screenshot_dir="$attempt_dir/screenshots"
    local drive_log="$attempt_dir/flutter_drive.log"
    local drive_result="$attempt_dir/flutter_drive_result.json"
    mkdir -p "$screenshot_dir"

    prepare_fresh_device "$attempt_dir/dynamic_type"
    set +e
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
            --driver="$driver" \
            --target="$target" \
            -d "$UDID"
    )
    local code="$?"
    set -e

    if [[ "$code" -eq 0 ]]; then
      assert_no_overflow "$drive_log"
      if [[ -z "$(find "$screenshot_dir" -type f -name "$expected_pattern" -print -quit)" ]]; then
        echo "ERROR: expected screenshot pattern $expected_pattern was not produced for $case_id" >&2
        return 1
      fi
      cp -R "$screenshot_dir/." "$final_screenshots/"
      cp -R "$attempt_dir/dynamic_type" "$case_dir/dynamic_type"
      cp "$drive_log" "$case_dir/flutter_drive.log"
      cp "$drive_result" "$case_dir/flutter_drive_result.json"
      successful_attempt="$attempt"
      final_result_file="$case_dir/flutter_drive_result.json"
      final_code=0
      break
    fi

    capture_diagnostics "$attempt_dir/simulator_diagnostics"
    if is_retryable_startup_failure "$drive_log" "$screenshot_dir" && \
       [[ "$attempt" -lt "$MAX_STARTUP_ATTEMPTS" ]]; then
      echo "Task20-D2J $case_id startup infrastructure failure; retrying clean attempt."
      continue
    fi
    final_code="$code"
    break
  done

  if [[ "$final_code" -ne 0 ]]; then
    echo "ERROR: Task20-D2J $case_id failed." >&2
    return "$final_code"
  fi
  printf '%s\n' "$successful_attempt" > "$case_dir/successful_attempt.txt"
  test -s "$final_result_file"
  cp "$final_screenshots"/*.png "$AGGREGATE_SCREENSHOTS/"
}

run_d2d_case() {
  local case_dir="$LOG_DIR/d2d"
  local final_screenshots="$case_dir/screenshots"
  rm -rf "$case_dir"
  mkdir -p "$final_screenshots"

  local phase1_result=""
  local phase1_success=0
  for attempt in $(seq 1 "$MAX_STARTUP_ATTEMPTS"); do
    local attempt_dir="$case_dir/phase1_attempt_$attempt"
    local screenshot_dir="$attempt_dir/screenshots"
    local drive_log="$attempt_dir/flutter_drive.log"
    local drive_result="$attempt_dir/flutter_drive_result.json"
    mkdir -p "$screenshot_dir"
    prepare_fresh_device "$attempt_dir/dynamic_type"

    set +e
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
            --driver=test_driver/task20_d2d_driver.dart \
            --target=integration_test/task20_d2d_weekly_planner_prepare_test.dart \
            -d "$UDID"
    )
    local code="$?"
    set -e
    if [[ "$code" -eq 0 && -s "$screenshot_dir/D2D_01_adjustment_saved.png" ]]; then
      assert_no_overflow "$drive_log"
      cp "$screenshot_dir/D2D_01_adjustment_saved.png" "$final_screenshots/"
      cp -R "$attempt_dir/dynamic_type" "$case_dir/dynamic_type_phase1"
      cp "$drive_log" "$case_dir/phase1_flutter_drive.log"
      cp "$drive_result" "$case_dir/phase1_flutter_drive_result.json"
      phase1_result="$case_dir/phase1_flutter_drive_result.json"
      phase1_success="$attempt"
      break
    fi
    capture_diagnostics "$attempt_dir/simulator_diagnostics"
    if [[ "$code" -ne 0 ]] && is_retryable_startup_failure "$drive_log" "$screenshot_dir" && \
       [[ "$attempt" -lt "$MAX_STARTUP_ATTEMPTS" ]]; then
      continue
    fi
    echo "ERROR: Task20-D2J D2D phase1 failed." >&2
    return 1
  done
  [[ "$phase1_success" -gt 0 && -s "$phase1_result" ]]

  {
    echo "bundle_id=$BUNDLE_ID"
    echo "phase1_keep_app_running=true"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID"
    echo "os_level_terminate=PASS"
  } > "$case_dir/process_restart.log" 2>&1

  local phase2_success=0
  local phase2_result=""
  for attempt in $(seq 1 "$MAX_STARTUP_ATTEMPTS"); do
    local attempt_dir="$case_dir/phase2_attempt_$attempt"
    local screenshot_dir="$attempt_dir/screenshots"
    local drive_log="$attempt_dir/flutter_drive.log"
    local drive_result="$attempt_dir/flutter_drive_result.json"
    mkdir -p "$screenshot_dir"
    xcrun simctl bootstatus "$UDID" -b
    bash "$ROOT/tools/task20_d2j_apply_dynamic_type.sh" "$UDID" "$attempt_dir/dynamic_type"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    sleep 2

    set +e
    (
      cd "$APP_DIR"
      TASK20_D2_SCREENSHOT_DIR="$screenshot_dir" \
        python3 "$ROOT/tools/task20_d2a_run_with_timeout.py" \
          --timeout-seconds "$DRIVE_TIMEOUT_SECONDS" \
          --log-file "$drive_log" \
          --result-file="$drive_result" \
          -- \
          flutter drive \
            --keep-app-running \
            --no-dds \
            --driver=test_driver/task20_d2d_driver.dart \
            --target=integration_test/task20_d2d_weekly_planner_verify_test.dart \
            -d "$UDID"
    )
    local code="$?"
    set -e
    if [[ "$code" -eq 0 && -s "$screenshot_dir/D2D_06_final_menu.png" ]]; then
      assert_no_overflow "$drive_log"
      cp -R "$screenshot_dir/." "$final_screenshots/"
      cp -R "$attempt_dir/dynamic_type" "$case_dir/dynamic_type_phase2"
      cp "$drive_log" "$case_dir/phase2_flutter_drive.log"
      cp "$drive_result" "$case_dir/phase2_flutter_drive_result.json"
      phase2_result="$case_dir/phase2_flutter_drive_result.json"
      phase2_success="$attempt"
      break
    fi
    capture_diagnostics "$attempt_dir/simulator_diagnostics"
    if [[ "$code" -ne 0 ]] && is_retryable_startup_failure "$drive_log" "$screenshot_dir" && \
       [[ "$attempt" -lt "$MAX_STARTUP_ATTEMPTS" ]]; then
      continue
    fi
    echo "ERROR: Task20-D2J D2D phase2 failed." >&2
    return 1
  done
  [[ "$phase2_success" -gt 0 && -s "$phase2_result" ]]
  printf '%s\n' "$phase1_success" > "$case_dir/phase1_successful_attempt.txt"
  printf '%s\n' "$phase2_success" > "$case_dir/phase2_successful_attempt.txt"
  cp "$final_screenshots"/*.png "$AGGREGATE_SCREENSHOTS/"
}

run_fresh_case \
  d2a \
  test_driver/task20_d2a_driver.dart \
  integration_test/task20_d2a_onboarding_reset_test.dart \
  'D2J_02_basic_info_large.png'

run_d2d_case

run_fresh_case \
  d2e \
  test_driver/task20_d2e_driver.dart \
  integration_test/task20_d2e_workout_core_flow_test.dart \
  'D2E_03_session.png'

run_fresh_case \
  d2g \
  test_driver/task20_d2g_driver.dart \
  integration_test/task20_d2g_my_page_settings_test.dart \
  'D2G_01_my_page_sections_top.png'

for required in \
  D2A_01_clean_launch.png \
  D2J_02_basic_info_large.png \
  D2D_06_final_menu.png \
  D2E_03_session.png \
  D2G_01_my_page_sections_top.png; do
  test -s "$AGGREGATE_SCREENSHOTS/$required"
done

shasum -a 256 "$AGGREGATE_SCREENSHOTS"/*.png > "$LOG_DIR/screenshots.sha256"

APP_DIR="$APP_DIR" LOG_DIR="$LOG_DIR" SCREENSHOT_DIR="$AGGREGATE_SCREENSHOTS" \
  ROLE="$ROLE" UDID="$UDID" RUNTIME="$RUNTIME" DEVICE_NAME="$DEVICE_NAME" \
  TARGET_CATEGORY="$TARGET_CATEGORY" python3 - <<'PY'
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

root = Path(os.environ["LOG_DIR"])
screenshot_dir = Path(os.environ["SCREENSHOT_DIR"])

def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))

screenshots = []
for path in sorted(screenshot_dir.glob("*.png")):
    screenshots.append({
        "name": path.name,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "size_bytes": path.stat().st_size,
    })

required = {
    "intro": "D2A_01_clean_launch.png",
    "basic_info": "D2J_02_basic_info_large.png",
    "menu": "D2D_06_final_menu.png",
    "workout": "D2E_03_session.png",
    "my_page": "D2G_01_my_page_sections_top.png",
}
for label, name in required.items():
    if not (screenshot_dir / name).is_file():
        raise SystemExit(f"Missing required D2J {label} screenshot: {name}")

result = {
    "task": "Task20-D2J Dynamic Type core-flow acceptance",
    "status": "PASS",
    "finished_at_utc": datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z"),
    "app_directory": os.environ["APP_DIR"],
    "device": {
        "role": os.environ["ROLE"],
        "udid": os.environ["UDID"],
        "runtime": os.environ["RUNTIME"],
        "device_name": os.environ["DEVICE_NAME"],
    },
    "content_size_category": os.environ["TARGET_CATEGORY"],
    "content_size_set_via_simctl": True,
    "component_results": {
        "d2a": load(root / "d2a" / "flutter_drive_result.json"),
        "d2d_phase1": load(root / "d2d" / "phase1_flutter_drive_result.json"),
        "d2d_phase2": load(root / "d2d" / "phase2_flutter_drive_result.json"),
        "d2e": load(root / "d2e" / "flutter_drive_result.json"),
        "d2g": load(root / "d2g" / "flutter_drive_result.json"),
    },
    "required_screen_evidence": required,
    "screenshots": screenshots,
    "verified_cases": ["D2-11"],
    "verified_behaviors": [
        "enlarged accessibility text category applied on the D1 compact-role iOS Simulator",
        "onboarding intro remains reachable and usable",
        "basic information screen remains reachable and usable",
        "weekly menu flow remains reachable and usable",
        "workout flow remains reachable and usable",
        "My Page flow remains reachable and usable",
        "major controls remain reachable through the existing accepted UI flows",
        "no rendering-overflow or ErrorWidget signal appears in accepted drive logs",
    ],
    "acceptance_boundary": {
        "minimum_devices_required_by_issue": 1,
        "tested_devices": 1,
        "tested_enlarged_categories": [os.environ["TARGET_CATEGORY"]],
        "detailed_dynamic_type_matrix_fully_verified": False,
        "physical_device_verified": False,
        "native_accessibility_verified": False,
        "task20_d2_fully_verified": False,
    },
}
(root / "result.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, ensure_ascii=False, sort_keys=True))
PY

echo "Task20-D2J Dynamic Type acceptance passed for $DEVICE_NAME at $TARGET_CATEGORY."
