#!/usr/bin/env bash
# Build script — copies source artifacts to dist/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
DIST_DIR="$SCRIPT_DIR/dist"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

cp "$SRC_DIR/tokens.json" "$DIST_DIR/"
cp "$SRC_DIR/tokens.css" "$DIST_DIR/"
cp "$SRC_DIR/theme.css" "$DIST_DIR/"
cp "$SRC_DIR/tailwind-preset.css" "$DIST_DIR/"

# Copy images if they exist
if [ -d "$SRC_DIR/images" ]; then
  cp -r "$SRC_DIR/images" "$DIST_DIR/"
fi

echo "Build complete: $(ls -1 "$DIST_DIR" | wc -l) files in dist/"