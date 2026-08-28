#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

# Keep the already accepted v0.9.22 D2J regression lane intact, then add the
# D2-08 local-reset interruption acceptance on the same exact candidate.
bash tools/run_task20_d2j_v0922_current_head_ios_ci.sh

# The D2J runner installs the pinned Flutter SDK and exports PATH only inside
# its child shell. Restore that exact SDK path in this parent shell before D2K;
# otherwise D2K starts after all regressions pass but immediately fails its
# `flutter`/`dart` preflight on GitHub-hosted macOS.
flutter_result_file="$ROOT/app/build/task20_b_logs/ios/flutter_sdk_install.json"
if [[ ! -s "$flutter_result_file" ]]; then
  echo "ERROR: Flutter SDK install result missing after D2J: $flutter_result_file" >&2
  exit 2
fi
flutter_bin_directory="$(python3 -c 'import json,sys; from pathlib import Path; print(Path(json.load(open(sys.argv[1], encoding="utf-8"))["flutter_bin"]).parent)' "$flutter_result_file")"
test -x "$flutter_bin_directory/flutter"
test -x "$flutter_bin_directory/dart"
export PATH="$flutter_bin_directory:$PATH"

# Persist a tiny handoff trace so an early D2K startup failure is visible in
# the always-uploaded evidence artifact instead of appearing as a missing dir.
d2k_log_dir="$ROOT/app/build/task20_d2k_reset_interruption"
mkdir -p "$d2k_log_dir"
{
  echo "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "flutter=$(command -v flutter)"
  echo "dart=$(command -v dart)"
  echo "python3=$(command -v python3)"
  echo "xcrun=$(command -v xcrun)"
  echo "pwd=$(pwd)"
} > "$d2k_log_dir/parent_preflight.log"

TASK20_D2K_TRIGGER_TIMEOUT_SECONDS=1200 \
TASK20_D2K_VERIFY_TIMEOUT_SECONDS=600 \
TASK20_D2K_LOG_DIR="$d2k_log_dir" \
  bash tools/run_task20_d2k_ios_ui_acceptance.sh "$ROOT/app"
