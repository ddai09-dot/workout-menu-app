# Task 20-D2I Review

## Purpose

Automate the remaining Simulator acceptance for D2-09 local-data reset without changing product code. The test verifies physical deletion of the current user's persisted rows, replacement anonymous identity, preservation of non-user content and another user, and non-resurrection after an OS-level process termination and separate relaunch.

## Baseline

- implementation v0.9.7 / app 0.9.7+25
- Schema v9 / 75 app tables
- Branch starts from main commit `60adb0f2b5f3de27b5009d19727f29b8dfe5667a`
- D2I design baseline: v0.6

## Change boundary

D2I initially changes test/CI/review files only:

- D2I integration-test overlay
- D2I two-phase runner and driver
- iOS CI connection and evidence upload
- this review note

It does **not** change product `lib/` code, Schema, Migration, Seed, assets, or the fixed v0.9.7 package.

## Acceptance model

Phase 1 creates real user data through existing D2 helpers, adds focused contract fixtures, exercises reset cancel and reset confirm through the UI, then verifies the reset contract immediately. The app is kept running and the host must successfully execute `xcrun simctl terminate`.

Phase 2 starts a separate `flutter drive` on the same Simulator/data and verifies that the reset state survives process restart.

Startup retries are allowed only before any screenshot for the affected phase and only for recognized launch/debug-connect infrastructure failures. Assertion failures, reset failures, data mismatches, FK violations, and process-termination failures are not retried.

## Dynamic Schema checks

The test derives the app-table set from `sqlite_master` and each table's columns from `PRAGMA table_info` at runtime. It requires:

- 75 app tables
- 53 tables with `user_id`
- all 53 to have a single `id` primary key
- 21 preserved tables plus `user_account`
- exact name equality with the Schema v9 audit baselines from D2I design v0.6

## Deletion proof

Before reset the test records, for every user-owned table:

- old-user row count
- IDs of old-user rows

After reset and again after restart it requires:

- old-user row count = 0 in all 53 tables
- every pre-reset old-row ID absent regardless of `user_id`
- old `user_account` absent
- replacement account `ANONYMOUS / ACTIVE`
- Secure Storage `current_user_id` equals the replacement ID
- complete `user_account` ID set equals pre-reset set minus old ID plus replacement ID

This distinguishes physical deletion from merely reassigning old rows to another user ID.

## Preservation proof

The test inserts an `ai_faq` sentinel and another user's account/profile before baseline capture. For all 21 preserved tables it records both row count and a type-aware, order-independent SHA-256 content fingerprint. Reset and restart must leave both values unchanged. It also requires the 75-table schema fingerprint and `PRAGMA foreign_key_check` result to remain unchanged/clean.

## UI evidence

Four screenshots per device, eight total:

1. `D2I_01_reset_ready.png`
2. `D2I_02_intro_after_reset.png`
3. `D2I_03_intro_after_restart.png`
4. `D2I_04_clean_basic_info_after_restart.png`

## Result boundary

A D2I PASS may promote D2-09 to `AUTOMATED PASS` for the defined Simulator acceptance scope and add D2I screens to D2-10 partial coverage. It does **not** complete Task20-D2 or Task20-B and does not verify physical iPhone, Dynamic Type detail, native accessibility, or reset interruption between Secure Storage switch and DB commit. That interruption remains a separate D2-08 case.
