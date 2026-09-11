#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
APP_DIR="${1:?usage: run_task20_with_v0923_lock_shim.sh <app-dir> <command> [args...]}"
shift
if [[ "$#" -eq 0 ]]; then
  echo "ERROR: command is required." >&2
  exit 2
fi

APP_DIR="$(cd "$APP_DIR" && pwd)"
EXPECTED_LOCK_SHA256="2b9fd241e021b09d40222cc738da578620fda952591bfc66d95ef08d1beef599"
LOCK_PATH="$APP_DIR/pubspec.lock"
if [[ -f "$LOCK_PATH" ]]; then
  current_lock_sha="$(shasum -a 256 "$LOCK_PATH" | awk '{print $1}')"
  if [[ "$current_lock_sha" != "$EXPECTED_LOCK_SHA256" ]]; then
    echo "ERROR: refusing to hide unexpected pubspec.lock before canonical verification: $current_lock_sha" >&2
    exit 2
  fi
  rm "$LOCK_PATH"
fi
if [[ -e "$LOCK_PATH" ]]; then
  echo "ERROR: pubspec.lock must be absent during canonical package verification." >&2
  exit 2
fi

# zip extraction on hosted macOS does not reliably preserve executable bits for
# the canonical shell harness. Restore only filesystem mode bits after all
# package/hash verification; product bytes remain unchanged.
find "$APP_DIR/tools" -type f -name '*.sh' -exec chmod +x {} +

REAL_FLUTTER="$(command -v flutter || true)"
if [[ -z "$REAL_FLUTTER" || ! -x "$REAL_FLUTTER" ]]; then
  echo "ERROR: real flutter executable was not found before lock shim setup." >&2
  exit 2
fi

SHIM_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/task20-v0923-flutter-shim.XXXXXX")"
cleanup() {
  rm -rf "$SHIM_DIR"
}
trap cleanup EXIT

cat > "$SHIM_DIR/flutter" <<'SHIM'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${1:-}" == "pub" && "${2:-}" == "get" ]]; then
  python3 "$TASK20_V0923_LOCK_RESTORE_HELPER" "$TASK20_V0923_APP_DIR"
fi
exec "$TASK20_V0923_REAL_FLUTTER" "$@"
SHIM
chmod +x "$SHIM_DIR/flutter"

export TASK20_V0923_REAL_FLUTTER="$REAL_FLUTTER"
export TASK20_V0923_APP_DIR="$APP_DIR"
export TASK20_V0923_LOCK_RESTORE_HELPER="$ROOT/tools/task20_restore_v0923_ci_lock.py"
export PATH="$SHIM_DIR:$PATH"

test "$(command -v flutter)" = "$SHIM_DIR/flutter"
test -x "$TASK20_V0923_REAL_FLUTTER"
test -f "$TASK20_V0923_LOCK_RESTORE_HELPER"

exec "$@"
