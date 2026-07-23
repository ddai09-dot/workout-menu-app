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
- stopped step: `Run Task 20-B Flutter checks` / shared Flutter checks
- stopped sub-step: `flutter_pub_get`
- exit code: 1
- Drift generation: not run
- strict analysis: not run
- Flutter Test: not run
- iOS Simulator build: not run

Solver cause:

`build_runner >=2.15.2` requires `meta ^1.18.3`, while Flutter 3.44.6 pins `meta 1.18.0`. Therefore `build_runner ^2.15.2` is incompatible with the pinned Flutter SDK.

Decision:

- Retain the exact `build_runner 2.15.1` compatibility pin.
- Do not interpret the failed joint trial as evidence about `drift_dev 2.34.4`, because dependency solving stopped first on the `build_runner` conflict.

## Attempt 2 — isolated drift_dev update

Trial changes:

- retain `build_runner: 2.15.1`
- `drift_dev: 2.34.0` → `drift_dev: ^2.34.4`

This isolated trial determines whether only the `drift_dev` exact pin can be removed.

## Acceptance conditions

The isolated change is eligible for merge only when both Linux and macOS lanes pass all of the following:

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

- `build_runner` remains exactly `2.15.1`
- `drift_dev` constraint is `^2.34.4`
- resolved `drift_dev` is at least `2.34.4`

## Failure policy

A dependency resolution, generation, analyzer, test, or iOS build failure means the relevant exact pin remains in place. The PR must not be merged merely to remove a temporary pin.

Any failure record must include:

- stopped step
- exit code
- dependency solver message or generated-source difference
- correction or reason for retaining the pin
- rerun result, when a safe correction exists

## Scope

- Runtime functionality changed: none
- Database schema changed: none
- User data migration changed: none
- Current ZIP integration structure changed: no
