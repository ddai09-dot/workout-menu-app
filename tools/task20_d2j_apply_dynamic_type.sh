#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: task20_d2j_apply_dynamic_type.sh <simulator-udid> <evidence-dir>" >&2
  exit 2
fi

UDID="$1"
EVIDENCE_DIR="$2"
TARGET_CATEGORY="accessibility-extra-large"
mkdir -p "$EVIDENCE_DIR"

xcrun simctl help ui > "$EVIDENCE_DIR/simctl_ui_help.txt" 2>&1
if ! grep -Fq "$TARGET_CATEGORY" "$EVIDENCE_DIR/simctl_ui_help.txt"; then
  echo "ERROR: simctl ui help does not advertise required content size: $TARGET_CATEGORY" >&2
  exit 2
fi

{
  echo "requested_content_size=$TARGET_CATEGORY"
  echo "set_command=xcrun simctl ui <udid> content_size $TARGET_CATEGORY"
  xcrun simctl ui "$UDID" content_size "$TARGET_CATEGORY"
  echo "set_exit=0"
} > "$EVIDENCE_DIR/content_size_set.txt" 2>&1

set +e
xcrun simctl ui "$UDID" content_size > "$EVIDENCE_DIR/content_size_query.txt" 2>&1
query_code="$?"
set -e
printf 'query_exit=%s\n' "$query_code" >> "$EVIDENCE_DIR/content_size_set.txt"

# The successful setter is the formal state change. Query output is retained as
# supporting evidence because its exact textual format is Xcode-version specific.
echo "Task20-D2J Dynamic Type set to $TARGET_CATEGORY for $UDID"
