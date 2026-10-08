#!/usr/bin/env bash
# Remove HebFix.spoon and the marked hebfix block from ~/.hammerspoon/init.lua.
# All other init.lua lines stay byte-for-byte. Safe to run when nothing is installed.
set -euo pipefail

MARK_BEGIN="-- >>> hebfix >>>"
MARK_END="-- <<< hebfix <<<"

hs_dir="$HOME/.hammerspoon"
dest="$hs_dir/Spoons/HebFix.spoon"
init_file="$hs_dir/init.lua"

if [ -d "$dest" ]; then
  rm -rf "$dest"
  echo "Removed Spoon: $dest"
else
  echo "Spoon not installed: $dest"
fi

if [ -f "$init_file" ] && grep -qxF -- "$MARK_BEGIN" "$init_file"; then
  if ! grep -qxF -- "$MARK_END" "$init_file"; then
    echo "uninstall.sh: found \"$MARK_BEGIN\" but no \"$MARK_END\" in $init_file, not editing it." >&2
    exit 1
  fi
  tmp="$(mktemp "$hs_dir/.init.lua.hebfix.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0 == b { skip = 1; next }
    skip && $0 == e { skip = 0; next }
    !skip { print }
  ' "$init_file" >"$tmp"
  # Write through the file, not mv over it: keeps the file mode and a dotfiles symlink.
  cat "$tmp" >"$init_file"
  rm -f "$tmp"
  trap - EXIT
  echo "Removed config block from: $init_file"
else
  echo "No hebfix config block in: $init_file"
fi
