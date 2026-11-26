# Historical invocation compatibility; the old mirror-parity test is retired.
param([string]$ProjectRoot = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))),
      [string]$InstalledSkillRoot,[switch]$SkipInstalledParity)
$ErrorActionPreference = 'Stop'
if ($InstalledSkillRoot) { Write-Warning 'InstalledSkillRoot is obsolete; this project owns .agents/skills.' }
& (Get-Process -Id $PID).Path -NoProfile -File (Join-Path $ProjectRoot 'tests/skill_packages_test.ps1') -Root $ProjectRoot
exit $LASTEXITCODE
