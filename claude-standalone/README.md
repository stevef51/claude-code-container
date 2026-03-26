# claude-standalone — Sandbox Launcher

Run isolated Claude Code sessions against a private repo, each in its own
Docker volume. Multiple sessions can run in parallel like git worktrees.

## Quick Start

```bash
# Build the image (one-time, or after Dockerfile / CLAUDE.md changes)
docker build -t claude-code-container .

# Launch a sandbox
./claude_lucifer.sh ui-redesign spike/portal-ui-redesign

# Launch another in parallel
./claude_lucifer.sh dto-review master

# Resume the last conversation
RESUME=1 ./claude_lucifer.sh ui-redesign

# Wipe a sandbox and reclone
RESET_REPO=1 ./claude_lucifer.sh ui-redesign
```

## Secrets Management (git-crypt)

Secrets (Slack tokens, GitHub PAT, etc.) are stored in `.secrets.env` and
encrypted transparently by **git-crypt**. On GitHub the file is unreadable
binary; locally it decrypts automatically.

### Setup (already done)

```bash
brew install git-crypt
git-crypt init
# .gitattributes routes .secrets.env through git-crypt
```

### Unlock on a new machine

```bash
git clone git@github.com:stevef51/claude-code-container.git
cd claude-code-container
git-crypt unlock /path/to/exported-key
```

### Export / back up the key

```bash
git-crypt export-key ~/git-crypt-key-backup
```

**Keep this key safe.** It is the only way to decrypt `.secrets.env`.
If the key is lost, revoke the old tokens, generate new ones, reinitialise
git-crypt, and update `.secrets.env`.

### Adding or rotating secrets

Edit `.secrets.env`, commit, push. The file is automatically re-encrypted.

```bash
# Format — plain KEY="value" lines, no `export` prefix
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
SLACK_BOT_TOKEN="xoxb-..."
SLACK_CHANNEL_ID="C0..."
GITHUB_TOKEN="github_pat_..."
```

## File Reference

| File | Baked into image? | Purpose |
|---|---|---|
| `Dockerfile` | — | Image definition |
| `CLAUDE.md` | Yes (`/workspace/CLAUDE.md`) | Container instructions & skills for Claude |
| `claude-config.json` | Yes (`~/.claude.json`) | Permissions, tool allowlist |
| `settings.local.json` | Yes (`~/.claude/settings.local.json`) | Local settings |
| `claude_lucifer.sh` | No (host only) | Launcher — sets env vars, execs worker |
| `claude_repo_sandbox.sh` | No (host only) | Worker — volumes, clone, docker run |
| `.secrets.env` | No (host only) | Secrets, encrypted by git-crypt |

**Rebuild the image** after changing any "Yes" file:

```bash
docker build -t claude-code-container .
```

## Volumes

Each sandbox named `<NAME>` gets three Docker volumes:

| Volume | Mount | Purpose |
|---|---|---|
| `claude-work-...-<NAME>` | `/workspace/repo` | Cloned repo |
| `claude-work-...-<NAME>-state` | `/home/claude/.claude` | Session state (enables `--continue`) |
| `claude-work-...-<NAME>-tools` | `/opt/tools` | Persistent tool installs (`setup.sh`) |

Plus a host-mounted reports directory: `reports-<NAME>/` → `/workspace/output`

## Environment Variables

Set in the launcher, forwarded into the container:

| Variable | Default | Purpose |
|---|---|---|
| `ALLOW_INSTALL` | `1` | Allow `sudo` inside container |
| `MOUNT_DOCKER` | `1` | Mount host Docker socket |
| `RESUME` | `0` | Resume last conversation (`--continue`) |
| `RESET_REPO` | `0` | Wipe volume and reclone |
| `SLACK_WEBHOOK_URL` | (from `.secrets.env`) | Progress messages |
| `SLACK_BOT_TOKEN` | (from `.secrets.env`) | File/image uploads |
| `SLACK_CHANNEL_ID` | (from `.secrets.env`) | Upload target channel |
| `GITHUB_TOKEN` | (from `.secrets.env`) | GitHub API / `gh` CLI |
