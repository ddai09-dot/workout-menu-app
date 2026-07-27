#!/usr/bin/env python3
"""Build Task20-D2A canonical v0.9.3 from canonical v0.9.2."""
from __future__ import annotations

import hashlib
import shutil
import sys
import zipfile
from pathlib import Path

EXPECTED_SHA256 = "d401ab4ea82b27a5b79cbcd2476264af847fd5e7bbc14f4a55f4924de98eeb6d"
EXCLUDED_TOP_LEVEL = {"build", ".dart_tool"}


def fail(message: str) -> None:
    raise SystemExit(message)


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        fail(f"{path}: expected exactly one occurrence of {old!r}; found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def append_once(path: Path, marker: str, content: str) -> None:
    text = path.read_text(encoding="utf-8")
    if marker in text:
        fail(f"{path}: marker already exists: {marker}")
    path.write_text(text.rstrip() + content + "\n", encoding="utf-8")


def update_source(root: Path) -> None:
    replacements: dict[str, list[tuple[str, str]]] = {
        "pubspec.yaml": [("version: 0.9.2+20\n", "version: 0.9.3+21\n")],
        "lib/features/data_management/presentation/local_data_reset_page.dart": [
            ("    context.go('/launch');\n", "    context.go('/onboarding');\n")
        ],
        "tools/verify_local_data_reset_contract.py": [
            (
                "    require(page, \"context.go('/launch')\", \"LocalDataResetPage\")\n",
                "    require(page, \"context.go('/onboarding')\", \"LocalDataResetPage\")\n",
            )
        ],
        "tools/verify_task20_b_execution_lane.py": [
            ('EXPECTED_APP_VERSION = "0.9.2+20"', 'EXPECTED_APP_VERSION = "0.9.3+21"')
        ],
        "tools/verify_weekly_algorithm_traceability.py": [
            ("version: 0.9.2+20", "version: 0.9.3+21"),
            ("project version must be 0.9.2+20", "project version must be 0.9.3+21"),
            ('"implementation_version": "0.9.2+20"', '"implementation_version": "0.9.3+21"'),
        ],
        "tools/verify_project_consistency.py": [
            ('EXPECTED_APP_VERSION = "0.9.2+20"', 'EXPECTED_APP_VERSION = "0.9.3+21"'),
            ('require(text, "0.9.2", label)', 'require(text, "0.9.3", label)'),
        ],
        "docs/weekly_algorithm_traceability_verification.json": [
            ('"implementation_version": "0.9.2+20"', '"implementation_version": "0.9.3+21"'),
            ("project version must be 0.9.2+20", "project version must be 0.9.3+21"),
        ],
        "README.md": [
            ("# 筋トレメニュー提案アプリ 実装基盤 v0.9.2\n", "# 筋トレメニュー提案アプリ 実装基盤 v0.9.3\n"),
            ("- アプリ版：`0.9.2+20`\n", "- アプリ版：`0.9.3+21`\n"),
            (
                "- v0.9.2：上記の検証済みpatchを正本実装へ統合\n",
                "- v0.9.2：上記の検証済みpatchを正本実装へ統合\n"
                "- v0.9.3：端末内データ初期化後の二重ナビゲーションを解消し、初期登録introへ直接遷移\n",
            ),
        ],
        "docs/VERSION_MATRIX.md": [
            ("- 現在のプロジェクト版：`0.9.2+20`\n", "- 現在のプロジェクト版：`0.9.3+21`\n"),
            ("- 確認日：2026-07-24\n", "- 確認日：2026-07-27\n"),
            (
                "| 0.9.2 | 9 | タスク20-C1〜C4：Analyzer・API・依存是正の正本統合 | strict Analyze 0件／Flutter Test 48件／iOS Simulator build PASS |\n",
                "| 0.9.2 | 9 | タスク20-C1〜C4：Analyzer・API・依存是正の正本統合 | strict Analyze 0件／Flutter Test 48件／iOS Simulator build PASS |\n"
                "| 0.9.3 | 9 | タスク20-D2A：端末内データ初期化後の遷移是正 | Shell破棄中の二重ナビゲーションを避け、初期登録introへ直接遷移 |\n",
            ),
        ],
        "docs/IMPLEMENTATION_ROADMAP.md": [
            (
                "- v0.9.2：B2／B3／C1〜C4の検証済み変更を正本実装へ統合\n",
                "- v0.9.2：B2／B3／C1〜C4の検証済み変更を正本実装へ統合\n"
                "- v0.9.3：D2A自動UI受入で検出した端末内データ初期化後の二重ナビゲーションを是正\n",
            )
        ],
        "docs/TASK20_A_LOCAL_DATA_RESET_AND_FLUTTER_PREFLIGHT.md": [
            (
                "- 成功後はユーザー状態Providerを破棄し、`/launch`へ戻す。\n",
                "- 成功後はユーザー状態Providerを破棄し、初期登録introを表示する`/onboarding`へ直接戻す。`/launch`を介した即時再遷移は行わない。\n",
            )
        ],
    }
    for relative, pairs in replacements.items():
        path = root / relative
        for old, new in pairs:
            replace_once(path, old, new)

    append_once(
        root / "docs/DECISION_LOG.md",
        "## D-009 端末内データ初期化後は初期登録introへ直接遷移",
        """

## D-009 端末内データ初期化後は初期登録introへ直接遷移

- 日付：2026-07-27
- 区分：採用
- 対象：`LocalDataResetPage`の初期化成功後ナビゲーション
- 理由：`/launch`経由ではLaunchPageの状態監視による`/onboarding`再遷移が直後に発生し、StatefulShellRoute破棄中にGlobalKey重複例外を生じたため
- 採用：ユーザー状態Providerを破棄した後、`/onboarding`へ直接遷移する
- 採用しなかった案：例外を無視する、固定delayを入れる、`/launch`経由を維持する
- 期待効果：初期化後の初期登録intro復帰を1回のナビゲーションで完了し、Shellの二重構築を防ぐ
- 影響範囲：端末内データ初期化後の画面遷移のみ。削除対象、匿名ID再発行、DB Schemaに変更なし
- 再検証：Task20-D2Aで通常サイズ・小型サイズの両Simulatorにて初期化後intro表示まで確認する
""",
    )

    task_doc = root / "docs/TASK20_D2A_LOCAL_RESET_NAVIGATION_FIX.md"
    if task_doc.exists():
        fail(f"Task20-D2A document already exists: {task_doc}")
    task_doc.write_text(
        """# Task20-D2A 端末内データ初期化後ナビゲーション是正

- 日付：2026-07-27
- 実装基盤：v0.9.3（アプリ 0.9.3+21）
- Schema：v9／75テーブル、変更なし

## 検出

GitHub Actions上のiOS Simulator自動UI受入で、初期登録完了後に端末内データを削除すると、`StatefulNavigationShell`のGlobalKey重複例外が発生した。削除処理、匿名ID再発行、4枚目までの画面操作は完了しており、停止点は削除成功後の画面遷移だった。

## 原因

`LocalDataResetPage`が`/launch`へ遷移した直後、LaunchPageが初期登録状態を監視して`/onboarding`へ再遷移していた。StatefulShellRouteの破棄と次の遷移が重なり、同一のStatefulNavigationShell GlobalKeyが一時的に重複した。

## 採用した修正

- ユーザー状態Providerのinvalidateは維持する。
- 削除成功後は`/launch`を介さず、初期登録introを表示する`/onboarding`へ直接遷移する。
- 削除対象、削除順序、Secure Storageの匿名ID切替、DB transaction、Schemaは変更しない。

## 判定境界

本修正のコード存在だけでは完了としない。Task20-D2Aの通常サイズ・小型サイズ両Simulatorで、初期化後intro表示、例外なし、証跡PNG取得まで成功した時点で自動UI受入範囲をPASSとする。iPhone実機、VoiceOver等のnative accessibility、全主要導線は別途未確認である。
""",
        encoding="utf-8",
    )

    files: list[str] = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if relative.parts and relative.parts[0] in EXCLUDED_TOP_LEVEL:
            continue
        files.append(relative.as_posix())
    (root / "FILE_MANIFEST.txt").write_text(
        "\n".join(sorted(files)) + "\n", encoding="utf-8"
    )


def write_deterministic_zip(root: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(root.rglob("*")):
            if not path.is_file():
                continue
            relative = path.relative_to(root)
            if relative.parts and relative.parts[0] in EXCLUDED_TOP_LEVEL:
                continue
            info = zipfile.ZipInfo(relative.as_posix(), date_time=(2026, 7, 27, 0, 0, 0))
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info._compresslevel = 9
            info.external_attr = (path.stat().st_mode & 0o777) << 16
            archive.writestr(info, path.read_bytes())


def main() -> int:
    if len(sys.argv) != 3:
        fail("Usage: task20_d2a_build_canonical_v093.py <v0.9.2-root> <output-zip>")
    root = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    pubspec = root / "pubspec.yaml"
    if not pubspec.is_file() or "version: 0.9.2+20\n" not in pubspec.read_text(encoding="utf-8"):
        fail("Input is not the v0.9.2+20 canonical package")
    update_source(root)
    shutil.rmtree(root / "build", ignore_errors=True)
    shutil.rmtree(root / ".dart_tool", ignore_errors=True)
    write_deterministic_zip(root, output)
    actual = hashlib.sha256(output.read_bytes()).hexdigest()
    if actual != EXPECTED_SHA256:
        fail(f"Canonical ZIP SHA-256 mismatch: {actual} != {EXPECTED_SHA256}")
    print(f"Task 20-D2A canonical package PASS: {output} sha256={actual}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
