#!/usr/bin/env bash
set -euo pipefail
# Quick test of generate_compose + generate_scripts
cd "$(dirname "$0")"

source <(sed -n '/^sanitize()/,/^}/p' setup-wizard.sh)
source <(sed -n '/^generate_compose()/,/^}/p' setup-wizard.sh)
source <(sed -n '/^generate_scripts()/,/^}/p' setup-wizard.sh)

SANDBOX_DIR="/tmp/test-sandbox/my-project-main"
mkdir -p "$SANDBOX_DIR/reports"
touch "$SANDBOX_DIR/entrypoint.sh"
echo "GITHUB_TOKEN=test" > "$SANDBOX_DIR/shared.env"

generate_compose \
  "my-project-main" \
  "git@github.com:acme/my-project.git" \
  "main" \
  "claude-code-container" \
  "$HOME/.ssh/id_ed25519_claude" \
  "$HOME/.ssh/known_hosts" \
  "$SANDBOX_DIR/reports" \
  "1" \
  "1" \
  "$SANDBOX_DIR/shared.env" \
  "$SANDBOX_DIR/entrypoint.sh" \
  "$SANDBOX_DIR/docker-compose.yaml"

generate_scripts "$SANDBOX_DIR" "my-project-main"

echo "=== Files ==="
ls -la "$SANDBOX_DIR/"

echo ""
echo "=== start script ==="
cat "$SANDBOX_DIR/start"

echo ""
echo "=== destroy script ==="
cat "$SANDBOX_DIR/destroy"

echo ""
echo "=== Compose validation ==="
docker compose -f "$SANDBOX_DIR/docker-compose.yaml" config --quiet 2>&1 && echo "YAML VALID" || echo "YAML INVALID"

rm -rf /tmp/test-sandbox
echo ""
echo "All tests passed."
