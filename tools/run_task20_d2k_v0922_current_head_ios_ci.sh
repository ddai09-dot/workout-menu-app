#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

# Keep the already accepted v0.9.22 D2J regression lane intact, then add the
# D2-08 local-reset interruption acceptance on the same exact candidate.
bash tools/run_task20_d2j_v0922_current_head_ios_ci.sh

# The D2J runner installs the pinned Flutter SDK and exports PATH only inside
# its child shell. Restore that exact SDK path in this parent shell before D2K.
flutter_result_file="$ROOT/app/build/task20_b_logs/ios/flutter_sdk_install.json"
if [[ ! -s "$flutter_result_file" ]]; then
  echo "ERROR: Flutter SDK install result missing after D2J: $flutter_result_file" >&2
  exit 2
fi
flutter_bin_directory="$(python3 -c 'import json,sys; from pathlib import Path; print(Path(json.load(open(sys.argv[1], encoding="utf-8"))["flutter_bin"]).parent)' "$flutter_result_file")"
test -x "$flutter_bin_directory/flutter"
test -x "$flutter_bin_directory/dart"
export PATH="$flutter_bin_directory:$PATH"

# D2A..D2J acceptance helpers intentionally overlay files under app/. D2K's
# SecureStore instrumentation must start from the canonical v0.9.22 source,
# otherwise a previous lane can invalidate its exact source precondition.
# Preserve all prior CI evidence/build products and the D2J-generated iOS host
# project, restore the exact candidate package, then put both generated trees
# back before D2K starts. The canonical ZIP intentionally does not contain ios/.
candidate_zip="$ROOT/implementation-v0.9.22.zip"
expected_candidate_sha="714b56ed1f074f22a500932719d75398ecfbc1c853da74e01eda85c4601fa6eb"
if [[ ! -s "$candidate_zip" ]]; then
  echo "ERROR: canonical v0.9.22 candidate ZIP missing after D2J: $candidate_zip" >&2
  exit 2
fi
actual_candidate_sha="$(shasum -a 256 "$candidate_zip" | awk '{print $1}')"
if [[ "$actual_candidate_sha" != "$expected_candidate_sha" ]]; then
  echo "ERROR: canonical v0.9.22 candidate ZIP SHA mismatch: $actual_candidate_sha" >&2
  exit 2
fi

preserve_root="$(mktemp -d "$ROOT/.task20-d2k-preserve.XXXXXX")"
if [[ ! -d "$ROOT/app/build" ]]; then
  echo "ERROR: D2J build/evidence tree missing before D2K source reset." >&2
  rm -rf "$preserve_root"
  exit 2
fi
if [[ ! -f "$ROOT/app/ios/Runner.xcodeproj/project.pbxproj" ]]; then
  echo "ERROR: D2J-generated iOS host project missing before D2K source reset." >&2
  rm -rf "$preserve_root"
  exit 2
fi
mv "$ROOT/app/build" "$preserve_root/build"
mv "$ROOT/app/ios" "$preserve_root/ios"
if ! (
  rm -rf "$ROOT/app"
  mkdir -p "$ROOT/app"
  unzip -q "$candidate_zip" -d "$ROOT/app"
); then
  echo "ERROR: failed to restore canonical v0.9.22 source for D2K." >&2
  mkdir -p "$ROOT/app"
  rm -rf "$ROOT/app/build" "$ROOT/app/ios"
  mv "$preserve_root/build" "$ROOT/app/build"
  mv "$preserve_root/ios" "$ROOT/app/ios"
  rm -rf "$preserve_root"
  exit 2
fi
mv "$preserve_root/build" "$ROOT/app/build"
mv "$preserve_root/ios" "$ROOT/app/ios"
rm -rf "$preserve_root"

if [[ ! -f "$ROOT/app/ios/Runner.xcodeproj/project.pbxproj" ]]; then
  echo "ERROR: D2J-generated iOS host project was not restored after D2K source reset." >&2
  exit 2
fi

# Reapply the exact accepted CI-only lock after the canonical source reset.
# This does not modify the product ZIP or pubspec.yaml.
python3 tools/task20_restore_v0922_ci_lock.py "$ROOT/app"

# The exact SecureStore marker is the contract consumed by the D2K overlay.
# Fail here with explicit evidence instead of an opaque overlay-preflight exit.
secure_store_file="$ROOT/app/lib/core/security/secure_store.dart"
source_reset_marker_count="$(python3 - "$secure_store_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = """  @override
  Future<void> write({
    required String key,
    required String value,
  }) {
    return _storage.write(key: key, value: value);
  }
"""
print(text.count(marker))
PY
)"
if [[ "$source_reset_marker_count" != "1" ]]; then
  echo "ERROR: D2K SecureStore marker count after canonical source reset: $source_reset_marker_count" >&2
  exit 2
fi

# app/build and the generated iOS host project were restored, so the pinned
# Flutter record, accepted D2J evidence, and an executable flutter-drive host
# project remain available while Dart product source is canonical v0.9.22.
flutter_result_file="$ROOT/app/build/task20_b_logs/ios/flutter_sdk_install.json"
test -s "$flutter_result_file"

d2k_log_dir="$ROOT/app/build/task20_d2k_reset_interruption"
wrapper_log_dir="$ROOT/app/build/task20_d2k_wrapper"
mkdir -p "$d2k_log_dir" "$wrapper_log_dir"
rm -rf "$wrapper_log_dir"/*
{
  echo "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "source_reset=canonical_v0.9.22_zip"
  echo "candidate_zip=$candidate_zip"
  echo "candidate_sha256=$actual_candidate_sha"
  echo "pubspec_lock_sha256=$(shasum -a 256 "$ROOT/app/pubspec.lock" | awk '{print $1}')"
  echo "secure_store_sha256=$(shasum -a 256 "$secure_store_file" | awk '{print $1}')"
  echo "secure_store_marker_count=$source_reset_marker_count"
  echo "d2j_build_evidence_restored=true"
  echo "d2j_generated_ios_restored=true"
  echo "ios_project_file=$ROOT/app/ios/Runner.xcodeproj/project.pbxproj"
  echo "ios_project_sha256=$(shasum -a 256 "$ROOT/app/ios/Runner.xcodeproj/project.pbxproj" | awk '{print $1}')"
} > "$wrapper_log_dir/source_reset_preflight.log"

write_wrapper_preflight() {
  local attempt="$1"
  {
    echo "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "attempt=$attempt"
    echo "flutter=$(command -v flutter)"
    echo "dart=$(command -v dart)"
    echo "python3=$(command -v python3)"
    echo "xcrun=$(command -v xcrun)"
    echo "plutil=$(command -v plutil)"
    echo "shasum=$(command -v shasum)"
    echo "pwd=$(pwd)"
    echo "path=$PATH"
  } > "$wrapper_log_dir/preflight_attempt_${attempt}.log"
}

snapshot_attempt() {
  local attempt="$1"
  local destination="$wrapper_log_dir/attempt_${attempt}"
  rm -rf "$destination"
  mkdir -p "$destination"
  if [[ -d "$d2k_log_dir" ]]; then
    cp -R "$d2k_log_dir/." "$destination/" 2>/dev/null || true
  fi
}

is_retryable_trigger_startup_failure() {
  local log_file="$d2k_log_dir/trigger_flutter_drive.log"
  [[ -f "$log_file" ]] || return 1
  if grep -Fq 'D2K_READY_FOR_DB_LOCK' "$log_file"; then
    return 1
  fi
  grep -Eqi \
    'Application failed to start|Error waiting for a debug connection|log reader failed unexpectedly|Unable to launch|Failed to start' \
    "$log_file"
}

max_attempts=3
for attempt in $(seq 1 "$max_attempts"); do
  write_wrapper_preflight "$attempt"
  echo "Task 20-D2K wrapper attempt $attempt/$max_attempts"

  set +e
  TASK20_D2K_TRIGGER_TIMEOUT_SECONDS=1200 \
  TASK20_D2K_VERIFY_TIMEOUT_SECONDS=600 \
  TASK20_D2K_LOG_DIR="$d2k_log_dir" \
    bash tools/run_task20_d2k_ios_ui_acceptance.sh "$ROOT/app"
  d2k_exit_code="$?"
  set -e

  snapshot_attempt "$attempt"
  printf '%s\n' "$d2k_exit_code" > "$wrapper_log_dir/attempt_${attempt}_exit_code.txt"

  if [[ "$d2k_exit_code" -eq 0 ]]; then
    cat > "$wrapper_log_dir/result.json" <<JSON
{
  "task": "Task 20-D2K wrapper",
  "status": "PASS",
  "attempts": $attempt,
  "final_exit_code": 0
}
JSON
    exit 0
  fi

  if is_retryable_trigger_startup_failure && [[ "$attempt" -lt "$max_attempts" ]]; then
    echo "Task 20-D2K trigger hit a GitHub-hosted Simulator startup failure; retrying from a clean D2K run."
    continue
  fi

  cat > "$wrapper_log_dir/result.json" <<JSON
{
  "task": "Task 20-D2K wrapper",
  "status": "FAIL",
  "attempts": $attempt,
  "final_exit_code": $d2k_exit_code,
  "retryable_trigger_startup_failure": $(is_retryable_trigger_startup_failure && echo true || echo false)
}
JSON
  exit "$d2k_exit_code"
done

echo "ERROR: Task 20-D2K wrapper exhausted startup attempts." >&2
exit 1
