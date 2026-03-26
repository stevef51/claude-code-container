#!/usr/bin/env bash
#
# claude_repo_sandbox.sh — Reusable worker that clones a repo into a Docker
# named volume and runs Claude Code against it in dangerous mode.
#
# Required env vars:
#   IMAGE           Docker image name      (e.g. claude-code-container)
#   REPO_URL        SSH clone URL          (e.g. git@github.com:user/repo.git)
#   REPORTS_DIR     Host path for output   (mounted to /workspace/output)
#   SSH_KEY_PATH    Host path to private SSH key
#
# Optional env vars:
#   BRANCH            Git branch to check out (default: repo default)
#   VOLUME_NAME       Docker volume name (derived from REPO_URL if empty)
#   RESET_REPO        Set to "1" to wipe the volume repo before cloning
#   KNOWN_HOSTS_PATH  Host path to known_hosts (default: ~/.ssh/known_hosts)
#   ALLOW_INSTALL     Set to "1" to let Claude install tools via sudo inside
#                     the container.  SECURITY NOTE: this removes --cap-drop=ALL
#                     and --security-opt=no-new-privileges so the in-container
#                     sudo (configured in the Dockerfile) becomes functional.
#                     Keep this off (default "0") for maximum isolation.
#   RESUME            Set to "1" to resume the most recent Claude conversation
#                     (passes --continue to Claude).  Requires the state volume.
#   MOUNT_DOCKER      Set to "1" to mount /var/run/docker.sock into the
#                     container so Claude can run docker build/run against the
#                     host daemon.  SECURITY NOTE: this grants near-root access
#                     to the host — use only when you need in-container Docker.
#
set -euo pipefail

# ── Required ────────────────────────────────────────────────────────────────
: "${IMAGE:?IMAGE is required}"
: "${REPO_URL:?REPO_URL is required}"
: "${REPORTS_DIR:?REPORTS_DIR is required}"
: "${SSH_KEY_PATH:?SSH_KEY_PATH is required}"

# ── Optional with defaults ──────────────────────────────────────────────────
BRANCH="${BRANCH:-}"
VOLUME_NAME="${VOLUME_NAME:-}"
RESET_REPO="${RESET_REPO:-0}"
KNOWN_HOSTS_PATH="${KNOWN_HOSTS_PATH:-$HOME/.ssh/known_hosts}"
ALLOW_INSTALL="${ALLOW_INSTALL:-0}"
RESUME="${RESUME:-0}"
MOUNT_DOCKER="${MOUNT_DOCKER:-0}"

# ── Preflight checks ───────────────────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker not found on PATH" >&2
  exit 1
fi

if [[ ! -f "$SSH_KEY_PATH" ]]; then
  echo "Error: SSH key not found: $SSH_KEY_PATH" >&2
  exit 1
fi

if [[ ! -f "$KNOWN_HOSTS_PATH" ]]; then
  echo "Error: known_hosts not found: $KNOWN_HOSTS_PATH" >&2
  echo "Create it with:  ssh-keyscan github.com >> \"$KNOWN_HOSTS_PATH\"" >&2
  exit 1
fi

# ── Derive volume name from repo URL if not set ────────────────────────────
repo_slug="$(basename "${REPO_URL%.git}")"
owner_slug="$(echo "$REPO_URL" | sed -E 's#.*github\.com[:/]([^/]+)/.*#\1#')"
owner_slug="${owner_slug//[^a-zA-Z0-9_.-]/-}"
repo_slug="${repo_slug//[^a-zA-Z0-9_.-]/-}"

if [[ -z "$VOLUME_NAME" ]]; then
  VOLUME_NAME="claude-work-${owner_slug}-${repo_slug}"
fi

# State volume: persists ~/.claude across container restarts so
# "claude --continue" can resume prior conversations.
STATE_VOLUME="${VOLUME_NAME}-state"

# Tools volume: persists /opt/tools across container rebuilds.  If Claude
# creates /opt/tools/setup.sh it will be re-run automatically on every
# container start (e.g. apt-get install, pip install, npm install -g).
TOOLS_VOLUME="${VOLUME_NAME}-tools"

mkdir -p "$REPORTS_DIR"

# ── Summary ─────────────────────────────────────────────────────────────────
echo "=== Claude Repo Sandbox ==="
echo "Image:          $IMAGE"
echo "Repo:           $REPO_URL"
echo "Branch:         ${BRANCH:-<default>}"
echo "Volume:         $VOLUME_NAME"
echo "Reports dir:    $REPORTS_DIR"
echo "SSH key:        $SSH_KEY_PATH"
echo "known_hosts:    $KNOWN_HOSTS_PATH"
echo "Reset repo:     $RESET_REPO"
echo "Allow install:  $ALLOW_INSTALL"
echo "State volume:   $STATE_VOLUME"
echo "Tools volume:   $TOOLS_VOLUME"
echo "Resume:         $RESUME"
echo "Mount docker:   $MOUNT_DOCKER"
echo

# ── GIT_SSH_COMMAND shared by clone and run phases ──────────────────────────
GIT_SSH="ssh -i /run/claude-ssh/id_ed25519 -o UserKnownHostsFile=/run/claude-ssh/known_hosts -o StrictHostKeyChecking=yes"

# ── Ensure Docker volumes exist ─────────────────────────────────────────────
for vol in "$VOLUME_NAME" "$STATE_VOLUME" "$TOOLS_VOLUME"; do
  if ! docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "Creating Docker volume: $vol"
    docker volume create "$vol" >/dev/null
  fi
done

# ── Fix volume ownership (root one-shot) ───────────────────────────────────
echo "Fixing volume permissions..."
docker run --rm \
  --user root \
  -v "${VOLUME_NAME}:/workspace/repo" \
  -v "${STATE_VOLUME}:/home/claude/.claude" \
  -v "${TOOLS_VOLUME}:/opt/tools" \
  --entrypoint /bin/bash \
  "$IMAGE" -lc '
    set -euo pipefail
    mkdir -p /workspace/repo
    chown -R claude:claude /workspace/repo || true
    chmod 755 /workspace/repo
    mkdir -p /home/claude/.claude
    chown -R claude:claude /home/claude/.claude || true
    chmod 700 /home/claude/.claude
    mkdir -p /opt/tools
    chown -R claude:claude /opt/tools || true
    chmod 755 /opt/tools
  '

# ── Optional: wipe volume contents ─────────────────────────────────────────
if [[ "$RESET_REPO" == "1" ]]; then
  echo "Resetting repo volume contents..."
  docker run --rm \
    --user root \
    -v "${VOLUME_NAME}:/workspace/repo" \
    --entrypoint /bin/bash \
    "$IMAGE" -lc '
      set -euo pipefail
      find /workspace/repo -mindepth 1 -maxdepth 1 -exec rm -rf {} +
      chown -R claude:claude /workspace/repo || true
    '
fi

# ── Clone / fetch / branch ─────────────────────────────────────────────────
echo "Preparing repo inside Docker volume..."
docker run --rm \
  -v "${VOLUME_NAME}:/workspace/repo" \
  -v "${SSH_KEY_PATH}:/run/claude-ssh/id_ed25519:ro" \
  -v "${KNOWN_HOSTS_PATH}:/run/claude-ssh/known_hosts:ro" \
  --entrypoint /bin/bash \
  "$IMAGE" -lc "
    set -euo pipefail
    export GIT_SSH_COMMAND='${GIT_SSH}'

    if [[ ! -d /workspace/repo/.git ]]; then
      echo 'Cloning repository into named volume...'
      git clone '${REPO_URL}' /workspace/repo
    else
      echo 'Repository already exists in volume.'
    fi

    cd /workspace/repo
    git remote set-url origin '${REPO_URL}'
    git fetch origin --prune || true

    if [[ -n '${BRANCH}' ]]; then
      if git show-ref --verify --quiet refs/heads/'${BRANCH}'; then
        git checkout '${BRANCH}'
      elif git ls-remote --exit-code --heads origin '${BRANCH}' >/dev/null 2>&1; then
        git checkout -b '${BRANCH}' --track origin/'${BRANCH}'
      else
        git checkout -b '${BRANCH}'
      fi
    fi

    echo
    echo 'Repo ready at /workspace/repo'
    git remote -v
    git branch --show-current || true
    git status --short || true
  "

# ── Build docker-run arguments ─────────────────────────────────────────────
echo
echo "Starting Claude..."
echo "Repo lives in Docker volume: ${VOLUME_NAME}"
echo "Session state in Docker volume: ${STATE_VOLUME}"
echo "Claude edits that copy, not your host checkout."
echo

RUN_ARGS=(
  run -it --rm

  # Temp filesystems
  --tmpfs /tmp:noexec,nosuid,size=100m
  --tmpfs /workspace/temp:noexec,nosuid,size=2g

  # Process limits
  --pids-limit=512

  # Network: bridge only, no host access
  --network=bridge
)

if [[ "$ALLOW_INSTALL" == "1" ]]; then
  # ------------------------------------------------------------------
  # ALLOW_INSTALL mode: drop the strict security flags so that the
  # in-container sudo (configured in the Dockerfile) can work.
  # The tradeoff is that the container can escalate to root, which
  # increases the attack surface.  Use only when you need Claude to
  # install extra tools (apt, npm, pip, etc.) during a session.
  # ------------------------------------------------------------------
  echo "WARNING: ALLOW_INSTALL=1 — container security is relaxed (sudo enabled)."
  echo
fi

if [[ "$MOUNT_DOCKER" == "1" ]]; then
  # ------------------------------------------------------------------
  # MOUNT_DOCKER mode: bind-mount the host Docker socket so the
  # container can run docker build, docker run, etc.  This effectively
  # gives the container root-equivalent access to the host — the
  # trade-off is knowingly accepted when you set MOUNT_DOCKER=1.
  # ------------------------------------------------------------------
  if [[ -S /var/run/docker.sock ]]; then
    # On macOS Docker Desktop the socket appears as root:root 660 inside the
    # container, so --group-add alone doesn't help.  We start as root, fix
    # the socket permissions, then exec back to the claude user.
    DOCKER_SOCK_GID="$(stat -f '%g' /var/run/docker.sock 2>/dev/null \
                    || stat -c '%g' /var/run/docker.sock 2>/dev/null)"
    RUN_ARGS+=(
      -v /var/run/docker.sock:/var/run/docker.sock
      --group-add "${DOCKER_SOCK_GID}"
      --user root
    )
    echo "WARNING: MOUNT_DOCKER=1 — host Docker socket is mounted (near-root host access)."
    echo
  else
    echo "Error: MOUNT_DOCKER=1 but /var/run/docker.sock not found" >&2
    exit 1
  fi
fi

if [[ "$ALLOW_INSTALL" != "1" ]]; then
  RUN_ARGS+=(
    --cap-drop=ALL
    --security-opt=no-new-privileges:true
  )
fi

RUN_ARGS+=(
  # Volume mounts
  -v "${VOLUME_NAME}:/workspace/repo:rw"
  -v "${STATE_VOLUME}:/home/claude/.claude:rw"
  -v "${TOOLS_VOLUME}:/opt/tools:rw"
  -v "${REPORTS_DIR}:/workspace/output:rw"
  -v "${SSH_KEY_PATH}:/run/claude-ssh/id_ed25519:ro"
  -v "${KNOWN_HOSTS_PATH}:/run/claude-ssh/known_hosts:ro"

  # Entrypoint override
  --entrypoint /bin/bash
)

# ── Build the claude command line ────────────────────────────────────────────
CLAUDE_CMD="claude --dangerously-skip-permissions"
if [[ "$RESUME" == "1" ]]; then
  CLAUDE_CMD="$CLAUDE_CMD --continue"
fi

RUN_ARGS+=(
  # Image
  "$IMAGE"

  # Command — when MOUNT_DOCKER is on we start as root, fix the socket, then
  # drop to the claude user.  Otherwise we're already claude.
  -lc "
    set -euo pipefail
    export GIT_SSH_COMMAND='${GIT_SSH}'
    if [ -S /var/run/docker.sock ]; then
      chmod 666 /var/run/docker.sock
    fi
    # Re-run persistent tool setup if it exists
    if [ -f /opt/tools/setup.sh ]; then
      echo 'Running /opt/tools/setup.sh ...'
      bash /opt/tools/setup.sh
      echo 'Tool setup complete.'
    fi
    cd /workspace/repo
    if [ \"\$(id -u)\" = 0 ]; then
      exec su -s /bin/bash claude -c \"export GIT_SSH_COMMAND='\${GIT_SSH_COMMAND}' && cd /workspace/repo && ${CLAUDE_CMD}\"
    else
      exec ${CLAUDE_CMD}
    fi
  "
)

docker "${RUN_ARGS[@]}"
