local converter = require("converter")
local convert = converter.convert

-- Sorted list of forward keys, for deterministic tests.
local function keys()
  local list = {}
  for k in pairs(converter.toHebrew) do
    list[#list + 1] = k
  end
  table.sort(list)
  return list
end

-- A key that types a Hebrew letter, so the converted text still has a direction.
local function isLetterKey(k)
  return k:match("^%a$") ~= nil and converter.toHebrew[k]:match("^[%z\1-\127]$") == nil
end

describe("converter", function()
  describe("module shape", function()
    it("exports convert, toHebrew and toEnglish", function()
      assert.is_function(converter.convert)
      assert.is_table(converter.toHebrew)
      assert.is_table(converter.toEnglish)
    end)

    it("maps all 26 letters and all 27 Hebrew letters", function()
      for c = string.byte("a"), string.byte("z") do
        assert.is_not_nil(converter.toHebrew[string.char(c)])
      end
      for cp = 0x05D0, 0x05EA do
        assert.is_not_nil(converter.toEnglish[utf8.char(cp)], string.format("U+%04X", cp))
      end
    end)
  end)

  describe("reverse table", function()
    it("has no collisions and is the exact inverse of the forward table", function()
      local seen, fwdCount, revCount = {}, 0, 0
      for k, v in pairs(converter.toHebrew) do
        fwdCount = fwdCount + 1
        assert.is_nil(seen[v], "collision on " .. v)
        seen[v] = k
        assert.are.equal(k, converter.toEnglish[v])
      end
      for k, v in pairs(converter.toEnglish) do
        revCount = revCount + 1
        assert.are.equal(k, converter.toHebrew[v])
      end
      assert.are.equal(fwdCount, revCount)
    end)
  end)

  describe("known words", function()
    it("converts English keys to Hebrew", function()
      local out, toHeb = convert("akuo")
      assert.are.equal("שלום", out)
      assert.is_true(toHeb)
      assert.are.equal("יקךךם", (convert("hello")))
      assert.are.equal("אקדא", (convert("test")))
    end)

    it("converts Hebrew to English keys", function()
      local out, toHeb = convert("יקךךם")
      assert.are.equal("hello", out)
      assert.is_false(toHeb)
      assert.are.equal("akuo", (convert("שלום")))
    end)
  end)

  describe("edge input", function()
    it("returns nil, nil for nil", function()
      local out, dir = convert(nil)
      assert.is_nil(out)
      assert.is_nil(dir)
    end)

    it("returns empty string, nil for empty string", function()
      local out, dir = convert("")
      assert.are.equal("", out)
      assert.is_nil(dir)
    end)

    it("returns digits unchanged with no direction", function()
      local out, dir = convert("0123456789")
      assert.are.equal("0123456789", out)
      assert.is_nil(dir)
    end)

    it("does not decide direction from punctuation alone", function()
      for _, s in ipairs({ ",./;'[]", "  12 - 3 ", "!@#$%^&*()" }) do
        local out, dir = convert(s)
        assert.are.equal(s, out)
        assert.is_nil(dir)
      end
    end)

    it("returns invalid UTF-8 unchanged with no direction", function()
      local bad = "abc\255def"
      local out, dir = convert(bad)
      assert.are.equal(bad, out)
      assert.is_nil(dir)
    end)
  end)

  describe("case", function()
    it("treats uppercase ASCII as lowercase", function()
      assert.are.equal("שלום", (convert("AKUO")))
      assert.are.equal("יקךךם", (convert("HeLLo")))
    end)
  end)

  describe("punctuation", function()
    it("converts punctuation keys once direction is known (to Hebrew)", function()
      assert.are.equal("ש,.ץתף][/'", (convert("a'/.,;[]qw")))
    end)

    it("converts punctuation back (to English)", function()
      assert.are.equal("a'/.,;[]qw", (convert("ש,.ץתף][/'")))
    end)

    it("decides direction from the first letter even after punctuation", function()
      local out, toHeb = convert("/.hello")
      assert.are.equal(".ץיקךךם", out)
      assert.is_true(toHeb)
      out, toHeb = convert(".,שלום")
      assert.are.equal("/'akuo", out)
      assert.is_false(toHeb)
    end)

    it("passes unmapped chars through", function()
      assert.are.equal("ש 1-2=3! ש", (convert("a 1-2=3! a")))
      assert.are.equal("a 1-2=3! a", (convert("ש 1-2=3! ש")))
    end)
  end)

  describe("mixed text", function()
    it("uses the first letter's direction and leaves the other script alone", function()
      local out, toHeb = convert("hello שלום")
      assert.are.equal("יקךךם שלום", out)
      assert.is_true(toHeb)
      out, toHeb = convert("שלום hello")
      assert.are.equal("akuo hello", out)
      assert.is_false(toHeb)
    end)

    it("leaves other Unicode untouched", function()
      assert.are.equal("בשכé → ש", (convert("café → a")))
    end)
  end)

  describe("round-trip", function()
    local function roundTrip(s)
      local hebrew, dir1 = convert(s)
      local back, dir2 = convert(hebrew)
      assert.is_true(dir1, s)
      assert.is_false(dir2, s)
      assert.are.equal(s:lower(), back, s)
    end

    it("holds for the whole keymap", function()
      roundTrip(table.concat(keys()))
      roundTrip(table.concat(keys()):upper())
    end)

    it("holds for every key paired with a letter key", function()
      for _, k in ipairs(keys()) do
        roundTrip(k .. "a")
        roundTrip("a" .. k)
        roundTrip(k .. " a " .. k .. k)
      end
    end)

    it("holds for many random mappable strings", function()
      math.randomseed(42)
      local all, letters = keys(), {}
      for _, k in ipairs(all) do
        if isLetterKey(k) then
          letters[#letters + 1] = k
        end
      end
      local extra = { " ", "1", "9", "-", "=", "!", "\n" }
      for _ = 1, 500 do
        local parts = { letters[math.random(#letters)] }
        for _ = 1, math.random(0, 30) do
          if math.random() < 0.8 then
            parts[#parts + 1] = all[math.random(#all)]
          else
            parts[#parts + 1] = extra[math.random(#extra)]
          end
        end
        local s = table.concat(parts)
        if math.random() < 0.3 then
          s = s:upper()
        end
        roundTrip(s)
      end
    end)

    it("holds starting from Hebrew", function()
      local heb = {}
      for cp = 0x05D0, 0x05EA do
        heb[#heb + 1] = utf8.char(cp)
      end
      local s = table.concat(heb) .. " ,./[]"
      local eng = convert(s)
      assert.are.equal(s, (convert(eng)))
    end)
  end)

  describe("performance", function()
    it("converts 1000 chars in under 5 ms on average", function()
      local base = "hello world, this is a test; [x] "
      local s = string.rep(base, math.ceil(1000 / #base)):sub(1, 1000)
      assert.are.equal(1000, #s)
      local runs = 20
      convert(s)
      local start = os.clock()
      for _ = 1, runs do
        convert(s)
      end
      local avg = (os.clock() - start) / runs
      assert.is_true(avg < 0.005, string.format("avg %.3f ms", avg * 1000))
    end)
  end)
end)
