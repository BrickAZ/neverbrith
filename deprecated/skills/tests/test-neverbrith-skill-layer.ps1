# Historical invocation compatibility; the old mirror-parity test is retired.
param([string]$ProjectRoot = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))),
      [string]$InstalledSkillRoot,[switch]$SkipInstalledParity)
$ErrorActionPreference = 'Stop'
if ($InstalledSkillRoot) { Write-Warning 'InstalledSkillRoot is obsolete; this project owns .agents/skills.' }
& (Join-Path $ProjectRoot 'tests/project_knowledge_test.ps1') -Root $ProjectRoot
exit 0
