--- Input source switch after paste.
-- Uses the global `hs`, read at call time. Logs the layout name only, never text.
local M = {}

M.DEFAULTS = { hebrew = "Hebrew", english = "ABC" }

local logger = nil
local warned = {}

local function log()
  if logger == nil then
    logger = hs.logger.new("HebFix", "warning")
  end
  return logger
end

local function hasLayout(name)
  for _, l in ipairs(hs.keycodes.layouts() or {}) do
    if l == name then
      return true
    end
  end
  return false
end

--- Switch to the Hebrew (toHebrew true) or English layout.
-- names: optional {hebrew=..., english=...}; missing keys use DEFAULTS.
-- Returns true when the layout was set, false when it is not installed.
function M.switch(toHebrew, names)
  names = names or {}
  local key = toHebrew and "hebrew" or "english"
  local name = names[key] or M.DEFAULTS[key]
  if hasLayout(name) then
    hs.keycodes.setLayout(name)
    return true
  end
  if not warned[name] then
    warned[name] = true
    log().w("layout not found: " .. tostring(name))
  end
  return false
end

--- Test helper: forget the logger and the warned names.
function M._reset()
  logger = nil
  warned = {}
end

return M
