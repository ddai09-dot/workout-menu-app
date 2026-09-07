#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
SOURCE_RUNNER="$ROOT/tools/run_task20_d2a_ios_ui_acceptance.sh"
PATCHED_RUNNER="$ROOT/tools/.task20_d2a_ios_ui_acceptance_warm_retry.generated.sh"

trap 'rm -f "$PATCHED_RUNNER"' EXIT

python3 - "$SOURCE_RUNNER" "$PATCHED_RUNNER" <<'PY'
import hashlib
import sys
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
raw = source.read_bytes()
blob_sha = hashlib.sha1(
    b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw
).hexdigest()
expected_blob_sha = "a74bdbf2f8bfe345581a3410ef7fec3395f764ed"
if blob_sha != expected_blob_sha:
    raise SystemExit(
        f"Unexpected D2A runner blob SHA: {blob_sha}; expected {expected_blob_sha}"
    )

text = raw.decode("utf-8")
old = '''    echo "Task 20-D2A attempt $attempt/$MAX_STARTUP_ATTEMPTS: role=$role device=$device_name"
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl erase "$udid"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b
'''
new = '''    echo "Task 20-D2A attempt $attempt/$MAX_STARTUP_ATTEMPTS: role=$role device=$device_name"
    if [[ "$attempt" -eq 1 ]]; then
      printf '%s\\n' 'fresh-erase' > "$attempt_dir/device_reset_mode.txt"
      xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
      xcrun simctl erase "$udid"
      xcrun simctl boot "$udid"
      xcrun simctl bootstatus "$udid" -b
    else
      # Retry only occurs after the runner has classified a pre-test Flutter
      # debug-attach/startup failure with zero screenshots. Reuse the already
      # booted Simulator so CoreSimulator/logd services stay warm while app-
      # local state is cleared. Product/test assertions are unchanged.
      printf '%s\\n' 'warm-retry-no-erase' > "$attempt_dir/device_reset_mode.txt"
      xcrun simctl boot "$udid" >/dev/null 2>&1 || true
      xcrun simctl bootstatus "$udid" -b
      bundle_id="$(plutil -extract CFBundleIdentifier raw "$APP_DIR/build/ios/iphonesimulator/Runner.app/Info.plist")"
      xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
      xcrun simctl uninstall "$udid" "$bundle_id" >/dev/null 2>&1 || true
      xcrun simctl keychain "$udid" reset
      xcrun simctl privacy "$udid" reset all "$bundle_id" >/dev/null 2>&1 || true
    fi
'''
if text.count(old) != 1:
    raise SystemExit(f"Expected one D2A fresh-attempt block, found {text.count(old)}")
text = text.replace(old, new, 1)
destination.write_text(text, encoding="utf-8")
PY

chmod +x "$PATCHED_RUNNER"
bash -n "$PATCHED_RUNNER"
bash "$PATCHED_RUNNER" "$APP_DIR"
