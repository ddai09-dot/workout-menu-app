#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
D1_DEVICE_FILE="${TASK20_D1_DEVICE_FILE:-$APP_DIR/build/task20_d1_ios_launch_smoke/selected_devices.tsv}"
LOG_DIR="${TASK20_D2_LOG_DIR:-$APP_DIR/build/task20_d2a_ios_ui_acceptance}"
RESULT_LINES="$LOG_DIR/device_results.ndjson"
mkdir -p "$LOG_DIR"
: > "$RESULT_LINES"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Task 20-D2A iOS UI acceptance requires macOS." >&2
  exit 2
fi
for command_name in flutter dart xcrun python3 shasum; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "ERROR: $command_name was not found." >&2
    exit 2
  }
done
if [[ ! -f "$D1_DEVICE_FILE" ]]; then
  echo "ERROR: D1 selected device file was not found: $D1_DEVICE_FILE" >&2
  exit 2
fi

cp "$APP_DIR/pubspec.yaml" "$LOG_DIR/canonical_pubspec.yaml"
if [[ -f "$APP_DIR/pubspec.lock" ]]; then
  cp "$APP_DIR/pubspec.lock" "$LOG_DIR/canonical_pubspec.lock"
fi

python3 "$ROOT/tools/task20_d2a_prepare_ui_acceptance.py" "$APP_DIR"
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
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  done < "$D1_DEVICE_FILE"
}
trap cleanup EXIT

while IFS=$'\t' read -r role udid runtime device_name; do
  device_dir="$LOG_DIR/$role"
  screenshot_dir="$device_dir/screenshots"
  mkdir -p "$screenshot_dir"
  log_file="$device_dir/flutter_drive.log"

  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  xcrun simctl erase "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b

  set +e
  (
    cd "$APP_DIR"
    TASK20_D2_SCREENSHOT_DIR="$screenshot_dir" \
      flutter drive \
        --driver=test_driver/task20_d2a_driver.dart \
        --target=integration_test/task20_d2a_onboarding_reset_test.dart \
        -d "$udid"
  ) 2>&1 | tee "$log_file"
  drive_code="${PIPESTATUS[0]}"
  set -e

  if [[ "$drive_code" -ne 0 ]]; then
    ROLE="$role" DEVICE_NAME="$device_name" RUNTIME="$runtime" UDID="$udid" \
      EXIT_CODE="$drive_code" RESULT_LINES="$RESULT_LINES" python3 - <<'PY'
import json
import os
from pathlib import Path
payload = {
    "role": os.environ["ROLE"],
    "device_name": os.environ["DEVICE_NAME"],
    "runtime": os.environ["RUNTIME"],
    "udid": os.environ["UDID"],
    "status": "FAIL",
    "exit_code": int(os.environ["EXIT_CODE"]),
}
with Path(os.environ["RESULT_LINES"]).open("a", encoding="utf-8") as stream:
    stream.write(json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n")
PY
    exit "$drive_code"
  fi

  for screenshot_name in \
    D2A_01_clean_launch.png \
    D2A_02_onboarding_review.png \
    D2A_03_home_after_onboarding.png \
    D2A_04_reset_before_acknowledgement.png \
    D2A_05_after_local_reset.png; do
    test -s "$screenshot_dir/$screenshot_name"
  done
  shasum -a 256 "$screenshot_dir"/*.png > "$device_dir/screenshots.sha256"

  ROLE="$role" DEVICE_NAME="$device_name" RUNTIME="$runtime" UDID="$udid" \
    SCREENSHOT_DIR="$screenshot_dir" RESULT_LINES="$RESULT_LINES" python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path
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
    "exit_code": 0,
    "screenshots": screenshots,
}
with Path(os.environ["RESULT_LINES"]).open("a", encoding="utf-8") as stream:
    stream.write(json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n")
PY

  xcrun simctl shutdown "$udid"
done < "$D1_DEVICE_FILE"

APP_DIR="$APP_DIR" LOG_DIR="$LOG_DIR" RESULT_LINES="$RESULT_LINES" python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path
lines = Path(os.environ["RESULT_LINES"]).read_text(encoding="utf-8").splitlines()
devices = [json.loads(line) for line in lines if line.strip()]
if len(devices) != 2 or any(item.get("status") != "PASS" for item in devices):
    raise SystemExit("Expected two passing Task 20-D2A device results")
result = {
    "task": "Task 20-D2A automated iOS UI acceptance",
    "status": "PASS",
    "finished_at_utc": datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z"),
    "app_directory": os.environ["APP_DIR"],
    "devices": devices,
    "verified_cases": ["D2-01", "D2-03", "D2-09", "D2-10-partial"],
    "manual_core_flow_fully_verified": False,
    "physical_device_verified": False,
    "native_accessibility_verified": False,
}
Path(os.environ["LOG_DIR"], "result.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, ensure_ascii=False, sort_keys=True))
PY

echo "Task 20-D2A automated iOS UI acceptance passed."
