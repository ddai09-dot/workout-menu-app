#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

bash tools/task20_d2j_build_current_v0915.sh

test "$(shasum -a 256 implementation-v0.9.15.zip | awk '{print $1}')" = "ccf69d61ee4f98e7c3a0e8926ab42c53cf868f133303d573b1d30896d6119b60"

python3 tools/task20_d2j_build_canonical_v0916.py app implementation-v0.9.16.zip
rm -rf app && mkdir app && unzip -q implementation-v0.9.16.zip -d app
test -f app/pubspec.yaml && test -f app/FILE_MANIFEST.txt
python3 tools/task20_d2j_verify_canonical_v0916.py app
test "$(shasum -a 256 implementation-v0.9.16.zip | awk '{print $1}')" = "e9e5d5f87eba8bde626bd14f7e2de6535f608edaa5cd1bac84b63b43e4040644"
