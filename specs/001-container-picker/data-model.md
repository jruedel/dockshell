# Data Model: Interactive Container Picker

**Feature**: 001-container-picker | **Date**: 2026-02-27

## Entities

### ContainerEntry

A running Docker container as displayed in the menu. Sourced live
from `docker ps` on each fetch.

| Attribute       | Type   | Source                    | Notes                              |
|-----------------|--------|---------------------------|------------------------------------|
| `id`            | string | `{{.ID}}`                 | Short container ID (12 chars)      |
| `name`          | string | `{{.Names}}`              | Container name                     |
| `image`         | string | `{{.Image}}`              | Image name (may include tag)       |
| `status`        | string | `{{.Status}}`             | e.g., "Up 3 hours (healthy)"      |

**Identity**: `id` is unique per container. `name` is unique within
a Docker daemon.

**Lifecycle**: Entries exist only while the menu is displayed. The
list is rebuilt on each fetch (launch, post-shell return, manual
refresh via `r`). There is no persistent state.

**Sort order**: Alphabetical by `image` (ascending), then by `name`
(ascending).

### MenuState

Runtime state for the interactive menu. Not persisted.

| Attribute        | Type    | Description                                          |
|------------------|---------|------------------------------------------------------|
| `containers`     | array   | Ordered list of ContainerEntry records                |
| `cursor`         | integer | Index of the currently highlighted item (0-based)     |
| `scroll_offset`  | integer | Index of the first visible item in the viewport       |
| `visible_count`  | integer | Number of items fitting on screen (terminal height - chrome) |
| `term_rows`      | integer | Current terminal height (rows)                        |
| `term_cols`      | integer | Current terminal width (columns)                      |

**State transitions**:

```text
[Launch] → fetch containers → [Menu Displayed]
  ↓ (arrow keys)          ↓ (Enter)          ↓ (q/Esc/Ctrl-C)
  update cursor/scroll     exec shell          cleanup & exit
                            ↓ (shell exit)
                          fetch containers → [Menu Displayed]
  ↓ (r key)
  fetch containers → [Menu Displayed] (cursor preserved if possible)
```

## Data Flow

```text
docker ps --format '...' | sort → parse into ContainerEntry[] → render menu
```

No data is written back to Docker. The tool is strictly read-only
with the sole exception of `docker exec -it` which opens an
interactive session.
