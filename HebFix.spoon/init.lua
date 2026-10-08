--- === HebFix ===
---
--- Convert text typed in the wrong keyboard layout (Hebrew <-> English).
--- Default triggers: tap Ctrl+Shift (press and release, no other key) to convert the
--- selection; press Ctrl+Shift+Space to select all text in the field and convert it.
---
--- Privacy: clipboard and selected text are never logged or written to disk.

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "HebFix"
obj.version = "1.1.0"
obj.author = "Daniel Mazhbits"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.homepage = "https://github.com/danielmazh/hebfix"

--- HebFix.layouts
--- Variable
--- Input source names to switch to after a conversion.
obj.layouts = { hebrew = "Hebrew", english = "ABC" }

--- HebFix.copyTimeout
--- Variable
--- Seconds to wait for Cmd+C to change the pasteboard. No change means no selection.
obj.copyTimeout = 0.3

--- HebFix.restoreDelay
--- Variable
--- Seconds to wait after Cmd+V before the original pasteboard is restored.
obj.restoreDelay = 0.2

--- HebFix.switchLayout
--- Variable
--- If true, switch the input source to the target language after a conversion.
obj.switchLayout = true

--- HebFix.defaultHotkeys
--- Variable
--- Triggers used by :start() when :bindHotkeys() was not called.
--- An entry with a key is a hotkey. An entry with no key is a modifier tap.
obj.defaultHotkeys = {
  convert = { { "ctrl", "shift" } },
  convertAll = { { "ctrl", "shift" }, "space" },
}

--- HebFix:init()
--- Method
--- Load the sibling modules and create the logger.
function obj:init()
  self.converter = dofile(hs.spoons.resourcePath("converter.lua"))
  self.clipboard = dofile(hs.spoons.resourcePath("clipboard.lua"))
  self.layout = dofile(hs.spoons.resourcePath("layout.lua"))
  self.modtap = dofile(hs.spoons.resourcePath("modtap.lua"))
  self.logger = hs.logger.new("HebFix")
  self._hotkeys = nil
  self._taps = nil
  self._running = false
  self._busy = false
  return self
end

local function deleteTriggers(self)
  for _, hk in pairs(self._hotkeys or {}) do
    hk:delete()
  end
  for _, tap in pairs(self._taps or {}) do
    tap:delete()
  end
  self._hotkeys = nil
  self._taps = nil
end

--- HebFix:bindHotkeys(mapping)
--- Method
--- Bind triggers. mapping uses the hs.spoons.bindHotkeysToSpec format, and an entry may
--- leave out the key: { convert = {{"ctrl","shift"}}, convertAll = {{"ctrl","shift"}, "space"} }.
--- An entry with a key is a hotkey. An entry with no key is a modifier tap: press the
--- modifiers and release them with no other key or click in between.
--- Actions: convert (the selection) and convertAll (select all, then convert).
--- Triggers are created disabled and enabled by :start(), so :stop() can turn them off.
function obj:bindHotkeys(mapping)
  local actions = {
    convert = function()
      self:convert()
    end,
    convertAll = function()
      self:convertAll()
    end,
  }
  deleteTriggers(self)
  local hotkeys, taps = {}, {}
  -- A hotkey press cancels any pending modifier tap, in case the tap did not see the key.
  local function cancelTaps()
    for _, tap in pairs(taps) do
      tap:cancel()
    end
  end
  for name, spec in pairs(mapping or {}) do
    local fn = actions[name]
    if fn == nil then
      self.logger.e("unknown hotkey action: " .. tostring(name))
    elseif spec[2] == nil then
      taps[name] = self.modtap.new(spec[1], fn)
      if self._running then
        taps[name]:start()
      end
    else
      hotkeys[name] = hs.hotkey.new(spec[1], spec[2], function()
        cancelTaps()
        fn()
      end)
      if self._running then
        hotkeys[name]:enable()
      end
    end
  end
  self._hotkeys = hotkeys
  self._taps = taps
  return self
end

--- HebFix:start()
--- Method
--- Enable the hotkeys and modifier taps. Binds defaultHotkeys first if nothing was bound.
function obj:start()
  if self._hotkeys == nil and self._taps == nil then
    self:bindHotkeys(self.defaultHotkeys)
  end
  self._running = true
  for _, hk in pairs(self._hotkeys) do
    hk:enable()
  end
  for _, tap in pairs(self._taps) do
    tap:start()
  end
  return self
end

--- HebFix:stop()
--- Method
--- Disable the hotkeys and modifier taps. :start() enables them again.
function obj:stop()
  self._running = false
  for _, hk in pairs(self._hotkeys or {}) do
    hk:disable()
  end
  for _, tap in pairs(self._taps or {}) do
    tap:stop()
  end
  return self
end

-- Shared flow: optional select all, copy, convert, paste, switch layout, restore.
-- Ignored while a conversion is running.
local function run(self, selectAll)
  if self._busy then
    return self
  end
  self._busy = true
  local clipboard = self.clipboard
  local saved

  local function finish()
    clipboard.restore(saved)
    self._busy = false
  end

  local function fail(err)
    -- Error text comes from code, never from clipboard content.
    self.logger.e("convert failed: " .. tostring(err))
    pcall(clipboard.restore, saved)
    self._busy = false
  end

  local function onCopy(ok, text)
    if not ok then
      finish()
      return
    end
    local result, toHebrew = self.converter.convert(text)
    if toHebrew == nil then
      finish()
      return
    end
    clipboard.writeTransient(result)
    clipboard.paste()
    if self.switchLayout then
      self.layout.switch(toHebrew, self.layouts)
    end
    hs.timer.doAfter(self.restoreDelay, function()
      local done, err = pcall(finish)
      if not done then
        fail(err)
      end
    end)
  end

  local started, err = pcall(function()
    if selectAll then
      clipboard.selectAll()
    end
    saved = clipboard.save()
    clipboard.copySelection(function(ok, text)
      local done, cbErr = pcall(onCopy, ok, text)
      if not done then
        fail(cbErr)
      end
    end, self.copyTimeout)
  end)
  if not started then
    fail(err)
  end
  return self
end

--- HebFix:convert()
--- Method
--- Copy the selection, convert it, paste the result, switch the layout and restore
--- the original pasteboard. Ignored while a conversion is running.
function obj:convert()
  return run(self, false)
end

--- HebFix:convertAll()
--- Method
--- Select all text in the focused field (Cmd+A), then run the same flow as :convert().
--- Ignored while a conversion is running.
function obj:convertAll()
  return run(self, true)
end

return obj
