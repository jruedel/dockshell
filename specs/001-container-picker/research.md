# Research: Interactive Container Picker

**Feature**: 001-container-picker | **Date**: 2026-02-27

---

## 1. Raw Terminal Input (Single Keystroke Reading)

### Decision

Use a **two-step read** approach: `read -rsN1` for the first byte (blocking), then `read -rsN1 -t 0.01` in a loop to drain any remaining bytes of a multi-byte escape sequence. Do **not** use `stty raw`; instead keep the terminal in cooked mode and rely on `read -rs` which handles the necessary line-discipline bypass internally.

### Rationale

- `read -rs` suppresses echo (`-s`) and treats backslash literally (`-r`). Combined with `-N1` (exactly 1 byte, does not treat newline as special) it gives single-keystroke capture without requiring manual `stty` mode changes for the read itself.
- The two-step pattern (block on first byte, then non-blocking drain with short timeout) is the canonical approach documented on [Greg's Wiki (ReadingFunctionKeysInBash)](https://mywiki.wooledge.org/ReadingFunctionKeysInBash) and used by production-grade pure-Bash tools like [fff](https://github.com/dylanaraps/fff).
- A small timeout (0.01s-0.05s) on the follow-up reads is enough to capture the 2-5 trailing bytes of escape sequences while still feeling instant to the user.
- We still need `stty` for *saving/restoring* terminal state and for disabling echo at the `stty` level as a safety net (see Section 5), but the actual keystroke reading uses `read` flags rather than `stty raw`.

### Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| `stty raw -echo` + `dd bs=1 count=1` | Heavier; gives no advantage over `read -rsN1`; `dd` adds a subprocess per keystroke. |
| `read -rsn3` (fixed 3-byte read) | Blocks if user presses a regular key (only 1 byte); cannot handle sequences longer than 3 bytes (e.g., `\e[1;5A` for Ctrl+Up is 6 bytes). |
| `read -rsn1` (lowercase n) | Differs from `-N1`: lowercase `-n` treats newline/delimiter as terminating, so pressing Enter returns empty string. `-N1` is safer for raw byte capture. Requires Bash 4.1+. |

---

## 2. Screen Drawing with tput

### Decision

Use **`tput`** for all cursor positioning, attribute control, and screen queries. Prefer terminfo capability names. The following capabilities form the safe cross-platform core for macOS (ncurses) and Linux (ncurses):

| Capability | tput Command | Purpose |
|---|---|---|
| Move cursor | `tput cup $row $col` | Position cursor at (row, col) |
| Clear to end of line | `tput el` | Wipe remainder of a line before reprinting |
| Reverse video on | `tput rev` | Highlight selected item |
| Bold on | `tput bold` | Emphasize text |
| All attributes off | `tput sgr0` | Reset to normal rendering |
| Hide cursor | `tput civis` | Prevent cursor flicker during redraws |
| Show cursor | `tput cnorm` | Restore cursor on exit |
| Save cursor | `tput sc` | Bookmark position before drawing |
| Restore cursor | `tput rc` | Return to bookmarked position |
| Terminal width | `tput cols` | Query column count |
| Terminal height | `tput lines` | Query row count |
| Alternate screen enter | `tput smcup` | Switch to alternate buffer |
| Alternate screen exit | `tput rmcup` | Restore original buffer |

### Rationale

- `tput` resolves the correct escape sequence for the current `$TERM` via the terminfo database, making it inherently more portable than hardcoded ANSI codes.
- All capabilities listed above are present in both macOS ncurses and Linux ncurses for `xterm`, `xterm-256color`, `screen`, `screen-256color`, and `tmux-256color` -- the terminals DockShell will realistically encounter.
- `smcup`/`rmcup` (alternate screen buffer) is strongly recommended: it preserves the user's scrollback history and guarantees a clean restore on exit, matching user expectations from tools like `vim`, `less`, and `htop`.
- Hardcoded `\e[` sequences are acceptable as a *fallback* within the key-reading code path (where tput overhead per-keystroke is wasteful), but all *output* drawing should go through tput.

### Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| Hardcoded ANSI `\e[` sequences everywhere | Works on most terminals but breaks on non-VT100/non-ANSI terminals. Harder to maintain; no terminfo lookup. |
| `printf '\e[?1049h'` for alt screen | Functionally equivalent to `tput smcup` on xterm-likes, but not portable to all $TERM types. |
| Avoid alternate screen entirely | User's scrollback gets polluted; on exit the menu remnants are visible. Poor UX. |

---

## 3. Handling Terminal Resize (SIGWINCH)

### Decision

Trap `SIGWINCH` to recalculate dimensions and trigger a full redraw. Use `tput lines` and `tput cols` inside the handler (not cached `$LINES`/`$COLUMNS` which may update asynchronously). Use `read -t` with a short timeout in the main input loop so the trap can fire between iterations.

```text
Handler: trap 'handle_resize' WINCH
handle_resize: re-query dimensions, recalculate viewport, set redraw flag
Main loop: read -rsN1 -t 0.5 (timeout allows trap delivery)
```

### Rationale

- Bash delivers `SIGWINCH` when the terminal emulator resizes. The kernel updates the pty dimensions and signals the foreground process group.
- **Bash 5 issue**: Since Bash 5, signal handlers are installed with `SA_RESTART`, meaning `SIGWINCH` does **not** interrupt a blocking `read`. The workaround is to use `read -t <timeout>` so the read syscall returns periodically, giving Bash a chance to dispatch the pending trap. A 0.5s timeout is a good balance: responsive enough for resize, low enough CPU overhead.
- `tput lines`/`tput cols` re-query the terminal driver each call, ensuring correct values even if `$LINES`/`$COLUMNS` have not yet been updated by the shell.
- The fff file manager uses this exact pattern (`trap 'get_term_size; redraw' WINCH`) and it works reliably across macOS Terminal, iTerm2, and common Linux terminals.

### Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| Rely on `$LINES`/`$COLUMNS` only | These are updated by Bash for interactive shells, but the timing relative to the trap handler is not guaranteed. `tput` is more reliable. |
| Use `stty size` in handler | Works, but `tput lines`/`tput cols` is equivalent and consistent with the rest of the tput-based approach. Either is acceptable. |
| Ignore resize entirely | Broken layout after resize; unacceptable for a tool claiming clean terminal behavior. |
| Blocking `read` without timeout | Trap never fires in Bash 5 until user presses a key. Resize is silently ignored until next input. |

---

## 4. Scrolling / Viewport When List Exceeds Terminal Height

### Decision

Maintain three state variables: `cursor` (index of selected item in the full list), `scroll_offset` (index of the first visible item), and `visible_count` (number of items that fit on screen, calculated as `$(tput lines) - N` where N accounts for header/footer chrome). On each cursor movement, adjust `scroll_offset` to keep `cursor` visible using a **follow-cursor** strategy.

**Viewport adjustment rules**:

1. If `cursor < scroll_offset`, set `scroll_offset = cursor` (scrolled above viewport -- snap to cursor).
2. If `cursor >= scroll_offset + visible_count`, set `scroll_offset = cursor - visible_count + 1` (scrolled below viewport).
3. Otherwise, do not change `scroll_offset`.

On redraw, iterate from `scroll_offset` to `scroll_offset + visible_count - 1`, drawing each item. The selected item (`cursor`) gets reverse-video highlighting.

### Rationale

- This is the simplest correct scrolling model and the one used by fff, fzf-like selectors, and most TUI list widgets. It requires no complex centering math and is easy to reason about.
- Recalculating `visible_count` inside the SIGWINCH handler automatically adapts the viewport to terminal resizes.
- No external pager or scrollback mechanism is needed. The menu redraws in-place using `tput cup` to position each line, avoiding terminal scroll artifacts.
- Keeping `scroll_offset` stable (rule 3) prevents unnecessary visual jumps when the user is navigating within the visible area.

### Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| Center-cursor strategy (cursor always mid-screen) | More visual movement on every keystroke. Disorienting for short lists. fff uses it, but DockShell's list is typically shorter (tens of containers, not thousands of files). Follow-cursor is simpler and sufficient. |
| Page-at-a-time scrolling | Loses positional context when the viewport jumps a full page. Worse UX for lists of 10-100 items. |
| Delegate to `less` or `fzf` | Adds external dependency; violates FR-010 (single script, no deps beyond Bash + POSIX + Docker). |

---

## 5. Terminal State Save / Restore

### Decision

On startup, save full terminal state with `stty -g`, enter alternate screen, and hide the cursor. Register a cleanup function on `EXIT` (which covers normal exit, `exit` calls, and signal-induced termination when combined with signal traps). Also trap `INT` and `TERM` to call `exit` explicitly (which then triggers the `EXIT` trap).

```text
Startup sequence:
  1. saved_tty="$(stty -g)"
  2. trap cleanup EXIT
  3. trap 'exit 130' INT
  4. trap 'exit 143' TERM
  5. tput smcup          # alternate screen
  6. tput civis          # hide cursor
  7. stty -echo          # belt-and-suspenders echo suppression

Cleanup function:
  1. tput cnorm          # show cursor
  2. tput rmcup          # restore main screen
  3. stty "$saved_tty"   # restore all terminal settings
```

### Rationale

- `stty -g` produces an opaque string that captures *all* terminal settings (baud, flags, special chars). Restoring it guarantees no setting is left modified, even ones we did not explicitly change.
- The `EXIT` trap is the single most important cleanup mechanism because it fires on `exit`, end-of-script, and (in Bash) after signal traps that call `exit`. This means we never need to duplicate cleanup logic.
- Trapping `INT` and `TERM` to call `exit` (rather than running cleanup directly) ensures the `EXIT` trap fires *and* the exit code reflects the signal (130 for SIGINT, 143 for SIGTERM), which is correct POSIX behavior.
- `stty -echo` at the `stty` level is a safety net beyond `read -s`. If the script crashes between reads, echo remains suppressed and the alternate screen hides any damage. The `stty "$saved_tty"` restore undoes it.
- `smcup`/`rmcup` (alternate screen) ensures the user's scrollback and prompt are untouched regardless of how DockShell exits.

### Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| `stty sane` on cleanup | Resets to *default* settings, not the user's *actual* settings. If the user had custom stty config (e.g., `stty erase ^H`), it would be lost. `stty "$saved_tty"` is strictly better. |
| Trap every signal individually | Fragile, verbose, and easy to miss signals. The `EXIT`-based pattern covers all exit paths. |
| No alternate screen | Terminal scrollback is polluted. On exit, menu remnants are visible. Users running DockShell inside tmux or an IDE terminal would see residual escape codes. |
| `trap cleanup INT TERM EXIT` (single trap) | Works in Bash but the exit code is always 0, losing signal information. Separate INT/TERM traps calling `exit N` preserve the correct exit code. |

---

## 6. Arrow Key Escape Sequence Portability

### Decision

Detect arrow keys by matching **both** CSI (`\e[`) and SS3 (`\eO`) prefixes. After reading the first byte and identifying it as ESC (`$'\x1b'` / `$'\e'`), drain follow-up bytes with a short timeout and match the accumulated sequence against a lookup table.

**Sequences to match**:

| Key | CSI Form | SS3 Form |
|---|---|---|
| Up | `\e[A` | `\eOA` |
| Down | `\e[B` | `\eOB` |
| Right | `\e[C` | `\eOC` |
| Left | `\e[D` | `\eOD` |

A bare ESC (no follow-up bytes within the timeout) is treated as the Escape key.

### Rationale

- **CSI form (`\e[A`)**: This is the standard form emitted by xterm, iTerm2, Terminal.app, GNOME Terminal, Alacritty, Kitty, and the Linux console in normal mode. It covers 95%+ of real-world usage.
- **SS3 form (`\eOA`)**: Emitted by xterm and some terminals when "application cursor key mode" is active (enabled by the `smkx` terminfo capability). Some terminal multiplexers (tmux, screen) may also emit SS3 sequences depending on configuration.
- Matching both forms with a simple case statement costs nothing and prevents mysterious "arrow keys don't work" reports from edge-case terminal configurations.
- The timeout-based drain approach (reading follow-up bytes with `read -t 0.01`) naturally handles both 3-byte sequences (`\e[A`) and longer modified sequences (`\e[1;5A` for Ctrl+Up, if we ever need them) without hardcoding byte counts.
- A bare ESC with no follow-up is reliably distinguishable because real escape sequences arrive within microseconds of each other (same write buffer from the terminal emulator), while a human pressing ESC alone leaves a detectable gap.

### Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| Match only CSI (`\e[`) | Misses SS3 variants. Would cause "broken arrow keys" in application cursor mode or under certain tmux configs. Low cost to handle both. |
| Use `read -rsn3` and match fixed-length | Cannot distinguish ESC-as-key from ESC-as-sequence-prefix. Also fails on longer sequences (modified keys are 5-6 bytes). |
| Query `$TERM` and switch sequences | Over-engineered. The two-prefix approach handles all known terminals without needing terminal identification. |
| Use `tput kcuu1` etc. to get the actual sequences | Correct in theory but awkward: requires capturing tput output into variables at startup and doing string comparison in the hot loop. The hardcoded two-prefix approach is simpler, faster, and covers all practical cases. |

---

## 7. Docker Container Listing & Parsing

### Decision

Use `docker ps --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}'` with tab delimiters. Parse with `IFS=$'\t' read -r id name image status`. Sort with `sort -t$'\t' -k3,3 -k2,2` (image then name).

### Rationale

- `--format` with Go templates produces clean, machine-parseable output. Tab delimiter avoids collisions with spaces in Status field (e.g., "Up 3 hours").
- `docker ps` has no native `--sort-by` flag ([moby/moby#25609](https://github.com/moby/moby/issues/25609), closed). External `sort` is a POSIX utility and permitted by the constitution.
- Field 3 = Image, field 2 = Name matches the spec's required sort order.

### Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| `docker ps --format json` | Requires `jq` or complex Bash JSON parsing; violates "no jq" constraint. |
| Default `docker ps` tabular output | Variable-width columns, space-separated; fragile parsing when values contain spaces. |
| Multi-character delimiter (e.g., `\|\|\|`) | Bash `IFS` treats each character individually, not as a multi-char string. |
| Pure Bash array sort | Over-engineered when POSIX `sort` is available and allowed. |

---

## 8. Docker Error Detection

### Decision

Three-stage detection: (1) `command -v docker` to check installation, (2) capture stderr from `docker ps` to detect daemon issues, (3) check for empty output to detect no containers.

### Rationale

| Scenario | Exit Code | Stderr Pattern |
|---|---|---|
| Docker not installed | 127 (shell) | `command not found` |
| Daemon not running (Linux) | 1 | `Cannot connect to the Docker daemon` |
| Daemon not running (macOS) | 1 | `failed to connect to the docker API` |
| No containers running | 0 | (empty stdout) |
| Permission denied | 1 | `permission denied` |

Exit codes alone cannot distinguish "no containers" (exit 0, empty output) from "has containers" (exit 0, non-empty output). Pattern-matching stderr covers both Linux and macOS Docker Desktop variants.

### Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| `docker info` as pre-check | Extra daemon round-trip; slower. Better to attempt `docker ps` directly and diagnose. |
| Check `/var/run/docker.sock` | Not portable; Docker Desktop on macOS uses different socket path; `DOCKER_HOST` may be TCP. |
| Exit codes only | Cannot distinguish "no containers" from "has containers" (both exit 0). |

---

## 9. Shell Detection & Fallback in Containers

### Decision

Probe with `docker exec <container> sh -c 'command -v bash'` before exec. If bash is found, exec bash; otherwise exec sh.

### Rationale

- `command -v` is POSIX-specified and available in every `sh` implementation including BusyBox ash and dash.
- Running via `sh -c` guarantees the probe works even in minimal containers.
- Adds ~100-200ms overhead but avoids a failed `bash` exec that would flash an error and cause TTY artifacts before retrying.

### Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| Try `bash` directly, fall back on failure | Failed `bash` exec with `-it` partially allocates a TTY, causing visible error flash and potential artifacts. |
| `docker exec <container> test -x /bin/bash` | `bash` might be at `/usr/bin/bash`; `command -v` finds it regardless of location. |
| `docker exec <container> which bash` | `which` is not POSIX, not present in many minimal images. |
| Inspect container image metadata | Requires `docker inspect` + JSON parsing; installed packages don't reliably map to available binaries. |

---

## References

- [Greg's Wiki: ReadingFunctionKeysInBash](https://mywiki.wooledge.org/ReadingFunctionKeysInBash) -- canonical reference for keystroke reading in Bash
- [fff file manager](https://github.com/dylanaraps/fff) -- production pure-Bash TUI; demonstrates viewport, key reading, SIGWINCH handling
- [fff Bash 5 SIGWINCH issue](https://github.com/dylanaraps/fff/issues/48) -- documents SA_RESTART behavior and read -t workaround
- [GNU tput documentation](https://www.gnu.org/software/termutils/manual/termutils-2.0/html_chapter/tput_1.html) -- portable tput usage
- [tput man page (Linux)](https://www.man7.org/linux/man-pages/man1/tput.1.html)
- [tput man page (macOS)](https://ss64.com/mac/tput.html)
- [ANSI Escape Code (Wikipedia)](https://en.wikipedia.org/wiki/ANSI_escape_code) -- CSI and SS3 sequence reference
- [Bash Cookbook: Making Your Terminal Sane Again](https://www.oreilly.com/library/view/bash-cookbook/0596526784/ch19s09.html) -- stty save/restore patterns
- [Riptutorial: React on terminal resize](https://riptutorial.com/bash/example/19838/react-on-change-of-terminals-window-size) -- SIGWINCH trap example
- [linuxcommand.org: tput adventure](https://linuxcommand.org/lc3_adv_tput.php) -- practical tput tutorial
