#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

bash tools/task20_d2j_build_current_v0920.sh

result_file="app/build/task20_b_logs/ios/flutter_sdk_install.json"
mkdir -p "$(dirname "$result_file")"
python3 app/tools/install_pinned_flutter_sdk.py \
  --version 3.44.6 \
  --channel stable \
  --ref-prefix ee80f08 \
  --install-root "${RUNNER_TOOL_CACHE}/workout-menu-flutter" \
  --result-file "$result_file"
flutter_bin_directory="$(python3 -c 'import json,sys; from pathlib import Path; print(Path(json.load(open(sys.argv[1], encoding="utf-8"))["flutter_bin"]).parent)' "$result_file")"
test -x "$flutter_bin_directory/flutter"
export PATH="$flutter_bin_directory:$PATH"

(cd app && ./tools/run_task20_b_ios_simulator.sh)

TASK20_D1_LOG_DIR="$ROOT/app/build/task20_d1_ios_launch_smoke" \
  bash tools/task20_d1_ios_launch_smoke.sh "$ROOT/app/build/ios/iphonesimulator/Runner.app"

TASK20_D2H_DRIVE_TIMEOUT_SECONDS=1500 \
TASK20_D2H_MAX_STARTUP_ATTEMPTS=2 \
TASK20_D2H_LOG_DIR="$ROOT/app/build/task20_d2h_restart_persistence" \
  bash tools/run_task20_d2h_ios_ui_acceptance.sh "$ROOT/app"

TASK20_D2I_PHASE1_TIMEOUT_SECONDS=1200 \
TASK20_D2I_PHASE2_TIMEOUT_SECONDS=600 \
TASK20_D2I_LOG_DIR="$ROOT/app/build/task20_d2i_local_data_reset" \
  bash tools/run_task20_d2i_ios_ui_acceptance.sh "$ROOT/app"

TASK20_D2G_DRIVE_TIMEOUT_SECONDS=1500 \
TASK20_D2G_LOG_DIR="$ROOT/app/build/task20_d2g_my_page_settings" \
  bash tools/run_task20_d2g_ios_ui_acceptance.sh "$ROOT/app"

TASK20_D2F_DRIVE_TIMEOUT_SECONDS=1500 \
TASK20_D2F_LOG_DIR="$ROOT/app/build/task20_d2f_records_progression" \
  bash tools/run_task20_d2f_ios_ui_acceptance.sh "$ROOT/app"

TASK20_D2E_DRIVE_TIMEOUT_SECONDS=720 \
TASK20_D2E_LOG_DIR="$ROOT/app/build/task20_d2e_workout_core_flow" \
  bash tools/run_task20_d2e_ios_ui_acceptance.sh "$ROOT/app"

TASK20_D2_LOG_DIR="$ROOT/app/build/task20_d2a_ios_ui_acceptance" \
  bash tools/run_task20_d2a_ios_ui_acceptance.sh "$ROOT/app"
TASK20_D2C_LOG_DIR="$ROOT/app/build/task20_d2c_onboarding_resume" \
  bash tools/run_task20_d2c_ios_ui_acceptance.sh "$ROOT/app"
TASK20_D2D_LOG_DIR="$ROOT/app/build/task20_d2d_weekly_planner_resume" \
  bash tools/run_task20_d2d_ios_ui_acceptance.sh "$ROOT/app"

python3 tools/task20_c3_verify_analyzer_clean.py \
  app/build/task20_b_logs/ios/flutter_checks/flutter_analyze.log \
  app/tools/run_task20_b_flutter_checks.sh
python3 tools/task20_c4_verify_dependency_resolution.py app/pubspec.yaml app/pubspec.lock
