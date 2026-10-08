--[[ Mock of the Hammerspoon `hs` API for busted tests.

Usage:
  local hsmock = require("mocks.hs")
  local hs = hsmock.install() -- sets _G.hs to a fresh mock and returns it
  hsmock.uninstall()          -- sets _G.hs to nil

Recorded calls (in order, as strings) in hs._calls:
  "pasteboard.readAllData", "pasteboard.writeAllData", "pasteboard.readString",
  "pasteboard.setContents", "pasteboard.getContents", "pasteboard.callbackWhenChanged",
  "eventtap.keyStroke cmd+c", "keycodes.setLayout Hebrew", "timer.doAfter 0.2",
  "timer.stop", "hotkey.bind ctrl+alt+h", "hotkey.new ctrl+alt+h", "hotkey.enable",
  "hotkey.disable", "hotkey.delete"
  hs._called(s) -> true if s is in hs._calls; hs._count(s) -> number of times.

Pasteboard state:
  hs._pb.contents   table UTI -> data ("public.utf8-plain-text" is text)
  hs._pb.changeCount
  readAllData() returns a copy of contents; writeAllData([name,] t) replaces contents with a
  copy of t; setContents(text) sets text only. Writes bump changeCount.
  hs._nextCopy = "text" makes the next Cmd+C copy that text (bumps changeCount even when the
  text equals the old content); nil means no selection. The copy is applied when
  callbackWhenChanged runs, which then calls its callback synchronously with
  changed = (changeCount moved). Signature: callbackWhenChanged([name,] [timeout,] fn).

Timers:
  hs.timer.doAfter(delay, fn) queues fn and returns {stop=, running=}.
  hs._runTimers() runs queued timers (FIFO, including ones queued while running).
  hs._autoRunTimers = true runs fn at once inside doAfter.

Keycodes: layouts() returns hs._layouts (default {"ABC","Hebrew"}); currentLayout() returns
  hs._currentLayout; setLayout(name) sets it and returns true.
Logger: hs.logger.new(id, level) -> logger with e, w, i, d, v, f, ef, wf, df, vf, setLogLevel.
  Each message is appended to hs._logs as {id=, level=, msg=}.
Hotkey: bind(mods, key, [msg,] pressedfn, releasedfn, repeatfn) and new(...) return objects
  with enable, disable, delete and a test helper _press(). All are listed in hs._hotkeys.
  bind() returns an enabled hotkey; new() a disabled one.
Spoons: hs.spoons.resourcePath(file) -> "HebFix.spoon/" .. file.
Eventtap: hs.eventtap.event.types has flagsChanged, keyDown, keyUp, leftMouseDown,
  rightMouseDown, otherMouseDown (numbers). hs.eventtap.new(types, fn) records "eventtap.new"
  and returns a stopped tap with start ("eventtap.start"), stop ("eventtap.stop") and
  isEnabled. All taps are listed in hs._taps.
  hs._emit(typeName, flags) builds an event (getType, getFlags) and calls fn of every started
  tap that watches that type. flags is a table like {ctrl=true, shift=true} (default {}).
  Returns a list of the consume values the taps returned.
]]

local M = {}

local function copy(t)
  local r = {}
  for k, v in pairs(t or {}) do
    r[k] = v
  end
  return r
end

local function combo(mods, key)
  local parts = {}
  for _, m in ipairs(mods or {}) do
    parts[#parts + 1] = m
  end
  parts[#parts + 1] = tostring(key)
  return table.concat(parts, "+")
end

function M.new()
  local hs = { _calls = {}, _logs = {}, _timers = {}, _hotkeys = {}, _taps = {} }
  hs._pb = { contents = {}, changeCount = 0 }
  hs._layouts = { "ABC", "Hebrew" }
  hs._currentLayout = "ABC"
  hs._autoRunTimers = false
  hs._nextCopy = nil
  local pendingCopy = false

  local function rec(s)
    hs._calls[#hs._calls + 1] = s
  end
  function hs._called(s)
    return hs._count(s) > 0
  end
  function hs._count(s)
    local n = 0
    for _, c in ipairs(hs._calls) do
      if c == s then
        n = n + 1
      end
    end
    return n
  end

  local pb = hs._pb
  hs.pasteboard = {}
  function hs.pasteboard.readAllData()
    rec("pasteboard.readAllData")
    return copy(pb.contents)
  end
  function hs.pasteboard.writeAllData(a, b)
    rec("pasteboard.writeAllData")
    local t = (type(a) == "table") and a or b
    pb.contents = copy(t)
    pb.changeCount = pb.changeCount + 1
    return true
  end
  function hs.pasteboard.readString()
    rec("pasteboard.readString")
    return pb.contents["public.utf8-plain-text"]
  end
  function hs.pasteboard.getContents()
    rec("pasteboard.getContents")
    return pb.contents["public.utf8-plain-text"]
  end
  function hs.pasteboard.setContents(text)
    rec("pasteboard.setContents")
    pb.contents = { ["public.utf8-plain-text"] = text }
    pb.changeCount = pb.changeCount + 1
    return true
  end
  function hs.pasteboard.changeCount()
    return pb.changeCount
  end
  function hs.pasteboard.callbackWhenChanged(...)
    rec("pasteboard.callbackWhenChanged")
    local fn
    for _, v in ipairs({ ... }) do
      if type(v) == "function" then
        fn = v
        break
      end
    end
    local before = pb.changeCount
    if pendingCopy then
      pendingCopy = false
      if hs._nextCopy ~= nil then
        pb.contents = { ["public.utf8-plain-text"] = hs._nextCopy }
        pb.changeCount = pb.changeCount + 1
      end
    end
    fn(pb.changeCount ~= before)
  end

  hs.eventtap = {}
  function hs.eventtap.keyStroke(mods, key, _delay)
    rec("eventtap.keyStroke " .. combo(mods, key))
    if key == "c" then
      pendingCopy = true
    end
  end

  hs.eventtap.event = {
    types = {
      leftMouseDown = 1,
      rightMouseDown = 3,
      keyDown = 10,
      keyUp = 11,
      flagsChanged = 12,
      otherMouseDown = 25,
    },
  }
  function hs.eventtap.new(types, fn)
    rec("eventtap.new")
    local tap = { types = copy(types), fn = fn, enabled = false }
    function tap:start()
      rec("eventtap.start")
      self.enabled = true
      return self
    end
    function tap:stop()
      rec("eventtap.stop")
      self.enabled = false
      return self
    end
    function tap:isEnabled()
      return self.enabled
    end
    hs._taps[#hs._taps + 1] = tap
    return tap
  end
  function hs._emit(typeName, flags)
    local t = hs.eventtap.event.types[typeName]
    assert(t ~= nil, "unknown event type: " .. tostring(typeName))
    local f = copy(flags)
    local event = {}
    function event.getType(_)
      return t
    end
    function event.getFlags(_)
      return copy(f)
    end
    local results = {}
    for _, tap in ipairs(hs._taps) do
      if tap.enabled then
        for _, wanted in ipairs(tap.types) do
          if wanted == t then
            results[#results + 1] = tap.fn(event)
            break
          end
        end
      end
    end
    return results
  end

  hs.timer = {}
  function hs.timer.doAfter(delay, fn)
    rec("timer.doAfter " .. tostring(delay))
    local t = { fn = fn, active = true }
    function t.stop()
      rec("timer.stop")
      t.active = false
      return t
    end
    function t.running()
      return t.active
    end
    if hs._autoRunTimers then
      t.active = false
      fn()
    else
      hs._timers[#hs._timers + 1] = t
    end
    return t
  end
  function hs._runTimers()
    while #hs._timers > 0 do
      local t = table.remove(hs._timers, 1)
      if t.active then
        t.active = false
        t.fn()
      end
    end
  end

  hs.keycodes = {}
  function hs.keycodes.layouts()
    return copy(hs._layouts)
  end
  function hs.keycodes.currentLayout()
    return hs._currentLayout
  end
  function hs.keycodes.setLayout(name)
    rec("keycodes.setLayout " .. tostring(name))
    hs._currentLayout = name
    return true
  end

  hs.logger = {}
  function hs.logger.new(id, _level)
    local lg = {}
    local function add(level, msg)
      hs._logs[#hs._logs + 1] = { id = id, level = level, msg = msg }
    end
    for _, lv in ipairs({ "e", "w", "i", "d", "v" }) do
      lg[lv] = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
          parts[#parts + 1] = tostring((select(i, ...)))
        end
        add(lv, table.concat(parts, " "))
      end
      lg[lv .. "f"] = function(fmt, ...)
        add(lv, string.format(fmt, ...))
      end
    end
    lg.f = lg["if"]
    lg.setLogLevel = function() end
    return lg
  end

  hs.hotkey = {}
  local function makeHotkey(kind, mods, key, a, b, c, d)
    rec("hotkey." .. kind .. " " .. combo(mods, key))
    if type(a) ~= "function" and a ~= nil then
      a, b, c = b, c, d -- skip the message argument
    end
    local hk = { mods = mods, key = key, pressedfn = a, releasedfn = b, repeatfn = c }
    hk.enabled = false
    function hk:enable()
      rec("hotkey.enable")
      self.enabled = true
      return self
    end
    function hk:disable()
      rec("hotkey.disable")
      self.enabled = false
      return self
    end
    function hk:delete()
      rec("hotkey.delete")
      self.enabled = false
      self.deleted = true
    end
    function hk:_press()
      if self.pressedfn then
        self.pressedfn()
      end
    end
    hs._hotkeys[#hs._hotkeys + 1] = hk
    return hk
  end
  function hs.hotkey.bind(...)
    local hk = makeHotkey("bind", ...)
    hk.enabled = true
    return hk
  end
  function hs.hotkey.new(...)
    return makeHotkey("new", ...)
  end

  hs.spoons = {}
  function hs.spoons.resourcePath(file)
    return "HebFix.spoon/" .. file
  end

  return hs
end

function M.install()
  _G.hs = M.new() -- luacheck: ignore 122
  return _G.hs
end

function M.uninstall()
  _G.hs = nil -- luacheck: ignore 122
end

return M
