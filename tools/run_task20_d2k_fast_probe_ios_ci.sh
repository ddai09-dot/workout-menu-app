#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

# Fast-probe trigger revision: a290dfe secure-key gate orchestration.
# Materialize the exact v0.9.22 product candidate without running the full
# multi-hour D2 regression chain. This is diagnostic acceleration only; the
# exact PR-head full iOS workflow remains the acceptance authority.
bash tools/task20_d2j_build_current_v0922.sh

flutter_result_file="$ROOT/app/build/task20_b_logs/ios/flutter_sdk_install.json"
mkdir -p "$(dirname "$flutter_result_file")"
python3 app/tools/install_pinned_flutter_sdk.py \
  --version 3.44.6 \
  --channel stable \
  --ref-prefix ee80f08 \
  --install-root "${RUNNER_TOOL_CACHE}/workout-menu-flutter" \
  --result-file "$flutter_result_file"
flutter_bin_directory="$(python3 -c 'import json,sys; from pathlib import Path; print(Path(json.load(open(sys.argv[1], encoding="utf-8"))["flutter_bin"]).parent)' "$flutter_result_file")"
test -x "$flutter_bin_directory/flutter"
test -x "$flutter_bin_directory/dart"
export PATH="$flutter_bin_directory:$PATH"

(cd app && ./tools/run_task20_b_ios_simulator.sh)
TASK20_D1_LOG_DIR="$ROOT/app/build/task20_d1_ios_launch_smoke" \
  bash tools/task20_d1_ios_launch_smoke.sh "$ROOT/app/build/ios/iphonesimulator/Runner.app"

probe_log_dir="$ROOT/app/build/task20_d2k_fast_probe"
d2k_log_dir="$ROOT/app/build/task20_d2k_reset_interruption"
mkdir -p "$probe_log_dir" "$d2k_log_dir"
rm -rf "$probe_log_dir"/*

snapshot_attempt() {
  local attempt="$1"
  local destination="$probe_log_dir/attempt_${attempt}"
  rm -rf "$destination"
  mkdir -p "$destination"
  cp -R "$d2k_log_dir/." "$destination/" 2>/dev/null || true
}

is_retryable_startup_failure() {
  local log_file="$d2k_log_dir/trigger_flutter_drive.log"
  [[ -f "$log_file" ]] || return 1
  grep -Fq 'D2K_READY_FOR_DB_LOCK' "$log_file" && return 1
  grep -Eqi \
    'Application failed to start|Error waiting for a debug connection|log reader failed unexpectedly|Unable to launch|Failed to start' \
    "$log_file"
}

max_attempts=2
for attempt in $(seq 1 "$max_attempts"); do
  {
    echo "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "attempt=$attempt"
    echo "flutter=$(command -v flutter)"
    echo "dart=$(command -v dart)"
    echo "xcrun=$(command -v xcrun)"
    echo "python3=$(command -v python3)"
    echo "pwd=$(pwd)"
    echo "PATH=$PATH"
  } > "$probe_log_dir/preflight_attempt_${attempt}.log"

  set +e
  TASK20_D2K_TRIGGER_TIMEOUT_SECONDS=1200 \
  TASK20_D2K_VERIFY_TIMEOUT_SECONDS=600 \
  TASK20_D2K_LOG_DIR="$d2k_log_dir" \
    bash tools/run_task20_d2k_ios_ui_acceptance.sh "$ROOT/app"
  exit_code="$?"
  set -e

  snapshot_attempt "$attempt"
  printf '%s\n' "$exit_code" > "$probe_log_dir/attempt_${attempt}_exit_code.txt"
  if [[ "$exit_code" -eq 0 ]]; then
    cat > "$probe_log_dir/result.json" <<JSON
{
  "task": "Task 20-D2K isolated fast probe",
  "status": "PASS",
  "attempts": $attempt,
  "acceptance_authority": false,
  "note": "Diagnostic pass only; exact-head full PR iOS regression must also pass."
}
JSON
    exit 0
  fi

  if is_retryable_startup_failure && [[ "$attempt" -lt "$max_attempts" ]]; then
    echo "Retrying D2K after GitHub-hosted Simulator startup failure."
    continue
  fi

  cat > "$probe_log_dir/result.json" <<JSON
{
  "task": "Task 20-D2K isolated fast probe",
  "status": "FAIL",
  "attempts": $attempt,
  "final_exit_code": $exit_code,
  "acceptance_authority": false
}
JSON
  exit "$exit_code"
done

exit 1
