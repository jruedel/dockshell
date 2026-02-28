# DockShell

Interactive terminal menu for jumping into Docker container shells.

DockShell lists your running Docker containers, lets you pick one with
arrow keys, and drops you into an interactive shell — no more typing
`docker ps` followed by `docker exec -it <id> bash`.

## Demo

```
DockShell — 3 containers
  my-api          node:18-alpine    Up 2 hours
> my-database     postgres:16       Up 2 hours
  my-redis        redis:7-alpine    Up 45 minutes

↑↓:Navigate  Enter:Shell  r:Refresh  q:Quit
```

## Prerequisites

- Bash (3.2+ on macOS, 4.0+ on Linux)
- Docker CLI installed and daemon running
- Your user must have permission to run `docker` commands

## Install

```bash
# Copy the script to a directory on your PATH
cp dockshell.sh /usr/local/bin/dockshell
chmod +x /usr/local/bin/dockshell
```

Or download directly:

```bash
curl -fsSL https://raw.githubusercontent.com/jruedel/dockshell/refs/heads/main/dockshell.sh \
  -o /usr/local/bin/dockshell
chmod +x /usr/local/bin/dockshell
```

## Usage

```bash
dockshell
```

### Key Bindings

| Key         | Action                                  |
|-------------|-----------------------------------------|
| Up / Down   | Navigate the container list             |
| Enter       | Open a shell in the selected container  |
| r           | Refresh the container list              |
| q / Escape  | Quit                                    |
| Ctrl-C      | Quit                                    |

### Options

```
dockshell --help      Show usage information
dockshell --version   Print version
```

### How It Works

1. DockShell lists all running containers sorted by image name, then
   container name.
2. Use arrow keys to highlight the container you want.
3. Press Enter — you're in an interactive shell (`bash` if available,
   otherwise `sh`).
4. Type `exit` or press Ctrl-D to leave the container shell.
5. You're back in the DockShell menu. Pick another or press `q` to quit.

## Troubleshooting

| Message                          | Cause                  | Fix                                                       |
|----------------------------------|------------------------|-----------------------------------------------------------|
| "Docker is not installed"        | `docker` not in PATH   | Install Docker                                            |
| "Docker daemon is not running"   | Daemon not started     | Start Docker Desktop or `systemctl start docker`          |
| "No running containers found"    | Zero running containers| Start a container first: `docker run -d nginx`            |
| "Permission denied"              | No Docker permissions  | Add your user to the `docker` group or use rootless Docker|

## Design Principles

- **Single file** — one script, no build steps, copy to install
- **Zero dependencies** — only Bash, standard POSIX utilities, and Docker CLI
- **Read-only** — never stops, kills, or removes containers
- **Portable** — works on macOS and Linux without modification
- **Clean terminal** — restores all terminal settings on exit

## License

MIT
