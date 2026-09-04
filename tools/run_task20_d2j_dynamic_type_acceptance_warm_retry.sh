#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$ROOT/app}"
LOG_DIR="${TASK20_D2J_LOG_DIR:-$APP_DIR/build/task20_d2j_dynamic_type}"
SOURCE_RUNNER="$ROOT/tools/run_task20_d2j_dynamic_type_acceptance.sh"
# Keep the generated runner under repo-root/tools so its own BASH_SOURCE-based
# ROOT calculation remains identical to the canonical source runner.
PATCHED_RUNNER="$ROOT/tools/.task20_d2j_dynamic_type_acceptance_warm_retry.generated.sh"
PATCH_METADATA="$LOG_DIR/warm_retry_patch_metadata.json"

mkdir -p "$LOG_DIR"
trap 'rm -f "$PATCHED_RUNNER"' EXIT

python3 - "$SOURCE_RUNNER" "$PATCHED_RUNNER" "$PATCH_METADATA" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
metadata_path = Path(sys.argv[3])
raw = source.read_bytes()
blob_sha = hashlib.sha1(
    b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw
).hexdigest()
expected_blob_sha = "c17c2ea34623a9e36840bf8d405a5f2285fae869"
if blob_sha != expected_blob_sha:
    raise SystemExit(
        f"Unexpected D2J runner blob SHA: {blob_sha}; expected {expected_blob_sha}"
    )

text = raw.decode("utf-8")
old_attempt_var = 'MAX_STARTUP_ATTEMPTS="${TASK20_D2J_MAX_STARTUP_ATTEMPTS:-2}"\n'
new_attempt_var = (
    old_attempt_var
    + 'D2D_PHASE1_MAX_STARTUP_ATTEMPTS="${TASK20_D2J_D2D_PHASE1_MAX_STARTUP_ATTEMPTS:-3}"\n'
)
if text.count(old_attempt_var) != 1:
    raise SystemExit("Expected exactly one D2J startup-attempt variable")
text = text.replace(old_attempt_var, new_attempt_var, 1)

old_function = '''prepare_fresh_device() {
  local evidence_dir="$1"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl erase "$UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b
  bash "$ROOT/tools/task20_d2j_apply_dynamic_type.sh" "$UDID" "$evidence_dir"
}
'''
new_function = '''prepare_fresh_device() {
  local evidence_dir="$1"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl erase "$UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b
  bash "$ROOT/tools/task20_d2j_apply_dynamic_type.sh" "$UDID" "$evidence_dir"
}

prepare_warm_retry_device() {
  local evidence_dir="$1"
  # A retry after a confirmed Flutter debug-attach startup failure must not
  # erase the Simulator again. The failed app is removed, keychain state is
  # reset, and the already-booted Simulator is reused so CoreSimulator/logd
  # services remain warm while app-local state is cleared.
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$UDID" -b
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl keychain "$UDID" reset
  xcrun simctl privacy "$UDID" reset all "$BUNDLE_ID" >/dev/null 2>&1 || true
  bash "$ROOT/tools/task20_d2j_apply_dynamic_type.sh" "$UDID" "$evidence_dir"
}

prepare_device_for_attempt() {
  local attempt="$1"
  local evidence_dir="$2"
  mkdir -p "$evidence_dir"
  if [[ "$attempt" -eq 1 ]]; then
    printf '%s\n' 'fresh-erase' > "$evidence_dir/device_reset_mode.txt"
    prepare_fresh_device "$evidence_dir"
  else
    printf '%s\n' 'warm-retry-no-erase' > "$evidence_dir/device_reset_mode.txt"
    prepare_warm_retry_device "$evidence_dir"
  fi
}
'''
if text.count(old_function) != 1:
    raise SystemExit("Expected exactly one prepare_fresh_device function block")
text = text.replace(old_function, new_function, 1)
old_call = '    prepare_fresh_device "$attempt_dir/dynamic_type"\n'
new_call = '    prepare_device_for_attempt "$attempt" "$attempt_dir/dynamic_type"\n'
call_count = text.count(old_call)
if call_count != 2:
    raise SystemExit(
        f"Expected exactly two fresh-device attempt calls; found {call_count}"
    )
text = text.replace(old_call, new_call)

# The latest failed exact-head run exhausted two D2D phase-1 attempts before
# the test connected to the VM service. Allow one additional attempt only for
# this phase; its existing retry predicate still requires a pre-test startup
# failure with zero screenshots, so app/test assertion failures are not retried.
d2d_start = text.index("run_d2d_case() {")
phase2_start = text.index("  local phase2_success=0", d2d_start)
phase1 = text[d2d_start:phase2_start]
old_loop = '  for attempt in $(seq 1 "$MAX_STARTUP_ATTEMPTS"); do\n'
if phase1.count(old_loop) != 1:
    raise SystemExit("Expected exactly one D2D phase1 attempt loop")
phase1 = phase1.replace(
    old_loop,
    '  for attempt in $(seq 1 "$D2D_PHASE1_MAX_STARTUP_ATTEMPTS"); do\n',
    1,
)
old_limit = '       [[ "$attempt" -lt "$MAX_STARTUP_ATTEMPTS" ]]; then\n'
if phase1.count(old_limit) != 1:
    raise SystemExit("Expected exactly one D2D phase1 retry limit")
phase1 = phase1.replace(
    old_limit,
    '       [[ "$attempt" -lt "$D2D_PHASE1_MAX_STARTUP_ATTEMPTS" ]]; then\n',
    1,
)
text = text[:d2d_start] + phase1 + text[phase2_start:]

destination.write_text(text, encoding="utf-8")
metadata_path.write_text(
    json.dumps(
        {
            "status": "PASS",
            "source_runner": str(source),
            "source_git_blob_sha1": blob_sha,
            "expected_source_git_blob_sha1": expected_blob_sha,
            "generated_runner": str(destination),
            "generated_runner_location_preserves_repo_root": True,
            "fresh_attempt_calls_replaced": call_count,
            "retry_reset_mode": "warm-retry-no-erase",
            "d2d_phase1_max_startup_attempts": 3,
            "d2d_phase1_retry_scope": "pre-test debug launch failures with zero screenshots only",
            "test_or_app_failures_retried": False,
            "warm_retry_resets": [
                "app process terminate",
                "app uninstall",
                "simulator keychain reset",
                "app privacy reset best-effort",
                "Dynamic Type reapply",
            ],
            "canonical_package_changed": False,
            "product_runtime_changed": False,
        },
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
PY

chmod +x "$PATCHED_RUNNER"
bash -n "$PATCHED_RUNNER"
bash "$PATCHED_RUNNER" "$APP_DIR"
