Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$selfPath = (Resolve-Path -LiteralPath $PSCommandPath).Path
$allFiles = Get-ChildItem -Path $repoRoot -Recurse -File | Where-Object { $_.FullName -ne $selfPath }

$forbiddenPatterns = @(
  "TeamCreate\(",
  "TeamDelete\(",
  "TaskOutput\(",
  "run_in_background\s*:",
  "\.claude/",
  "~\/\.claude",
  "Use Skill tool:",
  "TodoWrite",
  "NotebookEdit",
  "EnterPlanMode",
  "ExitPlanMode",
  "SessionStart\(compact\)",
  '\$CODEX_HOME',
  "\.codex/skills/"
)

$wrapperFiles = @(
  "skills/new-user-spec/SKILL.md",
  "skills/new-tech-spec/SKILL.md",
  "skills/decompose-tech-spec/SKILL.md",
  "skills/do-feature/SKILL.md",
  "skills/write-code/SKILL.md",
  "skills/init-project-knowledge/SKILL.md"
)

$failures = New-Object System.Collections.Generic.List[string]

foreach ($pattern in $forbiddenPatterns) {
  $matches = $allFiles |
    Select-String -Pattern $pattern -ErrorAction SilentlyContinue
  if ($matches) {
    foreach ($m in $matches) {
      $failures.Add("forbidden pattern '$pattern' in $($m.Path):$($m.LineNumber)")
    }
  }
}

foreach ($wf in $wrapperFiles) {
  $path = Join-Path $repoRoot $wf
  if (-not (Test-Path -LiteralPath $path)) {
    $failures.Add("wrapper missing: $wf")
    continue
  }
  $content = Get-Content -Raw -LiteralPath $path
  if ($content -notmatch "dispatch-skill\.ps1") {
    $failures.Add("wrapper does not use dispatcher: $wf")
  }
}

if ($failures.Count -gt 0) {
  Write-Host "FAIL"
  $failures | ForEach-Object { Write-Host "- $_" }
  exit 1
}

Write-Host "PASS"
