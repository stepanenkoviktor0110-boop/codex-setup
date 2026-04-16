---
name: task-decomposition
description: |
  Decompose approved tech-spec into atomic task files with parallel creation and validation.

  Use when: "разбей на задачи", "декомпозиция", "decompose tech-spec",
  "создай задачи из техспека", "/decompose-tech-spec"
---

# Task Decomposition

Decompose tech-spec Implementation Tasks into individual task files with parallel creation and validation.

**Input:** `work/{feature}/tech-spec.md` (status: approved)
**Output:** `work/{feature}/tasks/*.md` (validated)
**Language:** Task files in English, communication in Russian

Before starting, read [quick-ref.md](../quick-learning/references/quick-ref.md) — top reasoning patterns from past sessions (if file exists and non-empty).

## Phase 0: Scope Estimation

Before creating tasks, present the user a structural plan:

1. Read tech-spec Implementation Tasks section.
2. Estimate total lines of code for the feature.
3. **Break down into blocks of ~1200 lines (±300)**, each block into **steps of ~300 lines (±100)**.
4. Present the plan as a table: blocks → steps with line estimates.
5. Get user confirmation before proceeding to task creation.

This ensures predictable scope, manageable task sizes, and clear progress tracking. Each "step" typically maps to one task file. Each "block" maps to a wave or a group of related tasks.

**Important:** Save LOC estimates per task — they will be used in Phase 4 (Session Planning). Pass `estimated_loc` to each task-creator in Phase 1.

## Phase 1: Create Tasks

1. Ask user for feature name if not provided.

2. Read `work/{feature}/tech-spec.md`. Check frontmatter `status: approved`.
   If not approved — tell user: "tech-spec не утверждён. Сначала запусти `/new-tech-spec` и доведи до approved." Stop.

3. Read `work/{feature}/user-spec.md`.

4. Note the task template path: `$AGENTS_HOME/shared/work-templates/tasks/task.md.template`

5. Read skills/reviewers catalog from [skills-and-reviewers.md]($AGENTS_HOME/skills/tech-spec-planning/references/skills-and-reviewers.md) — for passing correct skills/reviewers to task-creators.

6. For each task in Implementation Tasks — launch [`task-creator`]($AGENTS_HOME/agents/task-creator.md) subagent in parallel.
   Pass each task-creator:
   - feature_path, task_number, task_name
   - template_path: `$AGENTS_HOME/shared/work-templates/tasks/task.md.template`
   - files_to_modify, files_to_read (from tech-spec)
   - depends_on, wave, skills, reviewers, verify (from tech-spec)
- worker_name (if specified in tech-spec, optional)
   Each task-creator copies the template to `tasks/{N}.md` first, then edits each section in place. This ensures no sections are skipped.

7. Confirm each task-creator returned a file path. Skip reading task content — preserve context budget for validation phase.
8. Git commit: `draft(tasks): create {N} tasks from tech-spec for {feature}`

**Checkpoint:**
- [ ] All `tasks/*.md` files created
- [ ] Each task-creator returned file path
- [ ] Draft committed

## Phase 2: Validation (up to 3 iterations)

Tech-spec was already validated by 5 validators. This phase checks only: (1) task-creator correctly expanded tasks by template, (2) no mismatches with real code appeared during detailing.

### Validators

Launch both in parallel:

[`task-validator`]($AGENTS_HOME/agents/task-validator.md) (gpt-5.4-mini) — Template Compliance + AC/TDD carry-forward:
- Batch: 5 tasks per call
- Pass: feature_path, task_numbers array, batch_number, iteration
- Report: `logs/tasks/template-batch{N}-review.json`

[`reality-checker`]($AGENTS_HOME/agents/reality-checker.md) (gpt-5.4-mini) — Reality & Adequacy:
- Batch: 3 tasks per call
- Pass: feature_path, task_numbers array, batch_number, iteration
- Report: `logs/tasks/reality-batch{N}-review.json`

### Process

1. Launch both validators in parallel (task-validator in batches of 5, reality-checker in batches of 3).
2. Read JSON reports, collect findings.
3. If issues found — for each task with issues, launch [`task-creator`]($AGENTS_HOME/agents/task-creator.md) in fix mode:
   - Pass: same inputs as creation + `mode: fix` + `findings` from validators
   - task-creator reads existing task, applies fixes, overwrites file
4. After each validation round, git commit: `chore(tasks): validation round {N} — {summary}`
5. Re-validate fixed tasks (repeat 1-4). Maximum 3 iterations.
6. If problems remain after 3rd iteration — show user: "Вот что осталось — давай решим вместе."

### Cross-Task Integration Check

After individual validation passes, run a final cross-task check:

1. **depends_on vs wave consistency — MANDATORY check.** For every task, verify: if `depends_on` lists task X, then task X MUST be in an earlier wave (lower wave number). A task CANNOT depend on another task in the same wave — same-wave tasks run in parallel and cannot guarantee execution order. If found — move the dependent task to the next wave or remove the dependency. This check is non-negotiable.

2. Launch both validators on ALL tasks in a single batch (not split into smaller batches):
   - `task-validator` — focus: shared resource ownership (one owner, consumers depend_on owner), no competing instances in same wave, **depends_on vs wave conflicts**
   - `reality-checker` — focus: duplicate heavy resource init, hidden dependencies, inconsistent approaches across tasks

3. If issues found → launch `task-creator` in fix mode for affected tasks. Re-validate fixed tasks.

4. Max 2 iterations for cross-task check (on top of the 3 individual iterations).

**Checkpoint:**
- [ ] Both validators: status=approved OR user resolved remaining issues
- [ ] Cross-task integration check: no cross-task conflicts

## Phase 3: Present to User — BLOCKING GATE

> **HARD STOP.** Do NOT proceed to Session Planning until user gives explicit approval.

1. Present summary as a table:

   | # | Task | Wave | depends_on | estimated_loc | Description |
   |---|------|------|------------|---------------|-------------|
   | 1 | ... | 1 | — | 200 | ... |

2. Show totals: task count, total estimated LOC, wave count, validation results (iterations, issues found/fixed).
3. Ask user explicitly: **"Декомпозиция готова. Подтверждаешь задачи? (да/нет/правки)"**
4. Wait for one of:
   - **"да"** → proceed to Phase 4
   - **"нет"** / corrections → apply changes, re-validate affected tasks, re-present
   - No response → do NOT proceed. Remind user that approval is required.
5. Only after explicit approval: Git commit `chore(tasks): task decomposition approved for {feature}`

**Checkpoint:**
- [ ] Summary table presented to user
- [ ] User explicitly approved (not assumed)
- [ ] Approval committed

## Phase 4: Session Planning — BLOCKING GATE

After user approves task decomposition, calculate session grouping for predictable execution.

1. Read all task files, collect per task: `wave`, `estimated_loc`, Context Files list.
2. Group waves into sessions using LOC budget:
   a. **Session LOC budget = ~1200 lines (±300)** — matches Phase 0 block size.
   b. Walk waves in order. For each wave, sum `estimated_loc` of its tasks.
   c. Accumulate wave LOC into current session. If adding next wave exceeds budget → start new session.
   d. **Never split a wave across sessions.**
   e. **Audit Wave + Final Wave → always the last session** (fixed, no LOC budget — these are review & deploy).
   f. If a single wave > budget → it gets its own session (warn user: "Wave N exceeds session budget").
3. For each session, collect unique Context Files from all tasks in that session (deduplicate).
4. Give each session a short descriptive title based on its tasks' descriptions.
5. Generate `work/{feature}/logs/session-plan.md` from template `$AGENTS_HOME/shared/work-templates/session-plan.md.template`.
6. Present session plan to user as a table:

   | Session | Title | Waves | Tasks | Estimated LOC |
   |---------|-------|-------|-------|---------------|
   | 1 | ... | 1-2 | 1,2,3 | 950 |

7. Ask user explicitly: **"План сессий готов. Подтверждаешь? (да/нет/правки)"**
8. Wait for explicit approval. Do NOT suggest running `/do-feature` until user confirms.
9. Only after explicit approval:
   - Update `session-plan.md` frontmatter: `status: approved`
   - Use `git add -f work/{feature}/logs/session-plan.md` (the `logs/` directory is typically gitignored — force-add is required)
   - Git commit: `chore(tasks): session plan approved for {feature} — {N} sessions`
10. After approval, inform user:

    ```
    Декомпозиция и план сессий утверждены.

    Следующий шаг: `/do-feature {feature}` для запуска сессии 1,
    или `/do-task` для ручного выполнения отдельной задачи.

    ⚠️ Реализация НЕ начнётся, пока вы явно не запустите одну из этих команд.
    ```

> **HARD STOP.** This is the end of `/decompose-tech-spec`. Do NOT auto-transition to `/do-feature` or `/do-task`. The user must explicitly invoke the next command in a separate action.

**Checkpoint:**
- [ ] session-plan.md created and committed
- [ ] User explicitly approved session plan
- [ ] status: approved set in session-plan.md frontmatter
- [ ] User informed about next step (no auto-transition)

## Final Check

- [ ] All phases completed (tasks created, validation passed, session plan approved)
- [ ] All tasks match template (frontmatter: status, depends_on, wave, skills, reviewers, worker_name)
- [ ] Validation: both validators passed or user confirmed remaining issues
- [ ] Session plan: approved by user, committed
