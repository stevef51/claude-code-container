#!/usr/bin/env bash
set -euo pipefail
#
# Launcher for stevef51/claude-lucifer repo sandboxes.
#
# Usage:
#   ./claude_lucifer.sh <name>            # required — isolated worktree name
#   ./claude_lucifer.sh <name> [branch]   # optional branch to check out
#
# Each <name> gets its own Docker volume and reports directory, so you can
# run multiple sandboxes of the same repo in parallel — like git worktrees:
#
#   ./claude_lucifer.sh main
#   ./claude_lucifer.sh feature-x  feature-x
#   ./claude_lucifer.sh experiment
#
# To wipe a sandbox and reclone:
#   RESET_REPO=1 ./claude_lucifer.sh main
#

NAME="${1:?Usage: $0 <name> [branch]}"
BRANCH_ARG="${2:-}"

export IMAGE="claude-code-container"
export REPO_URL="git@github.com:stevef51/claude-lucifer.git"
export BRANCH="$BRANCH_ARG"
export VOLUME_NAME="claude-work-stevef51-claude-lucifer-${NAME}"
export REPORTS_DIR="$HOME/repos/claude-code-container/claude-standalone/reports-${NAME}"

# Dedicated SSH key for Claude/GitHub access
export SSH_KEY_PATH="$HOME/.ssh/id_ed25519_claude"
export KNOWN_HOSTS_PATH="$HOME/.ssh/known_hosts"

# Set to 1 to wipe the Docker volume repo copy and reclone
export RESET_REPO="${RESET_REPO:-0}"

# Allow Claude to install tools (apt-get, npm, pip, dotnet, etc.) in the
# container via sudo.  This relaxes --cap-drop and --no-new-privileges.
export ALLOW_INSTALL="1"

# Set to 1 to mount host Docker socket so Claude can run docker build/run.
# SECURITY: this gives the container near-root access to the host.
export MOUNT_DOCKER="${MOUNT_DOCKER:-1}"

# Set to 1 (or use RESUME=1 env) to resume the most recent conversation
export RESUME="${RESUME:-0}"

# Load secrets (encrypted by git-crypt in the repo)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=.secrets.env
set -a
source "${SCRIPT_DIR}/.secrets.env"
set +a

exec "${SCRIPT_DIR}/claude_repo_sandbox.sh"