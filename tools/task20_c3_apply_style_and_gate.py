#!/usr/bin/env python3
"""Apply Task 20-C3 style normalization and restore strict analysis."""

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


def add_file_ignore(path: Path, lint: str) -> None:
    text = path.read_text(encoding="utf-8")
    marker = f"// ignore_for_file: {lint}\n\n"
    if marker in text:
        raise SystemExit(f"Ignore already present in {path}: {lint}")
    path.write_text(marker + text, encoding="utf-8")


def sort_imports(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    prefix: list[str] = []
    index = 0
    while index < len(lines) and (
        lines[index].startswith("// ignore_for_file:") or not lines[index].strip()
    ):
        prefix.append(lines[index])
        index += 1
    imports: list[str] = []
    while index < len(lines):
        line = lines[index]
        if line.startswith("import "):
            imports.append(line)
            index += 1
            continue
        if not line.strip():
            index += 1
            continue
        break
    if not imports:
        raise SystemExit(f"No import block found in {path}")
    dart_imports = sorted(line for line in imports if line.startswith("import 'dart:"))
    package_imports = sorted(line for line in imports if line.startswith("import 'package:"))
    other_imports = sorted(
        line for line in imports if line not in dart_imports and line not in package_imports
    )
    sections = [section for section in (dart_imports, package_imports, other_imports) if section]
    sorted_block = "\n".join("".join(section).rstrip("\n") for section in sections) + "\n\n"
    path.write_text("".join(prefix) + sorted_block + "".join(lines[index:]), encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: task20_c3_apply_style_and_gate.py <extracted-app-root>")
    root = Path(sys.argv[1]).resolve()
    if not (root / "pubspec.yaml").is_file():
        raise SystemExit(f"pubspec.yaml not found under {root}")

    initializing_formal_files = [
        "lib/core/ids/id_generator.dart",
        "lib/core/security/secure_store.dart",
        "lib/core/sync/local_sync_repository.dart",
        "lib/core/sync/outbox_sync_service.dart",
        "lib/features/account/data/local_account_repository.dart",
        "lib/features/ai_coach/data/local_ai_coach_repository.dart",
        "lib/features/onboarding/data/local_onboarding_repository.dart",
        "lib/features/progression/data/local_progression_repository.dart",
        "lib/features/records/data/local_records_repository.dart",
        "lib/features/weekly_planner/data/local_weekly_planner_repository.dart",
        "lib/features/weekly_planner/domain/rule_based_weekly_menu_generator.dart",
        "lib/features/workout/data/local_workout_repository.dart",
    ]
    for relative_path in initializing_formal_files:
        add_file_ignore(root / relative_path, "prefer_initializing_formals")

    for relative_path in (
        "lib/app/router/app_router.dart",
        "lib/features/ai_coach/data/local_ai_coach_repository.dart",
        "lib/features/onboarding/data/local_onboarding_repository.dart",
    ):
        sort_imports(root / relative_path)

    replace_count(
        root / "lib/features/account/presentation/account_page.dart",
        "          error: (_, __) => const Center(child: Text('アカウントを読み込めませんでした')),\n",
        "          error: (_, _) => const Center(child: Text('アカウントを読み込めませんでした')),\n",
    )
    for relative_path, height in (
        ("lib/features/records/presentation/exercise_list_page.dart", 8),
        ("lib/features/records/presentation/progression_proposals_page.dart", 12),
        ("lib/features/records/presentation/session_history_page.dart", 8),
    ):
        source = f"separatorBuilder: (_, __) => const SizedBox(height: {height}),"
        replace_count(root / relative_path, source, source.replace("(_, __)", "(_, _)"))

    draft = root / "lib/features/onboarding/domain/onboarding_draft.dart"
    replace_count(draft, "_stringMap", "stringMap", expected=3)

    repository = root / "lib/features/workout/data/local_workout_repository.dart"
    replace_count(
        repository,
        "    for (var i = 0; i < seeds.length; i += 1) seeds[i].orderIndex = i + 1;\n",
        "    for (var i = 0; i < seeds.length; i += 1) {\n      seeds[i].orderIndex = i + 1;\n    }\n",
    )

    models = root / "lib/features/workout/domain/workout_models.dart"
    for source, target in (
        ("'${targetDurationSec}秒'", "'$targetDurationSec秒'"),
        ("'${reps}回'", "'$reps回'"),
        ("'${durationSec}秒'", "'$durationSec秒'"),
    ):
        replace_count(models, source, target)

    replace_count(
        root / "test/exercise_form/asset_bundle_exercise_form_image_resolver_test.dart",
        "import 'dart:typed_data';\n\n",
        "",
    )

    runner = root / "tools/run_task20_b_flutter_checks.sh"
    replace_count(
        runner,
        "PASS is emitted only after pub get, Drift generation, make verify, analyze with errors/warnings fatal and infos recorded, and flutter test all succeed.",
        "PASS is emitted only after pub get, Drift generation, make verify, strict analyze, and flutter test all succeed.",
    )
    replace_count(
        runner,
        'run_logged_step "flutter_analyze" "flutter_analyze.log" flutter analyze --no-fatal-infos\n',
        'run_logged_step "flutter_analyze" "flutter_analyze.log" flutter analyze\n',
    )
    replace_count(
        root / "tools/verify_task20_b_execution_lane.py",
        '    "--no-fatal-infos",\n',
        "",
    )

    evidence_dir = root / "build/task20_b_logs/flutter"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    evidence = {
        "status": "APPLIED",
        "task": "Task 20-C3",
        "baseline_unique_info_count": 33,
        "expected_unique_info_count_after_fix": 0,
        "direct_code_fix_count": 15,
        "scoped_policy_exception_count": 18,
        "scoped_policy_exception": "prefer_initializing_formals",
        "exception_reason": (
            "Private field-formal parameters would rename public named constructor "
            "parameters and create avoidable API churn."
        ),
        "strict_analyzer_command": "flutter analyze",
        "no_fatal_infos_removed": True,
        "runtime_dependencies_changed": False,
        "functionality_removed": False,
        "canonical_source_status": (
            "temporary ZIP patch; must be folded into the next canonical source package"
        ),
    }
    (evidence_dir / "task20_c3_patch_evidence.json").write_text(
        json.dumps(evidence, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
