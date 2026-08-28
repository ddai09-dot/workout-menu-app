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

d2k_log_dir="$ROOT/app/build/task20_d2k_reset_interruption"
wrapper_log_dir="$ROOT/app/build/task20_d2k_wrapper"
mkdir -p "$d2k_log_dir" "$wrapper_log_dir"
rm -rf "$wrapper_log_dir"/*

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
