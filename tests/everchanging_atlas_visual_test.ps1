param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)

& (Join-Path $PSScriptRoot 'ringotsuga_accessory_atlas_visual_test.ps1') -Root $Root
& (Join-Path $PSScriptRoot 'creator_accessory_atlas_visual_test.ps1') -Root $Root
& (Join-Path $PSScriptRoot 'creator_accessory_anm2_visual_test.ps1') -Root $Root

Write-Output 'Everchanging Ringo atlas entry now delegates to the headgear-only accessory contract'
Write-Output 'Everchanging creator accessory visual contracts passed'

