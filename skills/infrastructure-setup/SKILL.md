---
name: infrastructure-setup
description: |
  Sets up dev infrastructure for new projects: framework init, folder structure,
  Docker, pre-commit hooks (gitleaks), testing infrastructure, .gitignore.

  Use when: "настрой инфраструктуру", "подготовь проект", "настрой тесты",
  "настрой проверки при коммите", "настрой проверки при пуше", "setup infrastructure"
---

# Infrastructure Setup

## Gathering Project Context

Read project-knowledge references:
- `.agents/skills/project-knowledge/references/architecture.md` — tech stack, framework
- `.agents/skills/project-knowledge/references/patterns.md` — code conventions, branching strategy, testing
- `.agents/skills/project-knowledge/references/deployment.md` — deployment strategy

If files lack needed info, search other project-knowledge references — info may exist under different names. If missing entirely, propose a default and confirm with user.

## Phase 0: Confirm Setup Plan with User — BLOCKING GATE

Before installing or creating anything, present a summary of what you will set up. Use **plain language** — describe what the user will get, not technical internals.

Example format:
```
Вот что я настрою для проекта:

1. **Основа приложения:** React + TypeScript — интерфейс будет работать в браузере, без серверной части.
   Стили: Tailwind CSS — готовые классы вместо написания CSS вручную.
2. **Структура папок:** отдельные папки для компонентов, сервисов, тестов.
3. **Тесты:** Vitest — можно будет запускать проверки одной командой `npm test`.
4. **Защита от утечек:** pre-commit хук gitleaks — не даст случайно закоммитить пароли/ключи.
5. **Docker:** не нужен (нет серверной части).

Подтверждаешь? Или хочешь что-то изменить?
```

**Rules for this summary:**
- Describe what each tool DOES for the user, not what it IS. Wrong: "Vitest — fast unit testing framework with ESM support". Right: "Vitest — можно будет запускать проверки одной командой `npm test`."
- If project-knowledge specifies the stack — still confirm it. The user may have changed their mind since planning.
- If project-knowledge is missing or vague about a choice — propose a default with one-sentence reasoning and ask to confirm.
- Wait for explicit approval before proceeding to Phase 1.

## Phase 1: Framework Initialization

**Non-empty directory handling — MANDATORY when project root has ANY files.** Scaffolding tools (Vite, Next.js, CRA) WILL refuse to init in a non-empty directory. If the project root already has files (e.g., `work/`, `.agents/`, `.gitignore`), you MUST:
1. Create the scaffold in a temporary subdirectory (e.g., `_scaffold_tmp/`).
2. Move runtime files (src/, package.json, tsconfig.json, vite.config.ts, etc.) from `_scaffold_tmp/` to the project root.
3. Delete `_scaffold_tmp/`.
4. Merge generated `.gitignore` entries into the existing `.gitignore` — do NOT overwrite it.

Do NOT attempt to scaffold directly into a non-empty directory. It will fail.

Init framework from confirmed stack. Use Context7 for up-to-date init commands and flags.

**Dev server verification:** Run `npm run dev` (or equivalent) and confirm the process starts. If the environment does not support long-running process stdout (timeouts, restricted terminals), verify via `npm run build` instead — a successful build confirms the framework is functional. One of these MUST succeed before moving on.

**Checkpoint:** dev server starts or build succeeds.

## Phase 2: Folder Structure

Convention — separate concerns by purpose:

- **Web Apps:** `src/{components, services, lib, config}` + `tests/{unit, integration, e2e}`
- **APIs:** `src/{routes, services, models, middleware, config}` + `tests/{unit, integration}`
- **CLI tools:** `src/{commands, services, config}` + `tests/{unit, integration}`

Add `src/prompts/` if project uses LLM prompts. Add `src/messages/` if project uses i18n.

**Checkpoint:** structure created, matches project type.

## Phase 3: Docker (conditional)

Set up only if specified in project-knowledge or user confirms.

**Checkpoint:** `docker build` succeeds, container starts.

## Phase 4: .gitignore

Security patterns (always add):
```
.env
.env.*
!.env.example
*.key
*.pem
credentials.json
secrets/
```

Add framework-specific patterns from `architecture.md`.
Create `.env.example` with required variable names (no values).

**Checkpoint:** `git check-ignore .env` returns `.env`.

## Phase 5: Pre-commit Hooks

Convention: gitleaks for secret scanning. Target: total pre-commit time under 10 seconds.

**Gitleaks installation — MUST complete before configuring the hook.** Install and verify `gitleaks version` succeeds:
- macOS: `brew install gitleaks`
- Windows: `winget install gitleaks` (binary may land outside PATH — check `$LOCALAPPDATA\Microsoft\WinGet\Links\` or `$HOME\AppData\Local\Microsoft\WinGet\Packages\*gitleaks*`)
- Linux / CI: download from GitHub releases or use `go install github.com/gitleaks/gitleaks/v8@latest`
- Verify: `gitleaks version`

The pre-commit hook template includes a fallback path search — see `husky-pre-commit-gitleaks.sh`.

**Custom rules (.gitleaks.toml) — ALWAYS create.** The default gitleaks ruleset does NOT catch all secret patterns. Copy `$AGENTS_HOME/shared/templates/infrastructure/static/.gitleaks.toml` to the project root and adjust rules for the project's secret formats. Without this file, the checkpoint test WILL fail.

Pre-commit scope (fast, staged files only):
- gitleaks (~2-5 seconds)
- Lint staged files
- Format check

**lint-staged + prettier — MUST avoid circular failures.** The pre-commit hook MUST run `prettier --write` (fix mode), NOT `prettier --check` (read-only mode). If lint-staged runs `--check`, it will fail on unformatted files that it could have auto-fixed, creating a cycle where the commit never passes. Correct lint-staged config:
```json
{
  "*.{js,ts,tsx,json,md}": ["prettier --write", "eslint --fix"]
}
```
Do NOT have both `prettier --check` and `prettier --write` in the same pipeline — pick `--write` only. If a pre-commit hook fails due to formatting, run `npx prettier --write .` on all staged files, re-stage, and retry.

Full test suites, integration tests, builds belong in CI.

**Checkpoint — clean testing approach.** Verify gitleaks blocks secrets WITHOUT polluting git history. Follow these steps EXACTLY:
1. `echo "AKIA1234567890EXAMPLE" > _gitleaks_test.txt`
2. `git add _gitleaks_test.txt`
3. `git commit -m "test: gitleaks check"` — MUST be BLOCKED by gitleaks.
4. **Clean up immediately — do NOT skip:** `git reset HEAD _gitleaks_test.txt && rm _gitleaks_test.txt`
5. If gitleaks did NOT block — your `.gitleaks.toml` is misconfigured. Fix rules and retry. Do NOT proceed to Phase 6 until this checkpoint passes.

## Phase 6: Testing Infrastructure

Set up test framework, create smoke test: 1-2 tests verifying setup works (import main module, check environment).

**Canonical test commands** — configure `package.json` scripts AND document the direct `npx` form:
- Vitest: `npx vitest run` (all), `npx vitest run <pattern>` (filtered)
- Jest: `npx jest` (all), `npx jest <pattern>` (filtered)

On Windows, `npm test -- <pattern>` is unreliable. Always prefer `npx <runner> run <pattern>` for filtered runs.

**Checkpoint:** test command passes (`npx vitest run` or equivalent).

## Phase 6b: Multi-Agent Verification — MANDATORY if project uses `/do-feature`

This phase verifies that Codex CLI's multi-agent orchestration actually works: subagents spawn, models switch, and config is respected. Do NOT skip — without this, `/do-feature` will silently run all agents on the default model, wasting budget or losing quality.

**Step 1: Verify Codex agent config exists.** Check `~/.codex/config.toml` contains:
```toml
[agents]
max_threads = 10
max_depth = 2
job_max_runtime_seconds = 3600
```
If missing → add it. Without `max_depth >= 2`, workers cannot spawn reviewer subagents.

**Step 2: Test spawn_agent with explicit model override.** Run in Codex:
```
Spawn a test agent with model gpt-5.4-mini. Ask it to respond with its model name in one word. Then close it.
```
Expected: agent spawns, responds, closes. If spawn fails → check `max_threads` and `max_depth` config.

**Step 3: Verify model switching in OpenAI Usage Dashboard.**
1. Open dashboard.openai.com → Usage.
2. Check the time window of Step 2.
3. You MUST see calls to `gpt-5.4-mini` (the override model), NOT only the default model.
4. If only the default model appears → model switching is broken. Check Codex CLI version and `spawn_agent` parameter support.

**Step 4: Record results in `decisions.md`:**
```markdown
## Multi-Agent Setup Verification
- spawn_agent: ✅/❌ (agent spawned and responded)
- model override: ✅/❌ (Usage Dashboard shows gpt-5.4-mini calls)
- config: max_threads={N}, max_depth={N}
- Codex CLI version: {version}
```

**Checkpoint:** ALL 3 checks pass (spawn works, model switches, config present). If model switching is broken, document the limitation and note that all agents will run on the default model — this affects cost estimates.

## Cross-platform Notes

**Windows / PowerShell gotchas:**
- Some compound or destructive shell commands may be blocked by execution policies. Break complex operations into smaller steps.
- Prefer `npm pkg set` / `npm pkg get` for editing `package.json` programmatically instead of parsing JSON via PowerShell objects (PSCustomObject has limitations with dynamic properties).
- Use forward slashes in paths for cross-platform compatibility in scripts and configs.
- If `husky` hooks don't fire on Windows, ensure git's `core.hooksPath` is set correctly: `git config core.hooksPath .husky`.

## Phase 7: Documentation & Commit

Update project-knowledge references (append, don't overwrite):
- `deployment.md` — required environment variables
- `patterns.md` (Git Workflow section) — pre-commit hooks and what they check

Commit:
```
chore: setup project infrastructure

- Initialize [framework] project
- Setup pre-commit hooks (gitleaks)
- Create folder structure
- Add testing infrastructure
- Configure .gitignore and .env.example
[- Setup Docker (if applicable)]
```

Verify before commit: `git status` shows no `.env` files (only `.env.example`).

## Final Validation

ALL items MUST be checked. Do NOT mark as done without actual verification.

- [ ] Framework runs locally (dev server or build)
- [ ] Folder structure matches convention
- [ ] gitleaks blocks test secret (clean test approach from Phase 5)
- [ ] `.gitignore` covers `.env`, `*.key`, secrets
- [ ] `.env.example` exists (if project uses env vars)
- [ ] Smoke test passes (`npx vitest run` or equivalent)
- [ ] Multi-agent: `spawn_agent` works with model override
- [ ] Multi-agent: Usage Dashboard confirms model switching
- [ ] Multi-agent: `[agents]` config in `~/.codex/config.toml`
- [ ] Results recorded in `decisions.md`
- [ ] Documentation updated (project-knowledge)
- [ ] All infrastructure committed
- [ ] Docker works (if applicable)
