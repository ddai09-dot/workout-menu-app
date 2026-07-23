#!/usr/bin/env python3
"""Apply Task 20-C2 deprecated API migrations.

This script is part of the temporary ZIP integration lane. The changes must be
folded into the next canonical source package before the ZIP patch lane is
retired.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def replace_count(path: Path, source: str, target: str, expected: int = 1) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(source)
    if count != expected:
        raise SystemExit(
            f"Expected {expected} match(es) in {path}: {source!r}; found {count}"
        )
    path.write_text(text.replace(source, target), encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: task20_c2_apply_deprecated_api_fixes.py <extracted-app-root>")

    root = Path(sys.argv[1]).resolve()
    if not (root / "pubspec.yaml").is_file():
        raise SystemExit(f"pubspec.yaml not found under {root}")

    replace_count(
        root / "lib/app/bootstrap.dart",
        "      anonKey: environment.supabasePublishableKey,\n",
        "      publishableKey: environment.supabasePublishableKey,\n",
    )

    weekly = root / "lib/features/weekly_planner/presentation/steps/weekly_planner_steps.dart"
    for source, target in (
        (
            "            value: draft.increaseMethodCode,\n",
            "            initialValue: draft.increaseMethodCode,\n",
        ),
        (
            "          value: draft.splitOverrideCode ?? 'DEFAULT',\n",
            "          initialValue: draft.splitOverrideCode ?? 'DEFAULT',\n",
        ),
        (
            "                      value: day.durationMin,\n",
            "                      initialValue: day.durationMin,\n",
        ),
        (
            "                      value: locations.any((value) => value.id == day.locationId)\n",
            "                      initialValue: locations.any((value) => value.id == day.locationId)\n",
        ),
        (
            "                value: value!.actionCode,\n",
            "                initialValue: value!.actionCode,\n",
        ),
        (
            "                value: value!.adjustmentCode,\n",
            "                initialValue: value!.adjustmentCode,\n",
        ),
    ):
        replace_count(weekly, source, target)

    adjustment = root / "lib/features/workout/presentation/workout_adjustment_page.dart"
    replace_count(
        adjustment,
        """                  for (final location in value.availableLocations)
                    RadioListTile<String>(
                      value: location.id,
                      groupValue: _locationId,
                      title: Text(location.name),
                      onChanged: (String? id) => setState(() => _locationId = id),
                    ),
""",
        """                  RadioGroup<String>(
                    groupValue: _locationId,
                    onChanged: (String? id) => setState(() => _locationId = id),
                    child: Column(
                      children: <Widget>[
                        for (final location in value.availableLocations)
                          RadioListTile<String>(
                            value: location.id,
                            title: Text(location.name),
                          ),
                      ],
                    ),
                  ),
""",
    )
    for source, target in (
        (
            "                    value: bodyPart,\n",
            "                    initialValue: bodyPart,\n",
        ),
        (
            "                    value: actionCode,\n",
            "                    initialValue: actionCode,\n",
        ),
    ):
        replace_count(adjustment, source, target)

    assessment = root / "lib/features/workout/presentation/workout_assessment_page.dart"
    for source, target in (
        (
            "                          value: _painBodyPartId,\n",
            "                          initialValue: _painBodyPartId,\n",
        ),
        (
            "                      value: _painExerciseId,\n",
            "                      initialValue: _painExerciseId,\n",
        ),
        (
            "                      value: _incompleteReason,\n",
            "                      initialValue: _incompleteReason,\n",
        ),
    ):
        replace_count(assessment, source, target)

    session = root / "lib/features/workout/presentation/workout_session_page.dart"
    for source, target in (
        (
            "                  value: part,\n",
            "                  initialValue: part,\n",
        ),
        (
            "                  value: action,\n",
            "                  initialValue: action,\n",
        ),
    ):
        replace_count(session, source, target)

    evidence_dir = root / "build/task20_b_logs/flutter"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    evidence = {
        "status": "APPLIED",
        "task": "Task 20-C2",
        "scope": "deprecated API migrations",
        "targeted_findings": {
            "supabase_anon_key": 1,
            "dropdown_button_form_field_value": 13,
            "radio_group_value_and_on_changed": 2,
        },
        "expected_reduction": 16,
        "baseline_unique_info_count": 49,
        "expected_unique_info_count_after_fix": 33,
        "runtime_dependencies_changed": False,
        "functionality_removed": False,
        "canonical_source_status": (
            "temporary ZIP patch; must be folded into the next canonical source package"
        ),
    }
    (evidence_dir / "task20_c2_patch_evidence.json").write_text(
        json.dumps(evidence, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
