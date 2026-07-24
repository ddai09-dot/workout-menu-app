# Task 20-C5 — Canonical package integration

## Purpose

Replace the temporary multi-stage ZIP patch validation lane with a new canonical source package that already contains the verified Task20-B2/B3 and Task20-C1 through C4 changes.

## Canonical package candidate

- Package: `implementation-v0.9.2.zip`
- Application version: `0.9.2+20`
- SHA-256: `5d9e35459123afdd22765e03e256fb9d9353cc0340c5f32bffd44b13cc0691c9`
- Schema: v9 / 75 tables, unchanged

The candidate is generated deterministically from the verified v0.9.1 canonical source. The integration input is an immutable compressed patch payload stored in four text parts. The promotion builder applies that payload once to v0.9.1, normalizes validation order, removes transient build directories, writes a deterministic ZIP, and requires the exact SHA-256 above.

Both workflows then delete the promotion worktree, re-extract the generated v0.9.2 ZIP, and perform all acceptance validation against that re-extracted package. No B2, C1, C2, C3, or C4 patch is applied to the v0.9.2 validation source after extraction.

## Workflow change

The Linux and macOS workflows now:

1. verify and extract the existing v0.9.1 canonical package;
2. build the exact v0.9.2 canonical candidate with the deterministic promotion builder;
3. verify the output ZIP SHA-256;
4. delete the promotion worktree and re-extract v0.9.2;
5. verify that the package already contains B2/B3/C1-C4;
6. install the pinned official Flutter SDK;
7. verify the pristine canonical source with `make verify` before generated artifacts are created;
8. create runtime config, resolve dependencies, generate Drift code, run strict analysis and Flutter Test;
9. on macOS, generate the iOS platform only after the common canonical-source checks and then build the Simulator application;
10. verify dependency resolution and upload the generated v0.9.2 ZIP with evidence.

The former five post-extraction patch-application steps are removed from the validation lane.

## Failed runs and corrections

### iOS PR run #30

- stopped step: `Run Task 20-B iOS Simulator checks`
- stopped sub-step: `common_flutter_checks` / `make_verify`
- exit code: 2
- v0.9.2 build, SHA verification, re-extraction, canonical-package verification, and Flutter SDK installation: PASS

Cause:

`flutter create --platforms=ios` generated platform files before exact package-manifest verification. `verify_project_consistency.py` correctly detected the additional files.

Correction:

Move common Flutter checks before `flutter create`. The manifest rule was not weakened.

### iOS PR run #32

- stopped step: `Run Task 20-B iOS Simulator checks`
- stopped sub-step: `common_flutter_checks` / `make_verify`
- exit code: 2
- `flutter create` had not yet run
- `flutter pub get` and Drift generation: PASS

Cause:

Although iOS platform generation had moved later, `flutter pub get`, runtime-config creation, and Drift generation still created non-canonical files before `make verify`. Exact manifest comparison therefore correctly stopped the lane.

Correction:

Move `make verify` ahead of all runtime/generated artifacts. The final validation order is:

1. pristine canonical source verification;
2. runtime config and dependency resolution;
3. Drift generation;
4. strict analysis and Flutter Test;
5. iOS platform generation and Simulator build.

No generated files were added to the canonical manifest, and no exception was added to weaken exact manifest verification.

## Classification

### Adopt after acceptance

- `implementation-v0.9.2.zip` as the next canonical implementation package.
- Direct validation of the re-extracted v0.9.2 package without subsequent source mutation.

### Temporarily adopt

- `task20_c5_build_canonical_v092.py` and its immutable payload parts as promotion tooling.

Reason: the connected repository write path cannot directly publish the locally generated binary ZIP. The builder produces byte-identical output with a fixed SHA and allows both CI platforms to validate the exact candidate.

Reconsideration criterion: after v0.9.2 is stored in a normal canonical binary/source layout and its PR/main validation evidence is archived, remove or archive the promotion builder through a separate recorded decision.

### Temporarily retain

- `implementation-v0.9.1.zip`
- B2/C1/C2/C3/C4 patch scripts

Reason: retain rollback and audit evidence until the v0.9.2 canonical package passes both PR lanes and both post-merge main lanes. Retention does not mean those staged scripts remain active in the validation workflow.

### Not deleted in this task

Historical packages and patch scripts are not deleted in Task20-C5. Cleanup requires a separate decision recording rollback value, evidence-retention requirements, and impact.

## Acceptance conditions

Task20-C5 can be merged only when both PR lanes pass from the re-extracted v0.9.2 package:

- v0.9.1 input SHA-256 and ZIP integrity
- deterministic promotion build
- v0.9.2 output SHA-256 and ZIP integrity
- canonical-package verifier
- Flutter 3.44.6 official SDK verification
- pristine `make verify`
- `flutter pub get`
- Drift generation
- strict `flutter analyze`: Error 0 / Warning 0 / Info 0
- Flutter Test
- iOS Simulator debug build
- Task20-C4 dependency-resolution verifier
- Artifact upload including `implementation-v0.9.2.zip`

Task20-C5 is complete only after the corresponding post-merge `main` runs also pass.

## Scope boundaries

- Runtime feature removed: none
- Database schema or migration changed: none
- User data changed: none
- Manual Simulator core-flow acceptance: not performed by this task
- Physical iPhone test: not performed by this task
- Accessibility test: not performed by this task
