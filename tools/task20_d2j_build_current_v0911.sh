#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

expected_v091="4d6e2f77f4f18d4a9ebc19994da6039ef42d23bd0a38b7790dc1475b0a20e529"
actual_v091="$(shasum -a 256 implementation-v0.9.1.zip | awk '{print $1}')"
test "$actual_v091" = "$expected_v091"
unzip -t implementation-v0.9.1.zip >/dev/null
rm -rf app
mkdir app
unzip -q implementation-v0.9.1.zip -d app
test -f app/pubspec.yaml
test -f app/FILE_MANIFEST.txt

build_and_extract() {
  local builder="$1" output="$2" verifier="$3"
  python3 "$builder" app "$output"
  rm -rf app
  mkdir app
  unzip -q "$output" -d app
  test -f app/pubspec.yaml
  test -f app/FILE_MANIFEST.txt
  python3 "$verifier" app
}

build_and_extract tools/task20_c5_build_canonical_v092.py implementation-v0.9.2.zip tools/task20_c5_verify_canonical_package.py
build_and_extract tools/task20_d2a_build_canonical_v093.py implementation-v0.9.3.zip tools/task20_d2a_verify_canonical_v093.py
build_and_extract tools/task20_d2b_build_canonical_v094.py implementation-v0.9.4.zip tools/task20_d2b_verify_canonical_v094.py
build_and_extract tools/task20_d2e_build_canonical_v095.py implementation-v0.9.5.zip tools/task20_d2e_verify_canonical_v095.py
build_and_extract tools/task20_d2g_build_canonical_v096.py implementation-v0.9.6.zip tools/task20_d2g_verify_canonical_v096.py
build_and_extract tools/task20_d2g_build_canonical_v097.py implementation-v0.9.7.zip tools/task20_d2g_verify_canonical_v097.py
# The v0.9.11 builder first reconstructs the accepted D2I v0.9.10 parent
# from exact v0.9.7 and proves its canonical ZIP SHA before applying D2J changes.
build_and_extract tools/task20_d2j_build_canonical_v0911.py implementation-v0.9.11.zip tools/task20_d2j_verify_canonical_v0911.py

test "$(shasum -a 256 implementation-v0.9.10.zip | awk '{print $1}')" = "9fce3c9dd234fcc669ed7e5b62b8b2d612b3fa80b634bca14406cf5c6bb4836f"
test "$(shasum -a 256 implementation-v0.9.11.zip | awk '{print $1}')" = "d2bc188138c32322ede945a73dd8a8bd28a3c316efe0ad1430b463cb8bc973ab"
