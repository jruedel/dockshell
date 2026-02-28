# Quickstart: DockShell

## Prerequisites

- Bash 4.0+ (`bash --version` to check)
- Docker CLI installed and daemon running (`docker ps` should work)
- Your user must have Docker permissions (member of `docker` group
  or using rootless Docker)

## Install

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/<owner>/dockshell/main/dockshell.sh \
  -o /usr/local/bin/dockshell

# Make executable
chmod +x /usr/local/bin/dockshell
```

Or simply copy `dockshell.sh` anywhere on your `$PATH`.

## Usage

```bash
# Launch the interactive container picker
dockshell
```

## Controls

| Key       | Action                            |
|-----------|-----------------------------------|
| Up/Down   | Navigate the container list       |
| Enter     | Open a shell in selected container|
| r         | Refresh the container list        |
| q / Esc   | Quit                              |
| Ctrl-C    | Quit                              |

## What Happens

1. DockShell lists all running Docker containers sorted by image
   name, then container name.
2. Use arrow keys to highlight the container you want.
3. Press Enter — you're in an interactive shell (bash if available,
   otherwise sh).
4. Type `exit` or press Ctrl-D to leave the container shell.
5. You're back in the DockShell menu. Pick another container or
   press `q` to quit.

## Troubleshooting

| Message | Cause | Fix |
|---------|-------|-----|
| "Docker is not installed" | `docker` not in PATH | Install Docker |
| "Docker daemon is not running" | Daemon not started | Start Docker Desktop or `systemctl start docker` |
| "No running containers found" | Zero running containers | Start a container first: `docker run -d nginx` |

## Verify Installation

```bash
# Start two test containers
docker run -d --name test1 nginx
docker run -d --name test2 alpine sleep 3600

# Launch DockShell
dockshell

# Clean up test containers
docker rm -f test1 test2
```
