local hsmock = require("mocks.hs")

describe("layout", function()
  local hs, layout

  before_each(function()
    hs = hsmock.install()
    package.loaded["layout"] = nil
    layout = require("layout")
  end)

  after_each(function()
    hsmock.uninstall()
  end)

  it("has default names", function()
    assert.same({ hebrew = "Hebrew", english = "ABC" }, layout.DEFAULTS)
  end)

  it("switches to Hebrew when found", function()
    assert.is_true(layout.switch(true))
    assert.same({ "keycodes.setLayout Hebrew" }, hs._calls)
    assert.equal(0, #hs._logs)
  end)

  it("switches to English when found", function()
    assert.is_true(layout.switch(false, {}))
    assert.same({ "keycodes.setLayout ABC" }, hs._calls)
  end)

  it("skips and warns once when the layout is not found", function()
    hs._layouts = { "ABC" }
    assert.is_false(layout.switch(true))
    assert.equal(0, #hs._calls)
    assert.equal(1, #hs._logs)
    assert.equal("w", hs._logs[1].level)
    assert.equal("HebFix", hs._logs[1].id)
    assert.truthy(hs._logs[1].msg:find("Hebrew", 1, true))

    assert.is_false(layout.switch(true))
    assert.equal(1, #hs._logs)
    assert.equal(0, #hs._calls)
  end)

  it("warning holds the layout name only, no text content", function()
    hs._layouts = {}
    hs._pb.contents = { ["public.utf8-plain-text"] = "secret" }
    layout.switch(false, { english = "U.S." })
    assert.equal(1, #hs._logs)
    assert.is_nil(hs._logs[1].msg:find("secret", 1, true))
    assert.equal("layout not found: U.S.", hs._logs[1].msg)
  end)

  it("warns once per missing name", function()
    hs._layouts = {}
    layout.switch(true)
    layout.switch(false)
    layout.switch(true)
    layout.switch(false)
    assert.equal(2, #hs._logs)
  end)

  it("uses custom names and falls back to defaults for missing keys", function()
    hs._layouts = { "ABC", "Hebrew-QWERTY" }
    local names = { hebrew = "Hebrew-QWERTY" }
    assert.is_true(layout.switch(true, names))
    assert.is_true(layout.switch(false, names))
    assert.same({ "keycodes.setLayout Hebrew-QWERTY", "keycodes.setLayout ABC" }, hs._calls)
  end)
end)
