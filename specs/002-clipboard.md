# SPEC-002 Clipboard

Owner files: `HebFix.spoon/clipboard.lua`, `tests/clipboard_spec.lua`, `tests/mocks/hs.lua`.

- `save()`: `hs.pasteboard.readAllData()`. `restore(saved)`: `hs.pasteboard.writeAllData(saved)`.
- `copySelection(cb, timeout)`: send Cmd+C, then `hs.pasteboard.callbackWhenChanged(timeout, fn)`;
  `cb(false)` when nothing is selected (no change in time), `cb(true, text)` otherwise.
  Never compare content to detect selection (change count only).
- `writeTransient(text)`: write converted text with an extra `org.nspasteboard.TransientType`
  entry so clipboard managers skip it.
- `paste()`: send Cmd+V.
- No clipboard content is ever logged or written to disk.

## AC
Mocked tests for: no selection, selection equal to previous clipboard, restore of non-text data.
