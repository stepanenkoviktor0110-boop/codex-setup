---
name: do-task
description: |
  Execute task from tasks/*.md with quality gates.

  Use when: "выполни задачу", "сделай таску", "do task", "execute task", "запусти задачу"
---

# Do Task

Execute a spec-driven task with validation and status tracking.

## Step 0: Pre-flight Checks

1. Determine feature path from task file location (`work/{feature}/tasks/{N}.md`).
2. Check `work/{feature}/logs/session-plan.md` exists and has `status: approved` in frontmatter.
   - If missing or not approved → **STOP**: "Session plan не утверждён. Сначала `/decompose-tech-spec` и подтверди план сессий."
3. Check that the requested task belongs to the current session (compare with session-plan.md).
   - If task is in a future session → **WARN**: "Задача {N} относится к сессии {M}, текущая сессия — {K}. Выполнить досрочно? (да/нет)"
4. **Codebase readiness:** check that directories from task's "Files to modify" exist (e.g., `src/`, `tests/`, `package.json` or equivalent). If missing → **STOP and redirect**: "Кодовая база не найдена. Сначала запусти `/infrastructure-setup`. После этого вернись к `/do-task`." Do NOT ask user where the code is.
5. Present scope confirmation before starting:

   ```
   Задача {N}: {title}
   Сессия: {session_num} из {total}
   estimated_loc: ~{loc}
   Оставшийся LOC бюджет сессии: ~{remaining} из ~1200

   Подтверждаешь запуск? (да/нет)
   ```

   Wait for explicit **"да"**.

## Step 1: Read Task

1. Read task file (user provides path or task number)
   - If user didn't specify → ask: "Which task to execute?"
2. Verify task status is `planned` (if not → ask user before proceeding)
3. Update task frontmatter: `status: planned` → `status: in_progress`
4. Read every file listed in the task's "Context Files" section

## Step 2: Execute

1. Load each skill listed in the task (frontmatter `skills: [...]` and "Required Skills" section)
   - If a skill is not found → warn user, continue with remaining skills
   - If task has no skill (frontmatter `skills: []` or absent) → read the task, execute "What to do" and "Verification Steps" directly. For tasks with user instructions → show the instruction to user, wait for confirmation.
2. Follow loaded skill workflow
3. Git commit implementation (code + tests pass): `feat|fix|refactor: task {N} — {brief description}`
4. **Design review hook** — if `.design-system/tokens.json` exists in the project AND the task changed UI files (`.tsx`, `.vue`, `.html`, `.css`, `.scss`): spawn `design-review` subagent on changed UI files. If either condition is false — skip silently. This hook calls ONLY design-review, not the full design pipeline.
5. For each reviewer from the task's "Reviewers" section (if present):
   1. Spawn subagent via spawn_agent tool (agent_type = reviewer name, e.g. `code-reviewer`)
   2. Pass: git diff of changes, path to task file, path to tech-spec, path to user-spec
   3. Reviewer loads its own skill automatically (via agent frontmatter `skills:`)
   4. Report is written to the path specified in the task's "Reviewers" section
   5. Read report. If findings exist → fix, re-run tests, git commit: `fix: address review round {N} for task {N}`, repeat (max 3 rounds)

## Step 3: Verify

1. Check each acceptance criterion from task file
2. If task has "Verification Steps → Smoke" → execute each smoke command, record results in decisions.md Verification section
3. If task has "Verification Steps → User" → ask user to verify, wait for confirmation
4. If any verification fails → fix → re-run tests → re-run reviewers (new round) → re-verify
   - After 3 failed rounds → stop, report failures to user, keep status `in_progress`
   - Tool unavailable → document, suggest manual check

## Step 4: Complete

1. Read template `$AGENTS_HOME/shared/work-templates/decisions.md.template` and write a concise execution report to `work/{feature}/decisions.md`. Follow template format strictly — no extra sections. Use Planned/Actual/Deviation structure.
2. Update task frontmatter: `status: in_progress` → `status: done` (or `done_with_concerns` + fill `concerns:` field if something worries you — performance risk, edge case not covered, code smell that passed review, tech debt introduced). Use `done_with_concerns` when the task works but you have reservations. Retrospective will prioritize these.
3. Update tech-spec: `- [ ] Task N` → `- [x] Task N`
4. Git commit: `chore: complete task {N} — update status and decisions`
5. **Session boundary check** (skip if `work/{feature}/logs/session-plan.md` does not exist):
   Read session-plan.md. Find which session this task belongs to.

   **If tasks remain in current session:**
   Inform user which tasks are left: "В текущей сессии осталось: задачи {list}."

   **If this task is the last task of current session → SESSION END PROTOCOL (HARD STOP):**

   > **This is a HARD STOP. Do NOT pick up the next task. Do NOT continue to the next session.**

   **a0. Quick Learning (subagent, background).** Spawn a subagent to run [quick-learning](../quick-learning/SKILL.md). Pass it: feature path, current session number, path to decisions.md. The subagent runs in the **background** while you proceed with step (a). When it finishes, show the user its one-line summary. Do NOT read the quick-learning SKILL.md yourself — the subagent loads it independently in its own context.

   a. Present session report:
      ```
      ## Отчёт по сессии {N} из {total}

      ### Что сделано
      - Задача {X}: {краткое описание} ✅

      ### Что не сделано
      - (если есть)

      ### Проверки и результаты
      - Тесты: {pass/fail}
      - Ревью: {раунды, findings}

      ### Риски и замечания
      - (если есть)
      ```

   b. **Sync documentation artifacts** (do NOT skip):
      - Verify `decisions.md` has entries for all tasks completed in this session
      - Verify all completed task files have `status: done` and checklists checked off
      - Update `tech-spec.md` checkboxes (`- [ ]` → `- [x]`) for completed tasks
      - Update `checkpoint.yml` with current state
      - Git commit: `chore: sync docs for session {N} — decisions, task statuses, tech-spec checkboxes`

   c. Generate next-session prompt from `$AGENTS_HOME/shared/work-templates/session-prompt.md.template`.
      Save to `work/{feature}/logs/next-session-prompt.md`.

   d. Present handoff:
      ```
      Сессия {N} из {total} завершена. Отчёт выше.

      Документация синхронизирована:
      - decisions.md: записи актуальны
      - Задачи: статусы обновлены
      - tech-spec: чеклисты обновлены

      ## Дальше по общему плану

      Следующая сессия: {N+1} из {total} — "{session_title}"
      Задачи: {task_list} (waves {wave_start}-{wave_end})
      Estimated LOC: ~{loc}
      {если последняя — "Это финальная сессия (Audit + QA)."}
      {если нужно от пользователя — "Требуется от тебя: {что именно}"}

      Скопируй этот промт для старта следующей сессии:

      ---
      {generated prompt content}
      ---

      ⚠️ Следующая сессия НЕ начнётся, пока ты явно не запустишь её.
      ```

   e. Git commit: `chore: complete session {N} — checkpoint and handoff prompt`
   f. **STOP.** Do not execute any more tasks.

## Self-Verification

- [ ] Task status is `done`
- [ ] Tech-spec checkbox updated
- [ ] decisions.md entry written with reviews and verification results
- [ ] Git commit created with task reference
- [ ] Every acceptance criterion from task file is met
- [ ] Session boundary check performed (if session-plan exists)
- [ ] If session ended: report + handoff prompt presented, execution stopped
