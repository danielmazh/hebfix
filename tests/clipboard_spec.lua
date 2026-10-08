local hsmock = require("mocks.hs")

describe("clipboard", function()
  local hs, clipboard

  before_each(function()
    hs = hsmock.install()
    package.loaded["clipboard"] = nil
    clipboard = require("clipboard")
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

  it("save reads all pasteboard data", function()
    hs._pb.contents = { ["public.utf8-plain-text"] = "old" }
    local saved = clipboard.save()
    assert.same({ ["public.utf8-plain-text"] = "old" }, saved)
    assert.is_true(hs._called("pasteboard.readAllData"))
  end)

  it("no selection calls cb(false) and writes nothing", function()
    hs._pb.contents = { ["public.utf8-plain-text"] = "old" }
    hs._nextCopy = nil
    local got
    clipboard.copySelection(function(...)
      got = table.pack(...)
    end, 0.3)
    assert.same({ n = 1, false }, got)
    assert.same({ "eventtap.keyStroke cmd+c", "pasteboard.callbackWhenChanged" }, hs._calls)
    assert.equal(0, count("pasteboard.write"))
    assert.equal(0, count("pasteboard.setContents"))
  end)

  it("selection equal to previous clipboard is still detected", function()
    hs._pb.contents = { ["public.utf8-plain-text"] = "same" }
    hs._nextCopy = "same"
    local ok, text
    clipboard.copySelection(function(a, b)
      ok, text = a, b
    end, 0.3)
    assert.is_true(ok)
    assert.equal("same", text)
  end)

  it("selection with new text returns the text", function()
    hs._nextCopy = "akuo"
    local ok, text
    clipboard.copySelection(function(a, b)
      ok, text = a, b
    end, 0.3)
    assert.is_true(ok)
    assert.equal("akuo", text)
  end)

  it("restore writes back exactly the saved non-text data", function()
    local png = "\137PNG\r\n\26\n\0\0binary"
    hs._pb.contents = { ["public.png"] = png }
    local saved = clipboard.save()
    hs._pb.contents = { ["public.utf8-plain-text"] = "other" }
    clipboard.restore(saved)
    assert.same({ ["public.png"] = png }, hs._pb.contents)
    assert.is_true(hs._called("pasteboard.writeAllData"))
  end)

  it("restore passes the saved table to writeAllData", function()
    local saved = { ["public.png"] = "\0\1\2" }
    local seen
    local orig = hs.pasteboard.writeAllData
    hs.pasteboard.writeAllData = function(t)
      seen = t
      return orig(t)
    end
    clipboard.restore(saved)
    assert.equal(saved, seen)
  end)

  it("restore of nil is safe and writes nothing", function()
    assert.has_no.errors(function()
      clipboard.restore(nil)
    end)
    assert.equal(0, count("pasteboard.write"))
  end)

  it("writeTransient writes text and the transient marker in one write", function()
    clipboard.writeTransient("שלום")
    assert.same({
      ["public.utf8-plain-text"] = "שלום",
      ["org.nspasteboard.TransientType"] = "",
    }, hs._pb.contents)
    assert.equal(1, hs._count("pasteboard.writeAllData"))
  end)

  it("paste sends cmd+v", function()
    clipboard.paste()
    assert.same({ "eventtap.keyStroke cmd+v" }, hs._calls)
  end)

  it("never logs clipboard content", function()
    hs._pb.contents = { ["public.utf8-plain-text"] = "secret-old" }
    hs._nextCopy = "secret-new"
    local saved = clipboard.save()
    clipboard.copySelection(function() end, 0.3)
    clipboard.writeTransient("secret-converted")
    clipboard.paste()
    clipboard.restore(saved)
    for _, entry in ipairs(hs._logs) do
      assert.is_nil(entry.msg:find("secret", 1, true))
    end
    for _, c in ipairs(hs._calls) do
      assert.is_nil(c:find("secret", 1, true))
    end
  end)
end)
