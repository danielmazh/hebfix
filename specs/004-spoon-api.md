# SPEC-004 Spoon API

Owner files: `HebFix.spoon/init.lua`, `tests/init_spec.lua`.

- Standard Spoon metadata: name, version ("1.0.0"), author, license ("MIT"), homepage.
- Methods: `:init()`, `:start()`, `:stop()`, `:bindHotkeys(mapping)`, plus `:convert()` for the flow.
- Default hotkey: `{{"ctrl","shift"}, "space"}`, action key `convert`.
- Config fields: `layouts` (`{hebrew="Hebrew", english="ABC"}`), `copyTimeout` (0.3),
  `restoreDelay` (0.2), `switchLayout` (true).
- Load sibling modules via `hs.spoons.resourcePath`.
- Flow per SPEC-000.

## AC
`init_spec` runs the full flow against mocks and asserts call order.
