# SPEC-008 Modifier tap and select-all convert (v1.1.0)

Owner files: `HebFix.spoon/modtap.lua` (new), `HebFix.spoon/init.lua`, `HebFix.spoon/clipboard.lua`
(add `selectAll`), `tests/modtap_spec.lua` (new), `tests/init_spec.lua`, `tests/clipboard_spec.lua`,
`tests/mocks/hs.lua`, `scripts/install.sh`, `tests/scripts_test.sh`, `README.md`, `CHANGELOG.md`.

## Behavior
- Tap Ctrl+Shift (press both, release both, no other key or mouse click in between):
  action `convert`, the v1.0.0 flow on the current selection.
- Ctrl+Shift+Space: action `convertAll`. Send Cmd+A first, then run the same flow.
  The whole text of the focused field is converted.

## Spoon API
- `obj.version = "1.1.0"`.
- `obj.defaultHotkeys = { convert = { { "ctrl", "shift" } }, convertAll = { { "ctrl", "shift" }, "space" } }`.
- `:bindHotkeys(mapping)`: an entry with a key (`{mods, key}`) is a normal hotkey (`hs.hotkey.new`).
  An entry with no key (`{mods}`) is a modifier tap (`modtap.new`). `:start()` / `:stop()` enable
  and disable both kinds.
- New method `:convertAll()`. Same busy guard as `:convert()`.

## modtap.lua
- `modtap.new(mods, fn)` returns an object with `:start()`, `:stop()`, `:delete()`.
- Uses `hs.eventtap.new` on flagsChanged, keyDown and mouse down events. Never consumes events.
- Arms when the held modifiers are exactly `mods`. Disarms on any keyDown, any mouse down, or any
  extra modifier (cmd, alt, fn, or one not in `mods`). Releasing part of `mods` keeps it armed.
- Fires `fn` once when all modifiers are released while armed, via `hs.timer.doAfter(0, fn)`.
- No key or text content is logged.

## Install
- The config block becomes `hs.loadSpoon("HebFix")` and `spoon.HebFix:start()` (uses defaults).
- If the marked block exists but differs from the current block, install.sh replaces it in place
  (writes through the file, keeps a symlink). Same block: no change (idempotent).

## AC
- modtap tests: plain tap fires once; Ctrl+Shift+Space does not fire the tap; extra modifier or
  mouse click disarms; partial release then full release fires once; stop() stops firing.
- init tests: default mapping binds one tap and one hotkey; convertAll call order starts with
  `eventtap.keyStroke cmd+a` before `cmd+c`; busy guard covers both actions.
- scripts tests: old v1.0.0 block is replaced once; second run changes nothing.
- README documents both hotkeys, `convertAll`, and the tap rules. CHANGELOG has 1.1.0.
