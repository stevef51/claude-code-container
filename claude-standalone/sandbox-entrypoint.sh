#!/usr/bin/env bash
set -euo pipefail
#
# sandbox-entrypoint.sh — Shared entrypoint for all Claude Code sandboxes.
#
# Runs as root inside the container, fixes permissions, clones/fetches the
# repo, syncs baked-in assets, runs tool setup, then drops to the claude
# user and starts Claude Code.
#
# All behaviour is controlled via environment variables set by the
# docker-compose.yaml that launched this container.
#
# Required env vars:  REPO_URL, GIT_SSH_COMMAND
# Optional env vars:  BRANCH, RESET_REPO (0|1), CLAUDE_RESUME (0|1)
#

echo "────────────────────────────────────────────"
echo "  Claude Code Sandbox"
echo "  Repo:   $REPO_URL"
echo "  Branch: ${BRANCH:-<default>}"
echo "────────────────────────────────────────────"

# ── Fix volume ownership (running as root) ──────────────────────────────────
for dir in /workspace/repo /opt/tools /workspace/output; do
  mkdir -p "$dir"
  chown -R claude:claude "$dir" 2>/dev/null || true
done
mkdir -p /home/claude/.claude
chown -R claude:claude /home/claude/.claude 2>/dev/null || true
chmod 700 /home/claude/.claude

# ── Docker socket (if mounted) ─────────────────────────────────────────────
if [ -S /var/run/docker.sock ]; then
  chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

# ── Reset sandbox if requested ──────────────────────────────────────────────
if [ "${RESET_REPO:-0}" = "1" ]; then
  echo "Resetting sandbox (wiping repo volume)..."
  find /workspace/repo -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  chown -R claude:claude /workspace/repo
fi

# ── Clone or update repo (as claude user) ───────────────────────────────────
su -s /bin/bash claude -c "
  set -euo pipefail
  export GIT_SSH_COMMAND='$GIT_SSH_COMMAND'

  if [ ! -d /workspace/repo/.git ]; then
    echo 'Cloning repository...'
    git clone '$REPO_URL' /workspace/repo
  fi

  cd /workspace/repo
  git remote set-url origin '$REPO_URL'
  echo 'Fetching latest...'
  git fetch origin --prune || true

  BRANCH='${BRANCH:-}'
  if [ -n \"\$BRANCH\" ]; then
    if git show-ref --verify --quiet refs/heads/\"\$BRANCH\"; then
      git checkout \"\$BRANCH\"
    elif git ls-remote --exit-code --heads origin \"\$BRANCH\" >/dev/null 2>&1; then
      git checkout -b \"\$BRANCH\" --track origin/\"\$BRANCH\"
    else
      git checkout -b \"\$BRANCH\"
    fi
  fi

  echo \"Branch: \$(git branch --show-current 2>/dev/null || echo 'detached')\"
"

# ── Sync baked-in assets to repo workspace ──────────────────────────────────
if [ -d /workspace/.claude/skills ]; then
  mkdir -p /workspace/repo/.claude/skills
  cp -a /workspace/.claude/skills/. /workspace/repo/.claude/skills/
  chown -R claude:claude /workspace/repo/.claude
  echo "Synced skills → /workspace/repo/.claude/skills/"
fi
if [ -d /workspace/design-system ]; then
  mkdir -p /workspace/repo/design-system
  cp -a /workspace/design-system/. /workspace/repo/design-system/
  chown -R claude:claude /workspace/repo/design-system
  echo "Synced design-system → /workspace/repo/design-system/"
fi

# ── Persistent tool setup ──────────────────────────────────────────────────
if [ -f /opt/tools/setup.sh ]; then
  echo "Running tool setup..."
  bash /opt/tools/setup.sh
  echo "Tool setup complete."
fi

# ── Build Claude command ────────────────────────────────────────────────────
CLAUDE_CMD="claude --dangerously-skip-permissions"
if [ "${CLAUDE_RESUME:-0}" = "1" ]; then
  CLAUDE_CMD="$CLAUDE_CMD --continue"
fi

echo ""
echo "Starting Claude Code..."
echo ""

# ── Drop to claude user and exec ───────────────────────────────────────────
exec su -s /bin/bash claude -c "
  export GIT_SSH_COMMAND='$GIT_SSH_COMMAND'
  cd /workspace/repo
  exec $CLAUDE_CMD
"
