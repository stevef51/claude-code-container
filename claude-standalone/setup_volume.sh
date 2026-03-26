# Fix ownership inside the Docker volume for the image's non-root user
docker run --rm \
  --user root \
  -v "${VOLUME_NAME}:/workspace/repo" \
  --entrypoint /bin/bash \
  "$IMAGE" -lc "
    set -euo pipefail
    mkdir -p /workspace/repo
    chown -R claude:claude /workspace/repo
    chmod 755 /workspace/repo
  "