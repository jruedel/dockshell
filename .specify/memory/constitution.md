<!--
  Sync Impact Report
  ==================
  Version change: 0.0.0 → 1.0.0 (initial ratification)
  Modified principles: N/A (initial)
  Added sections:
    - Core Principles (5 principles)
    - Technical Constraints
    - Development Workflow
    - Governance
  Removed sections: N/A
  Templates requiring updates:
    - .specify/templates/plan-template.md — ✅ no update needed (generic)
    - .specify/templates/spec-template.md — ✅ no update needed (generic)
    - .specify/templates/tasks-template.md — ✅ no update needed (generic)
  Follow-up TODOs: none
-->

# DockShell Constitution

## Core Principles

### I. Single-Script Simplicity

DockShell MUST remain a single Bash script file with no external
build steps, transpilation, or compilation. The entire tool MUST be
distributable by copying one file. Additional helper scripts are
prohibited unless a future amendment explicitly justifies them.

**Rationale**: The project's core value proposition is being lean and
instantly usable. Splitting into multiple files or adding a build
pipeline contradicts that goal.

### II. Pure Bash & Minimal Dependencies

The script MUST rely only on Bash (version 4.0+) built-ins, standard
POSIX utilities (`tput`, `stty`, `printf`, `read`), and the `docker`
CLI. No third-party tools (e.g., `fzf`, `gum`, `jq`) are permitted
as hard requirements. Optional integrations MAY be added behind
feature detection but MUST NOT break core functionality when absent.

**Rationale**: Users installing DockShell expect zero additional setup
beyond having Docker available. Every added dependency is a potential
failure point and installation hurdle.

### III. Interactive UX First

The terminal menu MUST support arrow-key navigation, provide clear
visual feedback for the selected item, and respond without perceptible
lag. The UI MUST gracefully handle terminal resize events and
containers appearing or disappearing between refreshes. Output MUST
be clean — no debug noise, no raw escape codes on unsupported
terminals.

**Rationale**: The entire purpose of this tool is to replace manual
`docker ps` + `docker exec` workflows with a smooth interactive
experience. Poor UX defeats the reason for the tool to exist.

### IV. Docker Safety

DockShell MUST NOT perform destructive Docker operations (stop, kill,
remove, prune). The script MUST be limited to read-only container
listing (`docker ps`) and interactive shell attachment
(`docker exec -it`). Any future feature that modifies container state
MUST require explicit user confirmation and a constitution amendment.

**Rationale**: A tool that simplifies shell access must not
accidentally become a tool that destroys running workloads. Limiting
scope to read + exec keeps the blast radius minimal.

### V. Portability

The script MUST work on macOS and common Linux distributions
(Ubuntu, Debian, Fedora, Alpine) without modification. Terminal
handling MUST degrade gracefully when advanced capabilities
(256-color, Unicode box drawing) are unavailable. The script MUST
restore original terminal settings on exit, including after
interrupts (SIGINT, SIGTERM).

**Rationale**: Docker users work across heterogeneous environments.
A tool that only works on one OS or terminal emulator has limited
real-world utility.

## Technical Constraints

- **Language**: Bash 4.0+ (no zsh-isms, no bashisms beyond 4.0)
- **Target platforms**: macOS (with Homebrew Bash if needed),
  Linux (glibc and musl)
- **Terminal**: Any VT100-compatible terminal emulator
- **Docker**: Docker CLI MUST be available in `$PATH`; the script
  MUST exit with a clear error message if Docker is not found or
  the daemon is not running
- **No root requirement**: The script MUST NOT require root.
  If the user lacks Docker permissions, the script MUST report
  the issue clearly rather than failing silently

## Development Workflow

- **Branching**: Feature work happens on topic branches off `main`;
  `main` MUST always contain a working script
- **Testing**: Manual smoke tests against a local Docker daemon
  are the minimum gate before merging. Automated tests (e.g.,
  using `bats-core`) are encouraged but not mandatory for v1
- **Commit discipline**: Each commit MUST represent a single
  logical change; commit messages MUST follow Conventional Commits
  format (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`)
- **ShellCheck**: The script MUST pass `shellcheck` with zero
  warnings before merge. Inline directives (`# shellcheck disable`)
  are permitted only with a justifying comment

## Governance

This constitution is the authoritative reference for all DockShell
design and implementation decisions. When a proposed change conflicts
with a principle stated here, the principle prevails unless formally
amended.

**Amendment procedure**:

1. Propose the change with rationale in a dedicated issue or PR.
2. Update the constitution document with the change.
3. Increment the version number per semantic versioning rules:
   - MAJOR: Principle removal or backward-incompatible redefinition.
   - MINOR: New principle or materially expanded guidance.
   - PATCH: Clarifications, wording, typo fixes.
4. Record the amendment date.

**Compliance**: Every PR MUST be checked against this constitution.
Non-compliance MUST be flagged before merge.

**Version**: 1.0.0 | **Ratified**: 2026-02-27 | **Last Amended**: 2026-02-27
