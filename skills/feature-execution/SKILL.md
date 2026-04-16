---
name: feature-execution
description: |
  Orchestrate feature delivery by waves: spawn workers, run reviewers,
  manage review cycles (max 3 rounds), commit per wave.

  Use when: "выполни фичу", "do feature", "execute feature", "запусти фичу",
  "выполни все задачи", "execute all tasks"
---

# Feature Execution

Orchestrate work as a single coordinator. Use `spawn_agent`, `wait_agent`, `send_input`, `close_agent`.
Do not rely on team APIs or direct agent-to-agent messaging.

**Required Codex config** (`~/.codex/config.toml`):
```toml
[agents]
max_threads = 10                    # parallel workers per wave
max_depth = 2                       # worker (depth 1) can spawn reviewer (depth 2)
job_max_runtime_seconds = 3600      # 1 hour for large waves
```

Before starting, read [quick-ref.md](../quick-learning/references/quick-ref.md) — top reasoning patterns from past sessions (~7 lines, if file exists and non-empty).

## Model Profiles

Use model tiers from [model-profiles.md](../tech-spec-planning/references/model-profiles.md):
- Worker default: `tier_high` (`gpt-5.4`)
- Reviewer default: `tier_medium` (`gpt-5.3-codex`)
- Cheap routine work: `tier_low` (`gpt-5.4-mini`, `reasoning_effort: low`)
- **No fallbacks.** If a model is unavailable — STOP and tell user. Do NOT auto-switch.

## Phase 0: Pre-flight Checks — BLOCKING GATE

Before any execution, verify the pipeline was followed correctly:

1. Read `work/{feature}/tech-spec.md`. Check frontmatter `status: approved`.
   - If not → **STOP**: "Tech-spec не утверждён. Сначала `/new-tech-spec`."
2. Read `work/{feature}/logs/session-plan.md`.
   - If missing → **STOP**: "Session plan отсутствует. Сначала `/decompose-tech-spec`."
   - If frontmatter `status` is not `approved` → **STOP**: "Session plan не утверждён. Сначала `/decompose-tech-spec` и подтверди план сессий."
3. Read all task files in `work/{feature}/tasks/`. If no tasks exist → **STOP**: "Задачи не созданы. Сначала `/decompose-tech-spec`."
4. Verify at least one task has `status: planned`. If all tasks are `done` → inform user, stop.
5. **Codebase readiness check:** collect unique file paths from "Files to modify" across current session's tasks. Check that base directories exist (e.g., `src/`, `tests/`, `package.json` or equivalent). If key directories are missing → **STOP and redirect**: "Кодовая база не найдена (нет `src/`, `package.json`). Для нового проекта сначала запусти `/infrastructure-setup` — он создаст скелет проекта по tech-spec. После этого вернись к `/do-feature`." Do NOT proceed into session scope confirmation with a missing codebase. Do NOT ask user "where is the code?" — if there is no code, the answer is `/infrastructure-setup`.
6. **Skill file integrity check:** verify that this SKILL.md and the shim entry-point (`do-feature/SKILL.md`) contain no git conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`). If found → **STOP**: "В файле скилла обнаружен merge-конфликт. Исправь вручную перед запуском."
7. **Dependency health check:** if `package.json` (or equivalent) exists, run `npm run build` (or the project's build command). If build fails → **STOP and fix** before proceeding. This catches type errors, broken imports, and stale dependencies BEFORE any feature work starts. Common after dependency upgrades between sessions.
8. **Dependency scope check:** if the current session's tasks require new libraries not yet in `package.json`, install them NOW and re-run build. Use `timeout_ms: 300000` for heavy packages. Do NOT discover missing dependencies mid-wave.
9. **Artifact sync check:** scan all task files in `work/{feature}/tasks/`. For each task from PREVIOUS sessions (sessions before the current one), verify its `status` matches reality:
   - If task files it was supposed to create/modify exist and work → status MUST be `done`.
   - If status is still `planned` or `in_progress` but the work is clearly done → fix status to `done` NOW.
   - Log every correction in decisions.md: "Synced task-{N} status: {old} → done (work was completed in session {M})."
   - This prevents false pre-flight failures from stale statuses left by previous sessions.

> **Do NOT proceed if any pre-flight check fails.** These checks ensure the user approved each prior stage and the workspace is ready for execution.

## Phase 1: Initialization

1. Read `work/{feature}/user-spec.md`.
2. Read all task frontmatters in `work/{feature}/tasks/`:
   - `status`, `wave`, `depends_on`, `skills`, `reviewers`, `verify`, optional `worker_name`.
3. Read `work/{feature}/logs/session-plan.md`. Determine current session number (from checkpoint or first incomplete session).
4. Build execution plan from `$AGENTS_HOME/shared/work-templates/execution-plan.md.template`.
5. Save plan to `work/{feature}/logs/execution-plan.md`.

### Session Scope Confirmation — BLOCKING GATE

Present session boundaries to user before any code:

```
## Запуск сессии {N} из {total}

### Границы этой сессии
| # | Задача | Wave | estimated_loc |
|---|--------|------|---------------|
| 3 | ... | 2 | 300 |
| 4 | ... | 2 | 250 |

**Суммарный LOC бюджет:** ~{sum_loc} из ~1200 лимита
**Waves:** {wave_start}-{wave_end}
**Scope:** {краткое описание что будет сделано}
**Риски:** {если есть — зависимости от предыдущих сессий, сложные интеграции}

Подтверждаешь запуск сессии {N}? (да/нет)
```

Wait for explicit **"да"**. Do NOT start execution without it.

> If user requests changes to session boundaries (move tasks, split differently) — update session-plan.md, re-present, wait for new approval.

6. Initialize/update `work/{feature}/logs/checkpoint.yml` with `total_waves`, `current_session`, `total_sessions`.

## Phase 2: Execute Wave

### ⛔ HARD LIMIT: NEVER spawn more than 4 agents at the same time.

This is a NON-NEGOTIABLE environment constraint. Violating it WILL freeze the host machine, crash agents, or cause silent failures. There is NO queue — excess agents run simultaneously and kill the system.

**Before EVERY `spawn_agent` call, count currently running agents.** If count >= 4 — STOP. Wait for running agents to finish and close them BEFORE spawning new ones.

**Batching is MANDATORY when total agents > 4:**
- Count all agents needed for this wave (workers + reviewers).
- Split into batches of max 4: Batch 1 → spawn, wait, close ALL. Batch 2 → spawn, wait, close ALL.
- Do NOT spawn batch 2 while any agent from batch 1 is still running.
- Log batch plan in decisions.md: "Wave {W}: {total} agents needed, limit 4, running in {B} batches."

**Examples of what is FORBIDDEN:**
- 5 workers at once ❌ (split: 4 + 1)
- 3 workers + 2 reviewers at once ❌ (split: 3 workers → close → 2 reviewers)
- "I'll spawn 6 and they'll queue" ❌ — there is no queue, it will freeze the machine

1. Select tasks for current wave: `status: planned` and dependencies done.
2. **File existence AND path naming check — MANDATORY before starting any worker.** For each selected task:
   - Verify target files/directories from "Files to modify" exist. If listed as "modify" but missing — worker MUST **create** them from scratch. Log in decisions.md: "Created {path} from scratch — tech-spec listed as modify but file didn't exist."
   - **Check path naming matches reality.** Tech-specs often use camelCase (`storageMigrations/`) while actual code uses kebab-case (`storage-migrations/`). Compare EVERY path in the task against the real filesystem. If naming diverges — use the REAL path, log deviation in decisions.md: "Path deviation: spec says {spec-path}, actual is {real-path}. Using actual."
   - Do NOT create a new file at the spec path if a file with the same purpose exists at a different-cased path — that creates duplicates.
3. Set each selected task to `in_progress`.
4. For each task, run worker flow (respect parallel agent limit — batch if needed):
   - Spawn worker (`agent_type: worker`, model from `tier_high`).
   - Pass task path and feature context files.
   - Worker performs implementation and local verification, then reports:
     - modified files
     - commits made
     - unresolved risks
   - **Close worker agent** after collecting results — free the slot for next batch.
5. Review flow per task (if `reviewers` not empty):
   - Coordinator gets `git diff` for task changes.
   - Spawn reviewer agents in parallel (`tier_medium`), respecting agent limit — batch if needed:
     - task path
     - spec paths
     - changed files list
     - diff text
     - output path: `logs/working/task-{N}/{reviewer}-round{R}.json`
   - Collect reports, **close reviewer agents**, apply valid findings, rerun tests.
   - Repeat up to 3 rounds.
6. If `reviewers` is empty, mark task self-verified after worker checks.
7. Ensure worker writes a concise decisions entry to `work/{feature}/decisions.md`.

## Audit Wave

Audit Wave tasks use `reviewers: []` and run as independent auditors:
- Code audit (`code-reviewing`)
- Security audit (`security-auditor`)
- Test audit (`test-master`)

Spawn all auditors in parallel (`tier_high`).
If findings exist, spawn a fixer worker (`tier_high`) and re-run only affected auditors as reviewers (`tier_medium`), max 3 rounds.

**When Audit Wave is in a different session:** If session-plan.md places the Audit Wave in a later session (e.g., final session), do NOT run it in the current session. Record in decisions.md: "Audit wave (code-reviewer, security-auditor, test-reviewer): not run — scheduled for session {N}." This is expected behavior, not a failure.

**Post-audit hardening — STRICT SCOPE RULE.** After audit findings are fixed, do NOT expand scope beyond what the audit flagged. Specifically:
- Fix ONLY the risks identified by auditors (security holes, missing error handling, test gaps for existing code).
- Do NOT add "nice to have" improvements, refactoring, or features "while we're here".
- If audit says "add integration test for X" — add that test only, do NOT expand the test suite broadly.
- If audit says "add input validation" — validate that input only, do NOT redesign the validation layer.
- Log every fix in decisions.md with the audit finding it addresses. If a fix has no matching finding — it's scope creep, remove it.

## Phase 3: Wave Transition

1. Verify decisions entries exist and include verification results.
2. Update tasks `in_progress` -> `done` (or `done_with_concerns` if worker reported concerns — preserve the `concerns:` field from decisions.md entry into task frontmatter).
3. Commit status/decision updates:
   - **Stage logs/ artifacts explicitly** (they are gitignored by the global `logs/` rule):
     ```bash
     git add -f work/{feature}/logs/checkpoint.yml
     git add -f work/{feature}/logs/execution-plan.md
     ```
   - `chore: complete wave {N} — update task statuses and decisions`
   - **If commit fails** (pre-commit hooks, formatting, lint): fix the issue (`npx prettier --write .`, re-stage), retry. Do NOT leave wave in `docs-synced / commit-pending` state — the commit MUST succeed before moving on. If stuck after 3 attempts, commit with `--no-verify` and log in decisions.md: "Pre-commit bypassed for wave {N} — reason: {what failed}."
4. Update checkpoint:
   - `last_completed_wave`, `next_wave`, task statuses.
5. **Session boundary check** — read session-plan.md, determine if current wave is last in current session.

### If waves remain in current session → continue to next wave.

### If current wave is last in current session → SESSION END PROTOCOL (HARD STOP)

> **This is a HARD STOP. Do NOT continue to the next session. Do NOT start the next wave.**

**Step 0: Quick Learning (subagent, background).** Spawn a subagent to run [quick-learning](../quick-learning/SKILL.md). Pass it: feature path, current session number, path to decisions.md. The subagent runs in the **background** while you proceed with Step 1. When it finishes, show the user its one-line summary. Do NOT read the quick-learning SKILL.md yourself — the subagent loads it independently in its own context.

**Step 1: Session Report.** Present to user:

```
## Отчёт по сессии {N} из {total}

### Что сделано
- Задача {X}: {краткое описание} ✅
- Задача {Y}: {краткое описание} ✅

### Что не сделано
- (если есть незавершённые задачи или отложенные проверки)

### Проверки и результаты
- Тесты: {pass/fail, количество}
- Ревью: {раунды, ключевые findings}
- Smoke-верификация: {результаты}

### Риски и замечания
- (если есть — технический долг, открытые вопросы, блокеры)
```

**Step 2: Sync documentation artifacts.** Before generating handoff:

1. **decisions.md** — verify all tasks completed in this session have entries. If any entry is missing or incomplete, write it now. Each entry must include: what was done, verification results, risks/trade-offs.
2. **Task files** — verify every task touched in this session has correct frontmatter:
   - Completed tasks: `status: done`
   - Incomplete tasks: `status: in_progress` with note explaining what remains
   - Checklists in task body: all completed items checked off
3. **tech-spec.md** — update Implementation Tasks checkboxes (`- [ ]` → `- [x]`) for all completed tasks.
4. **checkpoint.yml** — update with current state.
5. Git commit (stage logs/ artifacts explicitly — they are gitignored by the global `logs/` rule):
   ```bash
   git add -f work/{feature}/logs/checkpoint.yml
   git add -f work/{feature}/logs/execution-plan.md
   ```
   `chore: sync docs for session {N} — decisions, task statuses, tech-spec checkboxes`

> Do NOT skip this step. Documentation drift is a real problem — if docs are not synced, the next session starts with stale context.

**Step 3: Next Session Prompt.** Generate from `$AGENTS_HOME/shared/work-templates/session-prompt.md.template`. Save to `work/{feature}/logs/next-session-prompt.md`.

**Step 4: Present handoff package.** Show user:

```
Сессия {N} из {total} завершена. Отчёт выше.

Документация синхронизирована:
- decisions.md: {N} записей обновлено
- Задачи: статусы актуальны
- tech-spec: чеклисты обновлены

## Дальше по общему плану

Следующая сессия: {N+1} из {total} — "{session_title}"
Задачи: {task_list} (waves {wave_start}-{wave_end})
Estimated LOC: ~{loc}
{если последняя сессия — "Это финальная сессия (Audit + QA)."}
{если нужно что-то от пользователя — "Требуется от тебя: {что именно}"}

Скопируй этот промт для старта следующей сессии:

---
{generated prompt content}
---

⚠️ Следующая сессия НЕ начнётся, пока ты явно не запустишь её.
```

**Step 5: STOP.** Do not execute any more waves, tasks, or code. Wait for user to start a new session with the provided prompt.

Git commit (force-add logs/ artifacts):
   ```bash
   git add -f work/{feature}/logs/checkpoint.yml
   git add -f work/{feature}/logs/next-session-prompt.md
   ```
   `chore: complete session {N} — checkpoint and handoff prompt`

## Phase 4: User Review

1. Show built scope, key decisions, QA summary.
2. Ask user for manual checks listed in execution plan.
3. If issues found, run fix/review loop (max 3 rounds).
4. When approved:
   - close active agents,
   - delete `work/{feature}/logs/checkpoint.yml`.

## Escalation

Escalate to user when:
- 3 fix rounds exhausted
- requirement ambiguity blocks implementation
- required external service/tool is unavailable

On escalation:
1. Stop blocked task.
2. Report attempts and unresolved items.
3. Write decisions entry.
4. Commit: `chore: escalate task {N} — unresolved after 3 fix rounds`.

## Self-Verification

- [ ] Execution plan approved
- [ ] All tasks executed with required reviews
- [ ] All waves committed
- [ ] User review complete
