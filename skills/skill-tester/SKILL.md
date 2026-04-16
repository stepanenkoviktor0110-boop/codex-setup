---
name: skill-tester
description: |
  Execute test scenarios prepared by skill-test-designer. Runs parallel
  runners with and without the skill, grades acceptance criteria, and
  produces a report.

  Use when: "запусти тесты для скилла", "run skill tests", "execute skill
  scenarios", "проверь скилл тестами"
---

# Skill Tester

Use only supported Codex primitives:
- `spawn_agent`
- `wait_agent`
- `send_input`
- `close_agent`

Do not use team APIs, TaskOutput APIs, or run_in_background flags.

## Input

Scenario files: `$AGENTS_HOME/skill-tests/{skill-name}/scenarios/`
If missing -> ask user to run `skill-test-designer`.

## Phase 1: Prepare

1. Read all scenario files.
2. Read tested skill (`SKILL.md` + referenced files).
3. Extract:
   - required phases
   - required references
   - expected outputs
   - acceptance criteria
   - test model profile per scenario

## Phase 2: Execution Plan

Per scenario:
- 2 runners with skill
- 1 baseline runner without skill
- run runners in parallel, scenarios sequentially

Model selection:
- complex/coding scenarios -> `tier_high` (`gpt-5.4`)
- medium scenarios -> `tier_medium` (`gpt-5.3-codex`)
- simple deterministic scenarios -> `tier_low` (`gpt-5.4-mini`, `reasoning_effort: low`)

## Phase 3: Run Scenario

### 3a. Spawn runners

Spawn three agents with the same task prompt:
- `runner_a` (with skill context)
- `runner_b` (with skill context)
- `baseline` (without skill context)

Track returned `agent_id`s.

### 3b. Interactive loop

If runner asks clarification:
1. reply in scenario persona via `send_input`
2. keep answers consistent across runners

When each runner reports done, collect:
- output summary
- file paths created/modified
- verification commands executed

### 3c. Grade with grader agents

Spawn one grader per runner (`tier_medium`).
Pass grader:
- runner final message
- runner output files (read by grader)
- scenario acceptance criteria
- skill requirements checklist

Each grader returns structured result:
- criterion verdicts with evidence
- phase compliance
- references actually read
- final verdict

### 3d. Consolidate

Build comparison:
- skill-runners only pass -> skill adds value
- everyone passes -> scenario too easy or skill neutral
- everyone fails -> criterion unrealistic or task unclear
- baseline only pass -> skill likely harmful

## Phase 4: Report

Generate report from `references/report-template.md`.
Save to:
`$AGENTS_HOME/skill-tests/{skill-name}/reports/{timestamp}-report.md`

After report delivery, close all runner/grader agents.

## Self-Verification

- [ ] All scenarios executed
- [ ] 2 skill-runners + 1 baseline per scenario
- [ ] Criteria graded with evidence
- [ ] Skill compliance checked
- [ ] Report saved and shown
