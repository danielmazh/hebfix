# SPEC-005 Tooling and CI

Owner files: `Makefile`, `.luacheckrc`, `stylua.toml`, `.github/workflows/ci.yml`, `.gitignore`.

- Makefile targets: `lint` (luacheck), `fmt-check` (stylua --check), `test` (busted), `package`, `clean`.
- CI (GitHub Actions, ubuntu-latest): install lua5.4, luarocks, busted, luacheck, stylua;
  run lint, fmt-check, test on push to dev/main and on PRs.

## AC
CI green on `dev`.
