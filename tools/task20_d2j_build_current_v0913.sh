#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

bash tools/task20_d2j_build_current_v0912.sh

test "$(shasum -a 256 implementation-v0.9.12.zip | awk '{print $1}')" = "a1a2c89d73324a72d10a1d9b8a50bc896cf358f71a7c5dc485b8c3bd4faeb2a3"

python3 tools/task20_d2j_build_canonical_v0913.py app implementation-v0.9.13.zip
rm -rf app && mkdir app && unzip -q implementation-v0.9.13.zip -d app
test -f app/pubspec.yaml && test -f app/FILE_MANIFEST.txt
python3 tools/task20_d2j_verify_canonical_v0913.py app
test "$(shasum -a 256 implementation-v0.9.13.zip | awk '{print $1}')" = "d6b0016b669bde9091294c52d7c138ce964d90515b3dd42320bac784f3eef586"
