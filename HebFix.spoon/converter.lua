--- Pure text mapping between English (US) keys and the macOS "Hebrew" layout.
-- No hs.* use. See specs/001-converter.md.
local M = {}

-- Forward table: US key char (lowercase) -> character the macOS "Hebrew" layout types.
-- Square brackets are mirrored on macOS Hebrew, so "[" types "]" and "]" types "[".
-- Keys not listed here type the same character on both layouts and pass through.
M.toHebrew = {
  q = "/",
  w = "'",
  e = "ק",
  r = "ר",
  t = "א",
  y = "ט",
  u = "ו",
  i = "ן",
  o = "ם",
  p = "פ",
  a = "ש",
  s = "ד",
  d = "ג",
  f = "כ",
  g = "ע",
  h = "י",
  j = "ח",
  k = "ל",
  l = "ך",
  [";"] = "ף",
  ["'"] = ",",
  z = "ז",
  x = "ס",
  c = "ב",
  v = "ה",
  b = "נ",
  n = "מ",
  m = "צ",
  [","] = "ת",
  ["."] = "ץ",
  ["/"] = ".",
  ["["] = "]",
  ["]"] = "[",
}

-- Reverse table: built from the forward table. Errors at load time on a collision.
M.toEnglish = {}
for key, out in pairs(M.toHebrew) do
  if M.toEnglish[out] ~= nil then
    error("converter: reverse table collision on " .. out)
  end
  M.toEnglish[out] = key
end

-- Code point tables for fast lookup: code point -> output string.
local fwd, rev = {}, {}
for key, out in pairs(M.toHebrew) do
  fwd[utf8.codepoint(key)] = out
end
for key, out in pairs(M.toEnglish) do
  rev[utf8.codepoint(key)] = out
end

local HEB_FIRST, HEB_LAST = 0x05D0, 0x05EA

--- Convert text typed in the wrong layout.
-- @param text string or nil
-- @return converted text (or the input unchanged), and true (to Hebrew), false (to English)
--   or nil (no direction found, nil input, or invalid UTF-8)
function M.convert(text)
  if text == nil then
    return nil, nil
  end
  if text == "" or utf8.len(text) == nil then
    return text, nil
  end

  local toHeb
  for _, c in utf8.codes(text) do
    if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) then
      toHeb = true
      break
    elseif c >= HEB_FIRST and c <= HEB_LAST then
      toHeb = false
      break
    end
  end
  if toHeb == nil then
    return text, nil
  end

  local map = toHeb and fwd or rev
  local out, n = {}, 0
  for _, c in utf8.codes(text) do
    if toHeb and c >= 65 and c <= 90 then
      c = c + 32
    end
    n = n + 1
    out[n] = map[c] or utf8.char(c)
  end
  return table.concat(out), toHeb
end

return M
