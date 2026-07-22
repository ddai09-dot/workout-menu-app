#!/usr/bin/env python3
"""Patch the Task 20-B iOS runner to remove only Flutter's generated counter test.

`flutter create --platforms=ios .` may create `test/widget_test.dart`. The file is
removed only when all known counter-template markers are present. A non-template
file at the same path causes the CI lane to fail instead of deleting user code.
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
    target = source + '''
remove_generated_widget_test() {
  local path="test/widget_test.dart"
  if [[ ! -f "$path" ]]; then
    record_gate "remove_generated_widget_test" "PASS" 0 "No generated template widget test was present."
    return 0
  fi

  local required_markers=(
    "A basic Flutter widget test."
    "await tester.pumpWidget(const MyApp());"
    "Icons.add"
    "find.text('0')"
    "find.text('1')"
  )
  local marker
  for marker in "${required_markers[@]}"; do
    if ! grep -Fq "$marker" "$path"; then
      record_gate "remove_generated_widget_test" "FAIL" 1 "Refusing to delete a non-template test/widget_test.dart."
      return 1
    fi
  done

  rm "$path"
  record_gate "remove_generated_widget_test" "PASS" 0 "Removed Flutter-generated counter-app widget test."
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
