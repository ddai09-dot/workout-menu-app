#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

bash tools/task20_d2j_build_current_v0913.sh

test "$(shasum -a 256 implementation-v0.9.13.zip | awk '{print $1}')" = "d6b0016b669bde9091294c52d7c138ce964d90515b3dd42320bac784f3eef586"

python3 tools/task20_d2j_build_canonical_v0915.py app implementation-v0.9.15.zip
rm -rf app && mkdir app && unzip -q implementation-v0.9.15.zip -d app
test -f app/pubspec.yaml && test -f app/FILE_MANIFEST.txt
python3 tools/task20_d2j_verify_canonical_v0915.py app
test "$(shasum -a 256 implementation-v0.9.15.zip | awk '{print $1}')" = "ccf69d61ee4f98e7c3a0e8926ab42c53cf868f133303d573b1d30896d6119b60"
