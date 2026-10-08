# SPEC-006 Install and packaging

Owner files: `scripts/install.sh`, `scripts/uninstall.sh`, `tests/scripts_test.sh`, `package` target.

- `make package` -> `dist/HebFix.spoon.zip` containing only `HebFix.spoon/`.
- `install.sh`: checks macOS, installs Hammerspoon via `brew install --cask hammerspoon` if missing,
  copies the Spoon to `~/.hammerspoon/Spoons`, appends a marked config block to
  `~/.hammerspoon/init.lua` only if not present, prints the Accessibility permission step.
  Idempotent (second run changes nothing).
- `uninstall.sh` removes the Spoon and the marked block only.

## AC
shellcheck passes; scripts tested with HOME pointed at a temp dir.
