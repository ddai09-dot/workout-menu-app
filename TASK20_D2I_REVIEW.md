# Task 20-D2I Review

## Purpose

Automate the remaining Simulator acceptance for D2-09 local-data reset. D2I must prove physical deletion of the current user's local rows, replacement anonymous identity, preservation of non-user content and another user, and non-resurrection after an OS-level process termination and separate relaunch.

The acceptance baseline remains D2I design v0.6. Acceptance conditions are not relaxed to fit implementation behavior.

## Baseline and candidate history

- base main: `60adb0f2b5f3de27b5009d19727f29b8dfe5667a`
- current main canonical: implementation v0.9.7 / app 0.9.7+25
- D2I design baseline: v0.6
- historical v0.9.7 remains immutable
- v0.9.8 is retained as the first D2I product-fix candidate and is not overwritten
- current candidate: implementation v0.9.9 / app 0.9.9+27
- v0.9.9 ZIP SHA-256: `82186032482561daf7b56cfeeb8fdb5fd318aa294198af1abb65e72d2c123016`
- v0.9.9 runtime tree: `120ce9febc4a30d54909f04ba9f394aba2921c35e86237ac11a37708e7beb302`
- Schema v9 / 75 app tables
- Schema tree: `bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af`
- assets tree: `cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe`
- v0.9.9 patch SHA-256: `0f2272ce052aaeabd546e0ccf8fc6a52a98b6cc83454ab903858eab76538952c`

## Defect 1 discovered from v0.9.7

Earlier iOS run #187 reached D2I runtime but failed before reset fixture verification. Investigation found that Onboarding could create a DB account/profile while `LocalAccountRepository` could create a different anonymous account when Secure Storage `current_user_id` was missing. The visible user and reset deletion target could therefore diverge.

v0.9.8 fixed current-account recovery by reusing a unique active, undeleted account with a completed profile and refusing to guess when multiple completed candidates exist. Four regression tests were added. Schema, Migration, Seed, assets, and the 53-table deletion allowlist remained unchanged.

## iOS #196 result and Defect 2

Current-head predecessor `e4cafb880491341ed4d43d39c29a83266d47b24f` produced Flutter #209 SUCCESS and iOS #196 FAILURE.

In #196 regular Simulator Phase 1:

- v0.9.8 build/verify passed
- D2I overlay analyzer passed with zero issues
- reset UI execution passed
- old-user rows across all 53 user-owned tables were zero after reset
- pre-reset old row IDs remaining were zero
- replacement anonymous ID was created
- foreign-key check was zero
- the strengthened pre-reset account-set assertion passed
- `xcrun simctl terminate` completed and Phase 2 started as a separate `flutter drive`

Phase 2 then failed with `Timed out waiting for stable onboarding intro.` This is not classified as a permitted launch/debug-connect retry because the application had launched and the product-state expectation itself was not met.

Artifact and source inspection identified two Onboarding scope defects:

1. Showing the reset destination `/onboarding` creates an `IN_PROGRESS` draft at `INTRO`. On restart, `loadStatus()` treated that intro-only draft as resumable progress, so the app no longer remained at the clean intro state required after reset.
2. `LocalOnboardingRepository` used global profile/draft/account lookups instead of the current account identity. With another preserved user present, Onboarding state or a newly created draft could be associated with the wrong local account.

## v0.9.9 fix

v0.9.9 keeps the D2I acceptance contract unchanged and fixes the product boundary instead:

- Onboarding status and draft operations resolve the current user through `AccountRepository`.
- Completed-profile, draft-read, draft-write, and completion queries are scoped by that current user ID.
- An `IN_PROGRESS` draft whose current step is only `INTRO` is treated as `notStarted` rather than resumable progress.
- `BASIC_INFO` and later drafts remain resumable, preserving D2C behavior.
- The global "oldest active account" fallback is removed from the Onboarding path.

Four regression tests cover:

- another user's completed profile does not mark the current user complete
- intro-only current-user draft is `notStarted`
- advanced current-user draft remains `inProgress`
- `loadOrCreateDraft()` creates/uses only the current account even when another user exists

Local static verification passed for the 26 `make verify` checks, Onboarding contract, local-data-reset contract, project consistency, Task20-B execution-lane contract, deterministic v0.9.9 builder, and v0.9.9 verifier. Flutter analyzer/unit tests and iOS runtime acceptance remain CI-only formal evidence.

## Acceptance model

Phase 1 creates real data through existing D2 helpers, inserts focused preservation fixtures, executes reset cancel/confirm through the UI, verifies deletion and preservation immediately, then requires an OS-level process termination.

Phase 2 uses the same Simulator and app data in a separate `flutter drive` and verifies intro state, replacement identity, Secure Storage, 53-table deletion, old row-ID disappearance, 21 preserved tables, other-user preservation, schema fingerprint, foreign keys, and absence of old nickname resurrection.

Startup retry remains allowed only before evidence generation and only for recognized launch/debug-connect infrastructure failures. Assertion, reset, data-contract, FK, and product-state failures are never retried.

## UI evidence

Four screenshots per device, eight total:

1. `D2I_01_reset_ready.png`
2. `D2I_02_intro_after_reset.png`
3. `D2I_03_intro_after_restart.png`
4. `D2I_04_clean_basic_info_after_restart.png`

## Result boundary

D2I remains Pending until the current v0.9.9 Head passes:

- Flutter/common CI on that exact Head
- deterministic v0.9.9 build/verify
- both regular and compact Simulator D2I Phase 1/2
- all existing iOS regression acceptance steps
- clean analyzer and dependency gates
- result JSON/log inspection
- all 8 D2I PNGs and Artifact integrity inspection

Only after those checks may D2-09 become `AUTOMATED PASS` for the defined Simulator scope and D2-10 gain the D2I screen increment.

Even after D2I passes, the following remain incomplete: reset interruption between Secure Storage switch and DB commit (separate D2-08 case), D2-10 untested portions, D2-11, physical iPhone, Dynamic Type detail, native accessibility, Task20-D2 overall, and Task20-B overall.

PR #18 remains Draft and unmerged until an explicit later decision.
