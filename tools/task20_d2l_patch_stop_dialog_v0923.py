#!/usr/bin/env python3
"""Apply Matrix #53/#62 AXXXL dialog accessibility fixes."""

from __future__ import annotations

import hashlib
import stat
import sys
import tempfile
import zipfile
from pathlib import Path

INPUT_SHA256 = "7c4b88b6fb4058f0bd1d232cb069bd45421e798a43d0b041991b091765bcbfd6"
OUTPUT_SHA256 = "84675f0c90df6de2c704e1d1812aaf5797290c273e9b726678ad5709ab8480e8"
EXPECTED_TREE_HASHES = {
    "runtime": "147be8bc795b9088e1f9ae08a944a1a07625486a22e11ecaa862cad7b078dda2",
    "product_lib": "bad1291db5b248d8981642b6b57e6c92619a0cbdfab74d71706ee7e994777900",
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
        raise SystemExit("usage: task20_d2l_patch_stop_dialog_v0923.py <implementation-v0.9.23.zip>")

    candidate = Path(sys.argv[1]).resolve()
    actual_input = sha256(candidate.read_bytes())
    if actual_input != INPUT_SHA256:
        raise SystemExit(f"unexpected input v0.9.23 SHA: {actual_input}")

    with tempfile.TemporaryDirectory(prefix="task20-d2l-dialogs-") as temp_dir:
        root = Path(temp_dir) / "app"
        root.mkdir()
        with zipfile.ZipFile(candidate) as archive:
            archive.extractall(root)

        session = root / "lib/features/workout/presentation/workout_session_page.dart"
        replace_once(
            session,
            """    builder: (BuildContext context) => AlertDialog(\n      title: const Text('ここまでを記録して終了しますか？'),\n""",
            """    builder: (BuildContext context) => AlertDialog(\n      scrollable: true,\n      title: const Text('ここまでを記録して終了しますか？'),\n""",
        )

        settings = root / "lib/features/settings/presentation/training_settings_edit_page.dart"
        replace_once(
            settings,
            """        return AlertDialog(\n          title: const Text('変更を破棄しますか？'),\n""",
            """        return AlertDialog(\n          scrollable: true,\n          title: const Text('変更を破棄しますか？'),\n""",
        )

        readme = root / "README.md"
        existing = "- トレーニング中の入力行は値をラベル下へ配置し、最大文字サイズでも値＋操作アイコンが横幅を奪い合わない構造にする。\n"
        replace_once(
            readme,
            existing,
            existing + "- 途中終了の確認ダイアログをスクロール対応にし、最大文字サイズでも説明と終了操作を画面内で利用できるようにする。\n" + "- 設定編集の変更破棄ダイアログもスクロール対応にし、最大文字サイズでも確認文と操作を欠落させない。\n",
        )

        decision = root / "docs/DECISION_LOG.md"
        existing = "- 追加事実：Matrix #52の同カテゴリは上記修正とD2E lazy-materialization hardeningを通過後、トレーニング中の入力`ListTile`で値＋操作アイコンのtrailing `Row`が49px横overflowすることを検出した。値をsubtitleへ移して操作アイコンのみをtrailingに残し、拡大文字でも横幅競合しない構造へ変更する。\n"
        replace_once(
            decision,
            existing,
            existing + "- 追加事実：Matrix #53の同カテゴリは入力行修正後さらにD2Eを進行し、途中終了確認`AlertDialog`で159pxの縦overflowを検出した。ダイアログをスクロール対応にし、最大文字サイズでも確認文と終了操作の到達性を維持する。\n" + "- 追加事実：Matrix #62は11/12カテゴリPASS。AXXXLはD1／D2A／D2D／D2Eを通過後、設定編集の変更破棄`AlertDialog`で24pxの縦overflowを検出した。ダイアログをスクロール対応にし、最大文字サイズでも破棄確認操作の到達性を維持する。\n",
        )

        files = package_files(root)
        manifest = [
            line
            for line in (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8").splitlines()
            if line
        ]
        if files != manifest:
            raise SystemExit("patched v0.9.23 FILE_MANIFEST mismatch")

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
            raise SystemExit(f"patched v0.9.23 tree mismatch: {hashes}")

        staged = candidate.with_suffix(".dialogs.zip")
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

        actual_output = sha256(staged.read_bytes())
        if actual_output != OUTPUT_SHA256:
            raise SystemExit(
                f"patched v0.9.23 ZIP SHA mismatch: {actual_output} != {OUTPUT_SHA256}"
            )
        staged.replace(candidate)

    print(
        "patched v0.9.23 dialogs: "
        f"sha256={OUTPUT_SHA256} runtime={EXPECTED_TREE_HASHES['runtime']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
