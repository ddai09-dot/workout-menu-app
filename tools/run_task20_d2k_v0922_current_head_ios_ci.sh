#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

# Keep the already accepted v0.9.22 D2J regression lane intact, then add the
# D2-08 local-reset interruption acceptance on the same exact candidate.
bash tools/run_task20_d2j_v0922_current_head_ios_ci.sh

TASK20_D2K_TRIGGER_TIMEOUT_SECONDS=1200 \
TASK20_D2K_VERIFY_TIMEOUT_SECONDS=600 \
TASK20_D2K_LOG_DIR="$ROOT/app/build/task20_d2k_reset_interruption" \
  bash tools/run_task20_d2k_ios_ui_acceptance.sh "$ROOT/app"
