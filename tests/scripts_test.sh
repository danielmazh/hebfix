#!/usr/bin/env bash
# Tests for scripts/install.sh, scripts/uninstall.sh and `make package`.
# HOME points at a temp dir: the real ~/.hammerspoon is never touched.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
install="$repo/scripts/install.sh"
uninstall="$repo/scripts/uninstall.sh"

export HEBFIX_SKIP_OS_CHECK=1
export HEBFIX_SKIP_HAMMERSPOON=1

fails=0
work="$(mktemp -d "${TMPDIR:-/tmp}/hebfix-scripts-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

pass() { echo "PASS: $1"; }
fail() {
  echo "FAIL: $1"
  fails=$((fails + 1))
}
check() {
  local name="$1"
  shift
  if "$@"; then pass "$name"; else fail "$name"; fi
}

if command -v sha256sum >/dev/null 2>&1; then
  hash_cmd=(sha256sum)
else
  hash_cmd=(shasum -a 256)
fi

# Checksum of a whole tree: every path plus the content of every file.
tree_sum() {
  (
    cd "$1"
    find . -print | LC_ALL=C sort
    find . -type f -print0 | LC_ALL=C sort -z | xargs -0 "${hash_cmd[@]}"
  ) | "${hash_cmd[@]}"
}

new_home() {
  local h
  h="$(mktemp -d "$work/home.XXXXXX")"
  echo "$h"
}

run_install() { HOME="$1" bash "$install" >/dev/null; }
run_uninstall() { HOME="$1" bash "$uninstall" >/dev/null; }

block_count() { grep -cxF -- "-- >>> hebfix >>>" "$1/.hammerspoon/init.lua" || true; }

spoon_matches_source() {
  diff -r -x .DS_Store "$repo/HebFix.spoon" "$1/.hammerspoon/Spoons/HebFix.spoon" >/dev/null
}

has_block() {
  local f="$1/.hammerspoon/init.lua"
  grep -qxF -- "-- >>> hebfix >>>" "$f" &&
    grep -qxF -- 'hs.loadSpoon("HebFix")' "$f" &&
    grep -qxF -- 'spoon.HebFix:bindHotkeys({ convert = { { "ctrl", "shift" }, "space" } })' "$f" &&
    grep -qxF -- 'spoon.HebFix:start()' "$f" &&
    grep -qxF -- "-- <<< hebfix <<<" "$f"
}

# 1. Fresh install creates the Spoon and the block.
h="$(new_home)"
run_install "$h"
check "fresh install copies the Spoon" spoon_matches_source "$h"
check "fresh install creates init.lua with the block" has_block "$h"
check "fresh install adds the block once" test "$(block_count "$h")" = 1

# 2. Second install changes nothing.
before="$(tree_sum "$h")"
run_install "$h"
after="$(tree_sum "$h")"
check "second install changes nothing" test "$before" = "$after"
check "block appears exactly once after two installs" test "$(block_count "$h")" = 1

# 3. Install refreshes a changed Spoon copy.
echo "-- stale" >"$h/.hammerspoon/Spoons/HebFix.spoon/stale.lua"
run_install "$h"
check "install replaces a changed Spoon copy" spoon_matches_source "$h"

# 4. .DS_Store is not copied.
h_ds="$(new_home)"
src_ds="$work/srcrepo"
mkdir -p "$src_ds/scripts"
cp "$install" "$src_ds/scripts/install.sh"
cp -R "$repo/HebFix.spoon" "$src_ds/HebFix.spoon"
touch "$src_ds/HebFix.spoon/.DS_Store"
HOME="$h_ds" bash "$src_ds/scripts/install.sh" >/dev/null
check "install skips .DS_Store" test ! -e "$h_ds/.hammerspoon/Spoons/HebFix.spoon/.DS_Store"

# 5. Existing user init.lua content is kept, then restored by uninstall.
h="$(new_home)"
mkdir -p "$h/.hammerspoon"
user_cfg="$work/user_init.lua"
printf '%s\n' '-- my config' 'hs.alert.show("hi")' '' 'local x = 1 -- keep me' >"$user_cfg"
cp "$user_cfg" "$h/.hammerspoon/init.lua"
run_install "$h"
check "install keeps user init.lua lines at the top" \
  test "$(head -n 4 "$h/.hammerspoon/init.lua")" = "$(cat "$user_cfg")"
check "install adds the block after user lines" has_block "$h"
run_install "$h"
check "block appears exactly once with user config" test "$(block_count "$h")" = 1
run_uninstall "$h"
check "uninstall removes the Spoon" test ! -e "$h/.hammerspoon/Spoons/HebFix.spoon"
check "uninstall keeps user lines byte-for-byte" cmp -s "$user_cfg" "$h/.hammerspoon/init.lua"

# 6. Uninstall twice is fine.
before="$(tree_sum "$h")"
if HOME="$h" bash "$uninstall" >/dev/null; then
  pass "second uninstall exits 0"
else
  fail "second uninstall exits 0"
fi
after="$(tree_sum "$h")"
check "second uninstall changes nothing" test "$before" = "$after"

h="$(new_home)"
if HOME="$h" bash "$uninstall" >/dev/null; then
  pass "uninstall with nothing installed exits 0"
else
  fail "uninstall with nothing installed exits 0"
fi

# 7. Block in the middle of user lines: only the block goes.
h="$(new_home)"
mkdir -p "$h/.hammerspoon"
printf '%s\n' 'before = 1' >"$h/.hammerspoon/init.lua"
run_install "$h"
printf '%s\n' 'after = 2' >>"$h/.hammerspoon/init.lua"
run_uninstall "$h"
check "uninstall keeps lines before and after the block" \
  test "$(cat "$h/.hammerspoon/init.lua")" = "$(printf '%s\n%s' 'before = 1' 'after = 2')"

# 8. init.lua without a trailing newline.
h="$(new_home)"
mkdir -p "$h/.hammerspoon"
printf '%s' 'hs.alert.show("no newline")' >"$h/.hammerspoon/init.lua"
run_install "$h"
check "no-newline: user line stays on its own line" \
  test "$(head -n 1 "$h/.hammerspoon/init.lua")" = 'hs.alert.show("no newline")'
check "no-newline: marker starts its own line" \
  test "$(sed -n 2p "$h/.hammerspoon/init.lua")" = "-- >>> hebfix >>>"
check "no-newline: block present" has_block "$h"
run_uninstall "$h"
check "no-newline: uninstall leaves only the user line" \
  test "$(cat "$h/.hammerspoon/init.lua")" = 'hs.alert.show("no newline")'

# 9. make package.
pkg_out="$work/package.log"
if (cd "$repo" && make package >"$pkg_out" 2>&1); then
  pass "make package exits 0"
else
  fail "make package exits 0"
  cat "$pkg_out"
fi
zip_file="$repo/dist/HebFix.spoon.zip"
check "dist/HebFix.spoon.zip exists" test -f "$zip_file"
if [ -f "$zip_file" ]; then
  entries="$(unzip -Z1 "$zip_file")"
  outside="$(printf '%s\n' "$entries" | grep -v '^HebFix\.spoon/' || true)"
  check "zip lists only paths under HebFix.spoon/" test -z "$outside"
  check "zip has no .DS_Store" test -z "$(printf '%s\n' "$entries" | grep '\.DS_Store' || true)"
  for f in "$repo"/HebFix.spoon/*.lua; do
    [ -e "$f" ] || continue
    name="HebFix.spoon/$(basename "$f")"
    check "zip includes $name" grep -qxF -- "$name" <<<"$entries"
  done
  if [ -f "$repo/HebFix.spoon/init.lua" ]; then
    check "zip includes HebFix.spoon/init.lua" grep -qxF -- "HebFix.spoon/init.lua" <<<"$entries"
  else
    echo "SKIP: HebFix.spoon/init.lua not in source yet"
  fi
fi

echo
if [ "$fails" -ne 0 ]; then
  echo "scripts_test: $fails failure(s)"
  exit 1
fi
echo "scripts_test: all passed"
