# hebfix

You typed a whole sentence. Then you looked up. It says `akuo' nv eurv`.
You meant `שלום, מה קורה`. Your keyboard was in English the whole time.

hebfix fixes it with one key press. It works both ways, Hebrew to English and back.
macOS only.

## Install

Paste this in Terminal:

```sh
git clone https://github.com/danielmazh/hebfix.git ~/hebfix && ~/hebfix/scripts/install.sh
```

It installs [Hammerspoon](https://www.hammerspoon.org/) (with Homebrew) if you do not
have it, then installs hebfix. Running it again is safe.

Then do these 3 things once:

1. Open Hammerspoon: `open -a Hammerspoon`
2. Allow it in **System Settings > Privacy & Security > Accessibility**.
   If macOS asks for **Input Monitoring** too, allow that as well.
3. Restart it: `killall Hammerspoon; open -a Hammerspoon`

## Use

| Keys | What happens |
|---|---|
| Select text, tap **Ctrl+Shift** | The selection is converted. |
| **Ctrl+Shift+Space** | All text in the field is selected and converted. |

The keyboard also switches to the right language, so you can keep typing.
Your clipboard comes back as it was.

## Update

```sh
cd ~/hebfix && git pull && ./scripts/install.sh
```

## Uninstall

```sh
~/hebfix/scripts/uninstall.sh && rm -rf ~/hebfix
```

Hammerspoon and the rest of your `~/.hammerspoon/init.lua` stay.

## Settings (optional)

Edit `~/.hammerspoon/init.lua`. Put settings between `hs.loadSpoon("HebFix")` and
`spoon.HebFix:start()`:

```lua
spoon.HebFix.layouts = { hebrew = "Hebrew", english = "ABC" } -- names from hs.keycodes.layouts()
spoon.HebFix.copyTimeout = 0.3   -- seconds to wait for Cmd+C
spoon.HebFix.restoreDelay = 0.2  -- seconds before the clipboard is restored
spoon.HebFix.switchLayout = true -- switch the keyboard language after converting
spoon.HebFix:bindHotkeys({
  convert = { { "ctrl", "shift" } },             -- no key = tap the modifiers
  convertAll = { { "ctrl", "shift" }, "space" },
})
```

## Good to know

- Mixed text is converted in one direction, set by the first letter.
- Read-only fields: nothing happens.
- Nothing you type or copy is logged or saved.

## Development

```sh
make lint fmt-check test test-scripts package
```

Needs Lua 5.4, busted, luacheck, stylua and shellcheck.

## License

MIT. See [LICENSE](LICENSE).
