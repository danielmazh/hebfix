# SPEC-003 Layout switch

Owner files: `HebFix.spoon/layout.lua`, `tests/layout_spec.lua` (mock shared in `tests/mocks/hs.lua`).

- After paste, switch input source to the target language: `switch(toHebrew, names)`.
- Layout names configurable, defaults: hebrew = "Hebrew", english = "ABC".
- If the configured name is not in `hs.keycodes.layouts()`, skip silently and log one
  warning via `hs.logger` (layout name only, no text content).

## AC
Mocked tests for found and not-found layouts.
