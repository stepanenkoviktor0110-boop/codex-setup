---
description: |
  Finalize a completed feature: read specs and decisions, update project knowledge files,
  archive feature directory to work/completed/.

  Use when: "фича готова", "заверши фичу", "done", "финализация", "закрой фичу", "перенеси в completed"
---

# Done — Finalize Feature

## Step 1: Load Documentation Skill

Read `$AGENTS_HOME/skills/documentation-writing/SKILL.md` and follow its principles.

## Step 2: Identify Feature

User typically provides feature directory with the command (e.g., `/done work/my-feature`).
- If provided → use it
- If not → ask: "Which feature to finalize? Provide path to work/{feature}/ directory."

## Step 3: Read Feature Artifacts

Read these files from the feature directory:
1. `user-spec.md` — what was planned
2. `tech-spec.md` — how it was implemented
3. `decisions.md` — what decisions were made during implementation

If `decisions.md` is missing or sparse, use `git log --oneline` for feature-related commits to understand what changed.

**Completeness check:** If the feature looks incomplete (tasks not marked done in tech-spec, missing implementation, failing tests) — warn the user: "Feature appears incomplete: {reason}. Continue with finalization anyway?"

## Step 4: Retrospective

Run retrospective skill to extract lessons learned from the feature process:

1. Read and execute `$AGENTS_HOME/skills/retrospective/SKILL.md`
2. Pass feature path to the skill
3. Wait for completion — lessons will be written as triad entries to `$AGENTS_HOME/skills/quick-learning/references/reasoning-patterns.md`

## Step 5: Update Project Knowledge

If `.agents/skills/project-knowledge/references/` does not exist or is empty — skip this step, inform the user that project knowledge has not been initialized.

Otherwise, read current PK files and update only those affected by the feature:
- `architecture.md` — new components, changed structure, data model / schema changes
- `patterns.md` — new project-specific patterns, testing approaches, business rules
- `deployment.md` — deployment or monitoring changes
- If the project has a backlog file, note any status updates for the user

Apply quality principles from documentation-writing skill: no code examples, no obvious content, only project-specific information.

## Step 6: Pre-archive Safety Check

**MUST check working tree state before archiving.** Run `git status`.
- If there are uncommitted changes in `work/{feature}/` → commit them first: `chore: sync final state of {feature} before archiving`
- If there are uncommitted changes OUTSIDE `work/{feature}/` (parallel work, other features) → do NOT touch them. Archive ONLY the feature directory. Warn user: "В рабочем дереве есть изменения вне {feature} — они не затронуты."
- If there are untracked files in `work/{feature}/` that should be preserved → stage and commit them.

## Step 7: Archive

Move `work/{feature}/` → `work/completed/{feature}/` (create `work/completed/` if it doesn't exist).

**Post-archive path consistency.** After moving the directory, check if any committed files reference the old path `work/{feature}/`:
- `checkpoint.yml` — update `feature_path` if it contains the old path.
- Do NOT update paths in `tech-spec.md` or `user-spec.md` — they are historical records.
- Do NOT search-and-replace across the whole repo. Only fix operational files that would break.

## Step 8: Commit & Report

1. Commit PK file changes and feature archive move.
   ```
   docs: update project knowledge after {feature-name}
   ```

2. Report to user:
   - What was done (brief summary from specs)
   - What PK files were updated and what changed
   - Feature archived to `work/completed/{feature}/`

## Self-Verification

ALL items MUST be checked. Do NOT mark as done without actual verification.

- [ ] Documentation-writing skill loaded
- [ ] Feature artifacts read and understood
- [ ] Completeness assessed (user warned if incomplete)
- [ ] Retrospective completed (lessons extracted)
- [ ] PK files updated (only affected ones)
- [ ] Working tree checked — no uncommitted feature changes lost
- [ ] Parallel work outside feature directory left untouched
- [ ] Feature archived to work/completed/
- [ ] Post-archive paths consistent (checkpoint.yml updated)
- [ ] Changes committed
- [ ] Report delivered to user
