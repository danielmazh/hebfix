# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-10-08

### Added

- Modifier tap trigger: tap Ctrl+Shift (press and release, no other key or click in
  between) to convert the selection. `:bindHotkeys()` treats an entry with no key as
  a modifier tap.
- `convertAll` action and `:convertAll()` method: sends Cmd+A, then converts the whole
  text of the focused field. Same busy guard as `convert`.

### Changed

- Default triggers: tap Ctrl+Shift runs `convert`, Ctrl+Shift+Space runs `convertAll`.
- The install config block is now `hs.loadSpoon("HebFix")` and
  `spoon.HebFix:start()`, so the Spoon defaults apply. `install.sh` updates an older
  hebfix block in place and keeps a symlinked `init.lua`.

## [1.0.0] - 2026-10-08

### Added

- Converter for text typed in the wrong layout, Hebrew to English and English to
  Hebrew, based on the macOS "Hebrew" layout. Direction comes from the first
  mappable character. Unmapped characters pass through unchanged.
- Clipboard save and restore around each conversion. Converted text is marked with
  `org.nspasteboard.TransientType` so clipboard managers skip it. Selection is
  detected by pasteboard change count, with a configurable timeout.
- Input source switch to the target language after paste, with configurable layout
  names. A missing layout is skipped with one warning.
- Hammerspoon Spoon API: `:init()`, `:start()`, `:stop()`, `:bindHotkeys()`,
  `:convert()`. Default hotkey Ctrl+Shift+Space. Config fields `layouts`,
  `copyTimeout`, `restoreDelay`, `switchLayout`.
- `scripts/install.sh` and `scripts/uninstall.sh`. The installer is idempotent and
  adds a marked block to `~/.hammerspoon/init.lua`. `make package` builds
  `dist/HebFix.spoon.zip`.
- CI on GitHub Actions: luacheck, stylua check, and busted tests on Lua 5.4.

[1.1.0]: https://github.com/danielmazh/hebfix/releases/tag/v1.1.0
[1.0.0]: https://github.com/danielmazh/hebfix/releases/tag/v1.0.0
