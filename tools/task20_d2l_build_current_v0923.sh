#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

bash tools/task20_d2j_build_current_v0922.sh
test "$(shasum -a 256 implementation-v0.9.22.zip | awk '{print $1}')" = "714b56ed1f074f22a500932719d75398ecfbc1c853da74e01eda85c4601fa6eb"

python3 - "$ROOT/implementation-v0.9.22.zip" "$ROOT/implementation-v0.9.23.zip" <<'PYINNER'
from __future__ import annotations

import hashlib
import json
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

PARENT_ZIP_SHA = "714b56ed1f074f22a500932719d75398ecfbc1c853da74e01eda85c4601fa6eb"
EXPECTED_ZIP_SHA = "35858d4651c19743f2753b5f1d62977547073bcf8f88a16396827f50a84ab2f9"
EXPECTED_PUBSPEC_SHA = "243a2ad8e6d3afd291046523a23a8d87b32f7683b8217d8d139c68a7183a2c28"
EXPECTED = {
    "runtime": "827084034654c36a8a930b8f234d97a17367de2a4b79cf82028edfad8fdde36f",
    "product_lib": "f96d0e5ed59e9c960f6e8fe6ee4b3aa388cc1737fd2357821817c59773abe871",
    "tests": "878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5",
    "schema": "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af",
    "assets": "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe",
}
EXCLUDED = {"build", ".dart_tool"}


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if text.count(old) != 1:
        raise SystemExit(f"expected exactly one marker in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def package_files(root: Path) -> list[str]:
    return sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
        and path.relative_to(root).parts[0] not in EXCLUDED
        and "__pycache__" not in path.relative_to(root).parts
    )


def tree_hash(root: Path, parts: list[str]) -> str:
    digest = hashlib.sha256()
    files: list[Path] = []
    for part in parts:
        path = root / part
        if path.is_dir():
            files.extend(
                item
                for item in path.rglob("*")
                if item.is_file() and "__pycache__" not in item.parts
            )
        else:
            files.append(path)
    for path in sorted(set(files), key=lambda item: item.relative_to(root).as_posix()):
        rel = path.relative_to(root).as_posix()
        digest.update(rel.encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


parent = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
if hashlib.sha256(parent.read_bytes()).hexdigest() != PARENT_ZIP_SHA:
    raise SystemExit("canonical v0.9.22 parent ZIP SHA mismatch")

with tempfile.TemporaryDirectory(prefix="task20-d2l-v0923-") as temp_dir:
    root = Path(temp_dir) / "app"
    root.mkdir()
    with zipfile.ZipFile(parent) as archive:
        archive.extractall(root)

    replace_once(root / "pubspec.yaml", "version: 0.9.22+40", "version: 0.9.23+41")
    for rel in [
        "tools/verify_project_consistency.py",
        "tools/verify_task20_b_execution_lane.py",
    ]:
        replace_once(root / rel, "0.9.22+40", "0.9.23+41")

    trace_json = root / "docs/weekly_algorithm_traceability_verification.json"
    trace_json_text = trace_json.read_text(encoding="utf-8")
    if trace_json_text.count("0.9.22+40") != 2:
        raise SystemExit(
            "expected exactly two v0.9.22 markers in weekly algorithm trace JSON"
        )
    trace_json.write_text(
        trace_json_text.replace("0.9.22+40", "0.9.23+41"),
        encoding="utf-8",
    )

    trace = root / "tools/verify_weekly_algorithm_traceability.py"
    trace_text = trace.read_text(encoding="utf-8")
    if trace_text.count("0.9.22+40") != 3:
        raise SystemExit(
            "expected exactly three v0.9.22 markers in weekly algorithm trace verifier"
        )
    trace.write_text(
        trace_text.replace("0.9.22+40", "0.9.23+41"),
        encoding="utf-8",
    )

    replace_once(
        root / "tools/verify_project_consistency.py",
        'require(text, "0.9.22", label)',
        'require(text, "0.9.23", label)',
    )
    replace_once(
        root / "tools/verify_project_consistency.py",
        '"D-025",\n        "Decision Log",',
        '"D-031",\n        "Decision Log",',
    )

    flow = root / "lib/features/weekly_planner/presentation/weekly_planner_flow_page.dart"
    old_actions = """                if (draft.currentStep == WeeklyPlannerStep.review) ...<Widget>[\n                  OutlinedButton(\n                    onPressed: plannerState.isBusy\n                        ? null\n                        : () => unawaited(notifier.reviseConditions()),\n                    child: const Text('条件を修正して作り直す'),\n                  ),\n                  const SizedBox(height: 8),\n                ],\n                FilledButton(\n                  onPressed: plannerState.isBusy\n                      ? null\n                      : () => unawaited(\n                            _onPrimary(\n                              context,\n                              ref,\n                              plannerState,\n                              notifier,\n                            ),\n                          ),\n                  child: plannerState.isGenerating || plannerState.isFinalizing\n                      ? const SizedBox.square(\n                          dimension: 22,\n                          child: CircularProgressIndicator(strokeWidth: 2),\n                        )\n                      : Text(_primaryLabel(draft.currentStep)),\n                ),\n"""
    new_actions = """                if (draft.currentStep == WeeklyPlannerStep.review) ...<Widget>[\n                  SizedBox(\n                    width: double.infinity,\n                    child: OutlinedButton(\n                      onPressed: plannerState.isBusy\n                          ? null\n                          : () => unawaited(notifier.reviseConditions()),\n                      child: const Text(\n                        '条件を修正して作り直す',\n                        textAlign: TextAlign.center,\n                      ),\n                    ),\n                  ),\n                  const SizedBox(height: 8),\n                ],\n                SizedBox(\n                  width: double.infinity,\n                  child: FilledButton(\n                    onPressed: plannerState.isBusy\n                        ? null\n                        : () => unawaited(\n                              _onPrimary(\n                                context,\n                                ref,\n                                plannerState,\n                                notifier,\n                              ),\n                            ),\n                    child: plannerState.isGenerating || plannerState.isFinalizing\n                        ? const SizedBox.square(\n                            dimension: 22,\n                            child: CircularProgressIndicator(strokeWidth: 2),\n                          )\n                        : Text(\n                            _primaryLabel(draft.currentStep),\n                            textAlign: TextAlign.center,\n                          ),\n                  ),\n                ),\n"""
    replace_once(flow, old_actions, new_actions)

    readme = root / "README.md"
    replace_once(
        readme,
        "# 筋トレメニュー提案アプリ 実装基盤 v0.9.22",
        "# 筋トレメニュー提案アプリ 実装基盤 v0.9.23",
    )
    replace_once(readme, "- アプリ版：`0.9.22+40`", "- アプリ版：`0.9.23+41`")
    readme.write_text(
        readme.read_text(encoding="utf-8").rstrip()
        + """\n\n## v0.9.23の変更\n\n- Dynamic Type全12サイズmatrixで`accessibility-extra-extra-large`の週間メニュー「今週の調整方針」遷移時に右36pxのRenderFlex overflowを検出した。\n- 週間メニュー下部の主要／修正アクションを明示的な全幅ボタンにし、拡大文字ラベルを画面幅内で折返せるようにする。\n- Schema v9／75テーブル、Migration、Seed、assets、既存56 testsの仕様は変更しない。\n- Dynamic Type全12サイズの正式判定はv0.9.23 exact Head matrix CIとArtifact監査後のみ更新する。\n\n""",
        encoding="utf-8",
    )

    matrix = root / "docs/VERSION_MATRIX.md"
    replace_once(
        matrix,
        "- 現在のプロジェクト版：`0.9.22+40`",
        "- 現在のプロジェクト版：`0.9.23+41`",
    )
    matrix.write_text(
        matrix.read_text(encoding="utf-8").rstrip()
        + "\n| 0.9.23 | 9 | Task20-D2L weekly planner enlarged-text action fix | 全12サイズmatrixで検出した調整方針画面の右36px overflowを、下部アクションの全幅・折返し対応で是正 |\n",
        encoding="utf-8",
    )

    decision = root / "docs/DECISION_LOG.md"
    decision.write_text(
        decision.read_text(encoding="utf-8").rstrip()
        + """\n\n## D-031 D2L全サイズmatrixの週間メニュー横overflowをv0.9.23で是正する\n\n- 決定日：2026-09-11\n- 事実：PR #21 exact Head `07ac63a3b666fef74cf025d74cb7178f9ad7e4f4`のDynamic Type matrix #2は10/12カテゴリPASS。`accessibility-extra-extra-large`ではD2Dの「今週の調整方針」遷移直後に`A RenderFlex overflowed by 36 pixels on the right.`を検出した。\n- 判定：製品UI不具合。下部アクションの拡大文字ラベルを画面幅へ明示的に拘束し、縮小ではなく折返しで可読性を維持する。\n- 決定：v0.9.23／0.9.23+41で週間メニュー下部の主要／修正ボタンを全幅化し、ラベルを中央揃えで折返し可能にする。\n- 併記：`accessibility-extra-extra-extra-large`でD2D年齢pickerのplaceholderが固定下部ボタンに覆われた件は、D2Aと同じInkWell tap target＋ensureVisible方式へharnessを統一する。\n- 不変：既存56 tests、Schema v9／75 tables、Migration、Seed、assets。\n- 禁止：v0.9.22 canonical ZIPを上書きしない。v0.9.23は新exact Head matrix CIとArtifact監査前に受入済みとしない。\n"""
        + "\n",
        encoding="utf-8",
    )

    # Regenerate the traceability JSON using the updated verifier before hashing.
    for command in [
        [sys.executable, "tools/verify_project_consistency.py"],
        [sys.executable, "tools/verify_weekly_algorithm_traceability.py"],
        [sys.executable, "tools/verify_task20_b_execution_lane.py"],
    ]:
        completed = subprocess.run(command, cwd=root, text=True, capture_output=True)
        if completed.returncode:
            raise SystemExit(
                f"v0.9.23 pre-package verification failed: {' '.join(command)}\n"
                f"{completed.stdout}{completed.stderr}"
            )

    if hashlib.sha256((root / "pubspec.yaml").read_bytes()).hexdigest() != EXPECTED_PUBSPEC_SHA:
        raise SystemExit("v0.9.23 pubspec SHA mismatch")

    files = package_files(root)
    manifest = [
        line
        for line in (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8").splitlines()
        if line
    ]
    if files != manifest:
        raise SystemExit("v0.9.23 FILE_MANIFEST mismatch")

    hashes = {
        "runtime": tree_hash(root, ["lib", "test"]),
        "product_lib": tree_hash(root, ["lib"]),
        "tests": tree_hash(root, ["test"]),
        "schema": tree_hash(
            root,
            ["docs/schema_v9.sqlite.sql", "docs/migrations", "lib/core/database/schema"],
        ),
        "assets": tree_hash(root, ["assets"]),
    }
    if hashes != EXPECTED:
        raise SystemExit(f"v0.9.23 tree mismatch: {hashes}")

    if output.exists():
        output.unlink()
    with zipfile.ZipFile(
        output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for rel in files:
            path = root / rel
            info = zipfile.ZipInfo(rel, date_time=(2020, 1, 1, 0, 0, 0))
            info.create_system = 3
            mode = 0o755 if path.stat().st_mode & stat.S_IXUSR else 0o644
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            info.flag_bits |= 0x800
            archive.writestr(
                info,
                path.read_bytes(),
                compress_type=zipfile.ZIP_DEFLATED,
                compresslevel=9,
            )

actual_zip = hashlib.sha256(output.read_bytes()).hexdigest()
if actual_zip != EXPECTED_ZIP_SHA:
    raise SystemExit(f"v0.9.23 ZIP SHA mismatch: {actual_zip} != {EXPECTED_ZIP_SHA}")
print(
    json.dumps(
        {
            "status": "PASS",
            "task": "Task20-D2L weekly planner enlarged-text action fix",
            "canonical_package": "implementation-v0.9.23.zip",
            "app_version": "0.9.23+41",
            "parent_canonical_version": "0.9.22+40",
            "parent_zip_sha256": PARENT_ZIP_SHA,
            "zip_sha256": actual_zip,
            "expected_flutter_test_count": 56,
            "schema_version": 9,
            "schema_table_count": 75,
            "tree_hashes": EXPECTED,
            "product_runtime_changed": True,
            "tests_changed": False,
            "schema_changed": False,
            "assets_changed": False,
            "d2l_acceptance_status": "PENDING_EXACT_CURRENT_HEAD_MATRIX_CI_AND_ARTIFACT_AUDIT",
        },
        ensure_ascii=False,
        sort_keys=True,
    )
)
PYINNER

rm -rf app && mkdir app && unzip -q implementation-v0.9.23.zip -d app
python3 app/tools/verify_project_consistency.py
python3 app/tools/verify_weekly_algorithm_traceability.py
python3 app/tools/verify_task20_b_execution_lane.py
test "$(shasum -a 256 implementation-v0.9.22.zip | awk '{print $1}')" = "714b56ed1f074f22a500932719d75398ecfbc1c853da74e01eda85c4601fa6eb"
test "$(shasum -a 256 implementation-v0.9.23.zip | awk '{print $1}')" = "35858d4651c19743f2753b5f1d62977547073bcf8f88a16396827f50a84ab2f9"
python3 tools/task20_restore_v0923_ci_lock.py "$ROOT/app"
