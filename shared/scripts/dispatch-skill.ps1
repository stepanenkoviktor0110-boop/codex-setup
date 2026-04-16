param(
  [Parameter(Mandatory = $true)]
  [string]$SkillAlias,
  [switch]$AsPrompt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

$aliasMap = @{
  "new-user-spec"          = "user-spec-planning"
  "new-tech-spec"          = "tech-spec-planning"
  "decompose-tech-spec"    = "task-decomposition"
  "do-feature"             = "feature-execution"
  "write-code"             = "code-writing"
  "init-project-knowledge" = "project-planning"
}

$resolvedSkill = if ($aliasMap.ContainsKey($SkillAlias)) { $aliasMap[$SkillAlias] } else { $SkillAlias }
$skillPath = Join-Path $repoRoot ("skills/{0}/SKILL.md" -f $resolvedSkill)
$skillPathResolved = Resolve-Path -LiteralPath $skillPath

if (-not (Test-Path -LiteralPath $skillPath)) {
  Write-Error ("Skill not found: alias='{0}', resolved='{1}', path='{2}'" -f $SkillAlias, $resolvedSkill, $skillPath)
  exit 1
}

$result = [ordered]@{
  alias          = $SkillAlias
  resolved_skill = $resolvedSkill
  skill_path     = $skillPathResolved.Path
  exists         = $true
}

if ($AsPrompt) {
  @"
Resolved skill alias:
- alias: $SkillAlias
- skill: $resolvedSkill
- file: $($skillPathResolved.Path)

Execution contract:
1. Read SKILL.md fully.
2. Read only directly referenced files needed for the current step.
3. Execute the workflow exactly as written.
4. Use model tiers from skills/tech-spec-planning/references/model-profiles.md.
"@
  exit 0
}

$result | ConvertTo-Json -Depth 3
