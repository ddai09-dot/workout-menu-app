#!/usr/bin/env python3
"""Finalize the v0.9.23 D2L candidate after the first exact-head matrix."""

from __future__ import annotations

import hashlib
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

INPUT_SHA256 = "0ee2baff7fab5f02dde3dc73acb7b22f61b752805d6fc41369cf5c7ae684f2ea"
OUTPUT_SHA256 = "7c4b88b6fb4058f0bd1d232cb069bd45421e798a43d0b041991b091765bcbfd6"
EXPECTED_PUBSPEC_SHA256 = "243a2ad8e6d3afd291046523a23a8d87b32f7683b8217d8d139c68a7183a2c28"
EXPECTED_TREE_HASHES = {
    "runtime": "f66638a10ac29279da8ddacb6c2eaca30db9deb39333373ac0b4551a7b6e4c82",
    "product_lib": "e87162920b4d3358f246e2a680961fbcb38d43bd896a6ae56ef43d44e0a9344e",
    "tests": "878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5",
    "schema": "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af",
    "assets": "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe",
}
EXCLUDED = {"build", ".dart_tool"}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


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


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: task20_d2l_finalize_v0923_candidate.py <implementation-v0.9.23.zip>")

    candidate = Path(sys.argv[1]).resolve()
    if sha256(candidate.read_bytes()) != INPUT_SHA256:
        raise SystemExit("unexpected pre-finalization v0.9.23 candidate SHA")

    with tempfile.TemporaryDirectory(prefix="task20-d2l-finalize-v0923-") as temp_dir:
        root = Path(temp_dir) / "app"
        root.mkdir()
        with zipfile.ZipFile(candidate) as archive:
            archive.extractall(root)

        steps = root / "lib/features/weekly_planner/presentation/steps/weekly_planner_steps.dart"
        replace_once(
            steps,
            """          DropdownButtonFormField<String>(\n            initialValue: draft.increaseMethodCode,\n""",
            """          DropdownButtonFormField<String>(\n            isExpanded: true,\n            initialValue: draft.increaseMethodCode,\n""",
        )
        replace_once(
            steps,
            """        DropdownButtonFormField<String>(\n          initialValue: draft.splitOverrideCode ?? 'DEFAULT',\n""",
            """        DropdownButtonFormField<String>(\n          isExpanded: true,\n          initialValue: draft.splitOverrideCode ?? 'DEFAULT',\n""",
        )

        workout_adjustment = (
            root / "lib/features/workout/presentation/workout_adjustment_page.dart"
        )
        replace_once(
            workout_adjustment,
            """              child: Column(\n                mainAxisSize: MainAxisSize.min,\n                crossAxisAlignment: CrossAxisAlignment.stretch,\n                children: <Widget>[\n""",
            """              child: SingleChildScrollView(\n                child: Column(\n                  mainAxisSize: MainAxisSize.min,\n                  crossAxisAlignment: CrossAxisAlignment.stretch,\n                  children: <Widget>[\n""",
        )
        replace_once(
            workout_adjustment,
            """                ],\n              ),\n            );\n""",
            """                  ],\n                ),\n              ),\n            );\n""",
        )

        workout_session = root / "lib/features/workout/presentation/workout_session_page.dart"
        replace_once(
            workout_session,
            """    return ListTile(\n      contentPadding: EdgeInsets.zero,\n      title: Text(label),\n      trailing: Row(\n        mainAxisSize: MainAxisSize.min,\n        children: <Widget>[\n          Text(value, style: Theme.of(context).textTheme.titleMedium),\n          const SizedBox(width: 4),\n          const Icon(Icons.unfold_more),\n        ],\n      ),\n      onTap: onTap,\n    );\n""",
            """    return ListTile(\n      contentPadding: EdgeInsets.zero,\n      title: Text(label),\n      subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium),\n      trailing: const Icon(Icons.unfold_more),\n      onTap: onTap,\n    );\n""",
        )

        readme = root / "README.md"
        replace_once(
            readme,
            "- 週間メニュー下部の主要／修正アクションを明示的な全幅ボタンにし、拡大文字ラベルを画面幅内で折返せるようにする。\n",
            "- 週間メニュー下部の主要／修正アクションを明示的な全幅ボタンにし、拡大文字ラベルを画面幅内で折返せるようにする。\n"
            "- `accessibility-extra-extra-extra-large`で検出した痛み対応ボトムシートの縦overflowを、内容全体のスクロール対応で解消し、最大文字サイズでも追加ボタンまで到達可能にする。\n"
            "- トレーニング中の入力行は値をラベル下へ配置し、最大文字サイズでも値＋操作アイコンが横幅を奪い合わない構造にする。\n",
        )

        matrix = root / "docs/VERSION_MATRIX.md"
        replace_once(
            matrix,
            "| 0.9.23 | 9 | Task20-D2L weekly planner enlarged-text action fix | 全12サイズmatrixで検出した調整方針画面の右36px overflowを、下部アクションの全幅・折返し対応で是正 |",
            "| 0.9.23 | 9 | Task20-D2L enlarged-text layout fixes | 全12サイズmatrixで検出した調整方針画面の右36px overflowを下部アクションの全幅・折返し対応で是正し、最大文字サイズの痛み対応ボトムシート縦overflowとトレーニング入力行の横overflowを是正 |",
        )

        decision = root / "docs/DECISION_LOG.md"
        replace_once(
            decision,
            "- 併記：`accessibility-extra-extra-extra-large`でD2D年齢pickerのplaceholderが固定下部ボタンに覆われた件は、D2Aと同じInkWell tap target＋ensureVisible方式へharnessを統一する。\n",
            "- 併記：`accessibility-extra-extra-extra-large`でD2D年齢pickerのplaceholderが固定下部ボタンに覆われた件は、D2Aと同じInkWell tap target＋ensureVisible方式へharnessを統一する。\n"
            "- 追加事実：Matrix #28の`accessibility-extra-extra-extra-large`はD2A／D2Dを通過後、D2Eの痛み対応ボトムシートで`RenderFlex overflowed by 105 pixels on the bottom`を検出した。`この対応を追加する`も画面外となり操作不能だったため、製品UI不具合としてボトムシート内容を縦スクロール可能にする。\n"
            "- 追加事実：Matrix #52の同カテゴリは上記修正とD2E lazy-materialization hardeningを通過後、トレーニング中の入力`ListTile`で値＋操作アイコンのtrailing `Row`が49px横overflowすることを検出した。値をsubtitleへ移して操作アイコンのみをtrailingに残し、拡大文字でも横幅競合しない構造へ変更する。\n",
        )

        for command in [
            [sys.executable, "tools/verify_project_consistency.py"],
            [sys.executable, "tools/verify_weekly_algorithm_traceability.py"],
            [sys.executable, "tools/verify_task20_b_execution_lane.py"],
        ]:
            completed = subprocess.run(
                command,
                cwd=root,
                text=True,
                capture_output=True,
            )
            if completed.returncode:
                raise SystemExit(
                    f"v0.9.23 finalization verification failed: {' '.join(command)}\n"
                    f"{completed.stdout}{completed.stderr}"
                )

        pubspec_sha = sha256((root / "pubspec.yaml").read_bytes())
        if pubspec_sha != EXPECTED_PUBSPEC_SHA256:
            raise SystemExit(f"v0.9.23 pubspec SHA mismatch: {pubspec_sha}")

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
        if hashes != EXPECTED_TREE_HASHES:
            raise SystemExit(f"finalized v0.9.23 tree mismatch: {hashes}")

        files = package_files(root)
        manifest = [
            line
            for line in (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8").splitlines()
            if line
        ]
        if files != manifest:
            raise SystemExit("finalized v0.9.23 FILE_MANIFEST mismatch")

        staged = candidate.with_suffix(".finalized.zip")
        staged.unlink(missing_ok=True)
        with zipfile.ZipFile(
            staged, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
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

        actual_sha = sha256(staged.read_bytes())
        if actual_sha != OUTPUT_SHA256:
            raise SystemExit(
                f"finalized v0.9.23 ZIP SHA mismatch: {actual_sha} != {OUTPUT_SHA256}"
            )
        staged.replace(candidate)

    print(
        "finalized v0.9.23 candidate: "
        f"sha256={OUTPUT_SHA256} runtime={EXPECTED_TREE_HASHES['runtime']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
