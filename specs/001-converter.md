# SPEC-001 Converter

Owner files: `HebFix.spoon/converter.lua`, `tests/converter_spec.lua`.

- API: `convert(text) -> (result, toHebrew|nil)`. Module returns a table `{ convert = ..., toHebrew = <table>, toEnglish = <table> }`.
- Direction from the first mappable char: ASCII letter -> to Hebrew (toHebrew = true),
  Hebrew code point (U+05D0..U+05EA) -> to English (toHebrew = false). None -> return text, nil.
- Full mapping table for the macOS "Hebrew" layout, including punctuation keys.
  Reverse table generated from the forward table, with a test asserting no collisions.
- Case-insensitive input. Unmapped chars pass through unchanged. UTF-8 aware.
- Zero `hs.*` access.

## AC
Tests for: round-trip (`convert(convert(x)) == lowercase(x)` for mappable input), digits only,
empty string, nil, mixed text, punctuation, 1000-char input under 5 ms, reverse table has no collisions.
