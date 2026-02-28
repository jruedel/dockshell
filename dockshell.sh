#!/usr/bin/env bash
# DockShell — Interactive Docker container shell picker
# https://github.com/jruedel/dockshell
set -euo pipefail

DOCKSHELL_VERSION="0.1.0"

# --- Global state ---
declare -a CONTAINER_IDS=()
declare -a CONTAINER_NAMES=()
declare -a CONTAINER_IMAGES=()
declare -a CONTAINER_STATUSES=()
CONTAINER_COUNT=0

cursor=0
scroll_offset=0
visible_count=0
term_rows=0
term_cols=0
saved_tty=""
needs_redraw=1

# --- Functions ---

cleanup() {
    tput cnorm 2>/dev/null || true
    tput clear 2>/dev/null || true
    if [[ -n "$saved_tty" ]]; then
        stty "$saved_tty" 2>/dev/null || true
    fi
}

init_terminal() {
    saved_tty="$(stty -g)"
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap handle_resize WINCH
    tput clear
    tput civis
}

die() {
    printf '%s\n' "$1" >&2
    exit "${2:-1}"
}

check_prerequisites() {
    if ! command -v docker &>/dev/null; then
        die "Docker is not installed. Please install Docker first."
    fi

    local output
    output="$(docker ps --format '{{.ID}}' 2>&1)" || {
        if [[ "$output" == *"Cannot connect"* ]] || \
           [[ "$output" == *"failed to connect"* ]] || \
           [[ "$output" == *"daemon is not running"* ]]; then
            die "Docker daemon is not running. Start it with 'docker start' or launch Docker Desktop."
        elif [[ "$output" == *"permission denied"* ]] || \
             [[ "$output" == *"Permission denied"* ]] || \
             [[ "$output" == *"Got permission denied"* ]]; then
            die "Permission denied. Add your user to the docker group or use rootless Docker."
        else
            die "Docker error: $output"
        fi
    }
}

fetch_containers() {
    CONTAINER_IDS=()
    CONTAINER_NAMES=()
    CONTAINER_IMAGES=()
    CONTAINER_STATUSES=()
    CONTAINER_COUNT=0

    while IFS=$'\t' read -r id name image status; do
        CONTAINER_IDS+=("$id")
        CONTAINER_NAMES+=("$name")
        CONTAINER_IMAGES+=("$image")
        CONTAINER_STATUSES+=("$status")
    done < <(docker ps --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null \
        | sort -t$'\t' -k3,3 -k2,2)

    CONTAINER_COUNT=${#CONTAINER_IDS[@]}
}

update_dimensions() {
    term_rows="$(tput lines)"
    term_cols="$(tput cols)"
    # 3 rows for chrome: 1 header + 1 blank + 1 footer
    local chrome=3
    visible_count=$((term_rows - chrome))
    if (( visible_count < 1 )); then
        visible_count=1
    fi
    if (( visible_count > CONTAINER_COUNT )); then
        visible_count=$CONTAINER_COUNT
    fi
}

truncate_str() {
    local str="$1" max="$2"
    if (( ${#str} > max )); then
        printf '%s' "${str:0:$((max - 1))}…"
    else
        printf '%s' "$str"
    fi
}

render_menu() {
    update_dimensions

    # Clamp scroll/cursor after dimension changes
    if (( scroll_offset + visible_count > CONTAINER_COUNT )); then
        scroll_offset=$((CONTAINER_COUNT - visible_count))
        if (( scroll_offset < 0 )); then scroll_offset=0; fi
    fi
    if (( cursor >= CONTAINER_COUNT )); then
        cursor=$((CONTAINER_COUNT - 1))
        if (( cursor < 0 )); then cursor=0; fi
    fi

    # Header
    tput cup 0 0
    tput bold
    local header
    header="DockShell — ${CONTAINER_COUNT} container"
    if (( CONTAINER_COUNT != 1 )); then header+="s"; fi
    printf '%-*s' "$term_cols" "$header"
    tput sgr0

    # Container rows
    local row=1
    local i
    for (( i = scroll_offset; i < scroll_offset + visible_count && i < CONTAINER_COUNT; i++ )); do
        tput cup "$row" 0

        # Calculate column widths: name(30%) image(35%) status(35%)
        local name_w=$(( term_cols * 30 / 100 ))
        local image_w=$(( term_cols * 35 / 100 ))
        local status_w=$(( term_cols - name_w - image_w - 2 ))  # -2 for separators

        local name_str image_str status_str
        name_str="$(truncate_str "${CONTAINER_NAMES[$i]}" "$name_w")"
        image_str="$(truncate_str "${CONTAINER_IMAGES[$i]}" "$image_w")"
        status_str="$(truncate_str "${CONTAINER_STATUSES[$i]}" "$status_w")"

        if (( i == cursor )); then
            tput rev
        fi

        printf '%-*s %-*s %-*s' \
            "$name_w" "$name_str" \
            "$image_w" "$image_str" \
            "$status_w" "$status_str"

        if (( i == cursor )); then
            tput sgr0
        fi

        tput el
        (( row++ ))
    done

    # Clear any leftover rows from previous renders
    while (( row < term_rows - 1 )); do
        tput cup "$row" 0
        tput el
        (( row++ ))
    done

    # Footer
    tput cup $((term_rows - 1)) 0
    tput bold
    printf '%-*s' "$term_cols" "↑↓:Navigate  Enter:Shell  r:Refresh  q:Quit"
    tput sgr0

    needs_redraw=0
}

read_key() {
    local byte=""
    REPLY=""

    # Bash 3.2 on macOS only supports integer timeouts.
    # -t 1 gives 1-second timeout for SIGWINCH delivery.
    if ! read -rsn1 -t 1 byte; then
        REPLY="timeout"
        return
    fi

    case "$byte" in
        $'\x1b')  # ESC — could be arrow key or bare Escape
            # Read next byte: [ or O for arrow sequences, empty for bare ESC.
            # 1-second timeout only triggers for bare ESC (arrow key bytes
            # arrive within microseconds from the terminal emulator).
            local second=""
            if read -rsn1 -t 1 second; then
                case "$second" in
                    "["|"O")
                        local third=""
                        read -rsn1 -t 1 third
                        case "${second}${third}" in
                            "[A"|"OA") REPLY="up" ;;
                            "[B"|"OB") REPLY="down" ;;
                            "[C"|"OC") REPLY="right" ;;
                            "[D"|"OD") REPLY="left" ;;
                            *)         REPLY="unknown" ;;
                        esac
                        ;;
                    *)  REPLY="unknown" ;;
                esac
            else
                REPLY="escape"  # bare ESC (timeout, no follow-up bytes)
            fi
            ;;
        "")        REPLY="enter" ;;  # -n1 returns empty on Enter
        "q"|"Q")   REPLY="q" ;;
        "r"|"R")   REPLY="r" ;;
        *)         REPLY="unknown" ;;
    esac
}

move_cursor() {
    local direction="$1"
    case "$direction" in
        up)
            if (( cursor > 0 )); then
                (( cursor-- ))
                if (( cursor < scroll_offset )); then
                    scroll_offset=$cursor
                fi
            fi
            ;;
        down)
            if (( cursor < CONTAINER_COUNT - 1 )); then
                (( cursor++ ))
                if (( cursor >= scroll_offset + visible_count )); then
                    scroll_offset=$((cursor - visible_count + 1))
                fi
            fi
            ;;
    esac
    needs_redraw=1
}

exec_shell() {
    local cid="$1"

    # Restore terminal for the shell session
    tput clear
    tput cnorm
    stty "$saved_tty"

    # Probe for bash, fallback to sh
    local shell="sh"
    if docker exec "$cid" sh -c 'command -v bash' &>/dev/null; then
        shell="bash"
    fi

    # Check if container is still running before exec
    if ! docker inspect --format '{{.State.Running}}' "$cid" 2>/dev/null | grep -q true; then
        printf 'Container %s is no longer running.\n' "$cid" >&2
        sleep 2
        tput clear
        tput civis
        return 1
    fi

    # Run interactive shell — stderr goes to terminal naturally
    docker exec -it "$cid" "$shell" || {
        printf '\nShell exited with an error. Returning to menu...\n' >&2
        sleep 1
    }

    # Re-enter menu screen
    tput clear
    tput civis
}

show_help() {
    cat <<'EOF'
Usage: dockshell [OPTIONS]

Interactive Docker container shell picker.

Options:
  -h, --help      Show this help message and exit
  --version       Show version and exit

Key Bindings:
  Up/Down arrow   Navigate the container list
  Enter           Open an interactive shell in the selected container
  r               Refresh the container list
  q / Escape      Quit DockShell
  Ctrl-C          Quit DockShell

DockShell lists running Docker containers sorted by image name, then
container name. Select a container and press Enter to open a shell
(bash if available, otherwise sh). After exiting the shell, you
return to the menu.
EOF
}

handle_resize() {
    needs_redraw=1
}

main() {
    # Flag handling before interactive mode
    case "${1:-}" in
        -h|--help)    show_help; exit 0 ;;
        --version)    printf 'dockshell %s\n' "$DOCKSHELL_VERSION"; exit 0 ;;
        -*)           printf 'Unknown option: %s\nTry: dockshell --help\n' "$1" >&2; exit 2 ;;
    esac

    check_prerequisites
    fetch_containers

    if (( CONTAINER_COUNT == 0 )); then
        die "No running containers found."
    fi

    init_terminal
    needs_redraw=1

    while true; do
        if (( needs_redraw )); then
            render_menu
        fi

        read_key
        case "$REPLY" in
            up|down)    move_cursor "$REPLY" ;;
            enter)
                if (( CONTAINER_COUNT > 0 )); then
                    exec_shell "${CONTAINER_IDS[$cursor]}"
                    fetch_containers
                    if (( CONTAINER_COUNT == 0 )); then
                        cleanup
                        die "No running containers found."
                    fi
                    # Clamp cursor after refresh
                    if (( cursor >= CONTAINER_COUNT )); then
                        cursor=$((CONTAINER_COUNT - 1))
                    fi
                    needs_redraw=1
                fi
                ;;
            q|escape)   exit 0 ;;
            r)
                fetch_containers
                if (( CONTAINER_COUNT == 0 )); then
                    cleanup
                    die "No running containers found."
                fi
                if (( cursor >= CONTAINER_COUNT )); then
                    cursor=$((CONTAINER_COUNT - 1))
                fi
                scroll_offset=0
                needs_redraw=1
                ;;
            timeout)    ;; # no-op, allows SIGWINCH delivery
            *)          ;; # ignore unknown keys
        esac
    done
}

main "$@"
