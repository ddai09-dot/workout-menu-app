# Task 20-C2 — Deprecated API migrations

## Purpose

Remove the 16 `deprecated_member_use` findings that remained after Task 20-C1 while preserving behavior and the Task 20-C1 async-safety baseline.

## Baseline

Task 20-C1 reduced the unique analyzer info baseline from 65 to 49. The remaining deprecated findings were:

| API | Count | Replacement |
|---|---:|---|
| `Supabase.initialize(anonKey:)` | 1 | `publishableKey:` |
| `DropdownButtonFormField(value:)` | 13 | `initialValue:` |
| `Radio.groupValue` / `Radio.onChanged` | 2 | `RadioGroup` ancestor |

## Changes

- Rename the Supabase client-side key argument to `publishableKey`.
- Replace the deprecated `DropdownButtonFormField.value` alias with `initialValue`.
- Move workout-location selection state and change handling into a `RadioGroup<String>` ancestor.
- Keep each `RadioListTile` responsible only for its own immutable value and label.

## Expected analyzer result

- `deprecated_member_use`: 0
- Task 20-C1 categories remain 0:
  - `discarded_futures`
  - `unawaited_futures`
  - `use_build_context_synchronously`
- Unique info findings: 33

The active workflow verifier fails unless these conditions are met. Exact duplicate analyzer lines are counted separately because the macOS runner has produced one duplicate line in prior evidence.

## Decision classification

- **Adopt:** `publishableKey` for Supabase client initialization.
- **Adopt:** `DropdownButtonFormField.initialValue` as the direct replacement for the deprecated alias.
- **Adopt:** `RadioGroup` as the owner of radio selection state and change handling.
- **Delete:** no user-facing function or runtime dependency.
- **Temporarily defer:** the remaining 33 style-only analyzer findings.

## Canonical-source limitation

The repository is still using the temporary ZIP integration lane. These changes are applied after extracting implementation package v0.9.1 and after the Task 20-B2 / C1 patches. They must be folded into the next canonical source package before the ZIP patch lane is retired.
