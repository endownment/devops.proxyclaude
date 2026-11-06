#!/bin/sh
# First start: the mounted ~/.sdkman folder is empty, so fill it with the copy baked into the image.
set -eu
if [ ! -f /home/ubuntu/.sdkman/bin/sdkman-init.sh ]; then
  echo "[start] Copying SDKMAN from the image into ~/.sdkman"
  cp -a /home/ubuntu/.sdkman-seed/. /home/ubuntu/.sdkman/ || {
    echo "[start] No write access to ~/.sdkman. If your UID/GID differ from the ones in .env, update HOST_UID/HOST_GID (see README) and rebuild the image" >&2
    exit 1
  }
fi
exec sleep infinity
