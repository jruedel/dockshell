# Implementation Plan: Interactive Container Picker

**Branch**: `001-container-picker` | **Date**: 2026-02-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-container-picker/spec.md`

## Summary

Build a single-file Bash script (`dockshell.sh`) that queries running
Docker containers via `docker ps --format`, presents them in an
interactive terminal menu with arrow-key navigation and reverse-video
highlighting, and opens an interactive shell (`bash` or `sh` fallback)
in the selected container. The menu loops after shell exit, supports
manual refresh (`r`), and restores all terminal state on any exit path.

## Technical Context

**Language/Version**: Bash 4.0+
**Primary Dependencies**: `tput`, `stty`, `printf`, `read`, `sort`, `docker` CLI
**Storage**: N/A (no persistent state)
**Testing**: Manual smoke tests (bats-core optional, not required for v1)
**Target Platform**: macOS (Homebrew Bash if needed), Linux (glibc + musl)
**Project Type**: CLI (single executable script)
**Performance Goals**: Menu display < 2s, full flow (launch → shell) < 5s
**Constraints**: Single file, no third-party deps, ShellCheck clean
**Scale/Scope**: Up to 50 running containers

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
|-----------|------|--------|
| I. Single-Script Simplicity | Output is exactly one `.sh` file, no build steps | PASS |
| II. Pure Bash & Minimal Dependencies | Only Bash builtins, POSIX utils (`tput`, `stty`, `printf`, `read`, `sort`), and `docker` CLI | PASS |
| III. Interactive UX First | Arrow-key nav, reverse-video highlight, alternate screen, SIGWINCH handling | PASS |
| IV. Docker Safety | Only `docker ps` (read) and `docker exec -it` (shell access); no destructive ops | PASS |
| V. Portability | macOS + Linux, VT100 tput, graceful degradation, terminal restore via `stty -g` + EXIT trap | PASS |

**Post-Phase 1 re-check**: All gates still PASS. No violations introduced
by data model, contracts, or quickstart.

## Project Structure

### Documentation (this feature)

```text
specs/001-container-picker/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── cli-interface.md
├── checklists/
│   └── requirements.md
└── tasks.md               # (Phase 2 — /speckit.tasks)
```

### Source Code (repository root)

```text
dockshell.sh                # Single executable script (constitution: one file)
```

**Structure Decision**: The constitution mandates a single-file
distribution. There is no `src/`, `lib/`, or `tests/` directory.
The script lives at the repository root. All spec/design artifacts
live under `specs/001-container-picker/`.

## Complexity Tracking

No constitution violations. This table is intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | — | — |
