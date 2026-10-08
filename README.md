# hebfix

Fix text typed in the wrong keyboard layout, Hebrew or English, with one hotkey.

hebfix is a [Hammerspoon](https://www.hammerspoon.org/) Spoon for macOS
(`HebFix.spoon`). You meant to type Hebrew, but the English layout was active,
so you typed `akuo`. Select it, press Ctrl+Shift+Space, and it becomes `שלום`.
The reverse works too: `שלום` typed by mistake becomes `akuo`.

## How it works

1. You press the hotkey.
2. hebfix saves the full clipboard.
3. It sends Cmd+C and waits for the clipboard to change (`copyTimeout`).
   No change means no selection: it restores the clipboard and stops.
4. It converts the text. The direction comes from the first Hebrew or English letter.
5. It writes the result to the clipboard, marked as transient, and sends Cmd+V.
6. It switches the input source to the target language (if `switchLayout` is on).
7. After `restoreDelay` it restores your original clipboard.

## Install

### With the script

```sh
git clone https://github.com/danielmazh/hebfix.git && cd hebfix && ./scripts/install.sh
```

The script installs Hammerspoon with Homebrew if it is missing, copies the Spoon to
`~/.hammerspoon/Spoons`, and adds a config block to `~/.hammerspoon/init.lua`.
Running it again changes nothing.

### From the release zip

1. Download `HebFix.spoon.zip` from
   [GitHub Releases](https://github.com/danielmazh/hebfix/releases).
2. Unzip it.
3. Double-click `HebFix.spoon` (Hammerspoon installs it), or copy it to
   `~/.hammerspoon/Spoons`.
4. Add the config below to `~/.hammerspoon/init.lua` and reload Hammerspoon.

### Manual config

```lua
hs.loadSpoon("HebFix")
spoon.HebFix:bindHotkeys({ convert = { { "ctrl", "shift" }, "space" } })
spoon.HebFix:start()
```

## Accessibility permission

hebfix sends Cmd+C and Cmd+V, so Hammerspoon needs Accessibility access.
Open System Settings > Privacy & Security > Accessibility and enable Hammerspoon.
Without it, nothing happens when you press the hotkey.

## Usage

1. Select the text typed in the wrong layout.
2. Press Ctrl+Shift+Space.

The text is replaced in place, and the keyboard switches to the right language.

## Config

Set fields after `hs.loadSpoon` and before `:start()`.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `layouts` | table | `{ hebrew = "Hebrew", english = "ABC" }` | Input source names to switch to after conversion. |
| `copyTimeout` | number (seconds) | `0.3` | How long to wait for Cmd+C to change the clipboard. |
| `restoreDelay` | number (seconds) | `0.2` | Wait after Cmd+V before the old clipboard is restored. |
| `switchLayout` | boolean | `true` | Switch the input source to the target language after paste. |

The hotkey is set with `:bindHotkeys(mapping)`. The only action key is `convert`.
Default: `{ { "ctrl", "shift" }, "space" }`.

Example:

```lua
hs.loadSpoon("HebFix")
spoon.HebFix.layouts = { hebrew = "Hebrew - PC", english = "U.S." }
spoon.HebFix.copyTimeout = 0.5
spoon.HebFix.restoreDelay = 0.3
spoon.HebFix.switchLayout = false
spoon.HebFix:bindHotkeys({ convert = { { "cmd", "alt" }, "h" } })
spoon.HebFix:start()
```

## Privacy

- Your clipboard is saved before each conversion and restored after it.
- Converted text is marked with `org.nspasteboard.TransientType`, so clipboard
  managers that respect it do not store it.
- No selected or clipboard text is logged or written to disk.

## Known limits

- Mixed-language text: the whole selection is converted in the direction of the
  first detected Hebrew or English letter.
- Read-only fields: Cmd+V has no effect, so the conversion fails silently.
- Layout names must match the names in `hs.keycodes.layouts()`. To check, open the
  Hammerspoon console and run `hs.keycodes.layouts()`. If a name is not found, the
  switch is skipped and one warning is logged.
- Some apps block synthetic Cmd+C. In these apps nothing is copied, so nothing
  is converted.

## Uninstall

```sh
./scripts/uninstall.sh
```

It removes `~/.hammerspoon/Spoons/HebFix.spoon` and the block in
`~/.hammerspoon/init.lua` between the lines `-- >>> hebfix >>>` and
`-- <<< hebfix <<<`. The rest of your config and Hammerspoon itself stay.

## Development

Requirements: Lua 5.4, [busted](https://lunarmodules.github.io/busted/),
[luacheck](https://github.com/lunarmodules/luacheck), and
[stylua](https://github.com/JohnnyMorganz/StyLua).

```sh
make lint        # luacheck
make fmt-check   # stylua --check
make test        # busted
make package     # builds dist/HebFix.spoon.zip
```

CI runs lint, fmt-check, and test on every push to `dev` and `main` and on pull requests.

## License

MIT. See [LICENSE](LICENSE).
