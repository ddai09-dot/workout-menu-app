# Task 20-C4 — Dependency pin evaluation

## Purpose

Evaluate whether the temporary exact pins introduced by Task 20-B2 can be reduced under Flutter 3.44.6 without breaking dependency resolution, Drift generation, strict analysis, Flutter tests, or the iOS Simulator build.

## Attempt 1 — joint update

Trial changes:

- `build_runner: 2.15.1` → `build_runner: ^2.15.2`
- `drift_dev: 2.34.0` → `drift_dev: ^2.34.4`

Result: **FAIL**

- Flutter run: #34
- iOS run: #21
- stopped sub-step: `flutter_pub_get`
- exit code: 1

Cause:

`build_runner >=2.15.2` requires `meta ^1.18.3`, while Flutter 3.44.6 pins `meta 1.18.0`.

Decision:

- Retain the exact `build_runner 2.15.1` compatibility pin.
- Test `drift_dev` separately.

## Attempt 2 — drift_dev 2.34.4 or later

Trial changes:

- retain `build_runner: 2.15.1`
- `drift_dev: 2.34.0` → `drift_dev: ^2.34.4`

Result: **FAIL**

- Flutter run: #37
- iOS run: #24
- stopped sub-step: `flutter_pub_get`
- exit code: 1
- Drift generation, strict analysis, Flutter Test, and iOS Simulator build: not run

Cause:

`drift_dev >=2.34.1+1` requires `analyzer ^13.0.0`. Under the current dependency graph, Flutter Test pins `matcher 0.12.19` and `test_api 0.7.11`; Supabase requires `web_socket_channel ^3.0.0`; Riverpod requires `test ^1.0.0`. These constraints are incompatible with `drift_dev >=2.34.1+1`.

Decision:

- Do not require `drift_dev 2.34.4` or later under Flutter 3.44.6.
- Test whether the exact pin can be replaced with the compatible range `^2.34.0`.

## Attempt 3 — compatible drift_dev range

Trial changes:

- retain `build_runner: 2.15.1`
- `drift_dev: 2.34.0` → `drift_dev: ^2.34.0`

Result: **PASS**

- Flutter run: #40
- iOS run: #27
- resolved `build_runner`: `2.15.1`
- resolved `drift_dev`: `2.34.0`
- `flutter pub get`: PASS
- Drift generation: PASS
- `make verify`: PASS
- strict `flutter analyze`: Error 0 / Warning 0 / Info 0
- Flutter Test: 48 / 48 PASS
- iOS Simulator debug build: PASS
- dependency-resolution verifier: PASS in both lanes
- Artifact upload: PASS in both lanes

## Final decision

### Retain

- Exact `build_runner 2.15.1` compatibility pin

Reason:

Flutter 3.44.6 pins `meta 1.18.0`, which is incompatible with `build_runner >=2.15.2`.

Reconsider when:

The pinned Flutter SDK permits the `meta` version required by a newer `build_runner`, and the full Linux/macOS validation lanes pass.

### Replace

- Exact `drift_dev 2.34.0` pin → compatible constraint `drift_dev ^2.34.0`

Reason:

The current dependency graph selects the verified compatible version 2.34.0, while allowing the constraint to move when a future Flutter/dependency graph supports a later compatible release.

Boundary:

`drift_dev 2.34.4` or later is not currently compatible and was not adopted.

## Acceptance evidence

Both Linux and macOS lanes passed:

1. Flutter 3.44.6 official SDK verification
2. `flutter pub get`
3. Drift generation
4. `make verify`
5. strict `flutter analyze` with zero findings
6. Flutter Test
7. iOS Simulator debug build
8. resolved-version verifier
9. Artifact upload containing `pubspec.yaml`, `pubspec.lock`, logs, and generated files

## Scope

- Runtime functionality changed: none
- Database schema changed: none
- User data migration changed: none
- Current ZIP integration structure changed: no
