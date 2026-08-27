#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"
bash tools/task20_d2j_build_current_v0917.sh
test "$(shasum -a 256 implementation-v0.9.17.zip | awk '{print $1}')" = "969ccdf461d90a0936bce11050930b339d7bb50d6b879830b56d15f633560b2c"
python3 tools/task20_d2j_build_canonical_v0918.py app implementation-v0.9.18.zip
rm -rf app && mkdir app && unzip -q implementation-v0.9.18.zip -d app
python3 tools/task20_d2j_verify_canonical_v0918.py app
test "$(shasum -a 256 implementation-v0.9.18.zip | awk '{print $1}')" = "9d1c765ec0dcefb15170516e45ee93492bb775e00e75bf2f4f94db67edb90f82"
