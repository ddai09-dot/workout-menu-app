#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"
bash tools/task20_d2j_build_current_v0918.sh
test "$(shasum -a 256 implementation-v0.9.18.zip | awk '{print $1}')" = "9d1c765ec0dcefb15170516e45ee93492bb775e00e75bf2f4f94db67edb90f82"
python3 tools/task20_d2j_build_canonical_v0919.py app implementation-v0.9.19.zip
rm -rf app && mkdir app && unzip -q implementation-v0.9.19.zip -d app
python3 tools/task20_d2j_verify_canonical_v0919.py app
test "$(shasum -a 256 implementation-v0.9.19.zip | awk '{print $1}')" = "94590c894063c6fac75a8db766ea2d0aa6bfe30842428e578f96e7094d614b0e"
