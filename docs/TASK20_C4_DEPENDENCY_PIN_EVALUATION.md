# Task 20-C4 — Dependency pin evaluation

## Purpose

Evaluate whether the temporary exact pins introduced by Task 20-B2 can be removed under Flutter 3.44.6 without breaking dependency resolution, Drift generation, strict analysis, Flutter tests, or the iOS Simulator build.

## Trial changes

- `build_runner: 2.15.1` → `build_runner: ^2.15.2`
- `drift_dev: 2.34.0` → `drift_dev: ^2.34.4`

The trial restores the constraints that existed in the v0.9.1 implementation package before the Task 20-B2 compatibility pins were applied.

## Acceptance conditions

The change is eligible for merge only when both Linux and macOS lanes pass all of the following:

1. Flutter 3.44.6 official SDK verification
2. `flutter pub get`
3. Drift generation
4. `make verify`
5. strict `flutter analyze` with zero findings
6. Flutter Test
7. iOS Simulator debug build
8. resolved-version verifier
9. Artifact upload containing `pubspec.yaml`, `pubspec.lock`, logs, and generated files

## Failure policy

A dependency resolution, generation, analyzer, test, or iOS build failure means the exact pins remain in place. The PR must not be merged merely to remove temporary pins.

Any failure record must include:

- stopped step
- exit code
- dependency solver message or generated-source difference
- correction or reason for retaining the pins
- rerun result, when a safe correction exists

## Scope

- Runtime functionality changed: none
- Database schema changed: none
- User data migration changed: none
- Current ZIP integration structure changed: no
