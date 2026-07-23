# Task 20-C5 — Canonical package integration

## Purpose

Replace the temporary multi-stage ZIP patch lane with a new canonical source package that already contains the verified Task20-B2/B3 and Task20-C1 through C4 changes.

## Adopted package

- Package: `implementation-v0.9.2.zip`
- Application version: `0.9.2+20`
- SHA-256: `b35f8f15740fb0e30979bed4eb836fd315d466bb0bd489fc5c70b5749535cf98`
- Schema: v9 / 75 tables, unchanged

The package was generated deterministically from the v0.9.1 canonical source after applying the already merged and verified B2/B3/C1-C4 changes. Its file manifest was regenerated, the ZIP integrity test passed, and the re-extracted package passed the project consistency verifier before publication.

Because the connected repository write interface accepts text but not binary contents, the exact ZIP bytes are stored as six immutable Base64 parts named `implementation-v0.9.2.zip.b64.part00` through `part05`. Both workflows reconstruct the ZIP before any validation and require the reconstructed bytes to match the SHA-256 above. This is a transport representation only; no source patch is applied after extraction.

## Workflow change

The Linux and macOS workflows now:

1. reconstruct the exact v0.9.2 ZIP from the six immutable transport parts;
2. verify SHA-256 and ZIP integrity, then extract it;
3. verify that the package already contains B2/B3/C1-C4;
4. install the pinned official Flutter SDK;
5. run the existing Flutter or iOS Simulator validation lane;
6. verify the strict analyzer gate and dependency resolution;
7. upload evidence.

They no longer execute the temporary B2, C1, C2, C3, or C4 patch-application scripts after extraction.

## Classification

### Adopt

- `implementation-v0.9.2.zip` as the next canonical implementation package.
- Direct validation of the canonical package without post-extraction source mutation.
- Segmented Base64 only as the repository transport representation of the exact ZIP bytes.

### Temporarily retain

- `implementation-v0.9.1.zip`
- the B2/C1/C2/C3/C4 patch scripts

Reason: retain rollback and audit evidence until the new canonical package passes both PR lanes and both post-merge main lanes. Retention does not mean the old lane remains active.

### Not deleted in this task

Historical packages and patch scripts are not deleted in Task20-C5. A separate cleanup decision must record impact, rollback value, and evidence-retention requirements.

## Acceptance conditions

Task20-C5 can be merged only when both PR lanes pass directly from the reconstructed v0.9.2 package:

- Base64 part count and decoding
- SHA-256 and ZIP integrity
- canonical-package verifier
- Flutter 3.44.6 official SDK verification
- `flutter pub get`
- Drift generation
- `make verify`
- strict `flutter analyze`: Error 0 / Warning 0 / Info 0
- Flutter Test
- iOS Simulator debug build
- Task20-C4 dependency-resolution verifier
- Artifact upload

Task20-C5 is complete only after the corresponding post-merge `main` runs also pass.

## Scope boundaries

- Runtime feature removed: none
- Database schema or migration changed: none
- User data changed: none
- Manual Simulator core-flow acceptance: not performed by this task
- Physical iPhone test: not performed by this task
- Accessibility test: not performed by this task
