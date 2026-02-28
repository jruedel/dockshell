# Feature Specification: Interactive Container Picker

**Feature Branch**: `001-container-picker`
**Created**: 2026-02-27
**Status**: Draft
**Input**: User description: "Ein schlankes Bash-Script, das laufende Docker-Container in einem interaktiven Terminal-Menü anzeigt und dem Nutzer ermöglicht, per Pfeiltasten einen Container auszuwählen und direkt in dessen Shell zu wechseln."

## Clarifications

### Session 2026-02-27

- Q: After exiting a container shell, should DockShell return to the menu or exit completely? → A: Return to the container menu (re-pick or quit).
- Q: How should the container list be sorted? → A: Alphabetically by image name, then by container name.
- Q: When should the container list refresh? → A: On return from a shell session and via a manual refresh key (`r`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pick a Container and Enter Its Shell (Priority: P1)

A developer has several Docker containers running locally. They invoke
DockShell from their terminal. A list of all running containers
appears as a navigable menu showing container name, image, and status.
The developer uses the Up/Down arrow keys to highlight the desired
container, then presses Enter. DockShell immediately opens an
interactive shell session inside that container.

**Why this priority**: This is the core and only reason the tool
exists. Without this flow, DockShell delivers zero value.

**Independent Test**: Can be fully tested by running at least two
Docker containers, launching DockShell, navigating to a container,
pressing Enter, and verifying the user lands in an interactive shell
inside the chosen container.

**Acceptance Scenarios**:

1. **Given** two or more Docker containers are running, **When** the
   user launches DockShell, **Then** a menu lists all running
   containers with their name, image, and status, and the first
   container is highlighted by default.
2. **Given** the menu is displayed, **When** the user presses the
   Down arrow key, **Then** the highlight moves to the next container
   in the list.
3. **Given** the menu is displayed, **When** the user presses the Up
   arrow key while not on the first item, **Then** the highlight
   moves to the previous container.
4. **Given** a container is highlighted, **When** the user presses
   Enter, **Then** an interactive shell session opens inside that
   container.
5. **Given** the shell session is active, **When** the user exits the
   shell (e.g., `exit` or Ctrl-D), **Then** DockShell returns to the
   container menu with a refreshed container list, allowing the user
   to pick another container or quit.

---

### User Story 2 - Graceful Exit Without Selection (Priority: P2)

A developer launches DockShell but decides they do not want to enter
any container. They press `q` or Escape to quit the menu. DockShell
exits cleanly, restoring the terminal to its previous state without
any residual escape codes or altered settings.

**Why this priority**: Users must always be able to abort without
side effects. This is critical for trust and usability but depends on
the menu infrastructure from US1.

**Independent Test**: Launch DockShell with running containers, press
`q` or Escape, and verify the terminal prompt returns cleanly with no
visual artifacts.

**Acceptance Scenarios**:

1. **Given** the menu is displayed, **When** the user presses `q`,
   **Then** DockShell exits and the terminal is restored to its
   original state.
2. **Given** the menu is displayed, **When** the user presses Escape,
   **Then** DockShell exits and the terminal is restored to its
   original state.
3. **Given** DockShell is running, **When** the user presses Ctrl-C,
   **Then** DockShell exits and the terminal is restored to its
   original state (no garbled output or changed terminal settings).

---

### User Story 3 - No Running Containers (Priority: P3)

A developer launches DockShell when no Docker containers are running.
Instead of showing an empty menu or crashing, DockShell displays a
clear, helpful message indicating that no containers are currently
running and exits gracefully.

**Why this priority**: This is an important error-handling scenario
but only relevant when the happy path (US1) already works. Users need
a clear message rather than confusing behavior.

**Independent Test**: Stop all Docker containers, launch DockShell,
and verify a clear message is shown and the tool exits with a
non-zero exit code.

**Acceptance Scenarios**:

1. **Given** no Docker containers are running, **When** the user
   launches DockShell, **Then** a message like "No running containers
   found" is displayed and the tool exits.
2. **Given** Docker is not installed or the daemon is not running,
   **When** the user launches DockShell, **Then** a clear error
   message is shown (e.g., "Docker is not available") and the tool
   exits with a non-zero exit code.

---

### Edge Cases

- What happens when the container list is longer than the terminal
  height? The menu MUST scroll or paginate so all containers remain
  accessible.
- What happens when a container stops while the menu is displayed?
  The user can press `r` to refresh. If the user tries to exec into
  a stopped container, the tool MUST display an error message and
  return to the menu rather than crashing.
- What happens when the selected container has no shell (`sh` or
  `bash` not available)? The tool MUST display an error message and
  return to the menu or exit cleanly.
- What happens when the terminal window is very narrow (< 40
  columns)? The display MUST truncate container names gracefully
  rather than wrapping and breaking the layout.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The tool MUST list all running Docker containers with
  at least their name, image, and status, sorted alphabetically by
  image name and then by container name.
- **FR-002**: The tool MUST present the container list as an
  interactive terminal menu navigable with Up/Down arrow keys.
- **FR-003**: The tool MUST highlight the currently selected container
  with a distinct visual indicator (e.g., reverse video, color, or
  marker character).
- **FR-004**: The tool MUST open an interactive shell session inside
  the selected container when the user presses Enter.
- **FR-005**: The tool MUST attempt `bash` first as the exec shell
  and fall back to `sh` if `bash` is not available in the container.
- **FR-006**: The tool MUST allow the user to quit without selecting
  a container via `q`, Escape, or Ctrl-C.
- **FR-011**: The tool MUST refresh the container list when returning
  to the menu after a shell session ends.
- **FR-012**: The tool MUST support a manual refresh key (`r`) that
  re-fetches and re-renders the container list while the menu is
  displayed.
- **FR-007**: The tool MUST restore all terminal settings (cursor
  visibility, echo mode, canonical mode) on exit, including after
  interrupt signals.
- **FR-008**: The tool MUST display a clear error message and exit
  with a non-zero code when Docker is not installed, the daemon is
  not running, or no containers are running.
- **FR-009**: The tool MUST handle container lists longer than the
  terminal height by scrolling or paginating the menu.
- **FR-010**: The tool MUST be a single executable Bash script with
  no external dependencies beyond Bash 4.0+, standard POSIX
  utilities, and the Docker CLI.

### Key Entities

- **Container Entry**: A running Docker container represented in the
  menu. Key attributes: container ID, container name, image name,
  current status (e.g., "Up 3 hours"). Sourced live from the Docker
  daemon each time DockShell is launched.

### Assumptions

- The user has Docker installed and their account has permission to
  run `docker` commands (via group membership or rootless Docker).
- The terminal supports VT100 escape sequences (true for virtually
  all modern terminal emulators).
- Container names and image names may contain Unicode but the tool
  only needs to handle ASCII display; Unicode characters are passed
  through as-is.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can go from launching DockShell to an interactive
  shell inside a chosen container in under 5 seconds (with fewer than
  50 running containers).
- **SC-002**: The tool starts and displays the container menu in under
  2 seconds on a system with up to 50 running containers.
- **SC-003**: 100% of exit paths (quit, Escape, Ctrl-C, shell exit)
  restore the terminal to its pre-launch state with no visual
  artifacts.
- **SC-004**: The tool works without modification on both macOS and
  at least two common Linux distributions (e.g., Ubuntu, Alpine).
- **SC-005**: A first-time user can successfully select and enter a
  container shell without consulting documentation (self-explanatory
  interface).
