# Container Environment Instructions

You are running inside a Docker container. Your work directory is `/workspace/repo`.

## Persistent Tool Installation

Tools you install with `apt-get`, `pip`, `npm install -g`, etc. do NOT survive
container restarts because the root filesystem is ephemeral.

A persistent volume is mounted at **`/opt/tools`**. To make installations survive
restarts, create or update the script `/opt/tools/setup.sh` with the commands
needed to reinstall everything. This script is executed automatically every time
the container starts.

### How to use it

1. Install the tool you need normally (e.g. `sudo apt-get install -y dotnet-sdk-8.0`).
2. Append the install command to `/opt/tools/setup.sh` so it will be re-run next time.

Example `/opt/tools/setup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# .NET SDK
sudo apt-get update -qq
sudo apt-get install -y -qq dotnet-sdk-8.0

# Extra Python packages
pip3 install --break-system-packages httpx pydantic

# Extra Node tools
npm install -g vitest
```

**Rules for setup.sh:**

- Always use `sudo` for `apt-get`.
- Use `-y` and `-qq` flags so installs are non-interactive and quiet.
- Make the script idempotent — safe to run repeatedly.
- Keep it fast: only add what you actually need.

## Output & Reports

Write any reports, summaries or deliverables to `/workspace/output`. This
directory is mounted from the host and the user can see the files immediately.

## Docker Access

When Docker is available (`/var/run/docker.sock` is mounted), you can use the
`docker` CLI to build images, run containers, etc. Do NOT start background
daemons — only use the host Docker daemon via the socket.

## Git & SSH

Git is pre-configured with an SSH key for the repo. Do not modify the
`GIT_SSH_COMMAND` environment variable.
