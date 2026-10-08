# AGENTS.md - rules for every agent

- Read the assigned spec and `specs/000-architecture.md` before writing code.
- Touch only files owned by your task (see the task list below).
- Lua 5.4, 2-space indent, stylua formatting, no globals, local modules.
- Every behavior change needs a test. No test, no merge.
- Conventional Commits: `feat|fix|test|docs|chore|ci(scope): message`.
- Branch per task: `feat/spec-XXX-short-name`, from `dev`, merged back to `dev`
  with `--no-ff` after `make lint fmt-check test` passes locally.
- Never commit to `main` directly. Never force-push `main` or `dev`.
- No secrets, no tokens, no clipboard content in code, logs, or commits.
- Hyphens only in prose: never an em dash or an en dash.

## File ownership

| Owner | Files |
|---|---|
| Orchestrator | `specs/`, `AGENTS.md`, merges, release |
| SPEC-001 | `HebFix.spoon/converter.lua`, `tests/converter_spec.lua` |
| SPEC-002/003 | `HebFix.spoon/clipboard.lua`, `HebFix.spoon/layout.lua`, `tests/clipboard_spec.lua`, `tests/layout_spec.lua`, `tests/mocks/hs.lua` |
| SPEC-005 | `Makefile`, `.luacheckrc`, `stylua.toml`, `.github/workflows/ci.yml`, `.gitignore` |
| SPEC-007 | `README.md`, `CHANGELOG.md`, `LICENSE` |
| SPEC-004 | `HebFix.spoon/init.lua`, `tests/init_spec.lua` |
| SPEC-006 | `scripts/`, `tests/scripts_test.sh`, `package` target in `Makefile` |
