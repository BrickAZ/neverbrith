# Historical path compatibility only. Maintained implementation lives in tools/validators.
param([string]$Root,[string]$GameRoot)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
& (Join-Path $projectRoot 'tools/validators/validate-neverbrith.ps1') @PSBoundParameters
exit $LASTEXITCODE
