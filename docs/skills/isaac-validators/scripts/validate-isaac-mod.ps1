# Historical path compatibility only. Maintained implementation lives in tools/validators.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Root,[string]$ModObjectName='',
      [string[]]$LuaDirectories=@('scripts'),[string]$SkillRoot='')
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
& (Join-Path $projectRoot 'tools/validators/validate-isaac-mod.ps1') @PSBoundParameters
exit $LASTEXITCODE
