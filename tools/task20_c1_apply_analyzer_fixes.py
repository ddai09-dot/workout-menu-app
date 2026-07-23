#!/usr/bin/env python3
"""Apply Task 20-C1 async and BuildContext analyzer fixes.

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
        raise SystemExit("Usage: task20_c1_apply_analyzer_fixes.py <extracted-app-root>")

    root = Path(sys.argv[1]).resolve()
    if not (root / "pubspec.yaml").is_file():
        raise SystemExit(f"pubspec.yaml not found under {root}")

    # Await an explicitly user-triggered AI submission.
    replace_count(
        root / "lib/features/ai_coach/presentation/ai_coach_page.dart",
        "onPressed:(){final t=controller.text;controller.clear();ref.read(aiCoachProvider.notifier).submit(t);}",
        "onPressed:() async {final t=controller.text;controller.clear();await ref.read(aiCoachProvider.notifier).submit(t);}",
    )

    # Removing a Future-valued map entry intentionally discards the removed
    # in-flight Future; mark that decision explicitly without self-awaiting it.
    resolver = (
        root
        / "lib/features/exercise_form/data/asset_bundle_exercise_form_image_resolver.dart"
    )
    replace_count(resolver, "import 'dart:typed_data';\n", "import 'dart:async';\n")
    replace_count(
        resolver,
        "      _inFlight.remove(cacheKey);\n",
        "      unawaited(_inFlight.remove(cacheKey));\n",
    )

    # Await notification preference persistence from the dropdown callback.
    notification = (
        root / "lib/features/notifications/presentation/notification_settings_page.dart"
    )
    replace_count(
        notification,
        "                onChanged: (int? value) {\n"
        "                  if (value == null || value == preference.advanceMinutes) {\n"
        "                    return;\n"
        "                  }\n"
        "                  _run(\n",
        "                onChanged: (int? value) async {\n"
        "                  if (value == null || value == preference.advanceMinutes) {\n"
        "                    return;\n"
        "                  }\n"
        "                  await _run(\n",
    )

    # Pop callbacks intentionally launch a confirmation flow without waiting
    # for the callback itself to complete.
    training = (
        root / "lib/features/settings/presentation/training_settings_edit_page.dart"
    )
    replace_count(
        training,
        "import 'package:flutter/material.dart';\n",
        "import 'dart:async';\n\nimport 'package:flutter/material.dart';\n",
    )
    replace_count(
        training,
        "          _confirmDiscard();\n",
        "          unawaited(_confirmDiscard());\n",
    )
    replace_count(
        training,
        "      _confirmDiscard();\n",
        "      unawaited(_confirmDiscard());\n",
    )

    # Guard the exact BuildContext used after the asynchronous start call.
    adjustment = (
        root / "lib/features/workout/presentation/workout_adjustment_page.dart"
    )
    replace_count(
        adjustment,
        "                            if (mounted) {\n"
        "                              context.go('/workout/session/${session.sessionId}');\n"
        "                            }\n",
        "                            if (context.mounted) {\n"
        "                              context.go('/workout/session/${session.sessionId}');\n"
        "                            }\n",
    )
    replace_count(
        adjustment,
        "                            if (mounted) {\n"
        "                              ScaffoldMessenger.of(context).showSnackBar(\n",
        "                            if (context.mounted) {\n"
        "                              ScaffoldMessenger.of(context).showSnackBar(\n",
    )

    # The method receives BuildContext as a parameter, so guard that parameter
    # rather than relying on the State.mounted flag.
    assessment = (
        root / "lib/features/workout/presentation/workout_assessment_page.dart"
    )
    replace_count(
        assessment,
        "    if (!mounted) return;\n"
        "    setState(() => _saving = false);\n",
        "    if (!context.mounted) return;\n"
        "    setState(() => _saving = false);\n",
    )

    session = root / "lib/features/workout/presentation/workout_session_page.dart"
    replace_count(
        session,
        "import 'package:flutter/material.dart';\n",
        "import 'dart:async';\n\nimport 'package:flutter/material.dart';\n",
    )
    replace_count(
        session,
        "      ref.read(workoutSessionProvider.notifier).reload();\n",
        "      unawaited(ref.read(workoutSessionProvider.notifier).reload());\n",
    )
    for source, target in (
        (
            "              _changeExercise(context, ref);\n",
            "              unawaited(_changeExercise(context, ref));\n",
        ),
        (
            "              _changeSetCount(context, ref, session);\n",
            "              unawaited(_changeSetCount(context, ref, session));\n",
        ),
        (
            "              _skipExercise(context, ref);\n",
            "              unawaited(_skipExercise(context, ref));\n",
        ),
        (
            "              _recordPain(context, ref);\n",
            "              unawaited(_recordPain(context, ref));\n",
        ),
        (
            "              _stopEarly(context, ref);\n",
            "              unawaited(_stopEarly(context, ref));\n",
        ),
    ):
        replace_count(session, source, target)

    replace_count(
        session,
        "  if (!context.mounted) return;\n"
        "  if (action == 'SUBSTITUTE') await _changeExercise(context, ref);\n"
        "  if (action == 'SKIP') await ref.read(workoutSessionProvider.notifier).skip('PAIN');\n"
        "  if (action == 'STOP') await _stopEarly(context, ref);\n",
        "  if (!context.mounted) return;\n"
        "  if (action == 'SUBSTITUTE') {\n"
        "    await _changeExercise(context, ref);\n"
        "  } else if (action == 'SKIP') {\n"
        "    await ref.read(workoutSessionProvider.notifier).skip('PAIN');\n"
        "  } else if (action == 'STOP') {\n"
        "    await _stopEarly(context, ref);\n"
        "  }\n",
    )

    evidence_dir = root / "build/task20_b_logs/flutter"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    evidence = {
        "status": "APPLIED",
        "task": "Task 20-C1",
        "scope": "async and BuildContext analyzer findings",
        "targeted_findings": {
            "discarded_futures": 10,
            "unawaited_futures": 1,
            "use_build_context_synchronously": 4,
            "related_unnecessary_import": 1,
        },
        "expected_reduction": 16,
        "baseline_info_count": 65,
        "expected_max_info_count_after_fix": 49,
        "runtime_dependencies_changed": False,
        "functionality_removed": False,
        "canonical_source_status": "temporary ZIP patch; must be folded into the next canonical source package",
    }
    (evidence_dir / "task20_c1_patch_evidence.json").write_text(
        json.dumps(evidence, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
