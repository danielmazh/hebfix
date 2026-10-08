-- luacheck config for HebFix (Lua 5.4, Hammerspoon)
std = "lua54"
read_globals = { "hs" }
max_line_length = 100
codes = true

exclude_files = {
  ".worktrees/**",
  "dist/**",
  ".luarocks/**",
  ".lua/**",
  ".install/**",
  "lua_modules/**",
}

files["tests/**"] = {
  std = "+busted",
  max_line_length = 120,
}

-- The mock installs itself as the global hs.
files["tests/mocks/hs.lua"] = {
  globals = { "hs" },
}
