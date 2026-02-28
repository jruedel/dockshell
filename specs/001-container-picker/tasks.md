# Tasks: Interactive Container Picker

**Input**: Design documents from `/specs/001-container-picker/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/cli-interface.md, quickstart.md

**Tests**: Not explicitly requested in spec. Manual smoke tests only (per constitution: "Manual smoke tests against a local Docker daemon are the minimum gate").

**Organization**: Tasks grouped by user story. All tasks target a single file (`dockshell.sh`) per constitution (Single-Script Simplicity).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (independent functions, no cross-dependencies)
- **[Story]**: Which user story (US1, US2, US3)

---

## Phase 1: Setup

**Purpose**: Create the script file with correct structure and metadata

- [x] T001 Create dockshell.sh at repository root with bash shebang (`#!/usr/bin/env bash`), strict mode (`set -euo pipefail`), version variable (`DOCKSHELL_VERSION="0.1.0"`), and empty function stubs for: `cleanup`, `die`, `fetch_containers`, `render_menu`, `read_key`, `exec_shell`, `main`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Terminal management and Docker integration that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T002 Implement terminal state management in dockshell.sh — save terminal state with `stty -g` on startup, enter alternate screen (`tput smcup`), hide cursor (`tput civis`), suppress echo (`stty -echo`), register cleanup function on EXIT trap, trap INT to `exit 130`, trap TERM to `exit 143`; cleanup function: show cursor (`tput cnorm`), leave alternate screen (`tput rmcup`), restore saved stty state
- [x] T003 [P] Implement `die` helper and Docker prerequisite check function in dockshell.sh — `die` prints message to stderr and exits with code 1; prerequisite check: (1) `command -v docker` for installation, (2) capture stderr from `docker ps` and pattern-match "Cannot connect" / "failed to connect" / "permission denied" for daemon/permission issues per research.md section 8
- [x] T004 [P] Implement `fetch_containers` function in dockshell.sh — run `docker ps --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}'`, pipe through `sort -t$'\t' -k3,3 -k2,2`, parse output with `IFS=$'\t' read -r` into parallel arrays (`CONTAINER_IDS`, `CONTAINER_NAMES`, `CONTAINER_IMAGES`, `CONTAINER_STATUSES`), set `CONTAINER_COUNT` per data-model.md ContainerEntry schema

**Checkpoint**: Foundation ready — terminal managed, Docker accessible, containers fetchable

---

## Phase 3: User Story 1 — Pick a Container and Enter Its Shell (Priority: P1) MVP

**Goal**: User launches DockShell, sees a navigable container list, selects one, and enters its shell. After exiting the shell, the menu re-appears with a refreshed list.

**Independent Test**: Run 2+ Docker containers, launch `./dockshell.sh`, navigate with arrows, press Enter, verify shell opens. Type `exit`, verify menu returns.

### Implementation for User Story 1

- [x] T005 [US1] Implement `render_menu` function in dockshell.sh — query terminal dimensions via `tput lines`/`tput cols`, calculate `visible_count` (rows minus header/footer chrome), draw header line ("DockShell — N containers" at row 0), draw visible container rows from `scroll_offset` to `scroll_offset + visible_count - 1` using `tput cup` positioning with columns for name/image/status, apply `tput rev` highlight on cursor row and `tput sgr0` after, truncate each line to terminal width, draw footer line with key hints ("↑↓:Navigate  Enter:Shell  r:Refresh  q:Quit")
- [x] T006 [US1] Implement `read_key` function in dockshell.sh — blocking `read -rsN1 -t 0.5` for first byte (timeout enables SIGWINCH delivery per research.md section 3), if ESC byte: drain follow-up bytes with `read -rsN1 -t 0.05` loop, match accumulated sequence against CSI (`\e[A`-`\e[D`) and SS3 (`\eOA`-`\eOD`) for arrow keys per research.md section 6, detect bare ESC (no follow-up) as Escape key, detect Enter as empty read or newline byte; return key identifier string ("up"/"down"/"enter"/"escape"/"q"/"r"/"timeout"/"unknown")
- [x] T007 [US1] Implement cursor navigation and viewport scrolling in dockshell.sh — initialize `cursor=0`, `scroll_offset=0`; on "up": decrement cursor (min 0), adjust scroll_offset if `cursor < scroll_offset`; on "down": increment cursor (max `CONTAINER_COUNT - 1`), adjust scroll_offset if `cursor >= scroll_offset + visible_count`; follow-cursor viewport rules per research.md section 4
- [x] T008 [US1] Implement `exec_shell` function in dockshell.sh — accept container ID as argument, restore terminal for shell session (`tput rmcup`, `tput cnorm`, `stty "$saved_tty"`), probe for bash via `docker exec "$cid" sh -c 'command -v bash' &>/dev/null` per research.md section 9, exec `docker exec -it "$cid" bash` or `docker exec -it "$cid" sh` as fallback, after shell returns: re-enter alternate screen (`tput smcup`), hide cursor (`tput civis`), suppress echo (`stty -echo`)
- [x] T009 [US1] Implement `main` function and event loop in dockshell.sh — call prerequisite check, call `fetch_containers`, enter main loop: `render_menu` → `read_key` → dispatch (up/down → navigate, enter → `exec_shell` then `fetch_containers` to refresh, timeout → continue); wire `main` as script entry point called at end of file with `main "$@"`

**Checkpoint**: User Story 1 fully functional — select container, enter shell, return to menu

---

## Phase 4: User Story 2 — Graceful Exit Without Selection (Priority: P2)

**Goal**: User can quit from the menu via `q`, Escape, or Ctrl-C with clean terminal restore.

**Independent Test**: Launch DockShell, press `q` — terminal clean. Launch again, press Escape — terminal clean. Launch again, press Ctrl-C — terminal clean, exit code 130.

### Implementation for User Story 2

- [x] T010 [US2] Add quit key handling to event loop dispatch in dockshell.sh — on "q" key: `exit 0`; on "escape" key (bare ESC detected in `read_key`): `exit 0`; Ctrl-C already handled by INT trap from T002 (`exit 130` triggers cleanup); verify all three paths restore terminal via EXIT trap

**Checkpoint**: All exit paths clean — q (exit 0), Escape (exit 0), Ctrl-C (exit 130)

---

## Phase 5: User Story 3 — No Running Containers (Priority: P3)

**Goal**: Clear error messages when Docker is unavailable or no containers are running.

**Independent Test**: Stop all containers → launch DockShell → see "No running containers found" + exit 1. Stop Docker daemon → launch DockShell → see "Docker daemon is not running" + exit 1.

### Implementation for User Story 3

- [x] T011 [US3] Integrate error states into main entry flow in dockshell.sh — after `fetch_containers`, if `CONTAINER_COUNT` is 0: print "No running containers found." to stderr and `exit 1`; ensure prerequisite check from T003 is called before fetch and handles: docker not installed → "Docker is not installed. Please install Docker first." + exit 1, daemon not running → "Docker daemon is not running. Start it with 'docker start' or launch Docker Desktop." + exit 1, permission denied → "Permission denied. Add your user to the docker group or use rootless Docker." + exit 1; all error messages go to stderr per contracts/cli-interface.md

**Checkpoint**: All error states produce clear messages and non-zero exit codes

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Features that enhance all user stories

- [x] T012 [P] Add `--help` and `--version` flag handling to dockshell.sh — parse `$1` before entering main flow; `--help`/`-h`: print usage summary (invocation, options, key bindings from contracts/cli-interface.md) to stdout and exit 0; `--version`: print `dockshell $DOCKSHELL_VERSION` to stdout and exit 0
- [x] T013 [P] Implement SIGWINCH resize handler in dockshell.sh — `trap handle_resize WINCH`; handler re-queries `tput lines`/`tput cols`, recalculates `visible_count`, adjusts `scroll_offset` to keep cursor in viewport, sets a redraw flag; main loop checks redraw flag and calls `render_menu` when set per research.md section 3
- [x] T014 [P] Add manual refresh key (`r`) to event loop dispatch in dockshell.sh — on "r" key: call `fetch_containers`, clamp cursor to new `CONTAINER_COUNT - 1` if list shrank, reset `scroll_offset` if needed, trigger full redraw per FR-012
- [x] T015 Add stale container and no-shell error recovery in dockshell.sh — if `docker exec` fails (container stopped or no shell available): display inline error message at bottom of menu for 2 seconds, then return to menu loop rather than crashing; handle both "container not running" and "OCI runtime exec failed" stderr patterns
- [x] T016 Run `shellcheck dockshell.sh` and resolve all warnings — fix any issues found; only add `# shellcheck disable=SCXXXX` directives with justifying comments per constitution (Development Workflow)
- [x] T017 Run quickstart.md smoke test scenarios manually — execute the "Verify Installation" steps from quickstart.md (start two test containers, launch dockshell, navigate, enter shell, exit, quit, clean up); verify all acceptance scenarios from spec.md pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on T001 completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion
- **User Story 2 (Phase 4)**: Depends on T009 (main loop exists to add dispatch cases)
- **User Story 3 (Phase 5)**: Depends on T003 + T004 (prerequisite check + fetch exist)
- **Polish (Phase 6)**: Depends on T009 (main loop + dispatch exist)

### Within Each Phase

- Phase 2: T003 and T004 are parallel (independent functions); T002 can also be parallel
- Phase 3: T005-T008 build independent functions; T009 integrates them (must be last in phase)
- Phase 6: T012, T013, T014 are parallel (independent features); T015 depends on T008; T016-T017 are final validation

### Parallel Opportunities

```bash
# Phase 2 — all three foundational functions in parallel:
Task: "T002 Terminal state management in dockshell.sh"
Task: "T003 Docker prerequisite checks in dockshell.sh"
Task: "T004 Container fetch function in dockshell.sh"

# Phase 3 — independent functions before integration:
Task: "T005 Menu rendering in dockshell.sh"
Task: "T006 Keystroke reading in dockshell.sh"
Task: "T007 Cursor navigation in dockshell.sh"
Task: "T008 Shell exec in dockshell.sh"
# Then sequentially:
Task: "T009 Main event loop in dockshell.sh"

# Phase 6 — independent polish features:
Task: "T012 --help/--version in dockshell.sh"
Task: "T013 SIGWINCH handler in dockshell.sh"
Task: "T014 Manual refresh key in dockshell.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 2: Foundational (T002-T004)
3. Complete Phase 3: User Story 1 (T005-T009)
4. **STOP and VALIDATE**: Can you select a container and enter its shell?
5. Working MVP — the core tool is functional

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 → Test → Working MVP
3. Add User Story 2 → Test → Clean exit paths
4. Add User Story 3 → Test → Error handling complete
5. Polish phase → ShellCheck clean, resize handling, help flags
6. Final smoke test with quickstart.md

---

## Notes

- All tasks target a single file (`dockshell.sh`) per constitution principle I
- [P] tasks implement independent functions within the same file
- No test tasks generated (not requested in spec; manual smoke tests per constitution)
- Commit after each task or logical group per constitution (Development Workflow)
- ShellCheck validation (T016) is a merge gate per constitution
