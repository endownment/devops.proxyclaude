#!/bin/sh
# First start: fill the empty mounted folders, then install or update Claude Code.
set -eu

CLAUDE_BIN=/home/ubuntu/.local/bin/claude
CLAUDE_DIR=/home/ubuntu/.local/share/claude
DISTR_DIR=/distr

# SDKMAN: the mounted ~/.sdkman folder is empty on the first start, so fill it with the copy baked into the image.
if [ ! -f /home/ubuntu/.sdkman/bin/sdkman-init.sh ]; then
  echo "[start] Copying SDKMAN from the image into ~/.sdkman"
  cp -a /home/ubuntu/.sdkman-seed/. /home/ubuntu/.sdkman/ || {
    echo "[start] No write access to ~/.sdkman. If your UID/GID differ from the ones in .env, update HOST_UID/HOST_GID (see README) and rebuild the image" >&2
    exit 1
  }
fi

# Prints the installed Claude Code version (for example 2.1.325), or nothing if it is missing or broken.
installed_version() {
  [ -x "$CLAUDE_BIN" ] || return 0
  "$CLAUDE_BIN" --version 2>/dev/null | sed -n 's/^\([0-9][0-9.]*\).*/\1/p' | head -n 1
}

# Prints "<version> <path>" of the newest claude-<version>-*.zst archive in /distr, or nothing.
newest_archive() {
  for f in "$DISTR_DIR"/claude-*.zst; do
    [ -e "$f" ] || continue
    v=$(basename "$f" | sed -n 's/^claude-\([0-9][0-9.]*\)-.*\.zst$/\1/p')
    if [ -n "$v" ]; then
      printf '%s %s\n' "$v" "$f"
    else
      echo "[start] Ignoring $f: the name does not look like claude-<version>-<platform>.zst" >&2
    fi
  done | sort -V | tail -n 1
}

# Succeeds if version $1 is strictly newer than version $2.
is_newer() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$1" ]
}

# Unpacks the archive $1 as version $2 into ~/.local/share/claude/versions and points ~/.local/bin/claude to it.
# "claude install" is not used on purpose: it downloads the latest build from the network instead of using the local file.
install_from_archive() {
  echo "[start] Installing Claude Code $2 from $1"
  mkdir -p "$CLAUDE_DIR/versions" "$(dirname "$CLAUDE_BIN")" || return 1
  tmp="$CLAUDE_DIR/.$2.tmp"
  zstd -d -q -c "$1" > "$tmp" \
    && chmod 755 "$tmp" \
    && mv -f "$tmp" "$CLAUDE_DIR/versions/$2" \
    && ln -sfn "$CLAUDE_DIR/versions/$2" "$CLAUDE_BIN"
  status=$?
  rm -f "$tmp"
  return "$status"
}

install_or_update_claude() {
  installed=$(installed_version)
  newest=$(newest_archive)
  archive_version=${newest%% *}
  archive_path=${newest#* }

  if [ -z "$installed" ]; then
    if [ -n "$newest" ]; then
      install_from_archive "$archive_path" "$archive_version"
    else
      echo "[start] Claude Code is not installed and $DISTR_DIR has no archive, running the standard installer"
      timeout 900 sh -c 'curl -fsSL https://claude.ai/install.sh | bash'
    fi
  elif [ -n "$newest" ] && is_newer "$archive_version" "$installed"; then
    echo "[start] Claude Code $installed is installed, the archive has $archive_version"
    install_from_archive "$archive_path" "$archive_version"
  else
    echo "[start] Claude Code $installed is installed, nothing to do"
  fi
}

install_or_update_claude || echo "[start] Claude Code installation failed, see the messages above. The container keeps running" >&2

exec sleep infinity
