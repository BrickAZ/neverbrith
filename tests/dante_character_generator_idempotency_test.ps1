param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$generator = Join-Path $Root 'tools\rebuild-dante-full-base-atlas.ps1'
$atlas = Join-Path $Root 'resources\gfx\characters\costumes\character_dante.png'

if (-not (Test-Path -LiteralPath $generator)) { throw "missing generator: $generator" }
if (-not (Test-Path -LiteralPath $atlas)) { throw "missing atlas: $atlas" }

& $generator -Root $Root | Out-Null
$first = (Get-FileHash -Algorithm SHA256 -LiteralPath $atlas).Hash
& $generator -Root $Root | Out-Null
$second = (Get-FileHash -Algorithm SHA256 -LiteralPath $atlas).Hash

if ($first -ne $second) {
    throw "Dante atlas generator is not idempotent: first=$first second=$second"
}

Write-Output "Dante atlas generator idempotency contract passed: $second"
