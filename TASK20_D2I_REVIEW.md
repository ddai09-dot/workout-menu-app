# Task 20-D2I Review

## Purpose

Automate the remaining Simulator acceptance for D2-09 local-data reset. D2I must prove physical deletion of the current user's local rows, replacement anonymous identity, preservation of non-user content and another user, and non-resurrection after an OS-level process termination and separate relaunch.

The acceptance baseline remains D2I design v0.6. Acceptance conditions are not relaxed to fit implementation behavior.

## Baseline and candidate history

- base main: `60adb0f2b5f3de27b5009d19727f29b8dfe5667a`
- current main canonical: implementation v0.9.7 / app 0.9.7+25
- D2I design baseline: v0.6
- v0.9.7 remains immutable main history
- v0.9.8 remains the first D2I product-fix candidate and is not overwritten
- v0.9.9 remains the Onboarding-scope product-fix candidate and is not overwritten
- current candidate: implementation v0.9.10 / app 0.9.10+28
- v0.9.10 ZIP SHA-256: `9fce3c9dd234fcc669ed7e5b62b8b2d612b3fa80b634bca14406cf5c6bb4836f`
- v0.9.10 runtime tree (`lib` + `test`): `739b2f5dae66f86a9e6b368b1ba7c440684c650f67843d9834d107c20ce21e6a`
- v0.9.10 product `lib` tree: `0d13db6a7af6d8cbaaa25120b24fbfb3504f236c6168a2a24eb2705efc316570` (identical to v0.9.9)
- Schema v9 / 75 app tables
- Schema tree: `bc1dcc6000defb6bde64156e6f019056bf983bcc185cfda108c1635cb754f4af`
- assets tree: `cb0c88dc1b40ded797d647904f19b25916cfb8e0c1f3980b141823530ac529fe`
- v0.9.10 patch SHA-256: `b94f356d1f358a1b8452a8c5b08cfcb678feebd4520ee807a6df54e1d53ef5d4`

## Product defects discovered by D2I

### v0.9.7 identity split

iOS #187 showed that Onboarding could use a DB account/profile while local reset resolved another Secure Storage-backed anonymous account. v0.9.8 introduced deterministic recovery of a unique completed local account and refuses ambiguous recovery.

### v0.9.8 Onboarding restart/scope defect

iOS #196 regular Phase 1 passed the strengthened reset deletion contract and OS terminate. Phase 2 then failed because an `IN_PROGRESS / INTRO` draft was treated as resumable and Onboarding profile/draft/account lookup was not current-user scoped. v0.9.9 fixed that product boundary while preserving D2C resume behavior from `BASIC_INFO` and later.

## v0.9.9 current-head CI result

Head `a9aa037f8a336a0f1a633ae5f22408208292d213` ran Flutter #212 and iOS #199 on the same commit.

Both lanes passed deterministic v0.9.9 build/verify. Both then failed in `Run Task 20-B Flutter checks` before D1 or D2I runtime. Strict Analyzer reported the same four `ambiguous_import` errors in `test/features/onboarding/data/local_onboarding_repository_test.dart`: `OnboardingDraft` was visible from both generated `app_database.dart` and domain `onboarding_draft.dart`.

This is classified as a test-source/analyzer-gate failure, not a D2I product-runtime failure. No v0.9.9 D1/D2I Simulator acceptance result is claimed from #212/#199.

## v0.9.10 candidate

v0.9.9 remains immutable. v0.9.10 changes only the regression-test import plus version/document/verifier traceability:

- generated DB `OnboardingDraft` is hidden from the `app_database.dart` test import
- domain `OnboardingDraft` remains the intended test type
- product `lib/` tree is byte-identical to v0.9.9
- Schema, Migration, Seed, assets, and D2I acceptance conditions are unchanged
- expected Flutter Test count remains 56

Local static verification passed the complete 26-step `make verify` set (the long invocation was split after the local environment timeout; every remaining step was executed and passed), plus deterministic v0.9.10 build/verify.

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

D2I remains Pending until the current v0.9.10 Head passes:

- Flutter/common CI on that exact Head
- deterministic v0.9.10 build/verify
- strict analyzer and all 56 Flutter tests
- both regular and compact Simulator D2I Phase 1/2
- all existing iOS regression acceptance steps
- analyzer/dependency gates
- result JSON/log inspection
- all 8 D2I PNGs and Artifact integrity inspection

Only after those checks may D2-09 become `AUTOMATED PASS` for the defined Simulator scope and D2-10 gain the D2I screen increment.

Even after D2I passes, reset interruption between Secure Storage switch and DB commit (separate D2-08), D2-10 untested portions, D2-11, physical iPhone, Dynamic Type detail, native accessibility, Task20-D2 overall, and Task20-B overall remain incomplete.

PR #18 remains Draft and unmerged until an explicit later decision.
