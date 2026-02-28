# dockshell Development Guidelines

Last updated: 2026-02-27

## Active Technologies

- Bash 4.0+ + `tput`, `stty`, `printf`, `read`, `sort`, `docker` CLI (001-container-picker)

## Project Structure

```text
dockshell.sh              # Single executable script (root)
specs/                    # Feature specifications and design docs
.specify/                 # Speckit templates and config
```

## Commands

```bash
# Lint
shellcheck dockshell.sh

# Run
./dockshell.sh
```

## Code Style

Bash 4.0+: Follow standard conventions

## Recent Changes

- 001-container-picker: Added Bash 4.0+ + `tput`, `stty`, `printf`, `read`, `sort`, `docker` CLI

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
