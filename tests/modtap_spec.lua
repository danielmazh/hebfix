local hsmock = require("mocks.hs")

describe("modtap", function()
  local hs, modtap, fired, tap

  local CS = { ctrl = true, shift = true }

  before_each(function()
    hs = hsmock.install()
    package.loaded["modtap"] = nil
    modtap = require("modtap")
    fired = 0
    tap = modtap.new({ "ctrl", "shift" }, function()
      fired = fired + 1
    end)
    tap:start()
  end)

  after_each(function()
    hsmock.uninstall()
  end)

  -- Emit events, then run the timers, so fn has run if the tap fired.
  local function emit(...)
    for _, e in ipairs({ ... }) do
      hs._emit(e[1], e[2])
    end
    hs._runTimers()
  end

  it("watches flagsChanged, keyDown and mouse down events", function()
    assert.same({ "eventtap.new", "eventtap.start" }, hs._calls)
    local t = hs.eventtap.event.types
    assert.same({
      t.flagsChanged,
      t.keyDown,
      t.leftMouseDown,
      t.rightMouseDown,
      t.otherMouseDown,
    }, hs._taps[1].types)
    assert.is_true(hs._taps[1]:isEnabled())
  end)

  it("a plain tap fires once, through timer.doAfter 0", function()
    hs._emit("flagsChanged", { ctrl = true })
    hs._emit("flagsChanged", CS)
    hs._emit("flagsChanged", {})
    assert.equal(0, fired)
    assert.is_true(hs._called("timer.doAfter 0"))
    hs._runTimers()
    assert.equal(1, fired)
    emit({ "flagsChanged", {} })
    assert.equal(1, fired)
  end)

  it("never consumes events", function()
    for _, e in ipairs({
      { "flagsChanged", CS },
      { "keyDown", CS },
      { "leftMouseDown", {} },
      { "flagsChanged", {} },
    }) do
      assert.same({ false }, hs._emit(e[1], e[2]))
    end
  end)

  it("ctrl+shift+space does not fire the tap", function()
    emit({ "flagsChanged", CS }, { "keyDown", CS }, { "flagsChanged", {} })
    assert.equal(0, fired)
  end)

  it("an extra modifier disarms", function()
    for _, extra in ipairs({ "cmd", "alt", "fn" }) do
      local flags = { ctrl = true, shift = true, [extra] = true }
      emit({ "flagsChanged", CS }, { "flagsChanged", flags }, { "flagsChanged", {} })
    end
    assert.equal(0, fired)
  end)

  it("an extra modifier pressed and released before the end still cancels", function()
    emit(
      { "flagsChanged", CS },
      { "flagsChanged", { ctrl = true, shift = true, alt = true } },
      { "flagsChanged", CS },
      { "flagsChanged", {} }
    )
    assert.equal(0, fired)
  end)

  it("a mouse click disarms", function()
    for _, kind in ipairs({ "leftMouseDown", "rightMouseDown", "otherMouseDown" }) do
      emit({ "flagsChanged", CS }, { kind, CS }, { "flagsChanged", {} })
    end
    assert.equal(0, fired)
  end)

  it("a key pressed with one modifier held blocks the tap", function()
    emit({ "flagsChanged", { ctrl = true } }, { "keyDown", { ctrl = true } })
    emit({ "flagsChanged", CS }, { "flagsChanged", {} })
    assert.equal(0, fired)
  end)

  it("partial release then full release fires once", function()
    emit({ "flagsChanged", CS }, { "flagsChanged", { shift = true } }, { "flagsChanged", {} })
    assert.equal(1, fired)
  end)

  it("only one modifier pressed does not fire", function()
    emit({ "flagsChanged", { ctrl = true } }, { "flagsChanged", {} })
    emit({ "flagsChanged", { shift = true } }, { "flagsChanged", {} })
    assert.equal(0, fired)
  end)

  it("a keyDown with no modifier held does not block the next tap", function()
    emit({ "keyDown", {} }, { "flagsChanged", CS }, { "flagsChanged", {} })
    assert.equal(1, fired)
  end)

  it("works again after a cancelled tap", function()
    emit({ "flagsChanged", CS }, { "keyDown", CS }, { "flagsChanged", {} })
    emit({ "flagsChanged", CS }, { "flagsChanged", {} })
    assert.equal(1, fired)
  end)

  it("cancel() blocks the pending tap", function()
    hs._emit("flagsChanged", CS)
    tap:cancel()
    emit({ "flagsChanged", {} })
    assert.equal(0, fired)
  end)

  it("ignores unknown flags", function()
    emit({ "flagsChanged", { ctrl = true, shift = true, capslock = true } }, { "flagsChanged", {} })
    assert.equal(1, fired)
  end)

  it("stop() stops firing and start() turns it back on", function()
    tap:stop()
    assert.is_true(hs._called("eventtap.stop"))
    assert.is_false(hs._taps[1]:isEnabled())
    emit({ "flagsChanged", CS }, { "flagsChanged", {} })
    assert.equal(0, fired)
    tap:start()
    assert.equal(1, hs._count("eventtap.new"))
    emit({ "flagsChanged", CS }, { "flagsChanged", {} })
    assert.equal(1, fired)
  end)

  it("stop() while armed drops the pending tap", function()
    hs._emit("flagsChanged", CS)
    tap:stop()
    tap:start()
    emit({ "flagsChanged", {} })
    assert.equal(0, fired)
  end)

  it("delete() stops the event tap", function()
    tap:delete()
    assert.is_false(hs._taps[1]:isEnabled())
    emit({ "flagsChanged", CS }, { "flagsChanged", {} })
    assert.equal(0, fired)
  end)

  it("new() starts stopped and checks its arguments", function()
    local t = modtap.new({ "alt" }, function() end)
    assert.equal(1, #hs._taps)
    t:start()
    assert.equal(2, #hs._taps)
    assert.has_error(function()
      modtap.new({}, function() end)
    end)
    assert.has_error(function()
      modtap.new({ "ctrl" }, nil)
    end)
  end)

  it("logs nothing", function()
    emit({ "flagsChanged", CS }, { "keyDown", CS }, { "flagsChanged", {} })
    emit({ "flagsChanged", CS }, { "flagsChanged", {} })
    assert.equal(0, #hs._logs)
  end)
end)
