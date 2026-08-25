#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"
bash tools/task20_d2j_build_current_v0916.sh
test "$(shasum -a 256 implementation-v0.9.16.zip | awk '{print $1}')" = "e9e5d5f87eba8bde626bd14f7e2de6535f608edaa5cd1bac84b63b43e4040644"
python3 tools/task20_d2j_build_canonical_v0917.py app implementation-v0.9.17.zip
rm -rf app && mkdir app && unzip -q implementation-v0.9.17.zip -d app
python3 tools/task20_d2j_verify_canonical_v0917.py app
test "$(shasum -a 256 implementation-v0.9.17.zip | awk '{print $1}')" = "969ccdf461d90a0936bce11050930b339d7bb50d6b879830b56d15f633560b2c"
