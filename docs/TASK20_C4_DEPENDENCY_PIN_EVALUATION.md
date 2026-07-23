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
- stopped step: shared Flutter checks
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
- stopped step: shared Flutter checks
- stopped sub-step: `flutter_pub_get`
- exit code: 1
- Drift generation: not run
- strict analysis: not run
- Flutter Test: not run
- iOS Simulator build: not run

Cause:

`drift_dev >=2.34.1+1` requires `analyzer ^13.0.0`. Under the current dependency graph, Flutter Test pins `matcher 0.12.19` and `test_api 0.7.11`; Supabase requires `web_socket_channel ^3.0.0`; Riverpod requires `test ^1.0.0`. These constraints are incompatible with `drift_dev >=2.34.1+1`.

Decision:

- Do not require `drift_dev 2.34.4` or later under Flutter 3.44.6.
- Test whether the exact pin can be replaced with the compatible range `^2.34.0`, which should resolve to 2.34.0 under the current graph.

## Attempt 3 — compatible drift_dev range

Trial changes:

- retain `build_runner: 2.15.1`
- `drift_dev: 2.34.0` → `drift_dev: ^2.34.0`

The exact `drift_dev` pin may be removed only if the current dependency graph resolves to the verified compatible version 2.34.0 and all validation lanes pass.

## Acceptance conditions

Both Linux and macOS lanes must pass:

1. Flutter 3.44.6 official SDK verification
2. `flutter pub get`
3. Drift generation
4. `make verify`
5. strict `flutter analyze` with zero findings
6. Flutter Test
7. iOS Simulator debug build
8. resolved-version verifier
9. Artifact upload containing `pubspec.yaml`, `pubspec.lock`, logs, and generated files

The verifier must confirm:

- `build_runner` constraint and resolution remain exactly `2.15.1`
- `drift_dev` constraint is `^2.34.0`
- resolved `drift_dev` is exactly `2.34.0`

## Failure policy

A dependency resolution, generation, analyzer, test, or iOS build failure means the relevant exact pin remains in place. The PR must not be merged merely to remove a temporary pin.

## Scope

- Runtime functionality changed: none
- Database schema changed: none
- User data migration changed: none
- Current ZIP integration structure changed: no
