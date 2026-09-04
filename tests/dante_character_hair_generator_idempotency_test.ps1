param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$generator = Join-Path $Root 'tools\rebuild-dante-separated-hair.ps1'
$hair = Join-Path $Root 'resources\gfx\characters\costumes\costume_dante_hair.png'

foreach ($path in @($generator, $hair)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "missing Dante hair generator contract file: $path" }
}

& $generator -Root $Root | Out-Null
$first = (Get-FileHash -Algorithm SHA256 -LiteralPath $hair).Hash
& $generator -Root $Root | Out-Null
$second = (Get-FileHash -Algorithm SHA256 -LiteralPath $hair).Hash

if ($first -ne $second) {
    throw "Dante separated-hair generator is not idempotent: first=$first second=$second"
}

Write-Output "Dante separated-hair generator idempotency contract passed: $second"

