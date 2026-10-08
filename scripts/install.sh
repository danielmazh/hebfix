#!/usr/bin/env bash
# Install HebFix.spoon into ~/.hammerspoon and add a marked config block.
# Idempotent: a second run changes nothing.
# Test hooks: HEBFIX_SKIP_OS_CHECK=1 skips the macOS check,
# HEBFIX_SKIP_HAMMERSPOON=1 skips the Hammerspoon check and install.
set -euo pipefail

MARK_BEGIN="-- >>> hebfix >>>"
MARK_END="-- <<< hebfix <<<"

die() {
  echo "install.sh: $*" >&2
  exit 1
}

if [ "${HEBFIX_SKIP_OS_CHECK:-0}" != "1" ]; then
  if [ "$(uname -s)" != "Darwin" ]; then
    die "hebfix needs macOS (Hammerspoon runs only on macOS)."
  fi
fi

if [ "${HEBFIX_SKIP_HAMMERSPOON:-0}" != "1" ]; then
  if [ ! -d "/Applications/Hammerspoon.app" ] && [ ! -d "$HOME/Applications/Hammerspoon.app" ]; then
    if command -v brew >/dev/null 2>&1; then
      echo "Hammerspoon not found, installing it with Homebrew..."
      brew install --cask hammerspoon
    else
      die "Hammerspoon not found and Homebrew is missing.
Install Hammerspoon from https://www.hammerspoon.org/ (or install Homebrew from https://brew.sh/),
then run this script again."
    fi
  fi
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
src="$(cd "$script_dir/.." && pwd)/HebFix.spoon"
[ -d "$src" ] || die "Spoon source not found: $src"

hs_dir="$HOME/.hammerspoon"
spoons_dir="$hs_dir/Spoons"
dest="$spoons_dir/HebFix.spoon"
init_file="$hs_dir/init.lua"

mkdir -p "$spoons_dir"

# Stage a clean copy (no .DS_Store) so the compare and the install use the same content.
stage="$(mktemp -d "${TMPDIR:-/tmp}/hebfix-install.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
cp -R "$src/." "$stage/"
find "$stage" -name .DS_Store -type f -exec rm -f {} +

if [ -d "$dest" ] && diff -r "$stage" "$dest" >/dev/null 2>&1; then
  echo "Spoon already up to date: $dest"
else
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -R "$stage/." "$dest/"
  echo "Installed Spoon: $dest"
fi

if [ -f "$init_file" ] && grep -qxF -- "$MARK_BEGIN" "$init_file"; then
  echo "Config block already present: $init_file"
else
  # Add a newline first if the file exists, is not empty, and does not end with one.
  if [ -s "$init_file" ] && [ "$(tail -c 1 "$init_file" | od -An -c | tr -d ' ')" != '\n' ]; then
    printf '\n' >>"$init_file"
  fi
  {
    printf '%s\n' "$MARK_BEGIN"
    printf '%s\n' 'hs.loadSpoon("HebFix")'
    printf '%s\n' 'spoon.HebFix:bindHotkeys({ convert = { { "ctrl", "shift" }, "space" } })'
    printf '%s\n' 'spoon.HebFix:start()'
    printf '%s\n' "$MARK_END"
  } >>"$init_file"
  echo "Added config block to: $init_file"
fi

cat <<'MSG'

Next steps:
  1. Grant Accessibility access: System Settings > Privacy & Security >
     Accessibility > enable Hammerspoon.
  2. Reload the Hammerspoon config (Hammerspoon menu bar icon > Reload Config).
  3. Select text typed in the wrong layout and press Ctrl+Shift+Space.
MSG
