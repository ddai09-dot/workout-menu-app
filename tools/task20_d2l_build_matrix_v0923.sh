#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

bash tools/task20_d2l_build_current_v0923.sh
python3 tools/task20_d2l_finalize_v0923_candidate.py implementation-v0.9.23.zip

test "$(shasum -a 256 implementation-v0.9.22.zip | awk '{print $1}')" = "714b56ed1f074f22a500932719d75398ecfbc1c853da74e01eda85c4601fa6eb"
test "$(shasum -a 256 implementation-v0.9.23.zip | awk '{print $1}')" = "7c4b88b6fb4058f0bd1d232cb069bd45421e798a43d0b041991b091765bcbfd6"

rm -rf app
mkdir app
unzip -q implementation-v0.9.23.zip -d app
python3 app/tools/verify_project_consistency.py
python3 app/tools/verify_weekly_algorithm_traceability.py
python3 app/tools/verify_task20_b_execution_lane.py
python3 tools/task20_restore_v0923_ci_lock.py "$ROOT/app"

echo "Task20-D2L finalized v0.9.23 matrix candidate PASS."
