--- Modifier tap trigger: press a set of modifiers, release them, no other key in between.
-- Uses the global `hs`, read at call time. Never consumes events. Never logs keys or text.
local M = {}

local MODIFIERS = { "cmd", "alt", "shift", "ctrl", "fn" }

local Tap = {}
Tap.__index = Tap

local function toSet(mods)
  local set = {}
  for _, m in ipairs(mods or {}) do
    set[m] = true
  end
  return set
end

-- Held modifiers from event flags, as a set. Only the known modifier keys count.
local function heldSet(flags)
  local held = {}
  for _, m in ipairs(MODIFIERS) do
    if flags and flags[m] then
      held[m] = true
    end
  end
  return held
end

local function isEmpty(set)
  return next(set) == nil
end

function Tap:_onFlags(flags)
  local held = heldSet(flags)
  self._held = held
  if isEmpty(held) then
    local fire = self._armed
    self._armed = false
    self._dirty = false
    if fire then
      hs.timer.doAfter(0, self._fn)
    end
    return
  end
  for m in pairs(held) do
    if not self._mods[m] then
      -- An extra modifier: cancel until all modifiers are released.
      self._armed = false
      self._dirty = true
      return
    end
  end
  local exact = true
  for m in pairs(self._mods) do
    if not held[m] then
      exact = false
      break
    end
  end
  if exact and not self._dirty then
    self._armed = true
  end
  -- A partial release keeps the current state.
end

function Tap:_handle(event)
  local types = hs.eventtap.event.types
  if event:getType() == types.flagsChanged then
    self:_onFlags(event:getFlags())
  else
    -- A key or a mouse click: not a tap.
    self:cancel()
  end
  return false
end

--- Start watching events. Returns self.
function Tap:start()
  if self._tap == nil then
    local types = hs.eventtap.event.types
    self._tap = hs.eventtap.new({
      types.flagsChanged,
      types.keyDown,
      types.leftMouseDown,
      types.rightMouseDown,
      types.otherMouseDown,
    }, function(event)
      return self:_handle(event)
    end)
  end
  self._armed = false
  self._dirty = false
  self._held = {}
  self._tap:start()
  return self
end

--- Stop watching events. Returns self.
function Tap:stop()
  if self._tap ~= nil then
    self._tap:stop()
  end
  self._armed = false
  return self
end

--- Cancel a pending tap until all modifiers are released. Returns self.
function Tap:cancel()
  self._armed = false
  if not isEmpty(self._held) then
    self._dirty = true
  end
  return self
end

--- Stop and drop the event tap.
function Tap:delete()
  self:stop()
  self._tap = nil
end

--- Create a tap trigger for mods (a list like {"ctrl", "shift"}). fn runs once per tap.
-- The trigger is created stopped; call :start().
function M.new(mods, fn)
  assert(type(fn) == "function", "modtap.new: fn must be a function")
  assert(type(mods) == "table" and #mods > 0, "modtap.new: mods must be a non-empty list")
  return setmetatable({
    _mods = toSet(mods),
    _fn = fn,
    _tap = nil,
    _armed = false,
    _dirty = false,
    _held = {},
  }, Tap)
end

return M
