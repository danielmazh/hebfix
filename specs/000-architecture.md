# SPEC-000 Architecture

## Flow
1. Hotkey pressed.
2. Save the full pasteboard (`hs.pasteboard.readAllData`).
3. Send Cmd+C.
4. Wait with `hs.pasteboard.callbackWhenChanged` (timeout `copyTimeout`, default 0.3 s).
   No change means no selection: restore and stop.
5. `converter.convert(text)`.
6. Write the result in one `writeAllData` call: text plus an `org.nspasteboard.TransientType` entry.
7. Send Cmd+V.
8. Switch the input source to the target language (if `switchLayout`).
9. After `restoreDelay` (default 0.2 s) restore the saved pasteboard (`writeAllData`).

## Module boundaries
| Module | Role | hs.* use |
|---|---|---|
| `converter.lua` | pure text mapping | none |
| `clipboard.lua` | save, restore, copy, transient write, paste | `hs.pasteboard`, `hs.eventtap` |
| `layout.lua` | input source switch | `hs.keycodes`, `hs.logger` |
| `init.lua` | Spoon object, hotkey, orchestration | `hs.hotkey`, `hs.spoons`, `hs.timer`, `hs.logger` |

## Privacy
No clipboard or selected text is logged or written to disk.

## AC
- This document exists and the module boundaries above match the code.
