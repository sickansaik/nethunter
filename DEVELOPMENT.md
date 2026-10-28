# NetHunter Toolkit v0.5.0

## Codename

Evolution

## Status

Development

## Parent Release

NetHunter Toolkit v0.4.4 — Runtime — Stable

## Parent Snapshot

backups/v0.4.4-runtime/final-release-20260827-032440

## Rule

This tree is the active development workspace.

The v0.4.4 Golden Baseline must never be modified.

## Development Goals

- Extend toolkit functionality
- Improve runtime control
- Improve diagnostics
- Add useful networking/security tooling
- Improve CLI/GUI interaction
- Preserve rollback capability

## Development Contract

### Protected Baseline

- The v0.4.4 Golden Baseline is immutable.
- Historical qualification evidence under `backups/` must not be modified as part of normal development.
- Release anchor data must not be changed to represent an uncertified artifact.

### Source and State Boundaries

- Source changes must remain limited to the intended development scope.
- `backups/`, `logs/`, `updates/`, and generated `runtime/network/` state are not normal source scope.
- Generated archives and temporary files must not be committed.
- Development-only files must not enter a release package.

### Change Discipline

- Prefer the smallest safe change that solves the identified problem.
- Do not perform broad search-and-replace changes without explicit justification.
- Do not change unrelated files as part of a feature or fix.
- Existing runtime contracts must be preserved unless the change explicitly targets that contract.

### Verification Before Commit

- Review the complete Git diff before committing.
- Run `make check`.
- Run `make syntax`.
- Run `make lint`.
- Run relevant functional and regression tests for the changed area.
- The worktree must be clean after the intended commit.

### Codex Development Rule

- Codex may propose or implement changes only within the declared change scope.
- Codex must inspect the existing implementation before changing it.
- Codex must not invent functions, paths, interfaces, or runtime behavior.
- Codex changes must pass the same verification gates as manually developed changes.
- A passing automated check does not replace review of the actual diff.
