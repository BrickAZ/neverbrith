param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$registrationFiles = @(Get-ChildItem -LiteralPath (Join-Path $Root 'content') -Filter 'players*.xml' -File)
foreach ($resourceRoot in @(Get-ChildItem -LiteralPath $Root -Directory -Filter 'resources*')) {
    $registrationFiles += @(Get-ChildItem -LiteralPath $resourceRoot.FullName -Filter 'players*.xml' -File)
}
foreach ($file in $registrationFiles) {
    [xml]$xml = Get-Content -LiteralPath $file.FullName -Raw
    $players = @($xml.SelectNodes('//player'))
    if ($players.Count -ne 0) {
        throw "Custom characters must remain unregistered: $($file.FullName) contains $($players.Count) player(s)"
    }
}

$main = Get-Content -LiteralPath (Join-Path $Root 'main.lua') -Raw
$characterLoads = [regex]::Matches($main, '(?m)^(?!\s*--)[^\r\n]*\b(?:include|require)\s*\(\s*["''][^"'']*_character["'']')
if ($characterLoads.Count -ne 0) {
    throw "Custom character module is still loaded: $($characterLoads[0].Value.Trim())"
}

Write-Output 'No custom character registrations or character-module bootstrap calls: passed'
