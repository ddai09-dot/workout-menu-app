#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

bash tools/task20_d2j_build_current_v0919.sh
test "$(shasum -a 256 implementation-v0.9.19.zip | awk '{print $1}')" = "94590c894063c6fac75a8db766ea2d0aa6bfe30842428e578f96e7094d614b0e"

python3 - "$ROOT/app" "$ROOT/implementation-v0.9.20.zip" <<'PYINNER'
from __future__ import annotations
import base64, gzip, hashlib, json, shutil, stat, subprocess, sys, tempfile, zipfile
from pathlib import Path

EXPECTED_ZIP = "d94fd5cc83cabef0b9b0949961175f2f6421bf7d54981e746dcd02635c68469f"
PATCH_SHA = "42a634a0959f900dc5b26e8859dadccc4ed76bf9005b3f02aa1f9dece438f47c"
PARENT_LIB = "fc41b29ffc12ebea1601cb9f230833521deaf65b6e1edc520f4542f64ca63904"
EXPECTED = {
    "runtime": "237f41e418b63eb0dae2a86276dd8b69b97459a0dd346b5b1ed32e7687470500",
    "product_lib": "1e8b07494d6a47aa6bedd03384e15647170e24c92fbf297622d20afd897175dc",
    "tests": "878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5",
    "schema": "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af",
    "assets": "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe",
}
PATCH_B64 = "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..."
EXCLUDED = {"build", ".dart_tool"}

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
            files.extend(item for item in path.rglob("*") if item.is_file())
        else:
            files.append(path)
    for path in sorted(set(files), key=lambda item: item.relative_to(root).as_posix()):
        rel = path.relative_to(root).as_posix()
        digest.update(rel.encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()

source = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
if "version: 0.9.19+37" not in (source / "pubspec.yaml").read_text(encoding="utf-8"):
    raise SystemExit("requires canonical v0.9.19 / 0.9.19+37")
patch = gzip.decompress(base64.b64decode(PATCH_B64))
actual_patch_sha = hashlib.sha256(patch).hexdigest()
if actual_patch_sha != PATCH_SHA:
    raise SystemExit(f"v0.9.20 patch SHA mismatch: {actual_patch_sha} != {PATCH_SHA}")

with tempfile.TemporaryDirectory(prefix="task20-d2j-v0920-") as temp_dir:
    root = Path(temp_dir) / "app"
    shutil.copytree(source, root)
    patch_path = Path(temp_dir) / "v0920.patch"
    patch_path.write_bytes(patch)
    check = subprocess.run(["git", "apply", "--check", str(patch_path)], cwd=root, text=True, capture_output=True)
    if check.returncode:
        raise SystemExit(f"v0.9.20 patch precondition failed:\n{check.stdout}{check.stderr}")
    applied = subprocess.run(["git", "apply", str(patch_path)], cwd=root, text=True, capture_output=True)
    if applied.returncode:
        raise SystemExit(f"v0.9.20 patch apply failed:\n{applied.stdout}{applied.stderr}")

    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    readme = (root / "README.md").read_text(encoding="utf-8")
    matrix = (root / "docs/VERSION_MATRIX.md").read_text(encoding="utf-8")
    decision = (root / "docs/DECISION_LOG.md").read_text(encoding="utf-8")
    product = (root / "lib/features/settings/presentation/training_settings_edit_page.dart").read_text(encoding="utf-8")
    required = [
        ("version: 0.9.20+38", pubspec),
        ("実装基盤 v0.9.20", readme),
        ("現在のプロジェクト版：`0.9.20+38`", matrix),
        ("| 0.9.20 |", matrix),
        ("D-028", decision),
        ("RenderFlex overflowed by 162 pixels", decision),
    ]
    for marker, text in required:
        if marker not in text:
            raise SystemExit(f"Missing v0.9.20 marker: {marker}")
    for marker in [
        "appBar: AppBar(title: const Text('設定'))",
        "title: const Text('設定')",
        "label: '保存中'",
        "CircularProgressIndicator(strokeWidth: 2)",
        "scrollable: true",
        "style: Theme.of(context).textTheme.headlineSmall",
    ]:
        if marker not in product:
            raise SystemExit(f"Missing settings enlarged-text fix marker: {marker}")
    if "title: Text(section.title)" in product:
        raise SystemExit("long section title remains in AppBar")

    files = package_files(root)
    manifest = [line for line in (root / "FILE_MANIFEST.txt").read_text(encoding="utf-8").splitlines() if line]
    if files != manifest:
        raise SystemExit("FILE_MANIFEST mismatch")
    hashes = {
        "runtime": tree_hash(root, ["lib", "test"]),
        "product_lib": tree_hash(root, ["lib"]),
        "tests": tree_hash(root, ["test"]),
        "schema": tree_hash(root, ["docs/schema_v9.sqlite.sql", "docs/migrations", "lib/core/database/schema"]),
        "assets": tree_hash(root, ["assets"]),
    }
    if hashes != EXPECTED:
        raise SystemExit(f"v0.9.20 tree mismatch: {hashes}")
    if hashes["product_lib"] == PARENT_LIB:
        raise SystemExit("v0.9.20 must contain the intended product UI change")

    if output.exists():
        output.unlink()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for rel in files:
            path = root / rel
            info = zipfile.ZipInfo(rel, date_time=(2020, 1, 1, 0, 0, 0))
            info.create_system = 3
            mode = 0o755 if path.stat().st_mode & stat.S_IXUSR else 0o644
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            info.flag_bits |= 0x800
            archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)

actual_zip = hashlib.sha256(output.read_bytes()).hexdigest()
if actual_zip != EXPECTED_ZIP:
    raise SystemExit(f"v0.9.20 ZIP SHA mismatch: {actual_zip} != {EXPECTED_ZIP}")
print(json.dumps({
    "status": "PASS",
    "task": "Task20-D2J settings enlarged-text fix",
    "canonical_package": "implementation-v0.9.20.zip",
    "app_version": "0.9.20+38",
    "parent_canonical_version": "0.9.19+37",
    "zip_sha256": actual_zip,
    "patch_sha256": PATCH_SHA,
    "expected_flutter_test_count": 56,
    "schema_version": 9,
    "schema_table_count": 75,
    "tree_hashes": EXPECTED,
    "product_runtime_changed": True,
    "tests_changed": False,
    "schema_changed": False,
    "assets_changed": False,
    "d2j_acceptance_status": "PENDING_EXACT_CURRENT_HEAD_CI_AND_ARTIFACT_AUDIT",
}, ensure_ascii=False, sort_keys=True))
PYINNER

rm -rf app && mkdir app && unzip -q implementation-v0.9.20.zip -d app
python3 app/tools/verify_project_consistency.py
python3 app/tools/verify_weekly_algorithm_traceability.py
python3 app/tools/verify_task20_b_execution_lane.py
test "$(shasum -a 256 implementation-v0.9.20.zip | awk '{print $1}')" = "d94fd5cc83cabef0b9b0949961175f2f6421bf7d54981e746dcd02635c68469f"
