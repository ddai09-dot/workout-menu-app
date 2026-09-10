#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

# Reuse the exact v0.9.7 -> accepted D2I v0.9.10 -> D2J v0.9.11 lineage.
bash tools/task20_d2j_build_current_v0911.sh

test "$(shasum -a 256 implementation-v0.9.11.zip | awk '{print $1}')" = "cd0781aa74b6be26aaf990ceb6e01a02064bb2ca0688e56d1bc603a8f95114ca"

python3 tools/task20_d2j_build_canonical_v0912.py app implementation-v0.9.12.zip
rm -rf app && mkdir app && unzip -q implementation-v0.9.12.zip -d app
test -f app/pubspec.yaml && test -f app/FILE_MANIFEST.txt
python3 tools/task20_d2j_verify_canonical_v0912.py app
test "$(shasum -a 256 implementation-v0.9.12.zip | awk '{print $1}')" = "a1a2c89d73324a72d10a1d9b8a50bc896cf358f71a7c5dc485b8c3bd4faeb2a3"
