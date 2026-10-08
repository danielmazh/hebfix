local hsmock = require("mocks.hs")

local TEXT = "public.utf8-plain-text"
local TRANSIENT = "org.nspasteboard.TransientType"

describe("HebFix spoon", function()
  local hs, spoon, writes

  before_each(function()
    hs = hsmock.install()
    spoon = dofile("HebFix.spoon/init.lua")
    spoon:init()
    hs._pb.contents = { [TEXT] = "original", ["public.png"] = "\0png" }
    writes = {}
    local orig = hs.pasteboard.writeAllData
    hs.pasteboard.writeAllData = function(a, b)
      local t = (type(a) == "table") and a or b
      local c = {}
      for k, v in pairs(t) do
        c[k] = v
      end
      writes[#writes + 1] = c
      return orig(a, b)
    end
  end)

  after_each(function()
    hsmock.uninstall()
  end)

  local function count(prefix)
    local n = 0
    for _, c in ipairs(hs._calls) do
      if c:sub(1, #prefix) == prefix then
        n = n + 1
      end
    end
    return n
  end

  describe("metadata and defaults", function()
    it("has the Spoon metadata", function()
      assert.equal("HebFix", spoon.name)
      assert.equal("1.1.0", spoon.version)
      assert.equal("Daniel Mazhbits", spoon.author)
      assert.equal("MIT - https://opensource.org/licenses/MIT", spoon.license)
      assert.equal("https://github.com/danielmazh/hebfix", spoon.homepage)
      assert.equal(spoon, spoon.__index)
    end)

    it("has the default config", function()
      assert.same({ hebrew = "Hebrew", english = "ABC" }, spoon.layouts)
      assert.equal(0.3, spoon.copyTimeout)
      assert.equal(0.2, spoon.restoreDelay)
      assert.is_true(spoon.switchLayout)
      assert.same({
        convert = { { "ctrl", "shift" } },
        convertAll = { { "ctrl", "shift" }, "space" },
      }, spoon.defaultHotkeys)
    end)

    it("init returns self and loads the modules", function()
      assert.equal(spoon, spoon:init())
      assert.is_table(spoon.converter)
      assert.is_table(spoon.clipboard)
      assert.is_table(spoon.layout)
      assert.is_table(spoon.modtap)
      assert.is_table(spoon.logger)
    end)
  end)

  describe("convert", function()
    it("runs the full flow in order (English to Hebrew)", function()
      hs._nextCopy = "akuo"
      spoon:convert()
      assert.same({
        "pasteboard.readAllData",
        "eventtap.keyStroke cmd+c",
        "pasteboard.callbackWhenChanged",
        "pasteboard.readString",
        "pasteboard.writeAllData",
        "eventtap.keyStroke cmd+v",
        "keycodes.setLayout Hebrew",
        "timer.doAfter 0.2",
      }, hs._calls)
      assert.same({ [TEXT] = "שלום", [TRANSIENT] = "" }, writes[1])

      hs._runTimers()
      assert.equal("pasteboard.writeAllData", hs._calls[#hs._calls])
      assert.equal(2, #writes)
      assert.same({ [TEXT] = "original", ["public.png"] = "\0png" }, writes[2])
      assert.same({ [TEXT] = "original", ["public.png"] = "\0png" }, hs._pb.contents)
    end)

    it("reverse direction pastes English and switches to ABC", function()
      hs._currentLayout = "Hebrew"
      hs._nextCopy = "שלום"
      spoon:convert()
      assert.same({ [TEXT] = "akuo", [TRANSIENT] = "" }, writes[1])
      assert.is_true(hs._called("keycodes.setLayout ABC"))
      assert.is_false(hs._called("keycodes.setLayout Hebrew"))
      hs._runTimers()
      assert.same({ [TEXT] = "original", ["public.png"] = "\0png" }, hs._pb.contents)
    end)

    it("uses custom layout names", function()
      hs._layouts = { "U.S.", "Hebrew-QWERTY" }
      spoon.layouts = { hebrew = "Hebrew-QWERTY", english = "U.S." }
      hs._nextCopy = "akuo"
      spoon:convert()
      assert.is_true(hs._called("keycodes.setLayout Hebrew-QWERTY"))
    end)

    it("no selection restores and does not paste", function()
      hs._nextCopy = nil
      spoon:convert()
      assert.equal(0, count("eventtap.keyStroke cmd+v"))
      assert.equal(0, count("keycodes.setLayout"))
      assert.equal(0, count("timer.doAfter"))
      assert.equal(1, #writes)
      assert.same({ [TEXT] = "original", ["public.png"] = "\0png" }, writes[1])
    end)

    it("nothing to convert restores and does not paste", function()
      hs._nextCopy = "123"
      spoon:convert()
      assert.equal(0, count("eventtap.keyStroke cmd+v"))
      assert.equal(0, count("keycodes.setLayout"))
      assert.equal(1, #writes)
      assert.same({ [TEXT] = "original", ["public.png"] = "\0png" }, hs._pb.contents)
    end)

    it("switchLayout=false does not switch the layout", function()
      spoon.switchLayout = false
      hs._nextCopy = "akuo"
      spoon:convert()
      assert.is_true(hs._called("eventtap.keyStroke cmd+v"))
      assert.equal(0, count("keycodes.setLayout"))
    end)

    it("uses custom copyTimeout and restoreDelay", function()
      spoon.copyTimeout = 0.7
      spoon.restoreDelay = 0.5
      local seenTimeout
      local orig = hs.pasteboard.callbackWhenChanged
      hs.pasteboard.callbackWhenChanged = function(timeout, fn)
        seenTimeout = timeout
        return orig(timeout, fn)
      end
      hs._nextCopy = "akuo"
      spoon:convert()
      assert.equal(0.7, seenTimeout)
      assert.is_true(hs._called("timer.doAfter 0.5"))
      assert.is_false(hs._called("timer.doAfter 0.2"))
    end)

    it("ignores a second press while a conversion is running", function()
      hs._nextCopy = "akuo"
      spoon:convert()
      local before = #hs._calls
      spoon:convert()
      assert.equal(before, #hs._calls)
      assert.equal(1, hs._count("pasteboard.readAllData"))

      hs._runTimers()
      hs._nextCopy = "akuo"
      spoon:convert()
      assert.equal(2, hs._count("pasteboard.readAllData"))
    end)

    it("clears the busy flag after an early return", function()
      hs._nextCopy = nil
      spoon:convert()
      hs._nextCopy = "akuo"
      spoon:convert()
      assert.is_true(hs._called("eventtap.keyStroke cmd+v"))
    end)

    it("restores the clipboard and logs no text when the flow errors", function()
      spoon.converter = {
        convert = function()
          error("boom")
        end,
      }
      hs._nextCopy = "secret-text"
      spoon:convert()
      assert.equal(0, count("eventtap.keyStroke cmd+v"))
      assert.same({ [TEXT] = "original", ["public.png"] = "\0png" }, hs._pb.contents)
      assert.equal(1, #hs._logs)
      assert.equal("e", hs._logs[1].level)
      assert.is_nil(hs._logs[1].msg:find("secret", 1, true))

      spoon.converter = dofile("HebFix.spoon/converter.lua")
      hs._nextCopy = "akuo"
      spoon:convert()
      assert.is_true(hs._called("eventtap.keyStroke cmd+v"))
    end)

    it("never logs clipboard or selected text", function()
      hs._pb.contents = { [TEXT] = "secret-old" }
      hs._layouts = {}
      for _, sel in ipairs({ "secret-new", "שלום secret" }) do
        hs._nextCopy = sel
        spoon:convert()
        hs._runTimers()
      end
      hs._nextCopy = nil
      spoon:convert()
      assert.is_true(#hs._logs > 0)
      for _, entry in ipairs(hs._logs) do
        assert.is_nil(entry.msg:find("secret", 1, true))
        assert.is_nil(entry.msg:find("שלום", 1, true))
        assert.is_nil(entry.msg:find("akuo", 1, true))
      end
    end)
  end)

  describe("convertAll", function()
    it("sends cmd+a first, then runs the full flow in order", function()
      hs._nextCopy = "akuo"
      assert.equal(spoon, spoon:convertAll())
      assert.same({
        "eventtap.keyStroke cmd+a",
        "pasteboard.readAllData",
        "eventtap.keyStroke cmd+c",
        "pasteboard.callbackWhenChanged",
        "pasteboard.readString",
        "pasteboard.writeAllData",
        "eventtap.keyStroke cmd+v",
        "keycodes.setLayout Hebrew",
        "timer.doAfter 0.2",
      }, hs._calls)
      assert.same({ [TEXT] = "שלום", [TRANSIENT] = "" }, writes[1])
      hs._runTimers()
      assert.same({ [TEXT] = "original", ["public.png"] = "\0png" }, hs._pb.contents)
    end)

    it("convert does not send cmd+a", function()
      hs._nextCopy = "akuo"
      spoon:convert()
      assert.equal(0, count("eventtap.keyStroke cmd+a"))
    end)

    it("empty field restores and does not paste", function()
      hs._nextCopy = nil
      spoon:convertAll()
      assert.equal(0, count("eventtap.keyStroke cmd+v"))
      assert.equal(1, #writes)
      assert.same({ [TEXT] = "original", ["public.png"] = "\0png" }, hs._pb.contents)
    end)

    it("restores the clipboard and logs no text when the flow errors", function()
      spoon.converter = {
        convert = function()
          error("boom")
        end,
      }
      hs._nextCopy = "secret-text"
      spoon:convertAll()
      assert.equal(0, count("eventtap.keyStroke cmd+v"))
      assert.same({ [TEXT] = "original", ["public.png"] = "\0png" }, hs._pb.contents)
      assert.equal(1, #hs._logs)
      assert.is_nil(hs._logs[1].msg:find("secret", 1, true))
    end)

    it("the busy guard covers convert and convertAll", function()
      hs._nextCopy = "akuo"
      spoon:convert()
      local before = #hs._calls
      spoon:convertAll()
      spoon:convert()
      assert.equal(before, #hs._calls)

      hs._runTimers()
      hs._nextCopy = "akuo"
      spoon:convertAll()
      before = #hs._calls
      spoon:convert()
      spoon:convertAll()
      assert.equal(before, #hs._calls)
      assert.equal(1, count("eventtap.keyStroke cmd+a"))

      hs._runTimers()
      hs._nextCopy = "akuo"
      spoon:convert()
      assert.equal(3, hs._count("pasteboard.readAllData"))
    end)
  end)

  describe("hotkeys", function()
    -- Press and release ctrl+shift, then run the timers.
    local function tapCtrlShift()
      hs._emit("flagsChanged", { ctrl = true })
      hs._emit("flagsChanged", { ctrl = true, shift = true })
      hs._emit("flagsChanged", {})
      hs._runTimers()
    end

    it("start binds one tap and one hotkey by default and enables both", function()
      assert.equal(spoon, spoon:start())
      assert.equal(1, hs._count("eventtap.new"))
      assert.equal(1, #hs._taps)
      assert.is_true(hs._taps[1]:isEnabled())
      assert.is_true(hs._called("hotkey.new ctrl+shift+space"))
      assert.equal(1, #hs._hotkeys)
      assert.is_true(hs._hotkeys[1].enabled)
    end)

    it("the ctrl+shift tap runs convert", function()
      spoon:start()
      hs._nextCopy = "akuo"
      tapCtrlShift()
      assert.same({ [TEXT] = "שלום", [TRANSIENT] = "" }, writes[1])
      assert.equal(0, count("eventtap.keyStroke cmd+a"))
      assert.equal(1, hs._count("eventtap.keyStroke cmd+c"))
    end)

    it("the ctrl+shift+space hotkey runs convertAll", function()
      spoon:start()
      hs._nextCopy = "akuo"
      hs._hotkeys[1]:_press()
      assert.equal("eventtap.keyStroke cmd+a", hs._calls[#hs._calls - 8])
      assert.same({ [TEXT] = "שלום", [TRANSIENT] = "" }, writes[1])
    end)

    it("a hotkey press cancels a pending tap", function()
      spoon:start()
      hs._nextCopy = "akuo"
      hs._emit("flagsChanged", { ctrl = true, shift = true })
      hs._hotkeys[1]:_press()
      hs._emit("flagsChanged", {})
      hs._runTimers()
      assert.equal(1, hs._count("eventtap.keyStroke cmd+c"))
      assert.equal(1, hs._count("eventtap.keyStroke cmd+a"))
    end)

    it("a key-less entry binds a modifier tap, not a hotkey", function()
      spoon:bindHotkeys({ convert = { { "cmd", "alt" } } })
      assert.equal(0, #hs._hotkeys)
      assert.equal(0, #hs._taps) -- the event tap is created on start
      spoon:start()
      assert.equal(0, #hs._hotkeys)
      assert.equal(1, #hs._taps)
      assert.is_true(hs._taps[1]:isEnabled())
      hs._nextCopy = "akuo"
      hs._emit("flagsChanged", { cmd = true, alt = true })
      hs._emit("flagsChanged", {})
      hs._runTimers()
      assert.same({ [TEXT] = "שלום", [TRANSIENT] = "" }, writes[1])
    end)

    it("convertAll can be a tap and convert a hotkey", function()
      spoon:bindHotkeys({
        convert = { { "cmd", "alt" }, "h" },
        convertAll = { { "ctrl", "shift" } },
      })
      spoon:start()
      hs._nextCopy = "akuo"
      tapCtrlShift()
      assert.equal(1, hs._count("eventtap.keyStroke cmd+a"))
      assert.is_true(hs._called("hotkey.new cmd+alt+h"))
    end)

    it("stop stops the tap and start starts it again", function()
      spoon:start()
      spoon:stop()
      assert.is_true(hs._called("eventtap.stop"))
      assert.is_false(hs._taps[1]:isEnabled())
      hs._nextCopy = "akuo"
      tapCtrlShift()
      assert.equal(0, count("eventtap.keyStroke"))
      spoon:start()
      assert.equal(1, #hs._taps)
      tapCtrlShift()
      assert.equal(1, hs._count("eventtap.keyStroke cmd+c"))
    end)

    it("rebinding stops the old tap", function()
      spoon:start()
      spoon:bindHotkeys({ convert = { { "cmd", "alt" }, "h" } })
      assert.is_false(hs._taps[1]:isEnabled())
      assert.equal(1, #hs._taps)
      hs._nextCopy = "akuo"
      tapCtrlShift()
      assert.equal(0, count("eventtap.keyStroke"))
    end)

    it("bindHotkeys uses the given mapping and start keeps it", function()
      assert.equal(spoon, spoon:bindHotkeys({ convert = { { "cmd", "alt" }, "h" } }))
      assert.is_true(hs._called("hotkey.new cmd+alt+h"))
      assert.is_false(hs._hotkeys[1].enabled)
      spoon:start()
      assert.is_false(hs._called("hotkey.new ctrl+shift+space"))
      assert.equal(0, #hs._taps)
      assert.equal(1, #hs._hotkeys)
      assert.is_true(hs._hotkeys[1].enabled)
    end)

    it("rebinding deletes the old hotkey and keeps the running state", function()
      spoon:start()
      spoon:bindHotkeys({ convert = { { "cmd", "alt" }, "h" } })
      assert.is_true(hs._hotkeys[1].deleted)
      assert.is_true(hs._hotkeys[2].enabled)
    end)

    it("stop disables the hotkey and start enables it again", function()
      spoon:start()
      assert.equal(spoon, spoon:stop())
      assert.is_false(hs._hotkeys[1].enabled)
      assert.is_true(hs._called("hotkey.disable"))
      spoon:start()
      assert.is_true(hs._hotkeys[1].enabled)
      assert.equal(1, #hs._hotkeys)
      assert.equal(1, #hs._taps)
    end)

    it("stop before start is safe", function()
      assert.has_no.errors(function()
        spoon:stop()
      end)
    end)

    it("an unknown action is logged and not bound", function()
      spoon:bindHotkeys({ nope = { { "cmd" }, "x" } })
      assert.equal(0, #hs._hotkeys)
      assert.equal(1, #hs._logs)
      assert.truthy(hs._logs[1].msg:find("nope", 1, true))
    end)
  end)
end)
