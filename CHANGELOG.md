# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/danielmazh/hebfix/releases/tag/v1.0.0
