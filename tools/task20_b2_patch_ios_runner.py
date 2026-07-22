#!/usr/bin/env python3
"""Patch the Task 20-B iOS runner to remove only a newly generated scaffold test.

The runner records whether `test/widget_test.dart` existed before `flutter create`.
It deletes the file only when it was absent before creation, exists afterwards,
and the Flutter creation log explicitly reports that the file was created. Any
pre-existing or unproven file causes the CI lane to fail instead of deleting it.
"""

from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: task20_b2_patch_ios_runner.py <extracted-app-root>")

    root = Path(sys.argv[1]).resolve()
    runner = root / "tools/run_task20_b_ios_simulator.sh"
    text = runner.read_text(encoding="utf-8")

    source = '''run_logged_step "flutter_create_ios" "flutter_create_ios.log" flutter create \\
  --platforms=ios \\
  --org jp.workoutmenu \\
  --project-name workout_menu_app \\
  .
'''
    target = '''GENERATED_WIDGET_TEST_PATH="test/widget_test.dart"
GENERATED_WIDGET_TEST_EXISTED_BEFORE_CREATE=0
if [[ -e "$GENERATED_WIDGET_TEST_PATH" ]]; then
  GENERATED_WIDGET_TEST_EXISTED_BEFORE_CREATE=1
fi

''' + source + '''
remove_generated_widget_test() {
  local path="$GENERATED_WIDGET_TEST_PATH"
  local create_log="$LOG_DIR/flutter_create_ios.log"

  if [[ "$GENERATED_WIDGET_TEST_EXISTED_BEFORE_CREATE" -ne 0 ]]; then
    record_gate "remove_generated_widget_test" "FAIL" 1 "Refusing to delete test/widget_test.dart because it existed before flutter create."
    return 1
  fi

  if [[ ! -f "$path" ]]; then
    record_gate "remove_generated_widget_test" "PASS" 0 "No generated template widget test was present."
    return 0
  fi

  if ! grep -Fq "test/widget_test.dart (created)" "$create_log"; then
    record_gate "remove_generated_widget_test" "FAIL" 1 "Refusing to delete test/widget_test.dart because flutter create did not report creating it."
    return 1
  fi

  rm "$path"
  record_gate "remove_generated_widget_test" "PASS" 0 "Removed widget test proven to have been created by flutter create in this run."
}

remove_generated_widget_test
'''

    count = text.count(source)
    if count != 1:
        raise SystemExit(
            f"Expected exactly one flutter_create_ios step in {runner}; found {count}"
        )

    runner.write_text(text.replace(source, target), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
