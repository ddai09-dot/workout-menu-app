#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

bash tools/task20_d2j_build_current_v0921.sh
test "$(shasum -a 256 implementation-v0.9.21.zip | awk '{print $1}')" = "678d2e00c4d52b324be18c4b266e6eda49a51478b4e732456ebc0c32bf4a6447"

python3 - "$ROOT/app" "$ROOT/implementation-v0.9.22.zip" "$ROOT/tools/task20_d2j_v0922.patch.gz.b64" <<'PYINNER'
from __future__ import annotations
import base64, gzip, hashlib, json, shutil, stat, subprocess, sys, tempfile, zipfile
from pathlib import Path

EXPECTED_ZIP = "714b56ed1f074f22a500932719d75398ecfbc1c853da74e01eda85c4601fa6eb"
PATCH_SHA = "a182569ec8020758f7d442758b1275ea0ad8d39535ee2d4117b5bb1fb48605b4"
PARENT_LIB = "66bacd2e5bd052e4726e17592e99f5c3a46df61d8fb35bfee7a6c145db7fe4d1"
EXPECTED = {
    "runtime": "a721adad6bdb97a2b39bafb0a49e83ce6c5474e05467b13f5b79a8177571b6ae",
    "product_lib": "01cf834d370b2437dc14bc379964c2c93ccd4cc2c09cbd23632fe79518bf0e6e",
    "tests": "878bdfb548bcd42afbc3def4d7c6e680fd25432c0588c05e6a7bbf50bbfeeca5",
    "schema": "bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af",
    "assets": "cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe",
}
PATCH_B64_PATH = Path(sys.argv[3]).resolve()
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
if "version: 0.9.21+39" not in (source / "pubspec.yaml").read_text(encoding="utf-8"):
    raise SystemExit("requires canonical v0.9.21 / 0.9.21+39")
patch = gzip.decompress(base64.b64decode(PATCH_B64_PATH.read_text(encoding="ascii")))
actual_patch_sha = hashlib.sha256(patch).hexdigest()
if actual_patch_sha != PATCH_SHA:
    raise SystemExit(f"v0.9.22 patch SHA mismatch: {actual_patch_sha} != {PATCH_SHA}")

with tempfile.TemporaryDirectory(prefix="task20-d2j-v0922-") as temp_dir:
    root = Path(temp_dir) / "app"
    shutil.copytree(source, root)
    patch_path = Path(temp_dir) / "v0922.patch"
    patch_path.write_bytes(patch)
    check = subprocess.run(["git", "apply", "--check", str(patch_path)], cwd=root, text=True, capture_output=True)
    if check.returncode:
        raise SystemExit(f"v0.9.22 patch precondition failed:\n{check.stdout}{check.stderr}")
    applied = subprocess.run(["git", "apply", str(patch_path)], cwd=root, text=True, capture_output=True)
    if applied.returncode:
        raise SystemExit(f"v0.9.22 patch apply failed:\n{applied.stdout}{applied.stderr}")

    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    product = (root / "lib/features/onboarding/presentation/steps/onboarding_steps.dart").read_text(encoding="utf-8")
    if "version: 0.9.22+40" not in pubspec:
        raise SystemExit("v0.9.22 version marker missing")
    if "initialValue: selectedAction,\n                isExpanded: true,\n                itemHeight: null," not in product:
        raise SystemExit("v0.9.22 restriction dropdown width fix marker missing")

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
        raise SystemExit(f"v0.9.22 tree mismatch: {hashes}")
    if hashes["product_lib"] == PARENT_LIB:
        raise SystemExit("v0.9.22 must contain restriction dropdown width fix")

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
    raise SystemExit(f"v0.9.22 ZIP SHA mismatch: {actual_zip} != {EXPECTED_ZIP}")
print(json.dumps({
    "status": "PASS",
    "task": "Task20-D2J restrictions Dynamic Type width fix",
    "canonical_package": "implementation-v0.9.22.zip",
    "app_version": "0.9.22+40",
    "parent_canonical_version": "0.9.21+39",
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

rm -rf app && mkdir app && unzip -q implementation-v0.9.22.zip -d app
python3 app/tools/verify_project_consistency.py
python3 app/tools/verify_weekly_algorithm_traceability.py
python3 app/tools/verify_task20_b_execution_lane.py
test "$(shasum -a 256 implementation-v0.9.22.zip | awk '{print $1}')" = "714b56ed1f074f22a500932719d75398ecfbc1c853da74e01eda85c4601fa6eb"
