#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
APP_DIR="${1:?usage: run_task20_with_v0922_lock_shim.sh <app-dir> <command> [args...]}"
shift
if [[ "$#" -eq 0 ]]; then
  echo "ERROR: command is required." >&2
  exit 2
fi

APP_DIR="$(cd "$APP_DIR" && pwd)"
REAL_FLUTTER="$(command -v flutter || true)"
if [[ -z "$REAL_FLUTTER" || ! -x "$REAL_FLUTTER" ]]; then
  echo "ERROR: real flutter executable was not found before lock shim setup." >&2
  exit 2
fi

SHIM_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/task20-v0922-flutter-shim.XXXXXX")"
cleanup() {
  rm -rf "$SHIM_DIR"
}
trap cleanup EXIT

cat > "$SHIM_DIR/flutter" <<'SHIM'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${1:-}" == "pub" && "${2:-}" == "get" ]]; then
  python3 "$TASK20_V0922_LOCK_RESTORE_HELPER" "$TASK20_V0922_APP_DIR"
fi
exec "$TASK20_V0922_REAL_FLUTTER" "$@"
SHIM
chmod +x "$SHIM_DIR/flutter"

export TASK20_V0922_REAL_FLUTTER="$REAL_FLUTTER"
export TASK20_V0922_APP_DIR="$APP_DIR"
export TASK20_V0922_LOCK_RESTORE_HELPER="$ROOT/tools/task20_restore_v0922_ci_lock.py"
export PATH="$SHIM_DIR:$PATH"

# Prove the shim is first on PATH while retaining the pinned real SDK target.
test "$(command -v flutter)" = "$SHIM_DIR/flutter"
test -x "$TASK20_V0922_REAL_FLUTTER"
test -f "$TASK20_V0922_LOCK_RESTORE_HELPER"

exec "$@"
