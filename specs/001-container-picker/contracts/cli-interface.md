# CLI Interface Contract: dockshell

**Feature**: 001-container-picker | **Date**: 2026-02-27

## Invocation

```text
dockshell [OPTIONS]
```

No arguments required for default operation.

## Options

| Flag          | Description                          | Default |
|---------------|--------------------------------------|---------|
| `--help`, `-h`| Show usage information and exit      | N/A     |
| `--version`   | Print version string and exit        | N/A     |

No other flags for v1. The tool launches directly into the
interactive menu.

## Exit Codes

| Code | Meaning                                        |
|------|------------------------------------------------|
| 0    | User quit the menu normally (q/Esc)            |
| 1    | Docker not installed, daemon not running, or   |
|      | no running containers found                    |
| 2    | Invalid usage (reserved for future flags)      |
| 130  | Interrupted by SIGINT (Ctrl-C)                 |
| 143  | Terminated by SIGTERM                          |

## Interactive Key Bindings

| Key         | Action                                        |
|-------------|-----------------------------------------------|
| Up arrow    | Move highlight to previous container           |
| Down arrow  | Move highlight to next container               |
| Enter       | Open interactive shell in highlighted container|
| `q`         | Quit DockShell                                 |
| Escape      | Quit DockShell                                 |
| `r`         | Refresh container list                         |
| Ctrl-C      | Quit DockShell (signal-based)                  |

## Standard Streams

| Stream | Usage                                            |
|--------|--------------------------------------------------|
| stdout | Interactive menu display (alternate screen)       |
| stderr | Error messages (Docker not found, no containers)  |
| stdin  | Keystroke input (raw mode via `read -rsN1`)       |

## Docker Commands Used

| Command | Purpose | Destructive |
|---------|---------|-------------|
| `docker ps --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}'` | List running containers | No |
| `docker exec -it <id> bash` | Open bash shell in container | No |
| `docker exec -it <id> sh` | Open sh shell (fallback) | No |
| `docker exec <id> sh -c 'command -v bash'` | Probe for bash availability | No |

No other Docker commands are permitted (constitution: Docker Safety).

## Terminal Requirements

- VT100-compatible terminal emulator
- `tput` available (ncurses)
- Bash 4.0+ as interpreter
