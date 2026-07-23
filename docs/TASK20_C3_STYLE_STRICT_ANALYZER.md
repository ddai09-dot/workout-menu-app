# Task 20-C3 — Style normalization and strict analyzer gate

## Purpose

Resolve the 33 style-level analyzer findings that remained after Task 20-C2 and remove the temporary `--no-fatal-infos` analyzer mode.

## Baseline

- Task 20-C2 unique analyzer findings: 33
- Errors: 0
- Warnings: 0
- Info findings: 33

## Direct code fixes

The following 15 findings are corrected in code without changing runtime behavior:

- `directives_ordering`: 5
- `unnecessary_underscores`: 4
- `unnecessary_brace_in_string_interps`: 3
- `unnecessary_import`: 1
- `no_leading_underscores_for_local_identifiers`: 1
- `curly_braces_in_flow_control_structures`: 1

## Scoped policy exception

`prefer_initializing_formals` accounts for 18 findings across 12 files.

The affected constructors expose named parameters such as `idGenerator`, `gateway`, `storage`, and `environment`, while the backing fields are private. Replacing these with private field-formal parameters would rename public named parameters to private identifiers and cause avoidable constructor API churn.

Decision:

- Preserve the existing constructor API.
- Add `ignore_for_file: prefer_initializing_formals` only to the 12 affected files.
- Record this as an explicit lint-policy exception rather than claiming a structural constructor refactor.
- Reconsider only if constructor APIs are redesigned in the canonical source layout.

## Analyzer gate

Task 20-C3 restores the strict command:

```text
flutter analyze
```

The temporary command below is removed:

```text
flutter analyze --no-fatal-infos
```

The workflow verifier fails if:

- any error, warning, or info finding remains;
- `--no-fatal-infos` is still present; or
- the strict analyzer command is missing.

## Decision classification

- **Adopt:** direct style fixes for 15 findings.
- **Adopt:** strict `flutter analyze` gate.
- **Adopt as scoped exception:** `prefer_initializing_formals` in 12 identified files.
- **Delete:** temporary `--no-fatal-infos` mode.
- **Functionality removed:** none.
- **Runtime dependency changed:** none.

## Canonical-source limitation

The repository still uses the temporary ZIP integration lane. Task 20-C3 is applied after Task 20-B2, C1, and C2 patches. These changes and the scoped lint exception must be folded into the next canonical source package before the ZIP patch lane is retired.
