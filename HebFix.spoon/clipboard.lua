--- Clipboard helpers: save, restore, copy, paste.
-- Uses the global `hs`, read at call time. Never logs or stores clipboard content.
local M = {}

local TEXT_UTI = "public.utf8-plain-text"
local TRANSIENT_UTI = "org.nspasteboard.TransientType"

--- Save the full pasteboard (all items, all types).
function M.save()
  return hs.pasteboard.readAllData()
end

--- Restore a table returned by save(). A nil table is ignored.
function M.restore(saved)
  if saved == nil then
    return false
  end
  return hs.pasteboard.writeAllData(saved)
end

--- Send Cmd+C and wait for a pasteboard change.
-- Selection is detected by change count only, never by comparing content.
-- cb(true, text) when the pasteboard changed in time, cb(false) otherwise.
function M.copySelection(cb, timeout)
  hs.eventtap.keyStroke({ "cmd" }, "c", 0)
  hs.pasteboard.callbackWhenChanged(timeout, function(changed)
    if changed then
      cb(true, hs.pasteboard.readString())
    else
      cb(false)
    end
  end)
end

--- Write text with a transient marker so clipboard managers skip it.
function M.writeTransient(text)
  return hs.pasteboard.writeAllData({ [TEXT_UTI] = text, [TRANSIENT_UTI] = "" })
end

--- Send Cmd+V.
function M.paste()
  hs.eventtap.keyStroke({ "cmd" }, "v", 0)
end

return M
