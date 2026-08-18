# Task 20-D2I Review

## Purpose

Automate the remaining Simulator acceptance for D2-09 local-data reset and fix the current-user identity defect discovered by the acceptance itself. The final acceptance must verify physical deletion of the current user's persisted rows, replacement anonymous identity, preservation of non-user content and another user, and non-resurrection after an OS-level process termination and separate relaunch.

## Baseline and product promotion

- base main: `60adb0f2b5f3de27b5009d19727f29b8dfe5667a`
- previous canonical: implementation v0.9.7 / app 0.9.7+25
- promoted candidate: implementation v0.9.8 / app 0.9.8+26
- v0.9.8 ZIP SHA-256: `96ec3656dfe8c8d03654975d54daa7160a93788abf6f03ad8e502c0d3136726f`
- Schema v9 / 75 app tables
- Schema tree remains `bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af`
- assets tree remains `cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe`
- v0.9.8 runtime tree: `21eba6d3201c7e3981e13d2f29e209c562c59f755162367ea3a0c6463952504f`
- D2I design baseline: v0.6

Historical v0.9.7 is not overwritten. v0.9.8 is deterministically generated from v0.9.7 by a SHA-pinned compressed patch and independently verified before Flutter/iOS execution.

## Defect discovered by D2I

Current-head predecessor iOS run #187 passed the D2I overlay analyzer with zero issues and reached the regular Simulator runtime. It then failed before reset at the old-nickname fixture lookup with `Bad state: No element`.

Root cause analysis against the exact v0.9.7 source used by the run showed a real product identity split:

- Onboarding creates/selects a DB `user_account` and persists `user_profile`, but does not set Secure Storage `current_user_id`.
- `LocalAccountRepository.ensureAnonymousAccount()` previously created a new anonymous account whenever that Secure Storage key was absent.
- Home/settings can still display the completed DB profile, while local-data reset resolves its deletion target through `LocalAccountRepository`.

Therefore the user visible in the app and the user selected for local-data deletion could diverge.

## v0.9.8 fix

`LocalAccountRepository` now recovers an existing local current account only under a deterministic safety rule:

- active, undeleted account
- undeleted profile
- `onboarding_completed_at IS NOT NULL`
- exactly one completed local-account candidate

If Secure Storage is absent, or points to a valid account without a completed profile, a unique completed account is restored into `current_user_id`. If no completed candidate exists, the existing anonymous-account behavior remains. If multiple completed candidates exist, the repository throws instead of guessing and risking deletion of the wrong user.

`resetLocalData()` resolves current user through the same account path and then executes the existing 53-table child-first deletion transaction and replacement-account rotation.

Four unit regression cases are added for missing Secure Storage recovery, valid-orphan Secure Storage recovery, reset after recovery, and ambiguous completed-account rejection. Schema, Migration, Seed, assets, and the 53-table deletion allowlist are unchanged.

## Change boundary

PR files include:

- D2I integration-test overlay
- D2I two-phase runner and driver
- deterministic v0.9.8 canonical builder / verifier / patch payload
- Flutter and iOS CI wiring for v0.9.8
- this review note

The product behavior change is carried only inside the new canonical v0.9.8 patch; the historical v0.9.7 ZIP remains immutable.

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

D2I remains Pending until the current v0.9.8 Head passes Flutter CI, both Simulator phases, the complete iOS regression sequence, and Artifact/result/PNG inspection.

A D2I PASS may promote D2-09 to `AUTOMATED PASS` for the defined Simulator acceptance scope and add D2I screens to D2-10 partial coverage. It does **not** complete Task20-D2 or Task20-B and does not verify physical iPhone, Dynamic Type detail, native accessibility, or reset interruption between Secure Storage switch and DB commit. That interruption remains a separate D2-08 case.
