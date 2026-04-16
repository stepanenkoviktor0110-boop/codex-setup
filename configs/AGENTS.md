# Global Preferences

## ⛔ RULE #0: Auto-Update Before Any Pipeline Step

**Before running ANY skill command** (`/new-user-spec`, `/new-tech-spec`, `/decompose-tech-spec`, `/do-feature`, `/do-task`, `/retrospective`, `/done`, `/design-system-init`, `/design-generate`, `/design-review`, `/design-retrospective`, `/init-project`, `/init-project-knowledge`, `/write-code`, `/pre-deploy-qa`, `/post-deploy-qa`), the agent MUST check for methodology updates:

```bash
cd ~/.agents && git fetch origin master --quiet && git diff HEAD origin/master --stat
```

- If diff is non-empty → run `git pull origin master` and report: "Методология обновлена: {N} файлов изменено."
- If diff is empty → proceed silently.
- If fetch fails (no internet, auth error) → warn user and proceed with current version.

**This check is MANDATORY and runs ONCE per session** (not before every command — just the first pipeline command). After the first check, skip on subsequent commands within the same session.

## ⛔ RULE #1: Framework Updates — ONLY `git pull`, NEVER cherry-pick

**This rule has been violated 3 times. Read it carefully.**

When user says "apply framework commit {hash}" or "update framework":
1. `cd ~/.agents && git pull origin master` — this is the ONLY correct command.
2. Done. Return to project work.

**What is FORBIDDEN — do NOT do ANY of these:**
- `git cherry-pick {hash}` in the project repo ❌
- `git fetch methodology && git cherry-pick` ❌
- Copying files from `~/.agents/` to `{project}/.agents/` ❌
- Any attempt to merge framework history into project history ❌

**Why:** `~/.agents/` and `{project}/` are SEPARATE git repos with DIFFERENT histories. Cherry-pick WILL cause merge conflicts in files that don't belong to the project (like `skills/feature-execution/SKILL.md`). The project reads skills from `~/.agents/` at runtime — pulling there is enough.

## Instruction Tone: Strict by Default

These instructions are written for Codex agents that default to the laziest interpretation of any rule. Therefore:
- Every SHOULD is a MUST. Every "consider" is "do it". Every "if needed" is "always".
- When a skill says "ask the user" — first propose your own answer with reasoning. Only ask if you genuinely cannot determine the answer from project knowledge, code, or common sense.
- When a skill says "suggest" or "recommend" — do it, don't just mention it's possible.
- Soft language in skills is a formatting artifact, not permission to skip.

## Skill Execution: No Scripts

- **NEVER search for, read, or run helper scripts** (dispatch-skill.ps1, init-feature-folder.sh, smoke-codex-compat.ps1, etc.). Legacy scripts exist in `~/.agents/shared/scripts/` but are DEPRECATED and BROKEN — they require `/bin/bash` which is unavailable in most Windows environments. Their logic is already inlined in SKILL.md files. If you catch yourself about to run a `.sh` or `.ps1` from `shared/scripts/` — STOP. Read the SKILL.md instead — it has the same steps written as inline instructions. Use your built-in tools (mkdir, file-write, file-copy) to create folders and files.
- **Shim (proxy) skills** redirect to another skill. This is normal, not an error. When a shim skill (e.g., `decompose-tech-spec` → `task-decomposition`) says "Read and follow {target SKILL.md}" — load that file and execute its instructions step by step. Do NOT improvise a replacement procedure. Do NOT complain about the redirect — just follow it.
- If a SKILL.md references `$AGENTS_HOME` — resolve it to the actual agents home path (`~/.agents/`) and read the file.
- **Two repos** — see RULE #1 at the top. `~/.agents/` = framework (update via `git pull`). `{project}/` = project. `{project}/.agents/` = project-local knowledge (part of project repo, NOT framework).
- **Integrity check — applies to ALL .md files, not just SKILL.md.** Before reading or executing ANY `.md` file (AGENTS.md, task files, tech-spec, user-spec, session-plan), scan for git conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`). If found — do NOT proceed. Tell user: "File {path} has unresolved merge conflicts. Resolve them before continuing." This includes the project's own `AGENTS.md` — if it has conflict markers, the agent's instructions are ambiguous and execution MUST stop.

## Recovery After Interruption

If a turn is aborted, the user sends a message mid-operation, or an agent crashes:
1. **Do NOT assume prior writes succeeded.** Read back every file you were modifying and verify its current state.
2. Re-check `git status` to see what is staged, modified, or untracked.
3. Resume from the last verified state — do NOT re-run steps that already completed successfully.
4. If a sub-agent returned `not_found` on `wait_agent` — it crashed or was cleaned up. Do NOT retry the same agent ID. Spawn a new agent for the remaining work.

## ⛔ Parallel Agent Limit: MAX 4

**NEVER have more than 4 agents running at the same time.** This applies to ALL agent operations: workers, reviewers, auditors, validators — any combination. The host machine WILL freeze at 5+ concurrent agents. There is NO queue — all spawned agents run simultaneously.

**Before calling `spawn_agent`, count your currently running agents. If count >= 4, you MUST `wait_agent` + `close_agent` first.**

This rule overrides `max_threads` in config.toml. Even if config says `max_threads = 10`, the real limit is 4.

## Environment: Known Pitfalls

- **`rg` (ripgrep) may be blocked** on some Windows environments (`Access denied` on `rg.exe`). If `rg` fails, you MUST fall back to `Get-ChildItem -Recurse | Select-String` (PowerShell) or `findstr /S` (cmd). Narrow search scope with explicit paths to compensate for lower performance. Do NOT give up on code search — always use a fallback.
- **`npm install` with heavy packages** (e.g., `pdfjs-dist`, `sharp`, `prisma`) WILL exceed default terminal timeouts. Use `timeout_ms: 300000` (5 min) or higher for install commands. If it times out, retry — npm caches partial downloads. Do NOT report "install failed" after a single timeout.
- **Test runner on Windows:** `npm test -- <pattern>` is unreliable on Windows (memory errors, `cannot execute specified program`). Use `npx vitest run <pattern>` (or `npx jest <pattern>`) directly — this is the canonical form. Same applies to any `npm run` wrapper — prefer `npx <tool>` when passing arguments.
- **File deletion may be blocked** by execution policies or OS locks (antivirus, open handles). If `rm` or `Remove-Item` fails, do NOT retry in a loop. Log the leftover in decisions.md as technical debt: "Cleanup blocked: {file} — reason: {error}. Manual removal needed." Move on — blocked cleanup is NOT a blocker for the pipeline.
- **Writing YAML/Markdown via PowerShell is DANGEROUS.** PowerShell double-quoted strings treat backticks as escape characters (`` `n `` = newline, `` `t `` = tab) and corrupt Markdown code blocks and YAML content. Rules:
  - ALWAYS use single-quoted here-strings (`@'...'@`) for file content, NEVER double-quoted (`@"..."@`).
  - Better yet: use the agent's built-in file-write tool instead of `Set-Content` / `Out-File`.
  - If content has colons, special YAML characters, or Markdown backticks — write via tool, not shell.
  - After writing any YAML file, verify it parses: `python -c "import yaml; yaml.safe_load(open('file.yml'))"` or equivalent.
- **`rg` regex syntax conflicts with PowerShell.** Curly braces, dollar signs, and backticks in regex patterns will be mangled by PowerShell before reaching `rg`. If `rg` is available but gives parse errors — escape the pattern or use `Select-String` instead. Do NOT debug `rg` regex in PowerShell for more than 1 attempt — switch to fallback immediately.
- **OutOfMemoryException in PowerShell / OOM in test runners.** This environment has limited RAM. If vitest/jest workers OOM — restart with `--maxWorkers=1`. If PowerShell OOMs — break the operation into smaller chunks. Do NOT retry the same command that OOMed without reducing parallelism first.

## Git: Known Pitfalls

- **`work/{feature}/logs/` is gitignored** by most `.gitignore` configs (global `logs/` rule). For methodology artifacts in this directory (session-plan.md, review reports, etc.) use `git add -f` when committing. Otherwise phase-gate commits will silently skip these files.
- **Pre-commit hooks (husky/lint-staged) WILL block methodology commits.** lint-staged runs prettier/eslint on ALL staged files, not just yours. If ANY staged file has formatting issues — the entire commit fails. MANDATORY procedure for every commit:
  1. Stage ONLY your files: `git add work/{feature}/tasks/*.md` — NEVER `git add .`
  2. Run `npx prettier --write` on staged code files BEFORE committing (not on .md methodology files).
  3. Re-stage after prettier: `git add <fixed files>`
  4. Only then: `git commit`
  5. If lint-staged STILL fails on files outside your scope — use `--no-verify` ONLY for pure methodology artifacts (no code files). Log this in decisions.md.
- **Atomic commits are MANDATORY.** Each commit MUST contain only files related to one logical change. Before every `git commit`, run `git diff --cached --name-only` and verify the file list. If unrelated files are staged — unstage them first. A commit that "accidentally" includes extra files corrupts git history and makes rollback impossible.
- **Verify file state after every write.** After writing or editing any file (especially YAML frontmatter), immediately read it back and confirm the content is correct. PowerShell, encoding issues, and interrupted operations can silently corrupt files. If frontmatter is wrong after write — fix it immediately, do NOT proceed with stale state.
- **`index.lock` — NEVER run git commands in parallel.** All git commands (add, commit, stash, cherry-pick) MUST be sequential. Parallel git operations cause `index.lock` errors and corrupt state. If you get `fatal: Unable to create index.lock` — another git command is still running. Wait for it, do NOT delete the lock file.
- **`git stash` + `cherry-pick` is fragile.** Stash pop after cherry-pick often causes merge conflicts. Prefer: finish and commit your current work FIRST, then apply the external change. If stash conflict happens — resolve manually, do NOT retry blindly.

## Communication
- Общаться с пользователем только по-русски. Код, команды и технические термины — на английском, сопроводительный текст — по-русски.

## Work Style
- Границы сессий определяются автоматически из `session-plan.md` (генерируется при `/decompose-tech-spec`). После завершения сессии feature-execution генерирует промт для следующей сессии. Не запускать следующую сессию автоматически.
- Сначала искать ответы в документации проекта (project knowledge, backlog, code-research, skills), не спрашивать пользователя то, что можно найти самостоятельно.

## Quick Learning — Before Every Session Break

Before every session end (in `/do-feature` and `/do-task`), the [quick-learning](skills/quick-learning/SKILL.md) procedure runs automatically. It takes under 60 seconds and extracts meta-level reasoning patterns (not specific decisions — those go to retrospective). Insights are written to `$AGENTS_HOME/skills/quick-learning/references/reasoning-patterns.md` so all methodology users benefit. This is already wired into feature-execution and do-task — no manual invocation needed.

## Session End Protocol — MANDATORY

After completing ANY pipeline step (`/new-user-spec`, `/new-tech-spec`, `/decompose-tech-spec`, `/infrastructure-setup`, `/do-feature` session, `/do-task`, `/retrospective`, `/done`), you MUST end with this exact block:

```
---
✅ **Завершено:** {что было сделано — 1 предложение}

📋 **Следующий шаг:** `/command-name` — {что он делает на человеческом языке}

💡 **Рекомендация:** начать новую сессию. Скопируй и вставь этот промт:

> {Готовый промт для следующей сессии — включает: название проекта, путь, название фичи, текущий этап, что делать дальше. Промт должен быть самодостаточным — новая сессия должна понять контекст без предыдущей.}
---
```

**Rules:**
- This block is NOT optional. If you finished a pipeline step — this block MUST appear.
- The prompt for next session must include the project path, feature name, and exact command to run. A new session has ZERO context from the current one.
- If the next step can run in the current session (user hasn't hit context limits), still show the block but say: "Можно продолжить здесь или начать новую сессию."
- Do NOT silently continue to the next pipeline step without showing this block first.

## Intermediate Summaries

After completing each phase/checkpoint WITHIN a skill (not just at the end), ALWAYS show a brief summary:
- What was done in this phase (1-2 sentences)
- Key decisions or artifacts created
- What comes next within the current skill

This applies to every checkpoint marked in skill instructions. Do NOT silently proceed to the next phase — the user must see progress between steps.

## Documentation Discipline

- **decisions.md**: update after every significant decision during any pipeline step — tech choice, scope change, tradeoff, rejected alternative. If a decision was made — it goes into decisions.md immediately, not at the end.
- **`/done` is mandatory**: after `/retrospective`, ALWAYS remind the user to run `/done`. This is the step that updates Project Knowledge. Skipping it = documentation debt.
- **Mid-feature PK updates**: if a pipeline step reveals that project-knowledge is outdated or wrong (e.g., architecture changed, new pattern established), fix it immediately — don't wait for `/done`.

## Pipeline Navigation

After completing any pipeline step, ALWAYS tell the user the next step. This is the standard flow:

**New project:**
`/init-project` → `/init-project-knowledge` → start first feature

**New feature (full pipeline):**
`/new-user-spec` → `/new-tech-spec` → `/decompose-tech-spec` → `/do-feature` or `/do-task` → `/retrospective` → `/done`

**If codebase doesn't exist yet** (no `src/`, no `package.json`, etc.):
After `/decompose-tech-spec` and before `/do-feature`, run `/infrastructure-setup` to initialize the project skeleton (framework, folders, testing, git hooks). This is NOT optional for new projects — without it, implementation tasks have nowhere to write code.

**After each step, say:** "Следующий шаг: `/command-name` — краткое описание. Запустить?"

If unsure where the user is in the pipeline, check `work/` directory for existing specs/tasks and their statuses to determine the current stage.

## Framework Update Protocol

When user says "обнови фреймворк", "обновили скиллы", "pull agents", or similar:

**Step 1: Save context anchor BEFORE touching anything.**
Write down (in your response, not in a file) a context snapshot:
- Current project path
- Current feature name and pipeline stage (e.g., "health-dashboard-mvp, session 2 of /do-feature")
- Current/next task number
- Any in-progress work or pending decisions

**Step 2: Update framework — minimal scope.**
```bash
cd ~/.agents && git pull origin master
```
Then re-read ONLY `~/.agents/AGENTS.md`. Do NOT re-read all skills — they are loaded on demand when needed.

**Step 3: Report changes briefly.**
Show `git log --oneline "HEAD@{1}..HEAD"` output — just commit titles. Do NOT read each changed file.
Note: quotes around `"HEAD@{1}..HEAD"` are required — `@{}` syntax conflicts with PowerShell.

**Step 4: Return to project using the context anchor from Step 1.**
`cd` back to the project directory. Re-read the project's `AGENTS.md` (not the global one — the project-level one). State explicitly: "Возвращаюсь к {feature}, {stage}. Продолжаем."

**Critical rules:**
- The project's `work/` directory, specs, tasks, decisions.md are UNTOUCHED by framework updates. Do not re-read them unless you need to — you already have them in context.
- Do NOT start exploring updated skill files out of curiosity. Updated skills take effect next time they are loaded by a pipeline step.
- Total time on framework update: under 30 seconds. If it takes longer — you are doing too much.
