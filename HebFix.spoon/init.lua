--- === HebFix ===
---
--- Convert selected text typed in the wrong keyboard layout (Hebrew <-> English).
--- Select the text and press the hotkey (default ctrl+shift+space).
---
--- Privacy: clipboard and selected text are never logged or written to disk.

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "HebFix"
obj.version = "1.0.0"
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
--- Hotkey used by :start() when :bindHotkeys() was not called.
obj.defaultHotkeys = { convert = { { "ctrl", "shift" }, "space" } }

--- HebFix:init()
--- Method
--- Load the sibling modules and create the logger.
function obj:init()
  self.converter = dofile(hs.spoons.resourcePath("converter.lua"))
  self.clipboard = dofile(hs.spoons.resourcePath("clipboard.lua"))
  self.layout = dofile(hs.spoons.resourcePath("layout.lua"))
  self.logger = hs.logger.new("HebFix")
  self._hotkeys = nil
  self._running = false
  self._busy = false
  return self
end

local function deleteHotkeys(self)
  for _, hk in pairs(self._hotkeys or {}) do
    hk:delete()
  end
  self._hotkeys = nil
end

--- HebFix:bindHotkeys(mapping)
--- Method
--- Bind hotkeys. mapping uses the hs.spoons.bindHotkeysToSpec format:
--- { convert = {{"ctrl","shift"}, "space"} }.
--- Hotkeys are created disabled and enabled by :start(), so :stop() can turn them off.
function obj:bindHotkeys(mapping)
  local actions = {
    convert = function()
      self:convert()
    end,
  }
  deleteHotkeys(self)
  local hotkeys = {}
  for name, spec in pairs(mapping or {}) do
    local fn = actions[name]
    if fn == nil then
      self.logger.e("unknown hotkey action: " .. tostring(name))
    else
      hotkeys[name] = hs.hotkey.new(spec[1], spec[2], fn)
      if self._running then
        hotkeys[name]:enable()
      end
    end
  end
  self._hotkeys = hotkeys
  return self
end

--- HebFix:start()
--- Method
--- Enable the hotkeys. Binds defaultHotkeys first if no hotkey was bound.
function obj:start()
  if self._hotkeys == nil then
    self:bindHotkeys(self.defaultHotkeys)
  end
  self._running = true
  for _, hk in pairs(self._hotkeys) do
    hk:enable()
  end
  return self
end

--- HebFix:stop()
--- Method
--- Disable the hotkeys. :start() enables them again.
function obj:stop()
  self._running = false
  for _, hk in pairs(self._hotkeys or {}) do
    hk:disable()
  end
  return self
end

--- HebFix:convert()
--- Method
--- Copy the selection, convert it, paste the result, switch the layout and restore
--- the original pasteboard. Ignored while a conversion is running.
function obj:convert()
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

return obj
