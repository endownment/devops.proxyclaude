#!/bin/sh
# Writes the UID/GID of the current user to .env (read by docker compose).
# Rebuild the image afterwards: docker compose up -d --build
set -eu
cd "$(dirname "$0")"

uid="$(id -u)"
gid="$(id -g)"

if [ "$uid" = "0" ] || [ "$gid" = "0" ]; then
  echo "Running as root (UID/GID 0): an image with these ids cannot be built. Run as a regular user." >&2
  exit 1
fi

printf '%s\n' \
  '# UID/GID of the container user (used when building the image).' \
  '# Docker Compose reads this file automatically. Keep secrets out of it: it is tracked by git.' \
  '# To use the ids of the current user, run: ./fill-user-env-with-current-user.sh' \
  "HOST_UID=$uid" \
  "HOST_GID=$gid" > .env

echo "Updated .env: HOST_UID=$uid HOST_GID=$gid"
echo "Rebuild the image: docker compose up -d --build"
