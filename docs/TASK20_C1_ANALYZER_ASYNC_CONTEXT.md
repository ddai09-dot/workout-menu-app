# Task 20-C1 — Analyzer async / BuildContext findings

## Purpose

Reduce the Flutter analyzer baseline from 65 info findings by addressing the categories with the highest runtime-safety relevance first.

## Baseline

The verified Task 20-B2 artifact recorded 65 info findings:

| Lint | Count | Task 20-C1 classification |
|---|---:|---|
| `discarded_futures` | 10 | Fix now |
| `unawaited_futures` | 1 | Fix now |
| `use_build_context_synchronously` | 4 | Fix now |
| `deprecated_member_use` | 16 | Defer to a separate compatibility change |
| `prefer_initializing_formals` | 18 | Low-risk style cleanup, defer |
| `directives_ordering` | 5 | Style cleanup, defer |
| `unnecessary_underscores` | 4 | Style cleanup, defer |
| `unnecessary_brace_in_string_interps` | 3 | Style cleanup, defer |
| `unnecessary_import` | 2 | One related import fixed now; one test import remains |
| `no_leading_underscores_for_local_identifiers` | 1 | Style cleanup, defer |
| `curly_braces_in_flow_control_structures` | 1 | Style cleanup, defer |

## Changes

- Await user-triggered AI submission and notification preference persistence.
- Mark intentionally fire-and-forget lifecycle and navigation calls with `unawaited`.
- Mark removal of a Future-valued in-flight cache entry with `unawaited` without awaiting the same in-flight operation.
- Guard the exact `BuildContext` used after asynchronous gaps.
- Restructure the pain-action branch so only one asynchronous branch executes.
- Remove one now-unnecessary `dart:typed_data` import.

## Expected analyzer result

- `discarded_futures`: 0
- `unawaited_futures`: 0
- `use_build_context_synchronously`: 0
- Total info findings: 49

The workflow verifier fails unless those three categories are absent and the total is exactly 49.

## Decision classification

- **Adopt:** explicit awaiting or `unawaited` for every targeted Future.
- **Adopt:** `BuildContext.mounted` checks tied to the exact context used.
- **Temporarily defer:** deprecated Flutter APIs and style-only findings.
- **Delete:** no user-facing function or runtime dependency.

## Canonical-source limitation

The repository is still using the temporary ZIP integration lane. These changes are applied after extracting implementation package v0.9.1. They must be folded into the next canonical source package before the ZIP patch lane is retired.
