#!/usr/bin/env bash
set -euo pipefail
#
# setup-wizard.sh — One-command setup for Claude Code Container.
#
# Run this to configure shared settings (SSH key, tokens) and generate a
# docker-compose.yaml for a specific repo/branch sandbox.
#
# First run:   sets up shared config + builds image + creates first sandbox.
# Re-runs:     reuses shared config (or updates it) + creates more sandboxes.
#
# Each sandbox is a self-contained compose file. Run with:
#
#   docker compose -f ~/.claude-sandbox/sandboxes/<name>.yaml run --rm claude
#   CLAUDE_RESUME=1 docker compose -f ~/.claude-sandbox/sandboxes/<name>.yaml run --rm claude
#   RESET_REPO=1 docker compose -f ~/.claude-sandbox/sandboxes/<name>.yaml run --rm claude
#
# Re-run this wizard any time to create additional sandboxes.
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.claude-sandbox"
CONFIG_FILE="$CONFIG_DIR/config"
SECRETS_FILE="$CONFIG_DIR/shared.env"
ENTRYPOINT_DEST="$CONFIG_DIR/entrypoint.sh"
SANDBOXES_DIR="$CONFIG_DIR/sandboxes"

# ── Color helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

header()  { echo -e "\n${BOLD}${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $1"; }
info()    { echo -e "${DIM}$1${NC}"; }
error()   { echo -e "${RED}✗${NC} $1" >&2; }

# ── Prompt helpers ──────────────────────────────────────────────────────────
ask() {
  local prompt="$1" default="${2:-}" var_name="$3"
  if [[ -n "$default" ]]; then
    printf "${CYAN}?${NC} ${BOLD}%s${NC} ${DIM}(%s)${NC}: " "$prompt" "$default"
  else
    printf "${CYAN}?${NC} ${BOLD}%s${NC}: " "$prompt"
  fi
  read -r answer
  if [[ -z "$answer" ]]; then
    answer="$default"
  fi
  eval "$var_name=\"\$answer\""
}

ask_secret() {
  local prompt="$1" default="${2:-}" var_name="$3"
  if [[ -n "$default" ]]; then
    local masked
    masked="$(echo "$default" | sed 's/./*/g' | head -c 20)..."
    printf "${CYAN}?${NC} ${BOLD}%s${NC} ${DIM}(%s)${NC}: " "$prompt" "$masked"
  else
    printf "${CYAN}?${NC} ${BOLD}%s${NC}: " "$prompt"
  fi
  read -rs answer
  echo
  if [[ -z "$answer" ]]; then
    answer="$default"
  fi
  eval "$var_name=\"\$answer\""
}

ask_yesno() {
  local prompt="$1" default="${2:-y}" var_name="$3"
  local hint="Y/n"
  [[ "$default" == "n" ]] && hint="y/N"
  printf "${CYAN}?${NC} ${BOLD}%s${NC} ${DIM}(%s)${NC}: " "$prompt" "$hint"
  read -r answer
  answer="${answer:-$default}"
  answer="$(echo "$answer" | tr '[:upper:]' '[:lower:]')"
  [[ "$answer" == "y" || "$answer" == "yes" ]] && eval "$var_name=1" || eval "$var_name=0"
}

ask_path() {
  local prompt="$1" default="${2:-}" var_name="$3"
  while true; do
    ask "$prompt" "$default" "$var_name"
    local val
    eval "val=\"\$$var_name\""
    val="${val/#\~/$HOME}"
    eval "$var_name=\"\$val\""
    if [[ -z "$val" ]]; then
      return 0
    fi
    if [[ -f "$val" ]]; then
      return 0
    else
      error "File not found: $val"
    fi
  done
}

sanitize() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# ── Load existing config ───────────────────────────────────────────────────
load_existing() {
  PREV_SSH_KEY=""
  PREV_GITHUB_TOKEN=""
  PREV_SLACK_WEBHOOK=""
  PREV_SLACK_BOT_TOKEN=""
  PREV_SLACK_CHANNEL=""
  PREV_ALLOW_INSTALL="1"
  PREV_MOUNT_DOCKER="0"
  PREV_IMAGE_NAME="claude-code-container"

  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    PREV_SSH_KEY="${SSH_KEY_PATH:-}"
    PREV_ALLOW_INSTALL="${ALLOW_INSTALL:-1}"
    PREV_MOUNT_DOCKER="${MOUNT_DOCKER:-0}"
    PREV_IMAGE_NAME="${IMAGE_NAME:-claude-code-container}"
  fi
  if [[ -f "$SECRETS_FILE" ]]; then
    # Secrets file is in env_file format (KEY=VALUE), source-compatible
    set -a
    # shellcheck source=/dev/null
    source "$SECRETS_FILE"
    set +a
    PREV_GITHUB_TOKEN="${GITHUB_TOKEN:-}"
    PREV_SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
    PREV_SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN:-}"
    PREV_SLACK_CHANNEL="${SLACK_CHANNEL_ID:-}"
    # Unset so they don't leak into compose variable substitution
    unset GITHUB_TOKEN SLACK_WEBHOOK_URL SLACK_BOT_TOKEN SLACK_CHANNEL_ID
  fi
}

# ── Generate compose file ──────────────────────────────────────────────────
generate_compose() {
  local sandbox_name="$1"
  local repo_url="$2"
  local branch="$3"
  local image="$4"
  local ssh_key="$5"
  local known_hosts="$6"
  local reports_dir="$7"
  local allow_install="$8"
  local mount_docker="$9"
  local env_file="${10}"
  local entrypoint="${11}"
  local compose_file="${12}"

  local vol_prefix="claude-$(sanitize "$sandbox_name")"
  local project_name="claude-$(sanitize "$sandbox_name")"

  # Build optional sections
  local security_block=""
  if [[ "$allow_install" != "1" ]]; then
    security_block="    cap_drop: [ALL]
    security_opt:
      - no-new-privileges:true"
  fi

  local docker_sock_volume=""
  if [[ "$mount_docker" == "1" ]]; then
    docker_sock_volume="      - /var/run/docker.sock:/var/run/docker.sock"
  fi

  mkdir -p "$(dirname "$compose_file")"
  mkdir -p "$reports_dir"

  cat > "$compose_file" << YAML
# ─────────────────────────────────────────────────────────────────────────
# Claude Code Sandbox: ${sandbox_name}
# Generated by setup-wizard.sh on $(date +%Y-%m-%d)
#
# Start:
#   docker compose -f ${compose_file} run --rm claude
#
# Resume last conversation:
#   CLAUDE_RESUME=1 docker compose -f ${compose_file} run --rm claude
#
# Wipe sandbox and reclone:
#   RESET_REPO=1 docker compose -f ${compose_file} run --rm claude
#
# Clean up networks after exit:
#   docker compose -f ${compose_file} down
# ─────────────────────────────────────────────────────────────────────────

name: ${project_name}

services:
  claude:
    image: ${image}
    stdin_open: true
    tty: true
    user: "root"
    entrypoint: ["/usr/bin/dumb-init", "--", "/run/entrypoint.sh"]
    command: []

    environment:
      REPO_URL: "${repo_url}"
      BRANCH: "${branch}"
      RESET_REPO: "\${RESET_REPO:-0}"
      CLAUDE_RESUME: "\${CLAUDE_RESUME:-0}"
      GIT_SSH_COMMAND: "ssh -i /run/claude-ssh/id_ed25519 -o UserKnownHostsFile=/run/claude-ssh/known_hosts -o StrictHostKeyChecking=yes"

    env_file:
      - ${env_file}

    volumes:
      - repo:/workspace/repo:rw
      - state:/home/claude/.claude:rw
      - tools:/opt/tools:rw
      - ${reports_dir}:/workspace/output:rw
      - ${entrypoint}:/run/entrypoint.sh:ro
      - ${ssh_key}:/run/claude-ssh/id_ed25519:ro
      - ${known_hosts}:/run/claude-ssh/known_hosts:ro
${docker_sock_volume}

    tmpfs:
      - /tmp:noexec,nosuid,size=100m
      - /workspace/temp:noexec,nosuid,size=2g

    pids_limit: 512
    network_mode: bridge
${security_block}

volumes:
  repo:
    name: ${vol_prefix}-repo
  state:
    name: ${vol_prefix}-state
  tools:
    name: ${vol_prefix}-tools
YAML

  chmod 600 "$compose_file"
}

# ── Generate helper scripts in sandbox folder ──────────────────────────────
generate_scripts() {
  local sandbox_dir="$1"
  local sandbox_name="$2"

  local compose="$sandbox_dir/docker-compose.yaml"

  # start
  cat > "$sandbox_dir/start" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec docker compose -f "$DIR/docker-compose.yaml" run --rm claude
SCRIPT

  # resume
  cat > "$sandbox_dir/resume" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec CLAUDE_RESUME=1 docker compose -f "$DIR/docker-compose.yaml" run --rm claude
SCRIPT

  # reset
  cat > "$sandbox_dir/reset" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec RESET_REPO=1 docker compose -f "$DIR/docker-compose.yaml" run --rm claude
SCRIPT

  # stop (clean up networks/orphans)
  cat > "$sandbox_dir/stop" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec docker compose -f "$DIR/docker-compose.yaml" down
SCRIPT

  # destroy (remove volumes too)
  cat > "$sandbox_dir/destroy" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "This will delete all data (repo, conversation history, tools) for this sandbox."
read -rp "Are you sure? (y/N): " confirm
[[ "$confirm" =~ ^[Yy] ]] || { echo "Aborted."; exit 0; }
docker compose -f "$DIR/docker-compose.yaml" down -v
echo "Volumes removed."
SCRIPT

  chmod +x "$sandbox_dir"/{start,resume,reset,stop,destroy}
}

# ════════════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════════════

clear
echo -e "${BOLD}"
cat << 'BANNER'
   ┌──────────────────────────────────────────────────────┐
   │                                                      │
   │   Claude Code Container — Setup Wizard               │
   │                                                      │
   │   Configure shared settings, build the image, and    │
   │   generate a docker-compose.yaml for each sandbox.   │
   │                                                      │
   │   Run again to create additional sandboxes.          │
   │                                                      │
   └──────────────────────────────────────────────────────┘
BANNER
echo -e "${NC}"

# ── Preflight ───────────────────────────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
  error "Docker is not installed or not on PATH."
  echo "  Install Docker Desktop: https://www.docker.com/products/docker-desktop"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  error "Docker daemon is not running."
  echo "  Start Docker Desktop and re-run this script."
  exit 1
fi
success "Docker is running"

if ! docker compose version >/dev/null 2>&1; then
  error "Docker Compose v2 is required but not found."
  echo "  Update Docker Desktop or install the compose plugin."
  exit 1
fi
success "Docker Compose v2 available"

load_existing

HAS_SHARED=0
if [[ -f "$CONFIG_FILE" && -f "$SECRETS_FILE" ]]; then
  HAS_SHARED=1
fi

# ═══════════════════════════════════════════════════════════════════════════
# SHARED SETTINGS (first run, or update)
# ═══════════════════════════════════════════════════════════════════════════

SKIP_SHARED=0
if [[ "$HAS_SHARED" == "1" ]]; then
  header "Shared Configuration"
  echo ""
  echo -e "  ${BOLD}SSH Key:${NC}       $PREV_SSH_KEY"
  echo -e "  ${BOLD}GitHub PAT:${NC}    $(if [[ -n "$PREV_GITHUB_TOKEN" ]]; then echo "configured"; else echo "not set"; fi)"
  echo -e "  ${BOLD}Slack:${NC}         $(if [[ -n "$PREV_SLACK_WEBHOOK" ]]; then echo "enabled"; else echo "disabled"; fi)"
  echo -e "  ${BOLD}Image:${NC}         $PREV_IMAGE_NAME"
  echo -e "  ${BOLD}Allow Install:${NC} $(if [[ "$PREV_ALLOW_INSTALL" == "1" ]]; then echo "yes"; else echo "no"; fi)"
  echo -e "  ${BOLD}Mount Docker:${NC}  $(if [[ "$PREV_MOUNT_DOCKER" == "1" ]]; then echo "yes"; else echo "no"; fi)"
  echo ""

  ask_yesno "Update shared settings?" "n" UPDATE_SHARED
  if [[ "$UPDATE_SHARED" != "1" ]]; then
    SKIP_SHARED=1
    # Carry forward previous values
    SSH_KEY_PATH="$PREV_SSH_KEY"
    KNOWN_HOSTS="$HOME/.ssh/known_hosts"
    GITHUB_TOKEN="$PREV_GITHUB_TOKEN"
    SLACK_WEBHOOK_URL="$PREV_SLACK_WEBHOOK"
    SLACK_BOT_TOKEN="$PREV_SLACK_BOT_TOKEN"
    SLACK_CHANNEL_ID="$PREV_SLACK_CHANNEL"
    IMAGE_NAME="$PREV_IMAGE_NAME"
    ALLOW_INSTALL="$PREV_ALLOW_INSTALL"
    MOUNT_DOCKER="$PREV_MOUNT_DOCKER"
  fi
fi

if [[ "$SKIP_SHARED" != "1" ]]; then
  # ── SSH Key ─────────────────────────────────────────────────────────────
  header "SSH Key"
  info "Claude needs an SSH key to clone private repos and push changes."
  echo ""

  DEFAULT_SSH=""
  for candidate in "$HOME/.ssh/id_ed25519_claude" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
    if [[ -f "$candidate" ]]; then
      DEFAULT_SSH="$candidate"
      break
    fi
  done
  [[ -n "$PREV_SSH_KEY" ]] && DEFAULT_SSH="$PREV_SSH_KEY"

  ask_path "Path to SSH private key" "$DEFAULT_SSH" SSH_KEY_PATH
  if [[ -z "$SSH_KEY_PATH" ]]; then
    error "SSH key is required for repo access."
    exit 1
  fi
  success "SSH key: $SSH_KEY_PATH"

  KNOWN_HOSTS="$HOME/.ssh/known_hosts"
  if [[ ! -f "$KNOWN_HOSTS" ]] || ! grep -q "github.com" "$KNOWN_HOSTS" 2>/dev/null; then
    info "Adding github.com to known_hosts..."
    mkdir -p "$HOME/.ssh"
    ssh-keyscan -t ed25519,rsa github.com >> "$KNOWN_HOSTS" 2>/dev/null
    success "github.com added to known_hosts"
  fi

  # ── GitHub Token ────────────────────────────────────────────────────────
  header "GitHub Personal Access Token"
  info "Used by the 'gh' CLI inside the container for issues, PRs, etc."
  info "Create at: https://github.com/settings/tokens  (scopes: repo, read:org)"
  echo ""

  ask_secret "GitHub PAT (ghp_... or github_pat_...)" "$PREV_GITHUB_TOKEN" GITHUB_TOKEN
  if [[ -z "$GITHUB_TOKEN" ]]; then
    warn "No GitHub token — gh CLI won't work in the container."
  else
    success "GitHub token configured"
  fi

  # ── Slack ───────────────────────────────────────────────────────────────
  header "Slack Integration (Optional)"
  info "Claude can post progress updates and screenshots to Slack."
  echo ""

  ask_yesno "Enable Slack integration?" "$( [[ -n "$PREV_SLACK_WEBHOOK" ]] && echo y || echo n )" SETUP_SLACK

  SLACK_WEBHOOK_URL=""
  SLACK_BOT_TOKEN=""
  SLACK_CHANNEL_ID=""

  if [[ "$SETUP_SLACK" == "1" ]]; then
    ask_secret "Slack Incoming Webhook URL" "$PREV_SLACK_WEBHOOK" SLACK_WEBHOOK_URL
    ask_secret "Slack Bot OAuth Token (xoxb-...)" "$PREV_SLACK_BOT_TOKEN" SLACK_BOT_TOKEN
    ask "Slack Channel ID (C0...)" "$PREV_SLACK_CHANNEL" SLACK_CHANNEL_ID
    success "Slack configured"
  else
    info "Slack skipped"
  fi

  # ── Container Options ──────────────────────────────────────────────────
  header "Container Defaults"
  echo ""

  ask "Docker image name" "$PREV_IMAGE_NAME" IMAGE_NAME

  ask_yesno "Allow tool installation inside container? (sudo)" \
    "$( [[ "$PREV_ALLOW_INSTALL" == "1" ]] && echo y || echo n )" ALLOW_INSTALL

  ask_yesno "Mount host Docker socket? (docker build/run inside container)" \
    "$( [[ "$PREV_MOUNT_DOCKER" == "1" ]] && echo y || echo n )" MOUNT_DOCKER

  # ── Save shared config ─────────────────────────────────────────────────
  header "Saving shared configuration..."

  mkdir -p "$CONFIG_DIR" "$SANDBOXES_DIR"
  chmod 700 "$CONFIG_DIR"

  cat > "$CONFIG_FILE" << EOF
# Claude Sandbox — shared configuration (generated by setup-wizard.sh)
SSH_KEY_PATH="$SSH_KEY_PATH"
KNOWN_HOSTS_PATH="$KNOWN_HOSTS"
IMAGE_NAME="$IMAGE_NAME"
ALLOW_INSTALL="$ALLOW_INSTALL"
MOUNT_DOCKER="$MOUNT_DOCKER"
CONTAINER_BUILD_DIR="$SCRIPT_DIR"
EOF
  chmod 600 "$CONFIG_FILE"
  success "Config: $CONFIG_FILE"

  # shared.env is in compose env_file format (KEY=VALUE, no export)
  cat > "$SECRETS_FILE" << EOF
# Claude Sandbox — shared secrets (compose env_file format)
# Used by all sandbox compose files. Rotate tokens here.
GITHUB_TOKEN=$GITHUB_TOKEN
SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL
SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN
SLACK_CHANNEL_ID=$SLACK_CHANNEL_ID
EOF
  chmod 600 "$SECRETS_FILE"
  success "Secrets: $SECRETS_FILE"
fi

# ── Install entrypoint script ──────────────────────────────────────────────
cp "$SCRIPT_DIR/sandbox-entrypoint.sh" "$ENTRYPOINT_DEST"
chmod 755 "$ENTRYPOINT_DEST"

# ═══════════════════════════════════════════════════════════════════════════
# DOCKER IMAGE
# ═══════════════════════════════════════════════════════════════════════════
header "Docker Image"

BUILD_NEEDED=0
if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  info "Image '$IMAGE_NAME' already exists."
  ask_yesno "Rebuild the Docker image?" "n" BUILD_NEEDED
else
  warn "Image '$IMAGE_NAME' not found."
  BUILD_NEEDED=1
fi

if [[ "$BUILD_NEEDED" == "1" ]]; then
  echo ""
  info "Building image (this may take a few minutes)..."
  echo ""
  cd "$SCRIPT_DIR"
  if docker build -t "$IMAGE_NAME" .; then
    echo ""
    success "Image '$IMAGE_NAME' built"
  else
    error "Docker build failed. Fix the errors above and re-run."
    exit 1
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# SANDBOX CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════
header "New Sandbox"
info "Configure the repo and branch for this sandbox."
info "Run the wizard again to create additional sandboxes."
echo ""

ask "Git repo SSH URL (git@github.com:owner/repo.git)" "" REPO_URL
if [[ -z "$REPO_URL" ]]; then
  error "Repo URL is required."
  exit 1
fi

ask "Branch (leave empty for repo default)" "" BRANCH

# Derive sandbox name
repo_slug="$(basename "${REPO_URL%.git}")"
owner_slug="$(echo "$REPO_URL" | sed -E 's#.*github\.com[:/]([^/]+)/.*#\1#')"
owner_slug="$(sanitize "$owner_slug")"
repo_slug="$(sanitize "$repo_slug")"

DEFAULT_NAME="${owner_slug}-${repo_slug}"
if [[ -n "$BRANCH" ]]; then
  DEFAULT_NAME="${DEFAULT_NAME}-$(sanitize "$BRANCH")"
fi

ask "Sandbox name" "$DEFAULT_NAME" SANDBOX_NAME
SANDBOX_NAME="$(sanitize "$SANDBOX_NAME")"

# Per-sandbox option overrides
echo ""
info "Override container defaults for this sandbox? (Default: use shared settings)"
ask_yesno "Customise container options for this sandbox?" "n" CUSTOM_OPTS

SB_ALLOW_INSTALL="$ALLOW_INSTALL"
SB_MOUNT_DOCKER="$MOUNT_DOCKER"

if [[ "$CUSTOM_OPTS" == "1" ]]; then
  ask_yesno "Allow tool installation? (sudo)" \
    "$( [[ "$ALLOW_INSTALL" == "1" ]] && echo y || echo n )" SB_ALLOW_INSTALL
  ask_yesno "Mount host Docker socket?" \
    "$( [[ "$MOUNT_DOCKER" == "1" ]] && echo y || echo n )" SB_MOUNT_DOCKER
fi

# Check for existing sandbox
SANDBOX_DIR="$SANDBOXES_DIR/${SANDBOX_NAME}"
COMPOSE_FILE="$SANDBOX_DIR/docker-compose.yaml"
if [[ -d "$SANDBOX_DIR" ]]; then
  warn "Sandbox '$SANDBOX_NAME' already exists: $SANDBOX_DIR/"
  ask_yesno "Overwrite it?" "n" OVERWRITE
  if [[ "$OVERWRITE" != "1" ]]; then
    echo "Aborted. Choose a different name or re-run."
    exit 0
  fi
fi

# ── Review ──────────────────────────────────────────────────────────────────
header "Review"
echo ""
echo -e "  ${BOLD}Sandbox Name:${NC}    $SANDBOX_NAME"
echo -e "  ${BOLD}Repo:${NC}            $REPO_URL"
echo -e "  ${BOLD}Branch:${NC}          ${BRANCH:-<default>}"
echo -e "  ${BOLD}Image:${NC}           $IMAGE_NAME"
echo -e "  ${BOLD}Allow Install:${NC}   $(if [[ "$SB_ALLOW_INSTALL" == "1" ]]; then echo "yes"; else echo "no"; fi)"
echo -e "  ${BOLD}Mount Docker:${NC}    $(if [[ "$SB_MOUNT_DOCKER" == "1" ]]; then echo "yes"; else echo "no"; fi)"
echo -e "  ${BOLD}Sandbox Dir:${NC}     $SANDBOX_DIR/"
echo ""

ask_yesno "Generate this sandbox?" "y" PROCEED
if [[ "$PROCEED" != "1" ]]; then
  echo "Aborted."
  exit 0
fi

# ── Generate ────────────────────────────────────────────────────────────────
REPORTS_DIR="$SANDBOX_DIR/reports"
mkdir -p "$SANDBOX_DIR"

generate_compose \
  "$SANDBOX_NAME" \
  "$REPO_URL" \
  "$BRANCH" \
  "$IMAGE_NAME" \
  "$SSH_KEY_PATH" \
  "$KNOWN_HOSTS" \
  "$REPORTS_DIR" \
  "$SB_ALLOW_INSTALL" \
  "$SB_MOUNT_DOCKER" \
  "$SECRETS_FILE" \
  "$ENTRYPOINT_DEST" \
  "$COMPOSE_FILE"

generate_scripts "$SANDBOX_DIR" "$SANDBOX_NAME"

success "Sandbox: $SANDBOX_DIR/"

# ═══════════════════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}"
cat << 'DONE'
   ┌──────────────────────────────────────────────────────┐
   │                                                      │
   │   Setup complete!                                    │
   │                                                      │
   └──────────────────────────────────────────────────────┘
DONE
echo -e "${NC}"

echo -e "${BOLD}Sandbox: ${SANDBOX_DIR}/${NC}"
echo ""
echo -e "  ${CYAN}start${NC}    — Launch Claude in the sandbox"
echo -e "  ${CYAN}resume${NC}   — Resume last conversation"
echo -e "  ${CYAN}reset${NC}    — Wipe repo and reclone"
echo -e "  ${CYAN}stop${NC}     — Clean up networks"
echo -e "  ${CYAN}destroy${NC}  — Delete all sandbox data (volumes)"
echo ""
echo -e "${BOLD}Quick start:${NC}"
echo ""
echo -e "  ${SANDBOX_DIR}/start"
echo ""
echo -e "${DIM}Tip: add to ~/.zshrc for a shortcut:${NC}"
echo -e "  alias ${SANDBOX_NAME}='${SANDBOX_DIR}/start'"
echo ""
echo -e "${DIM}List all sandboxes:  ls ${SANDBOXES_DIR}/${NC}"
echo -e "${DIM}Create another:      ${SCRIPT_DIR}/setup-wizard.sh${NC}"
echo ""
